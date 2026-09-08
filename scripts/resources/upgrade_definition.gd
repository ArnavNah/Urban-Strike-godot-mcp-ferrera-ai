class_name UpgradeDefinition
extends Resource

## Resource definition for Heli-Strike survivor-style upgrades and build evolutions.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: String = "UPGRADE" # "Primary", "Secondary", "Airframe", "Avionics", "Support", "EVOLUTION"
@export var benefit: String = ""
@export var tradeoff: String = ""
@export var icon: Texture2D = null
@export var icon_path: String = ""
@export var rarity: String = "Common" # "Common", "Rare", "Epic", "Evolution"
@export var max_level: int = 1
@export var is_evolution: bool = false
@export var prerequisites: Array[String] = []
@export var effect_values: Dictionary = {}

func to_dictionary() -> Dictionary:
	var desc := description if not description.is_empty() else benefit
	var ben := benefit if not benefit.is_empty() else description
	return {
		"id": id,
		"name": display_name if not display_name.is_empty() else id.capitalize(),
		"display_name": display_name if not display_name.is_empty() else id.capitalize(),
		"description": desc,
		"category": category,
		"benefit": ben,
		"tradeoff": tradeoff,
		"icon": icon,
		"icon_path": icon_path,
		"rarity": rarity,
		"max_level": max_level,
		"is_evolution": is_evolution,
		"prerequisites": prerequisites,
		"effect_values": effect_values,
	}
