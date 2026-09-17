@tool
class_name TacticalMenuButton
extends Button

## Military tactical button for Heli-Strike main menu.
## Sized 500x72 px, 45-degree chamfer cut at top-left and bottom-right corners (12px).
## - Selected button: dark tactical plate with subtle amber tint, thin #F5B91B border,
##   soft outer glow, white text, small yellow >> icon on right, diagonal accent slashes on left.
## - Unselected normal buttons: dark navy/charcoal with subtle transparency, thin blue-grey border.
## - Unselected primary (PLAY): subtle warm undertone and thin warm border.

signal tactical_hovered()
signal tactical_pressed()

@export var action_title: String = "ACTION":
	set(val):
		action_title = val
		if _title_label:
			_title_label.text = action_title
		queue_redraw()

@export var is_primary: bool = false:
	set(val):
		is_primary = val
		_update_label_colors()
		queue_redraw()

@export var button_min_size: Vector2 = Vector2(500, 72):
	set(val):
		button_min_size = val
		custom_minimum_size = val
		queue_redraw()

@export var title_font_size: int = 22:
	set(val):
		title_font_size = val
		if _title_label:
			_title_label.add_theme_font_size_override("font_size", title_font_size)
		queue_redraw()

@export var chamfer_size: float = 12.0:
	set(val):
		chamfer_size = val
		queue_redraw()

var _title_label: Label = null
var _anim_tween: Tween = null
var _is_focused: bool = false
var _active_ratio: float = 0.0

const FONT_TITLE: FontFile = preload("res://assets/ui/fonts/Rajdhani-Bold.ttf")

# Golden Yellow Accent from spec: #F5B91B
const COLOR_ACCENT_YELLOW := Color(0.961, 0.725, 0.106, 1.0)

# Unselected non-primary button background: dark navy/charcoal with subtle transparency
const COLOR_BG_NORMAL_TOP := Color(0.06, 0.08, 0.12, 0.88)
const COLOR_BG_NORMAL_BOT := Color(0.035, 0.05, 0.08, 0.94)

# Unselected primary button (PLAY) background: dark plate with subtle warm undertone
const COLOR_PRIMARY_NORMAL_TOP := Color(0.10, 0.08, 0.04, 0.90)
const COLOR_PRIMARY_NORMAL_BOT := Color(0.05, 0.04, 0.02, 0.94)

# Selected button background: dark background with subtle amber transparent tint (NOT solid bright orange!)
const COLOR_BG_ACTIVE_TOP := Color(0.16, 0.12, 0.05, 0.92)
const COLOR_BG_ACTIVE_BOT := Color(0.08, 0.06, 0.02, 0.96)

# Borders
const COLOR_BORDER_NORMAL := Color(0.24, 0.32, 0.42, 0.50)         # Thin blue-grey
const COLOR_BORDER_PRIMARY_NORMAL := Color(0.50, 0.38, 0.14, 0.55) # Thin warm border
const COLOR_BORDER_ACTIVE := COLOR_ACCENT_YELLOW                   # Thin #F5B91B

# Accents (selected state)
const COLOR_STRIPES := Color(0.961, 0.725, 0.106, 0.85)
const COLOR_CHEVRON := COLOR_ACCENT_YELLOW

# Text colors
const COLOR_TEXT_NORMAL := Color(0.84, 0.88, 0.92, 0.95)          # Crisp light-grey
const COLOR_TEXT_PRIMARY_NORMAL := Color(0.92, 0.90, 0.85, 1.00)  # Light warm white
const COLOR_TEXT_ACTIVE := Color(1.0, 1.0, 1.0, 1.0)              # Pure white
const COLOR_TEXT_PRESSED := Color(0.70, 0.75, 0.80, 1.0)

const CHAMFER_SIZE: float = 12.0

func _ready() -> void:
	flat = true
	if text != "" and action_title == "ACTION":
		action_title = text
	text = ""
	if custom_minimum_size == Vector2.ZERO or custom_minimum_size == Vector2(500, 72):
		custom_minimum_size = button_min_size
	clip_contents = false
	focus_mode = Control.FOCUS_ALL

	_setup_empty_styleboxes()
	_build_hierarchy()

	resized.connect(_on_resized)
	_on_resized()

	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)

	if has_focus():
		_is_focused = true
		_active_ratio = 1.0
	else:
		_is_focused = false
		_active_ratio = 0.0

	_update_label_colors()
	queue_redraw()

func _on_resized() -> void:
	pivot_offset = size * 0.5

func _setup_empty_styleboxes() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("disabled", empty)

func _build_hierarchy() -> void:
	for c: Node in get_children():
		c.queue_free()

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = action_title
	_title_label.add_theme_font_override("font", FONT_TITLE)
	_title_label.add_theme_font_size_override("font_size", title_font_size)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)
	_update_label_colors()

func configure_button(title: String, _desc: String = "", _btn_icon: Texture2D = null, primary: bool = false, _amber: bool = false) -> void:
	action_title = title
	is_primary = primary
	if _title_label:
		_title_label.text = action_title
	_update_label_colors()
	queue_redraw()

func _on_mouse_entered() -> void:
	if not has_focus():
		grab_focus()

func _on_focus_entered() -> void:
	_is_focused = true
	_update_active_state()
	tactical_hovered.emit()

func _on_focus_exited() -> void:
	_is_focused = false
	_update_active_state()

func _update_active_state() -> void:
	var target_ratio: float = 1.0 if _is_focused else 0.0

	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_method(func(val: float) -> void:
		_active_ratio = val
		_update_label_colors()
		queue_redraw()
	, _active_ratio, target_ratio, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var target_scale: Vector2 = Vector2(1.010, 1.010) if _is_focused else Vector2.ONE
	_anim_tween.tween_property(self, "scale", target_scale, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_label_colors() -> void:
	if not _title_label:
		return

	if is_primary and not _is_focused:
		_title_label.modulate = COLOR_TEXT_PRIMARY_NORMAL.lerp(COLOR_TEXT_ACTIVE, _active_ratio)
	else:
		_title_label.modulate = COLOR_TEXT_NORMAL.lerp(COLOR_TEXT_ACTIVE, _active_ratio)

	if _active_ratio > 0.35:
		_title_label.add_theme_color_override("font_shadow_color", Color(0.96, 0.725, 0.106, 0.40 * _active_ratio))
		_title_label.add_theme_constant_override("shadow_offset_x", 0)
		_title_label.add_theme_constant_override("shadow_offset_y", 1)
	else:
		_title_label.remove_theme_color_override("font_shadow_color")

func _on_button_down() -> void:
	if _title_label:
		_title_label.modulate = COLOR_TEXT_PRESSED
	position.y += 1.0

func _on_button_up() -> void:
	position.y -= 1.0
	_update_label_colors()

func _on_pressed() -> void:
	tactical_pressed.emit()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var c: float = minf(chamfer_size, minf(w, h) * 0.35)

	# 1. Base Chamfer Polygon (top-left 45-deg cut, bottom-right 45-deg cut)
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(c, 0.0),
		Vector2(w, 0.0),
		Vector2(w, h - c),
		Vector2(w - c, h),
		Vector2(0.0, h),
		Vector2(0.0, c)
	])

	# Vertical gradient fill
	var col_top: Color
	var col_bot: Color
	if is_primary:
		col_top = COLOR_PRIMARY_NORMAL_TOP.lerp(COLOR_BG_ACTIVE_TOP, _active_ratio)
		col_bot = COLOR_PRIMARY_NORMAL_BOT.lerp(COLOR_BG_ACTIVE_BOT, _active_ratio)
	else:
		col_top = COLOR_BG_NORMAL_TOP.lerp(COLOR_BG_ACTIVE_TOP, _active_ratio)
		col_bot = COLOR_BG_NORMAL_BOT.lerp(COLOR_BG_ACTIVE_BOT, _active_ratio)

	var colors: PackedColorArray = PackedColorArray([
		col_top, col_top, col_bot, col_bot, col_bot, col_top
	])
	draw_polygon(pts, colors)

	# 2. Outer Soft Glow (when active/selected)
	var border_pts: PackedVector2Array = pts.duplicate()
	border_pts.append(pts[0]) # close loop

	if _active_ratio > 0.001:
		var glow_outer: Color = Color(COLOR_BORDER_ACTIVE.r, COLOR_BORDER_ACTIVE.g, COLOR_BORDER_ACTIVE.b, 0.18 * _active_ratio)
		draw_polyline(border_pts, glow_outer, 6.0, true)
		var glow_mid: Color = Color(COLOR_BORDER_ACTIVE.r, COLOR_BORDER_ACTIVE.g, COLOR_BORDER_ACTIVE.b, 0.40 * _active_ratio)
		draw_polyline(border_pts, glow_mid, 3.0, true)

	# 3. Main Thin Tactical Border (crisp, not thick)
	var default_border: Color = COLOR_BORDER_PRIMARY_NORMAL if is_primary else COLOR_BORDER_NORMAL
	var border_col: Color = default_border.lerp(COLOR_BORDER_ACTIVE, _active_ratio)
	var border_width: float = lerpf(1.2, 1.6, _active_ratio)
	draw_polyline(border_pts, border_col, border_width, true)

	# 4. Diagonal Parallel Slashes in Top-Left Corner (active/selected state)
	if _active_ratio > 0.001 and c >= 8.0:
		var stripe_col: Color = Color(COLOR_STRIPES.r, COLOR_STRIPES.g, COLOR_STRIPES.b, COLOR_STRIPES.a * _active_ratio)
		var s1: float = c * 0.9
		var s2: float = c * 1.4
		draw_line(Vector2(s1, 4.0), Vector2(4.0, s1), stripe_col, 1.6, true)
		draw_line(Vector2(s2, 4.0), Vector2(4.0, s2), stripe_col, 1.6, true)

	# 5. Small Glowing Chevrons ">>" on Right (active/selected state)
	if _active_ratio > 0.001 and w >= 160.0:
		var chev_col: Color = Color(COLOR_CHEVRON.r, COLOR_CHEVRON.g, COLOR_CHEVRON.b, _active_ratio)
		var cx: float = w - maxf(36.0, c + 18.0) + (1.0 - _active_ratio) * -4.0
		var cy: float = h * 0.5
		var chev1: PackedVector2Array = PackedVector2Array([
			Vector2(cx, cy - 6.5),
			Vector2(cx + 5.5, cy),
			Vector2(cx, cy + 6.5)
		])
		var chev2: PackedVector2Array = PackedVector2Array([
			Vector2(cx + 7.5, cy - 6.5),
			Vector2(cx + 13.0, cy),
			Vector2(cx + 7.5, cy + 6.5)
		])
		draw_polyline(chev1, chev_col, 2.0, true)
		draw_polyline(chev2, chev_col, 2.0, true)
