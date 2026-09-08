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
@export var max_health: float = 75.0
@export var threat_range: float = 55.0
@export var preferred_range: float = 36.0
@export var cannon_damage: float = 12.0 # GDD baseline
@export var aim_prep_time: float = 0.5
@export var charge_time: float = 0.45 # Visible pre-shot tell
@export var reload_time: float = 2.0
@export var move_speed: float = 7.5
@export var is_command_unit: bool = false
@export var escort_leader: Node3D = null
@export var xp_reward: int = 30

var current_health: float = 75.0
var current_state: State = State.REPOSITIONING
var is_alive: bool = true
var is_scattered: bool = false
var _troops_deployed: bool = false

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
	_transition_to(State.REPOSITIONING)
	if charge_light:
		charge_light.visible = false

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

	# Distance-based AI LOD throttling
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

	# If player moves far away, break out of aiming/reloading to pursue across the city
	if dist > threat_range and current_state != State.REPOSITIONING and not is_scattered:
		_release_slot()
		if charge_light:
			charge_light.visible = false
		_start_new_reposition()

	match current_state:
		State.REPOSITIONING:
			_tick_repositioning(step_delta, dist, has_los)
		State.ACQUIRE:
			_tick_acquire(step_delta, dist, has_los)
		State.AIMING:
			_tick_aiming(step_delta, dist, has_los)
		State.CHARGING:
			_tick_charging(step_delta, has_los)
		State.FIRING:
			_tick_firing()
		State.RELOADING:
			_tick_reloading(step_delta, dist, has_los)

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

func _tick_repositioning(delta: float, dist: float, has_los: bool) -> void:
	_state_timer -= delta
	var current_speed: float = move_speed * 1.4 if is_scattered else move_speed

	var move_dir := _reposition_dir
	if not is_scattered:
		# If too far from preferred range, steer toward player
		if dist > preferred_range or not has_los:
			var to_player := (_player.global_position - global_position)
			to_player.y = 0.0
			move_dir = to_player.normalized()

		# Steer around buildings and obstacles
		move_dir = _steer_around_obstacles(move_dir)

	velocity.x = move_dir.x * current_speed
	velocity.z = move_dir.z * current_speed

	# Rotate tank chassis to face movement direction
	if move_dir.length_squared() > 0.01:
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 4.0 * delta)

	# Check for transition into combat engagement
	if not is_scattered and dist <= preferred_range and has_los:
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
		elif dist <= threat_range and has_los:
			if archetype and archetype.weapon_type == GroundEnemyArchetype.WeaponType.TROOP_DEPLOY and not _troops_deployed:
				_deploy_troops()
			_transition_to(State.ACQUIRE)
		else:
			_start_new_reposition()

func _tick_acquire(delta: float, dist: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not has_los or dist > threat_range:
		_start_new_reposition()
		return

	_track_player(delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		if _request_slot():
			_transition_to(State.AIMING)
		else:
			_state_timer = 0.25 # Wait for attack slot

func _tick_aiming(delta: float, dist: float, has_los: bool) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not has_los or dist > threat_range:
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
			GroundEnemyArchetype.WeaponType.RAPID_MG, GroundEnemyArchetype.WeaponType.JAMMER_ECM:
				_fire_rapid_mg()
			GroundEnemyArchetype.WeaponType.ROCKET_BURST:
				_fire_rocket_burst()
			GroundEnemyArchetype.WeaponType.MORTAR_SHELL:
				_fire_mortar_shell()
			GroundEnemyArchetype.WeaponType.TROOP_DEPLOY:
				_deploy_troops()
				_fire_rapid_mg()
	else:
		_fire_cannon()

	_release_slot()
	_transition_to(State.RELOADING)

func _tick_reloading(delta: float, dist: float, has_los: bool) -> void:
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
		if dist <= preferred_range and has_los:
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
		if dist > preferred_range:
			# Advance toward player
			_reposition_dir = to_player.normalized()
		elif dist < 16.0:
			# Too close: back up
			_reposition_dir = -to_player.normalized()
		else:
			# Flank laterally
			var perp := Vector3(-to_player.z, 0, to_player.x).normalized()
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

	if dist < 18.0:
		_reposition_dir = -to_player.normalized() # Back up
	else:
		var perp := Vector3(-to_player.z, 0.0, to_player.x).normalized()
		_reposition_dir = (perp if randf() > 0.5 else -perp) + to_player.normalized() * randf_range(-0.2, 0.2)
		_reposition_dir = _reposition_dir.normalized()

func _apply_separation() -> void:
	var avoidance := Vector3.ZERO
	var search_radius: float = 6.0
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
				avoidance += (diff / d) * weight * 7.0

	velocity.x += avoidance.x
	velocity.z += avoidance.z

func _steer_around_obstacles(desired_dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 1.0, 0.0)
	var forward_check := origin + desired_dir * 5.0
	var query := PhysicsRayQueryParameters3D.create(origin, forward_check, 1) # Layer 1 = World
	var hit := space.intersect_ray(query)

	if hit.is_empty():
		return desired_dir

	var normal: Vector3 = hit.get("normal", Vector3.UP)
	normal.y = 0.0
	if normal.length_squared() > 0.01:
		var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
		if tangent.dot(desired_dir) < 0.0:
			tangent = -tangent
		return (desired_dir * 0.35 + tangent * 0.65).normalized()

	return desired_dir

func _track_player(delta: float) -> void:
	if not is_instance_valid(_player) or not turret or not barrel:
		return
	var target_pos := _player.global_position
	var local_pos := to_local(target_pos)
	var target_yaw := atan2(-local_pos.x, -local_pos.z)
	turret.rotation.y = lerp_angle(turret.rotation.y, target_yaw, 5.0 * delta)

	var local_barrel := turret.to_local(target_pos)
	var flat_dist := Vector2(local_barrel.x, local_barrel.z).length()
	var target_pitch := atan2(local_barrel.y, flat_dist)
	target_pitch = clampf(target_pitch, deg_to_rad(-5.0), deg_to_rad(45.0))
	barrel.rotation.x = lerp_angle(barrel.rotation.x, target_pitch, 5.0 * delta)

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

func _spawn_single_bullet(dmg: float) -> void:
	var muzzle_pos: Vector3 = muzzle.global_position if muzzle else (turret.global_position if turret else global_position + Vector3.UP)
	var fire_dir := -barrel.global_transform.basis.z if barrel else -global_transform.basis.z
	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance
	if pool:
		pool.spawn_projectile(muzzle_pos, fire_dir, false, dmg)
	var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
	if flash_scene:
		var flash := flash_scene.instantiate() as Node3D
		if flash:
			flash.transform.origin = muzzle_pos
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(flash)

func _fire_rocket_burst() -> void:
	var rocket_scene := preload("res://scenes/weapons/unguided_rocket.tscn")
	var count: int = archetype.burst_count if archetype else 3
	for i in range(count):
		if not is_instance_valid(self) or not is_alive or not is_instance_valid(_player):
			return
		var muzzle_pos: Vector3 = muzzle.global_position if muzzle else (turret.global_position if turret else global_position + Vector3.UP)
		var fire_dir := (_player.global_position - muzzle_pos).normalized()
		var spread := Vector3(randf_range(-0.06, 0.06), randf_range(-0.04, 0.04), randf_range(-0.06, 0.06))
		fire_dir = (fire_dir + spread).normalized()
		var rocket: UnguidedRocket = rocket_scene.instantiate() as UnguidedRocket
		if rocket:
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(rocket)
			rocket.call_deferred("launch", muzzle_pos, fire_dir, 42.0)
		if i < count - 1:
			await get_tree().create_timer(0.18).timeout

func _fire_mortar_shell() -> void:
	if not is_instance_valid(_player):
		return
	var target_pos := _player.global_position
	target_pos.y = 0.05

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

	get_tree().create_timer(1.6).timeout.connect(func():
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
					pl.take_damage(20.0, self)
	)

func _deploy_troops() -> void:
	if not _troops_deployed:
		_troops_deployed = true
		var inf_scene := preload("res://scenes/enemies/infantry_cluster.tscn")
		if inf_scene:
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
			var xp_val: int = archetype.xp_reward if archetype else 30
			if "xp_value" in gem:
				gem.xp_value = xp_val
			gem.transform.origin = global_position + Vector3(0, 1.0, 0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)
