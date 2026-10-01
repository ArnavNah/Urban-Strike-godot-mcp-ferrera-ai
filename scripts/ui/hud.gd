class_name HUD
extends Control

@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var heat_bar: ProgressBar = %HeatBar
@onready var overheat_warning: Label = %OverheatWarning

@onready var missile_bar: ProgressBar = %MissileLockBar
@onready var missile_status: Label = %MissileStatusLabel
@onready var flares_label: Label = %FlaresLabel
@onready var flares_bar: ProgressBar = get_node_or_null("%FlaresBar") as ProgressBar
@onready var missile_warning_panel: Panel = %MissileWarningPanel
@onready var evade_label: Label = get_node_or_null("%EvadeLabel") as Label
@onready var evade_bar: ProgressBar = get_node_or_null("%EvadeBar") as ProgressBar
@onready var passenger_label: Label = get_node_or_null("%PassengerLabel") as Label

@onready var xp_bar: ProgressBar = %XPBar
@onready var level_label: Label = %LevelLabel
@onready var salvage_label: Label = %SalvageLabel

@onready var wave_label: Label = get_node_or_null("%WaveLabel") as Label
@onready var wave_progress_label: Label = get_node_or_null("%WaveProgressLabel") as Label
@onready var wave_banner: Label = get_node_or_null("%WaveBanner") as Label
@onready var border_warning_banner: Control = %BorderWarningBanner
@onready var border_warning_label: Label = %BorderWarningLabel

@onready var boss_container: VBoxContainer = %BossContainer
@onready var boss_bar: ProgressBar = %BossBar
@onready var boss_phase_label: Label = %BossPhaseLabel

@onready var score_label: Label = get_node_or_null("%ScoreLabel") as Label
@onready var kills_label: Label = get_node_or_null("%KillsLabel") as Label
@onready var multiplier_badge: Label = get_node_or_null("%MultiplierBadge") as Label
@onready var combo_bar: ProgressBar = get_node_or_null("%ComboBar") as ProgressBar
@onready var hover_hazard_banner: PanelContainer = get_node_or_null("%HoverHazardBanner") as PanelContainer
@onready var hover_hazard_label: Label = get_node_or_null("%HoverHazardLabel") as Label

var _displayed_score: int = 0
var _target_score: int = 0
var _score_tween: Tween = null
var _multiplier_tween: Tween = null
var _is_hover_hazard: bool = false

@onready var altitude_label: Label = %AltitudeLabel
@onready var speed_label: Label = %SpeedLabel
@onready var aim_mode_label: Label = %AimModeLabel

@onready var target_reticle: Control = %TargetReticle
@onready var damage_vignette: ColorRect = %DamageVignette

class DamageCue:
	var dir_2d: Vector2 = Vector2.UP
	var timer: float = 0.45
	var max_time: float = 0.45
	var is_shield: bool = false

var _damage_cues: Array[DamageCue] = []
var upgrade_banner: PanelContainer = null
var upgrade_banner_label: Label = null
var _upgrade_banner_timer: float = 0.0

var attack_run_banner: PanelContainer = null
var attack_run_label: Label = null

var defense_status_label: Label = null
var _wingmen_alive: int = 0
var _has_wingmen: bool = false
var _armor_pct: float = 0.0
var _repair_rate: float = 0.0
var _has_aegis: bool = false
var _aegis_cooldown: float = 0.0

var _player: Node3D = null
var _current_target: Node3D = null
var _is_manual_aim: bool = false
var _is_jammed: bool = false
var _banner_timer: float = 0.0
var _prev_health: float = 100.0
var _health_tween: Tween = null
var _heat_tween: Tween = null
var _flares_tween: Tween = null
var _vignette_tween: Tween = null
var _missile_ammo: int = 6
var _max_missiles: int = 6
var _missile_warning_timer: float = 0.0
var _ammo_full_timer: float = 0.0
var _hull_full_timer: float = 0.0
var _current_health: float = 100.0
var _max_health: float = 100.0
var _last_lock_progress: float = 0.0
var _is_missile_locked: bool = false
var mission_card: PanelContainer = null
var mission_title_label: Label = null
var mission_detail_label: Label = null
var _mission_banner_timer: float = 0.0
var _has_active_mission: bool = false
var _active_mission_pos: Vector3 = Vector3.ZERO
var _active_mission_title: String = ""
var _current_mission_base_detail: String = ""

var _damage_flash_enabled: bool = true
var _damage_flash_intensity: float = 1.0
var _reduced_flashing: bool = false
var _high_contrast_indicators: bool = false

var _last_speed_int: int = -999
var _last_alt_tenth: int = -9999
var _last_mission_dist_m: int = -999

var _evade_cooldown_remaining: float = 0.0
var _evade_cooldown_max: float = 3.5
var _is_evading_active: bool = false
var _evade_burst_timer: float = 0.0

var _passenger_count: int = 0
var _passenger_capacity: int = 6
var _passenger_evac_msg_timer: float = 0.0
var _passenger_evac_msg: String = ""
var _hud_font: Font = null

func _ready() -> void:
	if not damage_vignette:
		damage_vignette = ColorRect.new()
		damage_vignette.name = "DamageVignette"
		damage_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		damage_vignette.color = Color(0.88, 0.12, 0.12, 0.0)
		add_child(damage_vignette)
		move_child(damage_vignette, 0)

	_setup_upgrade_banner()
	_setup_evade_and_passenger_ui()
	_damage_flash_enabled = bool(SaveSystem.get_setting("damage_flash_enabled", true))
	_damage_flash_intensity = float(SaveSystem.get_setting("damage_flash_intensity", 1.0))
	_reduced_flashing = bool(SaveSystem.get_setting("reduced_flashing", false))
	_high_contrast_indicators = bool(SaveSystem.get_setting("high_contrast_indicators", false))

	_player = get_tree().get_first_node_in_group("player") as Node3D
	# Smooth fade in for HUD elements on startup
	modulate.a = 0.0
	var hud_tween := create_tween()
	hud_tween.tween_interval(0.3)
	hud_tween.tween_property(self, "modulate:a", 1.0, 0.6)
	if target_reticle:
		target_reticle.visible = false
	if heat_bar:
		heat_bar.visible = false
	if missile_bar:
		missile_bar.visible = false
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
		if eb.has_signal("kills_updated"):
			eb.kills_updated.connect(_on_kills_updated)
		if eb.has_signal("score_updated"):
			eb.score_updated.connect(_on_score_updated)
		if eb.has_signal("combo_timer_updated"):
			eb.combo_timer_updated.connect(_on_combo_timer_updated)
		if eb.has_signal("hover_hazard_state_changed"):
			eb.hover_hazard_state_changed.connect(_on_hover_hazard_state_changed)
		if eb.has_signal("jammer_status_changed"):
			eb.jammer_status_changed.connect(_on_jammer_status_changed)
		if eb.has_signal("border_warning_changed"):
			eb.border_warning_changed.connect(_on_border_warning_changed)
		if eb.has_signal("mission_started"):
			eb.mission_started.connect(_on_mission_started)
		if eb.has_signal("mission_updated"):
			eb.mission_updated.connect(_on_mission_updated)
		if eb.has_signal("mission_completed"):
			eb.mission_completed.connect(_on_mission_completed)
		if eb.has_signal("mission_failed"):
			eb.mission_failed.connect(_on_mission_failed)
		if eb.has_signal("player_damaged_directional"):
			eb.player_damaged_directional.connect(_on_player_damaged_directional)
		if eb.has_signal("upgrade_applied"):
			eb.upgrade_applied.connect(_on_upgrade_applied)
		if eb.has_signal("command_unit_destroyed"):
			eb.command_unit_destroyed.connect(_on_command_unit_destroyed)
		if eb.has_signal("radar_status_changed"):
			eb.radar_status_changed.connect(_on_radar_status_changed)
		if eb.has_signal("setting_changed"):
			eb.setting_changed.connect(_on_setting_changed)
		if eb.has_signal("ammo_full_notified"):
			eb.ammo_full_notified.connect(_on_ammo_full_notified)
		if eb.has_signal("hull_full_notified"):
			eb.hull_full_notified.connect(_on_hull_full_notified)
		if eb.has_signal("evade_cooldown_updated"):
			eb.evade_cooldown_updated.connect(_on_evade_cooldown_updated)
		if eb.has_signal("player_evaded"):
			eb.player_evaded.connect(_on_player_evaded)
		if eb.has_signal("survivor_collected"):
			eb.survivor_collected.connect(_on_survivor_collected)
		if eb.has_signal("survivors_evacuated"):
			eb.survivors_evacuated.connect(_on_survivors_evacuated)
		if eb.has_signal("attack_run_state_changed"):
			eb.attack_run_state_changed.connect(_on_attack_run_state_changed)
		if eb.has_signal("wingmen_status_updated"):
			eb.wingmen_status_updated.connect(_on_wingmen_status_updated)
		if eb.has_signal("defense_status_updated"):
			eb.defense_status_updated.connect(_on_defense_status_updated)
		if eb.has_signal("player_died"):
			eb.player_died.connect(_on_player_died)

	_setup_defense_status_ui()
	_setup_mission_card()

	if _player and "missile_pod" in _player and _player.missile_pod:
		var pod: Node = _player.missile_pod
		if "current_missiles" in pod and "max_missiles" in pod:
			_missile_ammo = int(pod.current_missiles)
			_max_missiles = int(pod.max_missiles)
	_update_missile_status_display()

	if _player and "flare_dispenser" in _player and _player.flare_dispenser:
		var fd: Node = _player.flare_dispenser
		if "current_flares" in fd and "max_flares" in fd:
			_on_flares_updated(int(fd.current_flares), int(fd.max_flares), true)
	else:
		_on_flares_updated(3, 3, true)

	if _player:
		if "passenger_count" in _player and "passenger_capacity" in _player:
			_passenger_count = int(_player.passenger_count)
			_passenger_capacity = int(_player.passenger_capacity)
		if "_evade_timer" in _player and "evade_cooldown" in _player:
			_evade_cooldown_remaining = float(_player._evade_timer)
			_evade_cooldown_max = float(_player.evade_cooldown)
	_update_evade_display()
	_update_passenger_display()

func _process(delta: float) -> void:
	if _evade_burst_timer > 0.0:
		_evade_burst_timer -= delta
		if _evade_burst_timer <= 0.0:
			_is_evading_active = false
			_update_evade_display()

	if _passenger_evac_msg_timer > 0.0:
		_passenger_evac_msg_timer -= delta
		if _passenger_evac_msg_timer <= 0.0:
			_passenger_evac_msg = ""
			_update_passenger_display()
	if _upgrade_banner_timer > 0.0:
		_upgrade_banner_timer -= delta
		if _upgrade_banner_timer <= 0.0 and upgrade_banner:
			upgrade_banner.visible = false
		elif _upgrade_banner_timer < 0.4 and upgrade_banner:
			upgrade_banner.modulate.a = _upgrade_banner_timer / 0.4

	if not _damage_cues.is_empty():
		var active_cues: Array[DamageCue] = []
		for c in _damage_cues:
			c.timer -= delta
			if c.timer > 0.0:
				active_cues.append(c)
		_damage_cues = active_cues

	if _mission_banner_timer > 0.0:
		_mission_banner_timer -= delta
		if _mission_banner_timer <= 0.0 and mission_card:
			mission_card.visible = false

	if _is_hover_hazard and hover_hazard_banner:
		var pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		hover_hazard_banner.modulate.a = pulse

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return

	# Missile warning flash timer
	if _missile_warning_timer > 0.0:
		_missile_warning_timer -= delta
		if _missile_warning_timer <= 0.0:
			_update_missile_status_display()

	if _ammo_full_timer > 0.0:
		_ammo_full_timer -= delta
		if _ammo_full_timer <= 0.0:
			_update_missile_status_display()

	if _hull_full_timer > 0.0:
		_hull_full_timer -= delta
		if _hull_full_timer <= 0.0:
			_update_health_label_display()

	# Speed and altitude telemetry (cached to avoid per-frame string allocations)
	var speed_int: int = int(roundf(_player.velocity.length() * 3.6))
	if speed_int != _last_speed_int:
		_last_speed_int = speed_int
		if speed_label:
			speed_label.text = "%3.0f KPH" % float(speed_int)

	var alt_tenth: int = int(roundf(_player.global_position.y * 10.0))
	if alt_tenth != _last_alt_tenth:
		_last_alt_tenth = alt_tenth
		if altitude_label:
			altitude_label.text = "ALT: %4.1f m" % (float(alt_tenth) / 10.0)

	# Live mission objective distance readout (cached to whole meters)
	if _has_active_mission and is_instance_valid(mission_card) and mission_card.visible and is_instance_valid(mission_detail_label) and _mission_banner_timer <= 0.0:
		if not _current_mission_base_detail.is_empty():
			mission_detail_label.text = _current_mission_base_detail
		elif is_instance_valid(_player):
			var dist_m: int = int(roundf(_player.global_position.distance_to(_active_mission_pos)))
			if dist_m != _last_mission_dist_m:
				_last_mission_dist_m = dist_m
				mission_detail_label.text = "DISTANCE: %dm" % dist_m

	# Update 3D projected screen reticle with smooth tracking
	_update_target_reticle(delta)

	# Wave banner fade
	if _banner_timer > 0.0:
		_banner_timer -= delta
		if _banner_timer <= 0.0 and wave_banner:
			wave_banner.visible = false

	# Border warning pulse
	if border_warning_banner and border_warning_banner.visible:
		var pulse: float = (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		border_warning_banner.modulate = Color(1.0, 1.0, 1.0, lerpf(0.55, 1.0, pulse))

	# Critical health pulse (both label and continuous perimeter vignette)
	if is_instance_valid(health_label) and _hull_full_timer <= 0.0 and _max_health > 0.0 and _current_health <= _max_health * 0.30:
		var hp_pulse := lerpf(0.60, 1.0, (sin(Time.get_ticks_msec() * 0.010) + 1.0) * 0.5)
		health_label.modulate = Color(1.0, 0.20, 0.20, hp_pulse)
		if damage_vignette and _damage_flash_enabled and _damage_flash_intensity > 0.0 and _current_health > 0.0:
			var base_crit_a := lerpf(0.10, 0.28, hp_pulse) * _damage_flash_intensity
			if _reduced_flashing:
				base_crit_a = minf(base_crit_a, 0.12)
			if damage_vignette.color.a < base_crit_a or (_vignette_tween and not _vignette_tween.is_valid()):
				damage_vignette.color = Color(0.88, 0.12, 0.12, base_crit_a)

	# Overheat warning strobe
	if overheat_warning and overheat_warning.visible:
		var ov_pulse: float = (sin(Time.get_ticks_msec() * 0.016) + 1.0) * 0.5
		overheat_warning.modulate = Color(1.0, 0.25, 0.25, lerpf(0.6, 1.0, ov_pulse))

	queue_redraw()

func _get_clamped_edge_position(dir_2d: Vector2, vp_rect: Rect2, margin: float = 38.0) -> Vector2:
	var vp_center := vp_rect.size * 0.5
	if dir_2d.length_squared() < 0.0001:
		return vp_center

	var dir := dir_2d.normalized()

	var min_x := margin
	var max_x := vp_rect.size.x - margin
	var min_y := margin
	var max_y := vp_rect.size.y - margin

	var t := INF
	if dir.x > 0.0001:
		t = minf(t, (max_x - vp_center.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, (min_x - vp_center.x) / dir.x)

	if dir.y > 0.0001:
		t = minf(t, (max_y - vp_center.y) / dir.y)
	elif dir.y < -0.0001:
		t = minf(t, (min_y - vp_center.y) / dir.y)

	var hit := vp_center + dir * t

	# Clearance above BottomCenterCard (centered horizontally, card width 760, clearance at y = vp_rect.size.y - 118)
	var card_half_w := 410.0
	var card_clearance_y := vp_rect.size.y - 118.0
	if dir.y > 0.05 and absf(hit.x - vp_center.x) <= card_half_w:
		var t_card := (card_clearance_y - vp_center.y) / dir.y
		if t_card > 0.0:
			hit = vp_center + dir * t_card

	hit.x = clampf(hit.x, min_x, max_x)
	hit.y = clampf(hit.y, min_y, max_y)
	return hit

func get_screen_indicator(world_pos: Vector3, cam: Camera3D, margin: float = 45.0) -> Dictionary:
	var vp_rect := get_viewport_rect()
	var vp_center := vp_rect.size * 0.5
	var is_behind := cam.is_position_behind(world_pos)
	var scr_pos := cam.unproject_position(world_pos)
	var is_offscreen := is_behind or scr_pos.x < margin or scr_pos.x > (vp_rect.size.x - margin) or scr_pos.y < margin or scr_pos.y > (vp_rect.size.y - margin)
	var dir_2d := -(scr_pos - vp_center).normalized() if is_behind else (scr_pos - vp_center).normalized()
	if dir_2d.length_squared() < 0.01:
		dir_2d = Vector2.UP
	var edge_pos := _get_clamped_edge_position(dir_2d, vp_rect, margin)
	return {
		"is_offscreen": is_offscreen,
		"is_behind": is_behind,
		"screen_pos": scr_pos,
		"edge_pos": edge_pos,
		"dir_2d": dir_2d
	}

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam or not is_instance_valid(_player):
		return

	var vp_rect := get_viewport_rect()
	var vp_center := vp_rect.size * 0.5
	var margin := 38.0

	# Priority 1: Approaching incoming enemy missiles (immediate danger)
	var incoming_missiles := get_tree().get_nodes_in_group("incoming_enemy_missiles")
	var drawn_indicators: int = 0
	const MAX_CHEVRONS: int = 6

	for m in incoming_missiles:
		if drawn_indicators >= MAX_CHEVRONS:
			break
		var m3d := m as Node3D
		if not is_instance_valid(m3d):
			continue
		var m_pos := m3d.global_position
		var is_behind := cam.is_position_behind(m_pos)
		var scr_pos := cam.unproject_position(m_pos)
		var is_offscreen := is_behind or scr_pos.x < margin or scr_pos.x > (vp_rect.size.x - margin) or scr_pos.y < margin or scr_pos.y > (vp_rect.size.y - margin)
		if is_offscreen:
			var dir_2d: Vector2 = -(scr_pos - vp_center).normalized() if is_behind else (scr_pos - vp_center).normalized()
			if dir_2d.length_squared() < 0.01:
				dir_2d = Vector2.UP
			var edge_pos: Vector2 = _get_clamped_edge_position(dir_2d, vp_rect, margin)

			# Pulsing red diamond alert for incoming homing missiles
			var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.016)
			var m_col := Color(1.0, 0.1, 0.1, pulse)
			var d_top := edge_pos + dir_2d * 14.0
			var d_bot := edge_pos - dir_2d * 6.0
			var d_l := edge_pos + Vector2(-dir_2d.y, dir_2d.x) * 8.0
			var d_r := edge_pos - Vector2(-dir_2d.y, dir_2d.x) * 8.0
			var d_pts := PackedVector2Array([d_top, d_r, d_bot, d_l])
			if _high_contrast_indicators:
				draw_polyline(PackedVector2Array([d_top, d_r, d_bot, d_l, d_top]), Color(0.02, 0.04, 0.06, 0.95), 2.5)
			draw_colored_polygon(d_pts, m_col)
			drawn_indicators += 1

	# Priority 2: Imminent enemy threats (bosses, SAM sites, telegraphing/committed attackers)
	var raw_candidates: Array[Node3D] = []
	if EnemyRegistry.instance:
		raw_candidates = EnemyRegistry.instance.get_enemies_in_radius(_player.global_position, 85.0, 16)
	else:
		var raw_threats := get_tree().get_nodes_in_group("enemies")
		for th in raw_threats:
			var th3d := th as Node3D
			if is_instance_valid(th3d) and th3d != _player:
				raw_candidates.append(th3d)
				if raw_candidates.size() >= 16:
					break

	var prioritized_threats: Array[Node3D] = []
	for candidate in raw_candidates:
		if not is_instance_valid(candidate) or candidate == _player:
			continue
		var is_boss: bool = candidate.is_in_group("bosses")
		var is_sam: bool = candidate.is_in_group("sam_sites")
		var is_attacking: bool = (candidate.get("_has_attack_slot") == true) or (candidate.get("_has_air_slot") == true) or (candidate.get("_is_telegraphing") == true)
		var is_close: bool = _player.global_position.distance_to(candidate.global_position) < 32.0

		if is_boss or is_sam or is_attacking or is_close:
			prioritized_threats.append(candidate)

	for th3d in prioritized_threats:
		if drawn_indicators >= MAX_CHEVRONS:
			break
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
			var edge_pos: Vector2 = _get_clamped_edge_position(dir_2d, vp_rect, margin)

			var col := Color(1.0, 0.35, 0.2, 0.85)
			if th3d.is_in_group("bosses"):
				col = Color(1.0, 0.1, 0.1, 1.0)
			elif th3d.is_in_group("sam_sites"):
				col = Color(1.0, 0.6, 0.1, 0.9)

			# Draw chevron pointing outward
			var tip := edge_pos + dir_2d * 12.0
			var side_a := edge_pos - dir_2d * 8.0 + Vector2(-dir_2d.y, dir_2d.x) * 8.0
			var side_b := edge_pos - dir_2d * 8.0 - Vector2(-dir_2d.y, dir_2d.x) * 8.0
			if _high_contrast_indicators:
				var outline := PackedVector2Array([tip, side_a, side_b, tip])
				draw_polyline(outline, Color(0.02, 0.04, 0.06, 0.95), 2.5)
			draw_colored_polygon(PackedVector2Array([tip, side_a, side_b]), col)
			drawn_indicators += 1

	# Draw active mission objective indicator
	if _has_active_mission:
		var obj_pos := _active_mission_pos + Vector3(0, 1.5, 0)
		var obj_behind := cam.is_position_behind(obj_pos)
		var obj_scr := cam.unproject_position(obj_pos)
		var obj_offscreen := obj_behind or obj_scr.x < margin or obj_scr.x > (vp_rect.size.x - margin) or obj_scr.y < margin or obj_scr.y > (vp_rect.size.y - margin)
		var obj_col := Color(0.2, 0.95, 0.85, 0.95)

		if obj_offscreen:
			var obj_dir_2d := -(obj_scr - vp_center).normalized() if obj_behind else (obj_scr - vp_center).normalized()
			if obj_dir_2d.length_squared() < 0.01:
				obj_dir_2d = Vector2.UP
			var obj_edge := _get_clamped_edge_position(obj_dir_2d, vp_rect, margin)
			var d_top := obj_edge + obj_dir_2d * 14.0
			var d_bot := obj_edge - obj_dir_2d * 6.0
			var d_l := obj_edge + Vector2(-obj_dir_2d.y, obj_dir_2d.x) * 9.0
			var d_r := obj_edge - Vector2(-obj_dir_2d.y, obj_dir_2d.x) * 9.0
			var d_pts := PackedVector2Array([d_top, d_r, d_bot, d_l])
			if _high_contrast_indicators:
				draw_polyline(PackedVector2Array([d_top, d_r, d_bot, d_l, d_top]), Color(0.02, 0.04, 0.06, 0.95), 3.0)
			draw_colored_polygon(d_pts, obj_col)
		else:
			var rad := 12.0
			var d_top := obj_scr + Vector2(0, -rad)
			var d_r := obj_scr + Vector2(rad, 0)
			var d_bot := obj_scr + Vector2(0, rad)
			var d_l := obj_scr + Vector2(-rad, 0)
			if _high_contrast_indicators:
				draw_polyline(PackedVector2Array([d_top, d_r, d_bot, d_l, d_top]), Color(0.02, 0.04, 0.06, 0.95), 3.0)
			draw_polyline(PackedVector2Array([d_top, d_r, d_bot, d_l, d_top]), obj_col, 2.0)

	# Priority 3: Stranded Survivors (Rescue Winch targets)
	var survivors := get_tree().get_nodes_in_group("survivors")
	for s in survivors:
		var s_node := s as Node3D
		if not is_instance_valid(s_node):
			continue
		if s_node.get("current_state") == 2: # State.RESCUED
			continue

		var s_pos := s_node.global_position + Vector3(0, 1.0, 0)
		var s_behind := cam.is_position_behind(s_pos)
		var s_scr := cam.unproject_position(s_pos)
		var s_dist := _player.global_position.distance_to(s_node.global_position)
		var is_offscreen := s_behind or s_scr.x < margin or s_scr.x > (vp_rect.size.x - margin) or s_scr.y < margin or s_scr.y > (vp_rect.size.y - margin)
		var pulse := 0.80 + 0.20 * sin(Time.get_ticks_msec() * 0.010)
		var s_col := Color(0.20, 0.98, 0.45, pulse)

		if is_offscreen:
			var s_dir := -(s_scr - vp_center).normalized() if s_behind else (s_scr - vp_center).normalized()
			if s_dir.length_squared() < 0.01:
				s_dir = Vector2.UP
			var edge_pos := _get_clamped_edge_position(s_dir, vp_rect, margin)

			var tip := edge_pos + s_dir * 14.0
			var side_a := edge_pos - s_dir * 8.0 + Vector2(-s_dir.y, s_dir.x) * 9.0
			var side_b := edge_pos - s_dir * 8.0 - Vector2(-s_dir.y, s_dir.x) * 9.0
			var poly := PackedVector2Array([tip, side_a, side_b])

			if _high_contrast_indicators:
				var outline := PackedVector2Array([tip, side_a, side_b, tip])
				draw_polyline(outline, Color(0.02, 0.04, 0.06, 0.95), 3.0)
			draw_colored_polygon(poly, s_col)

			var font := _get_hud_font()
			if font:
				var txt := "RESCUE %dm" % int(s_dist)
				var lbl_pos := edge_pos - s_dir * 22.0
				var box_pos := lbl_pos - Vector2(36.0, 8.0)
				box_pos.x = clampf(box_pos.x, margin * 0.5, vp_rect.size.x - margin * 0.5 - 72.0)
				box_pos.y = clampf(box_pos.y, margin * 0.5, vp_rect.size.y - margin * 0.5 - 16.0)
				draw_rect(Rect2(box_pos, Vector2(72, 16)), Color(0.02, 0.05, 0.08, 0.80), true)
				draw_string(font, box_pos + Vector2(0, 12.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 72, 11, Color(0.35, 1.0, 0.6))
		else:
			var rad := 14.0
			var d_top := s_scr + Vector2(0, -rad)
			var d_r := s_scr + Vector2(rad, 0)
			var d_bot := s_scr + Vector2(0, rad)
			var d_l := s_scr + Vector2(-rad, 0)
			var poly := PackedVector2Array([d_top, d_r, d_bot, d_l, d_top])
			if _high_contrast_indicators:
				draw_polyline(poly, Color(0.02, 0.04, 0.06, 0.95), 3.0)
			draw_polyline(poly, s_col, 2.0)

			draw_line(s_scr + Vector2(-4, 0), s_scr + Vector2(4, 0), s_col, 1.5)
			draw_line(s_scr + Vector2(0, -4), s_scr + Vector2(0, 4), s_col, 1.5)

			var font := _get_hud_font()
			if font:
				var txt := "SURVIVOR %dm" % int(s_dist)
				var txt_pos := s_scr + Vector2(-36.0, rad + 14.0)
				draw_rect(Rect2(txt_pos - Vector2(2, 10), Vector2(74, 15)), Color(0.02, 0.05, 0.08, 0.70))
				draw_string(font, txt_pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 70, 11, Color(0.35, 1.0, 0.6))

	# Priority 4: Battlefield Crates (Salvage & Ammo Pickups)
	var crates: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("salvage_crates"):
		var n3d := node as Node3D
		if is_instance_valid(n3d) and n3d.get("_is_collected") != true:
			crates.append(n3d)
	for node in get_tree().get_nodes_in_group("missile_pickups"):
		var n3d := node as Node3D
		if is_instance_valid(n3d) and n3d.get("_is_collected") != true:
			crates.append(n3d)

	crates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _player.global_position.distance_squared_to(a.global_position) < _player.global_position.distance_squared_to(b.global_position)
	)

	var drawn_crates: int = 0
	for crate in crates:
		if drawn_crates >= 4:
			break
		var c_dist := _player.global_position.distance_to(crate.global_position)
		if c_dist > 120.0:
			break

		var is_salvage := crate.is_in_group("salvage_crates")
		var c_col := Color(1.0, 0.80, 0.20, 0.85) if is_salvage else Color(0.30, 0.90, 1.0, 0.85)
		var c_tag := "SALVAGE" if is_salvage else "AMMO"
		var c_pos := crate.global_position + Vector3(0, 0.6, 0)
		var c_behind := cam.is_position_behind(c_pos)
		var c_scr := cam.unproject_position(c_pos)
		var is_offscreen := c_behind or c_scr.x < margin or c_scr.x > (vp_rect.size.x - margin) or c_scr.y < margin or c_scr.y > (vp_rect.size.y - margin)

		if is_offscreen:
			var c_dir := -(c_scr - vp_center).normalized() if c_behind else (c_scr - vp_center).normalized()
			if c_dir.length_squared() < 0.01:
				c_dir = Vector2.UP
			var edge_pos := _get_clamped_edge_position(c_dir, vp_rect, margin)

			var tip := edge_pos + c_dir * 10.0
			var side_a := edge_pos - c_dir * 6.0 + Vector2(-c_dir.y, c_dir.x) * 6.0
			var side_b := edge_pos - c_dir * 6.0 - Vector2(-c_dir.y, c_dir.x) * 6.0
			var poly := PackedVector2Array([tip, side_a, side_b])
			if _high_contrast_indicators:
				draw_polyline(PackedVector2Array([tip, side_a, side_b, tip]), Color(0.02, 0.04, 0.06, 0.95), 2.5)
			draw_colored_polygon(poly, c_col)

			var font := _get_hud_font()
			if font:
				var txt := "%s %dm" % [c_tag, int(c_dist)]
				var lbl_pos := edge_pos - c_dir * 18.0
				var box_pos := lbl_pos - Vector2(30.0, 7.0)
				box_pos.x = clampf(box_pos.x, margin * 0.5, vp_rect.size.x - margin * 0.5 - 62.0)
				box_pos.y = clampf(box_pos.y, margin * 0.5, vp_rect.size.y - margin * 0.5 - 14.0)
				draw_rect(Rect2(box_pos, Vector2(62, 14)), Color(0.02, 0.05, 0.08, 0.75), true)
				draw_string(font, box_pos + Vector2(0, 11.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 62, 10, c_col)
			drawn_crates += 1
		else:
			var half := 8.0
			var box_rect := Rect2(c_scr - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
			if _high_contrast_indicators:
				draw_rect(box_rect.grow(1.0), Color(0.02, 0.04, 0.06, 0.95), false, 2.0)
			draw_rect(box_rect, c_col, false, 1.5)

			var font := _get_hud_font()
			if font and c_dist > 6.0:
				var txt := "%s %dm" % [c_tag, int(c_dist)]
				var txt_pos := c_scr + Vector2(-28.0, half + 12.0)
				draw_rect(Rect2(txt_pos - Vector2(2, 10), Vector2(60, 13)), Color(0.02, 0.05, 0.08, 0.65))
				draw_string(font, txt_pos, txt, HORIZONTAL_ALIGNMENT_CENTER, 56, 10, c_col)
			drawn_crates += 1

	# Priority 5: World Encounters & Tactical Rewards (Supply Stops, Guarded Caches, Beacons)
	var encounters := get_tree().get_nodes_in_group("world_encounters")
	for enc in encounters:
		var enc3d := enc as Node3D
		if not is_instance_valid(enc3d) or enc3d.is_queued_for_deletion():
			continue
		if enc3d.get("is_completed") == true:
			continue

		var dist := _player.global_position.distance_to(enc3d.global_position)
		if dist > 180.0:
			continue

		var enc_type: String = "SUPPLY"
		if enc3d.has_method("get_encounter_display_type"):
			enc_type = enc3d.get_encounter_display_type()

		var enc_status: String = ""
		if enc3d.has_method("get_encounter_status_text"):
			enc_status = enc3d.get_encounter_status_text()

		var enc_color: Color = Color(0.9, 0.75, 0.15, 1.0)
		if enc3d.has_method("get_encounter_color"):
			enc_color = enc3d.get_encounter_color()

		var enc_pos := enc3d.global_position + Vector3(0, 1.5, 0)
		if cam.global_position.distance_squared_to(enc_pos) < 0.5:
			continue
		var is_behind := cam.is_position_behind(enc_pos)
		var scr_pos := cam.unproject_position(enc_pos)
		var is_offscreen := is_behind or scr_pos.x < margin or scr_pos.x > (vp_rect.size.x - margin) or scr_pos.y < margin or scr_pos.y > (vp_rect.size.y - margin)

		var label_text := "%s %dm" % [enc_type, int(dist)]
		if not enc_status.is_empty() and enc_status != enc_type:
			label_text = "%s [%s] %dm" % [enc_type, enc_status, int(dist)]

		if is_offscreen:
			var dir_2d := -(scr_pos - vp_center).normalized() if is_behind else (scr_pos - vp_center).normalized()
			if dir_2d.length_squared() < 0.01:
				dir_2d = Vector2.UP
			var edge_pos := _get_clamped_edge_position(dir_2d, vp_rect, margin)

			var tip := edge_pos + dir_2d * 13.0
			var side_a := edge_pos - dir_2d * 7.0 + Vector2(-dir_2d.y, dir_2d.x) * 8.0
			var side_b := edge_pos - dir_2d * 7.0 - Vector2(-dir_2d.y, dir_2d.x) * 8.0
			var poly := PackedVector2Array([tip, side_a, side_b])

			if _high_contrast_indicators:
				var outline := PackedVector2Array([tip, side_a, side_b, tip])
				draw_polyline(outline, Color(0.02, 0.04, 0.06, 0.95), 3.0)
			draw_colored_polygon(poly, enc_color)

			var font := _get_hud_font()
			if font:
				var lbl_pos := edge_pos - dir_2d * 20.0
				var box_w := clampf(float(label_text.length()) * 7.0 + 16.0, 70.0, 140.0)
				var box_pos := lbl_pos - Vector2(box_w * 0.5, 8.0)
				box_pos.x = clampf(box_pos.x, margin * 0.5, vp_rect.size.x - margin * 0.5 - box_w)
				box_pos.y = clampf(box_pos.y, margin * 0.5, vp_rect.size.y - margin * 0.5 - 16.0)
				draw_rect(Rect2(box_pos, Vector2(box_w, 16)), Color(0.02, 0.05, 0.08, 0.82), true)
				draw_string(font, box_pos + Vector2(0, 12.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, int(box_w), 11, enc_color)
		else:
			# On-screen bracket reticle with corner ticks
			var rad := 16.0
			var tick := 6.0
			# Top-left corner
			draw_line(scr_pos + Vector2(-rad, -rad), scr_pos + Vector2(-rad + tick, -rad), enc_color, 2.0)
			draw_line(scr_pos + Vector2(-rad, -rad), scr_pos + Vector2(-rad, -rad + tick), enc_color, 2.0)
			# Top-right corner
			draw_line(scr_pos + Vector2(rad, -rad), scr_pos + Vector2(rad - tick, -rad), enc_color, 2.0)
			draw_line(scr_pos + Vector2(rad, -rad), scr_pos + Vector2(rad, -rad + tick), enc_color, 2.0)
			# Bottom-left corner
			draw_line(scr_pos + Vector2(-rad, rad), scr_pos + Vector2(-rad + tick, rad), enc_color, 2.0)
			draw_line(scr_pos + Vector2(-rad, rad), scr_pos + Vector2(-rad, rad - tick), enc_color, 2.0)
			# Bottom-right corner
			draw_line(scr_pos + Vector2(rad, rad), scr_pos + Vector2(rad - tick, rad), enc_color, 2.0)
			draw_line(scr_pos + Vector2(rad, rad), scr_pos + Vector2(rad, rad - tick), enc_color, 2.0)

			# Central reticle pip
			draw_circle(scr_pos, 2.5, enc_color)

			var font := _get_hud_font()
			if font and dist > 5.0:
				var box_w := clampf(float(label_text.length()) * 7.0 + 16.0, 70.0, 140.0)
				var txt_pos := scr_pos + Vector2(-box_w * 0.5, rad + 14.0)
				draw_rect(Rect2(txt_pos - Vector2(2, 10), Vector2(box_w, 15)), Color(0.02, 0.05, 0.08, 0.75))
				draw_string(font, txt_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, int(box_w), 11, enc_color)

	# Directional damage indicator arc wedges pointing toward damage sources
	var cue_radius := 145.0
	for cue in _damage_cues:
		if not _damage_flash_enabled or _damage_flash_intensity <= 0.0:
			continue
		var alpha := clampf(cue.timer / maxf(cue.max_time, 0.01), 0.0, 1.0) * _damage_flash_intensity
		if _reduced_flashing:
			alpha = minf(alpha, 0.25)
		var col := Color(0.2, 0.85, 1.0, alpha * 0.9) if cue.is_shield else Color(1.0, 0.22, 0.18, alpha * 0.9)
		var base_angle := cue.dir_2d.angle()
		var half_span := deg_to_rad(22.0)
		var arc_pts: Array[Vector2] = []
		var inner_pts: Array[Vector2] = []
		var segments := 8
		for i in range(segments + 1):
			var a: float = base_angle - half_span + (float(i) / float(segments)) * (half_span * 2.0)
			var dir := Vector2(cos(a), sin(a))
			arc_pts.append(vp_center + dir * (cue_radius + 14.0))
			inner_pts.append(vp_center + dir * cue_radius)
		inner_pts.reverse()
		var poly_pts := PackedVector2Array()
		for p in arc_pts:
			poly_pts.append(p)
		for p in inner_pts:
			poly_pts.append(p)
		if _high_contrast_indicators:
			var outline_pts := poly_pts.duplicate()
			outline_pts.append(poly_pts[0])
			draw_polyline(outline_pts, Color(0.02, 0.04, 0.06, alpha * 0.95), 2.5)
		draw_colored_polygon(poly_pts, col)

	# Priority 5: Target Reticle Classification & Missile Lock-On HUD Feedback
	if target_reticle and target_reticle.visible and not _is_manual_aim and is_instance_valid(_current_target) and not _current_target.is_queued_for_deletion():
		var r_center: Vector2 = target_reticle.position + target_reticle.size * 0.5
		var font := _get_hud_font()

		# Target category / role readout
		var role_tag := "HOSTILE"
		var role_col := Color(1.0, 0.35, 0.35, 0.95)
		if _current_target.is_in_group("bosses"):
			role_tag = "[ BOSS ]"
			role_col = Color(1.0, 0.15, 0.15, 1.0)
		elif _current_target.is_in_group("sam_sites"):
			role_tag = "[ SAM SITE ]"
			role_col = Color(1.0, 0.55, 0.15, 1.0)
		elif _current_target.is_in_group("turrets"):
			role_tag = "[ TURRET ]"
			role_col = Color(1.0, 0.75, 0.20, 0.95)
		elif _current_target.is_in_group("tanks") or _current_target.is_in_group("armored_enemies"):
			role_tag = "[ ARMOR ]"
			role_col = Color(1.0, 0.85, 0.30, 0.95)
		elif _current_target.is_in_group("rocket_raiders"):
			role_tag = "[ RAIDER ]"
			role_col = Color(1.0, 0.40, 0.25, 0.95)
		elif _current_target.is_in_group("attack_gunships") or _current_target.is_in_group("ace_gunships"):
			role_tag = "[ GUNSHIP ]"
			role_col = Color(0.95, 0.35, 0.60, 0.95)
		elif _current_target.is_in_group("air_enemies"):
			role_tag = "[ AIR ]"
			role_col = Color(0.35, 0.85, 1.0, 0.95)

		if font:
			draw_string(font, r_center + Vector2(-45, -22), role_tag, HORIZONTAL_ALIGNMENT_CENTER, 90, 11, role_col)

		# Missile lock state visualization
		if _is_missile_locked:
			var lock_col := Color(0.25, 1.0, 0.55, 1.0)
			var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.015)
			lock_col.a = pulse

			# Locked diamond frame
			var d_top := r_center + Vector2(0, -25)
			var d_r := r_center + Vector2(25, 0)
			var d_bot := r_center + Vector2(0, 25)
			var d_l := r_center + Vector2(-25, 0)
			var lock_diamond := PackedVector2Array([d_top, d_r, d_bot, d_l, d_top])
			if _high_contrast_indicators:
				draw_polyline(lock_diamond, Color(0.02, 0.04, 0.06, 0.95), 3.0)
			draw_polyline(lock_diamond, lock_col, 2.0)

			if font:
				draw_string(font, r_center + Vector2(-50, 36), "[ LOCKED ]", HORIZONTAL_ALIGNMENT_CENTER, 100, 11, lock_col)
		elif _last_lock_progress > 0.05:
			var ring_col := Color(1.0, 0.78, 0.22, 0.9)
			if _is_jammed:
				ring_col = Color(1.0, 0.45, 0.20, 0.9)
			var start_ang := -PI * 0.5
			var end_ang := start_ang + TAU * clampf(_last_lock_progress, 0.0, 1.0)
			draw_arc(r_center, 23.0, start_ang, end_ang, 28, ring_col, 2.0, false)

			if font:
				var lock_txt := "LOCK %d%%" % int(_last_lock_progress * 100.0)
				if _is_jammed:
					lock_txt = "JAMMED %d%%" % int(_last_lock_progress * 100.0)
				draw_string(font, r_center + Vector2(-45, 34), lock_txt, HORIZONTAL_ALIGNMENT_CENTER, 90, 10, ring_col)

func _update_target_reticle(delta: float = 0.0) -> void:
	if not target_reticle:
		return

	var cam := get_viewport().get_camera_3d()
	if not cam:
		target_reticle.visible = false
		return

	var target_3d_pos := Vector3.ZERO
	var has_valid_pos := false
	var is_manual := _is_manual_aim

	if is_manual:
		if not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(_player):
			var ts = _player.get_node_or_null("TargetingSystem")
			if ts and ts.is_manual_aim and ts.manual_aim_point != Vector3.ZERO:
				target_3d_pos = ts.manual_aim_point
				has_valid_pos = true
	elif is_instance_valid(_current_target) and not _current_target.is_queued_for_deletion():
		target_3d_pos = _current_target.global_position + Vector3(0, 0.8, 0)
		has_valid_pos = true

	if not has_valid_pos or cam.is_position_behind(target_3d_pos):
		target_reticle.visible = false
		return

	var screen_pos: Vector2 = cam.unproject_position(target_3d_pos)
	var target_screen_pos: Vector2 = screen_pos - (target_reticle.size * 0.5)

	# Update reticle color: Amber for manual aim, Emerald for locked, Gold for locking, Crimson for auto-track
	var reticle_color: Color = Color(1.0, 0.75, 0.18, 0.95)
	if not is_manual:
		if _is_missile_locked:
			reticle_color = Color(0.25, 0.98, 0.55, 1.0)
		elif _last_lock_progress > 0.05:
			reticle_color = Color(1.0, 0.82, 0.22, 1.0)
		else:
			reticle_color = Color(1.0, 0.2, 0.2, 0.9)

	for child in target_reticle.get_children():
		if child is ColorRect:
			(child as ColorRect).color = reticle_color

	if not target_reticle.visible:
		target_reticle.visible = true
		target_reticle.position = target_screen_pos
	else:
		var smooth_weight: float = clampf(delta * 28.0, 0.0, 1.0) if delta > 0.0 else 1.0
		target_reticle.position = target_reticle.position.lerp(target_screen_pos, smooth_weight)

func _on_health_changed(current: float, maximum: float) -> void:
	_current_health = current
	_max_health = maximum
	if health_bar:
		health_bar.max_value = maximum
		if _health_tween:
			_health_tween.kill()
		_health_tween = create_tween()
		_health_tween.tween_property(health_bar, "value", current, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_update_health_label_display()

	if current < _prev_health and damage_vignette:
		if not _damage_flash_enabled or _damage_flash_intensity <= 0.0:
			damage_vignette.color.a = 0.0
		else:
			var vignette_alpha := 0.32 * _damage_flash_intensity
			var fade_time := 0.45
			if current <= maximum * 0.30:
				vignette_alpha = (0.22 if _reduced_flashing else 0.55) * _damage_flash_intensity
			if _reduced_flashing:
				vignette_alpha = minf(vignette_alpha, 0.16)
				fade_time = 0.65
			damage_vignette.color = Color(0.88, 0.12, 0.12, vignette_alpha)
			if _vignette_tween:
				_vignette_tween.kill()
			_vignette_tween = create_tween()
			_vignette_tween.tween_property(damage_vignette, "color:a", 0.0, fade_time)

	_prev_health = current

func _update_health_label_display() -> void:
	if not health_label:
		return
	if _hull_full_timer > 0.0:
		health_label.text = "HULL: %d / %d  HULL FULL" % [int(_current_health), int(_max_health)]
		health_label.modulate = Color(0.20, 0.85, 0.45)
		return
	if _current_health <= _max_health * 0.30:
		health_label.text = "HULL: %d / %d  [!] CRITICAL" % [int(_current_health), int(_max_health)]
		health_label.modulate = Color(1.0, 0.20, 0.20)
	elif _current_health <= _max_health * 0.50:
		health_label.text = "HULL: %d / %d" % [int(_current_health), int(_max_health)]
		health_label.modulate = Color(1.0, 0.65, 0.15)
	else:
		health_label.text = "HULL: %d / %d" % [int(_current_health), int(_max_health)]
		health_label.modulate = Color(0.20, 0.85, 0.45)

func _on_hull_full_notified() -> void:
	_hull_full_timer = 1.2
	_update_health_label_display()

func _on_ammo_full_notified() -> void:
	_ammo_full_timer = 1.2
	_update_missile_status_display()

func _on_heat_changed(current: float, maximum: float, is_overheated: bool) -> void:
	var player_node: Node = _player if is_instance_valid(_player) else get_tree().get_first_node_in_group("player")
	var is_hellfire := false
	var is_ap_ric := false
	var is_siege := false
	var is_spread := false
	if is_instance_valid(player_node) and "chaingun" in player_node and is_instance_valid(player_node.chaingun):
		var cg: Node = player_node.chaingun
		is_hellfire = bool(cg.get("is_hellfire_active"))
		is_ap_ric = bool(cg.get("is_ap_ricochet_active"))
		is_siege = bool(cg.get("is_siege_active"))
		is_spread = int(cg.get("multishot_count")) > 1

	if heat_bar:
		heat_bar.max_value = maximum
		if _heat_tween:
			_heat_tween.kill()
		_heat_tween = create_tween()
		_heat_tween.tween_property(heat_bar, "value", current, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		heat_bar.visible = current > 0.05 and not is_hellfire
		if is_overheated:
			heat_bar.modulate = Color(1.0, 0.25, 0.25)
		elif maximum > 0.0 and current >= maximum * 0.80:
			heat_bar.modulate = Color(1.0, 0.55, 0.15)
		else:
			heat_bar.modulate = Color(1.0, 1.0, 1.0)

	if overheat_warning:
		if is_hellfire:
			overheat_warning.text = "🔥 HELLFIRE MINIGUN // OVERHEAT IMMUNE 🔥"
			overheat_warning.modulate = Color(1.0, 0.80, 0.2)
			overheat_warning.visible = true
		elif is_ap_ric:
			overheat_warning.text = "⚡ AP RICOCHET CANNON // +2 PIERCE ⚡"
			overheat_warning.modulate = Color(0.3, 0.9, 1.0)
			overheat_warning.visible = current > 0.15 or is_overheated
		elif is_siege:
			overheat_warning.text = "💥 SIEGE CANNON // HEAVY AP 💥"
			overheat_warning.modulate = Color(1.0, 0.65, 0.25)
			overheat_warning.visible = current > 0.15 or is_overheated
		elif is_overheated:
			overheat_warning.text = "CHAINGUN OVERHEATED - 2.5s LOCKOUT"
			overheat_warning.modulate = Color(1.0, 0.25, 0.25)
			overheat_warning.visible = true
		else:
			overheat_warning.visible = false

	if aim_mode_label and is_spread:
		if not aim_mode_label.text.contains("2-SPREAD"):
			aim_mode_label.text = "AIM: 2-ROUND SPREAD"

func _update_missile_status_display() -> void:
	if not missile_status:
		return

	var pips := ""
	for i in range(_max_missiles):
		pips += "▮" if i < _missile_ammo else "▯"

	var mode_tag := ""
	var player_node: Node = _player if is_instance_valid(_player) else get_tree().get_first_node_in_group("player")
	if is_instance_valid(player_node) and "missile_pod" in player_node and is_instance_valid(player_node.missile_pod):
		var pod: Node = player_node.missile_pod
		if pod.get("is_swarm_rockets") == true:
			mode_tag = "  [SWARM 6x]"
		elif pod.get("is_multi_lock") == true:
			mode_tag = "  [MULTI-LOCK]"
		elif int(pod.get("multi_launch_count")) > 1:
			mode_tag = "  [SALVO x%d]" % int(pod.get("multi_launch_count"))
		elif float(pod.get("lock_duration")) < 0.6:
			mode_tag = "  [RAPID]"

	if _missile_warning_timer > 0.0:
		missile_status.text = "MISSILES  %d / %d   %s   NO MISSILES%s" % [_missile_ammo, _max_missiles, pips, mode_tag]
		missile_status.modulate = Color(1.0, 0.25, 0.25)
		return

	if _ammo_full_timer > 0.0:
		missile_status.text = "MISSILES  %d / %d   %s   FULL%s" % [_missile_ammo, _max_missiles, pips, mode_tag]
		missile_status.modulate = Color(1.0, 0.75, 0.20)
		return

	if _missile_ammo <= 0:
		missile_status.text = "MISSILES  0 / %d   %s   EMPTY%s" % [_max_missiles, pips, mode_tag]
		missile_status.modulate = Color(0.85, 0.35, 0.35)
		return

	var jam_suffix := "  EW JAMMED" if _is_jammed else ""
	if _is_missile_locked:
		missile_status.text = "MISSILES  %d / %d   %s   LOCKED%s%s" % [_missile_ammo, _max_missiles, pips, mode_tag, jam_suffix]
		missile_status.modulate = Color(0.25, 0.95, 0.55)
	elif _last_lock_progress > 0.05:
		missile_status.text = "MISSILES  %d / %d   %s   LOCKING %d%%%s%s" % [_missile_ammo, _max_missiles, pips, int(_last_lock_progress * 100.0), jam_suffix, mode_tag]
		missile_status.modulate = Color(1.0, 0.50, 0.15) if _is_jammed else Color(1.0, 0.78, 0.22)
	else:
		missile_status.text = "MISSILES  %d / %d   %s   READY%s%s" % [_missile_ammo, _max_missiles, pips, jam_suffix, mode_tag]
		missile_status.modulate = Color(1.0, 0.55, 0.15) if _is_jammed else Color(0.88, 0.94, 1.0)

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
		missile_bar.visible = progress > 0.02
	_update_missile_status_display()

func _on_jammer_status_changed(is_jammed: bool, _count: int) -> void:
	_is_jammed = is_jammed

func _on_flares_updated(charges_left: int, max_charges: int, is_ready: bool) -> void:
	if flares_bar:
		flares_bar.max_value = max_charges
		if _flares_tween:
			_flares_tween.kill()
		_flares_tween = create_tween()
		_flares_tween.tween_property(flares_bar, "value", float(charges_left), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if not is_ready and charges_left < max_charges:
			flares_bar.modulate = Color(1.0, 0.65, 0.15)
		elif charges_left <= 0:
			flares_bar.modulate = Color(0.85, 0.35, 0.35)
		else:
			flares_bar.modulate = Color(0.30, 0.88, 0.95)

	if not flares_label:
		return
	var pips := ""
	for i in range(max_charges):
		pips += "◆" if i < charges_left else "◇"
	if not is_ready and charges_left < max_charges:
		flares_label.text = "FLARES [X]  %d/%d   %s   RECHARGING" % [charges_left, max_charges, pips]
		flares_label.modulate = Color(1.0, 0.65, 0.15)
	elif charges_left <= 0:
		flares_label.text = "FLARES [X]  0/%d   %s   DEPLETED" % [max_charges, pips]
		flares_label.modulate = Color(0.85, 0.35, 0.35)
	else:
		flares_label.text = "FLARES [X]  %d/%d   %s   READY" % [charges_left, max_charges, pips]
		flares_label.modulate = Color(0.30, 0.88, 0.95)

func _on_missile_warning(_source_pos: Vector3, is_active: bool) -> void:
	if missile_warning_panel:
		missile_warning_panel.visible = is_active
		if is_active:
			missile_warning_panel.modulate = Color(1.0, 0.15, 0.1, 1.0)

func _on_xp_updated(current: int, needed: int, level: int) -> void:
	if xp_bar:
		xp_bar.max_value = maxf(1.0, float(needed))
		var target_val := clampf(float(current), 0.0, xp_bar.max_value)
		if is_inside_tree() and xp_bar.value != target_val and xp_bar.is_node_ready():
			var tw := create_tween()
			tw.tween_property(xp_bar, "value", target_val, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(xp_bar, "modulate", Color(1.3, 1.3, 1.1, 1.0), 0.06)
			tw.tween_property(xp_bar, "modulate", Color.WHITE, 0.08)
		else:
			xp_bar.value = target_val
	if level_label:
		level_label.text = "LVL %d" % level

func _on_wave_started(wave_num: int, announcement: String) -> void:
	if wave_label:
		wave_label.text = "STAGE %d" % wave_num
	if wave_banner:
		var wave_hud := get_tree().get_first_node_in_group("wave_hud")
		if wave_hud:
			wave_banner.visible = false
		else:
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
	if attack_run_banner:
		attack_run_banner.visible = false
	if combo_bar:
		combo_bar.modulate = Color.WHITE

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

func _setup_mission_card() -> void:
	if not mission_card:
		mission_card = find_child("MissionCard", true, false) as PanelContainer
	if mission_card:
		if not mission_title_label:
			mission_title_label = mission_card.find_child("MissionTitleLabel", true, false) as Label
		if not mission_detail_label:
			mission_detail_label = mission_card.find_child("MissionDetailLabel", true, false) as Label
		return

	mission_card = PanelContainer.new()
	mission_card.name = "MissionCard"
	mission_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission_card.offset_left = 16.0
	mission_card.offset_top = 132.0
	mission_card.offset_right = 296.0
	mission_card.offset_bottom = 188.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.82)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.24, 0.38, 0.48, 0.65)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	mission_card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	mission_card.add_child(vbox)

	mission_title_label = Label.new()
	mission_title_label.name = "MissionTitleLabel"
	mission_title_label.text = "STRIKE MISSION"
	mission_title_label.add_theme_font_size_override("font_size", 13)
	mission_title_label.modulate = Color(0.22, 0.98, 0.82)
	vbox.add_child(mission_title_label)

	mission_detail_label = Label.new()
	mission_detail_label.name = "MissionDetailLabel"
	mission_detail_label.text = "STANDBY"
	mission_detail_label.add_theme_font_size_override("font_size", 12)
	mission_detail_label.modulate = Color(1.0, 0.85, 0.3)
	vbox.add_child(mission_detail_label)

	add_child(mission_card)
	mission_card.visible = false

func _on_mission_started(_id: String, title: String, _desc: String, pos: Vector3) -> void:
	if not mission_card:
		_setup_mission_card()
	if mission_card:
		mission_card.visible = true
	if mission_title_label:
		mission_title_label.text = title
		mission_title_label.modulate = Color(0.22, 0.98, 0.82)
	_current_mission_base_detail = "OBJECTIVE ACTIVE"
	if mission_detail_label:
		mission_detail_label.text = _current_mission_base_detail
		mission_detail_label.modulate = Color(1.0, 1.0, 1.0)
	_mission_banner_timer = 0.0
	_has_active_mission = true
	_active_mission_pos = pos
	_active_mission_title = title
	queue_redraw()

func _on_mission_updated(_id: String, title: String, detail_text: String, _progress: float) -> void:
	if not mission_card:
		_setup_mission_card()
	if mission_card and _mission_banner_timer <= 0.0:
		mission_card.visible = true
	if mission_title_label and _mission_banner_timer <= 0.0:
		mission_title_label.text = title
		mission_title_label.modulate = Color(0.22, 0.98, 0.82)
	_current_mission_base_detail = detail_text
	if mission_detail_label and _mission_banner_timer <= 0.0:
		mission_detail_label.text = detail_text
		mission_detail_label.modulate = Color(1.0, 0.85, 0.3)
	queue_redraw()

func _on_mission_completed(_id: String, title: String, reward_text: String) -> void:
	if not mission_card:
		_setup_mission_card()
	if mission_card:
		mission_card.visible = true
	if mission_title_label:
		mission_title_label.text = "%s // COMPLETE" % title
		mission_title_label.modulate = Color(0.3, 1.0, 0.45)
	if mission_detail_label:
		mission_detail_label.text = reward_text
		mission_detail_label.modulate = Color(1.0, 0.9, 0.4)
	_mission_banner_timer = 3.5
	_has_active_mission = false
	_active_mission_pos = Vector3.ZERO
	queue_redraw()

func _on_mission_failed(_id: String, title: String, reason: String) -> void:
	if not mission_card:
		_setup_mission_card()
	if mission_card:
		mission_card.visible = true
	if mission_title_label:
		mission_title_label.text = "%s // FAILED" % title
		mission_title_label.modulate = Color(1.0, 0.35, 0.35)
	if mission_detail_label:
		mission_detail_label.text = reason if not reason.is_empty() else "TIME EXPIRED"
		mission_detail_label.modulate = Color(0.85, 0.85, 0.85)
	_mission_banner_timer = 3.0
	_has_active_mission = false
	_active_mission_pos = Vector3.ZERO
	queue_redraw()

func _on_setting_changed(key: String, val: Variant) -> void:
	match key:
		"damage_flash_enabled":
			_damage_flash_enabled = bool(val)
			if not _damage_flash_enabled and damage_vignette:
				damage_vignette.color.a = 0.0
		"damage_flash_intensity":
			_damage_flash_intensity = float(val)
		"reduced_flashing":
			_reduced_flashing = bool(val)
		"high_contrast_indicators":
			_high_contrast_indicators = bool(val)
			queue_redraw()

func _on_player_damaged_directional(_amount: float, _hit_pos: Vector3, source_pos: Vector3, is_shield: bool, _metadata: Dictionary = {}) -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam or not is_instance_valid(_player):
		return
	var to_src := (source_pos - _player.global_position)
	to_src.y = 0.0
	if to_src.length_squared() < 0.01:
		to_src = -_player.global_transform.basis.z
		to_src.y = 0.0
	to_src = to_src.normalized()

	var cam_fwd := -cam.global_transform.basis.z
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized() if cam_fwd.length_squared() > 0.01 else Vector3.FORWARD

	var cam_right := cam.global_transform.basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized() if cam_right.length_squared() > 0.01 else Vector3.RIGHT

	var right_dot := cam_right.dot(to_src)
	var fwd_dot := cam_fwd.dot(to_src)

	var cue := DamageCue.new()
	cue.dir_2d = Vector2(right_dot, -fwd_dot).normalized()
	cue.is_shield = is_shield
	cue.timer = 0.45
	cue.max_time = 0.45
	_damage_cues.append(cue)
	queue_redraw()

func _setup_upgrade_banner() -> void:
	if upgrade_banner:
		return
	upgrade_banner = PanelContainer.new()
	upgrade_banner.name = "UpgradeBanner"
	upgrade_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	upgrade_banner.anchor_left = 0.5
	upgrade_banner.anchor_right = 0.5
	upgrade_banner.offset_left = -170.0
	upgrade_banner.offset_right = 170.0
	upgrade_banner.offset_top = 58.0
	upgrade_banner.offset_bottom = 92.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.14, 0.16, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.95, 0.85, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	upgrade_banner.add_theme_stylebox_override("panel", style)

	upgrade_banner_label = Label.new()
	upgrade_banner_label.name = "UpgradeBannerLabel"
	upgrade_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	upgrade_banner_label.add_theme_font_size_override("font_size", 13)
	upgrade_banner_label.modulate = Color(0.3, 1.0, 0.85)
	upgrade_banner.add_child(upgrade_banner_label)

	add_child(upgrade_banner)
	upgrade_banner.visible = false

func _on_upgrade_applied(upgrade_id: String) -> void:
	if not upgrade_banner:
		_setup_upgrade_banner()
	var title := upgrade_id.capitalize()
	var is_evo: bool = false
	var mgr := get_tree().get_first_node_in_group("upgrade_manager")
	if mgr and "upgrade_database" in mgr:
		var db: Dictionary = mgr.get("upgrade_database")
		if db.has(upgrade_id):
			title = str(db[upgrade_id].get("name", title))
			is_evo = bool(db[upgrade_id].get("is_evolution", false))
	if upgrade_banner_label:
		if is_evo:
			var path_tag := ""
			if upgrade_id in ["hellfire_minigun", "ap_ricochet_cannon", "siege_cannon"]:
				path_tag = " [GUN BARRAGE]"
			elif upgrade_id in ["swarm_rockets", "multi_lock_hellfire"]:
				path_tag = " [MISSILE HUNTER]"
			elif upgrade_id == "aegis_airframe":
				path_tag = " [DEFENSIVE SQUADRON]"
			upgrade_banner_label.text = "★ WEAPON EVOLUTION: %s%s" % [title.to_upper(), path_tag]
			upgrade_banner_label.modulate = Color(1.0, 0.84, 0.0)
		else:
			upgrade_banner_label.text = "▲ UPGRADE INSTALLED: %s" % title.to_upper()
			upgrade_banner_label.modulate = Color(0.3, 1.0, 0.85)
	if upgrade_banner:
		upgrade_banner.visible = true
		upgrade_banner.modulate.a = 1.0
	_upgrade_banner_timer = 2.8 if is_evo else 2.2
	_update_missile_status_display()
	_update_defense_status_display()
	_on_heat_changed(0.0, 1.0, false)

func _setup_defense_status_ui() -> void:
	if defense_status_label:
		return
	var top_left := find_child("TopLeft", true, false) as VBoxContainer
	if top_left:
		var card := find_child("TopLeftCard", true, false) as Control
		if card and card.offset_bottom < 132.0:
			card.offset_bottom = 132.0
		if top_left.offset_bottom < 126.0:
			top_left.offset_bottom = 126.0

		defense_status_label = Label.new()
		defense_status_label.name = "DefenseStatusLabel"
		var font := _get_hud_font()
		if font:
			defense_status_label.add_theme_font_override("font", font)
		defense_status_label.add_theme_font_size_override("font_size", 12)
		defense_status_label.modulate = Color(0.35, 0.95, 0.85)
		defense_status_label.text = ""
		top_left.add_child(defense_status_label)
		defense_status_label.visible = false

func _on_wingmen_status_updated(alive_count: int, _max_count: int) -> void:
	_has_wingmen = true
	_wingmen_alive = alive_count
	_update_defense_status_display()

func _on_defense_status_updated(armor_pct: float, rep_rate: float, aegis_ready: bool, aegis_cd: float) -> void:
	_armor_pct = armor_pct
	_repair_rate = rep_rate
	_has_aegis = (aegis_ready or aegis_cd > 0.0)
	_aegis_cooldown = aegis_cd
	_update_defense_status_display()

func _update_defense_status_display() -> void:
	if not defense_status_label:
		_setup_defense_status_ui()
	if not defense_status_label:
		return

	var parts: Array[String] = []

	if _has_wingmen:
		var w_icons := ""
		for i in range(2):
			w_icons += "◆ " if i < _wingmen_alive else "◇ "
		parts.append("ESCORT [ %s]" % w_icons.strip_edges())

	if _armor_pct > 0.01:
		parts.append("ARMOR +%d%%" % int(_armor_pct * 100.0))

	if _repair_rate > 0.1:
		parts.append("REPAIR 4/s")

	if _has_aegis:
		if _aegis_cooldown <= 0.0:
			parts.append("AEGIS READY")
		else:
			parts.append("AEGIS [%.0fs]" % _aegis_cooldown)

	if parts.is_empty():
		defense_status_label.visible = false
	else:
		defense_status_label.text = " // ".join(parts)
		defense_status_label.visible = true

func _on_command_unit_destroyed(_pos: Vector3) -> void:
	if not upgrade_banner:
		_setup_upgrade_banner()
	if upgrade_banner_label:
		upgrade_banner_label.text = "★ COMMAND UNIT DESTROYED // +1 REQUISITION"
		upgrade_banner_label.modulate = Color(1.0, 0.85, 0.2)
	if upgrade_banner:
		upgrade_banner.visible = true
		upgrade_banner.modulate.a = 1.0
	_upgrade_banner_timer = 2.4

func _on_radar_status_changed(is_active: bool) -> void:
	if not is_active:
		if not upgrade_banner:
			_setup_upgrade_banner()
		if upgrade_banner_label:
			upgrade_banner_label.text = "★ RADAR STATION DESTROYED // RECON RESTORED"
			upgrade_banner_label.modulate = Color(0.3, 1.0, 0.85)
		if upgrade_banner:
			upgrade_banner.visible = true
			upgrade_banner.modulate.a = 1.0
		_upgrade_banner_timer = 2.4

func _setup_attack_run_banner() -> void:
	if attack_run_banner:
		return
	attack_run_banner = PanelContainer.new()
	attack_run_banner.name = "AttackRunBanner"
	attack_run_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_run_banner.anchor_left = 0.5
	attack_run_banner.anchor_right = 0.5
	attack_run_banner.offset_left = -210.0
	attack_run_banner.offset_right = 210.0
	attack_run_banner.offset_top = 96.0
	attack_run_banner.offset_bottom = 124.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.01, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.80, 0.20, 0.90)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	attack_run_banner.add_theme_stylebox_override("panel", style)

	attack_run_label = Label.new()
	attack_run_label.name = "AttackRunLabel"
	attack_run_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_run_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := _get_hud_font()
	if font:
		attack_run_label.add_theme_font_override("font", font)
	attack_run_label.add_theme_font_size_override("font_size", 13)
	attack_run_label.modulate = Color(1.0, 0.88, 0.25)
	attack_run_banner.add_child(attack_run_label)

	add_child(attack_run_banner)
	attack_run_banner.visible = false

func _on_attack_run_state_changed(is_active: bool, duration: float, _max_duration: float) -> void:
	if not attack_run_banner:
		_setup_attack_run_banner()
	if is_active:
		if attack_run_banner:
			attack_run_banner.visible = true
		if attack_run_label:
			attack_run_label.text = "⚡ ATTACK RUN // -50%% HEAT + RAPID LOCK [%.1fs] ⚡" % duration
		if combo_bar:
			combo_bar.modulate = Color(1.0, 0.85, 0.25, 1.0)
	else:
		if attack_run_banner:
			attack_run_banner.visible = false
		if combo_bar:
			combo_bar.modulate = Color.WHITE

func _on_player_died() -> void:
	if attack_run_banner:
		attack_run_banner.visible = false
	if combo_bar:
		combo_bar.modulate = Color.WHITE

func _get_hud_font() -> Font:
	if not _hud_font:
		if ResourceLoader.exists("res://assets/ui/fonts/Rajdhani-Bold.ttf"):
			_hud_font = load("res://assets/ui/fonts/Rajdhani-Bold.ttf") as Font
		if not _hud_font:
			_hud_font = ThemeDB.fallback_font
	return _hud_font

func _update_evade_display() -> void:
	if not evade_label:
		return
	if _is_evading_active:
		evade_label.text = "EVADE [SPACE]  BURST!"
		evade_label.modulate = Color(1.0, 0.92, 0.25)
		if evade_bar:
			evade_bar.value = evade_bar.max_value
			evade_bar.modulate = Color(1.0, 0.92, 0.25)
		return

	if _evade_cooldown_remaining <= 0.001:
		evade_label.text = "EVADE [SPACE]  READY"
		evade_label.modulate = Color(0.25, 0.95, 0.65)
		if evade_bar:
			evade_bar.max_value = maxf(0.1, _evade_cooldown_max)
			evade_bar.value = evade_bar.max_value
			evade_bar.modulate = Color(0.25, 0.95, 0.65)
	else:
		evade_label.text = "EVADE [SPACE]  %.1fs" % _evade_cooldown_remaining
		evade_label.modulate = Color(1.0, 0.65, 0.20)
		if evade_bar:
			evade_bar.max_value = maxf(0.1, _evade_cooldown_max)
			evade_bar.value = maxf(0.0, _evade_cooldown_max - _evade_cooldown_remaining)
			evade_bar.modulate = Color(1.0, 0.65, 0.20)

func _update_passenger_display() -> void:
	if not passenger_label:
		return
	if not _passenger_evac_msg.is_empty():
		passenger_label.text = _passenger_evac_msg
		passenger_label.modulate = Color(0.30, 1.0, 0.85)
		return

	if _passenger_count <= 0:
		passenger_label.text = "PASSENGERS  0 / %d" % _passenger_capacity
		passenger_label.modulate = Color(0.65, 0.78, 0.88)
	elif _passenger_count >= _passenger_capacity:
		passenger_label.text = "PASSENGERS  %d / %d  [CABIN FULL]" % [_passenger_count, _passenger_capacity]
		passenger_label.modulate = Color(1.0, 0.85, 0.20)
	else:
		passenger_label.text = "PASSENGERS  %d / %d  [RTB LZ]" % [_passenger_count, _passenger_capacity]
		passenger_label.modulate = Color(0.25, 0.98, 0.55)

func _on_evade_cooldown_updated(current: float, maximum: float) -> void:
	_evade_cooldown_remaining = current
	_evade_cooldown_max = maximum
	if current <= 0.001:
		_is_evading_active = false
		_evade_burst_timer = 0.0
	_update_evade_display()

func _on_player_evaded() -> void:
	_is_evading_active = true
	_evade_burst_timer = 0.35
	_update_evade_display()

func _on_survivor_collected(current_passengers: int, max_capacity: int) -> void:
	_passenger_count = current_passengers
	_passenger_capacity = max_capacity
	_update_passenger_display()

func _on_survivors_evacuated(count: int, _heal_amount: float, salvage_amount: int) -> void:
	_passenger_count = 0
	if count > 0:
		_passenger_evac_msg = "PASSENGERS EVACUATED! +%d SALVAGE" % salvage_amount
		_passenger_evac_msg_timer = 3.0
	_update_passenger_display()

func _setup_evade_and_passenger_ui() -> void:
	if not evade_label:
		evade_label = find_child("EvadeLabel", true, false) as Label
	if not evade_bar:
		evade_bar = find_child("EvadeBar", true, false) as ProgressBar
	if not flares_bar:
		flares_bar = find_child("FlaresBar", true, false) as ProgressBar
	if not passenger_label:
		passenger_label = find_child("PassengerLabel", true, false) as Label

	# Dynamic fallback for EvadePod
	if not evade_label:
		var weapons_row := find_child("WeaponsRow", true, false) as HBoxContainer
		if weapons_row:
			var vdiv := ColorRect.new()
			vdiv.name = "TacticalVDivider2"
			vdiv.custom_minimum_size = Vector2(1, 24)
			vdiv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			vdiv.color = Color(0.22, 0.55, 0.68, 0.35)
			weapons_row.add_child(vdiv)

			var pod := VBoxContainer.new()
			pod.name = "EvadePod"
			pod.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pod.add_theme_constant_override("separation", 2)

			evade_label = Label.new()
			evade_label.name = "EvadeLabel"
			var font := _get_hud_font()
			if font:
				evade_label.add_theme_font_override("font", font)
			evade_label.add_theme_font_size_override("font_size", 14)
			evade_label.text = "EVADE [SPACE]  READY"
			evade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pod.add_child(evade_label)

			evade_bar = ProgressBar.new()
			evade_bar.name = "EvadeBar"
			evade_bar.custom_minimum_size = Vector2(0, 4)
			evade_bar.show_percentage = false
			evade_bar.max_value = 3.5
			evade_bar.value = 3.5

			var bg_style := StyleBoxFlat.new()
			bg_style.bg_color = Color(0.04, 0.07, 0.1, 0.9)
			bg_style.corner_radius_top_left = 2
			bg_style.corner_radius_top_right = 2
			bg_style.corner_radius_bottom_right = 2
			bg_style.corner_radius_bottom_left = 2
			evade_bar.add_theme_stylebox_override("background", bg_style)

			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = Color(0.25, 0.95, 0.75, 1.0)
			fill_style.corner_radius_top_left = 2
			fill_style.corner_radius_top_right = 2
			fill_style.corner_radius_bottom_right = 2
			fill_style.corner_radius_bottom_left = 2
			evade_bar.add_theme_stylebox_override("fill", fill_style)

			pod.add_child(evade_bar)
			weapons_row.add_child(pod)

	# Dynamic fallback for PassengerLabel
	if not passenger_label:
		var top_left := find_child("TopLeft", true, false) as VBoxContainer
		if top_left:
			var card := find_child("TopLeftCard", true, false) as Control
			if card and card.offset_bottom < 108.0:
				card.offset_bottom = 108.0
			if top_left.offset_bottom < 102.0:
				top_left.offset_bottom = 102.0

			passenger_label = Label.new()
			passenger_label.name = "PassengerLabel"
			var font := _get_hud_font()
			if font:
				passenger_label.add_theme_font_override("font", font)
			passenger_label.add_theme_font_size_override("font_size", 13)
			passenger_label.text = "PASSENGERS  0 / 6"
			passenger_label.modulate = Color(0.65, 0.78, 0.88)
			top_left.add_child(passenger_label)

func _on_kills_updated(total_kills: int) -> void:
	if kills_label:
		kills_label.text = "KILLS: %d" % total_kills

func _on_score_updated(total_score: int, _earned: int, mult: float, _streak: int) -> void:
	_target_score = total_score
	if score_label:
		if _score_tween and _score_tween.is_valid():
			_score_tween.kill()
		_score_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_score_tween.tween_method(func(val: int):
			_displayed_score = val
			if is_instance_valid(score_label):
				score_label.text = "SCORE: %s" % _format_number(val)
		, _displayed_score, _target_score, 0.4)

	if multiplier_badge:
		multiplier_badge.text = "%.1fx" % mult if mult > 1.05 else "1.0x"
		var color := Color(0.7, 0.88, 1.0, 1.0)
		if mult >= 5.0:
			color = Color(1.0, 0.95, 0.4, 1.0) # MEGABONK gold
		elif mult >= 4.0:
			color = Color(0.85, 0.35, 1.0, 1.0) # Mayhem purple
		elif mult >= 3.0:
			color = Color(1.0, 0.25, 0.25, 1.0) # Crimson
		elif mult >= 2.0:
			color = Color(1.0, 0.65, 0.1, 1.0) # Amber
		elif mult >= 1.5:
			color = Color(0.3, 0.95, 0.5, 1.0) # Green
		multiplier_badge.set("theme_override_colors/font_color", color)

		if mult > 1.05:
			multiplier_badge.pivot_offset = multiplier_badge.size * 0.5
			if _multiplier_tween and _multiplier_tween.is_valid():
				_multiplier_tween.kill()
			_multiplier_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_multiplier_tween.tween_property(multiplier_badge, "scale", Vector2(1.3, 1.3), 0.1)
			_multiplier_tween.tween_property(multiplier_badge, "scale", Vector2(1.0, 1.0), 0.2)

func _on_combo_timer_updated(remaining: float, max_time: float, _mult: float) -> void:
	if combo_bar:
		var ratio: float = clampf(remaining / maxf(0.01, max_time), 0.0, 1.0)
		combo_bar.value = ratio

func _on_hover_hazard_state_changed(is_hazard: bool) -> void:
	_is_hover_hazard = is_hazard
	if hover_hazard_banner:
		hover_hazard_banner.visible = is_hazard

func _format_number(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
