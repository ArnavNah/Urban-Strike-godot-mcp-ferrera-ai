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
	if not is_alive:
		return
	current_health = maxf(0.0, current_health - amount)
	if EventBus:
		EventBus.damage_number_spawned.emit(global_position + Vector3(0, 1.2, 0), amount, amount >= 30.0)
	if current_health <= 0.0:
		is_alive = false
		if EventBus:
			EventBus.enemy_destroyed.emit(self, 50)
		queue_free()
