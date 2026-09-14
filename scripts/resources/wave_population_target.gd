class_name WavePopulationTarget
extends Resource

## Data definition for per-wave population targets, node caps, and composition weights in Survivors mode.
## Controls visible horde density separately from active attack slots (Phase 10B).

@export_category("Wave Identity & Duration")
@export var wave_number: int = 1
@export var duration: float = 45.0 ## Approximately 45s per wave for low-difficulty profile
@export var announcement: String = ""

@export_category("Population Targets & Caps")
@export var visual_crowd_min: int = 8
@export var visual_crowd_max: int = 12
@export var node_cap: int = 8 ## Hard ceiling on simultaneously living enemy nodes

@export_category("Composition Weights & Roles")
## Dictionary mapping role String (e.g. "fodder", "light_shooter", "armored", "heavy", "air_scout") to normalized float weight
@export var composition_weights: Dictionary = {
	"fodder": 0.90,
	"light_shooter": 0.10
}
@export var allowed_roles: Array = ["fodder", "light_shooter"]

@export_category("Special Enemy Caps")
@export var max_medium_armored: int = 0 ## Wave 3: max 1
@export var max_heavy: int = 0          ## Wave 4: max 1
@export var max_sam: int = 0            ## Wave 5: max 1
@export var max_mortar: int = 0         ## Wave 5: max 1
@export var max_air: int = 0            ## Wave 6+: introduced gradually

@export_category("Boss & Support Units")
@export var is_boss_wave: bool = false
@export var support_node_cap: int = 10
@export var support_visual_crowd_min: int = 8
@export var support_visual_crowd_max: int = 12

@export_category("Spawn Rhythm")
@export var spawn_interval_min: float = 1.4
@export var spawn_interval_max: float = 2.4
@export var formation_interval_min: float = 4.0
@export var formation_interval_max: float = 6.0
