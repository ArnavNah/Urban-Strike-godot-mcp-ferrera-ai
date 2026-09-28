class_name Survivor
extends CharacterBody3D

## Stranded ally / downed pilot awaiting winch extraction.
## Emits a bright green distress flare signal.
## When player helicopter hovers overhead at low altitude, deploys a rescue winch
## and hoists the survivor safely into the helicopter cabin.

enum State {
	WAITING,
	HOISTING,
	RESCUED
}

@export var rescue_distance: float = 12.0
@export var rescue_altitude_max: float = 16.0
@export var hoist_speed: float = 10.0

var current_state: State = State.WAITING
var _hoist_target: Node3D = null
var _winch_cable: MeshInstance3D = null
var _flare_light: OmniLight3D = null
var _visual_mesh: MeshInstance3D = null
var _anim_phase: float = 0.0

func _ready() -> void:
	add_to_group("survivors")
	collision_layer = 16 # Pickup layer
	collision_mask = 1  # Ground collision
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	_setup_visuals()
	_setup_flare_beacon()
	_setup_winch_cable()

func _setup_visuals() -> void:
	_visual_mesh = MeshInstance3D.new()
	_visual_mesh.name = "SurvivorMesh"
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.3
	_visual_mesh.mesh = cap
	_visual_mesh.position = Vector3(0.0, 0.65, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.55, 0.15, 1.0) # High-vis orange flight suit
	mat.roughness = 0.4
	_visual_mesh.material_override = mat
	add_child(_visual_mesh)

	var col := CollisionShape3D.new()
	var col_shape := CapsuleShape3D.new()
	col_shape.radius = 0.4
	col_shape.height = 1.3
	col.shape = col_shape
	col.position = Vector3(0.0, 0.65, 0.0)
	add_child(col)

func _setup_flare_beacon() -> void:
	_flare_light = OmniLight3D.new()
	_flare_light.name = "SignalFlareLight"
	_flare_light.light_color = Color(0.2, 1.0, 0.35, 1.0) # Vivid green distress flare
	_flare_light.light_energy = 2.0
	_flare_light.omni_range = 14.0
	_flare_light.position = Vector3(0.4, 0.2, 0.0)
	add_child(_flare_light)

func _setup_winch_cable() -> void:
	_winch_cable = MeshInstance3D.new()
	_winch_cable.name = "WinchCable"
	_winch_cable.top_level = true
	_winch_cable.visible = false
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 1.0
	var cable_mat := StandardMaterial3D.new()
	cable_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cable_mat.albedo_color = Color(0.85, 0.85, 0.4, 0.95) # High-tensile steel cable
	_winch_cable.mesh = cyl
	_winch_cable.material_override = cable_mat
	add_child(_winch_cable)

func _physics_process(delta: float) -> void:
	_anim_phase += delta * 4.0

	match current_state:
		State.WAITING:
			_process_waiting(delta)
		State.HOISTING:
			_process_hoisting(delta)
		State.RESCUED:
			pass

func _process_waiting(delta: float) -> void:
	if is_instance_valid(_flare_light):
		_flare_light.light_energy = 1.6 + sin(_anim_phase * 2.0) * 0.9

	if not is_on_floor():
		velocity.y -= 18.0 * delta
		move_and_slide()

	var players := get_tree().get_nodes_in_group("player")
	var closest_player: Node3D = null
	var closest_dist := 9999.0

	for p in players:
		var p_node := p as Node3D
		if is_instance_valid(p_node) and p_node.get("is_alive") == true:
			var d := global_position.distance_to(p_node.global_position)
			if d < closest_dist:
				closest_dist = d
				closest_player = p_node

	if not is_instance_valid(closest_player):
		return

	var p_pos := closest_player.global_position
	var horiz_dist := Vector2(global_position.x - p_pos.x, global_position.z - p_pos.z).length()
	var vert_dist := p_pos.y - global_position.y

	if horiz_dist <= rescue_distance and vert_dist >= 0.0 and vert_dist <= rescue_altitude_max:
		if closest_player.has_method("can_rescue_passenger") and closest_player.call("can_rescue_passenger"):
			start_hoist(closest_player)

func start_hoist(player: Node3D) -> void:
	current_state = State.HOISTING
	_hoist_target = player
	collision_mask = 0
	collision_layer = 0
	if is_instance_valid(_winch_cable):
		_winch_cable.visible = true

	var sound_mgr: Node = get_tree().get_first_node_in_group("sound_manager")
	if sound_mgr and sound_mgr.has_method("play_sfx"):
		sound_mgr.call("play_sfx", "alert")

func _process_hoisting(delta: float) -> void:
	if not is_instance_valid(_hoist_target) or not _hoist_target.get("is_alive"):
		current_state = State.WAITING
		collision_mask = 1
		collision_layer = 16
		if is_instance_valid(_winch_cable):
			_winch_cable.visible = false
		return

	var target_pos := _hoist_target.global_position + Vector3(0.0, -1.2, 0.0)
	global_position = global_position.move_toward(target_pos, hoist_speed * delta)

	if is_instance_valid(_winch_cable):
		var heli_belly := _hoist_target.global_position + Vector3(0.0, -0.6, 0.0)
		var cable_mid := (heli_belly + global_position) * 0.5
		var cable_len := heli_belly.distance_to(global_position)
		_winch_cable.global_position = cable_mid
		if cable_len > 0.1:
			_winch_cable.scale = Vector3(1.0, cable_len, 1.0)
			var to_heli := (heli_belly - global_position).normalized()
			var up_vec := Vector3.FORWARD if absf(to_heli.dot(Vector3.UP)) > 0.95 else Vector3.UP
			_winch_cable.look_at(heli_belly, up_vec)
			_winch_cable.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))

	if global_position.distance_to(target_pos) <= 0.6:
		complete_rescue()

func complete_rescue() -> void:
	current_state = State.RESCUED
	if is_instance_valid(_winch_cable):
		_winch_cable.visible = false

	if is_instance_valid(_hoist_target) and _hoist_target.has_method("rescue_passenger"):
		_hoist_target.call("rescue_passenger")

	queue_free()
