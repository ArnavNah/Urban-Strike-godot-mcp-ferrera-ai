class_name ImpactSparksEffect
extends GPUParticles3D
var is_pooled: bool = false
var is_active: bool = false
var _remaining: float = 0.0

func _ready() -> void:
	if is_pooled:
		_on_pooled_finish()
	else:
		play()

func play() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	is_active = true
	_remaining = lifetime + 0.05
	set_process(true)
	restart()
	emitting = true

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		if is_pooled:
			_on_pooled_finish()
		else:
			queue_free()

func _on_pooled_finish() -> void:
	emitting = false
	visible = false
	is_active = false
	set_process(false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
