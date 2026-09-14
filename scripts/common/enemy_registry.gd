class_name EnemyRegistry
extends Node

## Centralized high-performance spatial enemy registry.
## Replaces expensive full scene-tree queries (get_nodes_in_group) with spatial hash grid lookups.
## Tracks active enemies, air threats, and ground targets with O(1) cell insertion and fast radius queries.

static var instance: EnemyRegistry = null

@export var cell_size: float = 32.0

# Active collections
var all_enemies: Array[Node3D] = []
var ground_enemies: Array[Node3D] = []
var air_enemies: Array[Node3D] = []

# Spatial hash grid: Vector2i(cell_x, cell_z) -> Array[Node3D]
var _spatial_grid: Dictionary = {}
var _enemy_cells: Dictionary = {} # Node3D -> Vector2i
var _enemy_air_status: Dictionary = {} # Node3D -> bool

func _enter_tree() -> void:
	instance = self
	add_to_group("enemy_registry")

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	# Scan for any enemies already in the scene tree
	var initial_enemies := get_tree().get_nodes_in_group("enemies")
	for node in initial_enemies:
		var enemy := node as Node3D
		if is_instance_valid(enemy):
			var is_air := bool(enemy.is_in_group("air_enemies"))
			register_enemy(enemy, is_air)

func register_enemy(enemy: Node3D, is_air: bool = false) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	if all_enemies.has(enemy):
		return

	all_enemies.append(enemy)
	_enemy_air_status[enemy] = is_air

	if is_air:
		if not air_enemies.has(enemy):
			air_enemies.append(enemy)
	else:
		if not ground_enemies.has(enemy):
			ground_enemies.append(enemy)

	# Register into spatial grid
	if enemy.is_inside_tree():
		var cell := _pos_to_cell(enemy.global_position)
		_insert_into_cell(enemy, cell)
	else:
		enemy.tree_entered.connect(func() -> void:
			if is_instance_valid(enemy) and enemy.is_inside_tree():
				var cell := _pos_to_cell(enemy.global_position)
				_insert_into_cell(enemy, cell)
		, CONNECT_ONE_SHOT)

func unregister_enemy(enemy: Variant) -> void:
	if enemy == null:
		return

	all_enemies.erase(enemy)
	ground_enemies.erase(enemy)
	air_enemies.erase(enemy)

	_enemy_air_status.erase(enemy)

	var cell_val: Variant = _enemy_cells.get(enemy)
	if cell_val != null:
		var cell: Vector2i = cell_val
		_remove_from_cell(enemy, cell)
		_enemy_cells.erase(enemy)

func update_enemy_position(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	var old_cell_val: Variant = _enemy_cells.get(enemy)
	var new_cell := _pos_to_cell(enemy.global_position)
	if old_cell_val == null:
		_insert_into_cell(enemy, new_cell)
	elif (old_cell_val as Vector2i) != new_cell:
		_remove_from_cell(enemy, old_cell_val as Vector2i)
		_insert_into_cell(enemy, new_cell)

func get_enemies_in_radius(origin: Vector3, radius: float) -> Array[Node3D]:
	var results: Array[Node3D] = []
	var radius_sq := radius * radius

	var min_cell := _pos_to_cell(origin - Vector3(radius, 0.0, radius))
	var max_cell := _pos_to_cell(origin + Vector3(radius, 0.0, radius))

	for cx in range(min_cell.x, max_cell.x + 1):
		for cz in range(min_cell.y, max_cell.y + 1):
			var cell_key := Vector2i(cx, cz)
			var enemies_in_cell: Variant = _spatial_grid.get(cell_key)
			if enemies_in_cell == null:
				continue
			var list: Array = enemies_in_cell as Array
			for e_variant in list:
				if not is_instance_valid(e_variant):
					continue
				var enemy: Node3D = e_variant as Node3D
				if enemy == null or enemy.is_queued_for_deletion():
					continue
				if not enemy.is_inside_tree():
					continue
				if "is_alive" in enemy and not enemy.is_alive:
					continue
				var d_sq := origin.distance_squared_to(enemy.global_position)
				if d_sq <= radius_sq:
					if not results.has(enemy):
						results.append(enemy)

	return results

func get_closest_enemy(origin: Vector3, max_radius: float = 120.0) -> Node3D:
	var nearby := get_enemies_in_radius(origin, max_radius)
	var closest: Node3D = null
	var min_dist_sq := INF
	for enemy in nearby:
		var d_sq := origin.distance_squared_to(enemy.global_position)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			closest = enemy
	return closest

func get_active_count() -> int:
	_clean_dead_references()
	return all_enemies.size()

func get_air_count() -> int:
	_clean_dead_references()
	return air_enemies.size()

func get_ground_count() -> int:
	_clean_dead_references()
	return ground_enemies.size()

func clear() -> void:
	all_enemies.clear()
	ground_enemies.clear()
	air_enemies.clear()
	_spatial_grid.clear()
	_enemy_cells.clear()
	_enemy_air_status.clear()

func _pos_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.z / cell_size)))

func _insert_into_cell(enemy: Node3D, cell: Vector2i) -> void:
	if not _spatial_grid.has(cell):
		_spatial_grid[cell] = []
	var list: Array = _spatial_grid[cell] as Array
	if not list.has(enemy):
		list.append(enemy)
	_enemy_cells[enemy] = cell

func _remove_from_cell(enemy: Variant, cell: Vector2i) -> void:
	if _spatial_grid.has(cell):
		var list: Array = _spatial_grid[cell] as Array
		list.erase(enemy)
		if list.is_empty():
			_spatial_grid.erase(cell)

func _clean_dead_references() -> void:
	var valid_all: Array[Node3D] = []
	for e in all_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			valid_all.append(e)
		else:
			_enemy_air_status.erase(e)
			var cell_val: Variant = _enemy_cells.get(e)
			if cell_val != null:
				_remove_from_cell(e, cell_val as Vector2i)
				_enemy_cells.erase(e)
	all_enemies = valid_all

	var valid_ground: Array[Node3D] = []
	for e in ground_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			valid_ground.append(e)
	ground_enemies = valid_ground

	var valid_air: Array[Node3D] = []
	for e in air_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			valid_air.append(e)
	air_enemies = valid_air

func _physics_process(_delta: float) -> void:
	# Periodic spatial refresh of mobile enemies
	_clean_dead_references()
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			update_enemy_position(enemy)

## Static helper to extract Phase 10A archetype metadata from any enemy node
static func get_enemy_metadata(enemy: Node) -> Dictionary:
	var result := {
		"visual_crowd_weight": 1.0,
		"role": "fodder",
		"threat_cost": 2,
		"attack_token_cost": 1,
		"tier": "ordinary", # "ordinary", "heavy", "elite", "boss", "objective"
		"earliest_permitted_wave": 1,
		"is_air": false,
		"is_special": false
	}
	if not is_instance_valid(enemy):
		return result

	# Check archetype property if present
	if "archetype" in enemy and enemy.archetype != null:
		var arch: Variant = enemy.archetype
		if "visual_crowd_weight" in arch:
			result["visual_crowd_weight"] = float(arch.visual_crowd_weight)
		if "role_identifier" in arch:
			result["role"] = str(arch.role_identifier)
		if "threat_cost" in arch:
			result["threat_cost"] = int(arch.threat_cost)
		if "attack_token_cost" in arch:
			result["attack_token_cost"] = int(arch.attack_token_cost)
		if "enemy_tier" in arch:
			result["tier"] = str(arch.enemy_tier)
		if "earliest_permitted_wave" in arch:
			result["earliest_permitted_wave"] = int(arch.earliest_permitted_wave)
		if arch is AirEnemyArchetype:
			result["is_air"] = true

	# Unit-specific overrides / fallbacks for native/legacy classes
	var s_name := enemy.name.to_lower()
	if enemy is InfantryCluster or s_name.contains("infantry"):
		result["visual_crowd_weight"] = 4.0
		result["role"] = "fodder"
		result["tier"] = "ordinary"
		result["threat_cost"] = 2
		result["earliest_permitted_wave"] = 1
	elif enemy is GroundTurret or s_name.contains("turret"):
		result["visual_crowd_weight"] = 1.0
		result["role"] = "light_shooter"
		result["tier"] = "ordinary"
		result["threat_cost"] = 3
		result["earliest_permitted_wave"] = 1
	elif enemy is SAMSite or s_name.contains("sam"):
		result["visual_crowd_weight"] = 1.0
		result["role"] = "anti_air"
		result["tier"] = "ordinary"
		result["is_special"] = true
		result["threat_cost"] = 8
		result["earliest_permitted_wave"] = 4
	elif enemy is BossArchon or s_name.contains("archon"):
		result["visual_crowd_weight"] = 6.0
		result["role"] = "boss"
		result["tier"] = "boss"
		result["threat_cost"] = 30
		result["earliest_permitted_wave"] = 10
	elif s_name.contains("mortar"):
		result["role"] = "mortar"
		result["is_special"] = true
		result["earliest_permitted_wave"] = 5
	elif s_name.contains("buggy"):
		result["role"] = "light_shooter"
		result["tier"] = "ordinary"
		result["visual_crowd_weight"] = 1.0
		result["earliest_permitted_wave"] = 2
	elif s_name.contains("technical"):
		result["role"] = "light_shooter"
		result["tier"] = "ordinary"
		result["visual_crowd_weight"] = 1.0
		result["earliest_permitted_wave"] = 3
	elif s_name.contains("tank") or s_name.contains("ifv"):
		result["role"] = "armored"
		result["tier"] = "heavy"
		result["visual_crowd_weight"] = 2.0
		result["threat_cost"] = 6
		result["earliest_permitted_wave"] = 3
	elif s_name.contains("apc"):
		result["role"] = "armored"
		result["tier"] = "ordinary"
		result["visual_crowd_weight"] = 2.0
		result["earliest_permitted_wave"] = 3

	if enemy.is_in_group("air_enemies"):
		result["is_air"] = true
		if result["earliest_permitted_wave"] < 6:
			result["earliest_permitted_wave"] = 6
	if enemy.is_in_group("objectives"):
		result["tier"] = "objective"
		result["visual_crowd_weight"] = 0.0

	return result

func get_living_visual_crowd() -> float:
	var total: float = 0.0
	for e in all_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "is_alive" in e and not e.is_alive:
				continue
			var meta := get_enemy_metadata(e)
			total += meta["visual_crowd_weight"]
	return total

func get_living_node_count() -> int:
	var count: int = 0
	for e in all_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "is_alive" in e and not e.is_alive:
				continue
			count += 1
	return count

func get_special_counts() -> Dictionary:
	var counts := {"sam": 0, "mortar": 0, "heavy": 0, "medium_armored": 0, "air": 0, "boss": 0}
	for e in all_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "is_alive" in e and not e.is_alive:
				continue
			var meta := get_enemy_metadata(e)
			if meta["is_air"]:
				counts["air"] += 1
			if meta["role"] == "anti_air" or e is SAMSite or e.is_in_group("sams"):
				counts["sam"] += 1
			if meta["role"] == "mortar" or e.name.to_lower().contains("mortar"):
				counts["mortar"] += 1
			if meta["tier"] == "heavy":
				counts["heavy"] += 1
			if meta["role"] == "armored":
				counts["medium_armored"] += 1
			if meta["tier"] == "boss":
				counts["boss"] += 1
	return counts

func get_role_counts() -> Dictionary:
	var counts: Dictionary = {}
	for e in all_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "is_alive" in e and not e.is_alive:
				continue
			var meta := get_enemy_metadata(e)
			var r: String = meta.get("role", "fodder")
			counts[r] = counts.get(r, 0) + 1
	return counts

func get_tier_counts() -> Dictionary:
	var counts: Dictionary = {}
	for e in all_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "is_alive" in e and not e.is_alive:
				continue
			var meta := get_enemy_metadata(e)
			var t: String = meta.get("tier", "ordinary")
			counts[t] = counts.get(t, 0) + 1
	return counts
