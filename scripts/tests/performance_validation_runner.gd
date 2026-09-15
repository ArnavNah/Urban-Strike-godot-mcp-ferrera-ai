extends Node
## Rendered benchmark. Survives real loading-screen transitions.
## Flight uses project inputs; automatic upgrade selection and health refill
## are test accommodations, not claims about player survivability.
var preset_name: String = "medium"
var quick: bool = false
var phase: String = "A_loading"
var samples: Array[float] = []
var counters: Array[Dictionary] = []
var report: Dictionary = {}
var last_tick: int = 0
var next_counter: float = 0.0
var phase_time: float = 0.0
var shots: int = 0
var choices: int = 0
var level_before: int = 1
var next_burst: float = 0.0
var started: bool = false
var completed: bool = false
var loading_screen_captured: bool = false
var loading_start: int = 0
var vsync_enabled: bool = false
var uncapped: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg == "--quick": quick = true
		if arg.begins_with("--preset="): preset_name = arg.trim_prefix("--preset=")
		if arg == "--vsync": vsync_enabled = true
		if arg == "--uncapped": uncapped = true
	seed(4702)
	_begin.call_deferred()

func _begin() -> void:
	get_tree().current_scene = null
	reparent(get_tree().root)
	get_window().size = Vector2i(1280, 720)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	if not vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSyncMode.DISABLED)
		if not uncapped:
			Engine.max_fps = 60
	loading_start = Time.get_ticks_usec()
	last_tick = loading_start
	started = true
	get_tree().change_scene_to_file("res://scenes/ui/loading_screen.tscn")

func _save_phase_screenshot(phase_name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img:
		var letter: String = phase_name.substr(0, 1).to_lower()
		var fn: String = "step8_scenario_%s.png" % letter
		DirAccess.make_dir_recursive_absolute("res://.fennara/tmp")
		img.save_png("res://.fennara/tmp/" + fn)
		img.save_png("res://.fennara/tmp/step8_scenario_%s.png" % phase_name.to_lower())

func _process(_delta: float) -> void:
	if not started or completed: return
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - last_tick) / 1000.0
	last_tick = now
	var root: Node = get_tree().current_scene
	if not root: return
	if phase == "A_loading":
		samples.append(ms)
		if not loading_screen_captured and samples.size() > 5:
			loading_screen_captured = true
			_save_phase_screenshot("a")
		if root is Battlefield:
			_record_counters(root)
			_finish_phase()
			report["A_loading"]["load_to_battlefield_ms"] = float(now - loading_start) / 1000.0
			SaveSystem.apply_graphics_preset(preset_name, get_tree())
			var initial_player: PlayerHelicopter = root.get_node("PlayerHelicopter")
			initial_player.chaingun.fired.connect(func(_p: Vector3, _d: Vector3) -> void: shots += 1)
			phase = "B_early"
		return
	if not root is Battlefield: return
	var menu: LevelUpMenu = root.get_node("UI/LevelUpMenu")
	if menu.visible:
		for action in ["fire_primary", "move_forward", "move_right", "move_left"]:
			Input.action_release(action)
		if menu._selection_ready and not menu._current_choices.is_empty():
			menu._on_card_selected(str(menu._current_choices[0]["id"]))
			choices += 1
		return
	if get_tree().paused: return
	samples.append(ms)
	phase_time += ms / 1000.0
	next_counter -= ms / 1000.0
	if next_counter <= 0:
		_record_counters(root)
		next_counter = 0.5
	var player: PlayerHelicopter = root.get_node("PlayerHelicopter")
	player.current_health = player.max_health
	Input.action_press("fire_primary")
	Input.action_press("move_forward", 0.5)
	# Alternate broad steering arcs; keep the normal controller in charge.
	Input.action_press("move_right", 0.25 if fmod(phase_time, 40.0) < 20.0 else 0.0)
	Input.action_press("move_left", 0.25 if fmod(phase_time, 40.0) >= 20.0 else 0.0)
	if phase_time >= next_burst:
		next_burst = phase_time + (1.5 if phase == "D_heavy" else 4.0)
		if phase == "D_heavy":
			player.missile_pod.replenish_ammo(1)
		player.missile_pod.try_fire()
		if phase == "D_heavy":
			for i in range(16):
				var pos: Vector3 = player.global_position + Vector3(float(i % 4) * 3.0 - 6.0, 0, -12.0 - floorf(float(i) / 4.0) * 3.0)
				VfxPool.instance.spawn_explosion(pos)
				VfxPool.instance.spawn_sparks(pos)
	var duration: float = 60.0
	if phase == "C_sustained": duration = 300.0
	if quick: duration = 12.0
	if phase_time < duration: return
	_finish_phase()
	if phase == "B_early":
		phase = "C_sustained"
	elif phase == "C_sustained":
		phase = "D_heavy"
		var director: MissionDirector = root.get_node("MissionDirector")
		director.start_mission_by_id("destroy_radar")
		# Exercise normal late-run director pressure; no arbitrary overlapping spawns.
		var spawner: SpawnDirector = root.get_node("SpawnSystem")
		spawner.elapsed_survival_time = maxf(spawner.elapsed_survival_time, 600.0)
	else:
		complete(root)

func _record_counters(root: Node) -> void:
	var entry: Dictionary = {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"enemies": EnemyRegistry.instance.all_enemies.size() if EnemyRegistry.instance else 0,
		"projectiles": 0, "gems": 0, "full_chunks": 0, "hlod_chunks": 0,
		"active_explosions": 0, "active_sparks": 0,
		"particle_systems_emitting": 0, "particle_emission_budget": 0,
	}
	for particles in root.find_children("*", "GPUParticles3D", true, false):
		if particles.emitting and particles.is_visible_in_tree():
			entry["particle_systems_emitting"] += 1
			entry["particle_emission_budget"] += ceili(particles.amount * particles.amount_ratio)
	if ProjectilePool.instance:
		for projectile in ProjectilePool.instance._pool:
			if projectile._is_active: entry["projectiles"] += 1
	if XpGemPool.instance: entry["gems"] = XpGemPool.instance.get_active_count()
	if VfxPool.instance:
		for effect in VfxPool.instance._explosion_pool:
			if effect.is_active: entry["active_explosions"] += 1
		for effect in VfxPool.instance._spark_pool:
			if effect.is_active: entry["active_sparks"] += 1
	var streamer: Node = root.get_node_or_null("Environment/CityWorldStreamer")
	if streamer:
		for chunk in streamer.active_chunks.values():
			if chunk.detail_level == CityChunk.DetailLevel.FULL_DETAIL: entry["full_chunks"] += 1
			else: entry["hlod_chunks"] += 1
	counters.append(entry)

func _finish_phase() -> void:
	_save_phase_screenshot(phase)
	if samples.is_empty(): return
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var sum: float = 0.0
	for value in samples: sum += value
	var slow_count: int = maxi(1, ceili(samples.size() * 0.01))
	var slow_sum: float = 0.0
	for i in range(sorted.size() - slow_count, sorted.size()): slow_sum += sorted[i]
	var result: Dictionary = {
		"duration_s": sum / 1000.0, "frames": samples.size(),
		"avg_fps": samples.size() * 1000.0 / sum,
		"min_instant_fps": 1000.0 / sorted[-1],
		"one_percent_low_fps": 1000.0 / (slow_sum / slow_count),
		"avg_frame_ms": sum / samples.size(), "worst_frame_ms": sorted[-1],
		"p99_frame_ms": sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))],
	}
	if not counters.is_empty():
		for key in counters[0]:
			var total: float = 0.0
			var peak: float = 0.0
			for entry in counters:
				total += float(entry[key])
				peak = maxf(peak, float(entry[key]))
			result["avg_" + key] = total / counters.size()
			result["peak_" + key] = peak
		result["first_sample"] = counters[0]
		result["last_sample"] = counters[-1]
	report[phase] = result
	print("BENCHMARK " + phase + " " + JSON.stringify(result))
	samples.clear()
	counters.clear()
	phase_time = 0.0
	next_burst = 0.0

func complete(root: Node) -> void:
	completed = true
	for action in ["fire_primary", "move_forward", "move_right", "move_left"]: Input.action_release(action)
	var all_pass: bool = not quick
	for scenario_name in ["B_early", "C_sustained", "D_heavy"]:
		var values: Dictionary = report.get(scenario_name, {})
		all_pass = all_pass and float(values.get("avg_fps", 0)) >= 58.0 and float(values.get("p99_frame_ms", INF)) <= 20.0 and float(values.get("worst_frame_ms", INF)) <= 35.0
	report["test_info"] = {
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"resolution": str(get_window().size), "preset": preset_name,
		"quick": quick, "debug_build": OS.is_debug_build(),
		"shots_fired": shots, "upgrade_choices": choices,
		"level": UpgradeManager.instance.current_level,
		"spawns": root.get_node("SpawnSystem").total_enemies_spawned,
		"stable_60_fps_achieved": all_pass,
		"regressions": "Separate regression suite required; performance does not prove mission correctness",
		"accommodations": "Health refilled; first offered upgrade automatically selected; real flight/fire inputs; missile ammo replenished during heavy stress",
	}
	var file: FileAccess = FileAccess.open("res://performance_validation_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("BENCHMARK_COMPLETE " + JSON.stringify(report["test_info"]))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.fennara/tmp/step8_final.png")
	get_tree().quit()
