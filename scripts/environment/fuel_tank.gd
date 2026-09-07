class_name FuelTank
extends StaticBody3D

## Destructible industrial fuel tank.
## Takes damage from player weapons, explodes with AoE damage to nearby ground enemies,
## and awards salvage on demolition.

@export var max_health: float = 60.0
@export var aoe_damage: float = 85.0
@export var aoe_radius: float = 14.0
@export var salvage_reward: int = 50

var current_health: float = 60.0
var is_destroyed: bool = false
var _is_smoking: bool = false

@onready var tank_mesh: MeshInstance3D = get_node_or_null("TankMesh")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var smoke_particles: GPUParticles3D = get_node_or_null("SmokeParticles")

func _ready() -> void:
	add_to_group("destructibles")
	add_to_group("enemies") # Allows targeting and collision with player munitions
	collision_layer = 4 # Enemy/Destructible layer
	collision_mask = 1
	current_health = max_health

func take_damage(amount: float, _source: Node = null, hit_pos: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return

	current_health = maxf(0.0, current_health - amount)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		var p: Vector3 = hit_pos if hit_pos != Vector3.ZERO else ((global_position if is_inside_tree() else position) + Vector3(0, 3.0, 0))
		eb.emit_signal("damage_number_spawned", p, amount, amount >= 25.0)

	if current_health <= max_health * 0.5 and not _is_smoking:
		_is_smoking = true
		if smoke_particles:
			smoke_particles.emitting = true

	if current_health <= 0.0:
		_explode()

func _explode() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("camera_shake_requested"):
			eb.emit_signal("camera_shake_requested", 0.4)
		if eb.has_signal("enemy_destroyed"):
			eb.emit_signal("enemy_destroyed", self, 80)

	# Award Salvage
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage"):
		gm.call("add_salvage", salvage_reward)

	# AoE Damage to nearby ground enemies
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if not is_instance_valid(e) or e == self:
			continue
		if e is Node3D:
			var d: float = global_position.distance_to((e as Node3D).global_position)
			if d <= aoe_radius and e.has_method("take_damage"):
				var falloff := 1.0 - (d / aoe_radius) * 0.5
				e.call("take_damage", aoe_damage * falloff, self, (e as Node3D).global_position)

	# Spawn explosion VFX
	var expl_scene: PackedScene = load("res://scenes/vfx/explosion.tscn")
	if expl_scene:
		var expl := expl_scene.instantiate() as Node3D
		if expl:
			expl.transform.origin = global_position + Vector3(0, 2.0, 0)
			var parent := get_parent() if get_parent() else get_tree().root
			parent.add_child.call_deferred(expl)

	# Spawn salvage crate pickup
	var crate_scene: PackedScene = load("res://scenes/pickups/salvage_crate.tscn")
	if crate_scene:
		var crate := crate_scene.instantiate() as Node3D
		if crate:
			crate.transform.origin = global_position + Vector3(0, 0.8, 0)
			var parent := get_parent() if get_parent() else get_tree().root
			parent.add_child.call_deferred(crate)

	# Disable collision
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if tank_mesh:
		var sm := tank_mesh.get_active_material(0)
		if sm is StandardMaterial3D:
			var burnt_mat := (sm as StandardMaterial3D).duplicate() as StandardMaterial3D
			burnt_mat.albedo_color = Color(0.1, 0.08, 0.08, 1.0)
			burnt_mat.roughness = 0.95
			tank_mesh.material_override = burnt_mat
		tank_mesh.scale = Vector3(1.1, 0.25, 1.1)
		tank_mesh.position.y = 0.4
	else:
		queue_free()
