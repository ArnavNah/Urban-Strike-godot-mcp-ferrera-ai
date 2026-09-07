extends SceneTree

func _init() -> void:
	var log_lines: Array[String] = []
	log_lines.append("--- STARTING HELI-STRIKE SANDBOX AUTOMATED TESTS ---")
	var success := true

	success = test_player_flight(log_lines) and success
	success = test_altitude_limits(log_lines) and success
	success = test_chaingun_heat_and_overheat(log_lines) and success
	success = test_projectile_pool(log_lines) and success
	success = test_turret_state_machine(log_lines) and success

	if success:
		log_lines.append("=== ALL HELI-STRIKE SANDBOX TESTS PASSED! ===")
	else:
		log_lines.append("=== SOME TESTS FAILED! ===")

	var target_path := "c:/Users/Prime 3/Documents/Downloads/urban-stike-rogue/test_results.txt"
	var f := FileAccess.open(target_path, FileAccess.WRITE)
	if f:
		for line in log_lines:
			f.store_line(line)
		f.close()

	quit(0 if success else 1)

func test_player_flight(logs: Array[String]) -> bool:
	logs.append("[TEST] Player flight physics parameters...")
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerHelicopter
	root.add_child(player)

	if absf(player.max_speed - 38.055) > 0.01:
		logs.append("FAIL: player max_speed is not 38.055 (137 KPH)")
		player.queue_free()
		return false
	if absf(player.acceleration - 42.0) > 0.01:
		logs.append("FAIL: player acceleration is not 42 m/s²")
		player.queue_free()
		return false
	if absf(player.min_altitude - 2.6) > 0.01:
		logs.append("FAIL: min_altitude is not 2.6m")
		player.queue_free()
		return false
	if absf(player.max_altitude - 26.0) > 0.01:
		logs.append("FAIL: max_altitude is not 26.0m")
		player.queue_free()
		return false

	logs.append("  -> Baseline speeds & accelerations verified (137 KPH, 42 m/s², [2.6m, 26m]).")
	player.queue_free()
	return true

func test_altitude_limits(logs: Array[String]) -> bool:
	logs.append("[TEST] Altitude clamping [2.6m - 26.0m]...")
	var player_scene := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerHelicopter
	player.global_position = Vector3(0, 1.0, 0)
	root.add_child(player)

	player._handle_altitude(0.1)
	if player.global_position.y < 2.6:
		logs.append("FAIL: player dropped below min_altitude 2.6m")
		player.queue_free()
		return false

	player.global_position = Vector3(0, 50.0, 0)
	player._handle_altitude(0.1)
	if player.global_position.y > 26.0:
		logs.append("FAIL: player exceeded max_altitude 26.0m")
		player.queue_free()
		return false

	logs.append("  -> Altitude strictly clamped between 2.6m and 26.0m.")
	player.queue_free()
	return true

func test_chaingun_heat_and_overheat(logs: Array[String]) -> bool:
	logs.append("[TEST] Chaingun 11.5 RPS and 2.5s overheat lockout...")
	var gun_scene := load("res://scenes/weapons/chaingun.tscn") as PackedScene
	var gun := gun_scene.instantiate() as Chaingun
	root.add_child(gun)

	if absf(gun.fire_rate - 11.5) > 0.01:
		logs.append("FAIL: Chaingun fire_rate != 11.5 RPS")
		gun.queue_free()
		return false
	if absf(gun.overheat_lockout_duration - 2.5) > 0.01:
		logs.append("FAIL: Chaingun lockout duration != 2.5s")
		gun.queue_free()
		return false

	var fired_shots := 0
	for i in range(30):
		gun._shot_cooldown = 0.0
		if gun.try_fire(Vector3(0, 0, -10)):
			fired_shots += 1
		if gun.is_overheated:
			break

	if not gun.is_overheated:
		logs.append("FAIL: Chaingun failed to overheat")
		gun.queue_free()
		return false

	logs.append("  -> Chaingun overheated after %d shots." % fired_shots)

	gun._shot_cooldown = 0.0
	if gun.try_fire(Vector3(0, 0, -10)):
		logs.append("FAIL: Chaingun fired while in overheat lockout!")
		gun.queue_free()
		return false

	gun._process(2.4)
	if not gun.is_overheated:
		logs.append("FAIL: Chaingun unlocked before 2.5s expired!")
		gun.queue_free()
		return false

	gun._process(0.2)
	if gun.is_overheated:
		logs.append("FAIL: Chaingun did not unlock after 2.5s!")
		gun.queue_free()
		return false

	logs.append("  -> 2.5s lockout enforced and recovered.")
	gun.queue_free()
	return true

func test_projectile_pool(logs: Array[String]) -> bool:
	logs.append("[TEST] ProjectilePool allocation and reuse...")
	var pool_scene := load("res://scenes/weapons/projectile_pool.tscn") as PackedScene
	var pool := pool_scene.instantiate() as ProjectilePool
	root.add_child(pool)

	if pool._pool.size() != pool.pool_size:
		logs.append("FAIL: Pool size mismatch")
		pool.queue_free()
		return false

	var p1 := pool.spawn_projectile(Vector3.ZERO, Vector3.FORWARD, true, 6.0)
	if p1 == null or not p1._is_active:
		logs.append("FAIL: Pool failed to spawn projectile")
		pool.queue_free()
		return false

	logs.append("  -> Pool pre-allocated %d projectiles and successfully spawned." % pool.pool_size)
	pool.queue_free()
	return true

func test_turret_state_machine(logs: Array[String]) -> bool:
	logs.append("[TEST] GroundTurret state machine...")
	var turret_scene := load("res://scenes/enemies/ground_turret.tscn") as PackedScene
	var turret := turret_scene.instantiate() as GroundTurret
	root.add_child(turret)

	if turret.current_state != GroundTurret.State.IDLE:
		logs.append("FAIL: Initial turret state is not IDLE")
		turret.queue_free()
		return false

	turret._transition_to(GroundTurret.State.AIMING)
	if turret.current_state != GroundTurret.State.AIMING:
		logs.append("FAIL: Failed transition to AIMING")
		turret.queue_free()
		return false

	turret._transition_to(GroundTurret.State.FIRING)
	if turret.current_state != GroundTurret.State.FIRING:
		logs.append("FAIL: Failed transition to FIRING")
		turret.queue_free()
		return false

	turret._transition_to(GroundTurret.State.RELOADING)
	if turret.current_state != GroundTurret.State.RELOADING:
		logs.append("FAIL: Failed transition to RELOADING")
		turret.queue_free()
		return false

	turret._transition_to(GroundTurret.State.WAITING)
	if turret.current_state != GroundTurret.State.WAITING:
		logs.append("FAIL: Failed transition to WAITING")
		turret.queue_free()
		return false

	logs.append("  -> GroundTurret state machine transitions verified.")
	turret.queue_free()
	return true
