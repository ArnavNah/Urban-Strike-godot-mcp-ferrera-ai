class_name UnguidedRocket
extends Node3D

## High-visibility unguided rocket with clear ballistic path and dodgeable tell.
## Fired in short salvos by Rocket Raider helicopters.

@export var speed: float = 48.0
@export var damage: float = 16.0
@export var splash_radius: float = 3.5
@export var max_lifetime: float = 3.5

var _direction: Vector3 = Vector3.FORWARD
var _lifetime: float = 0.0
var _has_exploded: bool = false

@onready var raycast: RayCast3D = $RayCast3D

func _ready() -> void:
	add_to_group("enemy_projectiles")
	if raycast:
		raycast.collision_mask = (1 << 0) | (1 << 1) # World + Player

func launch(start_pos: Vector3, launch_dir: Vector3, initial_speed: float = -1.0) -> void:
	global_position = start_pos
	_direction = launch_dir.normalized()
	if initial_speed > 0.0:
		speed = initial_speed
	_lifetime = 0.0
	_has_exploded = false
	if _direction.length_squared() > 0.01:
		var up_ref := Vector3.UP if absf(_direction.y) < 0.9 else Vector3.FORWARD
		look_at(global_position + _direction, up_ref)

func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	_lifetime += delta
	if _lifetime >= max_lifetime:
		explode(global_position)
		return

	var step_vec := _direction * speed * delta

	if raycast:
		raycast.target_position = to_local(global_position + step_vec * 1.4)
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var hit_pos := raycast.get_collision_point()
			explode(hit_pos)
			return

	global_position += step_vec

func explode(impact_pos: Vector3) -> void:
	if _has_exploded:
		return
	_has_exploded = true

	# Splash damage targeting Player (Layer 2)
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = splash_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), impact_pos)
	query.collision_mask = (1 << 1) # Player

	var results := space.intersect_shape(query, 8)
	for r in results:
		var col: Object = r.get("collider")
		if col and col.has_method("take_damage"):
			var dist := impact_pos.distance_to((col as Node3D).global_position)
			var falloff := clampf(1.0 - (dist / splash_radius), 0.4, 1.0)
			col.call("take_damage", damage * falloff)

	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(impact_pos)
	else:
		var expl_scene: PackedScene = load("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl: Node3D = expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = impact_pos
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(expl)

	queue_free()
