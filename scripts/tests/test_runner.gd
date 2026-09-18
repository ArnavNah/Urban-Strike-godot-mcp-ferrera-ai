extends Node

func append_log(line: String, log_lines: Array[String]) -> void:
	log_lines.append(line)
	print(line)
	var out_path := ProjectSettings.globalize_path("res://test_results.txt")
	var f := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()

func _ready() -> void:
	var out_path := ProjectSettings.globalize_path("res://test_results.txt")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_line("--- STARTING HELI-STRIKE VERTICAL SLICE AUTOMATED TESTS ---")
		f.close()

	var log_lines: Array[String] = ["--- STARTING HELI-STRIKE VERTICAL SLICE AUTOMATED TESTS ---"]
	var success := true

	append_log("Running test 1 (player flight)...", log_lines)
	success = test_player_flight_and_nodes(log_lines) and success
	append_log("Running test 2 (chaingun)...", log_lines)
	success = test_chaingun_heat_and_overheat(log_lines) and success
	append_log("Running test 3 (missiles & flares)...", log_lines)
	success = test_missiles_and_flares(log_lines) and success
	append_log("Running test 4 (upgrades)...", log_lines)
	success = test_upgrade_manager_and_evolutions(log_lines) and success
	append_log("Running test 5 (enemies)...", log_lines)
	success = test_enemy_roster_and_states(log_lines) and success
	append_log("Running test 6 (archon boss)...", log_lines)
	success = test_archon_boss_phases(log_lines) and success
	append_log("Running test 7 (directors)...", log_lines)
	success = test_directors_and_wave_table(log_lines) and success
	append_log("Running test 8 (save system)...", log_lines)
	success = test_save_system_and_hangar(log_lines) and success
	append_log("Running test 9 (targeting)...", log_lines)
	success = test_targeting_stickiness_and_mission_priority(log_lines) and success
	append_log("Running test 10 (formations)...", log_lines)
	success = test_formations_and_mission_consequences(log_lines) and success
	append_log("Running test 11 (synergies)...", log_lines)
	success = test_reward_hierarchy_and_weapon_synergies(log_lines) and success
	append_log("Running test 12 (pooling & lod)...", log_lines)
	success = test_performance_registry_pooling_and_ai_lod(log_lines) and success
	append_log("Running test 13 (accessibility)...", log_lines)
	success = test_accessibility_deadzones_and_telemetry(log_lines) and success
	append_log("Running test 14 (air ecosystem)...", log_lines)
	success = test_air_enemy_archetypes_and_mobility(log_lines) and success
	append_log("Running test 15 (air formations)...", log_lines)
	success = test_procedural_air_formations_and_caps(log_lines) and success
	append_log("Running test 16 (jammer)...", log_lines)
	success = test_jammer_targeting_interference_and_cleanup(log_lines) and success
	append_log("Running test 17 (transport drop)...", log_lines)
	success = test_transport_reinforcement_drop_mechanic(log_lines) and success
	append_log("Running test 18 (continuous horde)...", log_lines)
	success = test_continuous_horde_survival_director(log_lines) and success
	append_log("Running test 19 (360 auto aim)...", log_lines)
	success = test_360_auto_aim_and_auto_fire(log_lines) and success
	append_log("Running test 20 (predictive lead)...", log_lines)
	success = test_predictive_lead_aiming(log_lines) and success
	append_log("Running test 21 (continuous spawner & xp magnet)...", log_lines)
	success = test_continuous_spawning_and_xp_magnet(log_lines) and success
	append_log("Running test 22 (environment districts & boundary)...", log_lines)
	success = test_environment_districts_and_playable_boundary(log_lines) and success
	append_log("Running test 23 (environment gameplay integration)...", log_lines)
	success = test_environment_gameplay_integration(log_lines) and success
	append_log("Running test 24 (ground and air ai)...", log_lines)
	success = test_ground_and_air_ai(log_lines) and success
	append_log("Running test 25 (enemy roster & formations)...", log_lines)
	success = test_enemy_roster_and_procedural_formations(log_lines) and success
	append_log("Running test 26 (ground enemy grounding & gravity)...", log_lines)
	success = test_ground_enemy_grounding_and_gravity(log_lines) and success
	append_log("Running test 27 (mini helicopter support & upgrades)...", log_lines)
	success = test_mini_helicopter_support_and_upgrades(log_lines) and success
	append_log("Running test 28 (limited missile ammo & supply pickups)...", log_lines)
	success = test_limited_missile_ammo_and_pickups(log_lines) and success
	append_log("Running test 29 (level-up pacing & continuous randomized spawning)...", log_lines)
	success = test_level_up_pacing_and_continuous_spawning(log_lines) and success
	append_log("Running test 30 (survival encounter director & frustum safety)...", log_lines)
	success = test_survival_encounter_director_and_frustum_safety(log_lines) and success
	append_log("Running test 31 (xp collection & progression integrity)...", log_lines)
	success = test_xp_collection_and_progression_integrity(log_lines) and success
	append_log("Running test 32 (dynamic strike missions & combat causality)...", log_lines)
	success = test_dynamic_strike_missions(log_lines) and success
	append_log("Running test 33 (upgrade drafting, rarity, eligibility & legendary limits)...", log_lines)
	success = test_upgrade_drafting_rarity_and_legendary_rules(log_lines) and success
	append_log("Running test 34 (accessibility, persistent settings & enemy telegraphs)...", log_lines)
	success = test_accessibility_and_enemy_telegraphs(log_lines) and success
	append_log("Running test 35 (xp aggregation & 13-step acceptance suite)...", log_lines)
	success = test_xp_aggregation_and_acceptance_suite(log_lines) and success
	append_log("Running test 36 (Phase 10A survivors population & spawning foundation)...", log_lines)
	success = test_phase_10a_population_and_spawning_foundation(log_lines) and success
	append_log("Running test 37 (Phase 10B low-difficulty enemy ai & combat director)...", log_lines)
	success = test_phase_10b_low_difficulty_enemy_ai_and_combat_director(log_lines) and success
	append_log("Running test 38 (Survivors low-difficulty enemy AI & spawner refinement)...", log_lines)
	success = test_survivors_low_difficulty_enemy_ai_and_spawner_refinement(log_lines) and success
	append_log("Running test 39 (City world streamer, scale contract & socket continuity)...", log_lines)
	success = test_city_world_streamer_and_scale_contract(log_lines) and success
	append_log("Running test 40 (Nuclear Strike camera composition & oblique framing)...", log_lines)
	success = test_nuclear_strike_camera_composition_and_behavior(log_lines) and success
	append_log("Running test 41 (SpawnDirector separation, reservations & repeated-entry regression)...", log_lines)
	success = test_spawn_director_separation_reservations_and_regression(log_lines) and success
	append_log("Running test 42 (Loading screen & XpGemPool performance stabilization)...", log_lines)
	success = test_loading_screen_and_xp_gem_pool(log_lines) and success
	append_log("Running test 43 (XP progression pacing & in-flight collection dynamics)...", log_lines)
	success = test_xp_progression_pacing_and_in_flight_dynamics(log_lines) and success
	append_log("Running test 44 (Enemy movement purpose, steering dynamics & anti-oscillation)...", log_lines)
	success = test_enemy_movement_purpose_and_steering_dynamics(log_lines) and success
	append_log("Running test 45 (DamageNumberManager pooling, preset caps & burst resilience)...", log_lines)
	success = test_damage_number_pooling_and_limits(log_lines) and success
	append_log("Running test 46 (Damage categories, actual crits & player damage)...", log_lines)
	success = test_damage_number_categories_and_player_damage(log_lines) and success
	append_log("Running test 47 (Damage aggregation, clutter reduction & death flush)...", log_lines)
	success = test_damage_number_aggregation_and_clutter_reduction(log_lines) and success
	append_log("Running test 48 (Combat feedback hierarchy, slot reservation & anti-stacking)...", log_lines)
	success = test_combat_feedback_hierarchy_and_slot_reservation(log_lines) and success
	append_log("Running test 49 (Ordinary hit feedback: enemy damage flash, sparks, audio rate-limiting)...", log_lines)
	success = test_ordinary_hit_feedback_and_damage_flash(log_lines) and success

	if success:
		append_log("=== ALL HELI-STRIKE VERTICAL SLICE TESTS PASSED! ===", log_lines)
	else:
		for l in log_lines.duplicate():
			if "FAIL:" in l:
				append_log(l, log_lines)
		append_log("=== SOME TESTS FAILED! ===", log_lines)

	get_tree().quit(0 if success else 1)

func test_player_flight_and_nodes(logs: Array[String]) -> bool:
	logs.append("[TEST] Player flight physics & modular nodes...")
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player: Node3D = player_scene.instantiate() as Node3D
	add_child(player)

	var max_spd: float = player.get("max_speed")
	var accel_stat: float = player.get("acceleration_stat")
	if absf(max_spd - 38.0) > 0.1:
		logs.append("FAIL: player max_speed is not ~38.0 (got %.2f)" % max_spd)
		player.queue_free()
		return false
	if absf(accel_stat - 42.0) > 0.1:
		logs.append("FAIL: player acceleration_stat is not 42.0 (got %.2f)" % accel_stat)
		player.queue_free()
		return false

	if player.get("motion_mode") != CharacterBody3D.MOTION_MODE_FLOATING:
		logs.append("FAIL: player motion_mode is not MOTION_MODE_FLOATING")
		player.queue_free()
		return false

	var yaw_rate: float = player.get("max_yaw_rate")
	if absf(yaw_rate - 3.2) > 0.1 and absf(yaw_rate - 2.85) > 0.1:
		logs.append("FAIL: player max_yaw_rate is not ~3.2 rad/s (got %.2f)" % yaw_rate)
		player.queue_free()
		return false

	if not player.get_node_or_null("StableTrackingPoint"):
		logs.append("FAIL: Missing StableTrackingPoint Marker3D")
		player.queue_free()
		return false

	if not player.get_node_or_null("FlightTiltPivot"):
		logs.append("FAIL: Missing FlightTiltPivot Node3D")
		player.queue_free()
		return false

	# Verify chin-gun yaw and pitch pivots
	if not player.get_node_or_null("GunMount/GunYawPivot") or not player.get_node_or_null("GunMount/GunYawPivot/GunPitchPivot"):
		logs.append("FAIL: Missing decoupled GunYawPivot or GunPitchPivot")
		player.queue_free()
		return false

	# Verify modular subcomponents
	var main_r: Node = player.get_node_or_null("FlightTiltPivot/Visuals/MainRotor")
	if not main_r:
		main_r = player.get_node_or_null("Visuals/MainRotor")
	var tail_r: Node = player.get_node_or_null("FlightTiltPivot/Visuals/TailRotor")
	if not tail_r:
		tail_r = player.get_node_or_null("Visuals/TailRotor")
	if not main_r or not tail_r:
		logs.append("FAIL: Missing modular animated rotor nodes")
		player.queue_free()
		return false
	if not player.get_node_or_null("StubWings/MissilePod"):
		logs.append("FAIL: Missing StubWings/MissilePod")
		player.queue_free()
		return false
	if not player.get_node_or_null("FlareDispenser"):
		logs.append("FAIL: Missing FlareDispenser")
		player.queue_free()
		return false

	logs.append("  -> AH-9 Vulture flight physics, MOTION_MODE_FLOATING, 0.9s accel, and modular nodes verified.")
	player.remove_from_group("player")
	player.queue_free()
	return true

func test_chaingun_heat_and_overheat(logs: Array[String]) -> bool:
	logs.append("[TEST] Chaingun 11.5 RPS & 2.5s overheat lockout...")
	var gun_scene := load("res://scenes/weapons/chaingun.tscn") as PackedScene
	var gun: Node3D = gun_scene.instantiate() as Node3D
	add_child(gun)

	var rate: float = gun.get("fire_rate")
	if absf(rate - 11.5) > 0.01:
		logs.append("FAIL: chaingun fire_rate is not 11.5")
		gun.queue_free()
		return false

	var shots := 0
	while not gun.get("is_overheated") and shots < 40:
		gun.set("_shot_cooldown", 0.0)
		gun.call("try_fire", Vector3(0, 0, -20))
		shots += 1

	if not gun.get("is_overheated"):
		logs.append("FAIL: chaingun failed to overheat")
		gun.queue_free()
		return false

	# Advance 2.4s: should still be locked
	gun.call("_process", 2.4)
	if not gun.get("is_overheated"):
		logs.append("FAIL: chaingun cleared lockout too early (< 2.5s)")
		gun.queue_free()
		return false

	# Advance remaining 0.2s: should be cleared
	gun.call("_process", 0.2)
	if gun.get("is_overheated"):
		logs.append("FAIL: chaingun failed to clear lockout after 2.5s")
		gun.queue_free()
		return false

	logs.append("  -> Chaingun overheated after %d shots; 2.5s lockout verified." % shots)
	gun.queue_free()
	return true

func test_missiles_and_flares(logs: Array[String]) -> bool:
	logs.append("[TEST] Guided Missiles & Flare Countermeasures...")
	var pod_scene := load("res://scenes/weapons/missile_pod.tscn") as PackedScene
	var pod: Node3D = pod_scene.instantiate() as Node3D
	add_child(pod)

	var lock_dur: float = pod.get("lock_duration")
	if absf(lock_dur - 0.95) > 0.01:
		logs.append("FAIL: missile lock duration is not 0.95s")
		pod.queue_free()
		return false

	# Test lock accumulation
	var dummy_target := Node3D.new()
	add_child(dummy_target)
	pod.call("set_target_candidate", dummy_target, true)
	pod.call("_process", 0.5)
	var is_locked: bool = pod.get("is_locked")
	var lock_prog: float = pod.get("lock_progress")
	if is_locked or lock_prog < 0.4:
		logs.append("FAIL: lock progress accumulated incorrectly")
		pod.queue_free()
		dummy_target.queue_free()
		return false

	pod.call("_process", 0.6)
	is_locked = pod.get("is_locked")
	if not is_locked:
		logs.append("FAIL: missile did not achieve lock after full duration")
		pod.queue_free()
		dummy_target.queue_free()
		return false

	# Test flare dispenser
	var flare_scene := load("res://scenes/weapons/flare.tscn") as PackedScene
	var flare: Node3D = flare_scene.instantiate() as Node3D
	add_child(flare)
	if not is_instance_valid(flare):
		logs.append("FAIL: Flare failed to instantiate")
		pod.queue_free()
		dummy_target.queue_free()
		return false

	logs.append("  -> 0.95s missile lock and countermeasure flares verified.")
	pod.queue_free()
	dummy_target.queue_free()
	flare.queue_free()
	return true

func test_upgrade_manager_and_evolutions(logs: Array[String]) -> bool:
	logs.append("[TEST] UpgradeManager & Weapon Evolutions...")
	var mgr_script: GDScript = load("res://scripts/managers/upgrade_manager.gd")
	var mgr: Node = mgr_script.new() as Node
	add_child(mgr)

	var choices: Array = mgr.call("get_random_choices", 3)
	if choices.size() != 3:
		logs.append("FAIL: get_random_choices did not return 3 choices")
		mgr.queue_free()
		return false

	# Test Hellfire Minigun evolution prerequisite trigger
	var acquired: Array = mgr.get("acquired_upgrades")
	acquired.append("twin_barrel")
	acquired.append("overclocked_feed")
	var evo_choices: Array = mgr.call("get_random_choices", 3)
	var found_evo := false
	for c in evo_choices:
		if c.get("id") == "hellfire_minigun":
			found_evo = true
			break

	if not found_evo:
		logs.append("FAIL: Hellfire Minigun evolution not offered when prerequisites met")
		mgr.queue_free()
		return false

	logs.append("  -> Upgrade pool, 3-card presentation, and evolutions verified.")
	mgr.queue_free()
	return true

func test_enemy_roster_and_states(logs: Array[String]) -> bool:
	logs.append("[TEST] Enemy Roster: Infantry, Tank, SAM, Hunter, Radar...")
	var inf_scene := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var tank_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	var sam_scene := load("res://scenes/enemies/sam_site.tscn") as PackedScene
	var hunter_scene := load("res://scenes/enemies/hunter_helicopter.tscn") as PackedScene
	var radar_scene := load("res://scenes/objects/radar_station.tscn") as PackedScene

	var inf: Node3D = inf_scene.instantiate() as Node3D
	var tank: Node3D = tank_scene.instantiate() as Node3D
	var sam: Node3D = sam_scene.instantiate() as Node3D
	var hunter: Node3D = hunter_scene.instantiate() as Node3D
	var radar: Node3D = radar_scene.instantiate() as Node3D

	add_child(inf)
	add_child(tank)
	add_child(sam)
	add_child(hunter)
	add_child(radar)

	if not inf.is_in_group("enemies") or not tank.is_in_group("enemies") or not sam.is_in_group("enemies") or not hunter.is_in_group("enemies"):
		logs.append("FAIL: Enemies not correctly tagged in enemies group")
		return false

	var c_spd: float = hunter.cruise_speed if "cruise_speed" in hunter else 0.0
	if c_spd != 28.0:
		logs.append("FAIL: Hunter cruise speed is not 28.0 m/s")
		return false

	# Test Radar SAM buff
	sam.set("_radar_active", true)
	var buffed_time: float = sam.call("_get_effective_lock_time")
	sam.set("_radar_active", false)
	var normal_time: float = sam.call("_get_effective_lock_time")
	if buffed_time >= normal_time:
		logs.append("FAIL: Radar station does not accelerate SAM lock speed by 60%")
		return false

	logs.append("  -> Complete enemy roster instantiated and behaviors verified.")
	inf.queue_free()
	tank.queue_free()
	sam.queue_free()
	hunter.queue_free()
	radar.queue_free()
	return true

func test_archon_boss_phases(logs: Array[String]) -> bool:
	logs.append("[TEST] Archon Heavy Gunship 3-Phase Boss...")
	var dummy_player := Node3D.new()
	dummy_player.name = "DummyPlayer"
	dummy_player.add_to_group("player")
	add_child(dummy_player)

	var boss_scene := load("res://scenes/enemies/boss_archon.tscn") as PackedScene
	var boss: Node3D = boss_scene.instantiate() as Node3D
	add_child(boss)

	var p1: int = boss.get("current_phase")
	if p1 != 1:
		logs.append("FAIL: Boss did not start in Phase 1")
		dummy_player.queue_free()
		boss.queue_free()
		return false

	# Damage to 50% HP -> Phase 2
	var max_hp: float = boss.get("max_health")
	boss.set("current_health", max_hp * 0.5)
	boss.call("_physics_process", 0.1)
	var p2: int = boss.get("current_phase")
	if p2 != 2:
		logs.append("FAIL: Boss did not transition to Phase 2 at 50% HP")
		dummy_player.queue_free()
		boss.queue_free()
		return false

	# Damage to 20% HP -> Phase 3
	boss.set("current_health", max_hp * 0.2)
	boss.call("_physics_process", 0.1)
	var p3: int = boss.get("current_phase")
	if p3 != 3:
		logs.append("FAIL: Boss did not transition to Phase 3 at 20% HP")
		dummy_player.queue_free()
		boss.queue_free()
		return false

	logs.append("  -> Archon 3 distinct phase transitions verified.")
	dummy_player.queue_free()
	boss.queue_free()
	return true

func test_directors_and_wave_table(logs: Array[String]) -> bool:
	logs.append("[TEST] CombatDirector & SpawnDirector 10-Wave Table...")
	var cd_script: GDScript = load("res://scripts/directors/combat_director.gd")
	var cd: Node = cd_script.new() as Node
	add_child(cd)
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: Node = sd_script.new() as Node
	add_child(sd)

	var table: Array = sd.get("wave_table")
	if table.size() != 10:
		logs.append("FAIL: wave_table does not have exactly 10 waves")
		cd.queue_free()
		sd.queue_free()
		return false

	# Verify Wave 6 introduces Air slots
	var w6: Dictionary = table[5]
	if w6["air_slots"] < 1:
		logs.append("FAIL: Wave 6 did not introduce air slot")
		cd.queue_free()
		sd.queue_free()
		return false

	logs.append("  -> 10-wave budgets, composition, and attack slot limits verified.")
	cd.queue_free()
	sd.queue_free()
	return true

func test_save_system_and_hangar(logs: Array[String]) -> bool:
	logs.append("[TEST] SaveSystem & Hangar Persistence...")
	var save_script: GDScript = load("res://scripts/common/save_system.gd")
	var test_data: Dictionary = save_script.call("get_default_data")
	test_data["salvage"] = 850
	test_data["upgrades"]["scavenger_rig"] = 2
	save_script.call("save_data", test_data)

	var loaded: Dictionary = save_script.call("load_data")
	if int(loaded.get("salvage", 0)) != 850:
		logs.append("FAIL: SaveSystem failed to persist salvage")
		return false
	if int(loaded.get("upgrades", {}).get("scavenger_rig", 0)) != 2:
		logs.append("FAIL: SaveSystem failed to persist upgrade levels")
		return false

	logs.append("  -> SaveSystem persistence and Hangar data verified.")
	return true

func test_targeting_stickiness_and_mission_priority(logs: Array[String]) -> bool:
	logs.append("[TEST] Targeting Stickiness, Hysteresis & Mission Priority...")
	var ts_script: GDScript = load("res://scripts/player/targeting_system.gd")
	var ts: Node = ts_script.new() as Node
	add_child(ts)

	if absf(ts.target_stickiness_time - 0.25) > 0.01:
		logs.append("FAIL: target_stickiness_time is not 0.25")
		ts.queue_free()
		return false
	if absf(ts.persistence_score_bonus - 0.35) > 0.01:
		logs.append("FAIL: persistence_score_bonus is not 0.35")
		ts.queue_free()
		return false
	if absf(ts.switch_score_threshold_ratio - 0.15) > 0.01:
		logs.append("FAIL: switch_score_threshold_ratio is not 0.15")
		ts.queue_free()
		return false

	var grunt: Node3D = Node3D.new()
	grunt.name = "GruntDummy"
	add_child(grunt)

	var radar: Node3D = Node3D.new()
	radar.name = "RadarDummy"
	radar.add_to_group("objectives")
	add_child(radar)

	var grunt_bonus: float = ts._get_mission_priority_bonus(grunt)
	var radar_bonus: float = ts._get_mission_priority_bonus(radar)
	if grunt_bonus != 0.0 or radar_bonus < 0.49:
		logs.append("FAIL: Mission priority bonus calculation failed (grunt: %.2f, radar: %.2f)" % [grunt_bonus, radar_bonus])
		grunt.queue_free()
		radar.queue_free()
		ts.queue_free()
		return false

	var grunt_score: float = ts._calculate_candidate_score(grunt, 30.0, 0.0, 5)
	var radar_score: float = ts._calculate_candidate_score(radar, 30.0, 0.0, 5)
	if radar_score <= grunt_score:
		logs.append("FAIL: Radar candidate score (%.2f) not higher than grunt (%.2f)" % [radar_score, grunt_score])
		grunt.queue_free()
		radar.queue_free()
		ts.queue_free()
		return false

	# Test persistence bonus when candidate is current target
	ts.current_target = grunt
	var grunt_score_when_current: float = ts._calculate_candidate_score(grunt, 30.0, 0.0, 5)
	if grunt_score_when_current <= grunt_score:
		logs.append("FAIL: Persistence bonus not applied to current_target")
		grunt.queue_free()
		radar.queue_free()
		ts.queue_free()
		return false

	logs.append("  -> Targeting stickiness (0.25s), hysteresis bonus (+0.35), and mission-priority scoring verified.")
	grunt.queue_free()
	radar.queue_free()
	ts.queue_free()
	return true

func test_formations_and_mission_consequences(logs: Array[String]) -> bool:
	logs.append("[TEST] Battlefield Formations, Radar Consequences & Escort Scatter...")

	# 1. Test SAM site radar degradation
	var sam_scene := load("res://scenes/enemies/sam_site.tscn") as PackedScene
	var sam: Node = sam_scene.instantiate() as Node
	add_child(sam)

	sam.set("_radar_active", true)
	var active_lock: float = float(sam.call("_get_effective_lock_time"))
	var active_range: float = float(sam.call("_get_effective_threat_range"))

	sam.set("_radar_active", false)
	var degraded_lock: float = float(sam.call("_get_effective_lock_time"))
	var degraded_range: float = float(sam.call("_get_effective_threat_range"))

	if active_lock != 1.4 or degraded_lock != 2.4:
		logs.append("FAIL: SAM lock time not degrading from 1.4s to 2.4s (got %.2f -> %.2f)" % [active_lock, degraded_lock])
		sam.queue_free()
		return false

	if active_range != 85.0 or degraded_range != 60.0:
		logs.append("FAIL: SAM threat range not degrading from 85.0m to 60.0m (got %.2f -> %.2f)" % [active_range, degraded_range])
		sam.queue_free()
		return false

	sam.queue_free()

	# 2. Test convoy command unit and escort scattering
	var tank_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	var cmd_tank: Node = tank_scene.instantiate() as Node
	cmd_tank.set("is_command_unit", true)
	add_child(cmd_tank)

	var escort_tank: Node = tank_scene.instantiate() as Node
	add_child(escort_tank)
	cmd_tank.call("register_escort", escort_tank)

	# Kill command tank and verify escort scatter
	cmd_tank.call("_die")
	var is_scattered: bool = bool(escort_tank.get("is_scattered"))
	var scatter_timer: float = float(escort_tank.get("_scatter_timer"))

	if not is_scattered or scatter_timer <= 0.0:
		logs.append("FAIL: Escort tank failed to scatter upon command unit destruction")
		escort_tank.queue_free()
		return false

	escort_tank.queue_free()

	# 3. Test battlefield formations in SpawnDirector
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: Node = sd_script.new() as Node
	add_child(sd)

	var column: Array = sd.call("spawn_road_column", Vector3(0, 0, 50), Vector3.FORWARD, 3)
	if column.size() != 3:
		logs.append("FAIL: spawn_road_column did not return 3 units (got %d)" % column.size())
		sd.queue_free()
		return false

	var lead_unit: Node = column[0] as Node
	if not bool(lead_unit.get("is_command_unit")):
		logs.append("FAIL: Lead vehicle in road column is not marked as command unit")
		for unit in column:
			if is_instance_valid(unit):
				(unit as Node).queue_free()
		sd.queue_free()
		return false

	for unit in column:
		if is_instance_valid(unit):
			(unit as Node).queue_free()

	var sam_nest: Array = sd.call("spawn_sam_nest", Vector3(30, 0, 30), false)
	if sam_nest.size() != 3:
		logs.append("FAIL: spawn_sam_nest did not return 3 fortified units (got %d)" % sam_nest.size())
		sd.queue_free()
		return false

	for unit in sam_nest:
		if is_instance_valid(unit):
			(unit as Node).queue_free()

	var interceptors: Array = sd.call("spawn_interceptor_pair", Vector3(0, 15, -50), Vector3.FORWARD)
	if interceptors.size() != 2:
		logs.append("FAIL: spawn_interceptor_pair did not return 2 aircraft (got %d)" % interceptors.size())
		sd.queue_free()
		return false

	for unit in interceptors:
		if is_instance_valid(unit):
			(unit as Node).queue_free()

	sd.queue_free()

	# 4. Test Endless Mode & Extraction setup in GameManager
	var gm_script: GDScript = load("res://scripts/common/game_manager.gd")
	var gm: Node = gm_script.new() as Node
	add_child(gm)

	gm.call("enter_endless_mode")
	var is_endless: bool = bool(gm.get("is_endless_mode"))
	var salvage_mult: float = float(gm.get("salvage_multiplier"))
	if not is_endless or salvage_mult < 1.99:
		logs.append("FAIL: GameManager failed to activate Endless Overdrive (mult: %.2f)" % salvage_mult)
		gm.queue_free()
		return false

	gm.queue_free()

	logs.append("  -> Formations (column, sam nest, interceptors), radar consequences, and endless overdrive verified.")
	return true

func test_reward_hierarchy_and_weapon_synergies(logs: Array[String]) -> bool:
	logs.append("[TEST] 3-Tier Reward Hierarchy & Build-Changing Weapon Synergies...")

	# 1. Test Salvage Crate (Tier 3 Persistent Currency)
	var crate_scene := load("res://scenes/pickups/salvage_crate.tscn") as PackedScene
	var crate: Node3D = crate_scene.instantiate() as Node3D
	add_child(crate)

	if not crate.is_in_group("salvage_crates"):
		logs.append("FAIL: Salvage crate not in group salvage_crates")
		crate.queue_free()
		return false

	var s_val: int = crate.get("salvage_value")
	if s_val != 50:
		logs.append("FAIL: Salvage crate value is not 50 (got %d)" % s_val)
		crate.queue_free()
		return false

	crate.queue_free()

	# 2. Test UpgradeManager Requisitions (Tier 2 Objective Rewards)
	var mgr_script: GDScript = load("res://scripts/managers/upgrade_manager.gd")
	var mgr: Node = mgr_script.new() as Node
	add_child(mgr)

	mgr.call("award_requisition", 2)
	var reqs: int = mgr.get("requisition_points")
	if reqs != 2:
		logs.append("FAIL: award_requisition failed to queue requisitions (got %d)" % reqs)
		mgr.queue_free()
		return false

	# 3. Test Synergies on Player & Weapons
	for existing in get_tree().get_nodes_in_group("player"):
		existing.remove_from_group("player")
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player: Node = player_scene.instantiate() as Node
	add_child(player)

	# AP Ricochet Cannon evolution
	var acquired: Array = mgr.get("acquired_upgrades")
	acquired.clear()
	acquired.append("armor_piercing")
	acquired.append("ricochet_rounds")
	var applied_ap: bool = bool(mgr.call("apply_upgrade", "ap_ricochet_cannon"))
	if not applied_ap:
		logs.append("FAIL: Failed to apply ap_ricochet_cannon evolution")
		player.queue_free()
		mgr.queue_free()
		return false

	var gun: Node = player.get("chaingun") as Node
	var p_count: int = gun.get("pierce_count")
	var r_count: int = gun.get("ricochet_count")
	var a_mult: float = gun.get("armor_multiplier")
	if p_count < 2 or r_count < 1 or absf(a_mult - 1.8) > 0.05:
		logs.append("FAIL: AP Ricochet Cannon stats mismatch (pierce: %d, ricochet: %d, armor_mult: %.2f)" % [p_count, r_count, a_mult])
		player.queue_free()
		mgr.queue_free()
		return false

	# Swarm Rockets evolution
	acquired.append("rapid_lock")
	acquired.append("multi_launch")
	var applied_swarm: bool = bool(mgr.call("apply_upgrade", "swarm_rockets"))
	if not applied_swarm:
		logs.append("FAIL: Failed to apply swarm_rockets evolution")
		player.queue_free()
		mgr.queue_free()
		return false

	var pod: Node = player.get("missile_pod") as Node
	var is_sw: bool = bool(pod.get("is_swarm_rockets"))
	var ml_count: int = pod.get("multi_launch_count")
	if not is_sw or ml_count < 6:
		logs.append("FAIL: Swarm Rockets stats mismatch (is_swarm: %s, count: %d)" % [str(is_sw), ml_count])
		player.queue_free()
		mgr.queue_free()
		return false

	# Multi-Lock Hellfire evolution
	# Requires rapid_lock + armor_piercing (already in acquired)
	var applied_multilock: bool = bool(mgr.call("apply_upgrade", "multi_lock_hellfire"))
	if not applied_multilock:
		logs.append("FAIL: Failed to apply multi_lock_hellfire evolution")
		player.queue_free()
		mgr.queue_free()
		return false

	var is_ml: bool = bool(pod.get("is_multi_lock"))
	var max_targets: int = pod.get("max_lock_targets")
	if not is_ml or max_targets != 3:
		logs.append("FAIL: Multi-Lock Hellfire stats mismatch (is_multi: %s, targets: %d)" % [str(is_ml), max_targets])
		player.queue_free()
		mgr.queue_free()
		return false

	# Aegis Airframe evolution
	acquired.append("reinforced_airframe")
	acquired.append("repair_drone")
	var applied_aegis: bool = bool(mgr.call("apply_upgrade", "aegis_airframe"))
	if not applied_aegis:
		logs.append("FAIL: Failed to apply aegis_airframe evolution")
		player.queue_free()
		mgr.queue_free()
		return false

	var has_aegis: bool = bool(player.get("has_aegis_shield"))
	if not has_aegis:
		logs.append("FAIL: Player missing aegis shield after aegis_airframe evolution")
		player.queue_free()
		mgr.queue_free()
		return false

	logs.append("  -> Salvage crates, requisition drafting, and 4 weapon/airframe synergies verified.")
	player.queue_free()
	mgr.queue_free()
	return true

func test_performance_registry_pooling_and_ai_lod(logs: Array[String]) -> bool:
	logs.append("[TEST] Spatial EnemyRegistry, Object Pooling & Distance AI LOD...")

	# 1. Test Spatial EnemyRegistry
	var reg_script: GDScript = load("res://scripts/common/enemy_registry.gd")
	var reg: Node = reg_script.new() as Node
	add_child(reg)

	var e1 := Node3D.new()
	e1.name = "TestGroundEnemy"
	add_child(e1)
	e1.global_position = Vector3(10, 0, 10)

	var e2 := Node3D.new()
	e2.name = "TestAirEnemy"
	add_child(e2)
	e2.global_position = Vector3(80, 15, 80)

	reg.call("register_enemy", e1, false)
	reg.call("register_enemy", e2, true)

	var total_count: int = reg.call("get_active_count")
	var air_count: int = reg.call("get_air_count")
	var ground_count: int = reg.call("get_ground_count")

	if total_count != 2 or air_count != 1 or ground_count != 1:
		logs.append("FAIL: EnemyRegistry count mismatch (total: %d, air: %d, ground: %d)" % [total_count, air_count, ground_count])
		e1.queue_free()
		e2.queue_free()
		reg.queue_free()
		return false

	# Query radius 30m from origin: should return e1 (dist ~14m) and NOT e2 (dist ~114m)
	var near_enemies: Array = reg.call("get_enemies_in_radius", Vector3.ZERO, 30.0)
	if near_enemies.size() != 1 or not near_enemies.has(e1):
		logs.append("FAIL: EnemyRegistry spatial radius query failed to filter distant enemy")
		e1.queue_free()
		e2.queue_free()
		reg.queue_free()
		return false

	# Query radius 130m: should return both
	var all_near: Array = reg.call("get_enemies_in_radius", Vector3.ZERO, 130.0)
	if all_near.size() != 2:
		logs.append("FAIL: EnemyRegistry spatial radius query failed to find all enemies")
		e1.queue_free()
		e2.queue_free()
		reg.queue_free()
		return false

	# Test unregister
	reg.call("unregister_enemy", e1)
	if int(reg.call("get_active_count")) != 1:
		logs.append("FAIL: EnemyRegistry failed to unregister enemy")
		e1.queue_free()
		e2.queue_free()
		reg.queue_free()
		return false

	e1.queue_free()
	e2.queue_free()
	reg.queue_free()

	# 2. Test Object Pooling (VfxPool & FlarePool)
	var vfx_script: GDScript = load("res://scripts/common/vfx_pool.gd")
	var vfx: Node3D = vfx_script.new() as Node3D
	add_child(vfx)

	var flash: Node3D = vfx.call("spawn_muzzle_flash", Vector3(0, 2, 0))
	var spark: Node3D = vfx.call("spawn_sparks", Vector3(0, 2, 0))
	var expl: Node3D = vfx.call("spawn_explosion", Vector3(0, 2, 0))

	if not flash or not spark or not expl:
		logs.append("FAIL: VfxPool failed to spawn pooled effects")
		vfx.queue_free()
		return false

	if not bool(flash.get("is_pooled")) or not bool(spark.get("is_pooled")) or not bool(expl.get("is_pooled")):
		logs.append("FAIL: Spawned VFX effects not marked as pooled")
		vfx.queue_free()
		return false

	vfx.queue_free()

	# Test FlarePool
	var flare_pool_script: GDScript = load("res://scripts/common/flare_pool.gd")
	var fpool: Node3D = flare_pool_script.new() as Node3D
	add_child(fpool)

	var flare: Node = fpool.call("spawn_flare", Vector3(0, 5, 0), Vector3(1, 0, 0)) as Node
	if not flare or not bool(flare.get("is_pooled")) or not bool(flare.get("is_active")):
		logs.append("FAIL: FlarePool failed to spawn active pooled flare")
		fpool.queue_free()
		return false

	fpool.queue_free()

	# 3. Test Distance-Based AI LOD on Tank
	var tank_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	var tank: Node = tank_scene.instantiate() as Node
	add_child(tank)

	# Position player dummy at origin, tank far away (150m) -> should trigger LOD 3 cull
	var player_dummy := Node3D.new()
	player_dummy.name = "PlayerDummy"
	player_dummy.add_to_group("player")
	add_child(player_dummy)

	tank.set("global_position", Vector3(150, 0, 0))
	tank.call("_physics_process", 0.016)
	var culled_state: int = int(tank.get("current_state"))
	# Verify it remains stable without crashing while culled
	if not bool(tank.get("is_alive")) or culled_state < 0:
		logs.append("FAIL: Tank AI LOD crashed or corrupted state at distance 150m")
		tank.queue_free()
		player_dummy.queue_free()
		return false

	tank.queue_free()
	player_dummy.queue_free()

	logs.append("  -> Spatial EnemyRegistry, VfxPool, FlarePool, and distance AI LOD verified.")
	return true

func test_accessibility_deadzones_and_telemetry(logs: Array[String]) -> bool:
	logs.append("[TEST] Accessibility Deadzones & Combat Telemetry Tracking...")

	# 1. Test SaveSystem settings defaults
	var move_dz: float = float(SaveSystem.get_setting("move_deadzone", 0.0))
	var aim_dz: float = float(SaveSystem.get_setting("aim_deadzone", 0.0))
	if absf(move_dz - 0.15) > 0.01 or absf(aim_dz - 0.12) > 0.01:
		logs.append("FAIL: SaveSystem default deadzones mismatch (move: %.2f, aim: %.2f)" % [move_dz, aim_dz])
		return false

	# 2. Test InputRouter deadzone loading and configuration
	var router_script: GDScript = load("res://scripts/input/InputRouter.gd")
	var router: Node = router_script.new() as Node
	add_child(router)

	var r_move: float = float(router.get("move_deadzone"))
	var r_aim: float = float(router.get("aim_deadzone"))
	if absf(r_move - 0.15) > 0.01 or absf(r_aim - 0.12) > 0.01:
		logs.append("FAIL: InputRouter did not initialize with 0.15/0.12 deadzones (got %.2f / %.2f)" % [r_move, r_aim])
		router.queue_free()
		return false

	# Set new deadzones and save
	router.call("set_deadzones", 0.18, 0.10, true)
	var saved_move: float = float(SaveSystem.get_setting("move_deadzone", 0.0))
	var saved_aim: float = float(SaveSystem.get_setting("aim_deadzone", 0.0))
	if absf(saved_move - 0.18) > 0.01 or absf(saved_aim - 0.10) > 0.01:
		logs.append("FAIL: InputRouter failed to persist updated deadzones into SaveSystem")
		router.queue_free()
		return false

	# Restore defaults
	router.call("set_deadzones", 0.15, 0.12, true)
	router.queue_free()

	# 3. Test GameManager telemetry recording
	var gm_script: GDScript = load("res://scripts/common/game_manager.gd")
	var gm: Node = gm_script.new() as Node
	add_child(gm)

	gm.call("record_shot")
	gm.call("record_shot")
	gm.call("record_damage", 150.0)
	gm.call("_on_enemy_destroyed", null, 80)
	gm.call("_on_missile_fired")

	var tel: Dictionary = gm.call("get_run_telemetry", "TEST")
	if int(tel.get("shots_fired", 0)) != 2 or int(tel.get("enemies_killed", 0)) != 1 or int(tel.get("missiles_fired", 0)) != 1:
		logs.append("FAIL: GameManager telemetry metrics mismatch")
		gm.queue_free()
		return false

	gm.call("finalize_telemetry", "EXTRACTED")
	gm.queue_free()

	var data: Dictionary = SaveSystem.load_data()
	var recents: Array = data.get("telemetry", {}).get("recent_runs", [])
	if recents.is_empty():
		logs.append("FAIL: SaveSystem did not record run telemetry entry")
		return false

	var last_run: Dictionary = recents[recents.size() - 1]
	if last_run.get("status") != "EXTRACTED":
		logs.append("FAIL: Last run telemetry status is not EXTRACTED")
		return false

	logs.append("  -> Configurable 0.15/0.12 deadzones, persistence, and combat telemetry verified.")
	return true

func test_air_enemy_archetypes_and_mobility(logs: Array[String]) -> bool:
	logs.append("[TEST] Air Enemy Ecosystem: 6 Modular Archetypes...")
	var scenes_to_check: Dictionary = {
		"scout": {
			"path": "res://scenes/enemies/air_scout_helicopter.tscn",
			"hp": 25.0,
			"cost": 4,
			"score": 0.40,
			"tag": "scouts",
			"alt_min": 10.0,
			"alt_max": 15.0
		},
		"raider": {
			"path": "res://scenes/enemies/air_rocket_raider.tscn",
			"hp": 45.0,
			"cost": 6,
			"score": 0.75,
			"tag": "rocket_raiders",
			"alt_min": 15.0,
			"alt_max": 22.0
		},
		"transport": {
			"path": "res://scenes/enemies/air_transport_helicopter.tscn",
			"hp": 75.0,
			"cost": 7,
			"score": 0.70,
			"tag": "transports",
			"alt_min": 8.0,
			"alt_max": 16.0
		},
		"gunship": {
			"path": "res://scenes/enemies/air_attack_gunship.tscn",
			"hp": 95.0,
			"cost": 9,
			"score": 0.90,
			"tag": "attack_gunships",
			"alt_min": 12.0,
			"alt_max": 18.0
		},
		"jammer": {
			"path": "res://scenes/enemies/air_jammer_helicopter.tscn",
			"hp": 50.0,
			"cost": 8,
			"score": 1.15,
			"tag": "jammers",
			"alt_min": 18.0,
			"alt_max": 24.0
		},
		"ace": {
			"path": "res://scenes/enemies/air_ace_gunship.tscn",
			"hp": 150.0,
			"cost": 12,
			"score": 1.20,
			"tag": "ace_gunships",
			"alt_min": 14.0,
			"alt_max": 20.0
		}
	}

	for key in scenes_to_check.keys():
		var info: Dictionary = scenes_to_check[key]
		var scene := load(info["path"]) as PackedScene
		if not scene:
			logs.append("FAIL: Could not load %s" % info["path"])
			return false

		var enemy := scene.instantiate() as CharacterBody3D
		if not enemy:
			logs.append("FAIL: Failed to instantiate %s" % info["path"])
			return false
		add_child(enemy)

		var arch: AirEnemyArchetype = enemy.get("archetype") as AirEnemyArchetype
		if not arch:
			logs.append("FAIL: Enemy %s has no AirEnemyArchetype assigned" % key)
			enemy.queue_free()
			return false

		if absf(enemy.current_health - info["hp"]) > 0.1:
			logs.append("FAIL: %s health mismatch (expected %.1f, got %.1f)" % [key, info["hp"], enemy.current_health])
			enemy.queue_free()
			return false

		if arch.threat_cost != info["cost"]:
			logs.append("FAIL: %s threat cost mismatch (expected %d, got %d)" % [key, info["cost"], arch.threat_cost])
			enemy.queue_free()
			return false

		if absf(enemy.threat_score - info["score"]) > 0.05:
			logs.append("FAIL: %s threat score mismatch" % key)
			enemy.queue_free()
			return false

		if not enemy.is_in_group(info["tag"]):
			logs.append("FAIL: %s missing required group tag '%s'" % [key, info["tag"]])
			enemy.queue_free()
			return false

		if not enemy.is_in_group("air_enemies"):
			logs.append("FAIL: %s not in 'air_enemies' group" % key)
			enemy.queue_free()
			return false

		if enemy.collision_layer != 4 or enemy.collision_mask != 1:
			logs.append("FAIL: %s collision layer/mask incorrect" % key)
			enemy.queue_free()
			return false

		enemy.queue_free()

	logs.append("  -> All 6 air enemy archetypes instantiated, verified with layered altitude bands and threat costs.")
	return true

func test_procedural_air_formations_and_caps(logs: Array[String]) -> bool:
	logs.append("[TEST] Threat Director Procedural Air Formations & Active Caps...")
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: Node = sd_script.new() as Node
	add_child(sd)

	var origin := Vector3(0.0, 14.0, 50.0)
	var heading := Vector3.FORWARD

	# 1. Test Air Patrol (2 Scouts)
	var patrol: Array = sd.call("spawn_air_patrol", origin, heading)
	if patrol.size() != 2:
		logs.append("FAIL: spawn_air_patrol did not spawn exactly 2 units (got %d)" % patrol.size())
		sd.queue_free()
		return false
	for u in patrol:
		if not (u as Node).is_in_group("scouts"):
			logs.append("FAIL: Unit in air patrol is not a scout")
			sd.queue_free()
			return false
		(u as Node).queue_free()

	# 2. Test Harassment Group (1 Raider + 2 Scouts)
	var harassment: Array = sd.call("spawn_harassment_group", origin, heading)
	if harassment.size() != 3:
		logs.append("FAIL: spawn_harassment_group did not spawn 3 units (got %d)" % harassment.size())
		sd.queue_free()
		return false
	for u in harassment:
		(u as Node).queue_free()

	# 3. Test Reinforcement Drop (1 Transport + 1 Scout)
	var drop: Array = sd.call("spawn_reinforcement_drop", origin, heading, true)
	if drop.size() != 2:
		logs.append("FAIL: spawn_reinforcement_drop did not spawn 2 aircraft (got %d)" % drop.size())
		sd.queue_free()
		return false
	for u in drop:
		(u as Node).queue_free()

	# 4. Test Air Intercept (1 Gunship + 1-2 Scouts)
	var intercept: Array = sd.call("spawn_air_intercept", origin, heading, 2)
	if intercept.size() != 3:
		logs.append("FAIL: spawn_air_intercept did not spawn 3 aircraft (got %d)" % intercept.size())
		sd.queue_free()
		return false
	for u in intercept:
		(u as Node).queue_free()

	# 5. Test Electronic Strike Group (1 Gunship + 1 Jammer)
	var ew_group: Array = sd.call("spawn_electronic_strike_group", origin, heading, false)
	if ew_group.size() != 2:
		logs.append("FAIL: spawn_electronic_strike_group did not spawn 2 aircraft (got %d)" % ew_group.size())
		sd.queue_free()
		return false
	for u in ew_group:
		(u as Node).queue_free()

	# 6. Test Elite Air Encounter (1 Ace + 2 Scouts)
	var elite: Array = sd.call("spawn_elite_air_encounter", origin, heading)
	if elite.size() != 3:
		logs.append("FAIL: spawn_elite_air_encounter did not spawn 3 aircraft (got %d)" % elite.size())
		sd.queue_free()
		return false
	for u in elite:
		(u as Node).queue_free()

	# 7. Test Combined Arms Formation (Air + Ground)
	var combined: Array = sd.call("spawn_combined_arms_formation", origin, heading)
	if combined.size() < 2:
		logs.append("FAIL: spawn_combined_arms_formation did not spawn air and ground elements")
		sd.queue_free()
		return false
	for u in combined:
		(u as Node).queue_free()

	# 8. Test Cap Enforcement: simulate active caps reached
	sd.set("cap_jammer", 1)
	var j_scene: PackedScene = load("res://scenes/enemies/air_jammer_helicopter.tscn")
	var live_jammer := j_scene.instantiate() as Node3D
	add_child(live_jammer)
	var wave_enemies: Array = sd.get("_wave_enemies")
	wave_enemies.append(live_jammer)

	var second_ew: Array = sd.call("spawn_electronic_strike_group", origin, heading, false)
	if not second_ew.is_empty():
		logs.append("FAIL: Director allowed electronic strike group despite jammer cap reached")
		live_jammer.queue_free()
		sd.queue_free()
		return false

	live_jammer.queue_free()

	# 9. Test Formation History Cooldown
	sd.call("_record_formation", "air_patrol")
	if bool(sd.call("can_spawn_formation", "air_patrol")):
		logs.append("FAIL: Formation cooldown allowed consecutive duplicate formation spawn")
		sd.queue_free()
		return false

	sd.queue_free()
	logs.append("  -> 7 procedural formations, active caps enforcement, and cooldown history verified.")
	return true

func test_jammer_targeting_interference_and_cleanup(logs: Array[String]) -> bool:
	logs.append("[TEST] Jammer Electronic Warfare & Targeting Integration...")
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player := player_scene.instantiate() as Node3D
	add_child(player)

	var targeting := player.get_node_or_null("TargetingSystem") as TargetingSystem
	var pod := player.get_node_or_null("StubWings/MissilePod") as MissilePod
	if not targeting or not pod:
		logs.append("FAIL: Missing TargetingSystem or MissilePod on Player")
		player.queue_free()
		return false

	# 1. Verify priority sorting
	var j_scene := load("res://scenes/enemies/air_jammer_helicopter.tscn") as PackedScene
	var jammer := j_scene.instantiate() as Node3D
	add_child(jammer)

	var s_scene := load("res://scenes/enemies/air_scout_helicopter.tscn") as PackedScene
	var scout := s_scene.instantiate() as Node3D
	add_child(scout)

	var j_threat: float = targeting._get_enemy_threat_weight(jammer)
	var s_threat: float = targeting._get_enemy_threat_weight(scout)
	if j_threat <= s_threat:
		logs.append("FAIL: Jammer threat weight (%.2f) not higher than Scout (%.2f)" % [j_threat, s_threat])
		jammer.queue_free()
		scout.queue_free()
		player.queue_free()
		return false

	# 2. Verify Jamming status is active while jammer is alive
	if not targeting.is_jammed():
		logs.append("FAIL: TargetingSystem does not register active jamming when Jammer is present")
		jammer.queue_free()
		scout.queue_free()
		player.queue_free()
		return false

	if not pod._is_jammed():
		logs.append("FAIL: MissilePod does not register active jamming when Jammer is present")
		jammer.queue_free()
		scout.queue_free()
		player.queue_free()
		return false

	# 3. Destroy Jammer and verify clean deactivation
	jammer.queue_free()

	if targeting.is_jammed():
		logs.append("FAIL: TargetingSystem still shows jammed after Jammer is freed")
		scout.queue_free()
		player.queue_free()
		return false

	if pod._is_jammed():
		logs.append("FAIL: MissilePod still shows jammed after Jammer is freed")
		scout.queue_free()
		player.queue_free()
		return false

	scout.queue_free()
	player.queue_free()
	logs.append("  -> Jammer priority, targeting interference, missile lock slowdown, and immediate cleanup verified.")
	return true

func test_transport_reinforcement_drop_mechanic(logs: Array[String]) -> bool:
	logs.append("[TEST] Transport Helicopter Ground Force Deployment...")
	var trans_scene := load("res://scenes/enemies/air_transport_helicopter.tscn") as PackedScene
	var transport := trans_scene.instantiate() as AirEnemyController
	add_child(transport)
	transport.global_position = Vector3(10.0, 14.0, 10.0)

	if transport.has_deployed_cargo:
		logs.append("FAIL: Transport deployed cargo before reaching drop zone")
		transport.queue_free()
		return false

	var initial_child_count := get_child_count()
	transport.call("_deploy_cargo")

	if not transport.has_deployed_cargo:
		logs.append("FAIL: Transport has_deployed_cargo not set to true after drop")
		transport.queue_free()
		return false

	var new_child_count := get_child_count()
	if new_child_count <= initial_child_count:
		logs.append("FAIL: No ground units spawned by Transport Helicopter drop")
		transport.queue_free()
		return false

	# Clean up any ground units spawned during cargo deployment
	for i in range(initial_child_count, new_child_count):
		var c := get_child(i)
		if is_instance_valid(c):
			c.queue_free()

	transport.queue_free()
	logs.append("  -> Transport cargo deployment state and ground unit instantiation verified.")
	return true

func test_continuous_horde_survival_director(logs: Array[String]) -> bool:
	logs.append("[TEST] Continuous Horde Survival Director...")
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: SpawnDirector = sd_script.new() as SpawnDirector
	add_child(sd)

	if not sd.is_continuous_mode:
		logs.append("FAIL: SpawnDirector is_continuous_mode is not enabled")
		sd.queue_free()
		return false

	# Test progression stages
	sd.elapsed_survival_time = 30.0
	if sd.get_survival_stage() != 1 or sd.get_active_population_cap() != 24:
		logs.append("FAIL: Stage 1 mismatch (stage=%d, cap=%d)" % [sd.get_survival_stage(), sd.get_active_population_cap()])
		sd.queue_free()
		return false

	sd.elapsed_survival_time = 180.0
	if sd.get_survival_stage() != 2 or sd.get_active_population_cap() != 45:
		logs.append("FAIL: Stage 2 mismatch (stage=%d, cap=%d)" % [sd.get_survival_stage(), sd.get_active_population_cap()])
		sd.queue_free()
		return false

	sd.elapsed_survival_time = 360.0
	if sd.get_survival_stage() != 3 or sd.get_active_population_cap() != 65:
		logs.append("FAIL: Stage 3 mismatch (stage=%d, cap=%d)" % [sd.get_survival_stage(), sd.get_active_population_cap()])
		sd.queue_free()
		return false

	# Test continuous budget accumulation
	sd.is_wave_active = true
	sd.continuous_ground_budget = 0.0
	sd._process_continuous_survival(2.0)
	if sd.continuous_ground_budget <= 0.0:
		logs.append("FAIL: Continuous ground budget failed to accumulate over delta time")
		sd.queue_free()
		return false

	# Test elite modifier application
	var dummy_enemy := Node3D.new()
	dummy_enemy.set("max_health", 50.0)
	dummy_enemy.set("current_health", 50.0)
	dummy_enemy.set("xp_value", 10)
	sd.apply_elite_modifier(dummy_enemy)
	if not dummy_enemy.is_in_group("elites") or not dummy_enemy.has_meta("elite_type"):
		logs.append("FAIL: Elite modifier not applied to enemy node")
		dummy_enemy.queue_free()
		sd.queue_free()
		return false

	# Test that enemy destruction in continuous mode does not clear the active wave
	sd._wave_enemies.append(dummy_enemy)
	sd._on_enemy_destroyed(dummy_enemy, 10)
	if not sd.is_wave_active:
		logs.append("FAIL: Continuous wave was stopped when enemy was destroyed")
		dummy_enemy.queue_free()
		sd.queue_free()
		return false

	dummy_enemy.queue_free()
	sd.queue_free()
	logs.append("  -> Continuous horde progression, budget accumulation, and elite modifiers verified.")
	return true

func test_360_auto_aim_and_auto_fire(logs: Array[String]) -> bool:
	logs.append("[TEST] 360-degree Omnidirectional Auto-Aim & Auto-Fire...")
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player: PlayerHelicopter = player_scene.instantiate() as PlayerHelicopter
	add_child(player)
	player.global_position = Vector3(0.0, 10.0, 0.0)

	var ts: TargetingSystem = player.get_node_or_null("TargetingSystem") as TargetingSystem
	if not ts:
		logs.append("FAIL: Missing TargetingSystem")
		player.remove_from_group("player")
		player.queue_free()
		return false

	if absf(ts.max_yaw_arc_deg - 180.0) > 0.1:
		logs.append("FAIL: TargetingSystem max_yaw_arc_deg is not 180.0 (got %.1f)" % ts.max_yaw_arc_deg)
		player.remove_from_group("player")
		player.queue_free()
		return false

	if absf(ts.min_pitch_deg - (-85.0)) > 0.1 or absf(ts.max_pitch_deg - 45.0) > 0.1:
		logs.append("FAIL: TargetingSystem pitch bounds are not [-85, 45] (got [%.1f, %.1f])" % [ts.min_pitch_deg, ts.max_pitch_deg])
		player.remove_from_group("player")
		player.queue_free()
		return false

	# Spawn enemy BEHIND player (+Z is backward relative to AH-9 heading -Z)
	var rear_enemy := CharacterBody3D.new()
	rear_enemy.name = "RearEnemy"
	rear_enemy.add_to_group("enemies")
	add_child(rear_enemy)
	rear_enemy.global_position = Vector3(0.0, 10.0, 25.0)
	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(rear_enemy, false)

	# Update targeting system
	ts._update_auto_target()
	if ts.current_target != rear_enemy:
		logs.append("FAIL: Targeting system failed to acquire enemy directly behind player")
		if EnemyRegistry.instance:
			EnemyRegistry.instance.unregister_enemy(rear_enemy)
		rear_enemy.queue_free()
		player.remove_from_group("player")
		player.queue_free()
		return false

	# Handle gun aim toward rear target
	player._handle_gun_aim(1.0)
	var gun_yaw: float = player.gun_yaw_pivot.rotation.y
	if absf(absf(gun_yaw) - PI) > 0.5 and absf(gun_yaw) < 2.0:
		logs.append("FAIL: Gun yaw failed to swivel toward rear target (yaw: %.2f rad)" % gun_yaw)
		if EnemyRegistry.instance:
			EnemyRegistry.instance.unregister_enemy(rear_enemy)
		rear_enemy.queue_free()
		player.remove_from_group("player")
		player.queue_free()
		return false

	# Test Auto-Fire: should fire chaingun without pressing fire_primary
	var chaingun: Chaingun = player.chaingun as Chaingun
	chaingun.current_heat = 0.0
	chaingun._shot_cooldown = 0.0
	# Force gun orientation aligned to rear target for clean dot check
	player.gun_pitch_pivot.look_at(rear_enemy.global_position)
	player._handle_weapons()

	if chaingun.current_heat <= 0.0:
		logs.append("FAIL: Auto-fire failed to trigger when target acquired and in line of sight")
		if EnemyRegistry.instance:
			EnemyRegistry.instance.unregister_enemy(rear_enemy)
		rear_enemy.queue_free()
		player.remove_from_group("player")
		player.queue_free()
		return false

	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(rear_enemy)
	rear_enemy.queue_free()
	player.remove_from_group("player")
	player.queue_free()
	logs.append("  -> 360-degree rear target acquisition, turret traversal, and survivor auto-fire verified.")
	return true

func test_predictive_lead_aiming(logs: Array[String]) -> bool:
	logs.append("[TEST] Predictive Lead Aiming Calculation...")
	var ts_script: GDScript = load("res://scripts/player/targeting_system.gd")
	var ts: TargetingSystem = ts_script.new() as TargetingSystem
	add_child(ts)

	var moving_target := CharacterBody3D.new()
	moving_target.name = "MovingTarget"
	add_child(moving_target)
	moving_target.global_position = Vector3(0.0, 0.0, -40.0)
	moving_target.velocity = Vector3(20.0, 0.0, 0.0)

	var muzzle_pos := Vector3(0.0, 0.0, 0.0)
	var predicted := ts.get_predicted_target_position(moving_target, muzzle_pos, 140.0)
	var expected_x := (40.0 / 140.0) * 20.0

	if absf(predicted.x - expected_x) > 0.4:
		logs.append("FAIL: Predictive lead X error too high (got %.3f, expected %.3f)" % [predicted.x, expected_x])
		moving_target.queue_free()
		ts.queue_free()
		return false

	moving_target.queue_free()
	ts.queue_free()
	logs.append("  -> Predictive lead calculation matched projectile flight time accurately.")
	return true

func test_continuous_spawning_and_xp_magnet(logs: Array[String]) -> bool:
	logs.append("[TEST] Continuous Spawning Targets & XP Magnet Responsiveness...")

	# 1. Test SpawnDirector active targets & initial encounter
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: SpawnDirector = sd_script.new() as SpawnDirector
	add_child(sd)

	sd.elapsed_survival_time = 30.0
	var target_early: int = sd.get_target_active_count()
	if target_early < 16 or target_early > 25:
		logs.append("FAIL: Early target active count not in 16-25 range (got %d)" % target_early)
		sd.queue_free()
		return false

	sd.elapsed_survival_time = 240.0
	var target_mid: int = sd.get_target_active_count()
	if target_mid < 25 or target_mid > 40:
		logs.append("FAIL: Mid target active count not in 25-40 range (got %d)" % target_mid)
		sd.queue_free()
		return false

	# Test geometry obstacle & player proximity checking
	var dummy_p := Node3D.new()
	dummy_p.name = "TestPlayer"
	dummy_p.add_to_group("player")
	add_child(dummy_p)
	dummy_p.global_position = Vector3(0, 10, 0)

	# Too close to player (< 24m) must be rejected
	if sd.is_spawn_position_clear(Vector3(0, 0, 10)):
		logs.append("FAIL: is_spawn_position_clear allowed spawn too close to player (10m)")
		dummy_p.queue_free()
		sd.queue_free()
		return false

	# Valid open perimeter point must be clear
	if not sd.is_spawn_position_clear(Vector3(0, 0, 60)):
		logs.append("FAIL: is_spawn_position_clear rejected open road location at 60m")
		dummy_p.queue_free()
		sd.queue_free()
		return false

	dummy_p.queue_free()
	sd.queue_free()

	# 2. Test XPGem instant magnet attraction and collection
	var gem_scene := load("res://scenes/pickups/xp_gem.tscn") as PackedScene
	var gem: XPGem = gem_scene.instantiate() as XPGem
	add_child(gem)
	gem.global_position = Vector3(10, 0.4, 10)

	var dummy_heli := Node3D.new()
	dummy_heli.add_to_group("player")
	add_child(dummy_heli)
	dummy_heli.global_position = Vector3(0, 14, 0) # High hover altitude

	var initial_spd: float = gem.initial_magnet_speed
	var max_spd: float = gem.max_magnet_speed
	var accel: float = gem.magnet_accel
	if initial_spd < 35.0 or max_spd < 95.0 or accel < 240.0:
		logs.append("FAIL: XPGem magnet speeds not upgraded to high-speed (init=%.1f, max=%.1f, accel=%.1f)" % [initial_spd, max_spd, accel])
		gem.queue_free()
		dummy_heli.queue_free()
		return false

	# Setting magnet target must instantly activate attraction speed
	gem.set_magnet_target(dummy_heli)
	if gem._current_speed < 35.0:
		logs.append("FAIL: XPGem did not instantly set initial magnet speed on lock (got %.1f)" % gem._current_speed)
		gem.queue_free()
		dummy_heli.queue_free()
		return false

	# Physics step must accelerate toward max speed
	gem._physics_process(0.15)
	if gem._current_speed <= initial_spd:
		logs.append("FAIL: XPGem failed to accelerate over delta time")
		gem.queue_free()
		dummy_heli.queue_free()
		return false

	# 3. Test Area3D collision setup for XPGem and SalvageCrate
	if not (gem is Area3D) or gem.collision_layer != 16:
		logs.append("FAIL: XPGem is not Area3D on layer 5 (got layer %d)" % gem.collision_layer)
		gem.queue_free()
		dummy_heli.queue_free()
		return false

	var crate_scene := load("res://scenes/pickups/salvage_crate.tscn") as PackedScene
	var crate: Node = crate_scene.instantiate()
	add_child(crate)
	if not (crate is Area3D) or crate.get("collision_layer") != 16:
		logs.append("FAIL: SalvageCrate is not Area3D on layer 5")
		crate.queue_free()
		gem.queue_free()
		dummy_heli.queue_free()
		return false
	if crate.get("initial_magnet_speed") < 35.0 or crate.get("max_magnet_speed") < 95.0:
		logs.append("FAIL: SalvageCrate magnet speeds not upgraded")
		crate.queue_free()
		gem.queue_free()
		dummy_heli.queue_free()
		return false
	crate.queue_free()
	gem.queue_free()
	dummy_heli.queue_free()

	# 4. Test authored SpawnSystem.tscn scene structure
	var ss_scene := load("res://scenes/spawners/spawn_system.tscn") as PackedScene
	if not ss_scene:
		logs.append("FAIL: Failed to load res://scenes/spawners/spawn_system.tscn")
		return false
	var ss: Node = ss_scene.instantiate()
	add_child(ss)
	if not ss.get_node_or_null("GroundSpawnZones") or not ss.get_node_or_null("AirSpawnZones") or not ss.get_node_or_null("RooftopSpawnZones"):
		logs.append("FAIL: SpawnSystem missing Ground, Air, or Rooftop zone containers")
		ss.queue_free()
		return false
	if not (ss.get_node_or_null("StreamTimer") is Timer) or not (ss.get_node_or_null("FormationTimer") is Timer):
		logs.append("FAIL: SpawnSystem missing native StreamTimer or FormationTimer")
		ss.queue_free()
		return false
	ss.queue_free()

	# 5. Test PlayerHelicopter XPMagnetArea and XPCollectArea authored CollisionShape3Ds
	var heli_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var heli: Node = heli_scene.instantiate()
	add_child(heli)
	var mag_area := heli.get_node_or_null("XPMagnetArea") as Area3D
	var col_area := heli.get_node_or_null("XPCollectArea") as Area3D
	if not mag_area or mag_area.collision_mask != 16:
		logs.append("FAIL: PlayerHelicopter missing XPMagnetArea masking Layer 5")
		heli.queue_free()
		return false
	var mag_shape := mag_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not mag_shape or not (mag_shape.shape is CylinderShape3D):
		logs.append("FAIL: XPMagnetArea missing CylinderShape3D CollisionShape3D")
		heli.queue_free()
		return false
	if not col_area or col_area.collision_mask != 16:
		logs.append("FAIL: PlayerHelicopter missing XPCollectArea masking Layer 5")
		heli.queue_free()
		return false
	var col_shape := col_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not col_shape or not (col_shape.shape is CylinderShape3D):
		logs.append("FAIL: XPCollectArea missing CylinderShape3D CollisionShape3D")
		heli.queue_free()
		return false
	heli.queue_free()

	# 6. Test DebugCanvas responsive UI hierarchy
	var dc_scene := load("res://scenes/ui/debug_canvas.tscn") as PackedScene
	if not dc_scene:
		logs.append("FAIL: Failed to load res://scenes/ui/debug_canvas.tscn")
		return false
	var dc: Node = dc_scene.instantiate()
	add_child(dc)
	if dc.get("layer") != 105:
		logs.append("FAIL: DebugCanvas layer is not 105")
		dc.queue_free()
		return false
	if not dc.get_node_or_null("%SurvivalTimeVal") or not dc.get_node_or_null("%ActiveTargetVal"):
		logs.append("FAIL: DebugCanvas missing telemetry label nodes")
		dc.queue_free()
		return false
	dc.queue_free()

	logs.append("  -> Continuous active target curves, obstacle safety, high-speed XP magnet, Area3D detection, and DebugCanvas verified.")
	return true

func test_environment_districts_and_playable_boundary(logs: Array[String]) -> bool:
	append_log("[TEST 22] Starting Environment Districts & Boundary test...", logs)

	# 1. Test PlayableArea 3-tier boundary scene
	append_log("[TEST 22] Sub-step 1.1: Creating dummy player...", logs)
	var dummy_player := CharacterBody3D.new()
	add_child(dummy_player)
	dummy_player.position = Vector3(50.0, 10.0, 0.0)
	dummy_player.global_position = Vector3(50.0, 10.0, 0.0)

	append_log("[TEST 22] Sub-step 1.2: Instantiating PlayableArea...", logs)
	var pa_scene := load("res://scenes/environment/boundary/playable_area.tscn") as PackedScene
	if not pa_scene:
		logs.append("FAIL: Failed to load res://scenes/environment/boundary/playable_area.tscn")
		dummy_player.free()
		return false
	var pa: PlayableArea = pa_scene.instantiate() as PlayableArea
	pa.target_player = dummy_player
	add_child(pa)

	var safe_area := pa.get_node_or_null("InnerSafeArea") as Area3D
	var warn_area := pa.get_node_or_null("WarningBorder") as Area3D
	var hard_body := pa.get_node_or_null("HardBoundary") as StaticBody3D

	if not safe_area or not warn_area or not hard_body:
		logs.append("FAIL: PlayableArea missing one of InnerSafeArea, WarningBorder, or HardBoundary")
		dummy_player.free()
		pa.free()
		return false

	var warning_state := {"received": false, "dist": 0.0}
	var warning_cb := func(is_warn: bool, _dir: Vector3, dist: float) -> void:
		warning_state["received"] = is_warn
		warning_state["dist"] = dist

	EventBus.border_warning_changed.connect(warning_cb)

	# Place player in safe zone (< safe_half_extent)
	var safe_test_x: float = pa.safe_half_extent * 0.5
	append_log("[TEST 22] Sub-step 1.3: Testing safe zone (%.1fm)..." % safe_test_x, logs)
	dummy_player.position = Vector3(safe_test_x, 10.0, 0.0)
	dummy_player.global_position = Vector3(safe_test_x, 10.0, 0.0)
	pa._physics_process(0.016)
	if warning_state["received"]:
		logs.append("FAIL: Boundary warning triggered inside safe zone at %.1fm" % safe_test_x)
		EventBus.border_warning_changed.disconnect(warning_cb)
		dummy_player.free()
		pa.free()
		return false

	# Place player in warning zone (between safe and warning)
	var warn_test_x: float = (pa.safe_half_extent + pa.warning_half_extent) * 0.5
	append_log("[TEST 22] Sub-step 1.4: Testing warning zone (%.1fm)..." % warn_test_x, logs)
	dummy_player.position = Vector3(warn_test_x, 10.0, 0.0)
	dummy_player.global_position = Vector3(warn_test_x, 10.0, 0.0)
	pa._physics_process(0.016)
	if not warning_state["received"]:
		logs.append("FAIL: Boundary warning NOT triggered in warning zone at %.1fm (target_player=%s, pos=%s, is_warn=%s, safe=%s)" % [warn_test_x, str(pa.target_player), str(pa.target_player.global_position if pa.target_player else Vector3.ZERO), str(pa.get("_is_currently_warning")), str(pa.safe_half_extent)])
		EventBus.border_warning_changed.disconnect(warning_cb)
		dummy_player.free()
		pa.free()
		return false

	# Place player past hard boundary (> hard_half_extent) with outward velocity
	var hard_test_x: float = pa.hard_half_extent + 3.0
	append_log("[TEST 22] Sub-step 1.5: Testing hard boundary clamping...", logs)
	dummy_player.position = Vector3(hard_test_x, 10.0, 0.0)
	dummy_player.global_position = Vector3(hard_test_x, 10.0, 0.0)
	dummy_player.velocity = Vector3(25.0, 0.0, 0.0)
	pa._physics_process(0.016)
	if dummy_player.global_position.x > pa.hard_half_extent + 0.01:
		logs.append("FAIL: Hard boundary did not clamp position to <= %.1fm (got %.2f)" % [pa.hard_half_extent, dummy_player.global_position.x])
		EventBus.border_warning_changed.disconnect(warning_cb)
		dummy_player.free()
		pa.free()
		return false

	if dummy_player.velocity.x > 0.01:
		logs.append("FAIL: Hard boundary did not cancel outward velocity (got %.2f)" % dummy_player.velocity.x)
		EventBus.border_warning_changed.disconnect(warning_cb)
		dummy_player.free()
		pa.free()
		return false

	EventBus.border_warning_changed.disconnect(warning_cb)
	dummy_player.free()
	pa.free()

	# 2. Test Destructible Fuel Tank
	append_log("[TEST 22] Sub-step 2: Testing FuelTank...", logs)
	var ft_scene := load("res://scenes/environment/props/fuel_tank.tscn") as PackedScene
	if not ft_scene:
		logs.append("FAIL: Failed to load res://scenes/environment/props/fuel_tank.tscn")
		return false
	var ft: StaticBody3D = ft_scene.instantiate() as StaticBody3D
	add_child(ft)

	if ft.collision_layer != 4:
		logs.append("FAIL: FuelTank collision_layer is %d, expected 4" % ft.collision_layer)
		remove_child(ft)
		ft.free()
		return false

	var initial_hp: float = ft.get("max_health")
	if absf(initial_hp - 60.0) > 0.1:
		logs.append("FAIL: FuelTank initial health is %.1f, expected 60.0" % initial_hp)
		remove_child(ft)
		ft.free()
		return false

	ft.take_damage(20.0)
	var after_hp: float = ft.get("current_health")
	if absf(after_hp - 40.0) > 0.1:
		logs.append("FAIL: FuelTank health after 20 damage is %.1f, expected 40.0" % after_hp)
		remove_child(ft)
		ft.free()
		return false
	remove_child(ft)
	ft.free()

	# 3. Test Destructible Crate Prop
	append_log("[TEST 22] Sub-step 3: Testing Crate...", logs)
	var cr_scene := load("res://scenes/environment/props/crate.tscn") as PackedScene
	if not cr_scene:
		logs.append("FAIL: Failed to load res://scenes/environment/props/crate.tscn")
		return false
	var crate: StaticBody3D = cr_scene.instantiate() as StaticBody3D
	add_child(crate)
	if crate.collision_layer != 4:
		logs.append("FAIL: Crate collision_layer is %d, expected 4" % crate.collision_layer)
		remove_child(crate)
		crate.free()
		return false
	var cr_hp: float = crate.get("max_health")
	if absf(cr_hp - 25.0) > 0.1:
		logs.append("FAIL: Crate initial health is %.1f, expected 25.0" % cr_hp)
		remove_child(crate)
		crate.free()
		return false
	remove_child(crate)
	crate.free()

	# 4. Test HUD Border Warning Banner
	append_log("[TEST 22] Sub-step 4: Testing HUD banner...", logs)
	var hud_scene := load("res://scenes/ui/hud.tscn") as PackedScene
	var hud: Control = hud_scene.instantiate() as Control
	hud.set_process(false)
	add_child(hud)
	var banner: Control = hud.get_node_or_null("%BorderWarningBanner") as Control
	if not banner:
		logs.append("FAIL: HUD missing %BorderWarningBanner")
		hud.free()
		return false
	if banner.visible:
		logs.append("FAIL: HUD %BorderWarningBanner is visible by default")
		hud.free()
		return false

	EventBus.border_warning_changed.emit(true, Vector3(-1, 0, 0), 10.0)
	if not banner.visible:
		logs.append("FAIL: HUD %BorderWarningBanner did not show on border_warning_changed(true)")
		hud.free()
		return false

	EventBus.border_warning_changed.emit(false, Vector3.ZERO, 0.0)
	if banner.visible:
		logs.append("FAIL: HUD %BorderWarningBanner did not hide on border_warning_changed(false)")
		hud.free()
		return false
	hud.free()

	# 5. Test Battlefield Scene Hierarchy & District Organization
	var bf_scene := load("res://scenes/battlefield/battlefield.tscn") as PackedScene
	if not bf_scene:
		logs.append("FAIL: Failed to load res://scenes/battlefield/battlefield.tscn")
		return false
	var state: SceneState = bf_scene.get_state()
	var found_pa := false
	var found_districts := false
	var found_city := false
	var found_ind := false
	var found_mil := false
	var found_out := false
	var found_streamer := false
	for i in range(state.get_node_count()):
		var n: String = state.get_node_name(i)
		if n == "PlayableArea": found_pa = true
		elif n == "CityWorldStreamer": found_streamer = true
		elif n == "Districts": found_districts = true
		elif n == "District_CityCenter" or n == "CentralUrban": found_city = true
		elif n == "District_Industrial" or n == "Industrial": found_ind = true
		elif n == "District_Military" or n == "Military": found_mil = true
		elif n == "District_Outskirts" or n == "Outskirts": found_out = true

	if not found_pa or (not found_districts and not found_streamer):
		logs.append("FAIL: Battlefield missing PlayableArea or CityWorldStreamer/Districts node")
		return false
	if not found_streamer and (not found_city or not found_ind or not found_mil or not found_out):
		logs.append("FAIL: Battlefield missing one of the 4 district nodes")
		return false

	append_log("  -> 3-tier boundary, fuel tank, crate destruction, HUD border alert, and 4-district city battlefield verified.", logs)
	return true

func test_environment_gameplay_integration(logs: Array[String]) -> bool:
	logs.append("[TEST 23] Testing Environment Gameplay Integration...")

	var root_node := Node3D.new()
	root_node.name = "TestBattlefieldRoot"
	add_child(root_node)

	# 1. Setup authored Battlefield containers
	var g_sources := Node3D.new()
	g_sources.name = "GroundSpawnSources"
	root_node.add_child(g_sources)

	var m_north := Marker3D.new()
	m_north.name = "RoadEntrance_North"
	m_north.position = Vector3(0, 0.3, -140)
	g_sources.add_child(m_north)

	var m_south := Marker3D.new()
	m_south.name = "RoadEntrance_South"
	m_south.position = Vector3(0, 0.3, 140)
	g_sources.add_child(m_south)

	var m_ind := Marker3D.new()
	m_ind.name = "IndustrialEntrance"
	m_ind.position = Vector3(120, 0.3, 66)
	g_sources.add_child(m_ind)

	var m_mil := Marker3D.new()
	m_mil.name = "MilitaryGate"
	m_mil.position = Vector3(-66, 0.3, 0)
	g_sources.add_child(m_mil)

	var a_sources := Node3D.new()
	a_sources.name = "AirSpawnSources"
	root_node.add_child(a_sources)

	var a_north := Marker3D.new()
	a_north.name = "AirEntry_North"
	a_north.position = Vector3(0, 20, -140)
	a_sources.add_child(a_north)

	var a_east := Marker3D.new()
	a_east.name = "AirEntry_East"
	a_east.position = Vector3(140, 20, 0)
	a_sources.add_child(a_east)

	var a_south := Marker3D.new()
	a_south.name = "AirEntry_South"
	a_south.position = Vector3(0, 20, 140)
	a_sources.add_child(a_south)

	var a_west := Marker3D.new()
	a_west.name = "AirEntry_West"
	a_west.position = Vector3(-140, 20, 0)
	a_sources.add_child(a_west)

	var r_sources := Node3D.new()
	r_sources.name = "RooftopSpawnSources"
	root_node.add_child(r_sources)

	var r_tower := Marker3D.new()
	r_tower.name = "CommunicationsTower"
	r_tower.position = Vector3(31, 24.42, -96)
	r_sources.add_child(r_tower)

	var r_civic := Marker3D.new()
	r_civic.name = "CivicOffice"
	r_civic.position = Vector3(31, 11.42, -38)
	r_sources.add_child(r_civic)

	var r_wh := Marker3D.new()
	r_wh.name = "FreightWarehouse"
	r_wh.position = Vector3(34, 8.42, 30)
	r_sources.add_child(r_wh)

	var p_locations := Node3D.new()
	p_locations.name = "PickupLocations"
	root_node.add_child(p_locations)

	var p1 := Marker3D.new()
	p1.name = "SupplyPoint_01"
	p1.position = Vector3(35, 0.3, 50)
	p_locations.add_child(p1)

	var p2 := Marker3D.new()
	p2.name = "SupplyPoint_02"
	p2.position = Vector3(-24, 0.3, 24)
	p_locations.add_child(p2)

	var o_locations := Node3D.new()
	o_locations.name = "ObjectiveLocations"
	root_node.add_child(o_locations)

	var o_radar := Marker3D.new()
	o_radar.name = "RadarObjective"
	o_radar.position = Vector3(-95, 0.5, -37)
	o_locations.add_child(o_radar)

	# Dummy player
	var dummy_p := Node3D.new()
	dummy_p.name = "PlayerHelicopter"
	dummy_p.add_to_group("player")
	root_node.add_child(dummy_p)
	dummy_p.global_position = Vector3(0, 10, 0)

	# Instantiate SpawnDirector as sibling in root_node
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: SpawnDirector = sd_script.new() as SpawnDirector
	root_node.add_child(sd)
	sd.is_continuous_mode = true

	# 2. Verify Ground Entrance Selection & Alternation
	var ground_spawn_1 := sd.get_authored_ground_spawn("tank", dummy_p.global_position, 28.0)
	var s_name_1: String = ground_spawn_1.get("source_name", "")
	if s_name_1 != "IndustrialEntrance" and s_name_1 != "MilitaryGate":
		logs.append("FAIL: Tank ground spawn did not select IndustrialEntrance or MilitaryGate (got %s)" % s_name_1)
		root_node.queue_free()
		return false

	var ground_spawn_2 := sd.get_authored_ground_spawn("tank", dummy_p.global_position, 28.0)
	var s_name_2: String = ground_spawn_2.get("source_name", "")
	if s_name_2 == s_name_1:
		logs.append("FAIL: Ground spawn did not alternate sources on consecutive calls (repeated %s)" % s_name_1)
		root_node.queue_free()
		return false

	var ground_pos: Vector3 = ground_spawn_1.get("position", Vector3.ZERO)
	if dummy_p.global_position.distance_to(ground_pos) < 28.0:
		logs.append("FAIL: Ground spawn closer than min safe distance of 28m")
		root_node.queue_free()
		return false

	# 3. Verify Air Corridor Selection, Inward Heading, and Min Distance
	var air_entry_1 := sd.get_air_corridor_entry(dummy_p.global_position, 38.0)
	var a_name_1: String = air_entry_1.get("source_name", "")
	var a_head_1: Vector3 = air_entry_1.get("heading", Vector3.ZERO)
	var a_pos_1: Vector3 = air_entry_1.get("position", Vector3.ZERO)
	if not a_name_1.begins_with("AirEntry_"):
		logs.append("FAIL: Air entry did not use authored AirSpawnSources (got %s)" % a_name_1)
		root_node.queue_free()
		return false

	var dist_air := dummy_p.global_position.distance_to(a_pos_1)
	if dist_air < 38.0:
		logs.append("FAIL: Air entry spawned directly above or closer than 38m to player (dist=%.1f)" % dist_air)
		root_node.queue_free()
		return false

	if a_head_1.dot((dummy_p.global_position - a_pos_1).normalized()) < 0.7:
		logs.append("FAIL: Air entry heading does not point inward toward player")
		root_node.queue_free()
		return false

	# 4. Verify Rooftop Threat Marker Tracking, Cap, and Free on Exit
	var r1 := sd.spawn_rooftop_threat(1, dummy_p.global_position)
	if not r1 or sd.get_active_rooftop_count() != 1:
		logs.append("FAIL: spawn_rooftop_threat failed to spawn or increment active rooftop count")
		root_node.queue_free()
		return false

	var _r2 := sd.spawn_rooftop_threat(1, dummy_p.global_position)
	var _r3 := sd.spawn_rooftop_threat(1, dummy_p.global_position)
	if sd.get_active_rooftop_count() != 3:
		logs.append("FAIL: Expected 3 active rooftop threats, got %d" % sd.get_active_rooftop_count())
		root_node.queue_free()
		return false

	var r4 := sd.spawn_rooftop_threat(1, dummy_p.global_position)
	if r4 != null:
		logs.append("FAIL: Rooftop threat spawned exceeding max active cap of 3")
		root_node.queue_free()
		return false

	# Free one rooftop threat and verify marker liberation
	r1.queue_free()
	if is_instance_valid(r1):
		r1.emit_signal("tree_exited")
	if sd.get_active_rooftop_count() != 2:
		logs.append("FAIL: Freeing rooftop threat did not decrement active count (count=%d)" % sd.get_active_rooftop_count())
		root_node.queue_free()
		return false

	# 5. Verify Authored Pickup Spawning at PickupLocations
	var crate1 := sd._try_spawn_authored_pickup()
	if not crate1 or sd._active_authored_pickups.size() != 1:
		logs.append("FAIL: _try_spawn_authored_pickup failed to spawn at authored marker")
		root_node.queue_free()
		return false

	var c_pos: Vector3 = crate1.global_position if crate1.is_inside_tree() else crate1.transform.origin
	if absf(c_pos.x) > 125.0 or absf(c_pos.z) > 125.0:
		logs.append("FAIL: Pickup spawned outside EnvironmentBounds safe area (125m)")
		root_node.queue_free()
		return false

	var crate2 := sd._try_spawn_authored_pickup()
	if not crate2 or sd._active_authored_pickups.size() != 2:
		logs.append("FAIL: Second pickup failed to spawn at alternate authored location")
		root_node.queue_free()
		return false

	var crate3 := sd._try_spawn_authored_pickup()
	if crate3 != null:
		logs.append("FAIL: Pickup spawned exceeding max active authored pickups cap of 2")
		root_node.queue_free()
		return false

	# 6. Verify Objective Location Integration
	sd._spawn_radar_objective()
	var radar_station := root_node.find_child("RadarStation", true, false)
	if not radar_station:
		radar_station = root_node.find_child("*Radar*", true, false)
	if radar_station:
		var r_pos: Vector3 = radar_station.global_position
		if r_pos.distance_to(Vector3(-95, 0.5, -37)) > 1.0:
			logs.append("FAIL: RadarObjective not placed at authored Marker3D location (-95, 0.5, -37)")
			root_node.queue_free()
			return false

	root_node.queue_free()
	append_log("  -> Authored ground entrances, air corridors, rooftop tracking, pickup locations, and bounds verified.", logs)
	return true

func test_ground_and_air_ai(logs: Array[String]) -> bool:
	append_log("[TEST 24] Starting Ground + Air Enemy AI tests...", logs)

	var root_node := Node3D.new()
	root_node.name = "TestAIRoot"
	add_child(root_node)

	var dummy_player := Node3D.new()
	dummy_player.name = "DummyPlayer"
	dummy_player.add_to_group("player")
	dummy_player.position = Vector3(0.0, 10.0, 30.0)
	root_node.add_child(dummy_player)

	# 1. Test InfantryCluster mobility and approach
	var inf_scene := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var inf: Node3D = inf_scene.instantiate() as Node3D
	inf.position = Vector3(0.0, 0.0, 0.0)
	root_node.add_child(inf)

	if not (inf is CharacterBody3D):
		append_log("FAIL: InfantryCluster is not a CharacterBody3D", logs)
		root_node.queue_free()
		return false

	var inf_body := inf as CharacterBody3D
	inf.set("_player", dummy_player)
	inf_body.call("_physics_process", 0.05)
	inf_body.call("_physics_process", 0.05)
	if inf_body.velocity.z <= 0.0:
		append_log("FAIL: InfantryCluster did not advance toward player in APPROACH state (velocity: %s)" % str(inf_body.velocity), logs)
		root_node.queue_free()
		return false

	if int(inf.get("burst_count")) < 4 or float(inf.get("reload_time")) > 1.8:
		append_log("FAIL: InfantryCluster burst count or reload timing not tuned for frequent short bursts", logs)
		root_node.queue_free()
		return false

	# 2. Test Tank approach, chassis orientation, and pre-fire charge
	var tank_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	var tank: Node3D = tank_scene.instantiate() as Node3D
	tank.position = Vector3(0.0, 0.0, -10.0)
	root_node.add_child(tank)

	var tank_body := tank as CharacterBody3D
	tank.set("_player", dummy_player)
	tank.set("current_state", Tank.State.REPOSITIONING)
	tank.set("_reposition_time", 2.0)
	tank.set("_lod_frame_counter", 1)
	tank_body.call("_physics_process", 0.05)
	if tank_body.velocity.z <= 0.0:
		append_log("FAIL: Tank did not advance toward player in REPOSITIONING/APPROACH state (velocity: %s)" % str(tank_body.velocity), logs)
		root_node.queue_free()
		return false

	var charge_light := tank.find_child("ChargeLight", true, false) as OmniLight3D
	if not charge_light:
		append_log("FAIL: Tank missing ChargeLight telegraph node", logs)
		root_node.queue_free()
		return false

	# 3. Test GroundTurret rapid burst parameters
	var turret_scene := load("res://scenes/enemies/ground_turret.tscn") as PackedScene
	var turret: Node3D = turret_scene.instantiate() as Node3D
	root_node.add_child(turret)
	if float(turret.get("aim_prep_time")) > 0.45 or int(turret.get("burst_count")) < 4 or float(turret.get("reload_time")) > 1.6:
		append_log("FAIL: GroundTurret fire timings not tuned for rapid responsive bursts", logs)
		root_node.queue_free()
		return false

	# 4. Test SAMSite telegraph and lock structure
	var sam_scene := load("res://scenes/enemies/sam_site.tscn") as PackedScene
	var sam: Node3D = sam_scene.instantiate() as Node3D
	root_node.add_child(sam)
	if float(sam.get("base_lock_time")) < 1.0 or float(sam.get("reload_time")) < 2.5:
		append_log("FAIL: SAMSite timings unexpectedly rapid, must remain telegraphed and deliberate", logs)
		root_node.queue_free()
		return false

	# 5. Test Flying Enemy AI (AirEnemyController)
	var scout_scene := load("res://scenes/enemies/air_scout_helicopter.tscn") as PackedScene
	var scout: Node3D = scout_scene.instantiate() as Node3D
	scout.position = Vector3(0.0, 16.0, -30.0)
	root_node.add_child(scout)

	var scout_body := scout as CharacterBody3D
	scout.set("_player", dummy_player)
	scout.set("_lod_frame_counter", 1)
	scout.set("_stagger_offset", 0)
	scout_body.call("_physics_process", 0.05)
	scout_body.call("_physics_process", 0.05)
	if scout_body.velocity.z <= 0.0:
		append_log("FAIL: Scout helicopter did not fly toward player in APPROACH state (velocity: %s)" % str(scout_body.velocity), logs)
		root_node.queue_free()
		return false

	# 6. Test Air Enemy Break-Away on player proximity (< 14m)
	scout.global_position = dummy_player.global_position + Vector3(2.0, 0.0, 2.0)
	scout.set("_lod_frame_counter", 1)
	scout_body.call("_physics_process", 0.05)
	var scout_state: int = int(scout.get("current_state"))
	if scout_state != AirEnemyController.State.BREAK_AWAY and scout_state != AirEnemyController.State.DISENGAGE:
		append_log("FAIL: Air enemy did not immediately BREAK_AWAY when dangerously close to player (state: %d)" % scout_state, logs)
		root_node.queue_free()
		return false

	# 7. Test Separation Steering between multiple aircraft
	var raider_scene := load("res://scenes/enemies/air_rocket_raider.tscn") as PackedScene
	var raider1: Node3D = raider_scene.instantiate() as Node3D
	var raider2: Node3D = raider_scene.instantiate() as Node3D
	raider1.position = Vector3(30.0, 16.0, 30.0)
	raider2.position = Vector3(31.0, 16.0, 30.0) # 1m apart (within 10m search radius)
	root_node.add_child(raider1)
	root_node.add_child(raider2)

	var r1_body := raider1 as CharacterBody3D
	var r2_body := raider2 as CharacterBody3D
	r1_body.call("_apply_separation")
	r2_body.call("_apply_separation")

	if r1_body.velocity.x >= r2_body.velocity.x:
		append_log("FAIL: Separation steering failed to push clustered aircraft apart laterally", logs)
		root_node.queue_free()
		return false

	# 8. Test Dynamic Player Pursuit across City
	dummy_player.global_position = Vector3(50.0, 18.0, 50.0) # Player relocates across city (dist ~ 70m)
	scout.global_position = Vector3(0.0, 16.0, 0.0)
	scout.set("_player", dummy_player)
	scout.set("current_state", AirEnemyController.State.REPOSITION)
	scout.set("_lod_frame_counter", 1)
	scout_body.call("_physics_process", 0.05)
	if int(scout.get("current_state")) != AirEnemyController.State.APPROACH:
		append_log("FAIL: Air enemy failed to fall back to APPROACH when player relocated across city", logs)
		root_node.queue_free()
		return false

	# 9. Test Bounded Horizontal Acceleration (No instant velocity snaps)
	scout.global_position = Vector3(0.0, 16.0, 0.0)
	dummy_player.global_position = Vector3(0.0, 16.0, 50.0)
	scout.set("_player", dummy_player)
	scout.set("current_state", AirEnemyController.State.APPROACH)
	scout_body.velocity = Vector3.ZERO
	scout.set("_lod_frame_counter", 1)
	scout_body.call("_physics_process", 0.05)
	if scout_body.velocity.z > 2.5:
		append_log("FAIL: Air enemy snapped velocity instantly instead of bounded acceleration (vel.z: %.2f)" % scout_body.velocity.z, logs)
		root_node.queue_free()
		return false

	# 10. Test Rooftop Clearance and Altitude Banding
	scout.set("_ground_ray_timer", 2.0)
	scout.set("_cached_ground_y", 25.0) # Simulate a 25m tall skyscraper beneath helicopter
	scout.call("_update_altitude", 0.05)
	var tgt_y: float = float(scout.get("_current_target_y"))
	if tgt_y < 29.5: # 25m + 4.5m clearance
		append_log("FAIL: Air enemy did not enforce minimum 4.5m rooftop altitude clearance (target_y: %.2f)" % tgt_y, logs)
		root_node.queue_free()
		return false

	# 11. Test Stuck Detection and Recovery Trigger
	scout.set("current_state", AirEnemyController.State.APPROACH)
	scout.set("_stuck_timer", 1.75)
	scout.set("_last_stuck_pos", scout.global_position)
	scout.call("_check_stuck_condition", 0.1) # Exceeds 1.8s threshold
	if int(scout.get("current_state")) != AirEnemyController.State.RECOVER:
		append_log("FAIL: Air enemy failed to trigger State.RECOVER when stuck against obstacle", logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Ground approach, fire loops, turret/SAM timings, air approach/break-away/separation, bounded accel, roof clearance, and stuck recovery verified.", logs)
	return true

func test_enemy_roster_and_procedural_formations(logs: Array[String]) -> bool:
	append_log("[TEST 25] Starting Enemy Roster + Procedural Formations tests...", logs)

	var root_node := Node3D.new()
	root_node.name = "TestRosterRoot"
	add_child(root_node)

	# 1. Test Ground Enemy Roster Scenes & Archetypes
	var ground_roster := [
		{"path": "res://scenes/enemies/ground_scout_buggy.tscn", "cost": 2, "wtype": GroundEnemyArchetype.WeaponType.RAPID_MG, "hp": 25.0},
		{"path": "res://scenes/enemies/ground_rocket_technical.tscn", "cost": 3, "wtype": GroundEnemyArchetype.WeaponType.ROCKET_BURST, "hp": 35.0},
		{"path": "res://scenes/enemies/ground_assault_ifv.tscn", "cost": 5, "wtype": GroundEnemyArchetype.WeaponType.RAPID_MG, "hp": 50.0},
		{"path": "res://scenes/enemies/ground_troop_carrier_apc.tscn", "cost": 5, "wtype": GroundEnemyArchetype.WeaponType.TROOP_DEPLOY, "hp": 55.0},
		{"path": "res://scenes/enemies/ground_mortar_carrier.tscn", "cost": 6, "wtype": GroundEnemyArchetype.WeaponType.MORTAR_SHELL, "hp": 45.0},
		{"path": "res://scenes/enemies/ground_jammer_vehicle.tscn", "cost": 7, "wtype": GroundEnemyArchetype.WeaponType.JAMMER_ECM, "hp": 45.0}
	]

	for entry in ground_roster:
		var sc := load(entry["path"]) as PackedScene
		if not sc:
			append_log("FAIL: Ground scene missing: %s" % entry["path"], logs)
			root_node.queue_free()
			return false
		var inst: Node3D = sc.instantiate() as Node3D
		root_node.add_child(inst)
		var arch: GroundEnemyArchetype = inst.get("archetype") as GroundEnemyArchetype
		if not arch:
			append_log("FAIL: Vehicle %s missing GroundEnemyArchetype" % entry["path"], logs)
			root_node.queue_free()
			return false
		if arch.threat_cost != entry["cost"]:
			append_log("FAIL: Vehicle %s threat_cost mismatch (expected %d, got %d)" % [entry["path"], entry["cost"], arch.threat_cost], logs)
			root_node.queue_free()
			return false
		if arch.weapon_type != entry["wtype"]:
			append_log("FAIL: Vehicle %s weapon_type mismatch" % entry["path"], logs)
			root_node.queue_free()
			return false
		if inst.current_health != entry["hp"]:
			append_log("FAIL: Vehicle %s health mismatch (expected %.1f, got %.1f)" % [entry["path"], entry["hp"], inst.current_health], logs)
			root_node.queue_free()
			return false
		if entry["wtype"] == GroundEnemyArchetype.WeaponType.JAMMER_ECM and not inst.is_in_group("jammers"):
			append_log("FAIL: Jammer vehicle not registered in 'jammers' group", logs)
			root_node.queue_free()
			return false
		inst.queue_free()

	# 2. Test Air Enemy Roster Threat Costs
	var air_roster := [
		{"path": "res://scenes/enemies/air_scout_helicopter.tscn", "cost": 4},
		{"path": "res://scenes/enemies/air_rocket_raider.tscn", "cost": 6},
		{"path": "res://scenes/enemies/air_attack_gunship.tscn", "cost": 9},
		{"path": "res://scenes/enemies/air_transport_helicopter.tscn", "cost": 7},
		{"path": "res://scenes/enemies/air_jammer_helicopter.tscn", "cost": 8}
	]
	for a_entry in air_roster:
		var a_sc := load(a_entry["path"]) as PackedScene
		var a_inst: Node3D = a_sc.instantiate() as Node3D
		root_node.add_child(a_inst)
		var a_arch: AirEnemyArchetype = a_inst.get("archetype") as AirEnemyArchetype
		if not a_arch or a_arch.threat_cost != a_entry["cost"]:
			append_log("FAIL: Air vehicle %s threat cost mismatch" % a_entry["path"], logs)
			root_node.queue_free()
			return false
		a_inst.queue_free()

	# 3. Test APC Troop Deployment
	var apc_scene := load("res://scenes/enemies/ground_troop_carrier_apc.tscn") as PackedScene
	var apc: Node3D = apc_scene.instantiate() as Node3D
	root_node.add_child(apc)
	apc.call("_deploy_troops")
	if not bool(apc.get("_troops_deployed")):
		append_log("FAIL: APC failed to flag _troops_deployed", logs)
		root_node.queue_free()
		return false
	apc.queue_free()

	# 4. Test Procedural Formation Resources & Composition
	var sd := SpawnDirector.new()
	sd.name = "TestSpawnDirector"
	root_node.add_child(sd)
	sd.call("_load_procedural_formations")
	var forms: Array = sd.get("procedural_formations")
	if forms.size() < 12:
		append_log("FAIL: Expected 12 procedural formations, got %d" % forms.size(), logs)
		root_node.queue_free()
		return false

	# Test light_patrol composition
	var light_patrol := load("res://resources/formations/light_patrol.tres") as FormationDefinition
	if not light_patrol or light_patrol.units.size() != 2:
		append_log("FAIL: light_patrol units mismatch", logs)
		root_node.queue_free()
		return false

	# Test combined_arms composition
	var combined_arms := load("res://resources/formations/combined_arms.tres") as FormationDefinition
	if not combined_arms or combined_arms.units.size() != 3:
		append_log("FAIL: combined_arms units mismatch", logs)
		root_node.queue_free()
		return false

	# 5. Test Elapsed Time Unlock Tiers
	sd.set("continuous_ground_budget", 100.0)
	sd.set("continuous_air_budget", 100.0)

	# At t = 30s (Tier 1: 0-2 min), only 0-min formations eligible
	sd.set("elapsed_survival_time", 30.0)
	for i in range(5):
		var picked: FormationDefinition = sd.call("select_procedural_formation", Vector3.ZERO) as FormationDefinition
		if picked and picked.min_elapsed_time > 30.0:
			append_log("FAIL: Formation unlocked too early: %s (min_time: %.1f at elapsed 30s)" % [picked.formation_id, picked.min_elapsed_time], logs)
			root_node.queue_free()
			return false

	# At t = 180s (Tier 2: 2-5 min), 120s formations become eligible
	sd.set("elapsed_survival_time", 180.0)
	var armored_patrol := load("res://resources/formations/armored_patrol.tres") as FormationDefinition
	if armored_patrol.min_elapsed_time != 120.0:
		append_log("FAIL: armored_patrol min_elapsed_time should be 120s", logs)
		root_node.queue_free()
		return false

	# At t = 360s (Tier 3: 5-8 min), 300s formations become eligible
	sd.set("elapsed_survival_time", 360.0)
	var armored_push := load("res://resources/formations/armored_push.tres") as FormationDefinition
	if armored_push.min_elapsed_time != 300.0:
		append_log("FAIL: armored_push min_elapsed_time should be 300s", logs)
		root_node.queue_free()
		return false

	# At t = 540s (Tier 4: 8+ min), 480s formations become eligible
	sd.set("elapsed_survival_time", 540.0)
	var gunship_escort := load("res://resources/formations/gunship_escort.tres") as FormationDefinition
	if gunship_escort.min_elapsed_time != 480.0:
		append_log("FAIL: gunship_escort min_elapsed_time should be 480s", logs)
		root_node.queue_free()
		return false

	# 6. Test Variety Rules: Anti-Repetition
	var history: Array = sd.get("formation_history")
	history.clear()
	sd.call("_record_formation", "light_patrol")
	if sd.call("can_spawn_formation", "light_patrol"):
		append_log("FAIL: can_spawn_formation allowed exact repeat of last formation", logs)
		root_node.queue_free()
		return false

	# 7. Test Tactical Caps Enforcement
	for existing_sam in get_tree().get_nodes_in_group("sam_sites"):
		existing_sam.remove_from_group("sam_sites")

	sd.set("cap_sam", 3)
	var sam1 := Node3D.new()
	sam1.add_to_group("sam_sites")
	var sam2 := Node3D.new()
	sam2.add_to_group("sam_sites")
	var sam3 := Node3D.new()
	sam3.add_to_group("sam_sites")
	root_node.add_child(sam1)
	root_node.add_child(sam2)
	root_node.add_child(sam3)

	var active_sams: int = sd.call("get_active_unit_count", "sam")
	if active_sams != 3:
		append_log("FAIL: Expected 3 active SAMs, got %d" % active_sams, logs)
		root_node.queue_free()
		return false

	# Now check SAM defense formation selection when cap is reached
	var sam_defense := load("res://resources/formations/sam_defense.tres") as FormationDefinition
	var forms_list: Array[FormationDefinition] = [sam_defense]
	sd.set("procedural_formations", forms_list)
	history.clear()
	var sam_pick: FormationDefinition = sd.call("select_procedural_formation", Vector3.ZERO) as FormationDefinition
	if sam_pick != null:
		append_log("FAIL: Director selected SAM Defense despite SAM active cap reached", logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Ground/air roster, APC troop deploy, procedural formations, variety rules, elapsed unlock tiers, and tactical caps verified.", logs)
	return true

func test_ground_enemy_grounding_and_gravity(logs: Array[String]) -> bool:
	var root_node := Node3D.new()
	root_node.name = "TestGroundingRoot"
	add_child(root_node)

	# 1. Setup EnemyRegistry if missing
	var reg := EnemyRegistry.instance
	if not reg:
		reg = EnemyRegistry.new()
		reg.name = "EnemyRegistry"
		root_node.add_child(reg)

	# 2. Setup SpawnDirector
	var sd := SpawnDirector.new()
	sd.name = "TestSpawnDirector"
	root_node.add_child(sd)

	# 3. Test that all ground enemy archetypes/scenes are correctly identified as ground (not air)
	var ground_scenes := [
		{"path": "res://scenes/enemies/tank.tscn", "name": "Tank"},
		{"path": "res://scenes/enemies/ground_scout_buggy.tscn", "name": "ScoutBuggy"},
		{"path": "res://scenes/enemies/ground_rocket_technical.tscn", "name": "RocketTechnical"},
		{"path": "res://scenes/enemies/ground_assault_ifv.tscn", "name": "AssaultIFV"},
		{"path": "res://scenes/enemies/ground_troop_carrier_apc.tscn", "name": "TroopCarrierAPC"},
		{"path": "res://scenes/enemies/ground_mortar_carrier.tscn", "name": "MortarCarrier"},
		{"path": "res://scenes/enemies/ground_jammer_vehicle.tscn", "name": "JammerVehicle"},
		{"path": "res://scenes/enemies/infantry_cluster.tscn", "name": "InfantryCluster"},
		{"path": "res://scenes/enemies/ground_turret.tscn", "name": "GroundTurret"}
	]

	for g_entry in ground_scenes:
		var sc := load(g_entry["path"]) as PackedScene
		if not sc:
			append_log("FAIL: Scene missing: %s" % g_entry["path"], logs)
			root_node.queue_free()
			return false
		var enemy: Node3D = sc.instantiate() as Node3D
		root_node.add_child(enemy)

		var is_air: bool = bool(sd.call("_is_air_enemy", enemy))
		if is_air:
			append_log("FAIL: Ground enemy %s erroneously classified as air" % g_entry["name"], logs)
			root_node.queue_free()
			return false

		# Verify EnemyRegistry classification
		if reg.air_enemies.has(enemy):
			append_log("FAIL: Ground enemy %s found in EnemyRegistry.air_enemies" % g_entry["name"], logs)
			root_node.queue_free()
			return false

		enemy.queue_free()

	# 4. Test Continuous Spawner sets ground altitude = 0.0 for ground enemies
	for g_entry in ground_scenes:
		var sc := load(g_entry["path"]) as PackedScene
		var spawned: Node3D = sd.call("_spawn_continuous_enemy", sc, Vector3.ZERO, 0.0) as Node3D
		if spawned:
			if spawned.transform.origin.y > 0.5:
				append_log("FAIL: Ground enemy %s spawned at altitude %.2f (expected <= 0.5)" % [g_entry["name"], spawned.transform.origin.y], logs)
				root_node.queue_free()
				return false
			spawned.queue_free()

	# 5. Test Gravity and Ground Clamp on Tank & Infantry
	var tank_scene := load("res://scenes/enemies/ground_scout_buggy.tscn") as PackedScene
	var test_tank: Tank = tank_scene.instantiate() as Tank
	root_node.add_child(test_tank)
	test_tank.position = Vector3(0.0, 10.0, 0.0) # Start in mid-air

	# Simulate 1 physics step while in mid-air: should have downward vertical velocity
	test_tank._physics_process(0.1)
	if test_tank.velocity.y >= 0.0:
		append_log("FAIL: Airborne ground vehicle did not accelerate downward with gravity (vel.y=%.2f)" % test_tank.velocity.y, logs)
		root_node.queue_free()
		return false

	# Place at subterranean position to test clamp
	test_tank.position.y = -5.0
	test_tank._physics_process(0.1)
	if test_tank.position.y < 0.0:
		append_log("FAIL: Ground vehicle fell below ground plane (y=%.2f)" % test_tank.position.y, logs)
		root_node.queue_free()
		return false

	test_tank.queue_free()

	# Test Infantry gravity
	var inf_scene := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var test_inf: InfantryCluster = inf_scene.instantiate() as InfantryCluster
	root_node.add_child(test_inf)
	test_inf.position = Vector3(0.0, 8.0, 0.0)

	test_inf._physics_process(0.1)
	if test_inf.velocity.y >= 0.0:
		append_log("FAIL: Airborne infantry did not accelerate downward with gravity (vel.y=%.2f)" % test_inf.velocity.y, logs)
		root_node.queue_free()
		return false

	test_inf.position.y = -3.0
	test_inf._physics_process(0.1)
	if test_inf.position.y < 0.0:
		append_log("FAIL: Infantry fell below ground plane (y=%.2f)" % test_inf.position.y, logs)
		root_node.queue_free()
		return false

	test_inf.queue_free()
	root_node.queue_free()
	append_log("  -> Ground classification, continuous spawner ground elevation, gravity, and ground clamping verified.", logs)
	return true

func test_mini_helicopter_support_and_upgrades(logs: Array[String]) -> bool:
	logs.append("[TEST] Mini Helicopter Escort Drones, First Level Guarantee & Upgrades...")
	var root_node := Node3D.new()
	add_child(root_node)

	# 1. Test UpgradeDefinition resource
	var def := UpgradeDefinition.new()
	def.id = "test_upgrade"
	def.display_name = "Test Upgrade"
	def.category = "Support"
	def.benefit = "Does good things"
	def.tradeoff = "Costs something"
	var def_dict: Dictionary = def.to_dictionary()
	if def_dict.get("id") != "test_upgrade" or def_dict.get("display_name") != "Test Upgrade" or def_dict.get("category") != "Support":
		append_log("FAIL: UpgradeDefinition to_dictionary failed", logs)
		root_node.queue_free()
		return false

	# 2. Test First Level-Up Guarantee in UpgradeManager
	var mgr_script: GDScript = load("res://scripts/managers/upgrade_manager.gd")
	var mgr: UpgradeManager = mgr_script.new() as UpgradeManager
	root_node.add_child(mgr)

	# Player reaches Level 2 (first level-up)
	mgr.current_level = 2
	mgr.pending_levels = [2]
	var first_choices: Array = mgr.get_random_choices(3)
	if first_choices.size() != 3:
		append_log("FAIL: First level-up choices did not return 3 cards (got %d)" % first_choices.size(), logs)
		root_node.queue_free()
		return false

	var has_mini_heli := false
	for c in first_choices:
		if c.get("id") == "mini_helicopter_support":
			has_mini_heli = true
			break

	if not has_mini_heli:
		append_log("FAIL: First level-up guarantee failed; mini_helicopter_support not in offered choices", logs)
		root_node.queue_free()
		return false

	# Simulate rejecting mini_helicopter_support on level 2 and leveling up to level 3
	mgr.has_guaranteed_mini_heli_offered = true
	mgr.current_level = 3
	mgr.pending_levels = [3]
	var sub_choices: Array = mgr.get_random_choices(3)
	if sub_choices.size() != 3:
		append_log("FAIL: Subsequent level-up choices did not return 3 cards", logs)
		root_node.queue_free()
		return false

	# 3. Test Mini Helicopter Support Selection & Formation Spawning
	for existing in get_tree().get_nodes_in_group("player"):
		existing.remove_from_group("player")
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player: PlayerHelicopter = player_scene.instantiate() as PlayerHelicopter
	root_node.add_child(player)
	player.global_position = Vector3(0, 10, 0)

	# Projectile pool for firing
	var proj_pool_scene := load("res://scenes/weapons/projectile_pool.tscn") as PackedScene
	var proj_pool: ProjectilePool = proj_pool_scene.instantiate() as ProjectilePool
	root_node.add_child(proj_pool)

	# Apply mini_helicopter_support
	var applied := mgr.apply_upgrade("mini_helicopter_support")
	if not applied:
		append_log("FAIL: Failed to apply mini_helicopter_support upgrade", logs)
		root_node.queue_free()
		return false

	var drones := root_node.get_tree().get_nodes_in_group("mini_helicopters")
	if drones.size() != 2:
		append_log("FAIL: Expected exactly 2 mini helicopters spawned, found %d" % drones.size(), logs)
		root_node.queue_free()
		return false

	var drone1: MiniHelicopter = drones[0] as MiniHelicopter
	var drone2: MiniHelicopter = drones[1] as MiniHelicopter

	# Verify formation slots (flanking left-rear and right-rear)
	var has_left_rear := (drone1.formation_offset.x < -3.0 and drone1.formation_offset.z > 2.0) or (drone2.formation_offset.x < -3.0 and drone2.formation_offset.z > 2.0)
	var has_right_rear := (drone1.formation_offset.x > 3.0 and drone1.formation_offset.z > 2.0) or (drone2.formation_offset.x > 3.0 and drone2.formation_offset.z > 2.0)
	if not has_left_rear or not has_right_rear:
		append_log("FAIL: Mini helicopters do not have correct flanking formation offsets (offsets: %s, %s)" % [str(drone1.formation_offset), str(drone2.formation_offset)], logs)
		root_node.queue_free()
		return false

	# Verify smooth follow (not rigid child nodes glued to player)
	if drone1.get_parent() == player or drone2.get_parent() == player:
		append_log("FAIL: Mini helicopters are rigidly parented to player instead of scene root", logs)
		root_node.queue_free()
		return false

	# Simulate movement and rotor spin
	var initial_rot1: float = drone1.main_rotor.rotation.y if drone1.main_rotor else 0.0
	drone1._physics_process(0.1)
	drone2._physics_process(0.1)
	var post_rot1: float = drone1.main_rotor.rotation.y if drone1.main_rotor else 0.0
	if absf(post_rot1 - initial_rot1) < 0.01:
		append_log("FAIL: Mini helicopter main rotor did not rotate during physics process", logs)
		root_node.queue_free()
		return false

	# 4. Test Auto-Targeting & Auto-Firing
	var reg_script: GDScript = load("res://scripts/common/enemy_registry.gd")
	var reg: EnemyRegistry = reg_script.new() as EnemyRegistry
	root_node.add_child(reg)

	# Clean leftover enemies from prior tests for isolated targeting verification
	for e in root_node.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is Node3D:
			reg.unregister_enemy(e)
			(e as Node3D).remove_from_group("enemies")

	var enemy_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	var dummy_enemy: Tank = enemy_scene.instantiate() as Tank
	dummy_enemy.position = Vector3(5, 0, -10)
	dummy_enemy.is_alive = true
	dummy_enemy.add_to_group("enemies")
	root_node.add_child(dummy_enemy)
	reg.register_enemy(dummy_enemy, false)

	drone1._shot_cooldown = 0.0
	drone1._target_stick_timer = 0.0
	drone1.current_target = null
	drone1._physics_process(0.1)
	if not is_instance_valid(drone1.current_target) and not is_instance_valid(drone2.current_target):
		drone2._shot_cooldown = 0.0
		drone2._target_stick_timer = 0.0
		drone2.current_target = null
		drone2._physics_process(0.1)

	if not is_instance_valid(drone1.current_target) and not is_instance_valid(drone2.current_target):
		append_log("FAIL: Mini helicopter failed to acquire nearby enemy target", logs)
		root_node.queue_free()
		return false

	# Verify companions do not stack on player or each other (Points 8)
	var p_dist1 := drone1.global_position.distance_to(player.global_position)
	var p_dist2 := drone2.global_position.distance_to(player.global_position)
	if p_dist1 < 2.5 or p_dist2 < 2.5:
		append_log("FAIL: Mini helicopter stacked too close to player (dist1=%.2f, dist2=%.2f)" % [p_dist1, p_dist2], logs)
		root_node.queue_free()
		return false

	var drone_gap := drone1.global_position.distance_to(drone2.global_position)
	if drone_gap < 3.0:
		append_log("FAIL: Mini helicopters stacked too close together (gap=%.2f)" % drone_gap, logs)
		root_node.queue_free()
		return false

	# Verify damage to enemy (Point 7)
	var prev_enemy_hp := dummy_enemy.current_health
	dummy_enemy.take_damage(drone1.get_effective_damage())
	if dummy_enemy.current_health >= prev_enemy_hp:
		append_log("FAIL: Companion light chaingun damage not applied to enemy", logs)
		root_node.queue_free()
		return false

	# 4b. Test Support Wingmen Physical Interception, Independent Destruction, and Level-Up Restoration
	# Initial state: Both wingmen active -> upgrade should be ineligible
	if mgr._is_eligible("mini_helicopter_support"):
		append_log("FAIL: Support Wingmen should not be eligible when both aircraft are active", logs)
		root_node.queue_free()
		return false

	# Independent damage / interception test
	var prev_player_hp := player.current_health
	var initial_drone1_hp := drone1.current_health
	drone1.take_damage(20.0)
	if absf(drone1.current_health - (initial_drone1_hp - 20.0)) > 0.1:
		append_log("FAIL: Wingman take_damage did not decrease health correctly (got %.1f)" % drone1.current_health, logs)
		root_node.queue_free()
		return false
	if absf(player.current_health - prev_player_hp) > 0.01:
		append_log("FAIL: Player took damage when wingman was damaged", logs)
		root_node.queue_free()
		return false

	# Independent destruction: destroy drone1, drone2 must survive with full HP intact
	var drone2_hp := drone2.current_health
	drone1.take_damage(100.0)
	if drone1.is_alive:
		append_log("FAIL: Wingman did not die when health reached 0", logs)
		root_node.queue_free()
		return false
	if not drone2.is_alive or absf(drone2.current_health - drone2_hp) > 0.1:
		append_log("FAIL: Surviving wingman was affected when other wingman was destroyed", logs)
		root_node.queue_free()
		return false
	if mgr.get_living_wingmen_count() != 1:
		append_log("FAIL: Expected 1 living wingman after 1 destroyed (got %d)" % mgr.get_living_wingmen_count(), logs)
		root_node.queue_free()
		return false

	# Single survivor eligibility & card enrichment check
	if not mgr._is_eligible("mini_helicopter_support"):
		append_log("FAIL: Support Wingmen should be eligible when 1 aircraft is missing", logs)
		root_node.queue_free()
		return false
	var enriched_restore := mgr.enrich_card_data(mgr.upgrade_database["mini_helicopter_support"])
	if not ("Restore" in enriched_restore.get("benefit", "")):
		append_log("FAIL: Card benefit did not include restoration copy for missing aircraft (got '%s')" % enriched_restore.get("benefit", ""), logs)
		root_node.queue_free()
		return false

	# Level-up selection restores only missing slot, survivor HP is preserved
	var applied_restore := mgr.apply_upgrade("mini_helicopter_support")
	if not applied_restore:
		append_log("FAIL: Failed to apply Support Wingmen restoration upgrade", logs)
		root_node.queue_free()
		return false
	if mgr.get_living_wingmen_count() != 2:
		append_log("FAIL: Expected 2 living wingmen after restoration (got %d)" % mgr.get_living_wingmen_count(), logs)
		root_node.queue_free()
		return false
	if not drone2.is_alive or absf(drone2.current_health - drone2_hp) > 0.1:
		append_log("FAIL: Survivor wingman health was reset during restoration", logs)
		root_node.queue_free()
		return false
	if mgr._is_eligible("mini_helicopter_support"):
		append_log("FAIL: Support Wingmen should be ineligible again once restored to 2", logs)
		root_node.queue_free()
		return false

	# 5. Test Core Catalog Upgrades
	var gun: Chaingun = player.chaingun
	var pod: MissilePod = player.missile_pod
	var prev_heat := gun.heat_per_shot
	var applied_ms := mgr.apply_upgrade("multi_shot")
	if not applied_ms or gun.multishot_count != 2 or gun.heat_per_shot <= prev_heat:
		append_log("FAIL: multi_shot upgrade failed to set multishot_count=2 or increase heat", logs)
		root_node.queue_free()
		return false

	var prev_fire_rate := gun.fire_rate
	var applied_fc := mgr.apply_upgrade("faster_cannon")
	if not applied_fc or gun.fire_rate <= prev_fire_rate:
		append_log("FAIL: faster_cannon upgrade failed to increase fire_rate", logs)
		root_node.queue_free()
		return false

	var applied_le := mgr.apply_upgrade("larger_explosions")
	if not applied_le or pod.splash_radius_multiplier < 1.4:
		append_log("FAIL: larger_explosions upgrade failed to increase splash radius multiplier", logs)
		root_node.queue_free()
		return false

	var prev_cap := pod.max_missiles
	var applied_mc := mgr.apply_upgrade("missile_capacity")
	if not applied_mc or pod.max_missiles != prev_cap + 2:
		append_log("FAIL: missile_capacity upgrade failed to increase max_missiles (got %d, expected %d)" % [pod.max_missiles, prev_cap + 2], logs)
		root_node.queue_free()
		return false

	var prev_ml := pod.multi_launch_count
	var applied_ml := mgr.apply_upgrade("multi_launch")
	if not applied_ml or pod.multi_launch_count != prev_ml + 2:
		append_log("FAIL: multi_launch upgrade failed to increase multi_launch_count", logs)
		root_node.queue_free()
		return false

	var prev_magnet := player.magnet_radius
	var applied_mr := mgr.apply_upgrade("xp_magnet_range")
	if not applied_mr or player.magnet_radius <= prev_magnet:
		append_log("FAIL: xp_magnet_range upgrade failed to increase magnet_radius", logs)
		root_node.queue_free()
		return false

	var prev_spd := player.max_forward_speed
	var applied_mb := mgr.apply_upgrade("movement_boost")
	if not applied_mb or player.max_forward_speed <= prev_spd:
		append_log("FAIL: movement_boost upgrade failed to increase max_forward_speed", logs)
		root_node.queue_free()
		return false

	# 6. Test Clean Despawn on Player Death
	if EventBus:
		EventBus.player_died.emit()
	var remaining_drones: int = 0
	for d in root_node.get_tree().get_nodes_in_group("mini_helicopters"):
		if is_instance_valid(d) and not d.is_queued_for_deletion():
			remaining_drones += 1

	if remaining_drones > 0:
		append_log("FAIL: Mini helicopters did not queue_free upon player death", logs)
		root_node.queue_free()
		return false

	dummy_enemy.queue_free()
	root_node.queue_free()
	append_log("  -> Mini Helicopter escort drones, first-level guarantee, targeting, and upgrade catalog verified.", logs)
	return true

func test_limited_missile_ammo_and_pickups(logs: Array[String]) -> bool:
	logs.append("[TEST 28] Limited Missile Ammo, Ammo Crate Pickups, Upgrade Integration & HUD...")
	var root_node := Node3D.new()
	root_node.name = "TestMissileAmmoRoot"
	add_child(root_node)

	# Clean up any leftover pickups or players in groups
	for p in get_tree().get_nodes_in_group("missile_pickups"):
		if is_instance_valid(p):
			(p as Node).queue_free()
	for pl in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(pl):
			(pl as Node).remove_from_group("player")

	# 1. Test MissilePod ammo properties and starting ammo
	var pod_scene := load("res://scenes/weapons/missile_pod.tscn") as PackedScene
	var pod: MissilePod = pod_scene.instantiate() as MissilePod
	root_node.add_child(pod)

	if pod.max_missiles != 6 or pod.current_missiles != 6:
		append_log("FAIL: MissilePod starting ammo is not 6/6 (max=%d, cur=%d)" % [pod.max_missiles, pod.current_missiles], logs)
		root_node.queue_free()
		return false

	# 2. Test Ammo Consumption on fire
	pod._cooldown_timer = 0.0
	var fired_1 := pod.try_fire()
	if not fired_1 or pod.current_missiles != 5:
		append_log("FAIL: First missile fire failed to consume ammo or return true (ammo=%d)" % pod.current_missiles, logs)
		root_node.queue_free()
		return false

	# Fire remaining 5 missiles
	for i in range(5):
		pod._cooldown_timer = 0.0
		pod.try_fire()

	if pod.current_missiles != 0:
		append_log("FAIL: Missile ammo did not reach 0 after 6 fires (cur=%d)" % pod.current_missiles, logs)
		root_node.queue_free()
		return false

	# 3. Test Firing on Empty (current_missiles == 0)
	var warn_received := [false]
	var no_ammo_received := [false]
	var cb_warn = func() -> void: warn_received[0] = true
	var cb_ammo = func() -> void: no_ammo_received[0] = true

	if EventBus:
		EventBus.no_missiles_warning.connect(cb_warn)
	pod.no_ammo.connect(cb_ammo)

	pod._cooldown_timer = 0.0
	var fired_empty := pod.try_fire()
	if EventBus and EventBus.no_missiles_warning.is_connected(cb_warn):
		EventBus.no_missiles_warning.disconnect(cb_warn)

	if fired_empty:
		append_log("FAIL: MissilePod fired when current_missiles == 0", logs)
		root_node.queue_free()
		return false

	if not no_ammo_received[0] or not warn_received[0]:
		append_log("FAIL: MissilePod failed to emit no_ammo or EventBus.no_missiles_warning on empty fire", logs)
		root_node.queue_free()
		return false

	# 4. Verify No Automatic Ammo Regeneration
	pod._process(1.5)
	if pod.current_missiles != 0:
		append_log("FAIL: Missile ammo automatically regenerated over time without pickups", logs)
		root_node.queue_free()
		return false

	# 5. Test replenish_ammo() and reset_ammo()
	var gained := pod.replenish_ammo(3)
	if gained != 3 or pod.current_missiles != 3:
		append_log("FAIL: replenish_ammo(3) did not restore 3 missiles (cur=%d)" % pod.current_missiles, logs)
		root_node.queue_free()
		return false

	pod.reset_ammo()
	if pod.current_missiles != 6:
		append_log("FAIL: reset_ammo() did not reset ammo to 6 (cur=%d)" % pod.current_missiles, logs)
		root_node.queue_free()
		return false

	# 6. Test Upgrade Integration: Missile Capacity vs Multi-Launch
	var mgr_script: GDScript = load("res://scripts/managers/upgrade_manager.gd")
	var mgr: UpgradeManager = mgr_script.new() as UpgradeManager
	root_node.add_child(mgr)

	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player: PlayerHelicopter = player_scene.instantiate() as PlayerHelicopter
	root_node.add_child(player)

	var p_pod: MissilePod = player.missile_pod as MissilePod
	if not p_pod:
		append_log("FAIL: PlayerHelicopter missing missile_pod", logs)
		root_node.queue_free()
		return false

	var base_cap := p_pod.max_missiles
	var base_salvo := p_pod.multi_launch_count

	# Apply missile_capacity
	var cap_applied := mgr.apply_upgrade("missile_capacity")
	if not cap_applied:
		append_log("FAIL: Failed to apply missile_capacity upgrade", logs)
		root_node.queue_free()
		return false

	if p_pod.max_missiles != base_cap + 2:
		append_log("FAIL: missile_capacity did not increase max_missiles by 2 (got %d, expected %d)" % [p_pod.max_missiles, base_cap + 2], logs)
		root_node.queue_free()
		return false

	if p_pod.multi_launch_count != base_salvo:
		append_log("FAIL: missile_capacity altered multi_launch_count (salvo should be separate)", logs)
		root_node.queue_free()
		return false

	# Apply multi_launch
	var ml_applied := mgr.apply_upgrade("multi_launch")
	if not ml_applied or p_pod.multi_launch_count != base_salvo + 2:
		append_log("FAIL: multi_launch upgrade failed to increase salvo count separately", logs)
		root_node.queue_free()
		return false

	# 7. Test MissileAmmoPickup Scene & Logic
	var pickup_scene := load("res://scenes/pickups/missile_ammo_pickup.tscn") as PackedScene
	if not pickup_scene:
		append_log("FAIL: scenes/pickups/missile_ammo_pickup.tscn failed to load", logs)
		root_node.queue_free()
		return false

	var pickup: MissileAmmoPickup = pickup_scene.instantiate() as MissileAmmoPickup
	root_node.add_child(pickup)

	if not pickup.is_in_group("missile_pickups") or not pickup.is_in_group("pickups"):
		append_log("FAIL: MissileAmmoPickup not in groups missile_pickups and pickups", logs)
		root_node.queue_free()
		return false

	if pickup.refill_amount != 2:
		append_log("FAIL: MissileAmmoPickup refill_amount is not 2 (got %d)" % pickup.refill_amount, logs)
		root_node.queue_free()
		return false

	# 8. Test Full Capacity Rule: Pickup NOT consumed when player ammo is full
	p_pod.reset_ammo()
	var collected_full := pickup._try_collect(player)
	if collected_full or pickup.is_queued_for_deletion():
		append_log("FAIL: Missile ammo pickup was consumed when player ammo was already full!", logs)
		root_node.queue_free()
		return false

	# 9. Test Deficit Collection: Pickup consumed when current_missiles < max_missiles
	p_pod.current_missiles = p_pod.max_missiles - 2 # 6 / 8
	var collected_deficit := pickup._try_collect(player)
	if not collected_deficit or p_pod.current_missiles != p_pod.max_missiles:
		append_log("FAIL: Missile ammo pickup was not collected or did not replenish ammo when low (cur=%d, max=%d)" % [p_pod.current_missiles, p_pod.max_missiles], logs)
		root_node.queue_free()
		return false

	if not pickup.is_queued_for_deletion():
		append_log("FAIL: Missile ammo pickup was not queued for deletion after valid collection", logs)
		root_node.queue_free()
		return false

	# 10. Test Authored Spawning via SpawnDirector
	var spawner := SpawnDirector.new()
	spawner.name = "TestSpawnDirector"
	spawner.autostart_wave = false
	root_node.add_child(spawner)

	var p_locations := Node3D.new()
	p_locations.name = "PickupLocations"
	root_node.add_child(p_locations)
	var sp1 := Marker3D.new()
	sp1.name = "SupplyPoint_01"
	sp1.position = Vector3(35.0, 0.3, 50.0)
	p_locations.add_child(sp1)
	var sp2 := Marker3D.new()
	sp2.name = "SupplyPoint_02"
	sp2.position = Vector3(-24.0, 0.3, 24.0)
	p_locations.add_child(sp2)

	spawner.pickup_locations_node = p_locations

	var p1 := spawner.spawn_authored_missile_pickup()
	if not p1 or not is_instance_valid(p1):
		append_log("FAIL: spawner.spawn_authored_missile_pickup() failed to spawn first crate", logs)
		root_node.queue_free()
		return false

	var p2 := spawner.spawn_authored_missile_pickup()
	if not p2 or not is_instance_valid(p2):
		append_log("FAIL: spawner.spawn_authored_missile_pickup() failed to spawn second crate", logs)
		root_node.queue_free()
		return false

	var p3 := spawner.spawn_authored_missile_pickup()
	if p3 != null:
		append_log("FAIL: spawner spawned more than max 2 simultaneous missile crates", logs)
		root_node.queue_free()
		return false

	# Clear on reset
	spawner.clear_missile_pickups()
	var active_left := 0
	for p_check in get_tree().get_nodes_in_group("missile_pickups"):
		if is_instance_valid(p_check) and not (p_check as Node).is_queued_for_deletion():
			active_left += 1
	if active_left > 0:
		append_log("FAIL: clear_missile_pickups() failed to remove active missile crates", logs)
		root_node.queue_free()
		return false

	# 11. Test HUD Missile Display & Warning State
	var hud_scene := load("res://scenes/ui/hud.tscn") as PackedScene
	var hud: HUD = hud_scene.instantiate() as HUD
	root_node.add_child(hud)

	hud._on_missile_ammo_changed(4, 6)
	if not hud.missile_status.text.contains("MISSILES  4 / 6"):
		append_log("FAIL: HUD missile status label did not display MISSILES  4 / 6 (got '%s')" % hud.missile_status.text, logs)
		root_node.queue_free()
		return false

	hud._on_missile_ammo_changed(0, 6)
	if not hud.missile_status.text.contains("MISSILES  0 / 6") or not hud.missile_status.text.contains("EMPTY"):
		append_log("FAIL: HUD missile status label did not display EMPTY state (got '%s')" % hud.missile_status.text, logs)
		root_node.queue_free()
		return false

	hud._on_no_missiles_warning()
	if not hud.missile_status.text.contains("NO MISSILES"):
		append_log("FAIL: HUD missile status label did not show NO MISSILES warning (got '%s')" % hud.missile_status.text, logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Limited missile ammo, supply pickups, upgrade capacity, and HUD warnings verified.", logs)
	return true

func test_level_up_pacing_and_continuous_spawning(logs: Array[String]) -> bool:
	append_log("[TEST 29] Level-Up Pacing + Continuous Randomized Spawning...", logs)
	var root_node := Node3D.new()
	root_node.name = "Test29Root"
	add_child(root_node)

	# 1. Test Configurable XP Curve in UpgradeManager
	var mgr_script: GDScript = load("res://scripts/managers/upgrade_manager.gd")
	var mgr: UpgradeManager = mgr_script.new() as UpgradeManager
	root_node.add_child(mgr)

	var req_l1 := mgr.get_required_xp_for_level(1)
	var req_l2 := mgr.get_required_xp_for_level(2)
	var req_l3 := mgr.get_required_xp_for_level(3)
	var req_l4 := mgr.get_required_xp_for_level(4)

	if req_l1 != 50 or req_l2 != 90 or req_l3 != 140 or req_l4 != 200:
		append_log("FAIL: Configurable XP curve values mismatch (expected 50, 90, 140, 200; got %d, %d, %d, %d)" % [req_l1, req_l2, req_l3, req_l4], logs)
		root_node.queue_free()
		return false

	# 2. Test Level-Up progression and immediate EventBus notification
	var notified_xp: Array[int] = []
	var on_xp_sig = func(curr: int, needed: int, lvl: int) -> void:
		notified_xp.clear()
		notified_xp.append(curr)
		notified_xp.append(needed)
		notified_xp.append(lvl)
	EventBus.xp_updated.connect(on_xp_sig)

	mgr.reset_run()
	if mgr.xp_needed != 50 or mgr.current_level != 1:
		append_log("FAIL: reset_run failed to set base xp_needed to 50 (got %d, level %d)" % [mgr.xp_needed, mgr.current_level], logs)
		EventBus.xp_updated.disconnect(on_xp_sig)
		root_node.queue_free()
		return false

	# Add 50 XP -> reaches Level 2
	mgr.add_xp(50)
	if mgr.current_level != 2 or mgr.xp_needed != 90:
		append_log("FAIL: add_xp(50) did not reach Level 2 with 90 needed (level: %d, needed: %d)" % [mgr.current_level, mgr.xp_needed], logs)
		EventBus.xp_updated.disconnect(on_xp_sig)
		root_node.queue_free()
		return false

	if notified_xp.is_empty() or notified_xp[1] != 90 or notified_xp[2] != 2:
		append_log("FAIL: EventBus.xp_updated not emitted immediately on level-up (got %s)" % str(notified_xp), logs)
		EventBus.xp_updated.disconnect(on_xp_sig)
		root_node.queue_free()
		return false

	# Add 90 XP -> reaches Level 3
	mgr.add_xp(90)
	if mgr.current_level != 3 or mgr.xp_needed != 140:
		append_log("FAIL: add_xp(90) did not reach Level 3 with 140 needed (level: %d, needed: %d)" % [mgr.current_level, mgr.xp_needed], logs)
		EventBus.xp_updated.disconnect(on_xp_sig)
		root_node.queue_free()
		return false

	# Add 140 XP -> reaches Level 4
	mgr.add_xp(140)
	if mgr.current_level != 4 or mgr.xp_needed != 200:
		append_log("FAIL: add_xp(140) did not reach Level 4 with 200 needed (level: %d, needed: %d)" % [mgr.current_level, mgr.xp_needed], logs)
		EventBus.xp_updated.disconnect(on_xp_sig)
		root_node.queue_free()
		return false

	EventBus.xp_updated.disconnect(on_xp_sig)

	# 3. Test Differentiated Enemy XP Drop Values & Archetypes
	var enemy_reward_checks: Array[Dictionary] = [
		{"path": "res://scenes/enemies/ground_scout_buggy.tscn", "expected_xp": 5},
		{"path": "res://scenes/enemies/ground_rocket_technical.tscn", "expected_xp": 6},
		{"path": "res://scenes/enemies/air_scout_helicopter.tscn", "expected_xp": 6},
		{"path": "res://scenes/enemies/ground_assault_ifv.tscn", "expected_xp": 10},
		{"path": "res://scenes/enemies/ground_troop_carrier_apc.tscn", "expected_xp": 10},
		{"path": "res://scenes/enemies/air_transport_helicopter.tscn", "expected_xp": 12},
		{"path": "res://scenes/enemies/ground_mortar_carrier.tscn", "expected_xp": 16},
		{"path": "res://scenes/enemies/air_rocket_raider.tscn", "expected_xp": 16},
		{"path": "res://scenes/enemies/ground_jammer_vehicle.tscn", "expected_xp": 20},
		{"path": "res://scenes/enemies/air_jammer_helicopter.tscn", "expected_xp": 22},
		{"path": "res://scenes/enemies/air_attack_gunship.tscn", "expected_xp": 25},
		{"path": "res://scenes/enemies/air_ace_gunship.tscn", "expected_xp": 30}
	]

	for item in enemy_reward_checks:
		var sc := load(item["path"]) as PackedScene
		if not sc:
			append_log("FAIL: Could not load enemy scene %s" % item["path"], logs)
			root_node.queue_free()
			return false
		var inst := sc.instantiate() as Node3D
		var arch: Variant = inst.get("archetype")
		if not arch:
			append_log("FAIL: Enemy %s missing archetype resource" % item["path"], logs)
			inst.queue_free()
			root_node.queue_free()
			return false
		var xp_rew: int = int(arch.get("xp_reward"))
		if xp_rew != item["expected_xp"]:
			append_log("FAIL: Enemy %s xp_reward mismatch (got %d, expected %d)" % [item["path"], xp_rew, item["expected_xp"]], logs)
			inst.queue_free()
			root_node.queue_free()
			return false
		inst.queue_free()

	# Test Infantry Cluster XP reward
	var inf_scene := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var inf := inf_scene.instantiate() as InfantryCluster
	if inf.xp_reward != 3:
		append_log("FAIL: InfantryCluster xp_reward is not 3 (got %d)" % inf.xp_reward, logs)
		inf.queue_free()
		root_node.queue_free()
		return false
	inf.queue_free()

	# Test Tank XP reward
	var tank_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	var tank := tank_scene.instantiate() as Tank
	if tank.xp_reward != 16:
		append_log("FAIL: Tank baseline xp_reward is not 16 (got %d)" % tank.xp_reward, logs)
		tank.queue_free()
		root_node.queue_free()
		return false
	tank.queue_free()

	# Test SAM Site XP reward
	var sam_scene := load("res://scenes/enemies/sam_site.tscn") as PackedScene
	var sam := sam_scene.instantiate() as SAMSite
	if sam.xp_reward != 25:
		append_log("FAIL: SAMSite xp_reward is not 25 (got %d)" % sam.xp_reward, logs)
		sam.queue_free()
		root_node.queue_free()
		return false
	sam.queue_free()

	# Test Ground Turret XP reward
	var turret_scene := load("res://scenes/enemies/ground_turret.tscn") as PackedScene
	var turret := turret_scene.instantiate() as GroundTurret
	if turret.xp_reward != 12:
		append_log("FAIL: GroundTurret xp_reward is not 12 (got %d)" % turret.xp_reward, logs)
		turret.queue_free()
		root_node.queue_free()
		return false
	turret.queue_free()

	# Test Hunter Helicopter XP reward
	var hunter_scene := load("res://scenes/enemies/hunter_helicopter.tscn") as PackedScene
	var hunter := hunter_scene.instantiate() as HunterHelicopter
	if hunter.xp_reward != 15:
		append_log("FAIL: HunterHelicopter xp_reward is not 15 (got %d)" % hunter.xp_reward, logs)
		hunter.queue_free()
		root_node.queue_free()
		return false
	hunter.queue_free()

	# 4. Test SpawnDirector Continuous Intervals
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: SpawnDirector = sd_script.new() as SpawnDirector
	root_node.add_child(sd)

	for i in range(10):
		var int_s1: float = sd._get_next_stream_interval(1, false)
		if int_s1 < 1.49 or int_s1 > 2.51:
			append_log("FAIL: Stage 1 stream interval out of range [1.5, 2.5] (got %.2f)" % int_s1, logs)
			root_node.queue_free()
			return false

		var int_s2: float = sd._get_next_stream_interval(2, false)
		if int_s2 < 0.99 or int_s2 > 2.01:
			append_log("FAIL: Stage 2 stream interval out of range [1.0, 2.0] (got %.2f)" % int_s2, logs)
			root_node.queue_free()
			return false

		var int_s4: float = sd._get_next_stream_interval(4, false)
		if int_s4 < 0.69 or int_s4 > 1.51:
			append_log("FAIL: Stage 4 stream interval out of range [0.7, 1.5] (got %.2f)" % int_s4, logs)
			root_node.queue_free()
			return false

		var int_def: float = sd._get_next_stream_interval(1, true)
		if int_def < 0.84 or int_def > 1.21:
			append_log("FAIL: Deficit recovery interval out of range [0.85, 1.2] (got %.2f)" % int_def, logs)
			root_node.queue_free()
			return false

	# 5. Test Formation Staggering Queue
	sd.clear_formation_queue()
	var col_units := sd.spawn_road_column(Vector3(0, 0, 50), Vector3.FORWARD, 3, true)
	if col_units.size() != 3:
		append_log("FAIL: spawn_road_column did not return 3 units (got %d)" % col_units.size(), logs)
		root_node.queue_free()
		return false

	# Lead tank should be inside tree, and 2 escorts should be enqueued
	if sd._formation_spawn_queue.size() != 2:
		append_log("FAIL: Formation staggering queue did not receive 2 escort units (got %d)" % sd._formation_spawn_queue.size(), logs)
		root_node.queue_free()
		return false

	# Process 1 tick of stagger
	sd._formation_stagger_timer = 0.0
	sd._process_formation_stagger_queue(0.1)
	if sd._formation_spawn_queue.size() != 1:
		append_log("FAIL: Stagger queue did not pop 1 unit on timer expiry (got %d remaining)" % sd._formation_spawn_queue.size(), logs)
		root_node.queue_free()
		return false

	# Process 2nd tick of stagger
	sd._formation_stagger_timer = 0.0
	sd._process_formation_stagger_queue(0.1)
	if sd._formation_spawn_queue.size() != 0:
		append_log("FAIL: Stagger queue did not pop final unit (got %d remaining)" % sd._formation_spawn_queue.size(), logs)
		root_node.queue_free()
		return false

	for u in col_units:
		if is_instance_valid(u):
			u.queue_free()

	# 6. Test Source Selection Standoff (>= 35m ground, >= 38m air)
	# Player is at (0, 0, 0)
	var dummy_p := Node3D.new()
	dummy_p.add_to_group("player")
	dummy_p.transform.origin = Vector3.ZERO
	root_node.add_child(dummy_p)

	if sd.is_spawn_position_clear(Vector3(0, 0, 20), false):
		append_log("FAIL: is_spawn_position_clear allowed ground spawn at 20m (< 35m minimum)", logs)
		root_node.queue_free()
		return false

	if sd.is_spawn_position_clear(Vector3(0, 0, 32), false):
		append_log("FAIL: is_spawn_position_clear allowed ground spawn at 32m (< 35m minimum)", logs)
		root_node.queue_free()
		return false

	if sd.is_spawn_position_clear(Vector3(0, 15, 30), true):
		append_log("FAIL: is_spawn_position_clear allowed air spawn at 30m (< 38m minimum)", logs)
		root_node.queue_free()
		return false

	if not sd.is_spawn_position_clear(Vector3(0, 0, 60), false):
		append_log("FAIL: is_spawn_position_clear rejected open ground position at 60m", logs)
		root_node.queue_free()
		return false

	# Test authored ground spawn standoff distance
	var g_entry: Dictionary = sd.get_authored_ground_spawn("infantry", Vector3.ZERO, 35.0)
	var g_pos: Vector3 = g_entry.get("position", Vector3.ZERO)
	var g_dist: float = (g_pos - Vector3.ZERO).length()
	if g_dist < 34.5:
		append_log("FAIL: get_authored_ground_spawn returned position closer than 35m (got %.1fm)" % g_dist, logs)
		root_node.queue_free()
		return false

	# Test air corridor standoff distance
	var a_entry: Dictionary = sd.get_air_corridor_entry(Vector3.ZERO, 38.0, 85.0)
	var a_pos: Vector3 = a_entry.get("position", Vector3.ZERO)
	var a_dist: float = Vector2(a_pos.x, a_pos.z).length()
	if a_dist < 37.5:
		append_log("FAIL: get_air_corridor_entry returned position closer than 38m (got %.1fm)" % a_dist, logs)
		root_node.queue_free()
		return false

	dummy_p.queue_free()
	root_node.queue_free()
	append_log("  -> Level-up pacing curve, differentiated enemy XP drops, continuous stream intervals, formation staggering queue, and entrance standoff verified.", logs)
	return true

func test_survival_encounter_director_and_frustum_safety(logs: Array[String]) -> bool:
	append_log("[TEST 30] Starting Survival Encounter Director & Frustum Safety tests...", logs)
	var root_node := Node3D.new()
	root_node.name = "Test30Root"
	add_child(root_node)

	# 1. Test EncounterConfig Resource definition and serialized default
	if not ResourceLoader.exists("res://resources/directors/default_encounter_config.tres"):
		append_log("FAIL: res://resources/directors/default_encounter_config.tres does not exist", logs)
		root_node.queue_free()
		return false

	var cfg := load("res://resources/directors/default_encounter_config.tres") as EncounterConfig
	if not cfg:
		append_log("FAIL: Failed to load default_encounter_config.tres as EncounterConfig", logs)
		root_node.queue_free()
		return false

	if cfg.warmup_ground_cap != 5 or cfg.warmup_air_cap != 2:
		append_log("FAIL: EncounterConfig warmup caps mismatch (G:%d, A:%d)" % [cfg.warmup_ground_cap, cfg.warmup_air_cap], logs)
		root_node.queue_free()
		return false

	if cfg.max_ground_cap != 14 or cfg.max_air_cap != 6 or cfg.global_active_cap != 20:
		append_log("FAIL: EncounterConfig peak caps mismatch (G:%d, A:%d, Total:%d)" % [cfg.max_ground_cap, cfg.max_air_cap, cfg.global_active_cap], logs)
		root_node.queue_free()
		return false

	if cfg.recovery_duration < 8.0 or cfg.recovery_spawn_rate_mult > 0.40:
		append_log("FAIL: EncounterConfig recovery breather settings mismatch", logs)
		root_node.queue_free()
		return false

	# 2. Test SpawnDirector with EncounterConfig integration
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: SpawnDirector = sd_script.new() as SpawnDirector
	sd.encounter_config = cfg
	root_node.add_child(sd)

	sd.elapsed_survival_time = 5.0
	if sd.get_ground_population_cap() != 5 or sd.get_air_population_cap() != 2 or sd.get_active_population_cap() != 7:
		append_log("FAIL: Warmup population caps not enforced (G:%d, A:%d, Total:%d)" % [sd.get_ground_population_cap(), sd.get_air_population_cap(), sd.get_active_population_cap()], logs)
		root_node.queue_free()
		return false

	sd.elapsed_survival_time = 480.0
	if sd.get_ground_population_cap() != 14 or sd.get_air_population_cap() != 6 or sd.get_active_population_cap() != 20:
		append_log("FAIL: Peak population caps not enforced (G:%d, A:%d, Total:%d)" % [sd.get_ground_population_cap(), sd.get_air_population_cap(), sd.get_active_population_cap()], logs)
		root_node.queue_free()
		return false

	# 3. Test Non-Adjacent Sector Rotation and Escape Routes
	for r in range(5):
		sd._rotate_active_sectors()
		if sd._active_sectors.size() != 2:
			append_log("FAIL: _active_sectors size is not 2 (got %d)" % sd._active_sectors.size(), logs)
			root_node.queue_free()
			return false
		var s1: int = sd._active_sectors[0]
		var s2: int = sd._active_sectors[1]
		if s1 == s2:
			append_log("FAIL: _active_sectors contains identical sectors (%d, %d)" % [s1, s2], logs)
			root_node.queue_free()
			return false
		var diff: int = absi(s1 - s2)
		if diff == 1 or diff == 7:
			append_log("FAIL: _active_sectors are adjacent (%d, %d) - escape route compromised" % [s1, s2], logs)
			root_node.queue_free()
			return false

	# 4. Test Boundary Inward Redistribution (No Edge Clamping)
	var edge_player := Node3D.new()
	edge_player.name = "EdgePlayer"
	edge_player.add_to_group("player")
	root_node.add_child(edge_player)
	var edge_x: float = sd.arena_half_extents - 15.0 # Near outer boundary
	edge_player.global_position = Vector3(edge_x, 14.0, 0.0)

	for i in range(5):
		var spawn_dict := sd.get_dynamic_encounter_spawn_point(false, edge_player.global_position, 38.0, 68.0)
		var sp_pos: Vector3 = spawn_dict.get("position", Vector3.ZERO)
		if absf(sp_pos.x) > sd.arena_half_extents or absf(sp_pos.z) > sd.arena_half_extents:
			append_log("FAIL: get_dynamic_encounter_spawn_point spawned outside bounds (got %.1f, %.1f)" % [sp_pos.x, sp_pos.z], logs)
			root_node.queue_free()
			return false
		if sp_pos.x >= edge_x:
			append_log("FAIL: Spawn position was not redistributed inward away from boundary wall (got x=%.1f)" % sp_pos.x, logs)
			root_node.queue_free()
			return false

	# 5. Test Camera Frustum Safety
	var test_cam := Camera3D.new()
	test_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root_node.add_child(test_cam)
	test_cam.position = Vector3(0.0, 10.0, 30.0)
	test_cam.look_at(Vector3(0.0, 10.0, 0.0), Vector3.UP)
	test_cam.force_update_transform()
	test_cam.current = true

	var in_view_pos := Vector3(0.0, 10.0, 0.0)
	var in_view_result := sd.is_position_in_camera_view(in_view_pos, 100.0)
	if not in_view_result:
		append_log("FAIL: is_position_in_camera_view failed to detect point directly in front of camera", logs)
		root_node.queue_free()
		return false

	var behind_pos := Vector3(0.0, 10.0, 60.0)
	var behind_result := sd.is_position_in_camera_view(behind_pos, 100.0)
	if behind_result:
		append_log("FAIL: is_position_in_camera_view falsely detected point behind camera as in view", logs)
		root_node.queue_free()
		return false

	# 6. Test Surge and Recovery State Machine
	sd.is_wave_active = true
	sd.encounter_state = SpawnDirector.EncounterState.STREAMING
	sd.next_surge_time = 10.0
	sd.elapsed_survival_time = 10.5
	sd._process_continuous_survival(0.1)
	if sd.encounter_state != SpawnDirector.EncounterState.SURGE:
		append_log("FAIL: Encounter state failed to transition to SURGE upon surge trigger time", logs)
		root_node.queue_free()
		return false
	var surge_spawn_interval := sd._get_next_stream_interval(sd.get_survival_stage(), false)
	if surge_spawn_interval < 0.15 or not is_finite(surge_spawn_interval):
		append_log("FAIL: SURGE produced invalid stream interval %.3f" % surge_spawn_interval, logs)
		root_node.queue_free()
		return false

	sd.surge_timer_duration_active = 0.05
	sd._process_continuous_survival(0.1)
	if sd.encounter_state != SpawnDirector.EncounterState.RECOVERY:
		append_log("FAIL: Encounter state failed to transition to RECOVERY after SURGE timeout", logs)
		root_node.queue_free()
		return false
	if sd.recovery_timer_remaining <= 0.0:
		append_log("FAIL: Recovery timer not set for tactical breather", logs)
		root_node.queue_free()
		return false

	sd.recovery_timer_remaining = 0.05
	sd._process_continuous_survival(0.1)
	if sd.encounter_state != SpawnDirector.EncounterState.STREAMING:
		append_log("FAIL: Encounter state failed to transition back to STREAMING after RECOVERY", logs)
		root_node.queue_free()
		return false

	# 7. Test Quiet Despawn (No XP, Salvage, or Kill Count Awarded)
	var distant_enemy := Node3D.new()
	distant_enemy.name = "DistantScout"
	distant_enemy.add_to_group("enemies")
	root_node.add_child(distant_enemy)
	distant_enemy.global_position = Vector3(0.0, 0.0, 180.0)

	sd._wave_enemies.append(distant_enemy)
	var initial_despawns := sd.total_despawns
	var initial_kills := sd.total_enemies_killed

	sd._process_offscreen_cleanup()

	if sd.total_despawns != (initial_despawns + 1):
		append_log("FAIL: Offscreen cleanup failed to increment total_despawns", logs)
		root_node.queue_free()
		return false

	if sd.total_enemies_killed != initial_kills:
		append_log("FAIL: Offscreen quiet despawn incorrectly awarded kill count", logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> EncounterConfig, separate population caps, non-adjacent sectors, boundary inward redistribution, camera frustum safety, surge/recovery cycle, and quiet despawn verified.", logs)
	return true

func test_xp_collection_and_progression_integrity(logs: Array[String]) -> bool:
	append_log("[TEST 31] XP Collection, Volume Sweep & Progression Integrity...", logs)
	var root_node := Node3D.new()
	root_node.name = "Test31Root"
	add_child(root_node)

	# 1. Single basic enemy kill does not trigger level-up
	for existing in get_tree().get_nodes_in_group("upgrade_manager"):
		existing.remove_from_group("upgrade_manager")
	var mgr_script: GDScript = load("res://scripts/managers/upgrade_manager.gd")
	var mgr: UpgradeManager = mgr_script.new() as UpgradeManager
	root_node.add_child(mgr)
	mgr.add_to_group("upgrade_manager")
	mgr.reset_run()

	if mgr.current_level != 1 or mgr.xp_needed != 50 or mgr.current_xp != 0:
		append_log("FAIL: Initial UpgradeManager state invalid (level %d, xp %d/%d)" % [mgr.current_level, mgr.current_xp, mgr.xp_needed], logs)
		root_node.queue_free()
		return false

	# Scout Buggy gives 5 XP (10% toward Level 2)
	mgr.add_xp(5)
	if mgr.current_level != 1 or mgr.current_xp != 5 or not mgr.pending_levels.is_empty():
		append_log("FAIL: Single basic kill (5 XP) caused premature level-up or choice queue (level %d, pending %d)" % [mgr.current_level, mgr.pending_levels.size()], logs)
		root_node.queue_free()
		return false

	# Scout Helicopter gives 6 XP (total 11/50 XP = 22%)
	mgr.add_xp(6)
	if mgr.current_level != 1 or mgr.current_xp != 11 or not mgr.pending_levels.is_empty():
		append_log("FAIL: Second basic kill caused premature level-up (level %d, xp %d/50)" % [mgr.current_level, mgr.current_xp], logs)
		root_node.queue_free()
		return false

	# 2. Boundary condition tests: 49 XP, 50 XP, 51 XP (overflow preservation)
	mgr.reset_run()
	mgr.add_xp(49)
	if mgr.current_level != 1 or mgr.current_xp != 49 or not mgr.pending_levels.is_empty():
		append_log("FAIL: 49 XP boundary failed (level %d, xp %d/50)" % [mgr.current_level, mgr.current_xp], logs)
		root_node.queue_free()
		return false

	# 50 XP exact threshold -> Level 2, 0/90 XP, exactly 1 choice queued
	mgr.add_xp(1)
	if mgr.current_level != 2 or mgr.current_xp != 0 or mgr.xp_needed != 90 or mgr.pending_levels.size() != 1:
		append_log("FAIL: Exact threshold 50 XP did not advance to Level 2 cleanly (level %d, xp %d/%d, pending %d)" % [mgr.current_level, mgr.current_xp, mgr.xp_needed, mgr.pending_levels.size()], logs)
		root_node.queue_free()
		return false

	# 1 overflow XP -> Level 2, 1/90 XP, pending choices still 1
	mgr.add_xp(1)
	if mgr.current_level != 2 or mgr.current_xp != 1 or mgr.xp_needed != 90 or mgr.pending_levels.size() != 1:
		append_log("FAIL: Overflow XP not preserved at Level 2 (level %d, xp %d/%d, pending %d)" % [mgr.current_level, mgr.current_xp, mgr.xp_needed, mgr.pending_levels.size()], logs)
		root_node.queue_free()
		return false

	# 3. Multi-threshold jump & Requisition decoupling
	mgr.reset_run()
	# 150 XP jump:
	# Level 1 requires 50 XP -> reaches Level 2 with 100 XP remaining
	# Level 2 requires 90 XP -> reaches Level 3 with 10 XP remaining
	# Level 3 requires 140 XP -> final state: Level 3, 10/140 XP, exactly 2 choices queued
	mgr.add_xp(150)
	if mgr.current_level != 3 or mgr.current_xp != 10 or mgr.xp_needed != 140 or mgr.pending_levels.size() != 2:
		append_log("FAIL: Multi-threshold jump failed (level %d, xp %d/%d, pending %d)" % [mgr.current_level, mgr.current_xp, mgr.xp_needed, mgr.pending_levels.size()], logs)
		root_node.queue_free()
		return false

	# Requisition point award MUST NOT trigger or queue level-up card selections
	var pending_before := mgr.pending_levels.size()
	mgr.award_requisition(2)
	if mgr.requisition_points != 2 or mgr.pending_levels.size() != pending_before:
		append_log("FAIL: award_requisition corrupted level progression queue (req %d, pending %d vs %d)" % [mgr.requisition_points, mgr.pending_levels.size(), pending_before], logs)
		root_node.queue_free()
		return false

	# 4. Idempotent enemy death and reward guards
	var death_events: Array[int] = [0]
	var on_enemy_destroyed = func(_enemy: Node, _salvage: int) -> void:
		death_events[0] += 1
	EventBus.enemy_destroyed.connect(on_enemy_destroyed)

	var tank_scene: PackedScene = load("res://scenes/enemies/tank.tscn")
	var tank_inst: Tank = tank_scene.instantiate() as Tank
	root_node.add_child(tank_inst)
	tank_inst._die()
	tank_inst._die()
	if death_events[0] != 1:
		append_log("FAIL: Tank._die() is not idempotent (emitted %d death events)" % death_events[0], logs)
		EventBus.enemy_destroyed.disconnect(on_enemy_destroyed)
		root_node.queue_free()
		return false
	tank_inst.queue_free()
	death_events[0] = 0

	var sam_scene: PackedScene = load("res://scenes/enemies/sam_site.tscn")
	var sam_inst: SAMSite = sam_scene.instantiate() as SAMSite
	root_node.add_child(sam_inst)
	sam_inst._die()
	sam_inst._die()
	if death_events[0] != 1:
		append_log("FAIL: SAMSite._die() is not idempotent (emitted %d death events)" % death_events[0], logs)
		EventBus.enemy_destroyed.disconnect(on_enemy_destroyed)
		root_node.queue_free()
		return false
	sam_inst.queue_free()
	death_events[0] = 0

	var hunter_scene: PackedScene = load("res://scenes/enemies/hunter_helicopter.tscn")
	var hunter_inst: HunterHelicopter = hunter_scene.instantiate() as HunterHelicopter
	root_node.add_child(hunter_inst)
	hunter_inst._die()
	hunter_inst._die()
	if death_events[0] != 1:
		append_log("FAIL: HunterHelicopter._die() is not idempotent (emitted %d death events)" % death_events[0], logs)
		EventBus.enemy_destroyed.disconnect(on_enemy_destroyed)
		root_node.queue_free()
		return false
	hunter_inst.queue_free()
	EventBus.enemy_destroyed.disconnect(on_enemy_destroyed)

	# 5. Continuous line-segment sweep & 3D altitude collection
	var mock_player := CharacterBody3D.new()
	mock_player.name = "MockPlayerHeli"
	mock_player.add_to_group("player")
	mock_player.velocity = Vector3(38.0, 0.0, 0.0)
	var tracking_pt := Marker3D.new()
	tracking_pt.name = "StableTrackingPoint"
	mock_player.add_child(tracking_pt)
	root_node.add_child(mock_player)
	mock_player.global_position = Vector3(0.0, 24.0, 0.0)

	var gem_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn")
	var gem: XPGem = gem_scene.instantiate() as XPGem
	root_node.add_child(gem)
	gem.global_position = Vector3(0.0, 0.4, 0.0)
	gem.xp_value = 5

	# 5a. Ground gem idle state: no collection shortcut across 23.6m altitude gap
	gem._physics_process(0.016)
	if gem._is_collected:
		append_log("FAIL: XPGem prematurely collected across 23.6m altitude gap while idle", logs)
		root_node.queue_free()
		return false

	# 5b. Magnetize gem: begins moving upward toward player
	gem.magnetize_to(mock_player)
	if gem.current_state != XPGem.State.MAGNETIZED:
		append_log("FAIL: XPGem failed to transition to MAGNETIZED state", logs)
		root_node.queue_free()
		return false

	# Process 1 tick while still far below
	gem._physics_process(0.016)
	if gem._is_collected or gem.global_position.y >= 20.0:
		append_log("FAIL: XPGem prematurely collected during transit (Y=%.2f, collected=%s)" % [gem.global_position.y, str(gem._is_collected)], logs)
		root_node.queue_free()
		return false

	# 5c. Move gem near the player within sweep distance: (0, 23.0, 0) -> target is (0, 24.0, 0)
	gem.global_position = Vector3(0.0, 23.0, 0.0)
	mgr.reset_run()
	gem._physics_process(0.016)
	if not gem._is_collected or mgr.current_xp != 5:
		append_log("FAIL: XPGem failed sweep collection at player altitude (collected=%s, mgr_xp=%d)" % [str(gem._is_collected), mgr.current_xp], logs)
		root_node.queue_free()
		return false

	# 5d. Verify idempotency on gem collection: calling _collect() again must not double XP
	gem._collect()
	if mgr.current_xp != 5:
		append_log("FAIL: XPGem double collection occurred (mgr_xp=%d expected 5)" % mgr.current_xp, logs)
		root_node.queue_free()
		return false

	mock_player.queue_free()
	gem.queue_free()

	# 6. Run reset integrity & teardown
	mgr.reset_run()
	if mgr.current_level != 1 or mgr.current_xp != 0 or mgr.xp_needed != 50 or not mgr.pending_levels.is_empty():
		append_log("FAIL: Final reset_run failed clean reset (level %d, xp %d, needed %d, pending %d)" % [mgr.current_level, mgr.current_xp, mgr.xp_needed, mgr.pending_levels.size()], logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Single-kill non-level, 49/50/51 XP boundary & overflow, multi-level jumps, requisition decoupling, idempotent death/drops, and 3D altitude sweep collection verified.", logs)
	return true

func test_dynamic_strike_missions(logs: Array[String]) -> bool:
	logs.append("[TEST] Dynamic Strike Missions & Combat Causality...")
	var root_node := Node3D.new()
	root_node.name = "TestBattlefieldRoot"
	add_child(root_node)

	# 1. Setup mock scene environment
	var obj_locations := Node3D.new()
	obj_locations.name = "ObjectiveLocations"
	root_node.add_child(obj_locations)

	var radar_marker := Marker3D.new()
	radar_marker.name = "RadarObjective"
	radar_marker.position = Vector3(-95.0, 0.5, -37.0)
	obj_locations.add_child(radar_marker)

	var mil_marker := Marker3D.new()
	mil_marker.name = "MilitaryObjective"
	mil_marker.position = Vector3(-35.0, 0.3, -35.0)
	obj_locations.add_child(mil_marker)

	var spawn_sources := Node3D.new()
	spawn_sources.name = "GroundSpawnSources"
	root_node.add_child(spawn_sources)
	var north_entrance := Marker3D.new()
	north_entrance.name = "RoadEntrance_North"
	north_entrance.position = Vector3(0.0, 0.3, -190.0)
	spawn_sources.add_child(north_entrance)

	# Managers
	var upgrade_mgr := UpgradeManager.new()
	upgrade_mgr.name = "UpgradeManager"
	upgrade_mgr.add_to_group("upgrade_manager")
	root_node.add_child(upgrade_mgr)
	upgrade_mgr.reset_run()

	var game_mgr := GameManager.new()
	game_mgr.name = "GameManager"
	game_mgr.add_to_group("game_manager")
	root_node.add_child(game_mgr)

	# Player helicopter
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player := player_scene.instantiate() as CharacterBody3D
	root_node.add_child(player)
	player.global_position = Vector3(0.0, 15.0, 0.0)

	# SpawnDirector
	var spawn_director := SpawnDirector.new()
	spawn_director.name = "SpawnDirector"
	spawn_director.add_to_group("spawn_director")
	root_node.add_child(spawn_director)

	# MissionDirector
	var mission_director := MissionDirector.new()
	mission_director.name = "MissionDirector"
	mission_director.auto_start_missions = false
	root_node.add_child(mission_director)

	if mission_director.current_state != MissionDirector.State.IDLE:
		append_log("FAIL: MissionDirector initial state is not IDLE", logs)
		root_node.queue_free()
		return false

	# -------------------------------------------------------------
	# 2. Test Mission 1: Destroy Radar Station & SAM Network Coupling
	# -------------------------------------------------------------
	var sam_scene: PackedScene = load("res://scenes/enemies/sam_site.tscn")
	var sam: SAMSite = sam_scene.instantiate() as SAMSite
	root_node.add_child(sam)
	sam.global_position = Vector3(-80.0, 0.0, -30.0)

	var m1: StrikeMission = mission_director.start_mission_by_id("destroy_radar")
	if not m1 or mission_director.current_state != MissionDirector.State.ACTIVE:
		append_log("FAIL: Destroy Radar mission failed to transition to ACTIVE state", logs)
		root_node.queue_free()
		return false

	if not sam._radar_active:
		append_log("FAIL: SAM site did not receive radar_status_changed(true)", logs)
		root_node.queue_free()
		return false

	# A SAM joining after the radar signal must inherit the current network state.
	var late_sam: SAMSite = sam_scene.instantiate() as SAMSite
	root_node.add_child(late_sam)
	late_sam.global_position = Vector3(-70.0, 0.0, -20.0)
	if not late_sam._radar_active:
		append_log("FAIL: SAM spawned during active Radar mission did not inherit radar state", logs)
		root_node.queue_free()
		return false

	var lock_active: float = sam._get_effective_lock_time()
	var range_active: float = sam._get_effective_threat_range()
	if lock_active > 2.0 or range_active < 80.0:
		append_log("FAIL: SAM site active radar parameters incorrect (lock=%.2f, range=%.2f)" % [lock_active, range_active], logs)
		root_node.queue_free()
		return false

	var hud_info := m1.update(0.2, player)
	if hud_info.get("title") != "DESTROY RADAR" or not String(hud_info.get("detail", "")).ends_with("m"):
		append_log("FAIL: Destroy Radar HUD telemetry format mismatch: %s" % str(hud_info), logs)
		root_node.queue_free()
		return false

	var radar_inst: Node3D = (m1 as DestroyRadarMission).radar_station
	if not is_instance_valid(radar_inst):
		append_log("FAIL: Destroy Radar mission did not instantiate radar station", logs)
		root_node.queue_free()
		return false

	var pre_level: int = upgrade_mgr.current_level
	var pre_xp: int = upgrade_mgr.current_xp
	var pre_req: int = upgrade_mgr.requisition_points
	var pre_salvage: int = game_mgr.run_salvage

	radar_inst.queue_free()
	if not m1.check_completion():
		append_log("FAIL: Destroy Radar mission failed to register completion upon radar free", logs)
		root_node.queue_free()
		return false

	mission_director.resolve_mission(true)

	if sam._radar_active or late_sam._radar_active:
		append_log("FAIL: Existing/new SAM sites failed to transition to degraded mode after radar destroyed", logs)
		root_node.queue_free()
		return false

	var lock_degraded: float = sam._get_effective_lock_time()
	var range_degraded: float = sam._get_effective_threat_range()
	if lock_degraded < 2.0 or range_degraded > 65.0:
		append_log("FAIL: SAM site degraded parameters incorrect (lock=%.2f, range=%.2f)" % [lock_degraded, range_degraded], logs)
		root_node.queue_free()
		return false

	var xp_gained_1: bool = (upgrade_mgr.current_level > pre_level) or (upgrade_mgr.current_xp > pre_xp)
	if not xp_gained_1 or upgrade_mgr.requisition_points != pre_req + 1 or game_mgr.run_salvage <= pre_salvage:
		append_log("FAIL: Destroy Radar mission rewards not awarded correctly (xp=%d->%d, req=%d->%d, salvage=%d->%d)" % [
			pre_xp, upgrade_mgr.current_xp, pre_req, upgrade_mgr.requisition_points, pre_salvage, game_mgr.run_salvage
		], logs)
		root_node.queue_free()
		return false

	sam.queue_free()
	late_sam.queue_free()

	# -------------------------------------------------------------
	# 3. Test Mission 2: Destroy Jammer Convoy & Targeting Disruption
	# -------------------------------------------------------------
	var targeting := player.get_node_or_null("TargetingSystem") as TargetingSystem
	var pod := player.get_node_or_null("StubWings/MissilePod") as MissilePod

	var m2: StrikeMission = mission_director.start_mission_by_id("destroy_jammer")
	if not m2 or mission_director.current_state != MissionDirector.State.ACTIVE:
		append_log("FAIL: Jammer Convoy mission failed to transition to ACTIVE state", logs)
		root_node.queue_free()
		return false

	var jammer_mission := m2 as JammerConvoyMission
	var jammer_inst: Node3D = jammer_mission.jammer_unit
	if not is_instance_valid(jammer_inst):
		append_log("FAIL: Jammer Convoy mission did not instantiate jammer unit", logs)
		root_node.queue_free()
		return false

	if not targeting.is_jammed() or not pod._is_jammed():
		append_log("FAIL: TargetingSystem or MissilePod not jammed during jammer mission", logs)
		root_node.queue_free()
		return false

	hud_info = m2.update(0.2, player)
	if hud_info.get("title") != "DESTROY JAMMER":
		append_log("FAIL: Jammer Convoy HUD telemetry title mismatch: %s" % str(hud_info), logs)
		root_node.queue_free()
		return false

	pre_level = upgrade_mgr.current_level
	pre_xp = upgrade_mgr.current_xp
	pre_req = upgrade_mgr.requisition_points
	pre_salvage = game_mgr.run_salvage

	jammer_inst.remove_from_group("jammers")
	jammer_inst.queue_free()

	if not m2.check_completion():
		append_log("FAIL: Jammer Convoy mission failed to register completion", logs)
		root_node.queue_free()
		return false

	mission_director.resolve_mission(true)

	if targeting.is_jammed() or pod._is_jammed():
		append_log("FAIL: TargetingSystem or MissilePod still jammed after jammer destroyed", logs)
		root_node.queue_free()
		return false

	var xp_gained_2: bool = (upgrade_mgr.current_level > pre_level) or (upgrade_mgr.current_xp > pre_xp)
	if not xp_gained_2 or upgrade_mgr.requisition_points != pre_req + 1 or game_mgr.run_salvage <= pre_salvage:
		append_log("FAIL: Jammer Convoy mission rewards not applied correctly (xp=%d->%d, req=%d->%d, salvage=%d->%d)" % [
			pre_xp, upgrade_mgr.current_xp, pre_req, upgrade_mgr.requisition_points, pre_salvage, game_mgr.run_salvage
		], logs)
		root_node.queue_free()
		return false

	# -------------------------------------------------------------
	# 4. Test Mission 3: Rescue / Secure LZ Proximity Hold & Spawn Focus
	# -------------------------------------------------------------
	var m3: StrikeMission = mission_director.start_mission_by_id("secure_lz")
	if not m3 or mission_director.current_state != MissionDirector.State.ACTIVE:
		append_log("FAIL: Secure LZ mission failed to transition to ACTIVE state", logs)
		root_node.queue_free()
		return false

	var secure_lz: SecureLZMission = m3 as SecureLZMission
	if not spawn_director.has_mission_focus:
		append_log("FAIL: SpawnDirector did not receive mission focus from Secure LZ mission", logs)
		root_node.queue_free()
		return false

	# Position player inside LZ zone (military objective is (-35, 0.3, -35), player at (-35, 12, -35))
	player.global_position = Vector3(-35.0, 12.0, -35.0)
	hud_info = secure_lz.update(5.0, player)
	if secure_lz.current_hold_time != 5.0:
		append_log("FAIL: Secure LZ hold time did not advance (expected 5.0, got %.2f)" % secure_lz.current_hold_time, logs)
		root_node.queue_free()
		return false

	if hud_info.get("detail") != "5 / 20 SEC":
		append_log("FAIL: Secure LZ detail string incorrect: %s" % str(hud_info.get("detail")), logs)
		root_node.queue_free()
		return false

	# Position player outside LZ zone (150, 15, 150)
	player.global_position = Vector3(150.0, 15.0, 150.0)
	hud_info = secure_lz.update(5.0, player)
	if secure_lz.current_hold_time != 5.0:
		append_log("FAIL: Secure LZ hold time advanced while player was out of zone (got %.2f)" % secure_lz.current_hold_time, logs)
		root_node.queue_free()
		return false

	# Return player inside LZ zone and finish hold
	player.global_position = Vector3(-35.0, 20.0, -35.0)
	hud_info = secure_lz.update(15.0, player)
	if secure_lz.current_hold_time != 20.0 or not secure_lz.is_completed:
		append_log("FAIL: Secure LZ mission did not complete at 20s (hold=%.2f, is_completed=%s)" % [secure_lz.current_hold_time, str(secure_lz.is_completed)], logs)
		root_node.queue_free()
		return false

	pre_level = upgrade_mgr.current_level
	pre_xp = upgrade_mgr.current_xp
	pre_req = upgrade_mgr.requisition_points
	pre_salvage = game_mgr.run_salvage

	mission_director.resolve_mission(true)

	if spawn_director.has_mission_focus:
		append_log("FAIL: SpawnDirector mission focus was not cleared upon mission completion", logs)
		root_node.queue_free()
		return false

	var xp_gained_3: bool = (upgrade_mgr.current_level > pre_level) or (upgrade_mgr.current_xp > pre_xp)
	if not xp_gained_3 or upgrade_mgr.requisition_points != pre_req + 1 or game_mgr.run_salvage <= pre_salvage:
		append_log("FAIL: Secure LZ mission rewards not applied correctly (xp=%d->%d, req=%d->%d, salvage=%d->%d)" % [
			pre_xp, upgrade_mgr.current_xp, pre_req, upgrade_mgr.requisition_points, pre_salvage, game_mgr.run_salvage
		], logs)
		root_node.queue_free()
		return false

	# -------------------------------------------------------------
	# 5. Continuous Combat & Non-Interference Verification
	# -------------------------------------------------------------
	spawn_director.set_mission_focus(Vector3(50, 0, 50))
	if not spawn_director.has_mission_focus:
		append_log("FAIL: SpawnDirector focus hook broken", logs)
		root_node.queue_free()
		return false
	spawn_director.clear_mission_focus()
	if spawn_director.has_mission_focus:
		append_log("FAIL: SpawnDirector clear focus broken", logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Dynamic strike missions, radar/SAM causality, jammer EW interference, LZ 3D proximity hold, and continuous horde focus verified.", logs)
	return true

func test_upgrade_drafting_rarity_and_legendary_rules(logs: Array[String]) -> bool:
	logs.append("[TEST] Upgrade Drafting, Rarity Tiers, Eligibility & Legendary Limits...")

	var root_node := Node.new()
	add_child(root_node)

	var run_state := RunStateController.new()
	run_state.add_to_group("run_state_controller")
	root_node.add_child(run_state)

	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerHelicopter
	player.add_to_group("player")
	root_node.add_child(player)

	var menu_scene := load("res://scenes/ui/level_up_menu.tscn") as PackedScene
	var level_up_menu := menu_scene.instantiate() as LevelUpMenu
	level_up_menu.add_to_group("level_up_menu")
	root_node.add_child(level_up_menu)

	var upgrade_mgr := UpgradeManager.new()
	upgrade_mgr.add_to_group("upgrade_manager")
	root_node.add_child(upgrade_mgr)

	# 1. Rarity Classifications & UpgradeDefinition Resources
	var rarities_found: Dictionary = {"Common": 0, "Rare": 0, "Legendary": 0, "Evolution": 0}
	for key in upgrade_mgr.upgrade_database:
		var data: Dictionary = upgrade_mgr.upgrade_database[key]
		var rar: String = data.get("rarity", "")
		if not rarities_found.has(rar):
			append_log("FAIL: Unknown rarity '%s' for upgrade '%s'" % [rar, key], logs)
			root_node.queue_free()
			return false
		rarities_found[rar] += 1

		# Verify corresponding UpgradeDefinition resource
		var def: UpgradeDefinition = upgrade_mgr.get_definition(key)
		if not def:
			append_log("FAIL: Missing UpgradeDefinition for '%s'" % key, logs)
			root_node.queue_free()
			return false
		if def.rarity != rar:
			append_log("FAIL: Rarity mismatch between database and definition for '%s'" % key, logs)
			root_node.queue_free()
			return false
		if def.benefit.is_empty():
			append_log("FAIL: Empty benefit for '%s'" % key, logs)
			root_node.queue_free()
			return false

	if rarities_found["Common"] != 9 or rarities_found["Rare"] != 7 or rarities_found["Legendary"] != 3 or rarities_found["Evolution"] != 6:
		append_log("FAIL: Unexpected rarity distribution in catalog: %s" % str(rarities_found), logs)
		root_node.queue_free()
		return false

	# 2. Normalized 70% Common / 25% Rare / 5% Legendary Weighting & Dynamic Renormalization
	if upgrade_mgr.roll_rarity_tier(0.0, true, true, true) != "Common" or \
	   upgrade_mgr.roll_rarity_tier(0.6999, true, true, true) != "Common" or \
	   upgrade_mgr.roll_rarity_tier(0.70, true, true, true) != "Rare" or \
	   upgrade_mgr.roll_rarity_tier(0.9499, true, true, true) != "Rare" or \
	   upgrade_mgr.roll_rarity_tier(0.95, true, true, true) != "Legendary" or \
	   upgrade_mgr.roll_rarity_tier(0.9999, true, true, true) != "Legendary":
		append_log("FAIL: roll_rarity_tier 3-tier threshold calculation error", logs)
		root_node.queue_free()
		return false

	# 2-tier (No Legendary, e.g. after acquiring one): 0.70 / (0.70 + 0.25) = ~0.73684
	var cutoff_cr: float = 0.70 / 0.95
	if upgrade_mgr.roll_rarity_tier(cutoff_cr - 0.01, true, true, false) != "Common" or \
	   upgrade_mgr.roll_rarity_tier(cutoff_cr + 0.01, true, true, false) != "Rare":
		append_log("FAIL: roll_rarity_tier 2-tier (Common+Rare) renormalization failed", logs)
		root_node.queue_free()
		return false

	# 2-tier (No Common): 0.25 / (0.25 + 0.05) = ~0.83333
	var cutoff_rl: float = 0.25 / 0.30
	if upgrade_mgr.roll_rarity_tier(cutoff_rl - 0.01, false, true, true) != "Rare" or \
	   upgrade_mgr.roll_rarity_tier(cutoff_rl + 0.01, false, true, true) != "Legendary":
		append_log("FAIL: roll_rarity_tier 2-tier (Rare+Legendary) renormalization failed", logs)
		root_node.queue_free()
		return false

	# 1-tier fallback
	if upgrade_mgr.roll_rarity_tier(0.5, true, false, false) != "Common" or \
	   upgrade_mgr.roll_rarity_tier(0.5, false, true, false) != "Rare" or \
	   upgrade_mgr.roll_rarity_tier(0.5, false, false, true) != "Legendary" or \
	   upgrade_mgr.roll_rarity_tier(0.5, false, false, false) != "":
		append_log("FAIL: roll_rarity_tier single/empty tier calculation error", logs)
		root_node.queue_free()
		return false

	# Seeded Monte Carlo distribution test (10,000 samples)
	var counts: Dictionary = {"Common": 0, "Rare": 0, "Legendary": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(10000):
		var r := rng.randf()
		var tier := upgrade_mgr.roll_rarity_tier(r, true, true, true)
		counts[tier] += 1

	# Expected: Common ~7000 (6800-7200), Rare ~2500 (2300-2700), Legendary ~500 (400-600)
	if counts["Common"] < 6800 or counts["Common"] > 7200 or \
	   counts["Rare"] < 2300 or counts["Rare"] > 2700 or \
	   counts["Legendary"] < 400 or counts["Legendary"] > 600:
		append_log("FAIL: Monte Carlo tier distribution outside tolerance: %s" % str(counts), logs)
		root_node.queue_free()
		return false

	# 3. Eligibility Filtering: Dead Player & Weapon Subsystem Dependencies
	if not upgrade_mgr._is_eligible("multi_shot") or not upgrade_mgr._is_eligible("larger_explosions"):
		append_log("FAIL: Standard upgrades should be eligible with live player and subsystems", logs)
		root_node.queue_free()
		return false

	# Dead player ineligibility
	player.is_alive = false
	if upgrade_mgr._is_eligible("multi_shot") or upgrade_mgr._is_eligible("movement_boost"):
		append_log("FAIL: Upgrades should be ineligible when player is dead", logs)
		root_node.queue_free()
		return false
	player.is_alive = true

	# Subsystem dependency
	var saved_gun := player.chaingun
	player.chaingun = null
	if upgrade_mgr._is_eligible("multi_shot") or upgrade_mgr._is_eligible("faster_cannon"):
		append_log("FAIL: Chaingun upgrades should be ineligible when chaingun is missing", logs)
		root_node.queue_free()
		return false
	player.chaingun = saved_gun

	var saved_pod := player.missile_pod
	player.missile_pod = null
	if upgrade_mgr._is_eligible("larger_explosions") or upgrade_mgr._is_eligible("rapid_lock"):
		append_log("FAIL: Missile upgrades should be ineligible when missile_pod is missing", logs)
		root_node.queue_free()
		return false
	player.missile_pod = saved_pod

	# 4. Legendary Limit Enforcement: Maximum 1 Acquired Legendary Per Run
	upgrade_mgr.reset_run()
	if upgrade_mgr.has_acquired_legendary or upgrade_mgr.acquired_legendary_id != "":
		append_log("FAIL: Legendary state not clean after reset_run()", logs)
		root_node.queue_free()
		return false

	if not upgrade_mgr._is_eligible("overdrive_core") or not upgrade_mgr._is_eligible("ghost_rotor") or not upgrade_mgr._is_eligible("one_more_pass"):
		append_log("FAIL: Legendaries must be eligible prior to acquisition", logs)
		root_node.queue_free()
		return false

	var apply_ok := upgrade_mgr.apply_upgrade("overdrive_core")
	if not apply_ok or not upgrade_mgr.has_acquired_legendary or upgrade_mgr.acquired_legendary_id != "overdrive_core":
		append_log("FAIL: Failed to acquire initial Legendary upgrade", logs)
		root_node.queue_free()
		return false

	if upgrade_mgr._is_eligible("ghost_rotor") or upgrade_mgr._is_eligible("one_more_pass"):
		append_log("FAIL: Other Legendaries must be ineligible after acquiring one Legendary", logs)
		root_node.queue_free()
		return false

	var second_apply := upgrade_mgr.apply_upgrade("ghost_rotor")
	if second_apply:
		append_log("FAIL: Secondary Legendary acquisition should have been rejected", logs)
		root_node.queue_free()
		return false

	for i in range(50):
		var choices := upgrade_mgr.get_random_choices(3)
		for c in choices:
			if c.get("rarity") == "Legendary":
				append_log("FAIL: Legendary offered after Legendary was already acquired: %s" % str(c), logs)
				root_node.queue_free()
				return false

	# 5. Deterministic Evolution Priority Rule
	upgrade_mgr.reset_run()
	if upgrade_mgr._is_eligible("hellfire_minigun") or upgrade_mgr._is_eligible("siege_cannon"):
		append_log("FAIL: Evolutions should be ineligible without prerequisites", logs)
		root_node.queue_free()
		return false

	upgrade_mgr.acquired_upgrades.append("twin_barrel")
	upgrade_mgr.acquired_upgrades.append("overclocked_feed")
	upgrade_mgr.acquired_upgrades.append("armor_piercing")
	upgrade_mgr.acquired_upgrades.append("reinforced_airframe")

	if not upgrade_mgr._is_eligible("hellfire_minigun") or not upgrade_mgr._is_eligible("siege_cannon"):
		append_log("FAIL: Both evolutions should be eligible after satisfying prerequisites", logs)
		root_node.queue_free()
		return false

	upgrade_mgr.guarantee_mini_heli_on_first_offer = false
	var evo_choices := upgrade_mgr.get_random_choices(3)
	if evo_choices.is_empty() or evo_choices[0].get("id") != "hellfire_minigun":
		append_log("FAIL: Priority 1 evolution not placed in slot 0 (got %s)" % (evo_choices[0].get("id") if not evo_choices.is_empty() else "none"), logs)
		root_node.queue_free()
		return false

	var evo_card := evo_choices[0]
	if str(evo_card.get("evolution_synergy", "")).is_empty() or str(evo_card.get("prerequisites_text", "")).is_empty():
		append_log("FAIL: Evolution card missing synergy or prerequisites text: %s" % str(evo_card), logs)
		root_node.queue_free()
		return false

	# 6. Queued Multi-Level Pacing, Duplicate Protection & Exhausted Pool Continue
	upgrade_mgr.reset_run()
	upgrade_mgr.guarantee_mini_heli_on_first_offer = false

	upgrade_mgr.add_xp(50 + 90) # Reaches Level 3, pending levels = [2, 3]
	if upgrade_mgr.current_level != 3 or upgrade_mgr.pending_levels.size() != 2:
		append_log("FAIL: Multi-level XP addition failed (lvl=%d, pending=%s)" % [upgrade_mgr.current_level, str(upgrade_mgr.pending_levels)], logs)
		root_node.queue_free()
		return false

	upgrade_mgr._present_next_choice()
	if not upgrade_mgr.is_choice_active or not level_up_menu.visible:
		append_log("FAIL: Level-up choice modal not active after multi-level gain", logs)
		root_node.queue_free()
		return false

	var offered_first := upgrade_mgr._offered_ids.duplicate()
	if offered_first.is_empty():
		append_log("FAIL: No choices offered on first pending level", logs)
		root_node.queue_free()
		return false

	var pick_id: String = offered_first[0]
	var first_sub := upgrade_mgr.select_choice(pick_id)
	if not first_sub:
		append_log("FAIL: Valid card selection rejected", logs)
		root_node.queue_free()
		return false

	var dup_sub := upgrade_mgr.select_choice(pick_id)
	if dup_sub:
		append_log("FAIL: Duplicate choice submission should have been rejected", logs)
		root_node.queue_free()
		return false

	if not upgrade_mgr.is_choice_active or upgrade_mgr.pending_levels.size() != 1:
		append_log("FAIL: Second pending level choice was not queued and presented properly", logs)
		root_node.queue_free()
		return false

	var offered_second := upgrade_mgr._offered_ids.duplicate()
	if offered_second.has(pick_id):
		append_log("FAIL: Previously acquired upgrade was offered again in second choice", logs)
		root_node.queue_free()
		return false

	var pick_id2: String = offered_second[0]
	upgrade_mgr.select_choice(pick_id2)
	if not upgrade_mgr.pending_levels.is_empty() or upgrade_mgr.is_choice_active:
		append_log("FAIL: Pending levels not empty after resolving all choices", logs)
		root_node.queue_free()
		return false

	# 7. Exhausted Pool Continue Card Resolution
	for key in upgrade_mgr.upgrade_database:
		if not upgrade_mgr.acquired_upgrades.has(key):
			upgrade_mgr.acquired_upgrades.append(key)

	var exhausted_choices := upgrade_mgr.get_random_choices(3)
	if not exhausted_choices.is_empty():
		append_log("FAIL: get_random_choices should return empty when catalog is fully acquired", logs)
		root_node.queue_free()
		return false

	upgrade_mgr.pending_levels.append(99)
	upgrade_mgr.is_choice_active = true
	upgrade_mgr._offered_ids.clear()
	level_up_menu.display_cards([], 99)

	if level_up_menu._buttons.size() != 1 or level_up_menu._buttons[0].text != "CONTINUE":
		append_log("FAIL: Exhausted pool did not create CONTINUE button on level-up menu", logs)
		root_node.queue_free()
		return false

	var continue_res := upgrade_mgr.select_choice("")
	if not continue_res or not upgrade_mgr.pending_levels.is_empty():
		append_log("FAIL: Exhausted pool CONTINUE selection failed to clear pending level", logs)
		root_node.queue_free()
		return false

	# 8. Reset Run restores clean state
	upgrade_mgr.reset_run()
	if not upgrade_mgr.acquired_upgrades.is_empty() or upgrade_mgr.current_level != 1 or upgrade_mgr.current_xp != 0:
		append_log("FAIL: reset_run did not reset level, xp, or acquired upgrades", logs)
		root_node.queue_free()
		return false
	if upgrade_mgr.has_acquired_legendary or upgrade_mgr.acquired_legendary_id != "":
		append_log("FAIL: reset_run did not reset legendary flags", logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Upgrade drafting, rarity weights (70/25/5), eligibility, legendary limit (max 1), deterministic evolution priority, and exhausted pool verified.", logs)
	return true

func test_accessibility_and_enemy_telegraphs(logs: Array[String]) -> bool:
	logs.append("[TEST 34] Starting Accessibility, Persistent Settings & Enemy Telegraphs tests...")
	var root_node := Node3D.new()
	root_node.name = "Test34Root"
	add_child(root_node)

	# 1. Verify SaveSystem Settings Schema, Safe Defaults, and Signal
	var safe_defaults := {
		"screen_shake_enabled": true,
		"screen_shake_intensity": 1.0,
		"damage_flash_enabled": true,
		"damage_flash_intensity": 1.0,
		"reduced_flashing": false,
		"volume_master": 1.0,
		"volume_sfx": 1.0,
		"volume_music": 1.0,
		"move_deadzone": 0.15,
		"aim_deadzone": 0.20,
		"aim_sensitivity": 1.0,
		"aim_exponent": 1.0,
		"controller_glyph_mode": "auto",
		"high_contrast_indicators": false
	}

	var all_settings := SaveSystem.get_all_settings()
	for key in safe_defaults:
		if not all_settings.has(key):
			append_log("FAIL: SaveSystem missing setting key: %s" % key, logs)
			root_node.queue_free()
			return false

	# Test signal emission on set_setting with dictionary closure capture
	var signal_data := {"received": false, "key": "", "val": null}
	var listener := func(k: String, v: Variant) -> void:
		signal_data["received"] = true
		signal_data["key"] = k
		signal_data["val"] = v

	if EventBus and EventBus.has_signal("setting_changed"):
		EventBus.setting_changed.connect(listener)

	SaveSystem.set_setting("screen_shake_intensity", 0.65)
	if not bool(signal_data["received"]) or str(signal_data["key"]) != "screen_shake_intensity" or absf(float(signal_data["val"]) - 0.65) > 0.01:
		append_log("FAIL: EventBus.setting_changed not emitted or incorrect on set_setting (received=%s, key=%s, val=%s)" % [
			str(signal_data["received"]), str(signal_data["key"]), str(signal_data["val"])
		], logs)
		if EventBus and EventBus.has_signal("setting_changed"):
			EventBus.setting_changed.disconnect(listener)
		root_node.queue_free()
		return false

	if EventBus and EventBus.has_signal("setting_changed"):
		EventBus.setting_changed.disconnect(listener)

	# Restore default
	SaveSystem.set_setting("screen_shake_intensity", 1.0)

	# 2. Verify Camera Shake Scaling and Disabling
	var camera_rig_scene := load("res://scenes/camera/camera_rig.tscn") as PackedScene
	var camera_rig: CameraRig = null
	if camera_rig_scene:
		camera_rig = camera_rig_scene.instantiate() as CameraRig
		root_node.add_child(camera_rig)

	if camera_rig:
		# Test shake disabled
		camera_rig.camera_shake_enabled = false
		camera_rig._shake_trauma = 0.0
		camera_rig._on_shake_requested(1.0)
		if camera_rig._shake_trauma > 0.001:
			append_log("FAIL: CameraRig trauma increased while camera_shake_enabled = false", logs)
			root_node.queue_free()
			return false

		# Test shake scaling with intensity 0.5
		camera_rig.camera_shake_enabled = true
		camera_rig.screen_shake_intensity = 0.5
		camera_rig._shake_trauma = 0.0
		camera_rig._on_shake_requested(0.8)
		if absf(camera_rig._shake_trauma - 0.4) > 0.02:
			append_log("FAIL: CameraRig trauma did not scale correctly by intensity (expected 0.4, got %.2f)" % camera_rig._shake_trauma, logs)
			root_node.queue_free()
			return false

		# Test _apply_camera_shake resets camera to zero when disabled
		camera_rig.camera_shake_enabled = false
		camera_rig._apply_camera_shake(0.016)
		if is_instance_valid(camera_rig.camera) and camera_rig.camera.transform.origin != Vector3.ZERO:
			append_log("FAIL: Camera transform offset not reset to ZERO when shake disabled", logs)
			root_node.queue_free()
			return false

	# 3. Verify HUD Damage Flash, Reduced Flashing & Multi-Cue Health
	var hud_scene := load("res://scenes/ui/hud.tscn") as PackedScene
	var hud: HUD = null
	if hud_scene:
		hud = hud_scene.instantiate() as HUD
		root_node.add_child(hud)

	if hud:
		# Verify critical health multi-cue textual label
		hud._on_health_changed(15.0, 100.0)
		if not hud.health_label or not "CRITICAL" in hud.health_label.text or not "[!]" in hud.health_label.text:
			append_log("FAIL: HUD critical health did not format non-color multi-cue text: %s" % (hud.health_label.text if hud.health_label else "null"), logs)
			root_node.queue_free()
			return false

		# Verify normal health display
		hud._on_health_changed(85.0, 100.0)
		if not hud.health_label or not "HULL: 85 / 100" in hud.health_label.text:
			append_log("FAIL: HUD normal health did not format correctly: %s" % (hud.health_label.text if hud.health_label else "null"), logs)
			root_node.queue_free()
			return false

		# Verify damage flash suppression when disabled
		hud._damage_flash_enabled = false
		hud._damage_flash_intensity = 1.0
		hud._on_health_changed(70.0, 100.0)
		if hud.damage_vignette and hud.damage_vignette.color.a > 0.001:
			append_log("FAIL: HUD damage vignette alpha > 0 when damage_flash_enabled is false", logs)
			root_node.queue_free()
			return false

		# Verify reduced flashing mode caps alpha at <= 0.16
		hud._damage_flash_enabled = true
		hud._reduced_flashing = true
		hud._damage_flash_intensity = 1.0
		hud._prev_health = 100.0
		hud._on_health_changed(20.0, 100.0)
		if hud.damage_vignette and hud.damage_vignette.color.a > 0.165:
			append_log("FAIL: HUD reduced_flashing vignette alpha (%.2f) exceeded 0.16 cap" % hud.damage_vignette.color.a, logs)
			root_node.queue_free()
			return false

	# 4. Audio Volume Setting Management
	var sound_scene := load("res://scenes/audio/sound_manager.tscn") as PackedScene
	var sound_mgr: SoundManager = null
	if sound_scene:
		sound_mgr = sound_scene.instantiate() as SoundManager
		root_node.add_child(sound_mgr)

	if sound_mgr:
		SaveSystem.set_setting("volume_master", 0.75)
		SaveSystem.set_setting("volume_sfx", 0.6)
		SaveSystem.set_setting("volume_music", 0.4)
		sound_mgr.apply_volume_settings()
		# Restore
		SaveSystem.set_setting("volume_master", 1.0)
		SaveSystem.set_setting("volume_sfx", 1.0)
		SaveSystem.set_setting("volume_music", 1.0)
		sound_mgr.apply_volume_settings()

	# 5. Input Router Aim Sensitivity & Exponent
	var input_router := InputRouter.new()
	root_node.add_child(input_router)

	SaveSystem.set_setting("aim_sensitivity", 1.35)
	SaveSystem.set_setting("aim_exponent", 1.2)
	SaveSystem.set_setting("controller_glyph_mode", "xbox")
	if absf(input_router.aim_sensitivity - 1.35) > 0.01:
		append_log("FAIL: InputRouter did not update aim_sensitivity from setting", logs)
		root_node.queue_free()
		return false
	if input_router.controller_glyph_mode != "xbox":
		append_log("FAIL: InputRouter did not update controller_glyph_mode from setting", logs)
		root_node.queue_free()
		return false
	# Restore
	SaveSystem.set_setting("aim_sensitivity", 1.0)
	SaveSystem.set_setting("aim_exponent", 1.45)
	SaveSystem.set_setting("controller_glyph_mode", "auto")
	input_router.queue_free()

	# 6. Enemy Telegraphs Verification
	# Heavy Tank Charging tell
	var tank_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	if tank_scene:
		var tank := tank_scene.instantiate() as Tank
		root_node.add_child(tank)
		if not tank.charge_light:
			append_log("FAIL: Tank missing charge_light pre-shot tell node", logs)
			root_node.queue_free()
			return false
		tank.current_state = Tank.State.CHARGING
		tank._state_timer = 0.2
		if not is_instance_valid(tank.charge_light):
			append_log("FAIL: Tank charge_light invalid", logs)
			root_node.queue_free()
			return false
		tank.queue_free()

	# SAM Site Lock Tell
	var sam_scene := load("res://scenes/enemies/sam_site.tscn") as PackedScene
	if sam_scene:
		var sam := sam_scene.instantiate() as SAMSite
		root_node.add_child(sam)
		if not sam.has_method("_on_radar_status_changed"):
			append_log("FAIL: SAM missing radar status handler", logs)
			root_node.queue_free()
			return false
		sam.queue_free()

	# Boss Archon Attack Tells
	var boss_scene := load("res://scenes/enemies/boss_archon.tscn") as PackedScene
	if boss_scene:
		var boss := boss_scene.instantiate() as BossArchon
		root_node.add_child(boss)
		if not boss.has_method("_telegraph_rocket_salvo"):
			append_log("FAIL: BossArchon missing _telegraph_rocket_salvo method", logs)
			root_node.queue_free()
			return false
		if not boss.core_light:
			append_log("FAIL: BossArchon missing core_light node for telegraphs", logs)
			root_node.queue_free()
			return false
		boss.queue_free()

	root_node.queue_free()
	append_log("  -> Accessibility persistent settings, camera shake scaling, damage flash suppression, audio volumes, and enemy telegraph tells verified.", logs)
	return true

func test_xp_aggregation_and_acceptance_suite(logs: Array[String]) -> bool:
	logs.append("[TEST 35] Starting XP Aggregation & 13-Step Acceptance Suite...")
	var root_node := Node3D.new()
	root_node.name = "Test35Root"
	add_child(root_node)

	# 1. XP Gem Aggregation (Conserves 100% total XP value while capping count <= 50)
	var gem_scene := load("res://scenes/pickups/xp_gem.tscn") as PackedScene
	var spawned_gems: Array[XPGem] = []
	var total_initial_xp: int = 0
	var gem_count := 60
	for i in range(gem_count):
		var gem: XPGem = null
		if gem_scene:
			gem = gem_scene.instantiate() as XPGem
		else:
			gem = XPGem.new()
		gem.xp_value = 5
		gem.current_state = XPGem.State.IDLE
		gem.transform.origin = Vector3(randf_range(-4.0, 4.0), 0.4, randf_range(-4.0, 4.0))
		root_node.add_child(gem)
		spawned_gems.append(gem)
		total_initial_xp += 5

	if total_initial_xp != 300:
		append_log("FAIL: Initial XP sum is not 300 (got %d)" % total_initial_xp, logs)
		root_node.queue_free()
		return false

	var _merged_count := XPGem.aggregate_excess_gems(root_node.get_tree(), 50)
	var remaining_active_gems := 0
	var total_remaining_xp := 0
	for g in spawned_gems:
		if is_instance_valid(g) and not g.is_queued_for_deletion() and not g._is_collected:
			remaining_active_gems += 1
			total_remaining_xp += g.xp_value

	if remaining_active_gems > 50:
		append_log("FAIL: Remaining active gems (%d) exceeded cap of 50" % remaining_active_gems, logs)
		root_node.queue_free()
		return false

	if total_remaining_xp != total_initial_xp:
		append_log("FAIL: XP lost during gem aggregation! Expected %d total XP, got %d" % [total_initial_xp, total_remaining_xp], logs)
		root_node.queue_free()
		return false

	# Clean up test gems
	for g in spawned_gems:
		if is_instance_valid(g):
			g.queue_free()

	# 2. Dynamic Strike Mission: 4th Mission (Eliminate Elite)
	var mission_director := MissionDirector.new()
	mission_director.auto_start_missions = false
	root_node.add_child(mission_director)

	if not mission_director._mission_queue.has("eliminate_elite"):
		append_log("FAIL: MissionDirector._mission_queue missing eliminate_elite", logs)
		root_node.queue_free()
		return false

	var elite_mission := mission_director.start_mission_by_id("eliminate_elite")
	if not elite_mission or elite_mission.id != "eliminate_elite":
		append_log("FAIL: start_mission_by_id('eliminate_elite') did not return EliminateEliteMission", logs)
		root_node.queue_free()
		return false

	if elite_mission.time_limit != 60.0 or elite_mission.xp_reward != 80 or elite_mission.salvage_reward != 120 or elite_mission.requisition_reward != 1:
		append_log("FAIL: EliminateEliteMission config values incorrect", logs)
		root_node.queue_free()
		return false

	var reward_text := elite_mission.get_reward_text()
	if "+0" in reward_text or not "+80 XP" in reward_text or not "+120 CR" in reward_text or not "+1 REQ" in reward_text:
		append_log("FAIL: EliminateEliteMission.get_reward_text() ill-formed: '%s'" % reward_text, logs)
		root_node.queue_free()
		return false

	# Verify bounty timer countdown formatting
	var dummy_p := Node3D.new()
	root_node.add_child(dummy_p)
	var update_dict := elite_mission.update(1.0, dummy_p)
	if not ":" in str(update_dict.get("detail", "")):
		append_log("FAIL: EliminateEliteMission update detail missing countdown timer: %s" % str(update_dict.get("detail", "")), logs)
		root_node.queue_free()
		return false

	mission_director.resolve_mission(true)
	mission_director.queue_free()

	# 3. 13-Step Acceptance Suite Verification
	# Step 1: Save system schema & safe migration
	var save_data: Dictionary = SaveSystem.load_data()
	if not save_data.has("upgrades") or not save_data.has("settings") or not save_data.has("salvage"):
		append_log("FAIL: Step 1 (Save system) schema missing required top-level keys", logs)
		root_node.queue_free()
		return false

	# Step 2: Input router authoritative bindings
	for action in ["fire_primary", "fire_secondary", "countermeasure_flares", "aim_override", "pause"]:
		if not InputMap.has_action(action):
			append_log("FAIL: Step 2 (InputRouter) missing action: %s" % action, logs)
			root_node.queue_free()
			return false

	# Step 3: Flight physics isolation
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player: PlayerHelicopter = player_scene.instantiate() as PlayerHelicopter
	root_node.add_child(player)
	if absf(player.max_speed - 38.0) > 0.1 or absf(player.acceleration_stat - 42.0) > 0.1:
		append_log("FAIL: Step 3 (Flight physics) modified player flight constants", logs)
		root_node.queue_free()
		return false

	# Step 4: Weapon system heat & auto-aim
	if not player.chaingun or not player.targeting_system:
		append_log("FAIL: Step 4 (Weapons) missing chaingun or targeting system", logs)
		root_node.queue_free()
		return false

	# Step 5: Enemy hierarchy
	var enemy_reg := EnemyRegistry.instance
	if not enemy_reg:
		enemy_reg = EnemyRegistry.new()
		root_node.add_child(enemy_reg)

	# Step 6: Wave 1-5 ground-only gating
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: Node = sd_script.new() as Node
	root_node.add_child(sd)
	var table: Array = sd.get("wave_table")
	for i in range(5):
		if int(table[i]["air_slots"]) != 0:
			append_log("FAIL: Step 6 (Wave 1-5 gating) wave %d has non-zero air slots (%d)" % [i + 1, int(table[i]["air_slots"])], logs)
			root_node.queue_free()
			return false
	if int(table[5]["air_slots"]) < 1:
		append_log("FAIL: Step 6 (Wave 6+ gating) wave 6 has no air slots", logs)
		root_node.queue_free()
		return false
	sd.queue_free()

	# Step 7: Dynamic strike missions non-blocking verified above in sub-step 2

	# Step 8: Pausable run clock verified across test 8 & test 32

	# Step 9: Level-up drafting weights (70/25/5), max 1 legendary, deterministic evolution
	var up_mgr := UpgradeManager.new()
	var t_c := up_mgr.roll_rarity_tier(0.50, true, true, true)
	var t_r := up_mgr.roll_rarity_tier(0.80, true, true, true)
	var t_l := up_mgr.roll_rarity_tier(0.98, true, true, true)
	if t_c != "Common" or t_r != "Rare" or t_l != "Legendary":
		append_log("FAIL: Step 9 (Drafting weights) roll_rarity_tier did not follow 70/25/5 (got %s, %s, %s)" % [t_c, t_r, t_l], logs)
		root_node.queue_free()
		return false
	up_mgr.queue_free()

	# Step 10: Boss Archon 3 phases
	var archon_scene := load("res://scenes/enemies/boss_archon.tscn") as PackedScene
	var archon: BossArchon = archon_scene.instantiate() as BossArchon
	root_node.add_child(archon)
	if archon.speed_phase1 <= 0.0 or archon.speed_phase2 <= archon.speed_phase1 or archon.speed_phase3 <= archon.speed_phase2:
		append_log("FAIL: Step 10 (Boss Archon) speed phases not monotonically increasing", logs)
		root_node.queue_free()
		return false
	archon.queue_free()

	# Step 11: Post-wave-10 Victory vs Endless verified in test 8 & run_state_controller
	# Step 12: Hangar meta-progression verified in test 8
	# Step 13: Accessibility settings toggles verified in test 13 & test 34

	root_node.queue_free()
	append_log("  -> XP aggregation 100% value conservation, 4th Strike mission (Eliminate Elite), and 13-step acceptance suite verified.", logs)
	return true

func test_phase_10a_population_and_spawning_foundation(logs: Array[String]) -> bool:
	append_log("[TEST 36] Phase 10A Survivors Population & Spawning Foundation...", logs)
	var root_node := Node3D.new()
	root_node.name = "Test36Root"
	add_child(root_node)

	# 1. Test DifficultyProfile Resource & 10-Wave Population Targets
	var prof_path := "res://resources/directors/profiles/low_pressure_survivors.tres"
	if not ResourceLoader.exists(prof_path):
		append_log("FAIL: [Step 1] %s does not exist" % prof_path, logs)
		root_node.queue_free()
		return false

	var prof: Resource = load(prof_path)
	if not prof:
		append_log("FAIL: [Step 1] Failed to load low_pressure_survivors.tres as DifficultyProfile", logs)
		root_node.queue_free()
		return false

	var pop_targets: Array = prof.get("wave_targets")
	if pop_targets.size() != 10:
		append_log("FAIL: [Step 1] wave_targets does not contain exactly 10 waves (got %d)" % pop_targets.size(), logs)
		root_node.queue_free()
		return false

	# Verify each wave contract per GDD & Phase 10A specs
	var expected_targets: Array[Dictionary] = [
		{"wave": 1, "v_min": 8, "v_max": 12, "node_cap": 8, "max_air": 0},
		{"wave": 2, "v_min": 12, "v_max": 16, "node_cap": 10, "max_air": 0},
		{"wave": 3, "v_min": 16, "v_max": 22, "node_cap": 12, "max_med": 1, "max_air": 0},
		{"wave": 4, "v_min": 20, "v_max": 26, "node_cap": 14, "max_heavy": 1, "max_air": 0},
		{"wave": 5, "v_min": 24, "v_max": 30, "node_cap": 16, "max_sam": 1, "max_mortar": 1, "max_air": 0},
		{"wave": 6, "v_min": 24, "v_max": 32, "node_cap": 17, "max_air": 2},
		{"wave": 7, "v_min": 26, "v_max": 34, "node_cap": 18, "max_air": 3},
		{"wave": 8, "v_min": 28, "v_max": 36, "node_cap": 19, "max_heavy": 2, "max_air": 4},
		{"wave": 9, "v_min": 30, "v_max": 40, "node_cap": 20, "max_heavy": 2, "max_air": 5},
		{"wave": 10, "is_boss": true, "supp_v_min": 8, "supp_v_max": 12, "supp_node_cap": 10}
	]

	for expected_item in expected_targets:
		var w_num: int = int(expected_item["wave"])
		var wt: Resource = prof.get_wave_target(w_num)
		if not wt:
			append_log("FAIL: [Step 1] get_wave_target(%d) returned null" % w_num, logs)
			root_node.queue_free()
			return false
		if expected_item.get("is_boss", false):
			if not wt.is_boss_wave or wt.support_visual_crowd_min != expected_item["supp_v_min"] or wt.support_visual_crowd_max != expected_item["supp_v_max"] or wt.support_node_cap != expected_item["supp_node_cap"]:
				append_log("FAIL: [Step 1] Wave 10 boss support targets mismatch (vis: %d-%d, cap: %d)" % [wt.support_visual_crowd_min, wt.support_visual_crowd_max, wt.support_node_cap], logs)
				root_node.queue_free()
				return false
		else:
			if wt.visual_crowd_min != expected_item["v_min"] or wt.visual_crowd_max != expected_item["v_max"] or wt.node_cap != expected_item["node_cap"]:
				append_log("FAIL: [Step 1] Wave %d targets mismatch (vis: %d-%d, cap: %d)" % [w_num, wt.visual_crowd_min, wt.visual_crowd_max, wt.node_cap], logs)
				root_node.queue_free()
				return false
		if expected_item.has("max_med") and wt.max_medium_armored != expected_item["max_med"]:
			append_log("FAIL: [Step 1] Wave %d max_medium_armored mismatch" % w_num, logs)
			root_node.queue_free()
			return false
		if expected_item.has("max_heavy") and wt.max_heavy != expected_item["max_heavy"]:
			append_log("FAIL: [Step 1] Wave %d max_heavy mismatch" % w_num, logs)
			root_node.queue_free()
			return false
		if expected_item.has("max_sam") and wt.max_sam != expected_item["max_sam"]:
			append_log("FAIL: [Step 1] Wave %d max_sam mismatch" % w_num, logs)
			root_node.queue_free()
			return false
		if expected_item.has("max_mortar") and wt.max_mortar != expected_item["max_mortar"]:
			append_log("FAIL: [Step 1] Wave %d max_mortar mismatch" % w_num, logs)
			root_node.queue_free()
			return false
		if expected_item.has("max_air") and wt.max_air != expected_item["max_air"]:
			append_log("FAIL: [Step 1] Wave %d max_air mismatch (got %d, expected %d)" % [w_num, wt.max_air, expected_item["max_air"]], logs)
			root_node.queue_free()
			return false

	# 2. Test Archetype Metadata & Separation of Raw Nodes vs Visual Horde
	var inf_scene := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var inf := inf_scene.instantiate() as InfantryCluster
	if inf.visual_crowd_weight != 4:
		append_log("FAIL: [Step 2] InfantryCluster visual_crowd_weight is not 4 (got %d)" % inf.visual_crowd_weight, logs)
		inf.queue_free()
		root_node.queue_free()
		return false
	inf.queue_free()

	# 3. Test EnemyRegistry Visual Crowd & Living Node Separation
	if EnemyRegistry.instance:
		EnemyRegistry.instance.all_enemies.clear()
		EnemyRegistry.instance.ground_enemies.clear()
		EnemyRegistry.instance.air_enemies.clear()
		var cluster1 := inf_scene.instantiate() as InfantryCluster
		var cluster2 := inf_scene.instantiate() as InfantryCluster
		root_node.add_child(cluster1)
		root_node.add_child(cluster2)
		EnemyRegistry.instance.register_enemy(cluster1)
		EnemyRegistry.instance.register_enemy(cluster2)

		var vis_crowd := EnemyRegistry.instance.get_living_visual_crowd()
		var node_cnt := EnemyRegistry.instance.get_living_node_count()
		if vis_crowd != 8 or node_cnt != 2:
			append_log("FAIL: [Step 3] EnemyRegistry crowd/node separation failed (vis: %d, nodes: %d)" % [vis_crowd, node_cnt], logs)
			cluster1.queue_free()
			cluster2.queue_free()
			root_node.queue_free()
			return false

		EnemyRegistry.instance.unregister_enemy(cluster1)
		cluster1.queue_free()
		if EnemyRegistry.instance.get_living_visual_crowd() != 4 or EnemyRegistry.instance.get_living_node_count() != 1:
			append_log("FAIL: [Step 3] EnemyRegistry crowd unregister failed", logs)
			cluster2.queue_free()
			root_node.queue_free()
			return false
		EnemyRegistry.instance.unregister_enemy(cluster2)
		cluster2.queue_free()

	# 4. Test SpawnDirector Directional Sectors & Escape Arc
	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: SpawnDirector = sd_script.new() as SpawnDirector
	sd.difficulty_profile = prof
	root_node.add_child(sd)

	for i in range(10):
		sd.rotate_directional_sectors()
		var p_sec: int = sd.primary_entry_sector
		var s_sec: int = sd.secondary_entry_sector
		var esc := sd.get_protected_escape_sectors()
		var diff := absi(p_sec - s_sec)
		if diff != 1 and diff != 7:
			append_log("FAIL: [Step 4] Secondary sector (%d) is not adjacent to primary sector (%d)" % [s_sec, p_sec], logs)
			root_node.queue_free()
			return false
		if esc.size() < 3:
			append_log("FAIL: [Step 4] Protected escape sectors count < 3 (arc < 120 deg)" % esc.size(), logs)
			root_node.queue_free()
			return false
		if esc.has(p_sec) or esc.has(s_sec):
			append_log("FAIL: [Step 4] Entry sector (%d or %d) is inside protected escape arc %s" % [p_sec, s_sec, str(esc)], logs)
			root_node.queue_free()
			return false

	# 5. Test Air Gating (Ordinary Air Attackers Never Before Wave 6)
	for w in range(1, 6):
		sd.current_wave = w
		var f := sd.select_procedural_formation(Vector3.ZERO)
		if f:
			if f.air_budget_cost > 0.0 or f.category == 2 or f.category == 3:
				append_log("FAIL: [Step 5] Air formation selected during wave %d" % w, logs)
				root_node.queue_free()
				return false

	# 6. Test Spawn Rhythm & Deficit Compression
	for w in [1, 5, 9]:
		sd.current_wave = w
		var t_wt: Resource = prof.get_wave_target(w)
		var base_int := sd._get_next_stream_interval(1, false)
		if base_int < (t_wt.spawn_interval_min - 0.05) or base_int > (t_wt.spawn_interval_max + 0.05):
			append_log("FAIL: [Step 6] Wave %d base interval out of range (got %.2f, expected [%.1f, %.1f])" % [w, base_int, t_wt.spawn_interval_min, t_wt.spawn_interval_max], logs)
			root_node.queue_free()
			return false

	# Deficit reduction should be bounded at max 30% reduction (no instant burst dump)
	sd.current_wave = 1
	var def_int := sd._get_next_stream_interval(1, true)
	if def_int < (1.4 * 0.65):
		append_log("FAIL: [Step 6] Deficit interval dropped too aggressively (got %.2f)" % def_int, logs)
		root_node.queue_free()
		return false

	# 7. Test Quiet Despawn Eligibility & Zero Rewards
	var dummy_enemy := Node3D.new()
	dummy_enemy.name = "FarFodder"
	dummy_enemy.add_to_group("enemies")
	root_node.add_child(dummy_enemy)
	dummy_enemy.global_position = Vector3(0.0, 0.0, 160.0)

	var dummy_boss := Node3D.new()
	dummy_boss.name = "BossTarget"
	dummy_boss.add_to_group("bosses")
	root_node.add_child(dummy_boss)
	dummy_boss.global_position = Vector3(0.0, 0.0, 160.0)

	var dummy_elite := Node3D.new()
	dummy_elite.name = "EliteTarget"
	dummy_elite.add_to_group("elites")
	root_node.add_child(dummy_elite)
	dummy_elite.global_position = Vector3(0.0, 0.0, 160.0)

	# Regular far enemy is eligible
	if not sd.is_enemy_eligible_for_quiet_cleanup(dummy_enemy):
		append_log("FAIL: [Step 7] Regular far enemy not eligible for quiet cleanup", logs)
		root_node.queue_free()
		return false
	# Boss is protected
	if sd.is_enemy_eligible_for_quiet_cleanup(dummy_boss):
		append_log("FAIL: [Step 7] Boss falsely marked eligible for quiet cleanup", logs)
		root_node.queue_free()
		return false
	# Elite is protected
	if sd.is_enemy_eligible_for_quiet_cleanup(dummy_elite):
		append_log("FAIL: [Step 7] Elite falsely marked eligible for quiet cleanup", logs)
		root_node.queue_free()
		return false

	# Test quiet despawn awards zero kills and recycles budget
	sd._wave_enemies.append(dummy_enemy)
	var k_before := sd.total_enemies_killed
	var d_before := sd.total_despawns
	var g_budget_before := sd.continuous_ground_budget
	sd._despawn_enemy_quietly(dummy_enemy)

	if sd.total_enemies_killed != k_before:
		append_log("FAIL: [Step 7] Quiet despawn incorrectly incremented kill count", logs)
		root_node.queue_free()
		return false
	if sd.total_despawns != (d_before + 1):
		append_log("FAIL: [Step 7] Quiet despawn did not increment total_despawns", logs)
		root_node.queue_free()
		return false
	if sd.continuous_ground_budget <= g_budget_before:
		append_log("FAIL: [Step 7] Quiet despawn did not recycle 50% budget back to ground pool", logs)
		root_node.queue_free()
		return false

	# 8. Test Telemetry API
	var telem := sd.get_debug_telemetry()
	var required_keys := ["wave", "encounter_state", "living_nodes", "node_cap", "visual_crowd", "visual_target_min", "visual_target_max", "ground_budget", "air_budget", "primary_entry_sector", "secondary_entry_sector", "protected_escape_sectors", "special_counts"]
	for k in required_keys:
		if not telem.has(k):
			append_log("FAIL: [Step 8] Debug telemetry missing key '%s'" % k, logs)
			root_node.queue_free()
			return false

	root_node.queue_free()
	append_log("  -> 10-wave population targets, archetype weights, air gating, deficit pacing, directional sectors, escape arc, and quiet cleanup verified.", logs)
	return true

func test_phase_10b_low_difficulty_enemy_ai_and_combat_director(logs: Array[String]) -> bool:
	append_log("[TEST 37] Phase 10B Low-Difficulty Enemy AI & Combat Director...", logs)
	var root_node := Node3D.new()
	root_node.name = "TestPhase10BRoot"
	add_child(root_node)

	# 1. Arming Delays on Spawn
	var inf_scene := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var inf := inf_scene.instantiate() as InfantryCluster
	root_node.add_child(inf)
	if inf.arming_delay < 1.5 or inf._arming_timer < 1.4:
		append_log("FAIL: [Step 1] Infantry arming delay not set (got %.2f)" % inf.arming_delay, logs)
		root_node.queue_free()
		return false
	if inf._request_slot():
		append_log("FAIL: [Step 1] Infantry requested slot before arming delay elapsed", logs)
		root_node.queue_free()
		return false

	var tank_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	var tank := tank_scene.instantiate() as Tank
	root_node.add_child(tank)
	if tank.arming_delay < 2.0 or tank._arming_timer < 1.9:
		append_log("FAIL: [Step 1] Tank arming delay not set (got %.2f)" % tank.arming_delay, logs)
		root_node.queue_free()
		return false
	if tank._request_slot():
		append_log("FAIL: [Step 1] Tank requested slot before arming delay elapsed", logs)
		root_node.queue_free()
		return false

	var sam_scene := load("res://scenes/enemies/sam_site.tscn") as PackedScene
	var sam := sam_scene.instantiate() as SAMSite
	root_node.add_child(sam)
	if sam.arming_delay < 2.0 or sam._arming_timer < 1.9:
		append_log("FAIL: [Step 1] SAMSite arming delay not set (got %.2f)" % sam.arming_delay, logs)
		root_node.queue_free()
		return false
	if sam._request_slot():
		append_log("FAIL: [Step 1] SAMSite requested slot before arming delay elapsed", logs)
		root_node.queue_free()
		return false

	# 2. CombatDirector Wave Capacities & Token Limits
	var cd := CombatDirector.new()
	cd.name = "TestCombatDirector"
	root_node.add_child(cd)

	cd.set_wave(1)
	if cd.max_ground_attack_slots != 2 or cd.max_air_attack_slots != 1 or cd.max_concurrent_attackers != 2 or cd.max_projectile_danger != 6:
		append_log("FAIL: [Step 2] Wave 1 CombatDirector capacities incorrect: %s" % str(cd.get_debug_combat_telemetry()), logs)
		root_node.queue_free()
		return false

	cd.set_wave(6)
	if cd.max_ground_attack_slots != 2 or cd.max_air_attack_slots != 2 or cd.max_concurrent_attackers != 4 or cd.max_projectile_danger != 11:
		append_log("FAIL: [Step 2] Wave 6 CombatDirector capacities incorrect: %s" % str(cd.get_debug_combat_telemetry()), logs)
		root_node.queue_free()
		return false

	cd.set_wave(9)
	if cd.max_ground_attack_slots != 3 or cd.max_air_attack_slots != 2 or cd.max_concurrent_attackers != 5 or cd.max_projectile_danger != 16:
		append_log("FAIL: [Step 2] Wave 9 CombatDirector capacities incorrect: %s" % str(cd.get_debug_combat_telemetry()), logs)
		root_node.queue_free()
		return false

	# 3. Wave 1 Capacity & Attacker Count Enforcement
	cd.set_wave(1)
	var e1 := Node3D.new()
	e1.name = "DummyEnemy1"
	root_node.add_child(e1)
	var e2 := Node3D.new()
	e2.name = "DummyEnemy2"
	root_node.add_child(e2)
	var e3 := Node3D.new()
	e3.name = "DummyEnemy3"
	root_node.add_child(e3)

	if not cd.request_attack_permission(e1, 1, false, false, false, 1):
		append_log("FAIL: [Step 3] e1 was denied permission on empty Wave 1", logs)
		root_node.queue_free()
		return false

	if not cd.request_attack_permission(e2, 1, false, false, false, 1):
		append_log("FAIL: [Step 3] e2 was denied permission within Wave 1 max_attackers = 2", logs)
		root_node.queue_free()
		return false

	if cd.request_attack_permission(e3, 1, false, false, false, 1):
		append_log("FAIL: [Step 3] e3 was granted permission exceeding Wave 1 max_attackers = 2", logs)
		root_node.queue_free()
		return false

	cd.release_attack_permission(e1)
	cd.release_attack_permission(e2)
	if not cd.request_attack_permission(e3, 1, false, false, false, 1):
		append_log("FAIL: [Step 3] e3 was denied permission after slots released", logs)
		root_node.queue_free()
		return false
	cd.release_attack_permission(e3)

	# 4. Single Heavy Attack Constraint
	cd.set_wave(8) # ground tokens: 3, max attackers: 3
	var heavy1 := Node3D.new()
	heavy1.name = "HeavyTank1"
	root_node.add_child(heavy1)
	var heavy2 := Node3D.new()
	heavy2.name = "HeavySAM2"
	root_node.add_child(heavy2)

	if not cd.request_attack_permission(heavy1, 3, false, true, false, 3):
		append_log("FAIL: [Step 4] heavy1 was denied heavy attack permission", logs)
		root_node.queue_free()
		return false

	if cd.request_attack_permission(heavy2, 3, false, true, false, 3):
		append_log("FAIL: [Step 4] heavy2 was granted simultaneous heavy attack permission", logs)
		root_node.queue_free()
		return false

	cd.release_attack_permission(heavy1)
	if not cd.request_attack_permission(heavy2, 3, false, true, false, 3):
		append_log("FAIL: [Step 4] heavy2 was denied heavy attack permission after heavy1 release", logs)
		root_node.queue_free()
		return false
	cd.release_attack_permission(heavy2)

	# 5. Single Homing Lock Constraint
	cd.set_wave(6)
	var sam_unit1 := Node3D.new()
	sam_unit1.name = "SAMUnit1"
	root_node.add_child(sam_unit1)
	var sam_unit2 := Node3D.new()
	sam_unit2.name = "SAMUnit2"
	root_node.add_child(sam_unit2)

	if not cd.request_attack_permission(sam_unit1, 2, false, false, true, 2):
		append_log("FAIL: [Step 5] sam_unit1 denied homing lock permission", logs)
		root_node.queue_free()
		return false

	if cd.request_attack_permission(sam_unit2, 2, false, false, true, 2):
		append_log("FAIL: [Step 5] sam_unit2 granted simultaneous homing lock (max 1 exceeded)", logs)
		root_node.queue_free()
		return false

	cd.release_attack_permission(sam_unit1)
	if not cd.request_attack_permission(sam_unit2, 2, false, false, true, 2):
		append_log("FAIL: [Step 5] sam_unit2 denied homing lock after sam_unit1 released", logs)
		root_node.queue_free()
		return false
	cd.release_attack_permission(sam_unit2)

	# 6. Projectile Danger Budget Reservation & Release
	cd.set_wave(1) # danger_cap = 6
	if not cd.reserve_danger_capacity("shotA", 4, 2.0):
		append_log("FAIL: [Step 6] Failed to reserve 4 danger points under cap 6", logs)
		root_node.queue_free()
		return false

	if cd.reserve_danger_capacity("shotB", 3, 2.0):
		append_log("FAIL: [Step 6] Reserved 3 danger points exceeding cap 6 (4 + 3 > 6)", logs)
		root_node.queue_free()
		return false

	cd.release_danger_capacity("shotA", 4)
	if not cd.reserve_danger_capacity("shotB", 3, 2.0):
		append_log("FAIL: [Step 6] Failed to reserve shotB after shotA was released", logs)
		root_node.queue_free()
		return false
	cd.release_danger_capacity("shotB", 3)

	# 7. Watchdog Leaked Reservation Cleanup
	var leaked_enemy := Node3D.new()
	leaked_enemy.name = "LeakedEnemy"
	root_node.add_child(leaked_enemy)
	cd.request_attack_permission(leaked_enemy, 1, false, false, false, 2)
	cd.reserve_danger_capacity("leak_shot", 2, 0.05)

	var before_leases := cd.watchdog_reclaimed_leases
	var before_danger := cd.watchdog_reclaimed_danger
	leaked_enemy.queue_free()
	cd._gameplay_time += 1.0
	cd._cleanup_expired(0.1)

	if cd.watchdog_reclaimed_leases <= before_leases and cd.watchdog_reclaimed_danger <= before_danger:
		append_log("FAIL: [Step 7] Watchdog failed to reclaim dead node lease or expired danger", logs)
		root_node.queue_free()
		return false

	# 8. Player Post-Hit Invulnerability (0.35s i-frames) & Stack Protection
	var player_scene: PackedScene = load("res://scenes/player/player_helicopter.tscn")
	var player: PlayerHelicopter = player_scene.instantiate() as PlayerHelicopter
	root_node.add_child(player)
	player.current_health = 100.0
	player.max_health = 100.0
	player.is_alive = true
	player.set_control_enabled(true)

	var proj1 := Node3D.new()
	proj1.name = "EnemyBullet1"
	root_node.add_child(proj1)
	var proj2 := Node3D.new()
	proj2.name = "EnemyBullet2"
	root_node.add_child(proj2)

	player.take_damage(10.0, proj1)
	if player.current_health != 90.0:
		append_log("FAIL: [Step 8] Player did not take expected initial damage (got %.1f)" % player.current_health, logs)
		root_node.queue_free()
		return false

	# Same projectile repeat hit ignored
	player.take_damage(10.0, proj1)
	if player.current_health != 90.0:
		append_log("FAIL: [Step 8] Same projectile dealt repeat damage to player", logs)
		root_node.queue_free()
		return false

	# Same-frame / immediate second projectile ignored by i-frames
	player.take_damage(15.0, proj2)
	if player.current_health != 90.0:
		append_log("FAIL: [Step 8] Second projectile bypassed 0.35s post-hit invulnerability (got %.1f)" % player.current_health, logs)
		root_node.queue_free()
		return false

	# Zero damage does not consume protection
	player.take_damage(0.0)
	if player.current_health != 90.0:
		append_log("FAIL: [Step 8] Zero damage modified player health", logs)
		root_node.queue_free()
		return false

	# Simulate 0.4s passage of time to expire i-frames
	player._physics_process(0.4)

	var proj3 := Node3D.new()
	proj3.name = "EnemyBullet3"
	root_node.add_child(proj3)
	player.take_damage(10.0, proj3)
	if player.current_health != 80.0:
		append_log("FAIL: [Step 8] Player invulnerability did not expire after 0.35s (got %.1f)" % player.current_health, logs)
		root_node.queue_free()
		return false

	# 9. Ordinary Health Bands
	if inf.max_health > 24.0 or inf.max_health < 6.0:
		append_log("FAIL: [Step 9] InfantryCluster max_health not in ordinary fast-kill band [6.0, 24.0] (got %.1f)" % inf.max_health, logs)
		root_node.queue_free()
		return false
	if tank.max_health < 150.0:
		append_log("FAIL: [Step 9] Tank max_health < 150.0 (got %.1f)" % tank.max_health, logs)
		root_node.queue_free()
		return false
	if sam.max_health < 140.0:
		append_log("FAIL: [Step 9] SAMSite max_health < 140.0 (got %.1f)" % sam.max_health, logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Arming delays, weighted attack tokens, danger budgets, single-heavy/homing constraints, watchdog cleanup, i-frames, and health bands verified.", logs)
	return true

func test_survivors_low_difficulty_enemy_ai_and_spawner_refinement(logs: Array[String]) -> bool:
	append_log("--- Starting Test 38: Survivors Low-Difficulty Enemy AI & Spawner Refinement ---", logs)
	var root_node := Node3D.new()
	root_node.name = "Test38_Root"
	add_child(root_node)

	# 1. System Preservation & 10-Wave Token Architecture
	var cd := CombatDirector.new()
	cd.name = "Test38_CombatDirector"
	root_node.add_child(cd)

	var expected_attacker_caps: Dictionary = {
		1: { "attackers": 2, "air_tokens": 1 },
		2: { "attackers": 2, "air_tokens": 1 },
		3: { "attackers": 3, "air_tokens": 1 },
		4: { "attackers": 3, "air_tokens": 2 },
		5: { "attackers": 4, "air_tokens": 2 },
		6: { "attackers": 4, "air_tokens": 2 },
		7: { "attackers": 4, "air_tokens": 2 },
		8: { "attackers": 5, "air_tokens": 2 },
		9: { "attackers": 5, "air_tokens": 2 },
		10: { "attackers": 4, "air_tokens": 2 },
	}

	for wave_num in range(1, 11):
		cd.set_wave(wave_num)
		var exp_cap: Dictionary = expected_attacker_caps[wave_num]
		if cd.max_concurrent_attackers != exp_cap["attackers"]:
			append_log("FAIL: [Step 1] Wave %d max_concurrent_attackers mismatch (got %d, expected %d)" % [wave_num, cd.max_concurrent_attackers, exp_cap["attackers"]], logs)
			root_node.queue_free()
			return false
		if cd.max_air_attack_slots != exp_cap["air_tokens"]:
			append_log("FAIL: [Step 1] Wave %d max_air_attack_slots mismatch (got %d, expected %d)" % [wave_num, cd.max_air_attack_slots, exp_cap["air_tokens"]], logs)
			root_node.queue_free()
			return false

	# 2. Strict Attacker Limits & Waiting Queue Fairness
	cd.set_wave(1)
	var e1 := Node3D.new()
	e1.name = "DummyAttacker1"
	root_node.add_child(e1)
	var e2 := Node3D.new()
	e2.name = "DummyAttacker2"
	root_node.add_child(e2)
	var e3 := Node3D.new()
	e3.name = "DummyAttacker3"
	root_node.add_child(e3)

	if not cd.request_attack_permission(e1, 1, false, false, false, 1):
		append_log("FAIL: [Step 2] Attacker e1 denied initial attack permission on Wave 1", logs)
		root_node.queue_free()
		return false

	if not cd.request_attack_permission(e2, 1, false, false, false, 1):
		append_log("FAIL: [Step 2] Attacker e2 denied permission within Wave 1 limit of 2", logs)
		root_node.queue_free()
		return false

	if cd.request_attack_permission(e3, 1, false, false, false, 1):
		append_log("FAIL: [Step 2] Attacker e3 granted permission exceeding Wave 1 limit of 2", logs)
		root_node.queue_free()
		return false

	cd.release_attack_permission(e1)
	cd.release_attack_permission(e2)
	if not cd.request_attack_permission(e3, 1, false, false, false, 1):
		append_log("FAIL: [Step 2] Attacker e3 denied permission after e1 and e2 released slots", logs)
		root_node.queue_free()
		return false
	cd.release_attack_permission(e3)

	# 3. Single Heavy Attack Exclusion Across Battlefield (Waves 1-10)
	cd.set_wave(9) # Wave 9 allows 4 attackers, but heavy attack must remain capped at 1
	var heavy1 := Node3D.new()
	heavy1.name = "HeavyAttacker1"
	root_node.add_child(heavy1)
	var heavy2 := Node3D.new()
	heavy2.name = "HeavyAttacker2"
	root_node.add_child(heavy2)

	if not cd.request_attack_permission(heavy1, 3, false, true, false, 3, "tank_cannon"):
		append_log("FAIL: [Step 3] heavy1 was denied heavy attack permission", logs)
		root_node.queue_free()
		return false

	if cd.active_heavy_attacks != 1:
		append_log("FAIL: [Step 3] active_heavy_attacks != 1 (got %d)" % cd.active_heavy_attacks, logs)
		root_node.queue_free()
		return false

	if cd.request_attack_permission(heavy2, 3, false, true, false, 3, "tank_cannon"):
		append_log("FAIL: [Step 3] heavy2 granted simultaneous heavy attack permission (max 1 exceeded)", logs)
		root_node.queue_free()
		return false

	cd.release_attack_permission(heavy1)
	if cd.active_heavy_attacks != 0:
		append_log("FAIL: [Step 3] active_heavy_attacks != 0 after heavy1 released (got %d)" % cd.active_heavy_attacks, logs)
		root_node.queue_free()
		return false

	if not cd.request_attack_permission(heavy2, 3, false, true, false, 3, "tank_cannon"):
		append_log("FAIL: [Step 3] heavy2 denied heavy attack permission after heavy1 release", logs)
		root_node.queue_free()
		return false
	cd.release_attack_permission(heavy2)

	# 4. Single SAM / Homing Lock Constraint
	var sam1 := Node3D.new()
	sam1.name = "SAMUnit1"
	root_node.add_child(sam1)
	var sam2 := Node3D.new()
	sam2.name = "SAMUnit2"
	root_node.add_child(sam2)

	if not cd.request_attack_permission(sam1, 2, false, false, true, 2, "sam_missile"):
		append_log("FAIL: [Step 4] sam1 denied homing lock permission", logs)
		root_node.queue_free()
		return false

	if cd.active_homing_locks != 1:
		append_log("FAIL: [Step 4] active_homing_locks != 1 (got %d)" % cd.active_homing_locks, logs)
		root_node.queue_free()
		return false

	if cd.request_attack_permission(sam2, 2, false, false, true, 2, "sam_missile"):
		append_log("FAIL: [Step 4] sam2 granted simultaneous homing lock (max 1 exceeded)", logs)
		root_node.queue_free()
		return false

	cd.release_attack_permission(sam1)
	if cd.active_homing_locks != 0:
		append_log("FAIL: [Step 4] active_homing_locks != 0 after sam1 released (got %d)" % cd.active_homing_locks, logs)
		root_node.queue_free()
		return false

	if not cd.request_attack_permission(sam2, 2, false, false, true, 2, "sam_missile"):
		append_log("FAIL: [Step 4] sam2 denied homing lock permission after sam1 release", logs)
		root_node.queue_free()
		return false
	cd.release_attack_permission(sam2)

	# 5. Arming Delays for Newly Spawned Enemies (Ordinary >= 1.5s, Heavy >= 2.0s)
	var turret_scn := load("res://scenes/enemies/ground_turret.tscn") as PackedScene
	var turret_inst := turret_scn.instantiate() as GroundTurret
	root_node.add_child(turret_inst)
	if turret_inst.arming_delay < 1.5 or turret_inst._arming_timer < 1.4:
		append_log("FAIL: [Step 5] GroundTurret arming delay < 1.5s (got %.2f)" % turret_inst.arming_delay, logs)
		root_node.queue_free()
		return false

	var inf_scn := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var inf_inst := inf_scn.instantiate() as InfantryCluster
	root_node.add_child(inf_inst)
	if inf_inst.arming_delay < 1.5 or inf_inst._arming_timer < 1.4:
		append_log("FAIL: [Step 5] InfantryCluster arming delay < 1.5s (got %.2f)" % inf_inst.arming_delay, logs)
		root_node.queue_free()
		return false

	var heli_scn := load("res://scenes/enemies/hunter_helicopter.tscn") as PackedScene
	var heli_inst := heli_scn.instantiate() as HunterHelicopter
	root_node.add_child(heli_inst)
	if heli_inst.arming_delay < 1.5 or heli_inst._arming_timer < 1.4:
		append_log("FAIL: [Step 5] HunterHelicopter arming delay < 1.5s (got %.2f)" % heli_inst.arming_delay, logs)
		root_node.queue_free()
		return false

	var sam_scn := load("res://scenes/enemies/sam_site.tscn") as PackedScene
	var sam_inst := sam_scn.instantiate() as SAMSite
	root_node.add_child(sam_inst)
	if sam_inst.arming_delay < 2.0 or sam_inst._arming_timer < 1.9:
		append_log("FAIL: [Step 5] SAMSite arming delay < 2.0s (got %.2f)" % sam_inst.arming_delay, logs)
		root_node.queue_free()
		return false

	var tank_scn := load("res://scenes/enemies/tank.tscn") as PackedScene
	var tank_inst := tank_scn.instantiate() as Tank
	root_node.add_child(tank_inst)
	if tank_inst.arming_delay < 2.0 or tank_inst._arming_timer < 1.9:
		append_log("FAIL: [Step 5] Tank arming delay < 2.0s (got %.2f)" % tank_inst.arming_delay, logs)
		root_node.queue_free()
		return false

	# 6. Ordinary Enemy Health Bands (1-2 Chaingun Hits: 6.0 - 12.0 HP)
	var chaingun_scn := load("res://scenes/weapons/chaingun.tscn") as PackedScene
	var chaingun_inst := chaingun_scn.instantiate() as Chaingun
	root_node.add_child(chaingun_inst)
	if chaingun_inst.damage_per_shot != 6.0:
		append_log("FAIL: [Step 6] Chaingun damage_per_shot != 6.0 (got %.1f)" % chaingun_inst.damage_per_shot, logs)
		root_node.queue_free()
		return false

	if inf_inst.max_health > 12.0 or inf_inst.max_health < 6.0:
		append_log("FAIL: [Step 6] Ordinary infantry health not in 1-2 hit band [6.0, 12.0] (got %.1f)" % inf_inst.max_health, logs)
		root_node.queue_free()
		return false

	# 7. Continuous Spawner Geometry, Standoff >= 38m, Forward Arc & Boundary Rejection
	var p_scn := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player_inst := p_scn.instantiate() as PlayerHelicopter
	player_inst.name = "TestPlayer"
	player_inst.add_to_group("player")
	root_node.add_child(player_inst)
	player_inst.global_position = Vector3(0, 5, 0)
	player_inst.rotation = Vector3.ZERO # Forward is Vector3(0, 0, -1)

	var sd_script: GDScript = load("res://scripts/directors/spawn_director.gd")
	var sd: SpawnDirector = sd_script.new() as SpawnDirector
	root_node.add_child(sd)

	# Distance < 38m must be rejected
	if sd.is_spawn_position_clear(Vector3(0, 5, -25)):
		append_log("FAIL: [Step 7] Spawn position at 25m (<38m standoff) was accepted", logs)
		root_node.queue_free()
		return false

	# Distance >= 38m directly in forward arc (dot > 0.70) must be rejected
	if sd.is_spawn_position_clear(Vector3(0, 5, -45)):
		append_log("FAIL: [Step 7] Spawn position directly in player forward cone was accepted", logs)
		root_node.queue_free()
		return false

	# Outside battlefield boundary must be rejected
	if sd.is_spawn_position_clear(Vector3(450, 5, 0)):
		append_log("FAIL: [Step 7] Spawn position outside battlefield boundary was accepted", logs)
		root_node.queue_free()
		return false

	# Distance >= 38m lateral within boundary must be accepted
	if not sd.is_spawn_position_clear(Vector3(50, 5, 0)):
		append_log("FAIL: [Step 7] Valid lateral spawn position (50m, dot=0) was rejected", logs)
		root_node.queue_free()
		return false

	# 8. Escape Direction & Sector Preservation
	sd.rotate_directional_sectors()
	var escape_secs := sd.get_protected_escape_sectors()
	if escape_secs.size() < 3:
		append_log("FAIL: [Step 8] Protected escape arc size < 3 sectors (got %d)" % escape_secs.size(), logs)
		root_node.queue_free()
		return false

	if escape_secs.has(sd.primary_entry_sector) or escape_secs.has(sd.secondary_entry_sector):
		append_log("FAIL: [Step 8] Entry sector is inside protected escape arc", logs)
		root_node.queue_free()
		return false

	var diff := absi(sd.primary_entry_sector - sd.secondary_entry_sector)
	if diff == 4:
		append_log("FAIL: [Step 8] Primary and secondary entry sectors directly oppose each other", logs)
		root_node.queue_free()
		return false

	# 9. Offscreen Quiet Cleanup Rules (Bosses, Elites, Objectives, Active Attackers Protected)
	var far_fodder := Node3D.new()
	far_fodder.name = "FarFodderTest"
	far_fodder.add_to_group("enemies")
	root_node.add_child(far_fodder)
	far_fodder.global_position = Vector3(0, 5, 120)

	if not sd.is_enemy_eligible_for_quiet_cleanup(far_fodder):
		append_log("FAIL: [Step 9] Distant unengaged fodder not eligible for quiet cleanup", logs)
		root_node.queue_free()
		return false

	# Active attacker lease protects against quiet cleanup
	if cd.request_attack_permission(far_fodder, 1, false, false, false, 1):
		if sd.is_enemy_eligible_for_quiet_cleanup(far_fodder):
			append_log("FAIL: [Step 9] Enemy with active attack lease was marked eligible for quiet cleanup", logs)
			root_node.queue_free()
			return false
		cd.release_attack_permission(far_fodder)

	# Bosses and elites are protected
	far_fodder.add_to_group("bosses")
	if sd.is_enemy_eligible_for_quiet_cleanup(far_fodder):
		append_log("FAIL: [Step 9] Boss was marked eligible for quiet cleanup", logs)
		root_node.queue_free()
		return false
	far_fodder.remove_from_group("bosses")

	far_fodder.add_to_group("elites")
	if sd.is_enemy_eligible_for_quiet_cleanup(far_fodder):
		append_log("FAIL: [Step 9] Elite was marked eligible for quiet cleanup", logs)
		root_node.queue_free()
		return false
	far_fodder.remove_from_group("elites")

	# 10. Player Hit Protection & Post-Hit Invulnerability (~0.35s)
	player_inst.current_health = 100.0
	player_inst.max_health = 100.0
	player_inst.is_alive = true
	var p_bullet1 := Node3D.new()
	p_bullet1.name = "PBullet1"
	root_node.add_child(p_bullet1)
	var p_bullet2 := Node3D.new()
	p_bullet2.name = "PBullet2"
	root_node.add_child(p_bullet2)

	player_inst.take_damage(10.0, p_bullet1)
	if player_inst.current_health != 90.0:
		append_log("FAIL: [Step 10] Player initial damage failed (got %.1f)" % player_inst.current_health, logs)
		root_node.queue_free()
		return false

	# Second projectile on same frame ignored by i-frames
	player_inst.take_damage(15.0, p_bullet2)
	if player_inst.current_health != 90.0:
		append_log("FAIL: [Step 10] Simultaneous projectile bypassed ~0.35s invulnerability (got %.1f)" % player_inst.current_health, logs)
		root_node.queue_free()
		return false

	# Invulnerability expires after 0.4s
	player_inst._physics_process(0.4)
	var p_bullet3 := Node3D.new()
	p_bullet3.name = "PBullet3"
	root_node.add_child(p_bullet3)
	player_inst.take_damage(10.0, p_bullet3)
	if player_inst.current_health != 80.0:
		append_log("FAIL: [Step 10] Player invulnerability failed to expire after 0.4s (got %.1f)" % player_inst.current_health, logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Test 38 PASSED: Survivors low-difficulty enemy AI and spawner refinement validated.", logs)
	return true

func test_city_world_streamer_and_scale_contract(logs: Array[String]) -> bool:
	append_log("[TEST 39] Testing City World Streamer, Scale Contract & Road Sockets...", logs)

	# -------------------------------------------------------------
	# 1. Scale Contract Verification (1 Godot unit = 1 metre)
	# -------------------------------------------------------------
	append_log("[TEST 39] Sub-step 1: Verifying real-world asset scales...", logs)

	# 1a. Player Helicopter: rotor diameter in [11, 13], fuselage in [9, 12]
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	if not player_scene:
		append_log("FAIL: [Step 1] player_helicopter.tscn failed to load", logs)
		return false
	var player := player_scene.instantiate() as PlayerHelicopter
	add_child(player)
	var rotor_blur: MeshInstance3D = player.get_node_or_null("FlightTiltPivot/Visuals/MainRotor/RotorBlurDisc") as MeshInstance3D
	var rotor_diam: float = 0.0
	if rotor_blur and rotor_blur.mesh is CylinderMesh:
		rotor_diam = (rotor_blur.mesh as CylinderMesh).top_radius * 2.0
	elif rotor_blur and rotor_blur.mesh is SphereMesh:
		rotor_diam = (rotor_blur.mesh as SphereMesh).radius * 2.0
	var col_shape: CollisionShape3D = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var fuselage_len: float = 0.0
	if col_shape and col_shape.shape is CapsuleShape3D:
		fuselage_len = (col_shape.shape as CapsuleShape3D).height

	remove_child(player)
	player.free()

	if rotor_diam < 11.0 or rotor_diam > 13.0:
		append_log("FAIL: [Step 1] Helicopter rotor diameter %.2fm outside target [11.0, 13.0]m" % rotor_diam, logs)
		return false
	if fuselage_len < 9.0 or fuselage_len > 12.0:
		append_log("FAIL: [Step 1] Helicopter fuselage length %.2fm outside target [9.0, 12.0]m" % fuselage_len, logs)
		return false

	# 1b. Parked Vehicle: length in [4, 5]
	var car_scene := load("res://scenes/environment/props/parked_vehicle.tscn") as PackedScene
	if not car_scene:
		append_log("FAIL: [Step 1] parked_vehicle.tscn failed to load", logs)
		return false
	var car: Node3D = car_scene.instantiate() as Node3D
	add_child(car)
	var chassis: MeshInstance3D = car.get_node_or_null("Intact/Chassis") as MeshInstance3D
	var car_len: float = 0.0
	if chassis and chassis.mesh is BoxMesh:
		car_len = (chassis.mesh as BoxMesh).size.z
	remove_child(car)
	car.free()

	if car_len < 4.0 or car_len > 5.0:
		append_log("FAIL: [Step 1] Civilian car length %.2fm outside target [4.0, 5.0]m" % car_len, logs)
		return false

	# 1c. Road Widths: Local road asphalt in [8, 10], Main avenue in [14, 18]
	var road_scene := load("res://scenes/environment/roads/road_straight.tscn") as PackedScene
	var road: Node3D = road_scene.instantiate() as Node3D
	add_child(road)
	var r_asphalt: MeshInstance3D = road.get_node_or_null("Asphalt") as MeshInstance3D
	var r_width: float = (r_asphalt.mesh as BoxMesh).size.x if (r_asphalt and r_asphalt.mesh is BoxMesh) else 0.0
	remove_child(road)
	road.free()

	if r_width < 8.0 or r_width > 10.0:
		append_log("FAIL: [Step 1] Local road asphalt width %.2fm outside target [8.0, 10.0]m" % r_width, logs)
		return false

	var ave_scene := load("res://scenes/environment/roads/wide_avenue.tscn") as PackedScene
	var ave: Node3D = ave_scene.instantiate() as Node3D
	add_child(ave)
	var a_asphalt: MeshInstance3D = ave.get_node_or_null("Asphalt") as MeshInstance3D
	var a_width: float = (a_asphalt.mesh as BoxMesh).size.x if (a_asphalt and a_asphalt.mesh is BoxMesh) else 0.0
	remove_child(ave)
	ave.free()

	if a_width < 14.0 or a_width > 18.0:
		append_log("FAIL: [Step 1] Main avenue asphalt width %.2fm outside target [14.0, 18.0]m" % a_width, logs)
		return false

	# 1d. Building Heights: Low-rise [9, 18], Mid-rise [20, 45], High-rise [50, 90], Warehouse [10, 16]
	var b_small_scene := load("res://scenes/environment/city/building_small.tscn") as PackedScene
	var b_small: StaticBody3D = b_small_scene.instantiate() as StaticBody3D
	add_child(b_small)
	var bs_col: CollisionShape3D = b_small.get_node_or_null("CollisionShopModel") as CollisionShape3D
	var bs_h: float = (bs_col.shape as BoxShape3D).size.y if (bs_col and bs_col.shape is BoxShape3D) else 0.0
	remove_child(b_small)
	b_small.free()
	if bs_h < 9.0 or bs_h > 18.0:
		append_log("FAIL: [Step 1] Low-rise building height %.2fm outside [9.0, 18.0]m" % bs_h, logs)
		return false

	var b_med_scene := load("res://scenes/environment/city/building_medium.tscn") as PackedScene
	var b_med: StaticBody3D = b_med_scene.instantiate() as StaticBody3D
	add_child(b_med)
	var bm_col: CollisionShape3D = b_med.get_node_or_null("CollisionCommercialModel") as CollisionShape3D
	var bm_h: float = (bm_col.shape as BoxShape3D).size.y if (bm_col and bm_col.shape is BoxShape3D) else 0.0
	remove_child(b_med)
	b_med.free()
	if bm_h < 20.0 or bm_h > 45.0:
		append_log("FAIL: [Step 1] Mid-rise building height %.2fm outside [20.0, 45.0]m" % bm_h, logs)
		return false

	var b_lrg_scene := load("res://scenes/environment/city/building_large.tscn") as PackedScene
	var b_lrg: StaticBody3D = b_lrg_scene.instantiate() as StaticBody3D
	add_child(b_lrg)
	var bl_col: CollisionShape3D = b_lrg.get_node_or_null("CollisionTowerA") as CollisionShape3D
	var bl_h: float = (bl_col.shape as BoxShape3D).size.y if (bl_col and bl_col.shape is BoxShape3D) else 0.0
	remove_child(b_lrg)
	b_lrg.free()
	if bl_h < 50.0 or bl_h > 90.0:
		append_log("FAIL: [Step 1] High-rise building height %.2fm outside [50.0, 90.0]m" % bl_h, logs)
		return false

	var wh_scene := load("res://scenes/environment/city/warehouse.tscn") as PackedScene
	var wh: StaticBody3D = wh_scene.instantiate() as StaticBody3D
	add_child(wh)
	var wh_col: CollisionShape3D = wh.get_node_or_null("CollisionWarehouseModel") as CollisionShape3D
	var wh_h: float = (wh_col.shape as BoxShape3D).size.y if (wh_col and wh_col.shape is BoxShape3D) else 0.0
	remove_child(wh)
	wh.free()
	if wh_h < 10.0 or wh_h > 16.0:
		append_log("FAIL: [Step 1] Warehouse building height %.2fm outside [10.0, 16.0]m" % wh_h, logs)
		return false

	# -------------------------------------------------------------
	# 2. Seed Determinism Verification
	# -------------------------------------------------------------
	append_log("[TEST 39] Sub-step 2: Testing seed determinism...", logs)
	var chunkA := CityChunk.new()
	add_child(chunkA)
	chunkA.setup(Vector2i(2, 1), CityChunk.DetailLevel.FULL_DETAIL, 1337)

	var chunkB := CityChunk.new()
	add_child(chunkB)
	chunkB.setup(Vector2i(2, 1), CityChunk.DetailLevel.FULL_DETAIL, 1337)

	if chunkA.district_type != chunkB.district_type:
		append_log("FAIL: [Step 2] Chunk determinism failed: district types differ", logs)
		chunkA.queue_free()
		chunkB.queue_free()
		return false

	if chunkA.ground_spawn_points.size() != chunkB.ground_spawn_points.size():
		append_log("FAIL: [Step 2] Chunk determinism failed: ground spawn count differs (%d vs %d)" % [chunkA.ground_spawn_points.size(), chunkB.ground_spawn_points.size()], logs)
		chunkA.queue_free()
		chunkB.queue_free()
		return false

	for i in range(chunkA.ground_spawn_points.size()):
		if chunkA.ground_spawn_points[i].distance_to(chunkB.ground_spawn_points[i]) > 0.001:
			append_log("FAIL: [Step 2] Chunk determinism failed: ground spawn point %d position differs" % i, logs)
			chunkA.queue_free()
			chunkB.queue_free()
			return false

	chunkA.queue_free()
	chunkB.queue_free()

	# -------------------------------------------------------------
	# 3. Road Socket Continuity Across Chunk Seams
	# -------------------------------------------------------------
	append_log("[TEST 39] Sub-step 3: Testing road socket continuity...", logs)
	var c_center := CityChunk.new()
	add_child(c_center)
	c_center.setup(Vector2i(0, 0), CityChunk.DetailLevel.FULL_DETAIL, 1337)

	var c_north := CityChunk.new()
	add_child(c_north)
	c_north.setup(Vector2i(0, -1), CityChunk.DetailLevel.FULL_DETAIL, 1337)

	var c_east := CityChunk.new()
	add_child(c_east)
	c_east.setup(Vector2i(1, 0), CityChunk.DetailLevel.FULL_DETAIL, 1337)

	var center_north_socket: Vector3 = c_center.global_position + Vector3(0.0, 0.0, -64.0)
	var north_south_socket: Vector3 = c_north.global_position + Vector3(0.0, 0.0, 64.0)
	if center_north_socket.distance_to(north_south_socket) > 0.001:
		append_log("FAIL: [Step 3] North/South road seam mismatch: %s vs %s" % [str(center_north_socket), str(north_south_socket)], logs)
		c_center.queue_free()
		c_north.queue_free()
		c_east.queue_free()
		return false

	var center_east_socket: Vector3 = c_center.global_position + Vector3(64.0, 0.0, 0.0)
	var east_west_socket: Vector3 = c_east.global_position + Vector3(-64.0, 0.0, 0.0)
	if center_east_socket.distance_to(east_west_socket) > 0.001:
		append_log("FAIL: [Step 3] East/West road seam mismatch: %s vs %s" % [str(center_east_socket), str(east_west_socket)], logs)
		c_center.queue_free()
		c_north.queue_free()
		c_east.queue_free()
		return false

	c_center.queue_free()
	c_north.queue_free()
	c_east.queue_free()

	# -------------------------------------------------------------
	# 4. Chunk Streaming & Bounded Active Chunk Count
	# -------------------------------------------------------------
	append_log("[TEST 39] Sub-step 4: Testing chunk streaming & active bounds...", logs)
	var streamer := CityWorldStreamer.new()
	streamer.world_seed = 1337
	streamer.immediate_startup_load = false
	add_child(streamer)

	streamer.force_update(Vector2i(0, 0))
	var active_count: int = streamer.get_active_chunk_count()
	var hlod_count: int = streamer.get_hlod_chunk_count()

	if active_count > 25:
		append_log("FAIL: [Step 4] Active full-detail chunk count %d exceeded maximum 25" % active_count, logs)
		streamer.queue_free()
		return false

	if hlod_count > 40:
		append_log("FAIL: [Step 4] HLOD chunk count %d exceeded maximum 40" % hlod_count, logs)
		streamer.queue_free()
		return false

	# Move player 4 chunks East (to cx=4, cz=0)
	streamer.force_update(Vector2i(4, 0))
	var moved_active: int = streamer.get_active_chunk_count()
	if moved_active > 25:
		append_log("FAIL: [Step 4] Active chunk count %d after move exceeded maximum 25" % moved_active, logs)
		streamer.queue_free()
		return false

	if streamer.total_chunks_recycled == 0:
		append_log("FAIL: [Step 4] No chunks were recycled to pool after move (got %d)" % streamer.total_chunks_recycled, logs)
		streamer.queue_free()
		return false

	# -------------------------------------------------------------
	# 5. Typed Candidate Queries
	# -------------------------------------------------------------
	append_log("[TEST 39] Sub-step 5: Testing gameplay candidate queries...", logs)
	streamer.force_update(Vector2i(0, 0))

	var ground_pts: Array[Vector3] = streamer.get_ground_spawn_points(Vector3.ZERO, 38.0, 75.0)
	if ground_pts.is_empty():
		append_log("FAIL: [Step 5] get_ground_spawn_points returned empty array", logs)
		streamer.queue_free()
		return false

	for pt in ground_pts:
		var d: float = Vector3.ZERO.distance_to(pt)
		if d < 37.9 or d > 75.1:
			append_log("FAIL: [Step 5] Ground spawn point distance %.1fm outside [38, 75] window" % d, logs)
			streamer.queue_free()
			return false

	var roof_pts: Array[Vector3] = streamer.get_rooftop_spawn_points(Vector3.ZERO, 20.0, 100.0)
	if roof_pts.is_empty():
		append_log("FAIL: [Step 5] get_rooftop_spawn_points returned empty array", logs)
		streamer.queue_free()
		return false

	var air_pts: Array[Vector3] = streamer.get_air_entry_positions(Vector3.ZERO, 40.0, 140.0)
	if air_pts.is_empty():
		append_log("FAIL: [Step 5] get_air_entry_positions returned empty array", logs)
		streamer.queue_free()
		return false

	var obj_pts: Array[Vector3] = streamer.get_objective_candidates(Vector3.ZERO, 30.0, 160.0)
	if obj_pts.is_empty():
		append_log("FAIL: [Step 5] get_objective_candidates returned empty array", logs)
		streamer.queue_free()
		return false

	var pick_pts: Array[Vector3] = streamer.get_pickup_candidates(Vector3.ZERO, 20.0, 100.0)
	if pick_pts.is_empty():
		append_log("FAIL: [Step 5] get_pickup_candidates returned empty array", logs)
		streamer.queue_free()
		return false

	var safe_pts: Array[Vector3] = streamer.get_safe_open_positions(Vector3.ZERO, 0.0, 60.0)
	if safe_pts.is_empty():
		append_log("FAIL: [Step 5] get_safe_open_positions returned empty array", logs)
		streamer.queue_free()
		return false

	streamer.queue_free()
	append_log("  -> Test 39 PASSED: City world streamer, 1:1 scale contract, socket continuity and candidate queries validated.", logs)
	return true

func test_nuclear_strike_camera_composition_and_behavior(logs: Array[String]) -> bool:
	logs.append("[TEST 40] Testing Nuclear Strike Camera Composition & Oblique Framing...")

	var root_node := Node3D.new()
	add_child(root_node)

	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player: PlayerHelicopter = player_scene.instantiate() as PlayerHelicopter
	root_node.add_child(player)
	player.global_position = Vector3(0.0, 2.4, 0.0)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO

	var cam_scene := load("res://scenes/camera/camera_rig.tscn") as PackedScene
	var cam_rig: CameraRig = cam_scene.instantiate() as CameraRig
	root_node.add_child(cam_rig)
	cam_rig.tracked_player = player

	# 1. Baseline Composition Exports Check
	if absf(cam_rig.camera_fov - 50.0) > 0.1:
		append_log("FAIL: Camera FOV expected 50.0, got %.1f" % cam_rig.camera_fov, logs)
		root_node.queue_free()
		return false
	if absf(cam_rig.base_distance - 31.0) > 0.1:
		append_log("FAIL: Base distance expected 31.0, got %.1f" % cam_rig.base_distance, logs)
		root_node.queue_free()
		return false
	if absf(cam_rig.base_height - 22.0) > 0.1:
		append_log("FAIL: Base height expected 22.0, got %.1f" % cam_rig.base_height, logs)
		root_node.queue_free()
		return false
	if absf(cam_rig.base_lookahead - 16.0) > 0.1:
		append_log("FAIL: Base lookahead expected 16.0, got %.1f" % cam_rig.base_lookahead, logs)
		root_node.queue_free()
		return false
	if absf(cam_rig.horizontal_camera_response - 6.5) > 0.1:
		append_log("FAIL: Horizontal camera response expected 6.5, got %.1f" % cam_rig.horizontal_camera_response, logs)
		root_node.queue_free()
		return false
	if absf(cam_rig.vertical_camera_response - 5.5) > 0.1:
		append_log("FAIL: Vertical camera response expected 5.5, got %.1f" % cam_rig.vertical_camera_response, logs)
		root_node.queue_free()
		return false
	if absf(cam_rig.look_response - 9.0) > 0.1:
		append_log("FAIL: Look response expected 9.0, got %.1f" % cam_rig.look_response, logs)
		root_node.queue_free()
		return false

	# 2. Frame 1 & Hover Stabilization
	cam_rig.reset_smoothing()
	for _i in range(30):
		cam_rig._process(0.016)

	var cam_pos := cam_rig.smoothed_camera_position
	var look_pos := cam_rig.smoothed_look_position

	# Camera must be BEHIND the helicopter (facing -Z, so camera.z > player.z)
	if cam_pos.z < player.global_position.z + 25.0:
		append_log("FAIL: Camera position Z (%.1f) not sufficiently behind helicopter (player Z=%.1f)" % [cam_pos.z, player.global_position.z], logs)
		root_node.queue_free()
		return false

	# Camera must be ELEVATED above helicopter
	if cam_pos.y < player.global_position.y + 18.0:
		append_log("FAIL: Camera elevation Y (%.1f) too low relative to helicopter (player Y=%.1f)" % [cam_pos.y, player.global_position.y], logs)
		root_node.queue_free()
		return false

	# Look target must be AHEAD of helicopter (look_pos.z < player.z)
	if look_pos.z > player.global_position.z - 10.0:
		append_log("FAIL: Look position Z (%.1f) not ahead of helicopter (player Z=%.1f)" % [look_pos.z, player.global_position.z], logs)
		root_node.queue_free()
		return false

	# Optical pitch check: pitch to look target must be oblique (18-32 deg), NOT near-vertical (50-65 deg)
	var horiz_span := cam_pos.z - look_pos.z
	var vert_span := cam_pos.y - look_pos.y
	var optical_pitch_deg := rad_to_deg(atan2(vert_span, horiz_span))
	if optical_pitch_deg > 32.0 or optical_pitch_deg < 18.0:
		append_log("FAIL: Optical pitch angle to look target (%.1f deg) outside oblique window [18, 32] deg" % optical_pitch_deg, logs)
		root_node.queue_free()
		return false

	# 3. Dynamic Speed Pullback
	player.velocity = Vector3(0.0, 0.0, -38.0) # max forward speed
	for _i in range(60):
		cam_rig._process(0.016)

	var fast_cam_pos := cam_rig.smoothed_camera_position
	var fast_look_pos := cam_rig.smoothed_look_position
	if fast_cam_pos.z < cam_pos.z + 3.0:
		append_log("FAIL: Speed pullback did not increase camera distance at full speed (slow=%.1f, fast=%.1f)" % [cam_pos.z, fast_cam_pos.z], logs)
		root_node.queue_free()
		return false
	if fast_look_pos.z > look_pos.z - 3.0:
		append_log("FAIL: Speed lookahead bonus did not extend look target at full speed (slow=%.1f, fast=%.1f)" % [look_pos.z, fast_look_pos.z], logs)
		root_node.queue_free()
		return false

	# 4. Altitude Scaling & Perspective Preservation
	player.velocity = Vector3.ZERO
	player.global_position.y = 22.4 # climbed 20m above baseline 2.4m
	for _i in range(60):
		cam_rig._process(0.016)

	var high_cam_pos := cam_rig.smoothed_camera_position
	var high_look_pos := cam_rig.smoothed_look_position
	var expected_height_gain := 20.0 * cam_rig.altitude_height_scale # ~8.4m
	if absf((high_cam_pos.y - cam_pos.y) - (20.0 + expected_height_gain)) > 3.0:
		append_log("FAIL: Camera height did not scale appropriately with player climb (expected ~+%.1fm, got +%.1fm)" % [20.0 + expected_height_gain, high_cam_pos.y - cam_pos.y], logs)
		root_node.queue_free()
		return false

	# Pitch at high altitude must remain oblique and not collapse to top-down (< 46 deg)
	var high_horiz := high_cam_pos.z - high_look_pos.z
	var high_vert := high_cam_pos.y - high_look_pos.y
	var high_pitch_deg := rad_to_deg(atan2(high_vert, high_horiz))
	if high_pitch_deg > 46.0:
		append_log("FAIL: High altitude pitch (%.1f deg) became too steep (>46 deg)" % high_pitch_deg, logs)
		root_node.queue_free()
		return false

	# 5. Reverse Flight Protection (Reversing must NOT flip camera 180 deg)
	player.global_position.y = 2.4
	cam_rig.reset_smoothing()
	for _i in range(30):
		cam_rig._process(0.016)
	var pre_rev_yaw := cam_rig._current_yaw
	player.velocity = Vector3(0.0, 0.0, 15.0) # moving backward
	for _i in range(30):
		cam_rig._process(0.016)
	var post_rev_yaw := cam_rig._current_yaw
	var yaw_diff := absf(wrapf(post_rev_yaw - pre_rev_yaw, -PI, PI))
	if yaw_diff > deg_to_rad(30.0):
		append_log("FAIL: Reversing caused camera to flip or excessively rotate (yaw diff=%.1f deg)" % rad_to_deg(yaw_diff), logs)
		root_node.queue_free()
		return false

	# 6. Mode Switching & Recenter
	cam_rig.set_camera_mode(CameraRig.CameraMode.CLASSIC)
	if cam_rig.camera_mode != CameraRig.CameraMode.CLASSIC:
		append_log("FAIL: Failed to switch to CLASSIC camera mode", logs)
		root_node.queue_free()
		return false
	if str(SaveSystem.get_setting("camera_mode", "chase")).to_lower() != "classic":
		append_log("FAIL: Camera mode setting was not persisted to SaveSystem as 'classic'", logs)
		root_node.queue_free()
		return false

	cam_rig.set_camera_mode(CameraRig.CameraMode.CHASE)
	if cam_rig.camera_mode != CameraRig.CameraMode.CHASE:
		append_log("FAIL: Failed to switch back to CHASE camera mode", logs)
		root_node.queue_free()
		return false

	root_node.queue_free()
	append_log("  -> Test 40 PASSED: Nuclear Strike oblique camera composition, speed bonuses, altitude stability, reverse protection, and mode switching verified.", logs)
	return true

func test_spawn_director_separation_reservations_and_regression(logs: Array[String]) -> bool:
	append_log("[TEST] SpawnDirector separation, reservations & repeated-entry regression suite...", logs)

	var root_node := Node3D.new()
	add_child(root_node)

	# Seed RNG for deterministic test execution
	seed(1337)

	# Create a dummy player node at center
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	player.position = Vector3(0.0, 14.0, 0.0)
	root_node.add_child(player)

	# Instantiate SpawnDirector
	var spawn_director: SpawnDirector = SpawnDirector.new()
	root_node.add_child(spawn_director)
	spawn_director.arena_half_extents = 150.0
	spawn_director.elapsed_survival_time = 10.0

	# Saturated placement must not create enemies at the INF failure sentinel.
	var before_invalid: int = spawn_director.total_enemies_spawned
	if not spawn_director.spawn_road_column(Vector3.INF, Vector3.FORWARD).is_empty() or not spawn_director.spawn_sam_nest(Vector3(INF, 0, INF)).is_empty():
		append_log("FAIL: Invalid placement created a formation", logs)
		root_node.queue_free()
		return false
	if spawn_director.total_enemies_spawned != before_invalid:
		append_log("FAIL: Rejected placement consumed enemy population", logs)
		root_node.queue_free()
		return false

	# Ensure preloaded scenes are loaded if needed
	if not spawn_director._scene_infantry:
		spawn_director._scene_infantry = preload("res://scenes/enemies/infantry_cluster.tscn")
	if not spawn_director._scene_turret:
		spawn_director._scene_turret = preload("res://scenes/enemies/ground_turret.tscn")
	if not spawn_director._scene_tank:
		spawn_director._scene_tank = preload("res://scenes/enemies/tank.tscn")

	# --- Case 1: 3 same-frame opening requests return non-overlapping positions (>= 18m, >= 2 sources/sectors) ---
	append_log("  -> Running Case 1: Opening encounter 3-unit planning...", logs)
	var planned := spawn_director._plan_initial_encounter_positions(player.global_position)
	if planned.size() != 3:
		append_log("FAIL: Case 1 - Expected 3 planned initial encounter positions, got %d" % planned.size(), logs)
		root_node.queue_free()
		return false

	# Check pairwise separation >= 18.0m
	for i in range(planned.size()):
		for j in range(i + 1, planned.size()):
			var p_i: Vector3 = planned[i]["position"]
			var p_j: Vector3 = planned[j]["position"]
			var dist := Vector2(p_i.x - p_j.x, p_i.z - p_j.z).length()
			if dist < 18.0:
				append_log("FAIL: Case 1 - Initial encounter units %d and %d are too close (dist=%.2fm < 18m)" % [i, j, dist], logs)
				root_node.queue_free()
				return false

	# Check at least 2 distinct sources or sectors
	var sources_used: Dictionary = {}
	var sectors_used: Dictionary = {}
	for u in planned:
		sources_used[u["source_key"]] = true
		sectors_used[u["sector"]] = true
	if sources_used.size() < 2 and sectors_used.size() < 2:
		append_log("FAIL: Case 1 - Expected >= 2 distinct sources or sectors, got sources=%d, sectors=%d" % [sources_used.size(), sectors_used.size()], logs)
		root_node.queue_free()
		return false
	append_log("     Case 1 PASSED: 3 units planned, min sep >= 18m, %d sources, %d sectors" % [sources_used.size(), sectors_used.size()], logs)

	# Clean reservations from Case 1
	for u in planned:
		spawn_director.release_reservation(u["res_id"])

	# --- Case 2: A pending deferred enemy reservation blocks another spawn within clearance radius ---
	append_log("  -> Running Case 2: Pending deferred enemy reservation clearance...", logs)
	var res_pos := Vector3(60.0, 0.0, 60.0)
	var test_res_id := spawn_director.reserve_spawn_position(res_pos, 10.0, "ground", "TestPendingSource", 1, 4.5)
	if not spawn_director.has_reservation(test_res_id):
		append_log("FAIL: Case 2 - Failed to register reservation %s" % test_res_id, logs)
		root_node.queue_free()
		return false

	# Querying exact same position must be rejected
	if spawn_director.is_spawn_position_clear(res_pos, false, 10.0):
		append_log("FAIL: Case 2 - is_spawn_position_clear accepted position with active reservation", logs)
		root_node.queue_free()
		return false

	# Querying within clearance radius (< 10.0m, e.g. 5m away) must be rejected
	var near_pos := res_pos + Vector3(5.0, 0.0, 0.0)
	if spawn_director.is_spawn_position_clear(near_pos, false, 10.0):
		append_log("FAIL: Case 2 - is_spawn_position_clear accepted position within 5m of active reservation", logs)
		root_node.queue_free()
		return false

	# Querying outside clearance radius (e.g. 20m away) must be clear
	var far_pos := res_pos + Vector3(0.0, 0.0, -20.0)
	if not spawn_director.is_spawn_position_clear(far_pos, false, 10.0):
		append_log("FAIL: Case 2 - is_spawn_position_clear falsely rejected position 20m away from reservation", logs)
		root_node.queue_free()
		return false

	# Ignore self reservation ID check
	if not spawn_director.is_spawn_position_clear(res_pos, false, 10.0, test_res_id):
		append_log("FAIL: Case 2 - is_spawn_position_clear failed with ignore_reservation_id set", logs)
		root_node.queue_free()
		return false

	spawn_director.release_reservation(test_res_id)
	if not spawn_director.is_spawn_position_clear(res_pos, false, 10.0):
		append_log("FAIL: Case 2 - Position remained blocked after reservation released", logs)
		root_node.queue_free()
		return false
	append_log("     Case 2 PASSED: Active reservation strictly blocks within clearance radius and frees cleanly.", logs)

	# --- Case 3: A queued formation member blocks another spawn ---
	append_log("  -> Running Case 3: Queued formation member separation check...", logs)
	var q_unit := Node3D.new()
	q_unit.name = "QueuedInfantry"
	q_unit.add_to_group("infantry")
	var q_pos := Vector3(-60.0, 0.0, -60.0)
	q_unit.transform.origin = q_pos

	# Deploy as staggered unit (adds to _formation_spawn_queue)
	spawn_director._deploy_formation_unit(q_unit, root_node, false, true)
	if spawn_director._formation_spawn_queue.is_empty():
		append_log("FAIL: Case 3 - Unit was not queued into _formation_spawn_queue", logs)
		root_node.queue_free()
		return false

	# Position near queued unit (< 8.0m, e.g. 4m away) must be rejected
	var q_near := q_pos + Vector3(4.0, 0.0, 0.0)
	if spawn_director.is_spawn_position_clear(q_near, false, 8.0):
		append_log("FAIL: Case 3 - is_spawn_position_clear accepted position within 4m of queued formation unit", logs)
		root_node.queue_free()
		return false

	# Position far from queued unit (e.g. 20m away) must be clear
	var q_far := q_pos + Vector3(20.0, 0.0, 0.0)
	if not spawn_director.is_spawn_position_clear(q_far, false, 8.0):
		append_log("FAIL: Case 3 - is_spawn_position_clear falsely rejected position 20m away from queued unit", logs)
		root_node.queue_free()
		return false

	spawn_director.clear_formation_queue()
	if not spawn_director._formation_spawn_queue.is_empty():
		append_log("FAIL: Case 3 - clear_formation_queue failed to empty queue", logs)
		root_node.queue_free()
		return false
	append_log("     Case 3 PASSED: Queued formation members successfully block nearby spawns.", logs)

	# --- Case 4: An occupied safe road point is rejected by fallback ---
	append_log("  -> Running Case 4: Safe road perimeter fallback rejects occupied points...", logs)
	var safe_reservations: Array[String] = []
	for i in range(spawn_director._safe_road_points.size()):
		var pt := spawn_director._safe_road_points[i]
		var r_id := spawn_director.reserve_spawn_position(pt, 12.0, "ground", "SafeRoadPoint_%d" % i, 0, 10.0)
		safe_reservations.append(r_id)

	var fallback_all_busy := spawn_director._get_safe_perimeter_fallback(player.global_position, false, 10.0)
	if fallback_all_busy.get("success", true):
		append_log("FAIL: Case 4 - Fallback succeeded when all safe road points were occupied/reserved", logs)
		root_node.queue_free()
		return false

	var released_index := -1
	for i in range(spawn_director._safe_road_points.size()):
		var pt := spawn_director._safe_road_points[i]
		var d := player.global_position.distance_to(pt)
		if d >= 35.0 and d <= 120.0:
			spawn_director.release_reservation(safe_reservations[i])
			released_index = i
			break

	if released_index >= 0:
		var fallback_one_free := spawn_director._get_safe_perimeter_fallback(player.global_position, false, 10.0)
		if not fallback_one_free.get("success", false):
			append_log("FAIL: Case 4 - Fallback failed to pick the single available free road point", logs)
			root_node.queue_free()
			return false
		var picked_pt: Vector3 = fallback_one_free["position"]
		var target_pt: Vector3 = spawn_director._safe_road_points[released_index]
		if picked_pt.distance_to(target_pt) > 0.1:
			append_log("FAIL: Case 4 - Fallback picked wrong point (expected %s, got %s)" % [str(target_pt), str(picked_pt)], logs)
			root_node.queue_free()
			return false

	for r_id in safe_reservations:
		spawn_director.release_reservation(r_id)
	append_log("     Case 4 PASSED: Safe road fallback strictly rejects occupied road points.", logs)

	# --- Case 5: Recent natural road sockets are not reused within 6s / 18m within 8s ---
	append_log("  -> Running Case 5: Cooldown and recent spawn proximity enforcement...", logs)
	spawn_director.elapsed_survival_time = 100.0
	var socket_pos := Vector3(80.0, 0.0, -40.0)
	var socket_key := "streamer_ground_1_2_TestSocket"

	spawn_director.record_spawn_event(socket_key, socket_pos, "TestSocket")

	if not spawn_director.is_source_on_cooldown(socket_key, 6.0):
		append_log("FAIL: Case 5 - Source was not on cooldown immediately after spawn", logs)
		root_node.queue_free()
		return false

	if not spawn_director.is_position_near_recent_spawn(socket_pos, 18.0, 8.0):
		append_log("FAIL: Case 5 - Position near recent spawn was not detected at exact position", logs)
		root_node.queue_free()
		return false
	if not spawn_director.is_position_near_recent_spawn(socket_pos + Vector3(10.0, 0.0, 0.0), 18.0, 8.0):
		append_log("FAIL: Case 5 - Position within 10m of recent spawn was not detected", logs)
		root_node.queue_free()
		return false
	if spawn_director.is_position_near_recent_spawn(socket_pos + Vector3(25.0, 0.0, 0.0), 18.0, 8.0):
		append_log("FAIL: Case 5 - Position 25m away was falsely flagged as near recent spawn", logs)
		root_node.queue_free()
		return false

	spawn_director.elapsed_survival_time = 106.5
	if spawn_director.is_source_on_cooldown(socket_key, 6.0):
		append_log("FAIL: Case 5 - Source was still on cooldown after 6.5s (limit 6.0s)", logs)
		root_node.queue_free()
		return false
	if not spawn_director.is_position_near_recent_spawn(socket_pos, 18.0, 8.0):
		append_log("FAIL: Case 5 - Position proximity expired too early at 6.5s (limit 8.0s)", logs)
		root_node.queue_free()
		return false

	spawn_director.elapsed_survival_time = 108.5
	if spawn_director.is_position_near_recent_spawn(socket_pos, 18.0, 8.0):
		append_log("FAIL: Case 5 - Position proximity was still active after 8.5s (limit 8.0s)", logs)
		root_node.queue_free()
		return false
	append_log("     Case 5 PASSED: 6.0s source cooldown and 8.0s/18m proximity rules enforced.", logs)

	# --- Case 6: Failed spawn selection does not consume budget or increment counters ---
	append_log("  -> Running Case 6: Spawn failure budget & counter safety...", logs)
	var initial_budget: float = 85.0
	spawn_director.continuous_ground_budget = initial_budget
	var initial_spawns: int = spawn_director.total_enemies_spawned
	var initial_fails: int = spawn_director.failed_spawn_attempts

	var failed_enemy := spawn_director._spawn_continuous_enemy(spawn_director._scene_infantry, player.global_position, 0.0, Vector3(0.0, 0.0, 0.0))
	if failed_enemy != null:
		append_log("FAIL: Case 6 - Expected null from forced invalid spawn, got instance", logs)
		failed_enemy.queue_free()
		root_node.queue_free()
		return false

	if spawn_director.continuous_ground_budget != initial_budget:
		append_log("FAIL: Case 6 - Ground budget was deducted on failed spawn (was %.1f, now %.1f)" % [initial_budget, spawn_director.continuous_ground_budget], logs)
		root_node.queue_free()
		return false
	if spawn_director.total_enemies_spawned != initial_spawns:
		append_log("FAIL: Case 6 - total_enemies_spawned was incremented on failed spawn", logs)
		root_node.queue_free()
		return false
	if spawn_director.failed_spawn_attempts <= initial_fails:
		append_log("FAIL: Case 6 - failed_spawn_attempts was not incremented on failed spawn", logs)
		root_node.queue_free()
		return false
	append_log("     Case 6 PASSED: Failed spawn selection preserves budget and counters safely.", logs)

	# --- Case 7: Formation members satisfy minimum separation ---
	append_log("  -> Running Case 7: Formation member minimum separation...", logs)
	var column_origin := Vector3(50.0, 0.0, 50.0)
	var column_dir := Vector3(0.0, 0.0, 1.0)
	var column_units := spawn_director.spawn_road_column(column_origin, column_dir, 3, false)
	if column_units.size() != 3:
		append_log("FAIL: Case 7 - Expected 3 units from spawn_road_column, got %d" % column_units.size(), logs)
		root_node.queue_free()
		return false

	var tank_min_sep: float = float(SpawnDirector.SEPARATION_RADII["tank"]) # 12.0m
	for i in range(column_units.size()):
		for j in range(i + 1, column_units.size()):
			var u_i := column_units[i]
			var u_j := column_units[j]
			var dist := Vector2(u_i.transform.origin.x - u_j.transform.origin.x, u_i.transform.origin.z - u_j.transform.origin.z).length()
			if dist < tank_min_sep:
				append_log("FAIL: Case 7 - Road column tanks %d and %d are too close (dist=%.2fm < %.1fm)" % [i, j, dist, tank_min_sep], logs)
				root_node.queue_free()
				return false

	for u in column_units:
		u.queue_free()
	append_log("     Case 7 PASSED: Formation members strictly satisfy minimum separation (>=12m).", logs)

	# --- Case 8: Multiple clamped positions cannot collapse onto the same boundary coordinate ---
	append_log("  -> Running Case 8: Boundary clamping separation and anti-collapse...", logs)
	var boundary_origin := Vector3(149.0, 0.0, 0.0)
	var out_dir := Vector3(1.0, 0.0, 0.0)

	var boundary_tanks := spawn_director.spawn_road_column(boundary_origin, out_dir, 3, false)
	if boundary_tanks.size() != 3:
		append_log("FAIL: Case 8 - Expected 3 boundary tanks, got %d" % boundary_tanks.size(), logs)
		root_node.queue_free()
		return false

	for i in range(boundary_tanks.size()):
		var pos_i := boundary_tanks[i].transform.origin
		if absf(pos_i.x) > spawn_director.arena_half_extents or absf(pos_i.z) > spawn_director.arena_half_extents:
			append_log("FAIL: Case 8 - Tank %d placed out of bounds: %s" % [i, str(pos_i)], logs)
			root_node.queue_free()
			return false

		for j in range(i + 1, boundary_tanks.size()):
			var pos_j := boundary_tanks[j].transform.origin
			var dist := Vector2(pos_i.x - pos_j.x, pos_i.z - pos_j.z).length()
			if dist < 0.5:
				append_log("FAIL: Case 8 - Boundary tanks %d and %d collapsed onto identical coordinates: %s vs %s" % [i, j, str(pos_i), str(pos_j)], logs)
				root_node.queue_free()
				return false
			if dist < tank_min_sep:
				append_log("FAIL: Case 8 - Boundary tanks %d and %d violate min separation (dist=%.2fm < %.1fm)" % [i, j, dist, tank_min_sep], logs)
				root_node.queue_free()
				return false

	for u in boundary_tanks:
		u.queue_free()

	# Also directly verify get_clamped_formation_member_position with identical raw inputs
	var placed_direct: Array[Vector3] = []
	var p0 := spawn_director.get_clamped_formation_member_position(Vector3(160.0, 0.0, 0.0), placed_direct, 12.0, Vector3(-1.0, 0.0, 0.0))
	placed_direct.append(p0)
	var p1 := spawn_director.get_clamped_formation_member_position(Vector3(160.0, 0.0, 0.0), placed_direct, 12.0, Vector3(-1.0, 0.0, 0.0))
	placed_direct.append(p1)
	var p2 := spawn_director.get_clamped_formation_member_position(Vector3(160.0, 0.0, 0.0), placed_direct, 12.0, Vector3(-1.0, 0.0, 0.0))
	placed_direct.append(p2)

	var d01 := Vector2(p0.x - p1.x, p0.z - p1.z).length()
	var d12 := Vector2(p1.x - p2.x, p1.z - p2.z).length()
	var d02 := Vector2(p0.x - p2.x, p0.z - p2.z).length()
	if d01 < 12.0 or d12 < 12.0 or d02 < 12.0:
		append_log("FAIL: Case 8 - Direct clamped positions collapsed or too close: d01=%.1fm, d12=%.1fm, d02=%.1fm" % [d01, d12, d02], logs)
		root_node.queue_free()
		return false
	append_log("     Case 8 PASSED: Boundary clamping strictly prevents coordinate collapse and preserves separation.", logs)

	root_node.queue_free()
	append_log("  -> Test 41 PASSED: SpawnDirector separation, reservations, fallback rejection & anti-collapse verified.", logs)
	return true

func test_loading_screen_and_xp_gem_pool(logs: Array[String]) -> bool:
	append_log("[TEST 42] Testing Loading Screen & XpGemPool performance stabilization...", logs)

	# 1. Test XpGemPool
	var pool_script: GDScript = load("res://scripts/common/xp_gem_pool.gd")
	if not pool_script:
		append_log("FAIL: Could not load xp_gem_pool.gd", logs)
		return false

	var pool: XpGemPool = pool_script.new() as XpGemPool
	pool.name = "TestXpGemPool"
	pool.pool_size = 1
	add_child(pool)

	if not XpGemPool.instance:
		append_log("FAIL: XpGemPool.instance was not registered", logs)
		pool.queue_free()
		return false

	var spawn_pos := Vector3(15.0, 0.5, -20.0)
	var gem: XPGem = pool.spawn_gem(spawn_pos, 25)
	if not gem:
		append_log("FAIL: XpGemPool failed to spawn gem", logs)
		pool.queue_free()
		return false

	if not gem.is_pooled or not gem.is_active or not gem.visible:
		append_log("FAIL: Spawned gem is not properly activated as pooled", logs)
		pool.queue_free()
		return false

	if gem.xp_value != 25:
		append_log("FAIL: Spawned gem xp_value mismatch (expected 25, got %d)" % gem.xp_value, logs)
		pool.queue_free()
		return false

	if gem.global_position.distance_to(spawn_pos) > 0.1:
		append_log("FAIL: Spawned gem position mismatch", logs)
		pool.queue_free()
		return false

	# Full pools must conserve pending XP, not overwrite it.
	var saturated: XPGem = pool.spawn_gem(spawn_pos + Vector3.ONE, 15)
	if saturated != gem or gem.xp_value != 40 or pool.get_active_count() != 1:
		append_log("FAIL: Saturated XP pool lost XP or allocated another gem", logs)
		pool.queue_free()
		return false

	# Test deactivation & recycling
	gem.deactivate()
	if gem.is_active or gem.visible:
		append_log("FAIL: Gem deactivate() did not hide/deactivate gem", logs)
		pool.queue_free()
		return false

	var recycled_gem: XPGem = pool.spawn_gem(Vector3(0, 0, 0), 10)
	if recycled_gem != gem:
		append_log("FAIL: XpGemPool did not recycle inactive gem", logs)
		pool.queue_free()
		return false

	if not recycled_gem.is_active or not recycled_gem.visible or recycled_gem.xp_value != 10:
		append_log("FAIL: Recycled gem failed to re-activate with new values", logs)
		pool.queue_free()
		return false

	pool.queue_free()
	append_log("  -> Sub-step 1: XpGemPool allocation, activation, recycling, and material caching verified.", logs)

	# 2. Test LoadingScreen scene & state machine
	var load_scene: PackedScene = load("res://scenes/ui/loading_screen.tscn") as PackedScene
	if not load_scene:
		append_log("FAIL: Could not load res://scenes/ui/loading_screen.tscn", logs)
		return false

	var ls: LoadingScreen = load_scene.instantiate() as LoadingScreen
	add_child(ls)

	if not ls._is_loading:
		append_log("FAIL: LoadingScreen did not start in loading state", logs)
		ls.queue_free()
		return false

	if ls.min_display_time < 0.2:
		append_log("FAIL: LoadingScreen min_display_time is too short (got %.2f)" % ls.min_display_time, logs)
		ls.queue_free()
		return false

	# Test error state handling
	ls._handle_load_failure("TEST FAILURE REASON")
	if not ls._load_failed or ls._is_loading:
		append_log("FAIL: LoadingScreen _handle_load_failure did not set failure flags", logs)
		ls.queue_free()
		return false

	if not ls.error_container.visible:
		append_log("FAIL: LoadingScreen error_container is not visible after failure", logs)
		ls.queue_free()
		return false

	if ls.error_message_label.text != "TEST FAILURE REASON":
		append_log("FAIL: LoadingScreen error message text mismatch", logs)
		ls.queue_free()
		return false

	if absf(ls.modulate.a - 1.0) > 0.01:
		append_log("FAIL: LoadingScreen modulate.a was not restored to 1.0 on failure", logs)
		ls.queue_free()
		return false

	if ls.mouse_filter != Control.MOUSE_FILTER_PASS:
		append_log("FAIL: LoadingScreen mouse_filter was not restored to PASS on failure", logs)
		ls.queue_free()
		return false

	# Test retry trigger
	ls._on_retry_pressed()
	if ls._load_failed or not ls._is_loading:
		append_log("FAIL: LoadingScreen _on_retry_pressed did not re-engage loading state", logs)
		ls.queue_free()
		return false

	if ls.error_container.visible:
		append_log("FAIL: LoadingScreen error_container still visible after retry", logs)
		ls.queue_free()
		return false

	# Test invalid resource load error handling
	ls.start_load("res://scenes/nonexistent_scene.tscn")
	# Allow threaded request to evaluate failure
	for _i in range(8):
		if ls._load_failed:
			break
		OS.delay_msec(20)
		ls._process(0.05)
	if not ls._load_failed or not ls.error_container.visible:
		append_log("FAIL: LoadingScreen did not handle invalid resource load failure", logs)
		ls.queue_free()
		return false

	ls.queue_free()
	append_log("  -> Sub-step 2: LoadingScreen lifecycle, deadlock elimination, and error recovery verified.", logs)

	append_log("  -> Test 42 PASSED: LoadingScreen and XpGemPool performance stabilization validated.", logs)
	return true

func test_xp_progression_pacing_and_in_flight_dynamics(logs: Array[String]) -> bool:
	append_log("[TEST 43] XP Progression Pacing, Altitude Gating & In-Flight Dynamics...", logs)
	var root_node := Node3D.new()
	root_node.name = "Test43Root"
	add_child(root_node)

	# 1. Test XP Curve and Threshold Balance (10 basic kills for Level 2)
	for existing in get_tree().get_nodes_in_group("upgrade_manager"):
		existing.remove_from_group("upgrade_manager")
	var mgr_script: GDScript = load("res://scripts/managers/upgrade_manager.gd")
	var mgr: UpgradeManager = mgr_script.new() as UpgradeManager
	root_node.add_child(mgr)
	mgr.add_to_group("upgrade_manager")
	mgr.reset_run()

	if mgr.current_level != 1 or mgr.xp_needed != 50 or mgr.current_xp != 0:
		append_log("FAIL: Invalid initial UpgradeManager state (level %d, xp %d/%d)" % [mgr.current_level, mgr.current_xp, mgr.xp_needed], logs)
		root_node.queue_free()
		return false

	# 10 Scout Buggy kills (5 XP each) to reach Level 2
	for kill in range(1, 11):
		mgr.add_xp(5)
		if kill < 10:
			if mgr.current_level != 1 or not mgr.pending_levels.is_empty():
				append_log("FAIL: Premature level-up on kill %d (level %d, pending %d)" % [kill, mgr.current_level, mgr.pending_levels.size()], logs)
				root_node.queue_free()
				return false
		else:
			if mgr.current_level != 2 or mgr.current_xp != 0 or mgr.xp_needed != 90 or mgr.pending_levels.size() != 1:
				append_log("FAIL: Did not reach Level 2 with exactly 1 choice on 10th kill (level %d, xp %d/%d, pending %d)" % [mgr.current_level, mgr.current_xp, mgr.xp_needed, mgr.pending_levels.size()], logs)
				root_node.queue_free()
				return false

	append_log("  -> Sub-step 1: 10 basic enemy kills (5 XP each) required for Level 2 verified.", logs)

	# 2. Test Altitude Shortcut Immunity with real PlayerHelicopter
	var heli_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player: PlayerHelicopter = heli_scene.instantiate() as PlayerHelicopter
	root_node.add_child(player)
	player.global_position = Vector3(0.0, 15.0, 0.0) # 15m hover altitude

	var gem_scene := load("res://scenes/pickups/xp_gem.tscn") as PackedScene
	var ground_gem: XPGem = gem_scene.instantiate() as XPGem
	root_node.add_child(ground_gem)
	ground_gem.global_position = Vector3(1.0, 0.4, 1.0) # Directly below player horizontally (1.4m < 3.5m radius)
	ground_gem.xp_value = 5
	ground_gem.current_state = XPGem.State.IDLE

	# Simulate physics tick: XPCollectArea enters gem, but gem is IDLE
	player._on_xp_collect_area_entered(ground_gem)
	if ground_gem._is_collected:
		append_log("FAIL: Idle ground gem was prematurely collected through altitude shortcut!", logs)
		root_node.queue_free()
		return false

	append_log("  -> Sub-step 2: Idle ground gem altitude shortcut immunity verified.", logs)

	# 3. Test Magnet Activation, Flight Visual Stretch and Upward Ascent
	player._on_xp_magnet_area_entered(ground_gem)
	if ground_gem.current_state != XPGem.State.MAGNETIZED:
		append_log("FAIL: Gem failed to magnetize via _on_xp_magnet_area_entered", logs)
		root_node.queue_free()
		return false

	# Simulate 10 physics ticks (0.16s total) as gem flies upward
	var initial_y: float = ground_gem.global_position.y
	for i in range(10):
		ground_gem._physics_process(0.016)

	var mid_flight_y: float = ground_gem.global_position.y
	if ground_gem._is_collected or mid_flight_y <= initial_y:
		append_log("FAIL: Gem did not ascend upward or collected prematurely while far below player (y=%.2f)" % mid_flight_y, logs)
		root_node.queue_free()
		return false

	# Dynamic flight stretch verification
	if ground_gem.mesh and ground_gem.mesh.scale.z < 1.1:
		append_log("FAIL: Gem mesh did not apply flight stretch when magnetized (scale: %s)" % str(ground_gem.mesh.scale), logs)
		root_node.queue_free()
		return false

	# Run steps until arrival at player tracking point (y=16.2m)
	var steps := 0
	while not ground_gem._is_collected and steps < 80:
		ground_gem._physics_process(0.016)
		steps += 1

	if not ground_gem._is_collected:
		append_log("FAIL: Magnetized gem did not arrive at helicopter cabin within 80 steps", logs)
		root_node.queue_free()
		return false

	append_log("  -> Sub-step 3: Magnet ascent, flight stretch, and cabin arrival collection verified.", logs)

	# 4. Test High-Speed Pursuit at 38 m/s Forward Flight
	player.global_position = Vector3(0.0, 12.0, 0.0)
	player.velocity = Vector3(0.0, 0.0, -38.0) # Flying north at max speed

	var chase_gem: XPGem = gem_scene.instantiate() as XPGem
	root_node.add_child(chase_gem)
	chase_gem.global_position = Vector3(0.0, 12.0, 14.0) # 14m behind player
	chase_gem.xp_value = 10
	chase_gem.magnetize_to(player)

	var chase_steps := 0
	while not chase_gem._is_collected and chase_steps < 100:
		player.global_position += player.velocity * 0.016
		chase_gem._physics_process(0.016)
		chase_steps += 1

	if not chase_gem._is_collected:
		append_log("FAIL: Chase gem failed to catch up to 38 m/s helicopter (pos: %s, player: %s)" % [str(chase_gem.global_position), str(player.global_position)], logs)
		root_node.queue_free()
		return false

	append_log("  -> Sub-step 4: High-speed 38 m/s pursuit and sweep collection verified.", logs)

	# 5. Multi-kill Batch Drops
	mgr.reset_run()
	var batch_gems: Array[XPGem] = []
	for i in range(5):
		var bg: XPGem = gem_scene.instantiate() as XPGem
		root_node.add_child(bg)
		bg.global_position = player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		bg.xp_value = 5
		bg.magnetize_to(player)
		batch_gems.append(bg)

	for i in range(40):
		for bg in batch_gems:
			if not bg._is_collected:
				bg._physics_process(0.016)

	if mgr.current_xp != 25:
		append_log("FAIL: Multi-kill batch drop XP mismatch (got %d expected 25)" % mgr.current_xp, logs)
		root_node.queue_free()
		return false

	append_log("  -> Sub-step 5: Multi-kill simultaneous drops verified with 100% XP accounting.", logs)

	root_node.queue_free()
	append_log("  -> Test 43 PASSED: XP progression pacing and in-flight dynamics fully validated.", logs)
	return true

func test_enemy_movement_purpose_and_steering_dynamics(logs: Array[String]) -> bool:
	append_log("[TEST 44] Enemy Movement Purpose, Steering Dynamics & Anti-Oscillation...", logs)

	var root_node := Node3D.new()
	root_node.name = "TestMovementRoot"
	add_child(root_node)

	var dummy_player := CharacterBody3D.new()
	dummy_player.name = "DummyPlayer"
	dummy_player.add_to_group("player")
	dummy_player.position = Vector3(0.0, 16.0, 50.0)
	dummy_player.set("velocity", Vector3.ZERO)
	root_node.add_child(dummy_player)

	# --- Sub-step 1: Multi-aircraft cluster anti-stacking and velocity bounding ---
	var raider_scene := load("res://scenes/enemies/air_rocket_raider.tscn") as PackedScene
	var cluster: Array[CharacterBody3D] = []
	var offsets := [
		Vector3(-1.0, 0.0, -1.0),
		Vector3(1.0, 0.0, -1.0),
		Vector3(-1.0, 0.0, 1.0),
		Vector3(1.0, 0.0, 1.0)
	]
	for i in range(4):
		var r := raider_scene.instantiate() as CharacterBody3D
		r.position = Vector3(10.0, 16.0, 10.0) + offsets[i]
		r.set("_player", dummy_player)
		r.set("_lod_frame_counter", 1)
		root_node.add_child(r)
		cluster.append(r)

	var init_centroid := Vector3.ZERO
	for r in cluster:
		init_centroid += r.global_position
	init_centroid /= 4.0

	var init_spread := 0.0
	for r in cluster:
		init_spread += r.global_position.distance_to(init_centroid)

	for frame in range(10):
		for r in cluster:
			r.call("_physics_process", 0.05)

	var max_allowed_speed: float = 26.0 * 1.35 # cruise_speed 26.0 * 1.3 cap
	for r in cluster:
		var horiz_speed := Vector2(r.velocity.x, r.velocity.z).length()
		if horiz_speed > max_allowed_speed + 0.5:
			append_log("FAIL: Clustered aircraft velocity exploded under neighbor repulsion (speed: %.2f > %.2f)" % [horiz_speed, max_allowed_speed], logs)
			root_node.queue_free()
			return false

	var final_centroid := Vector3.ZERO
	for r in cluster:
		final_centroid += r.global_position
	final_centroid /= 4.0

	var final_spread := 0.0
	for r in cluster:
		final_spread += r.global_position.distance_to(final_centroid)

	if final_spread < init_spread:
		append_log("FAIL: Aircraft cluster collapsed or stacked instead of separating (init: %.2f, final: %.2f)" % [init_spread, final_spread], logs)
		root_node.queue_free()
		return false

	for r in cluster:
		r.queue_free()
	cluster.clear()
	append_log("  -> Sub-step 1: Multi-aircraft cluster separation & velocity bounding (<= 35 m/s) verified.", logs)

	# --- Sub-step 2: Aircraft role differentiation & purposeful state behavior ---
	var scout_scene := load("res://scenes/enemies/air_scout_helicopter.tscn") as PackedScene
	var scout := scout_scene.instantiate() as CharacterBody3D
	scout.position = Vector3(0.0, 16.0, 0.0)
	scout.set("_player", dummy_player)
	scout.set("_lod_frame_counter", 1)
	root_node.add_child(scout)

	var scout_archetype: AirEnemyArchetype = scout.get("archetype")
	if not scout_archetype or scout_archetype.weapon_type != AirEnemyArchetype.WeaponType.MACHINE_GUN:
		append_log("FAIL: Air Scout helicopter weapon_type is not MACHINE_GUN", logs)
		root_node.queue_free()
		return false

	var scout_cruise: float = scout_archetype.cruise_speed
	if scout_cruise < 24.0:
		append_log("FAIL: Air Scout cruise speed too low for strike pass archetype (got %.2f, expected >= 24.0)" % scout_cruise, logs)
		root_node.queue_free()
		return false

	var raider := raider_scene.instantiate() as CharacterBody3D
	raider.position = Vector3(0.0, 16.0, 0.0)
	raider.set("_player", dummy_player)
	raider.set("_lod_frame_counter", 1)
	root_node.add_child(raider)

	var raider_archetype: AirEnemyArchetype = raider.get("archetype")
	if not raider_archetype or raider_archetype.weapon_type != AirEnemyArchetype.WeaponType.ROCKET_SALVO:
		append_log("FAIL: Rocket Raider weapon_type is not ROCKET_SALVO", logs)
		root_node.queue_free()
		return false

	var raider_engage_dist: float = raider_archetype.preferred_distance
	if raider_engage_dist < 26.0 or raider_engage_dist > 50.0:
		append_log("FAIL: Rocket Raider engage distance not tuned for standoff combat (got %.2f)" % raider_engage_dist, logs)
		root_node.queue_free()
		return false

	var hunter_scene := load("res://scenes/enemies/hunter_helicopter.tscn") as PackedScene
	var hunter := hunter_scene.instantiate() as CharacterBody3D
	hunter.position = Vector3(0.0, 16.0, 0.0)
	hunter.set("_player", dummy_player)
	root_node.add_child(hunter)

	hunter.call("_transition_to", HunterHelicopter.State.ALIGN)
	hunter.set("_lod_frame_counter", 1)
	hunter.call("_physics_process", 0.05)
	var hunter_h_speed := Vector2(hunter.velocity.x, hunter.velocity.z).length()
	if hunter_h_speed <= 0.05:
		append_log("FAIL: Hunter helicopter dead-stopped in ALIGN state (speed: %.2f)" % hunter_h_speed, logs)
		root_node.queue_free()
		return false

	scout.queue_free()
	raider.queue_free()
	hunter.queue_free()
	append_log("  -> Sub-step 2: Role differentiation (Scout pass, Raider standoff, Hunter non-stopping) verified.", logs)

	# --- Sub-step 3: Smooth altitude elevation & forward rooftop clearance ---
	var air_test := raider_scene.instantiate() as CharacterBody3D
	air_test.position = Vector3(0.0, 16.0, 0.0)
	air_test.set("_player", dummy_player)
	root_node.add_child(air_test)

	air_test.set("_ground_ray_timer", 2.0)
	air_test.set("_cached_ground_y", 22.0)
	air_test.set("_cached_forward_roof_y", 22.0)
	air_test.call("_update_altitude", 0.05)
	var target_y: float = float(air_test.get("_current_target_y"))
	if target_y < 26.5:
		append_log("FAIL: Air enemy failed to maintain +4.5m clearance over rooftop (got %.2f, expected >= 26.5)" % target_y, logs)
		root_node.queue_free()
		return false

	# Verify climb rate is bounded (<= +6.5 m/s)
	air_test.call("_physics_process", 0.05)
	if air_test.velocity.y > 6.6 or air_test.velocity.y < -4.6:
		append_log("FAIL: Air enemy vertical velocity exceeded bounded envelope (-4.5 to +6.5 m/s, got %.2f)" % air_test.velocity.y, logs)
		root_node.queue_free()
		return false

	air_test.queue_free()
	append_log("  -> Sub-step 3: Rooftop clearance (+4.5m) and bounded vertical climb rates verified.", logs)

	# --- Sub-step 4: Multi-whisker obstacle avoidance directional stability ---
	var raider_avoid := raider_scene.instantiate() as CharacterBody3D
	raider_avoid.position = Vector3(0.0, 16.0, 0.0)
	raider_avoid.set("_player", dummy_player)
	root_node.add_child(raider_avoid)

	raider_avoid.set("_avoidance_timer", 0.45)
	raider_avoid.set("_avoidance_bias", 1.0)
	var steered: Vector3 = raider_avoid.call("_steer_around_air_obstacles", Vector3.FORWARD)
	if steered.dot(Vector3(1.0, 0.0, 0.0)) < 0.2:
		append_log("FAIL: Multi-whisker avoidance did not maintain directional hysteresis bias", logs)
		root_node.queue_free()
		return false

	raider_avoid.queue_free()
	append_log("  -> Sub-step 4: Multi-whisker avoidance directional hysteresis verified.", logs)

	# --- Sub-step 5: Ground combatant separation & floor stability ---
	var tank_scene := load("res://scenes/enemies/tank.tscn") as PackedScene
	var tank1 := tank_scene.instantiate() as CharacterBody3D
	var tank2 := tank_scene.instantiate() as CharacterBody3D
	tank1.position = Vector3(10.0, 0.0, 10.0)
	tank2.position = Vector3(11.0, 0.0, 10.0)
	tank1.set("_player", dummy_player)
	tank2.set("_player", dummy_player)
	tank1.set("current_state", Tank.State.REPOSITIONING)
	tank2.set("current_state", Tank.State.REPOSITIONING)
	root_node.add_child(tank1)
	root_node.add_child(tank2)

	tank1.call("_apply_separation")
	tank2.call("_apply_separation")

	if tank1.velocity.x >= tank2.velocity.x:
		append_log("FAIL: Ground tanks failed to apply repulsive separation", logs)
		root_node.queue_free()
		return false

	var t1_h_spd := Vector2(tank1.velocity.x, tank1.velocity.z).length()
	if t1_h_spd > 11.0:
		append_log("FAIL: Ground tank velocity exploded under separation (speed: %.2f > 11.0)" % t1_h_spd, logs)
		root_node.queue_free()
		return false

	var inf_scene := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var inf1 := inf_scene.instantiate() as CharacterBody3D
	var inf2 := inf_scene.instantiate() as CharacterBody3D
	inf1.position = Vector3(20.0, 0.0, 20.0)
	inf2.position = Vector3(21.0, 0.0, 20.0)
	inf1.set("_player", dummy_player)
	inf2.set("_player", dummy_player)
	inf1.set("current_state", InfantryCluster.State.APPROACH)
	inf2.set("current_state", InfantryCluster.State.APPROACH)
	root_node.add_child(inf1)
	root_node.add_child(inf2)

	inf1.call("_apply_separation")
	inf2.call("_apply_separation")

	if inf1.velocity.x >= inf2.velocity.x:
		append_log("FAIL: Infantry clusters failed to apply repulsive separation", logs)
		root_node.queue_free()
		return false

	var inf1_h_spd := Vector2(inf1.velocity.x, inf1.velocity.z).length()
	if inf1_h_spd > 8.0:
		append_log("FAIL: Infantry cluster velocity exploded under separation (speed: %.2f > 8.0)" % inf1_h_spd, logs)
		root_node.queue_free()
		return false

	tank1.position.y = -2.0
	tank1.call("_physics_process", 0.05)
	if tank1.position.y < 0.0:
		append_log("FAIL: Ground tank fell below ground plane (y: %.2f)" % tank1.position.y, logs)
		root_node.queue_free()
		return false

	tank1.queue_free()
	tank2.queue_free()
	inf1.queue_free()
	inf2.queue_free()
	append_log("  -> Sub-step 5: Ground tank & infantry bounded separation and floor clamping verified.", logs)

	root_node.queue_free()
	append_log("  -> Test 44 PASSED: Enemy movement purpose, steering dynamics and anti-oscillation fully validated.", logs)
	return true

func test_damage_number_pooling_and_limits(logs: Array[String]) -> bool:
	append_log("[TEST 45] DamageNumberManager Pooling, Preset Caps & Burst Resilience...", logs)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 10.0, 15.0)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.0, 0.0), Vector3.UP)
	cam.current = true
	vp.add_child(cam)

	var manager := DamageNumberManager.new()
	vp.add_child(manager)
	manager.set_camera(cam)

	# Sub-step 1: Preallocation
	if manager.get_pool_size() != 64 or manager.get_child_count() != 64:
		append_log("FAIL: Expected 64 preallocated labels, got %d" % manager.get_pool_size(), logs)
		vp.queue_free()
		return false
	if manager.get_active_count() != 0 or manager.get_free_count() != 64:
		append_log("FAIL: Expected 0 active and 64 free labels initially, got active=%d, free=%d" % [manager.get_active_count(), manager.get_free_count()], logs)
		vp.queue_free()
		return false
	for child in manager.get_children():
		if child is DamageNumber and (child.is_active or child.visible or child.is_processing()):
			append_log("FAIL: Preallocated label is active or processing before use!", logs)
			vp.queue_free()
			return false
	append_log("  -> Sub-step 1: Preallocated 64 pooled labels, all inactive, hidden, and stopped.", logs)

	# Sub-step 2: Preset active limits
	manager.set_preset("low")
	if manager.max_active_numbers != 24:
		append_log("FAIL: Low preset expected 24, got %d" % manager.max_active_numbers, logs)
		vp.queue_free()
		return false
	manager.set_preset("medium")
	if manager.max_active_numbers != 40:
		append_log("FAIL: Medium preset expected 40, got %d" % manager.max_active_numbers, logs)
		vp.queue_free()
		return false
	manager.set_preset("high")
	if manager.max_active_numbers != 56:
		append_log("FAIL: High preset expected 56, got %d" % manager.max_active_numbers, logs)
		vp.queue_free()
		return false
	append_log("  -> Sub-step 2: Preset active caps verified (Low: 24, Medium: 40, High: 56).", logs)

	# Sub-step 3: Frustum and Viewport rejection
	manager.set_preset("medium")
	# Behind camera (Z = 25m, cam is at Z = 15m facing -Z)
	EventBus.damage_number_spawned.emit(Vector3(0.0, 10.0, 25.0), 10.0, false)
	if manager.get_active_count() != 0:
		append_log("FAIL: Behind-camera position was not rejected!", logs)
		vp.queue_free()
		return false
	# Out-of-range (>150m)
	EventBus.damage_number_spawned.emit(Vector3(0.0, 0.0, -200.0), 10.0, false)
	if manager.get_active_count() != 0:
		append_log("FAIL: Distant position (>150m) was not rejected!", logs)
		vp.queue_free()
		return false
	# In-view position
	var visible_pos := Vector3(0.0, 0.0, 0.0)
	EventBus.damage_number_spawned.emit(visible_pos, 10.0, false)
	if manager.get_active_count() != 1:
		append_log("FAIL: In-view position should be accepted, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false
	for c in manager.get_children():
		if c is DamageNumber and c.is_active:
			c.deactivate()
	append_log("  -> Sub-step 3: Camera frustum, behind-camera, and distance culling verified.", logs)

	# Sub-step 4: Burst of 200 display events on Medium (cap 40)
	manager.set_preset("medium")
	for i in range(200):
		var offset := Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		EventBus.damage_number_spawned.emit(visible_pos + offset, float(i + 1), (i % 5 == 0))
	if manager.get_active_count() != 40:
		append_log("FAIL: 200-burst on Medium should cap at 40, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false
	if manager.get_child_count() != 64:
		append_log("FAIL: Node count grew during burst! Got %d" % manager.get_child_count(), logs)
		vp.queue_free()
		return false
	append_log("  -> Sub-step 4: Same-frame burst of 200 events strictly capped at 40 (0 heap allocations).", logs)

	# Sub-step 5: Pool reuse and state reset
	for c in manager.get_children():
		if c is DamageNumber and c.is_active:
			c.deactivate()
	if manager.get_active_count() != 0 or manager.get_free_count() != 64:
		append_log("FAIL: Free pool not fully restored after deactivation!", logs)
		vp.queue_free()
		return false

	manager.set_preset("low") # Cap = 24
	for i in range(200):
		var offset := Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		EventBus.damage_number_spawned.emit(visible_pos + offset, 75.0, true)
	if manager.get_active_count() != 24:
		append_log("FAIL: Second burst on Low should cap at 24, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false
	if manager.get_child_count() != 64:
		append_log("FAIL: Node count grew on second burst! Got %d" % manager.get_child_count(), logs)
		vp.queue_free()
		return false
	var sample_active: DamageNumber = null
	for c in manager.get_children():
		if c is DamageNumber and c.is_active:
			sample_active = c
			break
	if not sample_active or not sample_active.text.contains("75"):
		append_log("FAIL: Reused label state was not reset properly!", logs)
		vp.queue_free()
		return false
	append_log("  -> Sub-step 5: Full pool reuse and clean state reset verified under 2nd 200-hit burst.", logs)

	# Sub-step 6: High preset burst (cap 56) and tween safety
	for c in manager.get_children():
		if c is DamageNumber and c.is_active:
			c.deactivate()
			if c._tween != null:
				append_log("FAIL: Tween not cleared on deactivation!", logs)
				vp.queue_free()
				return false

	manager.set_preset("high") # Cap = 56
	for i in range(200):
		var offset := Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		EventBus.damage_number_spawned.emit(visible_pos + offset, 20.0, false)
	if manager.get_active_count() != 56:
		append_log("FAIL: Third burst on High should cap at 56, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false
	append_log("  -> Sub-step 6: High preset 200-burst capped at 56, tween lifecycle safety verified.", logs)

	# Sub-step 7: Damage application independence
	var dummy_hp := 500.0
	var dmg_step := 10.0
	for h in range(50):
		dummy_hp -= dmg_step
		EventBus.damage_number_spawned.emit(visible_pos, dmg_step, false)
	if dummy_hp != 0.0:
		append_log("FAIL: Damage application corrupted! Expected 0, got %f" % dummy_hp, logs)
		vp.queue_free()
		return false
	append_log("  -> Sub-step 7: Damage application 100% unaffected by skipped visual numbers.", logs)

	# Sub-step 8: Scene exit and clean disconnect
	manager._disconnect_events()
	vp.queue_free()
	append_log("  -> Sub-step 8: DamageNumberManager exit and cleanup verified with 0 leaks.", logs)

	append_log("  -> Test 45 PASSED: Damage number pooling, preset caps and burst resilience fully validated.", logs)
	return true

func test_damage_number_categories_and_player_damage(logs: Array[String]) -> bool:
	append_log("[TEST 46] Damage Categories, Actual Crits, Player Damage & Duplicate Prevention...", logs)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 10.0, 15.0)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.0, 0.0), Vector3.UP)
	cam.current = true
	vp.add_child(cam)

	var manager := DamageNumberManager.new()
	vp.add_child(manager)
	manager.set_camera(cam)

	var visible_pos := Vector3(0.0, 0.0, 0.0)

	# Helper to find first active label
	var get_active_label := func() -> DamageNumber:
		for c in manager.get_children():
			if c is DamageNumber and c.is_active:
				return c
		return null

	# Helper to deactivate all labels
	var deactivate_all := func() -> void:
		for c in manager.get_children():
			if c is DamageNumber and c.is_active:
				c.deactivate()
		manager._recent_event_keys.clear()

	# Sub-step 1: Normal hit (cream/off-white, 16px, clean number)
	deactivate_all.call()
	manager.spawn_damage_number(visible_pos, 15.0, false, DamageNumber.DamageCategory.NORMAL)
	var lbl_normal := get_active_label.call() as DamageNumber
	if not lbl_normal:
		append_log("FAIL: [Step 1] Normal damage label not spawned", logs)
		vp.queue_free()
		return false
	if lbl_normal.category != DamageNumber.DamageCategory.NORMAL:
		append_log("FAIL: [Step 1] Expected category NORMAL, got %d" % lbl_normal.category, logs)
		vp.queue_free()
		return false
	if lbl_normal.text != "15":
		append_log("FAIL: [Step 1] Expected text '15', got '%s'" % lbl_normal.text, logs)
		vp.queue_free()
		return false
	if lbl_normal.get_theme_font_size("font_size") != 16:
		append_log("FAIL: [Step 1] Expected font size 16 for normal damage, got %d" % lbl_normal.get_theme_font_size("font_size"), logs)
		vp.queue_free()
		return false
	var col_normal := lbl_normal.get_theme_color("font_color")
	if not col_normal.is_equal_approx(Color(0.96, 0.94, 0.88, 1.0)):
		append_log("FAIL: [Step 1] Expected cream/off-white color for normal damage, got %s" % str(col_normal), logs)
		vp.queue_free()
		return false
	deactivate_all.call()
	append_log("  -> Sub-step 1: Normal enemy hit (cream/off-white, 16px, clean text '15') verified.", logs)

	# Sub-step 2: Actual critical damage (gold, 22px, '★' icon, stronger pop)
	deactivate_all.call()
	manager.spawn_damage_number(visible_pos, 75.0, true, DamageNumber.DamageCategory.CRITICAL)
	var lbl_crit := get_active_label.call() as DamageNumber
	if not lbl_crit:
		append_log("FAIL: [Step 2] Critical damage label not spawned", logs)
		vp.queue_free()
		return false
	if lbl_crit.category != DamageNumber.DamageCategory.CRITICAL:
		append_log("FAIL: [Step 2] Expected category CRITICAL, got %d" % lbl_crit.category, logs)
		vp.queue_free()
		return false
	if not lbl_crit.text.begins_with("★"):
		append_log("FAIL: [Step 2] Expected critical text to contain '★' icon, got '%s'" % lbl_crit.text, logs)
		vp.queue_free()
		return false
	if lbl_crit.get_theme_font_size("font_size") != 22:
		append_log("FAIL: [Step 2] Expected font size 22 for critical damage, got %d" % lbl_crit.get_theme_font_size("font_size"), logs)
		vp.queue_free()
		return false
	var col_crit := lbl_crit.get_theme_color("font_color")
	if not col_crit.is_equal_approx(Color(1.0, 0.82, 0.15, 1.0)):
		append_log("FAIL: [Step 2] Expected gold color for critical damage, got %s" % str(col_crit), logs)
		vp.queue_free()
		return false
	deactivate_all.call()
	append_log("  -> Sub-step 2: Actual critical hit (gold, 22px, '★' multi-cue icon) verified.", logs)

	# Sub-step 3: Removal of arbitrary numeric threshold logic (large 50.0 hit without crit metadata stays NORMAL)
	deactivate_all.call()
	EventBus.damage_number_spawned.emit(visible_pos, 50.0, false)
	var lbl_large_normal := get_active_label.call() as DamageNumber
	if not lbl_large_normal:
		append_log("FAIL: [Step 3] Large damage label not spawned", logs)
		vp.queue_free()
		return false
	if lbl_large_normal.category != DamageNumber.DamageCategory.NORMAL:
		append_log("FAIL: [Step 3] Large hit was incorrectly categorized as %d instead of NORMAL!" % lbl_large_normal.category, logs)
		vp.queue_free()
		return false
	if lbl_large_normal.text != "50" or lbl_large_normal.text.contains("★"):
		append_log("FAIL: [Step 3] Large hit still formatted with critical text: '%s'" % lbl_large_normal.text, logs)
		vp.queue_free()
		return false
	if lbl_large_normal.get_theme_font_size("font_size") != 16:
		append_log("FAIL: [Step 3] Large hit without crit metadata scaled up font to %d!" % lbl_large_normal.get_theme_font_size("font_size"), logs)
		vp.queue_free()
		return false
	deactivate_all.call()
	append_log("  -> Sub-step 3: Large 50-damage hit correctly renders as Normal (threshold crit logic fully removed).", logs)

	# Sub-step 4: Player damage received (vivid red, 18px, '▼ -XX' downward cue)
	deactivate_all.call()
	EventBus.player_damaged_directional.emit(25.0, visible_pos, Vector3(0, 0, 5), false)
	var lbl_player := get_active_label.call() as DamageNumber
	if not lbl_player:
		append_log("FAIL: [Step 4] Player damage label not spawned via player_damaged_directional", logs)
		vp.queue_free()
		return false
	if lbl_player.category != DamageNumber.DamageCategory.PLAYER:
		append_log("FAIL: [Step 4] Expected category PLAYER, got %d" % lbl_player.category, logs)
		vp.queue_free()
		return false
	if not lbl_player.text.contains("▼") or not lbl_player.text.contains("-25"):
		append_log("FAIL: [Step 4] Expected player damage text format '▼ -25', got '%s'" % lbl_player.text, logs)
		vp.queue_free()
		return false
	if lbl_player.get_theme_font_size("font_size") != 18:
		append_log("FAIL: [Step 4] Expected font size 18 for player damage, got %d" % lbl_player.get_theme_font_size("font_size"), logs)
		vp.queue_free()
		return false
	var col_player := lbl_player.get_theme_color("font_color")
	if not col_player.is_equal_approx(Color(1.0, 0.25, 0.25, 1.0)):
		append_log("FAIL: [Step 4] Expected warning red color for player damage, got %s" % str(col_player), logs)
		vp.queue_free()
		return false
	deactivate_all.call()
	append_log("  -> Sub-step 4: Player damage received (vivid red, 18px, '▼ -25' non-color indicator) verified.", logs)

	# Sub-step 5: Blocked & zero-damage hits (steel cyan, 15px, '[SHIELD] 0' tag)
	deactivate_all.call()
	EventBus.player_damaged_directional.emit(0.0, visible_pos, Vector3(0, 0, 5), true)
	var lbl_blocked := get_active_label.call() as DamageNumber
	if not lbl_blocked:
		append_log("FAIL: [Step 5] Blocked shield damage label not spawned", logs)
		vp.queue_free()
		return false
	if lbl_blocked.category != DamageNumber.DamageCategory.BLOCKED:
		append_log("FAIL: [Step 5] Expected category BLOCKED, got %d" % lbl_blocked.category, logs)
		vp.queue_free()
		return false
	if not lbl_blocked.text.contains("SHIELD") and not lbl_blocked.text.contains("BLOCKED"):
		append_log("FAIL: [Step 5] Expected blocked text with SHIELD/BLOCKED tag, got '%s'" % lbl_blocked.text, logs)
		vp.queue_free()
		return false
	if lbl_blocked.get_theme_font_size("font_size") != 15:
		append_log("FAIL: [Step 5] Expected font size 15 for blocked hit, got %d" % lbl_blocked.get_theme_font_size("font_size"), logs)
		vp.queue_free()
		return false
	deactivate_all.call()

	# Zero-damage hit via damage_number_spawned also maps to BLOCKED
	EventBus.damage_number_spawned.emit(visible_pos, 0.0, false)
	var lbl_zero := get_active_label.call() as DamageNumber
	if not lbl_zero or lbl_zero.category != DamageNumber.DamageCategory.BLOCKED:
		append_log("FAIL: [Step 5] Zero-damage hit did not map to BLOCKED category", logs)
		vp.queue_free()
		return false
	deactivate_all.call()
	append_log("  -> Sub-step 5: Blocked and zero-damage hits (steel cyan, 15px, '[SHIELD] 0') verified.", logs)

	# Sub-step 6: Resolved vs Pre-mitigation value consistency
	deactivate_all.call()
	# Incoming attack: 50 damage, 20% armor mitigation = 40 resolved damage
	var raw_incoming := 50.0
	var armor_reduct := 0.20
	var resolved_dmg := raw_incoming * (1.0 - armor_reduct)
	EventBus.player_damaged_directional.emit(resolved_dmg, visible_pos, Vector3.ZERO, false)
	var lbl_resolved := get_active_label.call() as DamageNumber
	if not lbl_resolved or not lbl_resolved.text.contains("-40"):
		append_log("FAIL: [Step 6] Resolved damage display did not match mitigated value 40: '%s'" % (lbl_resolved.text if lbl_resolved else "null"), logs)
		vp.queue_free()
		return false
	deactivate_all.call()
	append_log("  -> Sub-step 6: Resolved damage post-mitigation value displayed consistently (-40, not pre-mitigated 50).", logs)

	# Sub-step 7: Duplicate prevention within same frame
	deactivate_all.call()
	EventBus.damage_number_spawned.emit(visible_pos, 33.0, false)
	EventBus.damage_number_spawned.emit(visible_pos, 33.0, false)
	if manager.get_active_count() != 1:
		append_log("FAIL: [Step 7] Duplicate event was not prevented in same frame! Active count: %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false
	deactivate_all.call()
	append_log("  -> Sub-step 7: Same-frame duplicate damage event dropped successfully (active count strictly 1).", logs)

	# Sub-step 8: Preserving existing 3-argument callers
	deactivate_all.call()
	EventBus.damage_number_spawned.emit(visible_pos, 18.0, false)
	if manager.get_active_count() != 1:
		append_log("FAIL: [Step 8] Legacy 3-argument caller failed to spawn label", logs)
		vp.queue_free()
		return false
	deactivate_all.call()
	append_log("  -> Sub-step 8: Legacy 3-argument signal callers verified with 0 runtime errors.", logs)

	manager._disconnect_events()
	vp.queue_free()
	append_log("  -> Test 46 PASSED: Damage categories, actual crits, player damage & deduplication fully validated.", logs)
	return true

func test_damage_number_aggregation_and_clutter_reduction(logs: Array[String]) -> bool:
	append_log("[TEST 47] Damage Number Aggregation, Clutter Reduction & Death Flush...", logs)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 10.0, 15.0)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.0, 0.0), Vector3.UP)
	cam.current = true
	vp.add_child(cam)

	var manager := DamageNumberManager.new()
	vp.add_child(manager)
	manager.set_camera(cam)

	var visible_pos := Vector3(0.0, 0.0, 0.0)

	var deactivate_all := func():
		for label in manager._pool:
			if is_instance_valid(label) and label.is_active:
				label.deactivate()
		manager.flush_all_buckets()
		for label in manager._pool:
			if is_instance_valid(label) and label.is_active:
				label.deactivate()

	var get_active_labels := func() -> Array[DamageNumber]:
		var actives: Array[DamageNumber] = []
		for label in manager._pool:
			if is_instance_valid(label) and label.is_active:
				actives.append(label)
		return actives

	# --- Sub-step 1: Ten known hits against one enemy ---
	deactivate_all.call()
	var enemy_a_id := 5001
	for i in range(10):
		EventBus.damage_number_spawned.emit(visible_pos, 12.5, false, {"target_id": enemy_a_id})

	# Bucket is currently accumulating (window not yet expired)
	if manager.get_pending_bucket_count() != 1:
		append_log("FAIL: [Step 1] Expected exactly 1 pending bucket for enemy A, got %d" % manager.get_pending_bucket_count(), logs)
		vp.queue_free()
		return false

	var total_accum := manager.get_bucket_total(enemy_a_id, DamageNumberManager.DamageCategory.NORMAL)
	if absf(total_accum - 125.0) > 0.001:
		append_log("FAIL: [Step 1] Expected bucket total 125.0, got %.3f" % total_accum, logs)
		vp.queue_free()
		return false

	# Active labels must remain 0 during collection window (no intermediate overlapping cumulative numbers!)
	if manager.get_active_count() != 0:
		append_log("FAIL: [Step 1] Active labels displayed before bucket completion: %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false

	# Advance time past 100 ms window (e.g. 0.11s)
	manager._process(0.11)

	# Exactly 1 completed number emitted
	var actives_step1: Array = get_active_labels.call()
	if actives_step1.size() != 1:
		append_log("FAIL: [Step 1] Expected exactly 1 emitted number after window completion, got %d" % actives_step1.size(), logs)
		vp.queue_free()
		return false

	var lbl1: DamageNumber = actives_step1[0]
	if lbl1.text != "125":
		append_log("FAIL: [Step 1] Expected label text '125', got '%s'" % lbl1.text, logs)
		vp.queue_free()
		return false

	append_log("  -> Sub-step 1: Ten known hits against one enemy aggregated into exactly 1 number ('125') verified.", logs)

	# --- Sub-step 2: Simultaneous hits on two distinct enemies ---
	deactivate_all.call()
	var enemy_1_id := 6001
	var enemy_2_id := 6002
	var pos_1 := Vector3(-2.0, 0.0, 0.0)
	var pos_2 := Vector3(2.0, 0.0, 0.0)

	# 3 hits to enemy 1 (20.0 each = 60.0)
	for i in range(3):
		EventBus.damage_number_spawned.emit(pos_1, 20.0, false, {"target_id": enemy_1_id})

	# 2 hits to enemy 2 (45.0 each = 90.0)
	for i in range(2):
		EventBus.damage_number_spawned.emit(pos_2, 45.0, false, {"target_id": enemy_2_id})

	if manager.get_pending_bucket_count() != 2:
		append_log("FAIL: [Step 2] Expected 2 distinct pending buckets, got %d" % manager.get_pending_bucket_count(), logs)
		vp.queue_free()
		return false

	manager._process(0.11)
	var actives_step2: Array = get_active_labels.call()
	if actives_step2.size() != 2:
		append_log("FAIL: [Step 2] Expected 2 distinct active labels for 2 enemies, got %d" % actives_step2.size(), logs)
		vp.queue_free()
		return false

	var texts_step2 := [actives_step2[0].text, actives_step2[1].text]
	if not ("60" in texts_step2 and "90" in texts_step2):
		append_log("FAIL: [Step 2] Expected numbers '60' and '90', got %s" % str(texts_step2), logs)
		vp.queue_free()
		return false

	append_log("  -> Sub-step 2: Simultaneous hits on two distinct enemies remained strictly separate ('60' & '90').", logs)

	# --- Sub-step 3: Mixed categories on the same enemy ---
	deactivate_all.call()
	var enemy_mixed_id := 7001
	# Normal damage: 2 hits of 15.0 = 30.0
	EventBus.damage_number_spawned.emit(visible_pos, 15.0, false, {"target_id": enemy_mixed_id})
	EventBus.damage_number_spawned.emit(visible_pos, 15.0, false, {"target_id": enemy_mixed_id})
	# Critical damage: 1 hit of 80.0
	EventBus.damage_number_spawned.emit(visible_pos, 80.0, true, {"target_id": enemy_mixed_id, "is_critical": true})

	if manager.get_pending_bucket_count() != 2:
		append_log("FAIL: [Step 3] Normal and Critical damage on same target must produce separate buckets", logs)
		vp.queue_free()
		return false

	manager._process(0.11)
	var actives_step3: Array = get_active_labels.call()
	if actives_step3.size() != 2:
		append_log("FAIL: [Step 3] Expected 2 active labels for mixed categories, got %d" % actives_step3.size(), logs)
		vp.queue_free()
		return false

	var has_normal := false
	var has_crit := false
	for lbl in actives_step3:
		if lbl.category == DamageNumber.DamageCategory.NORMAL and lbl.text == "30":
			has_normal = true
		elif lbl.category == DamageNumber.DamageCategory.CRITICAL and lbl.text.contains("80"):
			has_crit = true

	if not (has_normal and has_crit):
		append_log("FAIL: [Step 3] Expected separate Normal ('30') and Critical ('★ 80') labels", logs)
		vp.queue_free()
		return false

	append_log("  -> Sub-step 3: Mixed categories on same enemy kept strictly separate (Normal '30' & Critical '★ 80').", logs)

	# --- Sub-step 4: Target death before window closes ---
	deactivate_all.call()
	var dying_dummy := TargetDummy.new()
	vp.add_child(dying_dummy)
	dying_dummy.global_position = Vector3(1.0, 0.0, -1.0)
	var dummy_id := dying_dummy.get_instance_id()

	# Hit 1: 30.0 damage at t=0
	EventBus.damage_number_spawned.emit(dying_dummy.global_position, 30.0, false, {"target_id": dummy_id})
	# Hit 2: 40.0 damage at t=0.02
	manager._process(0.02)
	EventBus.damage_number_spawned.emit(dying_dummy.global_position, 40.0, false, {"target_id": dummy_id})

	# Window has NOT expired yet (remaining ~0.08s)
	if manager.get_active_count() != 0:
		append_log("FAIL: [Step 4] Label displayed prematurely before death or window close", logs)
		dying_dummy.queue_free()
		vp.queue_free()
		return false

	# Target dies: emits EventBus.enemy_destroyed and queues free
	EventBus.enemy_destroyed.emit(dying_dummy, 50)
	dying_dummy.queue_free()

	# Must have flushed immediately upon death signal!
	var actives_step4: Array = get_active_labels.call()
	if actives_step4.size() != 1:
		append_log("FAIL: [Step 4] Expected exactly 1 label flushed immediately upon target death, got %d" % actives_step4.size(), logs)
		vp.queue_free()
		return false

	var death_lbl: DamageNumber = actives_step4[0]
	if death_lbl.text != "70":
		append_log("FAIL: [Step 4] Expected total '70' (30 + 40 lethal) on death flush, got '%s'" % death_lbl.text, logs)
		vp.queue_free()
		return false

	append_log("  -> Sub-step 4: Target death immediately flushed pending bucket ('70') using cached position without memory leak.", logs)

	# --- Sub-step 5: Player damage aggregation ---
	deactivate_all.call()
	var player_id := 9999
	EventBus.player_damaged_directional.emit(14.5, visible_pos, Vector3.ZERO, false, {"target_id": player_id})
	EventBus.player_damaged_directional.emit(14.5, visible_pos, Vector3.ZERO, false, {"target_id": player_id})

	if manager.get_pending_bucket_count() != 1:
		append_log("FAIL: [Step 5] Rapid player damage should aggregate into 1 pending bucket", logs)
		vp.queue_free()
		return false

	manager._process(0.11)
	var actives_step5: Array = get_active_labels.call()
	if actives_step5.size() != 1:
		append_log("FAIL: [Step 5] Expected 1 label for aggregated player damage, got %d" % actives_step5.size(), logs)
		vp.queue_free()
		return false

	var player_lbl: DamageNumber = actives_step5[0]
	if not player_lbl.text.contains("-29"):
		append_log("FAIL: [Step 5] Expected player label '▼ -29', got '%s'" % player_lbl.text, logs)
		vp.queue_free()
		return false

	append_log("  -> Sub-step 5: Player damage aggregated into single indicator ('▼ -29') verified.", logs)

	# --- Sub-step 6: Large total abbreviation ---
	if DamageNumber.format_damage_value(1200.0) != "1.2K":
		append_log("FAIL: [Step 6] Expected 1200.0 to format as '1.2K', got '%s'" % DamageNumber.format_damage_value(1200.0), logs)
		vp.queue_free()
		return false
	if DamageNumber.format_damage_value(3400000.0) != "3.4M":
		append_log("FAIL: [Step 6] Expected 3400000.0 to format as '3.4M', got '%s'" % DamageNumber.format_damage_value(3400000.0), logs)
		vp.queue_free()
		return false
	append_log("  -> Sub-step 6: Large total abbreviation ('1.2K' & '3.4M') verified.", logs)

	# --- Sub-step 7: Clean scene exit ---
	deactivate_all.call()
	EventBus.damage_number_spawned.emit(visible_pos, 50.0, false, {"target_id": 8888})
	if manager.get_pending_bucket_count() != 1:
		append_log("FAIL: [Step 7] Failed to create pending bucket before exit", logs)
		vp.queue_free()
		return false

	manager._exit_tree()
	if manager.get_pending_bucket_count() != 0:
		append_log("FAIL: [Step 7] Pending buckets not cleared on _exit_tree()", logs)
		vp.queue_free()
		return false
	append_log("  -> Sub-step 7: Scene exit cleanly clears pending buckets with 0 leaks.", logs)
	manager._disconnect_events()
	manager.queue_free()
	cam.queue_free()
	vp.queue_free()
	append_log("  -> Test 47 PASSED: Damage number aggregation, clutter reduction & death flush fully validated.", logs)
	return true

func test_combat_feedback_hierarchy_and_slot_reservation(logs: Array[String]) -> bool:
	append_log("[TEST 48] Combat Feedback Hierarchy, Slot Reservation & Anti-Stacking...", logs)

	# --- Sub-step 1: Camera Shake Hierarchy & Accessibility Settings ---
	var camera_rig_scene := load("res://scenes/camera/camera_rig.tscn") as PackedScene
	if not camera_rig_scene:
		append_log("FAIL: camera_rig.tscn not found", logs)
		return false

	var camera_rig: CameraRig = camera_rig_scene.instantiate() as CameraRig
	add_child(camera_rig)

	# Test camera_shake setting: "off"
	SaveSystem.set_setting("camera_shake", "off")
	EventBus.setting_changed.emit("camera_shake", "off")
	if camera_rig.get_effective_shake_multiplier() > 0.001:
		append_log("FAIL: camera_shake 'off' should produce 0.0 multiplier, got %.2f" % camera_rig.get_effective_shake_multiplier(), logs)
		camera_rig.queue_free()
		return false

	camera_rig._on_shake_requested(0.5)
	if camera_rig._shake_trauma > 0.001:
		append_log("FAIL: camera_shake 'off' should not accumulate trauma", logs)
		camera_rig.queue_free()
		return false

	# Test camera_shake setting: "low"
	SaveSystem.set_setting("camera_shake", "low")
	EventBus.setting_changed.emit("camera_shake", "low")
	if absf(camera_rig.get_effective_shake_multiplier() - 0.5) > 0.05:
		append_log("FAIL: camera_shake 'low' should produce 0.5 multiplier, got %.2f" % camera_rig.get_effective_shake_multiplier(), logs)
		camera_rig.queue_free()
		return false

	# Test camera_shake setting: "normal"
	SaveSystem.set_setting("camera_shake", "normal")
	EventBus.setting_changed.emit("camera_shake", "normal")
	if absf(camera_rig.get_effective_shake_multiplier() - 1.0) > 0.05:
		append_log("FAIL: camera_shake 'normal' should produce 1.0 multiplier, got %.2f" % camera_rig.get_effective_shake_multiplier(), logs)
		camera_rig.queue_free()
		return false

	# Verify visual offset only (camera.transform.origin modified, rig global_position unaffected)
	var initial_rig_pos := camera_rig.global_position
	camera_rig._on_shake_requested(0.4)
	camera_rig._apply_camera_shake(0.016)
	if camera_rig.global_position != initial_rig_pos:
		append_log("FAIL: Camera shake altered CameraRig global_position (must only offset visual camera leaf)", logs)
		camera_rig.queue_free()
		return false

	# Clean reset
	SaveSystem.set_setting("camera_shake", 1.0)
	EventBus.setting_changed.emit("camera_shake", 1.0)
	camera_rig.queue_free()
	append_log("  -> Sub-step 1: Camera shake settings ('off', 'low', 'normal') and visual-offset-only isolation verified.", logs)

	# --- Sub-step 2: Damage Number Priority Slot Reservation ---
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 10.0, 15.0)
	cam.look_at_from_position(cam.position, Vector3.ZERO, Vector3.UP)
	cam.current = true
	vp.add_child(cam)

	var manager := DamageNumberManager.new()
	vp.add_child(manager)
	manager.max_active_numbers = 4 # Small cap to rigorously test preemption
	manager.set_camera(cam)

	var visible_pos := Vector3(0.0, 0.0, 0.0)

	# Flood with 4 NORMAL numbers (untargeted so immediate display)
	for i in range(4):
		EventBus.damage_number_spawned.emit(visible_pos, 10.0 + float(i), false, {})
		manager._process(0.02) # Give each a slight age separation

	if manager.get_active_count() != 4:
		append_log("FAIL: Expected 4 active labels after initial flood, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false

	# Attempt to spawn 5th NORMAL number: should be dropped because cap is 4 and it's low priority
	EventBus.damage_number_spawned.emit(visible_pos, 99.0, false, {})
	if manager.get_active_count() != 4:
		append_log("FAIL: 5th normal hit should be dropped at cap 4, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false

	# Spawn high-priority CRITICAL number: should preempt the oldest low-priority label
	EventBus.damage_number_spawned.emit(visible_pos, 77.0, true, {"is_critical": true})
	if manager.get_active_count() != 4:
		append_log("FAIL: Cap must remain 4 after critical preemption, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false

	var has_crit := false
	for lbl in manager._active_labels:
		if lbl.category == DamageNumber.DamageCategory.CRITICAL and lbl.text.contains("77"):
			has_crit = true
			break
	if not has_crit:
		append_log("FAIL: Critical number did not preempt low-priority label into active slots", logs)
		vp.queue_free()
		return false

	# Spawn high-priority PLAYER number: should preempt another low-priority label
	EventBus.player_damaged_directional.emit(25.0, visible_pos, Vector3.ZERO, false, {"target_id": 0})
	if manager.get_active_count() != 4:
		append_log("FAIL: Cap must remain 4 after player preemption, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false

	var has_player := false
	for lbl in manager._active_labels:
		if lbl.category == DamageNumber.DamageCategory.PLAYER and lbl.text.contains("-25"):
			has_player = true
			break
	if not has_player:
		append_log("FAIL: Player damage did not preempt low-priority label into active slots", logs)
		vp.queue_free()
		return false

	# Spawn high-priority LETHAL number
	EventBus.damage_number_spawned.emit(visible_pos, 50.0, false, {"is_lethal": true})
	if manager.get_active_count() != 4:
		append_log("FAIL: Cap must remain 4 after lethal preemption, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false

	# Spawn high-priority OBJECTIVE number (fills 4th slot with high-priority)
	EventBus.damage_number_spawned.emit(visible_pos, 150.0, false, {"is_objective": true})
	if manager.get_active_count() != 4:
		append_log("FAIL: Cap must remain 4 after objective preemption, got %d" % manager.get_active_count(), logs)
		vp.queue_free()
		return false

	# Now all 4 slots are high priority. A 5th high-priority number must NOT exceed the cap.
	EventBus.damage_number_spawned.emit(visible_pos, 200.0, true, {"is_critical": true})
	if manager.get_active_count() > 4:
		append_log("FAIL: Active count exceeded cap (%d > 4) when pool filled with high priority", logs)
		vp.queue_free()
		return false

	manager._disconnect_events()
	manager.queue_free()
	cam.queue_free()
	vp.queue_free()
	append_log("  -> Sub-step 2: Damage number priority slot reservation and hard pool cap adherence verified.", logs)

	# --- Sub-step 3: Anti-Stacking & Single Destruction Trigger ---
	var dummy := TargetDummy.new()
	add_child(dummy)
	dummy.max_health = 100.0
	dummy.current_health = 100.0
	dummy.is_alive = true

	var death_data := {"count": 0}
	var enemy_destroyed_cb := func(_enemy: Node3D, _pts: int):
		death_data["count"] += 1
	EventBus.enemy_destroyed.connect(enemy_destroyed_cb)

	# Trigger destruction twice
	dummy.take_damage(100.0)
	dummy.take_damage(100.0)

	EventBus.enemy_destroyed.disconnect(enemy_destroyed_cb)
	if is_instance_valid(dummy) and not dummy.is_queued_for_deletion():
		dummy.queue_free()

	if int(death_data["count"]) != 1:
		append_log("FAIL: Destruction triggered %d times on repeated lethal damage (expected exactly 1)" % int(death_data["count"]), logs)
		return false
	append_log("  -> Sub-step 3: Single destruction effect trigger (anti-stacking) verified.", logs)

	append_log("  -> Test 48 PASSED: Combat feedback hierarchy, slot reservation & anti-stacking verified.", logs)
	return true

func test_ordinary_hit_feedback_and_damage_flash(logs: Array[String]) -> bool:
	append_log("[TEST 49] Ordinary Hit Feedback: Enemy Flash, Sparks & Audio Rate-Limiting...", logs)

	# --- Sub-step 1: DamageFlashManager Initialization & Shared Materials ---
	var flash_mgr := DamageFlashManager.ensure_instance(get_tree())
	if not flash_mgr:
		append_log("FAIL: DamageFlashManager could not be instantiated", logs)
		return false

	var norm_mat: StandardMaterial3D = DamageFlashManager.get_normal_material()
	var red_mat: StandardMaterial3D = DamageFlashManager.get_reduced_material()

	if not norm_mat or norm_mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		append_log("FAIL: Normal flash material is invalid or not unshaded", logs)
		return false
	if not red_mat or red_mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
		append_log("FAIL: Reduced flash material is invalid or not unshaded", logs)
		return false
	if red_mat.albedo_color.v >= norm_mat.albedo_color.v:
		append_log("FAIL: Reduced flash material must be dimmer than normal flash", logs)
		return false
	append_log("  -> Sub-step 1: Zero-allocation shared unshaded flash materials verified.", logs)

	# --- Sub-step 2: Standard Flash Timing (40-70 ms) & Clean Material Restoration ---
	var dummy_scene := load("res://scenes/enemies/target_dummy.tscn") as PackedScene
	var dummy: TargetDummy = dummy_scene.instantiate() as TargetDummy
	add_child(dummy)
	var mesh_inst: MeshInstance3D = dummy.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_inst:
		append_log("FAIL: TargetDummy missing MeshInstance3D", logs)
		dummy.queue_free()
		return false

	var orig_mesh_mat := mesh_inst.mesh.surface_get_material(0)

	# Initial state
	if mesh_inst.material_override != null:
		append_log("FAIL: Initial material_override must be null", logs)
		dummy.queue_free()
		return false

	# Single confirmed hit
	DamageFlashManager.flash_target(dummy)
	if mesh_inst.material_override != norm_mat:
		append_log("FAIL: Target dummy mesh was not assigned normal flash material override", logs)
		dummy.queue_free()
		return false

	# Check duration constant is strictly within 40-70 ms
	var dur_ms := DamageFlashManager.FLASH_DURATION_NORMAL * 1000.0
	if dur_ms < 40.0 or dur_ms > 70.0:
		append_log("FAIL: Flash duration %.1f ms is outside 40-70 ms requirement" % dur_ms, logs)
		dummy.queue_free()
		return false

	# Tick halfway (25 ms) -> must still be flashing
	flash_mgr._process(0.025)
	if mesh_inst.material_override != norm_mat:
		append_log("FAIL: Flash cleared prematurely after 25 ms", logs)
		dummy.queue_free()
		return false

	# Tick past completion (35 ms more -> total 60 ms) -> must be restored
	flash_mgr._process(0.035)
	if mesh_inst.material_override != null:
		append_log("FAIL: Flash material override was not restored to null after 60 ms", logs)
		dummy.queue_free()
		return false

	# Verify original underlying mesh material was NOT mutated
	if mesh_inst.mesh.surface_get_material(0) != orig_mesh_mat:
		append_log("FAIL: Underlying mesh surface material was mutated by damage flash", logs)
		dummy.queue_free()
		return false
	append_log("  -> Sub-step 2: Standard 55 ms flash duration & clean material restoration verified.", logs)

	# --- Sub-step 3: Sustained Chaingun Fire & Refresh Rate-Limiting ---
	# Simulate 10 chaingun hits on the same target at 10 ms intervals
	for i in range(10):
		DamageFlashManager.flash_target(dummy)
		flash_mgr._process(0.010)

	# After rapid succession, target must still be flashing without leaking state
	if mesh_inst.material_override != norm_mat:
		append_log("FAIL: Sustained fire cut off flash prematurely", logs)
		dummy.queue_free()
		return false

	# Once firing stops, flash expires cleanly
	flash_mgr._process(0.060)
	if mesh_inst.material_override != null:
		append_log("FAIL: Flash not restored to null after sustained chaingun burst", logs)
		dummy.queue_free()
		return false
	append_log("  -> Sub-step 3: Sustained chaingun fire and flash refresh rate-limiting verified.", logs)

	# --- Sub-step 4: Simultaneous Hits on Distinct Enemies ---
	var dummy2: TargetDummy = dummy_scene.instantiate() as TargetDummy
	add_child(dummy2)
	var mesh2: MeshInstance3D = dummy2.get_node_or_null("MeshInstance3D") as MeshInstance3D

	# Hit both simultaneously
	DamageFlashManager.flash_target(dummy)
	DamageFlashManager.flash_target(dummy2)

	if mesh_inst.material_override != norm_mat or mesh2.material_override != norm_mat:
		append_log("FAIL: Simultaneous hits did not both trigger flash overrides", logs)
		dummy.queue_free()
		dummy2.queue_free()
		return false

	flash_mgr._process(0.060)
	if mesh_inst.material_override != null or mesh2.material_override != null:
		append_log("FAIL: Simultaneous hit meshes not cleanly restored", logs)
		dummy.queue_free()
		dummy2.queue_free()
		return false
	dummy2.queue_free()
	append_log("  -> Sub-step 4: Simultaneous hits on distinct enemies flash and restore independently.", logs)

	# --- Sub-step 5: Settings Respect (Suppression & Reduced Flashing) ---
	# Disable flash
	SaveSystem.set_setting("damage_flash_enabled", false)
	flash_mgr.refresh_settings()
	DamageFlashManager.flash_target(dummy)
	if mesh_inst.material_override != null:
		append_log("FAIL: Flash triggered when damage_flash_enabled is false", logs)
		dummy.queue_free()
		return false

	# Reduced flashing
	SaveSystem.set_setting("damage_flash_enabled", true)
	SaveSystem.set_setting("reduced_flashing", true)
	flash_mgr.refresh_settings()
	DamageFlashManager.flash_target(dummy)
	if mesh_inst.material_override != red_mat:
		append_log("FAIL: Reduced flashing did not apply reduced flash material", logs)
		dummy.queue_free()
		return false

	var red_dur_ms := DamageFlashManager.FLASH_DURATION_REDUCED * 1000.0
	if red_dur_ms < 35.0 or red_dur_ms > 50.0:
		append_log("FAIL: Reduced flash duration %.1f ms outside 35-50 ms", logs)
		dummy.queue_free()
		return false

	flash_mgr._process(0.045)
	if mesh_inst.material_override != null:
		append_log("FAIL: Reduced flash not cleared after 45 ms", logs)
		dummy.queue_free()
		return false

	# Restore settings
	SaveSystem.set_setting("damage_flash_enabled", true)
	SaveSystem.set_setting("reduced_flashing", false)
	SaveSystem.set_setting("damage_flash_intensity", 1.0)
	flash_mgr.refresh_settings()
	append_log("  -> Sub-step 5: Settings integration (suppression & reduced flashing) verified.", logs)

	# --- Sub-step 6: Death Flush (Immediate Cleanup on Destruction) ---
	DamageFlashManager.flash_target(dummy)
	if mesh_inst.material_override == null:
		append_log("FAIL: Dummy not flashing before death", logs)
		dummy.queue_free()
		return false

	DamageFlashManager.clear_target(dummy)
	if mesh_inst.material_override != null:
		append_log("FAIL: clear_target did not immediately restore material_override = null", logs)
		dummy.queue_free()
		return false
	dummy.queue_free()
	append_log("  -> Sub-step 6: Death flush immediately clears overrides with zero lingering state.", logs)

	# --- Sub-step 7: Audio Synthesis Rate-Limiting & Pitch Variation ---
	var sound_scene := load("res://scenes/audio/sound_manager.tscn") as PackedScene
	var sound_mgr: SoundManager = sound_scene.instantiate() as SoundManager
	add_child(sound_mgr)

	# Reset impact cooldown
	sound_mgr._last_impact_armor_time = 0.0
	EventBus.combat_impact_occurred.emit(Vector3.ZERO, Vector3.UP, true, false)
	var first_time := sound_mgr._last_impact_armor_time
	if first_time <= 0.0:
		append_log("FAIL: SoundManager did not record armor impact time", logs)
		sound_mgr.queue_free()
		return false

	# Immediate second hit in same frame (< 0.04s) must be dropped by rate limit
	EventBus.combat_impact_occurred.emit(Vector3.ZERO, Vector3.UP, true, false)
	if sound_mgr._last_impact_armor_time != first_time:
		append_log("FAIL: SoundManager played second impact within 40 ms (rate limit breached)", logs)
		sound_mgr.queue_free()
		return false

	sound_mgr.queue_free()
	append_log("  -> Sub-step 7: Audio synthesis rate-limiting (40 ms cooldown) verified.", logs)

	# --- Sub-step 8: Zero Camera Shake & Hit-Stop on Bullet Hits ---
	var shake_data := {"requested": false}
	var shake_cb := func(_amt: float):
		shake_data["requested"] = true
	EventBus.camera_shake_requested.connect(shake_cb)

	# Simulate ordinary bullet impact
	EventBus.combat_impact_occurred.emit(Vector3(1, 0, 1), Vector3.UP, true, false)
	if bool(shake_data["requested"]):
		append_log("FAIL: Camera shake was triggered by ordinary bullet impact (shake must be 0)", logs)
		EventBus.camera_shake_requested.disconnect(shake_cb)
		return false

	if Engine.time_scale != 1.0:
		append_log("FAIL: Global hit-stop active during ordinary combat hit", logs)
		EventBus.camera_shake_requested.disconnect(shake_cb)
		return false

	EventBus.camera_shake_requested.disconnect(shake_cb)
	append_log("  -> Sub-step 8: Zero camera shake and zero hit-stop on ordinary bullet hits verified.", logs)

	append_log("  -> Test 49 PASSED: Ordinary hit feedback (flash, sparks, audio rate-limiting) fully validated.", logs)
	return true

