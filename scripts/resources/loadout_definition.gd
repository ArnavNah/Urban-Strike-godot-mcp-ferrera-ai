class_name LoadoutDefinition
extends Resource

## Data-driven flight loadout profile for Heli-Strike.
## Defines distinct flight characteristics, weapon adjustments, and starting equipment.

@export var id: String = "balanced"
@export var display_name: String = "AH-9 VULTURE"
@export var designation: String = "COMBAT BASELINE"
@export var role_summary: String = "Multi-role attack helicopter with balanced hull, standard chaingun cadence, and standard missile payload."
@export var max_health: float = 100.0
@export var forward_speed: float = 38.0
@export var strafe_speed: float = 28.0
@export var active_response: float = 7.5
@export var chaingun_fire_rate: float = 11.5
@export var chaingun_damage: float = 6.0
@export var missile_cooldown: float = 2.2
@export var flare_recharge: float = 9.0
@export var starts_with_wingman: bool = false
@export var passive_repair_rate: float = 0.0

static var _catalogue: Dictionary = {}

static func get_catalogue() -> Dictionary:
	if not _catalogue.is_empty():
		return _catalogue

	# 1. Balanced: Baseline AH-9
	var balanced := LoadoutDefinition.new()
	balanced.id = "balanced"
	balanced.display_name = "AH-9 VULTURE"
	balanced.designation = "BALANCED"
	balanced.role_summary = "Standard multi-role airframe. Balanced armor, standard 11.5 rps chaingun, 2.2s missile cycle."
	balanced.max_health = 100.0
	balanced.forward_speed = 38.0
	balanced.strafe_speed = 28.0
	balanced.active_response = 7.5
	balanced.chaingun_fire_rate = 11.5
	balanced.chaingun_damage = 6.0
	balanced.missile_cooldown = 2.2
	balanced.flare_recharge = 9.0
	balanced.starts_with_wingman = false
	balanced.passive_repair_rate = 0.0
	_catalogue["balanced"] = balanced

	# 2. Interceptor: AH-9X
	var interceptor := LoadoutDefinition.new()
	interceptor.id = "interceptor"
	interceptor.display_name = "AH-9X INTERCEPTOR"
	interceptor.designation = "INTERCEPTOR"
	interceptor.role_summary = "High-speed strike gunship. +18% cruise speed, rapid 14.5 rps chaingun, -20% hull, +36% missile cooldown."
	interceptor.max_health = 80.0
	interceptor.forward_speed = 45.0
	interceptor.strafe_speed = 33.0
	interceptor.active_response = 9.0
	interceptor.chaingun_fire_rate = 14.5
	interceptor.chaingun_damage = 5.5
	interceptor.missile_cooldown = 3.0
	interceptor.flare_recharge = 9.0
	interceptor.starts_with_wingman = false
	interceptor.passive_repair_rate = 0.0
	_catalogue["interceptor"] = interceptor

	# 3. Support: AH-9S Guardian
	var support := LoadoutDefinition.new()
	support.id = "support"
	support.display_name = "AH-9S GUARDIAN"
	support.designation = "SUPPORT"
	support.role_summary = "Heavy escort fortress. +30% hull, 33% faster flare cycle, starts with 1 Escort Wingman and Nanite Repair Field."
	support.max_health = 130.0
	support.forward_speed = 33.0
	support.strafe_speed = 24.0
	support.active_response = 6.5
	support.chaingun_fire_rate = 10.5
	support.chaingun_damage = 6.0
	support.missile_cooldown = 2.2
	support.flare_recharge = 6.0
	support.starts_with_wingman = true
	support.passive_repair_rate = 2.0
	_catalogue["support"] = support

	return _catalogue

static func get_loadout(loadout_id: String) -> LoadoutDefinition:
	var cat := get_catalogue()
	if cat.has(loadout_id):
		return cat[loadout_id] as LoadoutDefinition
	return cat["balanced"] as LoadoutDefinition

static func get_loadout_ids() -> Array[String]:
	return ["balanced", "interceptor", "support"]
