class_name MainMenu
extends Control

## Cinematic military/urban main menu for Heli-Strike.
## Left-aligned tactical UI with rich typography, chamfered amber glowing buttons,
## sunset skyline with live helicopter showcase on the right, smooth intro sequence,
## and complete keyboard, mouse, and gamepad navigation.

@onready var play_button: Button = find_child("PlayButton", true, false) as Button
@onready var hangar_button: Button = find_child("HangarButton", true, false) as Button
@onready var settings_button: Button = find_child("SettingsButton", true, false) as Button
@onready var quit_button: Button = find_child("QuitButton", true, false) as Button
@onready var prompt_label: Label = find_child("PromptLabel", true, false) as Label
@onready var ui_sound_player: AudioStreamPlayer = find_child("UISoundPlayer", true, false) as AudioStreamPlayer
@onready var menu_column: Control = find_child("MenuColumn", true, false) as Control
@onready var bg_cam: Camera3D = find_child("Camera3D", true, false) as Camera3D
@onready var bg_heli: Node3D = find_child("HeliModel", true, false) as Node3D
@onready var bg_skyline: Node3D = find_child("Skyline", true, false) as Node3D
@onready var subviewport: SubViewport = find_child("SubViewport", true, false) as SubViewport

@onready var bg_rotor: Node3D = null
@onready var bg_tail_rotor: Node3D = null
@onready var bg_nav_tail: MeshInstance3D = null
@onready var bg_nav_port: MeshInstance3D = null
@onready var bg_nav_starboard: MeshInstance3D = null

const SettingsMenuClass = preload("res://scripts/ui/settings_menu.gd")
const SOUND_FOCUS: AudioStream = preload("res://assets/audio/sfx/ui/ui_focus.wav")
const SOUND_CONFIRM: AudioStream = preload("res://assets/audio/sfx/ui/ui_confirm.wav")
const SOUND_BACK: AudioStream = preload("res://assets/audio/sfx/ui/ui_back.wav")

# Helicopter showcase placement: center-right, framed by buildings, 25-30% larger
const HELI_CENTER: Vector3 = Vector3(3.6, 5.0, 14.5)

var _settings_overlay: Control = null
var _settings_menu: Control = null
var _is_transitioning: bool = false
var _anim_time: float = 0.0
var _last_focus_sound_ms: int = 0
var _using_gamepad: bool = false

func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--1080p" in user_args or "--1920x1080" in user_args:
		DisplayServer.window_set_size(Vector2i(1920, 1080))

	_resolve_scene_nodes()
	_disable_menu_background_physics()
	_init_static_camera()
	_connect_buttons()
	_setup_focus_navigation()
	_update_input_hints()

	# Explicit initial focus on PLAY
	if play_button:
		play_button.grab_focus()

	# Start snappy intro animation
	_play_intro_animation()

func _resolve_scene_nodes() -> void:
	if not bg_heli:
		bg_heli = find_child("HeliModel", true, false) as Node3D

	if bg_heli:
		bg_rotor = bg_heli.find_child("Rotor", true, false) as Node3D
		bg_tail_rotor = bg_heli.find_child("TailRotor", true, false) as Node3D
		bg_nav_port = bg_heli.find_child("NavLightPort", true, false) as MeshInstance3D
		bg_nav_starboard = bg_heli.find_child("NavLightStarboard", true, false) as MeshInstance3D
		bg_nav_tail = bg_heli.find_child("NavLightTail", true, false) as MeshInstance3D

func _disable_menu_background_physics() -> void:
	if not bg_skyline:
		return

	var stack: Array[Node] = [bg_skyline]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionShape3D:
			(n as CollisionShape3D).disabled = true

		if n is CollisionObject3D:
			var co: CollisionObject3D = n as CollisionObject3D
			co.collision_layer = 0
			co.collision_mask = 0

		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.material_override and not mi.name.begins_with("NavLight") and mi.name != "GroundPlane":
				mi.material_override = null

		for child: Node in n.get_children():
			stack.append(child)

func _init_static_camera() -> void:
	if bg_cam:
		bg_cam.position = Vector3(-0.8, 6.8, 23.5)
		bg_cam.rotation_degrees = Vector3(-3.0, 10.5, 0.0)

	if bg_heli:
		bg_heli.position = HELI_CENTER
		bg_heli.rotation = Vector3(-deg_to_rad(2.0), deg_to_rad(116.0), -deg_to_rad(1.0))

func _connect_buttons() -> void:
	var buttons: Array[Button] = [play_button, hangar_button, settings_button, quit_button]
	for btn: Button in buttons:
		if not btn:
			continue
		btn.focus_entered.connect(_on_button_focus_entered)
		btn.mouse_entered.connect(_on_button_mouse_entered)

	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if hangar_button:
		hangar_button.pressed.connect(_on_hangar_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _setup_focus_navigation() -> void:
	var buttons: Array[Button] = []
	if play_button:
		buttons.append(play_button)
	if hangar_button:
		buttons.append(hangar_button)
	if settings_button:
		buttons.append(settings_button)
	if quit_button:
		buttons.append(quit_button)

	for i: int in range(buttons.size()):
		var btn: Button = buttons[i]
		var prev_btn: Button = buttons[(i - 1 + buttons.size()) % buttons.size()]
		var next_btn: Button = buttons[(i + 1) % buttons.size()]
		btn.focus_neighbor_top = btn.get_path_to(prev_btn)
		btn.focus_neighbor_bottom = btn.get_path_to(next_btn)

func _play_intro_animation() -> void:
	if not menu_column:
		return

	var title_lbl: Label = menu_column.find_child("Title", true, false) as Label
	var sub_row: Control = menu_column.find_child("SubtitleRow", true, false) as Control
	var deco_top: Control = menu_column.find_child("DecorativeTop", true, false) as Control
	var buttons: Array[Button] = [play_button, hangar_button, settings_button, quit_button]

	if title_lbl:
		title_lbl.modulate.a = 0.0
		title_lbl.position.y += 12.0
	if sub_row:
		sub_row.modulate.a = 0.0
	if deco_top:
		deco_top.modulate.a = 0.0

	for btn: Button in buttons:
		if btn:
			btn.modulate.a = 0.0
			btn.position.x -= 20.0

	var tw: Tween = create_tween().set_parallel(true)

	if title_lbl:
		tw.tween_property(title_lbl, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(title_lbl, "position:y", title_lbl.position.y - 12.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if deco_top:
		tw.tween_property(deco_top, "modulate:a", 1.0, 0.25).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if sub_row:
		tw.tween_property(sub_row, "modulate:a", 1.0, 0.25).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	for i: int in range(buttons.size()):
		var btn: Button = buttons[i]
		if not btn:
			continue
		var delay: float = 0.16 + float(i) * 0.04
		tw.tween_property(btn, "modulate:a", 1.0, 0.24).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "position:x", btn.position.x + 20.0, 0.24).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(func() -> void:
		if play_button and is_instance_valid(play_button):
			play_button.grab_focus()
	)

func _on_button_focus_entered() -> void:
	_play_focus_sound()

func _on_button_mouse_entered() -> void:
	_play_focus_sound()

func _play_focus_sound() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_focus_sound_ms < 65:
		return
	_last_focus_sound_ms = now
	_play_ui_audio(SOUND_FOCUS, -15.0)

func _play_ui_audio(stream: AudioStream, vol_db: float = -14.0) -> void:
	if not ui_sound_player:
		ui_sound_player = AudioStreamPlayer.new()
		ui_sound_player.name = "UISoundPlayer"
		add_child(ui_sound_player)
	ui_sound_player.stream = stream
	ui_sound_player.volume_db = vol_db
	ui_sound_player.play()

func _physics_process(delta: float) -> void:
	_anim_time += delta

	# Rotors spin smoothly
	if bg_rotor:
		bg_rotor.rotate_y(26.0 * delta)
	if bg_tail_rotor:
		bg_tail_rotor.rotate_x(36.0 * delta)

	# Subtle cinematic idle hover
	if bg_heli:
		var bob_y: float = sin(_anim_time * 1.6) * 0.04
		var sway_x: float = sin(_anim_time * 0.7) * 0.06
		var sway_z: float = cos(_anim_time * 0.6) * 0.05
		bg_heli.position = HELI_CENTER + Vector3(sway_x, bob_y, sway_z)

		var pitch: float = -deg_to_rad(2.0) + sin(_anim_time * 0.9) * deg_to_rad(0.3)
		var yaw: float = deg_to_rad(116.0) + sin(_anim_time * 0.5) * deg_to_rad(0.4)
		var roll: float = -deg_to_rad(1.0) + cos(_anim_time * 1.2) * deg_to_rad(0.3)
		bg_heli.rotation = Vector3(pitch, yaw, roll)

	# Subtle slow camera drift
	if bg_cam:
		var cam_drift_x: float = sin(_anim_time * 0.25) * 0.12
		var cam_drift_y: float = cos(_anim_time * 0.20) * 0.06
		bg_cam.position = Vector3(-0.8 + cam_drift_x, 6.8 + cam_drift_y, 23.5)
		bg_cam.rotation_degrees = Vector3(-3.0 + sin(_anim_time * 0.18) * 0.08, 10.5 + cos(_anim_time * 0.22) * 0.10, 0.0)

	# Navigation and beacon lights
	if bg_nav_tail:
		bg_nav_tail.visible = fmod(_anim_time, 1.2) < 0.12
	if bg_nav_port:
		var pulse: float = 0.85 + 0.15 * sin(_anim_time * 3.5)
		bg_nav_port.transparency = 1.0 - pulse
	if bg_nav_starboard:
		var pulse_sb: float = 0.85 + 0.15 * sin(_anim_time * 3.5)
		bg_nav_starboard.transparency = 1.0 - pulse_sb

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not _using_gamepad:
			_using_gamepad = true
			_update_input_hints()
	elif event is InputEventKey or event is InputEventMouseButton:
		if _using_gamepad:
			_using_gamepad = false
			_update_input_hints()

	if _settings_overlay and is_instance_valid(_settings_overlay) and _settings_overlay.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_close_settings_menu()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_backward"):
		_navigate_focus(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_navigate_focus(-1)
		get_viewport().set_input_as_handled()

func _update_input_hints() -> void:
	if not prompt_label:
		return
	if _using_gamepad:
		prompt_label.text = "[A] SELECT  |  [B] BACK"
	else:
		prompt_label.text = "[ENTER] SELECT  |  [ESC] BACK"

func _unhandled_input(_event: InputEvent) -> void:
	pass

func _navigate_focus(dir: int) -> void:
	var buttons: Array[Button] = [play_button, hangar_button, settings_button, quit_button]
	var current_idx: int = -1
	for i: int in range(buttons.size()):
		if buttons[i] and buttons[i].has_focus():
			current_idx = i
			break

	if current_idx == -1:
		if play_button:
			play_button.grab_focus()
	else:
		var next_idx: int = posmod(current_idx + dir, buttons.size())
		if buttons[next_idx]:
			buttons[next_idx].grab_focus()

func _on_play_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_ui_audio(SOUND_CONFIRM, -12.0)

	if play_button:
		play_button.release_focus()

	# Create a full-screen fade curtain so the 3D scene and UI fade to dark together
	var curtain := ColorRect.new()
	curtain.name = "PlayTransitionCurtain"
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.grow_horizontal = Control.GROW_DIRECTION_BOTH
	curtain.grow_vertical = Control.GROW_DIRECTION_BOTH
	curtain.color = Color(0.02, 0.03, 0.06, 1.0)
	curtain.modulate.a = 0.0
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(curtain, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if menu_column:
		tw.tween_property(menu_column, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(menu_column, "position:y", menu_column.position.y + 12.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")
	)

func _on_hangar_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_ui_audio(SOUND_CONFIRM, -12.0)

	if hangar_button:
		hangar_button.release_focus()

	var tw: Tween = create_tween().set_parallel(true)
	if menu_column:
		tw.tween_property(menu_column, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(menu_column, "position:y", menu_column.position.y + 12.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var timer: SceneTreeTimer = get_tree().create_timer(0.20)
	timer.timeout.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/hangar/hangar.tscn")
	)

func _on_settings_pressed() -> void:
	_play_ui_audio(SOUND_CONFIRM, -12.0)
	_open_settings_menu()

func _open_settings_menu() -> void:
	if not _settings_overlay:
		_settings_overlay = ColorRect.new()
		_settings_overlay.name = "SettingsDimBackdrop"
		_settings_overlay.color = Color(0.02, 0.03, 0.05, 0.82)
		_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

		var center := CenterContainer.new()
		center.name = "Center"
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_settings_overlay.add_child(center)

		_settings_menu = SettingsMenuClass.new()
		center.add_child(_settings_menu)

		var canvas_ui: CanvasLayer = find_child("CanvasLayer_UI", true, false) as CanvasLayer
		if canvas_ui:
			canvas_ui.add_child(_settings_overlay)
		else:
			add_child(_settings_overlay)

		_settings_menu.closed.connect(_on_settings_menu_closed)

	_settings_overlay.visible = true
	_settings_overlay.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_settings_overlay, "modulate:a", 1.0, 0.14)
	_settings_menu.call("open_menu")

func _close_settings_menu() -> void:
	if _settings_menu and is_instance_valid(_settings_menu):
		_settings_menu.call("close_menu")

func _on_settings_menu_closed() -> void:
	_play_ui_audio(SOUND_BACK, -13.0)
	if _settings_overlay:
		var tw: Tween = create_tween()
		tw.tween_property(_settings_overlay, "modulate:a", 0.0, 0.12)
		tw.tween_callback(func() -> void:
			_settings_overlay.visible = false
		)
	if settings_button and settings_button.is_inside_tree():
		settings_button.grab_focus()

func _on_quit_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_ui_audio(SOUND_CONFIRM, -12.0)

	var tw: Tween = create_tween()
	if menu_column:
		tw.tween_property(menu_column, "modulate:a", 0.0, 0.15)
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void:
		get_tree().quit()
	)
