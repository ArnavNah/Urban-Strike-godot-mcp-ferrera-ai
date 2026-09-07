class_name CountermeasureFlare
extends Node3D

@export var lifetime: float = 2.5

var is_pooled: bool = false
var is_active: bool = false

var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0

@onready var particles: GPUParticles3D = $GPUParticles3D

func _ready() -> void:
	if not is_pooled:
		_divert_incoming_missiles()

func launch(start_pos: Vector3, initial_vel: Vector3) -> void:
	global_position = start_pos
	_velocity = initial_vel
	_age = 0.0
	is_active = true
	visible = true
	set_physics_process(true)
	if particles:
		particles.restart()
		particles.emitting = true
	_divert_incoming_missiles()

func _divert_incoming_missiles() -> void:
	var missiles := get_tree().get_nodes_in_group("homing_missiles")
	for m in missiles:
		if m.has_method("divert_to_flare"):
			m.divert_to_flare(global_position)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		if is_pooled:
			is_active = false
			visible = false
			set_physics_process(false)
			if particles:
				particles.emitting = false
		else:
			queue_free()
		return

	# Drag and gravity
	_velocity = _velocity.move_toward(Vector3(0, -2.0, 0), 6.0 * delta)
	global_position += _velocity * delta
