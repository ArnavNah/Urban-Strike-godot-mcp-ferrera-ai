class_name XpGemPool
extends Node3D

## Dedicated high-performance pool for XP gems.
## Pre-allocates gem instances to eliminate instantiation pauses and GC pressure
## when enemies are destroyed during combat.

static var instance: XpGemPool = null

@export var pool_size: int = 80
@export var gem_scene: PackedScene = null

var _pool: Array[XPGem] = []
var _pool_idx: int = 0

func _enter_tree() -> void:
	instance = self
	add_to_group("xp_gem_pool")

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	if not gem_scene:
		gem_scene = load("res://scenes/pickups/xp_gem.tscn")
	_init_pool()

func _init_pool() -> void:
	if not gem_scene:
		return
	for i in range(pool_size):
		var gem: XPGem = gem_scene.instantiate() as XPGem
		if gem:
			gem.is_pooled = true
			gem.deactivate()
			add_child(gem)
			_pool.append(gem)

func spawn_gem(pos: Vector3, val: int) -> XPGem:
	var count: int = _pool.size()
	if count == 0:
		return null

	for i in range(count):
		var idx: int = (_pool_idx + i) % count
		var gem: XPGem = _pool[idx]
		if not gem.is_active:
			_pool_idx = (idx + 1) % count
			gem.activate(pos, val)
			return gem

	# Preserve outstanding XP on saturation, including magnetized pickups.
	var nearest: XPGem = null
	var best_distance: float = INF
	for gem in _pool:
		if gem._is_collected:
			continue
		var distance: float = gem.global_position.distance_squared_to(pos)
		if distance < best_distance:
			best_distance = distance
			nearest = gem
	if nearest:
		nearest.xp_value += val
		nearest._apply_visual_style()
		return nearest
	# All slots are finishing their collection animation; retire one safely.
	var oldest: XPGem = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % count
	oldest.activate(pos, val)
	return oldest

func get_active_count() -> int:
	var count: int = 0
	for gem in _pool:
		if gem.is_active:
			count += 1
	return count
