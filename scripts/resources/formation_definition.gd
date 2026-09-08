class_name FormationDefinition
extends Resource

## Data definition for procedural formations and encounter cards.
## Selected by Threat/Spawn Director based on budget, elapsed time, district, caps, and variety rules.

enum FormationCategory {
	FODDER,
	ARMORED,
	AIR,
	SUPPORT,
	MIXED
}

@export var formation_id: String = "light_patrol"
@export var display_name: String = "Light Patrol"
@export var category: FormationCategory = FormationCategory.FODDER

@export var min_elapsed_time: float = 0.0 # Unlock threshold in seconds (0s, 120s, 300s, 480s)
@export var ground_budget_cost: float = 20.0
@export var air_budget_cost: float = 0.0

@export var preferred_districts: Array[String] = []
@export var preferred_ground_sources: Array[String] = []

## Array of unit dictionaries:
## {
##   "scene_path": String,
##   "count": int,
##   "is_air": bool,
##   "offset": Vector3,
##   "cap_tag": String
## }
@export var units: Array[Dictionary] = []

## Caps that must not be exceeded to spawn this formation:
## e.g. {"sam": 1}, {"mortar": 1}, {"gunship": 1}, {"jammer": 1}, {"transport": 1}
@export var required_caps: Dictionary = {}
