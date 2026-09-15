class_name SecureLZMission
extends StrikeMission

## Dynamic strike mission: Rescue / Secure LZ.
## Player must secure the landing zone by maintaining proximity for 20 seconds while under combat fire.
## Does NOT require landing or zero velocity. Area3D / horizontal proximity within 22m accumulates hold time.
## Causes SpawnDirector to bias enemy pressure toward the LZ district while active.

var required_hold_time: float = 20.0
var current_hold_time: float = 0.0
var zone_radius: float = 22.0
var max_altitude: float = 35.0

var lz_area: Area3D = null
var _owns_lz_area: bool = false
var _player_in_zone: bool = false
var _director_ref: Node = null

func _init() -> void:
	id = "secure_lz"
	title = "SECURE LZ"
	description = "Secure extraction zone by maintaining defensive perimeter for 20 seconds."
	xp_reward = 80
	salvage_reward = 100
	requisition_reward = 1
	target_position = Vector3(-35.0, 0.3, -35.0)

func start(director: Node) -> void:
	super.start(director)
	_director_ref = director
	current_hold_time = 0.0
	_player_in_zone = false
	_owns_lz_area = false

	var tree := director.get_tree() if is_instance_valid(director) else null
	if not tree:
		return

	var root := tree.current_scene
	if root:
		var marker := root.get_node_or_null("ObjectiveLocations/MilitaryObjective") as Marker3D
		if marker:
			target_position = marker.global_position

		# Check for existing LZ Area or create dynamic Area3D
		var existing_area := root.get_node_or_null("LZObjectiveArea") as Area3D
		if existing_area:
			lz_area = existing_area
		else:
			lz_area = Area3D.new()
			lz_area.name = "LZObjectiveArea"
			lz_area.transform.origin = target_position
			lz_area.collision_layer = 0
			lz_area.collision_mask = 2 # Detect player CharacterBody3D

			var col := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = zone_radius
			cyl.height = max_altitude
			col.shape = cyl
			col.transform.origin = Vector3(0.0, max_altitude * 0.5, 0.0)
			lz_area.add_child(col)

			var zone_visual := MeshInstance3D.new()
			zone_visual.name = "SecureLZMarker"
			var disc := CylinderMesh.new()
			disc.top_radius = zone_radius
			disc.bottom_radius = zone_radius
			disc.height = 0.12
			var zone_material := StandardMaterial3D.new()
			zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			zone_material.albedo_color = Color(0.1, 0.95, 0.55, 0.22)
			zone_material.emission_enabled = true
			zone_material.emission = Color(0.05, 0.65, 0.35)
			disc.material = zone_material
			zone_visual.mesh = disc
			zone_visual.position = Vector3(0.0, 0.08, 0.0)
			lz_area.add_child(zone_visual)

			root.add_child(lz_area)
			_owns_lz_area = true

		if lz_area:
			lz_area.body_entered.connect(_on_body_entered)
			lz_area.body_exited.connect(_on_body_exited)
			target_node = lz_area

	# Apply causality: Bias enemy spawn pressure toward the LZ district
	var spawner := _get_active_spawner(tree)
	if spawner and spawner.has_method("set_mission_focus"):
		spawner.set_mission_focus(target_position)

func update(delta: float, player: Node3D) -> Dictionary:
	elapsed_time += delta
	var dist: float = 0.0

	if is_instance_valid(player):
		var p_pos := player.global_position
		dist = Vector2(p_pos.x - target_position.x, p_pos.z - target_position.z).length()
		var relative_altitude := p_pos.y - target_position.y

		# Dual detection: Area3D or radius + altitude check relative to the LZ.
		var in_bounds := _player_in_zone or (dist <= zone_radius and relative_altitude >= 0.0 and relative_altitude <= max_altitude)

		if in_bounds:
			current_hold_time = minf(required_hold_time, current_hold_time + delta)
			if current_hold_time >= required_hold_time:
				is_completed = true

	var detail_text: String
	if current_hold_time > 0.0:
		detail_text = "%d / %d SEC" % [int(current_hold_time), int(required_hold_time)]
	else:
		detail_text = "%dm" % int(dist)

	var prog := clampf(current_hold_time / maxf(1.0, required_hold_time), 0.0, 1.0)

	return {
		"title": title,
		"detail": detail_text,
		"dist": dist,
		"progress": prog
	}

func check_completion() -> bool:
	return current_hold_time >= required_hold_time or is_completed

func on_success(director: Node) -> void:
	_clear_spawn_focus()
	super.on_success(director)

func on_failure(director: Node) -> void:
	_clear_spawn_focus()
	super.on_failure(director)

func cleanup() -> void:
	_clear_spawn_focus()
	if is_instance_valid(lz_area):
		if lz_area.body_entered.is_connected(_on_body_entered):
			lz_area.body_entered.disconnect(_on_body_entered)
		if lz_area.body_exited.is_connected(_on_body_exited):
			lz_area.body_exited.disconnect(_on_body_exited)
		if _owns_lz_area:
			lz_area.queue_free()
	super.cleanup()
	_owns_lz_area = false
	lz_area = null
	target_node = null

func _clear_spawn_focus() -> void:
	if is_instance_valid(_director_ref) and _director_ref.is_inside_tree():
		var spawner := _get_active_spawner(_director_ref.get_tree())
		if spawner and spawner.has_method("clear_mission_focus"):
			spawner.clear_mission_focus()

func _get_active_spawner(tree: SceneTree) -> Node:
	if not tree:
		return null
	var spawners: Array = tree.get_nodes_in_group("spawn_director")
	for i in range(spawners.size() - 1, -1, -1):
		var s: Node = spawners[i] as Node
		if is_instance_valid(s) and not s.is_queued_for_deletion():
			return s
	return null

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_zone = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
