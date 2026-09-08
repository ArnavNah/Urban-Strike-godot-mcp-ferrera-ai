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

@export var max_health: float = 24.0
@export var move_speed: float = 5.5
@export var preferred_range: float = 22.0
@export var threat_range: float = 34.0
@export var burst_count: int = 5
@export var burst_interval: float = 0.11
@export var reload_time: float = 1.3
@export var damage_per_shot: float = 1.2 # GDD baseline
@export var xp_reward: int = 6

var current_health: float = 24.0
var current_state: State = State.APPROACH
var is_alive: bool = true

var _player: Node3D = null
var _state_timer: float = 0.0
var _shots_left: int = 0
var _burst_timer: float = 0.0
var _reposition_dir: Vector3 = Vector3.ZERO
var _has_attack_slot: bool = false
var _lod_frame_counter: int = 0
var _cached_los: bool = false
var _los_timer: float = 0.0

@onready var los_ray: RayCast3D = get_node_or_null("LOSRayCast")

func _ready() -> void:
	add_to_group("enemies")
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(45.0)
	up_direction = Vector3.UP
	if global_position.y > 0.0 and global_position.y <= 1.0:
		global_position.y = 0.0

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
	if dist > 130.0:
		return # LOD 3: Culled
	elif dist > 70.0:
		if _lod_frame_counter % 4 != 0:
			return # LOD 2: 15 Hz
		step_delta = delta * 4.0
	elif dist > 38.0:
		if _lod_frame_counter % 2 != 0:
			return # LOD 1: 30 Hz
		step_delta = delta * 2.0

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
	var to_player := (_player.global_position - global_position)
	to_player.y = 0.0
	var dir := to_player.normalized()

	if dist <= preferred_range and has_los:
		velocity.x = 0.0
		velocity.z = 0.0
		_transition_to(State.ENGAGE)
		return

	# Obstacle avoidance steering
	var move_dir := _steer_around_obstacles(dir)
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
	var origin := global_position + Vector3(0.0, 0.6, 0.0)
	var forward_check := origin + desired_dir * 3.5
	var query := PhysicsRayQueryParameters3D.create(origin, forward_check, 1) # Layer 1 = World
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		return desired_dir

	# Steer left or right of the obstacle normal
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	normal.y = 0.0
	if normal.length_squared() > 0.01:
		var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
		if tangent.dot(desired_dir) < 0.0:
			tangent = -tangent
		return (desired_dir * 0.4 + tangent * 0.6).normalized()

	return desired_dir

func _check_los() -> bool:
	if not is_instance_valid(_player):
		return false
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 0.8, 0)
	var target_pos := _player.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, target_pos, 1) # Layer 1 = World
	var hit := space.intersect_ray(query)
	return hit.is_empty()

func _request_slot() -> bool:
	var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
	if not dir and CombatDirector.instance:
		dir = CombatDirector.instance
	if dir:
		var granted: bool = dir.request_attack_slot(self, false)
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
			dir.release_attack_slot(self, false)
	_has_attack_slot = false

func _fire_shot() -> void:
	if not is_instance_valid(_player):
		return
	var origin := global_position + Vector3(0, 1.0, 0)
	var aim_dir := (_player.global_position - origin).normalized()
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
	var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
	if xp_scene:
		var gem := xp_scene.instantiate() as Node3D
		if gem:
			if "xp_value" in gem:
				gem.xp_value = xp_reward
			gem.transform.origin = global_position + Vector3(0, 0.5, 0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)
