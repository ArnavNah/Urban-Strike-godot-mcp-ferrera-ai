class_name TargetDummy
extends StaticBody3D

## Stationary target dummy for auto-aim and weapon testing.

@export var max_health: float = 100.0
var current_health: float = 100.0
var is_alive: bool = true

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive or amount <= 0.0:
		return
	var prev_hp: float = current_health
	current_health = maxf(0.0, current_health - amount)
	var actual_damage: float = prev_hp - current_health
	if actual_damage > 0.0:
		DamageFlashManager.flash_target(self)
		if EventBus:
			EventBus.damage_number_spawned.emit(global_position + Vector3(0, 1.2, 0), actual_damage, false, {"target_id": get_instance_id(), "is_lethal": current_health <= 0.0})
	if current_health <= 0.0:
		is_alive = false
		collision_layer = 0
		collision_mask = 0
		DamageFlashManager.clear_target(self)
		if EventBus:
			EventBus.enemy_destroyed.emit(self, 50)
		queue_free()
