class_name CityWorldStreamer
extends Node3D

## Manages 2048m x 2048m procedural chunk streaming around the player helicopter.
## Uses a 16x16 chunk grid of 128m x 128m chunks (cx in [-8, 7], cz in [-8, 7]).
## Streaming radii:
## - Full Detail: Chebyshev distance <= 1 chunks (3x3 grid = up to 9 chunks)
## - HLOD Skyline: Chebyshev distance in [2, 3] chunks (7x7 ring = up to 40 chunks)
## - Unloaded/Pooled: Chebyshev distance > 3 chunks
## Bounded chunk loads per frame to eliminate loading hitching and frame spikes.

signal playable_area_ready()
signal chunk_streamed(coord: Vector2i, detail: CityChunk.DetailLevel)

@export var world_seed: int = 1337
@export var chunk_size: float = 128.0
@export var world_chunks_min: Vector2i = Vector2i(-8, -8)
@export var world_chunks_max: Vector2i = Vector2i(7, 7)
@export var full_detail_radius: int = 1
@export var hlod_radius: int = 3
@export var max_full_detail_loads_per_frame: int = 1
@export var max_hlod_loads_per_frame: int = 2
@export var max_unloads_per_frame: int = 1
@export var immediate_startup_load: bool = false

var target_player: Node3D = null
var active_chunks: Dictionary = {} # Vector2i -> CityChunk
var chunk_pool: Array[CityChunk] = []
var load_queue: Array[Dictionary] = [] # Array of { "coord": Vector2i, "detail": CityChunk.DetailLevel, "priority": int }
var unload_queue: Array[Vector2i] = []

var last_player_chunk: Vector2i = Vector2i(9999, 9999)
var _is_initialized: bool = false
var is_playable_ready: bool = false
var _is_startup_phase: bool = true
var total_chunks_recycled: int = 0

var road_graph: AStar3D = AStar3D.new()
var _chunk_road_points: Dictionary = {} # Vector2i -> Array[int]
var _road_point_ref_counts: Dictionary = {} # int -> int

# Registered world metadata synced with streamed chunk lifecycle
var registered_rooftop_sockets: Dictionary = {} # socket_id (String) -> Dictionary
var registered_buildings: Dictionary = {} # building_id (String) -> Dictionary
var _chunk_rooftop_socket_ids: Dictionary = {} # Vector2i -> Array[String]
var _chunk_building_ids: Dictionary = {} # Vector2i -> Array[String]

var _markers_dirty: bool = false
var _marker_sync_timer: float = 0.0

func _ready() -> void:
	add_to_group("city_streamer")
	_resolve_player()

	var start_chunk := Vector2i.ZERO
	if is_instance_valid(target_player):
		start_chunk = world_to_chunk_coord(target_player.global_position)

	if immediate_startup_load:
		force_update(start_chunk)
	else:
		_start_controlled_startup(start_chunk)

func _resolve_player() -> void:
	if not is_instance_valid(target_player) and is_inside_tree():
		target_player = get_tree().get_first_node_in_group("player") as Node3D

func world_to_chunk_coord(world_pos: Vector3) -> Vector2i:
	var cx: int = int(floor((world_pos.x + chunk_size * 0.5) / chunk_size))
	var cz: int = int(floor((world_pos.z + chunk_size * 0.5) / chunk_size))
	return Vector2i(cx, cz)

func chunk_to_world_center(chunk_coord: Vector2i) -> Vector3:
	return Vector3(float(chunk_coord.x) * chunk_size, 0.0, float(chunk_coord.y) * chunk_size)

func is_chunk_in_world_bounds(chunk_coord: Vector2i) -> bool:
	return (chunk_coord.x >= world_chunks_min.x and chunk_coord.x <= world_chunks_max.x and
			chunk_coord.y >= world_chunks_min.y and chunk_coord.y <= world_chunks_max.y)

# ==============================================================================
# CONTROLLED STARTUP SEQUENCE
# ==============================================================================
func _start_controlled_startup(start_chunk: Vector2i) -> void:
	last_player_chunk = start_chunk
	load_queue.clear()
	unload_queue.clear()
	is_playable_ready = false
	_is_startup_phase = true

	# 1. Immediately build player's center chunk so ground and helipad exist on frame 0
	var center_chunk := _get_or_create_chunk(start_chunk, CityChunk.DetailLevel.FULL_DETAIL)
	active_chunks[start_chunk] = center_chunk
	_add_chunk_to_road_graph(center_chunk)
	_register_chunk_metadata(center_chunk)
	chunk_streamed.emit(start_chunk, CityChunk.DetailLevel.FULL_DETAIL)

	# 2. Queue the remaining 8 immediate 3x3 neighbors with highest priority (1 per frame)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var c := start_chunk + Vector2i(dx, dz)
			if is_chunk_in_world_bounds(c):
				load_queue.append({ "coord": c, "detail": CityChunk.DetailLevel.FULL_DETAIL, "priority": 1 })

	# 3. Queue distant HLOD chunks (radius 2 and 3)
	for dx in range(-hlod_radius, hlod_radius + 1):
		for dz in range(-hlod_radius, hlod_radius + 1):
			var chebyshev_dist: int = maxi(absi(dx), absi(dz))
			if chebyshev_dist > full_detail_radius and chebyshev_dist <= hlod_radius:
				var c := start_chunk + Vector2i(dx, dz)
				if is_chunk_in_world_bounds(c):
					load_queue.append({ "coord": c, "detail": CityChunk.DetailLevel.HLOD, "priority": 0 })

	_sort_load_queue(start_chunk)
	_is_initialized = true

func _process(delta: float) -> void:
	if not is_instance_valid(target_player):
		_resolve_player()
		if not is_instance_valid(target_player):
			return

	var p_chunk := world_to_chunk_coord(target_player.global_position)
	if p_chunk != last_player_chunk:
		last_player_chunk = p_chunk
		_update_streaming_targets(p_chunk)

	_process_streaming_budget()

	# Deferred marker synchronization
	if _markers_dirty:
		_marker_sync_timer += delta
		if (load_queue.is_empty() and unload_queue.is_empty()) or _marker_sync_timer >= 1.0:
			_marker_sync_timer = 0.0
			_markers_dirty = false
			_sync_gameplay_markers()

func force_update(center_chunk: Vector2i) -> void:
	last_player_chunk = center_chunk
	load_queue.clear()
	unload_queue.clear()
	_update_streaming_targets(center_chunk)

	# Synchronously process all queued loads/unloads for explicit forced update (unit tests / resets)
	while not load_queue.is_empty() or not unload_queue.is_empty():
		while not load_queue.is_empty():
			var item: Dictionary = load_queue.pop_front()
			_apply_chunk_load(item)
		while not unload_queue.is_empty():
			var c: Vector2i = unload_queue.pop_front()
			_recycle_chunk(c)

	is_playable_ready = true
	_is_startup_phase = false
	_markers_dirty = false
	_sync_gameplay_markers()
	playable_area_ready.emit()
	_is_initialized = true

func _update_streaming_targets(center_chunk: Vector2i) -> void:
	var desired_chunks: Dictionary = {} # Vector2i -> CityChunk.DetailLevel

	# 1. Determine desired state for all chunks within hlod_radius (7x7 ring)
	for dx in range(-hlod_radius, hlod_radius + 1):
		for dz in range(-hlod_radius, hlod_radius + 1):
			var c := center_chunk + Vector2i(dx, dz)
			if not is_chunk_in_world_bounds(c):
				continue

			var chebyshev_dist: int = maxi(absi(dx), absi(dz))
			if chebyshev_dist <= full_detail_radius:
				desired_chunks[c] = CityChunk.DetailLevel.FULL_DETAIL
			elif chebyshev_dist <= hlod_radius:
				desired_chunks[c] = CityChunk.DetailLevel.HLOD

	# Pin chunks with active combat turrets to FULL_DETAIL if within combat range of player
	var player_world_pos: Vector3 = chunk_to_world_center(center_chunk)
	for sid in registered_rooftop_sockets.keys():
		var socket: Dictionary = registered_rooftop_sockets[sid]
		var occupant: Node = socket.get("occupant", null)
		if is_instance_valid(occupant) and not occupant.is_queued_for_deletion():
			var spos: Vector3 = socket.get("world_position", Vector3.ZERO)
			if spos.distance_to(player_world_pos) <= 95.0:
				var sc: Vector2i = world_to_chunk_coord(spos)
				if is_chunk_in_world_bounds(sc):
					desired_chunks[sc] = CityChunk.DetailLevel.FULL_DETAIL

	# 2. Queue chunks outside desired_chunks for gradual unloading
	for c: Vector2i in active_chunks.keys():
		if not desired_chunks.has(c):
			if not unload_queue.has(c):
				unload_queue.append(c)

	# Remove chunks from unload_queue if they are now desired again
	for c: Vector2i in desired_chunks.keys():
		unload_queue.erase(c)

	# Sort unload_queue: furthest chunks from player first
	unload_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = maxi(absi(a.x - center_chunk.x), absi(a.y - center_chunk.y))
		var db: int = maxi(absi(b.x - center_chunk.x), absi(b.y - center_chunk.y))
		return da > db
	)

	# 3. Check transitions and missing chunks
	for c: Vector2i in desired_chunks.keys():
		var desired_level: CityChunk.DetailLevel = desired_chunks[c] as CityChunk.DetailLevel
		var priority: int = 1 if desired_level == CityChunk.DetailLevel.FULL_DETAIL else 0
		if active_chunks.has(c):
			var existing_chunk: CityChunk = active_chunks[c] as CityChunk
			if existing_chunk.detail_level != desired_level:
				_queue_load(c, desired_level, priority)
		else:
			_queue_load(c, desired_level, priority)

	_sort_load_queue(center_chunk)

func _sort_load_queue(center_chunk: Vector2i) -> void:
	load_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var prio_a: int = a.get("priority", 0) as int
		var prio_b: int = b.get("priority", 0) as int
		if prio_a != prio_b:
			return prio_a > prio_b
		var ca: Vector2i = a.get("coord", Vector2i.ZERO) as Vector2i
		var cb: Vector2i = b.get("coord", Vector2i.ZERO) as Vector2i
		var da: int = maxi(absi(ca.x - center_chunk.x), absi(ca.y - center_chunk.y))
		var db: int = maxi(absi(cb.x - center_chunk.x), absi(cb.y - center_chunk.y))
		return da < db
	)

func _queue_load(c: Vector2i, detail: CityChunk.DetailLevel, priority: int = 0) -> void:
	for item in load_queue:
		if item.get("coord") == c:
			item["detail"] = detail
			item["priority"] = priority
			return
	load_queue.append({ "coord": c, "detail": detail, "priority": priority })

func _process_streaming_budget() -> void:
	var full_detail_loaded: int = 0
	var hlod_loaded: int = 0
	var unloads_done: int = 0

	# Process load queue with strict per-frame budget
	while not load_queue.is_empty():
		var next_item: Dictionary = load_queue[0]
		var next_detail: CityChunk.DetailLevel = next_item.get("detail", CityChunk.DetailLevel.FULL_DETAIL) as CityChunk.DetailLevel

		if next_detail == CityChunk.DetailLevel.FULL_DETAIL:
			if full_detail_loaded >= max_full_detail_loads_per_frame:
				break # At most 1 full-detail chunk per frame to prevent frame-time spikes
			var item: Dictionary = load_queue.pop_front()
			_apply_chunk_load(item)
			full_detail_loaded += 1
			_markers_dirty = true
			break # Stop after heavy full-detail chunk
		else:
			# Lightweight HLOD chunk
			if hlod_loaded >= max_hlod_loads_per_frame:
				break
			var item: Dictionary = load_queue.pop_front()
			_apply_chunk_load(item)
			hlod_loaded += 1

	# If no heavy full-detail chunk was loaded this frame, process gradual unloads
	if full_detail_loaded == 0 and not unload_queue.is_empty():
		while not unload_queue.is_empty() and unloads_done < max_unloads_per_frame:
			var c: Vector2i = unload_queue.pop_front()
			_recycle_chunk(c)
			unloads_done += 1
			_markers_dirty = true

	# Check startup readiness (minimum 3x3 playable region)
	if _is_startup_phase:
		var all_neighbors_ready: bool = true
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var c := last_player_chunk + Vector2i(dx, dz)
				if is_chunk_in_world_bounds(c):
					if not active_chunks.has(c) or (active_chunks[c] as CityChunk).detail_level != CityChunk.DetailLevel.FULL_DETAIL:
						all_neighbors_ready = false
						break
			if not all_neighbors_ready:
				break

		if all_neighbors_ready:
			_is_startup_phase = false
			is_playable_ready = true
			_sync_gameplay_markers()
			_markers_dirty = false
			playable_area_ready.emit()

func _apply_chunk_load(item: Dictionary) -> void:
	var c: Vector2i = item.get("coord", Vector2i.ZERO) as Vector2i
	var detail: CityChunk.DetailLevel = item.get("detail", CityChunk.DetailLevel.FULL_DETAIL) as CityChunk.DetailLevel

	var chunk: CityChunk = null
	if active_chunks.has(c):
		chunk = active_chunks[c] as CityChunk
		chunk.set_detail_level(detail)
	else:
		chunk = _get_or_create_chunk(c, detail)
		active_chunks[c] = chunk

	if detail == CityChunk.DetailLevel.FULL_DETAIL:
		_add_chunk_to_road_graph(chunk)
		_register_chunk_metadata(chunk)
	else:
		_remove_chunk_from_road_graph(chunk)
		_unregister_chunk_metadata(chunk.coord)

	chunk_streamed.emit(c, detail)

func _get_or_create_chunk(c: Vector2i, detail: CityChunk.DetailLevel) -> CityChunk:
	var chunk: CityChunk = null
	if not chunk_pool.is_empty():
		chunk = chunk_pool.pop_back()
		chunk.setup(c, detail, world_seed)
		chunk.visible = true
	else:
		chunk = CityChunk.new()
		add_child(chunk)
		chunk.setup(c, detail, world_seed)
	return chunk

func _recycle_chunk(c: Vector2i) -> void:
	if not active_chunks.has(c):
		return
	var chunk: CityChunk = active_chunks[c] as CityChunk
	_remove_chunk_from_road_graph(chunk)
	_unregister_chunk_metadata(c)
	active_chunks.erase(c)
	chunk.set_detail_level(CityChunk.DetailLevel.UNLOADED)
	chunk.visible = false
	chunk_pool.append(chunk)
	total_chunks_recycled += 1

func _get_road_point_id(pos: Vector3) -> int:
	var qx: int = int(round(pos.x / 4.0)) + 500000
	var qz: int = int(round(pos.z / 4.0)) + 500000
	return (qx & 0xFFFFFF) | ((qz & 0xFFFFFF) << 24)

func _add_chunk_to_road_graph(chunk: CityChunk) -> void:
	if _chunk_road_points.has(chunk.coord):
		return

	var origin := chunk_to_world_center(chunk.coord)
	var p_center := origin + Vector3(0.0, 0.3, 0.0)
	var p_north := origin + Vector3(0.0, 0.3, -64.0)
	var p_south := origin + Vector3(0.0, 0.3, 64.0)
	var p_west  := origin + Vector3(-64.0, 0.3, 0.0)
	var p_east  := origin + Vector3(64.0, 0.3, 0.0)
	var p_mid_n := origin + Vector3(0.0, 0.3, -32.0)
	var p_mid_s := origin + Vector3(0.0, 0.3, 32.0)
	var p_mid_w := origin + Vector3(-32.0, 0.3, 0.0)
	var p_mid_e := origin + Vector3(32.0, 0.3, 0.0)

	var pts: Array[Vector3] = [
		p_center, p_north, p_south, p_west, p_east,
		p_mid_n, p_mid_s, p_mid_w, p_mid_e
	]

	var added_ids: Array[int] = []
	for p in pts:
		var pid := _get_road_point_id(p)
		added_ids.append(pid)
		if not road_graph.has_point(pid):
			road_graph.add_point(pid, p)
		_road_point_ref_counts[pid] = _road_point_ref_counts.get(pid, 0) + 1

	_chunk_road_points[chunk.coord] = added_ids

	var id_c := _get_road_point_id(p_center)
	var id_n := _get_road_point_id(p_north)
	var id_s := _get_road_point_id(p_south)
	var id_w := _get_road_point_id(p_west)
	var id_e := _get_road_point_id(p_east)
	var id_mn := _get_road_point_id(p_mid_n)
	var id_ms := _get_road_point_id(p_mid_s)
	var id_mw := _get_road_point_id(p_mid_w)
	var id_me := _get_road_point_id(p_mid_e)

	road_graph.connect_points(id_n, id_mn)
	road_graph.connect_points(id_mn, id_c)
	road_graph.connect_points(id_c, id_ms)
	road_graph.connect_points(id_ms, id_s)

	road_graph.connect_points(id_w, id_mw)
	road_graph.connect_points(id_mw, id_c)
	road_graph.connect_points(id_c, id_me)
	road_graph.connect_points(id_me, id_e)

func _remove_chunk_from_road_graph(chunk: CityChunk) -> void:
	if not _chunk_road_points.has(chunk.coord):
		return
	var point_ids: Array[int] = _chunk_road_points[chunk.coord]
	_chunk_road_points.erase(chunk.coord)

	for pid in point_ids:
		var ref_cnt: int = _road_point_ref_counts.get(pid, 1) - 1
		if ref_cnt <= 0:
			_road_point_ref_counts.erase(pid)
			if road_graph.has_point(pid):
				road_graph.remove_point(pid)
		else:
			_road_point_ref_counts[pid] = ref_cnt

# ==============================================================================
# WORLD METADATA REGISTRATION & LIFECYCLE
# ==============================================================================
func _register_chunk_metadata(chunk: CityChunk) -> void:
	if _chunk_rooftop_socket_ids.has(chunk.coord):
		_unregister_chunk_metadata(chunk.coord)

	var s_ids: Array[String] = []
	for socket: Dictionary in chunk.rooftop_sockets:
		var sid: String = socket.get("socket_id", "")
		if not sid.is_empty():
			registered_rooftop_sockets[sid] = socket
			s_ids.append(sid)
	_chunk_rooftop_socket_ids[chunk.coord] = s_ids

	var b_ids: Array[String] = []
	for b_rec: Dictionary in chunk.building_records:
		var bid: String = b_rec.get("building_id", "")
		if not bid.is_empty():
			registered_buildings[bid] = b_rec
			b_ids.append(bid)
	_chunk_building_ids[chunk.coord] = b_ids

func _unregister_chunk_metadata(c: Vector2i) -> void:
	if _chunk_rooftop_socket_ids.has(c):
		for sid: String in _chunk_rooftop_socket_ids[c]:
			if registered_rooftop_sockets.has(sid):
				var socket: Dictionary = registered_rooftop_sockets[sid]
				var occupant: Node = socket.get("occupant", null)
				if is_instance_valid(occupant) and not occupant.is_queued_for_deletion():
					if occupant.has_method("despawn_unloaded"):
						occupant.despawn_unloaded()
					else:
						occupant.queue_free()
				registered_rooftop_sockets.erase(sid)
		_chunk_rooftop_socket_ids.erase(c)

	if _chunk_building_ids.has(c):
		for bid: String in _chunk_building_ids[c]:
			registered_buildings.erase(bid)
		_chunk_building_ids.erase(c)

func get_available_rooftop_sockets() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for socket: Dictionary in registered_rooftop_sockets.values():
		var is_occ: bool = socket.get("is_occupied", false)
		var occ: Variant = socket.get("occupant", null)
		if is_occ and (occ == null or not is_instance_valid(occ)):
			socket["is_occupied"] = false
			socket["occupant"] = null
			is_occ = false
		if not is_occ:
			available.append(socket)
	return available

func get_rooftop_sockets_in_radius(center_pos: Vector3, min_dist: float = 0.0, max_dist: float = 120.0, unoccupied_only: bool = true) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for socket: Dictionary in registered_rooftop_sockets.values():
		var is_occ: bool = socket.get("is_occupied", false)
		var occ: Variant = socket.get("occupant", null)
		if is_occ and (occ == null or not is_instance_valid(occ)):
			socket["is_occupied"] = false
			socket["occupant"] = null
			is_occ = false
		if unoccupied_only and is_occ:
			continue
		var wpos: Vector3 = socket.get("world_position", Vector3.ZERO)
		var d: float = center_pos.distance_to(wpos)
		if d >= min_dist and d <= max_dist:
			var copy: Dictionary = socket.duplicate()
			copy["distance"] = d
			results.append(copy)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	return results

func get_building_records_in_radius(center_pos: Vector3, radius: float = 120.0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for b_rec: Dictionary in registered_buildings.values():
		var wpos: Vector3 = b_rec.get("world_position", Vector3.ZERO)
		var d: float = center_pos.distance_to(wpos)
		if d <= radius:
			var copy: Dictionary = b_rec.duplicate()
			copy["distance"] = d
			results.append(copy)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	return results

func occupy_rooftop_socket(socket_id: String) -> bool:
	if registered_rooftop_sockets.has(socket_id):
		registered_rooftop_sockets[socket_id]["is_occupied"] = true
		return true
	return false

func set_socket_occupant(socket_id: String, occupant: Node3D) -> void:
	if registered_rooftop_sockets.has(socket_id):
		registered_rooftop_sockets[socket_id]["occupant"] = occupant
		registered_rooftop_sockets[socket_id]["is_occupied"] = is_instance_valid(occupant)

func get_socket_occupant(socket_id: String) -> Node3D:
	if registered_rooftop_sockets.has(socket_id):
		var occ: Variant = registered_rooftop_sockets[socket_id].get("occupant", null)
		if is_instance_valid(occ):
			return occ as Node3D
	return null

func release_rooftop_socket(socket_id: String) -> void:
	if registered_rooftop_sockets.has(socket_id):
		registered_rooftop_sockets[socket_id]["is_occupied"] = false
		registered_rooftop_sockets[socket_id]["occupant"] = null

# ==============================================================================
# QUERIES & TELEMETRY
# ==============================================================================
func get_active_chunk_count() -> int:
	var count: int = 0
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level == CityChunk.DetailLevel.FULL_DETAIL:
			count += 1
	return count

func get_hlod_chunk_count() -> int:
	var count: int = 0
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level == CityChunk.DetailLevel.HLOD:
			count += 1
	return count

func get_loaded_chunk_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for c: Vector2i in active_chunks.keys():
		coords.append(c)
	return coords

func get_ground_spawn_points(center_pos: Vector3, min_dist: float = 38.0, max_dist: float = 75.0) -> Array[Vector3]:
	var results: Array[Vector3] = []
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level == CityChunk.DetailLevel.FULL_DETAIL:
			for pt: Vector3 in chunk.ground_spawn_points:
				var d: float = center_pos.distance_to(pt)
				if d >= min_dist and d <= max_dist:
					results.append(pt)
	return results

func get_rooftop_spawn_points(center_pos: Vector3, min_dist: float = 30.0, max_dist: float = 85.0) -> Array[Vector3]:
	var results: Array[Vector3] = []
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level == CityChunk.DetailLevel.FULL_DETAIL:
			for pt: Vector3 in chunk.rooftop_spawn_points:
				var d: float = center_pos.distance_to(pt)
				if d >= min_dist and d <= max_dist:
					results.append(pt)
	return results

func get_air_entry_positions(center_pos: Vector3, min_dist: float = 45.0, max_dist: float = 120.0) -> Array[Vector3]:
	var results: Array[Vector3] = []
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level == CityChunk.DetailLevel.FULL_DETAIL:
			for pt: Vector3 in chunk.air_entry_positions:
				var d: float = center_pos.distance_to(pt)
				if d >= min_dist and d <= max_dist:
					results.append(pt)
	return results

func get_objective_candidates(center_pos: Vector3, min_dist: float = 40.0, max_dist: float = 150.0) -> Array[Vector3]:
	var results: Array[Vector3] = []
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level == CityChunk.DetailLevel.FULL_DETAIL:
			for pt: Vector3 in chunk.objective_candidates:
				var d: float = center_pos.distance_to(pt)
				if d >= min_dist and d <= max_dist:
					results.append(pt)
	return results

func get_pickup_candidates(center_pos: Vector3, min_dist: float = 25.0, max_dist: float = 90.0) -> Array[Vector3]:
	var results: Array[Vector3] = []
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level == CityChunk.DetailLevel.FULL_DETAIL:
			for pt: Vector3 in chunk.pickup_candidates:
				var d: float = center_pos.distance_to(pt)
				if d >= min_dist and d <= max_dist:
					results.append(pt)
	return results

func get_safe_open_positions(center_pos: Vector3, min_dist: float = 0.0, max_dist: float = 60.0) -> Array[Vector3]:
	var results: Array[Vector3] = []
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level == CityChunk.DetailLevel.FULL_DETAIL:
			for pt: Vector3 in chunk.safe_open_positions:
				var d: float = center_pos.distance_to(pt)
				if d >= min_dist and d <= max_dist:
					results.append(pt)
	return results

func get_road_path(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	if road_graph.get_point_count() == 0:
		return PackedVector3Array([to_pos])
	var id_from: int = road_graph.get_closest_point(from_pos)
	var id_to: int = road_graph.get_closest_point(to_pos)
	if id_from == -1 or id_to == -1:
		return PackedVector3Array([to_pos])
	var path := road_graph.get_point_path(id_from, id_to)
	if path.is_empty():
		return PackedVector3Array([to_pos])
	var result := PackedVector3Array(path)
	result.append(to_pos)
	return result

func get_nearest_road_point(pos: Vector3) -> Vector3:
	if road_graph.get_point_count() == 0:
		return pos
	var id: int = road_graph.get_closest_point(pos)
	if id == -1:
		return pos
	return road_graph.get_point_position(id)

func query_natural_spawn_candidates(center_pos: Vector3, category: String = "ground", min_dist: float = 38.0, max_dist: float = 160.0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for chunk: CityChunk in active_chunks.values():
		if chunk.detail_level != CityChunk.DetailLevel.FULL_DETAIL:
			continue
		var raw_points: Array[Vector3] = []
		match category:
			"ground":
				raw_points = chunk.ground_spawn_points
			"air":
				raw_points = chunk.air_entry_positions
			"rooftop":
				raw_points = chunk.rooftop_spawn_points
			_:
				raw_points = chunk.ground_spawn_points

		for pt: Vector3 in raw_points:
			var d: float = center_pos.distance_to(pt)
			if d >= min_dist and d <= max_dist:
				var heading := (center_pos - pt)
				heading.y = 0.0
				var h_norm := heading.normalized() if heading.length_squared() > 0.01 else Vector3.FORWARD
				var cand_data: Dictionary = {
					"position": pt,
					"heading": h_norm,
					"category": category,
					"chunk_coord": chunk.coord,
					"source_name": "%s_Chunk_%d_%d" % [category.capitalize(), chunk.coord.x, chunk.coord.y],
					"distance": d,
					"validation_result": "VALID"
				}
				if category == "rooftop":
					for socket: Dictionary in chunk.rooftop_sockets:
						var swpos: Vector3 = socket.get("world_position", Vector3.ZERO) as Vector3
						if swpos.distance_squared_to(pt) < 1.0:
							cand_data["socket_id"] = socket.get("socket_id", "")
							cand_data["building_id"] = socket.get("building_id", "")
							cand_data["building_type"] = socket.get("building_type", "")
							cand_data["usable_clearance"] = socket.get("usable_clearance", 4.0)
							cand_data["height"] = socket.get("height", 0.0)
							cand_data["surface_type"] = socket.get("surface_type", "concrete")
							cand_data["rotation_y"] = socket.get("rotation_y", 0.0)
							cand_data["equipment_position"] = socket.get("equipment_position", Vector3.ZERO)
							cand_data["lookout_position"] = socket.get("lookout_position", Vector3.ZERO)
							break
				results.append(cand_data)

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	return results

func _sync_gameplay_markers() -> void:
	if not is_inside_tree():
		return
	var root: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if not root:
		return

	# 1. Synchronize GroundSpawnSources
	var g_sources: Node3D = root.get_node_or_null("GroundSpawnSources") as Node3D
	if is_instance_valid(g_sources):
		var p_pos: Vector3 = target_player.global_position if is_instance_valid(target_player) else Vector3.ZERO
		var ground_pts := get_ground_spawn_points(p_pos, 35.0, 160.0)
		if not ground_pts.is_empty():
			_ensure_named_marker(g_sources, "RoadEntrance_North", ground_pts[0])
			if ground_pts.size() > 1:
				_ensure_named_marker(g_sources, "RoadEntrance_South", ground_pts[1])
			if ground_pts.size() > 2:
				_ensure_named_marker(g_sources, "RoadEntrance_East", ground_pts[2])
			if ground_pts.size() > 3:
				_ensure_named_marker(g_sources, "RoadEntrance_West", ground_pts[3])
			if ground_pts.size() > 4:
				_ensure_named_marker(g_sources, "IndustrialEntrance", ground_pts[4])
			if ground_pts.size() > 5:
				_ensure_named_marker(g_sources, "MilitaryGate", ground_pts[5])

	# 2. Synchronize AirSpawnSources
	var a_sources: Node3D = root.get_node_or_null("AirSpawnSources") as Node3D
	if is_instance_valid(a_sources):
		var p_pos: Vector3 = target_player.global_position if is_instance_valid(target_player) else Vector3.ZERO
		var air_pts := get_air_entry_positions(p_pos, 45.0, 180.0)
		if not air_pts.is_empty():
			_ensure_named_marker(a_sources, "AirEntry_North", air_pts[0])
			if air_pts.size() > 1:
				_ensure_named_marker(a_sources, "AirEntry_East", air_pts[1])
			if air_pts.size() > 2:
				_ensure_named_marker(a_sources, "AirEntry_South", air_pts[2])
			if air_pts.size() > 3:
				_ensure_named_marker(a_sources, "AirEntry_West", air_pts[3])

	# 3. Synchronize RooftopSpawnSources
	var r_sources: Node3D = root.get_node_or_null("RooftopSpawnSources") as Node3D
	if is_instance_valid(r_sources):
		var p_pos: Vector3 = target_player.global_position if is_instance_valid(target_player) else Vector3.ZERO
		var roof_pts := get_rooftop_spawn_points(p_pos, 20.0, 180.0)
		if not roof_pts.is_empty():
			_ensure_named_marker(r_sources, "CommunicationsTower", roof_pts[0])
			if roof_pts.size() > 1:
				_ensure_named_marker(r_sources, "CivicOffice", roof_pts[1])
			if roof_pts.size() > 2:
				_ensure_named_marker(r_sources, "FreightWarehouse", roof_pts[2])

	# Authored ObjectiveLocations are stable mission anchors. Do not relocate them
	# during chunk streaming; moving them can put Radar/LZ targets on rooftops.

	# 4. Synchronize PickupLocations
	var p_sources: Node3D = root.get_node_or_null("PickupLocations") as Node3D
	if is_instance_valid(p_sources):
		var p_pos: Vector3 = target_player.global_position if is_instance_valid(target_player) else Vector3.ZERO
		var pick_pts := get_pickup_candidates(p_pos, 20.0, 150.0)
		for idx in range(mini(pick_pts.size(), 6)):
			var s_name := "SupplyPoint_%02d" % (idx + 1)
			_ensure_named_marker(p_sources, s_name, pick_pts[idx])

func _ensure_named_marker(parent: Node3D, m_name: String, pos: Vector3) -> Marker3D:
	var m: Marker3D = parent.get_node_or_null(m_name) as Marker3D
	if not m:
		m = Marker3D.new()
		m.name = m_name
		parent.add_child(m)
	m.global_position = pos
	return m
