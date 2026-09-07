class_name SpawnTelegraphFX
extends Node3D

## Visual telegraph ring that expands and fades at enemy spawn locations.

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	if mesh_instance:
		scale = Vector3(0.3, 0.3, 0.3)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "scale", Vector3(1.4, 1.4, 1.4), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mesh_instance, "transparency", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(queue_free)
	else:
		get_tree().create_timer(0.5, false).timeout.connect(queue_free)
