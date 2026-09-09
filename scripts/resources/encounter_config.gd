class_name EncounterConfig
extends Resource

## Central configuration resource for the survival-style escalating encounter system.
## Inspired by Vampire Survivors and Megabonk, adapted to 3D helicopter combat.

@export_category("Run Phases & Warm-Up")
@export var warmup_duration: float = 20.0 ## Opening grace period with reduced threat
@export var escalation_duration: float = 480.0 ## 8 minutes to reach peak intensity

@export_category("Budget & Threat Rates")
@export var base_ground_budget_rate: float = 12.0 ## Ground budget points accumulated per second at start
@export var base_air_budget_rate: float = 6.0 ## Air budget points accumulated per second at start
@export var max_ground_budget_rate: float = 34.0 ## Ground budget points accumulated per second at peak
@export var max_air_budget_rate: float = 18.0 ## Air budget points accumulated per second at peak
@export var budget_curve_power: float = 1.35 ## Exponential growth factor for budget curve

@export_category("Population Caps")
@export var warmup_ground_cap: int = 5
@export var warmup_air_cap: int = 2
@export var max_ground_cap: int = 14
@export var max_air_cap: int = 6
@export var global_active_cap: int = 20 ## Bounded limit for silky 60 FPS on Compatibility renderer

@export_category("Surge & Recovery Cycle")
@export var surge_interval_min: float = 75.0 ## Minimum time between surge triggers
@export var surge_interval_max: float = 90.0 ## Maximum time between surge triggers
@export var surge_duration: float = 14.0 ## Duration of intense horde pressure
@export var surge_budget_bonus_ground: float = 50.0 ## Instant budget burst upon surge
@export var surge_budget_bonus_air: float = 30.0 ## Instant budget burst upon surge
@export var recovery_duration: float = 10.0 ## Calm breather post-surge for XP collection & repositioning
@export var recovery_breather_duration: float = 10.0
@export var recovery_spawn_rate_mult: float = 0.30 ## Spawn frequency reduction during recovery
@export var recovery_budget_rate_mult: float = 0.30

@export_category("Distance & Frustum Safety")
@export var min_camera_margin_pixels: float = 100.0 ## Viewport boundary buffer beyond screen edges
@export var camera_frustum_margin_px: float = 100.0
@export var min_player_standoff: float = 38.0 ## Minimum safe distance from player to avoid pop-in
@export var spawn_distance_min: float = 38.0
@export var max_spawn_radius: float = 85.0 ## Maximum radius around player for active spawns
@export var spawn_distance_max: float = 85.0
@export var lead_velocity_scale: float = 1.2 ## Projects spawn ring forward based on helicopter velocity
@export var velocity_lead_time: float = 1.2
@export var despawn_distance: float = 130.0 ## Distance threshold to mark unengaged enemies for cleanup
@export var despawn_distance_threshold: float = 130.0
@export var despawn_grace_time: float = 6.0 ## Time an enemy must remain unengaged and offscreen to despawn
@export var despawn_offscreen_time_threshold: float = 10.0
@export var offscreen_cleanup_check_interval: float = 2.0
@export var recycle_budget_ratio: float = 0.50
@export var boundary_redistribution_margin: float = 25.0
@export var budget_growth_power: float = 1.35
