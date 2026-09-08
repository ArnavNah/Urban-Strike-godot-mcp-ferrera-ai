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

func set_formation_slot(offset: Vector3) -> void:
	formation_offset = offset

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
		elif global_position.distance_to(current_target.global_position) > (detection_radius * 1.25):
			target_valid = false

	if not target_valid or (_target_stick_timer <= 0.0 and not is_instance_valid(current_target)):
		current_target = _find_best_target()
		_target_stick_timer = 0.45

	if is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
		if _shot_cooldown <= 0.0:
			_fire_at_target(current_target)
			_shot_cooldown = 1.0 / maxf(0.1, fire_rate)

func _find_best_target() -> Node3D:
	var candidates: Array[Node3D] = []
	if EnemyRegistry.instance:
		candidates = EnemyRegistry.instance.get_enemies_in_radius(global_position, detection_radius)

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
				if dist <= detection_radius:
					candidates.append(e as Node3D)

	var closest_enemy: Node3D = null
	var min_dist_sq := INF
	for enemy in candidates:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if "is_alive" in enemy and not enemy.is_alive:
			continue
		var d_sq := global_position.distance_squared_to(enemy.global_position)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			closest_enemy = enemy

	return closest_enemy

func _fire_at_target(target: Node3D) -> void:
	var muzzle_pos: Vector3 = weapon_mount.global_position if weapon_mount else global_position
	var target_center: Vector3 = target.global_position + Vector3(0, 0.4, 0)
	var fire_dir := (target_center - muzzle_pos).normalized()

	# Fire light projectile from ProjectilePool
	var pool := ProjectilePool.instance
	if not pool:
		pool = get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if pool:
		pool.spawn_projectile(muzzle_pos, fire_dir, true, damage_per_shot, 0, 0, 1.0)

	# Trigger muzzle flash
	if muzzle_flash:
		muzzle_flash.visible = true
		_flash_timer = 0.05
	elif VfxPool.instance:
		VfxPool.instance.spawn_muzzle_flash(muzzle_pos)

	if sfx and not sfx.playing:
		sfx.play()
