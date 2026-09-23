class_name ExplosionEffect
extends Node3D
var is_pooled: bool = false
var is_active: bool = false
var _remaining: float = 0.0
var _visual_tween: Tween
var _light_tween: Tween
@onready var particles: GPUParticles3D = get_node_or_null("GPUParticles3D")
@onready var fireball: MeshInstance3D = get_node_or_null("FireballMesh")
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
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	visible = true
	is_active = true
	_remaining = 1.2
	var s: float = clampf(scale_mult, 0.5, 2.0)
	if particles:
		particles.restart()
		particles.emitting = true
	if fireball:
		fireball.scale = Vector3.ONE * 0.01
		fireball.visible = true
		_visual_tween = create_tween()
		_visual_tween.tween_property(fireball, "scale", Vector3.ONE * 2.2 * s, 0.08)
		_visual_tween.tween_property(fireball, "scale", Vector3.ONE * 0.01, 0.14)
		_visual_tween.tween_callback(func() -> void: fireball.visible = false)
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
			flash_light.light_energy = 2.4 * s
			_light_tween = create_tween()
			_light_tween.tween_property(flash_light, "light_energy", 0.0, 0.16)

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
	if particles:
		particles.emitting = false
	if fireball:
		fireball.visible = false
	if flash_light:
		flash_light.light_energy = 0.0
	visible = false
	is_active = false
	set_process(false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
