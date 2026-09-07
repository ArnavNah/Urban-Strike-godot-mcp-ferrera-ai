class_name DestructibleProp
extends StaticBody3D

## Lightweight breakable prop (crates, wooden barricades).
## Destructible by chaingun or missiles, spawns impact sparks and debris.

@export var max_health: float = 25.0
@export var drops_xp: bool = false
@export var salvage_reward: int = 10

var current_health: float = 25.0
var is_destroyed: bool = false

func _ready() -> void:
	add_to_group("destructibles")
	add_to_group("enemies") # Collides with player munitions
	collision_layer = 4
	collision_mask = 1
	current_health = max_health

func take_damage(amount: float, _source: Node = null, hit_pos: Vector3 = Vector3.ZERO) -> void:
	if is_destroyed:
		return

	current_health = maxf(0.0, current_health - amount)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		var p: Vector3 = hit_pos if hit_pos != Vector3.ZERO else ((global_position if is_inside_tree() else position) + Vector3(0, 1.2, 0))
		eb.emit_signal("damage_number_spawned", p, amount, false)

	if current_health <= 0.0:
		_destroy_prop()

func _destroy_prop() -> void:
	if is_destroyed:
		return
	is_destroyed = true

	var spark_scene: PackedScene = load("res://scenes/vfx/impact_sparks.tscn")
	if spark_scene:
		var spark := spark_scene.instantiate() as Node3D
		if spark:
			spark.transform.origin = global_position
			var parent := get_parent() if get_parent() else get_tree().root
			parent.add_child.call_deferred(spark)

	if drops_xp:
		var gem_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn")
		if gem_scene:
			var gem := gem_scene.instantiate() as Node3D
			if gem:
				gem.transform.origin = global_position + Vector3(0, 0.4, 0)
				var parent := get_parent() if get_parent() else get_tree().root
				parent.add_child.call_deferred(gem)

	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage") and salvage_reward > 0:
		gm.call("add_salvage", salvage_reward)

	queue_free()
