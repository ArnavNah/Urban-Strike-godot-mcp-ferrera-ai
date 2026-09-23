class_name SoundManager
extends Node

## Procedural arcade sound manager providing real-time audio synthesis

@onready var chaingun_player: AudioStreamPlayer = $ChaingunPlayer
@onready var alert_player: AudioStreamPlayer = $AlertPlayer
@onready var explosion_player: AudioStreamPlayer = $ExplosionPlayer

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_idx: int = 0
const SFX_POOL_SIZE: int = 8

var _prev_overheated: bool = false
var _prev_player_health: float = 100.0
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Initialize round-robin voice pool to prevent rapid sound dropouts
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SfxVoice_%d" % i
		add_child(p)
		_sfx_pool.append(p)

	if EventBus:
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
		if EventBus.has_signal("setting_changed"):
			EventBus.setting_changed.connect(_on_setting_changed)

	apply_volume_settings()

func apply_volume_settings() -> void:
	var master_vol: float = float(SaveSystem.get_setting("volume_master", 1.0))
	var sfx_vol: float = float(SaveSystem.get_setting("volume_sfx", 1.0))
	var music_vol: float = float(SaveSystem.get_setting("volume_music", 1.0))

	# Update AudioServer buses if present
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

	var all_players := [chaingun_player, alert_player, explosion_player]
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
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_idx]
	_sfx_pool_idx = (_sfx_pool_idx + 1) % _sfx_pool.size()
	return player

func play_sfx(sfx_name: String) -> void:
	match sfx_name:
		"explosion":
			_play_sweep(95.0, 45.0, 0.45, 0.45)
		"shot", "laser":
			_play_sweep(190.0, 95.0, 0.04, 0.28)
		"alert":
			_play_tone(alert_player, 880.0, 0.2)

# --- Event Bus Combat Feedback Handlers ---

func _on_player_fired_primary(_muzzle_pos: Vector3, _dir: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_player_shot_time < 0.05:
		return
	_last_player_shot_time = now
	_play_sweep(190.0, 95.0, 0.04, 0.26)

func _on_enemy_fired_weapon(_enemy: Node3D, _muzzle_pos: Vector3, _dir: Vector3, is_heavy: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_enemy_shot_time < 0.06:
		return
	_last_enemy_shot_time = now
	if is_heavy:
		# Heavy cannon / mortar: low menacing launch thump
		_play_sweep(105.0, 36.0, 0.12, 0.42, true)
		_play_tone(alert_player, 65.0, 0.15)
	else:
		_play_sweep(135.0, 62.0, 0.06, 0.30)

func _on_combat_impact(_hit_pos: Vector3, _normal: Vector3, is_armored: bool, _is_lethal: bool) -> void:
	# Distance culling if camera is present and hit is beyond 140m
	if _hit_pos != Vector3.ZERO and is_inside_tree() and get_viewport():
		var camera := get_viewport().get_camera_3d()
		if camera and camera.global_position.distance_squared_to(_hit_pos) > 140.0 * 140.0:
			return

	var now := Time.get_ticks_msec() / 1000.0
	if is_armored:
		if now - _last_impact_armor_time < 0.04:
			return
		_last_impact_armor_time = now
		var pitch_var := randf_range(0.95, 1.05)
		_play_sweep(1500.0 * pitch_var, 950.0 * pitch_var, 0.035, 0.22)
	else:
		if now - _last_impact_terrain_time < 0.05:
			return
		_last_impact_terrain_time = now
		var pitch_var := randf_range(0.93, 1.07)
		_play_sweep(105.0 * pitch_var, 45.0 * pitch_var, 0.04, 0.18, true)

func _on_player_damaged_directional(_amount: float, _hit_pos: Vector3, _source_pos: Vector3, is_shield_hit: bool, _metadata: Dictionary = {}) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_player_hit_time < 0.06:
		return
	_last_player_hit_time = now
	if is_shield_hit:
		_play_sweep(1850.0, 1100.0, 0.12, 0.35)
	else:
		_play_sweep(115.0, 45.0, 0.15, 0.42)

func _on_upgrade_applied(_upgrade_id: String) -> void:
	_play_arpeggio(alert_player, [587.33, 880.0, 1174.66], 0.07)

func _on_heat_changed(_current_heat: float, _max_heat: float, is_overheated: bool) -> void:
	if is_overheated and not _prev_overheated:
		_play_tone(alert_player, 880.0, 0.35)
	_prev_overheated = is_overheated

func _on_health_changed(current_health: float, max_health: float) -> void:
	if current_health < _prev_player_health:
		if max_health > 0.0 and current_health <= max_health * 0.25:
			_play_sweep(480.0, 220.0, 0.16, 0.45)
		else:
			_play_tone(alert_player, 240.0, 0.12)
	_prev_player_health = current_health

func _on_missile_impact(_impact_pos: Vector3, _is_player: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_missile_impact_time < 0.05:
		return
	_last_missile_impact_time = now
	_play_sweep(145.0, 42.0, 0.26, 0.40)

func _on_enemy_destroyed(enemy: Node3D, points: int) -> void:
	var is_air := false
	if is_instance_valid(enemy):
		if enemy.is_in_group("air_enemies") or enemy is AirEnemyController or enemy is HunterHelicopter or enemy is Mig17Striker:
			is_air = true

	if is_air:
		# Aircraft destruction: descending airframe decompression whine / screech + secondary explosion pop
		_play_sweep(340.0, 85.0, 0.38, 0.40)
		_play_tone(explosion_player, 70.0, 0.45)
	elif points >= 150:
		# Major destruction (command unit, boss, radar, high-threat elite)
		_play_tone(explosion_player, 48.0, 0.85)
		_play_sweep(75.0, 28.0, 0.48, 0.48, true)
	elif points >= 25:
		# Standard ground armor / turret destruction: deep mechanical bass rumble + crunch
		_play_tone(explosion_player, 55.0, 0.60)
		_play_sweep(90.0, 35.0, 0.35, 0.38, true)
	else:
		# Light unit destruction
		_play_tone(explosion_player, 95.0, 0.35)

func _on_missile_lock(progress: float, _target: Node3D, is_locked: bool) -> void:
	if is_locked and not _was_missile_locked:
		_play_tone(alert_player, 1200.0, 0.2) # High tone lock-acquired beep
		_last_lock_progress_step = 3
	elif not is_locked:
		if progress >= 0.66 and _last_lock_progress_step < 2:
			_last_lock_progress_step = 2
			_play_tone(alert_player, 920.0, 0.08)
		elif progress >= 0.33 and _last_lock_progress_step < 1:
			_last_lock_progress_step = 1
			_play_tone(alert_player, 740.0, 0.08)
		elif progress < 0.15:
			_last_lock_progress_step = 0
	_was_missile_locked = is_locked

func _on_missile_fired() -> void:
	_play_tone(chaingun_player, 320.0, 0.25)

func _on_flares_updated(_left: int, _max: int, _is_ready: bool) -> void:
	_play_tone(chaingun_player, 640.0, 0.15)

func _on_missile_warning(_pos: Vector3, is_active: bool) -> void:
	if is_active:
		# Urgent incoming missile alert warble (980Hz -> 650Hz sweep)
		_play_sweep(980.0, 650.0, 0.16, 0.38)

func _on_level_up(_level: int) -> void:
	_play_arpeggio(alert_player, [523.25, 659.25, 783.99, 1046.5], 0.11)

func _on_xp_collected(_amount: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_xp_sound_time < 0.05:
		return
	if now - _last_xp_sound_time > 0.75:
		_xp_combo_step = 0
	_last_xp_sound_time = now
	var pentatonic: Array[float] = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
	var freq: float = pentatonic[_xp_combo_step % pentatonic.size()]
	_xp_combo_step += 1
	_play_tone(alert_player, freq, 0.08)

func _play_arpeggio(player: AudioStreamPlayer, freqs: Array[float], note_dur: float) -> void:
	if not player or freqs.is_empty():
		return
	var sample_hz := 22050.0
	var total_dur: float = freqs.size() * note_dur
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_hz
	gen.buffer_length = total_dur + 0.1
	player.stream = gen
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		for note_idx in range(freqs.size()):
			var freq: float = freqs[note_idx]
			var frames: int = int(sample_hz * note_dur)
			var phase := 0.0
			var phase_inc := freq / sample_hz
			for i in range(frames):
				var t := float(i) / float(frames)
				var env := sin(t * PI)
				var sample := sin(phase * TAU) * env * 0.42
				playback.push_frame(Vector2(sample, sample))
				phase += phase_inc
				if phase >= 1.0:
					phase -= 1.0

func _on_boss_spawned(_boss: Node3D) -> void:
	_play_tone(explosion_player, 80.0, 0.8) # Deep boss warhorn

func _on_wave_started(wave_num: int, _announcement: String) -> void:
	if wave_num == 10:
		_play_tone(alert_player, 440.0, 0.5) # Ominous final wave tone
	else:
		_play_tone(alert_player, 520.0, 0.25) # Crisp wave departure chime

func _on_player_died() -> void:
	_play_tone(explosion_player, 65.0, 1.0) # Heavy destruction blast

func _on_no_missiles_warning() -> void:
	_play_tone(alert_player, 160.0, 0.12) # Low dry click/buzz for empty missiles

func _on_missile_pickup_collected(_amount: int) -> void:
	_play_tone(chaingun_player, 880.0, 0.18) # Crisp ammo pickup chime

func _play_sweep(freq_start: float, freq_end: float, duration: float, volume: float = 0.35, is_noise: bool = false) -> void:
	var player: AudioStreamPlayer = _get_pooled_player()
	if not player:
		return
	var sample_hz := 22050.0
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_hz
	gen.buffer_length = duration + 0.05
	player.stream = gen
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(sample_hz * duration)
		var phase := 0.0
		var phase_inc_start := freq_start / sample_hz
		var phase_inc_end := freq_end / sample_hz
		for i in range(frames):
			var t := float(i) / float(frames)
			var env := (1.0 - t) * (1.0 - t)
			var phase_inc := lerpf(phase_inc_start, phase_inc_end, t)
			var sample := 0.0
			if is_noise:
				sample = (randf() * 2.0 - 1.0) * env * volume
			else:
				sample = sin(phase * TAU) * env * volume
			playback.push_frame(Vector2(sample, sample))
			phase += phase_inc
			if phase >= 1.0:
				phase -= 1.0

func _play_tone(player: AudioStreamPlayer, freq: float, duration: float) -> void:
	if not player:
		return
	var sample_hz := 22050.0
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = sample_hz
	gen.buffer_length = duration + 0.1
	player.stream = gen
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(sample_hz * duration)
		var phase := 0.0
		var phase_inc := freq / sample_hz
		for i in range(frames):
			var t := float(i) / float(frames)
			var env := (1.0 - t) * (1.0 - t)
			var sample := sin(phase * TAU) * env * 0.4
			playback.push_frame(Vector2(sample, sample))
			phase += phase_inc
			if phase >= 1.0:
				phase -= 1.0
