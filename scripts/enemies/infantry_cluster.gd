class_name InfantryCluster
extends StaticBody3D

## Infantry cluster enemy with explicit 4-state combat lifecycle and slot lease.

enum State {
	IDLE,
	ACQUIRE,
	BURST_FIRE,
	COOLDOWN
}

@export var max_health: float = 24.0
@export var threat_range: float = 48.0
@export var burst_count: int = 4
@export var burst_interval: float = 0.14
@export var reload_time: float = 2.2
@export var damage_per_shot: float = 1.2 # GDD baseline

var current_health: float = 24.0
var current_state: State = State.IDLE
var is_alive: bool = true

var _player: Node3D = null
var _state_timer: float = 0.0
var _shots_left: int = 0
var _burst_timer: float = 0.0
var _has_attack_slot: bool = false
var _lod_frame_counter: int = 0
var _cached_los: bool = false
var _los_timer: float = 0.0

@onready var los_ray: RayCast3D = $LOSRayCast

func _ready() -> void:
	add_to_group("enemies")
	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, false)
	current_health = max_health
	_player = get_tree().get_first_node_in_group("player")

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(_player.global_position)

	# Distance-based AI LOD throttling (Gap 11)
	_lod_frame_counter += 1
	var step_delta := delta
	if dist > 120.0:
		return # LOD 3: Culled/Dormant
	elif dist > 65.0:
		if _lod_frame_counter % 4 != 0:
			return # LOD 2: 15 Hz
		step_delta = delta * 4.0
	elif dist > 35.0:
		if _lod_frame_counter % 2 != 0:
			return # LOD 1: 30 Hz
		step_delta = delta * 2.0

	# Throttled LoS check based on LOD
	_los_timer -= step_delta
	if _los_timer <= 0.0:
		_los_timer = 0.1 if dist <= 35.0 else 0.25
		_cached_los = _check_los()
	var has_los := _cached_los

	match current_state:
		State.IDLE:
			if dist <= threat_range and has_los:
				_transition_to(State.ACQUIRE)

		State.ACQUIRE:
			if not has_los or dist > threat_range:
				_release_slot()
				_transition_to(State.IDLE)
				return

			_state_timer -= step_delta
			if _state_timer <= 0.0:
				if _request_slot():
					_transition_to(State.BURST_FIRE)
				else:
					_state_timer = 0.35 # Wait before polling slot again

		State.BURST_FIRE:
			if not has_los:
				_release_slot()
				_transition_to(State.COOLDOWN)
				return

			_burst_timer -= step_delta
			if _burst_timer <= 0.0:
				_burst_timer = burst_interval
				_fire_shot()
				_shots_left -= 1
				if _shots_left <= 0:
					_release_slot()
					_transition_to(State.COOLDOWN)

		State.COOLDOWN:
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_transition_to(State.IDLE)

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.IDLE:
			_state_timer = 0.0
		State.ACQUIRE:
			_state_timer = 0.1
		State.BURST_FIRE:
			_shots_left = burst_count
			_burst_timer = 0.0
		State.COOLDOWN:
			_state_timer = reload_time

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
			gem.transform.origin = global_position + Vector3(0, 0.5, 0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)
