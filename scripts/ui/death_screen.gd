class_name DeathScreen
extends Control

## Tactical Military Game Over & After-Action Report (AAR) for Heli-Strike.
## Displays combat telemetry (Survival Time, Waves, Kills, Damage Dealt),
## salvage loss / insurance recovery breakdown, banked salvage total,
## and dual action buttons (DEPLOY AGAIN & RETURN TO HANGAR).

signal deploy_again_requested()
signal return_to_hangar_requested()

const FONT_RAJ_BOLD: FontFile = preload("res://assets/ui/fonts/Rajdhani-Bold.ttf")
const FONT_INTER_REG: FontFile = preload("res://assets/ui/fonts/Inter-Regular.ttf")
const FONT_INTER_SEMI: FontFile = preload("res://assets/ui/fonts/Inter-SemiBold.ttf")

const SOUND_FOCUS: AudioStream = preload("res://assets/audio/ui/ui_focus.wav")
const SOUND_CONFIRM: AudioStream = preload("res://assets/audio/ui/ui_confirm.wav")
const SOUND_BACK: AudioStream = preload("res://assets/audio/ui/ui_back.wav")

const COLOR_ACCENT_AMBER := Color(0.961, 0.725, 0.106, 1.0)
const COLOR_COMBAT_RED := Color(0.92, 0.24, 0.24, 1.0)
const COLOR_RECOVERY_GREEN := Color(0.3, 0.88, 0.45, 1.0)
const COLOR_SLATE_BORDER := Color(0.24, 0.32, 0.42, 0.75)
const COLOR_DARK_BG := Color(0.045, 0.065, 0.095, 0.96)

# UI References
@onready var modal_panel: PanelContainer = find_child("ModalPanel", true, false) as PanelContainer
@onready var time_value_label: Label = find_child("StatTimeValue", true, false) as Label
@onready var wave_value_label: Label = find_child("StatWaveValue", true, false) as Label
@onready var kills_value_label: Label = find_child("StatKillsValue", true, false) as Label
@onready var damage_value_label: Label = find_child("StatDamageValue", true, false) as Label

@onready var salvage_badge: PanelContainer = find_child("SalvageBadge", true, false) as PanelContainer
@onready var salvage_badge_label: Label = find_child("SalvageBadgeLabel", true, false) as Label
@onready var salvage_main_label: Label = find_child("SalvageMainLabel", true, false) as Label
@onready var salvage_sub_label: Label = find_child("SalvageSubLabel", true, false) as Label
@onready var banked_total_label: Label = find_child("BankedTotalLabel", true, false) as Label

@onready var return_button: Button = find_child("ReturnButton", true, false) as Button
@onready var deploy_again_button: Button = find_child("DeployAgainButton", true, false) as Button
@onready var prompt_label: Label = find_child("PromptLabel", true, false) as Label

var _audio_player: AudioStreamPlayer = null
var _last_focus_sound_ms: int = 0
var _is_action_taken: bool = false
var _using_gamepad: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("death_screen")
	add_to_group("run_end_screen")
	visible = false
	_setup_audio()
	_connect_buttons()
	_update_input_hints()

func _setup_audio() -> void:
	if not _audio_player:
		_audio_player = AudioStreamPlayer.new()
		_audio_player.name = "DeathScreenAudioPlayer"
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

func _connect_buttons() -> void:
	if not return_button:
		return_button = find_child("ReturnButton", true, false) as Button
	if not deploy_again_button:
		deploy_again_button = find_child("DeployAgainButton", true, false) as Button

	if return_button:
		return_button.pressed.connect(_on_return_pressed)
		return_button.focus_entered.connect(_play_focus_sound)
		return_button.mouse_entered.connect(_play_focus_sound)

	if deploy_again_button:
		deploy_again_button.pressed.connect(_on_deploy_again_pressed)
		deploy_again_button.focus_entered.connect(_play_focus_sound)
		deploy_again_button.mouse_entered.connect(_play_focus_sound)

	# Setup linear focus loop between buttons
	if return_button and deploy_again_button:
		return_button.focus_neighbor_right = deploy_again_button.get_path()
		return_button.focus_neighbor_left = deploy_again_button.get_path()
		deploy_again_button.focus_neighbor_left = return_button.get_path()
		deploy_again_button.focus_neighbor_right = return_button.get_path()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not _using_gamepad:
			_using_gamepad = true
			_update_input_hints()
	elif event is InputEventKey or event is InputEventMouseButton:
		if _using_gamepad:
			_using_gamepad = false
			_update_input_hints()

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_return_pressed()
		get_viewport().set_input_as_handled()

func _update_input_hints() -> void:
	if not prompt_label:
		return
	if _using_gamepad:
		prompt_label.text = "[A] SELECT  |  [B] RETURN TO HANGAR"
	else:
		prompt_label.text = "[ENTER / CLICK] SELECT    [ESC] RETURN TO HANGAR"

## Primary entry point called by GameManager when player dies
func display_death(lost_salvage: int, has_insurance: bool) -> void:
	_is_action_taken = false
	_resolve_scene_nodes()
	_populate_telemetry()
	_populate_salvage(lost_salvage, has_insurance)

	# Smooth modal reveal
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if modal_panel:
		modal_panel.modulate.a = 0.0
		modal_panel.scale = Vector2(0.96, 0.96)
		modal_panel.pivot_offset = modal_panel.size * 0.5
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(modal_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(modal_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_play_ui_audio(SOUND_BACK, -10.0)

	# Focus default on Deploy Again for rapid rematch
	if deploy_again_button:
		deploy_again_button.grab_focus()
	elif return_button:
		return_button.grab_focus()

## Compatible alias for RunStateController
func display_game_over(stats: Dictionary) -> void:
	var salvage: int = int(stats.get("salvage", 0))
	var data: Dictionary = SaveSystem.load_data()
	var upgrades: Dictionary = data.get("upgrades", {})
	var has_insurance: bool = upgrades.get("extraction_insurance", false)
	display_death(salvage, has_insurance)

func _resolve_scene_nodes() -> void:
	if not modal_panel:
		modal_panel = find_child("ModalPanel", true, false) as PanelContainer
	if not time_value_label:
		time_value_label = find_child("StatTimeValue", true, false) as Label
	if not wave_value_label:
		wave_value_label = find_child("StatWaveValue", true, false) as Label
	if not kills_value_label:
		kills_value_label = find_child("StatKillsValue", true, false) as Label
	if not damage_value_label:
		damage_value_label = find_child("StatDamageValue", true, false) as Label
	if not salvage_badge:
		salvage_badge = find_child("SalvageBadge", true, false) as PanelContainer
	if not salvage_badge_label:
		salvage_badge_label = find_child("SalvageBadgeLabel", true, false) as Label
	if not salvage_main_label:
		salvage_main_label = find_child("SalvageMainLabel", true, false) as Label
	if not salvage_sub_label:
		salvage_sub_label = find_child("SalvageSubLabel", true, false) as Label
	if not banked_total_label:
		banked_total_label = find_child("BankedTotalLabel", true, false) as Label
	if not return_button:
		return_button = find_child("ReturnButton", true, false) as Button
	if not deploy_again_button:
		deploy_again_button = find_child("DeployAgainButton", true, false) as Button
	if not prompt_label:
		prompt_label = find_child("PromptLabel", true, false) as Label

func _populate_telemetry() -> void:
	var gm: GameManager = get_tree().get_first_node_in_group("game_manager") as GameManager
	var wm: WaveManager = get_tree().get_first_node_in_group("wave_manager") as WaveManager

	# 1. Survival Time
	var sec: float = gm.run_timer if gm else 0.0
	var mins: int = int(floorf(sec / 60.0))
	var rem_sec: int = int(sec) % 60
	if time_value_label:
		time_value_label.text = "%02d:%02d" % [mins, rem_sec]

	# 2. Stage Reached
	var current_stage: int = 1
	if wm:
		if "current_wave_index" in wm:
			current_stage = int(wm.current_wave_index) + 1
		elif "current_wave" in wm:
			current_stage = int(wm.current_wave)
	if wave_value_label:
		wave_value_label.text = "STAGE %d / 10" % current_stage

	# 3. Hostiles Destroyed
	var kills: int = gm.enemies_killed if gm else 0
	if kills_value_label:
		kills_value_label.text = "%d KILLS" % kills

	# 4. Total Damage
	var dmg: float = gm.damage_dealt if gm else 0.0
	if damage_value_label:
		if dmg >= 1000.0:
			damage_value_label.text = "%.1fK DMG" % (dmg / 1000.0)
		else:
			damage_value_label.text = "%d DMG" % int(dmg)

func _populate_salvage(lost_salvage: int, has_insurance: bool) -> void:
	var save_data: Dictionary = SaveSystem.load_data()
	var banked: int = int(save_data.get("salvage", 0))

	if has_insurance:
		var protected_amount: int = int(lost_salvage * 0.5)
		var actual_loss: int = lost_salvage - protected_amount

		if salvage_badge_label:
			salvage_badge_label.text = "INSURANCE POLICY EXECUTED"
			salvage_badge_label.add_theme_color_override("font_color", COLOR_RECOVERY_GREEN)

		if salvage_main_label:
			salvage_main_label.text = "+%d CR SALVAGE RECOVERED (50%% COVERAGE)" % protected_amount
			salvage_main_label.add_theme_color_override("font_color", COLOR_RECOVERY_GREEN)

		if salvage_sub_label:
			salvage_sub_label.text = "-%d CR unrecoverable combat damage" % actual_loss
			salvage_sub_label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.84, 0.8))
	else:
		if salvage_badge_label:
			salvage_badge_label.text = "CRITICAL COMBAT LOSS"
			salvage_badge_label.add_theme_color_override("font_color", COLOR_COMBAT_RED)

		if salvage_main_label:
			salvage_main_label.text = "ALL SALVAGE LOST: %d CR destroyed with airframe" % lost_salvage
			salvage_main_label.add_theme_color_override("font_color", COLOR_COMBAT_RED)

		if salvage_sub_label:
			salvage_sub_label.text = "[TACTICAL NOTE: Extraction Insurance in Hangar protects 50% salvage on loss]"
			salvage_sub_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.78, 0.8))

	if banked_total_label:
		banked_total_label.text = "CURRENT BANKED SALVAGE: %d CR" % banked

func _on_deploy_again_pressed() -> void:
	if _is_action_taken:
		return
	_is_action_taken = true
	_play_ui_audio(SOUND_CONFIRM, -12.0)
	deploy_again_requested.emit()

	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_return_pressed() -> void:
	if _is_action_taken:
		return
	_is_action_taken = true
	_play_ui_audio(SOUND_BACK, -12.0)
	return_to_hangar_requested.emit()

	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/hangar/hangar.tscn")
