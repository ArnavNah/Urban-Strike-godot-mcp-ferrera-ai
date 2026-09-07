class_name Chaingun
extends Node3D

## High-cadence chin-mounted chaingun.
## Fires along the muzzle's actual forward direction with or without an active target.

@export var fire_rate: float = 11.5 # Rounds per second (GDD baseline)
@export var damage_per_shot: float = 6.0
@export var heat_per_shot: float = 0.027
@export var cooling_rate: float = 0.55 # Heat lost per second when not firing
@export var overheat_lockout_duration: float = 2.5 # 2.5s GDD penalty
@export var pierce_count: int = 0
@export var ricochet_count: int = 0
@export var armor_multiplier: float = 1.0

var armored_damage_multiplier: float = 1.0
var air_damage_multiplier: float = 1.0
var ground_damage_multiplier: float = 1.0
var enemy_hit_limit: int = 1

var current_heat: float = 0.0
var is_overheated: bool = false
var _overheat_timer: float = 0.0
var _shot_cooldown: float = 0.0

@onready var muzzle: Marker3D = $Muzzle

signal fired(muzzle_pos: Vector3, aim_dir: Vector3)
signal heat_updated(heat: float, max_heat: float, overheated: bool)

func _ready() -> void:
	heat_updated.emit(current_heat, 1.0, is_overheated)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("chaingun_heat_changed"):
		eb.emit_signal("chaingun_heat_changed", current_heat, 1.0, is_overheated)

func _process(delta: float) -> void:
	if _shot_cooldown > 0.0:
		_shot_cooldown -= delta

	if is_overheated:
		_overheat_timer -= delta
		current_heat = maxf(0.0, current_heat - (1.0 / overheat_lockout_duration) * delta)
		if _overheat_timer <= 0.0 and current_heat <= 0.05:
			is_overheated = false
			current_heat = 0.0
		_notify_heat()
	else:
		if current_heat > 0.0:
			current_heat = maxf(0.0, current_heat - cooling_rate * delta)
			_notify_heat()

func try_fire(_target_pos: Vector3 = Vector3.ZERO) -> bool:
	if is_overheated or _shot_cooldown > 0.0:
		return false

	_shot_cooldown = 1.0 / fire_rate
	_execute_fire()

	current_heat += heat_per_shot
	if current_heat >= 1.0:
		current_heat = 1.0
		is_overheated = true
		_overheat_timer = overheat_lockout_duration

	_notify_heat()
	return true

func _execute_fire() -> void:
	var muzzle_pos: Vector3 = muzzle.global_position if muzzle else global_position
	# Authoritative fire direction along the muzzle's actual forward axis
	var fire_dir: Vector3 = -muzzle.global_transform.basis.z if muzzle else -global_transform.basis.z
	fire_dir = fire_dir.normalized()

	# Spawn projectile from pool
	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if not pool and ProjectilePool.instance:
		pool = ProjectilePool.instance
	if pool:
		var projectile := pool.spawn_projectile(muzzle_pos, fire_dir, true, damage_per_shot, pierce_count, ricochet_count, armor_multiplier)
		if projectile:
			# Snapshot the build when fired; later purchases do not alter these rounds.
			projectile.armored_damage_multiplier = armored_damage_multiplier
			projectile.air_damage_multiplier = air_damage_multiplier
			projectile.ground_damage_multiplier = ground_damage_multiplier
			projectile.enemy_hit_limit = enemy_hit_limit

	# Spawn muzzle flash (VfxPool with fallback)
	if VfxPool.instance:
		VfxPool.instance.spawn_muzzle_flash(muzzle_pos)
	else:
		var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
		if flash_scene:
			var flash := flash_scene.instantiate() as Node3D
			if flash:
				flash.transform.origin = muzzle_pos
				var target_parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
				target_parent.add_child.call_deferred(flash)

	fired.emit(muzzle_pos, fire_dir)

func _notify_heat() -> void:
	heat_updated.emit(current_heat, 1.0, is_overheated)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("chaingun_heat_changed"):
		eb.emit_signal("chaingun_heat_changed", current_heat, 1.0, is_overheated)
