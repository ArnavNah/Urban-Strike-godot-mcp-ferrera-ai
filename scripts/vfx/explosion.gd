class_name ExplosionEffect
extends Node3D

var is_pooled: bool = false
var is_active: bool = false
var _remaining: float = 0.0
var _visual_tween: Tween
var _light_tween: Tween
var _shockwave_tween: Tween

@onready var particles: GPUParticles3D = get_node_or_null("GPUParticles3D")
@onready var debris_particles: GPUParticles3D = get_node_or_null("DebrisParticles")
@onready var smoke_particles: GPUParticles3D = get_node_or_null("SmokeParticles")
@onready var fireball: MeshInstance3D = get_node_or_null("FireballMesh")
@onready var shockwave: MeshInstance3D = get_node_or_null("ShockwaveMesh")
@onready var flash_light: OmniLight3D = get_node_or_null("FlashLight")

func _ready() -> void:
	if is_pooled:
		_on_pooled_finish()
	else:
		play()

func play(scale_mult: float = 1.0) -> void:
	if _visual_tween:
		_visual_tween.kill()
	if _light_tween:
		_light_tween.kill()
	if _shockwave_tween:
		_shockwave_tween.kill()

	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	visible = true
	is_active = true
	_remaining = 1.3
	var s: float = clampf(scale_mult, 0.5, 2.5)

	# Trigger camera shake for tactile destruction punch
	if is_inside_tree():
		var eb := get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("camera_shake_requested"):
			eb.emit_signal("camera_shake_requested", clampf(0.24 * s, 0.12, 0.65))

	if particles:
		particles.restart()
		particles.emitting = true
	if debris_particles:
		debris_particles.restart()
		debris_particles.emitting = true
	if smoke_particles:
		smoke_particles.restart()
		smoke_particles.emitting = true

	if fireball:
		fireball.scale = Vector3.ONE * 0.01
		fireball.visible = true
		_visual_tween = create_tween()
		_visual_tween.tween_property(fireball, "scale", Vector3.ONE * 2.4 * s, 0.08)
		_visual_tween.tween_property(fireball, "scale", Vector3.ONE * 0.01, 0.16)
		_visual_tween.tween_callback(func() -> void: fireball.visible = false)

	if shockwave:
		shockwave.scale = Vector3.ONE * 0.1
		shockwave.visible = true
		shockwave.transparency = 0.0
		_shockwave_tween = create_tween()
		_shockwave_tween.set_parallel(true)
		_shockwave_tween.tween_property(shockwave, "scale", Vector3(3.2 * s, 0.2, 3.2 * s), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_shockwave_tween.tween_property(shockwave, "transparency", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_shockwave_tween.chain().tween_callback(func() -> void: shockwave.visible = false)

	if flash_light:
		var flash_enabled: bool = bool(SaveSystem.get_setting("damage_flash_enabled", true))
		var reduced_flash: bool = bool(SaveSystem.get_setting("reduced_flashing", false))
		if not flash_enabled:
			flash_light.visible = false
			flash_light.light_energy = 0.0
		elif reduced_flash:
			flash_light.visible = true
			flash_light.light_energy = 0.8 * s
			_light_tween = create_tween()
			_light_tween.tween_property(flash_light, "light_energy", 0.0, 0.10)
		else:
			flash_light.visible = true
			flash_light.light_energy = 2.6 * s
			_light_tween = create_tween()
			_light_tween.tween_property(flash_light, "light_energy", 0.0, 0.18)

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		if is_pooled:
			_on_pooled_finish()
		else:
			queue_free()

func _on_pooled_finish() -> void:
	if _visual_tween:
		_visual_tween.kill()
	if _light_tween:
		_light_tween.kill()
	if _shockwave_tween:
		_shockwave_tween.kill()
	if particles:
		particles.emitting = false
	if debris_particles:
		debris_particles.emitting = false
	if smoke_particles:
		smoke_particles.emitting = false
	if fireball:
		fireball.visible = false
	if shockwave:
		shockwave.visible = false
	if flash_light:
		flash_light.light_energy = 0.0
	visible = false
	is_active = false
	set_process(false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
