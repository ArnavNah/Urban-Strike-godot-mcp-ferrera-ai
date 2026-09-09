class_name ExplosionEffect
extends Node3D

var is_pooled: bool = false
var is_active: bool = false

@onready var particles: GPUParticles3D = get_node_or_null("GPUParticles3D")
@onready var fireball: MeshInstance3D = get_node_or_null("FireballMesh")
@onready var flash_light: OmniLight3D = get_node_or_null("FlashLight")

func _ready() -> void:
	if not is_pooled:
		play()

func play(scale_mult: float = 1.0) -> void:
	visible = true
	is_active = true
	var s: float = maxf(0.5, scale_mult)
	if particles:
		particles.restart()
		particles.emitting = true

	if is_inside_tree():
		if fireball:
			fireball.scale = Vector3.ZERO
			fireball.visible = true
			var tw := create_tween()
			var target_scale := Vector3(2.2 * s, 2.2 * s, 2.2 * s)
			tw.tween_property(fireball, "scale", target_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(fireball, "scale", Vector3.ZERO, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if flash_light:
			flash_light.light_energy = 2.4 * minf(2.0, s)
			var ltw := create_tween()
			ltw.tween_property(flash_light, "light_energy", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if is_pooled:
		get_tree().create_timer(1.2, false).timeout.connect(_on_pooled_finish)
	else:
		if particles:
			particles.finished.connect(queue_free)
		get_tree().create_timer(1.2, false).timeout.connect(queue_free)

func _on_pooled_finish() -> void:
	if particles:
		particles.emitting = false
	if fireball:
		fireball.scale = Vector3.ZERO
	if flash_light:
		flash_light.light_energy = 0.0
	visible = false
	is_active = false
