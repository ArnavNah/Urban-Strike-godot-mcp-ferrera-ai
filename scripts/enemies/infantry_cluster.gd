class_name InfantryCluster
extends CharacterBody3D

## Mobile infantry cluster enemy with a 5-state combat loop:
## APPROACH -> ENGAGE -> ATTACK -> REPOSITION -> ENGAGE
## Features frequent short bursts (4-6 shots), separation steering, and active pursuit.

enum State {
	APPROACH,
	ENGAGE,
	TELEGRAPH,
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
var _stagger_offset: int = 0
var _cached_los: bool = false
var _los_timer: float = 0.0
var _cached_separation: Vector3 = Vector3.ZERO
var _separation_timer: float = 0.0
var _cached_steer_dir: Vector3 = Vector3.ZERO
var _steer_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _is_recovering: bool = false
var _recovery_timer: float = 0.0
var _road_path: PackedVector3Array = PackedVector3Array()
var _road_path_index: int = 0
var _road_path_timer: float = 0.0
var _stuck_sample_timer: float = 0.0
var debug_last_blocked_reason: String = ""
var debug_shots_fired: int = 0

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
	_stagger_offset = randi() % 60

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
	var flat_vec := Vector2(_player.global_position.x - global_position.x, _player.global_position.z - global_position.z)
	var flat_dist := flat_vec.length()

	# Distance-based AI update tiers (NEAR <= 60m: 60Hz, MEDIUM 60-140m: 30Hz staggered, FAR > 140m: 10Hz staggered)
	_lod_frame_counter += 1
	var step_delta := delta
	var frame_stagger := _lod_frame_counter + _stagger_offset
	if dist > 280.0:
		return # LOD 4: Dormant beyond 280m
	elif dist > 140.0:
		if frame_stagger % 6 != 0:
			return # FAR: 10 Hz corridor advance
		step_delta = delta * 6.0
	elif dist > 60.0:
		if frame_stagger % 2 != 0:
			return # MEDIUM: 30 Hz approach
		step_delta = delta * 2.0

	# Phase 10B: Arming timer decay
	if _arming_timer > 0.0:
		_arming_timer -= step_delta

	# Throttled LoS check based on distance tier
	_los_timer -= step_delta
	if _los_timer <= 0.0:
		if dist > 140.0:
			_cached_los = false
			_los_timer = 1.0 # Far tier: no continuous LoS
		elif dist > 60.0:
			_los_timer = 0.45 # Medium tier: check every 0.45s
			_cached_los = _check_los()
		elif dist > 38.0:
			_los_timer = 0.25 # Near-medium: check every 0.25s
			_cached_los = _check_los()
		else:
			_los_timer = 0.15 # Near: check every 0.15s
			_cached_los = _check_los()
	var has_los := _cached_los

	# If player moves far away horizontally or vertically, break out to APPROACH to follow across the city
	if (flat_dist > preferred_range * 1.6 or dist > 55.0) and current_state != State.APPROACH and current_state != State.ATTACK:
		_release_slot()
		_transition_to(State.APPROACH)

	match current_state:
		State.APPROACH:
			_tick_approach(step_delta, flat_dist, dist, has_los)
		State.ENGAGE:
			_tick_engage(step_delta, flat_dist, dist, has_los)
		State.TELEGRAPH:
			_tick_telegraph(step_delta, has_los)
		State.ATTACK:
			_tick_attack(step_delta, has_los)
		State.REPOSITION:
			_tick_reposition(step_delta, flat_dist, dist, has_los)
		State.COOLDOWN:
			_tick_cooldown(step_delta, flat_dist, dist, has_los)

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

func _tick_approach(delta: float, flat_dist: float, dist: float, has_los: bool) -> void:
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
			if to_player.length_squared() > 0.01:
				move_dir = to_player.normalized()
	else:
		var to_player := (_player.global_position - global_position)
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			move_dir = to_player.normalized()

	if _arming_timer <= 0.0 and flat_dist <= preferred_range and has_los and dist <= 50.0:
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
	if move_dir.length_squared() > 0.01 and is_finite(move_dir.x) and is_finite(move_dir.z):
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		if is_finite(target_yaw):
			rotation.y = lerp_angle(rotation.y, target_yaw, 6.0 * delta)

func _tick_engage(delta: float, flat_dist: float, dist: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	# Face player smoothly while lining up burst
	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	if to_player.length_squared() > 0.01 and is_finite(to_player.x) and is_finite(to_player.z):
		var target_yaw := atan2(-to_player.x, -to_player.z)
		if is_finite(target_yaw):
			rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)

	if not has_los or flat_dist > preferred_range * 1.4 or dist > 55.0:
		_release_slot()
		_transition_to(State.APPROACH)
		return

	# If too close horizontally, back up or strafe
	if flat_dist < 6.0:
		_transition_to(State.REPOSITION)
		return

	_state_timer -= delta
	if _state_timer <= 0.0:
		if _request_slot():
			_transition_to(State.TELEGRAPH)
		else:
			_state_timer = 0.25 # Poll slot again soon

func _tick_telegraph(delta: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if not has_los:
		_is_telegraphing = false
		_release_slot()
		_transition_to(State.REPOSITION)
		return

	if is_instance_valid(_player):
		var to_player := (_player.global_position - global_position)
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			var target_yaw := atan2(-to_player.x, -to_player.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)

	_state_timer -= delta
	if _state_timer <= 0.0:
		_is_telegraphing = false
		_transition_to(State.ATTACK)

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

func _tick_reposition(delta: float, flat_dist: float, dist: float, has_los: bool) -> void:
	_state_timer -= delta

	velocity.x = _reposition_dir.x * (move_speed * 0.8)
	velocity.z = _reposition_dir.z * (move_speed * 0.8)

	if _reposition_dir.length_squared() > 0.01:
		var target_yaw := atan2(-_reposition_dir.x, -_reposition_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)

	if _state_timer <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if flat_dist <= preferred_range and has_los and dist <= 50.0:
			_transition_to(State.COOLDOWN)
		else:
			_transition_to(State.APPROACH)

func _tick_cooldown(delta: float, flat_dist: float, dist: float, has_los: bool) -> void:
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
		if flat_dist <= preferred_range * 1.2 and has_los and dist <= 50.0:
			_transition_to(State.ENGAGE)
		else:
			_transition_to(State.APPROACH)

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.APPROACH:
			_state_timer = 0.0
			_is_telegraphing = false
		State.ENGAGE:
			_state_timer = 0.20 # Short prep before requesting slot
			_is_telegraphing = false
		State.TELEGRAPH:
			_state_timer = 0.40 # Restrained 0.4s pre-burst tell
			_is_telegraphing = true
			if is_instance_valid(_player):
				var origin := global_position + Vector3(0, 1.15, 0)
				_snapshot_aim_dir = (_player.global_position - origin).normalized()
		State.ATTACK:
			_shots_left = burst_count
			_burst_timer = 0.0
			_is_telegraphing = false
			if _snapshot_aim_dir.length_squared() < 0.01 and is_instance_valid(_player):
				var origin := global_position + Vector3(0, 1.15, 0)
				_snapshot_aim_dir = (_player.global_position - origin).normalized()
		State.REPOSITION:
			_is_telegraphing = false
			_pick_reposition_dir()
			_state_timer = randf_range(1.0, 1.6)
		State.COOLDOWN:
			_is_telegraphing = false
			_state_timer = reload_time

func _pick_reposition_dir() -> void:
	if not is_instance_valid(_player):
		_reposition_dir = Vector3.FORWARD
		return

	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	var dist := to_player.length()

	if dist < 0.1:
		_reposition_dir = Vector3.FORWARD
		return

	var norm_tp := to_player.normalized()
	if dist < 12.0:
		# Too close: backpedal away
		_reposition_dir = -norm_tp
	else:
		# Flank laterally left or right
		var perp := Vector3(-norm_tp.z, 0.0, norm_tp.x)
		_reposition_dir = (perp if randf() > 0.5 else -perp) + norm_tp * randf_range(-0.3, 0.3)
		if _reposition_dir.length_squared() > 0.01:
			_reposition_dir = _reposition_dir.normalized()
		else:
			_reposition_dir = norm_tp

func _apply_separation() -> void:
	var dist := 0.0
	if is_instance_valid(_player):
		dist = global_position.distance_to(_player.global_position)
	if dist > 140.0:
		return # Far tier: no separation

	_separation_timer -= 0.016667
	if _separation_timer <= 0.0:
		_separation_timer = 0.15 if dist <= 60.0 else 0.25
		var avoidance := Vector3.ZERO
		var search_radius: float = 8.0
		var search_radius_sq := search_radius * search_radius
		var max_candidates: int = 6 if dist <= 60.0 else 4
		var nearby: Array[Node3D] = []

		if EnemyRegistry.instance:
			nearby = EnemyRegistry.instance.get_enemies_in_radius(global_position, search_radius, max_candidates)
		else:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D and e != self:
					nearby.append(e as Node3D)
					if nearby.size() >= max_candidates:
						break

		var count: int = 0
		for other in nearby:
			if other != self and is_instance_valid(other) and not other.is_in_group("air_enemies"):
				var diff := global_position - other.global_position
				diff.y = 0.0
				var d_sq := diff.length_squared()
				if d_sq < search_radius_sq and d_sq > 0.0025:
					var d := sqrt(d_sq)
					var weight: float = (search_radius - d) / search_radius
					avoidance += (diff / d) * weight * 6.0
					count += 1
					if count >= max_candidates:
						break

		if avoidance.length_squared() > 16.0: # 4.0 m/s max lateral push
			avoidance = avoidance.normalized() * 4.0

		_cached_separation = avoidance

	velocity.x += _cached_separation.x
	velocity.z += _cached_separation.z

	var max_h_speed: float = (move_speed * 1.3) if (current_state == State.APPROACH or current_state == State.REPOSITION) else 3.0
	var h_vel := Vector2(velocity.x, velocity.z)
	if h_vel.length() > max_h_speed:
		h_vel = h_vel.normalized() * max_h_speed
		velocity.x = h_vel.x
		velocity.z = h_vel.y

func _steer_around_obstacles(desired_dir: Vector3) -> Vector3:
	if desired_dir.length_squared() < 0.01:
		return desired_dir

	var dist := 0.0
	if is_instance_valid(_player):
		dist = global_position.distance_to(_player.global_position)

	# FAR TIER (> 140m): No obstacle raycasts
	if dist > 140.0:
		return desired_dir

	_steer_timer -= 0.016667
	if _steer_timer > 0.0 and _cached_steer_dir != Vector3.ZERO:
		return _cached_steer_dir

	_steer_timer = 0.2 if dist <= 60.0 else 0.35

	var space := get_world_3d().direct_space_state
	if not space:
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
			_cached_steer_dir = (desired_dir * 0.4 + tangent * 0.6).normalized()
			return _cached_steer_dir

	# Whiskers for lateral corner detection - only checked near player
	if dist <= 60.0:
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
			_cached_steer_dir = desired_dir.rotated(Vector3.UP, deg_to_rad(-25.0)).normalized()
			return _cached_steer_dir
		elif not right_hit.is_empty() and left_hit.is_empty():
			_cached_steer_dir = desired_dir.rotated(Vector3.UP, deg_to_rad(25.0)).normalized()
			return _cached_steer_dir

	_cached_steer_dir = desired_dir
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
		debug_last_blocked_reason = "arming_delay"
		return false

	var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
	if not dir and CombatDirector.instance:
		dir = CombatDirector.instance
	if dir:
		var granted: bool = dir.request_attack_permission(self, CombatDirector.TOKEN_COST_INFANTRY, false, false, false, CombatDirector.DANGER_COST_BULLET, "infantry")
		_has_attack_slot = granted
		debug_last_blocked_reason = "active" if granted else "token_denied"
		return granted
	_has_attack_slot = true
	debug_last_blocked_reason = "active_no_director"
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
	var to_p := (_player.global_position - origin).normalized() if (_player.global_position - origin).length_squared() > 0.01 else -global_transform.basis.z
	var spread := Vector3(randf_range(-0.04, 0.04), randf_range(-0.03, 0.03), randf_range(-0.04, 0.04))
	var aim_dir := (to_p + spread).normalized()

	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance
	var proj: Projectile = null
	if pool:
		var scaled_damage: float = damage_per_shot * CombatDirector.get_damage_multiplier()
		proj = pool.spawn_projectile(origin, aim_dir, false, scaled_damage)

	if proj != null:
		debug_shots_fired += 1
		if VfxPool.instance:
			VfxPool.instance.spawn_muzzle_flash(origin, aim_dir, true)
		if EventBus:
			EventBus.enemy_fired_weapon.emit(self, origin, aim_dir, false)

var _visual_meshes: Array[MeshInstance3D] = []
static var _flash_mat: StandardMaterial3D = null

func _collect_visual_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_visual_meshes.append(child as MeshInstance3D)
		_collect_visual_meshes(child)

func _trigger_damage_flash() -> void:
	if _visual_meshes.is_empty():
		_collect_visual_meshes(self)
	if not _flash_mat:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1.8, 1.8, 1.8, 1.0)
	for m in _visual_meshes:
		if is_instance_valid(m):
			m.material_override = _flash_mat
	if is_inside_tree():
		get_tree().create_timer(0.06, false).timeout.connect(func():
			for m in _visual_meshes:
				if is_instance_valid(m) and m.material_override == _flash_mat:
					m.material_override = null
		)

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return
	current_health = maxf(0.0, current_health - amount)
	_trigger_damage_flash()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 0.8, 0), amount, false)
	if current_health <= 0.0:
		_die()

func _die() -> void:
	if _is_dead or not is_alive:
		return
	_is_dead = true
	is_alive = false
	collision_layer = 0
	collision_mask = 0
	_release_slot()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_destroyed"):
		eb.emit_signal("enemy_destroyed", self, 35)

	_spawn_xp()

	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(global_position + Vector3(0, 0.5, 0), 0.45)
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = global_position + Vector3(0, 0.5, 0)
				expl.scale = Vector3(0.5, 0.5, 0.5)
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(expl)
	queue_free()

func _spawn_xp() -> void:
	if _has_spawned_rewards:
		return
	_has_spawned_rewards = true
	var spawn_pos := global_position + Vector3(0, 0.5, 0)
	if XpGemPool.instance:
		XpGemPool.instance.spawn_gem(spawn_pos, xp_reward)
	else:
		var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
		if xp_scene:
			var gem := xp_scene.instantiate() as Node3D
			if gem:
				if "xp_value" in gem:
					gem.xp_value = xp_reward
				gem.transform.origin = spawn_pos
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(gem)
