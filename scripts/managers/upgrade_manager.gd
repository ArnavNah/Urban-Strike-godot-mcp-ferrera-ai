class_name UpgradeManager
extends Node

var current_xp: int = 0
var current_level: int = 1
var xp_needed: int = 50
var requisition_points: int = 0

var acquired_upgrades: Array[String] = []
var pending_levels: Array[int] = []
var is_choice_active: bool = false
var _offered_ids: Array[String] = []

signal requisition_awarded(current_points: int)

# Upgrade catalog with build synergies and evolutions
var upgrade_database: Dictionary = {
	"twin_barrel": {
		"id": "twin_barrel",
		"name": "Twin Barrel",
		"category": "Primary",
		"benefit": "+40% Chaingun Fire Rate",
		"tradeoff": "-15% Damage per Round",
		"is_evolution": false
	},
	"armor_piercing": {
		"id": "armor_piercing",
		"name": "Armor-Piercing Rounds",
		"category": "Primary",
		"benefit": "+50% Damage vs Ground Armor",
		"tradeoff": "-20% Damage vs Air Units",
		"is_evolution": false
	},
	"overclocked_feed": {
		"id": "overclocked_feed",
		"name": "Overclocked Feed",
		"category": "Primary",
		"benefit": "+20% Fire Rate & Damage",
		"tradeoff": "Builds 25% More Heat per Shot",
		"is_evolution": false
	},
	"ricochet_rounds": {
		"id": "ricochet_rounds",
		"name": "Ricochet Rounds",
		"category": "Primary",
		"benefit": "Autocannon Shells Ricochet Into Nearby Targets",
		"tradeoff": "-10% Projectile Velocity",
		"is_evolution": false
	},
	"rapid_lock": {
		"id": "rapid_lock",
		"name": "Rapid Lock Suite",
		"category": "Secondary",
		"benefit": "Missile Lock Time Halved (0.48s)",
		"tradeoff": "20% Narrower Missile Lock Cone",
		"is_evolution": false
	},
	"multi_launch": {
		"id": "multi_launch",
		"name": "Multi-Launch Pod",
		"category": "Secondary",
		"benefit": "+2 Missiles per Salvo",
		"tradeoff": "+20% Reload Cooldown",
		"is_evolution": false
	},
	"reinforced_airframe": {
		"id": "reinforced_airframe",
		"name": "Reinforced Airframe",
		"category": "Passive",
		"benefit": "+35 Max Hull Integrity",
		"tradeoff": "-10% Top Flight Speed",
		"is_evolution": false
	},
	"afterburner": {
		"id": "afterburner",
		"name": "Afterburner Boost",
		"category": "Passive",
		"benefit": "+25% Lateral Strafe Speed",
		"tradeoff": "20% Longer Horizontal Stopping Time",
		"is_evolution": false
	},
	"repair_drone": {
		"id": "repair_drone",
		"name": "Auto-Repair Drone",
		"category": "Passive",
		"benefit": "Regenerates 4 HP/sec After 5s Without Damage",
		"tradeoff": "Disabled While Overheated",
		"is_evolution": false
	},
	# Evolutions & Build Synergies (GDD Section 15.6)
	"hellfire_minigun": {
		"id": "hellfire_minigun",
		"name": "🔥 HELLFIRE MINIGUN 🔥",
		"category": "EVOLUTION",
		"benefit": "+100% Fire Rate & ZERO OVERHEAT LOCKOUT",
		"tradeoff": "Evolution of Twin Barrel + Overclocked Feed",
		"is_evolution": true
	},
	"siege_cannon": {
		"id": "siege_cannon",
		"name": "SIEGE CANNON",
		"category": "EVOLUTION",
		"benefit": "+80% Ground Damage; Rounds Hit Two Enemies",
		"tradeoff": "Armor-Piercing + Airframe; Buildings Stop Rounds",
		"is_evolution": true
	},
	"ap_ricochet_cannon": {
		"id": "ap_ricochet_cannon",
		"name": "⚡ AP RICOCHET CANNON ⚡",
		"category": "EVOLUTION",
		"benefit": "+80% Armor Shredding, +2 Penetration, & Ricochets",
		"tradeoff": "Evolution of Armor-Piercing + Ricochet Rounds",
		"is_evolution": true
	},
	"swarm_rockets": {
		"id": "swarm_rockets",
		"name": "🚀 SWARM ROCKET POD 🚀",
		"category": "EVOLUTION",
		"benefit": "Fires 6 Micro-Guided Homing Rockets in Rapid Ripple",
		"tradeoff": "Evolution of Rapid Lock + Multi-Launch",
		"is_evolution": true
	},
	"multi_lock_hellfire": {
		"id": "multi_lock_hellfire",
		"name": "🎯 MULTI-LOCK HELLFIRE 🎯",
		"category": "EVOLUTION",
		"benefit": "Simultaneous 3-Target Tracking & Tri-Missile Volley",
		"tradeoff": "Evolution of Rapid Lock + Armor-Piercing",
		"is_evolution": true
	},
	"aegis_airframe": {
		"id": "aegis_airframe",
		"name": "🛡️ AEGIS COUNTERMEASURE 🛡️",
		"category": "EVOLUTION",
		"benefit": "+50 Max Hull, Flare Shockwave & Emergency Stasis Shield at <35% HP",
		"tradeoff": "Evolution of Reinforced Airframe + Repair Drone",
		"is_evolution": true
	}
}

func _ready() -> void:
	add_to_group("upgrade_manager")
	_notify_xp()

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	while current_xp >= xp_needed:
		current_xp -= xp_needed
		current_level += 1
		xp_needed = maxi(1, int(xp_needed * 1.45))
		pending_levels.append(current_level)
	_notify_xp()
	_present_next_choice.call_deferred()

func award_requisition(amount: int = 1) -> void:
	requisition_points += amount
	emit_signal("requisition_awarded", requisition_points)
	pending_levels.append(current_level)
	_present_next_choice.call_deferred()

func _notify_xp() -> void:
	if EventBus:
		EventBus.xp_updated.emit(current_xp, xp_needed, current_level)

func _present_next_choice() -> void:
	if is_choice_active or pending_levels.is_empty():
		return
	var menu := get_tree().get_first_node_in_group("level_up_menu")
	if not menu or not menu.has_method("display_cards"):
		return
	var choices := get_random_choices(3)
	_offered_ids.clear()
	for choice in choices:
		_offered_ids.append(choice["id"])
	is_choice_active = true
	if not menu.display_cards(choices, pending_levels[0]):
		is_choice_active = false
		return
	if EventBus:
		EventBus.level_up_requested.emit(pending_levels[0])

func _is_eligible(upgrade_id: String) -> bool:
	if not upgrade_database.has(upgrade_id):
		return false
	if acquired_upgrades.has(upgrade_id):
		return false

	# Prerequisite synergy checks
	match upgrade_id:
		"hellfire_minigun":
			return acquired_upgrades.has("twin_barrel") and acquired_upgrades.has("overclocked_feed")
		"siege_cannon":
			return acquired_upgrades.has("armor_piercing") and acquired_upgrades.has("reinforced_airframe")
		"ap_ricochet_cannon":
			return acquired_upgrades.has("armor_piercing") and acquired_upgrades.has("ricochet_rounds")
		"swarm_rockets":
			return acquired_upgrades.has("rapid_lock") and acquired_upgrades.has("multi_launch")
		"multi_lock_hellfire":
			return acquired_upgrades.has("rapid_lock") and acquired_upgrades.has("armor_piercing")
		"aegis_airframe":
			return acquired_upgrades.has("reinforced_airframe") and acquired_upgrades.has("repair_drone")
		_:
			return true

func get_random_choices(count: int) -> Array[Dictionary]:
	var evolutions: Array[Dictionary] = []
	var standard: Array[Dictionary] = []
	for key in upgrade_database:
		var upgrade_id := str(key)
		if not _is_eligible(upgrade_id):
			continue
		var up: Dictionary = upgrade_database[key]
		if up.get("is_evolution", false):
			evolutions.append(up)
		else:
			standard.append(up)
	standard.shuffle()
	var selected: Array[Dictionary] = []
	for up in evolutions + standard:
		if selected.size() >= count:
			break
		selected.append(up.duplicate(true))
	return selected

func select_choice(upgrade_id: String) -> bool:
	if not is_choice_active or pending_levels.is_empty():
		return false
	if upgrade_id.is_empty():
		if not _offered_ids.is_empty():
			return false
	else:
		if not _offered_ids.has(upgrade_id) or not apply_upgrade(upgrade_id):
			return false
	pending_levels.pop_front()
	_offered_ids.clear()
	is_choice_active = false
	if pending_levels.is_empty():
		var menu := get_tree().get_first_node_in_group("level_up_menu")
		if menu and menu.has_method("finish_selection"):
			menu.finish_selection()
	else:
		_present_next_choice()
	return true

func apply_upgrade(upgrade_id: String) -> bool:
	if not _is_eligible(upgrade_id):
		return false
	var player := get_tree().get_first_node_in_group("player") as PlayerHelicopter
	if not is_instance_valid(player) or not player.is_alive:
		return false
	var gun := player.chaingun as Chaingun
	var pod := player.missile_pod as MissilePod

	match upgrade_id:
		"twin_barrel":
			if not gun:
				return false
			gun.fire_rate *= 1.4
			gun.damage_per_shot *= 0.85
		"armor_piercing":
			if not gun:
				return false
			gun.armored_damage_multiplier *= 1.5
			gun.air_damage_multiplier *= 0.8
		"overclocked_feed":
			if not gun:
				return false
			gun.fire_rate *= 1.2
			gun.damage_per_shot *= 1.2
			gun.heat_per_shot *= 1.25
		"ricochet_rounds":
			if not gun:
				return false
			gun.ricochet_count += 1
		"rapid_lock":
			if not pod:
				return false
			pod.lock_duration *= 0.5
			pod.lock_cone_scale *= 0.8
		"multi_launch":
			if not pod:
				return false
			pod.multi_launch_count += 2
			pod.fire_cooldown *= 1.2
		"reinforced_airframe":
			player.max_health += 35.0
			player.current_health += 35.0
			player.max_forward_speed *= 0.9
			player.health_changed.emit(player.current_health, player.max_health)
			if EventBus:
				EventBus.player_health_changed.emit(player.current_health, player.max_health)
		"afterburner":
			player.strafe_speed *= 1.25
			# Exponential decay takes 20% longer to reach the same stopping threshold.
			player.release_velocity_response /= 1.2
		"repair_drone":
			if player.has_method("enable_repair_drone"):
				player.enable_repair_drone(4.0)
			else:
				player.repair_drone_enabled = true
		# Evolutions / Build Synergies
		"hellfire_minigun":
			if not gun:
				return false
			gun.fire_rate *= 2.0
			gun.heat_per_shot = 0.0
			gun.current_heat = 0.0
			gun.is_overheated = false
			gun._overheat_timer = 0.0
			gun._notify_heat()
		"siege_cannon":
			if not gun:
				return false
			gun.ground_damage_multiplier *= 1.8
			gun.enemy_hit_limit = 2
		"ap_ricochet_cannon":
			if not gun:
				return false
			gun.armor_multiplier = 1.8
			gun.pierce_count += 2
			gun.ricochet_count += 1
			gun.damage_per_shot *= 1.35
		"swarm_rockets":
			if not pod:
				return false
			pod.is_swarm_rockets = true
			pod.multi_launch_count = 6
			pod.fire_cooldown = 1.8
		"multi_lock_hellfire":
			if not pod:
				return false
			pod.is_multi_lock = true
			pod.max_lock_targets = 3
			pod.lock_duration = 0.45
		"aegis_airframe":
			player.max_health += 50.0
			player.current_health += 50.0
			if player.has_method("enable_aegis_shield"):
				player.enable_aegis_shield()
			player.health_changed.emit(player.current_health, player.max_health)
			if EventBus:
				EventBus.player_health_changed.emit(player.current_health, player.max_health)
		_:
			return false

	acquired_upgrades.append(upgrade_id)
	if EventBus:
		EventBus.upgrade_applied.emit(upgrade_id)
	return true
