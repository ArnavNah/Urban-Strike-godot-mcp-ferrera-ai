class_name WaveManager
extends Node

## Component-based 10-wave manager.
## Drives a timed ~4 minute 39 second run using Godot-native Timer nodes.
## Controls wave progression, difficulty budgets, enemy population caps, and transitions.

enum State {
	IDLE,
	DEPLOYMENT_COUNTDOWN,
	ACTIVE_WAVE,
	INTERMISSION,
	RUN_COMPLETE,
	STOPPED
}

signal deployment_countdown_changed(seconds_left: int)
signal wave_started(wave_number: int, total_waves: int)
signal wave_time_changed(time_left: float)
signal enemy_count_changed(active_count: int)
signal wave_completed(wave_number: int)
@warning_ignore("unused_signal")
signal intermission_started(next_wave: int, duration: float)
@warning_ignore("unused_signal")
signal run_completed()

@export_category("Wave Configuration")
@export var wave_definitions: Array[WaveDefinition] = []
@export var total_waves: int = 10
@export var opening_countdown_duration: int = 3
@export var intermission_duration: float = 4.0
@export var autostart_run: bool = true

@export_category("Node References")
@export var enemy_container: Node3D = null
@export var spawn_points_parent: Node3D = null
@export var spawn_director: SpawnDirector = null

var current_state: State = State.IDLE
var current_wave_index: int = 0
var elapsed_survival_time: float = 0.0
var _current_wave_def: WaveDefinition = null
var _remaining_budget: int = 0
var _countdown_seconds: int = 0
var _active_enemies: Array[Node] = []
var _spawn_markers: Array[Marker3D] = []

@onready var wave_timer: Timer = $WaveTimer
@onready var intermission_timer: Timer = $IntermissionTimer
@onready var spawn_timer: Timer = $SpawnTimer
@onready var countdown_timer: Timer = $CountdownTimer

func _ready() -> void:
	add_to_group("wave_manager")
	_setup_timers()
	_load_default_definitions_if_empty()
	_collect_spawn_points()

	if not spawn_director:
		spawn_director = get_node_or_null("../SpawnSystem") as SpawnDirector
		if not spawn_director:
			spawn_director = get_node_or_null("../SpawnDirector") as SpawnDirector
		if not spawn_director:
			var group_sd := get_tree().get_first_node_in_group("spawn_director") as SpawnDirector
			if group_sd:
				spawn_director = group_sd

	if autostart_run:
		# Short frame delay to allow other battlefield systems to initialize
		get_tree().create_timer(0.1, false).timeout.connect(start_run)

func _setup_timers() -> void:
	if not wave_timer:
		wave_timer = Timer.new()
		wave_timer.name = "WaveTimer"
		add_child(wave_timer)
	wave_timer.one_shot = true
	wave_timer.timeout.connect(_on_wave_timer_timeout)

	if not intermission_timer:
		intermission_timer = Timer.new()
		intermission_timer.name = "IntermissionTimer"
		add_child(intermission_timer)
	intermission_timer.one_shot = true
	intermission_timer.timeout.connect(_on_intermission_timer_timeout)

	if not spawn_timer:
		spawn_timer = Timer.new()
		spawn_timer.name = "SpawnTimer"
		add_child(spawn_timer)
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	if not countdown_timer:
		countdown_timer = Timer.new()
		countdown_timer.name = "CountdownTimer"
		add_child(countdown_timer)
	countdown_timer.one_shot = false
	countdown_timer.timeout.connect(_on_countdown_timer_timeout)

func _load_default_definitions_if_empty() -> void:
	if wave_definitions.is_empty():
		for i in range(1, total_waves + 1):
			var path := "res://resources/waves/wave_%02d.tres" % i
			if ResourceLoader.exists(path):
				var def := load(path) as WaveDefinition
				if def:
					wave_definitions.append(def)

func _collect_spawn_points() -> void:
	_spawn_markers.clear()
	if spawn_points_parent:
		for child in spawn_points_parent.get_children():
			if child is Marker3D:
				_spawn_markers.append(child)
	if _spawn_markers.is_empty():
		var group_nodes := get_tree().get_nodes_in_group("enemy_spawn_point")
		for node in group_nodes:
			if node is Marker3D and not _spawn_markers.has(node):
				_spawn_markers.append(node)

func _process(delta: float) -> void:
	if current_state == State.ACTIVE_WAVE:
		elapsed_survival_time += delta
		emit_signal("wave_time_changed", elapsed_survival_time)

func start_run() -> void:
	current_state = State.ACTIVE_WAVE
	_countdown_seconds = 0
	emit_signal("deployment_countdown_changed", 0)
	start_wave(1)

func _on_countdown_timer_timeout() -> void:
	countdown_timer.stop()
	if current_state != State.ACTIVE_WAVE:
		start_wave(1)

func start_wave(index: int) -> void:
	current_wave_index = index
	current_state = State.ACTIVE_WAVE

	if index >= 1 and index <= wave_definitions.size():
		_current_wave_def = wave_definitions[index - 1]
	else:
		_current_wave_def = null

	if _current_wave_def:
		_remaining_budget = _current_wave_def.spawn_budget
		wave_timer.wait_time = _current_wave_def.duration
		spawn_timer.wait_time = _current_wave_def.spawn_interval

		if CombatDirector.instance:
			CombatDirector.instance.set_wave_limits(
				_current_wave_def.ground_attack_slots,
				_current_wave_def.air_attack_slots
			)

		if EventBus:
			EventBus.wave_started.emit(current_wave_index, _current_wave_def.announcement)
	else:
		var endless_lvl: int = maxi(1, index - total_waves)
		_remaining_budget = 120 + endless_lvl * 35
		wave_timer.wait_time = 35.0
		spawn_timer.wait_time = 2.0
		if CombatDirector.instance:
			CombatDirector.instance.set_wave_limits(
				mini(4 + int(float(endless_lvl) * 0.5), 6),
				mini(2 + int(float(endless_lvl) * 0.33), 4)
			)
		if EventBus:
			EventBus.wave_started.emit(current_wave_index, "ENDLESS OVERDRIVE // WAVE %d (2.0x SALVAGE)" % current_wave_index)

	if not spawn_director or not spawn_director.is_continuous_mode:
		wave_timer.start()
		spawn_timer.start()

	emit_signal("wave_started", current_wave_index, total_waves)
	emit_signal("wave_time_changed", elapsed_survival_time)
	# Trigger SpawnDirector wave and tactical formations
	if spawn_director:
		spawn_director.start_wave(current_wave_index)
		for e in spawn_director._wave_enemies:
			if is_instance_valid(e) and not _active_enemies.has(e):
				register_spawned_enemy(e)

	# Initial spawn attempt only if spawn_director is NOT handling continuous mode
	if not spawn_director or not spawn_director.is_continuous_mode:
		_try_spawn_enemy()

func _on_spawn_timer_timeout() -> void:
	if current_state != State.ACTIVE_WAVE:
		return

	if spawn_director and spawn_director.is_continuous_mode:
		spawn_timer.stop()
		return

	var max_alive: int = _current_wave_def.maximum_alive if _current_wave_def else 20
	if _active_enemies.size() >= max_alive:
		return

	if _remaining_budget <= 0:
		spawn_timer.stop()
		return

	_try_spawn_enemy()

func _try_spawn_enemy() -> void:
	var entries: Array[WaveEnemyEntry] = []
	var max_alive: int = 20
	if _current_wave_def:
		entries = _current_wave_def.enemy_entries
		max_alive = _current_wave_def.maximum_alive
	elif not wave_definitions.is_empty():
		var template := wave_definitions[wave_definitions.size() - 1]
		entries = template.enemy_entries
		max_alive = 20

	if entries.is_empty():
		return
	if _active_enemies.size() >= max_alive:
		return

	var affordable: Array[WaveEnemyEntry] = []
	var total_weight: float = 0.0

	for entry in entries:
		if entry and entry.enemy_scene and entry.spawn_cost <= _remaining_budget:
			affordable.append(entry)
			total_weight += entry.spawn_weight

	if affordable.is_empty() or total_weight <= 0.0:
		spawn_timer.stop()
		return

	# Weighted selection
	var roll := randf() * total_weight
	var cumulative := 0.0
	var chosen: WaveEnemyEntry = affordable[0]
	for entry in affordable:
		cumulative += entry.spawn_weight
		if roll <= cumulative:
			chosen = entry
			break

	var spawn_marker := _select_spawn_marker()
	if not spawn_marker:
		return

	var enemy := chosen.enemy_scene.instantiate() as Node3D
	if not enemy:
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var p_y := player.global_position.y if player else 14.0

	var spawn_pos := spawn_marker.global_position
	if chosen.category == WaveEnemyEntry.EnemyCategory.AIR or chosen.category == WaveEnemyEntry.EnemyCategory.BOSS:
		spawn_pos.y = clampf(p_y, 8.0, 22.0)
	else:
		spawn_pos.y = 0.0

	var container: Node = enemy_container
	if not container:
		container = get_tree().current_scene if get_tree().current_scene else get_tree().root

	# Ground spawn warning telegraph
	var tele_scene: PackedScene = preload("res://scenes/vfx/spawn_telegraph_fx.tscn")
	if tele_scene and chosen.category != WaveEnemyEntry.EnemyCategory.AIR and chosen.category != WaveEnemyEntry.EnemyCategory.BOSS:
		var tele := tele_scene.instantiate() as Node3D
		if tele:
			container.add_child(tele)
			tele.global_position = Vector3(spawn_pos.x, 0.05, spawn_pos.z)

	container.add_child(enemy)
	enemy.global_position = spawn_pos
	register_spawned_enemy(enemy)
	_remaining_budget -= chosen.spawn_cost

func _select_spawn_marker() -> Marker3D:
	if _spawn_markers.is_empty():
		_collect_spawn_points()
	if _spawn_markers.is_empty():
		return null

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var p_pos := player.global_position if player else Vector3.ZERO
	var cam := get_viewport().get_camera_3d() if get_viewport() else null

	var distant_candidates: Array[Marker3D] = []
	var offscreen_candidates: Array[Marker3D] = []

	for marker in _spawn_markers:
		if not is_instance_valid(marker):
			continue
		var flat_dist := Vector2(marker.global_position.x - p_pos.x, marker.global_position.z - p_pos.z).length()
		if flat_dist >= 28.0:
			distant_candidates.append(marker)
			if cam:
				var is_behind := cam.is_position_behind(marker.global_position)
				if is_behind or not cam.is_position_in_frustum(marker.global_position):
					offscreen_candidates.append(marker)

	if not offscreen_candidates.is_empty():
		return offscreen_candidates.pick_random()
	if not distant_candidates.is_empty():
		return distant_candidates.pick_random()
	return _spawn_markers.pick_random()

func register_spawned_enemy(enemy: Node) -> void:
	if not enemy or _active_enemies.has(enemy):
		return
	_active_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))
	emit_signal("enemy_count_changed", _active_enemies.size())

func _on_enemy_tree_exited(enemy: Node) -> void:
	_active_enemies.erase(enemy)
	emit_signal("enemy_count_changed", _active_enemies.size())

	# If wave is active and budget remains, resume spawn timer if stopped (non-continuous wave mode only)
	if not (spawn_director and spawn_director.is_continuous_mode):
		if current_state == State.ACTIVE_WAVE and _remaining_budget > 0 and spawn_timer and spawn_timer.is_inside_tree() and spawn_timer.is_stopped():
			spawn_timer.start()

func _on_wave_timer_timeout() -> void:
	emit_signal("wave_completed", current_wave_index)
	if EventBus:
		EventBus.wave_completed.emit(current_wave_index)

	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	if gm and gm.has_method("add_salvage"):
		var mult: float = 2.0 if current_wave_index > total_waves else 1.0
		gm.add_salvage(int(current_wave_index * 50 * mult))

	var is_endless: bool = gm.is_endless_mode if gm else false
	if current_wave_index >= total_waves:
		if EventBus:
			EventBus.extraction_decision_requested.emit(gm.run_salvage if gm else 0)
	elif is_endless and EventBus:
		EventBus.extraction_decision_requested.emit(gm.run_salvage if gm else 0)

	# Continuous survival escalation: advance to next stage without clearing enemies
	start_wave(current_wave_index + 1)

func enter_endless_mode() -> void:
	current_state = State.INTERMISSION
	start_wave(total_waves + 1)

func _cleanup_surviving_enemies() -> void:
	var enemies_to_clean := _active_enemies.duplicate()
	_active_enemies.clear()

	for enemy in enemies_to_clean:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			# Safely release CombatDirector lease if held
			if CombatDirector.instance and enemy is Node3D:
				CombatDirector.instance.release_attack_slot(enemy as Node3D, false)
				CombatDirector.instance.release_attack_slot(enemy as Node3D, true)
			enemy.queue_free()

	if spawn_director:
		spawn_director.is_wave_active = false
		spawn_director._wave_enemies.clear()

	emit_signal("enemy_count_changed", 0)

func _on_intermission_timer_timeout() -> void:
	start_wave(current_wave_index + 1)

func stop_run() -> void:
	current_state = State.STOPPED
	wave_timer.stop()
	spawn_timer.stop()
	intermission_timer.stop()
	countdown_timer.stop()
	_cleanup_surviving_enemies()

func pause_spawning() -> void:
	spawn_timer.paused = true

func resume_spawning() -> void:
	spawn_timer.paused = false

func finish_current_wave() -> void:
	if current_state == State.ACTIVE_WAVE:
		wave_timer.stop()
		_on_wave_timer_timeout()
