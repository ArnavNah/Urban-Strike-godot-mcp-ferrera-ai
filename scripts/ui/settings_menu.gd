class_name SettingsMenu
extends PanelContainer

## Reusable, full-featured accessibility, audio, and controls settings menu.
## Works in both MainMenu and in-game PauseMenu with full controller/keyboard focus navigation.

signal closed()

const FONT_RAJ_BOLD = preload("res://assets/ui/fonts/Rajdhani-Bold.ttf")
const FONT_INTER_REG = preload("res://assets/ui/fonts/Inter-Regular.ttf")
const FONT_INTER_SEMI = preload("res://assets/ui/fonts/Inter-SemiBold.ttf")

var _controls: Dictionary = {}
var _focus_widgets: Array[Control] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_load_current_values()
	_setup_focus_loop()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	visible = true
	_load_current_values()
	if not _focus_widgets.is_empty() and is_instance_valid(_focus_widgets[0]):
		if is_inside_tree() and _focus_widgets[0].is_inside_tree():
			_focus_widgets[0].grab_focus()

func close_menu() -> void:
	visible = false
	closed.emit()

func _on_close_pressed() -> void:
	close_menu()

func _build_ui() -> void:
	# Tactical panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.10, 0.98)
	style.border_color = Color(0.28, 0.82, 0.92, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 28.0
	style.content_margin_top = 22.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 22.0
	add_theme_stylebox_override("panel", style)
	theme = preload("res://resources/ui/menu_theme.tres")

	custom_minimum_size = Vector2(600, 540)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	add_child(main_vbox)

	# Title Header
	var title := Label.new()
	title.text = "COMMAND SETTINGS & ACCESSIBILITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_RAJ_BOLD)
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.35, 0.92, 0.98, 1.0)
	main_vbox.add_child(title)

	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# Scroll container for settings sections
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(content_vbox)

	# 1. VISUALS & ACCESSIBILITY
	_build_section_header(content_vbox, "VISUALS & ACCESSIBILITY")
	_add_camera_mode_option(content_vbox, "camera_mode", "Camera View", ["Chase", "Classic"], "chase")
	_add_checkbox(content_vbox, "screen_shake_enabled", "Screen Shake Enabled", true)
	_add_slider(content_vbox, "screen_shake_intensity", "Screen Shake Intensity", 0.0, 2.0, 0.05, 1.0, "%.2fx")
	_add_checkbox(content_vbox, "damage_flash_enabled", "Damage Flash Enabled", true)
	_add_slider(content_vbox, "damage_flash_intensity", "Damage Flash Intensity", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)
	_add_checkbox(content_vbox, "reduced_flashing", "Reduced Flashing Mode (Photosensitivity Safe)", false)
	_add_checkbox(content_vbox, "high_contrast_indicators", "High-Contrast Threat & Target Indicators", false)

	# 2. AUDIO VOLUMES
	_build_section_header(content_vbox, "AUDIO VOLUMES")
	_add_slider(content_vbox, "volume_master", "Master Volume", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)
	_add_slider(content_vbox, "volume_sfx", "Sound Effects (SFX)", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)
	_add_slider(content_vbox, "volume_music", "Music Volume", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)

	# 3. CONTROLS & INPUT
	_build_section_header(content_vbox, "CONTROLS & INPUT")
	_add_slider(content_vbox, "move_deadzone", "Left Stick Move Deadzone", 0.0, 0.40, 0.01, 0.15, "%.2f")
	_add_slider(content_vbox, "aim_deadzone", "Right Stick Aim Deadzone", 0.0, 0.40, 0.01, 0.12, "%.2f")
	_add_slider(content_vbox, "aim_sensitivity", "Right Stick Aim Sensitivity", 0.5, 2.5, 0.05, 1.0, "%.2fx")
	_add_slider(content_vbox, "aim_exponent", "Aim Response Curve (Exponent)", 1.0, 2.5, 0.05, 1.45, "%.2f")
	_add_option_button(content_vbox, "controller_glyph_mode", "Controller Prompt Glyphs", ["Auto-Detect", "Xbox Controller", "PlayStation Controller", "Keyboard & Mouse"], "auto")

	# Close Button
	var bottom_sep := HSeparator.new()
	main_vbox.add_child(bottom_sep)

	var close_btn := Button.new()
	close_btn.text = "RETURN TO COMMAND"
	close_btn.add_theme_font_override("font", FONT_INTER_SEMI)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.custom_minimum_size = Vector2(0, 42)
	close_btn.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_btn)
	_focus_widgets.append(close_btn)

	# Setup linear focus neighbors for seamless controller navigation
	if is_inside_tree():
		_setup_focus_loop()

func _setup_focus_loop() -> void:
	for i in range(_focus_widgets.size()):
		var w := _focus_widgets[i]
		var prev := _focus_widgets[(i - 1 + _focus_widgets.size()) % _focus_widgets.size()]
		var next := _focus_widgets[(i + 1) % _focus_widgets.size()]
		w.focus_neighbor_top = prev.get_path()
		w.focus_neighbor_bottom = next.get_path()

func _build_section_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = "— %s —" % text
	lbl.add_theme_font_override("font", FONT_RAJ_BOLD)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(1.0, 0.78, 0.25, 0.95)
	parent.add_child(lbl)

func _add_checkbox(parent: Control, key: String, label_text: String, default_val: bool) -> void:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.add_theme_font_override("font", FONT_INTER_REG)
	cb.add_theme_font_size_override("font_size", 13)
	cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cb.button_pressed = default_val
	cb.toggled.connect(func(pressed: bool):
		SaveSystem.set_setting(key, pressed)
	)
	parent.add_child(cb)
	_controls[key] = cb
	_focus_widgets.append(cb)

func _add_slider(parent: Control, key: String, label_text: String, min_v: float, max_v: float, step: float, default_v: float, fmt: String, multiplier: float = 1.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", FONT_INTER_REG)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(56, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_override("font", FONT_INTER_SEMI)
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.modulate = Color(0.68, 0.90, 1.0)
	val_lbl.text = fmt % (default_v * multiplier)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = default_v
	slider.custom_minimum_size = Vector2(170, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	slider.value_changed.connect(func(new_val: float):
		SaveSystem.set_setting(key, new_val)
		val_lbl.text = fmt % (new_val * multiplier)
	)

	row.add_child(slider)
	row.add_child(val_lbl)
	_controls[key] = slider
	_controls[key + "_label"] = val_lbl
	_controls[key + "_fmt"] = fmt
	_controls[key + "_mult"] = multiplier
	_focus_widgets.append(slider)

func _add_option_button(parent: Control, key: String, label_text: String, options: Array, _default_opt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", FONT_INTER_REG)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)

	var opt_btn := OptionButton.new()
	opt_btn.custom_minimum_size = Vector2(170, 32)
	opt_btn.add_theme_font_override("font", FONT_INTER_REG)
	opt_btn.add_theme_font_size_override("font_size", 12)
	for i in range(options.size()):
		opt_btn.add_item(str(options[i]), i)

	opt_btn.item_selected.connect(func(idx: int):
		var code: String = "auto"
		match idx:
			0: code = "auto"
			1: code = "xbox"
			2: code = "playstation"
			3: code = "keyboard"
		SaveSystem.set_setting(key, code)
	)

	row.add_child(opt_btn)
	_controls[key] = opt_btn
	_focus_widgets.append(opt_btn)

func _add_camera_mode_option(parent: Control, key: String, label_text: String, options: Array, _default_opt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", FONT_INTER_REG)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)

	var opt_btn := OptionButton.new()
	opt_btn.custom_minimum_size = Vector2(170, 32)
	opt_btn.add_theme_font_override("font", FONT_INTER_REG)
	opt_btn.add_theme_font_size_override("font_size", 12)
	for i in range(options.size()):
		opt_btn.add_item(str(options[i]), i)

	opt_btn.item_selected.connect(func(idx: int):
		var mode_str: String = "chase" if idx == 0 else "classic"
		SaveSystem.set_setting(key, mode_str)
	)

	row.add_child(opt_btn)
	_controls[key] = opt_btn
	_focus_widgets.append(opt_btn)

func _load_current_values() -> void:
	var settings := SaveSystem.get_all_settings()
	for key in settings.keys():
		var val = settings[key]
		if _controls.has(key):
			var widget = _controls[key]
			if widget is CheckBox:
				widget.button_pressed = bool(val)
			elif widget is HSlider:
				widget.value = float(val)
				if _controls.has(key + "_label"):
					var val_lbl: Label = _controls[key + "_label"]
					var fmt: String = str(_controls.get(key + "_fmt", "%.2f"))
					var mult: float = float(_controls.get(key + "_mult", 1.0))
					val_lbl.text = fmt % (float(val) * mult)
			elif widget is OptionButton:
				if key == "camera_mode":
					widget.selected = 0 if str(val).to_lower() == "chase" else 1
				else:
					match str(val):
						"auto": widget.selected = 0
						"xbox": widget.selected = 1
						"playstation": widget.selected = 2
						"keyboard": widget.selected = 3
