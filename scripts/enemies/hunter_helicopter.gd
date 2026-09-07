class_name HunterHelicopter
extends CharacterBody3D

## Hostile air superiority gunship executing fast, committed sweeping strafe runs.
## Matches player altitude in the air for intense same-altitude aerial dogfights.

enum State {
	APPROACH,
	ALIGN,
	COMMIT,
	ATTACK,
	BREAK_AWAY,
	REPOSITION,
	COOLDOWN
}

@export var max_health: float = 50.0
@export var cruise_speed: float = 28.0 # Sweeping air pursuit speed
@export var attack_speed: float = 34.0 # High-speed commit speed
@export var damage_per_shot: float = 2.4
@export var fire_rate: float = 8.0 # RPS during attack window

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
	_pick_approach_waypoint()

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	if main_rotor:
		main_rotor.rotate_y(44.0 * delta)

	# Distance-based AI LOD throttling (Gap 11)
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

	# Keep altitude matched with player in all states
	_match_player_altitude(step_delta)

	match current_state:
		State.APPROACH:
			_update_approach_waypoint()
			var to_wp := _target_waypoint - global_position
			to_wp.y = 0.0
			if to_wp.length() < 8.0 or _state_timer <= 0.0:
				_transition_to(State.ALIGN)
			else:
				_fly_toward(_target_waypoint, cruise_speed, step_delta)
			_state_timer -= step_delta

		State.ALIGN:
			# Face player and check LoS
			_attack_vector = (_player.global_position - global_position)
			_attack_vector.y = 0.0 # Maintain same altitude attack vector
			_attack_vector = _attack_vector.normalized()
			var target_yaw := atan2(-_attack_vector.x, -_attack_vector.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * step_delta)
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				if _request_air_slot():
					_transition_to(State.COMMIT)
				else:
					_state_timer = 0.35 # Wait for air slot

		State.COMMIT:
			# High-speed committed charge pass towards player position at same altitude
			velocity.x = _attack_vector.x * attack_speed
			velocity.z = _attack_vector.z * attack_speed
			move_and_slide()
			var dist_flat := Vector2(global_position.x - _player.global_position.x, global_position.z - _player.global_position.z).length()
			if dist_flat <= 35.0 or _state_timer <= 0.0:
				_transition_to(State.ATTACK)
			_state_timer -= step_delta

		State.ATTACK:
			# Fire chaingun bursts while sweeping past at same altitude
			velocity.x = _attack_vector.x * attack_speed
			velocity.z = _attack_vector.z * attack_speed
			move_and_slide()
			_attack_timer -= step_delta
			_shot_cooldown -= step_delta
			if _shot_cooldown <= 0.0:
				_shot_cooldown = 1.0 / fire_rate
				_fire_pass_shot()

			if _attack_timer <= 0.0:
				_transition_to(State.BREAK_AWAY)

		State.BREAK_AWAY:
			# Peel away laterally at same altitude
			var break_vec := (_attack_vector + Vector3(0.6, 0.0, 0.3)).normalized()
			velocity.x = break_vec.x * cruise_speed
			velocity.z = break_vec.z * cruise_speed
			move_and_slide()
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_release_air_slot()
				_transition_to(State.REPOSITION)

		State.REPOSITION:
			_update_reposition_waypoint()
			var to_wp := _target_waypoint - global_position
			to_wp.y = 0.0
			if to_wp.length() < 10.0 or _state_timer <= 0.0:
				_transition_to(State.COOLDOWN)
			else:
				_fly_toward(_target_waypoint, cruise_speed, step_delta)
			_state_timer -= step_delta

		State.COOLDOWN:
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_pick_approach_waypoint()
				_transition_to(State.APPROACH)

func _match_player_altitude(delta: float) -> void:
	if is_instance_valid(_player):
		var target_y := _player.global_position.y
		global_position.y = move_toward(global_position.y, target_y, 14.0 * delta)
		velocity.y = 0.0

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.APPROACH:
			_state_timer = 3.5
		State.ALIGN:
			_state_timer = 0.5
		State.COMMIT:
			_state_timer = 1.6
		State.ATTACK:
			_attack_timer = 1.2
			_shot_cooldown = 0.0
		State.BREAK_AWAY:
			_state_timer = 1.5
		State.REPOSITION:
			_pick_reposition_waypoint()
			_state_timer = 3.0
		State.COOLDOWN:
			_state_timer = 1.2

func _fly_toward(dest: Vector3, speed: float, delta: float) -> void:
	var to_dest := dest - global_position
	to_dest.y = 0.0
	var dir := to_dest.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	if Vector2(dir.x, dir.z).length_squared() > 0.01:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 4.5 * delta)

func _pick_approach_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0, sin(angle)) * 40.0
	_target_waypoint = _player.global_position + offset
	_target_waypoint.y = _player.global_position.y

func _update_approach_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	_target_waypoint.y = _player.global_position.y

func _pick_reposition_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	var angle := randf() * TAU
	var offset := Vector3(cos(angle), 0, sin(angle)) * 60.0
	_target_waypoint = _player.global_position + offset
	_target_waypoint.y = _player.global_position.y

func _update_reposition_waypoint() -> void:
	if not is_instance_valid(_player):
		return
	_target_waypoint.y = _player.global_position.y

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
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position, amount, amount >= 30.0)
	if current_health <= 0.0:
		_die()

func _die() -> void:
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
	var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
	if xp_scene:
		var gem := xp_scene.instantiate() as Node3D
		if gem:
			gem.transform.origin = global_position
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)
