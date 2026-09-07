class_name GuidedMissile
extends Node3D

@export var speed: float = 65.0
@export var damage: float = 45.0 # GDD baseline
@export var splash_radius: float = 3.2 # GDD baseline
@export var turn_rate: float = 6.0 # Rad/s steering
@export var max_lifetime: float = 4.0

var target: Node3D = null
var is_player_missile: bool = true
var _lifetime: float = 0.0
var _has_exploded: bool = false

@onready var raycast: RayCast3D = $RayCast3D
@onready var smoke_trail: GPUParticles3D = $SmokeTrail

func _ready() -> void:
	add_to_group("homing_missiles")

func launch(start_pos: Vector3, initial_dir: Vector3, missile_target: Node3D, from_player: bool = true) -> void:
	global_position = start_pos
	look_at(start_pos + initial_dir, Vector3.UP if absf(initial_dir.y) < 0.9 else Vector3.FORWARD)
	target = missile_target
	is_player_missile = from_player
	_lifetime = 0.0
	_has_exploded = false

	if raycast:
		raycast.clear_exceptions()
		if is_player_missile:
			raycast.collision_mask = (1 << 0) | (1 << 2) # World + Enemies
		else:
			raycast.collision_mask = (1 << 0) | (1 << 1) # World + Player

func divert_to_flare(flare_pos: Vector3) -> void:
	# Fooled by defensive countermeasure flare
	target = null
	# Steer erratically towards flare position or deviate
	var jitter_dir := (flare_pos - global_position).normalized() + Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	look_at(global_position + jitter_dir.normalized(), Vector3.UP)

func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	_lifetime += delta
	if _lifetime >= max_lifetime:
		explode(global_position)
		return

	# Steer toward target if target exists and is alive
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		var aim_pos: Vector3 = target.global_position + Vector3(0, 0.8, 0)
		var desired_dir := (aim_pos - global_position).normalized()
		var current_fwd := -global_transform.basis.z
		var new_fwd := current_fwd.slerp(desired_dir, turn_rate * delta).normalized()
		look_at(global_position + new_fwd, Vector3.UP if absf(new_fwd.y) < 0.9 else Vector3.FORWARD)

	var move_dist := speed * delta
	var step_vec := -global_transform.basis.z * move_dist

	# Obstacle ray check
	if raycast:
		raycast.target_position = to_local(global_position + step_vec * 1.5)
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

	# Splash damage query
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = splash_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), impact_pos)
	if is_player_missile:
		query.collision_mask = (1 << 2) # Enemies
	else:
		query.collision_mask = (1 << 1) # Player

	var results := space.intersect_shape(query, 16)
	for r in results:
		var col: Object = r.get("collider")
		if col and col.has_method("take_damage"):
			var dist := impact_pos.distance_to(r.get("collider").global_position)
			var falloff := clampf(1.0 - (dist / splash_radius), 0.35, 1.0)
			col.take_damage(damage * falloff)

	# Spawn explosion VFX (VfxPool with fallback)
	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(impact_pos)
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = impact_pos
				expl.scale = Vector3(1.8, 1.8, 1.8)
				var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
				parent.add_child.call_deferred(expl)

	queue_free()
