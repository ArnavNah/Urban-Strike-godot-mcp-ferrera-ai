class_name CameraRig
extends Node3D

## Third-person chase camera rig ported from the TypeScript reference implementation.
## World-space tracking, dynamic distance/height/look-ahead, SpringArm3D obstruction,
## and subtle cinematic banking decoupled from mouse aiming.

@export var tracked_player: PlayerHelicopter = null
@export var target: Node3D = null:
	set(val):
		target = val
		if val is PlayerHelicopter:
			tracked_player = val

@export_category("Camera Composition")
@export var base_distance: float = 31.0
@export var speed_distance_bonus: float = 5.5
@export var base_height: float = 22.0
@export var altitude_height_scale: float = 0.42
@export var speed_height_bonus: float = 2.0
@export var base_lookahead: float = 16.0
@export var speed_lookahead_bonus: float = 8.0
@export var velocity_lookahead_scale: float = 0.25
@export var look_height_scale: float = 0.35
@export var look_height_offset: float = 1.2

@export_category("Camera Response")
@export var horizontal_camera_response: float = 6.5
@export var vertical_camera_response: float = 5.5
@export var look_response: float = 9.0
@export var camera_roll_scale: float = 0.15

var smoothed_camera_position: Vector3 = Vector3.ZERO
var smoothed_look_position: Vector3 = Vector3.ZERO
var _is_initialized: bool = false
var _shake_trauma: float = 0.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera_roll_pivot: Node3D = $SpringArm3D/CameraRollPivot
@onready var camera: Camera3D = $SpringArm3D/CameraRollPivot/Camera3D

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if spring_arm:
		spring_arm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if camera:
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.fov = 50.0

	if not tracked_player:
		tracked_player = get_tree().get_first_node_in_group("player") as PlayerHelicopter

	if EventBus and EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.connect(_on_shake_requested)

	_setup_player_tracking()

func _setup_player_tracking() -> void:
	if not is_instance_valid(tracked_player):
		return

	if spring_arm:
		spring_arm.add_excluded_object(tracked_player.get_rid())
		spring_arm.collision_mask = 1 # Environment / Buildings only

	# Initialize smoothed positions immediately to prevent camera flying in at spawn
	var p_pos := _get_tracking_position()
	var forward := -tracked_player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	smoothed_camera_position = p_pos - forward * base_distance + Vector3.UP * base_height
	smoothed_look_position = p_pos + forward * base_lookahead
	smoothed_look_position.y = p_pos.y * look_height_scale + look_height_offset
	_is_initialized = true

func exp_response(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)

func _get_tracking_position() -> Vector3:
	if not is_instance_valid(tracked_player):
		return global_position
	if tracked_player.has_node("StableTrackingPoint"):
		return tracked_player.get_node("StableTrackingPoint").global_position
	return tracked_player.global_position

func _process(delta: float) -> void:
	if not is_instance_valid(tracked_player):
		tracked_player = get_tree().get_first_node_in_group("player") as PlayerHelicopter
		if is_instance_valid(tracked_player):
			_setup_player_tracking()
		return

	if not _is_initialized:
		_setup_player_tracking()

	var player_position := _get_tracking_position()

	var forward := -tracked_player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var horizontal_velocity := Vector3(
		tracked_player.velocity.x,
		0.0,
		tracked_player.velocity.z
	)

	var horizontal_speed := horizontal_velocity.length()
	var speed_ratio := clampf(horizontal_speed / maxf(tracked_player.max_speed, 1.0), 0.0, 1.2)

	# Dynamic distance and height calculations
	var camera_distance := base_distance + speed_ratio * speed_distance_bonus
	var camera_height := base_height
	camera_height += (player_position.y - 2.4) * altitude_height_scale
	camera_height += speed_ratio * speed_height_bonus

	var lookahead_distance := base_lookahead + speed_ratio * speed_lookahead_bonus

	# Desired positions
	var desired_camera_position := player_position
	desired_camera_position -= forward * camera_distance
	desired_camera_position += Vector3.UP * camera_height

	var desired_look_position := player_position
	desired_look_position += forward * lookahead_distance
	desired_look_position += horizontal_velocity * velocity_lookahead_scale
	desired_look_position.y = player_position.y * look_height_scale + look_height_offset

	# Separate exponential smoothing
	var horizontal_weight := exp_response(horizontal_camera_response, delta)
	var vertical_weight := exp_response(vertical_camera_response, delta)
	var look_weight := exp_response(look_response, delta)

	smoothed_camera_position.x = lerp(smoothed_camera_position.x, desired_camera_position.x, horizontal_weight)
	smoothed_camera_position.z = lerp(smoothed_camera_position.z, desired_camera_position.z, horizontal_weight)
	smoothed_camera_position.y = lerp(smoothed_camera_position.y, desired_camera_position.y, vertical_weight)

	smoothed_look_position = smoothed_look_position.lerp(desired_look_position, look_weight)

	# Orient rig and configure SpringArm3D
	_update_rig_and_spring_arm()
	_update_cinematic_bank(delta)
	_apply_camera_shake(delta)

func _update_rig_and_spring_arm() -> void:
	# Position the rig at the smoothed look target
	global_position = smoothed_look_position

	var to_cam := smoothed_camera_position - smoothed_look_position
	var dist := to_cam.length()

	if dist > 0.01:
		# Orient rig so local +Z points toward smoothed_camera_position
		var z_axis := to_cam.normalized()
		var up_ref := Vector3.UP
		if absf(z_axis.dot(up_ref)) > 0.99:
			up_ref = Vector3.FORWARD
		var x_axis := up_ref.cross(z_axis).normalized()
		var y_axis := z_axis.cross(x_axis).normalized()
		global_transform.basis = Basis(x_axis, y_axis, z_axis)

		if spring_arm:
			spring_arm.transform = Transform3D.IDENTITY
			spring_arm.spring_length = dist

func _update_cinematic_bank(delta: float) -> void:
	if not camera_roll_pivot or not is_instance_valid(tracked_player):
		return
	# Apply subtle cinematic bank (15% of visual roll) with gentle exponential smoothing
	var target_roll: float = tracked_player.visual_roll * camera_roll_scale
	var roll_weight := exp_response(5.0, delta)
	camera_roll_pivot.rotation.z = lerp_angle(camera_roll_pivot.rotation.z, target_roll, roll_weight)

func _on_shake_requested(trauma_amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + trauma_amount, 0.0, 1.0)

func _apply_camera_shake(delta: float) -> void:
	if not camera:
		return
	if _shake_trauma > 0.0:
		var shake_amount := _shake_trauma * _shake_trauma
		var offset_x := (randf() * 2.0 - 1.0) * shake_amount * 0.3
		var offset_y := (randf() * 2.0 - 1.0) * shake_amount * 0.3
		camera.transform.origin = Vector3(offset_x, offset_y, 0.0)
		_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.0)
	else:
		camera.transform.origin = Vector3.ZERO
