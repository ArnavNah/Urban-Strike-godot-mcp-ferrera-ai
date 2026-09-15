class_name JammerConvoyMission
extends StrikeMission

## Dynamic strike mission: Destroy Jammer Convoy.
## Inbound jammer vehicle + escort formation causes targeting disruption and missile lock delay.
## Destroying the jammer restores electronic systems and awards bonus salvage/requisition.

var jammer_unit: Node3D = null
var escort_units: Array[Node3D] = []

func _init() -> void:
	id = "destroy_jammer"
	title = "DESTROY JAMMER"
	description = "Intercept and destroy the mobile electronic warfare jammer convoy."
	xp_reward = 50
	salvage_reward = 75
	requisition_reward = 1
	target_position = Vector3(0.0, 0.3, -190.0)

func start(director: Node) -> void:
	super.start(director)
	var tree := director.get_tree() if is_instance_valid(director) else null
	if not tree:
		return

	var root := tree.current_scene
	var spawn_pos := Vector3(0.0, 0.3, -70.0)
	var spawner := _get_spawn_director(tree)
	var player := tree.get_first_node_in_group("player") as Node3D
	var player_pos := player.global_position if is_instance_valid(player) else Vector3.ZERO

	# Use the director's validated road entry so the convoy arrives within the
	# active combat ring and respects current spawn separation.
	if spawner:
		var spawn_data := spawner.get_authored_ground_spawn("road_column", player_pos, 45.0)
		if bool(spawn_data.get("success", false)):
			spawn_pos = spawn_data.get("position", spawn_pos)
	elif root:
		var entrance := root.get_node_or_null("GroundSpawnSources/RoadEntrance_North") as Marker3D
		if entrance:
			spawn_pos = entrance.global_position

	target_position = spawn_pos
	var parent: Node = _get_enemy_parent(tree)

	# Spawn Jammer Vehicle
	var jammer_scene: PackedScene = load("res://scenes/enemies/ground_jammer_vehicle.tscn")
	if not jammer_scene:
		jammer_scene = load("res://scenes/enemies/air_jammer_helicopter.tscn")

	if jammer_scene:
		var j := jammer_scene.instantiate() as Node3D
		if j:
			j.transform.origin = spawn_pos
			j.add_to_group("jammers")
			j.add_to_group("mission_jammers")
			j.add_to_group("objectives")
			j.add_to_group("enemies")
			parent.add_child(j)
			_register_mission_enemy(tree, j)
			jammer_unit = j
			target_node = j
			target_position = j.global_position

	# Spawn 2 Escorts
	var escort_scene: PackedScene = load("res://scenes/enemies/ground_scout_buggy.tscn")
	if escort_scene:
		var escort_positions: Array[Vector3] = []
		for offset_x in [-14.0, 14.0]:
			var escort_pos := spawn_pos + Vector3(offset_x, 0.0, 10.0)
			if spawner:
				escort_pos = spawner.get_clamped_formation_member_position(
					escort_pos, escort_positions, 10.0, (player_pos - spawn_pos).normalized(), false
				)
				if not spawner.is_spawn_position_clear(escort_pos, false, 10.0):
					var fallback := spawner.get_mission_spawn_position(false, 45.0, 75.0)
					if bool(fallback.get("success", false)):
						escort_pos = fallback.get("position", escort_pos)
			var escort := escort_scene.instantiate() as Node3D
			if escort:
				escort.transform.origin = escort_pos
				escort.add_to_group("enemies")
				parent.add_child(escort)
				_register_mission_enemy(tree, escort)
				escort_units.append(escort)
				escort_positions.append(escort_pos)

	# Trigger immediate jammer state update
	var eb: Node = EventBus if is_instance_valid(EventBus) else (tree.root.get_node_or_null("EventBus") if tree else null)
	if eb and eb.has_signal("jammer_status_changed"):
		eb.emit_signal("jammer_status_changed", true, 1)

func update(delta: float, player: Node3D) -> Dictionary:
	if not is_instance_valid(jammer_unit) or jammer_unit.is_queued_for_deletion():
		is_completed = true
	elif "is_alive" in jammer_unit and not jammer_unit.is_alive:
		is_completed = true

	var res := super.update(delta, player)
	return res

func check_completion() -> bool:
	if not is_instance_valid(jammer_unit) or jammer_unit.is_queued_for_deletion():
		return true
	if "is_alive" in jammer_unit and not jammer_unit.is_alive:
		return true
	return is_completed

func on_success(director: Node) -> void:
	var eb: Node = EventBus if is_instance_valid(EventBus) else (director.get_tree().root.get_node_or_null("EventBus") if is_instance_valid(director) and director.is_inside_tree() else null)
	if eb and eb.has_signal("jammer_status_changed"):
		var remaining_jammers: Array = director.get_tree().get_nodes_in_group("jammers") if is_instance_valid(director) and director.is_inside_tree() else []
		var active_count: int = 0
		for j in remaining_jammers:
			if is_instance_valid(j) and j != jammer_unit and not j.is_queued_for_deletion():
				active_count += 1
		eb.emit_signal("jammer_status_changed", active_count > 0, active_count)
	super.on_success(director)

func cleanup() -> void:
	super.cleanup()
	jammer_unit = null
	target_node = null
	escort_units.clear()
