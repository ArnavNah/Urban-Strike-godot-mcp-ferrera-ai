class_name Projectile
extends Node3D

## High-speed ballistic projectile with continuous ray sweep collision.

@export var speed: float = 140.0
@export var damage: float = 6.0
@export var max_lifetime: float = 1.6

var _direction: Vector3 = Vector3.FORWARD
var _lifetime: float = 0.0
var _is_active: bool = false
var _is_player_projectile: bool = true
var armored_damage_multiplier: float = 1.0
var air_damage_multiplier: float = 1.0
var ground_damage_multiplier: float = 1.0
var enemy_hit_limit: int = 1
var _hit_target_ids: Array[int] = []
var pierce_remaining: int = 0
var ricochet_remaining: int = 0
var armor_damage_multiplier: float = 1.0
var has_danger_reservation: bool = false
var weapon_source: String = "chaingun"
var shooter_node: Node = null
var has_hit_target: bool = false

static var _player_mat: StandardMaterial3D = null
static var _enemy_mat: StandardMaterial3D = null

@onready var raycast: RayCast3D = $RayCast3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

signal hit_occurred(pos: Vector3, normal: Vector3)

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	visible = false
	if raycast:
		raycast.enabled = false

func launch(start_pos: Vector3, dir: Vector3, from_player: bool = true, proj_damage: float = 6.0, pierce_count: int = 0, ricochet_count: int = 0, armor_mult: float = 1.0, weapon_src: String = "chaingun", shooter: Node = null) -> void:
	global_position = start_pos
	_direction = dir.normalized()
	_is_player_projectile = from_player
	damage = proj_damage
	weapon_source = weapon_src
	shooter_node = shooter
	has_hit_target = false
	# A pooled round starts with neutral upgrade state on every launch.
	armored_damage_multiplier = 1.0
	air_damage_multiplier = 1.0
	ground_damage_multiplier = 1.0
	enemy_hit_limit = 1
	_hit_target_ids.clear()
	pierce_remaining = pierce_count
	ricochet_remaining = ricochet_count
	armor_damage_multiplier = armor_mult
	has_danger_reservation = false
	_lifetime = 0.0
	_is_active = true
	visible = true
	set_process(true)

	if not _player_mat:
		_player_mat = StandardMaterial3D.new()
		_player_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_player_mat.albedo_color = Color(1.8, 1.6, 0.55, 1.0)
		_player_mat.emission_enabled = true
		_player_mat.emission = Color(1.0, 0.90, 0.30, 1.0)
		_player_mat.emission_energy_multiplier = 3.0
	if not _enemy_mat:
		_enemy_mat = StandardMaterial3D.new()
		_enemy_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_enemy_mat.albedo_color = Color(2.4, 0.75, 0.18, 1.0)
		_enemy_mat.emission_enabled = true
		_enemy_mat.emission = Color(1.0, 0.28, 0.05, 1.0)
		_enemy_mat.emission_energy_multiplier = 4.0

	if _is_player_projectile:
		speed = 150.0
		if mesh_instance:
			mesh_instance.material_override = _player_mat
			mesh_instance.scale = Vector3(1.0, 1.0, 1.8)
	else:
		speed = 68.0 # High-readability dodgeable bullet speed
		if mesh_instance:
			mesh_instance.material_override = _enemy_mat
			mesh_instance.scale = Vector3(1.35, 1.35, 2.5)

	# Safe look_at without gimbal lock crashes on steep vertical shots
	if _direction.length_squared() > 0.001:
		var up_axis := Vector3.UP if absf(_direction.y) < 0.9 else Vector3.FORWARD
		look_at(global_position + _direction, up_axis)

	if raycast:
		raycast.clear_exceptions()
		if _is_player_projectile:
			# Player bullets hit World (Layer 1) and Enemies (Layer 3)
			raycast.collision_mask = (1 << 0) | (1 << 2)
			var player: CollisionObject3D = PlayerHelicopter.instance if is_instance_valid(PlayerHelicopter.instance) else (get_tree().get_first_node_in_group("player") as CollisionObject3D)
			if player:
				raycast.add_exception(player)
		else:
			# Enemy bullets hit World (Layer 1) and Player (Layer 2)
			raycast.collision_mask = (1 << 0) | (1 << 1)
			if is_instance_valid(shooter_node) and shooter_node is CollisionObject3D:
				raycast.add_exception(shooter_node as CollisionObject3D)
		raycast.enabled = true
		raycast.target_position = Vector3(0, 0, -speed * (1.0 / 60.0) * 1.5)

func _process(delta: float) -> void:
	if not _is_active:
		return

	_lifetime += delta
	if _lifetime >= max_lifetime:
		deactivate()
		return

	var step_dist: float = speed * delta
	var step_vec: Vector3 = _direction * step_dist

	# Continuous raycast sweep over the frame movement segment
	if raycast:
		raycast.target_position = raycast.to_local(global_position + step_vec * 1.2)
		# Resweep the same segment after excluding a pierced collider. This catches
		# a second enemy or intervening wall even within one large frame step.
		for sweep_index in range(8):
			raycast.force_raycast_update()
			if not raycast.is_colliding():
				global_position += step_vec
				return
			var hit_collider: Object = raycast.get_collider()
			var hit_pos: Vector3 = raycast.get_collision_point()
			var hit_norm: Vector3 = raycast.get_collision_normal()
			_handle_hit(hit_collider, hit_pos, hit_norm)
			if not _is_active or enemy_hit_limit <= 1:
				return # Preserve the existing non-Siege ricochet/pierce path.
		deactivate() # Bound pathological multi-collider sweeps without tunnelling.
		return

	global_position += step_vec

func _handle_hit(collider: Object, hit_pos: Vector3, hit_norm: Vector3) -> void:
	hit_occurred.emit(hit_pos, hit_norm)

	var target_obj: Node = null
	if collider is Node:
		if collider.has_method("take_damage"):
			target_obj = collider
		elif collider.get_parent() and collider.get_parent().has_method("take_damage"):
			target_obj = collider.get_parent()

	var is_enemy := is_instance_valid(target_obj) and target_obj.is_in_group("enemies")
	var is_player_unit := is_instance_valid(target_obj) and (target_obj.is_in_group("player") or target_obj.is_in_group("mini_helicopters"))
	var is_armored_surface := is_enemy or is_player_unit
	var is_lethal := false
	if target_obj and target_obj.get("current_health") != null:
		if float(target_obj.get("current_health")) <= _damage_for_target(target_obj):
			is_lethal = true

	var siege_round := _is_player_projectile and enemy_hit_limit > 1
	var can_pierce := siege_round and is_enemy and not target_obj.is_in_group("objectives") \
		and collider is CollisionObject3D
	var already_hit := is_enemy and _hit_target_ids.has(target_obj.get_instance_id())
	if can_pierce:
		raycast.add_exception(collider as CollisionObject3D)
	if target_obj and (not siege_round or not already_hit):
		has_hit_target = true
		if is_instance_valid(shooter_node) and shooter_node.has_method("on_projectile_hit"):
			shooter_node.on_projectile_hit(target_obj, hit_pos)
		var source_node: Node = null
		if _is_player_projectile:
			source_node = PlayerHelicopter.instance if is_instance_valid(PlayerHelicopter.instance) else get_tree().get_first_node_in_group("player")
		else:
			source_node = self
			if is_player_unit and CombatDirector.instance and CombatDirector.instance.telemetry_enabled:
				CombatDirector.instance.telemetry_player_collisions += 1
		if siege_round and is_enemy:
			_hit_target_ids.append(target_obj.get_instance_id())
		var applied_dmg: float = _damage_for_target(target_obj)
		target_obj.take_damage(applied_dmg, source_node, hit_pos)
		if _is_player_projectile and is_enemy:
			var gm: Node = get_tree().get_first_node_in_group("game_manager")
			if gm and gm.has_method("record_attributed_damage"):
				gm.call("record_attributed_damage", applied_dmg, weapon_source)
			var is_dead: bool = false
			if "current_health" in target_obj:
				var ch_val: Variant = target_obj.get("current_health")
				if ch_val != null and float(ch_val) <= 0.0:
					is_dead = true
			elif "is_alive" in target_obj:
				var alive_val: Variant = target_obj.get("is_alive")
				if alive_val != null and not bool(alive_val):
					is_dead = true
			if is_dead and gm and gm.has_method("record_attributed_kill"):
				gm.call("record_attributed_kill", weapon_source)

	var is_shield_hit := false
	if is_player_unit and is_instance_valid(target_obj):
		var ghost_val: Variant = target_obj.get("has_ghost_rotor")
		var timer_val: Variant = target_obj.get("_ghost_rotor_timer")
		if ghost_val != null and bool(ghost_val) and timer_val != null and float(timer_val) <= 0.0:
			is_shield_hit = true

	if not (siege_round and already_hit):
		_spawn_spark(hit_pos, hit_norm, is_armored_surface, is_shield_hit)
		if EventBus:
			EventBus.combat_impact_occurred.emit(hit_pos, hit_norm, is_armored_surface, is_lethal)

	if siege_round:
		# Siege hits at most two distinct enemies and always stops at world/objectives.
		if not can_pierce or _hit_target_ids.size() >= enemy_hit_limit:
			deactivate()
		return

	if ricochet_remaining > 0:
		ricochet_remaining -= 1
		if hit_norm.length_squared() > 0.01:
			_direction = _direction.bounce(hit_norm).normalized()
		else:
			_direction = -_direction
		global_position = hit_pos + _direction * 0.5
		if raycast and collider is CollisionObject3D:
			raycast.add_exception(collider as CollisionObject3D)
		return

	if pierce_remaining > 0:
		pierce_remaining -= 1
		global_position = hit_pos + _direction * 0.5
		if raycast and collider is CollisionObject3D:
			raycast.add_exception(collider as CollisionObject3D)
		return

	deactivate()

func _damage_for_target(target: Node) -> float:
	var result := damage
	# Retain the separate, pre-existing AP Ricochet evolution's modifier.
	if target is Tank or target is SAMSite or target.is_in_group("objectives") or target is BossArchon:
		result *= armor_damage_multiplier
	if not _is_player_projectile or not target.is_in_group("enemies"):
		return result
	if target.is_in_group("air_enemies"):
		return result * air_damage_multiplier
	result *= ground_damage_multiplier
	if target.is_in_group("armored_enemies"):
		return result * armored_damage_multiplier
	return result

func _spawn_spark(pos: Vector3, norm: Vector3, is_armor: bool = false, is_shield: bool = false) -> void:
	if VfxPool.instance:
		VfxPool.instance.spawn_sparks(pos, norm, is_armor, is_shield)
		return
	var spark_scene: PackedScene = preload("res://scenes/vfx/impact_sparks.tscn")
	if spark_scene:
		var spark: GPUParticles3D = spark_scene.instantiate() as GPUParticles3D
		if spark:
			if spark.has_method("play_impact"):
				spark.global_position = pos
				spark.call("play_impact", norm, is_armor, is_shield)
			elif norm.length_squared() > 0.01:
				var up_axis := Vector3.UP if absf(norm.y) < 0.9 else Vector3.FORWARD
				spark.look_at_from_position(pos, pos + norm, up_axis)
			else:
				spark.transform.origin = pos
			var target_parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
			target_parent.add_child.call_deferred(spark)

func deactivate() -> void:
	if not has_hit_target and is_instance_valid(shooter_node) and shooter_node.has_method("on_projectile_miss"):
		shooter_node.on_projectile_miss()
	shooter_node = null
	has_hit_target = false
	if CombatDirector.instance and (has_danger_reservation or CombatDirector.instance.has_danger_reservation(self)):
		CombatDirector.instance.release_danger_capacity(self, 1)
		has_danger_reservation = false
	_is_active = false
	visible = false
	set_process(false)
	if raycast:
		raycast.enabled = false
		raycast.clear_exceptions()
	if mesh_instance:
		mesh_instance.material_override = null
		mesh_instance.scale = Vector3.ONE
	_hit_target_ids.clear()
