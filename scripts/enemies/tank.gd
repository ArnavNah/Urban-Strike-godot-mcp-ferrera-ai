class_name Tank
extends CharacterBody3D

## Armored heavy vehicle with rotating turret, pre-fire charge telegraph, and slot lease.

enum State {
	REPOSITIONING,
	ACQUIRE,
	AIMING,
	CHARGING,
	FIRING,
	RELOADING
}

@export var max_health: float = 75.0
@export var threat_range: float = 65.0
@export var cannon_damage: float = 12.0 # GDD baseline
@export var aim_prep_time: float = 0.9
@export var charge_time: float = 0.6 # Visible pre-shot tell
@export var reload_time: float = 2.4
@export var move_speed: float = 7.0
@export var is_command_unit: bool = false
@export var escort_leader: Node3D = null

var current_health: float = 75.0
var current_state: State = State.REPOSITIONING
var is_alive: bool = true
var is_scattered: bool = false

var _state_timer: float = 0.0
var _reposition_dir: Vector3 = Vector3.FORWARD
var _reposition_time: float = 2.0
var _scatter_timer: float = 0.0
var _player: Node3D = null
var _has_attack_slot: bool = false
var _escorts: Array[Tank] = []
var _lod_frame_counter: int = 0
var _cached_los: bool = false
var _los_timer: float = 0.0

@onready var turret: Node3D = get_node_or_null("Turret")
@onready var barrel: Node3D = get_node_or_null("Turret/Barrel")
@onready var muzzle: Marker3D = get_node_or_null("Turret/Barrel/Muzzle")
@onready var charge_light: OmniLight3D = get_node_or_null("Turret/Barrel/ChargeLight")

func _ready() -> void:
	add_to_group("armored_enemies")
	add_to_group("enemies")
	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, false)
	current_health = max_health
	_player = get_tree().get_first_node_in_group("player")
	_transition_to(State.REPOSITIONING)
	if charge_light:
		charge_light.visible = false

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

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
	if not is_alive:
		return

	if is_scattered:
		_scatter_timer -= delta
		if _scatter_timer <= 0.0:
			is_scattered = false

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(_player.global_position)

	# Distance-based AI LOD throttling (Gap 11)
	_lod_frame_counter += 1
	var step_delta := delta
	if dist > 130.0 and not is_scattered:
		return # LOD 3: Culled/Dormant
	elif dist > 75.0 and not is_scattered:
		if _lod_frame_counter % 4 != 0:
			return # LOD 2: 15 Hz update
		step_delta = delta * 4.0
	elif dist > 38.0 and not is_scattered:
		if _lod_frame_counter % 2 != 0:
			return # LOD 1: 30 Hz update
		step_delta = delta * 2.0

	# Throttled LoS check based on LOD
	_los_timer -= step_delta
	if _los_timer <= 0.0:
		_los_timer = 0.1 if dist <= 38.0 else 0.25
		_cached_los = _check_los()
	var has_los := _cached_los

	match current_state:
		State.REPOSITIONING:
			_state_timer -= step_delta
			var current_speed: float = move_speed * 1.5 if is_scattered else move_speed
			velocity = _reposition_dir * current_speed
			move_and_slide()
			if _state_timer <= 0.0:
				velocity = Vector3.ZERO
				if is_scattered:
					var angle := randf() * TAU
					_reposition_dir = Vector3(cos(angle), 0.0, sin(angle))
					_state_timer = 1.0
				elif dist <= threat_range and has_los:
					_transition_to(State.ACQUIRE)
				else:
					_start_new_reposition()

		State.ACQUIRE:
			if not has_los or dist > threat_range:
				_start_new_reposition()
				return

			_track_player(step_delta)
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				if _request_slot():
					_transition_to(State.AIMING)
				else:
					_state_timer = 0.35 # Wait for slot

		State.AIMING:
			if not has_los or dist > threat_range:
				_release_slot()
				_start_new_reposition()
				return

			_track_player(step_delta)
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_transition_to(State.CHARGING)

		State.CHARGING:
			if not has_los:
				_release_slot()
				if charge_light:
					charge_light.visible = false
				_start_new_reposition()
				return

			_track_player(step_delta * 0.6)
			_state_timer -= step_delta
			if charge_light:
				charge_light.visible = true
				charge_light.light_energy = (1.0 - (_state_timer / charge_time)) * 4.0

			if _state_timer <= 0.0:
				_transition_to(State.FIRING)

		State.FIRING:
			if charge_light:
				charge_light.visible = false
			_fire_cannon()
			_release_slot()
			_transition_to(State.RELOADING)

		State.RELOADING:
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_start_new_reposition()

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.REPOSITIONING:
			_state_timer = _reposition_time
		State.ACQUIRE:
			_state_timer = 0.2
		State.AIMING:
			_state_timer = aim_prep_time
		State.CHARGING:
			_state_timer = charge_time
		State.FIRING:
			pass
		State.RELOADING:
			_state_timer = reload_time

func _start_new_reposition() -> void:
	if is_instance_valid(_player):
		var to_player := (_player.global_position - global_position)
		to_player.y = 0.0
		var dist := to_player.length()
		if dist > threat_range * 0.85:
			# Move toward player
			_reposition_dir = to_player.normalized()
		else:
			# Flank or reposition laterally
			var perp := Vector3(-to_player.z, 0, to_player.x).normalized()
			_reposition_dir = perp if randf() > 0.5 else -perp
	else:
		_reposition_dir = Vector3.FORWARD

	_reposition_time = randf_range(1.4, 2.5)
	_transition_to(State.REPOSITIONING)

func _track_player(delta: float) -> void:
	if not is_instance_valid(_player) or not turret or not barrel:
		return
	var target_pos := _player.global_position
	var local_pos := to_local(target_pos)
	var target_yaw := atan2(-local_pos.x, -local_pos.z)
	turret.rotation.y = lerp_angle(turret.rotation.y, target_yaw, 4.5 * delta)

	var local_barrel := turret.to_local(target_pos)
	var flat_dist := Vector2(local_barrel.x, local_barrel.z).length()
	var target_pitch := atan2(local_barrel.y, flat_dist)
	target_pitch = clampf(target_pitch, deg_to_rad(-5.0), deg_to_rad(45.0))
	barrel.rotation.x = lerp_angle(barrel.rotation.x, target_pitch, 4.5 * delta)

func _fire_cannon() -> void:
	var muzzle_pos: Vector3 = muzzle.global_position if muzzle else turret.global_position
	var fire_dir := -barrel.global_transform.basis.z

	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance
	if pool:
		pool.spawn_projectile(muzzle_pos, fire_dir, false, cannon_damage)

	var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
	if flash_scene:
		var flash := flash_scene.instantiate() as Node3D
		if flash:
			flash.transform.origin = muzzle_pos
			flash.scale = Vector3(2.0, 2.0, 2.0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(flash)

func _check_los() -> bool:
	if not is_instance_valid(_player):
		return false
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 1.8, 0)
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

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return
	current_health = maxf(0.0, current_health - amount)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 1.2, 0), amount, amount >= 30.0)
	if current_health <= 0.0:
		_die()

func _die() -> void:
	is_alive = false
	_release_slot()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("enemy_destroyed"):
			eb.emit_signal("enemy_destroyed", self, 150 if is_command_unit else 80)
		if is_command_unit and eb.has_signal("command_unit_destroyed"):
			eb.emit_signal("command_unit_destroyed", global_position)

	# Scatter all registered escorts
	for escort in _escorts:
		if is_instance_valid(escort) and escort != self and escort.is_alive:
			escort.scatter(global_position)
	_escorts.clear()

	# Also scatter any nearby tanks that had this as their escort_leader
	if is_inside_tree():
		var group_tanks := get_tree().get_nodes_in_group("enemies")
		for node in group_tanks:
			if node is Tank and node != self and is_instance_valid(node):
				var t := node as Tank
				if t.escort_leader == self and t.is_alive and not t.is_scattered:
					t.scatter(global_position)

	if is_command_unit:
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

	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(global_position + Vector3(0, 1.2, 0))
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = global_position + Vector3(0, 1.2, 0)
				expl.scale = Vector3(2.2, 2.2, 2.2)
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(expl)
	queue_free()

func _spawn_xp() -> void:
	var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
	if xp_scene:
		var gem := xp_scene.instantiate() as Node3D
		if gem:
			gem.transform.origin = global_position + Vector3(0, 1.0, 0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)
