class_name WaveHUD
extends Control

## UI display for wave run status, timers, enemy counts, opening sequence, and transition banners.

@onready var wave_number_label: Label = %WaveNumberLabel
@onready var wave_timer_label: Label = %WaveTimerLabel
@onready var enemy_count_label: Label = %EnemyCountLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var transition_banner: Label = %TransitionBannerLabel

@onready var header_container: MarginContainer = get_node_or_null("%HeaderContainer") as MarginContainer
@onready var black_fade: ColorRect = get_node_or_null("%BlackFade") as ColorRect
@onready var opening_card: PanelContainer = get_node_or_null("%OpeningMissionCard") as PanelContainer
@onready var op_name_label: Label = get_node_or_null("%OpNameLabel") as Label
@onready var op_obj_label: Label = get_node_or_null("%OpObjectiveLabel") as Label
@onready var op_threat_label: Label = get_node_or_null("%OpThreatLabel") as Label

var _banner_tween: Tween = null
var _countdown_tween: Tween = null
var _wave_manager: WaveManager = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if countdown_label:
		countdown_label.visible = false
		countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if transition_banner:
		transition_banner.visible = false
		transition_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_start_opening_presentation()
	_connect_to_wave_manager()

func _start_opening_presentation() -> void:
	# 1. Fast fade from black (0.6s)
	if black_fade:
		black_fade.visible = true
		black_fade.modulate.a = 1.0
		var fade_tween := create_tween()
		fade_tween.tween_property(black_fade, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
		fade_tween.tween_callback(func(): black_fade.visible = false)

	# 2. Smoothly fade in top header panel
	if header_container:
		header_container.modulate.a = 0.0
		var header_tween := create_tween()
		header_tween.tween_interval(0.4)
		header_tween.tween_property(header_container, "modulate:a", 1.0, 0.5)

	# 3. Compact restrained mission card for ~2 seconds
	if opening_card:
		opening_card.visible = true
		opening_card.modulate.a = 0.0

		var md := get_tree().get_first_node_in_group("mission_director") as MissionDirector
		if not md:
			md = get_tree().root.find_child("MissionDirector", true, false) as MissionDirector
		if md and md.current_mission:
			if op_name_label:
				op_name_label.text = md.current_mission.mission_name.to_upper()
			if op_obj_label:
				op_obj_label.text = "MISSION: %s" % md.current_mission.mission_description.to_upper()
		else:
			if op_name_label:
				op_name_label.text = "OPERATION URBAN SHIELD"
			if op_obj_label:
				op_obj_label.text = "MISSION: SECURE METROPOLITAN AIRSPACE"
		if op_threat_label:
			op_threat_label.text = "THREAT LEVEL: LOW  //  AIRSPACE PATROL"

		var card_tween := create_tween()
		card_tween.tween_property(opening_card, "modulate:a", 1.0, 0.25)
		card_tween.tween_interval(1.8)
		card_tween.tween_property(opening_card, "modulate:a", 0.0, 0.35)
		card_tween.tween_callback(func(): opening_card.visible = false)

func _connect_to_wave_manager() -> void:
	var wm := get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if not wm:
		wm = get_tree().root.find_child("WaveManager", true, false) as WaveManager

	if wm:
		_wave_manager = wm
		wm.deployment_countdown_changed.connect(_on_deployment_countdown_changed)
		wm.wave_started.connect(_on_wave_started)
		wm.wave_time_changed.connect(_on_wave_time_changed)
		wm.enemy_count_changed.connect(_on_enemy_count_changed)
		wm.intermission_started.connect(_on_intermission_started)
		wm.run_completed.connect(_on_run_completed)

func _on_deployment_countdown_changed(seconds_left: int) -> void:
	if not countdown_label:
		return

	if seconds_left > 0:
		countdown_label.text = str(seconds_left)
		countdown_label.visible = true
		countdown_label.modulate = Color(0.31, 0.88, 0.93, 1.0) # Cyan
		countdown_label.modulate.a = 1.0

		if _countdown_tween:
			_countdown_tween.kill()
		_countdown_tween = create_tween()
		countdown_label.scale = Vector2(1.25, 1.25)
		_countdown_tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		countdown_label.text = "SYSTEMS ARMED"
		countdown_label.visible = true
		countdown_label.modulate = Color(0.96, 0.65, 0.14, 1.0) # Amber
		countdown_label.modulate.a = 1.0

		if _countdown_tween:
			_countdown_tween.kill()
		_countdown_tween = create_tween()
		countdown_label.scale = Vector2(1.15, 1.15)
		_countdown_tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.2)
		_countdown_tween.tween_interval(0.6)
		_countdown_tween.tween_property(countdown_label, "modulate:a", 0.0, 0.35)
		_countdown_tween.tween_callback(func(): countdown_label.visible = false)

func _on_wave_started(wave_num: int, _total_waves: int) -> void:
	if wave_number_label:
		wave_number_label.text = "STAGE %d" % wave_num

	# Wave 1 is introduced by the restrained opening countdown & SYSTEMS ARMED
	if wave_num > 1:
		var banner_text := "STAGE %d // THREAT ELEVATED" % wave_num
		_show_banner(banner_text, Color(0.31, 0.88, 0.93, 1.0), 0.7)

func _on_wave_time_changed(time_val: float) -> void:
	if wave_timer_label:
		var clamped_time := maxf(0.0, time_val)
		var minutes := int(floorf(clamped_time / 60.0))
		var seconds := int(clamped_time) % 60
		wave_timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_enemy_count_changed(active_count: int) -> void:
	if enemy_count_label:
		var is_clearing: bool = _wave_manager != null and _wave_manager.is_wave_clearing()
		if active_count == 0:
			enemy_count_label.text = "HOSTILES: 0 [SECURED]"
			enemy_count_label.modulate = Color(0.31, 0.88, 0.93, 1.0)
		elif is_clearing:
			enemy_count_label.text = "HOSTILES: %d [CLEARING]" % active_count
			enemy_count_label.modulate = Color(1.0, 0.45, 0.20, 1.0)
		else:
			enemy_count_label.text = "HOSTILES: %d" % active_count
			enemy_count_label.modulate = Color(0.96, 0.65, 0.14, 1.0)

func _on_intermission_started(next_wave: int, _duration: float) -> void:
	_show_banner("PREPARING STAGE %d" % next_wave, Color(0.7, 0.8, 0.9, 0.9), 0.7)

func _on_run_completed() -> void:
	_show_banner("MISSION ACCOMPLISHED // ALL WAVES CLEARED", Color(0.2, 1.0, 0.4, 1.0), 3.0)

func _show_banner(text: String, color: Color = Color.WHITE, duration: float = 0.7) -> void:
	if not transition_banner:
		return

	transition_banner.text = text
	transition_banner.modulate = color
	transition_banner.modulate.a = 0.0
	transition_banner.visible = true

	if _banner_tween:
		_banner_tween.kill()

	_banner_tween = create_tween()
	_banner_tween.tween_property(transition_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(transition_banner, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(func(): transition_banner.visible = false)
