class_name ProjectilePool
extends Node3D

@export var pool_size: int = 120
@export var projectile_scene: PackedScene

var _pool: Array[Projectile] = []
var _pool_index: int = 0

static var instance: ProjectilePool

func _enter_tree() -> void:
	instance = self
	add_to_group("projectile_pool")

func _ready() -> void:
	if not projectile_scene:
		projectile_scene = preload("res://scenes/weapons/projectile.tscn")

	for i in range(pool_size):
		var proj: Projectile = projectile_scene.instantiate() as Projectile
		add_child(proj)
		_pool.append(proj)

func spawn_projectile(start_pos: Vector3, dir: Vector3, from_player: bool = true, damage: float = 6.0, pierce_count: int = 0, ricochet_count: int = 0, armor_mult: float = 1.0) -> Projectile:
	var count: int = _pool.size()
	if count == 0:
		return null

	for i in range(count):
		var idx: int = (_pool_index + i) % count
		var proj: Projectile = _pool[idx]
		if not proj._is_active:
			_pool_index = (idx + 1) % count
			proj.launch(start_pos, dir, from_player, damage, pierce_count, ricochet_count, armor_mult)
			return proj

	# If all are active, steal the oldest one
	var oldest: Projectile = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % count
	oldest.launch(start_pos, dir, from_player, damage, pierce_count, ricochet_count, armor_mult)
	return oldest
