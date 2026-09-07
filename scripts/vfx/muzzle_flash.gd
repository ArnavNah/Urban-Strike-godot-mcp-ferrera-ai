class_name MuzzleFlashEffect
extends Node3D

var is_pooled: bool = false
var is_active: bool = false

@onready var light: OmniLight3D = $OmniLight3D

func _ready() -> void:
	if not is_pooled:
		play()

func play() -> void:
	visible = true
	is_active = true
	scale = Vector3(1.4, 1.4, 1.4)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.05).from(Vector3(1.4, 1.4, 1.4))
	if is_pooled:
		tween.tween_callback(_on_pooled_finish)
	else:
		tween.tween_callback(queue_free)

func _on_pooled_finish() -> void:
	visible = false
	is_active = false
