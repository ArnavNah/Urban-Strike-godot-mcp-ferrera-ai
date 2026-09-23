class_name SettingsMenu
extends PanelContainer

## Reusable, full-featured accessibility, audio, and controls settings menu.
## Redesigned to match the Heli-Strike tactical military theme (amber accents,
## dark slate plates, chamfered buttons, high-contrast typography, and audio triggers).
## Works in both MainMenu and in-game PauseMenu with full controller/keyboard focus navigation.

signal closed()

const FONT_RAJ_BOLD: FontFile = preload("res://assets/ui/fonts/Rajdhani-Bold.ttf")
const FONT_INTER_REG: FontFile = preload("res://assets/ui/fonts/Inter-Regular.ttf")
const FONT_INTER_SEMI: FontFile = preload("res://assets/ui/fonts/Inter-SemiBold.ttf")

const SOUND_FOCUS: AudioStream = preload("res://assets/audio/sfx/ui/ui_focus.wav")
const SOUND_CONFIRM: AudioStream = preload("res://assets/audio/sfx/ui/ui_confirm.wav")
const SOUND_BACK: AudioStream = preload("res://assets/audio/sfx/ui/ui_back.wav")

const COLOR_ACCENT_AMBER := Color(0.961, 0.725, 0.106, 1.0)
const COLOR_SLATE_BORDER := Color(0.24, 0.32, 0.42, 0.75)
const COLOR_DARK_BG := Color(0.045, 0.065, 0.095, 0.98)

var _controls: Dictionary = {}
var _focus_widgets: Array[Control] = []
var _audio_player: AudioStreamPlayer = null
var _last_focus_sound_ms: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio()
	_build_ui()
	_load_current_values()
	_setup_focus_loop()

func _setup_audio() -> void:
	if not _audio_player:
		_audio_player = AudioStreamPlayer.new()
		_audio_player.name = "SettingsAudioPlayer"
		add_child(_audio_player)

func _play_ui_audio(stream: AudioStream, vol_db: float = -14.0) -> void:
	if _audio_player and stream:
		_audio_player.stream = stream
		_audio_player.volume_db = vol_db
		_audio_player.play()

func _play_focus_sound() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_focus_sound_ms < 60:
		return
	_last_focus_sound_ms = now
	_play_ui_audio(SOUND_FOCUS, -16.0)

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
	_play_ui_audio(SOUND_BACK, -12.0)
	closed.emit()

func _on_close_pressed() -> void:
	close_menu()

func _build_ui() -> void:
	# Tactical panel container
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_DARK_BG
	style.border_color = COLOR_SLATE_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 28.0
	style.content_margin_top = 20.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 20.0
	add_theme_stylebox_override("panel", style)
	theme = preload("res://resources/ui/menu_theme.tres")

	custom_minimum_size = Vector2(680, 560)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)

	# Title Header with tactical framing
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 4)
	main_vbox.add_child(header_box)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 12)
	header_box.add_child(title_row)

	var line_l := ColorRect.new()
	line_l.color = COLOR_ACCENT_AMBER
	line_l.custom_minimum_size = Vector2(24, 2)
	line_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(line_l)

	var title := Label.new()
	title.text = "COMMAND SETTINGS & ACCESSIBILITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_RAJ_BOLD)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title_row.add_child(title)

	var line_r := ColorRect.new()
	line_r.color = COLOR_ACCENT_AMBER
	line_r.custom_minimum_size = Vector2(24, 2)
	line_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(line_r)

	var subtitle := Label.new()
	subtitle.text = "CONFIG // FLIGHT CONTROLS, AUDIO BALANCING & ACCESSIBILITY"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", FONT_INTER_REG)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.modulate = Color(0.55, 0.65, 0.75, 0.85)
	header_box.add_child(subtitle)

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
	_build_section_header(content_vbox, "01. VISUALS & ACCESSIBILITY")
	_add_graphics_preset_option(content_vbox, "graphics_preset", "Graphics Quality", ["Low (Performance)", "Medium (Balanced)", "High (Fidelity)"], "medium")
	_add_camera_mode_option(content_vbox, "camera_mode", "Camera View", ["Chase", "Classic"], "chase")
	_add_damage_numbers_option(content_vbox, "damage_numbers", "Damage Numbers", ["All Numbers", "Important Only", "Off"], "all")
	_add_checkbox(content_vbox, "screen_shake_enabled", "Screen Shake Enabled", true)
	_add_slider(content_vbox, "screen_shake_intensity", "Screen Shake Intensity", 0.0, 2.0, 0.05, 1.0, "%.2fx")
	_add_checkbox(content_vbox, "damage_flash_enabled", "Damage Flash Enabled", true)
	_add_slider(content_vbox, "damage_flash_intensity", "Damage Flash Intensity", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)
	_add_checkbox(content_vbox, "reduced_flashing", "Reduced Flashing Mode (Photosensitivity Safe)", false)
	_add_checkbox(content_vbox, "high_contrast_indicators", "High-Contrast Threat & Target Indicators", false)

	# 2. AUDIO VOLUMES
	_build_section_header(content_vbox, "02. AUDIO VOLUMES")
	_add_slider(content_vbox, "volume_master", "Master Volume", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)
	_add_slider(content_vbox, "volume_sfx", "Sound Effects (SFX)", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)
	_add_slider(content_vbox, "volume_music", "Music Volume", 0.0, 1.0, 0.05, 1.0, "%d%%", 100.0)

	# 3. CONTROLS & INPUT
	_build_section_header(content_vbox, "03. CONTROLS & INPUT")
	_add_slider(content_vbox, "move_deadzone", "Left Stick Move Deadzone", 0.0, 0.40, 0.01, 0.15, "%.2f")
	_add_slider(content_vbox, "aim_deadzone", "Right Stick Aim Deadzone", 0.0, 0.40, 0.01, 0.12, "%.2f")
	_add_slider(content_vbox, "aim_sensitivity", "Right Stick Aim Sensitivity", 0.5, 2.5, 0.05, 1.0, "%.2fx")
	_add_slider(content_vbox, "aim_exponent", "Aim Response Curve (Exponent)", 1.0, 2.5, 0.05, 1.45, "%.2f")
	_add_option_button(content_vbox, "controller_glyph_mode", "Controller Prompt Glyphs", ["Auto-Detect", "Xbox Controller", "PlayStation Controller", "Keyboard & Mouse"], "auto")

	# Close Button - Tactical Chamfered Button
	var bottom_sep := HSeparator.new()
	main_vbox.add_child(bottom_sep)

	var close_btn := TacticalMenuButton.new()
	close_btn.action_title = "RETURN TO COMMAND"
	close_btn.text = "RETURN TO COMMAND"
	close_btn.button_min_size = Vector2(340, 46)
	close_btn.title_font_size = 14
	close_btn.chamfer_size = 10.0
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	close_btn.focus_entered.connect(_play_focus_sound)
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var bar := ColorRect.new()
	bar.color = COLOR_ACCENT_AMBER
	bar.custom_minimum_size = Vector2(4, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT_RAJ_BOLD)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", COLOR_ACCENT_AMBER)
	row.add_child(lbl)

func _add_checkbox(parent: Control, key: String, label_text: String, default_val: bool) -> void:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.add_theme_font_override("font", FONT_INTER_REG)
	cb.add_theme_font_size_override("font_size", 13)
	cb.add_theme_color_override("font_color", Color(0.85, 0.89, 0.94))
	cb.add_theme_color_override("font_hover_color", Color.WHITE)
	cb.add_theme_color_override("font_focus_color", Color.WHITE)
	cb.add_theme_color_override("font_pressed_color", COLOR_ACCENT_AMBER)
	cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cb.button_pressed = default_val

	# Tactical checkbox focus style
	var focus_sb := StyleBoxFlat.new()
	focus_sb.bg_color = Color(0.12, 0.10, 0.04, 0.8)
	focus_sb.border_color = COLOR_ACCENT_AMBER
	focus_sb.border_width_left = 1
	focus_sb.border_width_top = 1
	focus_sb.border_width_right = 1
	focus_sb.border_width_bottom = 1
	focus_sb.set_corner_radius_all(2)
	cb.add_theme_stylebox_override("focus", focus_sb)

	cb.focus_entered.connect(_play_focus_sound)
	cb.toggled.connect(func(pressed: bool):
		_play_ui_audio(SOUND_CONFIRM, -16.0)
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
	lbl.add_theme_color_override("font_color", Color(0.85, 0.89, 0.94))
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(60, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_override("font", FONT_INTER_SEMI)
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.modulate = COLOR_ACCENT_AMBER
	val_lbl.text = fmt % (default_v * multiplier)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = default_v
	slider.custom_minimum_size = Vector2(180, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Tactical slider rail styling
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.08, 0.11, 0.16, 0.9)
	slider_bg.border_color = COLOR_SLATE_BORDER
	slider_bg.border_width_left = 1
	slider_bg.border_width_top = 1
	slider_bg.border_width_right = 1
	slider_bg.border_width_bottom = 1
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	slider_bg.set_corner_radius_all(2)
	slider.add_theme_stylebox_override("slider", slider_bg)

	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = Color(0.70, 0.52, 0.08, 0.85)
	grabber_area.content_margin_top = 4
	grabber_area.content_margin_bottom = 4
	grabber_area.set_corner_radius_all(2)
	slider.add_theme_stylebox_override("grabber_area", grabber_area)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber_area)

	slider.focus_entered.connect(_play_focus_sound)
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
	lbl.add_theme_color_override("font_color", Color(0.85, 0.89, 0.94))
	row.add_child(lbl)

	var opt_btn := OptionButton.new()
	opt_btn.custom_minimum_size = Vector2(180, 34)
	opt_btn.add_theme_font_override("font", FONT_INTER_REG)
	opt_btn.add_theme_font_size_override("font_size", 12)
	for i in range(options.size()):
		opt_btn.add_item(str(options[i]), i)

	opt_btn.focus_entered.connect(_play_focus_sound)
	opt_btn.item_selected.connect(func(idx: int):
		_play_ui_audio(SOUND_CONFIRM, -14.0)
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

func _add_graphics_preset_option(parent: Control, key: String, label_text: String, options: Array, _default_opt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", FONT_INTER_REG)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.89, 0.94))
	row.add_child(lbl)

	var opt_btn := OptionButton.new()
	opt_btn.custom_minimum_size = Vector2(180, 34)
	opt_btn.add_theme_font_override("font", FONT_INTER_REG)
	opt_btn.add_theme_font_size_override("font_size", 12)
	for i in range(options.size()):
		opt_btn.add_item(str(options[i]), i)

	opt_btn.focus_entered.connect(_play_focus_sound)
	opt_btn.item_selected.connect(func(idx: int):
		_play_ui_audio(SOUND_CONFIRM, -14.0)
		var preset_id: String = "medium"
		match idx:
			0: preset_id = "low"
			1: preset_id = "medium"
			2: preset_id = "high"
		SaveSystem.set_setting(key, preset_id)
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
	lbl.add_theme_color_override("font_color", Color(0.85, 0.89, 0.94))
	row.add_child(lbl)

	var opt_btn := OptionButton.new()
	opt_btn.custom_minimum_size = Vector2(180, 34)
	opt_btn.add_theme_font_override("font", FONT_INTER_REG)
	opt_btn.add_theme_font_size_override("font_size", 12)
	for i in range(options.size()):
		opt_btn.add_item(str(options[i]), i)

	opt_btn.focus_entered.connect(_play_focus_sound)
	opt_btn.item_selected.connect(func(idx: int):
		_play_ui_audio(SOUND_CONFIRM, -14.0)
		var mode_str: String = "chase" if idx == 0 else "classic"
		SaveSystem.set_setting(key, mode_str)
	)

	row.add_child(opt_btn)
	_controls[key] = opt_btn
	_focus_widgets.append(opt_btn)

func _add_damage_numbers_option(parent: Control, key: String, label_text: String, options: Array, _default_opt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", FONT_INTER_REG)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.89, 0.94))
	row.add_child(lbl)

	var opt_btn := OptionButton.new()
	opt_btn.custom_minimum_size = Vector2(180, 34)
	opt_btn.add_theme_font_override("font", FONT_INTER_REG)
	opt_btn.add_theme_font_size_override("font_size", 12)
	for i in range(options.size()):
		opt_btn.add_item(str(options[i]), i)

	opt_btn.focus_entered.connect(_play_focus_sound)
	opt_btn.item_selected.connect(func(idx: int):
		_play_ui_audio(SOUND_CONFIRM, -14.0)
		var mode_str: String = "all"
		match idx:
			0: mode_str = "all"
			1: mode_str = "important_only"
			2: mode_str = "off"
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
				if key == "graphics_preset":
					match str(val).to_lower():
						"low": widget.selected = 0
						"high": widget.selected = 2
						_: widget.selected = 1
				elif key == "camera_mode":
					widget.selected = 0 if str(val).to_lower() == "chase" else 1
				elif key == "damage_numbers":
					match str(val).to_lower():
						"important_only": widget.selected = 1
						"off": widget.selected = 2
						_: widget.selected = 0
				else:
					match str(val):
						"auto": widget.selected = 0
						"xbox": widget.selected = 1
						"playstation": widget.selected = 2
						"keyboard": widget.selected = 3
