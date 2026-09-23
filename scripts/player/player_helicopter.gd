class_name PlayerHelicopter
extends CharacterBody3D

## AH-9 Vulture attack helicopter controller.
## Fast, responsive arcade flight physics with decoupled visual pitch and banking.
## CharacterBody3D collider stays strictly upright while FlightTiltPivot handles visual tilt.

signal health_changed(current: float, maximum: float)
signal died()

@export_category("Arcade Flight")
@export var max_forward_speed: float = 38.0 # ~137 KPH
@export var reverse_speed_scale: float = 0.65
@export var strafe_speed: float = 28.0
@export var active_velocity_response: float = 7.5
@export var release_velocity_response: float = 5.5
@export var max_yaw_rate: float = 3.2 # rad/s
@export var yaw_input_response: float = 6.5
@export var yaw_release_response: float = 8.0
@export var climb_speed: float = 14.0
@export var vertical_input_response: float = 14.0
@export var vertical_release_response: float = 11.0
@export var minimum_altitude: float = 3.6
@export var maximum_altitude: float = 90.0

@export_category("Flight Tilt")
@export var forward_pitch_degrees: float = 16.0
@export var reverse_pitch_degrees: float = 11.0
@export var turn_bank_degrees: float = 24.0
@export var strafe_bank_degrees: float = 22.0
@export var velocity_bank_degrees: float = 10.0
@export var maximum_bank_degrees: float = 34.0
@export var tilt_input_response: float = 7.5
@export var tilt_release_response: float = 6.0
@export var quick_tilt_response: float = 8.0
@export var quick_tilt_release: float = 6.5

@export_category("Rotors")
@export var main_rotor_speed: float = 48.0
@export var tail_rotor_speed: float = 72.0

@export_category("Combat & Systems")
@export var max_health: float = 100.0
@export var gun_traverse_speed: float = 38.0
@export var magnet_radius: float = 18.0

# Backwards compatibility accessors for other systems
var max_speed: float:
	get: return max_forward_speed
var min_altitude: float:
	get: return minimum_altitude
var max_altitude: float:
	get: return maximum_altitude
var visual_roll: float:
	get: return current_visual_bank
var visual_pitch: float:
	get: return current_visual_pitch
var acceleration_stat: float = 42.0

var current_health: float = 100.0
var armor_reduction: float = 0.0 # Damage reduction percentage (capped at 60%)
var repair_drone_enabled: bool = false
var repair_rate: float = 4.0
var _time_since_damage: float = 0.0
var _repair_drone_healed_accum: float = 0.0
var has_aegis_shield: bool = false
var _aegis_cooldown: float = 0.0

# Legendary Upgrades
var has_ghost_rotor: bool = false
var ghost_rotor_cooldown: float = 12.0
var _ghost_rotor_timer: float = 0.0
var has_one_more_pass: bool = false
var one_more_pass_used: bool = false

# Phase 10B Player-Damage Fairness & Post-Hit Invulnerability (i-frames)
@export var invulnerability_duration: float = 0.35
var _invulnerability_timer: float = 0.0
var _recent_damaging_sources: Dictionary = {} # Maps Variant -> float (expiry)

var is_alive: bool = true
var active_loadout_id: String = "balanced"
var _control_enabled: bool = true
var _is_dying: bool = false

# State variables
var current_yaw_rate: float = 0.0
var current_visual_pitch: float = 0.0
var current_visual_bank: float = 0.0
var hover_time: float = 0.0
var _base_tilt_rotation: Vector3 = Vector3.ZERO
var _recoil_offset: float = 0.0
var _base_gun_mount_pos: Vector3 = Vector3(0.0, -1.25, -2.60)
var _current_main_speed: float = 48.0
var _current_tail_speed: float = 72.0
var _smoothed_throttle: float = 0.0
var _smoothed_strafe: float = 0.0

# Node references
static var instance: PlayerHelicopter = null
var _magnet_fallback_timer: float = 0.0
var _hull_full_notify_cooldown: float = 0.0

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

@onready var flight_tilt_pivot: Node3D = $FlightTiltPivot
@onready var visuals: Node3D = $FlightTiltPivot/VisualRig
@onready var main_rotor: Node3D = $FlightTiltPivot/VisualRig/MainRotorPivot
@onready var tail_rotor: Node3D = $FlightTiltPivot/VisualRig/TailRotorPivot
@onready var stable_tracking_point: Marker3D = $StableTrackingPoint
@onready var gun_mount: Node3D = $FlightTiltPivot/VisualRig/GunMount
@onready var gun_yaw_pivot: Node3D = $FlightTiltPivot/VisualRig/GunMount/GunYawPivot
@onready var gun_pitch_pivot: Node3D = $FlightTiltPivot/VisualRig/GunMount/GunYawPivot/GunPitchPivot
@onready var chaingun: Node3D = $FlightTiltPivot/VisualRig/GunMount/GunYawPivot/GunPitchPivot/Chaingun
@onready var missile_pod: Node3D = $FlightTiltPivot/VisualRig/StubWings/MissilePod
@onready var flare_dispenser: Node3D = $FlightTiltPivot/VisualRig/FlareDispenser
@onready var targeting_system: TargetingSystem = $TargetingSystem
@onready var ground_ray: RayCast3D = $GroundRayCast
@onready var ground_shadow: MeshInstance3D = $GroundShadow
@onready var downwash_dust: GPUParticles3D = $DownwashDust
@onready var xp_magnet_area: Area3D = get_node_or_null("XPMagnetArea")
@onready var xp_collect_area: Area3D = get_node_or_null("XPCollectArea")

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	current_health = max_health
	_apply_hangar_upgrades()

	if flight_tilt_pivot:
		_base_tilt_rotation = flight_tilt_pivot.rotation
	if gun_mount:
		_base_gun_mount_pos = gun_mount.position
	_current_main_speed = main_rotor_speed
	_current_tail_speed = tail_rotor_speed

	global_position.y = clampf(global_position.y, minimum_altitude, maximum_altitude)
	reset_physics_interpolation()

	if EventBus:
		EventBus.player_health_changed.emit(current_health, max_health)
		if missile_pod:
			EventBus.missile_ammo_changed.emit(missile_pod.current_missiles, missile_pod.max_missiles)
	if chaingun and chaingun.has_signal("fired"):
		chaingun.fired.connect(_on_chaingun_fired)

	if xp_magnet_area:
		var col := xp_magnet_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is CylinderShape3D:
			(col.shape as CylinderShape3D).radius = magnet_radius
		if not xp_magnet_area.area_entered.is_connected(_on_xp_magnet_area_entered):
			xp_magnet_area.area_entered.connect(_on_xp_magnet_area_entered)
	if xp_collect_area:
		var col_shape := xp_collect_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col_shape and col_shape.shape is CylinderShape3D:
			(col_shape.shape as CylinderShape3D).height = 40.0
			(col_shape.shape as CylinderShape3D).radius = 3.5
		if not xp_collect_area.area_entered.is_connected(_on_xp_collect_area_entered):
			xp_collect_area.area_entered.connect(_on_xp_collect_area_entered)

func _on_xp_magnet_area_entered(area: Area3D) -> void:
	if not is_instance_valid(area) or area.is_queued_for_deletion():
		return
	if area.has_method("can_collect") and not area.can_collect(self):
		return
	if area.has_method("magnetize_to"):
		area.magnetize_to(self)
	elif area.has_method("set_magnet_target"):
		area.set_magnet_target(self)

func _on_xp_collect_area_entered(area: Area3D) -> void:
	if not is_instance_valid(area) or area.is_queued_for_deletion():
		return
	if area.has_method("can_collect") and not area.can_collect(self):
		return

	# State guard: Items with a state machine must first be magnetized and travel to the cabin,
	# unless they are already directly within close-range cabin reach.
	if "current_state" in area:
		var state = area.get("current_state")
		if state == 0: # State.IDLE == 0
			var tracking_pos := global_position + Vector3(0.0, 1.2, 0.0)
			if has_node("StableTrackingPoint"):
				var marker: Node3D = get_node("StableTrackingPoint") as Node3D
				if marker:
					tracking_pos = marker.global_position
			var to_pickup := area.global_position - tracking_pos
			var flat_d := Vector2(to_pickup.x, to_pickup.z).length()
			# Close-range skid hover: collect immediately
			if flat_d <= 3.8 and to_pickup.y >= -2.0 and to_pickup.y <= 5.5:
				pass # Fall through to collect below
			else:
				# Not close enough for direct collection: magnetize instead of silently dropping
				if area.has_method("magnetize_to"):
					area.magnetize_to(self)
				elif area.has_method("set_magnet_target"):
					area.set_magnet_target(self)
				return

	if area.has_method("collect"):
		area.collect(self)
	elif area.has_method("_try_collect"):
		area.call("_try_collect", self)
	elif area.has_method("_collect"):
		area._collect()

func _apply_hangar_upgrades() -> void:
	var loadout_id := SaveSystem.get_selected_loadout()
	_apply_loadout(loadout_id)

	var data := SaveSystem.load_data()
	var upgrades: Dictionary = data.get("upgrades", {})
	var armor_lvl := int(upgrades.get("rotor_armor", 0))
	var extra_hp := float(armor_lvl) * 20.0
	max_health += extra_hp
	current_health = max_health
	armor_reduction = clampf(armor_reduction + float(armor_lvl) * 0.05, 0.0, 0.40)

	var extra_magnet := int(upgrades.get("magnet_radius", 0)) * 6.0
	magnet_radius += extra_magnet
	if xp_magnet_area:
		var col := xp_magnet_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is CylinderShape3D:
			(col.shape as CylinderShape3D).radius = magnet_radius

func _apply_loadout(loadout_id: String) -> void:
	active_loadout_id = loadout_id
	var loadout := LoadoutDefinition.get_loadout(loadout_id)
	max_health = loadout.max_health
	current_health = max_health
	max_forward_speed = loadout.forward_speed
	strafe_speed = loadout.strafe_speed
	active_velocity_response = loadout.active_response

	if chaingun:
		chaingun.fire_rate = loadout.chaingun_fire_rate
		chaingun.damage_per_shot = loadout.chaingun_damage
	if missile_pod:
		missile_pod.fire_cooldown = loadout.missile_cooldown
	if flare_dispenser:
		flare_dispenser.recharge_time = loadout.flare_recharge

	if loadout.passive_repair_rate > 0.0:
		repair_drone_enabled = true
		repair_rate = loadout.passive_repair_rate

	if loadout.starts_with_wingman:
		_spawn_starting_wingman.call_deferred()

func _spawn_starting_wingman() -> void:
	var mini_scene: PackedScene = load("res://scenes/companions/mini_helicopter.tscn")
	if not mini_scene:
		return
	var spawn_parent: Node = get_parent() if get_parent() else get_tree().current_scene
	if not spawn_parent:
		spawn_parent = get_tree().root

	var offset := Vector3(-8.2, 0.6, 3.8)
	var drone: MiniHelicopter = mini_scene.instantiate() as MiniHelicopter
	if drone:
		drone.slot_id = "left"
		drone.player_target = self
		drone.set_formation_slot(offset, "left")
		spawn_parent.add_child(drone)
		var yaw_basis: Basis = MiniHelicopter.get_player_yaw_basis(self)
		var start_pos: Vector3 = global_position + (yaw_basis * Vector3(offset.x, 0.0, offset.z)) + Vector3(0.0, offset.y, 0.0)
		drone.global_position = start_pos

func heal(amount: float) -> float:
	if not is_alive or _is_dying or amount <= 0.0:
		return 0.0
	if current_health >= max_health:
		if _hull_full_notify_cooldown <= 0.0 and EventBus and EventBus.has_signal("hull_full_notified"):
			EventBus.hull_full_notified.emit()
			_hull_full_notify_cooldown = 2.0
		return 0.0
	var actual_heal: float = minf(amount, max_health - current_health)
	current_health = clampf(current_health + actual_heal, 0.0, max_health)
	emit_signal("health_changed", current_health, max_health)
	if EventBus:
		EventBus.player_health_changed.emit(current_health, max_health)
		if actual_heal > 0.0 and EventBus.has_signal("damage_number_spawned"):
			EventBus.damage_number_spawned.emit(global_position + Vector3(0.0, 1.2, 0.0), actual_heal, false, {
				"target_id": get_instance_id(),
				"is_heal": true,
				"is_player": true
			})
	return actual_heal

func add_armor_reduction(amount: float) -> void:
	armor_reduction = clampf(armor_reduction + amount, 0.0, 0.60)

func exp_weight(response: float, delta: float) -> float:
	return 1.0 - exp(-response * delta)

# Alias for legacy compatibility
func exp_response(rate: float, delta: float) -> float:
	return exp_weight(rate, delta)

func _process(delta: float) -> void:
	_handle_rotor_animations(delta)
	var tail_light := get_node_or_null("FlightTiltPivot/VisualRig/NavLightTail") as MeshInstance3D
	if tail_light:
		tail_light.visible = fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.15

func _handle_rotor_animations(delta: float) -> void:
	var target_main := main_rotor_speed
	var target_tail := tail_rotor_speed
	if _is_dying or not is_alive:
		_current_main_speed = move_toward(_current_main_speed, 0.0, 40.0 * delta)
		_current_tail_speed = move_toward(_current_tail_speed, 0.0, 60.0 * delta)
	else:
		var throttle_in := Input.get_axis("heli_throttle_reverse", "heli_throttle_forward")
		if absf(throttle_in) < 0.001:
			throttle_in = Input.get_axis("move_backward", "move_forward")
		var collective_in := Input.get_axis("heli_descend", "heli_climb")
		if absf(collective_in) < 0.001:
			collective_in = Input.get_axis("descend", "ascend")
		var power_boost := 1.0 + 0.15 * clampf(absf(throttle_in) + absf(collective_in), 0.0, 1.0)
		target_main *= power_boost
		target_tail *= power_boost
		_current_main_speed = lerp(_current_main_speed, target_main, exp_weight(8.0, delta))
		_current_tail_speed = lerp(_current_tail_speed, target_tail, exp_weight(8.0, delta))

	if main_rotor and _current_main_speed > 0.001:
		main_rotor.rotate_y(_current_main_speed * delta)
	if tail_rotor and _current_tail_speed > 0.001:
		tail_rotor.rotate_x(_current_tail_speed * delta)

func _physics_process(delta: float) -> void:
	if not is_alive or not _control_enabled or _is_dying:
		return

	if has_aegis_shield and _aegis_cooldown > 0.0:
		_aegis_cooldown -= delta
	if has_ghost_rotor and _ghost_rotor_timer > 0.0:
		_ghost_rotor_timer -= delta
	if _invulnerability_timer > 0.0:
		_invulnerability_timer = maxf(0.0, _invulnerability_timer - delta)

	if _recent_damaging_sources.size() > 0:
		var expired_sources: Array = []
		for src in _recent_damaging_sources.keys():
			_recent_damaging_sources[src] -= delta
			if _recent_damaging_sources[src] <= 0.0:
				expired_sources.append(src)
		for exp_src in expired_sources:
			_recent_damaging_sources.erase(exp_src)

	_handle_flight_movement(delta)
	_handle_visual_tilt(delta)
	_handle_gun_aim(delta)
	_handle_weapons()
	_handle_ground_fx()
	_handle_magnet()
	_handle_repair_drone(delta)

func enable_repair_drone(rate: float = 4.0) -> void:
	repair_drone_enabled = true
	repair_rate = rate

func enable_aegis_shield() -> void:
	has_aegis_shield = true

func enable_ghost_rotor(cooldown: float = 12.0) -> void:
	has_ghost_rotor = true
	ghost_rotor_cooldown = cooldown
	_ghost_rotor_timer = 0.0

func enable_one_more_pass() -> void:
	has_one_more_pass = true
	one_more_pass_used = false

func reset_legendaries() -> void:
	has_ghost_rotor = false
	_ghost_rotor_timer = 0.0
	has_one_more_pass = false
	one_more_pass_used = false

func _handle_repair_drone(delta: float) -> void:
	_time_since_damage += delta
	if not repair_drone_enabled or current_health >= max_health:
		if _repair_drone_healed_accum > 0.0:
			if EventBus and EventBus.has_signal("damage_number_spawned"):
				EventBus.damage_number_spawned.emit(global_position + Vector3(0.0, 1.2, 0.0), _repair_drone_healed_accum, false, {
					"target_id": get_instance_id(),
					"is_heal": true,
					"is_player": true
				})
			_repair_drone_healed_accum = 0.0
		return
	if is_instance_valid(chaingun) and chaingun.is_overheated:
		return
	# Only heal for the portion of this frame after the five-second delay.
	var healing_delta := minf(delta, maxf(0.0, _time_since_damage - 5.0))
	if healing_delta <= 0.0:
		return
	var heal_amount := repair_rate * healing_delta
	var prev_health := current_health
	current_health = minf(max_health, current_health + heal_amount)
	var actual_healed := current_health - prev_health
	_repair_drone_healed_accum += actual_healed
	if _repair_drone_healed_accum >= 2.0 or current_health >= max_health:
		if EventBus and EventBus.has_signal("damage_number_spawned"):
			EventBus.damage_number_spawned.emit(global_position + Vector3(0.0, 1.2, 0.0), _repair_drone_healed_accum, false, {
				"target_id": get_instance_id(),
				"is_heal": true,
				"is_player": true
			})
		_repair_drone_healed_accum = 0.0
	health_changed.emit(current_health, max_health)
	if EventBus:
		EventBus.player_health_changed.emit(current_health, max_health)

## Periodic magnet fallback polling: catches pickups that spawned inside the magnet area
## after the initial area_entered signal, or that became eligible after initial rejection.
func _handle_magnet() -> void:
	_magnet_fallback_timer -= get_physics_process_delta_time()
	if _hull_full_notify_cooldown > 0.0:
		_hull_full_notify_cooldown -= get_physics_process_delta_time()
	if _magnet_fallback_timer > 0.0:
		return
	_magnet_fallback_timer = 0.25

	if not xp_magnet_area or not is_alive:
		return

	var overlapping: Array[Area3D] = xp_magnet_area.get_overlapping_areas()
	for area in overlapping:
		if not is_instance_valid(area) or area.is_queued_for_deletion():
			continue
		# Only magnetize idle pickups that haven't been collected
		if "current_state" in area:
			var state = area.get("current_state")
			if state != 0: # Not IDLE
				continue
		if area.has_method("can_collect") and not area.can_collect(self):
			continue
		if area.has_method("magnetize_to"):
			area.magnetize_to(self)
		elif area.has_method("set_magnet_target"):
			area.set_magnet_target(self)

func _handle_flight_movement(delta: float) -> void:
	# 1. Yaw turning (A turns left, D turns right)
	var turn_input := Input.get_axis("heli_turn_right", "heli_turn_left")
	if absf(turn_input) < 0.001:
		turn_input = Input.get_axis("move_right", "move_left") # Legacy fallback

	var target_yaw_rate := turn_input * max_yaw_rate
	var yaw_response := yaw_input_response if absf(turn_input) > 0.001 else yaw_release_response
	var yaw_weight := exp_weight(yaw_response, delta)

	current_yaw_rate = lerp(current_yaw_rate, target_yaw_rate, yaw_weight)
	rotate_y(current_yaw_rate * delta)

	# 2. Heading-relative forward and right vectors (projected onto XZ plane)
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	# 3. Read throttle & strafe inputs
	var throttle_input := Input.get_axis("heli_throttle_reverse", "heli_throttle_forward")
	if absf(throttle_input) < 0.001:
		throttle_input = Input.get_axis("move_backward", "move_forward")

	var strafe_input := Input.get_axis("heli_strafe_left", "heli_strafe_right")
	if absf(strafe_input) < 0.001:
		strafe_input = Input.get_axis("strafe_left", "strafe_right")

	# Full forward speed for positive throttle; scaled reverse speed for negative throttle
	var scaled_throttle := throttle_input
	if scaled_throttle < 0.0:
		scaled_throttle *= reverse_speed_scale

	# 4. Target horizontal velocity (un-normalized to allow strong simultaneous diagonal movement)
	var target_horizontal_velocity := (forward * scaled_throttle * max_forward_speed) + (right * strafe_input * strafe_speed)

	# 5. Horizontal velocity response (14.0 active, 9.0 release)
	var has_h_input := absf(throttle_input) > 0.001 or absf(strafe_input) > 0.001
	var h_response := active_velocity_response if has_h_input else release_velocity_response
	var h_weight := exp_weight(h_response, delta)

	var current_h := Vector3(velocity.x, 0.0, velocity.z)
	current_h = current_h.lerp(target_horizontal_velocity, h_weight)

	velocity.x = current_h.x
	velocity.z = current_h.z

	# 6. Altitude movement
	var collective_input := Input.get_axis("heli_descend", "heli_climb")
	if absf(collective_input) < 0.001:
		collective_input = Input.get_axis("descend", "ascend")

	var target_v_velocity := collective_input * climb_speed
	var has_v_input := absf(collective_input) > 0.001
	var v_response := vertical_input_response if has_v_input else vertical_release_response
	var v_weight := exp_weight(v_response, delta)

	velocity.y = lerp(velocity.y, target_v_velocity, v_weight)

	# At upper limit, clear only upward velocity. At lower limit, clear only downward velocity.
	if global_position.y <= minimum_altitude and velocity.y < 0.0:
		global_position.y = minimum_altitude
		velocity.y = 0.0
	elif global_position.y >= maximum_altitude and velocity.y > 0.0:
		global_position.y = maximum_altitude
		velocity.y = 0.0

	# Ensure root CharacterBody3D collider stays strictly upright (only heading Y changes)
	rotation.x = 0.0
	rotation.z = 0.0

	# 7. Single authoritative physics integration step
	move_and_slide()

	# 8. Post-move altitude safety clamp without storing outward velocity
	if global_position.y < minimum_altitude:
		global_position.y = minimum_altitude
		if velocity.y < 0.0:
			velocity.y = 0.0
	elif global_position.y > maximum_altitude:
		global_position.y = maximum_altitude
		if velocity.y > 0.0:
			velocity.y = 0.0

func _handle_visual_tilt(delta: float) -> void:
	var throttle_input := Input.get_axis("heli_throttle_reverse", "heli_throttle_forward")
	if absf(throttle_input) < 0.001:
		throttle_input = Input.get_axis("move_backward", "move_forward")

	var turn_input := Input.get_axis("heli_turn_right", "heli_turn_left")
	if absf(turn_input) < 0.001:
		turn_input = Input.get_axis("move_right", "move_left")

	var strafe_input := Input.get_axis("heli_strafe_left", "heli_strafe_right")
	if absf(strafe_input) < 0.001:
		strafe_input = Input.get_axis("strafe_left", "strafe_right")

	# 1. Asymmetric forward / backward pitch with smoothed throttle input:
	# Forward input requires negative local X pitch so nose points down.
	# Reverse input requires positive local X pitch so nose points up.
	_smoothed_throttle = lerp(_smoothed_throttle, throttle_input, exp_weight(7.0, delta))
	var target_pitch: float = 0.0
	if _smoothed_throttle > 0.001:
		target_pitch = -deg_to_rad(forward_pitch_degrees) * _smoothed_throttle
	elif _smoothed_throttle < -0.001:
		target_pitch = deg_to_rad(reverse_pitch_degrees) * absf(_smoothed_throttle)

	# 2. Smooth aerodynamic banking:
	# A. Bank from yaw turn: driven continuously by actual rotational velocity (current_yaw_rate / max_yaw_rate)
	# This guarantees smooth entry and smooth exit without abrupt steps when pressing or releasing A/D.
	var turn_ratio := current_yaw_rate / maxf(0.01, max_yaw_rate)
	var bank_from_turn := turn_ratio * deg_to_rad(turn_bank_degrees)

	# B. Bank from lateral strafe: smoothly filter strafe input to avoid jerky steps
	_smoothed_strafe = lerp(_smoothed_strafe, strafe_input, exp_weight(6.5, delta))

	var local_right := global_transform.basis.x
	local_right.y = 0.0
	if local_right.length_squared() > 0.001:
		local_right = local_right.normalized()
	var lateral_speed := local_right.dot(velocity)
	var lateral_ratio := clampf(lateral_speed / maxf(1.0, strafe_speed), -1.0, 1.0)

	# Smoothly combine input intent with physical lateral speed for natural aerodynamic roll
	var effective_strafe: float = lerp(lateral_ratio, _smoothed_strafe, 0.6) if absf(strafe_input) > 0.001 else lateral_ratio
	var bank_from_strafe := -effective_strafe * deg_to_rad(strafe_bank_degrees)

	var target_bank := clampf(
		bank_from_turn + bank_from_strafe,
		-deg_to_rad(maximum_bank_degrees),
		deg_to_rad(maximum_bank_degrees)
	)

	# 3. Smooth visual pitch
	var has_pitch_input := absf(throttle_input) > 0.001
	var pitch_resp := tilt_input_response if has_pitch_input else tilt_release_response
	var pitch_weight := exp_weight(pitch_resp, delta)
	current_visual_pitch = lerp(current_visual_pitch, target_pitch, pitch_weight)

	# 4. Smooth visual bank response
	var has_bank_input := absf(turn_input) > 0.001 or absf(strafe_input) > 0.001 or absf(lateral_ratio) > 0.05
	var bank_resp := quick_tilt_response if has_bank_input else quick_tilt_release
	var bank_weight := exp_weight(bank_resp, delta)
	current_visual_bank = lerp(current_visual_bank, target_bank, bank_weight)

	# 5. Apply strictly to FlightTiltPivot (or visuals fallback)
	var tilt_target: Node3D = flight_tilt_pivot if flight_tilt_pivot else visuals
	if tilt_target:
		tilt_target.rotation.x = _base_tilt_rotation.x + current_visual_pitch
		tilt_target.rotation.z = _base_tilt_rotation.z + current_visual_bank
		tilt_target.rotation.y = _base_tilt_rotation.y

	# 6. Hover breathing
	if visuals:
		hover_time += delta
		var hover_offset := sin(hover_time * 2.4) * 0.08
		visuals.position.y = hover_offset

func _handle_gun_aim(delta: float) -> void:
	if not gun_mount or not gun_yaw_pivot or not gun_pitch_pivot:
		return

	# Handle gun recoil recovery
	_recoil_offset = move_toward(_recoil_offset, 0.0, 1.8 * delta)
	gun_mount.position = _base_gun_mount_pos + Vector3(0.0, 0.0, _recoil_offset)

	var aim_weight := exp_weight(gun_traverse_speed, delta)

	var has_aim_target := false
	var aim_world_pos := Vector3.ZERO

	if targeting_system:
		if targeting_system.is_manual_aim:
			has_aim_target = true
			aim_world_pos = targeting_system.manual_aim_point
		elif is_instance_valid(targeting_system.current_target) and not targeting_system.current_target.is_queued_for_deletion():
			has_aim_target = true
			aim_world_pos = targeting_system.get_predicted_target_position(targeting_system.current_target, gun_mount.global_position, 140.0)

	if has_aim_target:
		var local_target := gun_mount.to_local(aim_world_pos)
		var target_yaw := atan2(-local_target.x, -local_target.z)
		var flat_dist := Vector2(local_target.x, local_target.z).length()
		var target_pitch := atan2(local_target.y, flat_dist)

		# 360-degree yaw tracking, vertical pitch range -85 to +45 deg
		target_yaw = clampf(target_yaw, -PI, PI)
		target_pitch = clampf(target_pitch, deg_to_rad(-85.0), deg_to_rad(45.0))

		gun_yaw_pivot.rotation.y = lerp_angle(gun_yaw_pivot.rotation.y, target_yaw, aim_weight)
		gun_pitch_pivot.rotation.x = lerp_angle(gun_pitch_pivot.rotation.x, target_pitch, aim_weight)
	else:
		gun_yaw_pivot.rotation.y = lerp_angle(gun_yaw_pivot.rotation.y, 0.0, aim_weight)
		gun_pitch_pivot.rotation.x = lerp_angle(gun_pitch_pivot.rotation.x, 0.0, aim_weight)

	gun_yaw_pivot.rotation.x = 0.0
	gun_yaw_pivot.rotation.z = 0.0
	gun_pitch_pivot.rotation.y = 0.0
	gun_pitch_pivot.rotation.z = 0.0

func _handle_weapons() -> void:
	# Survivor-style Auto-Fire: automatically fire chaingun if target is acquired and in line of sight
	# with gun turret roughly aligned, or whenever manual primary fire is pressed.
	var auto_fire := false
	if targeting_system and is_instance_valid(targeting_system.current_target) and not targeting_system.current_target.is_queued_for_deletion():
		if targeting_system.has_los_to_current() and gun_pitch_pivot:
			var target_pos := targeting_system.get_predicted_target_position(targeting_system.current_target, gun_mount.global_position, 140.0)
			var to_target := (target_pos - gun_mount.global_position).normalized()
			var gun_fwd := -gun_pitch_pivot.global_transform.basis.z.normalized()
			# Trigger auto-fire once the chin turret is tracking within 65 degrees of target
			if gun_fwd.dot(to_target) > 0.42:
				auto_fire = true

	if (auto_fire or Input.is_action_pressed("fire_primary")) and chaingun:
		chaingun.try_fire()

	if missile_pod and targeting_system:
		var target: Node3D = null
		if is_instance_valid(targeting_system.current_target) and not targeting_system.current_target.is_queued_for_deletion():
			target = targeting_system.current_target
		var has_los: bool = targeting_system.has_los_to_current() if target else false
		missile_pod.set_target_candidate(target, has_los)

	if Input.is_action_just_pressed("fire_secondary") and missile_pod:
		missile_pod.try_fire()

	if Input.is_action_just_pressed("countermeasure_flares") and flare_dispenser:
		flare_dispenser.try_dispense()

func _on_chaingun_fired(_muzzle_pos: Vector3, _dir: Vector3) -> void:
	_recoil_offset = 0.09

func _handle_ground_fx() -> void:
	if ground_ray:
		ground_ray.global_position = global_position
		ground_ray.force_raycast_update()
		if ground_ray.is_colliding():
			var ground_y := ground_ray.get_collision_point().y
			var altitude_above_ground := global_position.y - ground_y

			if ground_shadow:
				ground_shadow.global_position = Vector3(global_position.x, ground_y + 0.05, global_position.z)
				var shadow_scale := clampf(1.0 - (altitude_above_ground / 30.0), 0.35, 1.2)
				ground_shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale)

			if downwash_dust:
				if altitude_above_ground < 18.0:
					downwash_dust.emitting = true
					downwash_dust.global_position = Vector3(global_position.x, ground_y + 0.1, global_position.z)
				else:
					downwash_dust.emitting = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		if Input.is_action_pressed("aim_override") or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			var cam := get_viewport().get_camera_3d()
			if cam:
				var from := cam.project_ray_origin(mouse_pos)
				var dir := cam.project_ray_normal(mouse_pos)
				var plane := Plane(Vector3.UP, 0.0)
				var hit_point = plane.intersects_ray(from, dir)
				if hit_point != null:
					targeting_system.trigger_manual_aim(hit_point)

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive or _is_dying or not _control_enabled:
		return

	# Deployment safety: invulnerable during opening countdown
	var wm := get_tree().get_first_node_in_group("wave_manager")
	if is_instance_valid(wm) and wm.has_method("is_deployment_active") and wm.is_deployment_active():
		return

	# Armor damage reduction (capped strictly at 60%)
	var effective_reduction := clampf(armor_reduction, 0.0, 0.60)
	amount *= (1.0 - effective_reduction)

	# Zero damage and invalid/friendly hits do not consume protection or trigger i-frames
	if amount <= 0.0:
		return

	# Phase 10B: Post-hit invulnerability (0.35s i-frames)
	if _invulnerability_timer > 0.0:
		return

	# Same-projectile / same-source repeat hit protection
	if _source != null and _recent_damaging_sources.has(_source):
		return

	_time_since_damage = 0.0

	# Legendary Ghost Rotor ECM Barrier: Absorbs 1 hit every 12 seconds
	if has_ghost_rotor and _ghost_rotor_timer <= 0.0:
		_ghost_rotor_timer = ghost_rotor_cooldown
		_invulnerability_timer = invulnerability_duration
		if _source != null:
			_recent_damaging_sources[_source] = 0.5
		_flash_hit()
		if EventBus and EventBus.has_signal("camera_shake_requested"):
			EventBus.camera_shake_requested.emit(0.15)
		if EventBus and EventBus.has_signal("player_damaged_directional"):
			var src_pos := (_source as Node3D).global_position if (_source is Node3D) else (_hit_pos if _hit_pos != Vector3.ZERO else global_position - global_transform.basis.z)
			EventBus.player_damaged_directional.emit(0.0, _hit_pos if _hit_pos != Vector3.ZERO else global_position, src_pos, true, {"target_id": get_instance_id()})
		return

	# Emergency Aegis Countermeasure: Trigger when falling below 35% hull
	var shield_damage: float = 0.0
	if has_aegis_shield and _aegis_cooldown <= 0.0 and (current_health - amount) <= (max_health * 0.35):
		_aegis_cooldown = 18.0
		if flare_dispenser and flare_dispenser.has_method("deploy_flares"):
			flare_dispenser.deploy_flares()
		if EventBus and EventBus.has_signal("camera_shake_requested"):
			EventBus.camera_shake_requested.emit(0.6)
		shield_damage = amount * 0.5 # Shield absorbs 50% of the breach damage
		amount *= 0.5
		if EventBus and EventBus.has_signal("player_damaged_directional"):
			var src_pos := (_source as Node3D).global_position if (_source is Node3D) else (_hit_pos if _hit_pos != Vector3.ZERO else global_position - global_transform.basis.z)
			EventBus.player_damaged_directional.emit(shield_damage, _hit_pos if _hit_pos != Vector3.ZERO else global_position, src_pos, true, {"target_id": get_instance_id(), "is_shield": true})

	# Activate i-frames and record source
	_invulnerability_timer = invulnerability_duration
	if _source != null:
		_recent_damaging_sources[_source] = 0.5

	# Telemetry: Record player damage in CombatDirector
	if CombatDirector.instance:
		CombatDirector.instance.record_player_damage(amount)

	var prev_hp: float = current_health
	current_health = maxf(0.0, current_health - amount)
	var actual_hull_damage: float = prev_hp - current_health
	_time_since_damage = 0.0
	_repair_drone_healed_accum = 0.0
	_flash_hit()
	emit_signal("health_changed", current_health, max_health)
	if EventBus:
		EventBus.player_health_changed.emit(current_health, max_health)
		if EventBus.has_signal("player_damaged_directional"):
			var src_pos := (_source as Node3D).global_position if (_source is Node3D) else (_hit_pos if _hit_pos != Vector3.ZERO else global_position - global_transform.basis.z)
			EventBus.player_damaged_directional.emit(actual_hull_damage, _hit_pos if _hit_pos != Vector3.ZERO else global_position, src_pos, false, {"target_id": get_instance_id(), "is_hull": true})
		if EventBus.has_signal("camera_shake_requested"):
			EventBus.camera_shake_requested.emit(0.25)

	if current_health <= 0.0:
		# Legendary One More Pass: Revive once per run at 30% Hull
		if has_one_more_pass and not one_more_pass_used:
			one_more_pass_used = true
			current_health = max_health * 0.3
			emit_signal("health_changed", current_health, max_health)
			if EventBus:
				EventBus.player_health_changed.emit(current_health, max_health)
				if EventBus.has_signal("camera_shake_requested"):
					EventBus.camera_shake_requested.emit(0.5)
			if flare_dispenser and flare_dispenser.has_method("deploy_flares"):
				flare_dispenser.deploy_flares()
			return
		_die()

func _flash_hit() -> void:
	var target_vis: Node3D = flight_tilt_pivot if flight_tilt_pivot else visuals
	if target_vis:
		var tween := create_tween()
		tween.tween_property(target_vis, "scale", Vector3(1.10, 1.10, 1.10), 0.05)
		tween.tween_property(target_vis, "scale", Vector3(1.0, 1.0, 1.0), 0.05)
	var body_node: Node = find_child("Body", true, false)
	var body_mesh: MeshInstance3D = body_node.get_node_or_null("Mesh0") as MeshInstance3D if body_node else null
	if body_mesh and is_inside_tree():
		var flash_enabled := bool(SaveSystem.get_setting("damage_flash_enabled", true))
		var reduced_flash := bool(SaveSystem.get_setting("reduced_flashing", false))
		if flash_enabled:
			var flash_mat := StandardMaterial3D.new()
			if reduced_flash:
				flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				flash_mat.albedo_color = Color(0.9, 0.45, 0.45, 1.0)
			else:
				flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				flash_mat.albedo_color = Color(1.8, 0.3, 0.3, 1.0)
			var orig_mat := body_mesh.material_override
			body_mesh.material_override = flash_mat
			get_tree().create_timer(0.06, false).timeout.connect(func():
				if is_instance_valid(body_mesh) and body_mesh.material_override == flash_mat:
					body_mesh.material_override = orig_mat
			)

func _die() -> void:
	if _is_dying:
		return
	_is_dying = true
	is_alive = false
	_control_enabled = false
	if ground_shadow:
		ground_shadow.visible = false
	if downwash_dust:
		downwash_dust.emitting = false
	emit_signal("died")
	if EventBus:
		EventBus.player_died.emit()

func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled

func hide_visuals() -> void:
	if visuals:
		visuals.visible = false
	if flight_tilt_pivot:
		flight_tilt_pivot.visible = false
	if ground_shadow:
		ground_shadow.visible = false
	if downwash_dust:
		downwash_dust.emitting = false

func disable_collision() -> void:
	collision_layer = 0
	collision_mask = 0
