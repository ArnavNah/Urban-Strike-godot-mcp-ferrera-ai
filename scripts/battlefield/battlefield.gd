class_name Battlefield
extends Node3D

@onready var player: PlayerHelicopter = $PlayerHelicopter
@onready var camera_rig: Node3D = $CameraRig
@onready var run_state_controller: RunStateController = $RunStateController
@onready var wave_manager: WaveManager = $WaveManager

func _ready() -> void:
	# 1. Initialize & clear spatial EnemyRegistry
	if not EnemyRegistry.instance:
		var reg := EnemyRegistry.new()
		reg.name = "EnemyRegistry"
		add_child(reg)
	else:
		EnemyRegistry.instance.clear()

	# 2. Initialize VfxPool for zero GC visual effects
	if not VfxPool.instance:
		var vfx := VfxPool.new()
		vfx.name = "VfxPool"
		add_child(vfx)

	# 3. Initialize FlarePool for pre-allocated countermeasures
	if not FlarePool.instance:
		var flares := FlarePool.new()
		flares.name = "FlarePool"
		add_child(flares)

	# 4. Initialize XpGemPool for pre-allocated, zero-allocation XP gems
	if not XpGemPool.instance:
		var gem_pool := XpGemPool.new()
		gem_pool.name = "XpGemPool"
		add_child(gem_pool)

	SaveSystem.apply_graphics_preset(str(SaveSystem.get_setting("graphics_preset", "medium")), get_tree())

	# 5. Initialize tactical SpawnDirector / SpawnSystem
	var spawner := get_node_or_null("SpawnSystem") as SpawnDirector
	if not spawner:
		spawner = SpawnDirector.new()
		spawner.name = "SpawnSystem"
		spawner.autostart_wave = false
		add_child(spawner)
	else:
		spawner.autostart_wave = false

	# 6. Link WaveManager to SpawnDirector
	if wave_manager:
		wave_manager.spawn_director = spawner
