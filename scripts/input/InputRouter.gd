class_name InputRouter
extends Node

signal device_changed(device: StringName)

const DEVICE_GAMEPAD: StringName = &"gamepad"
const DEVICE_KBM: StringName = &"keyboard_mouse"

@export_group("Deadzones")
@export_range(0.0, 0.5, 0.01) var move_deadzone: float = 0.15
@export_range(0.0, 0.5, 0.01) var aim_deadzone: float = 0.12
@export_range(0.5, 1.0, 0.01) var outer_deadzone: float = 0.98

@export_group("Response Curves")
@export_range(1.0, 3.0, 0.05) var move_exponent: float = 1.25
@export_range(1.0, 3.0, 0.05) var aim_exponent: float = 1.45

var last_device: StringName = DEVICE_KBM

func _ready() -> void:
	# Load configured deadzones from SaveSystem
	move_deadzone = float(SaveSystem.get_setting("move_deadzone", 0.15))
	aim_deadzone = float(SaveSystem.get_setting("aim_deadzone", 0.12))

func set_deadzones(move_dz: float, aim_dz: float, save: bool = false) -> void:
	move_deadzone = clampf(move_dz, 0.0, 0.45)
	aim_deadzone = clampf(aim_dz, 0.0, 0.45)
	if save:
		SaveSystem.set_setting("move_deadzone", move_deadzone)
		SaveSystem.set_setting("aim_deadzone", aim_deadzone)


func _input(event: InputEvent) -> void:
	var new_device := last_device

	if event is InputEventJoypadButton:
		new_device = DEVICE_GAMEPAD
	elif event is InputEventJoypadMotion:
		# Ignore microscopic drift when detecting device changes
		if absf(event.axis_value) > 0.25:
			new_device = DEVICE_GAMEPAD
	elif event is InputEventKey:
		if event.pressed:
			new_device = DEVICE_KBM
	elif event is InputEventMouseButton:
		new_device = DEVICE_KBM
	elif event is InputEventMouseMotion:
		if event.relative.length_squared() > 1.0:
			new_device = DEVICE_KBM

	if new_device != last_device:
		last_device = new_device
		device_changed.emit(last_device)


func get_move_input() -> Vector2:
	var raw := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back",
		0.0
	)
	return _radial_curve(raw, move_deadzone, outer_deadzone, move_exponent)


func get_aim_input() -> Vector2:
	var raw := Input.get_vector(
		"aim_left",
		"aim_right",
		"aim_up",
		"aim_down",
		0.0
	)
	return _radial_curve(raw, aim_deadzone, outer_deadzone, aim_exponent)


func is_precision_aiming() -> bool:
	return Input.is_action_pressed("precision_aim")


func is_boosting() -> bool:
	return Input.is_action_pressed("boost")


static func _radial_curve(
	value: Vector2,
	inner: float,
	outer: float,
	exponent: float
) -> Vector2:
	var magnitude: float = value.length()
	if magnitude <= inner:
		return Vector2.ZERO

	var range_size: float = maxf(outer - inner, 0.001)
	var normalized: float = clampf((magnitude - inner) / range_size, 0.0, 1.0)
	normalized = pow(normalized, exponent)
	return value.normalized() * normalized
