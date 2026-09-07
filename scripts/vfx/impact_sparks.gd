class_name ImpactSparksEffect
extends GPUParticles3D

var is_pooled: bool = false
var is_active: bool = false

func _ready() -> void:
	if not is_pooled:
		play()

func play() -> void:
	visible = true
	is_active = true
	restart()
	emitting = true
	if is_pooled:
		get_tree().create_timer(lifetime + 0.05, false).timeout.connect(_on_pooled_finish)
	else:
		finished.connect(queue_free)
		get_tree().create_timer(1.0, false).timeout.connect(queue_free)

func _on_pooled_finish() -> void:
	emitting = false
	visible = false
	is_active = false
