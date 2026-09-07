class_name Hangar
extends Control

@onready var salvage_label: Label = %SalvageLabel
@onready var scavenger_btn: Button = %ScavengerButton
@onready var armor_btn: Button = %ArmorButton
@onready var magnet_btn: Button = %MagnetButton
@onready var insurance_btn: Button = %InsuranceButton
@onready var deploy_btn: Button = %DeployButton
@onready var menu_btn: Button = %MenuButton

var _save_data: Dictionary = {}

func _ready() -> void:
	_save_data = SaveSystem.load_data()
	_update_ui()

	scavenger_btn.pressed.connect(_buy_scavenger)
	armor_btn.pressed.connect(_buy_armor)
	magnet_btn.pressed.connect(_buy_magnet)
	insurance_btn.pressed.connect(_buy_insurance)

	deploy_btn.pressed.connect(_on_deploy_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _update_ui() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})

	salvage_label.text = "BANKED SALVAGE: %d" % salvage

	# Scavenger Rig
	var scav_lvl: int = int(upgrades.get("scavenger_rig", 0))
	if scav_lvl >= 4:
		scavenger_btn.text = "SCAVENGER RIG: MAX (Rank 4)"
		scavenger_btn.disabled = true
	else:
		var cost := (scav_lvl + 1) * 150
		scavenger_btn.text = "SCAVENGER RIG Rank %d (+25%% Salvage) - Cost: %d" % [scav_lvl + 1, cost]
		scavenger_btn.disabled = salvage < cost

	# Rotor Armor
	var armor_lvl: int = int(upgrades.get("rotor_armor", 0))
	if armor_lvl >= 4:
		armor_btn.text = "ROTOR ARMOR: MAX (Rank 4)"
		armor_btn.disabled = true
	else:
		var cost := (armor_lvl + 1) * 200
		armor_btn.text = "ROTOR ARMOR Rank %d (+20 Max HP) - Cost: %d" % [armor_lvl + 1, cost]
		armor_btn.disabled = salvage < cost

	# Magnet Radius
	var mag_lvl: int = int(upgrades.get("magnet_radius", 0))
	if mag_lvl >= 3:
		magnet_btn.text = "MAGNET SUITE: MAX (Rank 3)"
		magnet_btn.disabled = true
	else:
		var cost := (mag_lvl + 1) * 100
		magnet_btn.text = "MAGNET SUITE Rank %d (+6m Range) - Cost: %d" % [mag_lvl + 1, cost]
		magnet_btn.disabled = salvage < cost

	# Extraction Insurance
	var has_ins: bool = upgrades.get("extraction_insurance", false)
	if has_ins:
		insurance_btn.text = "EXTRACTION INSURANCE: OWNED (50% Protected)"
		insurance_btn.disabled = true
	else:
		insurance_btn.text = "EXTRACTION INSURANCE (Keep 50% on Death) - Cost: 350"
		insurance_btn.disabled = salvage < 350

func _buy_scavenger() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})
	var lvl: int = int(upgrades.get("scavenger_rig", 0))
	var cost := (lvl + 1) * 150
	if salvage >= cost:
		_save_data["salvage"] = salvage - cost
		upgrades["scavenger_rig"] = lvl + 1
		_save_data["upgrades"] = upgrades
		SaveSystem.save_data(_save_data)
		_update_ui()

func _buy_armor() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})
	var lvl: int = int(upgrades.get("rotor_armor", 0))
	var cost := (lvl + 1) * 200
	if salvage >= cost:
		_save_data["salvage"] = salvage - cost
		upgrades["rotor_armor"] = lvl + 1
		_save_data["upgrades"] = upgrades
		SaveSystem.save_data(_save_data)
		_update_ui()

func _buy_magnet() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})
	var lvl: int = int(upgrades.get("magnet_radius", 0))
	var cost := (lvl + 1) * 100
	if salvage >= cost:
		_save_data["salvage"] = salvage - cost
		upgrades["magnet_radius"] = lvl + 1
		_save_data["upgrades"] = upgrades
		SaveSystem.save_data(_save_data)
		_update_ui()

func _buy_insurance() -> void:
	var salvage: int = int(_save_data.get("salvage", 0))
	var upgrades: Dictionary = _save_data.get("upgrades", {})
	if salvage >= 350:
		_save_data["salvage"] = salvage - 350
		upgrades["extraction_insurance"] = true
		_save_data["upgrades"] = upgrades
		SaveSystem.save_data(_save_data)
		_update_ui()

func _on_deploy_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battlefield/battlefield.tscn")

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
