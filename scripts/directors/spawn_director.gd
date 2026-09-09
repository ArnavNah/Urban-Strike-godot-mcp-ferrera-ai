class_name SpawnDirector
extends Node

## GDD Section 11 & 13: Ten-wave escalation and procedural Threat Director.
## Manages ground/air threat budgets, active population caps, air corridors,
## and tactical battlefield formations (air, ground, combined arms).

@export var arena_half_extents: float = 215.0
@export var recovery_pause_duration: float = 5.5
@export var autostart_wave: bool = false

@export_group("Air Enemy Active Caps")
@export var cap_scout: int = 4
@export var cap_raider: int = 2
@export var cap_transport: int = 2
@export var cap_gunship: int = 2
@export var cap_jammer: int = 1
@export var cap_ace: int = 1
@export var max_active_rooftop_threats: int = 3

@export_group("Ground Enemy Tactical Caps")
@export var cap_sam: int = 3
@export var cap_mortar: int = 2
@export var cap_support: int = 1

@export_group("Encounter System Configuration")
@export var encounter_config: EncounterConfig = null

enum EncounterState {
	WARMUP,
	STREAMING,
	SURGE,
	RECOVERY
}

var encounter_state: EncounterState = EncounterState.WARMUP
var recovery_timer_remaining: float = 0.0
var total_despawns: int = 0
var _offscreen_cleanup_timer: float = 0.0
var _enemy_offscreen_durations: Dictionary = {}
var _active_sectors: Array[int] = [0, 2] # 2 active non-adjacent sectors to preserve escape routes
var _sector_rotation_timer: float = 8.0
var has_mission_focus: bool = false
var mission_focus_position: Vector3 = Vector3.ZERO

@export_group("Continuous Survival Tuning")
@export var is_continuous_mode: bool = true
@export var base_ground_budget_rate: float = 18.0
@export var base_air_budget_rate: float = 10.0
@export var surge_interval: float = 90.0
@export var surge_duration: float = 15.0

@export_group("Spawn Zones")
@export var ground_zones_node: Node3D = null
@export var air_zones_node: Node3D = null
@export var rooftop_zones_node: Node3D = null
@export var pickup_locations_node: Node3D = null
@export var objective_locations_node: Node3D = null
@export var environment_bounds_node: Node3D = null

@export_group("Timers")
@export var stream_timer: Timer = null
@export var formation_timer: Timer = null
@export var surge_timer: Timer = null

var current_wave: int = 1
var is_wave_active: bool = false
var _wave_enemies: Array[Node3D] = []
var _total_wave_enemies: int = 0
var _recovery_timer: float = 0.0

var elapsed_survival_time: float = 0.0
var continuous_ground_budget: float = 0.0
var continuous_air_budget: float = 0.0
var total_enemies_spawned: int = 0
var total_enemies_killed: int = 0
var surge_timer_duration_active: float = 0.0
var surge_timer_value: float = 0.0
var next_surge_time: float = 90.0

var last_formation_name: String = "None"
var last_spawn_source: String = "Initial Deployment"
var failed_spawn_attempts: int = 0

var _continuous_formation_cooldown: float = 4.0
var _continuous_stream_cooldown: float = 1.0
var _scheduled_events_triggered: Dictionary = {}

var formation_history: Array[String] = []
var is_radar_active: bool = false
var _recent_spawn_sectors: Array[int] = []
var _recent_ground_sources: Array[String] = []
var _recent_air_sources: Array[String] = []
var _formation_spawn_queue: Array[Dictionary] = []
var _formation_stagger_timer: float = 0.0
var _occupied_rooftop_markers: Dictionary = {}
var _active_authored_pickups: Array[Node3D] = []
var _pickup_spawn_timer: float = 12.0
var _pickup_spawn_interval: float = 38.0
var _rooftop_check_timer: float = 8.0
var _scene_crate: PackedScene = preload("res://scenes/pickups/salvage_crate.tscn")
var _scene_missile_pickup: PackedScene = preload("res://scenes/pickups/missile_ammo_pickup.tscn")
var _active_missile_pickups: Array[Node3D] = []
var _missile_pickup_timer: float = 12.0
var _missile_pickup_interval_min: float = 20.0
var _missile_pickup_interval_max: float = 40.0
var max_active_missile_pickups: int = 2

# Known open road points guaranteed free of building collisions
var _safe_road_points: Array[Vector3] = [
	Vector3(0.0, 0.0, -70.0),
	Vector3(0.0, 0.0, 70.0),
	Vector3(70.0, 0.0, 0.0),
	Vector3(-70.0, 0.0, 0.0),
	Vector3(55.0, 0.0, -55.0),
	Vector3(-55.0, 0.0, 55.0),
	Vector3(0.0, 0.0, -85.0),
	Vector3(0.0, 0.0, 85.0)
]

# Preloaded enemy scenes
var _scene_infantry: PackedScene = preload("res://scenes/enemies/infantry_cluster.tscn")
var _scene_turret: PackedScene = preload("res://scenes/enemies/ground_turret.tscn")
var _scene_tank: PackedScene = preload("res://scenes/enemies/tank.tscn")
var _scene_sam: PackedScene = preload("res://scenes/enemies/sam_site.tscn")
var _scene_hunter: PackedScene = preload("res://scenes/enemies/hunter_helicopter.tscn")
var _scene_radar: PackedScene = preload("res://scenes/objects/radar_station.tscn")
var _scene_archon: PackedScene = preload("res://scenes/enemies/boss_archon.tscn")

# Modular Air Ecosystem scenes
var _scene_air_scout: PackedScene = preload("res://scenes/enemies/air_scout_helicopter.tscn")
var _scene_air_raider: PackedScene = preload("res://scenes/enemies/air_rocket_raider.tscn")
var _scene_air_transport: PackedScene = preload("res://scenes/enemies/air_transport_helicopter.tscn")
var _scene_air_gunship: PackedScene = preload("res://scenes/enemies/air_attack_gunship.tscn")
var _scene_air_jammer: PackedScene = preload("res://scenes/enemies/air_jammer_helicopter.tscn")
var _scene_air_ace: PackedScene = preload("res://scenes/enemies/air_ace_gunship.tscn")

# Modular Ground Vehicle scenes
var _scene_buggy: PackedScene = preload("res://scenes/enemies/ground_scout_buggy.tscn")
var _scene_technical: PackedScene = preload("res://scenes/enemies/ground_rocket_technical.tscn")
var _scene_ifv: PackedScene = preload("res://scenes/enemies/ground_assault_ifv.tscn")
var _scene_apc: PackedScene = preload("res://scenes/enemies/ground_troop_carrier_apc.tscn")
var _scene_mortar: PackedScene = preload("res://scenes/enemies/ground_mortar_carrier.tscn")
var _scene_ground_jammer: PackedScene = preload("res://scenes/enemies/ground_jammer_vehicle.tscn")

var procedural_formations: Array[FormationDefinition] = []
var formation_category_history: Array[int] = []

# GDD Section 11.2 & 12.2 wave table (Preserved for compatibility and tests)
var wave_table: Array[Dictionary] = [
	{
		"wave": 1,
		"announcement": "WAVE 1 // HOSTILE INFANTRY CONTACT",
		"ground_budget": 40,
		"air_budget": 0,
		"ground_slots": 2,
		"air_slots": 0,
		"enemies": ["infantry", "turret"]
	},
	{
		"wave": 2,
		"announcement": "WAVE 2 // ARMORED TANK DIVISION INBOUND",
		"ground_budget": 55,
		"air_budget": 0,
		"ground_slots": 2,
		"air_slots": 0,
		"enemies": ["infantry", "tank"]
	},
	{
		"wave": 3,
		"announcement": "WAVE 3 // SUSTAINED GROUND ASSAULT",
		"ground_budget": 70,
		"air_budget": 0,
		"ground_slots": 3,
		"air_slots": 0,
		"enemies": ["infantry", "tank", "turret"]
	},
	{
		"wave": 4,
		"announcement": "WAVE 4 // SAM AIR-DEFENSE DETECTED - USE FLARES",
		"ground_budget": 85,
		"air_budget": 0,
		"ground_slots": 3,
		"air_slots": 0,
		"enemies": ["sam", "tank", "infantry"]
	},
	{
		"wave": 5,
		"announcement": "WAVE 5 // MISSION OBJECTIVE: DESTROY RADAR STATION",
		"ground_budget": 100,
		"air_budget": 0,
		"ground_slots": 3,
		"air_slots": 0,
		"enemies": ["sam", "tank", "turret"]
	},
	{
		"wave": 6,
		"announcement": "WAVE 6 // AIR THREAT: RECON & HUNTER CONTACT",
		"ground_budget": 100,
		"air_budget": 30,
		"ground_slots": 3,
		"air_slots": 1,
		"enemies": ["hunter", "scout", "raider", "infantry", "turret"]
	},
	{
		"wave": 7,
		"announcement": "WAVE 7 // COMBINED AIR & ARMORED PRESSURE",
		"ground_budget": 115,
		"air_budget": 45,
		"ground_slots": 3,
		"air_slots": 1,
		"enemies": ["hunter", "scout", "raider", "transport", "tank", "infantry"]
	},
	{
		"wave": 8,
		"announcement": "WAVE 8 // AIR STRIKE & SAM CODES ACTIVE",
		"ground_budget": 130,
		"air_budget": 60,
		"ground_slots": 4,
		"air_slots": 2,
		"enemies": ["hunter", "scout", "raider", "gunship", "jammer", "sam", "tank"]
	},
	{
		"wave": 9,
		"announcement": "WAVE 9 // MAXIMUM ENEMY SATURATION",
		"ground_budget": 150,
		"air_budget": 75,
		"ground_slots": 4,
		"air_slots": 2,
		"enemies": ["hunter", "scout", "raider", "gunship", "jammer", "ace", "sam", "tank", "turret"]
	},
	{
		"wave": 10,
		"announcement": "WAVE 10 // WARNING: ARCHON HEAVY GUNSHIP DETECTED",
		"ground_budget": 50,
		"air_budget": 25,
		"ground_slots": 2,
		"air_slots": 1,
		"enemies": ["archon", "tank", "scout"]
	}
]

func _ready() -> void:
	add_to_group("spawn_director")
	_init_encounter_config()
	_setup_spawn_nodes_and_timers()
	if EventBus:
		EventBus.enemy_destroyed.connect(_on_enemy_destroyed)
		if EventBus.has_signal("radar_status_changed"):
			EventBus.radar_status_changed.connect(_on_radar_status_changed)
	if autostart_wave:
		get_tree().create_timer(1.0).timeout.connect(_on_intro_timeout)

func _init_encounter_config() -> void:
	if not encounter_config:
		if is_inside_tree() and get_tree().current_scene and get_tree().current_scene.name == "Battlefield":
			if ResourceLoader.exists("res://resources/directors/default_encounter_config.tres"):
				encounter_config = load("res://resources/directors/default_encounter_config.tres") as EncounterConfig
	if encounter_config:
		base_ground_budget_rate = encounter_config.base_ground_budget_rate
		base_air_budget_rate = encounter_config.base_air_budget_rate
		surge_interval = encounter_config.surge_interval_min
		surge_duration = encounter_config.surge_duration

func _setup_spawn_nodes_and_timers() -> void:
	if not ground_zones_node or (is_inside_tree() and ground_zones_node.get_child_count() == 0):
		var b_ground := get_node_or_null("../GroundSpawnSources") as Node3D
		if b_ground and b_ground.get_child_count() > 0:
			ground_zones_node = b_ground
		elif not ground_zones_node:
			ground_zones_node = get_node_or_null("GroundSpawnZones") as Node3D

	if not air_zones_node or (is_inside_tree() and air_zones_node.get_child_count() == 0):
		var b_air := get_node_or_null("../AirSpawnSources") as Node3D
		if b_air and b_air.get_child_count() > 0:
			air_zones_node = b_air
		elif not air_zones_node:
			air_zones_node = get_node_or_null("AirSpawnZones") as Node3D

	if not rooftop_zones_node or (is_inside_tree() and rooftop_zones_node.get_child_count() == 0):
		var b_roof := get_node_or_null("../RooftopSpawnSources") as Node3D
		if b_roof and b_roof.get_child_count() > 0:
			rooftop_zones_node = b_roof
		elif not rooftop_zones_node:
			rooftop_zones_node = get_node_or_null("RooftopSpawnZones") as Node3D

	if not pickup_locations_node:
		var b_pick := get_node_or_null("../PickupLocations") as Node3D
		if b_pick:
			pickup_locations_node = b_pick

	if not objective_locations_node:
		var b_obj := get_node_or_null("../ObjectiveLocations") as Node3D
		if b_obj:
			objective_locations_node = b_obj

	if not environment_bounds_node:
		var b_env := get_node_or_null("../EnvironmentBounds") as Node3D
		if b_env:
			environment_bounds_node = b_env

	var pa := get_node_or_null("../PlayableArea")
	if not pa and is_inside_tree():
		pa = get_tree().get_first_node_in_group("playable_area")
	if pa and "warning_half_extent" in pa:
		arena_half_extents = float(pa.warning_half_extent)

	if not stream_timer:
		stream_timer = get_node_or_null("StreamTimer") as Timer
		if not stream_timer and is_inside_tree():
			stream_timer = Timer.new()
			stream_timer.name = "StreamTimer"
			add_child(stream_timer)
	if stream_timer and not stream_timer.timeout.is_connected(_on_stream_timer_timeout):
		stream_timer.timeout.connect(_on_stream_timer_timeout)

	if not formation_timer:
		formation_timer = get_node_or_null("FormationTimer") as Timer
		if not formation_timer and is_inside_tree():
			formation_timer = Timer.new()
			formation_timer.name = "FormationTimer"
			add_child(formation_timer)
	if formation_timer and not formation_timer.timeout.is_connected(_on_formation_timer_timeout):
		formation_timer.timeout.connect(_on_formation_timer_timeout)

	if not surge_timer:
		surge_timer = get_node_or_null("SurgeTimer") as Timer
		if not surge_timer and is_inside_tree():
			surge_timer = Timer.new()
			surge_timer.name = "SurgeTimer"
			add_child(surge_timer)
	if surge_timer and not surge_timer.timeout.is_connected(_on_surge_timer_timeout):
		surge_timer.timeout.connect(_on_surge_timer_timeout)

	_load_procedural_formations()

func get_ground_spawn_nodes() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	if ground_zones_node:
		for child in ground_zones_node.get_children():
			if child is Marker3D:
				result.append(child)
	if result.is_empty() and is_inside_tree() and get_tree():
		var b_ground := get_node_or_null("../GroundSpawnSources") as Node3D
		if b_ground:
			for child in b_ground.get_children():
				if child is Marker3D:
					result.append(child)
	if result.is_empty() and is_inside_tree() and get_tree():
		var group_nodes := get_tree().get_nodes_in_group("spawn_ground")
		for n in group_nodes:
			if n is Marker3D:
				result.append(n)
	return result

func get_air_spawn_nodes() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	if air_zones_node:
		for child in air_zones_node.get_children():
			if child is Marker3D:
				result.append(child)
	if result.is_empty() and is_inside_tree() and get_tree():
		var b_air := get_node_or_null("../AirSpawnSources") as Node3D
		if b_air:
			for child in b_air.get_children():
				if child is Marker3D:
					result.append(child)
	if result.is_empty() and is_inside_tree() and get_tree():
		var group_nodes := get_tree().get_nodes_in_group("spawn_air")
		for n in group_nodes:
			if n is Marker3D:
				result.append(n)
	return result

func get_rooftop_spawn_nodes() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	if rooftop_zones_node:
		for child in rooftop_zones_node.get_children():
			if child is Marker3D:
				result.append(child)
	if result.is_empty() and is_inside_tree() and get_tree():
		var b_roof := get_node_or_null("../RooftopSpawnSources") as Node3D
		if b_roof:
			for child in b_roof.get_children():
				if child is Marker3D:
					result.append(child)
	if result.is_empty() and is_inside_tree() and get_tree():
		var group_nodes := get_tree().get_nodes_in_group("spawn_rooftop")
		for n in group_nodes:
			if n is Marker3D:
				result.append(n)
	return result

func get_pickup_spawn_nodes() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	if pickup_locations_node:
		for child in pickup_locations_node.get_children():
			if child is Marker3D:
				result.append(child)
	if result.is_empty() and is_inside_tree() and get_tree():
		var b_pick := get_node_or_null("../PickupLocations") as Node3D
		if b_pick:
			for child in b_pick.get_children():
				if child is Marker3D:
					result.append(child)
	if result.is_empty() and is_inside_tree() and get_tree():
		var group_nodes := get_tree().get_nodes_in_group("pickup_locations")
		for n in group_nodes:
			if n is Marker3D:
				result.append(n)
	return result

func get_active_rooftop_count() -> int:
	var count: int = 0
	for marker in _occupied_rooftop_markers.keys():
		var enemy: Node3D = _occupied_rooftop_markers[marker] as Node3D
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			if "is_alive" in enemy and not enemy.is_alive:
				continue
			count += 1
	return count

## Calculates continuous stream interval based on game stage and deficit state.
## Early game: 1.5 - 2.5s. Mid game: 1.0 - 2.0s. Late game: 0.7 - 1.5s.
## Deficit recovery: recovers gradually at 0.85 - 1.2s without instant burst dumping.
func _get_next_stream_interval(stage: int, is_behind_target: bool) -> float:
	var base_int: float
	if is_behind_target:
		base_int = randf_range(0.85, 1.2)
	else:
		match stage:
			1:
				base_int = randf_range(1.5, 2.5)
			2, 3:
				base_int = randf_range(1.0, 2.0)
			_:
				base_int = randf_range(0.7, 1.5)

	match encounter_state:
		EncounterState.SURGE:
			return base_int * 0.60
		EncounterState.RECOVERY:
			return base_int * 2.8
		_:
			return base_int

func _on_stream_timer_timeout() -> void:
	if not is_wave_active or not is_continuous_mode:
		return
	var stage := get_survival_stage()
	var current_living := get_living_enemy_count()
	var target_count := get_target_active_count()
	var cap := get_active_population_cap()

	if current_living >= cap:
		if stream_timer:
			stream_timer.wait_time = randf_range(2.0, 3.5)
		return

	var player := _get_player()
	var p_pos := player.global_position if player else Vector3.ZERO
	var is_behind_target := current_living < target_count

	# Single gradual stream spawn per tick (no double-spawn burst dumping)
	_spawn_continuous_stream(stage, p_pos)

	if stream_timer:
		stream_timer.wait_time = _get_next_stream_interval(stage, is_behind_target)

func _on_formation_timer_timeout() -> void:
	if not is_wave_active or not is_continuous_mode:
		return
	var stage := get_survival_stage()
	var cap := get_active_population_cap()
	var current_living := get_living_enemy_count()
	var target_count := get_target_active_count()

	if current_living + 4 <= cap:
		var player := _get_player()
		var p_pos := player.global_position if player else Vector3.ZERO
		var is_behind_target := current_living < target_count
		if try_spawn_formation_with_fallback(stage, p_pos):
			if formation_timer:
				formation_timer.wait_time = randf_range(6.0, 10.0) if is_behind_target else randf_range(9.0, 15.0)
			return

	if formation_timer:
		formation_timer.wait_time = randf_range(4.0, 8.0)

func _on_surge_timer_timeout() -> void:
	if not is_wave_active or not is_continuous_mode:
		return
	encounter_state = EncounterState.SURGE
	surge_timer_duration_active = encounter_config.surge_duration if encounter_config else surge_duration
	var bonus_g: float = encounter_config.surge_budget_bonus_ground if encounter_config else 50.0
	var bonus_a: float = encounter_config.surge_budget_bonus_air if encounter_config else 30.0
	continuous_ground_budget += bonus_g
	continuous_air_budget += bonus_a
	if EventBus:
		EventBus.wave_started.emit(current_wave, "⚠ WARNING: HOSTILE HORDE SURGE INBOUND ⚠")
	var s_min: float = encounter_config.surge_interval_min if encounter_config else 75.0
	var s_max: float = encounter_config.surge_interval_max if encounter_config else 90.0
	if surge_timer:
		surge_timer.wait_time = randf_range(s_min, s_max)

func _on_intro_timeout() -> void:
	if is_inside_tree() and not is_queued_for_deletion() and not is_wave_active:
		start_wave(1)

func _on_radar_status_changed(active: bool) -> void:
	is_radar_active = active

func _process(delta: float) -> void:
	if not is_wave_active and not is_continuous_mode and _recovery_timer > 0.0:
		_recovery_timer -= delta
		if _recovery_timer <= 0.0:
			start_wave(current_wave + 1)
		return

	if not is_wave_active:
		return

	# Process staggered arrivals for active formations (0.25 - 0.8s between units)
	_process_formation_stagger_queue(delta)

	if is_continuous_mode:
		_process_continuous_survival(delta)

func _process_formation_stagger_queue(delta: float) -> void:
	if _formation_spawn_queue.is_empty():
		return
	_formation_stagger_timer -= delta
	if _formation_stagger_timer <= 0.0:
		var item: Dictionary = _formation_spawn_queue.pop_front()
		var unit: Node3D = item.get("unit", null) as Node3D
		var parent: Node = item.get("parent", null) as Node
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			if not unit.is_inside_tree() and is_instance_valid(parent):
				parent.add_child.call_deferred(unit)
				_register_spawned_node(unit)
		_formation_stagger_timer = randf_range(0.3, 0.65)

func _deploy_formation_unit(unit: Node3D, parent: Node, is_first: bool, stagger: bool = true) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(parent):
		return
	if is_first or not stagger:
		parent.add_child.call_deferred(unit)
		_register_spawned_node(unit)
	else:
		_formation_spawn_queue.append({
			"unit": unit,
			"parent": parent
		})

func clear_formation_queue() -> void:
	for item in _formation_spawn_queue:
		var u: Node3D = item.get("unit", null) as Node3D
		if is_instance_valid(u) and not u.is_inside_tree():
			u.queue_free()
	_formation_spawn_queue.clear()
	_formation_stagger_timer = 0.0

func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	is_wave_active = true
	clear_formation_queue()
	if wave_num == 1:
		clear_missile_pickups()
		var p := _get_player()
		if is_instance_valid(p) and p.missile_pod and p.missile_pod.has_method("reset_ammo"):
			p.missile_pod.reset_ammo()

	var config: Dictionary
	if wave_num > 10:
		var endless_lvl: int = wave_num - 10
		config = {
			"wave": wave_num,
			"announcement": "ENDLESS OVERDRIVE // SECTOR WAVE %d (2.0x SALVAGE)" % wave_num,
			"ground_budget": 130 + endless_lvl * 30,
			"air_budget": 60 + endless_lvl * 25,
			"ground_slots": mini(4 + int(float(endless_lvl) * 0.5), 6),
			"air_slots": mini(2 + int(float(endless_lvl) * 0.33), 4),
			"enemies": ["hunter", "scout", "raider", "gunship", "jammer", "ace", "sam", "tank", "turret", "infantry"]
		}
	else:
		var wave_idx: int = mini(wave_num - 1, wave_table.size() - 1)
		config = wave_table[wave_idx]

	if CombatDirector.instance:
		CombatDirector.instance.set_wave_limits(config["ground_slots"], config["air_slots"])

	if EventBus:
		if is_continuous_mode:
			if wave_num == 1:
				EventBus.wave_started.emit(1, "HOSTILE COMBAT ZONE // SURVIVAL DEPLOYMENT ACTIVE")
			else:
				EventBus.wave_started.emit(wave_num, "THREAT LEVEL ESCALATING // COMBAT ACTIVE")
		else:
			EventBus.wave_started.emit(current_wave, config["announcement"])

	# Spawn specific wave objective / boss
	if wave_num == 5 and not _scheduled_events_triggered.get("radar_station", false):
		_scheduled_events_triggered["radar_station"] = true
		_spawn_radar_objective()
	elif wave_num == 10 and not _scheduled_events_triggered.get("archon_boss", false):
		_scheduled_events_triggered["archon_boss"] = true
		_spawn_archon_boss()

	if is_continuous_mode:
		if stream_timer and stream_timer.is_stopped():
			stream_timer.start(1.2)
		if formation_timer and formation_timer.is_stopped():
			formation_timer.start(4.0)
		if surge_timer and surge_timer.is_stopped():
			surge_timer.start(surge_interval)

		if elapsed_survival_time <= 0.1:
			continuous_ground_budget = 40.0
			continuous_air_budget = 10.0
			var player := _get_player()
			var p_pos := player.global_position if player else Vector3.ZERO
			_spawn_initial_encounter(p_pos)
		else:
			_spend_budget(config)
		_total_wave_enemies = _wave_enemies.size()
		_notify_progress()
	else:
		_wave_enemies.clear()
		_spend_budget(config)
		_total_wave_enemies = _wave_enemies.size()
		_notify_progress()

## Guaranteed playable initial encounter on run start using authored ground, rooftop, and air entrances
func _spawn_initial_encounter(player_pos: Vector3) -> void:
	# 1. First infantry squad entering from Road Entrance North
	var g_north := get_authored_ground_spawn("infantry", player_pos, 35.0)
	_spawn_continuous_enemy(_scene_infantry, player_pos, 0.0, g_north["position"])

	# 2. Second infantry squad in opposing direction (Road Entrance South / Outskirts)
	var g_south := get_authored_ground_spawn("infantry", player_pos, 35.0)
	_spawn_continuous_enemy(_scene_infantry, player_pos, 0.0, g_south["position"])

	# 3. Ground Turret / technical at Industrial Entrance or Military Gate
	var g_ind := get_authored_ground_spawn("turret", player_pos, 35.0)
	_spawn_continuous_enemy(_scene_turret, player_pos, 0.0, g_ind["position"])

	# 4. Third squad from available perimeter entrance
	var g_west := get_authored_ground_spawn("infantry", player_pos, 35.0)
	_spawn_continuous_enemy(_scene_infantry, player_pos, 0.0, g_west["position"])

	# 5. Rooftop threat on authored rooftop marker in Urban / Industrial district
	spawn_rooftop_threat(1, player_pos)

	# 6. Two light air scouts approaching from opposing air corridors
	var air_1 := get_air_corridor_entry(player_pos, 38.0)
	_spawn_continuous_enemy(_scene_air_scout, player_pos, air_1["position"].y, air_1["position"])

	var air_2 := get_air_corridor_entry(player_pos, 38.0)
	_spawn_continuous_enemy(_scene_air_scout, player_pos, air_2["position"].y, air_2["position"])

func get_survival_stage() -> int:
	if elapsed_survival_time < 120.0:
		return 1 # 0-2 min: Opening
	elif elapsed_survival_time < 300.0:
		return 2 # 2-5 min: Build-Up
	elif elapsed_survival_time < 480.0:
		return 3 # 5-8 min: Pressure
	elif elapsed_survival_time < 720.0:
		return 4 # 8-12 min: Escalation
	elif elapsed_survival_time < 900.0:
		return 5 # 12-15 min: Crisis
	else:
		return 6 # 15+ min: Extreme

func get_active_population_cap() -> int:
	if not encounter_config:
		var stage := get_survival_stage()
		match stage:
			1: return 24
			2: return 45
			3: return 65
			4: return 80
			5: return 95
			6: return 120
			_: return 35
	if elapsed_survival_time < encounter_config.warmup_duration:
		return encounter_config.warmup_ground_cap + encounter_config.warmup_air_cap
	var progress := clampf(elapsed_survival_time / encounter_config.escalation_duration, 0.0, 1.0)
	var max_total: int = encounter_config.max_ground_cap + encounter_config.max_air_cap
	return mini(int(lerpf(float(encounter_config.warmup_ground_cap + encounter_config.warmup_air_cap), float(max_total), progress)), encounter_config.global_active_cap)

func get_ground_population_cap() -> int:
	if not encounter_config:
		return 14
	if elapsed_survival_time < encounter_config.warmup_duration:
		return encounter_config.warmup_ground_cap
	var progress := clampf(elapsed_survival_time / encounter_config.escalation_duration, 0.0, 1.0)
	return int(lerpf(float(encounter_config.warmup_ground_cap), float(encounter_config.max_ground_cap), progress))

func get_air_population_cap() -> int:
	if not encounter_config:
		return 6
	if elapsed_survival_time < encounter_config.warmup_duration:
		return encounter_config.warmup_air_cap
	var progress := clampf(elapsed_survival_time / encounter_config.escalation_duration, 0.0, 1.0)
	return int(lerpf(float(encounter_config.warmup_air_cap), float(encounter_config.max_air_cap), progress))

func get_target_active_count() -> int:
	if not encounter_config:
		if elapsed_survival_time < 120.0:
			return int(lerpf(16.0, 24.0, elapsed_survival_time / 120.0))
		elif elapsed_survival_time < 300.0:
			return int(lerpf(25.0, 38.0, (elapsed_survival_time - 120.0) / 180.0))
		elif elapsed_survival_time < 480.0:
			return int(lerpf(38.0, 50.0, (elapsed_survival_time - 300.0) / 180.0))
		else:
			return int(lerpf(50.0, 68.0, clampf((elapsed_survival_time - 480.0) / 360.0, 0.0, 1.0)))
	var cap := get_active_population_cap()
	if elapsed_survival_time < encounter_config.warmup_duration:
		return maxi(2, int(float(cap) * 0.55))
	return maxi(4, int(float(cap) * 0.85))

func get_living_enemy_count() -> int:
	if EnemyRegistry.instance:
		return EnemyRegistry.instance.get_active_count()
	var count: int = 0
	for i in range(_wave_enemies.size() - 1, -1, -1):
		var e := _wave_enemies[i]
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			_wave_enemies.remove_at(i)
		elif "is_alive" in e and not e.is_alive:
			_wave_enemies.remove_at(i)
		else:
			count += 1
	return count

func apply_elite_modifier(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or enemy.is_in_group("bosses") or enemy.is_in_group("elites"):
		return
	var mods := ["Armored", "Rapid Fire", "Fast", "Berserk"]
	var mod: String = mods.pick_random()
	enemy.add_to_group("elites")
	enemy.set_meta("elite_type", mod)

	match mod:
		"Armored":
			if "max_health" in enemy:
				enemy.max_health *= 1.8
				enemy.current_health = enemy.max_health
			elif "health" in enemy:
				enemy.health *= 1.8
			if "damage_taken_mult" in enemy:
				enemy.damage_taken_mult *= 0.6
		"Rapid Fire":
			if "fire_rate" in enemy:
				enemy.fire_rate *= 1.5
			if "attack_cooldown" in enemy:
				enemy.attack_cooldown *= 0.65
		"Fast":
			if "move_speed" in enemy:
				enemy.move_speed *= 1.4
			if "max_speed" in enemy:
				enemy.max_speed *= 1.4
		"Berserk":
			if "max_health" in enemy:
				enemy.max_health *= 1.3
				enemy.current_health = enemy.max_health
			if "move_speed" in enemy:
				enemy.move_speed *= 1.25
			if "damage" in enemy:
				enemy.damage *= 1.4

	enemy.scale *= 1.2
	var mesh: GeometryInstance3D = enemy.find_child("*Mesh*", true, false) as GeometryInstance3D
	if not mesh:
		mesh = enemy.find_child("Visuals", true, false) as GeometryInstance3D
	if mesh and mesh.material_override:
		var mat := mesh.material_override.duplicate() as StandardMaterial3D
		if mat:
			mat.albedo_color = mat.albedo_color.lerp(Color(1.3, 0.7, 0.2), 0.45)
			mesh.material_override = mat

	if "salvage_value" in enemy:
		enemy.salvage_value = int(enemy.salvage_value * 3)
	if "xp_value" in enemy:
		enemy.xp_value = int(enemy.xp_value * 3)

func _process_continuous_survival(delta: float) -> void:
	elapsed_survival_time += delta

	var warmup_dur: float = encounter_config.warmup_duration if encounter_config else 25.0
	var surge_dur: float = encounter_config.surge_duration if encounter_config else 15.0
	var breather_dur: float = encounter_config.recovery_breather_duration if encounter_config else 10.0
	var s_min: float = encounter_config.surge_interval_min if encounter_config else 75.0
	var s_max: float = encounter_config.surge_interval_max if encounter_config else 90.0

	# 1. Encounter State Machine: WARMUP -> STREAMING <-> SURGE -> RECOVERY -> STREAMING
	match encounter_state:
		EncounterState.WARMUP:
			if elapsed_survival_time >= warmup_dur:
				encounter_state = EncounterState.STREAMING
				next_surge_time = elapsed_survival_time + randf_range(s_min, s_max)
		EncounterState.STREAMING:
			if elapsed_survival_time >= next_surge_time:
				encounter_state = EncounterState.SURGE
				surge_timer_duration_active = surge_dur
				var bonus_g: float = encounter_config.surge_budget_bonus_ground if encounter_config else 50.0
				var bonus_a: float = encounter_config.surge_budget_bonus_air if encounter_config else 30.0
				continuous_ground_budget += bonus_g
				continuous_air_budget += bonus_a
				if EventBus:
					EventBus.wave_started.emit(current_wave, "⚠ WARNING: HOSTILE HORDE SURGE INBOUND ⚠")
		EncounterState.SURGE:
			surge_timer_duration_active -= delta
			if surge_timer_duration_active <= 0.0:
				encounter_state = EncounterState.RECOVERY
				recovery_timer_remaining = breather_dur
				if EventBus:
					EventBus.wave_started.emit(current_wave, "TACTICAL BREATHER // GATHER SALVAGE & REPOSITION")
		EncounterState.RECOVERY:
			recovery_timer_remaining -= delta
			if recovery_timer_remaining <= 0.0:
				encounter_state = EncounterState.STREAMING
				next_surge_time = elapsed_survival_time + randf_range(s_min, s_max)

	# 2. Sector Rotation (preserves 2 active non-adjacent sectors for escape routes)
	_sector_rotation_timer -= delta
	if _sector_rotation_timer <= 0.0:
		_rotate_active_sectors()
		_sector_rotation_timer = randf_range(7.0, 11.0)

	# 3. Power-curve budget accumulation scaling
	var esc_dur: float = encounter_config.escalation_duration if encounter_config else 300.0
	var power_val: float = encounter_config.budget_growth_power if encounter_config else 1.35
	var progress := elapsed_survival_time / esc_dur
	var time_mult := pow(1.0 + progress, power_val)

	var state_mult := 1.0
	match encounter_state:
		EncounterState.WARMUP:
			state_mult = 0.55
		EncounterState.SURGE:
			state_mult = 2.2
		EncounterState.RECOVERY:
			state_mult = encounter_config.recovery_budget_rate_mult if encounter_config else 0.30
		EncounterState.STREAMING:
			state_mult = 1.0

	var diff_scale := 1.0
	var gm := get_tree().get_first_node_in_group("game_manager") if is_inside_tree() else null
	if gm and "difficulty_scale" in gm:
		diff_scale = float(gm.difficulty_scale)

	continuous_ground_budget += base_ground_budget_rate * time_mult * state_mult * diff_scale * delta
	continuous_air_budget += base_air_budget_rate * time_mult * state_mult * diff_scale * delta

	# Cap accumulated budget to prevent runaway stockpiles during peaceful lulls
	var max_ground_b: float = 120.0 * time_mult
	var max_air_b: float = 60.0 * time_mult
	continuous_ground_budget = minf(continuous_ground_budget, max_ground_b)
	continuous_air_budget = minf(continuous_air_budget, max_air_b)

	# 4. Offscreen distant enemy cleanup (every ~2 seconds)
	var cleanup_interval: float = encounter_config.offscreen_cleanup_check_interval if encounter_config else 2.0
	_offscreen_cleanup_timer -= delta
	if _offscreen_cleanup_timer <= 0.0:
		_offscreen_cleanup_timer = cleanup_interval
		_process_offscreen_cleanup()

	# 5. Dynamic CombatDirector attack slot scaling
	if CombatDirector.instance:
		var stage := get_survival_stage()
		var g_slots := mini(3 + stage, 6)
		var a_slots := 1 if stage == 1 else mini(1 + stage, 4)
		CombatDirector.instance.set_wave_limits(g_slots, a_slots)

	# 6. Check scheduled encounters
	_check_scheduled_events()

	# 7. Process periodic authored pickup spawning
	_process_pickup_spawning(delta)

	# 8. Periodic rooftop threat check
	_rooftop_check_timer -= delta
	if _rooftop_check_timer <= 0.0:
		_rooftop_check_timer = randf_range(22.0, 32.0)
		var player := _get_player()
		var p_pos := player.global_position if player else Vector3.ZERO
		spawn_rooftop_threat(get_survival_stage(), p_pos)

	# 9. Process continuous spawning of formations and streams (fallback when timers are not used)
	if not stream_timer and not formation_timer:
		_process_continuous_spawning(delta)

func set_mission_focus(pos: Vector3) -> void:
	has_mission_focus = true
	mission_focus_position = pos
	_apply_mission_sector_focus()

func clear_mission_focus() -> void:
	has_mission_focus = false
	mission_focus_position = Vector3.ZERO

func _apply_mission_sector_focus() -> void:
	var player := _get_player()
	var p_pos := player.global_position if is_instance_valid(player) else Vector3.ZERO
	var to_mission := mission_focus_position - p_pos
	var angle := atan2(to_mission.x, to_mission.z)
	var focus_sec := posmod(int(round((angle + PI) / (TAU / 8.0))), 8)
	var second_sec := (focus_sec + 2) % 8
	_active_sectors = [focus_sec, second_sec]

func _rotate_active_sectors() -> void:
	if has_mission_focus:
		_apply_mission_sector_focus()
		return
	var old_first := _active_sectors[0] if _active_sectors.size() > 0 else 0
	var new_first := (old_first + randi_range(2, 6)) % 8
	var offsets: Array[int] = [2, 3, 4, 5]
	var offset: int = offsets.pick_random()
	var new_second: int = (new_first + offset) % 8
	_active_sectors = [new_first, new_second]

func is_position_in_camera_view(pos: Vector3, margin_px: float = 100.0) -> bool:
	if not is_inside_tree():
		return false
	var vp := get_viewport()
	if not vp:
		return false
	var cam := vp.get_camera_3d()
	if not cam:
		return false
	if cam.is_position_behind(pos):
		return false

	var cam_fwd := -cam.global_transform.basis.z
	var near_dist: float = maxf(cam.near, 0.1)
	if cam_fwd.dot(pos - cam.global_position) <= near_dist:
		return false

	var vp_rect := vp.get_visible_rect()
	var expanded_rect := Rect2(
		-margin_px,
		-margin_px,
		vp_rect.size.x + margin_px * 2.0,
		vp_rect.size.y + margin_px * 2.0
	)
	var screen_pos := cam.unproject_position(pos)
	if expanded_rect.has_point(screen_pos):
		return true

	# Check lateral/vertical bounding extents of vehicles/aircraft to prevent pop-in of vehicle edges
	var bounding_offsets: Array[Vector3] = [
		Vector3(4.0, 0.0, 0.0),
		Vector3(-4.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 4.0),
		Vector3(0.0, 0.0, -4.0),
		Vector3(0.0, 3.0, 0.0)
	]
	for off: Vector3 in bounding_offsets:
		var p: Vector3 = pos + off
		if not cam.is_position_behind(p) and cam_fwd.dot(p - cam.global_position) > near_dist:
			var sp := cam.unproject_position(p)
			if expanded_rect.has_point(sp):
				return true
	return false

func _get_world_direct_space_state() -> PhysicsDirectSpaceState3D:
	if is_inside_tree():
		var vp := get_viewport()
		if vp and vp.find_world_3d() and vp.find_world_3d().direct_space_state:
			return vp.find_world_3d().direct_space_state
	return null

func _validate_ground_clearance(pos: Vector3) -> Dictionary:
	var space := _get_world_direct_space_state()
	var ground_y := 0.0
	if space:
		var ray_query := PhysicsRayQueryParameters3D.new()
		ray_query.from = Vector3(pos.x, 60.0, pos.z)
		ray_query.to = Vector3(pos.x, -10.0, pos.z)
		ray_query.collision_mask = 1 # World geometry / terrain / buildings
		var hit := space.intersect_ray(ray_query)
		if not hit.is_empty():
			ground_y = float(hit.position.y)
			# If hit object is higher than 4.5m, it's a rooftop/structure, not walkable ground
			if ground_y > 4.5:
				return { "valid": false, "position": Vector3(pos.x, ground_y, pos.z) }
		else:
			ground_y = 0.0

	var checked_pos := Vector3(pos.x, ground_y, pos.z)
	if not is_spawn_position_clear(checked_pos, false):
		return { "valid": false, "position": checked_pos }

	return { "valid": true, "position": checked_pos }

func _validate_air_clearance(pos: Vector3) -> bool:
	if not is_spawn_position_clear(pos, true):
		return false
	var space := _get_world_direct_space_state()
	if space:
		var shape_query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 3.5
		shape_query.shape = sphere
		shape_query.transform = Transform3D(Basis(), pos)
		shape_query.collision_mask = 1
		var hits := space.intersect_shape(shape_query, 1)
		if not hits.is_empty():
			return false
	return true

func get_dynamic_encounter_spawn_point(is_air: bool, player_pos: Vector3, min_dist: float = -1.0, max_dist: float = -1.0) -> Dictionary:
	if min_dist < 0.0:
		min_dist = encounter_config.spawn_distance_min if encounter_config else 38.0
	if max_dist < 0.0:
		max_dist = encounter_config.spawn_distance_max if encounter_config else 68.0

	# 1. Velocity lead calculation
	var player := _get_player()
	var p_vel := Vector3.ZERO
	if player:
		if "velocity" in player:
			p_vel = player.velocity
		elif "linear_velocity" in player:
			p_vel = player.linear_velocity
	p_vel.y = 0.0

	var lead_time: float = encounter_config.velocity_lead_time if encounter_config else 1.2
	var ref_center := player_pos + (p_vel * lead_time)

	# 2. Check arena edge proximity for boundary redistribution
	var margin: float = encounter_config.boundary_redistribution_margin if encounter_config else 25.0
	var safe_limit := arena_half_extents - margin
	var near_boundary := absf(ref_center.x) > safe_limit or absf(ref_center.z) > safe_limit
	var inward_dir := Vector2.ZERO
	if near_boundary:
		inward_dir = -Vector2(ref_center.x, ref_center.z).normalized()

	var margin_px: float = encounter_config.camera_frustum_margin_px if encounter_config else 100.0
	var arena_bound := arena_half_extents - 8.0

	# 3. Sample from current 2 active non-adjacent sectors
	for attempt in range(16):
		var sector: int = _active_sectors.pick_random() if _active_sectors.size() > 0 else (randi() % 8)
		var base_angle := float(sector) * (TAU / 8.0)
		var angle := base_angle + randf_range(-PI / 8.0, PI / 8.0)

		# Edge redistribution: blend sector angle inward if facing boundary wall
		if near_boundary and inward_dir.length_squared() > 0.01:
			var inward_angle := atan2(inward_dir.y, inward_dir.x)
			var angle_diff := absf(angle_difference(angle, inward_angle))
			if angle_diff > (PI * 0.5):
				angle = lerp_angle(angle, inward_angle, 0.75)

		var dist := randf_range(min_dist, max_dist)
		var cand_x := ref_center.x + cos(angle) * dist
		var cand_z := ref_center.z + sin(angle) * dist

		# Reject if candidate is beyond playable boundary (no edge clumping)
		if absf(cand_x) > arena_bound or absf(cand_z) > arena_bound:
			continue

		var cand_alt := 0.0
		if is_air:
			cand_alt = clampf(_get_player_altitude() + randf_range(-2.0, 3.5), 13.0, 24.0)

		var cand_pos := Vector3(cand_x, cand_alt, cand_z)

		# Reject if inside visible camera view (strict pop-in protection)
		if is_position_in_camera_view(cand_pos, margin_px):
			continue

		if not is_air:
			var g_res := _validate_ground_clearance(cand_pos)
			if not g_res["valid"]:
				continue
			var final_pos: Vector3 = g_res["position"]
			var hd := (player_pos - final_pos)
			hd.y = 0.0
			_record_spawn_sector(sector)
			last_spawn_source = "EncounterSector_%d" % sector
			return { "position": final_pos, "heading": hd.normalized(), "source_name": "Sector_%d" % sector }
		else:
			if not _validate_air_clearance(cand_pos):
				continue
			var hd := (player_pos - cand_pos)
			hd.y = 0.0
			_record_spawn_sector(sector)
			last_spawn_source = "EncounterAirSector_%d" % sector
			return { "position": cand_pos, "heading": hd.normalized(), "source_name": "AirSector_%d" % sector }

	# 4. Fallback pass: check authored spawn nodes that are off-screen
	if is_air:
		for a_node in get_air_spawn_nodes():
			var p := a_node.global_position
			var d := player_pos.distance_to(p)
			if d >= min_dist and not is_position_in_camera_view(p, margin_px) and is_spawn_position_clear(p, true):
				var hd := (player_pos - p)
				hd.y = 0.0
				last_spawn_source = a_node.name + " (EncounterFallback)"
				return { "position": p, "heading": hd.normalized(), "source_name": a_node.name }
	else:
		for g_node in get_ground_spawn_nodes():
			var p := g_node.global_position
			var d := player_pos.distance_to(p)
			if d >= min_dist and not is_position_in_camera_view(p, margin_px) and is_spawn_position_clear(p, false):
				var hd := (player_pos - p)
				hd.y = 0.0
				last_spawn_source = g_node.name + " (EncounterFallback)"
				return { "position": p, "heading": hd.normalized(), "source_name": g_node.name }

	# 5. Final safe fallback
	failed_spawn_attempts += 1
	var safe_pos := _get_safe_perimeter_fallback(player_pos)
	var safe_hd := (player_pos - safe_pos)
	safe_hd.y = 0.0
	if is_air:
		safe_pos.y = clampf(_get_player_altitude(), 14.0, 22.0)
	last_spawn_source = "Safe Perimeter Fallback"
	return { "position": safe_pos, "heading": safe_hd.normalized(), "source_name": "SafePerimeter" }

func _process_offscreen_cleanup() -> void:
	var player := _get_player()
	if not is_instance_valid(player):
		return
	var player_pos := player.global_position

	var despawn_dist: float = encounter_config.despawn_distance_threshold if encounter_config else 115.0
	var time_threshold: float = encounter_config.despawn_offscreen_time_threshold if encounter_config else 25.0
	var check_interval: float = encounter_config.offscreen_cleanup_check_interval if encounter_config else 2.0

	var living_enemies: Array[Node3D] = []
	for enemy in _wave_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			living_enemies.append(enemy)

	for enemy in living_enemies:
		if enemy.is_in_group("bosses") or enemy.is_in_group("objective") or enemy.name.begins_with("Boss") or enemy.name.begins_with("Radar"):
			continue
		if "is_alive" in enemy and not enemy.is_alive:
			continue

		var dist := player_pos.distance_to(enemy.global_position)
		var is_viewable := is_position_in_camera_view(enemy.global_position, 60.0)

		if dist > 150.0 and not is_viewable:
			_despawn_enemy_quietly(enemy)
			continue

		if dist > despawn_dist and not is_viewable:
			var cur_time: float = _enemy_offscreen_durations.get(enemy, 0.0) + check_interval
			_enemy_offscreen_durations[enemy] = cur_time
			if cur_time >= time_threshold:
				_despawn_enemy_quietly(enemy)
		else:
			if _enemy_offscreen_durations.has(enemy):
				_enemy_offscreen_durations.erase(enemy)

func _despawn_enemy_quietly(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	_enemy_offscreen_durations.erase(enemy)
	total_despawns += 1

	if enemy.tree_exited.is_connected(_on_spawned_enemy_tree_exited):
		enemy.tree_exited.disconnect(_on_spawned_enemy_tree_exited)

	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(enemy)

	_wave_enemies.erase(enemy)

	var is_air := _is_air_enemy(enemy)
	var recycle_ratio: float = encounter_config.recycle_budget_ratio if encounter_config else 0.5
	if is_air:
		continuous_air_budget += 4.0 * recycle_ratio
	else:
		continuous_ground_budget += 15.0 * recycle_ratio

	enemy.queue_free()
	_notify_progress()

func _check_scheduled_events() -> void:
	# 1. Transport Reinforcement Drop at ~150s (2.5m)
	if elapsed_survival_time >= 150.0 and not _scheduled_events_triggered.get("transport_drop", false):
		_scheduled_events_triggered["transport_drop"] = true
		var player := _get_player()
		var p_pos := player.global_position if player else Vector3.ZERO
		var entry := get_air_corridor_entry(p_pos, 48.0, 75.0)
		spawn_reinforcement_drop(entry["position"], entry["heading"], true)
		if EventBus:
			EventBus.wave_started.emit(current_wave, "⚠ INCOMING AIRBORNE REINFORCEMENT CONVOY ⚠")

	# 2. Radar Station at ~270s (4.5m)
	if elapsed_survival_time >= 270.0 and not _scheduled_events_triggered.get("radar_station", false):
		_scheduled_events_triggered["radar_station"] = true
		_spawn_radar_objective()
		if EventBus:
			EventBus.wave_started.emit(current_wave, "⚠ MISSION OBJECTIVE: DESTROY RADAR STATION ⚠")

	# 3. Ace Gunship at ~420s (7.0m)
	if elapsed_survival_time >= 420.0 and not _scheduled_events_triggered.get("ace_gunship", false):
		_scheduled_events_triggered["ace_gunship"] = true
		var player := _get_player()
		var p_pos := player.global_position if player else Vector3.ZERO
		var entry := get_air_corridor_entry(p_pos, 50.0, 80.0)
		spawn_elite_air_encounter(entry["position"], entry["heading"])
		if EventBus:
			EventBus.wave_started.emit(current_wave, "⚠ ELITE AIR CONTACT: ACE GUNSHIP ⚠")

	# 4. Archon Boss at ~600s (10.0m)
	if elapsed_survival_time >= 600.0 and not _scheduled_events_triggered.get("archon_boss", false):
		_scheduled_events_triggered["archon_boss"] = true
		_spawn_archon_boss()
		if EventBus:
			EventBus.wave_started.emit(current_wave, "⚠ BOSS CONTACT: ARCHON HEAVY GUNSHIP ⚠")

func _process_continuous_spawning(delta: float) -> void:
	var stage := get_survival_stage()
	var cap := get_active_population_cap()
	var current_living := get_living_enemy_count()
	var target_count := get_target_active_count()

	if current_living >= cap:
		return

	var player := _get_player()
	var p_pos := player.global_position if player else Vector3.ZERO

	var is_behind_target := current_living < target_count

	# 1. Formation Spawning
	_continuous_formation_cooldown -= delta
	if _continuous_formation_cooldown <= 0.0 and (current_living + 4 <= cap):
		if try_spawn_formation_with_fallback(stage, p_pos):
			_continuous_formation_cooldown = randf_range(6.0, 10.0) if is_behind_target else randf_range(9.0, 15.0)
			return

	# 2. Ambient Stream Spawning
	_continuous_stream_cooldown -= delta
	if _continuous_stream_cooldown <= 0.0:
		_spawn_continuous_stream(stage, p_pos)
		_continuous_stream_cooldown = _get_next_stream_interval(stage, is_behind_target)

func try_spawn_formation_with_fallback(stage: int, p_pos: Vector3) -> bool:
	# 1. Primary formation candidates
	if _try_spawn_continuous_formation(stage, p_pos):
		return true

	# 2. Multi-tier Fallback: Cheaper formation (Infantry Squad, staggered)
	if continuous_ground_budget >= 25.0 and can_spawn_formation("infantry_squad"):
		var s_pos := get_frustum_safe_spawn_pos(p_pos, 35.0, 55.0)
		_spawn_continuous_enemy(_scene_infantry, p_pos, 0.0, s_pos)
		var off := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		var second: Node3D = _scene_infantry.instantiate() as Node3D
		if second:
			second.transform.origin = Vector3(s_pos.x + off.x, 0.0, s_pos.z + off.z)
			_deploy_formation_unit(second, _get_spawn_parent(), false, true)
		continuous_ground_budget -= 25.0
		_record_formation("infantry_squad")
		last_formation_name = "infantry_squad (Fallback)"
		return true

	# 3. Final Fallback: Basic fodder stream from safe zone
	var current_living := get_living_enemy_count()
	var target_count := get_target_active_count()
	if current_living < target_count:
		continuous_ground_budget = maxf(continuous_ground_budget, 15.0)

	if continuous_ground_budget >= 15.0:
		var f_pos := get_frustum_safe_spawn_pos(p_pos, 32.0, 52.0)
		_spawn_continuous_enemy(_scene_infantry, p_pos, 0.0, f_pos)
		continuous_ground_budget -= 15.0
		last_formation_name = "basic_fodder (Fallback)"
		return true

	return false

func _try_spawn_continuous_formation(stage: int, p_pos: Vector3) -> bool:
	# 1. Evaluate procedural formation cards first
	var proc_form := select_procedural_formation(p_pos)
	if proc_form:
		var spawned := spawn_procedural_formation(proc_form, p_pos)
		if not spawned.is_empty():
			return true

	if stage >= 4 and continuous_air_budget >= 20.0 and can_spawn_formation("elite_encounter") and get_active_air_count("ace_gunships") < cap_ace and randf() > 0.4:
		var entry := get_air_corridor_entry(p_pos, 45.0, 75.0)
		spawn_elite_air_encounter(entry["position"], entry["heading"])
		continuous_air_budget -= 20.0
		return true

	if stage >= 4 and continuous_air_budget >= 17.0 and can_spawn_formation("electronic_strike") and get_active_air_count("jammers") < cap_jammer and randf() > 0.4:
		var entry := get_air_corridor_entry(p_pos, 45.0, 75.0)
		spawn_electronic_strike_group(entry["position"], entry["heading"], true)
		continuous_air_budget -= 17.0
		return true

	if stage >= 3 and continuous_ground_budget >= 40.0 and continuous_air_budget >= 22.0 and can_spawn_formation("combined_arms") and randf() > 0.35:
		var entry := get_air_corridor_entry(p_pos, 45.0, 72.0)
		spawn_combined_arms_formation(entry["position"], entry["heading"])
		continuous_ground_budget -= 40.0
		continuous_air_budget -= 22.0
		return true

	if stage >= 3 and continuous_air_budget >= 13.0 and can_spawn_formation("air_intercept") and get_active_air_count("attack_gunships") < cap_gunship and randf() > 0.35:
		var entry := get_air_corridor_entry(p_pos, 42.0, 70.0)
		spawn_air_intercept(entry["position"], entry["heading"], 1)
		continuous_air_budget -= 13.0
		return true

	if stage >= 2 and continuous_air_budget >= 14.0 and can_spawn_formation("harassment_group") and get_active_air_count("rocket_raiders") < cap_raider and randf() > 0.3:
		var entry := get_air_corridor_entry(p_pos, 42.0, 70.0)
		spawn_harassment_group(entry["position"], entry["heading"])
		continuous_air_budget -= 14.0
		return true

	if stage >= 2 and continuous_ground_budget >= 55.0 and can_spawn_formation("road_column") and randf() > 0.3:
		var entry := get_authored_ground_spawn("road_column", p_pos, 35.0)
		spawn_road_column(entry["position"], entry["heading"], 3)
		continuous_ground_budget -= 55.0
		_record_formation("road_column")
		return true

	# Air Patrol (2 Scouts) available in Stage 1 & 2
	if continuous_air_budget >= 8.0 and can_spawn_formation("air_patrol") and get_active_air_count("scouts") + 2 <= cap_scout:
		var entry := get_air_corridor_entry(p_pos, 40.0, 65.0)
		spawn_air_patrol(entry["position"], entry["heading"])
		continuous_air_budget -= 8.0
		return true

	# Formation Fallback: Infantry Squad (2 clusters, staggered)
	if continuous_ground_budget >= 25.0 and can_spawn_formation("infantry_squad"):
		var entry := get_authored_ground_spawn("infantry", p_pos, 35.0)
		var s_pos: Vector3 = entry["position"]
		_spawn_continuous_enemy(_scene_infantry, p_pos, 0.0, s_pos)
		var off := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		var second: Node3D = _scene_infantry.instantiate() as Node3D
		if second:
			second.transform.origin = Vector3(s_pos.x + off.x, 0.0, s_pos.z + off.z)
			_deploy_formation_unit(second, _get_spawn_parent(), false, true)
		continuous_ground_budget -= 25.0
		_record_formation("infantry_squad")
		return true

	return false

func _spawn_continuous_stream(stage: int, p_pos: Vector3) -> void:
	var current_living := get_living_enemy_count()
	var target_count := get_target_active_count()
	var cap := get_active_population_cap()
	if current_living >= cap:
		return

	var ground_living := 0
	var air_living := 0
	if EnemyRegistry.instance:
		ground_living = EnemyRegistry.instance.ground_enemies.size()
		air_living = EnemyRegistry.instance.air_enemies.size()
	else:
		for e in _wave_enemies:
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				if _is_air_enemy(e):
					air_living += 1
				else:
					ground_living += 1

	var ground_cap := get_ground_population_cap()
	var air_cap := get_air_population_cap()

	# Minimum budget guarantee when below target count to prevent starving
	if current_living < target_count:
		continuous_ground_budget = maxf(continuous_ground_budget, 15.0)
		if continuous_air_budget < 4.0 and stage >= 1:
			continuous_air_budget = maxf(continuous_air_budget, 4.0)

	# Ground stream with time-based unlocks and tactical caps
	if ground_living < ground_cap and continuous_ground_budget >= 15.0:
		var chosen_scene: PackedScene = _scene_infantry
		var cost: float = 15.0

		if elapsed_survival_time >= 300.0 and continuous_ground_budget >= 40.0 and get_active_unit_count("sam") < cap_sam and randf() > 0.7:
			chosen_scene = _scene_sam
			cost = 40.0
		elif elapsed_survival_time >= 300.0 and continuous_ground_budget >= 34.0 and get_active_unit_count("mortar") < cap_mortar and randf() > 0.65:
			chosen_scene = _scene_mortar
			cost = 34.0
		elif elapsed_survival_time >= 300.0 and continuous_ground_budget >= 35.0 and get_active_unit_count("jammer") < cap_support and randf() > 0.7:
			chosen_scene = _scene_ground_jammer
			cost = 35.0
		elif elapsed_survival_time >= 300.0 and continuous_ground_budget >= 28.0 and randf() > 0.5:
			chosen_scene = _scene_tank
			cost = 28.0
		elif elapsed_survival_time >= 120.0 and continuous_ground_budget >= 28.0 and get_active_unit_count("transport") < cap_transport and randf() > 0.6:
			chosen_scene = _scene_apc
			cost = 28.0
		elif elapsed_survival_time >= 120.0 and continuous_ground_budget >= 26.0 and randf() > 0.55:
			chosen_scene = _scene_ifv
			cost = 26.0
		elif elapsed_survival_time >= 120.0 and continuous_ground_budget >= 20.0 and randf() > 0.5:
			chosen_scene = _scene_turret
			cost = 20.0
		elif continuous_ground_budget >= 22.0 and randf() > 0.5:
			chosen_scene = _scene_technical
			cost = 22.0
		elif continuous_ground_budget >= 18.0 and randf() > 0.4:
			chosen_scene = _scene_buggy
			cost = 18.0
		else:
			chosen_scene = _scene_infantry
			cost = 15.0

		_spawn_continuous_enemy(chosen_scene, p_pos, 0.0)
		continuous_ground_budget -= cost

	# Air stream with time-based unlocks and tactical caps
	var p_y := clampf(_get_player_altitude(), 11.0, 17.0)
	if air_living < air_cap:
		if elapsed_survival_time >= 480.0 and continuous_air_budget >= 9.0 and get_active_unit_count("gunship") < cap_gunship and randf() > 0.45:
			_spawn_continuous_enemy(_scene_air_gunship, p_pos, p_y)
			continuous_air_budget -= 9.0
		elif elapsed_survival_time >= 300.0 and continuous_air_budget >= 8.0 and get_active_unit_count("jammer") < cap_jammer and randf() > 0.6:
			_spawn_continuous_enemy(_scene_air_jammer, p_pos, p_y + 3.0)
			continuous_air_budget -= 8.0
		elif elapsed_survival_time >= 300.0 and continuous_air_budget >= 7.0 and get_active_unit_count("transport") < cap_transport and randf() > 0.6:
			_spawn_continuous_enemy(_scene_air_transport, p_pos, p_y)
			continuous_air_budget -= 7.0
		elif elapsed_survival_time >= 120.0 and continuous_air_budget >= 6.0 and get_active_unit_count("raider") < cap_raider and randf() > 0.4:
			_spawn_continuous_enemy(_scene_air_raider, p_pos, p_y + 2.0)
			continuous_air_budget -= 6.0
		elif continuous_air_budget >= 4.0 and get_active_unit_count("scout") < cap_scout:
			_spawn_continuous_enemy(_scene_air_scout, p_pos, p_y)
			continuous_air_budget -= 4.0

func _is_air_enemy(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	# Explicit ground enemy types and resources must NEVER be treated as air
	if (enemy is Tank) or (enemy is InfantryCluster) or (enemy is GroundTurret) or (enemy is SAMSite):
		return false
	if "archetype" in enemy and enemy.archetype is GroundEnemyArchetype:
		return false
	if enemy.is_in_group("air_enemies"):
		return true
	if (enemy is AirEnemyController) or (enemy is HunterHelicopter) or (enemy is BossArchon):
		return true
	if "archetype" in enemy and enemy.archetype is AirEnemyArchetype:
		return true
	var n: String = enemy.name
	if n.begins_with("Air") or n.begins_with("Hunter") or n.begins_with("Boss"):
		return true
	return false

func _spawn_continuous_enemy(scene: PackedScene, player_pos: Vector3, altitude: float, forced_pos: Vector3 = Vector3.INF) -> Node3D:
	if not scene:
		return null
	var enemy: Node3D = scene.instantiate() as Node3D
	if not enemy:
		return null

	var spawn_pos: Vector3 = forced_pos
	var heading: Vector3 = Vector3.FORWARD
	var is_air: bool = _is_air_enemy(enemy)

	if spawn_pos == Vector3.INF:
		var spawn_data := get_dynamic_encounter_spawn_point(is_air, player_pos)
		spawn_pos = spawn_data["position"]
		heading = spawn_data["heading"]
		if is_air:
			altitude = clampf(spawn_pos.y, 11.0, 22.0)
		else:
			altitude = spawn_pos.y

	# Ground units must strictly stay on ground level (hit surface y)
	if not is_air:
		altitude = spawn_pos.y

	enemy.transform.origin = Vector3(spawn_pos.x, altitude, spawn_pos.z)

	# Orient mobile enemies toward movement heading
	if heading.length_squared() > 0.01:
		enemy.rotation.y = atan2(-heading.x, -heading.z)

	if elapsed_survival_time > 180.0 and randf() < clampf(0.12 + (elapsed_survival_time - 180.0) / 600.0 * 0.25, 0.12, 0.35):
		apply_elite_modifier(enemy)

	var parent := _get_spawn_parent()
	parent.add_child.call_deferred(enemy)
	_register_spawned_node(enemy)
	return enemy

func _register_spawned_node(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	if not _wave_enemies.has(enemy):
		_wave_enemies.append(enemy)
	total_enemies_spawned += 1

	var is_air := _is_air_enemy(enemy)
	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(enemy, is_air)

	enemy.tree_entered.connect(func() -> void:
		if is_instance_valid(enemy) and EnemyRegistry.instance:
			var air_check := _is_air_enemy(enemy)
			if air_check and not EnemyRegistry.instance.air_enemies.has(enemy):
				EnemyRegistry.instance.ground_enemies.erase(enemy)
				if not EnemyRegistry.instance.air_enemies.has(enemy):
					EnemyRegistry.instance.air_enemies.append(enemy)
				EnemyRegistry.instance._enemy_air_status[enemy] = true
			elif not air_check and not EnemyRegistry.instance.ground_enemies.has(enemy):
				EnemyRegistry.instance.air_enemies.erase(enemy)
				if not EnemyRegistry.instance.ground_enemies.has(enemy):
					EnemyRegistry.instance.ground_enemies.append(enemy)
				EnemyRegistry.instance._enemy_air_status[enemy] = false
	, CONNECT_ONE_SHOT)

	if not enemy.tree_exited.is_connected(_on_spawned_enemy_tree_exited):
		enemy.tree_exited.connect(_on_spawned_enemy_tree_exited.bind(enemy))

	if is_inside_tree() and get_tree():
		var wm := get_tree().get_first_node_in_group("wave_manager")
		if wm and wm.has_method("register_spawned_enemy"):
			wm.register_spawned_enemy(enemy)

func _on_spawned_enemy_tree_exited(enemy: Node3D) -> void:
	_wave_enemies.erase(enemy)
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(enemy)
	_notify_progress()

func get_active_unit_count(tag: String) -> int:
	var count: int = 0
	var group_name := tag
	match tag:
		"sam": group_name = "sam_sites"
		"mortar": group_name = "mortars"
		"gunship": group_name = "attack_gunships"
		"jammer": group_name = "jammers"
		"transport": group_name = "transports"
		"scout": group_name = "scouts"
		"raider": group_name = "rocket_raiders"
		"ace": group_name = "ace_gunships"
		"buggy": group_name = "buggies"
		"technical": group_name = "technicals"
		"ifv": group_name = "ifvs"
		"tank": group_name = "tanks"

	if is_inside_tree() and get_tree():
		for e in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				if "is_alive" in e and not e.is_alive:
					continue
				count += 1
		if count == 0 and group_name != tag:
			for e in get_tree().get_nodes_in_group(tag):
				if is_instance_valid(e) and not e.is_queued_for_deletion():
					if "is_alive" in e and not e.is_alive:
						continue
					count += 1
		return count

	for e in _wave_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "is_alive" in e and not e.is_alive:
				continue
			if e.is_in_group(group_name) or e.is_in_group(tag):
				count += 1
	return count

func get_active_air_count(tag: String) -> int:
	return get_active_unit_count(tag)

func _load_procedural_formations() -> void:
	procedural_formations.clear()
	var form_ids := [
		"light_patrol", "technical_raid", "air_patrol",
		"armored_patrol", "troop_insertion", "air_harassment",
		"armored_push", "fire_support", "sam_defense",
		"reinforcement_drop", "gunship_escort", "combined_arms"
	]
	for fid in form_ids:
		var path := "res://resources/formations/%s.tres" % fid
		if ResourceLoader.exists(path):
			var res := load(path) as FormationDefinition
			if res:
				procedural_formations.append(res)

func get_district_at_position(pos: Vector3) -> String:
	if pos.x < -20.0:
		return "Industrial" if pos.z < 20.0 else "Outskirts"
	elif pos.x > 20.0:
		return "Military" if pos.z < 20.0 else "Outskirts"
	else:
		return "CentralUrban"

func select_procedural_formation(p_pos: Vector3) -> FormationDefinition:
	if procedural_formations.is_empty():
		_load_procedural_formations()

	var player_district := get_district_at_position(p_pos)
	var candidates: Array[FormationDefinition] = []
	var weights: Array[float] = []

	for form in procedural_formations:
		# 1. Unlock time check
		if form.min_elapsed_time > elapsed_survival_time:
			continue

		# 2. Budget check
		if continuous_ground_budget < form.ground_budget_cost or continuous_air_budget < form.air_budget_cost:
			continue

		# 3. Tactical Caps check
		var cap_violated := false
		for cap_tag in form.required_caps.keys():
			var req_count: int = int(form.required_caps[cap_tag])
			var current_count := get_active_unit_count(cap_tag)
			var max_allowed: int = 99
			match cap_tag:
				"sam": max_allowed = cap_sam
				"mortar": max_allowed = cap_mortar
				"gunship": max_allowed = cap_gunship
				"jammer": max_allowed = cap_support
				"transport": max_allowed = cap_transport
				"scout": max_allowed = cap_scout
				"raider": max_allowed = cap_raider
			if current_count + req_count > max_allowed:
				cap_violated = true
				break
		if cap_violated:
			continue

		# 4. Variety Rules: Anti-repetition
		if formation_history.size() > 0 and formation_history[-1] == form.formation_id:
			continue

		var weight: float = 10.0
		if formation_history.size() >= 2 and formation_history[-2] == form.formation_id:
			weight *= 0.25
		elif formation_history.size() >= 3 and formation_history[-3] == form.formation_id:
			weight *= 0.5

		if formation_category_history.size() > 0 and formation_category_history[-1] == form.category:
			weight *= 0.35

		if form.preferred_districts.has(player_district):
			weight *= 1.75

		candidates.append(form)
		weights.append(weight)

	if candidates.is_empty():
		return null

	var total_weight: float = 0.0
	for w in weights:
		total_weight += w

	var roll := randf() * total_weight
	var accum := 0.0
	for i in range(candidates.size()):
		accum += weights[i]
		if roll <= accum:
			return candidates[i]

	return candidates[-1]

func spawn_procedural_formation(form: FormationDefinition, p_pos: Vector3, stagger: bool = true) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if not form:
		return spawned

	continuous_ground_budget -= form.ground_budget_cost
	continuous_air_budget -= form.air_budget_cost

	var g_spawn := get_authored_ground_spawn(form.formation_id, p_pos, 35.0)
	var a_spawn := get_air_corridor_entry(p_pos, 42.0, 72.0)

	var parent := _get_spawn_parent()

	for unit_spec in form.units:
		var scene_path: String = unit_spec.get("scene_path", "")
		if scene_path.is_empty():
			continue
		var scene := load(scene_path) as PackedScene
		if not scene:
			continue

		var count: int = int(unit_spec.get("count", 1))
		var is_air: bool = bool(unit_spec.get("is_air", false))
		var base_offset: Vector3 = unit_spec.get("offset", Vector3.ZERO)

		var base_pos: Vector3 = a_spawn["position"] if is_air else g_spawn["position"]
		var base_heading: Vector3 = a_spawn["heading"] if is_air else g_spawn["heading"]
		var dir := base_heading.normalized()
		var perp := Vector3(-dir.z, 0, dir.x)

		for i in range(count):
			var enemy := scene.instantiate() as Node3D
			if not enemy:
				continue

			var cap_tag: String = unit_spec.get("cap_tag", "")
			if not cap_tag.is_empty() and not enemy.is_in_group(cap_tag):
				enemy.add_to_group(cap_tag)
			if is_air and not enemy.is_in_group("air_enemies"):
				enemy.add_to_group("air_enemies")

			var side_mult: float = 1.0 if i % 2 == 0 else -1.0
			var stagger_dist := float(i) * 3.5
			var spawn_pos: Vector3
			if is_air:
				var p_y := clampf(_get_player_altitude(), 12.0, 18.0)
				spawn_pos = base_pos + (perp * (base_offset.x + float(i) * 5.0) * side_mult) - (dir * stagger_dist)
				spawn_pos.y = clampf(p_y + base_offset.y, 11.0, 22.0)
			else:
				spawn_pos = base_pos + (perp * (base_offset.x + float(i) * 2.5) * side_mult) - (dir * stagger_dist)
				spawn_pos.y = 0.0

			spawn_pos.x = clampf(spawn_pos.x, -arena_half_extents, arena_half_extents)
			spawn_pos.z = clampf(spawn_pos.z, -arena_half_extents, arena_half_extents)
			enemy.transform.origin = spawn_pos

			var is_first: bool = spawned.is_empty()
			_deploy_formation_unit(enemy, parent, is_first, stagger)
			spawned.append(enemy)

	_record_formation(form.formation_id)
	formation_category_history.append(form.category)
	if formation_category_history.size() > 6:
		formation_category_history.pop_front()
	last_formation_name = form.display_name
	return spawned

func can_spawn_formation(formation_id: String) -> bool:
	if formation_history.size() > 0 and formation_history[-1] == formation_id:
		return false
	if formation_history.size() >= 2 and formation_history[-2] == formation_id:
		return false
	return true

func _record_formation(formation_id: String) -> void:
	formation_history.append(formation_id)
	if formation_history.size() > 6:
		formation_history.pop_front()

func _get_spawn_parent() -> Node:
	if is_inside_tree() and get_tree():
		return get_tree().current_scene if get_tree().current_scene else get_tree().root
	return self

func _get_player() -> Node3D:
	if is_inside_tree() and get_tree():
		return get_tree().get_first_node_in_group("player") as Node3D
	return null

func _get_player_altitude() -> float:
	var player := _get_player()
	return player.global_position.y if player else 14.0

func _spend_budget(config: Dictionary) -> void:
	var g_budget: int = config["ground_budget"]
	var a_budget: int = config["air_budget"]
	var allowed: Array = config["enemies"]

	var player := _get_player()
	var p_pos: Vector3 = player.global_position if player else Vector3.ZERO

	# --- 1. Procedural Combined Arms Formations ---
	if (allowed.has("gunship") or allowed.has("raider")) and allowed.has("tank") and g_budget >= 45 and a_budget >= 25 and randf() > 0.45:
		var entry := get_air_corridor_entry(p_pos, 48.0, 75.0)
		spawn_combined_arms_formation(entry["position"], entry["heading"])
		g_budget -= 40
		a_budget -= 25

	# --- 2. Ground Tactical Formations ---
	if allowed.has("sam") and g_budget >= 80 and randf() > 0.4:
		var sam_pos := get_frustum_safe_spawn_pos(p_pos, 45.0, 72.0)
		spawn_sam_nest(sam_pos, false)
		g_budget -= 80

	if allowed.has("tank") and g_budget >= 60 and randf() > 0.35:
		var col_pos := get_frustum_safe_spawn_pos(p_pos, 45.0, 72.0)
		var approach := (p_pos - col_pos)
		approach.y = 0.0
		spawn_road_column(col_pos, approach.normalized(), 3)
		g_budget -= 60

	# --- 3. Remainder Ground Units ---
	while g_budget >= 15:
		if allowed.has("tank") and g_budget >= 30 and randf() > 0.5:
			_spawn_enemy(_scene_tank, p_pos, 0.0)
			g_budget -= 30
		elif allowed.has("sam") and g_budget >= 40 and randf() > 0.6:
			_spawn_enemy(_scene_sam, p_pos, 0.0)
			g_budget -= 40
		elif allowed.has("turret") and g_budget >= 20 and randf() > 0.5:
			_spawn_enemy(_scene_turret, p_pos, 0.0)
			g_budget -= 20
		elif allowed.has("infantry"):
			_spawn_enemy(_scene_infantry, p_pos, 0.0)
			g_budget -= 15
		else:
			break

	# --- 4. Remainder Air Units ---
	var p_y: float = _get_player_altitude()
	while a_budget >= 4:
		if allowed.has("gunship") and a_budget >= 9 and get_active_air_count("attack_gunships") < cap_gunship and randf() > 0.5:
			_spawn_enemy(_scene_air_gunship, p_pos, clampf(p_y, 13.0, 18.0))
			a_budget -= 9
		elif allowed.has("raider") and a_budget >= 6 and get_active_air_count("rocket_raiders") < cap_raider and randf() > 0.5:
			_spawn_enemy(_scene_air_raider, p_pos, clampf(p_y, 15.0, 21.0))
			a_budget -= 6
		elif allowed.has("scout") and a_budget >= 4 and get_active_air_count("scouts") < cap_scout:
			_spawn_enemy(_scene_air_scout, p_pos, clampf(p_y, 10.0, 15.0))
			a_budget -= 4
		elif allowed.has("hunter") and a_budget >= 30:
			_spawn_enemy(_scene_hunter, p_pos, p_y)
			a_budget -= 30
		else:
			break

func is_position_frustum_safe(pos: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if not cam:
		return true
	if cam.is_position_behind(pos):
		return true
	return not cam.is_position_in_frustum(pos)

## Validates that a spawn position is within arena, not inside buildings, and not directly on the player
func is_spawn_position_clear(pos: Vector3, is_air: bool = false) -> bool:
	var margin := 2.5 if is_air else 3.0
	if absf(pos.x) > (arena_half_extents - margin) or absf(pos.z) > (arena_half_extents - margin):
		return false

	var player := _get_player()
	if player:
		var flat_offset := Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z)
		var flat_dist := flat_offset.length()
		var min_safe_dist: float = 35.0 if not is_air else 38.0
		if flat_dist < min_safe_dist:
			return false

		# Reject directly in player's forward arc if close
		var p_fwd := -player.global_transform.basis.z
		var p_fwd_2d := Vector2(p_fwd.x, p_fwd.z).normalized()
		if p_fwd_2d.length_squared() > 0.1 and flat_offset.length_squared() > 0.1:
			if p_fwd_2d.dot(flat_offset.normalized()) > 0.82 and flat_dist < 38.0:
				return false

	# 3D physics collision check to avoid spawning inside buildings / roadblocks
	if is_inside_tree() and get_viewport() and get_viewport().find_world_3d():
		var space: PhysicsDirectSpaceState3D = get_viewport().find_world_3d().direct_space_state
		if space:
			var shape_query := PhysicsShapeQueryParameters3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 2.0 if not is_air else 3.2
			shape_query.shape = sphere
			shape_query.transform = Transform3D(Basis(), pos + Vector3(0, 1.2 if not is_air else 0.0, 0))
			shape_query.collision_mask = 1 # World geometry / Buildings
			var hits: Array[Dictionary] = space.intersect_shape(shape_query, 1)
			if not hits.is_empty():
				return false

	return true

func _get_next_spawn_sector() -> int:
	var candidates: Array[int] = []
	for i in range(8):
		if not _recent_spawn_sectors.has(i):
			candidates.append(i)
	if candidates.is_empty():
		_recent_spawn_sectors.clear()
		return randi() % 8
	return candidates.pick_random()

func _record_spawn_sector(sector: int) -> void:
	_recent_spawn_sectors.append(sector)
	if _recent_spawn_sectors.size() > 4:
		_recent_spawn_sectors.pop_front()

func _record_ground_source(source_name: String) -> void:
	_recent_ground_sources.append(source_name)
	if _recent_ground_sources.size() > 4:
		_recent_ground_sources.pop_front()

func _record_air_source(source_name: String) -> void:
	_recent_air_sources.append(source_name)
	if _recent_air_sources.size() > 4:
		_recent_air_sources.pop_front()

func _get_safe_perimeter_fallback(player_pos: Vector3) -> Vector3:
	var best_pt := Vector3(0.0, 0.0, 70.0)
	var best_dist := -1.0
	for pt in _safe_road_points:
		var d := player_pos.distance_to(pt)
		if d >= 28.0 and d <= 75.0:
			return pt
		elif d > best_dist:
			best_dist = d
			best_pt = pt
	return best_pt

func _get_sector_spawn_position(player_pos: Vector3, sector: int, min_dist: float, max_dist: float, is_air: bool) -> Vector3:
	var base_angle := float(sector) * (TAU / 8.0)
	for attempt in range(6):
		var angle := base_angle + randf_range(-PI / 6.0, PI / 6.0)
		var dist := randf_range(min_dist, max_dist)
		var cand := Vector3(
			clampf(player_pos.x + cos(angle) * dist, -arena_half_extents + 12.0, arena_half_extents - 12.0),
			0.0,
			clampf(player_pos.z + sin(angle) * dist, -arena_half_extents + 12.0, arena_half_extents - 12.0)
		)
		if is_spawn_position_clear(cand, is_air):
			_record_spawn_sector(sector)
			return cand

	return _get_safe_perimeter_fallback(player_pos)

## Selects an authored ground entrance (RoadEntrance_North, RoadEntrance_South, IndustrialEntrance, MilitaryGate)
## based on player distance (min safe >= 35m), district affinity, direction alternation, and clearance.
func get_authored_ground_spawn(enemy_tag: String = "infantry", player_pos: Vector3 = Vector3.ZERO, min_dist: float = 35.0) -> Dictionary:
	var nodes := get_ground_spawn_nodes()
	if nodes.is_empty():
		var fb_pos := get_frustum_safe_spawn_pos(player_pos, min_dist, 65.0)
		var fb_head := (player_pos - fb_pos)
		fb_head.y = 0.0
		return { "position": fb_pos, "heading": fb_head.normalized(), "source_name": "Fallback" }

	var scored_candidates: Array[Dictionary] = []
	for marker in nodes:
		var pos := marker.global_position
		var flat_dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		if flat_dist < min_dist:
			continue # Exclude entrances too close to player (safe distance >= 35m)

		var m_name := marker.name
		var score := 50.0

		# 1. District Affinity (Preferences)
		match m_name:
			"IndustrialEntrance":
				if enemy_tag in ["tank", "armored", "technicals", "road_column"]:
					score += 35.0
				elif enemy_tag in ["infantry"]:
					score += 10.0
			"MilitaryGate":
				if enemy_tag in ["sam", "turret", "tank", "armored"]:
					score += 40.0
				else:
					score += 15.0
			"RoadEntrance_North":
				if enemy_tag in ["infantry", "light_vehicle", "road_column"]:
					score += 35.0
				elif enemy_tag in ["tank"]:
					score += 20.0
			"RoadEntrance_South":
				if enemy_tag in ["road_column", "reinforcement", "infantry", "tank"]:
					score += 35.0
				else:
					score += 15.0

		# 2. Alternation / Recency penalty (avoid repeatedly spawning from same source)
		if _recent_ground_sources.size() > 0:
			if _recent_ground_sources[-1] == m_name:
				score -= 80.0
			if _recent_ground_sources.size() > 1 and _recent_ground_sources[-2] == m_name:
				score -= 40.0

		# 3. Distance weighting
		if flat_dist >= 35.0 and flat_dist <= 95.0:
			score += 15.0
		elif flat_dist > 120.0:
			score -= 10.0

		score += randf_range(0.0, 25.0)
		scored_candidates.append({ "marker": marker, "score": score, "dist": flat_dist })

	scored_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)

	# Validate clearance with entrance road perpendicular lateral spread (±6-15m)
	for cand in scored_candidates:
		var marker: Marker3D = cand["marker"]
		var base_pos: Vector3 = marker.global_position

		var to_center := -base_pos
		to_center.y = 0.0
		var fwd := to_center.normalized() if to_center.length_squared() > 0.1 else Vector3.FORWARD
		var perp := Vector3(-fwd.z, 0.0, fwd.x)

		for attempt in range(6):
			var side_dir: float = 1.0 if (attempt % 2 == 0) else -1.0
			var lateral_dist: float = randf_range(6.0, 15.0) if attempt < 4 else randf_range(2.0, 6.0)
			var depth_off: float = randf_range(-3.0, 6.0)
			var spawn_cand := base_pos + (perp * lateral_dist * side_dir) + (fwd * depth_off)
			spawn_cand.y = base_pos.y

			if is_spawn_position_clear(spawn_cand, false):
				_record_ground_source(marker.name)
				last_spawn_source = marker.name
				var heading := (player_pos - spawn_cand)
				heading.y = 0.0
				return {
					"position": spawn_cand,
					"heading": heading.normalized(),
					"source_name": marker.name
				}

	# Secondary pass on any valid node
	for marker in nodes:
		var pos: Vector3 = marker.global_position
		if is_spawn_position_clear(pos, false):
			_record_ground_source(marker.name)
			last_spawn_source = marker.name + " (Clearance Fallback)"
			var heading := (player_pos - pos)
			heading.y = 0.0
			return { "position": pos, "heading": heading.normalized(), "source_name": marker.name }

	# Fallback to safe road points
	failed_spawn_attempts += 1
	var safe_pt := _get_safe_perimeter_fallback(player_pos)
	var safe_hd := (player_pos - safe_pt)
	safe_hd.y = 0.0
	last_spawn_source = "Safe Road Point Fallback"
	return { "position": safe_pt, "heading": safe_hd.normalized(), "source_name": "SafeRoadFallback" }

func get_frustum_safe_spawn_pos(center_ref: Vector3, min_dist: float = 32.0, max_dist: float = 68.0) -> Vector3:
	var res := get_dynamic_encounter_spawn_point(false, center_ref, min_dist, max_dist)
	return res["position"]

## Selects an authored air entry (AirEntry_North, AirEntry_East, AirEntry_South, AirEntry_West)
## and returns inward flight heading toward player. Never spawns directly above the player.
func get_air_corridor_entry(player_pos: Vector3, min_dist: float = 38.0, max_dist: float = 85.0) -> Dictionary:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var a_nodes := get_air_spawn_nodes()

	if not a_nodes.is_empty():
		var scored_candidates: Array[Dictionary] = []
		for marker in a_nodes:
			var pos: Vector3 = marker.global_position
			var flat_dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
			if flat_dist < min_dist:
				continue # Must not spawn directly above the helicopter

			var score := 40.0
			var m_name := marker.name

			# Alternation: avoid repeatedly using the same entry
			if _recent_air_sources.size() > 0:
				if _recent_air_sources[-1] == m_name:
					score -= 80.0
				if _recent_air_sources.size() > 1 and _recent_air_sources[-2] == m_name:
					score -= 40.0

			# Frustum preference
			if cam and (cam.is_position_behind(pos) or not cam.is_position_in_frustum(pos)):
				score += 20.0

			score += randf_range(0.0, 25.0)
			scored_candidates.append({ "marker": marker, "score": score, "pos": pos })

		scored_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["score"]) > float(b["score"])
		)

		for cand in scored_candidates:
			var marker: Marker3D = cand["marker"]
			var base_pos: Vector3 = marker.global_position
			var to_player := (player_pos - base_pos)
			to_player.y = 0.0
			var dir := to_player.normalized() if to_player.length_squared() > 0.01 else Vector3.FORWARD
			var perp := Vector3(-dir.z, 0.0, dir.x)

			for attempt in range(6):
				var side_dir: float = 1.0 if (attempt % 2 == 0) else -1.0
				# Add lateral corridor spread (±8-20m) and varied altitude
				var lateral_dist: float = randf_range(8.0, 20.0) if attempt < 4 else randf_range(4.0, 8.0)
				var depth_off: float = randf_range(-4.0, 6.0)
				var alt_jitter: float = randf_range(-2.5, 4.0)
				var p_y := clampf(_get_player_altitude() + alt_jitter, 13.0, 24.0)

				var spawn_pos := base_pos + (perp * lateral_dist * side_dir) + (dir * depth_off)
				spawn_pos.y = p_y
				spawn_pos.x = clampf(spawn_pos.x, -arena_half_extents + 5.0, arena_half_extents - 5.0)
				spawn_pos.z = clampf(spawn_pos.z, -arena_half_extents + 5.0, arena_half_extents - 5.0)

				if is_spawn_position_clear(spawn_pos, true):
					_record_air_source(marker.name)
					last_spawn_source = marker.name
					return { "position": spawn_pos, "heading": dir, "source_name": marker.name }

	# Fallback perimeter corridors
	var perimeter_candidates: Array[Vector3] = [
		Vector3(0.0, 18.0, -arena_half_extents + 6.0), # North
		Vector3(0.0, 18.0, arena_half_extents - 6.0),  # South
		Vector3(arena_half_extents - 6.0, 18.0, 0.0),  # East
		Vector3(-arena_half_extents + 6.0, 18.0, 0.0), # West
	]
	perimeter_candidates.shuffle()
	for candidate in perimeter_candidates:
		var flat_dist := Vector2(candidate.x - player_pos.x, candidate.z - player_pos.z).length()
		if flat_dist >= min_dist and is_spawn_position_clear(candidate, true):
			var heading := (player_pos - candidate)
			heading.y = 0.0
			last_spawn_source = "Perimeter Air Fallback"
			return { "position": candidate, "heading": heading.normalized(), "source_name": "PerimeterAir" }

	failed_spawn_attempts += 1
	var fb_pos := get_frustum_safe_spawn_pos(player_pos, min_dist, max_dist)
	var fb_heading := (player_pos - fb_pos)
	fb_heading.y = 0.0
	fb_pos.y = clampf(_get_player_altitude(), 14.0, 22.0)
	last_spawn_source = "Ground Fallback Air"
	return { "position": fb_pos, "heading": fb_heading.normalized(), "source_name": "FallbackAir" }

## Spawns stationary defense threat (Turret, SAM) on an unoccupied authored Rooftop Marker3D.
## Enforces active rooftop cap (<= 3) and frees marker on enemy death / tree_exited.
func spawn_rooftop_threat(stage: int, player_pos: Vector3) -> Node3D:
	if get_active_rooftop_count() >= max_active_rooftop_threats:
		return null

	var r_nodes := get_rooftop_spawn_nodes()
	if r_nodes.is_empty():
		return null

	var free_markers: Array[Marker3D] = []
	for marker in r_nodes:
		var occ: Variant = _occupied_rooftop_markers.get(marker)
		if occ == null or not is_instance_valid(occ) or (occ as Node).is_queued_for_deletion():
			var dist := player_pos.distance_to(marker.global_position)
			if dist >= 22.0:
				free_markers.append(marker)

	if free_markers.is_empty():
		return null

	free_markers.shuffle()
	var chosen_marker: Marker3D = free_markers[0]

	# CommunicationsTower supports SAM in stage >= 3, otherwise GroundTurret
	var scene_to_spawn: PackedScene = _scene_turret
	if stage >= 3 and chosen_marker.name == "CommunicationsTower" and randf() > 0.35:
		scene_to_spawn = _scene_sam

	var enemy := scene_to_spawn.instantiate() as Node3D
	if not enemy:
		return null

	enemy.transform.origin = chosen_marker.global_position
	var to_player := (player_pos - chosen_marker.global_position)
	to_player.y = 0.0
	if to_player.length_squared() > 0.1:
		enemy.rotation.y = atan2(-to_player.x, -to_player.z)

	var parent := _get_spawn_parent()
	parent.add_child.call_deferred(enemy)
	_register_spawned_node(enemy)

	_occupied_rooftop_markers[chosen_marker] = enemy
	enemy.tree_exited.connect(func() -> void:
		if _occupied_rooftop_markers.get(chosen_marker) == enemy:
			_occupied_rooftop_markers.erase(chosen_marker)
	)

	last_spawn_source = "Rooftop_" + chosen_marker.name
	return enemy

func _process_pickup_spawning(delta: float) -> void:
	if not is_continuous_mode or not is_wave_active:
		return
	_pickup_spawn_timer -= delta
	if _pickup_spawn_timer <= 0.0:
		_pickup_spawn_timer = _pickup_spawn_interval + randf_range(-5.0, 7.0)
		_try_spawn_authored_pickup()

	_missile_pickup_timer -= delta
	if _missile_pickup_timer <= 0.0:
		_missile_pickup_timer = randf_range(_missile_pickup_interval_min, _missile_pickup_interval_max)
		spawn_authored_missile_pickup()

func spawn_authored_missile_pickup() -> Node3D:
	var active_pickups: Array[Node3D] = []
	for p in _active_missile_pickups:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			active_pickups.append(p)
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group("missile_pickups"):
			if p is Node3D and is_instance_valid(p) and not p.is_queued_for_deletion() and not active_pickups.has(p):
				active_pickups.append(p as Node3D)
	_active_missile_pickups = active_pickups

	if _active_missile_pickups.size() >= max_active_missile_pickups:
		return null # Maximum 1-2 active missile crates simultaneously

	var markers := get_pickup_spawn_nodes()
	if markers.is_empty():
		return null

	var free_markers: Array[Marker3D] = []
	for marker in markers:
		var m_pos := marker.global_position if marker.is_inside_tree() else marker.position
		var has_pickup_nearby := false
		for p in _active_missile_pickups + _active_authored_pickups:
			if is_instance_valid(p):
				var p_pos := p.global_position if p.is_inside_tree() else p.position
				if m_pos.distance_to(p_pos) < 6.0:
					has_pickup_nearby = true
					break
		if not has_pickup_nearby:
			free_markers.append(marker)

	if free_markers.is_empty():
		return null

	var chosen: Marker3D = free_markers.pick_random()
	if not _scene_missile_pickup:
		_scene_missile_pickup = load("res://scenes/pickups/missile_ammo_pickup.tscn") as PackedScene
	if not _scene_missile_pickup:
		return null

	var pickup := _scene_missile_pickup.instantiate() as Node3D
	if not pickup:
		return null

	pickup.transform.origin = chosen.global_position if chosen.is_inside_tree() else chosen.position
	var parent := _get_spawn_parent()
	parent.add_child.call_deferred(pickup)

	_active_missile_pickups.append(pickup)
	pickup.tree_exited.connect(func() -> void:
		_active_missile_pickups.erase(pickup)
	)

	return pickup

func clear_missile_pickups() -> void:
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group("missile_pickups"):
			if is_instance_valid(p) and not p.is_queued_for_deletion():
				p.queue_free()
	_active_missile_pickups.clear()

func _try_spawn_authored_pickup() -> Node3D:
	var active_pickups: Array[Node3D] = []
	for p in _active_authored_pickups:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			active_pickups.append(p)
	_active_authored_pickups = active_pickups

	if _active_authored_pickups.size() >= 2:
		return null # Maximum 2 active authored pickups simultaneously

	var markers := get_pickup_spawn_nodes()
	if markers.is_empty():
		return null

	var free_markers: Array[Marker3D] = []
	for marker in markers:
		var has_pickup_nearby := false
		for p in _active_authored_pickups:
			if marker.global_position.distance_to(p.global_position) < 8.0:
				has_pickup_nearby = true
				break
		if not has_pickup_nearby and is_spawn_position_clear(marker.global_position, false):
			free_markers.append(marker)

	if free_markers.is_empty():
		return null

	var chosen: Marker3D = free_markers.pick_random()
	if not _scene_crate:
		_scene_crate = load("res://scenes/pickups/salvage_crate.tscn") as PackedScene
	if not _scene_crate:
		return null

	var crate := _scene_crate.instantiate() as Node3D
	if not crate:
		return null

	crate.transform.origin = chosen.global_position
	var parent := _get_spawn_parent()
	parent.add_child.call_deferred(crate)

	_active_authored_pickups.append(crate)
	crate.tree_exited.connect(func() -> void:
		_active_authored_pickups.erase(crate)
	)

	return crate

# --- FORMATION SPAWNING IMPLEMENTATIONS ---

func spawn_air_patrol(spawn_origin: Vector3, heading: Vector3, stagger: bool = true) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if get_active_air_count("scouts") + 2 > cap_scout:
		return spawned

	var parent := _get_spawn_parent()
	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var alt := clampf(_get_player_altitude(), 10.0, 15.0)

	var s1 := _scene_air_scout.instantiate() as Node3D
	if s1:
		s1.add_to_group("scouts")
		s1.add_to_group("air_enemies")
		s1.add_to_group("enemies")
		s1.transform.origin = Vector3(spawn_origin.x, alt, spawn_origin.z)
		_deploy_formation_unit(s1, parent, true, stagger)
		spawned.append(s1)

	var s2 := _scene_air_scout.instantiate() as Node3D
	if s2:
		s2.add_to_group("scouts")
		s2.add_to_group("air_enemies")
		s2.add_to_group("enemies")
		var pos2 := spawn_origin + (perp * 10.0) - (dir * 9.0)
		s2.transform.origin = Vector3(
			clampf(pos2.x, -arena_half_extents, arena_half_extents),
			alt + 1.0,
			clampf(pos2.z, -arena_half_extents, arena_half_extents)
		)
		_deploy_formation_unit(s2, parent, false, stagger)
		spawned.append(s2)

	_record_formation("air_patrol")
	return spawned

func spawn_harassment_group(spawn_origin: Vector3, heading: Vector3, stagger: bool = true) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if get_active_air_count("rocket_raiders") + 1 > cap_raider or get_active_air_count("scouts") + 2 > cap_scout:
		return spawned

	var parent := _get_spawn_parent()
	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var p_y: float = _get_player_altitude()

	var raider := _scene_air_raider.instantiate() as Node3D
	if raider:
		raider.add_to_group("rocket_raiders")
		raider.add_to_group("air_enemies")
		raider.add_to_group("enemies")
		raider.transform.origin = Vector3(spawn_origin.x, clampf(p_y, 15.0, 21.0), spawn_origin.z)
		_deploy_formation_unit(raider, parent, true, stagger)
		spawned.append(raider)

	var offsets: Array[Vector3] = [
		-perp * 12.0 - dir * 10.0,
		perp * 12.0 - dir * 10.0
	]
	for off in offsets:
		var scout := _scene_air_scout.instantiate() as Node3D
		if scout:
			scout.add_to_group("scouts")
			scout.add_to_group("air_enemies")
			scout.add_to_group("enemies")
			var spos := spawn_origin + off
			scout.transform.origin = Vector3(
				clampf(spos.x, -arena_half_extents, arena_half_extents),
				clampf(p_y, 11.0, 15.0),
				clampf(spos.z, -arena_half_extents, arena_half_extents)
			)
			_deploy_formation_unit(scout, parent, false, stagger)
			spawned.append(scout)

	_record_formation("harassment_group")
	return spawned

func spawn_reinforcement_drop(spawn_origin: Vector3, heading: Vector3, with_escort: bool = true) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if get_active_air_count("transports") + 1 > cap_transport:
		return spawned

	var parent := _get_spawn_parent()
	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var perp := Vector3(-dir.z, 0.0, dir.x)

	var player := _get_player()
	var p_pos: Vector3 = player.global_position if player else Vector3.ZERO
	var lz_pos := spawn_origin.lerp(p_pos, 0.6)
	lz_pos.x = clampf(lz_pos.x, -arena_half_extents + 20.0, arena_half_extents - 20.0)
	lz_pos.z = clampf(lz_pos.z, -arena_half_extents + 20.0, arena_half_extents - 20.0)
	lz_pos.y = 0.0

	var transport := _scene_air_transport.instantiate() as Node3D
	if transport:
		transport.add_to_group("transports")
		transport.add_to_group("air_enemies")
		transport.add_to_group("enemies")
		transport.transform.origin = Vector3(spawn_origin.x, 14.0, spawn_origin.z)
		transport.set("drop_target_position", lz_pos)
		parent.add_child.call_deferred(transport)
		_register_spawned_node(transport)
		spawned.append(transport)

	if with_escort and get_active_air_count("scouts") + 1 <= cap_scout:
		var scout := _scene_air_scout.instantiate() as Node3D
		if scout:
			scout.add_to_group("scouts")
			scout.add_to_group("air_enemies")
			scout.add_to_group("enemies")
			var spos := spawn_origin + perp * 12.0 - dir * 8.0
			scout.transform.origin = Vector3(
				clampf(spos.x, -arena_half_extents, arena_half_extents),
				15.0,
				clampf(spos.z, -arena_half_extents, arena_half_extents)
			)
			parent.add_child.call_deferred(scout)
			_register_spawned_node(scout)
			spawned.append(scout)

	_record_formation("reinforcement_drop")
	return spawned

func spawn_air_intercept(spawn_origin: Vector3, heading: Vector3, scout_count: int = 1) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if get_active_air_count("attack_gunships") + 1 > cap_gunship:
		return spawned

	var parent := _get_spawn_parent()
	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var p_y: float = _get_player_altitude()

	var gunship := _scene_air_gunship.instantiate() as Node3D
	if gunship:
		gunship.add_to_group("attack_gunships")
		gunship.add_to_group("air_enemies")
		gunship.add_to_group("enemies")
		gunship.transform.origin = Vector3(spawn_origin.x, clampf(p_y, 13.0, 18.0), spawn_origin.z)
		parent.add_child.call_deferred(gunship)
		_register_spawned_node(gunship)
		spawned.append(gunship)

	var count: int = mini(scout_count, cap_scout - get_active_air_count("scouts"))
	for i in range(count):
		var scout := _scene_air_scout.instantiate() as Node3D
		if scout:
			scout.add_to_group("scouts")
			scout.add_to_group("air_enemies")
			scout.add_to_group("enemies")
			var side_mult: float = 1.0 if i % 2 == 0 else -1.0
			var spos := spawn_origin + (perp * 12.0 * side_mult) - (dir * 10.0)
			scout.transform.origin = Vector3(
				clampf(spos.x, -arena_half_extents, arena_half_extents),
				clampf(p_y, 11.0, 15.0),
				clampf(spos.z, -arena_half_extents, arena_half_extents)
			)
			parent.add_child.call_deferred(scout)
			_register_spawned_node(scout)
			spawned.append(scout)

	_record_formation("air_intercept")
	return spawned

func spawn_electronic_strike_group(spawn_origin: Vector3, heading: Vector3, with_scout: bool = false) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if get_active_air_count("jammers") + 1 > cap_jammer or get_active_air_count("attack_gunships") + 1 > cap_gunship:
		return spawned

	var parent := _get_spawn_parent()
	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var p_y: float = _get_player_altitude()

	var gunship := _scene_air_gunship.instantiate() as Node3D
	if gunship:
		gunship.add_to_group("attack_gunships")
		gunship.add_to_group("air_enemies")
		gunship.add_to_group("enemies")
		gunship.transform.origin = Vector3(spawn_origin.x, clampf(p_y, 13.0, 17.0), spawn_origin.z)
		parent.add_child.call_deferred(gunship)
		_register_spawned_node(gunship)
		spawned.append(gunship)

	var jammer := _scene_air_jammer.instantiate() as Node3D
	if jammer:
		jammer.add_to_group("jammers")
		jammer.add_to_group("air_enemies")
		jammer.add_to_group("enemies")
		var jpos := spawn_origin - (dir * 16.0) + (perp * 8.0)
		jammer.transform.origin = Vector3(
			clampf(jpos.x, -arena_half_extents, arena_half_extents),
			clampf(p_y + 4.0, 19.0, 24.0),
			clampf(jpos.z, -arena_half_extents, arena_half_extents)
		)
		parent.add_child.call_deferred(jammer)
		_register_spawned_node(jammer)
		spawned.append(jammer)

	if with_scout and get_active_air_count("scouts") + 1 <= cap_scout:
		var scout := _scene_air_scout.instantiate() as Node3D
		if scout:
			scout.add_to_group("scouts")
			scout.add_to_group("air_enemies")
			scout.add_to_group("enemies")
			var spos := spawn_origin - (dir * 14.0) - (perp * 8.0)
			scout.transform.origin = Vector3(
				clampf(spos.x, -arena_half_extents, arena_half_extents),
				clampf(p_y, 11.0, 15.0),
				clampf(spos.z, -arena_half_extents, arena_half_extents)
			)
			parent.add_child.call_deferred(scout)
			_register_spawned_node(scout)
			spawned.append(scout)

	_record_formation("electronic_strike")
	return spawned

func spawn_elite_air_encounter(spawn_origin: Vector3, heading: Vector3) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if get_active_air_count("ace_gunships") + 1 > cap_ace:
		return spawned

	var parent := _get_spawn_parent()
	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var p_y: float = _get_player_altitude()

	var ace := _scene_air_ace.instantiate() as Node3D
	if ace:
		ace.add_to_group("ace_gunships")
		ace.add_to_group("elites")
		ace.add_to_group("air_enemies")
		ace.add_to_group("enemies")
		ace.transform.origin = Vector3(spawn_origin.x, clampf(p_y, 14.0, 19.0), spawn_origin.z)
		parent.add_child.call_deferred(ace)
		_register_spawned_node(ace)
		spawned.append(ace)

	var offsets: Array[Vector3] = [
		-perp * 14.0 - dir * 12.0,
		perp * 14.0 - dir * 12.0
	]
	for off in offsets:
		if get_active_air_count("scouts") + 1 <= cap_scout:
			var scout := _scene_air_scout.instantiate() as Node3D
			if scout:
				scout.add_to_group("scouts")
				scout.add_to_group("air_enemies")
				scout.add_to_group("enemies")
				var spos := spawn_origin + off
				scout.transform.origin = Vector3(
					clampf(spos.x, -arena_half_extents, arena_half_extents),
					clampf(p_y, 11.0, 15.0),
					clampf(spos.z, -arena_half_extents, arena_half_extents)
				)
				parent.add_child.call_deferred(scout)
				_register_spawned_node(scout)
				spawned.append(scout)

	_record_formation("elite_encounter")
	return spawned

func spawn_combined_arms_formation(spawn_origin: Vector3, heading: Vector3) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	var parent := _get_spawn_parent()
	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD

	var p_y: float = _get_player_altitude()
	if get_active_air_count("attack_gunships") + 1 <= cap_gunship:
		var gunship := _scene_air_gunship.instantiate() as Node3D
		if gunship:
			gunship.add_to_group("attack_gunships")
			gunship.add_to_group("air_enemies")
			gunship.add_to_group("enemies")
			gunship.transform.origin = Vector3(spawn_origin.x, clampf(p_y, 13.0, 18.0), spawn_origin.z)
			parent.add_child.call_deferred(gunship)
			_register_spawned_node(gunship)
			spawned.append(gunship)
	elif get_active_air_count("rocket_raiders") + 1 <= cap_raider:
		var raider := _scene_air_raider.instantiate() as Node3D
		if raider:
			raider.add_to_group("rocket_raiders")
			raider.add_to_group("air_enemies")
			raider.add_to_group("enemies")
			raider.transform.origin = Vector3(spawn_origin.x, clampf(p_y, 15.0, 20.0), spawn_origin.z)
			parent.add_child.call_deferred(raider)
			_register_spawned_node(raider)
			spawned.append(raider)

	var g_pos := Vector3(spawn_origin.x, 0.0, spawn_origin.z) + dir * 18.0
	g_pos.x = clampf(g_pos.x, -arena_half_extents, arena_half_extents)
	g_pos.z = clampf(g_pos.z, -arena_half_extents, arena_half_extents)

	var tank := _scene_tank.instantiate() as Node3D
	if tank:
		tank.transform.origin = g_pos
		parent.add_child.call_deferred(tank)
		_register_spawned_node(tank)
		spawned.append(tank)

	var sam := _scene_sam.instantiate() as Node3D
	if sam:
		var sam_pos := g_pos - dir * 12.0
		sam.transform.origin = Vector3(
			clampf(sam_pos.x, -arena_half_extents, arena_half_extents),
			0.0,
			clampf(sam_pos.z, -arena_half_extents, arena_half_extents)
		)
		parent.add_child.call_deferred(sam)
		_register_spawned_node(sam)
		spawned.append(sam)

	_record_formation("combined_arms")
	return spawned

func spawn_road_column(spawn_origin: Vector3, approach_direction: Vector3, count: int = 3, stagger: bool = true) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	var parent := _get_spawn_parent()
	var dir := approach_direction.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD

	var lead_tank: Tank = null

	for i in range(count):
		var offset_dist: float = float(i) * 14.0
		var pos := spawn_origin - dir * offset_dist
		pos.x = clampf(pos.x, -arena_half_extents, arena_half_extents)
		pos.z = clampf(pos.z, -arena_half_extents, arena_half_extents)

		var tank := _scene_tank.instantiate() as Tank
		if tank:
			tank.transform.origin = Vector3(pos.x, 0.0, pos.z)
			if i == 0:
				tank.is_command_unit = true
				lead_tank = tank
			else:
				if lead_tank:
					lead_tank.register_escort(tank)
			_deploy_formation_unit(tank, parent, i == 0, stagger)
			spawned.append(tank)

	return spawned

func spawn_sam_nest(center_pos: Vector3, with_radar: bool = false) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	var parent := _get_spawn_parent()

	var sam_offsets: Array[Vector3] = [
		Vector3(-16.0, 0.0, 0.0),
		Vector3(16.0, 0.0, 0.0)
	]

	for off in sam_offsets:
		var s := _scene_sam.instantiate() as Node3D
		if s:
			s.transform.origin = Vector3(
				clampf(center_pos.x + off.x, -arena_half_extents, arena_half_extents),
				0.0,
				clampf(center_pos.z + off.z, -arena_half_extents, arena_half_extents)
			)
			parent.add_child.call_deferred(s)
			_register_spawned_node(s)
			spawned.append(s)

	var support_pos := Vector3(
		clampf(center_pos.x, -arena_half_extents, arena_half_extents),
		0.0,
		clampf(center_pos.z - 14.0, -arena_half_extents, arena_half_extents)
	)
	var support_scene := _scene_radar if with_radar else _scene_turret
	var support := support_scene.instantiate() as Node3D
	if support:
		support.transform.origin = support_pos
		parent.add_child.call_deferred(support)
		_register_spawned_node(support)
		spawned.append(support)

	return spawned

func spawn_two_direction_pincer(center_target: Vector3, distance: float = 65.0) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	var parent := _get_spawn_parent()

	var angle_a := randf() * TAU
	var angle_b := wrapf(angle_a + PI, 0.0, TAU)

	var g_pos := Vector3(
		clampf(center_target.x + cos(angle_a) * distance, -arena_half_extents, arena_half_extents),
		0.0,
		clampf(center_target.z + sin(angle_a) * distance, -arena_half_extents, arena_half_extents)
	)
	var tank := _scene_tank.instantiate() as Node3D
	if tank:
		tank.transform.origin = g_pos
		parent.add_child.call_deferred(tank)
		_register_spawned_node(tank)
		spawned.append(tank)

	var player := _get_player()
	var p_y := player.global_position.y if player else 14.0
	var a_pos := Vector3(
		clampf(center_target.x + cos(angle_b) * distance, -arena_half_extents, arena_half_extents),
		p_y,
		clampf(center_target.z + sin(angle_b) * distance, -arena_half_extents, arena_half_extents)
	)
	var hunter := _scene_hunter.instantiate() as Node3D
	if hunter:
		hunter.transform.origin = a_pos
		parent.add_child.call_deferred(hunter)
		_register_spawned_node(hunter)
		spawned.append(hunter)

	return spawned

func spawn_interceptor_pair(spawn_pos: Vector3, heading: Vector3) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	var parent := _get_spawn_parent()

	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD

	var perp := Vector3(-dir.z, 0.0, dir.x)

	var lead := _scene_hunter.instantiate() as Node3D
	if lead:
		lead.transform.origin = spawn_pos
		parent.add_child.call_deferred(lead)
		_register_spawned_node(lead)
		spawned.append(lead)

	var wingman := _scene_hunter.instantiate() as Node3D
	if wingman:
		var wing_pos := spawn_pos + (perp * 14.0) - (dir * 12.0)
		wing_pos.x = clampf(wing_pos.x, -arena_half_extents, arena_half_extents)
		wing_pos.z = clampf(wing_pos.z, -arena_half_extents, arena_half_extents)
		wingman.transform.origin = wing_pos
		parent.add_child.call_deferred(wingman)
		_register_spawned_node(wingman)
		spawned.append(wingman)

	return spawned

func _spawn_enemy(scene: PackedScene, player_pos: Vector3, altitude: float) -> void:
	if not scene:
		return
	var enemy: Node3D = scene.instantiate() as Node3D
	if not enemy:
		return

	var spawn_pos := get_frustum_safe_spawn_pos(player_pos, 32.0, 68.0)
	enemy.transform.origin = Vector3(spawn_pos.x, altitude, spawn_pos.z)
	var parent := _get_spawn_parent()
	parent.add_child.call_deferred(enemy)
	_register_spawned_node(enemy)

func _spawn_radar_objective() -> void:
	var radar: Node3D = _scene_radar.instantiate() as Node3D
	if radar:
		var spawn_pos := Vector3(-95.0, 0.5, -37.0)
		if objective_locations_node:
			var radar_marker := objective_locations_node.get_node_or_null("RadarObjective") as Marker3D
			if radar_marker:
				spawn_pos = radar_marker.global_position
		radar.transform.origin = spawn_pos
		var parent := _get_spawn_parent()
		parent.add_child.call_deferred(radar)
		_register_spawned_node(radar)

func _spawn_archon_boss() -> void:
	var boss: Node3D = _scene_archon.instantiate() as Node3D
	if boss:
		var player := _get_player()
		var p_y := player.global_position.y if player else 14.0
		boss.transform.origin = Vector3(0.0, p_y, -70.0)
		var parent := _get_spawn_parent()
		parent.add_child.call_deferred(boss)
		_register_spawned_node(boss)

func _on_enemy_destroyed(enemy: Node3D, _points: int) -> void:
	_wave_enemies.erase(enemy)
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(enemy)
	total_enemies_killed += 1
	_notify_progress()

	if not is_continuous_mode and is_wave_active and _wave_enemies.size() == 0:
		_complete_wave()

func _notify_progress() -> void:
	if EventBus:
		var living := get_living_enemy_count()
		EventBus.wave_progress_updated.emit(living, maxi(living, _total_wave_enemies))

func _complete_wave() -> void:
	is_wave_active = false
	if EventBus:
		EventBus.wave_completed.emit(current_wave)

	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage"):
		var mult: float = 2.0 if current_wave > 10 else 1.0
		gm.add_salvage(int(current_wave * 40 * mult))

	if current_wave == 10:
		pass
	elif current_wave > 10:
		_recovery_timer = recovery_pause_duration
		if EventBus:
			EventBus.extraction_decision_requested.emit(gm.run_salvage if gm else 0)
	else:
		_recovery_timer = recovery_pause_duration
