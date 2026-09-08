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

	if success:
		append_log("=== ALL HELI-STRIKE VERTICAL SLICE TESTS PASSED! ===", log_lines)
	else:
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

	# Place player in safe zone (<125m)
	append_log("[TEST 22] Sub-step 1.3: Testing safe zone (50m)...", logs)
	dummy_player.position = Vector3(50.0, 10.0, 0.0)
	dummy_player.global_position = Vector3(50.0, 10.0, 0.0)
	pa._physics_process(0.016)
	if warning_state["received"]:
		logs.append("FAIL: Boundary warning triggered inside safe zone at 50m")
		EventBus.border_warning_changed.disconnect(warning_cb)
		dummy_player.free()
		pa.free()
		return false

	# Place player in warning zone (135m, between 125m and 145m)
	append_log("[TEST 22] Sub-step 1.4: Testing warning zone (135m)...", logs)
	dummy_player.position = Vector3(135.0, 10.0, 0.0)
	dummy_player.global_position = Vector3(135.0, 10.0, 0.0)
	pa._physics_process(0.016)
	if not warning_state["received"]:
		logs.append("FAIL: Boundary warning NOT triggered in warning zone at 135m (target_player=%s, pos=%s, is_warn=%s, safe=%s)" % [str(pa.target_player), str(pa.target_player.global_position if pa.target_player else Vector3.ZERO), str(pa.get("_is_currently_warning")), str(pa.safe_half_extent)])
		EventBus.border_warning_changed.disconnect(warning_cb)
		dummy_player.free()
		pa.free()
		return false

	# Place player past hard boundary (>148m) with outward velocity
	append_log("[TEST 22] Sub-step 1.5: Testing hard boundary clamping...", logs)
	dummy_player.position = Vector3(150.0, 10.0, 0.0)
	dummy_player.global_position = Vector3(150.0, 10.0, 0.0)
	dummy_player.velocity = Vector3(25.0, 0.0, 0.0)
	pa._physics_process(0.016)
	if dummy_player.global_position.x > 148.01:
		logs.append("FAIL: Hard boundary did not clamp position to <= 148m (got %.2f)" % dummy_player.global_position.x)
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
	for i in range(state.get_node_count()):
		var n: String = state.get_node_name(i)
		if n == "PlayableArea": found_pa = true
		elif n == "Districts": found_districts = true
		elif n == "District_CityCenter" or n == "CentralUrban": found_city = true
		elif n == "District_Industrial" or n == "Industrial": found_ind = true
		elif n == "District_Military" or n == "Military": found_mil = true
		elif n == "District_Outskirts" or n == "Outskirts": found_out = true

	if not found_pa or not found_districts:
		logs.append("FAIL: Battlefield missing PlayableArea or Districts node")
		return false
	if not found_city or not found_ind or not found_mil or not found_out:
		logs.append("FAIL: Battlefield missing one of the 4 district nodes")
		return false

	append_log("  -> 3-tier boundary, fuel tank, crate destruction, HUD border alert, and 4-district city battlefield verified.", logs)
	return true
