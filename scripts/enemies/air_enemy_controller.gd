class_name AirEnemyController
extends CharacterBody3D

## Shared, modular air enemy controller for all flying helicopter archetypes.
## Implements readable flight states, altitude banding, neighbor avoidance,
## smooth yaw, banking visuals, CombatDirector slot leases, and archetype weapons.

enum State {
	APPROACH,
	ORBIT,
	STRAFE,
	ATTACK,
	REPOSITION,
	DISENGAGE,
	RETREAT,
	DEATH
}

@export var archetype: AirEnemyArchetype:
	set(value):
		archetype = value
		_apply_archetype_config()
@export var custom_threat_cost: int = -1

var current_state: State = State.APPROACH
var current_health: float = 30.0
var is_alive: bool = true
var threat_score: float = 0.5

# Drop zone for Transport Helicopter
var drop_target_position: Vector3 = Vector3.ZERO
var has_deployed_cargo: bool = false

# Internal state tracking
var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _shot_cooldown: float = 0.0
var _missile_cooldown_timer: float = 0.0
var _target_waypoint: Vector3 = Vector3.ZERO
var _attack_vector: Vector3 = Vector3.FORWARD
var _orbit_angle: float = 0.0
var _orbit_direction: float = 1.0 # 1.0 or -1.0
var _player: Node3D = null
var _has_air_slot: bool = false
var _lod_frame_counter: int = 0
var _is_telegraphing: bool = false
var _burst_shots_remaining: int = 0
var _evasion_cooldown: float = 0.0

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var main_rotor: Node3D = get_node_or_null("Visuals/MainRotor")
@onready var los_ray: RayCast3D = get_node_or_null("LOSRayCast")
@onready var muzzle_flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
@onready var guided_missile_scene: PackedScene = preload("res://scenes/weapons/guided_missile.tscn")
@onready var unguided_rocket_scene: PackedScene = preload("res://scenes/weapons/unguided_rocket.tscn")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("air_enemies")

	_apply_archetype_config()

	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, true)

	_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player):
		var init_y: float = clampf(_player.global_position.y, _get_alt_min(), _get_alt_max())
		global_position.y = init_y

	_orbit_direction = 1.0 if randf() > 0.5 else -1.0
	_orbit_angle = randf() * TAU
	_missile_cooldown_timer = randf_range(2.0, 4.0)

	_pick_approach_waypoint()

	# If Jammer, notify active jamming
	if archetype and archetype.weapon_type == AirEnemyArchetype.WeaponType.JAMMER_SUPPORT:
		add_to_group("jammers")
		_notify_jammer_state_change()

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)
	_release_air_slot()
	if is_in_group("jammers"):
		remove_from_group("jammers")
		_notify_jammer_state_change()

func _apply_archetype_config() -> void:
	if not archetype:
		archetype = AirEnemyArchetype.new()

	current_health = archetype.max_health
	threat_score = archetype.threat_score

	for tag in archetype.formation_tags:
		if not is_in_group(tag):
			add_to_group(tag)

	if archetype.is_elite:
		add_to_group("elites")

func _get_alt_min() -> float:
	return archetype.altitude_min if archetype else 10.0

func _get_alt_max() -> float:
	return archetype.altitude_max if archetype else 20.0

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	if main_rotor:
		main_rotor.rotate_y(45.0 * delta)

	if _evasion_cooldown > 0.0:
		_evasion_cooldown -= delta
	if _missile_cooldown_timer > 0.0:
		_missile_cooldown_timer -= delta

	# Distance-based AI LOD
	var dist_to_player := global_position.distance_to(_player.global_position)
	_lod_frame_counter += 1
	var step_delta := delta
	if dist_to_player > 140.0:
		return # LOD 3: Culled
	elif dist_to_player > 80.0:
		if _lod_frame_counter % 4 != 0:
			return # LOD 2: 15 Hz
		step_delta = delta * 4.0
	elif dist_to_player > 40.0:
		if _lod_frame_counter % 2 != 0:
			return # LOD 1: 30 Hz
		step_delta = delta * 2.0

	# Altitude band compliance
	_update_altitude(step_delta)

	# Safety check: avoid hovering directly over player or ramming
	var flat_dist := Vector2(global_position.x - _player.global_position.x, global_position.z - _player.global_position.z).length()
	if flat_dist < 10.0 and current_state != State.DISENGAGE and current_state != State.RETREAT:
		_transition_to(State.DISENGAGE)

	match current_state:
		State.APPROACH:
			_tick_approach(step_delta, flat_dist)
		State.ORBIT:
			_tick_orbit(step_delta)
		State.STRAFE:
			_tick_strafe(step_delta)
		State.ATTACK:
			_tick_attack(step_delta)
		State.REPOSITION:
			_tick_reposition(step_delta)
		State.DISENGAGE:
			_tick_disengage(step_delta)
		State.RETREAT:
			_tick_retreat(step_delta)

	# Lateral neighbor separation & avoidance
	_apply_separation()

	# Move and update orientation
	move_and_slide()
	_update_visual_orientation(step_delta)

func _update_altitude(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var target_y := clampf(_player.global_position.y, _get_alt_min(), _get_alt_max())
	# If Transport is actively landing at LZ, descend toward ground level
	if archetype.weapon_type == AirEnemyArchetype.WeaponType.TRANSPORT_DEPLOY:
		if current_state == State.ATTACK:
			target_y = 3.5 # Near ground hover for drop

	global_position.y = move_toward(global_position.y, target_y, 10.0 * delta)
	velocity.y = 0.0

func _apply_separation() -> void:
	var avoidance := Vector3.ZERO
	var search_radius: float = 8.5
	var nearby: Array[Node3D] = []

	if EnemyRegistry.instance:
		nearby = EnemyRegistry.instance.get_enemies_in_radius(global_position, search_radius)
	else:
		for e in get_tree().get_nodes_in_group("air_enemies"):
			if e is Node3D and e != self:
				nearby.append(e as Node3D)

	for other in nearby:
		if other != self and is_instance_valid(other) and other.is_in_group("air_enemies"):
			var diff := global_position - other.global_position
			diff.y = 0.0
			var d := diff.length()
			if d < search_radius and d > 0.05:
				var weight: float = (search_radius - d) / search_radius
				avoidance += (diff / d) * weight * 14.0

	velocity.x += avoidance.x
	velocity.z += avoidance.z

func _update_visual_orientation(delta: float) -> void:
	var horiz_vel := Vector2(velocity.x, velocity.z)
	if horiz_vel.length_squared() > 0.5:
		var target_yaw := atan2(-velocity.x, -velocity.z)
		var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)
		rotation.y = lerp_angle(rotation.y, target_yaw, archetype.turn_speed * delta)

		if visuals:
			# Roll into turns (banking)
			var max_bank := deg_to_rad(30.0)
			var target_bank := clampf(-yaw_diff * 1.5, -max_bank, max_bank)
			visuals.rotation.z = lerp_angle(visuals.rotation.z, target_bank, 6.0 * delta)

			# Slight forward pitch based on speed
			var max_pitch := deg_to_rad(14.0)
			var speed_ratio := clampf(horiz_vel.length() / maxf(archetype.attack_speed, 1.0), 0.0, 1.0)
			var target_pitch := speed_ratio * max_pitch
			visuals.rotation.x = lerp_angle(visuals.rotation.x, target_pitch, 5.0 * delta)
	else:
		if visuals:
			visuals.rotation.z = lerp_angle(visuals.rotation.z, 0.0, 4.0 * delta)
			visuals.rotation.x = lerp_angle(visuals.rotation.x, 0.0, 4.0 * delta)

func _tick_approach(delta: float, flat_dist: float) -> void:
	_state_timer -= delta
	_update_approach_waypoint()

	var to_wp := _target_waypoint - global_position
	to_wp.y = 0.0

	if to_wp.length() < 10.0 or _state_timer <= 0.0 or flat_dist <= archetype.preferred_distance:
		# Decide next state based on archetype
		match archetype.weapon_type:
			AirEnemyArchetype.WeaponType.TRANSPORT_DEPLOY:
				_transition_to(State.ATTACK) # Drop payload at LZ
			AirEnemyArchetype.WeaponType.JAMMER_SUPPORT:
				_transition_to(State.ORBIT) # Keep safe orbital distance
			_:
				if randf() < archetype.aggression:
					_transition_to(State.ATTACK)
				else:
					_transition_to(State.ORBIT if randf() > 0.4 else State.STRAFE)
		return

	_fly_toward(_target_waypoint, archetype.cruise_speed)

func _tick_orbit(delta: float) -> void:
	_state_timer -= delta
	_orbit_angle += _orbit_direction * (archetype.cruise_speed / maxf(archetype.orbit_distance, 10.0)) * delta

	var orbit_offset := Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * archetype.orbit_distance
	var orbit_target := _player.global_position + orbit_offset
	orbit_target.y = global_position.y

	_fly_toward(orbit_target, archetype.cruise_speed)

	# Periodic attack check during orbit
	if _state_timer <= 0.0:
		if archetype.weapon_type != AirEnemyArchetype.WeaponType.JAMMER_SUPPORT and randf() <= archetype.aggression:
			_transition_to(State.ATTACK)
		else:
			_transition_to(State.STRAFE if randf() > 0.5 else State.REPOSITION)

func _tick_strafe(delta: float) -> void:
	_state_timer -= delta
	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	var fwd := to_player.normalized()
	var perp := Vector3(-fwd.z, 0.0, fwd.x) * _orbit_direction

	var strafe_vec := (perp * 0.85 + fwd * 0.35).normalized()
	velocity.x = strafe_vec.x * archetype.cruise_speed
	velocity.z = strafe_vec.z * archetype.cruise_speed

	if _state_timer <= 0.0:
		_transition_to(State.ATTACK if randf() <= archetype.aggression else State.REPOSITION)

func _tick_attack(delta: float) -> void:
	_attack_timer -= delta
	_shot_cooldown -= delta

	match archetype.weapon_type:
		AirEnemyArchetype.WeaponType.MACHINE_GUN:
			_exec_machine_gun_attack(delta)
		AirEnemyArchetype.WeaponType.ROCKET_SALVO:
			_exec_rocket_salvo_attack(delta)
		AirEnemyArchetype.WeaponType.HEAVY_CANNON_AND_MISSILES:
			_exec_gunship_attack(delta)
		AirEnemyArchetype.WeaponType.JAMMER_SUPPORT:
			_exec_jammer_attack(delta)
		AirEnemyArchetype.WeaponType.ACE_ARSENAL:
			_exec_ace_attack(delta)
		AirEnemyArchetype.WeaponType.TRANSPORT_DEPLOY:
			_exec_transport_drop(delta)

	if _attack_timer <= 0.0:
		_release_air_slot()
		_transition_to(State.DISENGAGE)

func _exec_machine_gun_attack(_delta: float) -> void:
	# Strafe pass while firing MG
	velocity.x = _attack_vector.x * archetype.attack_speed
	velocity.z = _attack_vector.z * archetype.attack_speed

	if _shot_cooldown <= 0.0:
		_shot_cooldown = 1.0 / maxf(archetype.fire_rate, 1.0)
		_fire_bullet()

func _exec_rocket_salvo_attack(_delta: float) -> void:
	# Slow steady aim run with clear tell
	if _is_telegraphing:
		velocity.x = _attack_vector.x * (archetype.cruise_speed * 0.6)
		velocity.z = _attack_vector.z * (archetype.cruise_speed * 0.6)
		if _attack_timer <= archetype.strafe_duration - 0.7:
			_is_telegraphing = false
			_burst_shots_remaining = archetype.burst_count
	else:
		velocity.x = _attack_vector.x * archetype.attack_speed
		velocity.z = _attack_vector.z * archetype.attack_speed

		if _burst_shots_remaining > 0 and _shot_cooldown <= 0.0:
			_shot_cooldown = 0.2
			_burst_shots_remaining -= 1
			_fire_rocket()

func _exec_gunship_attack(_delta: float) -> void:
	velocity.x = _attack_vector.x * archetype.attack_speed
	velocity.z = _attack_vector.z * archetype.attack_speed

	# Cannon fire
	if _shot_cooldown <= 0.0:
		_shot_cooldown = 1.0 / maxf(archetype.fire_rate, 1.0)
		_fire_bullet(3.5)

	# Telegraphed missile salvo
	if _missile_cooldown_timer <= 0.0 and _attack_timer > 1.2:
		_missile_cooldown_timer = archetype.missile_cooldown
		_warn_incoming_missile(true)
		get_tree().create_timer(archetype.missile_lock_time).timeout.connect(_fire_missile_at_player)

func _exec_jammer_attack(_delta: float) -> void:
	# Orbits and fires light defensive chin gun only if close
	velocity.x = _attack_vector.x * archetype.cruise_speed
	velocity.z = _attack_vector.z * archetype.cruise_speed
	if _shot_cooldown <= 0.0:
		_shot_cooldown = 0.5
		_fire_bullet(1.5)

func _exec_ace_attack(_delta: float) -> void:
	# Aggressive sweep with heavy cannon and dual missiles
	velocity.x = _attack_vector.x * archetype.attack_speed
	velocity.z = _attack_vector.z * archetype.attack_speed

	if _shot_cooldown <= 0.0:
		_shot_cooldown = 1.0 / maxf(archetype.fire_rate, 1.0)
		_fire_bullet(4.0)

	if _missile_cooldown_timer <= 0.0 and _attack_timer > 1.0:
		_missile_cooldown_timer = archetype.missile_cooldown
		_warn_incoming_missile(true)
		get_tree().create_timer(archetype.missile_lock_time * 0.85).timeout.connect(_fire_missile_at_player)

func _exec_transport_drop(_delta: float) -> void:
	# Decelerate to hover over drop zone
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * _delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * _delta)

	if not has_deployed_cargo and _attack_timer <= 1.0:
		has_deployed_cargo = true
		_deploy_cargo()

func _tick_reposition(delta: float) -> void:
	_state_timer -= delta
	_update_reposition_waypoint()

	var to_wp := _target_waypoint - global_position
	to_wp.y = 0.0

	if to_wp.length() < 12.0 or _state_timer <= 0.0:
		_transition_to(State.ORBIT if randf() > 0.5 else State.APPROACH)
	else:
		_fly_toward(_target_waypoint, archetype.cruise_speed)

func _tick_disengage(delta: float) -> void:
	_state_timer -= delta
	# Break away at a 45-degree angle
	var break_vec := (_attack_vector + Vector3(0.7 * _orbit_direction, 0.0, 0.4)).normalized()
	velocity.x = break_vec.x * archetype.cruise_speed
	velocity.z = break_vec.z * archetype.cruise_speed

	if _state_timer <= 0.0:
		if archetype.weapon_type == AirEnemyArchetype.WeaponType.TRANSPORT_DEPLOY and has_deployed_cargo:
			_transition_to(State.RETREAT)
		else:
			_transition_to(State.REPOSITION)

func _tick_retreat(_delta: float) -> void:
	# Fly away from map center toward boundary and despawn safely
	var center_dir := (global_position - Vector3.ZERO)
	center_dir.y = 0.0
	var exit_vec := center_dir.normalized()
	if exit_vec.length_squared() < 0.01:
		exit_vec = Vector3.FORWARD

	velocity.x = exit_vec.x * archetype.cruise_speed
	velocity.z = exit_vec.z * archetype.cruise_speed

	if global_position.length() > 140.0:
		# Safely despawn outside battlefield
		queue_free()

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.APPROACH:
			_state_timer = archetype.approach_timeout
			_pick_approach_waypoint()
		State.ORBIT:
			_state_timer = randf_range(2.5, 4.5)
		State.STRAFE:
			_state_timer = archetype.strafe_duration
		State.ATTACK:
			if not _request_air_slot():
				# Slot denied, fall back to orbit
				current_state = State.ORBIT
				_state_timer = 1.0
				return

			_attack_timer = archetype.strafe_duration
			_shot_cooldown = 0.0
			_is_telegraphing = (archetype.weapon_type == AirEnemyArchetype.WeaponType.ROCKET_SALVO)

			if is_instance_valid(_player):
				var aim_pos: Vector3 = _player.global_position
				_attack_vector = (aim_pos - global_position)
				_attack_vector.y = 0.0
				_attack_vector = _attack_vector.normalized()
		State.REPOSITION:
			_state_timer = archetype.reposition_delay
			_pick_reposition_waypoint()
		State.DISENGAGE:
			_state_timer = 1.5
		State.RETREAT:
			_state_timer = 10.0

func _fly_toward(dest: Vector3, speed: float) -> void:
	var to_dest := dest - global_position
	to_dest.y = 0.0
	var dir := to_dest.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _pick_approach_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * archetype.preferred_distance
	_target_waypoint = _player.global_position + offset
	_target_waypoint.y = global_position.y

func _update_approach_waypoint() -> void:
	if is_instance_valid(_player):
		_target_waypoint.y = global_position.y

func _pick_reposition_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * (archetype.preferred_distance * 1.5)
	_target_waypoint = _player.global_position + offset
	_target_waypoint.y = global_position.y

func _update_reposition_waypoint() -> void:
	if is_instance_valid(_player):
		_target_waypoint.y = global_position.y

func _fire_bullet(damage_mult: float = 1.0) -> void:
	if not is_instance_valid(_player):
		return

	var muzzle_pos := global_position + (-global_transform.basis.z * 1.8) + Vector3(0.0, -0.3, 0.0)
	var fire_dir := (_player.global_position - muzzle_pos).normalized()

	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance
	if pool:
		pool.spawn_projectile(muzzle_pos, fire_dir, false, archetype.damage_per_shot * damage_mult)

	if muzzle_flash_scene:
		var flash := muzzle_flash_scene.instantiate() as Node3D
		if flash:
			flash.transform.origin = muzzle_pos
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(flash)

func _fire_rocket() -> void:
	if not is_instance_valid(_player) or not unguided_rocket_scene:
		return

	var muzzle_pos := global_position + (-global_transform.basis.z * 1.6) + Vector3(randf_range(-0.6, 0.6), -0.2, 0.0)
	var fire_dir := (_player.global_position - muzzle_pos).normalized()
	# Add small inaccuracy spread
	var spread := Vector3(randf_range(-0.06, 0.06), randf_range(-0.04, 0.04), randf_range(-0.06, 0.06))
	fire_dir = (fire_dir + spread).normalized()

	var rocket: UnguidedRocket = unguided_rocket_scene.instantiate() as UnguidedRocket
	if rocket:
		var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
		p.add_child.call_deferred(rocket)
		rocket.call_deferred("launch", muzzle_pos, fire_dir, 46.0)

func _fire_missile_at_player() -> void:
	_warn_incoming_missile(false)
	if not is_alive or not is_instance_valid(_player) or not guided_missile_scene:
		return

	var muzzle_pos := global_position + Vector3(0.0, -0.4, -1.0)
	var fire_dir := (muzzle_pos.direction_to(_player.global_position) + Vector3.UP * 0.25).normalized()

	var missile: GuidedMissile = guided_missile_scene.instantiate() as GuidedMissile
	if missile:
		missile.damage = 38.0
		var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
		p.add_child.call_deferred(missile)
		missile.call_deferred("launch", muzzle_pos, fire_dir, _player, false)

func _deploy_cargo() -> void:
	has_deployed_cargo = true
	# Deploys real existing ground enemies (1 Tank or 2 Infantry clusters)
	var parent: Node = get_parent()
	if not parent:
		parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var drop_pos := Vector3(global_position.x, 0.0, global_position.z)

	var spawn_tank := randf() > 0.4
	if spawn_tank:
		var tank_scene: PackedScene = load("res://scenes/enemies/tank.tscn")
		if tank_scene:
			var tank := tank_scene.instantiate() as Node3D
			if tank:
				tank.transform.origin = drop_pos
				parent.add_child(tank)
	else:
		var inf_scene: PackedScene = load("res://scenes/enemies/infantry_cluster.tscn")
		if inf_scene:
			for i in range(2):
				var inf := inf_scene.instantiate() as Node3D
				if inf:
					var off := Vector3(float(i * 3 - 1.5), 0.0, 0.0)
					inf.transform.origin = drop_pos + off
					parent.add_child(inf)

	if VfxPool.instance:
		VfxPool.instance.spawn_sparks(drop_pos)

func _warn_incoming_missile(active: bool) -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("incoming_missile_warning"):
		eb.emit_signal("incoming_missile_warning", global_position, active)

func _notify_jammer_state_change() -> void:
	var jammers := get_tree().get_nodes_in_group("jammers")
	var count: int = jammers.size()
	var is_jammed: bool = count > 0

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("jammer_status_changed"):
		eb.emit_signal("jammer_status_changed", is_jammed, count)

func _request_air_slot() -> bool:
	var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
	if not dir and CombatDirector.instance:
		dir = CombatDirector.instance
	if dir:
		var granted: bool = dir.request_attack_slot(self, true)
		_has_air_slot = granted
		return granted
	_has_air_slot = true
	return true

func _release_air_slot() -> void:
	if _has_air_slot:
		var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
		if not dir and CombatDirector.instance:
			dir = CombatDirector.instance
		if dir:
			dir.release_attack_slot(self, true)
	_has_air_slot = false

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return

	current_health = maxf(0.0, current_health - amount)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position, amount, amount >= 30.0)

	# Ace Gunship evasion check: burst away or deploy flares if damaged
	if archetype.is_elite and _evasion_cooldown <= 0.0 and randf() > 0.4:
		_perform_ace_evasion()

	if current_health <= 0.0:
		_die()

func _perform_ace_evasion() -> void:
	_evasion_cooldown = 4.0
	_transition_to(State.DISENGAGE)
	# Lateral surge
	var evade_dir := (global_transform.basis.x * (1.0 if randf() > 0.5 else -1.0)).normalized()
	velocity += evade_dir * 18.0

func _die() -> void:
	is_alive = false
	_release_air_slot()

	if is_in_group("jammers"):
		remove_from_group("jammers")
		_notify_jammer_state_change()

	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_destroyed"):
		var pts: int = archetype.threat_cost * 15
		eb.emit_signal("enemy_destroyed", self, pts)

	_spawn_pickups()

	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(global_position)
	else:
		var expl_scene: PackedScene = load("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = global_position
				expl.scale = Vector3(2.2, 2.2, 2.2) if archetype.is_elite else Vector3(1.6, 1.6, 1.6)
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(expl)

	queue_free()

func _spawn_pickups() -> void:
	var xp_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn")
	if xp_scene:
		var gem := xp_scene.instantiate() as Node3D
		if gem:
			gem.transform.origin = global_position
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)

	# Elite or heavy gunships drop salvage crate
	if archetype.is_elite or archetype.threat_cost >= 8:
		var crate_scene: PackedScene = load("res://scenes/pickups/salvage_crate.tscn")
		if crate_scene:
			var crate := crate_scene.instantiate() as Node3D
			if crate:
				crate.transform.origin = global_position + Vector3(0.0, -0.5, 0.0)
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(crate)
