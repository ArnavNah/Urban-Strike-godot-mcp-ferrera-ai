class_name VfxPool
extends Node3D

## High-cadence visual effects pool.
## Eliminates per-shot heap allocations and GC pressure from chaingun flashes, 
## bullet impact sparks, and missile/ordnance explosions.

static var instance: VfxPool = null

@export var flash_pool_size: int = 30
@export var spark_pool_size: int = 30
@export var explosion_pool_size: int = 20
@export var max_active_explosions: int = 6
var max_active_sparks: int = 12
var max_active_flashes: int = 12
var effect_distance: float = 140.0

@export var muzzle_flash_scene: PackedScene
@export var impact_sparks_scene: PackedScene
@export var explosion_scene: PackedScene

var _flash_pool: Array[Node3D] = []
var _flash_idx: int = 0

var _spark_pool: Array[Node3D] = []
var _spark_idx: int = 0

var _explosion_pool: Array[Node3D] = []
var _explosion_idx: int = 0

func _enter_tree() -> void:
	instance = self
	add_to_group("vfx_pool")

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	if not muzzle_flash_scene:
		muzzle_flash_scene = preload("res://scenes/vfx/muzzle_flash.tscn")
	if not impact_sparks_scene:
		impact_sparks_scene = preload("res://scenes/vfx/impact_sparks.tscn")
	if not explosion_scene:
		explosion_scene = preload("res://scenes/vfx/explosion.tscn")

	_init_pools()
	call_deferred("warm_up")

func _allow_effect(pos: Vector3, pool: Array[Node3D], limit: int) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_squared_to(pos) > effect_distance * effect_distance:
		return false
	var active: int = 0
	for item in pool:
		if bool(item.get("is_active")):
			active += 1
	return active < limit

func warm_up() -> void:
	if not _flash_pool.is_empty():
		var fl: Node3D = _flash_pool[0]
		fl.global_position = Vector3(0, -999, 0)
		if fl.has_method("play"):
			fl.call("play")
	if not _spark_pool.is_empty():
		var sp: Node3D = _spark_pool[0]
		sp.global_position = Vector3(0, -999, 0)
		if sp.has_method("play"):
			sp.call("play")
	if not _explosion_pool.is_empty():
		var ex: Node3D = _explosion_pool[0]
		ex.global_position = Vector3(0, -999, 0)
		if ex.has_method("play"):
			ex.call("play")

func _init_pools() -> void:
	# Flash pool
	if muzzle_flash_scene:
		for i in range(flash_pool_size):
			var fl: Node3D = muzzle_flash_scene.instantiate() as Node3D
			fl.set("is_pooled", true)
			fl.visible = false
			fl.set_process(false)
			fl.set_physics_process(false)
			add_child(fl)
			_flash_pool.append(fl)

	# Spark pool
	if impact_sparks_scene:
		for i in range(spark_pool_size):
			var sp: Node3D = impact_sparks_scene.instantiate() as Node3D
			sp.set("is_pooled", true)
			sp.visible = false
			sp.set_process(false)
			sp.set_physics_process(false)
			add_child(sp)
			_spark_pool.append(sp)

	# Explosion pool
	if explosion_scene:
		for i in range(explosion_pool_size):
			var ex: Node3D = explosion_scene.instantiate() as Node3D
			ex.set("is_pooled", true)
			ex.visible = false
			ex.set_process(false)
			ex.set_physics_process(false)
			add_child(ex)
			_explosion_pool.append(ex)

func spawn_muzzle_flash(pos: Vector3) -> Node3D:
	if not _allow_effect(pos, _flash_pool, max_active_flashes):
		return null
	var count: int = _flash_pool.size()
	if count == 0:
		return null

	for i in range(count):
		var idx: int = (_flash_idx + i) % count
		var item: Node3D = _flash_pool[idx]
		if not bool(item.get("is_active")):
			_flash_idx = (idx + 1) % count
			item.global_position = pos
			item.call("play")
			return item

	# Recycle oldest
	var oldest: Node3D = _flash_pool[_flash_idx]
	_flash_idx = (_flash_idx + 1) % count
	oldest.global_position = pos
	oldest.call("play")
	return oldest

func spawn_sparks(pos: Vector3) -> Node3D:
	if not _allow_effect(pos, _spark_pool, max_active_sparks):
		return null
	var count: int = _spark_pool.size()
	if count == 0:
		return null

	for i in range(count):
		var idx: int = (_spark_idx + i) % count
		var item: Node3D = _spark_pool[idx]
		if not bool(item.get("is_active")):
			_spark_idx = (idx + 1) % count
			item.global_position = pos
			item.call("play")
			return item

	var oldest: Node3D = _spark_pool[_spark_idx]
	_spark_idx = (_spark_idx + 1) % count
	oldest.global_position = pos
	oldest.call("play")
	return oldest

func spawn_explosion(pos: Vector3, scale_mult: float = 1.0) -> Node3D:
	if not _allow_effect(pos, _explosion_pool, max_active_explosions):
		return null
	var count: int = _explosion_pool.size()
	if count == 0:
		return null

	var active_count: int = 0
	for ex in _explosion_pool:
		if bool(ex.get("is_active")):
			active_count += 1

	# Cap simultaneous active explosions to prevent overdraw and light spikes
	if active_count >= max_active_explosions:
		_explosion_idx = (_explosion_idx + 1) % count
		# Do not activate an unused ring slot when already at the cap.
		return null

	for i in range(count):
		var idx: int = (_explosion_idx + i) % count
		var item: Node3D = _explosion_pool[idx]
		if not bool(item.get("is_active")):
			_explosion_idx = (idx + 1) % count
			item.global_position = pos
			item.call("play", scale_mult)
			return item

	var oldest: Node3D = _explosion_pool[_explosion_idx]
	_explosion_idx = (_explosion_idx + 1) % count
	oldest.global_position = pos
	oldest.call("play", scale_mult)
	return oldest
