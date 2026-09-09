class_name DestroyRadarMission
extends StrikeMission

## Dynamic strike mission: Destroy Radar Station.
## While radar survives: SAM sites have fast lock time (2.0s) and full range (80m).
## When destroyed: SAM sites degrade to 4.0s lock time and 45m range.

var radar_station: Node3D = null
var _station_rewards_granted: bool = false

func _init() -> void:
	id = "destroy_radar"
	title = "DESTROY RADAR"
	description = "Eliminate hostile radar installation to degrade SAM missile network."
	xp_reward = 60
	salvage_reward = 100
	requisition_reward = 1
	target_position = Vector3(-95.0, 0.5, -37.0)

func start(director: Node) -> void:
	super.start(director)
	var tree := director.get_tree() if is_instance_valid(director) else null
	if not tree:
		return

	# Locate RadarObjective marker if available
	var root := tree.current_scene
	var marker: Marker3D = null
	if root:
		marker = root.get_node_or_null("ObjectiveLocations/RadarObjective") as Marker3D
	if marker:
		target_position = marker.global_position

	# Check for existing active RadarStation
	var existing_radar: Node3D = null
	var candidate_objectives: Array = tree.get_nodes_in_group("objectives")
	for obj in candidate_objectives:
		if is_instance_valid(obj) and obj is RadarStation and not obj.is_queued_for_deletion() and obj.is_active:
			existing_radar = obj as Node3D
			break

	if existing_radar:
		radar_station = existing_radar
		target_node = existing_radar
		target_position = existing_radar.global_position
	else:
		# Spawn fresh RadarStation if none active
		var radar_scene: PackedScene = load("res://scenes/objects/radar_station.tscn")
		if radar_scene:
			var spawned := radar_scene.instantiate() as Node3D
			if spawned:
				spawned.transform.origin = target_position
				var spawn_parent: Node = root if root else tree.root
				spawn_parent.add_child(spawned)
				radar_station = spawned
				target_node = spawned

	# Notify SAM network of active radar lock assistance
	var eb: Node = EventBus if is_instance_valid(EventBus) else (tree.root.get_node_or_null("EventBus") if tree else null)
	if eb and eb.has_signal("radar_status_changed"):
		eb.emit_signal("radar_status_changed", true)

func update(delta: float, player: Node3D) -> Dictionary:
	if not is_instance_valid(radar_station) or radar_station.is_queued_for_deletion():
		is_completed = true
	elif "is_active" in radar_station and not radar_station.is_active:
		_station_rewards_granted = true
		is_completed = true

	var res := super.update(delta, player)
	return res

func check_completion() -> bool:
	if not is_instance_valid(radar_station) or radar_station.is_queued_for_deletion():
		return true
	if "is_active" in radar_station and not radar_station.is_active:
		_station_rewards_granted = true
		return true
	return is_completed

func on_success(director: Node) -> void:
	# Guarantee SAM network receives degraded signal
	var eb: Node = EventBus if is_instance_valid(EventBus) else (director.get_tree().root.get_node_or_null("EventBus") if is_instance_valid(director) and director.is_inside_tree() else null)
	if eb and eb.has_signal("radar_status_changed"):
		eb.emit_signal("radar_status_changed", false)
	# If RadarStation._destroy_radar() already awarded 100 salvage and 1 requisition, avoid double grant
	if _station_rewards_granted:
		salvage_reward = 0
		requisition_reward = 0
	super.on_success(director)

func cleanup() -> void:
	super.cleanup()
	radar_station = null
	target_node = null
