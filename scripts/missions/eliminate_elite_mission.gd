class_name EliminateEliteMission
extends StrikeMission

## Dynamic strike mission: Eliminate Elite.
## High-threat hostile ace gunship enters the combat area.
## Player must locate and neutralize the target before the bounty window expires.

var elite_unit: Node3D = null

func _init() -> void:
	id = "eliminate_elite"
	title = "ELIMINATE ELITE"
	description = "Locate and neutralize the high-threat hostile commander before the bounty window expires."
	xp_reward = 80
	salvage_reward = 120
	requisition_reward = 1
	time_limit = 60.0
	target_position = Vector3(45.0, 18.0, -45.0)

func start(director: Node) -> void:
	super.start(director)
	var tree := director.get_tree() if is_instance_valid(director) else null
	if not tree:
		return

	var root := tree.current_scene
	var spawn_pos := Vector3(45.0, 18.0, -45.0)
	var spawner := _get_spawn_director(tree)

	# Use the same validated offscreen corridor as the continuous air director.
	if spawner:
		var spawn_data := spawner.get_mission_spawn_position(true, 55.0, 85.0)
		if bool(spawn_data.get("success", false)):
			spawn_pos = spawn_data.get("position", spawn_pos)
	elif root:
		var marker := root.get_node_or_null("AirSpawnSources/AirEntry_North") as Marker3D
		if marker:
			spawn_pos = marker.global_position
	spawn_pos.y = maxf(spawn_pos.y, 18.0)

	target_position = spawn_pos
	var parent: Node = _get_enemy_parent(tree)

	# Check for existing ace gunship or spawn one
	var existing_ace: Node3D = null
	var candidate_enemies: Array = tree.get_nodes_in_group("enemies")
	for enemy in candidate_enemies:
		if is_instance_valid(enemy) and enemy is AirEnemyController and not enemy.is_queued_for_deletion():
			if enemy.archetype and enemy.archetype.is_elite:
				existing_ace = enemy
				break

	if existing_ace:
		elite_unit = existing_ace
		target_node = existing_ace
		target_position = existing_ace.global_position
		if not elite_unit.is_in_group("objectives"):
			elite_unit.add_to_group("objectives")
	else:
		var elite_scene: PackedScene = load("res://scenes/enemies/air_ace_gunship.tscn")
		if not elite_scene:
			elite_scene = load("res://scenes/enemies/air_attack_gunship.tscn")

		if elite_scene:
			var spawned := elite_scene.instantiate() as Node3D
			if spawned:
				spawned.transform.origin = spawn_pos
				spawned.add_to_group("enemies")
				spawned.add_to_group("objectives")
				parent.add_child(spawned)
				_register_mission_enemy(tree, spawned)
				elite_unit = spawned
				target_node = spawned
				target_position = spawned.global_position

func update(delta: float, player: Node3D) -> Dictionary:
	if not is_instance_valid(elite_unit) or elite_unit.is_queued_for_deletion():
		is_completed = true
	elif "is_alive" in elite_unit and not elite_unit.is_alive:
		is_completed = true
	elif "current_health" in elite_unit and elite_unit.current_health <= 0.0:
		is_completed = true

	var res := super.update(delta, player)

	# Format bounty window timer countdown
	var remaining_time: float = maxf(0.0, time_limit - elapsed_time)
	var dist_text: String = res.get("detail", "")
	res["detail"] = "%s  [%02d:%02d]" % [dist_text, int(remaining_time / 60.0), int(remaining_time) % 60]
	res["progress"] = clampf(remaining_time / maxf(1.0, time_limit), 0.0, 1.0)
	return res

func check_completion() -> bool:
	if not is_instance_valid(elite_unit) or elite_unit.is_queued_for_deletion():
		return true
	if "is_alive" in elite_unit and not elite_unit.is_alive:
		return true
	if "current_health" in elite_unit and elite_unit.current_health <= 0.0:
		return true
	return is_completed

func on_success(director: Node) -> void:
	super.on_success(director)

func cleanup() -> void:
	super.cleanup()
	elite_unit = null
	target_node = null
