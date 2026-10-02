class_name SoundManager
extends Node

## Procedural arcade sound manager providing real-time audio synthesis,
## pre-rendered 16-bit WAV stream caching, dedicated channels, and zero-latency mixing.

static var instance: SoundManager = null

@onready var chaingun_player: AudioStreamPlayer = $ChaingunPlayer
@onready var alert_player: AudioStreamPlayer = $AlertPlayer
@onready var explosion_player: AudioStreamPlayer = $ExplosionPlayer
@onready var missile_player: AudioStreamPlayer = $MissilePlayer
@onready var hud_player: AudioStreamPlayer = $HudPlayer

var engine_player: AudioStreamPlayer = null

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_idx: int = 0
const SFX_POOL_SIZE: int = 16

var _prev_overheated: bool = false
var _prev_player_health: float = 100.0
var _prev_flare_charges: int = 3
var _was_missile_locked: bool = false
var _last_lock_progress_step: int = 0
var _last_xp_sound_time: float = 0.0
var _xp_combo_step: int = 0

# Rate-limiting cooldowns for high-cadence combat events
var _last_player_shot_time: float = 0.0
var _last_enemy_shot_time: float = 0.0
var _last_impact_armor_time: float = 0.0
var _last_impact_terrain_time: float = 0.0
var _last_player_hit_time: float = 0.0
var _last_missile_impact_time: float = 0.0
var _last_missile_fired_time: float = 0.0

var _cached_camera: Camera3D = null
var _cached_player: Node3D = null
var _engine_sound_enabled: bool = true
var _chaingun_cycle_idx: int = 0
var _is_attack_run_active_sound: bool = false

# Pre-rendered procedural AudioStreamWAV assets
var _wav_chaingun: Array[AudioStreamWAV] = []
var _wav_hellfire: AudioStreamWAV = null
var _wav_enemy_light: AudioStreamWAV = null
var _wav_enemy_heavy: AudioStreamWAV = null
var _wav_missile_launch: AudioStreamWAV = null
var _wav_swarm_launch: AudioStreamWAV = null
var _wav_flares: AudioStreamWAV = null
var _wav_evade: AudioStreamWAV = null
var _wav_missile_impact: AudioStreamWAV = null
var _wav_explosion_light: AudioStreamWAV = null
var _wav_explosion_med: AudioStreamWAV = null
var _wav_explosion_heavy: AudioStreamWAV = null
var _wav_explosion_air: AudioStreamWAV = null
var _wav_impact_armor: AudioStreamWAV = null
var _wav_impact_terrain: AudioStreamWAV = null
var _wav_shield_hit: AudioStreamWAV = null
var _wav_lock_step1: AudioStreamWAV = null
var _wav_lock_step2: AudioStreamWAV = null
var _wav_lock_acquired: AudioStreamWAV = null
var _wav_missile_warning: AudioStreamWAV = null
var _wav_overheat: AudioStreamWAV = null
var _wav_low_health: AudioStreamWAV = null
var _wav_no_missiles: AudioStreamWAV = null
var _wav_missile_pickup: AudioStreamWAV = null
var _wav_xp_chimes: Array[AudioStreamWAV] = []
var _wav_level_up: AudioStreamWAV = null
var _wav_upgrade_applied: AudioStreamWAV = null
var _wav_survivor_collected: AudioStreamWAV = null
var _wav_survivors_evacuated: AudioStreamWAV = null
var _wav_wave_start: AudioStreamWAV = null
var _wav_wave_complete: AudioStreamWAV = null
var _wav_boss_spawn: AudioStreamWAV = null
var _wav_boss_defeat: AudioStreamWAV = null
var _wav_attack_run_start: AudioStreamWAV = null
var _wav_attack_run_end: AudioStreamWAV = null

func _get_active_camera() -> Camera3D:
	if is_instance_valid(_cached_camera) and (_cached_camera.current or not is_inside_tree()):
		return _cached_camera
	if is_inside_tree():
		var vp := get_viewport()
		if vp:
			_cached_camera = vp.get_camera_3d()
	return _cached_camera

func _calc_distance_volume_mult(pos: Vector3, max_dist: float = 140.0) -> float:
	if pos == Vector3.ZERO:
		return 1.0
	var cam := _get_active_camera()
	if not cam:
		return 1.0
	var dist := cam.global_position.distance_to(pos)
	if dist >= max_dist:
		return 0.0
	return clampf(1.0 - (dist / max_dist), 0.12, 1.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self
	add_to_group("sound_manager")

	_ensure_audio_buses()

	# Pre-render all procedural audio streams into 16-bit WAV buffers
	_synthesize_all_sfx()

	# Ensure dedicated channel players exist
	if not chaingun_player:
		chaingun_player = _get_or_create_channel("ChaingunPlayer")
	if not alert_player:
		alert_player = _get_or_create_channel("AlertPlayer")
	if not explosion_player:
		explosion_player = _get_or_create_channel("ExplosionPlayer")
	if not missile_player:
		missile_player = _get_or_create_channel("MissilePlayer")
	if not hud_player:
		hud_player = _get_or_create_channel("HudPlayer")

	# Initialize round-robin voice pool for dynamic 3D combat sound events
	var sfx_bus_exists := AudioServer.get_bus_index("SFX") >= 0
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SfxVoice_%d" % i
		if sfx_bus_exists:
			p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	if has_node("EnginePlayer"):
		engine_player = get_node("EnginePlayer") as AudioStreamPlayer
	else:
		engine_player = AudioStreamPlayer.new()
		engine_player.name = "EnginePlayer"
		add_child(engine_player)

	if sfx_bus_exists:
		for p in [chaingun_player, alert_player, explosion_player, missile_player, hud_player, engine_player]:
			if is_instance_valid(p):
				p.bus = "SFX"

	if is_instance_valid(engine_player):
		engine_player.stream = _create_procedural_rotor_stream()

	_connect_event_bus()
	apply_volume_settings()

func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")

func _get_or_create_channel(channel_name: String) -> AudioStreamPlayer:
	if has_node(channel_name):
		return get_node(channel_name) as AudioStreamPlayer
	var p := AudioStreamPlayer.new()
	p.name = channel_name
	add_child(p)
	return p

func _connect_event_bus() -> void:
	if not EventBus:
		return
	EventBus.chaingun_heat_changed.connect(_on_heat_changed)
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
	EventBus.missile_lock_updated.connect(_on_missile_lock)
	EventBus.missile_fired.connect(_on_missile_fired)
	EventBus.flares_updated.connect(_on_flares_updated)
	EventBus.incoming_missile_warning.connect(_on_missile_warning)
	EventBus.level_up_requested.connect(_on_level_up)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.player_died.connect(_on_player_died)

	if EventBus.has_signal("player_fired_primary"):
		EventBus.player_fired_primary.connect(_on_player_fired_primary)
	if EventBus.has_signal("enemy_fired_weapon"):
		EventBus.enemy_fired_weapon.connect(_on_enemy_fired_weapon)
	if EventBus.has_signal("combat_impact_occurred"):
		EventBus.combat_impact_occurred.connect(_on_combat_impact)
	if EventBus.has_signal("missile_impact_occurred"):
		EventBus.missile_impact_occurred.connect(_on_missile_impact)
	if EventBus.has_signal("player_damaged_directional"):
		EventBus.player_damaged_directional.connect(_on_player_damaged_directional)
	if EventBus.has_signal("upgrade_applied"):
		EventBus.upgrade_applied.connect(_on_upgrade_applied)
	if EventBus.has_signal("no_missiles_warning"):
		EventBus.no_missiles_warning.connect(_on_no_missiles_warning)
	if EventBus.has_signal("missile_pickup_collected"):
		EventBus.missile_pickup_collected.connect(_on_missile_pickup_collected)
	if EventBus.has_signal("xp_collected"):
		EventBus.xp_collected.connect(_on_xp_collected)
	if EventBus.has_signal("attack_run_state_changed"):
		EventBus.attack_run_state_changed.connect(_on_attack_run_state_changed)
	if EventBus.has_signal("player_evaded"):
		EventBus.player_evaded.connect(_on_player_evaded)
	if EventBus.has_signal("survivor_collected"):
		EventBus.survivor_collected.connect(_on_survivor_collected)
	if EventBus.has_signal("survivors_evacuated"):
		EventBus.survivors_evacuated.connect(_on_survivors_evacuated)
	if EventBus.has_signal("wave_completed"):
		EventBus.wave_completed.connect(_on_wave_completed)
	if EventBus.has_signal("boss_defeated"):
		EventBus.boss_defeated.connect(_on_boss_defeated)
	if EventBus.has_signal("setting_changed"):
		EventBus.setting_changed.connect(_on_setting_changed)

func apply_volume_settings() -> void:
	var master_vol: float = float(SaveSystem.get_setting("volume_master", 1.0))
	var sfx_vol: float = float(SaveSystem.get_setting("volume_sfx", 1.0))
	var music_vol: float = float(SaveSystem.get_setting("volume_music", 1.0))

	# Update AudioServer buses
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(0.0001, master_vol)))
		AudioServer.set_bus_mute(master_idx, master_vol <= 0.001)

	for sfx_bus in ["SFX", "Effects"]:
		var idx := AudioServer.get_bus_index(sfx_bus)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, sfx_vol)))
			AudioServer.set_bus_mute(idx, sfx_vol <= 0.001)

	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(0.0001, music_vol)))
		AudioServer.set_bus_mute(music_idx, music_vol <= 0.001)

	# Also directly scale internal stream players
	var eff_sfx_db := linear_to_db(maxf(0.0001, master_vol * sfx_vol))
	var is_muted := (master_vol * sfx_vol) <= 0.001

	var all_players := [chaingun_player, alert_player, explosion_player, missile_player, hud_player, engine_player]
	all_players.append_array(_sfx_pool)
	for p in all_players:
		if is_instance_valid(p):
			p.volume_db = -80.0 if is_muted else eff_sfx_db

func _on_setting_changed(key: String, _val: Variant) -> void:
	if key.begins_with("volume_"):
		apply_volume_settings()

func _get_pooled_player() -> AudioStreamPlayer:
	if _sfx_pool.is_empty():
		return chaingun_player

	# First look for an idle player
	for i in range(_sfx_pool.size()):
		var idx := (_sfx_pool_idx + i) % _sfx_pool.size()
		var p: AudioStreamPlayer = _sfx_pool[idx]
		if is_instance_valid(p) and not p.playing:
			_sfx_pool_idx = (idx + 1) % _sfx_pool.size()
			return p

	# If all are playing, steal the voice furthest along in playback
	var best_p: AudioStreamPlayer = _sfx_pool[_sfx_pool_idx]
	var max_pos: float = -1.0
	for p in _sfx_pool:
		if is_instance_valid(p):
			var pos := p.get_playback_position()
			if pos > max_pos:
				max_pos = pos
				best_p = p

	_sfx_pool_idx = (_sfx_pool_idx + 1) % _sfx_pool.size()
	return best_p

func _play_stream(stream: AudioStream, vol_mult: float = 1.0, pitch_var: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer:
	if not stream:
		return null
	var player := _get_pooled_player()
	if not player:
		return null

	player.stream = stream
	if bus_name != "" and AudioServer.get_bus_index(bus_name) >= 0:
		player.bus = bus_name

	if pitch_var > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	else:
		player.pitch_scale = 1.0

	var master_vol: float = float(SaveSystem.get_setting("volume_master", 1.0))
	var sfx_vol: float = float(SaveSystem.get_setting("volume_sfx", 1.0))
	var eff_vol := clampf(master_vol * sfx_vol * vol_mult, 0.0001, 1.5)
	if (master_vol * sfx_vol) <= 0.001 or vol_mult <= 0.001:
		player.volume_db = -80.0
	else:
		player.volume_db = linear_to_db(eff_vol)

	player.play()
	return player

func _play_stream_on(player: AudioStreamPlayer, stream: AudioStream, vol_mult: float = 1.0, pitch: float = 1.0) -> void:
	if not is_instance_valid(player) or not stream:
		return
	player.stream = stream
	player.pitch_scale = pitch
	var master_vol: float = float(SaveSystem.get_setting("volume_master", 1.0))
	var sfx_vol: float = float(SaveSystem.get_setting("volume_sfx", 1.0))
	var eff_vol := clampf(master_vol * sfx_vol * vol_mult, 0.0001, 1.5)
	if (master_vol * sfx_vol) <= 0.001 or vol_mult <= 0.001:
		player.volume_db = -80.0
	else:
		player.volume_db = linear_to_db(eff_vol)
	player.play()

func play_sfx(sfx_name: String) -> void:
	match sfx_name:
		"explosion":
			_play_stream(_wav_explosion_med, 0.55, 0.05)
		"shot":
			_play_stream(_get_chaingun_stream(), 0.38, 0.04)
		"laser", "evade":
			_play_stream(_wav_evade, 0.42, 0.03)
		"alert":
			_play_stream_on(alert_player, _wav_overheat, 0.45)
		_:
			_play_stream(_wav_chaingun[0], 0.35, 0.03)

func get_wingman_gun_stream() -> AudioStreamWAV:
	return _wav_enemy_light

# --- Event Bus Handlers ---

func _on_player_fired_primary(_muzzle_pos: Vector3, _dir: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_player_shot_time < 0.04:
		return
	_last_player_shot_time = now

	var is_hellfire := false
	if not is_instance_valid(_cached_player) or not _cached_player.is_inside_tree():
		_cached_player = get_tree().get_first_node_in_group("player") as Node3D

	if is_instance_valid(_cached_player):
		var gun = _cached_player.get("chaingun")
		if is_instance_valid(gun) and "is_hellfire_active" in gun:
			is_hellfire = bool(gun.get("is_hellfire_active"))

	if is_hellfire:
		_play_stream_on(chaingun_player, _wav_hellfire, 0.46, randf_range(0.97, 1.03))
	else:
		var st := _get_chaingun_stream()
		_play_stream_on(chaingun_player, st, 0.38, randf_range(0.96, 1.04))

func _get_chaingun_stream() -> AudioStreamWAV:
	if _wav_chaingun.is_empty():
		return null
	var st := _wav_chaingun[_chaingun_cycle_idx % _wav_chaingun.size()]
	_chaingun_cycle_idx += 1
	return st

func _on_enemy_fired_weapon(_enemy: Node3D, muzzle_pos: Vector3, _dir: Vector3, is_heavy: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_enemy_shot_time < 0.05:
		return
	_last_enemy_shot_time = now

	var dist_mult := _calc_distance_volume_mult(muzzle_pos)
	if dist_mult <= 0.0:
		return

	if is_heavy:
		_play_stream(_wav_enemy_heavy, 0.52 * dist_mult, 0.05)
	else:
		_play_stream(_wav_enemy_light, 0.36 * dist_mult, 0.06)

func _on_combat_impact(hit_pos: Vector3, _normal: Vector3, is_armored: bool, _is_lethal: bool) -> void:
	var dist_mult := _calc_distance_volume_mult(hit_pos)
	if dist_mult <= 0.0:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if is_armored:
		if now - _last_impact_armor_time < 0.04:
			return
		_last_impact_armor_time = now
		_play_stream(_wav_impact_armor, 0.38 * dist_mult, 0.06)
	else:
		if now - _last_impact_terrain_time < 0.05:
			return
		_last_impact_terrain_time = now
		_play_stream(_wav_impact_terrain, 0.32 * dist_mult, 0.07)

func _on_player_damaged_directional(_amount: float, _hit_pos: Vector3, _source_pos: Vector3, is_shield_hit: bool, _metadata: Dictionary = {}) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_player_hit_time < 0.05:
		return
	_last_player_hit_time = now

	if is_shield_hit:
		_play_stream(_wav_shield_hit, 0.48, 0.04)
	else:
		_play_stream(_wav_explosion_light, 0.52, 0.05)

func _on_missile_fired() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_missile_fired_time < 0.08:
		return
	_last_missile_fired_time = now

	var is_swarm := false
	if not is_instance_valid(_cached_player) or not _cached_player.is_inside_tree():
		_cached_player = get_tree().get_first_node_in_group("player") as Node3D

	if is_instance_valid(_cached_player):
		var pod = _cached_player.get("missile_pod")
		if is_instance_valid(pod) and "is_swarm_rockets" in pod:
			is_swarm = bool(pod.get("is_swarm_rockets"))

	if is_swarm:
		_play_stream_on(missile_player, _wav_swarm_launch, 0.55, randf_range(0.96, 1.04))
	else:
		_play_stream_on(missile_player, _wav_missile_launch, 0.62, randf_range(0.96, 1.04))

func _on_flares_updated(charges_left: int, max_charges: int, _is_ready: bool) -> void:
	if charges_left < _prev_flare_charges:
		_play_stream(_wav_flares, 0.50, 0.04)
	elif charges_left == max_charges and _prev_flare_charges < max_charges:
		_play_stream_on(hud_player, _wav_missile_pickup, 0.35, 1.2)
	_prev_flare_charges = charges_left

func _on_missile_impact(impact_pos: Vector3, _is_player: bool) -> void:
	var dist_mult := _calc_distance_volume_mult(impact_pos)
	if dist_mult <= 0.0:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_missile_impact_time < 0.04:
		return
	_last_missile_impact_time = now

	_play_stream(_wav_missile_impact, 0.65 * dist_mult, 0.05)

func _on_enemy_destroyed(enemy: Node3D, points: int) -> void:
	var pos := enemy.global_position if is_instance_valid(enemy) else Vector3.ZERO
	var dist_mult := _calc_distance_volume_mult(pos)
	if dist_mult <= 0.0:
		return

	var is_air := false
	if is_instance_valid(enemy):
		if enemy.is_in_group("air_enemies") or enemy is AirEnemyController or enemy is HunterHelicopter or enemy is Mig17Striker:
			is_air = true

	if is_air:
		_play_stream_on(explosion_player, _wav_explosion_air, 0.62 * dist_mult, randf_range(0.95, 1.05))
	elif points >= 150:
		_play_stream_on(explosion_player, _wav_explosion_heavy, 0.85 * dist_mult, randf_range(0.94, 1.06))
	elif points >= 25:
		_play_stream_on(explosion_player, _wav_explosion_med, 0.60 * dist_mult, randf_range(0.95, 1.05))
	else:
		_play_stream(_wav_explosion_light, 0.45 * dist_mult, 0.06)

func _on_missile_lock(progress: float, _target: Node3D, is_locked: bool) -> void:
	if is_locked and not _was_missile_locked:
		_play_stream_on(alert_player, _wav_lock_acquired, 0.50)
		_last_lock_progress_step = 3
	elif not is_locked:
		if progress >= 0.66 and _last_lock_progress_step < 2:
			_last_lock_progress_step = 2
			_play_stream_on(alert_player, _wav_lock_step2, 0.38)
		elif progress >= 0.33 and _last_lock_progress_step < 1:
			_last_lock_progress_step = 1
			_play_stream_on(alert_player, _wav_lock_step1, 0.35)
		elif progress < 0.15:
			_last_lock_progress_step = 0
	_was_missile_locked = is_locked

func _on_missile_warning(_pos: Vector3, is_active: bool) -> void:
	if is_active:
		_play_stream_on(alert_player, _wav_missile_warning, 0.55)

func _on_heat_changed(_current_heat: float, _max_heat: float, is_overheated: bool) -> void:
	if is_overheated and not _prev_overheated:
		_play_stream_on(alert_player, _wav_overheat, 0.55)
	_prev_overheated = is_overheated

func _on_health_changed(current_health: float, max_health: float) -> void:
	if current_health < _prev_player_health:
		if max_health > 0.0 and current_health <= max_health * 0.25:
			_play_stream_on(alert_player, _wav_low_health, 0.58)
	_prev_player_health = current_health

func _on_player_died() -> void:
	if is_instance_valid(engine_player) and engine_player.playing:
		engine_player.stop()
	_play_stream_on(explosion_player, _wav_explosion_heavy, 0.95)

func _on_player_evaded() -> void:
	_play_stream(_wav_evade, 0.48, 0.04)

func _on_survivor_collected(_current_passengers: int, _max_capacity: int) -> void:
	_play_stream_on(hud_player, _wav_survivor_collected, 0.48)

func _on_survivors_evacuated(_count: int, _heal_amount: float, _salvage_amount: int) -> void:
	_play_stream_on(hud_player, _wav_survivors_evacuated, 0.55)

func _on_level_up(_level: int) -> void:
	_play_stream_on(hud_player, _wav_level_up, 0.60)

func _on_upgrade_applied(_upgrade_id: String) -> void:
	_play_stream_on(hud_player, _wav_upgrade_applied, 0.50)

func _on_xp_collected(_amount: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_xp_sound_time < 0.04:
		return
	if now - _last_xp_sound_time > 0.75:
		_xp_combo_step = 0
	_last_xp_sound_time = now

	if not _wav_xp_chimes.is_empty():
		var chime: AudioStreamWAV = _wav_xp_chimes[_xp_combo_step % _wav_xp_chimes.size()]
		_xp_combo_step += 1
		_play_stream_on(hud_player, chime, 0.38)

func _on_attack_run_state_changed(is_active: bool, _duration: float, _max_duration: float) -> void:
	if is_active != _is_attack_run_active_sound:
		_is_attack_run_active_sound = is_active
		if is_active:
			_play_stream_on(hud_player, _wav_attack_run_start, 0.50)
		else:
			_play_stream_on(hud_player, _wav_attack_run_end, 0.45)

func _on_boss_spawned(_boss: Node3D) -> void:
	_play_stream_on(explosion_player, _wav_boss_spawn, 0.85)

func _on_boss_defeated() -> void:
	_play_stream_on(hud_player, _wav_boss_defeat, 0.70)

func _on_wave_started(wave_num: int, _announcement: String) -> void:
	if wave_num == 10:
		_play_stream_on(alert_player, _wav_boss_spawn, 0.65)
	else:
		_play_stream_on(hud_player, _wav_wave_start, 0.45)

func _on_wave_completed(_wave_num: int) -> void:
	_play_stream_on(hud_player, _wav_wave_complete, 0.50)

func _on_no_missiles_warning() -> void:
	_play_stream_on(alert_player, _wav_no_missiles, 0.40)

func _on_missile_pickup_collected(_amount: int) -> void:
	_play_stream_on(hud_player, _wav_missile_pickup, 0.45)

# --- Legacy Compatibility Methods (Zero-glitch wrappers) ---

func _play_sweep(freq_start: float, freq_end: float, duration: float, volume: float = 0.35, is_noise: bool = false) -> void:
	var stream := _synth_generic_sweep(freq_start, freq_end, duration, is_noise)
	_play_stream(stream, volume)

func _play_tone(player: AudioStreamPlayer, freq: float, duration: float, volume: float = 0.4) -> void:
	var stream := _synth_pure_tone(freq, duration)
	if player:
		_play_stream_on(player, stream, volume)
	else:
		_play_stream(stream, volume)

func _play_arpeggio(player: AudioStreamPlayer, freqs: Array[float], note_dur: float) -> void:
	var stream := _synth_arpeggio_wav(freqs, note_dur)
	if player:
		_play_stream_on(player, stream, 0.5)
	else:
		_play_stream(stream, 0.5)

# --- Procedural Engine Sound Synthesis & Speed Pitch Modulation ---

func _process(delta: float) -> void:
	_update_engine_sound(delta)

func _update_engine_sound(delta: float) -> void:
	if not _engine_sound_enabled or not is_instance_valid(engine_player):
		return

	if get_tree().paused:
		if engine_player.playing:
			engine_player.stop()
		return

	if not is_instance_valid(_cached_player) or not _cached_player.is_inside_tree():
		_cached_player = get_tree().get_first_node_in_group("player") as Node3D

	if is_instance_valid(_cached_player) and _cached_player.get("is_alive") == true:
		if not engine_player.playing:
			engine_player.play()

		var vel: Vector3 = _cached_player.get("velocity") if "velocity" in _cached_player else Vector3.ZERO
		var horiz_spd := Vector2(vel.x, vel.z).length()
		var max_spd: float = float(_cached_player.get("max_forward_speed")) if "max_forward_speed" in _cached_player else 28.0
		var speed_ratio := clampf(horiz_spd / maxf(1.0, max_spd), 0.0, 1.25)

		# Pitch modulation: 0.92 (idle hover) up to 1.32 (full forward flight)
		var target_pitch := lerpf(0.92, 1.32, speed_ratio)

		# If helicopter health is critical (<25%), add distressed stuttering wobble
		var cur_hp: float = float(_cached_player.get("current_health")) if "current_health" in _cached_player else 100.0
		var max_hp: float = float(_cached_player.get("max_health")) if "max_health" in _cached_player else 100.0
		if (cur_hp / maxf(1.0, max_hp)) < 0.25:
			target_pitch += sin(float(Time.get_ticks_msec()) * 0.02) * 0.06

		engine_player.pitch_scale = lerpf(engine_player.pitch_scale, target_pitch, delta * 6.0)

		# Volume scaling with settings
		var master_vol: float = float(SaveSystem.get_setting("volume_master", 1.0))
		var sfx_vol: float = float(SaveSystem.get_setting("volume_sfx", 1.0))
		var base_vol := master_vol * sfx_vol * 0.32
		if base_vol <= 0.001:
			engine_player.volume_db = -80.0
		else:
			var target_db := linear_to_db(base_vol * lerpf(0.85, 1.15, speed_ratio))
			engine_player.volume_db = lerpf(engine_player.volume_db, target_db, delta * 4.0)
	else:
		if engine_player.playing:
			engine_player.stop()

func _create_procedural_rotor_stream() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 1.0 # 1 second seamless loop
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2) # 16-bit mono

	# Exactly 21 pulses per second: 22050 / 21 = 1050 samples per pulse (zero fractional seam error)
	var pulses_per_sec := 21.0
	var pulse_period_samples := float(sample_hz) / pulses_per_sec

	for i in range(num_samples):
		var t := float(i) / float(sample_hz)
		var sample_in_pulse := fmod(float(i), pulse_period_samples)
		var pulse_phase := sample_in_pulse / pulse_period_samples

		# 1. Blade-slap thump: exponential attack and decay
		var slap_envelope := pow(1.0 - pulse_phase, 2.5) * sin(pulse_phase * PI * 4.0)
		var thump := sin(pulse_phase * TAU * 3.5) * slap_envelope * 0.55

		# 2. Turbine engine whine
		var whine := (sin(t * TAU * 420.0) * 0.12) + (sin(t * TAU * 840.0) * 0.05)

		# 3. Air rotor whoosh
		var whoosh := sin(t * TAU * pulses_per_sec) * 0.18

		var total_sample := clampf(thump + whine + whoosh, -0.95, 0.95)
		var sample_16 := int(clampf(total_sample * 32767.0, -32768.0, 32767.0))
		byte_data.encode_s16(i * 2, sample_16)

	return _create_wav_resource(byte_data, sample_hz, true)

# --- Procedural Audio Synthesis Engine ---

static func _create_wav_resource(byte_data: PackedByteArray, sample_hz: int = 22050, loop: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_hz
	stream.data = byte_data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = byte_data.size() / 2
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream

func _synthesize_all_sfx() -> void:
	# Chaingun variations (3 variations to eliminate repetition flanging)
	_wav_chaingun.clear()
	for v in range(3):
		_wav_chaingun.append(_synth_chaingun_round(v))

	_wav_hellfire = _synth_hellfire_round()
	_wav_enemy_light = _synth_enemy_light_round()
	_wav_enemy_heavy = _synth_enemy_heavy_round()
	_wav_missile_launch = _synth_missile_launch_sfx()
	_wav_swarm_launch = _synth_swarm_launch_sfx()
	_wav_flares = _synth_flares_sfx()
	_wav_evade = _synth_evade_sfx()
	_wav_missile_impact = _synth_missile_impact_sfx()

	_wav_explosion_light = _synth_explosion_sfx(0)
	_wav_explosion_med = _synth_explosion_sfx(1)
	_wav_explosion_heavy = _synth_explosion_sfx(2)
	_wav_explosion_air = _synth_explosion_sfx(3)

	_wav_impact_armor = _synth_impact_armor_sfx()
	_wav_impact_terrain = _synth_impact_terrain_sfx()
	_wav_shield_hit = _synth_shield_hit_sfx()

	_wav_lock_step1 = _synth_pure_tone(740.0, 0.065, 0.35)
	_wav_lock_step2 = _synth_pure_tone(920.0, 0.075, 0.40)
	_wav_lock_acquired = _synth_dual_tone(1046.5, 1567.98, 0.18, 0.50)
	_wav_missile_warning = _synth_warble_alert(1050.0, 680.0, 0.22, 16.0)
	_wav_overheat = _synth_overheat_buzzer(880.0, 0.26)
	_wav_low_health = _synth_generic_sweep(480.0, 220.0, 0.18, false)
	_wav_no_missiles = _synth_dry_click()
	_wav_missile_pickup = _synth_ammo_pickup_sfx()

	# C-major pentatonic chimes for XP gem pickup chain
	var pentatonic := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
	_wav_xp_chimes.clear()
	for f in pentatonic:
		_wav_xp_chimes.append(_synth_bell_chime(f, 0.14))

	_wav_level_up = _synth_arpeggio_wav([523.25, 659.25, 783.99, 1046.5], 0.11)
	_wav_upgrade_applied = _synth_arpeggio_wav([587.33, 880.0, 1174.66], 0.08)
	_wav_survivor_collected = _synth_survivor_collected_sfx()
	_wav_survivors_evacuated = _synth_arpeggio_wav([440.0, 554.37, 659.25, 880.0], 0.12)
	_wav_wave_start = _synth_dual_tone(520.0, 780.0, 0.24, 0.45)
	_wav_wave_complete = _synth_arpeggio_wav([587.33, 739.99, 880.0], 0.10)
	_wav_boss_spawn = _synth_boss_warhorn(65.0, 0.90)
	_wav_boss_defeat = _synth_arpeggio_wav([440.0, 554.37, 659.25, 880.0, 1108.73], 0.12)
	_wav_attack_run_start = _synth_arpeggio_wav([440.0, 554.37, 659.25], 0.08)
	_wav_attack_run_end = _synth_arpeggio_wav([554.37, 440.0], 0.07)

func _synth_chaingun_round(var_idx: int) -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.062
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var start_freq := 270.0 + float(var_idx) * 14.0
	var end_freq := 72.0 + float(var_idx) * 4.0
	var phase := 0.0

	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 2.5)
		if t < 0.03:
			env *= (t / 0.03)

		var cur_freq := lerpf(start_freq, end_freq, pow(t, 0.4))
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var thump := sin(phase * TAU)
		var throat := sin(phase * TAU * 2.0) * 0.32
		var blast := 0.0
		if t < 0.25:
			blast = (randf() * 2.0 - 1.0) * pow(1.0 - (t / 0.25), 2.0) * 0.40

		var sample := clampf((thump + throat + blast) * env * 0.88, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_hellfire_round() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.048
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 2.2)
		if t < 0.02:
			env *= (t / 0.02)

		var cur_freq := lerpf(440.0, 105.0, pow(t, 0.35))
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var core := sin(phase * TAU) * 0.65
		var overtone := sin(phase * TAU * 3.0) * 0.25
		var sizzle := (randf() * 2.0 - 1.0) * pow(1.0 - t, 1.5) * 0.35

		var sample := clampf((core + overtone + sizzle) * env * 0.92, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_enemy_light_round() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.070
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 2.4)
		if t < 0.03:
			env *= (t / 0.03)

		var cur_freq := lerpf(175.0, 58.0, pow(t, 0.45))
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var s := sin(phase * TAU)
		var snap := (s * 1.4) - (0.4 * s * s * s)
		var noise := (randf() * 2.0 - 1.0) * 0.22 * pow(1.0 - t, 3.0)

		var sample := clampf((snap * 0.72 + noise) * env * 0.82, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_enemy_heavy_round() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.22
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 2.0)
		if t < 0.02:
			env *= (t / 0.02)

		var cur_freq := lerpf(80.0, 24.0, pow(t, 0.35))
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var bass := sin(phase * TAU) * 0.75
		var sub := sin(phase * TAU * 0.5) * 0.35
		var raw_n := randf() * 2.0 - 1.0
		noise_filt += (raw_n - noise_filt) * 0.14
		var noise := noise_filt * pow(1.0 - t, 1.8) * 0.55

		var sample := clampf((bass + sub + noise) * env * 0.94, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_missile_launch_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.32
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var punch_env := pow(clampf(1.0 - (t / 0.12), 0.0, 1.0), 2.0)
		var punch_freq := lerpf(180.0, 42.0, clampf(t / 0.12, 0.0, 1.0))
		phase += punch_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0
		var tube_thump := sin(phase * TAU) * punch_env * 0.65

		var rocket_env := 0.0
		if t > 0.04:
			var rt := (t - 0.04) / 0.96
			rocket_env = sin(rt * PI) * pow(1.0 - rt, 0.4)

		var raw_noise := randf() * 2.0 - 1.0
		var cutoff := lerpf(0.14, 0.36, t)
		noise_filt += (raw_noise - noise_filt) * cutoff
		var rocket_whoosh := noise_filt * rocket_env * 0.85

		var sample := clampf((tube_thump + rocket_whoosh) * 0.90, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_swarm_launch_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.18
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := sin(t * PI * 0.8) * pow(1.0 - t, 0.8)
		var cur_freq := lerpf(220.0, 55.0, pow(t, 0.4))
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0
		var pop := sin(phase * TAU) * pow(1.0 - clampf(t / 0.2, 0.0, 1.0), 2.0) * 0.55

		var raw := randf() * 2.0 - 1.0
		noise_filt += (raw - noise_filt) * 0.30
		var whoosh := noise_filt * env * 0.78

		var sample := clampf((pop + whoosh) * 0.88, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_flares_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.24
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var pop_env := pow(clampf(1.0 - (t / 0.14), 0.0, 1.0), 2.5)
		phase += lerpf(250.0, 48.0, clampf(t / 0.14, 0.0, 1.0)) / sample_hz
		if phase >= 1.0:
			phase -= 1.0
		var pop := sin(phase * TAU) * pop_env * 0.65

		var sizzle_env := pow(1.0 - t, 1.2) * (t / 0.05 if t < 0.05 else 1.0)
		var raw := randf() * 2.0 - 1.0
		noise_filt += (raw - noise_filt) * 0.42
		var trem := 0.8 + 0.2 * sin(float(i) * TAU * 32.0 / sample_hz)
		var sizzle := noise_filt * sizzle_env * trem * 0.68

		var sample := clampf((pop + sizzle) * 0.86, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_evade_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.32
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase1 := 0.0
	var phase2 := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := sin(t * PI)

		var f1 := 220.0 + sin(t * PI) * 190.0
		var f2 := 360.0 + sin(t * PI) * 260.0
		phase1 += f1 / sample_hz
		phase2 += f2 / sample_hz
		if phase1 >= 1.0: phase1 -= 1.0
		if phase2 >= 1.0: phase2 -= 1.0
		var turbine := (sin(phase1 * TAU) * 0.42 + sin(phase2 * TAU) * 0.25) * env

		var raw := randf() * 2.0 - 1.0
		noise_filt += (raw - noise_filt) * (0.12 + 0.18 * env)
		var air := noise_filt * env * 0.58

		var sample := clampf((turbine + air) * 0.88, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_missile_impact_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.42
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 1.8)
		if t < 0.01:
			env *= (t / 0.01)

		var cur_freq := lerpf(120.0, 24.0, pow(t, 0.35))
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var sub_boom := sin(phase * TAU) * 0.78
		var raw := randf() * 2.0 - 1.0
		noise_filt += (raw - noise_filt) * 0.18
		var crunch := noise_filt * pow(1.0 - t, 2.2) * 0.62

		var crack := 0.0
		if t < 0.03:
			crack = (randf() * 2.0 - 1.0) * pow(1.0 - (t / 0.03), 2.0) * 0.50

		var sample := clampf((sub_boom + crunch + crack) * env * 0.92, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_explosion_sfx(kind: int) -> AudioStreamWAV:
	var sample_hz := 22050
	var dur := 0.32
	var f_start := 120.0
	var f_end := 35.0
	match kind:
		0: # light
			dur = 0.28
			f_start = 140.0
			f_end = 45.0
		1: # med
			dur = 0.45
			f_start = 100.0
			f_end = 30.0
		2: # heavy
			dur = 0.75
			f_start = 75.0
			f_end = 22.0
		3: # air
			dur = 0.52
			f_start = 380.0
			f_end = 65.0

	var num_samples := int(sample_hz * dur)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 1.9)
		if t < 0.015:
			env *= (t / 0.015)

		var cur_freq := lerpf(f_start, f_end, pow(t, 0.38))
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var boom := sin(phase * TAU) * 0.72
		var raw := randf() * 2.0 - 1.0
		noise_filt += (raw - noise_filt) * (0.22 if kind == 3 else 0.15)
		var rumble := noise_filt * pow(1.0 - t, 2.0) * 0.65

		# Air explosion adds turbine stall whine
		var whine := 0.0
		if kind == 3:
			whine = sin(phase * TAU * 1.5) * pow(1.0 - t, 1.4) * 0.35

		var sample := clampf((boom + rumble + whine) * env * 0.90, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_impact_armor_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.042
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase1 := 0.0
	var phase2 := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 4.0)

		phase1 += 1850.0 / sample_hz
		phase2 += 2780.0 / sample_hz
		if phase1 >= 1.0: phase1 -= 1.0
		if phase2 >= 1.0: phase2 -= 1.0

		var ring := (sin(phase1 * TAU) * 0.65 + sin(phase2 * TAU) * 0.35) * env
		var click := 0.0
		if t < 0.08:
			click = (randf() * 2.0 - 1.0) * pow(1.0 - (t / 0.08), 2.0) * 0.40

		var sample := clampf((ring + click) * 0.85, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_impact_terrain_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.055
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 2.8)

		var cur_freq := lerpf(105.0, 36.0, pow(t, 0.4))
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var thud := sin(phase * TAU) * 0.70
		var raw := randf() * 2.0 - 1.0
		noise_filt += (raw - noise_filt) * 0.20
		var crunch := noise_filt * pow(1.0 - t, 2.0) * 0.45

		var sample := clampf((thud + crunch) * env * 0.85, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_shield_hit_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.15
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 2.0)
		var vibrato := sin(t * TAU * 120.0) * 80.0
		var freq := lerpf(1650.0, 750.0, pow(t, 0.3)) + vibrato
		phase += freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var sample := clampf(sin(phase * TAU) * env * 0.85, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_pure_tone(freq: float, duration: float, volume: float = 0.4) -> AudioStreamWAV:
	var sample_hz := 22050
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := sin(t * PI)
		phase += freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var sample := clampf(sin(phase * TAU) * env * volume, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_dual_tone(f1: float, f2: float, duration: float, volume: float = 0.45) -> AudioStreamWAV:
	var sample_hz := 22050
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var p1 := 0.0
	var p2 := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := sin(t * PI)
		p1 += f1 / sample_hz
		p2 += f2 / sample_hz
		if p1 >= 1.0: p1 -= 1.0
		if p2 >= 1.0: p2 -= 1.0

		var s := (sin(p1 * TAU) * 0.55 + sin(p2 * TAU) * 0.45) * env * volume
		byte_data.encode_s16(i * 2, int(clampf(s, -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_warble_alert(f_start: float, f_end: float, duration: float, warble_rate: float) -> AudioStreamWAV:
	var sample_hz := 22050
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := sin(t * PI)
		var warble := sin(t * TAU * warble_rate) * 90.0
		var freq := lerpf(f_start, f_end, t) + warble
		phase += freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var sample := clampf(sin(phase * TAU) * env * 0.55, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_overheat_buzzer(freq: float, duration: float) -> AudioStreamWAV:
	var sample_hz := 22050
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		# Dual pulse buzz
		var gate := 1.0 if fmod(t * 8.0, 1.0) < 0.65 else 0.0
		var env := sin(t * PI) * gate
		phase += freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		# Square-ish tone with odd harmonics
		var s := (sin(phase * TAU) * 0.7 + sin(phase * TAU * 3.0) * 0.3) * env * 0.55
		byte_data.encode_s16(i * 2, int(clampf(s, -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_dry_click() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.06
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 3.5)
		phase += lerpf(350.0, 120.0, t) / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var click := sin(phase * TAU) * env * 0.55
		byte_data.encode_s16(i * 2, int(clampf(click, -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_ammo_pickup_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.16
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase1 := 0.0
	var phase2 := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 2.0)
		if t < 0.05:
			env *= (t / 0.05)

		phase1 += 880.0 / sample_hz
		phase2 += 1320.0 / sample_hz
		if phase1 >= 1.0: phase1 -= 1.0
		if phase2 >= 1.0: phase2 -= 1.0

		var clack := 0.0
		if t < 0.15:
			clack = (randf() * 2.0 - 1.0) * pow(1.0 - (t / 0.15), 2.0) * 0.35

		var chime := (sin(phase1 * TAU) * 0.6 + sin(phase2 * TAU) * 0.4) * env * 0.45
		byte_data.encode_s16(i * 2, int(clampf((chime + clack), -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_bell_chime(freq: float, duration: float) -> AudioStreamWAV:
	var sample_hz := 22050
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := pow(1.0 - t, 2.2)
		if t < 0.04:
			env *= (t / 0.04)

		p1 += freq / sample_hz
		p2 += (freq * 2.005) / sample_hz # slight detuning for shimmer
		p3 += (freq * 3.01) / sample_hz
		if p1 >= 1.0: p1 -= 1.0
		if p2 >= 1.0: p2 -= 1.0
		if p3 >= 1.0: p3 -= 1.0

		var s := (sin(p1 * TAU) * 0.65 + sin(p2 * TAU) * 0.25 + sin(p3 * TAU) * 0.10) * env * 0.48
		byte_data.encode_s16(i * 2, int(clampf(s, -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_survivor_collected_sfx() -> AudioStreamWAV:
	var sample_hz := 22050
	var duration := 0.22
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		# Winch click in first 40ms, followed by friendly two-tone radio pip
		var click := 0.0
		if t < 0.18:
			click = (randf() * 2.0 - 1.0) * pow(1.0 - (t / 0.18), 2.0) * 0.45

		var pip_env := 0.0
		var pip_freq := 659.25
		if t >= 0.15 and t < 0.55:
			pip_env = sin((t - 0.15) / 0.40 * PI)
			pip_freq = 659.25 # E5
		elif t >= 0.55:
			pip_env = sin((t - 0.55) / 0.45 * PI)
			pip_freq = 987.77 # B5

		phase += pip_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var s := (click + sin(phase * TAU) * pip_env * 0.50) * 0.85
		byte_data.encode_s16(i * 2, int(clampf(s, -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_boss_warhorn(base_freq: float, duration: float) -> AudioStreamWAV:
	var sample_hz := 22050
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := sin(t * PI)

		p1 += base_freq / sample_hz
		p2 += (base_freq * 2.0) / sample_hz
		p3 += (base_freq * 3.0) / sample_hz
		if p1 >= 1.0: p1 -= 1.0
		if p2 >= 1.0: p2 -= 1.0
		if p3 >= 1.0: p3 -= 1.0

		var horn := (sin(p1 * TAU) * 0.55 + sin(p2 * TAU) * 0.30 + sin(p3 * TAU) * 0.15) * env * 0.75
		byte_data.encode_s16(i * 2, int(clampf(horn, -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_arpeggio_wav(freqs: Array[float], note_dur: float) -> AudioStreamWAV:
	if freqs.is_empty():
		return _synth_pure_tone(440.0, 0.1)

	var sample_hz := 22050
	var total_dur := freqs.size() * note_dur
	var num_samples := int(sample_hz * total_dur)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var note_samples := int(sample_hz * note_dur)
	for note_idx in range(freqs.size()):
		var freq := freqs[note_idx]
		var phase := 0.0
		var start_i := note_idx * note_samples
		var end_i := mini(num_samples, start_i + note_samples)

		for i in range(start_i, end_i):
			var local_t := float(i - start_i) / float(note_samples)
			var env := sin(local_t * PI)
			phase += freq / sample_hz
			if phase >= 1.0:
				phase -= 1.0

			var s := sin(phase * TAU) * env * 0.48
			byte_data.encode_s16(i * 2, int(clampf(s, -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)

func _synth_generic_sweep(freq_start: float, freq_end: float, duration: float, is_noise: bool) -> AudioStreamWAV:
	var sample_hz := 22050
	var num_samples := int(sample_hz * duration)
	var byte_data := PackedByteArray()
	byte_data.resize(num_samples * 2)

	var phase := 0.0
	var noise_filt := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		var env := (1.0 - t) * (1.0 - t)
		var cur_freq := lerpf(freq_start, freq_end, t)
		phase += cur_freq / sample_hz
		if phase >= 1.0:
			phase -= 1.0

		var s := 0.0
		if is_noise:
			var raw := randf() * 2.0 - 1.0
			noise_filt += (raw - noise_filt) * 0.25
			s = noise_filt * env * 0.65
		else:
			s = sin(phase * TAU) * env * 0.55

		byte_data.encode_s16(i * 2, int(clampf(s, -0.98, 0.98) * 32767.0))

	return _create_wav_resource(byte_data, sample_hz)
