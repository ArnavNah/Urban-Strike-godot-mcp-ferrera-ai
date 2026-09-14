class_name DifficultyProfile
extends Resource

## Data-driven configuration resource defining a complete difficulty profile for Survivors-style mode.
## Holds wave population targets, node caps, rhythm timings, surge/recovery parameters, and spatial limits.

const WavePopulationTargetClass = preload("res://scripts/resources/wave_population_target.gd")

@export_category("Profile Metadata")
@export var profile_name: String = "LOW_PRESSURE_SURVIVORS"
@export var display_name: String = "Low-Pressure Survivors"

@export_category("Per-Wave Population Targets")
@export var wave_targets: Array[Resource] = []

@export_category("Surge and Recovery Cycle")
@export var surge_interval_min: float = 75.0   ## Minimum time between surge triggers (no surge before ~75s)
@export var surge_interval_max: float = 95.0   ## Maximum time between surge triggers
@export var surge_duration_min: float = 8.0    ## Minimum surge duration
@export var surge_duration_max: float = 12.0   ## Maximum surge duration
@export var surge_pressure_bonus: float = 0.35 ## Increases population/refill pressure by 30-40%
@export var recovery_duration_min: float = 10.0 ## Calm breather duration
@export var recovery_duration_max: float = 14.0
@export var recovery_spawn_mult: float = 0.30  ## Spawn rate during recovery (~25-35% of normal)

@export_category("Stagger & Rhythm")
@export var formation_stagger_min: float = 0.25 ## Formation members enter 0.25-0.55s apart
@export var formation_stagger_max: float = 0.55
@export var deficit_interval_scale_max: float = 0.70 ## Modest interval reduction when below target (at most 30% faster)

@export_category("Spatial Sectors & Escape Route")
@export var sector_rotation_interval_min: float = 10.0 ## Rotate pressure every 10-15 seconds
@export var sector_rotation_interval_max: float = 15.0
@export var escape_arc_degrees: float = 120.0          ## Guaranteed open escape arc width
@export var min_spawn_distance: float = 38.0           ## Standoff distance from player (38-45m)
@export var max_spawn_distance: float = 85.0
@export var camera_frustum_margin_px: float = 100.0

@export_category("Quiet Cleanup")
@export var despawn_distance: float = 130.0    ## Cleanup distance threshold
@export var despawn_grace_time: float = 6.0    ## Time unengaged/offscreen before cleanup
@export var recycle_budget_ratio: float = 0.50 ## Recycled fraction of spawn budget

func get_wave_target(wave_num: int) -> Resource:
	if wave_num >= 1 and wave_num <= wave_targets.size():
		return wave_targets[wave_num - 1]
	if not wave_targets.is_empty():
		return wave_targets.back()
	return null

static func create_low_pressure_survivors_profile() -> Resource:
	var profile: Resource = (load("res://scripts/resources/difficulty_profile.gd") as GDScript).new()
	profile.profile_name = "LOW_PRESSURE_SURVIVORS"
	profile.display_name = "Low-Pressure Survivors (Default)"
	profile.surge_interval_min = 75.0
	profile.surge_interval_max = 95.0
	profile.surge_duration_min = 8.0
	profile.surge_duration_max = 12.0
	profile.surge_pressure_bonus = 0.35
	profile.recovery_duration_min = 10.0
	profile.recovery_duration_max = 14.0
	profile.recovery_spawn_mult = 0.30
	profile.formation_stagger_min = 0.25
	profile.formation_stagger_max = 0.55
	profile.sector_rotation_interval_min = 10.0
	profile.sector_rotation_interval_max = 15.0
	profile.escape_arc_degrees = 120.0
	profile.min_spawn_distance = 38.0
	profile.max_spawn_distance = 85.0
	profile.despawn_distance = 130.0
	profile.despawn_grace_time = 6.0
	profile.recycle_budget_ratio = 0.50

	var targets: Array[Resource] = []

	# Wave 1: Visual 8-12, node cap 8, ~90% fodder, 10% light shooters. No heavy/special/air.
	var w1: Resource = WavePopulationTargetClass.new()
	w1.wave_number = 1
	w1.duration = 45.0
	w1.announcement = "WAVE 1 // HOSTILE INFANTRY CONTACT"
	w1.visual_crowd_min = 8
	w1.visual_crowd_max = 12
	w1.node_cap = 8
	w1.composition_weights = {"fodder": 0.90, "light_shooter": 0.10}
	w1.allowed_roles = ["fodder", "light_shooter"]
	w1.spawn_interval_min = 1.4
	w1.spawn_interval_max = 2.4
	targets.append(w1)

	# Wave 2: Visual 12-16, node cap 10, ~85% fodder, 15% light shooters.
	var w2: Resource = WavePopulationTargetClass.new()
	w2.wave_number = 2
	w2.duration = 45.0
	w2.announcement = "WAVE 2 // ARMORED PATROL INBOUND"
	w2.visual_crowd_min = 12
	w2.visual_crowd_max = 16
	w2.node_cap = 10
	w2.composition_weights = {"fodder": 0.85, "light_shooter": 0.15}
	w2.allowed_roles = ["fodder", "light_shooter"]
	w2.spawn_interval_min = 1.4
	w2.spawn_interval_max = 2.4
	targets.append(w2)

	# Wave 3: Visual 16-22, node cap 12, ~75% fodder, 20% light shooters, 5% armored; max 1 medium armored.
	var w3: Resource = WavePopulationTargetClass.new()
	w3.wave_number = 3
	w3.duration = 45.0
	w3.announcement = "WAVE 3 // SUSTAINED GROUND ASSAULT"
	w3.visual_crowd_min = 16
	w3.visual_crowd_max = 22
	w3.node_cap = 12
	w3.composition_weights = {"fodder": 0.75, "light_shooter": 0.20, "armored": 0.05}
	w3.allowed_roles = ["fodder", "light_shooter", "armored"]
	w3.max_medium_armored = 1
	w3.spawn_interval_min = 1.4
	w3.spawn_interval_max = 2.4
	targets.append(w3)

	# Wave 4: Visual 20-26, node cap 14, ~70% fodder, 20% light shooters, 10% armored; max 1 heavy.
	var w4: Resource = WavePopulationTargetClass.new()
	w4.wave_number = 4
	w4.duration = 45.0
	w4.announcement = "WAVE 4 // HEAVY ARMOR CONVOY INBOUND"
	w4.visual_crowd_min = 20
	w4.visual_crowd_max = 26
	w4.node_cap = 14
	w4.composition_weights = {"fodder": 0.70, "light_shooter": 0.20, "armored": 0.10}
	w4.allowed_roles = ["fodder", "light_shooter", "armored", "heavy"]
	w4.max_heavy = 1
	w4.spawn_interval_min = 1.1
	w4.spawn_interval_max = 2.0
	targets.append(w4)

	# Wave 5: Visual 24-30, node cap 16; max 1 SAM, max 1 mortar; never in same formation.
	var w5: Resource = WavePopulationTargetClass.new()
	w5.wave_number = 5
	w5.duration = 45.0
	w5.announcement = "WAVE 5 // SAM & MORTAR FIRE SUPPORT DETECTED"
	w5.visual_crowd_min = 24
	w5.visual_crowd_max = 30
	w5.node_cap = 16
	w5.composition_weights = {"fodder": 0.65, "light_shooter": 0.20, "armored": 0.10, "anti_air": 0.025, "mortar": 0.025}
	w5.allowed_roles = ["fodder", "light_shooter", "armored", "heavy", "anti_air", "mortar"]
	w5.max_sam = 1
	w5.max_mortar = 1
	w5.spawn_interval_min = 1.1
	w5.spawn_interval_max = 2.0
	targets.append(w5)

	# Wave 6: Visual 24-32, node cap 17; air enemies introduced gradually (first enters alone/staggered).
	var w6: Resource = WavePopulationTargetClass.new()
	w6.wave_number = 6
	w6.duration = 45.0
	w6.announcement = "WAVE 6 // AIR THREAT: RECON SQUADRONS CONTACT"
	w6.visual_crowd_min = 24
	w6.visual_crowd_max = 32
	w6.node_cap = 17
	w6.composition_weights = {"fodder": 0.60, "light_shooter": 0.18, "armored": 0.10, "air_scout": 0.12}
	w6.allowed_roles = ["fodder", "light_shooter", "armored", "heavy", "anti_air", "mortar", "air_scout", "air_raider"]
	w6.max_air = 2
	w6.spawn_interval_min = 1.1
	w6.spawn_interval_max = 2.0
	targets.append(w6)

	# Wave 7: Visual 26-34, node cap 18.
	var w7: Resource = WavePopulationTargetClass.new()
	w7.wave_number = 7
	w7.duration = 45.0
	w7.announcement = "WAVE 7 // COMBINED AIR & ARMORED PRESSURE"
	w7.visual_crowd_min = 26
	w7.visual_crowd_max = 34
	w7.node_cap = 18
	w7.composition_weights = {"fodder": 0.55, "light_shooter": 0.18, "armored": 0.12, "air_scout": 0.10, "air_raider": 0.05}
	w7.allowed_roles = ["fodder", "light_shooter", "armored", "heavy", "anti_air", "mortar", "air_scout", "air_raider", "air_transport"]
	w7.max_air = 3
	w7.spawn_interval_min = 0.9
	w7.spawn_interval_max = 1.7
	targets.append(w7)

	# Wave 8: Visual 28-36, node cap 19; heavy enemies remain a minority.
	var w8: Resource = WavePopulationTargetClass.new()
	w8.wave_number = 8
	w8.duration = 45.0
	w8.announcement = "WAVE 8 // AIR STRIKE & ADVANCED FORMATIONS"
	w8.visual_crowd_min = 28
	w8.visual_crowd_max = 36
	w8.node_cap = 19
	w8.composition_weights = {"fodder": 0.50, "light_shooter": 0.18, "armored": 0.12, "heavy": 0.05, "air_scout": 0.08, "air_raider": 0.05, "air_gunship": 0.02}
	w8.allowed_roles = ["fodder", "light_shooter", "armored", "heavy", "anti_air", "mortar", "air_scout", "air_raider", "air_gunship", "air_jammer"]
	w8.max_heavy = 2
	w8.max_air = 4
	w8.spawn_interval_min = 0.9
	w8.spawn_interval_max = 1.7
	targets.append(w8)

	# Wave 9: Visual 30-40, node cap 20; highest normal combined-arms population.
	var w9: Resource = WavePopulationTargetClass.new()
	w9.wave_number = 9
	w9.duration = 45.0
	w9.announcement = "WAVE 9 // MAXIMUM THREAT SATURATION"
	w9.visual_crowd_min = 30
	w9.visual_crowd_max = 40
	w9.node_cap = 20
	w9.composition_weights = {"fodder": 0.45, "light_shooter": 0.18, "armored": 0.14, "heavy": 0.06, "air_scout": 0.08, "air_raider": 0.05, "air_gunship": 0.04}
	w9.allowed_roles = ["fodder", "light_shooter", "armored", "heavy", "anti_air", "mortar", "air_scout", "air_raider", "air_gunship", "air_jammer", "air_ace"]
	w9.max_heavy = 2
	w9.max_air = 5
	w9.spawn_interval_min = 0.9
	w9.spawn_interval_max = 1.7
	targets.append(w9)

	# Wave 10: Boss + 8-12 visual support units; support node cap 10 (excluding boss).
	var w10: Resource = WavePopulationTargetClass.new()
	w10.wave_number = 10
	w10.duration = 60.0
	w10.announcement = "WAVE 10 // WARNING: ARCHON HEAVY GUNSHIP ENGAGEMENT"
	w10.is_boss_wave = true
	w10.support_visual_crowd_min = 8
	w10.support_visual_crowd_max = 12
	w10.support_node_cap = 10
	w10.visual_crowd_min = 8
	w10.visual_crowd_max = 12
	w10.node_cap = 11 # 1 boss + 10 support
	w10.composition_weights = {"fodder": 0.60, "light_shooter": 0.25, "armored": 0.15}
	w10.allowed_roles = ["fodder", "light_shooter", "armored", "boss"]
	w10.spawn_interval_min = 1.4
	w10.spawn_interval_max = 2.4
	targets.append(w10)

	profile.wave_targets = targets
	return profile
