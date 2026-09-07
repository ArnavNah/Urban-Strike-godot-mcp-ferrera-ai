class_name ExplosionEffect
extends Node3D

var is_pooled: bool = false
var is_active: bool = false

@onready var particles: GPUParticles3D = $GPUParticles3D

func _ready() -> void:
	if not is_pooled:
		play()

func play() -> void:
	visible = true
	is_active = true
	if particles:
		particles.restart()
		particles.emitting = true
	if is_pooled:
		get_tree().create_timer(1.2, false).timeout.connect(_on_pooled_finish)
	else:
		if particles:
			particles.finished.connect(queue_free)
		get_tree().create_timer(1.2, false).timeout.connect(queue_free)

func _on_pooled_finish() -> void:
	if particles:
		particles.emitting = false
	visible = false
	is_active = false
