class_name DamageNumberManager
extends Control

@export var max_active_numbers: int = 16 # Stacking limit
@export var damage_number_scene: PackedScene

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not damage_number_scene:
		damage_number_scene = preload("res://scenes/ui/damage_number.tscn")
	if EventBus:
		EventBus.damage_number_spawned.connect(_on_damage_spawned)

func _on_damage_spawned(pos: Vector3, amount: float, is_critical: bool) -> void:
	if get_child_count() >= max_active_numbers:
		# Recycle oldest
		var oldest := get_child(0)
		if oldest:
			oldest.queue_free()

	if not damage_number_scene:
		return

	var dmg_lbl := damage_number_scene.instantiate() as DamageNumber
	if dmg_lbl:
		add_child(dmg_lbl)
		dmg_lbl.setup(pos + Vector3(randf_range(-0.4, 0.4), 0.5, randf_range(-0.4, 0.4)), amount, is_critical)
