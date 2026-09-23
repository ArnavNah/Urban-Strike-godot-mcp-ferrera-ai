class_name XPGem
extends Area3D

## Reusable survivor-style XP pickup node.
## Uses Area3D detection, rapid direct acceleration, and physical sweep collection.

enum State {
	IDLE,
	MAGNETIZED
}

@export var xp_value: int = 5
@export var initial_magnet_speed: float = 36.0
@export var max_magnet_speed: float = 95.0
@export var magnet_accel: float = 250.0
@export var collection_radius: float = 2.8
@export var collection_radius_xz: float = 3.5
@export var collection_height: float = 4.0

var current_state: State = State.IDLE
var _target_player: Node3D = null
var _current_speed: float = 0.0
var _is_collected: bool = false
var _bob_timer: float = 0.0
var _base_y: float = 0.4
var _collection_tween: Tween

var is_pooled: bool = false
var is_active: bool = true

@onready var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")

# Pre-cached static materials to eliminate runtime StandardMaterial3D allocations and shader compile spikes
static var _mat_emerald: StandardMaterial3D = null
static var _mat_sapphire: StandardMaterial3D = null
static var _mat_topaz: StandardMaterial3D = null

static func _ensure_static_materials() -> void:
	if _mat_emerald == null:
		_mat_emerald = StandardMaterial3D.new()
		_mat_emerald.roughness = 0.12
		_mat_emerald.metallic = 0.35
		_mat_emerald.emission_enabled = true
		var col := Color(0.20, 0.96, 0.65, 1.0)
		_mat_emerald.albedo_color = col
		_mat_emerald.emission = col
		_mat_emerald.emission_energy_multiplier = 2.0

	if _mat_sapphire == null:
		_mat_sapphire = StandardMaterial3D.new()
		_mat_sapphire.roughness = 0.12
		_mat_sapphire.metallic = 0.35
		_mat_sapphire.emission_enabled = true
		var col := Color(0.20, 0.65, 1.0, 1.0)
		_mat_sapphire.albedo_color = col
		_mat_sapphire.emission = col
		_mat_sapphire.emission_energy_multiplier = 2.0

	if _mat_topaz == null:
		_mat_topaz = StandardMaterial3D.new()
		_mat_topaz.roughness = 0.12
		_mat_topaz.metallic = 0.35
		_mat_topaz.emission_enabled = true
		var col := Color(1.0, 0.82, 0.18, 1.0)
		_mat_topaz.albedo_color = col
		_mat_topaz.emission = col
		_mat_topaz.emission_energy_multiplier = 2.0

func _init() -> void:
	add_to_group("xp_gems")
	add_to_group("pickups")

func _ready() -> void:
	add_to_group("xp_gems")
	add_to_group("pickups")
	# Collision Layer 5 (value 16) for pickups
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = is_active
	_base_y = global_position.y
	_bob_timer = randf() * TAU
	_apply_visual_style()

	# Reparent safeguard: ensure pickup does not unload prematurely if placed inside a streaming city chunk
	if not is_pooled:
		_ensure_persistent_parent()

	# Godot enables script callbacks on tree entry after pre-tree deactivate().
	set_physics_process(is_active)
	set_process(false)

func _ensure_persistent_parent() -> void:
	var p := get_parent()
	while p:
		if p.is_in_group("city_chunks") or p.name == "Encounters" or p.name == "encounters_root":
			var root_scene := get_tree().current_scene if get_tree().current_scene else get_tree().root
			reparent.call_deferred(root_scene, true)
			break
		p = p.get_parent()

func activate(pos: Vector3, val: int) -> void:
	if _collection_tween:
		_collection_tween.kill()
		_collection_tween = null
	is_active = true
	_is_collected = false
	xp_value = val
	global_position = pos
	_base_y = pos.y
	_bob_timer = randf() * TAU
	_current_speed = 0.0
	_target_player = null
	current_state = State.IDLE
	scale = Vector3.ONE
	if mesh:
		mesh.scale = Vector3.ONE
		mesh.rotation = Vector3.ZERO
	_apply_visual_style()
	visible = true
	set_physics_process(true)
	monitoring = false
	monitorable = true

func deactivate() -> void:
	if _collection_tween:
		_collection_tween.kill()
		_collection_tween = null
	is_active = false
	_is_collected = true
	visible = false
	set_physics_process(false)
	set_process(false)
	monitorable = false
	monitoring = false
	_target_player = null

func _apply_visual_style() -> void:
	if not mesh:
		return
	_ensure_static_materials()
	if xp_value >= 30:
		mesh.material_override = _mat_topaz
	elif xp_value >= 10:
		mesh.material_override = _mat_sapphire
	else:
		mesh.material_override = _mat_emerald

## Explicit shared collection contract: checks whether player is eligible to collect
func can_collect(player: Node3D) -> bool:
	if _is_collected or not is_active:
		return false
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return false
	if "is_alive" in player and not player.is_alive:
		return false
	var mgr: UpgradeManager = UpgradeManager.instance
	if not mgr and is_inside_tree():
		mgr = get_tree().get_first_node_in_group("upgrade_manager") as UpgradeManager
	return mgr != null and mgr.has_method("add_xp")

## Atomic collection execution
func collect(player: Node3D = null) -> bool:
	if _is_collected or not is_active:
		return false
	var target: Node3D = player if is_instance_valid(player) else _target_player
	if not is_instance_valid(target) and is_inside_tree():
		target = get_tree().get_first_node_in_group("player") as Node3D
	if not can_collect(target):
		return false

	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var mgr: UpgradeManager = UpgradeManager.instance
	if not mgr and is_inside_tree():
		mgr = get_tree().get_first_node_in_group("upgrade_manager") as UpgradeManager
	if mgr and mgr.has_method("add_xp"):
		mgr.add_xp(xp_value)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("xp_collected"):
		eb.emit_signal("xp_collected", xp_value)

	_play_collection_fx()
	return true

## Backward-compatible collection hook
func _collect() -> void:
	collect(_target_player)

## Backward-compatible test and caller hook
func _try_collect(player: PlayerHelicopter) -> bool:
	return collect(player)

func _play_collection_fx() -> void:
	if is_pooled:
		if mesh and is_inside_tree():
			var tw := create_tween()
			_collection_tween = tw
			tw.tween_property(mesh, "scale", Vector3(1.8, 1.8, 1.8), 0.05)
			tw.tween_property(mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.06)
			tw.tween_callback(deactivate)
		else:
			deactivate()
	else:
		if mesh and is_inside_tree():
			var tw := create_tween()
			_collection_tween = tw
			tw.tween_property(mesh, "scale", Vector3(1.8, 1.8, 1.8), 0.05)
			tw.tween_property(mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.06)
			tw.tween_callback(queue_free)
		else:
			queue_free()

func _is_line_of_sight_clear(target_pos: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var space := get_world_3d().direct_space_state
	if not space:
		return true
	var from_pos := global_position + Vector3(0.0, 0.4, 0.0)
	var ray_query := PhysicsRayQueryParameters3D.create(from_pos, target_pos, 1) # Layer 1 = World/Buildings
	ray_query.exclude = [get_rid()]
	var hit := space.intersect_ray(ray_query)
	return hit.is_empty()

## Primary survivor magnet activation
func magnetize_to(player: Node3D) -> void:
	if not is_instance_valid(player) or _is_collected or not is_active:
		return
	if not _is_line_of_sight_clear(player.global_position):
		return
	_target_player = player
	current_state = State.MAGNETIZED
	if _current_speed < initial_magnet_speed:
		_current_speed = initial_magnet_speed

## Backward-compatible alias for unit tests and existing calls
func set_magnet_target(player: Node3D) -> void:
	magnetize_to(player)

func _get_target_pos() -> Vector3:
	if not is_instance_valid(_target_player):
		return global_position
	if _target_player.has_node("StableTrackingPoint"):
		var marker: Node3D = _target_player.get_node("StableTrackingPoint") as Node3D
		if marker:
			return marker.global_position
	return _target_player.global_position + Vector3(0.0, 0.4, 0.0)

func _physics_process(delta: float) -> void:
	if _is_collected or not is_active:
		return

	# Idle state or lost player target
	if current_state == State.IDLE or not is_instance_valid(_target_player) or _target_player.is_queued_for_deletion():
		if current_state == State.MAGNETIZED:
			current_state = State.IDLE
			_target_player = null
			_current_speed = 0.0
			if mesh:
				mesh.scale = Vector3.ONE
				mesh.rotation = Vector3.ZERO
		# Only skip cosmetic bobbing when far from camera; still run gameplay proximity check below
		var cam := get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() else null
		var cam_far := cam and global_position.distance_squared_to(cam.global_position) > 6400.0
		if not cam_far:
			rotate_y(3.0 * delta)
			_bob_timer += delta * 3.5
			position.y = _base_y + sin(_bob_timer) * 0.15

		# Direct 3D proximity check when idle (e.g. low-flying helicopter or gem placed on rooftop at player altitude)
		var active_player: Node3D = _target_player
		if not is_instance_valid(active_player) and is_inside_tree():
			active_player = get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(active_player) and not active_player.is_queued_for_deletion():
			var to_player := active_player.global_position - global_position
			if to_player.length() <= collection_radius:
				collect(active_player)
		return

	# Magnetized state: locks onto player stable tracking point with full relative velocity feed-forward
	var target_pos := _get_target_pos()
	var to_target := target_pos - global_position
	var dist := to_target.length()
	var flat_dist := Vector2(to_target.x, to_target.z).length()

	# Cylinder & distance reach entry check
	if dist <= collection_radius or (flat_dist <= collection_radius_xz and absf(to_target.y) <= collection_height):
		collect(_target_player)
		return

	# Rapid smooth acceleration toward max magnet speed (scales up if player speed exceeds normal bounds)
	var player_vel: Vector3 = _target_player.velocity if ("velocity" in _target_player) else Vector3.ZERO
	var effective_max_speed := maxf(max_magnet_speed, player_vel.length() + 45.0)
	_current_speed = move_toward(_current_speed, effective_max_speed, magnet_accel * delta)
	var dir := to_target / dist if dist > 0.0001 else Vector3.UP

	# Relative continuous sweep: In the moving player's frame of reference,
	# the relative step is dir * (_current_speed * delta).
	# This cancels player forward velocity and prevents altitude/speed skew during high-speed flight.
	var rel_p0 := -to_target
	var rel_step := dir * (_current_speed * delta)
	var rel_p1 := rel_p0 + rel_step

	var seg := rel_step
	var seg_len_sq := seg.length_squared()
	var closest_dist: float = minf(dist, rel_p1.length())
	if seg_len_sq > 0.00001:
		var t := clampf(-rel_p0.dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest_rel := rel_p0 + seg * t
		closest_dist = closest_rel.length()

	if closest_dist <= collection_radius or (Vector2(rel_p1.x, rel_p1.z).length() <= collection_radius_xz and absf(rel_p1.y) <= collection_height):
		collect(_target_player)
		return

	# Step world position with relative approach plus player movement feed-forward
	global_position += rel_step + player_vel * delta
	rotate_y(12.0 * delta)

	# Dynamic flight stretch and orientation along travel vector when magnetized
	if mesh:
		mesh.scale = Vector3(0.85, 0.85, 1.35)
		var to_look := dir.normalized()
		if absf(to_look.y) < 0.92 and to_look.length_squared() > 0.01:
			mesh.look_at(mesh.global_position + to_look, Vector3.UP)

## Aggregates excessive idle XP gems within proximity, conserving total value while capping entities.
static func aggregate_excess_gems(tree: SceneTree, max_count: int = 50) -> int:
	if not tree:
		return 0
	var gems := tree.get_nodes_in_group("xp_gems")
	if gems.size() <= max_count:
		return 0

	var idle_gems: Array[XPGem] = []
	for g in gems:
		var gem := g as XPGem
		if is_instance_valid(gem) and not gem.is_queued_for_deletion() and not gem._is_collected and gem.is_active and gem.current_state == State.IDLE:
			idle_gems.append(gem)

	var active_count: int = 0
	for gem in gems:
		if gem is XPGem and gem.is_active and not gem._is_collected:
			active_count += 1
	var merged_count: int = 0
	var i := 0
	while i < idle_gems.size() - 1 and (active_count - merged_count) > max_count:
		var g1: XPGem = idle_gems[i]
		if not is_instance_valid(g1) or g1._is_collected:
			i += 1
			continue

		var best_dist: float = 30.0 # Proximity merge radius
		var best_idx: int = -1
		for j in range(i + 1, idle_gems.size()):
			var g2: XPGem = idle_gems[j]
			if is_instance_valid(g2) and not g2._is_collected:
				var d: float = g1.global_position.distance_to(g2.global_position)
				if d < best_dist:
					best_dist = d
					best_idx = j

		if best_idx != -1:
			var g2: XPGem = idle_gems[best_idx]
			g1.xp_value += g2.xp_value
			g1.scale = clamp(Vector3.ONE * (1.0 + log(float(g1.xp_value)) * 0.22), Vector3.ONE, Vector3.ONE * 2.2)
			g2._is_collected = true
			if g2.is_pooled:
				g2.deactivate()
			else:
				g2.queue_free()
			merged_count += 1
		i += 1

	return merged_count
