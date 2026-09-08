class_name RunStateController
extends Node

## Central run lifecycle controller managing transitions between
## PREPARING, PLAYING, PLAYER_DYING, GAME_OVER, and VICTORY states.

enum State {
	PREPARING,
	PLAYING,
	PLAYER_DYING,
	GAME_OVER,
	VICTORY,
	TRANSITIONING
}

signal run_started()
signal player_death_started()
signal game_over_shown(stats: Dictionary)
signal victory_started(stats: Dictionary)
signal run_ended(won: bool)

@export var player: PlayerHelicopter = null
@export var wave_manager: WaveManager = null
@export var hud: HUD = null
@export var end_screen: RunEndScreen = null
@export var death_fx_scene: PackedScene = preload("res://scenes/vfx/player_death_fx.tscn")

var current_state: State = State.PREPARING

# Run statistics
var run_time_seconds: float = 0.0
var highest_wave: int = 1
var enemies_destroyed: int = 0
var salvage_collected: int = 0

var _is_ending_guarded: bool = false
var _pause_reasons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("run_state_controller")

	_resolve_dependencies()
	_connect_signals()

func _resolve_dependencies() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as PlayerHelicopter
	if not wave_manager:
		wave_manager = get_tree().get_first_node_in_group("wave_manager") as WaveManager
	if not hud:
		hud = get_tree().get_first_node_in_group("hud") as HUD
	if not end_screen:
		end_screen = get_tree().get_first_node_in_group("run_end_screen") as RunEndScreen

func _connect_signals() -> void:
	if player:
		if player.has_signal("died"):
			player.died.connect(_on_player_died)
	# EventBus fallback
	if EventBus:
		EventBus.player_died.connect(_on_player_died)
		EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
		EventBus.salvage_updated.connect(_on_salvage_updated)

	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.run_completed.connect(_on_wave_run_completed)

func _process(delta: float) -> void:
	if current_state == State.PLAYING and not get_tree().paused:
		run_time_seconds += delta

func set_pause_reason(reason: StringName, enabled: bool) -> bool:
	# Gameplay modals own separate reasons; results/death keep their own pause.
	if _is_ending_guarded:
		return false
	if enabled:
		_pause_reasons[reason] = true
	else:
		_pause_reasons.erase(reason)
	var should_pause := not _pause_reasons.is_empty()
	var changed := get_tree().paused != should_pause
	get_tree().paused = should_pause
	if changed and EventBus:
		EventBus.game_paused.emit(should_pause)
	return true

func has_pause_reason(reason: StringName) -> bool:
	return _pause_reasons.has(reason)

func _on_wave_started(wave_num: int, _total: int) -> void:
	highest_wave = maxi(highest_wave, wave_num)
	if current_state == State.PREPARING:
		current_state = State.PLAYING
		emit_signal("run_started")
		if is_instance_valid(player) and player.missile_pod and player.missile_pod.has_method("reset_ammo"):
			player.missile_pod.reset_ammo()
		var spawner := get_tree().get_first_node_in_group("spawn_director")
		if spawner and spawner.has_method("clear_missile_pickups"):
			spawner.clear_missile_pickups()

func _on_enemy_destroyed(_enemy: Node, _points: int) -> void:
	if current_state == State.PLAYING or current_state == State.PREPARING:
		enemies_destroyed += 1

func _on_salvage_updated(amount: int) -> void:
	salvage_collected = amount

func _on_player_died() -> void:
	if _is_ending_guarded:
		return
	_is_ending_guarded = true

	current_state = State.PLAYER_DYING
	emit_signal("player_death_started")

	# 1. 0.00s: Disable control, stop weapons and spawning
	if player and player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	if wave_manager and wave_manager.has_method("stop_run"):
		wave_manager.stop_run()
	if CombatDirector.instance:
		CombatDirector.instance.set_wave_limits(0, 0)

	# 2. 0.05s: Camera shake and flash
	if EventBus and EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.emit(0.7)

	# 3. 0.15s: Slowdown beat and main explosion
	Engine.time_scale = 0.25

	if death_fx_scene and is_instance_valid(player):
		var fx := death_fx_scene.instantiate() as Node3D
		if fx:
			var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
			parent.add_child(fx)
			fx.global_position = player.global_position

	# 4. 0.25s (real time): Hide helicopter model, disable collision
	await get_tree().create_timer(0.25, true, false, true).timeout

	if is_instance_valid(player):
		if player.has_method("hide_visuals"):
			player.hide_visuals()
		if player.has_method("disable_collision"):
			player.disable_collision()

	# 5. 0.85s (real time): Restore time_scale, pause game, display Game Over UI
	await get_tree().create_timer(0.60, true, false, true).timeout

	Engine.time_scale = 1.0
	get_tree().paused = true
	current_state = State.GAME_OVER

	var stats := _build_stats(false)
	emit_signal("game_over_shown", stats)
	emit_signal("run_ended", false)

	if not end_screen:
		end_screen = get_tree().get_first_node_in_group("run_end_screen") as RunEndScreen

	if end_screen and end_screen.has_method("display_game_over"):
		end_screen.display_game_over(stats)

func on_endless_mode_entered() -> void:
	_is_ending_guarded = false
	current_state = State.PLAYING
	if player and player.has_method("set_control_enabled"):
		player.set_control_enabled(true)
	get_tree().paused = false

func _on_wave_run_completed() -> void:
	if _is_ending_guarded:
		return
	if is_instance_valid(player) and not player.is_alive:
		return

	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm and gm.is_endless_mode:
		if EventBus:
			EventBus.extraction_decision_requested.emit(gm.run_salvage)
		return

	# If victory screen is present, offer extraction vs endless overdrive choice
	var vic_screen := get_tree().get_first_node_in_group("victory_screen")
	if vic_screen and vic_screen.has_method("display_victory"):
		var salvage_amt: int = gm.run_salvage if gm else salvage_collected
		vic_screen.display_victory(salvage_amt)
		return

	_is_ending_guarded = true
	current_state = State.VICTORY

	# Disable player weapons and new damage
	if player and player.has_method("set_control_enabled"):
		player.set_control_enabled(false)
	if CombatDirector.instance:
		CombatDirector.instance.set_wave_limits(0, 0)

	# Brief victory celebration delay
	await get_tree().create_timer(1.2, true, false, true).timeout

	get_tree().paused = true
	var stats := _build_stats(true)
	emit_signal("victory_started", stats)
	emit_signal("run_ended", true)

	if not end_screen:
		end_screen = get_tree().get_first_node_in_group("run_end_screen") as RunEndScreen

	if end_screen and end_screen.has_method("display_victory"):
		end_screen.display_victory(stats)

func _build_stats(won: bool) -> Dictionary:
	var salvage_total := salvage_collected
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm:
		salvage_total = gm.run_salvage

	return {
		"run_time": run_time_seconds,
		"highest_wave": highest_wave,
		"enemies_destroyed": enemies_destroyed,
		"salvage": salvage_total,
		"won": won
	}
