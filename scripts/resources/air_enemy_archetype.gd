class_name AirEnemyArchetype
extends Resource

## Data definition for modular flying helicopter enemy archetypes.
## Controls combat mobility, weapon payload, threat costs, and AI behavior.

enum WeaponType {
	MACHINE_GUN,
	ROCKET_SALVO,
	TRANSPORT_DEPLOY,
	HEAVY_CANNON_AND_MISSILES,
	JAMMER_SUPPORT,
	ACE_ARSENAL
}

@export_category("Identity & Threat")
@export var archetype_name: String = "Air Enemy"
@export var threat_cost: int = 4
@export var threat_score: float = 0.5 # Relative priority for player targeting (0.0 to 1.5)
@export var is_elite: bool = false
@export var formation_tags: Array[String] = []

@export_category("Survivability")
@export var max_health: float = 30.0
@export var salvage_reward: int = 40
@export var xp_reward: int = 40

@export_category("Flight Mobility")
@export var cruise_speed: float = 28.0
@export var attack_speed: float = 34.0
@export var turn_speed: float = 4.0
@export var preferred_distance: float = 30.0
@export var orbit_distance: float = 28.0
@export var altitude_min: float = 12.0
@export var altitude_max: float = 18.0

@export_category("AI Timings & Aggression")
@export var aggression: float = 0.5 # 0.0 to 1.0, scales aggressiveness of attack runs
@export var attack_cooldown: float = 2.0
@export var strafe_duration: float = 2.0
@export var reposition_delay: float = 2.5
@export var approach_timeout: float = 5.0

@export_category("Weapons & Tactics")
@export var weapon_type: WeaponType = WeaponType.MACHINE_GUN
@export var damage_per_shot: float = 2.5
@export var fire_rate: float = 8.0 # Shots per second during burst
@export var burst_count: int = 4
@export var missile_cooldown: float = 6.0
@export var missile_lock_time: float = 1.2
