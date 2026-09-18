class_name Hangar
extends Control

## Tactical Military Hangar & Retrofit Terminal for Heli-Strike.
## Left-side upgrade cards and telemetry readouts with amber accents,
## live 3D helicopter showcase on the right, banked salvage badge,
## and complete keyboard, gamepad, and mouse navigation with audio triggers.

@onready var salvage_label: Label = find_child("SalvageLabel", true, false) as Label
@onready var scavenger_btn: Button = find_child("ScavengerButton", true, false) as Button
@onready var armor_btn: Button = find_child("ArmorButton", true, false) as Button
@onready var magnet_btn: Button = find_child("MagnetButton", true, false) as Button
@onready var insurance_btn: Button = find_child("InsuranceButton", true, false) as Button
@onready var deploy_btn: Button = find_child("DeployButton", true, false) as Button
@onready var menu_btn: Button = find_child("MenuButton", true, false) as Button

# Telemetry stat labels (if present in scene)
@onready var stat_hp_label: Label = find_child("StatHPValue", true, false) as Label
@onready var stat_salvage_label: Label = find_child("StatSalvageValue", true, false) as Label
@onready var stat_magnet_label: Label = find_child("StatMagnetValue", true, false) as Label
@onready var stat_insurance_label: Label = find_child("StatInsuranceValue", true, false) as Label
@onready var prompt_label: Label = find_child("PromptLabel", true, false) as Label

# 3D Showcase nodes
@onready var bg_cam: Camera3D = find_child("Camera3D", true, false) as Camera3D
@onready var bg_heli: Node3D = find_child("HeliModel", true, false) as Node3D
@onready var bg_skyline: Node3D = find_child("Skyline", true, false) as Node3D
@onready var bg_rotor: Node3D = null
@onready var bg_tail_rotor: Node3D = null
@onready var bg_nav_tail: MeshInstance3D = null
@onready var bg_nav_port: MeshInstance3D = null
@onready var bg_nav_starboard: MeshInstance3D = null

const SOUND_FOCUS: AudioStream = preload("res://assets/audio/sfx/ui/ui_focus.wav")
const SOUND_CONFIRM: AudioStream = preload("res://assets/audio/sfx/ui/ui_confirm.wav")
const SOUND_BACK: AudioStream = preload("res://assets/audio/sfx/ui/ui_back.wav")

const COLOR_ACCENT_AMBER := Color(0.961, 0.725, 0.106, 1.0)
const HELI_CENTER: Vector3 = Vector3(3.9, 5.2, 14.2)

var _save_data: Dictionary = {}
var _audio_player: AudioStreamPlayer = null
var _last_focus_sound_ms: int = 0
var _anim_time: float = 0.0
var _is_transitioning: bool = false
var _using_gamepad: bool = false

func _ready() -> void:
	_setup_audio()
	_resolve_3d_nodes()
	_disable_menu_background_physics()
	_init_static_camera()
	_save_data = SaveSystem.load_data()
	_connect_signals()
	_update_ui()
	_setup_focus_navigation()
	_update_input_hints()

	# Default focus on Deploy if affordable/ready, or first upgrade
	if deploy_btn:
		deploy_btn.grab_focus()

func _setup_audio() -> void:
	if not _audio_player:
		_audio_player = AudioStreamPlayer.new()
		_audio_player.name = "HangarAudioPlayer"
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

func _resolve_3d_nodes() -> void:
	if not bg_cam:
		bg_cam = find_child("Camera3D", true, false) as Camera3D
	if not bg_skyline:
		bg_skyline = find_child("Skyline", true, false) as Node3D
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

func _connect_signals() -> void:
	if scavenger_btn:
		scavenger_btn.pressed.connect(_buy_scavenger)
		scavenger_btn.focus_entered.connect(_play_focus_sound)
		scavenger_btn.mouse_entered.connect(_play_focus_sound)
	if armor_btn:
		armor_btn.pressed.connect(_buy_armor)
		armor_btn.focus_entered.connect(_play_focus_sound)
		armor_btn.mouse_entered.connect(_play_focus_sound)
	if magnet_btn:
		magnet_btn.pressed.connect(_buy_magnet)
		magnet_btn.focus_entered.connect(_play_focus_sound)
		magnet_btn.mouse_entered.connect(_play_focus_sound)
	if insurance_btn:
		insurance_btn.pressed.connect(_buy_insurance)
		insurance_btn.focus_entered.connect(_play_focus_sound)
		insurance_btn.mouse_entered.connect(_play_focus_sound)

	if deploy_btn:
		deploy_btn.pressed.connect(_on_deploy_pressed)
		deploy_btn.focus_entered.connect(_play_focus_sound)
		deploy_btn.mouse_entered.connect(_play_focus_sound)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
		menu_btn.focus_entered.connect(_play_focus_sound)
		menu_btn.mouse_entered.connect(_play_focus_sound)

func _setup_focus_navigation() -> void:
	var buttons: Array[Button] = [scavenger_btn, armor_btn, magnet_btn, insurance_btn, deploy_btn, menu_btn]
	var active_buttons: Array[Button] = []
	for btn: Button in buttons:
		if btn and is_instance_valid(btn):
			active_buttons.append(btn)

	for i: int in range(active_buttons.size()):
		var btn: Button = active_buttons[i]
		var prev: Button = active_buttons[(i - 1 + active_buttons.size()) % active_buttons.size()]
		var next: Button = active_buttons[(i + 1) % active_buttons.size()]
		btn.focus_neighbor_top = btn.get_path_to(prev)
		btn.focus_neighbor_bottom = btn.get_path_to(next)

func _update_input_hints() -> void:
	if not prompt_label:
		return
	if _using_gamepad:
		prompt_label.text = "[A] PURCHASE / SELECT  |  [B] RETURN"
	else:
		prompt_label.text = "[ENTER / CLICK] SELECT  |  [ESC] MAIN MENU"

func _physics_process(delta: float) -> void:
	_anim_time += delta

	# Rotors spin smoothly in the hangar
	if bg_rotor:
		bg_rotor.rotate_y(26.0 * delta)
	if bg_tail_rotor:
		bg_tail_rotor.rotate_x(36.0 * delta)

	# Subtle tactical idle hover animation with clean clearance
	if bg_heli:
		var bob_y: float = sin(_anim_time * 1.6) * 0.03
		var sway_x: float = sin(_anim_time * 0.7) * 0.04
		var sway_z: float = cos(_anim_time * 0.6) * 0.03
		bg_heli.position = HELI_CENTER + Vector3(sway_x, bob_y, sway_z)

		var pitch: float = -deg_to_rad(2.0) + sin(_anim_time * 0.9) * deg_to_rad(0.3)
		var yaw: float = deg_to_rad(116.0) + sin(_anim_time * 0.5) * deg_to_rad(0.4)
		var roll: float = -deg_to_rad(1.0) + cos(_anim_time * 1.2) * deg_to_rad(0.3)
		bg_heli.rotation = Vector3(pitch, yaw, roll)

	# Subtle slow camera drift
	if bg_cam:
		var cam_drift_x: float = sin(_anim_time * 0.25) * 0.10
		var cam_drift_y: float = cos(_anim_time * 0.35) * 0.06
		bg_cam.position = Vector3(-0.8 + cam_drift_x, 6.8 + cam_drift_y, 23.5)

	# Navigation lights
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

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_menu_pressed()
		get_viewport().set_input_as_handled()

func _update_ui() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})

	if salvage_label:
		salvage_label.text = "BANKED SALVAGE: %d" % salvage

	# 1. Scavenger Rig (Max Rank 4)
	var scav_lvl: int = int(upgrades.get("scavenger_rig", 0))
	var scav_max: bool = scav_lvl >= 4
	var scav_cost: int = (scav_lvl + 1) * 150
	_format_upgrade_button(
		scavenger_btn,
		"SCAVENGER RIG",
		scav_lvl,
		4,
		"+%d%% Salvage Recovery" % ((scav_lvl + 1) * 25),
		scav_cost,
		salvage,
		scav_max
	)

	# 2. Rotor Armor (Max Rank 4)
	var armor_lvl: int = int(upgrades.get("rotor_armor", 0))
	var armor_max: bool = armor_lvl >= 4
	var armor_cost: int = (armor_lvl + 1) * 200
	_format_upgrade_button(
		armor_btn,
		"ROTOR ARMOR",
		armor_lvl,
		4,
		"+%d Max Airframe HP" % ((armor_lvl + 1) * 20),
		armor_cost,
		salvage,
		armor_max
	)

	# 3. Magnet Suite (Max Rank 3)
	var mag_lvl: int = int(upgrades.get("magnet_radius", 0))
	var mag_max: bool = mag_lvl >= 3
	var mag_cost: int = (mag_lvl + 1) * 100
	_format_upgrade_button(
		magnet_btn,
		"MAGNET SUITE",
		mag_lvl,
		3,
		"+%dm Attract Radius" % ((mag_lvl + 1) * 6),
		mag_cost,
		salvage,
		mag_max
	)

	# 4. Extraction Insurance (1 rank, owned or not)
	var has_ins: bool = bool(upgrades.get("extraction_insurance", false))
	_format_upgrade_button(
		insurance_btn,
		"EXTRACTION INSURANCE",
		1 if has_ins else 0,
		1,
		"Retain 50% Salvage on Combat Loss",
		350,
		salvage,
		has_ins
	)

	# Update Telemetry Readout Panel
	_update_telemetry(scav_lvl, armor_lvl, mag_lvl, has_ins)

func _format_upgrade_button(btn: Button, title: String, current_lvl: int, max_lvl: int, effect_str: String, cost: int, current_salvage: int, is_max: bool) -> void:
	if not btn:
		return

	# Build pips string: [■ ■ ■ □]
	var pips: String = "["
	for p: int in range(max_lvl):
		if p < current_lvl:
			pips += "■"
		else:
			pips += "□"
		if p < max_lvl - 1:
			pips += " "
	pips += "]"

	var status_text: String
	if is_max:
		status_text = "MAX RANK"
		btn.disabled = true
	else:
		status_text = "COST: %d" % cost
		btn.disabled = current_salvage < cost

	# If child rich labels exist, format them
	var title_lbl: Label = btn.find_child("CardTitle", true, false) as Label
	var pips_lbl: Label = btn.find_child("CardPips", true, false) as Label
	var desc_lbl: Label = btn.find_child("CardDesc", true, false) as Label
	var cost_lbl: Label = btn.find_child("CardCost", true, false) as Label

	if title_lbl:
		title_lbl.text = title
	if pips_lbl:
		pips_lbl.text = "%s  RANK %d/%d" % [pips, current_lvl, max_lvl]
	if desc_lbl:
		desc_lbl.text = effect_str
	if cost_lbl:
		cost_lbl.text = status_text
		if is_max:
			cost_lbl.modulate = Color(0.3, 0.9, 0.6, 1.0)
		elif current_salvage < cost:
			cost_lbl.modulate = Color(0.7, 0.4, 0.4, 0.9)
		else:
			cost_lbl.modulate = COLOR_ACCENT_AMBER

	# Set clean single-line fallback text for standard button rendering
	if is_max:
		btn.text = "%s  %s  (%s)  —  MAX RANK" % [title, pips, effect_str]
	else:
		btn.text = "%s  %s  (%s)  —  COST: %d" % [title, pips, effect_str, cost]

func _update_telemetry(scav_lvl: int, armor_lvl: int, mag_lvl: int, has_ins: bool) -> void:
	if stat_hp_label:
		stat_hp_label.text = "%d HP" % (100 + armor_lvl * 20)
	if stat_salvage_label:
		stat_salvage_label.text = "+%d%%" % (scav_lvl * 25)
	if stat_magnet_label:
		stat_magnet_label.text = "%d METERS" % (10 + mag_lvl * 6)
	if stat_insurance_label:
		if has_ins:
			stat_insurance_label.text = "ACTIVE (50%)"
			stat_insurance_label.modulate = Color(0.3, 0.9, 0.6, 1.0)
		else:
			stat_insurance_label.text = "UNINSURED"
			stat_insurance_label.modulate = Color(0.65, 0.70, 0.78, 0.8)

func _buy_scavenger() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})
	var lvl: int = int(upgrades.get("scavenger_rig", 0))
	var cost := (lvl + 1) * 150
	if salvage >= cost and lvl < 4:
		_save_data["salvage"] = salvage - cost
		upgrades["scavenger_rig"] = lvl + 1
		_save_data["upgrades"] = upgrades
		SaveSystem.save_data(_save_data)
		_play_ui_audio(SOUND_CONFIRM, -12.0)
		_update_ui()

func _buy_armor() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})
	var lvl: int = int(upgrades.get("rotor_armor", 0))
	var cost := (lvl + 1) * 200
	if salvage >= cost and lvl < 4:
		_save_data["salvage"] = salvage - cost
		upgrades["rotor_armor"] = lvl + 1
		_save_data["upgrades"] = upgrades
		SaveSystem.save_data(_save_data)
		_play_ui_audio(SOUND_CONFIRM, -12.0)
		_update_ui()

func _buy_magnet() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})
	var lvl: int = int(upgrades.get("magnet_radius", 0))
	var cost := (lvl + 1) * 100
	if salvage >= cost and lvl < 3:
		_save_data["salvage"] = salvage - cost
		upgrades["magnet_radius"] = lvl + 1
		_save_data["upgrades"] = upgrades
		SaveSystem.save_data(_save_data)
		_play_ui_audio(SOUND_CONFIRM, -12.0)
		_update_ui()

func _buy_insurance() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})
	var has_ins: bool = bool(upgrades.get("extraction_insurance", false))
	if salvage >= 350 and not has_ins:
		_save_data["salvage"] = salvage - 350
		upgrades["extraction_insurance"] = true
		_save_data["upgrades"] = upgrades
		SaveSystem.save_data(_save_data)
		_play_ui_audio(SOUND_CONFIRM, -12.0)
		_update_ui()

func _on_deploy_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_ui_audio(SOUND_CONFIRM, -10.0)

	var curtain := ColorRect.new()
	curtain.name = "DeployTransitionCurtain"
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.grow_horizontal = Control.GROW_DIRECTION_BOTH
	curtain.grow_vertical = Control.GROW_DIRECTION_BOTH
	curtain.color = Color(0.02, 0.03, 0.06, 1.0)
	curtain.modulate.a = 0.0
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)

	var tw: Tween = create_tween()
	tw.tween_property(curtain, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")
	)

func _on_menu_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_play_ui_audio(SOUND_BACK, -12.0)

	var curtain := ColorRect.new()
	curtain.name = "MenuReturnTransitionCurtain"
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	curtain.grow_horizontal = Control.GROW_DIRECTION_BOTH
	curtain.grow_vertical = Control.GROW_DIRECTION_BOTH
	curtain.color = Color(0.02, 0.03, 0.06, 1.0)
	curtain.modulate.a = 0.0
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)

	var tw: Tween = create_tween()
	tw.tween_property(curtain, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)
