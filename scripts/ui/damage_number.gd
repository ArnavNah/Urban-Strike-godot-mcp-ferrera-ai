class_name DamageNumber
extends Label

enum DamageCategory {
	NORMAL = 0,    # Cream/off-white, 16px, clean number e.g. "12"
	CRITICAL = 1,  # Radiant gold, 22px, strong pop, e.g. "★ 75"
	PLAYER = 2,    # Vivid red, 18px, downward cue, e.g. "▼ -16"
	BLOCKED = 3    # Cool steel cyan, 15px, e.g. "[SHIELD] 0" or "BLOCKED"
}

var world_position: Vector3 = Vector3.ZERO
var velocity_2d: Vector2 = Vector2.ZERO
var lifetime: float = 0.65
var _age: float = 0.0
var is_active: bool = false
var manager: DamageNumberManager = null
var _tween: Tween = null
var category: int = DamageCategory.NORMAL

static func format_damage_value(val: float) -> String:
	if val >= 1_000_000.0:
		return "%.1fM" % (val / 1_000_000.0)
	elif val >= 1_000.0:
		return "%.1fK" % (val / 1_000.0)
	elif val >= 1.0:
		return str(int(roundf(val)))
	elif val > 0.0:
		return "%.1f" % val
	else:
		return "0"

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
	category = DamageCategory.NORMAL

	remove_theme_font_size_override("font_size")
	remove_theme_color_override("font_color")

func setup(pos: Vector3, amount: float, is_critical: bool, p_manager: DamageNumberManager = null, p_category: int = -1, metadata: Dictionary = {}) -> void:
	reset_state()
	manager = p_manager
	world_position = pos

	# Category resolution:
	if amount <= 0.0 or p_category == DamageCategory.BLOCKED or metadata.get("is_blocked", false):
		category = DamageCategory.BLOCKED
	elif p_category == DamageCategory.PLAYER or metadata.get("is_player", false) or metadata.get("target_type", "") == "player":
		category = DamageCategory.PLAYER
	elif is_critical or p_category == DamageCategory.CRITICAL or metadata.get("is_critical", false):
		category = DamageCategory.CRITICAL
	else:
		category = DamageCategory.NORMAL

	var rand_angle := randf_range(-PI * 0.75, -PI * 0.25)
	velocity_2d = Vector2(cos(rand_angle), sin(rand_angle)) * randf_range(40.0, 75.0)

	match category:
		DamageCategory.CRITICAL:
			# Actual critical damage: gold, slightly larger, stronger pop, multi-cue icon
			text = "★ %s" % format_damage_value(amount)
			add_theme_font_size_override("font_size", 22)
			add_theme_color_override("font_color", Color(1.0, 0.82, 0.15, 1.0))
			pivot_offset = size * 0.5
			scale = Vector2(1.4, 1.4)
			_tween = create_tween()
			if _tween:
				_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		DamageCategory.PLAYER:
			# Player damage received: distinct red treatment with downward arrow + negative indicator
			text = "▼ -%s" % format_damage_value(amount)
			add_theme_font_size_override("font_size", 18)
			add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
			pivot_offset = size * 0.5
			scale = Vector2(1.25, 1.25)
			_tween = create_tween()
			if _tween:
				_tween.tween_property(self, "scale", Vector2.ONE, 0.10).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		DamageCategory.BLOCKED:
			# Blocked or zero-damage hits: steel cyan, shield tag
			text = "[SHIELD] 0" if amount <= 0.0 else "[BLOCKED] %s" % format_damage_value(amount)
			add_theme_font_size_override("font_size", 15)
			add_theme_color_override("font_color", Color(0.65, 0.85, 1.0, 0.95))
			pivot_offset = size * 0.5
			scale = Vector2(1.1, 1.1)
			_tween = create_tween()
			if _tween:
				_tween.tween_property(self, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_OUT)
		_: # DamageCategory.NORMAL
			# Normal enemy damage: cream/off-white, standard clean number
			text = format_damage_value(amount)
			add_theme_font_size_override("font_size", 16)
			add_theme_color_override("font_color", Color(0.96, 0.94, 0.88, 1.0))
			pivot_offset = size * 0.5
			scale = Vector2(1.15, 1.15)
			_tween = create_tween()
			if _tween:
				_tween.tween_property(self, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_OUT)

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
