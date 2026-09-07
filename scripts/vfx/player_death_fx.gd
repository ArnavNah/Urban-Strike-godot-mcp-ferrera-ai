class_name PlayerDeathFX
extends Node3D

## Visual and audio sequence for player helicopter destruction.
## Spawns stylized GPUParticles3D, shockwave flash, and sound cue.

@onready var fire_particles: GPUParticles3D = $FireParticles
@onready var spark_particles: GPUParticles3D = $DebrisSparks
@onready var smoke_particles: GPUParticles3D = $SmokeParticles
@onready var flash_light: OmniLight3D = $FlashLight

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if flash_light:
		flash_light.light_energy = 4.0
		var light_tween := create_tween()
		light_tween.tween_property(flash_light, "light_energy", 0.0, 0.45)

	if fire_particles:
		fire_particles.restart()
		fire_particles.emitting = true
	if spark_particles:
		spark_particles.restart()
		spark_particles.emitting = true
	if smoke_particles:
		smoke_particles.restart()
		smoke_particles.emitting = true

	# Auto-free after FX finishes
	get_tree().create_timer(3.0, true, false, true).timeout.connect(queue_free)
