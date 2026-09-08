class_name GroundEnemyArchetype
extends Resource

## Data definition for modular ground vehicle enemy archetypes.
## Controls combat mobility, weapon payload, threat costs, and AI behavior.

enum WeaponType {
	CANNON,          # Heavy single shot (Tank, IFV)
	RAPID_MG,        # Rapid machine gun bursts (Scout Buggy, APC defense)
	ROCKET_BURST,    # Telegraphed rocket volley (Rocket Technical)
	MORTAR_SHELL,    # High-arc area denial with ground telegraph (Mortar Carrier)
	TROOP_DEPLOY,    # Deploys infantry squad upon combat entry (Troop Carrier APC)
	JAMMER_ECM       # Electronic warfare support interfering with targeting (Jammer Vehicle)
}

@export_category("Identity & Threat")
@export var archetype_name: String = "Ground Enemy"
@export var threat_cost: int = 6
@export var threat_score: float = 0.6 # Relative priority for player targeting (0.0 to 1.5)
@export var is_elite: bool = false
@export var formation_tags: Array[String] = []

@export_category("Survivability")
@export var max_health: float = 75.0
@export var is_armored: bool = true
@export var salvage_reward: int = 80
@export var xp_reward: int = 80

@export_category("Mobility & Standoff")
@export var move_speed: float = 7.5
@export var preferred_range: float = 36.0
@export var threat_range: float = 55.0

@export_category("AI Timings & Fire Timing")
@export var aim_prep_time: float = 0.5
@export var charge_time: float = 0.45
@export var reload_time: float = 2.0
@export var burst_count: int = 1
@export var burst_interval: float = 0.12

@export_category("Weapons & Tactics")
@export var weapon_type: WeaponType = WeaponType.CANNON
@export var damage_per_shot: float = 12.0
@export var is_command_unit: bool = false
