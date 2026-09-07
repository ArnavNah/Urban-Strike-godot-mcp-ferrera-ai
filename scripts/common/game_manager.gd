class_name GameManager
extends Node

## Run director, salvage banking, endless overdrive, and combat telemetry coordinator.

var run_salvage: int = 0
var is_endless_mode: bool = false
var salvage_multiplier: float = 1.0

# Telemetry metrics
var enemies_killed: int = 0
var damage_dealt: float = 0.0
var shots_fired: int = 0
var missiles_fired: int = 0
var bosses_killed: int = 0
var run_timer: float = 0.0
var is_run_active: bool = true

func _ready() -> void:
	add_to_group("game_manager")
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("player_died"):
			eb.player_died.connect(_on_player_died)
		if eb.has_signal("boss_defeated"):
			eb.boss_defeated.connect(_on_boss_defeated)
		if eb.has_signal("extraction_decision_requested"):
			eb.extraction_decision_requested.connect(_on_extraction_decision_requested)
		if eb.has_signal("enemy_destroyed"):
			eb.enemy_destroyed.connect(_on_enemy_destroyed)
		if eb.has_signal("missile_fired"):
			eb.missile_fired.connect(_on_missile_fired)
		if eb.has_signal("salvage_updated"):
			eb.emit_signal("salvage_updated", run_salvage)

func _process(delta: float) -> void:
	if is_run_active and not get_tree().paused:
		run_timer += delta

func record_shot() -> void:
	shots_fired += 1

func record_damage(amount: float) -> void:
	damage_dealt += amount

func _on_enemy_destroyed(_enemy: Node, _score: int) -> void:
	enemies_killed += 1

func _on_missile_fired() -> void:
	missiles_fired += 1

func add_salvage(amount: int) -> void:
	var data := SaveSystem.load_data()
	var upgrades: Dictionary = data.get("upgrades", {})
	var scavenger_lvl := int(upgrades.get("scavenger_rig", 0))
	var bonus_mult := 1.0 + (scavenger_lvl * 0.25)

	var gained := int(amount * bonus_mult * salvage_multiplier)
	run_salvage += gained
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("salvage_updated"):
		eb.emit_signal("salvage_updated", run_salvage)

func get_run_telemetry(status: String = "IN_PROGRESS") -> Dictionary:
	return {
		"status": status,
		"duration_sec": run_timer,
		"salvage_banked": run_salvage,
		"enemies_killed": enemies_killed,
		"damage_dealt": damage_dealt,
		"shots_fired": shots_fired,
		"missiles_fired": missiles_fired,
		"boss_defeated": bosses_killed > 0,
		"is_endless": is_endless_mode
	}

func finalize_telemetry(status: String) -> void:
	is_run_active = false
	var stats := get_run_telemetry(status)
	SaveSystem.record_run_telemetry(stats)

func extract_salvage() -> void:
	finalize_telemetry("EXTRACTED")
	var data := SaveSystem.load_data()
	data["salvage"] = int(data.get("salvage", 0)) + run_salvage
	SaveSystem.save_data(data)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hangar/hangar.tscn")

func enter_endless_mode() -> void:
	is_endless_mode = true
	salvage_multiplier = 2.0
	get_tree().paused = false

	var rsc := get_tree().get_first_node_in_group("run_state_controller")
	if rsc and rsc.has_method("on_endless_mode_entered"):
		rsc.call("on_endless_mode_entered")

	var wm := get_tree().get_first_node_in_group("wave_manager")
	if wm and wm.has_method("enter_endless_mode"):
		wm.call("enter_endless_mode")

	var sd := get_tree().get_first_node_in_group("spawn_director")
	if sd and sd.has_method("start_wave"):
		sd.call("start_wave", 11)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("endless_mode_entered"):
		eb.emit_signal("endless_mode_entered")

func _on_extraction_decision_requested(salvage_amount: int) -> void:
	var victory_screen := get_tree().get_first_node_in_group("victory_screen")
	if victory_screen and victory_screen.has_method("display_victory"):
		victory_screen.display_victory(salvage_amount)

func _on_player_died() -> void:
	finalize_telemetry("KIA")
	var data := SaveSystem.load_data()
	var upgrades: Dictionary = data.get("upgrades", {})
	var has_insurance: bool = upgrades.get("extraction_insurance", false)

	if has_insurance:
		var protected_salvage: int = int(run_salvage * 0.5)
		data["salvage"] = int(data.get("salvage", 0)) + protected_salvage
		SaveSystem.save_data(data)

	# Show Death modal after brief delay
	await get_tree().create_timer(1.8).timeout
	var death_screen := get_tree().get_first_node_in_group("death_screen")
	if death_screen and death_screen.has_method("display_death"):
		death_screen.display_death(run_salvage, has_insurance)

func _on_boss_defeated() -> void:
	bosses_killed += 1
	add_salvage(300)
	await get_tree().create_timer(2.5).timeout
	var victory_screen := get_tree().get_first_node_in_group("victory_screen")
	if victory_screen and victory_screen.has_method("display_victory"):
		victory_screen.display_victory(run_salvage)
