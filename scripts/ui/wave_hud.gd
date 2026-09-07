class_name WaveHUD
extends Control

## UI display for wave run status, timers, enemy counts, and transition banners.

@onready var wave_number_label: Label = %WaveNumberLabel
@onready var wave_timer_label: Label = %WaveTimerLabel
@onready var enemy_count_label: Label = %EnemyCountLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var transition_banner: Label = %TransitionBannerLabel

var _banner_tween: Tween = null
var _countdown_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if countdown_label:
		countdown_label.visible = false
		countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if transition_banner:
		transition_banner.visible = false
		transition_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_connect_to_wave_manager()

func _connect_to_wave_manager() -> void:
	var wm := get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if not wm:
		# Search parent or root
		wm = get_tree().root.find_child("WaveManager", true, false) as WaveManager

	if wm:
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
		countdown_label.text = "DEPLOYING IN %d" % seconds_left
		countdown_label.visible = true
		countdown_label.modulate.a = 1.0

		if _countdown_tween:
			_countdown_tween.kill()
		_countdown_tween = create_tween()
		countdown_label.scale = Vector2(1.25, 1.25)
		_countdown_tween.tween_property(countdown_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		countdown_label.visible = false

func _on_wave_started(wave_num: int, _total_waves: int) -> void:
	if countdown_label:
		countdown_label.visible = false

	if wave_number_label:
		wave_number_label.text = "STAGE %d" % wave_num

	var banner_text := "DEPLOYMENT // SURVIVAL ACTIVE" if wave_num == 1 else "THREAT ESCALATION // STAGE %d" % wave_num
	_show_banner(banner_text, Color(0.3, 0.9, 1.0, 1.0))

func _on_wave_time_changed(time_val: float) -> void:
	if wave_timer_label:
		var clamped_time := maxf(0.0, time_val)
		var minutes := int(floorf(clamped_time / 60.0))
		var seconds := int(clamped_time) % 60
		wave_timer_label.text = "%02d:%02d" % [minutes, seconds]

func _on_enemy_count_changed(active_count: int) -> void:
	if enemy_count_label:
		enemy_count_label.text = "HOSTILES: %d" % active_count

func _on_intermission_started(next_wave: int, _duration: float) -> void:
	_show_banner("PREPARING WAVE %d" % next_wave, Color(0.7, 0.8, 0.9, 0.9))

func _on_run_completed() -> void:
	_show_banner("MISSION ACCOMPLISHED // ALL WAVES CLEARED", Color(0.2, 1.0, 0.4, 1.0), 6.0)

func _show_banner(text: String, color: Color = Color.WHITE, duration: float = 2.5) -> void:
	if not transition_banner:
		return

	transition_banner.text = text
	transition_banner.modulate = color
	transition_banner.modulate.a = 0.0
	transition_banner.visible = true

	if _banner_tween:
		_banner_tween.kill()

	_banner_tween = create_tween()
	_banner_tween.tween_property(transition_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(transition_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(func(): transition_banner.visible = false)
