class_name UpgradeManager
extends Node

## Manages survivor progression, level-up card drafting, upgrade definitions, and stat modifications.

static var instance: UpgradeManager = null

func _enter_tree() -> void:
	instance = self
	add_to_group("upgrade_manager")

func _exit_tree() -> void:
	if instance == self:
		instance = null

var current_xp: int = 0
var current_level: int = 1
var xp_needed: int = 50
var requisition_points: int = 0

var acquired_upgrades: Array[String] = []
var pending_levels: Array[int] = []
var is_choice_active: bool = false
var _offered_ids: Array[String] = []

# Legendary limit: Maximum 1 acquired Legendary per run (GDD 15.7)
var has_acquired_legendary: bool = false
var acquired_legendary_id: String = ""
var acquired_legendary_count: int = 0

# First level-up guarantee tracking
var has_guaranteed_mini_heli_offered: bool = false
var guarantee_mini_heli_on_first_offer: bool = true

# Companion progression hooks for future ranks (Step 5A Section 9)
var mini_heli_rank: int = 1
var mini_heli_damage_mult: float = 1.0
var mini_heli_fire_rate_mult: float = 1.0
var mini_heli_range_mult: float = 1.0
var mini_heli_has_rockets: bool = false
var has_deployed_wingmen: bool = false

signal requisition_awarded(current_points: int)

# Upgrade catalog with definitions, build synergies, rarities, and evolutions
var upgrade_database: Dictionary = {
	# --- Common (Base Upgrade Pool, 70% normalized weight) ---
	"multi_shot": {
		"id": "multi_shot",
		"name": "Multi-Shot Cannons",
		"category": "Primary",
		"rarity": "Common",
		"benefit": "Fires 2-round spread per chaingun shot",
		"tradeoff": "+15% Heat Generation per burst",
		"current_value": "1 Round / Shot",
		"next_value": "2-Round Spread (+15% Heat)",
		"is_evolution": false,
		"priority": 0
	},
	"faster_cannon": {
		"id": "faster_cannon",
		"name": "High-Cadence Feeder",
		"category": "Primary",
		"rarity": "Common",
		"benefit": "+35% Chaingun Fire Rate",
		"tradeoff": "-10% Damage per round",
		"current_value": "11.5 RPS",
		"next_value": "15.5 RPS (-10% Dmg)",
		"is_evolution": false,
		"priority": 0
	},
	"twin_barrel": {
		"id": "twin_barrel",
		"name": "Twin Barrel",
		"category": "Primary",
		"rarity": "Common",
		"benefit": "+40% Chaingun Fire Rate",
		"tradeoff": "-15% Damage per Round",
		"current_value": "11.5 RPS",
		"next_value": "16.1 RPS (-15% Dmg)",
		"is_evolution": false,
		"priority": 0
	},
	"larger_explosions": {
		"id": "larger_explosions",
		"name": "High-Explosive Warheads",
		"category": "Secondary",
		"rarity": "Common",
		"benefit": "+50% Missile Blast Radius & +15% Splash Damage",
		"tradeoff": "-10% Missile Velocity",
		"current_value": "3.2m Blast Radius",
		"next_value": "4.8m Blast Radius (+15% Splash)",
		"is_evolution": false,
		"priority": 0
	},
	"missile_capacity": {
		"id": "missile_capacity",
		"name": "Expanded Missile Racks",
		"category": "Secondary",
		"rarity": "Common",
		"benefit": "+2 Max Missile Ammo Capacity",
		"tradeoff": "Requires battlefield ammo crate replenishment",
		"current_value": "6 Max Missiles",
		"next_value": "8 Max Missiles",
		"is_evolution": false,
		"priority": 0
	},
	"xp_magnet_range": {
		"id": "xp_magnet_range",
		"name": "Wide-Band Avionics",
		"category": "Avionics",
		"rarity": "Common",
		"benefit": "+60% XP & Salvage Magnet Range",
		"tradeoff": "Expanded sensor footprint",
		"current_value": "18.0m Radius",
		"next_value": "28.8m Radius",
		"is_evolution": false,
		"priority": 0
	},
	"movement_boost": {
		"id": "movement_boost",
		"name": "Turbine Overdrive",
		"category": "Airframe",
		"rarity": "Common",
		"benefit": "+25% Forward Speed & Strafe Velocity",
		"tradeoff": "10% Longer Inertial Stopping Distance",
		"current_value": "38.0 m/s Speed",
		"next_value": "47.5 m/s (+10% Stopping Dist)",
		"is_evolution": false,
		"priority": 0
	},
	"reinforced_airframe": {
		"id": "reinforced_airframe",
		"name": "Reinforced Airframe",
		"category": "Airframe",
		"rarity": "Common",
		"benefit": "+35 Max Hull & +10% Armor Reduction (Heals 35 HP on Select)",
		"tradeoff": "-10% Top Flight Speed",
		"current_value": "100 Hull",
		"next_value": "+35 Hull, Heal 35, +10% Armor (-10% Speed)",
		"is_evolution": false,
		"priority": 0
	},
	"afterburner": {
		"id": "afterburner",
		"name": "Afterburner Boost",
		"category": "Airframe",
		"rarity": "Common",
		"benefit": "+25% Lateral Strafe Speed",
		"tradeoff": "20% Longer Horizontal Stopping Time",
		"current_value": "28.0 m/s Strafe",
		"next_value": "35.0 m/s Strafe (+20% Decel Time)",
		"is_evolution": false,
		"priority": 0
	},

	# --- Rare (Specialized / Tactical Upgrades, 25% normalized weight) ---
	"armor_piercing": {
		"id": "armor_piercing",
		"name": "Armor-Piercing Rounds",
		"category": "Primary",
		"rarity": "Rare",
		"benefit": "+50% Damage vs Ground Armor",
		"tradeoff": "-20% Damage vs Air Units",
		"current_value": "1.0x vs Armor",
		"next_value": "1.5x Ground Armor / 0.8x Air",
		"is_evolution": false,
		"priority": 0
	},
	"overclocked_feed": {
		"id": "overclocked_feed",
		"name": "Overclocked Feed",
		"category": "Primary",
		"rarity": "Rare",
		"benefit": "+20% Fire Rate & Damage",
		"tradeoff": "Builds 25% More Heat per Shot",
		"current_value": "Standard Feed",
		"next_value": "+20% Rate & Dmg (+25% Heat)",
		"is_evolution": false,
		"priority": 0
	},
	"ricochet_rounds": {
		"id": "ricochet_rounds",
		"name": "Ricochet Rounds",
		"category": "Primary",
		"rarity": "Rare",
		"benefit": "Autocannon Shells Ricochet Into Nearby Targets",
		"tradeoff": "-10% Projectile Velocity",
		"current_value": "0 Ricochets",
		"next_value": "1 Ricochet on Impact",
		"is_evolution": false,
		"priority": 0
	},
	"rapid_lock": {
		"id": "rapid_lock",
		"name": "Rapid Lock Suite",
		"category": "Secondary",
		"rarity": "Rare",
		"benefit": "Missile Lock Time Halved (0.48s)",
		"tradeoff": "20% Narrower Missile Lock Cone",
		"current_value": "0.95s Lock",
		"next_value": "0.48s Lock (Narrower Cone)",
		"is_evolution": false,
		"priority": 0
	},
	"multi_launch": {
		"id": "multi_launch",
		"name": "Multi-Launch Pod",
		"category": "Secondary",
		"rarity": "Rare",
		"benefit": "+2 Missiles per Salvo",
		"tradeoff": "+20% Reload Cooldown",
		"current_value": "1 Missile / Salvo",
		"next_value": "3 Missiles / Salvo (+20% Cooldown)",
		"is_evolution": false,
		"priority": 0
	},
	"repair_drone": {
		"id": "repair_drone",
		"name": "Auto-Repair Drone",
		"category": "Support",
		"rarity": "Rare",
		"benefit": "Regenerates 4 HP/sec After 5s Without Damage",
		"tradeoff": "Disabled While Overheated",
		"current_value": "Inactive",
		"next_value": "4 HP/s (5s Out of Combat)",
		"is_evolution": false,
		"priority": 0
	},
	"mini_helicopter_support": {
		"id": "mini_helicopter_support",
		"name": "Support Wingmen",
		"category": "Support",
		"rarity": "Rare",
		"benefit": "Deploy two allied aircraft that attack enemies and intercept incoming fire. Each aircraft can be destroyed.",
		"tradeoff": "Independent health; lost aircraft can be restored in later upgrades",
		"current_value": "0 Escort Drones",
		"next_value": "2 Escort Drones",
		"is_evolution": false,
		"priority": 0
	},

	# --- Legendary (No-downside, 5% normalized weight, max 1 acquired per run, GDD 15.7) ---
	"overdrive_core": {
		"id": "overdrive_core",
		"name": "Overdrive Core",
		"category": "Legendary",
		"rarity": "Legendary",
		"benefit": "+15% Weapon Damage & -10% Cooldowns Across All Systems",
		"tradeoff": "None (Legendary Tech)",
		"current_value": "Standard Core",
		"next_value": "+15% Damage & -10% Cooldowns",
		"is_evolution": false,
		"priority": 0
	},
	"ghost_rotor": {
		"id": "ghost_rotor",
		"name": "Ghost Rotor ECM",
		"category": "Legendary",
		"rarity": "Legendary",
		"benefit": "Refractive ECM Barrier: Absorbs 1 Hit Every 12 Seconds",
		"tradeoff": "None (Legendary Tech)",
		"current_value": "Standard ECM",
		"next_value": "Absorbs 1 Hit Every 12s",
		"is_evolution": false,
		"priority": 0
	},
	"one_more_pass": {
		"id": "one_more_pass",
		"name": "One More Pass",
		"category": "Legendary",
		"rarity": "Legendary",
		"benefit": "Emergency Auto-Eject: Revives Helicopter Once at 30% Hull",
		"tradeoff": "None (Legendary Tech)",
		"current_value": "0 Revives",
		"next_value": "1 Emergency Revive (30% Hull)",
		"is_evolution": false,
		"priority": 0
	},

	# --- Evolutions (Deterministic Priority, outside ordinary rarity rolling, GDD 15.6) ---
	"hellfire_minigun": {
		"id": "hellfire_minigun",
		"name": "🔥 HELLFIRE MINIGUN 🔥",
		"category": "EVOLUTION",
		"rarity": "Evolution",
		"benefit": "+100% Fire Rate & ZERO OVERHEAT LOCKOUT",
		"tradeoff": "Evolution of Twin Barrel + Overclocked Feed",
		"current_value": "Overheating Autocannon",
		"next_value": "+100% Rate & Zero Overheat Lockout",
		"is_evolution": true,
		"priority": 1,
		"prerequisites": ["twin_barrel", "overclocked_feed"]
	},
	"siege_cannon": {
		"id": "siege_cannon",
		"name": "SIEGE CANNON",
		"category": "EVOLUTION",
		"rarity": "Evolution",
		"benefit": "+80% Ground Damage; Rounds Hit Two Enemies",
		"tradeoff": "Evolution of Armor-Piercing + Reinforced Airframe",
		"current_value": "Single-Target Shells",
		"next_value": "+80% Ground Dmg & 2 Target Piercing",
		"is_evolution": true,
		"priority": 2,
		"prerequisites": ["armor_piercing", "reinforced_airframe"]
	},
	"ap_ricochet_cannon": {
		"id": "ap_ricochet_cannon",
		"name": "⚡ AP RICOCHET CANNON ⚡",
		"category": "EVOLUTION",
		"rarity": "Evolution",
		"benefit": "+80% Armor Shredding, +2 Penetration, & Ricochets",
		"tradeoff": "Evolution of Armor-Piercing + Ricochet Rounds",
		"current_value": "Standard Cannon",
		"next_value": "+80% Armor Shred, +2 Pierce, Ricochets",
		"is_evolution": true,
		"priority": 3,
		"prerequisites": ["armor_piercing", "ricochet_rounds"]
	},
	"swarm_rockets": {
		"id": "swarm_rockets",
		"name": "🚀 SWARM ROCKET POD 🚀",
		"category": "EVOLUTION",
		"rarity": "Evolution",
		"benefit": "Fires 6 Micro-Guided Homing Rockets in Rapid Ripple",
		"tradeoff": "Evolution of Rapid Lock + Multi-Launch",
		"current_value": "Standard Salvo",
		"next_value": "6 Micro-Guided Homing Rockets",
		"is_evolution": true,
		"priority": 4,
		"prerequisites": ["rapid_lock", "multi_launch"]
	},
	"multi_lock_hellfire": {
		"id": "multi_lock_hellfire",
		"name": "🎯 MULTI-LOCK HELLFIRE 🎯",
		"category": "EVOLUTION",
		"rarity": "Evolution",
		"benefit": "Simultaneous 3-Target Tracking & Tri-Missile Volley",
		"tradeoff": "Evolution of Rapid Lock + Armor-Piercing",
		"current_value": "1 Target Lock",
		"next_value": "3-Target Multi-Lock Volley",
		"is_evolution": true,
		"priority": 5,
		"prerequisites": ["rapid_lock", "armor_piercing"]
	},
	"aegis_airframe": {
		"id": "aegis_airframe",
		"name": "🛡️ AEGIS COUNTERMEASURE 🛡️",
		"category": "EVOLUTION",
		"rarity": "Evolution",
		"benefit": "+50 Max Hull, Flare Shockwave & Emergency Stasis Shield at <35% HP",
		"tradeoff": "Evolution of Reinforced Airframe + Repair Drone",
		"current_value": "Standard Airframe",
		"next_value": "+50 Hull & Emergency Stasis Shield",
		"is_evolution": true,
		"priority": 6,
		"prerequisites": ["reinforced_airframe", "repair_drone"]
	}
}

# Typed UpgradeDefinition resources mapped by ID
var upgrade_definitions: Dictionary = {}

func _ready() -> void:
	add_to_group("upgrade_manager")
	_init_definitions()
	_notify_xp()

func _init_definitions() -> void:
	upgrade_definitions.clear()
	for key in upgrade_database:
		var data: Dictionary = upgrade_database[key]
		var def := UpgradeDefinition.new()
		def.id = str(data.get("id", key))
		def.display_name = str(data.get("name", def.id.capitalize()))
		def.category = str(data.get("category", "UPGRADE"))
		def.benefit = str(data.get("benefit", ""))
		def.tradeoff = str(data.get("tradeoff", ""))
		def.is_evolution = bool(data.get("is_evolution", false))
		def.rarity = str(data.get("rarity", "Evolution" if def.is_evolution else "Common"))
		def.current_value = str(data.get("current_value", ""))
		def.next_value = str(data.get("next_value", ""))
		def.priority = int(data.get("priority", 0))
		def.prerequisites.clear()
		for p in data.get("prerequisites", []):
			def.prerequisites.append(str(p))
		upgrade_definitions[def.id] = def

func get_definition(upgrade_id: String) -> UpgradeDefinition:
	if upgrade_id == "support_wingmen":
		upgrade_id = "mini_helicopter_support"
	return upgrade_definitions.get(upgrade_id, null)

func _get_active_player() -> PlayerHelicopter:
	var tree := get_tree()
	if not tree:
		return null
	var nodes := tree.get_nodes_in_group("player")
	for i in range(nodes.size() - 1, -1, -1):
		var p := nodes[i]
		if is_instance_valid(p) and not p.is_queued_for_deletion() and p is PlayerHelicopter:
			var parent := p.get_parent()
			var queued := false
			while parent:
				if parent.is_queued_for_deletion():
					queued = true
					break
				parent = parent.get_parent()
			if not queued:
				return p as PlayerHelicopter
	return null

## Smooth configurable XP curve balancing early progression and mid/late geometric scaling
func get_required_xp_for_level(level: int) -> int:
	match level:
		1:
			return 50
		2:
			return 90
		3:
			return 140
		4:
			return 200
		_:
			return int(200.0 * pow(1.28, float(level - 4)))

func get_living_wingmen() -> Array[MiniHelicopter]:
	var result: Array[MiniHelicopter] = []
	var tree := get_tree()
	if not tree:
		return result
	var nodes := tree.get_nodes_in_group("mini_helicopters")
	for node in nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node is MiniHelicopter:
			if (node as MiniHelicopter).is_alive:
				result.append(node as MiniHelicopter)
	return result

func get_living_wingmen_count() -> int:
	return get_living_wingmen().size()

func get_occupied_wingman_slots() -> Dictionary:
	var slots: Dictionary = {}
	for drone in get_living_wingmen():
		slots[drone.slot_id] = drone
	return slots

func on_wingman_destroyed(_slot: String, _wingman: MiniHelicopter = null) -> void:
	pass

func reset_run() -> void:
	current_xp = 0
	current_level = 1
	xp_needed = get_required_xp_for_level(current_level)
	requisition_points = 0
	acquired_upgrades.clear()
	pending_levels.clear()
	is_choice_active = false
	_offered_ids.clear()
	has_acquired_legendary = false
	acquired_legendary_id = ""
	acquired_legendary_count = 0
	has_guaranteed_mini_heli_offered = false
	mini_heli_rank = 1
	mini_heli_damage_mult = 1.0
	mini_heli_fire_rate_mult = 1.0
	mini_heli_range_mult = 1.0
	mini_heli_has_rockets = false
	has_deployed_wingmen = false
	var tree := get_tree()
	if tree:
		for drone in tree.get_nodes_in_group("mini_helicopters"):
			if is_instance_valid(drone) and not drone.is_queued_for_deletion():
				drone.queue_free()
	var player := _get_active_player()
	if is_instance_valid(player):
		if player.missile_pod and player.missile_pod.has_method("reset_ammo"):
			player.missile_pod.reset_ammo()
		if player.has_method("reset_legendaries"):
			player.reset_legendaries()
	var menu := get_tree().get_first_node_in_group("level_up_menu")
	if is_instance_valid(menu):
		menu.visible = false
		menu.set("_selection_ready", false)
		menu.set("_closing", false)
	var run := get_tree().get_first_node_in_group("run_state_controller")
	if is_instance_valid(run):
		run.set_pause_reason(&"upgrade", false)
	_notify_xp()

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	current_xp += amount
	while current_xp >= xp_needed:
		current_xp -= xp_needed
		current_level += 1
		xp_needed = get_required_xp_for_level(current_level)
		pending_levels.append(current_level)
	_notify_xp()
	_present_next_choice.call_deferred()

func award_requisition(amount: int = 1) -> void:
	requisition_points += amount
	emit_signal("requisition_awarded", requisition_points)

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
		if is_inside_tree() and not pending_levels.is_empty():
			get_tree().create_timer(0.08, true, false, true).timeout.connect(_present_next_choice)
		return
	if EventBus:
		EventBus.level_up_requested.emit(pending_levels[0])

func _is_eligible(upgrade_id: String) -> bool:
	if upgrade_id == "support_wingmen":
		upgrade_id = "mini_helicopter_support"
	if not upgrade_database.has(upgrade_id):
		return false

	# If a player node is present in the scene tree, verify live state and subsystems
	var player := _get_active_player()
	if is_instance_valid(player):
		if not player.is_alive:
			return false
		# Chaingun-dependent upgrades require chaingun node
		if upgrade_id in ["multi_shot", "faster_cannon", "twin_barrel", "armor_piercing", "overclocked_feed", "ricochet_rounds", "hellfire_minigun", "siege_cannon", "ap_ricochet_cannon"]:
			if not is_instance_valid(player.chaingun):
				return false
		# MissilePod-dependent upgrades require missile_pod node
		if upgrade_id in ["larger_explosions", "missile_capacity", "rapid_lock", "multi_launch", "swarm_rockets", "multi_lock_hellfire"]:
			if not is_instance_valid(player.missile_pod):
				return false

	# Special eligibility for Support Wingmen:
	# - If not yet acquired, eligible for initial deployment.
	# - If already acquired and deployed, eligible whenever fewer than 2 wingmen survive (to restore lost aircraft).
	# - If marked acquired without ever being deployed (catalog exhaustion simulation), ineligible.
	if upgrade_id == "mini_helicopter_support":
		if not acquired_upgrades.has("mini_helicopter_support"):
			return true
		if has_deployed_wingmen:
			return get_living_wingmen_count() < 2
		return false

	if acquired_upgrades.has(upgrade_id):
		return false

	var up: Dictionary = upgrade_database[upgrade_id]

	# Legendary rule: Max 1 acquired Legendary per run
	if up.get("rarity") == "Legendary" and has_acquired_legendary:
		return false

	# Prerequisite synergy checks
	match upgrade_id:
		"hellfire_minigun":
			return (acquired_upgrades.has("twin_barrel") or acquired_upgrades.has("faster_cannon")) and acquired_upgrades.has("overclocked_feed")
		"siege_cannon":
			return acquired_upgrades.has("armor_piercing") and acquired_upgrades.has("reinforced_airframe")
		"ap_ricochet_cannon":
			return acquired_upgrades.has("armor_piercing") and acquired_upgrades.has("ricochet_rounds")
		"swarm_rockets":
			return acquired_upgrades.has("rapid_lock") and (acquired_upgrades.has("multi_launch") or acquired_upgrades.has("missile_capacity"))
		"multi_lock_hellfire":
			return acquired_upgrades.has("rapid_lock") and acquired_upgrades.has("armor_piercing")
		"aegis_airframe":
			return (acquired_upgrades.has("reinforced_airframe") or acquired_upgrades.has("movement_boost")) and acquired_upgrades.has("repair_drone")
		_:
			for p in up.get("prerequisites", []):
				if not acquired_upgrades.has(p):
					return false
			return true

## Normalized 70% Common / 25% Rare / 5% Legendary selection tier calculator.
## Exposed for deterministic automated testing.
func roll_rarity_tier(roll: float, has_c: bool, has_r: bool, has_l: bool) -> String:
	var wc: float = 0.70 if has_c else 0.0
	var wr: float = 0.25 if has_r else 0.0
	var wl: float = 0.05 if has_l else 0.0
	var total: float = wc + wr + wl
	if total <= 0.0:
		return ""
	var pc: float = wc / total
	var pr: float = wr / total
	var r: float = clampf(roll, 0.0, 0.999999)
	if r < pc:
		return "Common"
	elif r < (pc + pr):
		return "Rare"
	else:
		return "Legendary"

func get_random_choices(count: int) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []

	# 1. Deterministic Evolution Priority Rule:
	# Evolutions are kept outside ordinary rarity rolling.
	var eligible_evolutions: Array[Dictionary] = []
	for key in upgrade_database:
		var uid := str(key)
		var up: Dictionary = upgrade_database[key]
		if up.get("is_evolution", false) and _is_eligible(uid):
			eligible_evolutions.append(up.duplicate(true))

	eligible_evolutions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = int(a.get("priority", 999))
		var pb: int = int(b.get("priority", 999))
		if pa != pb:
			return pa < pb
		return str(a.get("id", "")) < str(b.get("id", ""))
	)

	# Present the highest-priority eligible evolution in slot 0
	if not eligible_evolutions.is_empty():
		selected.append(enrich_card_data(eligible_evolutions[0]))

	# 2. First Level-Up Guarantee:
	# On the first level-up of every run (Level 2), one card MUST be Mini Helicopter Support.
	var is_first_level_up: bool = (current_level >= 2 or not pending_levels.is_empty())
	if guarantee_mini_heli_on_first_offer and not has_guaranteed_mini_heli_offered and is_first_level_up:
		has_guaranteed_mini_heli_offered = true
		if _is_eligible("mini_helicopter_support") and upgrade_database.has("mini_helicopter_support"):
			var already := false
			for s in selected:
				if s.get("id") == "mini_helicopter_support":
					already = true
					break
			if not already:
				selected.append(enrich_card_data(upgrade_database["mini_helicopter_support"].duplicate(true)))

	# 3. Normalized 70% Common / 25% Rare / 5% Legendary Selection for remaining slots:
	while selected.size() < count:
		var avail_c: Array[Dictionary] = []
		var avail_r: Array[Dictionary] = []
		var avail_l: Array[Dictionary] = []

		for key in upgrade_database:
			var uid := str(key)
			var up: Dictionary = upgrade_database[key]
			if up.get("is_evolution", false):
				continue
			if not _is_eligible(uid):
				continue
			var already_picked := false
			for s in selected:
				if s.get("id") == uid:
					already_picked = true
					break
			if already_picked:
				continue

			var rar: String = str(up.get("rarity", "Common"))
			match rar:
				"Legendary":
					if not has_acquired_legendary:
						avail_l.append(up)
				"Rare":
					avail_r.append(up)
				_:
					avail_c.append(up)

		# If standard pools are completely exhausted, fill with any remaining eligible evolutions
		if avail_c.is_empty() and avail_r.is_empty() and avail_l.is_empty():
			var extra_evo_added := false
			for evo in eligible_evolutions:
				var already_evo := false
				for s in selected:
					if s.get("id") == evo.get("id"):
						already_evo = true
						break
				if not already_evo:
					selected.append(enrich_card_data(evo))
					extra_evo_added = true
					break
			if not extra_evo_added:
				break # Completely exhausted
			continue

		var chosen_tier := roll_rarity_tier(randf(), not avail_c.is_empty(), not avail_r.is_empty(), not avail_l.is_empty())
		var pool: Array[Dictionary] = []
		match chosen_tier:
			"Common":
				pool = avail_c
			"Rare":
				pool = avail_r
			"Legendary":
				pool = avail_l

		if pool.is_empty():
			break

		var idx := randi() % pool.size()
		selected.append(enrich_card_data(pool[idx].duplicate(true)))

	return selected

func enrich_card_data(card: Dictionary) -> Dictionary:
	var enriched := card.duplicate(true)
	var uid := str(card.get("id", ""))
	if uid == "mini_helicopter_support":
		var living := get_living_wingmen_count()
		if living == 1:
			enriched["name"] = "Support Wingmen"
			enriched["benefit"] = "Restore your missing support aircraft."
			enriched["tradeoff"] = "Brings companion escort wing back to full operational strength"
			enriched["next_value"] = "2 Escort Drones (1 Restored)"
		else:
			enriched["name"] = "Support Wingmen"
			enriched["benefit"] = "Deploy two allied aircraft that attack enemies and intercept incoming fire. Each aircraft can be destroyed."
			enriched["tradeoff"] = "Independent health; lost aircraft can be restored in later upgrades"
			enriched["next_value"] = "2 Escort Drones"
	enriched["current_value"] = get_upgrade_current_value(uid)
	if not enriched.has("next_value") or uid != "mini_helicopter_support":
		enriched["next_value"] = get_upgrade_next_value(uid)
	enriched["evolution_synergy"] = get_upgrade_evolution_synergy(uid)
	enriched["prerequisites_text"] = get_upgrade_prerequisites_text(uid)
	return enriched

func get_upgrade_current_value(upgrade_id: String) -> String:
	var player := _get_active_player()
	match upgrade_id:
		"twin_barrel", "faster_cannon":
			if is_instance_valid(player) and is_instance_valid(player.chaingun):
				return "%.1f RPS" % player.chaingun.fire_rate
			return "11.5 RPS"
		"multi_shot":
			if is_instance_valid(player) and is_instance_valid(player.chaingun):
				return "%d Round / Shot" % player.chaingun.multishot_count
			return "1 Round / Shot"
		"armor_piercing":
			if is_instance_valid(player) and is_instance_valid(player.chaingun):
				return "%.1fx Armor Dmg" % player.chaingun.armored_damage_multiplier
			return "1.0x Armor Dmg"
		"overclocked_feed":
			return "Standard Feed"
		"ricochet_rounds":
			if is_instance_valid(player) and is_instance_valid(player.chaingun):
				return "%d Ricochets" % player.chaingun.ricochet_count
			return "0 Ricochets"
		"larger_explosions":
			if is_instance_valid(player) and is_instance_valid(player.missile_pod):
				return "%.1fm Blast Radius" % (3.2 * player.missile_pod.splash_radius_multiplier)
			return "3.2m Blast Radius"
		"missile_capacity":
			if is_instance_valid(player) and is_instance_valid(player.missile_pod):
				return "%d Max Missiles" % player.missile_pod.max_missiles
			return "6 Max Missiles"
		"rapid_lock":
			if is_instance_valid(player) and is_instance_valid(player.missile_pod):
				return "%.2fs Lock Time" % player.missile_pod.lock_duration
			return "0.95s Lock Time"
		"multi_launch":
			if is_instance_valid(player) and is_instance_valid(player.missile_pod):
				return "%d Missile / Salvo" % player.missile_pod.multi_launch_count
			return "1 Missile / Salvo"
		"reinforced_airframe":
			if is_instance_valid(player):
				return "%.0f Hull Integrity" % player.max_health
			return "100 Hull Integrity"
		"afterburner":
			if is_instance_valid(player):
				return "%.1f m/s Strafe" % player.strafe_speed
			return "28.0 m/s Strafe"
		"xp_magnet_range":
			if is_instance_valid(player):
				return "%.1fm Radius" % player.magnet_radius
			return "18.0m Radius"
		"movement_boost":
			if is_instance_valid(player):
				return "%.1f m/s Speed" % player.max_forward_speed
			return "38.0 m/s Speed"
		"repair_drone":
			if is_instance_valid(player) and player.repair_drone_enabled:
				return "%.1f HP/s" % player.repair_rate
			return "Inactive"
		"mini_helicopter_support":
			var count := get_living_wingmen_count()
			return "%d Escort Drones" % count
		"overdrive_core":
			return "Standard Systems"
		"ghost_rotor":
			if is_instance_valid(player) and player.has_ghost_rotor:
				return "Active"
			return "Standard ECM"
		"one_more_pass":
			if is_instance_valid(player) and player.has_one_more_pass:
				return "1 Revive Ready" if not player.one_more_pass_used else "Used"
			return "0 Revives"
		"hellfire_minigun":
			return "Overheating Autocannon"
		"siege_cannon":
			return "Single-Target Shells"
		"ap_ricochet_cannon":
			return "Standard Cannon"
		"swarm_rockets":
			return "Standard Salvo"
		"multi_lock_hellfire":
			return "1 Target Lock"
		"aegis_airframe":
			return "Standard Airframe"
		_:
			return str(upgrade_database.get(upgrade_id, {}).get("current_value", "Current"))

func get_upgrade_next_value(upgrade_id: String) -> String:
	match upgrade_id:
		"twin_barrel":
			return "16.1 RPS (-15% Dmg)"
		"faster_cannon":
			return "15.5 RPS (-10% Dmg)"
		"multi_shot":
			return "2-Round Spread (+15% Heat)"
		"armor_piercing":
			return "1.5x Armor / 0.8x Air"
		"overclocked_feed":
			return "+20% Rate & Dmg (+25% Heat)"
		"ricochet_rounds":
			return "1 Ricochet on Impact"
		"larger_explosions":
			return "4.8m Radius (+15% Splash)"
		"missile_capacity":
			return "8 Max Missiles"
		"rapid_lock":
			return "0.48s Lock (Narrower Cone)"
		"multi_launch":
			return "3 Missiles / Salvo (+20% Cooldown)"
		"reinforced_airframe":
			return "+35 Hull, Heal 35, +10% Armor (-10% Speed)"
		"afterburner":
			return "35.0 m/s Strafe (+20% Decel Time)"
		"xp_magnet_range":
			return "28.8m Radius"
		"movement_boost":
			return "47.5 m/s (+10% Stopping Dist)"
		"repair_drone":
			return "4 HP/s (5s Out of Combat)"
		"mini_helicopter_support":
			return "2 Escort Drones"
		"overdrive_core":
			return "+15% Damage & -10% Cooldowns"
		"ghost_rotor":
			return "Absorbs 1 Hit Every 12s"
		"one_more_pass":
			return "1 Emergency Revive (30% Hull)"
		"hellfire_minigun":
			return "+100% Rate & Zero Overheat Lockout"
		"siege_cannon":
			return "+80% Ground Dmg & 2 Target Piercing"
		"ap_ricochet_cannon":
			return "+80% Armor Shred, +2 Pierce, Ricochets"
		"swarm_rockets":
			return "6 Micro-Guided Homing Rockets"
		"multi_lock_hellfire":
			return "3-Target Multi-Lock Volley"
		"aegis_airframe":
			return "+50 Hull & Emergency Stasis Shield"
		_:
			return str(upgrade_database.get(upgrade_id, {}).get("next_value", "Upgraded"))

func get_upgrade_evolution_synergy(upgrade_id: String) -> String:
	match upgrade_id:
		"twin_barrel", "faster_cannon", "overclocked_feed":
			return "Synergy: Builds toward Hellfire Minigun"
		"armor_piercing":
			return "Synergy: Builds toward Siege Cannon & AP Ricochet"
		"reinforced_airframe":
			return "Synergy: Builds toward Siege Cannon & Aegis"
		"ricochet_rounds":
			return "Synergy: Builds toward AP Ricochet Cannon"
		"rapid_lock":
			return "Synergy: Builds toward Swarm Rockets & Multi-Lock"
		"multi_launch", "missile_capacity":
			return "Synergy: Builds toward Swarm Rockets"
		"movement_boost", "repair_drone":
			return "Synergy: Builds toward Aegis Airframe"
		"hellfire_minigun":
			return "EVOLUTION: Twin Barrel + Overclocked Feed"
		"siege_cannon":
			return "EVOLUTION: Armor-Piercing + Reinforced Airframe"
		"ap_ricochet_cannon":
			return "EVOLUTION: Armor-Piercing + Ricochet Rounds"
		"swarm_rockets":
			return "EVOLUTION: Rapid Lock + Multi-Launch"
		"multi_lock_hellfire":
			return "EVOLUTION: Rapid Lock + Armor-Piercing"
		"aegis_airframe":
			return "EVOLUTION: Reinforced Airframe + Repair Drone"
		_:
			return ""

func get_upgrade_prerequisites_text(upgrade_id: String) -> String:
	match upgrade_id:
		"hellfire_minigun":
			return "Requires: [Twin Barrel or Feeder] + [Overclocked Feed]"
		"siege_cannon":
			return "Requires: [Armor-Piercing] + [Reinforced Airframe]"
		"ap_ricochet_cannon":
			return "Requires: [Armor-Piercing] + [Ricochet Rounds]"
		"swarm_rockets":
			return "Requires: [Rapid Lock] + [Multi-Launch or Rack]"
		"multi_lock_hellfire":
			return "Requires: [Rapid Lock] + [Armor-Piercing]"
		"aegis_airframe":
			return "Requires: [Airframe or Turbine] + [Repair Drone]"
		_:
			return ""

func select_choice(upgrade_id: String) -> bool:
	if not is_choice_active or pending_levels.is_empty():
		return false
	if upgrade_id.is_empty():
		if not _offered_ids.is_empty() and not _offered_ids.has(""):
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
	if upgrade_id == "support_wingmen":
		upgrade_id = "mini_helicopter_support"
	if not _is_eligible(upgrade_id):
		return false
	var player := _get_active_player()
	if not is_instance_valid(player) or not player.is_alive:
		return false
	var gun := player.chaingun as Chaingun
	var pod := player.missile_pod as MissilePod

	var up_data: Dictionary = upgrade_database.get(upgrade_id, {})
	var rar: String = str(up_data.get("rarity", "Common"))
	if rar == "Legendary":
		if has_acquired_legendary:
			return false
		has_acquired_legendary = true
		acquired_legendary_id = upgrade_id
		acquired_legendary_count = 1

	match upgrade_id:
		"mini_helicopter_support":
			has_deployed_wingmen = true
			var mini_scene: PackedScene = load("res://scenes/companions/mini_helicopter.tscn")
			if not mini_scene:
				return false
			var spawn_parent: Node = player.get_parent() if player.get_parent() else get_tree().current_scene
			if not spawn_parent:
				spawn_parent = get_tree().root

			var slot_configs: Dictionary = {
				"left": Vector3(-4.8, 0.5, 2.6),
				"right": Vector3(4.8, 0.5, 2.6)
			}
			var occupied := get_occupied_wingman_slots()

			for slot_key in ["left", "right"]:
				if occupied.has(slot_key):
					# Survivor remains intact: preserve current HP and node!
					continue
				var offset: Vector3 = slot_configs[slot_key]
				var drone: MiniHelicopter = mini_scene.instantiate() as MiniHelicopter
				if drone:
					drone.slot_id = slot_key
					drone.player_target = player
					drone.set_formation_slot(offset, slot_key)
					drone.apply_companion_modifiers(mini_heli_damage_mult, mini_heli_fire_rate_mult, mini_heli_range_mult, mini_heli_has_rockets)
					spawn_parent.add_child(drone)
					var yaw_basis: Basis = MiniHelicopter.get_player_yaw_basis(player)
					var start_pos: Vector3 = player.global_position + (yaw_basis * Vector3(offset.x, 0.0, offset.z)) + Vector3(0.0, offset.y, 0.0)
					drone.global_position = start_pos

			for living in get_living_wingmen():
				living.apply_companion_modifiers(mini_heli_damage_mult, mini_heli_fire_rate_mult, mini_heli_range_mult, mini_heli_has_rockets)
		"multi_shot":
			if not gun:
				return false
			gun.multishot_count = 2
			gun.heat_per_shot *= 1.15
		"faster_cannon":
			if not gun:
				return false
			gun.fire_rate *= 1.35
			gun.damage_per_shot *= 0.9
		"larger_explosions":
			if not pod:
				return false
			pod.splash_radius_multiplier *= 1.5
			pod.splash_damage_multiplier *= 1.15
		"missile_capacity":
			if not pod:
				return false
			pod.max_missiles += 2
			pod.current_missiles = mini(pod.max_missiles, pod.current_missiles + 2)
			pod.ammo_changed.emit(pod.current_missiles, pod.max_missiles)
			if EventBus and EventBus.has_signal("missile_ammo_changed"):
				EventBus.missile_ammo_changed.emit(pod.current_missiles, pod.max_missiles)
		"xp_magnet_range":
			player.magnet_radius *= 1.6
			if player.xp_magnet_area:
				var col := player.xp_magnet_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
				if col and col.shape is CylinderShape3D:
					(col.shape as CylinderShape3D).radius = player.magnet_radius
		"movement_boost":
			player.max_forward_speed *= 1.25
			player.strafe_speed *= 1.25
			player.release_velocity_response /= 1.1
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
			player.current_health = minf(player.max_health, player.current_health + 35.0)
			player.armor_reduction = minf(player.armor_reduction + 0.10, 0.60)
			player.max_forward_speed *= 0.9
			player.health_changed.emit(player.current_health, player.max_health)
			if EventBus:
				EventBus.player_health_changed.emit(player.current_health, player.max_health)
		"afterburner":
			player.strafe_speed *= 1.25
			player.release_velocity_response /= 1.2
		"repair_drone":
			if player.has_method("enable_repair_drone"):
				player.enable_repair_drone(4.0)
			else:
				player.repair_drone_enabled = true
		# Legendary Upgrades
		"overdrive_core":
			if gun:
				gun.damage_per_shot *= 1.15
			if pod:
				pod.fire_cooldown *= 0.9
				pod.splash_damage_multiplier *= 1.15
		"ghost_rotor":
			if player.has_method("enable_ghost_rotor"):
				player.enable_ghost_rotor(12.0)
			else:
				player.has_ghost_rotor = true
		"one_more_pass":
			if player.has_method("enable_one_more_pass"):
				player.enable_one_more_pass()
			else:
				player.has_one_more_pass = true
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

	if not acquired_upgrades.has(upgrade_id):
		acquired_upgrades.append(upgrade_id)
	if EventBus:
		EventBus.upgrade_applied.emit(upgrade_id)
	return true
