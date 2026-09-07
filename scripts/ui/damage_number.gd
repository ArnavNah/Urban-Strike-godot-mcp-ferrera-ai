class_name DamageNumber
extends Label

var world_position: Vector3 = Vector3.ZERO
var velocity_2d: Vector2 = Vector2.ZERO
var lifetime: float = 0.65
var _age: float = 0.0

func setup(pos: Vector3, amount: float, is_critical: bool) -> void:
	world_position = pos
	text = str(int(amount)) if amount >= 1.0 else "%.1f" % amount
	_age = 0.0

	# Drift slightly upward and outward
	var rand_angle := randf_range(-PI * 0.75, -PI * 0.25)
	velocity_2d = Vector2(cos(rand_angle), sin(rand_angle)) * randf_range(40.0, 75.0)

	if is_critical or amount >= 30.0:
		add_theme_font_size_override("font_size", 22)
		add_theme_color_override("font_color", Color(1.0, 0.35, 0.1, 1.0))
	elif amount >= 10.0:
		add_theme_font_size_override("font_size", 18)
		add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	else:
		add_theme_font_size_override("font_size", 15)
		add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))

func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	if cam.is_position_behind(world_position):
		visible = false
		return

	visible = true
	var base_screen_pos := cam.unproject_position(world_position)
	var anim_offset := velocity_2d * _age + Vector2(0, -30.0 * _age)
	position = base_screen_pos + anim_offset - (size * 0.5)

	# Fade out near end of life
	var alpha := clampf(1.0 - (_age / lifetime), 0.0, 1.0)
	modulate.a = alpha
