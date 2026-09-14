class_name CameraRig
extends Node3D

## Modernized Nuclear Strike-style elevated overhead Chase & Classic camera rig.
## Oblique perspective framing, smooth heading/yaw lag, stable altitude tracking,
## SpringArm3D obstruction safety with responsive clearance recovery, and subtle cinematic banking.

enum CameraMode {
	CHASE,   ## Default: camera yaw smoothly tracks helicopter heading with ~0.25s lag
	CLASSIC  ## Independent world-relative yaw; helicopter rotates beneath view; recenters on demand or sustained flight
}

@export var camera_mode: CameraMode = CameraMode.CHASE
@export var tracked_player: PlayerHelicopter = null
@export var target: Node3D = null:
	set(val):
		target = val
		if val is PlayerHelicopter:
			tracked_player = val

@export_category("Nuclear Strike Composition")
@export_range(40.0, 60.0, 1.0) var camera_fov: float = 50.0 ## Vertical FOV 50 deg
@export var base_distance: float = 31.0 ## Horizontal follow distance behind helicopter
@export var speed_distance_bonus: float = 5.5 ## Pullback distance bonus at max speed
@export var base_height: float = 22.0 ## Base camera elevation above helicopter
@export var altitude_height_scale: float = 0.42 ## Height increase scaling with player altitude
@export var speed_height_bonus: float = 2.0 ## Height bonus at max speed
@export var base_lookahead: float = 16.0 ## Forward look target ahead of helicopter
@export var speed_lookahead_bonus: float = 8.0 ## Lookahead bonus at max speed
@export var velocity_lookahead_scale: float = 0.25 ## Dynamic velocity lead
@export var look_height_scale: float = 0.35 ## Look target vertical scale
@export var look_height_offset: float = 1.2 ## Look target vertical offset above ground/player

@export_category("Camera Response & Smoothing")
@export var yaw_response: float = 4.0 ## Exponential yaw response (~0.25s settling lag)
@export var horizontal_camera_response: float = 6.5 ## Follow position horizontal response
@export var vertical_camera_response: float = 5.5 ## Vertical follow response
@export var look_response: float = 9.0 ## Look-target response
@export var camera_roll_scale: float = 0.15 ## Subtle cinematic roll (<= 15%)
@export var roll_response: float = 5.0
@export var obstruction_collapse_speed: float = 55.0 ## Rapid SpringArm shortening
@export var obstruction_recovery_speed: float = 24.0 ## Responsive SpringArm recovery to prevent lingering

@export_category("Accessibility & Screen Shake")
@export var camera_shake_enabled: bool = true
var screen_shake_intensity: float = 1.0

# Live tracking state
var smoothed_camera_position: Vector3 = Vector3.ZERO
var smoothed_look_position: Vector3 = Vector3.ZERO
var _current_yaw: float = 0.0
var _classic_yaw: float = 0.0
var _sustained_travel_timer: float = 0.0
var _current_spring_length: float = 38.0
var _is_initialized: bool = false
var _shake_trauma: float = 0.0

# Mode transition blending
var _mode_blend_timer: float = 0.0
var _mode_blend_duration: float = 0.4
var _mode_start_yaw: float = 0.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera_roll_pivot: Node3D = $SpringArm3D/CameraRollPivot
@onready var camera: Camera3D = $SpringArm3D/CameraRollPivot/Camera3D

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if spring_arm:
		spring_arm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if camera:
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.fov = camera_fov

	camera_shake_enabled = bool(SaveSystem.get_setting("screen_shake_enabled", true))
	screen_shake_intensity = float(SaveSystem.get_setting("screen_shake_intensity", 1.0))

	var saved_mode := str(SaveSystem.get_setting("camera_mode", "chase")).to_lower()
	camera_mode = CameraMode.CLASSIC if saved_mode == "classic" else CameraMode.CHASE

	if not tracked_player:
		tracked_player = get_tree().get_first_node_in_group("player") as PlayerHelicopter

	if EventBus and EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.connect(_on_shake_requested)
	if EventBus and EventBus.has_signal("setting_changed"):
		EventBus.setting_changed.connect(_on_setting_changed)

	_setup_player_tracking()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle_mode"):
		var next_mode: CameraMode = CameraMode.CLASSIC if camera_mode == CameraMode.CHASE else CameraMode.CHASE
		set_camera_mode(next_mode)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_recenter") and camera_mode == CameraMode.CLASSIC:
		if is_instance_valid(tracked_player):
			var fwd := -tracked_player.global_transform.basis.z
			fwd.y = 0.0
			if fwd.length_squared() > 0.01:
				_classic_yaw = atan2(-fwd.x, -fwd.z)
		get_viewport().set_input_as_handled()

func set_camera_mode(mode: CameraMode, blend_time: float = 0.4) -> void:
	if mode == camera_mode:
		return
	_mode_start_yaw = _current_yaw
	_mode_blend_timer = blend_time
	_mode_blend_duration = maxf(blend_time, 0.01)
	camera_mode = mode

	var mode_str := "chase" if camera_mode == CameraMode.CHASE else "classic"
	if str(SaveSystem.get_setting("camera_mode", "chase")).to_lower() != mode_str:
		SaveSystem.set_setting("camera_mode", mode_str)

func _setup_player_tracking() -> void:
	if not is_instance_valid(tracked_player):
		return

	if spring_arm:
		spring_arm.add_excluded_object(tracked_player.get_rid())
		spring_arm.collision_mask = 1 # Environment / Buildings only

	var p_pos := _get_tracking_position()
	var forward := -tracked_player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.01:
		forward = forward.normalized()
	else:
		forward = Vector3.FORWARD

	_current_yaw = atan2(-forward.x, -forward.z)
	_classic_yaw = _current_yaw
	_mode_start_yaw = _current_yaw

	var camera_forward := Vector3(-sin(_current_yaw), 0.0, -cos(_current_yaw)).normalized()
	var player_altitude := p_pos.y
	var camera_distance := base_distance
	var camera_height := base_height + maxf(0.0, player_altitude - 2.4) * altitude_height_scale

	smoothed_camera_position = p_pos - camera_forward * camera_distance + Vector3.UP * camera_height

	var lookahead_distance := base_lookahead
	smoothed_look_position = p_pos + camera_forward * lookahead_distance
	smoothed_look_position.y = p_pos.y * look_height_scale + look_height_offset

	var to_cam := smoothed_camera_position - smoothed_look_position
	_current_spring_length = to_cam.length()
	global_position = smoothed_look_position
	_update_rig_and_spring_arm(0.016)
	_is_initialized = true

func reset_smoothing() -> void:
	if is_instance_valid(tracked_player):
		tracked_player.force_update_transform()
	_setup_player_tracking()

func exp_response(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)

func _get_tracking_position() -> Vector3:
	if not is_instance_valid(tracked_player):
		return global_position
	if tracked_player.has_node("StableTrackingPoint"):
		return (tracked_player.get_node("StableTrackingPoint") as Node3D).global_position
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
	if forward.length_squared() > 0.01:
		forward = forward.normalized()
	else:
		forward = Vector3.FORWARD

	var heli_yaw: float = atan2(-forward.x, -forward.z)

	var horizontal_velocity := Vector3(
		tracked_player.velocity.x,
		0.0,
		tracked_player.velocity.z
	)
	var horizontal_speed := horizontal_velocity.length()
	var speed_ratio := clampf(horizontal_speed / maxf(tracked_player.max_speed, 1.0), 0.0, 1.2)

	# Determine mode-dependent target yaw
	var target_yaw := heli_yaw
	if camera_mode == CameraMode.CHASE:
		# Blend subtle lateral travel (max 20%), but never let reversing flip the camera
		if horizontal_speed > 1.5:
			var move_dir := horizontal_velocity / horizontal_speed
			var fwd_dot := forward.dot(move_dir)
			if fwd_dot > -0.2:
				var right := Vector3(-forward.z, 0.0, forward.x)
				var lateral_dot := right.dot(move_dir)
				var lateral_bias := clampf(lateral_dot * 0.20, -0.20, 0.20)
				target_yaw = heli_yaw - lateral_bias * (PI / 4.0)
	elif camera_mode == CameraMode.CLASSIC:
		# Helicopter rotates beneath view; yaw stays stable or recenters on sustained movement
		if horizontal_speed > 8.0:
			_sustained_travel_timer += delta
			if _sustained_travel_timer >= 1.0:
				var travel_yaw := atan2(-horizontal_velocity.x, -horizontal_velocity.z)
				_classic_yaw = lerp_angle(_classic_yaw, travel_yaw, exp_response(1.2, delta))
		elif horizontal_speed < 4.0:
			_sustained_travel_timer = maxf(0.0, _sustained_travel_timer - delta * 2.0)
		target_yaw = _classic_yaw

	# Handle smooth mode transition blend
	if _mode_blend_timer > 0.0:
		_mode_blend_timer -= delta
		var t := 1.0 - clampf(_mode_blend_timer / _mode_blend_duration, 0.0, 1.0)
		var smooth_t := smoothstep(0.0, 1.0, t)
		target_yaw = lerp_angle(_mode_start_yaw, target_yaw, smooth_t)

	# 1. Continue calculating the smoothed chase yaw using the current _current_yaw
	_current_yaw = lerp_angle(_current_yaw, target_yaw, exp_response(yaw_response, delta))

	# 2. Generate a horizontal camera-forward direction from _current_yaw
	var camera_forward := Vector3(-sin(_current_yaw), 0.0, -cos(_current_yaw)).normalized()

	# 3. Calculate distance, height, and desired camera position
	var player_altitude := player_position.y
	var camera_distance := base_distance + speed_ratio * speed_distance_bonus
	var camera_height := base_height + maxf(0.0, player_altitude - 2.4) * altitude_height_scale + speed_ratio * speed_height_bonus
	var desired_camera_position := player_position - camera_forward * camera_distance + Vector3.UP * camera_height

	var lookahead_distance := base_lookahead + speed_ratio * speed_lookahead_bonus
	var desired_look_position := player_position + camera_forward * lookahead_distance + horizontal_velocity * velocity_lookahead_scale
	desired_look_position.y = player_position.y * look_height_scale + look_height_offset

	# 4. Smooth camera position and look position independently using exponential response
	var horiz_weight := exp_response(horizontal_camera_response, delta)
	var vert_weight := exp_response(vertical_camera_response, delta)
	var look_weight := exp_response(look_response, delta)

	smoothed_camera_position.x = lerp(smoothed_camera_position.x, desired_camera_position.x, horiz_weight)
	smoothed_camera_position.z = lerp(smoothed_camera_position.z, desired_camera_position.z, horiz_weight)
	smoothed_camera_position.y = lerp(smoothed_camera_position.y, desired_camera_position.y, vert_weight)

	smoothed_look_position = smoothed_look_position.lerp(desired_look_position, look_weight)

	# Update rig orientation and SpringArm3D obstruction
	_update_rig_and_spring_arm(delta)
	_update_cinematic_bank(delta)
	_apply_camera_shake(delta)

func _update_rig_and_spring_arm(delta: float) -> void:
	global_position = smoothed_look_position

	var to_cam := smoothed_camera_position - smoothed_look_position
	var target_dist := to_cam.length()

	if target_dist > 0.01:
		var z_axis := to_cam.normalized()
		var up_ref := Vector3.UP
		if absf(z_axis.dot(up_ref)) > 0.99:
			up_ref = Vector3.FORWARD
		var x_axis := up_ref.cross(z_axis).normalized()
		var y_axis := z_axis.cross(x_axis).normalized()
		global_transform.basis = Basis(x_axis, y_axis, z_axis)

		if spring_arm:
			spring_arm.transform = Transform3D.IDENTITY
			var hit_len: float = spring_arm.get_hit_length()
			if hit_len < _current_spring_length:
				# Obstruction detected: rapid inward collapse
				_current_spring_length = move_toward(_current_spring_length, hit_len, obstruction_collapse_speed * delta)
			else:
				# Clearance restored: responsive recovery back to target_dist
				_current_spring_length = move_toward(_current_spring_length, target_dist, obstruction_recovery_speed * delta)
			spring_arm.spring_length = _current_spring_length

func _update_cinematic_bank(delta: float) -> void:
	if not camera_roll_pivot or not is_instance_valid(tracked_player):
		return
	var target_roll: float = tracked_player.visual_roll * camera_roll_scale
	var roll_weight := exp_response(roll_response, delta)
	camera_roll_pivot.rotation.z = lerp_angle(camera_roll_pivot.rotation.z, target_roll, roll_weight)

func _on_setting_changed(key: String, val: Variant) -> void:
	if key == "screen_shake_enabled":
		camera_shake_enabled = bool(val)
		if not camera_shake_enabled:
			_shake_trauma = 0.0
			if camera:
				camera.transform.origin = Vector3.ZERO
	elif key == "screen_shake_intensity":
		screen_shake_intensity = float(val)
	elif key == "camera_mode":
		var target_mode: CameraMode = CameraMode.CLASSIC if str(val).to_lower() == "classic" else CameraMode.CHASE
		if target_mode != camera_mode:
			set_camera_mode(target_mode)

func _on_shake_requested(trauma_amount: float) -> void:
	if not camera_shake_enabled or screen_shake_intensity <= 0.0:
		_shake_trauma = 0.0
		return
	_shake_trauma = clampf(_shake_trauma + trauma_amount * screen_shake_intensity, 0.0, 1.0)

func _apply_camera_shake(delta: float) -> void:
	if not camera:
		return
	if not camera_shake_enabled or screen_shake_intensity <= 0.0:
		camera.transform.origin = Vector3.ZERO
		_shake_trauma = 0.0
		return
	if _shake_trauma > 0.0:
		var shake_amount := _shake_trauma * _shake_trauma * screen_shake_intensity
		var offset_x := (randf() * 2.0 - 1.0) * shake_amount * 0.3
		var offset_y := (randf() * 2.0 - 1.0) * shake_amount * 0.3
		camera.transform.origin = Vector3(offset_x, offset_y, 0.0)
		_shake_trauma = maxf(0.0, _shake_trauma - delta * 2.5)
	else:
		camera.transform.origin = Vector3.ZERO
