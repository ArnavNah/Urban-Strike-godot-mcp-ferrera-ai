class_name HelicopterController
extends CharacterBody3D

@export_group("Horizontal Flight")
@export var max_speed: float = 20.0
@export var acceleration: float = 38.0
@export var braking: float = 48.0
@export var boost_multiplier: float = 1.45

@export_group("Yaw & Facing")
@export var max_yaw_rate_deg: float = 200.0
@export var face_movement_when_idle: bool = true

@export_group("Hover Dynamics")
@export var hover_height: float = 6.5
@export var hover_spring: float = 34.0
@export var hover_damping: float = 10.0
@export var max_vertical_speed: float = 8.0

@export_group("Visual Banking")
@export var max_roll_deg: float = 22.0
@export var max_pitch_deg: float = 12.0
@export var bank_response: float = 8.0

@export_group("Rotor Animation")
@export var main_rotor_rpm: float = 600.0
@export var tail_rotor_rpm: float = 2400.0

@export_group("Node References")
@export var input_router: InputRouter
@export var gameplay_camera: Camera3D
@export var ground_probe: RayCast3D
@export var visual_yaw: Node3D
@export var bank_root: Node3D
@export var main_rotor: Node3D
@export var tail_rotor: Node3D
@export var aim_controller: Node

var _target_heading: Vector3 = Vector3.FORWARD
var _has_custom_heading: bool = false


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_auto_bind_children()


func _auto_bind_children() -> void:
	if input_router == null and has_node("InputRouter"):
		input_router = get_node("InputRouter") as InputRouter

	if ground_probe == null and has_node("GroundProbe"):
		ground_probe = get_node("GroundProbe") as RayCast3D

	if visual_yaw == null and has_node("VisualYaw"):
		visual_yaw = get_node("VisualYaw") as Node3D

	if bank_root == null and visual_yaw != null and visual_yaw.has_node("BankRoot"):
		bank_root = visual_yaw.get_node("BankRoot") as Node3D

	if main_rotor == null and bank_root != null and bank_root.has_node("MainRotor"):
		main_rotor = bank_root.get_node("MainRotor") as Node3D

	if tail_rotor == null and bank_root != null and bank_root.has_node("TailRotor"):
		tail_rotor = bank_root.get_node("TailRotor") as Node3D

	if gameplay_camera == null and has_node("CameraRig/CameraPivot/SpringArm3D/Camera3D"):
		gameplay_camera = get_node("CameraRig/CameraPivot/SpringArm3D/Camera3D") as Camera3D


func _physics_process(delta: float) -> void:
	var move_input := Vector2.ZERO
	if input_router != null:
		move_input = input_router.get_move_input()

	var desired_direction := _camera_relative_direction(move_input)
	var speed: float = max_speed

	if input_router != null and input_router.is_boosting():
		speed *= boost_multiplier

	var desired_velocity: Vector3 = desired_direction * speed

	_update_planar_velocity(desired_velocity, delta)
	_update_hover(delta)
	_update_yaw(desired_direction, delta)

	move_and_slide()

	_update_visual_bank(delta)
	_update_rotors(delta)


func set_visual_heading(world_direction: Vector3, _delta: float) -> void:
	var flat: Vector3 = world_direction
	flat.y = 0.0
	if flat.length_squared() > 0.01:
		_target_heading = flat.normalized()
		_has_custom_heading = true


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if gameplay_camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y).limit_length(1.0)

	var camera_forward: Vector3 = -gameplay_camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()

	var camera_right: Vector3 = gameplay_camera.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()

	# Godot input vector returns negative Y for "forward" (Up).
	var world_direction: Vector3 = (
		camera_right * input_vector.x
		- camera_forward * input_vector.y
	)

	return world_direction.limit_length(1.0)


func _update_planar_velocity(desired_velocity: Vector3, delta: float) -> void:
	var current_planar: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var rate: float = acceleration
	if desired_velocity.length_squared() < 0.01:
		rate = braking

	current_planar = current_planar.move_toward(desired_velocity, rate * delta)
	velocity.x = current_planar.x
	velocity.z = current_planar.z


func _update_hover(delta: float) -> void:
	var desired_y: float = global_position.y

	if ground_probe != null and ground_probe.is_colliding():
		desired_y = ground_probe.get_collision_point().y + hover_height

	var altitude_error: float = desired_y - global_position.y
	var vertical_accel: float = (
		altitude_error * hover_spring
		- velocity.y * hover_damping
	)

	velocity.y += vertical_accel * delta
	velocity.y = clampf(velocity.y, -max_vertical_speed, max_vertical_speed)


func _update_yaw(movement_direction: Vector3, delta: float) -> void:
	if visual_yaw == null:
		return

	var facing: Vector3 = Vector3.ZERO
	if _has_custom_heading:
		facing = _target_heading
	elif face_movement_when_idle and movement_direction.length_squared() > 0.01:
		facing = movement_direction

	if facing.length_squared() < 0.01:
		return

	facing.y = 0.0
	facing = facing.normalized()

	# Godot forward is -Z. Target yaw maps to -facing.x, -facing.z
	var target_yaw: float = atan2(-facing.x, -facing.z)
	var max_step: float = deg_to_rad(max_yaw_rate_deg) * delta

	visual_yaw.rotation.y = rotate_toward(visual_yaw.rotation.y, target_yaw, max_step)
	_has_custom_heading = false


func _update_visual_bank(delta: float) -> void:
	if bank_root == null or visual_yaw == null:
		return

	# Transform world velocity into local coordinates of visual_yaw
	var local_velocity: Vector3 = visual_yaw.global_transform.basis.inverse() * velocity

	var lateral_ratio: float = clampf(local_velocity.x / max_speed, -1.0, 1.0)
	var forward_ratio: float = clampf(-local_velocity.z / max_speed, -1.0, 1.0)

	var target_roll: float = deg_to_rad(-max_roll_deg * lateral_ratio)
	var target_pitch: float = deg_to_rad(max_pitch_deg * forward_ratio)

	var blend: float = 1.0 - exp(-bank_response * delta)

	bank_root.rotation.z = lerp_angle(bank_root.rotation.z, target_roll, blend)
	bank_root.rotation.x = lerp_angle(bank_root.rotation.x, target_pitch, blend)


func _update_rotors(delta: float) -> void:
	if main_rotor != null:
		var main_step: float = deg_to_rad(main_rotor_rpm * 6.0) * delta
		main_rotor.rotate_y(main_step)

	if tail_rotor != null:
		var tail_step: float = deg_to_rad(tail_rotor_rpm * 6.0) * delta
		tail_rotor.rotate_x(tail_step)
