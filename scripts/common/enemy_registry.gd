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

func unregister_enemy(enemy: Node3D) -> void:
	if not enemy:
		return

	all_enemies.erase(enemy)
	ground_enemies.erase(enemy)
	air_enemies.erase(enemy)

	var is_air_val: Variant = _enemy_air_status.get(enemy)
	if is_air_val != null:
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
				var enemy: Node3D = e_variant as Node3D
				if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
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

func _remove_from_cell(enemy: Node3D, cell: Vector2i) -> void:
	if _spatial_grid.has(cell):
		var list: Array = _spatial_grid[cell] as Array
		list.erase(enemy)
		if list.is_empty():
			_spatial_grid.erase(cell)

func _clean_dead_references() -> void:
	var dead: Array[Node3D] = []
	for e in all_enemies:
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			dead.append(e)
	for d in dead:
		unregister_enemy(d)

func _physics_process(_delta: float) -> void:
	# Periodic spatial refresh of mobile enemies
	_clean_dead_references()
	for enemy in all_enemies:
		if is_instance_valid(enemy) and enemy.is_inside_tree():
			update_enemy_position(enemy)
