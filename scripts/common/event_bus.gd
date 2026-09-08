extends Node

## Global Event Bus for decoupled communication across systems

@warning_ignore("unused_signal")
signal player_health_changed(current_health: float, max_health: float)
@warning_ignore("unused_signal")
signal player_died()
@warning_ignore("unused_signal")
signal chaingun_heat_changed(current_heat: float, max_heat: float, is_overheated: bool)
@warning_ignore("unused_signal")
signal target_acquired(target: Node3D)
@warning_ignore("unused_signal")
signal target_lost()
@warning_ignore("unused_signal")
signal manual_aim_state_changed(is_manual: bool)
@warning_ignore("unused_signal")
signal enemy_destroyed(enemy: Node3D, points: int)
@warning_ignore("unused_signal")
signal game_paused(is_paused: bool)
@warning_ignore("unused_signal")
signal camera_shake_requested(trauma_amount: float)

# --- Weapons & Defense ---
@warning_ignore("unused_signal")
signal missile_lock_updated(progress: float, target: Node3D, is_locked: bool)
@warning_ignore("unused_signal")
signal missile_fired()
@warning_ignore("unused_signal")
signal missile_ammo_changed(current: int, maximum: int)
@warning_ignore("unused_signal")
signal no_missiles_warning()
@warning_ignore("unused_signal")
signal missile_pickup_collected(amount: int)
@warning_ignore("unused_signal")
signal flares_updated(charges_left: int, max_charges: int, is_ready: bool)
@warning_ignore("unused_signal")
signal incoming_missile_warning(source_pos: Vector3, is_active: bool)

# --- Progression & Director ---
@warning_ignore("unused_signal")
signal xp_updated(current_xp: int, next_xp: int, level: int)
@warning_ignore("unused_signal")
signal level_up_requested(level: int)
@warning_ignore("unused_signal")
signal upgrade_applied(upgrade_id: String)
@warning_ignore("unused_signal")
signal wave_started(wave_num: int, announcement: String)
@warning_ignore("unused_signal")
signal wave_completed(wave_num: int)
@warning_ignore("unused_signal")
signal wave_progress_updated(remaining: int, total: int)
@warning_ignore("unused_signal")
signal radar_status_changed(is_active: bool)
@warning_ignore("unused_signal")
signal jammer_status_changed(is_jammed: bool, count: int)
@warning_ignore("unused_signal")
signal command_unit_destroyed(pos: Vector3)
@warning_ignore("unused_signal")
signal extraction_decision_requested(salvage_amount: int)
@warning_ignore("unused_signal")
signal endless_mode_entered()
@warning_ignore("unused_signal")
signal boss_spawned(boss_node: Node3D)
@warning_ignore("unused_signal")
signal boss_health_changed(current: float, maximum: float, phase: int)
@warning_ignore("unused_signal")
signal boss_defeated()
@warning_ignore("unused_signal")
signal salvage_updated(run_salvage: int)
@warning_ignore("unused_signal")
signal damage_number_spawned(pos: Vector3, amount: float, is_critical: bool)
@warning_ignore("unused_signal")
signal border_warning_changed(is_warning: bool, return_direction: Vector3, distance_to_edge: float)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_default_inputs()

func _setup_default_inputs() -> void:
	_add_action_key("move_forward", KEY_W)
	_add_action_key("move_forward", KEY_UP)
	_add_action_key("move_backward", KEY_S)
	_add_action_key("move_backward", KEY_DOWN)
	_add_action_key("move_left", KEY_A)
	_add_action_key("move_left", KEY_LEFT)
	_add_action_key("move_right", KEY_D)
	_add_action_key("move_right", KEY_RIGHT)

	_add_action_key("strafe_left", KEY_Q)
	_add_action_key("strafe_right", KEY_E)

	_add_action_key("ascend", KEY_SPACE)
	_add_action_key("descend", KEY_SHIFT)
	_add_action_key("descend", KEY_C)

	_add_action_mouse("fire_primary", MOUSE_BUTTON_LEFT)
	_add_action_mouse("aim_override", MOUSE_BUTTON_RIGHT)
	_add_action_key("fire_secondary", KEY_F)
	_add_action_mouse("fire_secondary", MOUSE_BUTTON_RIGHT)
	_add_action_key("countermeasure_flares", KEY_X)

	_add_action_key("camera_orbit_left", KEY_J)
	_add_action_key("camera_orbit_right", KEY_L)
	_add_action_key("camera_recenter", KEY_R)
	_add_action_key("pause", KEY_ESCAPE)

func _add_action_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_action_mouse(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)
