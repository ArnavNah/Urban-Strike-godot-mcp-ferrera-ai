class_name DamageNumber
extends Label

var world_position: Vector3 = Vector3.ZERO
var velocity_2d: Vector2 = Vector2.ZERO
var lifetime: float = 0.65
var _age: float = 0.0
var is_active: bool = false
var manager: DamageNumberManager = null
var _tween: Tween = null

func _ready() -> void:
	if not is_active:
		set_process(false)
		visible = false

func reset_state() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

	_age = 0.0
	text = ""
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	z_index = 0
	pivot_offset = Vector2.ZERO
	velocity_2d = Vector2.ZERO
	world_position = Vector3.ZERO
	lifetime = 0.65

	remove_theme_font_size_override("font_size")
	remove_theme_color_override("font_color")

func setup(pos: Vector3, amount: float, is_critical: bool, p_manager: DamageNumberManager = null) -> void:
	reset_state()
	manager = p_manager
	world_position = pos
	text = str(int(amount)) if amount >= 1.0 else "%.1f" % amount

	var rand_angle := randf_range(-PI * 0.75, -PI * 0.25)
	velocity_2d = Vector2(cos(rand_angle), sin(rand_angle)) * randf_range(40.0, 75.0)

	if is_critical or amount >= 30.0:
		add_theme_font_size_override("font_size", 22)
		add_theme_color_override("font_color", Color(1.0, 0.35, 0.1, 1.0))
		pivot_offset = size * 0.5
		scale = Vector2(1.3, 1.3)
		_tween = create_tween()
		if _tween:
			_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	elif amount >= 10.0:
		add_theme_font_size_override("font_size", 18)
		add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		pivot_offset = size * 0.5
		scale = Vector2(1.15, 1.15)
		_tween = create_tween()
		if _tween:
			_tween.tween_property(self, "scale", Vector2.ONE, 0.10).set_ease(Tween.EASE_OUT)
	else:
		add_theme_font_size_override("font_size", 15)
		add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))

	# Initial screen alignment if camera is available
	var cam: Camera3D = null
	if is_instance_valid(manager):
		cam = manager.get_active_camera()
	elif is_inside_tree():
		cam = get_viewport().get_camera_3d()

	if cam and not cam.is_position_behind(world_position):
		var base_screen_pos := cam.unproject_position(world_position)
		position = base_screen_pos - (size * 0.5)
		visible = true
	else:
		visible = false

	is_active = true
	set_process(true)

func _process(delta: float) -> void:
	if not is_active:
		return

	_age += delta
	if _age >= lifetime:
		deactivate()
		return

	var cam: Camera3D = null
	if is_instance_valid(manager):
		cam = manager.get_active_camera()
	elif is_inside_tree():
		cam = get_viewport().get_camera_3d()

	if not cam or cam.is_position_behind(world_position):
		visible = false
		return

	visible = true
	var base_screen_pos := cam.unproject_position(world_position)
	var anim_offset := velocity_2d * _age + Vector2(0.0, -30.0 * _age)
	position = base_screen_pos + anim_offset - (size * 0.5)

	# Fade out near end of life
	var alpha := clampf(1.0 - (_age / lifetime), 0.0, 1.0)
	modulate.a = alpha

func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	visible = false
	set_process(false)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

	if is_instance_valid(manager):
		manager._on_label_deactivated(self)

func _exit_tree() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	is_active = false
