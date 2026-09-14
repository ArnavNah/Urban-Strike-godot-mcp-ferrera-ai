class_name InfantryCluster
extends CharacterBody3D

## Mobile infantry cluster enemy with a 5-state combat loop:
## APPROACH -> ENGAGE -> ATTACK -> REPOSITION -> ENGAGE
## Features frequent short bursts (4-6 shots), separation steering, and active pursuit.

enum State {
	APPROACH,
	ENGAGE,
	ATTACK,
	REPOSITION,
	COOLDOWN
}

@export var max_health: float = 12.0
@export var move_speed: float = 5.5
@export var preferred_range: float = 22.0
@export var threat_range: float = 34.0
@export var burst_count: int = 5
@export var burst_interval: float = 0.11
@export var reload_time: float = 1.3
@export var damage_per_shot: float = 1.2 # GDD baseline
@export var xp_reward: int = 3
@export var visual_crowd_weight: int = 4
@export var arming_delay: float = 1.5

var _is_dead: bool = false
var _has_spawned_rewards: bool = false
var current_health: float = 12.0
var current_state: State = State.APPROACH
var is_alive: bool = true
var _arming_timer: float = 1.5
@warning_ignore("unused_private_class_variable")
var _is_telegraphing: bool = false
var _snapshot_aim_dir: Vector3 = Vector3.ZERO

var _player: Node3D = null
var _state_timer: float = 0.0
var _shots_left: int = 0
var _burst_timer: float = 0.0
var _reposition_dir: Vector3 = Vector3.ZERO
var _has_attack_slot: bool = false
var _lod_frame_counter: int = 0
var _cached_los: bool = false
var _los_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _is_recovering: bool = false
var _recovery_timer: float = 0.0
var _road_path: PackedVector3Array = PackedVector3Array()
var _road_path_index: int = 0
var _road_path_timer: float = 0.0
var _stuck_sample_timer: float = 0.0

@onready var los_ray: RayCast3D = get_node_or_null("LOSRayCast")

func _ready() -> void:
	add_to_group("enemies")
	floor_snap_length = 0.6
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45.0)
	up_direction = Vector3.UP
	if global_position.y > 0.0 and global_position.y <= 1.0:
		global_position.y = 0.0

	_last_pos = global_position

	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, false)
	current_health = max_health
	_player = get_tree().get_first_node_in_group("player")
	_transition_to(State.APPROACH)

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)
	_release_slot()

func _physics_process(delta: float) -> void:
	if not is_alive or not is_inside_tree():
		return

	if not is_instance_valid(_player):
		if is_inside_tree() and get_tree():
			_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			# Apply gravity and floor snap even if player not yet present
			if not is_on_floor():
				velocity.y -= 25.0 * delta
			else:
				velocity.y = -1.0
			move_and_slide()
			if global_position.y < 0.0:
				global_position.y = 0.0
				velocity.y = 0.0
			return

	var dist := global_position.distance_to(_player.global_position)

	# Distance-based AI LOD throttling
	_lod_frame_counter += 1
	var step_delta := delta
	if dist > 280.0:
		return # LOD 4: Dormant beyond 280m
	elif dist > 120.0:
		if _lod_frame_counter % 8 != 0:
			return # LOD 3: 7.5 Hz distant corridor advance
		step_delta = delta * 8.0
	elif dist > 60.0:
		if _lod_frame_counter % 3 != 0:
			return # LOD 2: 20 Hz medium approach
		step_delta = delta * 3.0

	# Phase 10B: Arming timer decay
	if _arming_timer > 0.0:
		_arming_timer -= step_delta

	# Throttled LoS check based on LOD
	_los_timer -= step_delta
	if _los_timer <= 0.0:
		_los_timer = 0.1 if dist <= 38.0 else 0.25
		_cached_los = _check_los()
	var has_los := _cached_los

	# If player moves far away, break out to APPROACH to follow across the city
	if dist > threat_range * 1.15 and current_state != State.APPROACH and current_state != State.ATTACK:
		_release_slot()
		_transition_to(State.APPROACH)

	match current_state:
		State.APPROACH:
			_tick_approach(step_delta, dist, has_los)
		State.ENGAGE:
			_tick_engage(step_delta, dist, has_los)
		State.ATTACK:
			_tick_attack(step_delta, has_los)
		State.REPOSITION:
			_tick_reposition(step_delta, dist, has_los)
		State.COOLDOWN:
			_tick_cooldown(step_delta, dist, has_los)

	# Lightweight ground separation steering to prevent clumping
	_apply_separation()

	# Apply gravity and floor snap so infantry stays firmly grounded
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = -1.0 # Downward floor snap velocity

	move_and_slide()

	# Safety ground clamp: infantry can never fall below ground or float if disconnected
	if global_position.y < 0.0:
		global_position.y = 0.0
		velocity.y = 0.0

func _tick_approach(delta: float, dist: float, has_los: bool) -> void:
	if _is_recovering:
		_recovery_timer -= delta
		velocity.x = _reposition_dir.x * move_speed
		velocity.z = _reposition_dir.z * move_speed
		if _reposition_dir.length_squared() > 0.01:
			var target_yaw := atan2(-_reposition_dir.x, -_reposition_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 6.0 * delta)
		if _recovery_timer <= 0.0:
			_is_recovering = false
		return

	var move_dir := Vector3.FORWARD

	if dist > 35.0 or not has_los:
		_road_path_timer -= delta
		if _road_path_timer <= 0.0 or _road_path.is_empty():
			_road_path_timer = randf_range(1.5, 2.5)
			var streamer := get_tree().get_first_node_in_group("city_streamer") as CityWorldStreamer
			if is_instance_valid(streamer):
				_road_path = streamer.get_road_path(global_position, _player.global_position)
				_road_path_index = 0

		if not _road_path.is_empty() and _road_path_index < _road_path.size():
			var wp := _road_path[_road_path_index]
			var to_wp := (wp - global_position)
			to_wp.y = 0.0
			if to_wp.length() < 6.0:
				_road_path_index += 1
				if _road_path_index < _road_path.size():
					wp = _road_path[_road_path_index]
					to_wp = (wp - global_position)
					to_wp.y = 0.0
			if to_wp.length_squared() > 0.1:
				move_dir = to_wp.normalized()
		else:
			var to_player := (_player.global_position - global_position)
			to_player.y = 0.0
			move_dir = to_player.normalized()
	else:
		var to_player := (_player.global_position - global_position)
		to_player.y = 0.0
		move_dir = to_player.normalized()

	if _arming_timer <= 0.0 and dist <= preferred_range and has_los:
		velocity.x = 0.0
		velocity.z = 0.0
		_transition_to(State.ENGAGE)
		return

	# Obstacle avoidance steering
	move_dir = _steer_around_obstacles(move_dir)

	# Stuck detection (< 1.0m over 2.0s with distant target)
	_stuck_sample_timer += delta
	if _stuck_sample_timer >= 2.0:
		var disp := (global_position - _last_pos).length()
		if disp < 1.0 and dist > 20.0:
			_is_recovering = true
			_recovery_timer = 1.0
			var streamer := get_tree().get_first_node_in_group("city_streamer") as CityWorldStreamer
			if is_instance_valid(streamer):
				var road_pt := streamer.get_nearest_road_point(global_position)
				var to_road := (road_pt - global_position)
				to_road.y = 0.0
				_reposition_dir = to_road.normalized() if to_road.length_squared() > 0.01 else -move_dir
				_road_path = streamer.get_road_path(road_pt, _player.global_position)
				_road_path_index = 0
			else:
				var rev := -move_dir
				var perp := Vector3(-rev.z, 0.0, rev.x)
				_reposition_dir = (rev * 0.5 + (perp if randf() > 0.5 else -perp) * 0.5).normalized()
			move_dir = _reposition_dir
		_last_pos = global_position
		_stuck_sample_timer = 0.0

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	# Face movement direction
	if move_dir.length_squared() > 0.01:
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 6.0 * delta)

func _tick_engage(delta: float, dist: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	# Face player smoothly while lining up burst
	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		var target_yaw := atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)

	if not has_los or dist > threat_range:
		_release_slot()
		_transition_to(State.APPROACH)
		return

	# If too close, back up or strafe
	if dist < 10.0:
		_transition_to(State.REPOSITION)
		return

	_state_timer -= delta
	if _state_timer <= 0.0:
		if _request_slot():
			_transition_to(State.ATTACK)
		else:
			_state_timer = 0.25 # Poll slot again soon

func _tick_attack(delta: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if not has_los:
		_release_slot()
		_transition_to(State.REPOSITION)
		return

	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_burst_timer = burst_interval
		_fire_shot()
		_shots_left -= 1
		if _shots_left <= 0:
			_release_slot()
			_transition_to(State.REPOSITION)

func _tick_reposition(delta: float, dist: float, has_los: bool) -> void:
	_state_timer -= delta

	velocity.x = _reposition_dir.x * (move_speed * 0.8)
	velocity.z = _reposition_dir.z * (move_speed * 0.8)

	if _reposition_dir.length_squared() > 0.01:
		var target_yaw := atan2(-_reposition_dir.x, -_reposition_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)

	if _state_timer <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if dist <= preferred_range and has_los:
			_transition_to(State.COOLDOWN)
		else:
			_transition_to(State.APPROACH)

func _tick_cooldown(delta: float, dist: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_state_timer -= delta

	# Track player during cooldown
	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		var target_yaw := atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)

	if _state_timer <= 0.0:
		if dist <= threat_range and has_los:
			_transition_to(State.ENGAGE)
		else:
			_transition_to(State.APPROACH)

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.APPROACH:
			_state_timer = 0.0
		State.ENGAGE:
			_state_timer = 0.25 # Short prep before requesting slot
		State.ATTACK:
			_shots_left = burst_count
			_burst_timer = 0.0
			if is_instance_valid(_player):
				var origin := global_position + Vector3(0, 1.15, 0)
				_snapshot_aim_dir = (_player.global_position - origin).normalized()
		State.REPOSITION:
			_pick_reposition_dir()
			_state_timer = randf_range(1.0, 1.6)
		State.COOLDOWN:
			_state_timer = reload_time

func _pick_reposition_dir() -> void:
	if not is_instance_valid(_player):
		_reposition_dir = Vector3.FORWARD
		return

	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	var dist := to_player.length()

	if dist < 12.0:
		# Too close: backpedal away
		_reposition_dir = -to_player.normalized()
	else:
		# Flank laterally left or right
		var perp := Vector3(-to_player.z, 0.0, to_player.x).normalized()
		_reposition_dir = (perp if randf() > 0.5 else -perp) + to_player.normalized() * randf_range(-0.3, 0.3)
		_reposition_dir = _reposition_dir.normalized()

func _apply_separation() -> void:
	var avoidance := Vector3.ZERO
	var search_radius: float = 4.0
	var nearby: Array[Node3D] = []

	if EnemyRegistry.instance:
		nearby = EnemyRegistry.instance.get_enemies_in_radius(global_position, search_radius)
	else:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node3D and e != self:
				nearby.append(e as Node3D)

	for other in nearby:
		if other != self and is_instance_valid(other) and not other.is_in_group("air_enemies"):
			var diff := global_position - other.global_position
			diff.y = 0.0
			var d := diff.length()
			if d < search_radius and d > 0.05:
				var weight: float = (search_radius - d) / search_radius
				avoidance += (diff / d) * weight * 6.0

	velocity.x += avoidance.x
	velocity.z += avoidance.z

func _steer_around_obstacles(desired_dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if not space or desired_dir.length_squared() < 0.01:
		return desired_dir

	var origin := global_position + Vector3(0.0, 0.6, 0.0)
	var forward_check := origin + desired_dir * 3.5
	var query := PhysicsRayQueryParameters3D.create(origin, forward_check, 1) # Layer 1 = World
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)

	if not hit.is_empty():
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		normal.y = 0.0
		if normal.length_squared() > 0.01:
			var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
			if tangent.dot(desired_dir) < 0.0:
				tangent = -tangent
			return (desired_dir * 0.4 + tangent * 0.6).normalized()

	# Whiskers for lateral corner detection
	var left_dir := desired_dir.rotated(Vector3.UP, deg_to_rad(30.0))
	var right_dir := desired_dir.rotated(Vector3.UP, deg_to_rad(-30.0))

	var left_query := PhysicsRayQueryParameters3D.create(origin, origin + left_dir * 2.8, 1)
	left_query.collide_with_areas = false
	left_query.collide_with_bodies = true
	left_query.exclude = [get_rid()]
	var left_hit := space.intersect_ray(left_query)

	var right_query := PhysicsRayQueryParameters3D.create(origin, origin + right_dir * 2.8, 1)
	right_query.collide_with_areas = false
	right_query.collide_with_bodies = true
	right_query.exclude = [get_rid()]
	var right_hit := space.intersect_ray(right_query)

	if not left_hit.is_empty() and right_hit.is_empty():
		return desired_dir.rotated(Vector3.UP, deg_to_rad(-25.0)).normalized()
	elif not right_hit.is_empty() and left_hit.is_empty():
		return desired_dir.rotated(Vector3.UP, deg_to_rad(25.0)).normalized()

	return desired_dir

func _check_los() -> bool:
	if not is_instance_valid(_player):
		return false
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.8, 0)
	var target_pos := _player.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, target_pos, 1) # Layer 1 = World
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit.is_empty()

func _request_slot() -> bool:
	if _arming_timer > 0.0:
		return false

	# Phase 10B: No silent offscreen attacks
	var cam := get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() else null
	if cam and not cam.is_position_in_frustum(global_position):
		return false

	var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
	if not dir and CombatDirector.instance:
		dir = CombatDirector.instance
	if dir:
		var granted: bool = dir.request_attack_permission(self, CombatDirector.TOKEN_COST_INFANTRY, false, false, false, CombatDirector.DANGER_COST_BULLET, "infantry")
		_has_attack_slot = granted
		return granted
	_has_attack_slot = true
	return true

func _release_slot() -> void:
	if _has_attack_slot:
		var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
		if not dir and CombatDirector.instance:
			dir = CombatDirector.instance
		if dir:
			dir.release_attack_permission(self)
	_has_attack_slot = false

func _fire_shot() -> void:
	if not is_instance_valid(_player):
		return
	var origin := global_position + Vector3(0, 1.15, 0)
	var aim_dir := _snapshot_aim_dir
	if aim_dir.length_squared() < 0.01:
		aim_dir = (_player.global_position - origin).normalized()
	aim_dir += Vector3(randf_range(-0.12, 0.12), randf_range(-0.08, 0.08), randf_range(-0.12, 0.12))
	aim_dir = aim_dir.normalized()

	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance
	if pool:
		pool.spawn_projectile(origin, aim_dir, false, damage_per_shot)

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return
	current_health = maxf(0.0, current_health - amount)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 0.8, 0), amount, amount >= 30.0)
	if current_health <= 0.0:
		_die()

func _die() -> void:
	if _is_dead or not is_alive:
		return
	_is_dead = true
	is_alive = false
	_release_slot()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_destroyed"):
		eb.emit_signal("enemy_destroyed", self, 35)

	_spawn_xp()

	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(global_position + Vector3(0, 0.5, 0))
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = global_position + Vector3(0, 0.5, 0)
				expl.scale = Vector3(0.8, 0.8, 0.8)
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(expl)
	queue_free()

func _spawn_xp() -> void:
	if _has_spawned_rewards:
		return
	_has_spawned_rewards = true
	var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
	if xp_scene:
		var gem := xp_scene.instantiate() as Node3D
		if gem:
			if "xp_value" in gem:
				gem.xp_value = xp_reward
			gem.transform.origin = global_position + Vector3(0, 0.5, 0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)
