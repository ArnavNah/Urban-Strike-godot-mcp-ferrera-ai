class_name DebugCanvas
extends CanvasLayer

## Responsive, Godot-native debug & telemetry overlay.
## Displays real-time horde director state, active enemy breakdowns, player vitals,
## and engine performance metrics. Updates at 8 Hz via internal Timer.
## Toggle with [F3] or [~].

@export var update_frequency_hz: float = 8.0
@export var toggle_action: String = "toggle_debug"

# UI Labels (Unique Name references in Control hierarchy)
@onready var debug_root: Control = %DebugRoot
@onready var active_target_val: Label = %ActiveTargetVal
@onready var budget_val: Label = %BudgetVal
@onready var stage_cap_val: Label = %StageCapVal
@onready var last_formation_val: Label = %LastFormationVal
@onready var last_spawn_node_val: Label = %LastSpawnNodeVal
@onready var failed_spawns_val: Label = %FailedSpawnsVal

@onready var ground_count_val: Label = %GroundCountVal
@onready var air_count_val: Label = %AirCountVal
@onready var sam_count_val: Label = %SamCountVal
@onready var elites_count_val: Label = %ElitesCountVal

@onready var hull_hp_val: Label = %HullHpVal
@onready var level_xp_val: Label = %LevelXpVal
@onready var missile_ammo_val: Label = %MissileAmmoVal
@onready var heat_val: Label = %HeatVal

@onready var survival_time_val: Label = %SurvivalTimeVal
@onready var fps_val: Label = %FpsVal

@onready var update_timer: Timer = $UpdateTimer

func _ready() -> void:
	layer = 105
	if update_timer:
		update_timer.wait_time = 1.0 / maxf(1.0, update_frequency_hz)
		update_timer.timeout.connect(_update_telemetry)
		if not update_timer.is_stopped():
			update_timer.start()

	# Start hidden in normal release gameplay, or toggleable with F3
	if debug_root:
		debug_root.visible = false
	_update_telemetry()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or event.keycode == KEY_QUOTELEFT:
			toggle_overlay()
			get_viewport().set_input_as_handled()

func toggle_overlay() -> void:
	if debug_root:
		debug_root.visible = not debug_root.visible

func _update_telemetry() -> void:
	if not is_inside_tree():
		return
	if debug_root and not debug_root.visible:
		return

	# 1. Performance & Runtime
	if fps_val:
		var fps := Engine.get_frames_per_second()
		fps_val.text = "%d FPS" % fps
		if fps >= 55:
			fps_val.modulate = Color(0.3, 0.95, 0.5)
		elif fps >= 30:
			fps_val.modulate = Color(1.0, 0.85, 0.3)
		else:
			fps_val.modulate = Color(1.0, 0.3, 0.3)

	# 2. Spawn Director info
	var sd := get_tree().get_first_node_in_group("spawn_director") as SpawnDirector
	if sd:
		if survival_time_val:
			var total_sec := int(sd.elapsed_survival_time)
			var m := int(float(total_sec) / 60.0)
			var s := total_sec % 60
			survival_time_val.text = "%02d:%02d" % [m, s]

		if active_target_val:
			var living := sd.get_living_enemy_count()
			var target := sd.get_target_active_count()
			active_target_val.text = "%d / %d" % [living, target]
			active_target_val.modulate = Color(1.0, 0.4, 0.4) if living < target else Color(0.3, 0.9, 0.5)

		if budget_val:
			budget_val.text = "G: %3.0f | A: %3.0f" % [sd.continuous_ground_budget, sd.continuous_air_budget]

		if stage_cap_val:
			stage_cap_val.text = "Stage %d (Cap: %d)" % [sd.get_survival_stage(), sd.get_active_population_cap()]

		if last_formation_val:
			last_formation_val.text = sd.last_formation_name

		if last_spawn_node_val:
			last_spawn_node_val.text = sd.last_spawn_source

		if failed_spawns_val:
			failed_spawns_val.text = "%d rejected" % sd.failed_spawn_attempts

	# 3. Enemy Breakdown
	if EnemyRegistry.instance:
		if ground_count_val:
			ground_count_val.text = str(EnemyRegistry.instance.get_ground_count())
		if air_count_val:
			air_count_val.text = str(EnemyRegistry.instance.get_air_count())

	var sams := get_tree().get_nodes_in_group("sam_sites")
	var active_sams: int = 0
	for sam in sams:
		if is_instance_valid(sam) and not sam.is_queued_for_deletion():
			if not ("is_alive" in sam) or sam.is_alive:
				active_sams += 1
	if sam_count_val:
		sam_count_val.text = str(active_sams)

	var elites := get_tree().get_nodes_in_group("elites")
	var active_elites: int = 0
	for el in elites:
		if is_instance_valid(el) and not el.is_queued_for_deletion():
			if not ("is_alive" in el) or el.is_alive:
				active_elites += 1
	if elites_count_val:
		elites_count_val.text = str(active_elites)

	# 4. Player Vitals
	var player := get_tree().get_first_node_in_group("player") as PlayerHelicopter
	if player and is_instance_valid(player):
		if hull_hp_val:
			hull_hp_val.text = "%3.0f / %3.0f" % [player.current_health, player.max_health]
		if missile_ammo_val:
			if "current_missiles" in player and "max_missiles" in player:
				missile_ammo_val.text = "%d / %d" % [player.current_missiles, player.max_missiles]
			else:
				missile_ammo_val.text = "ONLINE"
		if heat_val:
			var cg := player.get_node_or_null("GunMount/GunYawPivot/GunPitchPivot/Chaingun")
			if cg and "current_heat" in cg:
				heat_val.text = "%2.0f%%" % (float(cg.current_heat) * 100.0)
			else:
				heat_val.text = "0%"

	var um := get_tree().get_first_node_in_group("upgrade_manager")
	if um:
		if level_xp_val:
			var lvl: int = um.current_level if "current_level" in um else 1
			var cur_xp: int = um.current_xp if "current_xp" in um else 0
			var req_xp: int = um.xp_to_next_level if "xp_to_next_level" in um else 100
			level_xp_val.text = "LVL %d (%d / %d XP)" % [lvl, cur_xp, req_xp]
