class_name HunterHelicopter
extends CharacterBody3D

## Hostile air superiority gunship executing fast, committed sweeping strafe runs.
## Matches player altitude in the air for intense same-altitude aerial dogfights.
## Features dynamic pursuit across the city, neighbor separation, and visual banking.

enum State {
	APPROACH,
	ALIGN,
	COMMIT,
	ATTACK,
	BREAK_AWAY,
	REPOSITION,
	COOLDOWN,
	RECOVER
}

@export var max_health: float = 50.0
@export var cruise_speed: float = 28.0 # Sweeping air pursuit speed
@export var attack_speed: float = 34.0 # High-speed commit speed
@export var damage_per_shot: float = 2.4
@export var fire_rate: float = 8.0 # RPS during attack window
@export var xp_reward: int = 15

var _is_dead: bool = false
var _has_spawned_rewards: bool = false
var current_health: float = 50.0
var current_state: State = State.APPROACH
var is_alive: bool = true

var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _shot_cooldown: float = 0.0
var _target_waypoint: Vector3 = Vector3.ZERO
var _attack_vector: Vector3 = Vector3.FORWARD
var _player: Node3D = null
var _has_air_slot: bool = false
var _lod_frame_counter: int = 0

# Steering physics & 3D altitude banding
var _max_horizontal_accel: float = 26.0 # m/s²
var _stuck_timer: float = 0.0
var _last_stuck_pos: Vector3 = Vector3.ZERO
var _recovery_vector: Vector3 = Vector3.FORWARD
var _ground_ray_timer: float = 0.0
var _cached_ground_y: float = 0.0

@onready var visuals: Node3D = $Visuals
@onready var main_rotor: Node3D = $Visuals/MainRotor

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("air_enemies")
	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, true)
	current_health = max_health
	_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player):
		global_position.y = _player.global_position.y
	_last_stuck_pos = global_position
	_pick_approach_waypoint()

	if visuals and not visuals.has_node("HostileBeacon"):
		var beacon := MeshInstance3D.new()
		beacon.name = "HostileBeacon"
		var sph := SphereMesh.new()
		sph.radius = 0.14
		sph.height = 0.28
		var b_mat := StandardMaterial3D.new()
		b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		b_mat.albedo_color = Color(1.8, 0.2, 0.1, 1.0)
		sph.material = b_mat
		beacon.mesh = sph
		beacon.position = Vector3(0.0, 0.25, -1.4)
		visuals.add_child(beacon)

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)
	_release_air_slot()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	if main_rotor:
		main_rotor.rotate_y(44.0 * delta)

	# Distance-based AI LOD throttling
	var dist := global_position.distance_to(_player.global_position)
	_lod_frame_counter += 1
	var step_delta := delta
	if dist > 140.0:
		return # LOD 3: Culled
	elif dist > 80.0:
		if _lod_frame_counter % 4 != 0:
			return # LOD 2: 15 Hz
		step_delta = delta * 4.0
	elif dist > 40.0:
		if _lod_frame_counter % 2 != 0:
			return # LOD 1: 30 Hz
		step_delta = delta * 2.0

	# Keep altitude matched with player with rooftop clearance
	_match_player_altitude(step_delta)

	var dist_flat := Vector2(global_position.x - _player.global_position.x, global_position.z - _player.global_position.z).length()

	# Safety check: Never hover directly over player or ram
	if dist_flat < 14.0 and current_state != State.BREAK_AWAY and current_state != State.RECOVER:
		_release_air_slot()
		_transition_to(State.BREAK_AWAY)

	# Active pursuit: follow when player travels across city
	if dist_flat > 52.0 and current_state != State.APPROACH and current_state != State.RECOVER:
		_release_air_slot()
		_transition_to(State.APPROACH)

	# Stuck detection
	_check_stuck_condition(step_delta)

	match current_state:
		State.APPROACH:
			_update_approach_waypoint()
			var to_wp := _target_waypoint - global_position
			to_wp.y = 0.0
			if to_wp.length() < 10.0 or _state_timer <= 0.0 or dist_flat <= 32.0:
				_transition_to(State.ALIGN)
			else:
				var spd := cruise_speed * 1.35 if dist_flat > 50.0 else cruise_speed
				_fly_toward(_target_waypoint, spd, step_delta)
			_state_timer -= step_delta

		State.ALIGN:
			# Face player smoothly
			_attack_vector = (_player.global_position - global_position)
			_attack_vector.y = 0.0
			_attack_vector = _attack_vector.normalized()
			var target_yaw := atan2(-_attack_vector.x, -_attack_vector.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(5.0 * step_delta, 0.0, 1.0))
			# Slow slightly while aligning
			velocity.x = move_toward(velocity.x, 0.0, _max_horizontal_accel * step_delta)
			velocity.z = move_toward(velocity.z, 0.0, _max_horizontal_accel * step_delta)
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				if _request_air_slot():
					_transition_to(State.COMMIT)
				else:
					_state_timer = 0.35 # Wait for air slot

		State.COMMIT:
			var target_vec := _steer_around_air_obstacles(_attack_vector)
			velocity.x = move_toward(velocity.x, target_vec.x * attack_speed, _max_horizontal_accel * step_delta)
			velocity.z = move_toward(velocity.z, target_vec.z * attack_speed, _max_horizontal_accel * step_delta)
			if dist_flat <= 35.0 or _state_timer <= 0.0:
				_transition_to(State.ATTACK)
			_state_timer -= step_delta

		State.ATTACK:
			var target_vec := _steer_around_air_obstacles(_attack_vector)
			velocity.x = move_toward(velocity.x, target_vec.x * attack_speed, _max_horizontal_accel * step_delta)
			velocity.z = move_toward(velocity.z, target_vec.z * attack_speed, _max_horizontal_accel * step_delta)
			_attack_timer -= step_delta
			_shot_cooldown -= step_delta
			if _shot_cooldown <= 0.0:
				_shot_cooldown = 1.0 / fire_rate
				_fire_pass_shot()

			if _attack_timer <= 0.0 or dist_flat < 14.0:
				_transition_to(State.BREAK_AWAY)

		State.BREAK_AWAY:
			var break_vec := (_attack_vector + Vector3(0.7, 0.0, 0.35)).normalized()
			break_vec = _steer_around_air_obstacles(break_vec)
			velocity.x = move_toward(velocity.x, break_vec.x * (cruise_speed * 1.15), _max_horizontal_accel * step_delta)
			velocity.z = move_toward(velocity.z, break_vec.z * (cruise_speed * 1.15), _max_horizontal_accel * step_delta)
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_release_air_slot()
				_transition_to(State.REPOSITION)

		State.REPOSITION:
			_update_reposition_waypoint()
			var to_wp := _target_waypoint - global_position
			to_wp.y = 0.0
			if to_wp.length() < 12.0 or _state_timer <= 0.0 or dist_flat > 46.0:
				_transition_to(State.COOLDOWN)
			else:
				_fly_toward(_target_waypoint, cruise_speed, step_delta)
			_state_timer -= step_delta

		State.COOLDOWN:
			velocity.x = move_toward(velocity.x, 0.0, _max_horizontal_accel * step_delta)
			velocity.z = move_toward(velocity.z, 0.0, _max_horizontal_accel * step_delta)
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_pick_approach_waypoint()
				_transition_to(State.APPROACH)

		State.RECOVER:
			_state_timer -= step_delta
			_fly_toward(global_position + _recovery_vector * 25.0, cruise_speed * 1.1, step_delta)
			velocity.y = move_toward(velocity.y, 6.0, 18.0 * step_delta)
			if _state_timer <= 0.0:
				_transition_to(State.REPOSITION)

	# Aircraft separation steering so helicopters never stack
	_apply_separation()

	# Single physics move call per frame
	move_and_slide()

	# Visual banking into turns
	if visuals:
		var horiz_vel := Vector2(velocity.x, velocity.z)
		if horiz_vel.length_squared() > 0.5:
			var target_yaw := atan2(-velocity.x, -velocity.z)
			var yaw_diff := wrapf(target_yaw - rotation.y, -PI, PI)
			visuals.rotation.z = lerp_angle(visuals.rotation.z, clampf(-yaw_diff * 1.5, -deg_to_rad(30.0), deg_to_rad(30.0)), clampf(6.0 * delta, 0.0, 1.0))
		else:
			visuals.rotation.z = lerp_angle(visuals.rotation.z, 0.0, clampf(4.0 * delta, 0.0, 1.0))

func _match_player_altitude(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	_ground_ray_timer -= delta
	if _ground_ray_timer <= 0.0:
		_ground_ray_timer = 0.15
		_cached_ground_y = _query_ground_or_roof_height()

	var target_y := _player.global_position.y
	# Ensure clearance over rooftops
	var min_clearance_y := _cached_ground_y + 4.5
	target_y = maxf(target_y, min_clearance_y)

	var y_diff := target_y - global_position.y
	var target_vy := clampf(y_diff * 3.5, -5.0, 7.0)
	velocity.y = move_toward(velocity.y, target_vy, 18.0 * delta)

func _query_ground_or_roof_height() -> float:
	var space := get_world_3d().direct_space_state
	if not space:
		return 0.0
	var from_pos := global_position + Vector3(0.0, 4.0, 0.0)
	var to_pos := from_pos + Vector3(0.0, -80.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return hit.get("position", Vector3.ZERO).y

func _steer_around_air_obstacles(desired_dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	if not space or desired_dir.length_squared() < 0.01:
		return desired_dir

	var origin := global_position
	var lookahead: float = 16.0
	var target := origin + desired_dir.normalized() * lookahead
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		return desired_dir

	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	normal.y = 0.0
	if normal.length_squared() > 0.01:
		normal = normal.normalized()
		var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
		if tangent.dot(desired_dir) < 0.0:
			tangent = -tangent
		return (desired_dir.normalized() * 0.35 + tangent * 0.65).normalized()

	return desired_dir

func _check_stuck_condition(delta: float) -> void:
	if current_state == State.BREAK_AWAY or current_state == State.RECOVER:
		_stuck_timer = 0.0
		_last_stuck_pos = global_position
		return

	var disp := (global_position - _last_stuck_pos).length()
	if disp < 0.4:
		_stuck_timer += delta
		if _stuck_timer >= 1.8:
			_transition_to(State.RECOVER)
	else:
		_stuck_timer = 0.0
		_last_stuck_pos = global_position

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.APPROACH:
			_state_timer = 3.5
		State.ALIGN:
			_state_timer = 0.4
		State.COMMIT:
			_state_timer = 1.6
		State.ATTACK:
			_attack_timer = 1.2
			_shot_cooldown = 0.0
		State.BREAK_AWAY:
			_state_timer = 1.5
		State.REPOSITION:
			_pick_reposition_waypoint()
			_state_timer = 2.5
		State.COOLDOWN:
			_state_timer = 1.0
		State.RECOVER:
			_state_timer = 1.4
			_stuck_timer = 0.0
			var perp := Vector3(-global_transform.basis.z.z, 0.0, global_transform.basis.z.x)
			if randf() > 0.5:
				perp = -perp
			_recovery_vector = perp.normalized()

func _fly_toward(dest: Vector3, speed: float, delta: float) -> void:
	var to_dest := dest - global_position
	to_dest.y = 0.0
	var dir := to_dest.normalized() if to_dest.length_squared() > 0.01 else Vector3.ZERO
	dir = _steer_around_air_obstacles(dir)
	var target_vel := dir * speed
	velocity.x = move_toward(velocity.x, target_vel.x, _max_horizontal_accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, _max_horizontal_accel * delta)
	if Vector2(dir.x, dir.z).length_squared() > 0.01:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(4.5 * delta, 0.0, 1.0))

func _pick_approach_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	var dir := to_player.normalized() if to_player.length_squared() > 0.01 else Vector3.FORWARD
	_target_waypoint = _player.global_position - dir * 28.0
	_target_waypoint.y = _player.global_position.y

func _update_approach_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	var dir := to_player.normalized() if to_player.length_squared() > 0.01 else Vector3.FORWARD
	_target_waypoint = _player.global_position - dir * 28.0
	_target_waypoint.y = _player.global_position.y

func _pick_reposition_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0, sin(angle)) * 48.0
	_target_waypoint = _player.global_position + offset
	_target_waypoint.y = _player.global_position.y

func _update_reposition_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	_target_waypoint.y = _player.global_position.y

func _apply_separation() -> void:
	var avoidance := Vector3.ZERO
	var search_radius: float = 10.0
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
				avoidance += (diff / d) * weight * 16.0

	avoidance = avoidance.limit_length(16.0)
	velocity.x += avoidance.x
	velocity.z += avoidance.z

	var max_horiz: float = maxf(attack_speed, cruise_speed) * 1.3
	var horiz := Vector2(velocity.x, velocity.z)
	if horiz.length() > max_horiz:
		horiz = horiz.limit_length(max_horiz)
		velocity.x = horiz.x
		velocity.z = horiz.y

func _fire_pass_shot() -> void:
	if not is_instance_valid(_player):
		return
	var muzzle_pos := global_position + Vector3(0, -0.2, -1.0)
	var fire_dir := (_player.global_position - muzzle_pos).normalized()

	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance
	if pool:
		pool.spawn_projectile(muzzle_pos, fire_dir, false, damage_per_shot)

	var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
	if flash_scene:
		var flash := flash_scene.instantiate() as Node3D
		if flash:
			flash.transform.origin = muzzle_pos
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(flash)

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
	_trigger_damage_flash()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position, amount, amount >= 30.0)
	if current_health <= 0.0:
		_die()

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

func _die() -> void:
	if _is_dead or not is_alive:
		return
	_is_dead = true
	is_alive = false
	_release_air_slot()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_destroyed"):
		eb.emit_signal("enemy_destroyed", self, 90)

	_spawn_xp()

	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(global_position)
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = global_position
				expl.scale = Vector3(2.0, 2.0, 2.0)
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
			gem.transform.origin = global_position
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)
