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
signal kills_updated(total_kills: int)
@warning_ignore("unused_signal")
signal score_updated(total_score: int, points_earned: int, multiplier: float, combo_streak: int)
@warning_ignore("unused_signal")
signal combo_timer_updated(time_remaining: float, max_time: float, multiplier: float)
@warning_ignore("unused_signal")
signal attack_run_state_changed(is_active: bool, duration: float, max_duration: float)
@warning_ignore("unused_signal")
signal attack_run_cooldown_updated(current: float, maximum: float)
@warning_ignore("unused_signal")
signal hover_hazard_state_changed(is_hazard: bool)
@warning_ignore("unused_signal")
signal game_paused(is_paused: bool)
@warning_ignore("unused_signal")
signal camera_shake_requested(trauma_amount: float)

# --- Weapons & Defense ---
@warning_ignore("unused_signal")
signal player_fired_primary(muzzle_pos: Vector3, dir: Vector3)
@warning_ignore("unused_signal")
signal enemy_fired_weapon(enemy: Node3D, muzzle_pos: Vector3, dir: Vector3, is_heavy: bool)
@warning_ignore("unused_signal")
signal combat_impact_occurred(hit_pos: Vector3, normal: Vector3, is_armored: bool, is_lethal: bool)
@warning_ignore("unused_signal")
signal player_damaged_directional(amount: float, hit_pos: Vector3, source_pos: Vector3, is_shield_hit: bool)
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
@warning_ignore("unused_signal")
signal missile_impact_occurred(impact_pos: Vector3, is_player: bool)
@warning_ignore("unused_signal")
signal wingmen_status_updated(alive_count: int, max_count: int)
@warning_ignore("unused_signal")
signal defense_status_updated(armor_pct: float, repair_rate: float, aegis_ready: bool, aegis_cd: float)

# --- Evasive & Rescue Mechanics ---
@warning_ignore("unused_signal")
signal player_evaded()
@warning_ignore("unused_signal")
signal evade_cooldown_updated(current: float, maximum: float)
@warning_ignore("unused_signal")
signal survivor_collected(current_passengers: int, max_capacity: int)
@warning_ignore("unused_signal")
signal survivors_evacuated(count: int, heal_amount: float, salvage_amount: int)

# --- Progression & Director ---
@warning_ignore("unused_signal")
signal xp_collected(amount: int)
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
signal mission_offered(mission_id: String, title: String)
@warning_ignore("unused_signal")
signal mission_started(mission_id: String, title: String, description: String, target_pos: Vector3)
@warning_ignore("unused_signal")
signal mission_updated(mission_id: String, title: String, detail_text: String, progress: float)
@warning_ignore("unused_signal")
signal mission_completed(mission_id: String, title: String, reward_text: String)
@warning_ignore("unused_signal")
signal mission_failed(mission_id: String, title: String, reason: String)
@warning_ignore("unused_signal")
signal extraction_decision_requested(salvage_amount: int)
@warning_ignore("unused_signal")
signal run_completed()
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
signal damage_number_spawned(pos: Vector3, amount: float, is_critical: bool, metadata: Dictionary)
@warning_ignore("unused_signal")
signal border_warning_changed(is_warning: bool, return_direction: Vector3, distance_to_edge: float)
@warning_ignore("unused_signal")
signal setting_changed(setting_name: String, new_value: Variant)
@warning_ignore("unused_signal")
signal ammo_full_notified()
@warning_ignore("unused_signal")
signal hull_full_notified()

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
	_add_action_joypad_button("strafe_left", JOY_BUTTON_LEFT_SHOULDER)
	_add_action_joypad_button("strafe_right", JOY_BUTTON_RIGHT_SHOULDER)

	_add_action_key("ascend", KEY_SPACE)
	_add_action_key("descend", KEY_SHIFT)
	_add_action_key("descend", KEY_C)
	_add_action_joypad_button("ascend", JOY_BUTTON_A)
	_add_action_joypad_button("descend", JOY_BUTTON_B)
	_add_action_joypad_button("heli_climb", JOY_BUTTON_A)
	_add_action_joypad_button("heli_descend", JOY_BUTTON_B)

	_add_action_mouse("fire_primary", MOUSE_BUTTON_LEFT)
	_add_action_joypad_motion("fire_primary", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_action_joypad_button("fire_primary", JOY_BUTTON_RIGHT_SHOULDER)

	_add_action_mouse("fire_secondary", MOUSE_BUTTON_RIGHT)
	_add_action_key("fire_secondary", KEY_F)
	_add_action_joypad_button("fire_secondary", JOY_BUTTON_X)

	_add_action_key("countermeasure_flares", KEY_X)
	_add_action_joypad_button("countermeasure_flares", JOY_BUTTON_Y)

	# Dedicated aim_override actions (Shift key, Middle Mouse, Gamepad LT / LB)
	_add_action_key("aim_override", KEY_SHIFT)
	_add_action_mouse("aim_override", MOUSE_BUTTON_MIDDLE)
	_add_action_joypad_motion("aim_override", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_action_joypad_button("aim_override", JOY_BUTTON_LEFT_SHOULDER)

	# Tactical Evade / Barrel Roll:
	# Purge conflicting Space and Joypad B events so altitude controls don't trigger evade
	if InputMap.has_action("evade"):
		for existing in InputMap.action_get_events("evade"):
			if existing is InputEventKey and existing.physical_keycode == KEY_SPACE:
				InputMap.action_erase_event("evade", existing)
			elif existing is InputEventJoypadButton and existing.button_index == JOY_BUTTON_B:
				InputMap.action_erase_event("evade", existing)
	_add_action_key("evade", KEY_ALT)
	_add_action_key("evade", KEY_Z)
	_add_action_joypad_button("evade", JOY_BUTTON_LEFT_STICK)
	_add_action_joypad_button("evade", JOY_BUTTON_RIGHT_STICK)

	# Dual-stick aim axes
	_add_action_joypad_motion("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_action_joypad_motion("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_action_joypad_motion("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_action_joypad_motion("aim_down", JOY_AXIS_RIGHT_Y, 1.0)

	# Flight throttle & turn axes for gamepad left stick
	_add_action_joypad_motion("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_action_joypad_motion("move_backward", JOY_AXIS_LEFT_Y, 1.0)
	_add_action_joypad_motion("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_action_joypad_motion("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_action_joypad_motion("heli_throttle_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_action_joypad_motion("heli_throttle_reverse", JOY_AXIS_LEFT_Y, 1.0)
	_add_action_joypad_motion("heli_turn_left", JOY_AXIS_LEFT_X, -1.0)
	_add_action_joypad_motion("heli_turn_right", JOY_AXIS_LEFT_X, 1.0)

	# UI navigation with Gamepad
	_add_action_joypad_button("ui_accept", JOY_BUTTON_A)
	_add_action_joypad_button("ui_cancel", JOY_BUTTON_B)

	_add_action_key("camera_orbit_left", KEY_J)
	_add_action_key("camera_orbit_right", KEY_L)
	_add_action_key("camera_recenter", KEY_R)
	_add_action_joypad_button("camera_recenter", JOY_BUTTON_BACK)
	_add_action_key("pause", KEY_ESCAPE)
	_add_action_joypad_button("pause", JOY_BUTTON_START)

func _add_action_key(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _add_action_mouse(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventMouseButton and existing.button_index == button_index:
			return
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)

func _add_action_joypad_button(action: StringName, button_index: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == button_index:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)

func _add_action_joypad_motion(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion and existing.axis == axis and signf(existing.axis_value) == signf(axis_value):
			return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	InputMap.action_add_event(action, ev)
