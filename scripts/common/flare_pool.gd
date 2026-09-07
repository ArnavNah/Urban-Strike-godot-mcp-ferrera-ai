class_name FlarePool
extends Node3D

## Dedicated pool for defensive countermeasure flares.
## Recycles flare instances to avoid frame hitching during multi-flare defensive dumps.

static var instance: FlarePool = null

@export var pool_size: int = 16
@export var flare_scene: PackedScene

var _pool: Array[CountermeasureFlare] = []
var _pool_idx: int = 0

func _enter_tree() -> void:
	instance = self
	add_to_group("flare_pool")

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	if not flare_scene:
		flare_scene = preload("res://scenes/weapons/flare.tscn")
	_init_pool()

func _init_pool() -> void:
	if not flare_scene:
		return
	for i in range(pool_size):
		var flare: CountermeasureFlare = flare_scene.instantiate() as CountermeasureFlare
		if flare:
			flare.is_pooled = true
			flare.is_active = false
			flare.visible = false
			flare.set_physics_process(false)
			add_child(flare)
			_pool.append(flare)

func spawn_flare(pos: Vector3, vel: Vector3) -> CountermeasureFlare:
	var count: int = _pool.size()
	if count == 0:
		return null

	for i in range(count):
		var idx: int = (_pool_idx + i) % count
		var flare: CountermeasureFlare = _pool[idx]
		if not flare.is_active:
			_pool_idx = (idx + 1) % count
			flare.launch(pos, vel)
			return flare

	# Recycle oldest
	var oldest: CountermeasureFlare = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % count
	oldest.launch(pos, vel)
	return oldest
