class_name MuzzleFlashEffect
extends Node3D

var is_pooled: bool = false
var is_active: bool = false
var _tween: Tween

@onready var light: OmniLight3D = get_node_or_null("OmniLight3D")

func _ready() -> void:
	if is_pooled:
		visible = false
		is_active = false
		set_process(false)
		set_physics_process(false)
		if light:
			light.visible = false
	else:
		play()

func play() -> void:
	if _tween:
		_tween.kill()
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	is_active = true
	scale = Vector3(1.4, 1.4, 1.4)
	if light:
		light.visible = true
	var tween := create_tween()
	_tween = tween
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.05).from(Vector3(1.4, 1.4, 1.4))
	if is_pooled:
		tween.tween_callback(_on_pooled_finish)
	else:
		tween.tween_callback(queue_free)

func _on_pooled_finish() -> void:
	if light:
		light.visible = false
	visible = false
	is_active = false
	set_process(false)
	set_physics_process(false)
