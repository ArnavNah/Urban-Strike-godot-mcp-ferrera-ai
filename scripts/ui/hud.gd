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

@onready var wave_label: Label = get_node_or_null("%WaveLabel") as Label
@onready var wave_progress_label: Label = get_node_or_null("%WaveProgressLabel") as Label
@onready var wave_banner: Label = get_node_or_null("%WaveBanner") as Label
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

class DamageCue:
	var dir_2d: Vector2 = Vector2.UP
	var timer: float = 0.45
	var max_time: float = 0.45
	var is_shield: bool = false

var _damage_cues: Array[DamageCue] = []
var upgrade_banner: PanelContainer = null
var upgrade_banner_label: Label = null
var _upgrade_banner_timer: float = 0.0

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
		if eb.has_signal("setting_changed"):
			eb.setting_changed.connect(_on_setting_changed)

	_setup_mission_card()

	if _player and "missile_pod" in _player and _player.missile_pod:
		var pod: Node = _player.missile_pod
		if "current_missiles" in pod and "max_missiles" in pod:
			_missile_ammo = int(pod.current_missiles)
			_max_missiles = int(pod.max_missiles)
	_update_missile_status_display()

func _process(delta: float) -> void:
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

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return

	# Missile warning flash timer
	if _missile_warning_timer > 0.0:
		_missile_warning_timer -= delta
		if _missile_warning_timer <= 0.0:
			_update_missile_status_display()

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
		threats = EnemyRegistry.instance.get_enemies_in_radius(_player.global_position, 85.0, 16)
	else:
		var raw_threats := get_tree().get_nodes_in_group("enemies")
		for th in raw_threats:
			var th3d := th as Node3D
			if is_instance_valid(th3d) and th3d != _player:
				threats.append(th3d)
				if threats.size() >= 16:
					break

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
			if _high_contrast_indicators:
				var outline := PackedVector2Array([tip, side_a, side_b, tip])
				draw_polyline(outline, Color(0.02, 0.04, 0.06, 0.95), 2.5)
			draw_colored_polygon(PackedVector2Array([tip, side_a, side_b]), col)

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
			var obj_edge := vp_center + obj_dir_2d * minf(vp_center.x - margin, vp_center.y - margin)
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

func _update_target_reticle(delta: float = 0.0) -> void:
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
	var target_screen_pos: Vector2 = screen_pos - (target_reticle.size * 0.5)

	if not target_reticle.visible:
		target_reticle.visible = true
		target_reticle.position = target_screen_pos
	else:
		var smooth_weight: float = clampf(delta * 28.0, 0.0, 1.0) if delta > 0.0 else 1.0
		target_reticle.position = target_reticle.position.lerp(target_screen_pos, smooth_weight)

func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		if _health_tween:
			_health_tween.kill()
		_health_tween = create_tween()
		_health_tween.tween_property(health_bar, "value", current, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if health_label:
		if current <= maximum * 0.30:
			health_label.text = "HULL: %d / %d  [!] CRITICAL" % [int(current), int(maximum)]
			health_label.modulate = Color(1.0, 0.20, 0.20)
		elif current <= maximum * 0.50:
			health_label.text = "HULL: %d / %d" % [int(current), int(maximum)]
			health_label.modulate = Color(1.0, 0.65, 0.15)
		else:
			health_label.text = "HULL: %d / %d" % [int(current), int(maximum)]
			health_label.modulate = Color(0.20, 0.85, 0.45)

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

func _on_heat_changed(current: float, maximum: float, is_overheated: bool) -> void:
	if heat_bar:
		heat_bar.max_value = maximum
		heat_bar.value = current
		heat_bar.visible = current > 0.05
	if overheat_warning:
		overheat_warning.visible = is_overheated

func _update_missile_status_display() -> void:
	if not missile_status:
		return

	var pips := ""
	for i in range(_max_missiles):
		pips += "▲" if i < _missile_ammo else "△"

	if _missile_warning_timer > 0.0:
		missile_status.text = "MISSILES  %d / %d  [%s]  NO MISSILES" % [_missile_ammo, _max_missiles, pips]
		missile_status.modulate = Color(1.0, 0.25, 0.25)
		return

	if _missile_ammo <= 0:
		missile_status.text = "MISSILES  0 / %d  [%s]  EMPTY" % [_max_missiles, pips]
		missile_status.modulate = Color(0.85, 0.35, 0.35)
		return

	var jam_suffix := "  EW JAMMED" if _is_jammed else ""
	if _is_missile_locked:
		missile_status.text = "MISSILES  %d / %d  [%s]  LOCKED" % [_missile_ammo, _max_missiles, pips]
		missile_status.modulate = Color(0.20, 0.85, 0.45)
	elif _last_lock_progress > 0.05:
		missile_status.text = "MISSILES  %d / %d  [%s]  LOCKING %d%%%s" % [_missile_ammo, _max_missiles, pips, int(_last_lock_progress * 100.0), jam_suffix]
		missile_status.modulate = Color(1.0, 0.50, 0.15) if _is_jammed else Color(1.0, 0.75, 0.20)
	else:
		missile_status.text = "MISSILES  %d / %d  [%s]  READY%s" % [_missile_ammo, _max_missiles, pips, jam_suffix]
		missile_status.modulate = Color(1.0, 0.55, 0.15) if _is_jammed else Color(0.85, 0.90, 0.95)

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
		missile_bar.visible = progress > 0.05
	_update_missile_status_display()

func _on_jammer_status_changed(is_jammed: bool, _count: int) -> void:
	_is_jammed = is_jammed

func _on_flares_updated(charges_left: int, max_charges: int, is_ready: bool) -> void:
	if flares_label:
		if not is_ready and charges_left < max_charges:
			flares_label.text = "FLARES: %d/%d  CHARGING" % [charges_left, max_charges]
			flares_label.modulate = Color(1.0, 0.65, 0.15)
		elif charges_left <= 0:
			flares_label.text = "FLARES: 0/%d  DEPLETED" % max_charges
			flares_label.modulate = Color(0.85, 0.35, 0.35)
		else:
			flares_label.text = "FLARES: %d/%d  [X]" % [charges_left, max_charges]
			flares_label.modulate = Color(0.85, 0.90, 0.95)

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
	var mgr := get_tree().get_first_node_in_group("upgrade_manager")
	if mgr and "upgrade_database" in mgr:
		var db: Dictionary = mgr.get("upgrade_database")
		if db.has(upgrade_id):
			title = str(db[upgrade_id].get("name", title))
	if upgrade_banner_label:
		upgrade_banner_label.text = "▲ UPGRADE INSTALLED: %s" % title.to_upper()
	if upgrade_banner:
		upgrade_banner.visible = true
		upgrade_banner.modulate.a = 1.0
	_upgrade_banner_timer = 2.2
