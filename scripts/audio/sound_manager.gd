class_name SoundManager
extends Node

## Procedural arcade sound manager providing real-time audio synthesis

@onready var chaingun_player: AudioStreamPlayer = $ChaingunPlayer
@onready var alert_player: AudioStreamPlayer = $AlertPlayer
@onready var explosion_player: AudioStreamPlayer = $ExplosionPlayer

var _prev_overheated: bool = false
var _prev_player_health: float = 100.0
var _was_missile_locked: bool = false
var _last_xp_sound_time: float = 0.0
var _xp_combo_step: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		if EventBus.has_signal("no_missiles_warning"):
			EventBus.no_missiles_warning.connect(_on_no_missiles_warning)
		if EventBus.has_signal("missile_pickup_collected"):
			EventBus.missile_pickup_collected.connect(_on_missile_pickup_collected)
		if EventBus.has_signal("xp_collected"):
			EventBus.xp_collected.connect(_on_xp_collected)

func _on_heat_changed(_current_heat: float, _max_heat: float, is_overheated: bool) -> void:
	if is_overheated and not _prev_overheated:
		_play_tone(alert_player, 880.0, 0.35)
	_prev_overheated = is_overheated

func _on_health_changed(current_health: float, _max_health: float) -> void:
	if current_health < _prev_player_health:
		_play_tone(alert_player, 240.0, 0.12)
	_prev_player_health = current_health

func _on_enemy_destroyed(_enemy: Node3D, points: int) -> void:
	if points >= 25:
		_play_tone(explosion_player, 75.0, 0.6)
	else:
		_play_tone(explosion_player, 110.0, 0.4)

func _on_missile_lock(_progress: float, _target: Node3D, is_locked: bool) -> void:
	if is_locked and not _was_missile_locked:
		_play_tone(alert_player, 1200.0, 0.2) # High tone lock-acquired beep
	_was_missile_locked = is_locked

func _on_missile_fired() -> void:
	_play_tone(chaingun_player, 320.0, 0.25)

func _on_flares_updated(_left: int, _max: int, _is_ready: bool) -> void:
	_play_tone(chaingun_player, 640.0, 0.15)

func _on_missile_warning(_pos: Vector3, is_active: bool) -> void:
	if is_active:
		_play_tone(alert_player, 950.0, 0.18)

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
