class_name MiniHelicopter
extends CharacterBody3D

## Support Wingman allied escort aircraft.
## Flies in tactical flanking formation (left/right slots), engages enemies with allied autocannon fire,
## and physically intercepts incoming enemy projectiles as a destructible shield.

signal health_changed(current_hp: float, max_hp: float)
signal destroyed(wingman: MiniHelicopter, slot: String)

@export_category("Health & Shielding")
@export var max_health: float = 60.0
@export var current_health: float = 60.0
@export var is_alive: bool = true

@export_category("Formation Slots")
@export var slot_id: String = "left" # "left" or "right"
@export var formation_offset: Vector3 = Vector3(-4.8, 0.5, 2.6)
@export var follow_gain: float = 7.5
@export var max_flight_speed: float = 52.0
@export var follow_responsiveness: float = 7.5
@export var follow_accel: float = 85.0

@export_category("Combat & Systems")
@export var detection_radius: float = 36.0
@export var fire_rate: float = 4.5 # Rounds per second
@export var damage_per_shot: float = 6.0
@export var rotor_speed: float = 48.0

@export_category("Visual & Procedural Animation")
@export var visual_scale: float = 0.28
@export var lateral_spacing: float = 4.8
@export var rear_offset: float = 2.6
@export var altitude_offset: float = 0.5
@export var hover_bob_amplitude: float = 0.08
@export var hover_bob_frequency: float = 2.4
@export var max_bank_angle: float = 0.45 # ~26 deg
@export var max_pitch_angle: float = 0.30 # ~17 deg

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
var _bob_phase: float = 0.0
var _visual_meshes: Array[MeshInstance3D] = []
static var _flash_mat: StandardMaterial3D = null

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var plane_model: Node3D = get_node_or_null("VisualRoot/PlaneModel")
@onready var main_rotor: Node3D = get_node_or_null("VisualRoot/PlaneModel/MainRotor")
@onready var weapon_mount: Marker3D = get_node_or_null("WeaponMount")
@onready var target_detection: Area3D = get_node_or_null("TargetDetection")
@onready var fire_timer: Timer = get_node_or_null("FireTimer")
@onready var muzzle_flash: Node3D = get_node_or_null("MuzzleFlash")
@onready var sfx: AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer3D")
@onready var health_bar_root: Node3D = get_node_or_null("HealthBar3D")
@onready var health_bar_fill: MeshInstance3D = get_node_or_null("HealthBar3D/Fill")

## Pure yaw-only, scale-free basis from player heading, completely decoupled from pitch, roll, and scale
static func get_player_yaw_basis(player: Node3D) -> Basis:
	if not is_instance_valid(player):
		return Basis.IDENTITY
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	return Basis(right, Vector3.UP, -fwd)

func _ready() -> void:
	add_to_group("companions")
	add_to_group("mini_helicopters")
	
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# Layer 2 is Player team layer — enemy projectiles detect and hit Layer 2
	collision_layer = 2
	# Collision mask 0 so wingmen do not collide with terrain physics or push player
	collision_mask = 0

	current_health = max_health
	is_alive = true
	is_active = true

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

	_collect_visual_meshes(self)
	_update_health_display()

func set_formation_slot(offset: Vector3, slot_name: String = "") -> void:
	formation_offset = offset
	if not slot_name.is_empty():
		slot_id = slot_name

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

func get_target_formation_position() -> Vector3:
	if not is_instance_valid(player_target):
		return global_position
	var yaw_basis: Basis = get_player_yaw_basis(player_target)
	var horiz_offset: Vector3 = yaw_basis * Vector3(formation_offset.x, 0.0, formation_offset.z)
	return Vector3(
		player_target.global_position.x + horiz_offset.x,
		player_target.global_position.y + formation_offset.y,
		player_target.global_position.z + horiz_offset.z
	)

func _physics_process(delta: float) -> void:
	if not is_active or not is_alive:
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
	# Calculate target formation position using player's yaw-only, scale-free basis with independent altitude
	var target_pos: Vector3 = get_target_formation_position()
	var to_target: Vector3 = target_pos - global_position
	var dist: float = to_target.length()

	# Large-distance recovery only after genuine teleport or excessive separation (> 65m)
	if dist > 65.0:
		global_position = target_pos
		velocity = Vector3.ZERO
		return

	# Smooth follow with bounded acceleration and maximum flight speed
	var desired_vel: Vector3 = to_target * follow_gain

	# Anti-stacking: separation push away from player if too close (< 2.8m)
	var to_player: Vector3 = global_position - player_target.global_position
	to_player.y = 0.0
	var player_dist: float = to_player.length()
	if player_dist < 2.8 and player_dist > 0.01:
		var push: Vector3 = (to_player / player_dist) * ((2.8 - player_dist) * 8.0)
		desired_vel += push

	# Anti-stacking: separation push away from peer wingmen (< 3.2m)
	for peer in get_tree().get_nodes_in_group("mini_helicopters"):
		if peer != self and is_instance_valid(peer) and peer is Node3D:
			var to_peer: Vector3 = global_position - (peer as Node3D).global_position
			to_peer.y = 0.0
			var peer_dist: float = to_peer.length()
			if peer_dist < 3.2 and peer_dist > 0.01:
				var push: Vector3 = (to_peer / peer_dist) * ((3.2 - peer_dist) * 10.0)
				desired_vel += push

	if desired_vel.length() > max_flight_speed:
		desired_vel = desired_vel.normalized() * max_flight_speed

	velocity = velocity.move_toward(desired_vel, follow_accel * delta)
	move_and_slide()

	# Body yaw orientation:
	# Base heading matches the player's yaw flight heading
	var player_fwd: Vector3 = -player_target.global_transform.basis.z
	player_fwd.y = 0.0
	if player_fwd.length_squared() < 0.001:
		player_fwd = Vector3.FORWARD
	else:
		player_fwd = player_fwd.normalized()

	var player_yaw: float = atan2(-player_fwd.x, -player_fwd.z)
	var desired_yaw: float = player_yaw

	# When engaging a target, allow a smooth visual yaw bias constrained to +/- 45 deg
	# to avoid abrupt sideways or backward flips during formation flight.
	if is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
		var to_target_flat: Vector3 = current_target.global_position - global_position
		to_target_flat.y = 0.0
		if to_target_flat.length_squared() > 0.01:
			var target_heading: float = atan2(-to_target_flat.x, -to_target_flat.z)
			var angle_diff: float = wrapf(target_heading - player_yaw, -PI, PI)
			var max_bias: float = deg_to_rad(45.0)
			desired_yaw = player_yaw + clampf(angle_diff, -max_bias, max_bias)

	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(7.0 * delta, 0.0, 1.0))
	rotation.x = 0.0
	rotation.z = 0.0

	# Procedural aerodynamic banking, pitch, and subtle hover bob on VisualRoot ONLY
	if visual_root:
		_bob_phase += delta * hover_bob_frequency
		var bob_y: float = sin(_bob_phase) * hover_bob_amplitude
		visual_root.position.y = bob_y

		var local_vel: Vector3 = global_transform.basis.inverse() * velocity
		var target_bank: float = clampf(-local_vel.x * 0.035, -max_bank_angle, max_bank_angle)
		var target_pitch: float = clampf(-local_vel.z * 0.025, -max_pitch_angle, max_pitch_angle)
		visual_root.rotation.z = lerp(visual_root.rotation.z, target_bank, clampf(8.0 * delta, 0.0, 1.0))
		visual_root.rotation.x = lerp(visual_root.rotation.x, target_pitch, clampf(8.0 * delta, 0.0, 1.0))
		visual_root.rotation.y = 0.0

	# Health bar readability: keep horizontal and billboarded toward the camera
	if health_bar_root:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() else null
		if cam:
			var cam_fwd: Vector3 = cam.global_transform.basis.z
			cam_fwd.y = 0.0
			if cam_fwd.length_squared() > 0.001:
				health_bar_root.global_rotation.y = atan2(cam_fwd.x, cam_fwd.z)
				health_bar_root.global_rotation.x = 0.0
				health_bar_root.global_rotation.z = 0.0

func _handle_rotors(delta: float) -> void:
	if main_rotor:
		main_rotor.rotate_y(rotor_speed * delta)

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and muzzle_flash:
			muzzle_flash.visible = false

func _handle_targeting_and_combat(delta: float) -> void:
	if _shot_cooldown > 0.0:
		_shot_cooldown -= delta

	if _target_stick_timer > 0.0:
		_target_stick_timer -= delta

	var target_valid: bool = is_instance_valid(current_target) and not current_target.is_queued_for_deletion()
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
	var eff_range: float = get_effective_range()
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
				var dist: float = global_position.distance_to((e as Node3D).global_position)
				if dist <= eff_range:
					candidates.append(e as Node3D)

	var closest_enemy: Node3D = null
	var best_score: float = INF
	for enemy in candidates:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if "is_alive" in enemy and not enemy.is_alive:
			continue
		var score: float = global_position.distance_squared_to(enemy.global_position)
		if enemy.is_in_group("high_threat") or enemy.is_in_group("sam_sites") or enemy.is_in_group("bosses"):
			score *= 0.65
		if score < best_score:
			best_score = score
			closest_enemy = enemy

	return closest_enemy

func _fire_at_target(target: Node3D) -> void:
	var muzzle_pos: Vector3 = weapon_mount.global_position if weapon_mount else global_position + Vector3(0.0, -0.06, -0.72)
	var target_center: Vector3 = target.global_position + Vector3(0, 0.4, 0)
	var fire_dir: Vector3 = (target_center - muzzle_pos).normalized()
	if fire_dir.length_squared() < 0.001:
		fire_dir = -global_transform.basis.z

	var pool: ProjectilePool = ProjectilePool.instance
	if not pool:
		pool = get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if pool:
		# Allied round: from_player = true (hits World & Enemies, will NEVER hit player or companions)
		pool.spawn_projectile(muzzle_pos, fire_dir, true, get_effective_damage(), 0, 0, 1.0)

	if muzzle_flash:
		muzzle_flash.visible = true
		_flash_timer = 0.05
	elif VfxPool.instance:
		VfxPool.instance.spawn_muzzle_flash(muzzle_pos, fire_dir, false)

	if sfx and not sfx.playing:
		sfx.play()

## Physical Interception: Called by Projectile when an enemy round collides with this aircraft.
func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)

	_trigger_damage_flash()
	_update_health_display()

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 0.8, 0), amount, false)

	if current_health <= 0.0:
		_die()

func _collect_visual_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child != health_bar_fill and child.name != "Bg" and child.name != "MuzzleFlash":
			_visual_meshes.append(child as MeshInstance3D)
		_collect_visual_meshes(child)

func _trigger_damage_flash() -> void:
	if _visual_meshes.is_empty():
		_collect_visual_meshes(self)
	if not _flash_mat:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1.8, 1.8, 1.8, 1.0)
	for m in _visual_meshes:
		if is_instance_valid(m):
			m.material_override = _flash_mat
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_interval(0.08)
		tween.tween_callback(func() -> void:
			for m in _visual_meshes:
				if is_instance_valid(m):
					m.material_override = null
		)

func _update_health_display() -> void:
	if not is_instance_valid(health_bar_fill):
		return
	var pct: float = clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
	health_bar_fill.scale.x = pct
	# Color shift: cyan/green at full health -> amber -> red
	var mat: StandardMaterial3D = health_bar_fill.get_surface_override_material(0) as StandardMaterial3D
	if not mat and health_bar_fill.mesh and health_bar_fill.mesh.get_surface_count() > 0:
		mat = health_bar_fill.mesh.surface_get_material(0) as StandardMaterial3D
	if mat:
		if pct > 0.5:
			mat.albedo_color = Color(0.1, 0.9, 0.8, 0.9).lerp(Color(1.0, 0.85, 0.1, 0.9), (1.0 - pct) * 2.0)
		else:
			mat.albedo_color = Color(1.0, 0.85, 0.1, 0.9).lerp(Color(1.0, 0.2, 0.15, 0.9), (0.5 - pct) * 2.0)

func _die() -> void:
	if not is_alive:
		return
	is_alive = false
	is_active = false
	collision_layer = 0 # Immediately stop intercepting any further shots
	set_physics_process(false)

	# Bounded visual destruction VFX
	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(global_position, 0.75)

	# Audio feedback
	var sound_mgr: Node = get_tree().get_first_node_in_group("sound_manager")
	if sound_mgr and sound_mgr.has_method("play_sfx"):
		sound_mgr.call("play_sfx", "explosion")

	destroyed.emit(self, slot_id)

	# Notify UpgradeManager so slot is immediately recognized as free/missing
	var mgr := get_tree().get_first_node_in_group("upgrade_manager") as UpgradeManager
	if mgr and mgr.has_method("on_wingman_destroyed"):
		mgr.on_wingman_destroyed(slot_id, self)

	queue_free()
