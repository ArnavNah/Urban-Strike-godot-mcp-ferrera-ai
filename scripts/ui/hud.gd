class_name HUD
extends Control

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var heat_bar: ProgressBar = %HeatBar
@onready var overheat_warning: Label = %OverheatWarning

@onready var missile_bar: ProgressBar = %MissileLockBar
@onready var missile_status: Label = %MissileStatusLabel
@onready var flares_label: Label = %FlaresLabel
@onready var missile_warning_panel: Panel = %MissileWarningPanel

@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel
@onready var salvage_label: Label = %SalvageLabel

@onready var wave_label: Label = %WaveLabel
@onready var wave_progress_label: Label = %WaveProgressLabel
@onready var wave_banner: Label = %WaveBanner
@onready var border_warning_banner: Control = %BorderWarningBanner
@onready var border_warning_label: Label = %BorderWarningLabel

@onready var boss_container: VBoxContainer = %BossContainer
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_phase_label: Label = %BossPhaseLabel

@onready var altitude_label: Label = %AltitudeLabel
@onready var speed_label: Label = %SpeedLabel
@onready var aim_mode_label: Label = %AimModeLabel

@onready var target_reticle: Control = %TargetReticle
@onready var damage_vignette: ColorRect = %DamageVignette

var _player: Node3D = null
var _current_target: Node3D = null
var _is_manual_aim: bool = false
var _is_jammed: bool = false
var _banner_timer: float = 0.0
var _prev_health: float = 100.0
var _health_tween: Tween = null
var _vignette_tween: Tween = null
var _missile_ammo: int = 6
var _max_missiles: int = 6
var _missile_warning_timer: float = 0.0
var _last_lock_progress: float = 0.0
var _is_missile_locked: bool = false

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if target_reticle:
		target_reticle.visible = false
	if overheat_warning:
		overheat_warning.visible = false
	if missile_warning_panel:
		missile_warning_panel.visible = false
	if boss_container:
		boss_container.visible = false
	if wave_banner:
		wave_banner.visible = false
	if border_warning_banner:
		border_warning_banner.visible = false

	# EventBus listeners
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("player_health_changed"):
			eb.player_health_changed.connect(_on_health_changed)
		if eb.has_signal("chaingun_heat_changed"):
			eb.chaingun_heat_changed.connect(_on_heat_changed)
		if eb.has_signal("target_acquired"):
			eb.target_acquired.connect(_on_target_acquired)
		if eb.has_signal("target_lost"):
			eb.target_lost.connect(_on_target_lost)
		if eb.has_signal("manual_aim_state_changed"):
			eb.manual_aim_state_changed.connect(_on_manual_aim_changed)
		if eb.has_signal("missile_lock_updated"):
			eb.missile_lock_updated.connect(_on_missile_lock_updated)
		if eb.has_signal("missile_ammo_changed"):
			eb.missile_ammo_changed.connect(_on_missile_ammo_changed)
		if eb.has_signal("no_missiles_warning"):
			eb.no_missiles_warning.connect(_on_no_missiles_warning)
		if eb.has_signal("flares_updated"):
			eb.flares_updated.connect(_on_flares_updated)
		if eb.has_signal("incoming_missile_warning"):
			eb.incoming_missile_warning.connect(_on_missile_warning)
		if eb.has_signal("xp_updated"):
			eb.xp_updated.connect(_on_xp_updated)
		if eb.has_signal("wave_started"):
			eb.wave_started.connect(_on_wave_started)
		if eb.has_signal("wave_progress_updated"):
			eb.wave_progress_updated.connect(_on_wave_progress)
		if eb.has_signal("boss_spawned"):
			eb.boss_spawned.connect(_on_boss_spawned)
		if eb.has_signal("boss_health_changed"):
			eb.boss_health_changed.connect(_on_boss_health_changed)
		if eb.has_signal("boss_defeated"):
			eb.boss_defeated.connect(_on_boss_defeated)
		if eb.has_signal("salvage_updated"):
			eb.salvage_updated.connect(_on_salvage_updated)
		if eb.has_signal("jammer_status_changed"):
			eb.jammer_status_changed.connect(_on_jammer_status_changed)
		if eb.has_signal("border_warning_changed"):
			eb.border_warning_changed.connect(_on_border_warning_changed)

	if _player and "missile_pod" in _player and _player.missile_pod:
		var pod: Node = _player.missile_pod
		if "current_missiles" in pod and "max_missiles" in pod:
			_missile_ammo = int(pod.current_missiles)
			_max_missiles = int(pod.max_missiles)
	_update_missile_status_display()

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return

	# Missile warning flash timer
	if _missile_warning_timer > 0.0:
		_missile_warning_timer -= delta
		if _missile_warning_timer <= 0.0:
			_update_missile_status_display()

	# Speed and altitude telemetry
	var speed_kph: float = _player.velocity.length() * 3.6
	if speed_label:
		speed_label.text = "%3.0f KPH" % speed_kph

	if altitude_label:
		altitude_label.text = "ALT: %4.1f m" % _player.global_position.y

	# Update 3D projected screen reticle
	_update_target_reticle()

	# Wave banner fade
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and wave_banner:
			wave_banner.visible = false

	# Border warning pulse
	if border_warning_banner and border_warning_banner.visible:
		var pulse: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		border_warning_banner.modulate = Color(1.0, 1.0, 1.0, lerpf(0.55, 1.0, pulse))

	queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam or not is_instance_valid(_player):
		return

	var vp_rect := get_viewport_rect()
	var vp_center := vp_rect.size * 0.5
	var margin := 45.0

	var threats: Array[Node3D] = []
	if EnemyRegistry.instance:
		threats = EnemyRegistry.instance.get_enemies_in_radius(_player.global_position, 85.0)
	else:
		var raw_threats := get_tree().get_nodes_in_group("enemies")
		for th in raw_threats:
			var th3d := th as Node3D
			if is_instance_valid(th3d) and th3d != _player:
				threats.append(th3d)

	for th3d in threats:
		if not is_instance_valid(th3d) or th3d == _player:
			continue

		var dist := _player.global_position.distance_to(th3d.global_position)
		if dist > 85.0:
			continue

		var th_pos := th3d.global_position + Vector3(0, 1.0, 0)
		var is_behind := cam.is_position_behind(th_pos)
		var scr_pos := cam.unproject_position(th_pos)

		var is_offscreen := is_behind or scr_pos.x < margin or scr_pos.x > (vp_rect.size.x - margin) or scr_pos.y < margin or scr_pos.y > (vp_rect.size.y - margin)

		if is_offscreen:
			var dir_2d: Vector2
			if is_behind:
				dir_2d = -(scr_pos - vp_center).normalized()
			else:
				dir_2d = (scr_pos - vp_center).normalized()

			if dir_2d.length_squared() < 0.01:
				dir_2d = Vector2.UP

			# Clamp to edge of screen with margin
			var edge_pos: Vector2 = vp_center + dir_2d * minf(vp_center.x - margin, vp_center.y - margin)

			var col := Color(1.0, 0.3, 0.2, 0.85)
			if th3d.is_in_group("bosses"):
				col = Color(1.0, 0.1, 0.1, 1.0)
			elif th3d.is_in_group("sam_sites"):
				col = Color(1.0, 0.6, 0.1, 0.9)

			# Draw chevron pointing outward
			var tip := edge_pos + dir_2d * 12.0
			var side_a := edge_pos - dir_2d * 8.0 + Vector2(-dir_2d.y, dir_2d.x) * 8.0
			var side_b := edge_pos - dir_2d * 8.0 - Vector2(-dir_2d.y, dir_2d.x) * 8.0
			draw_colored_polygon(PackedVector2Array([tip, side_a, side_b]), col)

func _update_target_reticle() -> void:
	if not target_reticle:
		return

	if not is_instance_valid(_current_target) or _is_manual_aim:
		target_reticle.visible = false
		return

	var cam := get_viewport().get_camera_3d()
	if not cam:
		target_reticle.visible = false
		return

	var target_3d_pos := _current_target.global_position + Vector3(0, 0.8, 0)
	if cam.is_position_behind(target_3d_pos):
		target_reticle.visible = false
		return

	var screen_pos: Vector2 = cam.unproject_position(target_3d_pos)
	target_reticle.visible = true
	target_reticle.position = screen_pos - (target_reticle.size * 0.5)

func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		if _health_tween:
			_health_tween.kill()
		_health_tween = create_tween()
		_health_tween.tween_property(health_bar, "value", current, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if health_label:
		if current <= maximum * 0.30:
			health_label.text = "CRITICAL: %d / %d" % [int(current), int(maximum)]
			health_label.modulate = Color(1.0, 0.2, 0.2)
		else:
			health_label.text = "HULL: %d / %d" % [int(current), int(maximum)]
			health_label.modulate = Color(1.0, 1.0, 1.0)

	if current < _prev_health and damage_vignette:
		var vignette_alpha := 0.32
		if current <= maximum * 0.30:
			vignette_alpha = 0.55 # Intense emergency tell when critically damaged
		damage_vignette.color = Color(0.9, 0.1, 0.1, vignette_alpha)
		if _vignette_tween:
			_vignette_tween.kill()
		_vignette_tween = create_tween()
		_vignette_tween.tween_property(damage_vignette, "color:a", 0.0, 0.45)

	_prev_health = current

func _on_heat_changed(current: float, maximum: float, is_overheated: bool) -> void:
	if heat_bar:
		heat_bar.max_value = maximum
		heat_bar.value = current
	if overheat_warning:
		overheat_warning.visible = is_overheated

func _update_missile_status_display() -> void:
	if not missile_status:
		return

	if _missile_warning_timer > 0.0:
		missile_status.text = "MISSILES  %d / %d  [ ⚠ NO MISSILES ⚠ ]" % [_missile_ammo, _max_missiles]
		missile_status.modulate = Color(1.0, 0.2, 0.2, 1.0)
		return

	if _missile_ammo <= 0:
		missile_status.text = "MISSILES  0 / %d  [ EMPTY ]" % _max_missiles
		missile_status.modulate = Color(0.85, 0.25, 0.25, 0.75) # Dim red
		return

	var jam_suffix := " [EW JAMMED]" if _is_jammed else ""
	if _is_missile_locked:
		missile_status.text = "MISSILES  %d / %d  [ LOCKED - RMB ]" % [_missile_ammo, _max_missiles]
		missile_status.modulate = Color(0.2, 1.0, 0.3, 1.0)
	elif _last_lock_progress > 0.05:
		missile_status.text = "MISSILES  %d / %d  [ LOCKING %d%%%s ]" % [_missile_ammo, _max_missiles, int(_last_lock_progress * 100.0), jam_suffix]
		missile_status.modulate = Color(1.0, 0.4, 0.2) if _is_jammed else Color(1.0, 0.8, 0.2)
	else:
		missile_status.text = "MISSILES  %d / %d  [ READY%s ]" % [_missile_ammo, _max_missiles, jam_suffix]
		missile_status.modulate = Color(1.0, 0.5, 0.1) if _is_jammed else Color(0.85, 0.9, 0.95)

func _on_missile_ammo_changed(current: int, maximum: int) -> void:
	_missile_ammo = current
	_max_missiles = maximum
	_update_missile_status_display()

func _on_no_missiles_warning() -> void:
	_missile_warning_timer = 1.2
	_update_missile_status_display()

func reset_missile_display(current: int = 6, maximum: int = 6) -> void:
	_missile_ammo = current
	_max_missiles = maximum
	_missile_warning_timer = 0.0
	_update_missile_status_display()

func _on_missile_lock_updated(progress: float, _target: Node3D, is_locked: bool) -> void:
	_last_lock_progress = progress
	_is_missile_locked = is_locked
	if missile_bar:
		missile_bar.value = progress * 100.0
	_update_missile_status_display()

func _on_jammer_status_changed(is_jammed: bool, _count: int) -> void:
	_is_jammed = is_jammed

func _on_flares_updated(charges_left: int, max_charges: int, _is_ready: bool) -> void:
	if flares_label:
		var txt := "FLARES [X]: "
		for i in range(max_charges):
			if i < charges_left:
				txt += "[◆] "
			else:
				txt += "[◇] "
		flares_label.text = txt

func _on_missile_warning(_source_pos: Vector3, is_active: bool) -> void:
	if missile_warning_panel:
		missile_warning_panel.visible = is_active
		if is_active:
			missile_warning_panel.modulate = Color(1.0, 0.15, 0.1, 1.0)

func _on_xp_updated(current: int, needed: int, level: int) -> void:
	if xp_bar:
		xp_bar.max_value = needed
		xp_bar.value = current
	if level_label:
		level_label.text = "LVL %d" % level

func _on_wave_started(wave_num: int, announcement: String) -> void:
	if wave_label:
		wave_label.text = "STAGE %d" % wave_num
	if wave_banner:
		wave_banner.text = announcement
		wave_banner.visible = true
		_banner_timer = 4.0

func _on_wave_progress(remaining: int, _total: int) -> void:
	if wave_progress_label:
		wave_progress_label.text = "HOSTILES: %d" % remaining

func _on_boss_spawned(_boss: Node3D) -> void:
	if boss_container:
		boss_container.visible = true

func _on_boss_health_changed(current: float, maximum: float, phase: int) -> void:
	if boss_bar:
		boss_bar.max_value = maximum
		boss_bar.value = current
	if boss_phase_label:
		boss_phase_label.text = "ARCHON GUNSHIP // PHASE %d" % phase

func _on_boss_defeated() -> void:
	if boss_container:
		boss_container.visible = false

func _on_salvage_updated(run_salvage: int) -> void:
	if salvage_label:
		salvage_label.text = "SALVAGE: %d" % run_salvage

func _on_target_acquired(target: Node3D) -> void:
	_current_target = target

func _on_target_lost() -> void:
	_current_target = null

func _on_manual_aim_changed(is_manual: bool) -> void:
	_is_manual_aim = is_manual
	if aim_mode_label:
		aim_mode_label.text = "AIM: MANUAL" if is_manual else "AIM: AUTO-LOS"

func _on_border_warning_changed(is_warning: bool, _return_direction: Vector3, distance_to_edge: float) -> void:
	if border_warning_banner:
		border_warning_banner.visible = is_warning
	if is_warning and border_warning_label:
		border_warning_label.text = "⚠ WARNING: LEAVING MISSION AIRSPACE ⚠\nRETURN TO COMBAT AREA (%.0fm to perimeter)" % maxf(0.0, distance_to_edge)
