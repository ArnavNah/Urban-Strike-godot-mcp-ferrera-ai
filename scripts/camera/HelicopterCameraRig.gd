class_name HelicopterCameraRig
extends Node3D

@export_group("Follow Target")
@export var target: Node3D
@export var follow_response: float = 9.0

@export_group("Look-Ahead")
@export var movement_look_ahead: float = 3.5
@export var aim_look_ahead: float = 2.0

@export_group("Internal Nodes")
@export var spring_arm: SpringArm3D
@export var camera: Camera3D

var _aim_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	if target == null and get_parent() is Node3D:
		target = get_parent() as Node3D
	if spring_arm == null and has_node("CameraPivot/SpringArm3D"):
		spring_arm = get_node("CameraPivot/SpringArm3D") as SpringArm3D
	if camera == null and has_node("CameraPivot/SpringArm3D/Camera3D"):
		camera = get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D


func set_aim_direction(direction: Vector3) -> void:
	var flat: Vector3 = direction
	flat.y = 0.0
	_aim_direction = flat.normalized() if flat.length_squared() > 0.01 else Vector3.ZERO


func _process(delta: float) -> void:
	if target == null:
		return

	var desired_position: Vector3 = target.global_position

	# Add movement look-ahead if target is a CharacterBody3D with velocity
	if target is CharacterBody3D:
		var body: CharacterBody3D = target as CharacterBody3D
		var planar_vel: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
		if planar_vel.length_squared() > 1.0:
			desired_position += planar_vel.normalized() * movement_look_ahead

	# Add aim look-ahead
	if _aim_direction.length_squared() > 0.01:
		desired_position += _aim_direction * aim_look_ahead

	# Smooth follow using exponential decay
	var weight: float = 1.0 - exp(-follow_response * delta)
	global_position = global_position.lerp(desired_position, weight)
