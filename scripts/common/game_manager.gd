class_name GameManager
extends Node

## Run director, salvage banking, endless overdrive, and combat telemetry coordinator.

var run_salvage: int = 0
var is_endless_mode: bool = false
var salvage_multiplier: float = 1.0

# Telemetry & Score metrics
var enemies_killed: int = 0
var total_score: int = 0
var combo_streak: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 3.5
const COMBO_GRACE_WINDOW: float = 1.2
var combo_multiplier: float = 1.0
var max_multiplier_achieved: float = 1.0
var damage_dealt: float = 0.0
var shots_fired: int = 0
var missiles_fired: int = 0
var bosses_killed: int = 0
var run_timer: float = 0.0
var is_run_active: bool = true

# --- Attack Run Gunship Payoff Configuration ---
@export var attack_run_combo_milestone: int = 10     # Consecutive kills required to activate
@export var attack_run_duration: float = 6.0         # Duration of the boosted state in seconds
@export var attack_run_cooldown: float = 20.0        # Hard cooldown between attack runs in seconds
@export var attack_run_min_speed: float = 4.0        # Minimum flight speed (m/s) required (prevents stationary hover camping)
@export var attack_run_heat_multiplier: float = 0.5  # 50% reduced chaingun heat generation per shot
@export var attack_run_cooling_multiplier: float = 1.5 # 50% faster chaingun heat cooling
@export var attack_run_lock_multiplier: float = 0.65 # 35% faster guided missile lock-on acquisition

var is_attack_run_active: bool = false
var attack_run_timer: float = 0.0
var attack_run_cooldown_remaining: float = 0.0
var attack_runs_triggered: int = 0

var damage_by_source: Dictionary = {
	"chaingun": 0.0,
	"missiles": 0.0,
	"wingmen": 0.0,
	"other": 0.0
}
var kills_by_source: Dictionary = {
	"chaingun": 0,
	"missiles": 0,
	"wingmen": 0,
	"other": 0
}

func record_attributed_damage(amount: float, source_id: String) -> void:
	damage_dealt += amount
	var key := source_id.to_lower()
	if not damage_by_source.has(key):
		key = "other"
	damage_by_source[key] = float(damage_by_source.get(key, 0.0)) + amount

func record_attributed_kill(source_id: String) -> void:
	var key := source_id.to_lower()
	if not kills_by_source.has(key):
		key = "other"
	kills_by_source[key] = int(kills_by_source.get(key, 0)) + 1

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
		if eb.has_signal("player_damaged_directional"):
			eb.player_damaged_directional.connect(_on_player_damaged)
		if eb.has_signal("salvage_updated"):
			eb.emit_signal("salvage_updated", run_salvage)
		if eb.has_signal("kills_updated"):
			eb.emit_signal("kills_updated", enemies_killed)
		if eb.has_signal("score_updated"):
			eb.emit_signal("score_updated", total_score, 0, combo_multiplier, combo_streak)

func _process(delta: float) -> void:
	if is_run_active and not get_tree().paused:
		run_timer += delta
		if combo_timer > 0.0:
			combo_timer -= delta
			var eb: Node = get_node_or_null("/root/EventBus")
			if eb and eb.has_signal("combo_timer_updated"):
				eb.emit_signal("combo_timer_updated", maxf(0.0, combo_timer), COMBO_WINDOW, combo_multiplier)
			if combo_timer <= 0.0:
				_decay_combo()

		# --- Attack Run Timer & Cooldown Updates ---
		if attack_run_cooldown_remaining > 0.0:
			attack_run_cooldown_remaining = maxf(0.0, attack_run_cooldown_remaining - delta)
			var eb: Node = get_node_or_null("/root/EventBus")
			if eb and eb.has_signal("attack_run_cooldown_updated"):
				eb.emit_signal("attack_run_cooldown_updated", attack_run_cooldown_remaining, attack_run_cooldown)

		if is_attack_run_active:
			attack_run_timer -= delta
			var eb: Node = get_node_or_null("/root/EventBus")
			if eb and eb.has_signal("attack_run_state_changed"):
				eb.emit_signal("attack_run_state_changed", true, maxf(0.0, attack_run_timer), attack_run_duration)
			if attack_run_timer <= 0.0:
				end_attack_run(true)
		elif attack_run_cooldown_remaining <= 0.0 and combo_streak >= attack_run_combo_milestone:
			_check_attack_run_trigger()

func get_multiplier_for_streak(streak: int) -> float:
	if streak >= 40:
		return 5.0
	elif streak >= 25:
		return 4.0
	elif streak >= 15:
		return 3.0
	elif streak >= 10:
		return 2.5
	elif streak >= 6:
		return 2.0
	elif streak >= 3:
		return 1.5
	return 1.0

func _decay_combo() -> void:
	if combo_streak > 0:
		if combo_streak >= 40:
			combo_streak = 25
		elif combo_streak >= 25:
			combo_streak = 15
		elif combo_streak >= 15:
			combo_streak = 10
		elif combo_streak >= 10:
			combo_streak = 6
		elif combo_streak >= 6:
			combo_streak = 3
		elif combo_streak >= 3:
			combo_streak = 2
		else:
			combo_streak = 0
		
		combo_multiplier = get_multiplier_for_streak(combo_streak)
		if combo_streak > 0:
			combo_timer = COMBO_GRACE_WINDOW
		else:
			combo_timer = 0.0
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("score_updated"):
			eb.emit_signal("score_updated", total_score, 0, combo_multiplier, combo_streak)

func _on_player_damaged(_amount: float, _hit_pos: Vector3, _source_pos: Vector3, is_shield_hit: bool, _metadata: Dictionary = {}) -> void:
	if not is_shield_hit:
		if is_attack_run_active:
			# Taking unshielded damage cuts attack run short, penalizing careless flight
			attack_run_timer = maxf(0.0, attack_run_timer - 1.5)
			if attack_run_timer <= 0.0:
				end_attack_run(true)
		if combo_streak > 0:
			if combo_streak >= 40:
				combo_streak = 25
			elif combo_streak >= 25:
				combo_streak = 15
			elif combo_streak >= 15:
				combo_streak = 10
			elif combo_streak >= 10:
				combo_streak = 6
			elif combo_streak >= 6:
				combo_streak = 3
			else:
				combo_streak = 0
			combo_multiplier = get_multiplier_for_streak(combo_streak)
			var eb: Node = get_node_or_null("/root/EventBus")
			if eb and eb.has_signal("score_updated"):
				eb.emit_signal("score_updated", total_score, 0, combo_multiplier, combo_streak)

func record_shot() -> void:
	shots_fired += 1

func record_damage(amount: float) -> void:
	damage_dealt += amount

func _on_enemy_destroyed(_enemy: Node, _score: int) -> void:
	if _enemy != null:
		if _enemy.is_in_group("fuel_tanks") or _enemy.is_in_group("explosives"):
			var base_salvage: int = _score if _score > 0 else 50
			var pts: int = int(base_salvage * combo_multiplier)
			total_score += pts
			var eb_prop: Node = get_node_or_null("/root/EventBus")
			if eb_prop and eb_prop.has_signal("score_updated"):
				eb_prop.emit_signal("score_updated", total_score, pts, combo_multiplier, combo_streak)
			return

	enemies_killed += 1
	combo_streak += 1
	combo_multiplier = get_multiplier_for_streak(combo_streak)
	if combo_multiplier > max_multiplier_achieved:
		max_multiplier_achieved = combo_multiplier
	combo_timer = COMBO_WINDOW

	var base_pts: int = _score if _score > 0 else 50
	var earned: int = int(base_pts * combo_multiplier)
	total_score += earned

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("kills_updated"):
			eb.emit_signal("kills_updated", enemies_killed)
		if eb.has_signal("score_updated"):
			eb.emit_signal("score_updated", total_score, earned, combo_multiplier, combo_streak)
		if eb.has_signal("combo_timer_updated"):
			eb.emit_signal("combo_timer_updated", combo_timer, COMBO_WINDOW, combo_multiplier)

	_check_attack_run_trigger()

func _check_attack_run_trigger() -> void:
	if not is_run_active or is_attack_run_active or attack_run_cooldown_remaining > 0.0:
		return
	if combo_streak < attack_run_combo_milestone:
		return

	# Verify movement requirement: player must be actively moving and not in hover hazard
	var player: Node = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			player = p
			break

	if is_instance_valid(player):
		if player.has_method("is_hover_hazard_active") and player.call("is_hover_hazard_active"):
			return
		if player.has_method("get_horizontal_speed"):
			var spd: float = float(player.call("get_horizontal_speed"))
			if spd < attack_run_min_speed:
				return
		elif "velocity" in player:
			var vel: Vector3 = player.velocity
			if Vector2(vel.x, vel.z).length() < attack_run_min_speed:
				return

	start_attack_run()

func start_attack_run() -> void:
	if is_attack_run_active:
		return
	is_attack_run_active = true
	attack_run_timer = attack_run_duration
	attack_runs_triggered += 1
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("attack_run_state_changed"):
		eb.emit_signal("attack_run_state_changed", true, attack_run_timer, attack_run_duration)

func end_attack_run(start_cooldown: bool = true) -> void:
	if not is_attack_run_active and attack_run_timer <= 0.0:
		if not start_cooldown:
			attack_run_cooldown_remaining = 0.0
		return
	is_attack_run_active = false
	attack_run_timer = 0.0
	if start_cooldown:
		attack_run_cooldown_remaining = attack_run_cooldown
		var eb_cd: Node = get_node_or_null("/root/EventBus")
		if eb_cd and eb_cd.has_signal("attack_run_cooldown_updated"):
			eb_cd.emit_signal("attack_run_cooldown_updated", attack_run_cooldown_remaining, attack_run_cooldown)
	else:
		attack_run_cooldown_remaining = 0.0

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("attack_run_state_changed"):
		eb.emit_signal("attack_run_state_changed", false, 0.0, attack_run_duration)

func reset_attack_run() -> void:
	end_attack_run(false)

func _on_missile_fired() -> void:
	missiles_fired += 1

func add_salvage(amount: int) -> int:
	var data := SaveSystem.load_data()
	var upgrades: Dictionary = data.get("upgrades", {})
	var scavenger_lvl := int(upgrades.get("scavenger_rig", 0))
	var bonus_mult := 1.0 + (scavenger_lvl * 0.25)

	var gained := int(amount * bonus_mult * salvage_multiplier)
	run_salvage += gained
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("salvage_updated"):
		eb.emit_signal("salvage_updated", run_salvage)
	return gained

func get_run_telemetry(status: String = "IN_PROGRESS") -> Dictionary:
	return {
		"status": status,
		"duration_sec": run_timer,
		"salvage_banked": run_salvage,
		"enemies_killed": enemies_killed,
		"total_score": total_score,
		"max_multiplier": max_multiplier_achieved,
		"highest_combo": combo_streak,
		"damage_dealt": damage_dealt,
		"shots_fired": shots_fired,
		"missiles_fired": missiles_fired,
		"boss_defeated": bosses_killed > 0,
		"is_endless": is_endless_mode,
		"attack_runs_triggered": attack_runs_triggered,
		"damage_by_source": damage_by_source.duplicate(),
		"kills_by_source": kills_by_source.duplicate()
	}

func finalize_telemetry(status: String) -> void:
	is_run_active = false
	end_attack_run(false)
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
	if is_instance_valid(rsc) and not rsc.is_queued_for_deletion() and rsc.has_method("on_endless_mode_entered"):
		rsc.call("on_endless_mode_entered")

	var wm := get_tree().get_first_node_in_group("wave_manager")
	if is_instance_valid(wm) and not wm.is_queued_for_deletion() and wm.has_method("enter_endless_mode"):
		wm.call("enter_endless_mode")

	var sd := get_tree().get_first_node_in_group("spawn_director")
	if is_instance_valid(sd) and not sd.is_queued_for_deletion() and sd.has_method("start_wave"):
		sd.call("start_wave", 11)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("endless_mode_entered"):
		eb.emit_signal("endless_mode_entered")

func _on_extraction_decision_requested(salvage_amount: int) -> void:
	var victory_screen := get_tree().get_first_node_in_group("victory_screen")
	if victory_screen and victory_screen.has_method("display_victory"):
		victory_screen.display_victory(salvage_amount)

func _on_player_died() -> void:
	end_attack_run(false)
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
	end_attack_run(false)
