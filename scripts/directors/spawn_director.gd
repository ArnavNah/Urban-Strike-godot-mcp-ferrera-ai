class_name SpawnDirector
extends Node3D

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
@export var difficulty_profile: Resource = null

const DifficultyProfileClass = preload("res://scripts/resources/difficulty_profile.gd")
const WavePopulationTargetClass = preload("res://scripts/resources/wave_population_target.gd")

var primary_entry_sector: int = 0
var secondary_entry_sector: int = 1
var protected_escape_sectors: Array[int] = [3, 4, 5]
var rejected_spawn_reasons: Dictionary = {
	"frustum": 0,
	"safety_margin": 0,
	"standoff_distance": 0,
	"boundary": 0,
	"building": 0,
	"rooftop_occupied": 0,
	"escape_arc_violation": 0,
	"opposing_sector": 0
}

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

## Centralized minimum separation radii by enemy category / archetype tag
const SEPARATION_RADII: Dictionary = {
	"infantry": 8.0,
	"buggy": 10.0,
	"technical": 10.0,
	"tank": 12.0,
	"apc": 12.0,
	"ifv": 12.0,
	"turret": 10.0,
	"sam": 10.0,
	"mortar": 10.0,
	"ground_default": 10.0,
	"air_default": 16.0
}

## Centralized spawn reservation registry
var _active_reservations: Array[Dictionary] = []
var _reservation_id_seq: int = 0
var _source_cooldowns: Dictionary = {}
var _recent_spawn_history: Array[Dictionary] = []

## Staggered initial encounter deployment
var _initial_encounter_queue: Array[Dictionary] = []
var _initial_encounter_timer: float = 0.0
var _initial_encounter_retries_remaining: int = 0
var _initial_retry_timer: float = 0.0
var _initial_encounter_spawned: bool = false

## Deficit batch reinforcement delay queue
var _pending_deficit_spawns: Array[Dictionary] = []

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

func _init() -> void:
	if not _scene_infantry:
		_scene_infantry = load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	if not _scene_turret:
		_scene_turret = load("res://scenes/enemies/ground_turret.tscn") as PackedScene
	if not _scene_tank:
		_scene_tank = load("res://scenes/enemies/tank.tscn") as PackedScene
	if not _scene_sam:
		_scene_sam = load("res://scenes/enemies/sam_site.tscn") as PackedScene
	if not _scene_hunter:
		_scene_hunter = load("res://scenes/enemies/hunter_helicopter.tscn") as PackedScene
	if not _scene_radar:
		_scene_radar = load("res://scenes/objects/radar_station.tscn") as PackedScene
	if not _scene_archon:
		_scene_archon = load("res://scenes/enemies/boss_archon.tscn") as PackedScene

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

	if not difficulty_profile:
		if is_inside_tree() and get_tree().current_scene and get_tree().current_scene.name == "Battlefield":
			if ResourceLoader.exists("res://resources/directors/profiles/low_pressure_survivors.tres"):
				difficulty_profile = load("res://resources/directors/profiles/low_pressure_survivors.tres")
			else:
				difficulty_profile = DifficultyProfileClass.create_low_pressure_survivors_profile()

	if difficulty_profile != null:
		rotate_directional_sectors()
	else:
		_rotate_active_sectors()

func get_current_wave_target() -> Resource:
	if difficulty_profile and difficulty_profile.has_method("get_wave_target"):
		return difficulty_profile.get_wave_target(current_wave)
	return null

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
	if difficulty_profile:
		var target: Resource = get_current_wave_target()
		var min_int: float = float(target.get("spawn_interval_min")) if target else (1.4 if current_wave <= 3 else (1.1 if current_wave <= 7 else 0.9))
		var max_int: float = float(target.get("spawn_interval_max")) if target else (2.4 if current_wave <= 3 else (2.0 if current_wave <= 7 else 1.7))
		base_int = randf_range(min_int, max_int)
		if is_behind_target:
			# Maximum 30% interval reduction when behind target (no instant deficit dumping)
			base_int *= 0.70

		match encounter_state:
			EncounterState.SURGE:
				var pressure_bonus: float = float(difficulty_profile.get("surge_pressure_bonus"))
				var s_mult := maxf(1.0, 1.0 + pressure_bonus)
				return maxf(0.15, base_int / s_mult)
			EncounterState.RECOVERY:
				var r_mult := maxf(0.05, float(difficulty_profile.get("recovery_spawn_mult")))
				return maxf(0.15, base_int / r_mult)
			_:
				return maxf(0.15, base_int)

	# Legacy fallback for test 29 / vanilla EncounterConfig
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
	var p_band := get_population_band()

	# Population band hysteresis:
	# If at or above cap, back off until population drops below cap - 2
	if current_living >= cap:
		if stream_timer:
			stream_timer.wait_time = randf_range(2.0, 3.5)
		return

	var player := _get_player()
	var p_pos := player.global_position if player else Vector3.ZERO
	var is_behind_target := current_living < target_count

	# Spawn continuous stream
	_spawn_continuous_stream(stage, p_pos)

	# Population debt recovery: when below minimum band, queue delayed deficit reinforcement
	if current_living + 1 < p_band.x:
		_queue_deficit_reinforcement(stage, p_pos, randf_range(0.45, 0.75))

	if stream_timer:
		var next_interval: float
		if current_living < p_band.x:
			# Fast pacing (1.0 - 1.5s) to recover population debt quickly
			next_interval = randf_range(1.0, 1.5)
		else:
			next_interval = _get_next_stream_interval(stage, is_behind_target)
		stream_timer.wait_time = maxf(0.15, next_interval)

func _queue_deficit_reinforcement(stage: int, p_pos: Vector3, delay: float) -> void:
	_pending_deficit_spawns.append({
		"stage": stage,
		"p_pos": p_pos,
		"delay": delay
	})

func _process_deficit_spawns(delta: float) -> void:
	for i in range(_pending_deficit_spawns.size() - 1, -1, -1):
		_pending_deficit_spawns[i]["delay"] -= delta
		if _pending_deficit_spawns[i]["delay"] <= 0.0:
			var stage: int = _pending_deficit_spawns[i]["stage"]
			var p_pos: Vector3 = _pending_deficit_spawns[i]["p_pos"]
			_pending_deficit_spawns.remove_at(i)
			_spawn_continuous_stream(stage, p_pos)

func _on_formation_timer_timeout() -> void:
	if not is_wave_active or not is_continuous_mode:
		return
	var stage := get_survival_stage()
	var cap := get_active_population_cap()
	var current_living := get_living_enemy_count()
	var target_count := get_target_active_count()
	var p_band := get_population_band()

	# Formations have 3-4 units. Check if adding formation exceeds cap
	if current_living + 3 <= cap:
		var player := _get_player()
		var p_pos := player.global_position if player else Vector3.ZERO
		var is_behind_target := current_living < target_count
		if try_spawn_formation_with_fallback(stage, p_pos):
			if formation_timer:
				formation_timer.wait_time = randf_range(4.0, 7.0) if current_living < p_band.x else (randf_range(6.0, 10.0) if is_behind_target else randf_range(9.0, 15.0))
			return

	if formation_timer:
		formation_timer.wait_time = randf_range(3.0, 6.0)

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
	if is_inside_tree() and get_tree().paused:
		return

	if not is_wave_active and not is_continuous_mode and _recovery_timer > 0.0:
		_recovery_timer -= delta
		if _recovery_timer <= 0.0:
			start_wave(current_wave + 1)
		return

	if not is_wave_active:
		return

	clean_expired_reservations()
	_process_initial_encounter_queue(delta)
	_process_deficit_spawns(delta)
	if _initial_encounter_retries_remaining > 0:
		_initial_retry_timer -= delta
		if _initial_retry_timer <= 0.0:
			_retry_missing_initial_encounter()

	# Process staggered arrivals for active formations (0.25 - 0.55s between units)
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
		var res_id: String = str(item.get("res_id", ""))
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			if not unit.is_inside_tree() and is_instance_valid(parent):
				parent.add_child.call_deferred(unit)
				_register_spawned_node(unit)
				if not res_id.is_empty():
					bind_enemy_to_reservation(res_id, unit)
		_formation_stagger_timer = randf_range(0.25, 0.55)

func _deploy_formation_unit(unit: Node3D, parent: Node, is_first: bool, stagger: bool = true, res_id: String = "") -> void:
	if not is_instance_valid(unit) or not is_instance_valid(parent):
		if not res_id.is_empty():
			release_reservation(res_id)
		return
	if not unit.transform.is_finite():
		if not res_id.is_empty():
			release_reservation(res_id)
		unit.queue_free()
		return
	if is_first or not stagger:
		parent.add_child.call_deferred(unit)
		_register_spawned_node(unit)
		if not res_id.is_empty():
			bind_enemy_to_reservation(res_id, unit)
	else:
		_formation_spawn_queue.append({
			"unit": unit,
			"parent": parent,
			"res_id": res_id
		})

func clear_formation_queue() -> void:
	for item in _formation_spawn_queue:
		var u: Node3D = item.get("unit", null) as Node3D
		if is_instance_valid(u) and not u.is_inside_tree():
			u.queue_free()
		var res_id: String = str(item.get("res_id", ""))
		if not res_id.is_empty():
			release_reservation(res_id)
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
		CombatDirector.instance.set_wave(wave_num)

	if EventBus:
		if is_continuous_mode:
			if wave_num == 1:
				EventBus.wave_started.emit(1, "STAGE 1")
			else:
				EventBus.wave_started.emit(wave_num, "STAGE %d" % wave_num)
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

		if wave_num == 1 and not _initial_encounter_spawned:
			_initial_encounter_spawned = true
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

## Guaranteed playable initial encounter on run start using authored ground entrances and primary/adjacent sectors.
## Chooses and reserves all 3 valid positions upfront, requiring >=18m separation between units,
## at least 2 distinct road sources or sectors, offscreen camera view, and 0.7 - 1.1s arrival staggering.
func _spawn_initial_encounter(player_pos: Vector3) -> void:
	var planned := _plan_initial_encounter_positions(player_pos)
	if planned.is_empty():
		_initial_encounter_retries_remaining = 3
		_initial_retry_timer = 0.5
		return

	# Deploy unit 0 immediately
	var u0: Dictionary = planned[0]
	_deploy_staggered_enemy(u0["scene"], u0["position"], u0["heading"], u0["source_key"], u0["sector"], u0["res_id"])

	# Queue remaining units to arrive 0.75 - 1.05s apart
	for i in range(1, planned.size()):
		_initial_encounter_queue.append(planned[i])

	if not _initial_encounter_queue.is_empty():
		_initial_encounter_timer = randf_range(0.75, 1.05)

	if planned.size() < 3:
		_initial_encounter_retries_remaining = 3 - planned.size()
		_initial_retry_timer = 1.8

func _process_initial_encounter_queue(delta: float) -> void:
	if _initial_encounter_queue.is_empty():
		return
	_initial_encounter_timer -= delta
	if _initial_encounter_timer <= 0.0:
		var item: Dictionary = _initial_encounter_queue.pop_front()
		var scene: PackedScene = item.get("scene", null) as PackedScene
		var pos: Vector3 = item.get("position", Vector3.INF)
		var heading: Vector3 = item.get("heading", Vector3.FORWARD)
		var s_key: String = str(item.get("source_key", "Initial"))
		var sec: int = int(item.get("sector", primary_entry_sector))
		var res_id: String = str(item.get("res_id", ""))

		if scene and pos != Vector3.INF:
			_deploy_staggered_enemy(scene, pos, heading, s_key, sec, res_id)

		if not _initial_encounter_queue.is_empty():
			_initial_encounter_timer = randf_range(0.75, 1.05)

func _deploy_staggered_enemy(scene: PackedScene, pos: Vector3, heading: Vector3, source_key: String, sector: int, res_id: String) -> Node3D:
	if not scene or not scene.can_instantiate():
		if not res_id.is_empty():
			release_reservation(res_id)
		return null

	var enemy := scene.instantiate() as Node3D
	if not enemy:
		if not res_id.is_empty():
			release_reservation(res_id)
		return null

	enemy.transform.origin = pos
	if heading.length_squared() > 0.01:
		enemy.rotation.y = atan2(-heading.x, -heading.z)

	var req_radius := get_enemy_clearance_radius(enemy)
	if not res_id.is_empty():
		bind_enemy_to_reservation(res_id, enemy)
	record_spawn_event(source_key, pos)
	_log_spawn_event(enemy, source_key, sector, pos, req_radius)

	var parent := _get_spawn_parent()
	parent.add_child.call_deferred(enemy)
	_register_spawned_node(enemy)
	return enemy

func _plan_initial_encounter_positions(player_pos: Vector3) -> Array[Dictionary]:
	var inf_scene := _scene_infantry if (_scene_infantry and _scene_infantry.can_instantiate()) else load("res://scenes/enemies/infantry_cluster.tscn") as PackedScene
	var turret_scene := _scene_turret if (_scene_turret and _scene_turret.can_instantiate()) else load("res://scenes/enemies/ground_turret.tscn") as PackedScene
	var units_to_plan := [
		{"scene": inf_scene, "radius": 8.0, "type": "infantry"},
		{"scene": inf_scene, "radius": 8.0, "type": "infantry"},
		{"scene": turret_scene, "radius": 10.0, "type": "turret"}
	]
	var results: Array[Dictionary] = []

	var raw_candidates: Array[Dictionary] = []

	# 1. Natural road streamer candidates
	var streamer := get_tree().get_first_node_in_group("city_streamer") as CityWorldStreamer if is_inside_tree() else null
	if is_instance_valid(streamer):
		var s_cands := streamer.query_natural_spawn_candidates(player_pos, "ground", 38.0, 95.0)
		for c in s_cands:
			var pos: Vector3 = c["position"]
			var s_key := _get_streamer_source_key(c)
			raw_candidates.append({
				"position": pos,
				"heading": c.get("heading", Vector3.FORWARD),
				"source_name": c.get("source_name", "StreamerRoad"),
				"source_key": s_key,
				"sector": primary_entry_sector
			})

	# 2. Authored ground entrance markers
	for marker in get_ground_spawn_nodes():
		var pos := marker.global_position
		var d := player_pos.distance_to(pos)
		if d >= 35.0 and d <= 120.0:
			var hd := (player_pos - pos)
			hd.y = 0.0
			raw_candidates.append({
				"position": pos,
				"heading": hd.normalized() if hd.length_squared() > 0.01 else Vector3.FORWARD,
				"source_name": marker.name,
				"source_key": marker.name,
				"sector": primary_entry_sector
			})

	# 3. Active sectors
	var off_angles: Array[float] = [-0.25, 0.0, 0.25]
	var dists: Array[float] = [42.0, 56.0, 70.0]
	for sec in [primary_entry_sector, secondary_entry_sector]:
		var base_angle := float(sec) * (TAU / 8.0)
		for off_ang: float in off_angles:
			var a: float = base_angle + off_ang
			for dist: float in dists:
				var cand_pos := Vector3(
					player_pos.x + cos(a) * dist,
					0.0,
					player_pos.z + sin(a) * dist
				)
				var hd := (player_pos - cand_pos)
				hd.y = 0.0
				raw_candidates.append({
					"position": cand_pos,
					"heading": hd.normalized() if hd.length_squared() > 0.01 else Vector3.FORWARD,
					"source_name": "Sector_%d" % sec,
					"source_key": "Sector_%d" % sec,
					"sector": sec
				})

	# 4. Safe road perimeter points
	for i in range(_safe_road_points.size()):
		var pt: Vector3 = _safe_road_points[i]
		var d := player_pos.distance_to(pt)
		if d >= 35.0 and d <= 95.0:
			var hd := (player_pos - pt)
			hd.y = 0.0
			raw_candidates.append({
				"position": pt,
				"heading": hd.normalized() if hd.length_squared() > 0.01 else Vector3.FORWARD,
				"source_name": "SafeRoadPoint_%d" % i,
				"source_key": "SafeRoadPoint_%d" % i,
				"sector": secondary_entry_sector
			})

	raw_candidates.shuffle()

	# Select up to 3 positions with >= 18m separation, at least 2 distinct sources/sectors, camera offscreen
	for unit_info in units_to_plan:
		var req_rad: float = float(unit_info["radius"])
		var chosen_cand: Dictionary = {}

		for cand in raw_candidates:
			var c_pos: Vector3 = cand["position"]
			var c_skey: String = cand["source_key"]
			var c_sec: int = cand["sector"]

			# Check separation against already chosen positions in this initial encounter
			var conflict := false
			for prev in results:
				var prev_pos: Vector3 = prev["position"]
				if Vector2(c_pos.x - prev_pos.x, c_pos.z - prev_pos.z).length() < 18.0:
					conflict = true
					break
			if conflict:
				continue

			# Must have at least two distinct sources/sectors if on second unit
			if results.size() == 1:
				if c_skey == results[0]["source_key"] and c_sec == results[0]["sector"]:
					continue

			if is_position_in_camera_view(c_pos, 80.0):
				continue

			var g_res := _validate_ground_clearance(c_pos)
			if not g_res["valid"]:
				continue
			c_pos = g_res["position"]

			if not is_spawn_position_clear(c_pos, false, req_rad):
				continue

			chosen_cand = cand.duplicate()
			chosen_cand["position"] = c_pos
			break

		# Relax strict distinct source requirement if needed, while keeping >= 18m separation
		if chosen_cand.is_empty():
			for cand in raw_candidates:
				var c_pos: Vector3 = cand["position"]
				var conflict := false
				for prev in results:
					var prev_pos: Vector3 = prev["position"]
					if Vector2(c_pos.x - prev_pos.x, c_pos.z - prev_pos.z).length() < 18.0:
						conflict = true
						break
				if conflict:
					continue
				if is_position_in_camera_view(c_pos, 80.0):
					continue
				var g_res := _validate_ground_clearance(c_pos)
				if not g_res["valid"]:
					continue
				c_pos = g_res["position"]
				if not is_spawn_position_clear(c_pos, false, req_rad):
					continue
				chosen_cand = cand.duplicate()
				chosen_cand["position"] = c_pos
				break

		if not chosen_cand.is_empty():
			var res_id := reserve_spawn_position(
				chosen_cand["position"],
				req_rad,
				"ground",
				chosen_cand["source_name"],
				chosen_cand["sector"],
				6.0,
				"initial_encounter",
				chosen_cand["source_key"]
			)
			results.append({
				"scene": unit_info["scene"],
				"position": chosen_cand["position"],
				"heading": chosen_cand["heading"],
				"source_name": chosen_cand["source_name"],
				"source_key": chosen_cand["source_key"],
				"sector": chosen_cand["sector"],
				"res_id": res_id
			})

	return results

func _retry_missing_initial_encounter() -> void:
	if _initial_encounter_retries_remaining <= 0:
		return
	var player := _get_player()
	var p_pos := player.global_position if player else Vector3.ZERO
	var planned := _plan_initial_encounter_positions(p_pos)
	if not planned.is_empty():
		var u: Dictionary = planned[0]
		_deploy_staggered_enemy(u["scene"], u["position"], u["heading"], u["source_key"], u["sector"], u["res_id"])
		_initial_encounter_retries_remaining -= 1
		_initial_retry_timer = 0.8
	else:
		_initial_retry_timer = 0.6

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

func get_population_band() -> Vector2i:
	match current_wave:
		1: return Vector2i(12, 16)
		2: return Vector2i(16, 20)
		3: return Vector2i(20, 24)
		_: return Vector2i(20 + (current_wave - 3) * 2, 24 + (current_wave - 3) * 2)

func get_visual_crowd_band() -> Vector2i:
	match current_wave:
		1: return Vector2i(20, 28)
		2: return Vector2i(26, 36)
		3: return Vector2i(34, 44)
		_: return Vector2i(34 + (current_wave - 3) * 4, 44 + (current_wave - 3) * 4)

func get_active_population_cap() -> int:
	if is_wave_active:
		var band := get_population_band()
		if current_wave == 10:
			var wt: Resource = get_current_wave_target()
			if wt and int(wt.get("support_node_cap")) > 0:
				return int(wt.get("support_node_cap")) + 1
		return band.y
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
	if is_wave_active:
		var n_cap := get_active_population_cap()
		var a_max := get_air_population_cap()
		if current_wave < 6:
			return n_cap
		return maxi(4, n_cap - a_max)
	if not encounter_config:
		return 14
	if elapsed_survival_time < encounter_config.warmup_duration:
		return encounter_config.warmup_ground_cap
	var progress := clampf(elapsed_survival_time / encounter_config.escalation_duration, 0.0, 1.0)
	return int(lerpf(float(encounter_config.warmup_ground_cap), float(encounter_config.max_ground_cap), progress))

func get_air_population_cap() -> int:
	if is_wave_active:
		if current_wave < 6:
			return 0 # Air enemies strictly forbidden before Wave 6!
		var wt: Resource = get_current_wave_target()
		if wt and wt.get("max_air") != null:
			return int(wt.get("max_air"))
		return 3
	if not encounter_config:
		return 6
	if elapsed_survival_time < encounter_config.warmup_duration:
		return encounter_config.warmup_air_cap
	var progress := clampf(elapsed_survival_time / encounter_config.escalation_duration, 0.0, 1.0)
	return int(lerpf(float(encounter_config.warmup_air_cap), float(encounter_config.max_air_cap), progress))

func get_target_active_count() -> int:
	if is_wave_active:
		var band := get_population_band()
		return int((band.x + band.y) * 0.5)
	if not encounter_config:
		var stage := get_survival_stage()
		match stage:
			1: return 18
			2: return 32
			3: return 48
			4: return 60
			5: return 72
			6: return 90
			_: return 25
	var cap := get_active_population_cap()
	if encounter_config and elapsed_survival_time < encounter_config.warmup_duration:
		return maxi(2, int(float(cap) * 0.55))
	return maxi(4, int(float(cap) * 0.85))

func get_visual_crowd_target() -> Vector2i:
	if is_wave_active:
		return get_visual_crowd_band()
	var wt: Resource = get_current_wave_target()
	if wt:
		return Vector2i(int(wt.get("visual_crowd_min")), int(wt.get("visual_crowd_max")))
	return Vector2i(20, 28)

func get_living_visual_crowd() -> float:
	if EnemyRegistry.instance:
		return EnemyRegistry.instance.get_living_visual_crowd()
	var total: float = 0.0
	for e in _wave_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "is_alive" in e and not e.is_alive:
				continue
			var meta := EnemyRegistry.get_enemy_metadata(e)
			total += meta.get("visual_crowd_weight", 1.0)
	return total

func get_special_enemy_counts() -> Dictionary:
	if EnemyRegistry.instance:
		return EnemyRegistry.instance.get_special_counts()
	return {"sam": 0, "mortar": 0, "heavy": 0, "medium_armored": 0, "air": 0, "boss": 0}

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
	if "xp_reward" in enemy:
		enemy.xp_reward = int(enemy.xp_reward * 3)
	elif "xp_value" in enemy:
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

	# 2. Sector Rotation (preserves primary + adjacent sector, guarantees >=120 deg escape arc)
	_sector_rotation_timer -= delta
	if _sector_rotation_timer <= 0.0:
		if not is_heavy_telegraph_active():
			rotate_directional_sectors()
			var r_min: float = difficulty_profile.sector_rotation_interval_min if difficulty_profile else 10.0
			var r_max: float = difficulty_profile.sector_rotation_interval_max if difficulty_profile else 15.0
			_sector_rotation_timer = randf_range(r_min, r_max)
		else:
			# Postpone rotation during heavy encounter telegraphs
			_sector_rotation_timer = 2.0

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
			state_mult = 1.35
		EncounterState.RECOVERY:
			state_mult = difficulty_profile.recovery_spawn_mult if difficulty_profile else (encounter_config.recovery_budget_rate_mult if encounter_config else 0.30)
		EncounterState.STREAMING:
			state_mult = 1.0

	var diff_scale := 1.0
	var gm := get_tree().get_first_node_in_group("game_manager") if is_inside_tree() else null
	if gm and "difficulty_scale" in gm:
		diff_scale = float(gm.difficulty_scale)

	continuous_ground_budget += base_ground_budget_rate * time_mult * state_mult * diff_scale * delta
	if current_wave >= 3:
		continuous_air_budget += base_air_budget_rate * time_mult * state_mult * diff_scale * delta
	else:
		continuous_air_budget = 0.0

	# Cap stored budget to prevent runaway stockpiles during quiet lulls
	continuous_ground_budget = clampf(continuous_ground_budget, 0.0, 50.0)
	continuous_air_budget = clampf(continuous_air_budget, 0.0, 30.0)

	# 4. Offscreen distant enemy cleanup (every ~2 seconds)
	var cleanup_interval: float = encounter_config.offscreen_cleanup_check_interval if encounter_config else 2.0
	_offscreen_cleanup_timer -= delta
	if _offscreen_cleanup_timer <= 0.0:
		_offscreen_cleanup_timer = cleanup_interval
		_process_offscreen_cleanup()

	# 5. Dynamic CombatDirector attack slot scaling
	if CombatDirector.instance:
		if CombatDirector.instance.current_wave != current_wave:
			CombatDirector.instance.set_wave(current_wave)

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
	primary_entry_sector = focus_sec
	secondary_entry_sector = (focus_sec + 1) % 8
	protected_escape_sectors = [posmod(focus_sec + 3, 8), posmod(focus_sec + 4, 8), posmod(focus_sec + 5, 8)]
	_active_sectors = [primary_entry_sector, secondary_entry_sector]

func is_heavy_telegraph_active() -> bool:
	if not is_inside_tree():
		return false
	var bosses := get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			if "is_telegraphing" in b and b.is_telegraphing:
				return true
			if "_is_telegraphing" in b and b._is_telegraphing:
				return true
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if "current_state" in e and e.current_state == 2:
				return true
			if "_is_telegraphing" in e and e._is_telegraphing:
				return true
	return false

func rotate_directional_sectors() -> void:
	if has_mission_focus:
		_apply_mission_sector_focus()
		return
	var old_p := primary_entry_sector
	var new_p := (old_p + randi_range(2, 6)) % 8
	primary_entry_sector = new_p

	# At most one adjacent secondary sector (+1 or -1)
	var adj_offset := 1 if randf() < 0.5 else -1
	secondary_entry_sector = posmod(new_p + adj_offset, 8)

	# Continuous escape arc of at least 120 degrees (3 contiguous sectors opposite = 135 deg)
	protected_escape_sectors.clear()
	if adj_offset == 1:
		protected_escape_sectors = [posmod(new_p + 3, 8), posmod(new_p + 4, 8), posmod(new_p + 5, 8)]
	else:
		protected_escape_sectors = [posmod(new_p - 3, 8), posmod(new_p - 4, 8), posmod(new_p - 5, 8)]

	_active_sectors = [primary_entry_sector, secondary_entry_sector]

func get_active_entry_sectors() -> Array[int]:
	return [primary_entry_sector, secondary_entry_sector]

func get_protected_escape_sectors() -> Array[int]:
	return protected_escape_sectors

func is_sector_in_escape_arc(sector: int) -> bool:
	return protected_escape_sectors.has(sector)

func _rotate_active_sectors() -> void:
	if difficulty_profile != null:
		rotate_directional_sectors()
		return
	if has_mission_focus:
		_apply_mission_sector_focus()
		return
	var old_first := _active_sectors[0] if _active_sectors.size() > 0 else 0
	var new_first := (old_first + randi_range(2, 6)) % 8
	var offsets: Array[int] = [2, 3]
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

func query_natural_spawn_candidates(category: String, player_pos: Vector3, min_dist: float = -1.0, max_dist: float = -1.0) -> Array[Dictionary]:
	var streamer := get_tree().get_first_node_in_group("city_streamer") as CityWorldStreamer if is_inside_tree() else null
	if is_instance_valid(streamer):
		var q_min := (160.0 if category == "air" else (60.0 if category == "rooftop" else 90.0)) if min_dist < 0.0 else min_dist
		var q_max := (230.0 if category == "air" else (140.0 if category == "rooftop" else 160.0)) if max_dist < 0.0 else max_dist
		var cands := streamer.query_natural_spawn_candidates(player_pos, category, q_min, q_max)
		var valid_results: Array[Dictionary] = []
		for cand in cands:
			var pos: Vector3 = cand["position"]
			if is_position_in_camera_view(pos, 80.0):
				cand["validation_result"] = "REJECTED_FRUSTUM"
				continue
			var to_c := pos - player_pos
			to_c.y = 0.0
			if to_c.length_squared() > 1.0:
				var a := atan2(to_c.x, to_c.z)
				var sec := posmod(int(round(a / (TAU / 8.0))), 8)
				if is_sector_in_escape_arc(sec):
					cand["validation_result"] = "REJECTED_ESCAPE_ARC"
					continue
			if category == "ground" and not is_spawn_position_clear(pos, false):
				cand["validation_result"] = "REJECTED_BUILDING"
				continue
			cand["validation_result"] = "VALID"
			valid_results.append(cand)
		return valid_results
	return []

func _get_streamer_source_key(cand: Dictionary) -> String:
	var coord: Vector2i = cand.get("chunk_coord", Vector2i.ZERO)
	var sname: String = str(cand.get("source_name", "Unknown"))
	var cat: String = str(cand.get("category", "ground"))
	return "streamer_%s_%d_%d_%s" % [cat, coord.x, coord.y, sname]

func get_dynamic_encounter_spawn_point(is_air: bool, player_pos: Vector3, min_dist: float = -1.0, max_dist: float = -1.0) -> Dictionary:
	if min_dist < 0.0:
		min_dist = encounter_config.spawn_distance_min if encounter_config else 38.0
	if max_dist < 0.0:
		max_dist = encounter_config.spawn_distance_max if encounter_config else 68.0

	var req_rad: float = float(SEPARATION_RADII["air_default"]) if is_air else float(SEPARATION_RADII["ground_default"])

	# 0. Query CityWorldStreamer for natural road sockets or elevated air corridors.
	# Respect the caller's distance band so continuous threats enter just outside view
	# instead of appearing so far away that the battlefield feels empty.
	var streamer := get_tree().get_first_node_in_group("city_streamer") as CityWorldStreamer if is_inside_tree() else null
	if is_instance_valid(streamer):
		var cat := "air" if is_air else "ground"
		var q_min := maxf(min_dist, 45.0 if is_air else 38.0)
		var q_max := maxf(q_min + 8.0, max_dist)
		var natural_cands := streamer.query_natural_spawn_candidates(player_pos, cat, q_min, q_max)
		natural_cands.shuffle()
		for cand in natural_cands:
			var c_pos: Vector3 = cand["position"]
			var s_key := _get_streamer_source_key(cand)

			# Source cooldown (6.0s) & recent position proximity (18.0m, 8.0s)
			if is_source_on_cooldown(s_key, 6.0):
				continue
			if is_position_near_recent_spawn(c_pos, 18.0, 8.0, is_air):
				continue

			# 1. Frustum rejection with safe margin (reject points in camera view)
			if is_position_in_camera_view(c_pos, 80.0):
				rejected_spawn_reasons["frustum"] += 1
				continue

			# 2. Escape arc violation check
			var to_c := c_pos - player_pos
			to_c.y = 0.0
			if to_c.length_squared() > 1.0:
				var a := atan2(to_c.x, to_c.z)
				var sec := posmod(int(round(a / (TAU / 8.0))), 8)
				if is_sector_in_escape_arc(sec):
					rejected_spawn_reasons["escape_arc_violation"] += 1
					continue

			# 3. Clearance check
			if is_air:
				c_pos.y = clampf(_get_player_altitude() + randf_range(12.0, 20.0), 25.0, 45.0)
				if not _validate_air_clearance(c_pos) or not is_spawn_position_clear(c_pos, true, req_rad):
					rejected_spawn_reasons["building"] += 1
					continue
			else:
				var g_val := _validate_ground_clearance(c_pos)
				if not g_val["valid"]:
					rejected_spawn_reasons["building"] += 1
					continue
				c_pos = g_val["position"]
				if not is_spawn_position_clear(c_pos, false, req_rad):
					rejected_spawn_reasons["building"] += 1
					continue

			_record_spawn_sector(primary_entry_sector)
			record_spawn_event(s_key, c_pos, str(cand["source_name"]))
			last_spawn_source = cand["source_name"]
			var hd := (player_pos - c_pos)
			hd.y = 0.0
			return {
				"success": true,
				"position": c_pos,
				"heading": hd.normalized() if hd.length_squared() > 0.01 else Vector3.FORWARD,
				"source_name": cand["source_name"],
				"source_key": s_key,
				"category": cat,
				"chunk_coord": cand["chunk_coord"],
				"distance": c_pos.distance_to(player_pos),
				"validation_result": "VALID"
			}

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

	# 3. Sample from current active sectors (primary + at most one adjacent secondary)
	for attempt in range(20):
		var sector: int = _active_sectors.pick_random() if _active_sectors.size() > 0 else primary_entry_sector
		if is_sector_in_escape_arc(sector):
			rejected_spawn_reasons["escape_arc_violation"] += 1
			continue
		if sector == posmod(primary_entry_sector + 4, 8):
			rejected_spawn_reasons["opposing_sector"] += 1
			continue

		var base_angle := float(sector) * (TAU / 8.0)
		var angle := base_angle + randf_range(-PI / 8.0, PI / 8.0)

		if near_boundary and inward_dir.length_squared() > 0.01:
			var inward_angle := atan2(inward_dir.y, inward_dir.x)
			var angle_diff := absf(angle_difference(angle, inward_angle))
			if angle_diff > (PI * 0.5):
				angle = lerp_angle(angle, inward_angle, 0.75)

		var dist := randf_range(min_dist, max_dist)
		if dist < min_dist:
			rejected_spawn_reasons["standoff_distance"] += 1
			continue

		var cand_x := ref_center.x + cos(angle) * dist
		var cand_z := ref_center.z + sin(angle) * dist

		if absf(cand_x) > arena_bound or absf(cand_z) > arena_bound:
			rejected_spawn_reasons["boundary"] += 1
			continue

		var cand_alt := 0.0
		if is_air:
			cand_alt = clampf(_get_player_altitude() + randf_range(-2.0, 3.5), 13.0, 24.0)

		var cand_pos := Vector3(cand_x, cand_alt, cand_z)

		var wm_node := get_tree().get_first_node_in_group("wave_manager")
		if is_instance_valid(wm_node) and wm_node.has_method("is_deployment_active") and wm_node.is_deployment_active():
			if cand_pos.distance_to(Vector3.ZERO) < 45.0:
				rejected_spawn_reasons["standoff_distance"] += 1
				continue

		if is_position_in_camera_view(cand_pos, margin_px):
			rejected_spawn_reasons["frustum"] += 1
			continue

		if is_position_near_recent_spawn(cand_pos, 18.0, 8.0, is_air):
			continue

		var s_key := "Sector_%d" % sector
		if not is_air:
			var g_res := _validate_ground_clearance(cand_pos)
			if not g_res["valid"]:
				rejected_spawn_reasons["building"] += 1
				continue
			var final_pos: Vector3 = g_res["position"]
			if not is_spawn_position_clear(final_pos, false, req_rad):
				rejected_spawn_reasons["building"] += 1
				continue
			var hd := (player_pos - final_pos)
			hd.y = 0.0
			_record_spawn_sector(sector)
			record_spawn_event(s_key, final_pos)
			last_spawn_source = "EncounterSector_%d" % sector
			return { "success": true, "position": final_pos, "heading": hd.normalized(), "source_name": "Sector_%d" % sector, "source_key": s_key, "validation_result": "VALID" }
		else:
			if not _validate_air_clearance(cand_pos) or not is_spawn_position_clear(cand_pos, true, req_rad):
				rejected_spawn_reasons["building"] += 1
				continue
			var hd := (player_pos - cand_pos)
			hd.y = 0.0
			_record_spawn_sector(sector)
			record_spawn_event(s_key, cand_pos)
			last_spawn_source = "EncounterAirSector_%d" % sector
			return { "success": true, "position": cand_pos, "heading": hd.normalized(), "source_name": "AirSector_%d" % sector, "source_key": s_key, "validation_result": "VALID" }

	# 4. Fallback pass: check authored spawn nodes that are off-screen
	if is_air:
		for a_node in get_air_spawn_nodes():
			var p := a_node.global_position
			var d := player_pos.distance_to(p)
			if d >= min_dist and not is_position_in_camera_view(p, margin_px) and not is_source_on_cooldown(a_node.name, 6.0) and not is_position_near_recent_spawn(p, 18.0, 8.0, true) and is_spawn_position_clear(p, true, req_rad):
				var hd := (player_pos - p)
				hd.y = 0.0
				last_spawn_source = a_node.name + " (EncounterFallback)"
				record_spawn_event(a_node.name, p)
				return { "success": true, "position": p, "heading": hd.normalized(), "source_name": a_node.name, "source_key": a_node.name, "validation_result": "VALID" }
	else:
		for g_node in get_ground_spawn_nodes():
			var p := g_node.global_position
			var d := player_pos.distance_to(p)
			if d >= min_dist and not is_position_in_camera_view(p, margin_px) and not is_source_on_cooldown(g_node.name, 6.0) and not is_position_near_recent_spawn(p, 18.0, 8.0, false) and is_spawn_position_clear(p, false, req_rad):
				var hd := (player_pos - p)
				hd.y = 0.0
				last_spawn_source = g_node.name + " (EncounterFallback)"
				record_spawn_event(g_node.name, p)
				return { "success": true, "position": p, "heading": hd.normalized(), "source_name": g_node.name, "source_key": g_node.name, "validation_result": "VALID" }

	# 5. Final safe fallback pass with full validation
	var safe_fb := _get_safe_perimeter_fallback(player_pos, is_air, req_rad)
	if safe_fb.get("success", false):
		var s_pos: Vector3 = safe_fb["position"]
		if is_air:
			s_pos.y = clampf(_get_player_altitude(), 14.0, 22.0)
		last_spawn_source = "Safe Perimeter Fallback"
		record_spawn_event(safe_fb["source_key"], s_pos, safe_fb["source_name"])
		return {
			"success": true,
			"position": s_pos,
			"heading": safe_fb["heading"],
			"source_name": safe_fb["source_name"],
			"source_key": safe_fb["source_key"],
			"validation_result": "VALID"
		}

	failed_spawn_attempts += 1
	return {
		"success": false,
		"position": Vector3.INF,
		"heading": Vector3.FORWARD,
		"source_name": "None",
		"source_key": "None",
		"validation_result": "FAILED"
	}

func is_enemy_eligible_for_quiet_cleanup(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false
	if "is_alive" in enemy and not enemy.is_alive:
		return false

	# 1. Never clean bosses
	if enemy.is_in_group("bosses") or enemy.name.begins_with("Boss") or (enemy is BossArchon):
		return false

	# 2. Never clean elites
	if enemy.is_in_group("elites") or ("is_elite" in enemy and enemy.is_elite):
		return false

	# 3. Never clean objectives or mission targets
	if enemy.is_in_group("objective") or enemy.is_in_group("mission_target") or enemy.is_in_group("mission_enemies") or enemy.name.begins_with("Radar"):
		return false
	if "is_mission_target" in enemy and enemy.is_mission_target:
		return false

	# 4. Never clean actively attacking, charging, or telegraphing enemies
	if "is_telegraphing" in enemy and enemy.is_telegraphing:
		return false
	if "_is_telegraphing" in enemy and enemy._is_telegraphing:
		return false
	if "is_firing" in enemy and enemy.is_firing:
		return false
	if "is_charging" in enemy and enemy.is_charging:
		return false
	var tele_node := enemy.get_node_or_null("AttackTelegraph")
	if tele_node and "visible" in tele_node and tele_node.visible:
		return false

	# 5. Never clean active attackers holding an attack slot
	if CombatDirector.instance and CombatDirector.instance.has_attack_permission(enemy):
		return false
	if "_has_attack_slot" in enemy and enemy._has_attack_slot:
		return false
	if "_has_air_slot" in enemy and enemy._has_air_slot:
		return false

	# 6. Never clean damaged enemies within 200m
	if "current_health" in enemy and "max_health" in enemy:
		var cur_hp: float = float(enemy.current_health)
		var max_hp: float = float(enemy.max_health)
		if max_hp > 0.0 and cur_hp < (max_hp * 0.75):
			var player := _get_player()
			if is_instance_valid(player) and player.global_position.distance_to(enemy.global_position) <= 200.0:
				return false

	return true

func _process_offscreen_cleanup() -> void:
	var player := _get_player()
	if not is_instance_valid(player):
		return
	var player_pos := player.global_position

	var despawn_dist: float = 260.0
	var time_threshold: float = 15.0
	var check_interval: float = encounter_config.offscreen_cleanup_check_interval if encounter_config else 2.0

	var streamer := get_tree().get_first_node_in_group("city_streamer") as CityWorldStreamer if is_inside_tree() else null

	var living_enemies: Array[Node3D] = []
	for enemy in _wave_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.is_inside_tree():
			living_enemies.append(enemy)

	for enemy in living_enemies:
		if not is_enemy_eligible_for_quiet_cleanup(enemy):
			if _enemy_offscreen_durations.has(enemy):
				_enemy_offscreen_durations.erase(enemy)
			continue

		var is_viewable := is_position_in_camera_view(enemy.global_position, 60.0)
		if is_viewable:
			if _enemy_offscreen_durations.has(enemy):
				_enemy_offscreen_durations.erase(enemy)
			continue

		# Check if the chunk they occupy has unloaded
		if is_instance_valid(streamer):
			var chunk_c := streamer.world_to_chunk_coord(enemy.global_position)
			if not streamer.active_chunks.has(chunk_c):
				_despawn_enemy_quietly(enemy)
				continue

		var dist := player_pos.distance_to(enemy.global_position)

		# Immediate hard recycle for enemies far away (> 150m) and not viewable
		if dist > 150.0 and not is_viewable:
			_despawn_enemy_quietly(enemy)
			continue

		# Soft recycle: only if dist > despawn_dist and offscreen for > time_threshold
		if dist > despawn_dist:
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
	var p_band := get_population_band()

	if current_living >= cap:
		return

	var player := _get_player()
	var p_pos := player.global_position if player else Vector3.ZERO

	var is_behind_target := current_living < target_count

	# 1. Formation Spawning
	_continuous_formation_cooldown -= delta
	if _continuous_formation_cooldown <= 0.0 and (current_living + 3 <= cap):
		if try_spawn_formation_with_fallback(stage, p_pos):
			_continuous_formation_cooldown = randf_range(4.0, 7.0) if current_living < p_band.x else (randf_range(6.0, 10.0) if is_behind_target else randf_range(9.0, 15.0))
			return

	# 2. Ambient Stream Spawning
	_continuous_stream_cooldown -= delta
	if _continuous_stream_cooldown <= 0.0:
		_spawn_continuous_stream(stage, p_pos)
		if current_living + 1 < p_band.x:
			_spawn_continuous_stream(stage, p_pos)
			_continuous_stream_cooldown = randf_range(1.0, 1.5)
		else:
			_continuous_stream_cooldown = _get_next_stream_interval(stage, is_behind_target)

func try_spawn_formation_with_fallback(stage: int, p_pos: Vector3) -> bool:
	# 1. Primary formation candidates
	if _try_spawn_continuous_formation(stage, p_pos):
		return true

	# 2. Multi-tier Fallback: Cheaper formation (Infantry Squad, staggered)
	if continuous_ground_budget >= 25.0 and can_spawn_formation("infantry_squad"):
		var s_pos := get_frustum_safe_spawn_pos(p_pos, 35.0, 55.0)
		if not s_pos.is_finite() or not _spawn_continuous_enemy(_scene_infantry, p_pos, 0.0, s_pos):
			return false
		var ang := randf() * TAU
		var second_raw := s_pos + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(8.5, 12.0)
		var second_pos := get_clamped_formation_member_position(second_raw, [s_pos], 8.0, Vector3(cos(ang), 0.0, sin(ang)), false)
		var second: Node3D = _scene_infantry.instantiate() as Node3D
		if second:
			second.transform.origin = second_pos
			var res_id := reserve_spawn_position(second_pos, 8.0, "ground", "infantry_squad", primary_entry_sector, 4.5, "infantry_squad")
			_deploy_formation_unit(second, _get_spawn_parent(), false, true, res_id)
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
		if not f_pos.is_finite() or not _spawn_continuous_enemy(_scene_infantry, p_pos, 0.0, f_pos):
			return false
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

	if current_wave >= 6 and stage >= 4 and continuous_air_budget >= 20.0 and can_spawn_formation("elite_encounter") and get_active_air_count("ace_gunships") < cap_ace and randf() > 0.4:
		var entry := get_air_corridor_entry(p_pos, 45.0, 75.0)
		spawn_elite_air_encounter(entry["position"], entry["heading"])
		continuous_air_budget -= 20.0
		return true

	if current_wave >= 6 and stage >= 4 and continuous_air_budget >= 17.0 and can_spawn_formation("electronic_strike") and get_active_air_count("jammers") < cap_jammer and randf() > 0.4:
		var entry := get_air_corridor_entry(p_pos, 45.0, 75.0)
		spawn_electronic_strike_group(entry["position"], entry["heading"], true)
		continuous_air_budget -= 17.0
		return true

	if current_wave >= 6 and stage >= 3 and continuous_ground_budget >= 40.0 and continuous_air_budget >= 22.0 and can_spawn_formation("combined_arms") and randf() > 0.35:
		var entry := get_air_corridor_entry(p_pos, 45.0, 72.0)
		spawn_combined_arms_formation(entry["position"], entry["heading"])
		continuous_ground_budget -= 40.0
		continuous_air_budget -= 22.0
		return true

	if current_wave >= 6 and stage >= 3 and continuous_air_budget >= 13.0 and can_spawn_formation("air_intercept") and get_active_air_count("attack_gunships") < cap_gunship and randf() > 0.35:
		var entry := get_air_corridor_entry(p_pos, 42.0, 70.0)
		spawn_air_intercept(entry["position"], entry["heading"], 1)
		continuous_air_budget -= 13.0
		return true

	if current_wave >= 6 and stage >= 2 and continuous_air_budget >= 14.0 and can_spawn_formation("harassment_group") and get_active_air_count("rocket_raiders") < cap_raider and randf() > 0.3:
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

	# Air Patrol (2 Scouts) becomes available once air threats enter the run.
	if current_wave >= 3 and continuous_air_budget >= 8.0 and can_spawn_formation("air_patrol") and get_active_air_count("scouts") + 2 <= cap_scout:
		var entry := get_air_corridor_entry(p_pos, 40.0, 65.0)
		spawn_air_patrol(entry["position"], entry["heading"])
		continuous_air_budget -= 8.0
		return true

	# Formation Fallback: Infantry Squad (2 clusters, staggered)
	if continuous_ground_budget >= 25.0 and can_spawn_formation("infantry_squad"):
		var entry := get_authored_ground_spawn("infantry", p_pos, 35.0)
		var s_pos: Vector3 = entry["position"]
		_spawn_continuous_enemy(_scene_infantry, p_pos, 0.0, s_pos)
		var ang := randf() * TAU
		var second_raw := s_pos + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(8.5, 12.0)
		var second_pos := get_clamped_formation_member_position(second_raw, [s_pos], 8.0, Vector3(cos(ang), 0.0, sin(ang)), false)
		var second: Node3D = _scene_infantry.instantiate() as Node3D
		if second:
			second.transform.origin = second_pos
			var res_id := reserve_spawn_position(second_pos, 8.0, "ground", "infantry_squad", primary_entry_sector, 4.5, "infantry_squad")
			_deploy_formation_unit(second, _get_spawn_parent(), false, true, res_id)
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
		continuous_ground_budget = maxf(continuous_ground_budget, 25.0)
		if continuous_air_budget < 4.0 and stage >= 1 and current_wave >= 3:
			continuous_air_budget = maxf(continuous_air_budget, 4.0)

	# --- Data-driven profile path (Phase 10A) ---
	if difficulty_profile != null:
		var target: Resource = get_current_wave_target()
		var current_visual := int(get_living_visual_crowd())
		var max_visual: int = int(target.get("support_visual_crowd_max")) if (target and target.get("is_boss_wave")) else (get_visual_crowd_band().y if is_wave_active else (int(target.get("visual_crowd_max")) if target else 40))
		if current_visual >= max_visual:
			return

		var special_counts := EnemyRegistry.instance.get_special_counts() if EnemyRegistry.instance else {}
		var cur_sam: int = special_counts.get("sam", 0)
		var cur_mortar: int = special_counts.get("mortar", 0)
		var cur_heavy: int = special_counts.get("heavy", 0)
		var cur_med: int = special_counts.get("medium_armored", 0)
		var cur_air: int = special_counts.get("air", 0)

		var max_sam: int = int(target.get("max_sam")) if target else cap_sam
		var max_mortar: int = int(target.get("max_mortar")) if target else cap_mortar
		var max_heavy: int = int(target.get("max_heavy")) if target else 99
		var max_med: int = int(target.get("max_medium_armored")) if target else 99
		var max_air: int = int(target.get("max_air")) if target else (0 if current_wave < 3 else air_cap)
		# Introduce one scout in wave 3 so the air state machine is part of normal
		# play, then let authored wave caps take over from wave 6 onward.
		if current_wave >= 3 and max_air <= 0:
			max_air = 1

		var can_spawn_air: bool = (current_wave >= 3) and (cur_air < max_air) and (air_living < air_cap) and (continuous_air_budget >= 4.0)
		var can_spawn_ground: bool = (ground_living < ground_cap) and (continuous_ground_budget >= 15.0)

		var spawn_air_now: bool = false
		if can_spawn_air and (not can_spawn_ground or randf() < 0.25):
			spawn_air_now = true
		elif not can_spawn_ground and not can_spawn_air:
			return

		if spawn_air_now:
			var air_spawn_alt := clampf(_get_player_altitude(), 11.0, 17.0)
			var air_scene: PackedScene = _scene_air_scout
			var air_cost: float = 4.0

			if current_wave >= 9 and continuous_air_budget >= 12.0 and randf() < 0.20:
				air_scene = _scene_air_ace
				air_cost = 12.0
			elif current_wave >= 8 and continuous_air_budget >= 9.0 and cur_heavy < max_heavy and randf() < 0.30:
				air_scene = _scene_air_gunship
				air_cost = 9.0
			elif current_wave >= 8 and continuous_air_budget >= 8.0 and get_active_unit_count("jammer") < cap_jammer and randf() < 0.25:
				air_scene = _scene_air_jammer
				air_cost = 8.0
			elif current_wave >= 7 and continuous_air_budget >= 7.0 and get_active_unit_count("transport") < cap_transport and randf() < 0.30:
				air_scene = _scene_air_transport
				air_cost = 7.0
			elif current_wave >= 6 and continuous_air_budget >= 6.0 and get_active_unit_count("raider") < cap_raider and randf() < 0.40:
				air_scene = _scene_air_raider
				air_cost = 6.0
			else:
				air_scene = _scene_air_scout
				air_cost = 4.0

			_spawn_continuous_enemy(air_scene, p_pos, air_spawn_alt)
			continuous_air_budget -= air_cost
		else:
			# Spawn 1 ground unit respecting wave weights and caps
			var weights: Dictionary = target.composition_weights if target else {"fodder": 0.8, "light_shooter": 0.2}
			var total_w := 0.0
			for role in weights.keys():
				total_w += float(weights[role])
			var roll := randf() * total_w
			var accum := 0.0
			var chosen_role := "fodder"
			for role in weights.keys():
				accum += float(weights[role])
				if roll <= accum:
					chosen_role = role
					break

			var g_scene: PackedScene = _scene_infantry
			var g_cost: float = 15.0

			if (chosen_role == "anti_air" or chosen_role == "sam") and cur_sam < max_sam and continuous_ground_budget >= 40.0:
				if current_wave != 5 or cur_mortar == 0:
					g_scene = _scene_sam
					g_cost = 40.0
				else:
					chosen_role = "fodder"
			elif chosen_role == "mortar" and cur_mortar < max_mortar and continuous_ground_budget >= 34.0:
				if current_wave != 5 or cur_sam == 0:
					g_scene = _scene_mortar
					g_cost = 34.0
				else:
					chosen_role = "fodder"
			elif (chosen_role == "heavy") and cur_heavy < max_heavy and continuous_ground_budget >= 28.0:
				g_scene = _scene_tank
				g_cost = 28.0
			elif (chosen_role == "armored" or chosen_role == "medium_armored") and cur_med < max_med and continuous_ground_budget >= 26.0:
				g_scene = _scene_ifv if randf() < 0.5 else _scene_apc
				g_cost = 26.0 if g_scene == _scene_ifv else 28.0
			elif chosen_role == "light_shooter" and continuous_ground_budget >= 20.0:
				g_scene = _scene_turret if randf() < 0.5 else _scene_technical
				g_cost = 20.0 if g_scene == _scene_turret else 22.0
			else:
				if current_visual + 4 <= max_visual and randf() < 0.70:
					g_scene = _scene_infantry
					g_cost = 15.0
				else:
					g_scene = _scene_buggy
					g_cost = 18.0

			_spawn_continuous_enemy(g_scene, p_pos, 0.0)
			continuous_ground_budget -= g_cost

		if is_inside_tree() and Engine.get_process_frames() % 60 == 0:
			XPGem.aggregate_excess_gems(get_tree(), 50)
		return

	# Ground stream with time-based unlocks and tactical caps (Legacy)
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

	# Periodic XP Gem Aggregation to keep pickup entity count bounded (under 50)
	if is_inside_tree() and Engine.get_process_frames() % 60 == 0:
		XPGem.aggregate_excess_gems(get_tree(), 50)

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

func _is_air_scene(scene: PackedScene) -> bool:
	if not scene:
		return false
	var p := scene.resource_path.to_lower()
	if "ground_" in p or "tank" in p or "infantry" in p or "turret" in p or "sam_" in p or "dummy" in p:
		return false
	return "hunter" in p or "gunship" in p or "raider" in p or "air" in p or "boss_archon" in p

func _spawn_continuous_enemy(scene: PackedScene, player_pos: Vector3, altitude: float, forced_pos: Vector3 = Vector3.INF) -> Node3D:
	if not scene:
		failed_spawn_attempts += 1
		return null

	var is_air: bool = _is_air_scene(scene)
	var req_radius: float = get_enemy_clearance_radius(scene)

	var spawn_pos: Vector3 = forced_pos
	var heading: Vector3 = Vector3.FORWARD
	var source_key: String = "Forced"
	var source_name: String = "Forced"
	var sector: int = primary_entry_sector

	if not forced_pos.is_finite():
		var spawn_data := get_dynamic_encounter_spawn_point(is_air, player_pos)
		var pos_val: Vector3 = spawn_data.get("position", Vector3.INF)
		if not spawn_data.get("success", false) or not pos_val.is_finite():
			failed_spawn_attempts += 1
			_continuous_stream_cooldown = randf_range(0.4, 0.8)
			return null
		spawn_pos = pos_val
		heading = spawn_data.get("heading", Vector3.FORWARD)
		source_key = spawn_data.get("source_key", spawn_data.get("source_name", "Dynamic"))
		source_name = spawn_data.get("source_name", "Dynamic")
		sector = spawn_data.get("sector", primary_entry_sector)
	else:
		if not is_spawn_position_clear(spawn_pos, is_air, req_radius):
			failed_spawn_attempts += 1
			return null

	if not spawn_pos.is_finite():
		failed_spawn_attempts += 1
		return null

	var enemy: Node3D = scene.instantiate() as Node3D
	if not enemy:
		failed_spawn_attempts += 1
		return null

	if is_air:
		altitude = clampf(spawn_pos.y if spawn_pos.y > 4.5 else altitude, 11.0, 22.0)
	else:
		altitude = spawn_pos.y
	if not is_finite(altitude):
		altitude = 14.0 if is_air else 0.0

	enemy.transform.origin = Vector3(spawn_pos.x, altitude, spawn_pos.z)

	# Orient mobile enemies toward movement heading
	if heading.length_squared() > 0.01:
		enemy.rotation.y = atan2(-heading.x, -heading.z)

	var res_id := reserve_spawn_position(
		enemy.transform.origin,
		req_radius,
		"air" if is_air else "ground",
		source_name,
		sector,
		4.5,
		"",
		source_key
	)
	bind_enemy_to_reservation(res_id, enemy)
	record_spawn_event(source_key, enemy.transform.origin, source_name)
	_log_spawn_event(enemy, source_key, sector, enemy.transform.origin, req_radius)

	if elapsed_survival_time > 180.0 and randf() < clampf(0.12 + (elapsed_survival_time - 180.0) / 600.0 * 0.25, 0.12, 0.35):
		apply_elite_modifier(enemy)

	# Attach headlights to non-infantry ground vehicles for arrival readability
	if not is_air and not enemy.is_in_group("infantry") and not ("turret" in enemy.name.to_lower()) and not enemy.has_node("Headlight"):
		var light := SpotLight3D.new()
		light.name = "Headlight"
		light.spot_range = 28.0
		light.spot_angle = 38.0
		light.light_color = Color(1.0, 0.95, 0.85)
		light.light_energy = 2.2
		light.transform.origin = Vector3(0.0, 0.7, -1.0)
		light.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		enemy.add_child(light)

	var parent := _get_spawn_parent()
	parent.add_child.call_deferred(enemy)
	_register_spawned_node(enemy)
	return enemy

func register_mission_enemy(enemy: Node3D) -> void:
	# Mission targets share the same population bookkeeping and cleanup path as
	# continuously spawned enemies without pausing or resetting the stream.
	_register_spawned_node(enemy)

func get_mission_spawn_position(is_air: bool, min_distance: float = 45.0, max_distance: float = 75.0) -> Dictionary:
	var player := _get_player()
	var player_pos := player.global_position if is_instance_valid(player) else Vector3.ZERO
	return get_dynamic_encounter_spawn_point(is_air, player_pos, min_distance, max_distance)

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
	var target: Resource = get_current_wave_target()

	for form in procedural_formations:
		# 0. Air gating: Waves 1-5 NEVER allow air formations
		if current_wave < 6:
			if form.air_budget_cost > 0.0 or form.category == 2 or form.category == 3:
				continue
			var has_air_unit := false
			for u in form.units:
				if u.get("is_air", false):
					has_air_unit = true
					break
			if has_air_unit:
				continue

		# 0b. Wave 5 special rule: SAM and Mortar NEVER in same formation
		if current_wave <= 5:
			var req_sam: int = int(form.required_caps.get("sam", 0))
			var req_mortar: int = int(form.required_caps.get("mortar", 0))
			if req_sam > 0 and req_mortar > 0:
				continue

		# 1. Unlock time check
		if form.min_elapsed_time > elapsed_survival_time:
			continue

		# 2. Budget check
		if continuous_ground_budget < form.ground_budget_cost or continuous_air_budget < form.air_budget_cost:
			continue

		# 3. Tactical and Wave Caps check
		var cap_violated := false
		for cap_tag in form.required_caps.keys():
			var req_count: int = int(form.required_caps[cap_tag])
			var current_count := get_active_unit_count(cap_tag)
			var max_allowed: int = 99
			match cap_tag:
				"sam":
					max_allowed = int(target.get("max_sam")) if (target and int(target.get("max_sam")) < 99) else cap_sam
				"mortar":
					max_allowed = int(target.get("max_mortar")) if (target and int(target.get("max_mortar")) < 99) else cap_mortar
				"gunship":
					max_allowed = int(target.get("max_heavy")) if (target and int(target.get("max_heavy")) < 99) else cap_gunship
				"tank":
					max_allowed = int(target.get("max_heavy")) if (target and int(target.get("max_heavy")) < 99) else 99
				"ifv", "apc":
					max_allowed = int(target.get("max_medium_armored")) if (target and int(target.get("max_medium_armored")) < 99) else 99
				"jammer":
					max_allowed = cap_support
				"transport":
					max_allowed = cap_transport
				"scout":
					max_allowed = cap_scout
				"raider":
					max_allowed = cap_raider
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

## Calculates a valid position for a formation member that respects arena boundaries,
## does not collapse onto boundary coordinates with other members, and guarantees minimum separation.
func get_clamped_formation_member_position(proposed_pos: Vector3, placed_positions: Array[Vector3], min_sep: float = 8.0, travel_dir: Vector3 = Vector3.ZERO, is_air: bool = false) -> Vector3:
	var margin: float = 2.5 if is_air else 3.0
	var bound: float = arena_half_extents - margin
	var candidate := proposed_pos
	candidate.x = clampf(candidate.x, -bound, bound)
	candidate.z = clampf(candidate.z, -bound, bound)
	if not is_air:
		candidate.y = 0.0

	var conflicts := false
	for p: Vector3 in placed_positions:
		var d: float = candidate.distance_to(p) if is_air else Vector2(candidate.x - p.x, candidate.z - p.z).length()
		if d < min_sep:
			conflicts = true
			break

	if not conflicts:
		return candidate

	# Resolve collision / boundary collapse
	var dir := travel_dir.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD
	var perp := Vector3(-dir.z, 0.0, dir.x)

	# Calculate inward vector from arena boundaries
	var inward := Vector3.ZERO
	if absf(candidate.x) >= bound - 2.0:
		inward.x = -signf(candidate.x)
	if absf(candidate.z) >= bound - 2.0:
		inward.z = -signf(candidate.z)
	if inward.length_squared() > 0.01:
		inward = inward.normalized()
	else:
		inward = -candidate.normalized() if candidate.length_squared() > 1.0 else Vector3.FORWARD

	# Structured candidate offsets
	var candidate_offsets: Array[Vector3] = []
	for step in [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]:
		candidate_offsets.append(inward * (min_sep * step))
		candidate_offsets.append(perp * (min_sep * step))
		candidate_offsets.append(-perp * (min_sep * step))
		candidate_offsets.append(-dir * (min_sep * step))
		candidate_offsets.append(dir * (min_sep * step))
		candidate_offsets.append((inward + perp).normalized() * (min_sep * step))
		candidate_offsets.append((inward - perp).normalized() * (min_sep * step))

	for off: Vector3 in candidate_offsets:
		var test_p := candidate + off
		test_p.x = clampf(test_p.x, -bound, bound)
		test_p.z = clampf(test_p.z, -bound, bound)
		if not is_air:
			test_p.y = 0.0

		var ok := true
		for p: Vector3 in placed_positions:
			var d: float = test_p.distance_to(p) if is_air else Vector2(test_p.x - p.x, test_p.z - p.z).length()
			if d < min_sep:
				ok = false
				break
		if ok:
			return test_p

	# Fallback: step directly away from closest placed position into arena
	var closest_p := placed_positions[0] if not placed_positions.is_empty() else candidate
	var closest_dist := 9999.0
	for p: Vector3 in placed_positions:
		var d: float = candidate.distance_to(p) if is_air else Vector2(candidate.x - p.x, candidate.z - p.z).length()
		if d < closest_dist:
			closest_dist = d
			closest_p = p

	var away := (candidate - closest_p)
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = inward if inward.length_squared() > 0.01 else Vector3.FORWARD
	away = away.normalized()

	var fallback_pos := closest_p + away * min_sep
	fallback_pos.x = clampf(fallback_pos.x, -bound, bound)
	fallback_pos.z = clampf(fallback_pos.z, -bound, bound)
	if not is_air:
		fallback_pos.y = 0.0

	return fallback_pos

func spawn_procedural_formation(form: FormationDefinition, p_pos: Vector3, stagger: bool = true) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if not form:
		return spawned

	continuous_ground_budget -= form.ground_budget_cost
	continuous_air_budget -= form.air_budget_cost

	var g_spawn := get_authored_ground_spawn(form.formation_id, p_pos, 35.0)
	var a_spawn := get_air_corridor_entry(p_pos, 42.0, 72.0)

	var parent := _get_spawn_parent()
	var placed_positions: Array[Vector3] = []

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

			var req_rad: float = get_enemy_clearance_radius(enemy)
			var side_mult: float = 1.0 if i % 2 == 0 else -1.0
			var stagger_step: float = maxf(req_rad * 0.9, 8.0)
			var stagger_dist := float(i) * stagger_step
			var lateral_step: float = maxf(req_rad * 0.6, 6.0)
			var spawn_pos: Vector3
			if is_air:
				var p_y := clampf(_get_player_altitude(), 12.0, 18.0)
				spawn_pos = base_pos + (perp * (base_offset.x + float(i) * lateral_step) * side_mult) - (dir * stagger_dist)
				spawn_pos.y = clampf(p_y + base_offset.y, 11.0, 22.0)
			else:
				spawn_pos = base_pos + (perp * (base_offset.x + float(i) * lateral_step) * side_mult) - (dir * stagger_dist)
				spawn_pos.y = 0.0

			spawn_pos = get_clamped_formation_member_position(spawn_pos, placed_positions, req_rad, dir, is_air)
			placed_positions.append(spawn_pos)
			enemy.transform.origin = spawn_pos

			var is_first: bool = spawned.is_empty()
			var res_id := reserve_spawn_position(spawn_pos, req_rad, "air" if is_air else "ground", form.formation_id, primary_entry_sector, 4.5, form.formation_id)
			_deploy_formation_unit(enemy, parent, is_first, stagger, res_id)
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
		var scene := get_tree().current_scene
		if scene is Node3D:
			return scene
		var cur: Node = get_parent()
		while cur:
			if cur is Node3D:
				return cur
			cur = cur.get_parent()
		return get_tree().root
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
func is_spawn_position_clear(pos: Vector3, is_air: bool = false, required_radius: float = -1.0, ignore_reservation_id: String = "") -> bool:
	clean_expired_reservations()

	if required_radius < 0.0:
		required_radius = float(SEPARATION_RADII["air_default"]) if is_air else float(SEPARATION_RADII["ground_default"])

	var margin := 2.5 if is_air else 3.0
	if absf(pos.x) > (arena_half_extents - margin) or absf(pos.z) > (arena_half_extents - margin):
		return false

	var player := _get_player()
	if player:
		var flat_offset := Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z)
		var flat_dist := flat_offset.length()
		var min_safe_dist: float = 38.0 if is_air else 35.0
		if flat_dist < min_safe_dist:
			return false

		# Reject directly in player's forward arc if close
		var p_fwd := -player.global_transform.basis.z
		var p_fwd_2d := Vector2(p_fwd.x, p_fwd.z).normalized()
		if p_fwd_2d.length_squared() > 0.1 and flat_offset.length_squared() > 0.1:
			if p_fwd_2d.dot(flat_offset.normalized()) > 0.70 and flat_dist < 55.0:
				return false

	# 3D physics collision check to avoid spawning inside buildings / roadblocks
	if is_inside_tree() and get_viewport() and get_viewport().find_world_3d():
		var space: PhysicsDirectSpaceState3D = get_viewport().find_world_3d().direct_space_state
		if space:
			var shape_query := PhysicsShapeQueryParameters3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 2.0 if not is_air else 3.2
			shape_query.shape = sphere
			shape_query.collide_with_areas = false
			shape_query.collide_with_bodies = true
			shape_query.transform = Transform3D(Basis(), pos + Vector3(0, (sphere.radius + 0.15) if not is_air else 0.0, 0))
			shape_query.collision_mask = 1 # World geometry / Buildings
			var hits: Array[Dictionary] = space.intersect_shape(shape_query, 1)
			if not hits.is_empty():
				return false

	# Check separation against living enemies inside scene tree
	var live_enemies: Array = []
	if EnemyRegistry.instance:
		for e in EnemyRegistry.instance.ground_enemies:
			live_enemies.append(e)
		for e in EnemyRegistry.instance.air_enemies:
			live_enemies.append(e)
	else:
		for e in _wave_enemies:
			live_enemies.append(e)

	for enemy_node in live_enemies:
		var e: Node3D = enemy_node as Node3D
		if not is_instance_valid(e) or e.is_queued_for_deletion() or not e.is_inside_tree():
			continue
		var other_pos := e.global_position
		var other_is_air := _is_air_enemy(e)
		var other_rad := get_enemy_clearance_radius(e)
		var min_sep := maxf(required_radius, other_rad)

		if is_air or other_is_air:
			if pos.distance_to(other_pos) < min_sep:
				return false
		else:
			var flat_d := Vector2(pos.x - other_pos.x, pos.z - other_pos.z).length()
			if flat_d < min_sep:
				return false

	# Check separation against active spawn reservations
	for res: Dictionary in _active_reservations:
		if res.get("id", "") == ignore_reservation_id:
			continue
		var enemy_ref: WeakRef = res.get("enemy_ref", null)
		if enemy_ref:
			var ref_node = enemy_ref.get_ref()
			if ref_node == null or not is_instance_valid(ref_node) or ref_node.is_queued_for_deletion():
				continue
		var r_pos: Vector3 = res.get("position", Vector3.ZERO)
		var r_is_air: bool = (res.get("category", "ground") == "air")
		var r_rad: float = float(res.get("radius", 10.0))
		var min_sep := maxf(required_radius, r_rad)

		if is_air or r_is_air:
			if pos.distance_to(r_pos) < min_sep:
				return false
		else:
			var flat_d := Vector2(pos.x - r_pos.x, pos.z - r_pos.z).length()
			if flat_d < min_sep:
				return false

	# Check separation against units waiting in formation spawn queue
	for item: Dictionary in _formation_spawn_queue:
		var u: Node3D = item.get("unit", null) as Node3D
		if is_instance_valid(u) and not u.is_queued_for_deletion():
			var u_pos := u.transform.origin
			var u_is_air := _is_air_enemy(u)
			var u_rad := get_enemy_clearance_radius(u)
			var min_sep := maxf(required_radius, u_rad)

			if is_air or u_is_air:
				if pos.distance_to(u_pos) < min_sep:
					return false
			else:
				var flat_d := Vector2(pos.x - u_pos.x, pos.z - u_pos.z).length()
				if flat_d < min_sep:
					return false

	return true

func get_enemy_clearance_radius(enemy_identifier: Variant) -> float:
	if enemy_identifier is PackedScene:
		var path: String = enemy_identifier.resource_path.to_lower()
		for key: String in SEPARATION_RADII.keys():
			if key in path:
				return float(SEPARATION_RADII[key])
		return float(SEPARATION_RADII["ground_default"])
	elif enemy_identifier is String:
		var tag: String = enemy_identifier.to_lower()
		for key: String in SEPARATION_RADII.keys():
			if key in tag:
				return float(SEPARATION_RADII[key])
		return float(SEPARATION_RADII["ground_default"])
	elif enemy_identifier is Node:
		var name_str: String = enemy_identifier.name.to_lower()
		for key: String in SEPARATION_RADII.keys():
			if key in name_str or enemy_identifier.is_in_group(key):
				return float(SEPARATION_RADII[key])
		if _is_air_enemy(enemy_identifier):
			return float(SEPARATION_RADII["air_default"])
		return float(SEPARATION_RADII["ground_default"])
	return float(SEPARATION_RADII["ground_default"])

func reserve_spawn_position(pos: Vector3, radius: float, category: String, source_name: String, sector: int, duration: float = 4.5, formation_id: String = "", source_key: String = "") -> String:
	_reservation_id_seq += 1
	var res_id := "res_%d_%d" % [int(elapsed_survival_time * 100.0), _reservation_id_seq]
	var res: Dictionary = {
		"id": res_id,
		"position": pos,
		"radius": radius,
		"category": category,
		"source_name": source_name,
		"source_key": source_name if source_key.is_empty() else source_key,
		"sector": sector,
		"created_time": elapsed_survival_time,
		"expiry_time": elapsed_survival_time + duration,
		"formation_id": formation_id,
		"enemy_ref": null
	}
	_active_reservations.append(res)
	return res_id

func release_reservation(res_id: String) -> void:
	if res_id.is_empty():
		return
	for i in range(_active_reservations.size() - 1, -1, -1):
		if _active_reservations[i].get("id", "") == res_id:
			_active_reservations.remove_at(i)
			break

func has_reservation(res_id: String) -> bool:
	if res_id.is_empty():
		return false
	for res: Dictionary in _active_reservations:
		if res.get("id", "") == res_id:
			return true
	return false

func bind_enemy_to_reservation(res_id: String, enemy: Node3D) -> void:
	if res_id.is_empty() or not is_instance_valid(enemy):
		return
	for res: Dictionary in _active_reservations:
		if res.get("id", "") == res_id:
			res["enemy_ref"] = weakref(enemy)
			break
	if not enemy.tree_entered.is_connected(_on_reserved_enemy_tree_entered):
		enemy.tree_entered.connect(_on_reserved_enemy_tree_entered.bind(res_id, enemy), CONNECT_ONE_SHOT)
	if not enemy.tree_exited.is_connected(release_reservation):
		enemy.tree_exited.connect(release_reservation.bind(res_id), CONNECT_ONE_SHOT)

func _on_reserved_enemy_tree_entered(res_id: String, enemy: Node3D) -> void:
	if is_instance_valid(enemy):
		release_reservation(res_id)

func clean_expired_reservations() -> void:
	for i in range(_active_reservations.size() - 1, -1, -1):
		var res: Dictionary = _active_reservations[i]
		var enemy_ref: WeakRef = res.get("enemy_ref", null)
		if enemy_ref:
			var ref_node = enemy_ref.get_ref()
			if ref_node == null or not is_instance_valid(ref_node) or ref_node.is_queued_for_deletion():
				_active_reservations.remove_at(i)
				continue
			if is_instance_valid(ref_node) and ref_node.is_inside_tree():
				_active_reservations.remove_at(i)
				continue
		if elapsed_survival_time >= float(res.get("expiry_time", 0.0)):
			_active_reservations.remove_at(i)

func is_source_on_cooldown(source_key: String, min_cooldown: float = 6.0) -> bool:
	if not _source_cooldowns.has(source_key):
		return false
	return (elapsed_survival_time - float(_source_cooldowns[source_key])) < min_cooldown

func is_position_near_recent_spawn(pos: Vector3, min_dist: float = 18.0, window_time: float = 8.0, is_air: bool = false) -> bool:
	for entry: Dictionary in _recent_spawn_history:
		if (elapsed_survival_time - float(entry.get("time", 0.0))) < window_time:
			var prev_pos: Vector3 = entry.get("position", Vector3.ZERO)
			var d: float = pos.distance_to(prev_pos) if is_air else Vector2(pos.x - prev_pos.x, pos.z - prev_pos.z).length()
			if d < min_dist:
				return true
	return false

func record_spawn_event(source_key: String, pos: Vector3, source_name: String = "") -> void:
	_source_cooldowns[source_key] = elapsed_survival_time
	if not source_name.is_empty():
		_source_cooldowns[source_name] = elapsed_survival_time
	_recent_spawn_history.append({
		"position": pos,
		"time": elapsed_survival_time,
		"source_key": source_key
	})
	_clean_spawn_history()

func _clean_spawn_history() -> void:
	for i in range(_recent_spawn_history.size() - 1, -1, -1):
		if (elapsed_survival_time - float(_recent_spawn_history[i].get("time", 0.0))) > 12.0:
			_recent_spawn_history.remove_at(i)

func _log_spawn_event(enemy: Node3D, source_key: String, sector: int, pos: Vector3, radius: float) -> void:
	var nearest_dist := 999.0
	var is_air := _is_air_enemy(enemy)
	for other: Node3D in _wave_enemies:
		if is_instance_valid(other) and other != enemy and other.is_inside_tree():
			var d: float = pos.distance_to(other.global_position) if is_air else Vector2(pos.x - other.global_position.x, pos.z - other.global_position.z).length()
			if d < nearest_dist:
				nearest_dist = d
	for res: Dictionary in _active_reservations:
		var r_pos: Vector3 = res.get("position", Vector3.ZERO)
		if r_pos != pos:
			var d: float = pos.distance_to(r_pos) if is_air else Vector2(pos.x - r_pos.x, pos.z - r_pos.z).length()
			if d < nearest_dist:
				nearest_dist = d

	var enemy_type: String = enemy.name
	if "archetype" in enemy and enemy.archetype and "display_name" in enemy.archetype:
		enemy_type = enemy.archetype.display_name
	elif enemy.get_script():
		enemy_type = enemy.get_script().resource_path.get_file().get_basename()

	print("[SPAWN] T+%.2fs | Type: %s | Source: %s | Sector: %d | Pos: (%.1f, %.1f, %.1f) | Radius: %.1fm | Nearest: %.1fm" % [
		elapsed_survival_time, enemy_type, source_key, sector, pos.x, pos.y, pos.z, radius, nearest_dist
	])

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

func _get_safe_perimeter_fallback(player_pos: Vector3, is_air: bool = false, required_radius: float = 10.0) -> Dictionary:
	var valid_candidates: Array[Dictionary] = []
	for i in range(_safe_road_points.size()):
		var pt: Vector3 = _safe_road_points[i]
		var d := player_pos.distance_to(pt)
		if d < 35.0 or d > 120.0:
			continue
		var source_key := "SafeRoadPoint_%d" % i

		if is_source_on_cooldown(source_key, 6.0):
			continue
		if is_position_near_recent_spawn(pt, 18.0, 8.0, is_air):
			continue
		if not is_spawn_position_clear(pt, is_air, required_radius):
			continue

		var score: float = 100.0 - absf(d - 55.0) + randf_range(0.0, 20.0)
		valid_candidates.append({
			"position": pt,
			"score": score,
			"source_name": source_key,
			"source_key": source_key
		})

	if valid_candidates.is_empty():
		return {
			"success": false,
			"position": Vector3.INF,
			"heading": Vector3.FORWARD,
			"source_name": "None",
			"source_key": "None",
			"validation_result": "FAILED"
		}

	valid_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	var chosen: Dictionary = valid_candidates[0]
	var chosen_pos: Vector3 = chosen["position"]
	var hd: Vector3 = (player_pos - chosen_pos)
	hd.y = 0.0
	return {
		"success": true,
		"position": chosen_pos,
		"heading": hd.normalized() if hd.length_squared() > 0.01 else Vector3.FORWARD,
		"source_name": chosen["source_name"],
		"source_key": chosen["source_key"],
		"validation_result": "VALID"
	}

func _get_sector_spawn_position(player_pos: Vector3, sector: int, min_dist: float, max_dist: float, is_air: bool) -> Vector3:
	var base_angle := float(sector) * (TAU / 8.0)
	var req_rad := float(SEPARATION_RADII["air_default"]) if is_air else float(SEPARATION_RADII["ground_default"])
	var s_key := "Sector_%d" % sector
	for attempt in range(8):
		var angle := base_angle + randf_range(-PI / 6.0, PI / 6.0)
		var dist := randf_range(min_dist, max_dist)
		var cand := Vector3(
			clampf(player_pos.x + cos(angle) * dist, -arena_half_extents + 12.0, arena_half_extents - 12.0),
			0.0,
			clampf(player_pos.z + sin(angle) * dist, -arena_half_extents + 12.0, arena_half_extents - 12.0)
		)
		if not is_position_near_recent_spawn(cand, 18.0, 8.0, is_air) and is_spawn_position_clear(cand, is_air, req_rad):
			_record_spawn_sector(sector)
			record_spawn_event(s_key, cand)
			return cand

	var fb := _get_safe_perimeter_fallback(player_pos, is_air, req_rad)
	if fb.get("success", false):
		return fb["position"]
	return Vector3.INF

## Selects an authored ground entrance (RoadEntrance_North, RoadEntrance_South, IndustrialEntrance, MilitaryGate)
## based on player distance (min safe >= 35m), district affinity, direction alternation, and clearance.
func get_authored_ground_spawn(enemy_tag: String = "infantry", player_pos: Vector3 = Vector3.ZERO, min_dist: float = 35.0) -> Dictionary:
	var req_rad: float = get_enemy_clearance_radius(enemy_tag)
	var nodes := get_ground_spawn_nodes()
	if nodes.is_empty():
		var fb_pos := get_frustum_safe_spawn_pos(player_pos, min_dist, 65.0)
		if fb_pos == Vector3.INF:
			return { "success": false, "position": Vector3.INF, "heading": Vector3.FORWARD, "source_name": "Fallback", "validation_result": "FAILED" }
		var fb_head := (player_pos - fb_pos)
		fb_head.y = 0.0
		return { "success": true, "position": fb_pos, "heading": fb_head.normalized(), "source_name": "Fallback", "validation_result": "VALID" }

	var scored_candidates: Array[Dictionary] = []
	for marker in nodes:
		var pos := marker.global_position
		var flat_dist := Vector2(pos.x - player_pos.x, pos.z - player_pos.z).length()
		if flat_dist < min_dist:
			continue

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

		# 2. Alternation / Recency penalty
		if _recent_ground_sources.size() > 0:
			if _recent_ground_sources[-1] == m_name:
				score -= 80.0
			if _recent_ground_sources.size() > 1 and _recent_ground_sources[-2] == m_name:
				score -= 40.0

		# Real source cooldown check penalty
		if is_source_on_cooldown(m_name, 6.0):
			score -= 60.0

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

			if not is_position_near_recent_spawn(spawn_cand, 18.0, 8.0, false) and is_spawn_position_clear(spawn_cand, false, req_rad):
				_record_ground_source(marker.name)
				record_spawn_event(marker.name, spawn_cand, marker.name)
				last_spawn_source = marker.name
				var heading := (player_pos - spawn_cand)
				heading.y = 0.0
				return {
					"success": true,
					"position": spawn_cand,
					"heading": heading.normalized(),
					"source_name": marker.name,
					"source_key": marker.name,
					"validation_result": "VALID"
				}

	# Secondary pass on any valid node
	for marker in nodes:
		var pos: Vector3 = marker.global_position
		if not is_position_near_recent_spawn(pos, 18.0, 8.0, false) and is_spawn_position_clear(pos, false, req_rad):
			_record_ground_source(marker.name)
			record_spawn_event(marker.name, pos, marker.name)
			last_spawn_source = marker.name + " (Clearance Fallback)"
			var heading := (player_pos - pos)
			heading.y = 0.0
			return { "success": true, "position": pos, "heading": heading.normalized(), "source_name": marker.name, "source_key": marker.name, "validation_result": "VALID" }

	# Fallback to safe road points with full validation
	var safe_fb := _get_safe_perimeter_fallback(player_pos, false, req_rad)
	if safe_fb.get("success", false):
		last_spawn_source = "Safe Road Point Fallback"
		record_spawn_event(safe_fb["source_key"], safe_fb["position"], safe_fb["source_name"])
		return {
			"success": true,
			"position": safe_fb["position"],
			"heading": safe_fb["heading"],
			"source_name": safe_fb["source_name"],
			"source_key": safe_fb["source_key"],
			"validation_result": "VALID"
		}

	failed_spawn_attempts += 1
	return {
		"success": false,
		"position": Vector3.INF,
		"heading": Vector3.FORWARD,
		"source_name": "SafeRoadFallback",
		"source_key": "SafeRoadFallback",
		"validation_result": "FAILED"
	}

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

## Spawns stationary defense threat (Turret, SAM) on an unoccupied authored Rooftop Marker3D or procedural rooftop socket.
## Enforces active rooftop cap (<= 3) and frees marker on enemy death / tree_exited.
func spawn_rooftop_threat(stage: int, player_pos: Vector3) -> Node3D:
	if get_active_rooftop_count() >= max_active_rooftop_threats:
		return null

	var r_nodes := get_rooftop_spawn_nodes()
	var chosen_pos := Vector3.ZERO
	var chosen_marker: Marker3D = null

	var free_markers: Array[Marker3D] = []
	for marker in r_nodes:
		var occ: Variant = _occupied_rooftop_markers.get(marker)
		if occ == null or not is_instance_valid(occ) or (occ as Node).is_queued_for_deletion():
			var dist := player_pos.distance_to(marker.global_position)
			if dist >= 22.0:
				free_markers.append(marker)

	if not free_markers.is_empty():
		free_markers.shuffle()
		chosen_marker = free_markers[0]
		chosen_pos = chosen_marker.global_position
	else:
		# Query natural rooftop candidates from CityWorldStreamer
		var streamer := get_tree().get_first_node_in_group("world_streamer") if is_inside_tree() else null
		if streamer and streamer.has_method("query_natural_spawn_candidates"):
			var candidates: Array[Dictionary] = streamer.query_natural_spawn_candidates(player_pos, "rooftop", 60.0, 140.0)
			if not candidates.is_empty():
				var cand: Dictionary = candidates.pick_random()
				chosen_pos = cand.get("position", Vector3.ZERO)

	if chosen_pos == Vector3.ZERO:
		return null

	# CommunicationsTower or high stages support SAM, otherwise GroundTurret
	var scene_to_spawn: PackedScene = _scene_turret
	if stage >= 3 and (chosen_marker == null or chosen_marker.name == "CommunicationsTower") and randf() > 0.40:
		scene_to_spawn = _scene_sam

	var enemy := scene_to_spawn.instantiate() as Node3D
	if not enemy:
		return null

	enemy.transform.origin = chosen_pos
	var to_player := (player_pos - chosen_pos)
	to_player.y = 0.0
	if to_player.length_squared() > 0.1:
		enemy.rotation.y = atan2(-to_player.x, -to_player.z)

	enemy.set_meta("is_resident_defender", true)

	var parent := _get_spawn_parent()
	parent.add_child.call_deferred(enemy)
	_register_spawned_node(enemy)

	if chosen_marker:
		_occupied_rooftop_markers[chosen_marker] = enemy
		enemy.tree_exited.connect(func() -> void:
			if _occupied_rooftop_markers.get(chosen_marker) == enemy:
				_occupied_rooftop_markers.erase(chosen_marker)
		)
		last_spawn_source = "Rooftop_" + chosen_marker.name
	else:
		last_spawn_source = "Rooftop_Streamer"

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
			var p_pos: Vector3 = p.global_position if p.is_inside_tree() else p.transform.origin
			if marker.global_position.distance_to(p_pos) < 8.0:
				has_pickup_nearby = true
				break
		if not has_pickup_nearby:
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_origin.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_origin.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_origin.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_origin.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_origin.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_origin.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_origin.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_origin.is_finite():
		return []
	var spawned: Array[Node3D] = []
	var parent := _get_spawn_parent()
	var dir := approach_direction.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD

	var lead_tank: Tank = null
	var placed_positions: Array[Vector3] = []
	var min_sep: float = float(SEPARATION_RADII["tank"])

	for i in range(count):
		var offset_dist: float = float(i) * 14.0
		var raw_pos := spawn_origin - dir * offset_dist
		var pos := get_clamped_formation_member_position(raw_pos, placed_positions, min_sep, dir, false)
		placed_positions.append(pos)

		var tank := _scene_tank.instantiate() as Tank
		if tank:
			tank.transform.origin = Vector3(pos.x, 0.0, pos.z)
			if i == 0:
				tank.is_command_unit = true
				lead_tank = tank
			else:
				if lead_tank:
					lead_tank.register_escort(tank)
			var res_id := reserve_spawn_position(tank.transform.origin, min_sep, "ground", "RoadColumn_%d" % i, primary_entry_sector, 4.5, "road_column")
			_deploy_formation_unit(tank, parent, i == 0, stagger, res_id)
			spawned.append(tank)

	return spawned

func spawn_sam_nest(center_pos: Vector3, with_radar: bool = false) -> Array[Node3D]:
	# A failed safe-placement query must not create non-finite transforms.
	if not center_pos.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not center_target.is_finite():
		return []
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
	# A failed safe-placement query must not create non-finite transforms.
	if not spawn_pos.is_finite():
		return []
	var spawned: Array[Node3D] = []
	var parent := _get_spawn_parent()

	var dir := heading.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.FORWARD

	var perp := Vector3(-dir.z, 0.0, dir.x)
	var req_rad: float = float(SEPARATION_RADII["air_default"])

	if not _scene_hunter:
		_scene_hunter = load("res://scenes/enemies/hunter_helicopter.tscn") as PackedScene

	var placed_positions: Array[Vector3] = []

	var lead := _scene_hunter.instantiate() as Node3D if _scene_hunter else null
	if lead:
		var l_pos := get_clamped_formation_member_position(spawn_pos, placed_positions, req_rad, dir, true)
		lead.transform.origin = l_pos
		parent.add_child.call_deferred(lead)
		_register_spawned_node(lead)
		spawned.append(lead)
		placed_positions.append(l_pos)

	var wingman := _scene_hunter.instantiate() as Node3D if _scene_hunter else null
	if wingman:
		var wing_raw := spawn_pos + (perp * 14.0) - (dir * 12.0)
		var wing_pos := get_clamped_formation_member_position(wing_raw, placed_positions, req_rad, dir, true)
		wingman.transform.origin = wing_pos
		parent.add_child.call_deferred(wingman)
		_register_spawned_node(wingman)
		spawned.append(wingman)
		placed_positions.append(wing_pos)

	return spawned

func _spawn_enemy(scene: PackedScene, player_pos: Vector3, altitude: float) -> void:
	if not scene or not scene.can_instantiate():
		return
	var spawn_pos := get_frustum_safe_spawn_pos(player_pos, 32.0, 68.0)
	if not spawn_pos.is_finite() or not is_finite(altitude):
		return
	var enemy: Node3D = scene.instantiate() as Node3D
	if not enemy:
		return
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

func encounter_state_name() -> String:
	match encounter_state:
		EncounterState.WARMUP: return "WARMUP"
		EncounterState.STREAMING: return "STREAMING"
		EncounterState.SURGE: return "SURGE"
		EncounterState.RECOVERY: return "RECOVERY"
		_: return "UNKNOWN"

func get_debug_telemetry() -> Dictionary:
	var special_counts := {}
	var role_counts := {}
	var tier_counts := {}
	var visual_crowd := 0
	var living_nodes := 0
	if EnemyRegistry.instance:
		special_counts = EnemyRegistry.instance.get_special_counts()
		role_counts = EnemyRegistry.instance.get_role_counts()
		tier_counts = EnemyRegistry.instance.get_tier_counts()
		visual_crowd = int(EnemyRegistry.instance.get_living_visual_crowd())
		living_nodes = EnemyRegistry.instance.get_living_node_count()
	else:
		visual_crowd = int(get_living_visual_crowd())
		living_nodes = get_living_enemy_count()

	var target: Resource = get_current_wave_target()
	var vis_target_min: int = int(target.get("visual_crowd_min")) if target else 8
	var vis_target_max: int = int(target.get("visual_crowd_max")) if target else 12
	var node_cap: int = get_active_population_cap()

	return {
		"wave": current_wave,
		"encounter_state": encounter_state_name(),
		"living_nodes": living_nodes,
		"node_cap": node_cap,
		"visual_crowd": visual_crowd,
		"visual_target_min": vis_target_min,
		"visual_target_max": vis_target_max,
		"ground_budget": continuous_ground_budget,
		"air_budget": continuous_air_budget,
		"primary_entry_sector": primary_entry_sector,
		"secondary_entry_sector": secondary_entry_sector,
		"protected_escape_sectors": protected_escape_sectors.duplicate(),
		"special_counts": special_counts,
		"role_counts": role_counts,
		"tier_counts": tier_counts,
		"rejected_spawn_reasons": rejected_spawn_reasons.duplicate(),
		"total_spawns": total_enemies_spawned,
		"total_despawns": total_despawns,
	}
