class_name MissilePod
extends Node3D

@export var lock_duration: float = 0.95 # GDD baseline
@export var fire_cooldown: float = 2.2
@export var missile_scene: PackedScene
@export var multi_launch_count: int = 1
@export var is_swarm_rockets: bool = false
@export var is_multi_lock: bool = false
@export var max_lock_targets: int = 1
@export var splash_radius_multiplier: float = 1.0
@export var splash_damage_multiplier: float = 1.0

var lock_cone_scale: float = 1.0
var current_target: Node3D = null
var lock_progress: float = 0.0
var is_locked: bool = false
var _cooldown_timer: float = 0.0

@onready var left_muzzle: Marker3D = $LeftMuzzle
@onready var right_muzzle: Marker3D = $RightMuzzle

var _fire_left_next: bool = true

@export var max_missiles: int = 6
@export var current_missiles: int = 6

signal ammo_changed(current: int, maximum: int)
signal no_ammo()

func replenish_ammo(amount: int) -> int:
	var old_ammo := current_missiles
	current_missiles = mini(max_missiles, current_missiles + amount)
	var gained := current_missiles - old_ammo
	if gained > 0:
		emit_signal("ammo_changed", current_missiles, max_missiles)
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("missile_ammo_changed"):
			eb.emit_signal("missile_ammo_changed", current_missiles, max_missiles)
	return gained

func reset_ammo() -> void:
	current_missiles = max_missiles
	emit_signal("ammo_changed", current_missiles, max_missiles)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("missile_ammo_changed"):
		eb.emit_signal("missile_ammo_changed", current_missiles, max_missiles)

func _ready() -> void:
	if not missile_scene:
		missile_scene = preload("res://scenes/weapons/guided_missile.tscn")
	current_missiles = max_missiles
	emit_signal("ammo_changed", current_missiles, max_missiles)
	_notify_ammo_deferred.call_deferred()

func _notify_ammo_deferred() -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("missile_ammo_changed"):
		eb.emit_signal("missile_ammo_changed", current_missiles, max_missiles)

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	_update_lock_progress(delta)

func set_target_candidate(cand_target: Node3D, has_los: bool) -> void:
	var valid_target: Node3D = null
	if is_instance_valid(cand_target) and not cand_target.is_queued_for_deletion():
		if _inside_lock_cone(cand_target):
			valid_target = cand_target

	if valid_target != current_target:
		current_target = valid_target
		lock_progress = 0.0
		is_locked = false

	if not has_los or not is_instance_valid(current_target) or current_target.is_queued_for_deletion():
		current_target = null
		lock_progress = 0.0
		is_locked = false

func _inside_lock_cone(target: Node3D) -> bool:
	if lock_cone_scale >= 1.0:
		return true # Preserve baseline candidate handling without Rapid Lock.
	var player := get_tree().get_first_node_in_group("player") as PlayerHelicopter
	if not player or not player.targeting_system:
		return false
	var targeting := player.targeting_system
	var local_target := targeting.to_local(targeting._get_target_center(target))
	var yaw := atan2(-local_target.x, -local_target.z)
	var pitch := atan2(local_target.y, Vector2(local_target.x, local_target.z).length())
	return absf(yaw) <= deg_to_rad(targeting.max_yaw_arc_deg * lock_cone_scale) \
		and pitch >= deg_to_rad(targeting.min_pitch_deg * lock_cone_scale) \
		and pitch <= deg_to_rad(targeting.max_pitch_deg * lock_cone_scale)

func _is_jammed() -> bool:
	var jammers := get_tree().get_nodes_in_group("jammers")
	for j in jammers:
		if is_instance_valid(j) and not (j as Node).is_queued_for_deletion():
			if not ("is_alive" in j) or j.is_alive:
				return true
	return false

func _update_lock_progress(delta: float) -> void:
	if is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
		if lock_progress < 1.0:
			var eff_duration: float = lock_duration * (1.6 if _is_jammed() else 1.0)
			lock_progress = minf(1.0, lock_progress + (delta / eff_duration))
			if lock_progress >= 1.0:
				is_locked = true
		else:
			is_locked = true
	else:
		current_target = null
		lock_progress = maxf(0.0, lock_progress - delta * 3.0)
		is_locked = false

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("missile_lock_updated"):
		var emit_target: Node3D = current_target if (is_instance_valid(current_target) and not current_target.is_queued_for_deletion()) else null
		eb.emit_signal("missile_lock_updated", lock_progress, emit_target, is_locked)

func _configure_missile(missile: Node3D) -> void:
	if not missile:
		return
	if "splash_radius" in missile:
		missile.splash_radius *= splash_radius_multiplier
	if "damage" in missile:
		missile.damage *= splash_damage_multiplier

func try_fire() -> bool:
	if _cooldown_timer > 0.0:
		return false

	if current_missiles <= 0:
		emit_signal("no_ammo")
		var eb_warn: Node = get_node_or_null("/root/EventBus")
		if eb_warn and eb_warn.has_signal("no_missiles_warning"):
			eb_warn.emit_signal("no_missiles_warning")
		return false

	current_missiles = maxi(0, current_missiles - 1)
	emit_signal("ammo_changed", current_missiles, max_missiles)
	var eb_ammo: Node = get_node_or_null("/root/EventBus")
	if eb_ammo and eb_ammo.has_signal("missile_ammo_changed"):
		eb_ammo.emit_signal("missile_ammo_changed", current_missiles, max_missiles)

	_cooldown_timer = fire_cooldown
	var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root

	if is_swarm_rockets:
		var count: int = maxi(multi_launch_count, 6)
		for i in range(count):
			var muzzle: Marker3D = left_muzzle if (i % 2 == 0) else right_muzzle
			var spawn_pos: Vector3 = muzzle.global_position if muzzle else global_position
			var spread := Vector3(randf_range(-0.35, 0.35), randf_range(-0.15, 0.25), randf_range(-0.35, 0.35))
			var fwd: Vector3 = (-global_transform.basis.z + spread).normalized()
			var missile: Node3D = missile_scene.instantiate() as Node3D
			if missile:
				_configure_missile(missile)
				missile.transform.origin = spawn_pos
				parent.add_child.call_deferred(missile)
				missile.call_deferred("launch", spawn_pos, fwd, current_target if is_locked else null, true)
	elif is_multi_lock:
		var targets: Array[Node3D] = []
		if is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
			targets.append(current_target)
		var enemies: Array[Node3D] = []
		if EnemyRegistry.instance:
			enemies = EnemyRegistry.instance.get_enemies_in_radius(global_position, 75.0)
		else:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Node3D:
					enemies.append(e as Node3D)
		for e in enemies:
			if targets.size() >= 3:
				break
			if e != current_target and is_instance_valid(e) and not e.is_queued_for_deletion():
				targets.append(e)

		var num_missiles: int = maxi(targets.size(), 3)
		for i in range(num_missiles):
			var muzzle: Marker3D = left_muzzle if (i % 2 == 0) else right_muzzle
			var spawn_pos: Vector3 = muzzle.global_position if muzzle else global_position
			var tgt: Node3D = targets[i % targets.size()] if not targets.is_empty() else null
			var spread := Vector3(float(i - 1) * 0.25, 0.1, 0.0)
			var fwd: Vector3 = (-global_transform.basis.z + spread).normalized()
			var missile: Node3D = missile_scene.instantiate() as Node3D
			if missile:
				_configure_missile(missile)
				missile.transform.origin = spawn_pos
				parent.add_child.call_deferred(missile)
				missile.call_deferred("launch", spawn_pos, fwd, tgt, true)
	elif multi_launch_count > 1:
		for i in range(multi_launch_count):
			var muzzle: Marker3D = left_muzzle if (i % 2 == 0) else right_muzzle
			var spawn_pos: Vector3 = muzzle.global_position if muzzle else global_position
			var spread := Vector3(float(i) * 0.15 - 0.075, 0.0, 0.0)
			var fwd: Vector3 = (-global_transform.basis.z + spread).normalized()
			var missile: Node3D = missile_scene.instantiate() as Node3D
			if missile:
				_configure_missile(missile)
				missile.transform.origin = spawn_pos
				parent.add_child.call_deferred(missile)
				missile.call_deferred("launch", spawn_pos, fwd, current_target if is_locked else null, true)
	else:
		var muzzle: Marker3D = left_muzzle if _fire_left_next else right_muzzle
		_fire_left_next = not _fire_left_next
		var spawn_pos: Vector3 = muzzle.global_position if muzzle else global_position
		var initial_fwd: Vector3 = -global_transform.basis.z
		var missile: Node3D = missile_scene.instantiate() as Node3D
		if missile:
			_configure_missile(missile)
			missile.transform.origin = spawn_pos
			parent.add_child.call_deferred(missile)
			missile.call_deferred("launch", spawn_pos, initial_fwd, current_target if is_locked else null, true)

	var eb_fired: Node = get_node_or_null("/root/EventBus")
	if eb_fired and eb_fired.has_signal("missile_fired"):
		eb_fired.emit_signal("missile_fired")

	return true
