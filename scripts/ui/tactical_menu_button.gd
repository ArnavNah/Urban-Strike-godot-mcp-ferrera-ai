@tool
class_name TacticalMenuButton
extends Button

## Clean vintage arcade button for Heli-Strike main menu.
## 320x54, dark navy/charcoal fill, subtle 1px border, warm amber focus/hover,
## 0.12s +4px rightward slide on focus/hover, centered Rajdhani-Bold text,
## no icons, no nested tactical decorations.

signal tactical_hovered()
signal tactical_pressed()

@export var action_title: String = "ACTION":
	set(val):
		action_title = val
		if _title_label:
			_title_label.text = action_title
		text = ""

var _title_label: Label = null
var _anim_tween: Tween = null
var _press_tween: Tween = null
var _is_hovered: bool = false
var _is_focused: bool = false
var _base_pos_x: float = 0.0
var _base_pos_recorded: bool = false

const FONT_TITLE = preload("res://assets/ui/fonts/Rajdhani-Bold.ttf")

const COLOR_TEXT_NORMAL := Color(0.88, 0.91, 0.95, 1.0)
const COLOR_TEXT_ACTIVE := Color(1.0, 0.96, 0.86, 1.0)
const COLOR_TEXT_PRESSED := Color(0.75, 0.80, 0.86, 1.0)

func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(320, 54)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clip_contents = false
	alignment = HORIZONTAL_ALIGNMENT_CENTER

	_setup_styles()
	_build_hierarchy()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)

func _setup_styles() -> void:
	# 1. Normal: dark navy/charcoal, subtle 1px border
	var style_normal := StyleBoxFlat.new()
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	style_normal.content_margin_left = 16.0
	style_normal.content_margin_top = 8.0
	style_normal.content_margin_right = 16.0
	style_normal.content_margin_bottom = 8.0
	style_normal.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color(0.20, 0.26, 0.34, 0.60)
	style_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style_normal.shadow_size = 3
	style_normal.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("normal", style_normal)

	# 2. Hover: slightly brighter navy, warm amber 2px border
	var style_hover := StyleBoxFlat.new()
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	style_hover.content_margin_left = 16.0
	style_hover.content_margin_top = 8.0
	style_hover.content_margin_right = 16.0
	style_hover.content_margin_bottom = 8.0
	style_hover.bg_color = Color(0.09, 0.12, 0.18, 0.95)
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = Color(0.96, 0.74, 0.22, 1.0)
	style_hover.shadow_color = Color(0.96, 0.74, 0.22, 0.18)
	style_hover.shadow_size = 6
	style_hover.shadow_offset = Vector2(0, 1)
	add_theme_stylebox_override("hover", style_hover)

	# 3. Focus: identical warm amber accent for keyboard / gamepad
	var style_focus := style_hover.duplicate() as StyleBoxFlat
	add_theme_stylebox_override("focus", style_focus)

	# 4. Pressed: slightly compressed dark navy
	var style_pressed := StyleBoxFlat.new()
	style_pressed.corner_radius_top_left = 4
	style_pressed.corner_radius_top_right = 4
	style_pressed.corner_radius_bottom_left = 4
	style_pressed.corner_radius_bottom_right = 4
	style_pressed.content_margin_left = 16.0
	style_pressed.content_margin_top = 9.0
	style_pressed.content_margin_right = 16.0
	style_pressed.content_margin_bottom = 7.0
	style_pressed.bg_color = Color(0.04, 0.05, 0.08, 0.98)
	style_pressed.border_width_left = 2
	style_pressed.border_width_top = 2
	style_pressed.border_width_right = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_color = Color(0.85, 0.62, 0.16, 0.95)
	add_theme_stylebox_override("pressed", style_pressed)

	# 5. Disabled
	var style_disabled := StyleBoxFlat.new()
	style_disabled.corner_radius_top_left = 4
	style_disabled.corner_radius_top_right = 4
	style_disabled.corner_radius_bottom_left = 4
	style_disabled.corner_radius_bottom_right = 4
	style_disabled.bg_color = Color(0.04, 0.05, 0.07, 0.5)
	style_disabled.border_width_left = 1
	style_disabled.border_width_top = 1
	style_disabled.border_width_right = 1
	style_disabled.border_width_bottom = 1
	style_disabled.border_color = Color(0.12, 0.16, 0.22, 0.3)
	add_theme_stylebox_override("disabled", style_disabled)

func _build_hierarchy() -> void:
	for c in get_children():
		c.queue_free()

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = action_title
	_title_label.add_theme_font_override("font", FONT_TITLE)
	_title_label.add_theme_font_size_override("font_size", 21)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.modulate = COLOR_TEXT_NORMAL
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

func configure_button(title: String, _desc: String = "", _btn_icon: Texture2D = null, _primary: bool = false, _amber: bool = false) -> void:
	action_title = title
	if is_node_ready() and _title_label:
		_title_label.text = action_title

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_active_state()
	tactical_hovered.emit()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_active_state()

func _on_focus_entered() -> void:
	_is_focused = true
	_update_active_state()
	tactical_hovered.emit()

func _on_focus_exited() -> void:
	_is_focused = false
	_update_active_state()

func _update_active_state() -> void:
	if not _base_pos_recorded:
		_base_pos_x = position.x
		_base_pos_recorded = true

	var active: bool = _is_hovered or _is_focused

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_tween = create_tween().set_parallel(true)

	# Slide right by 4px on hover/focus over 0.12s
	var target_x: float = _base_pos_x + (4.0 if active else 0.0)
	_anim_tween.tween_property(self, "position:x", target_x, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Title text color
	if _title_label:
		var target_col: Color = COLOR_TEXT_ACTIVE if active else COLOR_TEXT_NORMAL
		_anim_tween.tween_property(_title_label, "modulate", target_col, 0.12)

func _on_button_down() -> void:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "position:y", position.y + 1.0, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _title_label:
		_title_label.modulate = COLOR_TEXT_PRESSED

func _on_button_up() -> void:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "position:y", position.y - 1.0, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _title_label:
		var active: bool = _is_hovered or _is_focused
		_title_label.modulate = COLOR_TEXT_ACTIVE if active else COLOR_TEXT_NORMAL

func _on_pressed() -> void:
	tactical_pressed.emit()
