class_name MiniHelicopter
extends CharacterBody3D

## Autonomous tactical escort drone helicopter.
## Flies in loose formation flanking the player and provides automatic chaingun fire support.

@export var formation_offset: Vector3 = Vector3(-4.5, 0.6, 3.5)
@export var follow_gain: float = 7.0
@export var max_flight_speed: float = 52.0
@export var detection_radius: float = 36.0
@export var fire_rate: float = 4.5 # Rounds per second
@export var damage_per_shot: float = 5.0
@export var rotor_speed: float = 52.0
@export var tail_rotor_speed: float = 80.0

@export_group("Upgrade Progression Hooks")
@export var damage_mult: float = 1.0
@export var fire_rate_mult: float = 1.0
@export var range_mult: float = 1.0
@export var has_micro_rockets: bool = false

var player_target: Node3D = null
var current_target: Node3D = null
var is_active: bool = true

var _shot_cooldown: float = 0.0
var _flash_timer: float = 0.0
var _target_stick_timer: float = 0.0

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var main_rotor: Node3D = get_node_or_null("VisualRoot/MainRotor")
@onready var tail_rotor: Node3D = get_node_or_null("VisualRoot/TailRotor")
@onready var weapon_mount: Marker3D = get_node_or_null("WeaponMount")
@onready var target_detection: Area3D = get_node_or_null("TargetDetection")
@onready var fire_timer: Timer = get_node_or_null("FireTimer")
@onready var muzzle_flash: Node3D = get_node_or_null("MuzzleFlash")
@onready var sfx: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")

func _ready() -> void:
	add_to_group("companions")
	add_to_group("mini_helicopters")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0

	if not player_target:
		player_target = get_tree().get_first_node_in_group("player") as Node3D

	if EventBus and EventBus.has_signal("player_died"):
		EventBus.player_died.connect(_on_player_died)

	if muzzle_flash:
		muzzle_flash.visible = false

	if fire_timer:
		fire_timer.wait_time = 1.0 / maxf(0.1, get_effective_fire_rate())
		if not fire_timer.timeout.is_connected(_on_fire_timer_timeout):
			fire_timer.timeout.connect(_on_fire_timer_timeout)
		if fire_timer.is_inside_tree() and not fire_timer.is_stopped():
			fire_timer.start()

func set_formation_slot(offset: Vector3) -> void:
	formation_offset = offset

func get_effective_damage() -> float:
	return damage_per_shot * damage_mult

func get_effective_fire_rate() -> float:
	return fire_rate * fire_rate_mult

func get_effective_range() -> float:
	return detection_radius * range_mult

func apply_companion_modifiers(dmg_m: float = 1.0, rate_m: float = 1.0, rng_m: float = 1.0, rockets: bool = false) -> void:
	damage_mult = dmg_m
	fire_rate_mult = rate_m
	range_mult = rng_m
	has_micro_rockets = rockets
	if fire_timer:
		fire_timer.wait_time = 1.0 / maxf(0.1, get_effective_fire_rate())

func _exit_tree() -> void:
	if EventBus and EventBus.has_signal("player_died") and EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)

func _on_player_died() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	if not is_instance_valid(player_target) or player_target.is_queued_for_deletion():
		player_target = get_tree().get_first_node_in_group("player") as Node3D
		if not is_instance_valid(player_target):
			queue_free()
			return

	if "is_alive" in player_target and not player_target.is_alive:
		queue_free()
		return

	_handle_movement_and_banking(delta)
	_handle_rotors(delta)
	_handle_targeting_and_combat(delta)

func _handle_movement_and_banking(delta: float) -> void:
	# Calculate target formation position in player reference frame
	var target_pos := player_target.global_position + (player_target.global_transform.basis * formation_offset)
	var to_target := target_pos - global_position
	var dist := to_target.length()

	# Anti-lag catch-up: snap if teleported or fell too far behind
	if dist > 65.0:
		global_position = target_pos
		velocity = Vector3.ZERO
		return

	# Smooth spring / velocity damping follow
	var desired_vel := to_target * follow_gain

	# Anti-stacking: separation push away from player if too close (< 3.0m)
	var to_player := global_position - player_target.global_position
	to_player.y = 0.0
	var player_dist := to_player.length()
	if player_dist < 3.0 and player_dist > 0.01:
		var push := (to_player / player_dist) * ((3.0 - player_dist) * 8.0)
		desired_vel += push

	# Anti-stacking: separation push away from sibling mini helicopters (< 3.5m)
	for peer in get_tree().get_nodes_in_group("mini_helicopters"):
		if peer != self and is_instance_valid(peer) and peer is Node3D:
			var to_peer: Vector3 = global_position - (peer as Node3D).global_position
			to_peer.y = 0.0
			var peer_dist := to_peer.length()
			if peer_dist < 3.5 and peer_dist > 0.01:
				var push := (to_peer / peer_dist) * ((3.5 - peer_dist) * 10.0)
				desired_vel += push

	if desired_vel.length() > max_flight_speed:
		desired_vel = desired_vel.normalized() * max_flight_speed

	velocity = velocity.lerp(desired_vel, clampf(7.5 * delta, 0.0, 1.0))
	move_and_slide()

	# Heading orientation: aim towards target if engaging, or match player heading
	var aim_dir: Vector3
	if is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
		aim_dir = (current_target.global_position - global_position).normalized()
	else:
		aim_dir = -player_target.global_transform.basis.z

	aim_dir.y = 0.0
	if aim_dir.length_squared() > 0.01:
		aim_dir = aim_dir.normalized()
		var target_yaw := atan2(-aim_dir.x, -aim_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(8.0 * delta, 0.0, 1.0))

	# Dynamic aerodynamic banking on VisualRoot
	if visual_root:
		var local_vel := global_transform.basis.inverse() * velocity
		var target_bank := clampf(-local_vel.x * 0.035, -0.42, 0.42)
		var target_pitch := clampf(-local_vel.z * 0.025, -0.32, 0.32)
		visual_root.rotation.z = lerp(visual_root.rotation.z, target_bank, clampf(8.0 * delta, 0.0, 1.0))
		visual_root.rotation.x = lerp(visual_root.rotation.x, target_pitch, clampf(8.0 * delta, 0.0, 1.0))

func _handle_rotors(delta: float) -> void:
	if main_rotor:
		main_rotor.rotate_y(rotor_speed * delta)
	if tail_rotor:
		tail_rotor.rotate_x(tail_rotor_speed * delta)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and muzzle_flash:
			muzzle_flash.visible = false

func _handle_targeting_and_combat(delta: float) -> void:
	if _shot_cooldown > 0.0:
		_shot_cooldown -= delta

	if _target_stick_timer > 0.0:
		_target_stick_timer -= delta

	# Validate current target with hysteresis
	var target_valid := is_instance_valid(current_target) and not current_target.is_queued_for_deletion()
	if target_valid:
		if "is_alive" in current_target and not current_target.is_alive:
			target_valid = false
		elif global_position.distance_to(current_target.global_position) > (get_effective_range() * 1.25):
			target_valid = false

	if not target_valid or (_target_stick_timer <= 0.0 and not is_instance_valid(current_target)):
		current_target = _find_best_target()
		_target_stick_timer = 0.45

	if is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
		if _shot_cooldown <= 0.0:
			_fire_at_target(current_target)
			_shot_cooldown = 1.0 / maxf(0.1, get_effective_fire_rate())

func _on_fire_timer_timeout() -> void:
	if not is_instance_valid(current_target) or current_target.is_queued_for_deletion():
		return
	if "is_alive" in current_target and not current_target.is_alive:
		return
	if global_position.distance_to(current_target.global_position) <= (get_effective_range() * 1.25):
		_fire_at_target(current_target)
		_shot_cooldown = 1.0 / maxf(0.1, get_effective_fire_rate())

func _find_best_target() -> Node3D:
	var eff_range := get_effective_range()
	var candidates: Array[Node3D] = []
	if EnemyRegistry.instance:
		candidates = EnemyRegistry.instance.get_enemies_in_radius(global_position, eff_range)

	if candidates.is_empty() and target_detection:
		for body in target_detection.get_overlapping_bodies():
			if body is Node3D and body.is_in_group("enemies"):
				candidates.append(body as Node3D)
		for area in target_detection.get_overlapping_areas():
			if area is Node3D and area.is_in_group("enemies"):
				candidates.append(area as Node3D)

	if candidates.is_empty():
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node3D:
				var dist := global_position.distance_to((e as Node3D).global_position)
				if dist <= eff_range:
					candidates.append(e as Node3D)

	var closest_enemy: Node3D = null
	var best_score := INF
	for enemy in candidates:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if "is_alive" in enemy and not enemy.is_alive:
			continue
		var d_sq := global_position.distance_squared_to(enemy.global_position)
		var score := d_sq
		# Threat-weighted practical targeting: prioritize high-threat/SAM/armor slightly over distant fodder
		if enemy.is_in_group("high_threat") or enemy.is_in_group("sam_sites") or enemy.is_in_group("bosses"):
			score *= 0.65
		if score < best_score:
			best_score = score
			closest_enemy = enemy

	return closest_enemy

func _fire_at_target(target: Node3D) -> void:
	var muzzle_pos: Vector3 = weapon_mount.global_position if weapon_mount else global_position
	var target_center: Vector3 = target.global_position + Vector3(0, 0.4, 0)
	var fire_dir := (target_center - muzzle_pos).normalized()

	# Fire light projectile from ProjectilePool with effective damage
	var pool := ProjectilePool.instance
	if not pool:
		pool = get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if pool:
		pool.spawn_projectile(muzzle_pos, fire_dir, true, get_effective_damage(), 0, 0, 1.0)

	# Trigger muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true
		_flash_timer = 0.05
	elif VfxPool.instance:
		VfxPool.instance.spawn_muzzle_flash(muzzle_pos)

	if sfx and not sfx.playing:
		sfx.play()
