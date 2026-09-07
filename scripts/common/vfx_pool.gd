class_name VfxPool
extends Node3D

## High-cadence visual effects pool.
## Eliminates per-shot heap allocations and GC pressure from chaingun flashes, 
## bullet impact sparks, and missile/ordnance explosions.

static var instance: VfxPool = null

@export var flash_pool_size: int = 30
@export var spark_pool_size: int = 30
@export var explosion_pool_size: int = 20

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

func _init_pools() -> void:
	# Flash pool
	if muzzle_flash_scene:
		for i in range(flash_pool_size):
			var fl: Node3D = muzzle_flash_scene.instantiate() as Node3D
			fl.set("is_pooled", true)
			fl.visible = false
			add_child(fl)
			_flash_pool.append(fl)

	# Spark pool
	if impact_sparks_scene:
		for i in range(spark_pool_size):
			var sp: Node3D = impact_sparks_scene.instantiate() as Node3D
			sp.set("is_pooled", true)
			sp.visible = false
			add_child(sp)
			_spark_pool.append(sp)

	# Explosion pool
	if explosion_scene:
		for i in range(explosion_pool_size):
			var ex: Node3D = explosion_scene.instantiate() as Node3D
			ex.set("is_pooled", true)
			ex.visible = false
			add_child(ex)
			_explosion_pool.append(ex)

func spawn_muzzle_flash(pos: Vector3) -> Node3D:
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

func spawn_explosion(pos: Vector3) -> Node3D:
	var count: int = _explosion_pool.size()
	if count == 0:
		return null

	for i in range(count):
		var idx: int = (_explosion_idx + i) % count
		var item: Node3D = _explosion_pool[idx]
		if not bool(item.get("is_active")):
			_explosion_idx = (idx + 1) % count
			item.global_position = pos
			item.call("play")
			return item

	var oldest: Node3D = _explosion_pool[_explosion_idx]
	_explosion_idx = (_explosion_idx + 1) % count
	oldest.global_position = pos
	oldest.call("play")
	return oldest
