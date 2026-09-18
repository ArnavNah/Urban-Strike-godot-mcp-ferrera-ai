class_name Tank
extends CharacterBody3D

## Armored heavy vehicle with rotating turret, pre-fire charge telegraph, and slot lease.
## Implements the shared ground combat loop: APPROACH -> ENGAGE -> ATTACK -> REPOSITION -> ENGAGE
## Features chassis steering, obstacle evasion, neighbor separation, and active player pursuit.

enum State {
	REPOSITIONING,
	ACQUIRE,
	AIMING,
	CHARGING,
	FIRING,
	RELOADING
}

@export var archetype: GroundEnemyArchetype = null
@export var max_health: float = 180.0
@export var threat_range: float = 55.0
@export var preferred_range: float = 36.0
@export var cannon_damage: float = 12.0 # GDD baseline
@export var aim_prep_time: float = 0.5
@export var charge_time: float = 0.9 # Phase 10B: 0.8-1.1s visible pre-shot tell
@export var reload_time: float = 2.0
@export var move_speed: float = 7.5
@export var is_command_unit: bool = false
@export var escort_leader: Node3D = null
@export var xp_reward: int = 16
@export var arming_delay: float = 2.5

var _is_dead: bool = false
var _has_spawned_rewards: bool = false
var current_health: float = 180.0
var current_state: State = State.REPOSITIONING
var is_alive: bool = true
var is_scattered: bool = false
var _troops_deployed: bool = false
var _arming_timer: float = 2.5

var _state_timer: float = 0.0
var _reposition_dir: Vector3 = Vector3.FORWARD
var _reposition_time: float = 2.0
var _scatter_timer: float = 0.0
var _player: Node3D = null
var _has_attack_slot: bool = false
var _escorts: Array[Tank] = []
var _lod_frame_counter: int = 0
var _stagger_offset: int = 0
var _cached_los: bool = false
var _los_timer: float = 0.0
var _cached_separation: Vector3 = Vector3.ZERO
var _separation_timer: float = 0.0
var _cached_steer_dir: Vector3 = Vector3.ZERO
var _steer_timer: float = 0.0
var _last_tank_pos: Vector3 = Vector3.ZERO
var _is_recovering: bool = false
var _recovery_timer: float = 0.0
var _road_path: PackedVector3Array = PackedVector3Array()
var _road_path_index: int = 0
var _road_path_timer: float = 0.0
var _stuck_sample_timer: float = 0.0
var debug_last_blocked_reason: String = ""
var debug_shots_fired: int = 0
var _visual_meshes: Array[MeshInstance3D] = []

@onready var turret: Node3D = get_node_or_null("Body/Turret") if has_node("Body/Turret") else get_node_or_null(NodePath("Turret"))
@onready var barrel: Node3D = (turret.get_node_or_null("Barrel") if turret else null)
@onready var muzzle: Marker3D = (barrel.get_node_or_null("Muzzle") if barrel else null)
@onready var muzzle_left: Marker3D = (barrel.get_node_or_null("MuzzleLeft") if barrel else null)
@onready var muzzle_right: Marker3D = (barrel.get_node_or_null("MuzzleRight") if barrel else null)
@onready var charge_light: OmniLight3D = (barrel.get_node_or_null("ChargeLight") if barrel else null)
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var body_node: Node3D = get_node_or_null("Body")

func _ready() -> void:
	if archetype:
		max_health = archetype.max_health
		threat_range = archetype.threat_range
		preferred_range = archetype.preferred_range
		cannon_damage = archetype.damage_per_shot
		aim_prep_time = archetype.aim_prep_time
		charge_time = archetype.charge_time
		reload_time = archetype.reload_time
		move_speed = archetype.move_speed
		is_command_unit = archetype.is_command_unit
		xp_reward = archetype.xp_reward
		if archetype.is_armored:
			add_to_group("armored_enemies")
		for tag in archetype.formation_tags:
			if not is_in_group(tag):
				add_to_group(tag)
		if archetype.weapon_type == GroundEnemyArchetype.WeaponType.JAMMER_ECM:
			add_to_group("jammers")
	else:
		add_to_group("armored_enemies")

	if not charge_light:
		charge_light = OmniLight3D.new()
		charge_light.name = "ChargeLight"
		charge_light.light_color = Color(1.0, 0.85, 0.2)
		charge_light.omni_range = 6.0
		charge_light.visible = false
		if barrel:
			barrel.add_child(charge_light)
		elif turret:
			turret.add_child(charge_light)
		else:
			add_child(charge_light)

	add_to_group("enemies")

	floor_snap_length = 0.6
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45.0)
	up_direction = Vector3.UP
	if global_position.y > 0.0 and global_position.y <= 1.0:
		global_position.y = 0.0

	_last_tank_pos = global_position
	_stagger_offset = randi() % 60

	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, false)
	current_health = max_health
	_player = get_tree().get_first_node_in_group("player")
	_transition_to(State.REPOSITIONING)
	if charge_light:
		charge_light.visible = false
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)
	_release_slot()
	if is_in_group("jammers"):
		remove_from_group("jammers")

func register_escort(escort: Tank) -> void:
	if escort and not _escorts.has(escort):
		_escorts.append(escort)
		escort.escort_leader = self

func scatter(origin_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return
	is_scattered = true
	_scatter_timer = randf_range(3.0, 4.5)
	_release_slot()
	if charge_light:
		charge_light.visible = false

	var flee_vec: Vector3
	if origin_pos != Vector3.ZERO:
		flee_vec = (global_position - origin_pos)
		flee_vec.y = 0.0
	else:
		flee_vec = Vector3.ZERO

	if flee_vec.length_squared() < 0.1:
		var angle := randf() * TAU
		flee_vec = Vector3(cos(angle), 0.0, sin(angle))
	else:
		var perp := Vector3(-flee_vec.z, 0.0, flee_vec.x).normalized()
		flee_vec = (flee_vec.normalized() + perp * randf_range(-0.6, 0.6)).normalized()

	_reposition_dir = flee_vec
	_reposition_time = _scatter_timer
	_transition_to(State.REPOSITIONING)

func _physics_process(delta: float) -> void:
	if not is_alive or not is_inside_tree():
		return

	if is_scattered:
		_scatter_timer -= delta
		if _scatter_timer <= 0.0:
			is_scattered = false

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
	if dist > 280.0 and not is_scattered:
		return # LOD 4: Dormant beyond 280m
	elif dist > 140.0 and not is_scattered:
		if frame_stagger % 6 != 0:
			return # FAR: 10 Hz corridor approach
		step_delta = delta * 6.0
	elif dist > 60.0 and not is_scattered:
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

	# If player moves far away horizontally or vertically, break out of aiming/reloading to pursue across the city
	if (flat_dist > preferred_range * 1.5 or dist > 70.0) and current_state != State.REPOSITIONING and not is_scattered:
		_release_slot()
		if charge_light:
			charge_light.visible = false
		_start_new_reposition()

	match current_state:
		State.REPOSITIONING:
			_tick_repositioning(step_delta, flat_dist, dist, has_los)
		State.ACQUIRE:
			_tick_acquire(step_delta, flat_dist, dist, has_los)
		State.AIMING:
			_tick_aiming(step_delta, flat_dist, dist, has_los)
		State.CHARGING:
			_tick_charging(step_delta, has_los)
		State.FIRING:
			_tick_firing()
		State.RELOADING:
			_tick_reloading(step_delta, flat_dist, dist, has_los)

	# Ground vehicle separation steering so tanks do not stack
	_apply_separation()

	# Apply gravity and floor snapping so vehicles never float or fly
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = -1.0 # Downward floor snap velocity

	move_and_slide()

	# Hard floor clamp to ensure ground vehicles never float or fall through ground plane
	if global_position.y < 0.0:
		global_position.y = 0.0
		velocity.y = 0.0

	_update_movement_animation(delta)

func _update_movement_animation(_delta: float) -> void:
	if not anim_player:
		return
	var horiz_vel := Vector2(velocity.x, velocity.z).length()
	if horiz_vel > 0.3:
		if anim_player.has_animation("move") and anim_player.current_animation != "move":
			anim_player.play("move")
		var target_speed_scale: float = clampf(horiz_vel / maxf(move_speed, 1.0), 0.6, 2.2)
		anim_player.speed_scale = target_speed_scale
	else:
		if anim_player.has_animation("idle") and anim_player.current_animation != "idle":
			anim_player.play("idle")
		anim_player.speed_scale = 1.0

func _tick_repositioning(delta: float, flat_dist: float, dist: float, has_los: bool) -> void:
	_state_timer -= delta
	var current_speed: float = move_speed * 1.4 if is_scattered else move_speed

	var move_dir := _reposition_dir

	if _is_recovering:
		_recovery_timer -= delta
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
		if move_dir.length_squared() > 0.01:
			var target_yaw := atan2(-move_dir.x, -move_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 4.0 * delta)
		if _recovery_timer <= 0.0:
			_is_recovering = false
			_start_new_reposition()
		return

	if not is_scattered:
		# If far or no LoS, navigate along street network
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
				if to_wp.length() < 7.0:
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
				move_dir = to_player.normalized() if to_player.length_squared() > 0.01 else -global_transform.basis.z
		else:
			# Close range tactical direct pursuit
			var to_player := (_player.global_position - global_position)
			to_player.y = 0.0
			move_dir = to_player.normalized() if to_player.length_squared() > 0.01 else -global_transform.basis.z

		# Steer around buildings and obstacles with whiskers
		move_dir = _steer_around_obstacles(move_dir)

		# Stuck detection (< 1.0m over 2.0s with distant target)
		_stuck_sample_timer += delta
		if _stuck_sample_timer >= 2.0:
			var disp := (global_position - _last_tank_pos).length()
			if disp < 1.0 and dist > 20.0:
				_is_recovering = true
				_recovery_timer = 1.2
				var streamer := get_tree().get_first_node_in_group("city_streamer") as CityWorldStreamer
				if is_instance_valid(streamer):
					var road_pt := streamer.get_nearest_road_point(global_position)
					var to_road := (road_pt - global_position)
					to_road.y = 0.0
					_reposition_dir = to_road.normalized() if to_road.length_squared() > 0.01 else -move_dir
					_road_path = streamer.get_road_path(road_pt, _player.global_position)
					_road_path_index = 0
				else:
					var rev_dir := -move_dir
					var perp := Vector3(-rev_dir.z, 0.0, rev_dir.x)
					_reposition_dir = (rev_dir * 0.5 + (perp if randf() > 0.5 else -perp) * 0.5).normalized()
				move_dir = _reposition_dir
			_last_tank_pos = global_position
			_stuck_sample_timer = 0.0

	velocity.x = move_dir.x * current_speed
	velocity.z = move_dir.z * current_speed

	# Rotate tank chassis to face movement direction
	if move_dir.length_squared() > 0.01:
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 4.0 * delta)

	# Check for transition into combat engagement (healthy standoff distance 14-38m)
	if not is_scattered and _arming_timer <= 0.0 and flat_dist <= preferred_range and flat_dist >= 14.0 and has_los and dist <= 60.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if archetype and archetype.weapon_type == GroundEnemyArchetype.WeaponType.TROOP_DEPLOY and not _troops_deployed:
			_deploy_troops()
		_transition_to(State.ACQUIRE)
		return

	if _state_timer <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_scattered:
			var angle := randf() * TAU
			_reposition_dir = Vector3(cos(angle), 0.0, sin(angle))
			_state_timer = 1.0
		elif not is_scattered and _arming_timer <= 0.0 and flat_dist <= threat_range and flat_dist >= 12.0 and has_los and dist <= 60.0:
			if archetype and archetype.weapon_type == GroundEnemyArchetype.WeaponType.TROOP_DEPLOY and not _troops_deployed:
				_deploy_troops()
			_transition_to(State.ACQUIRE)
		else:
			_start_new_reposition()

func _tick_acquire(delta: float, flat_dist: float, dist: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not has_los or flat_dist > threat_range or flat_dist < 12.0 or dist > 65.0:
		_start_new_reposition()
		return

	_track_player(delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		if _request_slot():
			_transition_to(State.AIMING)
		else:
			_state_timer = 0.25 # Wait for attack slot

func _tick_aiming(delta: float, flat_dist: float, dist: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not has_los or flat_dist > threat_range or dist > 65.0:
		_release_slot()
		_start_new_reposition()
		return

	_track_player(delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_transition_to(State.CHARGING)

func _tick_charging(delta: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not has_los:
		_release_slot()
		if charge_light:
			charge_light.visible = false
		_start_new_reposition()
		return

	_track_player(delta * 0.6)
	_state_timer -= delta
	if charge_light:
		charge_light.visible = true
		charge_light.light_energy = (1.0 - (_state_timer / charge_time)) * 4.0

	if _state_timer <= 0.0:
		_transition_to(State.FIRING)

func _tick_firing() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if charge_light:
		charge_light.visible = false

	if archetype:
		match archetype.weapon_type:
			GroundEnemyArchetype.WeaponType.CANNON:
				_fire_cannon()
				_finish_firing()
			GroundEnemyArchetype.WeaponType.RAPID_MG, GroundEnemyArchetype.WeaponType.JAMMER_ECM:
				_fire_rapid_mg()
			GroundEnemyArchetype.WeaponType.ROCKET_BURST:
				_fire_rocket_burst()
			GroundEnemyArchetype.WeaponType.MORTAR_SHELL:
				_fire_mortar_shell()
				_finish_firing()
			GroundEnemyArchetype.WeaponType.TROOP_DEPLOY:
				_deploy_troops()
				_fire_rapid_mg()
	else:
		_fire_cannon()
		_finish_firing()

func _finish_firing() -> void:
	_release_slot()
	_transition_to(State.RELOADING)

func _tick_reloading(delta: float, flat_dist: float, dist: float, has_los: bool) -> void:
	# Tactical slow creep/strafe while reloading
	if _state_timer > reload_time * 0.4:
		velocity.x = _reposition_dir.x * (move_speed * 0.6)
		velocity.z = _reposition_dir.z * (move_speed * 0.6)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	_track_player(delta * 0.7)
	_state_timer -= delta

	if _state_timer <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if flat_dist <= preferred_range and flat_dist >= 14.0 and has_los and dist <= 60.0:
			_transition_to(State.ACQUIRE)
		else:
			_start_new_reposition()

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.REPOSITIONING:
			_state_timer = _reposition_time
		State.ACQUIRE:
			_state_timer = 0.15
		State.AIMING:
			_state_timer = aim_prep_time
		State.CHARGING:
			_state_timer = charge_time
		State.FIRING:
			pass
		State.RELOADING:
			_state_timer = reload_time
			_pick_tactical_reposition_dir()

func _start_new_reposition() -> void:
	if is_instance_valid(_player):
		var to_player := (_player.global_position - global_position)
		to_player.y = 0.0
		var dist := to_player.length()
		if dist < 0.1:
			_reposition_dir = Vector3.FORWARD
		elif dist > preferred_range:
			# Advance toward player
			_reposition_dir = to_player.normalized()
		elif dist < 16.0:
			# Too close: back up
			_reposition_dir = -to_player.normalized()
		else:
			# Flank laterally
			var norm_tp := to_player.normalized()
			var perp := Vector3(-norm_tp.z, 0.0, norm_tp.x)
			_reposition_dir = perp if randf() > 0.5 else -perp
	else:
		_reposition_dir = Vector3.FORWARD

	_reposition_time = randf_range(1.6, 2.5)
	_transition_to(State.REPOSITIONING)

func _pick_tactical_reposition_dir() -> void:
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
	if dist < 18.0:
		_reposition_dir = -norm_tp # Back up
	else:
		var perp := Vector3(-norm_tp.z, 0.0, norm_tp.x)
		_reposition_dir = (perp if randf() > 0.5 else -perp) + norm_tp * randf_range(-0.2, 0.2)
		if _reposition_dir.length_squared() > 0.01:
			_reposition_dir = _reposition_dir.normalized()
		else:
			_reposition_dir = norm_tp

func _apply_separation() -> void:
	var dist := 0.0
	if is_instance_valid(_player):
		dist = global_position.distance_to(_player.global_position)
	if dist > 140.0 and not is_scattered:
		return # Far tier: minimal or no separation

	_separation_timer -= 0.016667
	if _separation_timer <= 0.0:
		_separation_timer = 0.15 if dist <= 60.0 else 0.25
		var avoidance := Vector3.ZERO
		var search_radius: float = 12.0
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
					avoidance += (diff / d) * weight * 7.0
					count += 1
					if count >= max_candidates:
						break

		if avoidance.length_squared() > 25.0: # 5.0 m/s max lateral push
			avoidance = avoidance.normalized() * 5.0

		_cached_separation = avoidance

	velocity.x += _cached_separation.x
	velocity.z += _cached_separation.z

	var max_h_speed: float = (move_speed * 1.35) if (current_state == State.REPOSITIONING or current_state == State.RELOADING) else 4.0
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
	if dist > 140.0 and not is_scattered:
		return desired_dir

	_steer_timer -= 0.016667
	if _steer_timer > 0.0 and _cached_steer_dir != Vector3.ZERO:
		return _cached_steer_dir

	_steer_timer = 0.2 if dist <= 60.0 else 0.35

	var space := get_world_3d().direct_space_state
	if not space:
		return desired_dir

	var origin := global_position + Vector3(0.0, 1.0, 0.0)
	var forward_check := origin + desired_dir * 5.0
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
			_cached_steer_dir = (desired_dir * 0.35 + tangent * 0.65).normalized()
			return _cached_steer_dir

	# Whiskers for lateral corner avoidance - only checked near player
	if dist <= 60.0:
		var left_dir := desired_dir.rotated(Vector3.UP, deg_to_rad(30.0))
		var right_dir := desired_dir.rotated(Vector3.UP, deg_to_rad(-30.0))

		var left_query := PhysicsRayQueryParameters3D.create(origin, origin + left_dir * 4.2, 1)
		left_query.collide_with_areas = false
		left_query.collide_with_bodies = true
		left_query.exclude = [get_rid()]
		var left_hit := space.intersect_ray(left_query)

		var right_query := PhysicsRayQueryParameters3D.create(origin, origin + right_dir * 4.2, 1)
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

func _track_player(delta: float) -> void:
	if not is_instance_valid(_player) or not turret or not barrel:
		return
	var target_pos := _player.global_position
	var local_pos := to_local(target_pos)
	var target_yaw := atan2(-local_pos.x, -local_pos.z)
	turret.rotation.y = lerp_angle(turret.rotation.y, target_yaw, 5.0 * delta)

	var barrel_origin := barrel.global_position
	var to_target := target_pos - barrel_origin
	var flat_dist := Vector2(to_target.x, to_target.z).length()
	var target_pitch := atan2(to_target.y, flat_dist)
	target_pitch = clampf(target_pitch, deg_to_rad(-5.0), deg_to_rad(55.0))
	barrel.rotation.x = lerp_angle(barrel.rotation.x, target_pitch, 5.0 * delta)

func _fire_cannon() -> void:
	var muzzle_positions: Array[Vector3] = []
	if muzzle_left and muzzle_right:
		muzzle_positions.append(muzzle_left.global_position)
		muzzle_positions.append(muzzle_right.global_position)
	elif muzzle:
		muzzle_positions.append(muzzle.global_position)
	elif turret:
		muzzle_positions.append(turret.global_position)
	else:
		muzzle_positions.append(global_position + Vector3.UP)

	var ref_pos: Vector3 = muzzle_positions[0] if not muzzle_positions.is_empty() else global_position
	var fire_dir: Vector3
	if is_instance_valid(_player):
		var to_player := (_player.global_position - ref_pos).normalized()
		var spread := Vector3(randf_range(-0.02, 0.02), randf_range(-0.015, 0.015), randf_range(-0.02, 0.02))
		fire_dir = (to_player + spread).normalized()
	else:
		fire_dir = (-barrel.global_transform.basis.z if barrel else -global_transform.basis.z).normalized()

	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance

	var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
	var p := get_tree().current_scene if get_tree().current_scene else get_tree().root

	var dmg_mult: float = CombatDirector.get_damage_multiplier()
	var base_dmg: float = cannon_damage / float(muzzle_positions.size()) if muzzle_positions.size() > 1 else cannon_damage
	var dmg_per_shot: float = base_dmg * dmg_mult

	var any_spawned := false
	for m_pos in muzzle_positions:
		var proj: Projectile = null
		if pool:
			proj = pool.spawn_projectile(m_pos, fire_dir, false, dmg_per_shot)
			if proj:
				any_spawned = true
				debug_shots_fired += 1
				if CombatDirector.instance:
					CombatDirector.instance.transfer_danger_to_projectile(self, proj, 2.0)

		if proj != null:
			if VfxPool.instance:
				VfxPool.instance.spawn_muzzle_flash(m_pos, fire_dir, true)
			elif flash_scene and p:
				var flash := flash_scene.instantiate() as Node3D
				if flash:
					flash.transform.origin = m_pos
					flash.scale = Vector3(2.0, 2.0, 2.0)
					p.add_child.call_deferred(flash)

	if any_spawned and EventBus:
		var first_pos := muzzle_positions[0] if not muzzle_positions.is_empty() else global_position
		EventBus.enemy_fired_weapon.emit(self, first_pos, fire_dir, true)

	_trigger_recoil()

func _trigger_recoil() -> void:
	if not barrel:
		return
	var orig_z: float = barrel.position.z
	var tween := create_tween()
	if tween:
		tween.tween_property(barrel, "position:z", orig_z + 0.15, 0.05).set_ease(Tween.EASE_OUT)
		tween.tween_property(barrel, "position:z", orig_z, 0.22).set_ease(Tween.EASE_IN_OUT)

func _fire_rapid_mg() -> void:
	var count: int = archetype.burst_count if archetype else 4
	var interval: float = archetype.burst_interval if archetype else 0.11
	var dmg: float = archetype.damage_per_shot if archetype else 2.5
	for i in range(count):
		if not is_instance_valid(self) or not is_alive:
			return
		_spawn_single_bullet(dmg)
		if i < count - 1:
			await get_tree().create_timer(interval).timeout
	_finish_firing()

func _spawn_single_bullet(dmg: float) -> void:
	var muzzle_pos: Vector3
	if muzzle_left and muzzle_right:
		muzzle_pos = muzzle_left.global_position if randf() > 0.5 else muzzle_right.global_position
	elif muzzle:
		muzzle_pos = muzzle.global_position
	elif turret:
		muzzle_pos = turret.global_position
	else:
		muzzle_pos = global_position + Vector3.UP

	var fire_dir: Vector3
	if is_instance_valid(_player):
		var to_player := (_player.global_position - muzzle_pos).normalized()
		var spread := Vector3(randf_range(-0.03, 0.03), randf_range(-0.02, 0.02), randf_range(-0.03, 0.03))
		fire_dir = (to_player + spread).normalized()
	else:
		fire_dir = (-barrel.global_transform.basis.z if barrel else -global_transform.basis.z).normalized()

	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance
	var proj: Projectile = null
	if pool:
		proj = pool.spawn_projectile(muzzle_pos, fire_dir, false, dmg * CombatDirector.get_damage_multiplier())

	if proj != null:
		debug_shots_fired += 1
		if VfxPool.instance:
			VfxPool.instance.spawn_muzzle_flash(muzzle_pos, fire_dir, true)
		else:
			var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
			if flash_scene:
				var flash := flash_scene.instantiate() as Node3D
				if flash:
					flash.transform.origin = muzzle_pos
					var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
					p.add_child.call_deferred(flash)

		if EventBus:
			EventBus.enemy_fired_weapon.emit(self, muzzle_pos, fire_dir, false)

	_trigger_recoil()

func _fire_rocket_burst() -> void:
	var rocket_scene := preload("res://scenes/weapons/unguided_rocket.tscn")
	var count: int = archetype.burst_count if archetype else 3
	for i in range(count):
		if not is_instance_valid(self) or not is_alive or not is_instance_valid(_player):
			return
		var muzzle_pos: Vector3
		if muzzle_left and muzzle_right:
			muzzle_pos = muzzle_left.global_position if (i % 2 == 0) else muzzle_right.global_position
		elif muzzle:
			muzzle_pos = muzzle.global_position
		elif turret:
			muzzle_pos = turret.global_position
		else:
			muzzle_pos = global_position + Vector3.UP

		var fire_dir := (_player.global_position - muzzle_pos).normalized()
		var spread := Vector3(randf_range(-0.06, 0.06), randf_range(-0.04, 0.04), randf_range(-0.06, 0.06))
		fire_dir = (fire_dir + spread).normalized()
		var rocket: UnguidedRocket = rocket_scene.instantiate() as UnguidedRocket
		if rocket:
			rocket.damage = 16.0 * CombatDirector.get_damage_multiplier()
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(rocket)
			rocket.call_deferred("launch", muzzle_pos, fire_dir, 42.0)
			if CombatDirector.instance and i == 0:
				CombatDirector.instance.transfer_danger_to_projectile(self, rocket, 3.0)
		_trigger_recoil()
		if i < count - 1:
			await get_tree().create_timer(0.18).timeout
	_finish_firing()

func _fire_mortar_shell() -> void:
	if not is_instance_valid(_player):
		return
	var target_pos := _player.global_position
	target_pos.y = 0.05

	# Mortar area denial must not target protected escape sector (Phase 10B rule)
	var sd := get_tree().get_first_node_in_group("spawn_director") as SpawnDirector
	if sd and sd.has_method("get_protected_escape_sectors"):
		var to_tgt := target_pos - _player.global_position
		to_tgt.y = 0.0
		if to_tgt.length_squared() > 1.0:
			var angle := atan2(to_tgt.x, to_tgt.z)
			var sector := int(round(angle / (TAU / 8.0))) % 8
			if sector < 0: sector += 8
			var escape_sectors: Array[int] = sd.get_protected_escape_sectors()
			if escape_sectors.has(sector):
				target_pos += Vector3(-to_tgt.z, 0.0, to_tgt.x).normalized() * 10.0

	var warning_node := Node3D.new()
	var mesh_inst := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 5.5
	cylinder.bottom_radius = 5.5
	cylinder.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.mesh = cylinder
	mesh_inst.material_override = mat
	warning_node.add_child(mesh_inst)
	warning_node.global_position = target_pos

	var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
	p.add_child(warning_node)

	if CombatDirector.instance:
		CombatDirector.instance.transfer_danger_to_projectile(self, warning_node, 2.5)

	get_tree().create_timer(1.6).timeout.connect(func():
		if CombatDirector.instance:
			CombatDirector.instance.release_danger_capacity(warning_node, CombatDirector.DANGER_COST_MORTAR_ZONE)
		if is_instance_valid(warning_node):
			warning_node.queue_free()
		var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
		if flash_scene:
			var flash := flash_scene.instantiate() as Node3D
			if flash:
				flash.transform.origin = target_pos + Vector3.UP * 0.5
				flash.scale = Vector3(5.0, 5.0, 5.0)
				p.add_child.call_deferred(flash)
		var pl := get_tree().get_first_node_in_group("player")
		if is_instance_valid(pl):
			var flat_dist := Vector2(pl.global_position.x - target_pos.x, pl.global_position.z - target_pos.z).length()
			if flat_dist <= 6.5:
				if pl.has_method("take_damage"):
					pl.take_damage(20.0 * CombatDirector.get_damage_multiplier(), self)
	)

func _deploy_troops() -> void:
	if not _troops_deployed:
		_troops_deployed = true
		var inf_scene := load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
		if inf_scene and inf_scene.can_instantiate():
			var squad := inf_scene.instantiate() as Node3D
			if squad:
				var spawn_p: Vector3
				if is_inside_tree():
					spawn_p = global_position + (-global_transform.basis.z * 3.5)
				else:
					spawn_p = position + Vector3(0.0, 0.0, 3.5)
				spawn_p.y = 0.0
				squad.transform.origin = spawn_p
				var p := get_parent() if get_parent() else (get_tree().current_scene if get_tree() and get_tree().current_scene else (get_tree().root if get_tree() else null))
				if p:
					p.add_child.call_deferred(squad)

func _check_los() -> bool:
	if not is_instance_valid(_player):
		return false
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 1.8, 0)
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
		var token_cost: int = CombatDirector.TOKEN_COST_TANK_CANNON
		var is_heavy: bool = true
		var danger_cost: int = CombatDirector.DANGER_COST_CANNON_SHELL
		var attack_name: String = "cannon"

		if archetype:
			match archetype.weapon_type:
				GroundEnemyArchetype.WeaponType.RAPID_MG, GroundEnemyArchetype.WeaponType.JAMMER_ECM:
					token_cost = CombatDirector.TOKEN_COST_INFANTRY
					is_heavy = false
					danger_cost = CombatDirector.DANGER_COST_BULLET
					attack_name = "rapid_mg"
				GroundEnemyArchetype.WeaponType.ROCKET_BURST:
					token_cost = CombatDirector.TOKEN_COST_ROCKET_VOLLEY
					is_heavy = true
					danger_cost = CombatDirector.DANGER_COST_ROCKET
					attack_name = "rocket_volley"
				GroundEnemyArchetype.WeaponType.MORTAR_SHELL:
					token_cost = CombatDirector.TOKEN_COST_MORTAR_STRIKE
					is_heavy = true
					danger_cost = CombatDirector.DANGER_COST_MORTAR_ZONE
					attack_name = "mortar"
				GroundEnemyArchetype.WeaponType.TROOP_DEPLOY:
					token_cost = CombatDirector.TOKEN_COST_INFANTRY
					is_heavy = false
					danger_cost = CombatDirector.DANGER_COST_BULLET
					attack_name = "troop_deploy"

		var granted: bool = dir.request_attack_permission(self, token_cost, false, is_heavy, false, danger_cost, attack_name)
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

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return
	current_health = maxf(0.0, current_health - amount)
	_trigger_damage_flash()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 1.2, 0), amount, false, {"target_id": get_instance_id()})
	if current_health <= 0.0:
		_die()

func _collect_visual_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_visual_meshes.append(child as MeshInstance3D)
		_collect_visual_meshes(child)

func _trigger_damage_flash() -> void:
	if _visual_meshes.is_empty():
		_collect_visual_meshes(self)
	DamageFlashManager.flash_target(self, _visual_meshes)

func _die() -> void:
	if _is_dead or not is_alive:
		return
	_is_dead = true
	is_alive = false
	DamageFlashManager.clear_target(self)
	collision_layer = 0
	collision_mask = 0
	if charge_light:
		charge_light.visible = false
	_release_slot()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("enemy_destroyed"):
			eb.emit_signal("enemy_destroyed", self, 150 if is_command_unit else 80)
		if is_command_unit and eb.has_signal("command_unit_destroyed"):
			eb.emit_signal("command_unit_destroyed", global_position)

	for escort in _escorts:
		if is_instance_valid(escort) and escort != self and escort.is_alive:
			escort.scatter(global_position)
	_escorts.clear()

	if is_inside_tree():
		var group_tanks := get_tree().get_nodes_in_group("enemies")
		for node in group_tanks:
			if node is Tank and node != self and is_instance_valid(node):
				var t := node as Tank
				if t.escort_leader == self and t.is_alive and not t.is_scattered:
					t.scatter(global_position)

	if is_command_unit:
		if eb and eb.has_signal("camera_shake_requested"):
			eb.emit_signal("camera_shake_requested", 0.35)
		var um := get_tree().get_first_node_in_group("upgrade_manager") as UpgradeManager
		if um:
			um.award_requisition(1)
		var crate_scene: PackedScene = preload("res://scenes/pickups/salvage_crate.tscn")
		if crate_scene:
			var crate := crate_scene.instantiate() as Node3D
			if crate:
				crate.transform.origin = global_position + Vector3(0.0, 0.5, 0.0)
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(crate)

	_spawn_xp()

	var expl_scale: float = 2.0 if is_command_unit else 1.4
	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(global_position + Vector3(0, 1.2, 0), expl_scale)
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = global_position + Vector3(0, 1.2, 0)
				expl.scale = Vector3(expl_scale, expl_scale, expl_scale)
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(expl)
	queue_free()

func _spawn_xp() -> void:
	if _has_spawned_rewards:
		return
	_has_spawned_rewards = true
	var xp_val: int = archetype.xp_reward if archetype else xp_reward
	var spawn_pos := global_position + Vector3(0, 1.0, 0)
	if XpGemPool.instance:
		XpGemPool.instance.spawn_gem(spawn_pos, xp_val)
	else:
		var xp_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn") as PackedScene
		if xp_scene:
			var gem := xp_scene.instantiate() as Node3D
			if gem:
				if "xp_value" in gem:
					gem.xp_value = xp_val
				gem.transform.origin = spawn_pos
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(gem)
