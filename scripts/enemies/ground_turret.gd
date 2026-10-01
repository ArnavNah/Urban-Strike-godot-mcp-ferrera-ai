class_name GroundTurret
extends StaticBody3D

## Stationary defense turret on ground or rooftops.
## Fires responsive, readable machine-gun/autocannon bursts (3-8 shots) with crisp pauses.

enum State {
	IDLE,
	AIMING,
	FIRING,
	RELOADING,
	WAITING
}

@export var max_health: float = 45.0
@export var threat_range: float = 58.0
@export var aim_speed: float = 4.8
@export var aim_prep_time: float = 0.35
@export var burst_count: int = 5
@export var burst_interval: float = 0.11
@export var reload_time: float = 1.3
@export var wait_time: float = 0.25
@export var bullet_damage: float = 6.5
@export var xp_reward: int = 12
@export var arming_delay: float = 1.5
@export var debug_combat_telemetry: bool = false

var _is_dead: bool = false
var _has_spawned_rewards: bool = false
var current_health: float = 45.0
var current_state: State = State.IDLE
var is_alive: bool = true
var _arming_timer: float = 1.5

var _state_timer: float = 0.0
var _shots_fired_in_burst: int = 0
var _burst_timer: float = 0.0
var _player_node: Node3D = null
var _has_attack_slot: bool = false
var _lod_frame_counter: int = 0
var _stagger_offset: int = 0
var _cached_los: bool = false
var _los_timer: float = 0.0
var reserved_socket_id: String = ""
var chunk_coord: Vector2i = Vector2i.ZERO
var debug_last_blocked_reason: String = ""
var debug_shots_fired: int = 0

func _log_combat(event_name: String, details: String = "") -> void:
	if not debug_combat_telemetry:
		return
	var time_sec := Time.get_ticks_msec() / 1000.0
	var msg := "[%.2fs][Turret:%d][%s] %s" % [time_sec, get_instance_id(), event_name, details]
	print(msg)

func on_projectile_hit(target: Node, hit_pos: Vector3) -> void:
	var target_name: String = str(target.name) if target else "null"
	_log_combat("target_hit", "target: %s, pos: %s" % [target_name, str(hit_pos)])

func on_projectile_miss() -> void:
	_log_combat("target_miss", "burst shot missed")

func on_attack_slot_revoked() -> void:
	_has_attack_slot = false
	_log_combat("slot_revoked")
	if current_state == State.AIMING or current_state == State.FIRING:
		_set_telegraph(false)
		_transition_to(State.IDLE)

func has_valid_attack_slot() -> bool:
	if not _has_attack_slot:
		return false
	var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
	if not dir and CombatDirector.instance:
		dir = CombatDirector.instance
	if dir:
		return dir.has_attack_permission(self)
	return true

var _telegraph_mesh: MeshInstance3D = null

static var _burnt_mat: StandardMaterial3D = null

static func _get_burnt_mat() -> StandardMaterial3D:
	if not _burnt_mat:
		_burnt_mat = StandardMaterial3D.new()
		_burnt_mat.albedo_color = Color(0.12, 0.10, 0.10, 1.0)
		_burnt_mat.roughness = 0.95
	return _burnt_mat

@onready var head: Node3D = $TurretHead
@onready var barrel: Node3D = $TurretHead/Barrel
@onready var muzzle: Marker3D = $TurretHead/Barrel/Muzzle
@onready var los_ray: RayCast3D = $LOSRayCast

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("armored_enemies")
	add_to_group("turrets")
	add_to_group("stationary_enemies")
	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, false)
	current_health = max_health
	_find_player()
	_setup_telegraph_mesh()
	_stagger_offset = randi() % 60
	if los_ray:
		los_ray.collision_mask = 1 # World layer blocks LoS
		los_ray.add_exception(self)

var _laser_beam_mesh: MeshInstance3D = null

func _setup_telegraph_mesh() -> void:
	_telegraph_mesh = MeshInstance3D.new()
	_telegraph_mesh.name = "TelegraphMesh"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	_telegraph_mesh.mesh = sphere
	var t_mat := StandardMaterial3D.new()
	t_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	t_mat.albedo_color = Color(1.0, 0.45, 0.1, 0.95)
	_telegraph_mesh.material_override = t_mat
	_telegraph_mesh.visible = false

	_laser_beam_mesh = MeshInstance3D.new()
	_laser_beam_mesh.name = "LaserBeamMesh"
	var beam_cyl := CylinderMesh.new()
	beam_cyl.top_radius = 0.035
	beam_cyl.bottom_radius = 0.035
	beam_cyl.height = 1.0
	_laser_beam_mesh.mesh = beam_cyl
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(1.0, 0.25, 0.1, 0.65)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_beam_mesh.material_override = beam_mat
	_laser_beam_mesh.visible = false
	_laser_beam_mesh.top_level = true
	add_child(_laser_beam_mesh)

	if muzzle:
		muzzle.add_child(_telegraph_mesh)
	elif barrel:
		barrel.add_child(_telegraph_mesh)

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)
	_release_slot()
	_release_socket()

func _find_player() -> void:
	_player_node = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_instance_valid(_player_node):
		_find_player()
		if not is_instance_valid(_player_node):
			return

	var dist_to_player := global_position.distance_to(_player_node.global_position)
	if dist_to_player > 140.0:
		return # Dormant beyond 140m

	_lod_frame_counter += 1
	var step_delta := delta
	var frame_stagger := _lod_frame_counter + _stagger_offset

	if dist_to_player > 60.0:
		if frame_stagger % 2 != 0:
			return # 30 Hz for medium distance
		step_delta = delta * 2.0

	# Throttled LoS check: only if within threat range
	if dist_to_player > threat_range:
		_cached_los = false
	else:
		_los_timer -= step_delta
		if _los_timer <= 0.0:
			_los_timer = 0.2
			_cached_los = _check_line_of_sight()
	var has_los := _cached_los

	if _arming_timer > 0.0:
		_arming_timer -= step_delta

	match current_state:
		State.IDLE:
			if _arming_timer <= 0.0 and dist_to_player <= threat_range and has_los:
				_log_combat("acquire", "dist: %.1fm" % dist_to_player)
				_transition_to(State.AIMING)

		State.AIMING:
			if not is_instance_valid(_player_node) or ("is_alive" in _player_node and not _player_node.is_alive) or dist_to_player > threat_range or not has_los:
				_set_telegraph(false)
				_release_slot()
				_transition_to(State.IDLE)
				return

			_track_player(step_delta)
			_state_timer -= step_delta
			var progress: float = 1.0 - clampf(_state_timer / maxf(aim_prep_time, 0.01), 0.0, 1.0)
			_update_telegraph(progress)

			if _state_timer <= 0.0:
				var can_attack: bool = _request_slot()
				if can_attack:
					_log_combat("aim_aligned", "slot confirmed, starting burst")
					_set_telegraph(false)
					_shots_fired_in_burst = 0
					_burst_timer = 0.0
					_transition_to(State.FIRING)
				else:
					# Hold aim until slot becomes available
					_state_timer = 0.2

		State.FIRING:
			# If player broke LoS behind building, destroyed, or lease revoked, stop firing burst and release slot
			if not is_instance_valid(_player_node) or ("is_alive" in _player_node and not _player_node.is_alive) or not has_los or not has_valid_attack_slot():
				_release_slot()
				_transition_to(State.IDLE)
				return

			# Track player smoothly during burst to prevent rounds trailing behind moving targets
			_track_player(step_delta * 0.5)

			_burst_timer -= delta
			if _burst_timer <= 0.0:
				var spawned := _fire_shot()
				if spawned:
					_burst_timer = burst_interval
					_shots_fired_in_burst += 1
					if _shots_fired_in_burst >= burst_count:
						_release_slot()
						_transition_to(State.RELOADING)
				else:
					# On projectile pool failure, retry after short delay without consuming burst round
					_burst_timer = 0.08

		State.RELOADING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_transition_to(State.WAITING)

		State.WAITING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				if dist_to_player <= threat_range and has_los:
					_transition_to(State.AIMING)
				else:
					_transition_to(State.IDLE)

func _transition_to(new_state: State) -> void:
	if (current_state == State.AIMING or current_state == State.FIRING) and new_state != State.AIMING and new_state != State.FIRING:
		_release_slot()
		_set_telegraph(false)
	current_state = new_state
	match new_state:
		State.IDLE:
			_state_timer = 0.0
		State.AIMING:
			_state_timer = aim_prep_time
		State.FIRING:
			pass
		State.RELOADING:
			_state_timer = reload_time
		State.WAITING:
			_state_timer = wait_time

func _set_telegraph(active: bool) -> void:
	if is_instance_valid(_telegraph_mesh):
		_telegraph_mesh.visible = active
		if not active:
			_telegraph_mesh.scale = Vector3.ZERO
	if is_instance_valid(_laser_beam_mesh):
		_laser_beam_mesh.visible = active

func _update_telegraph(progress: float) -> void:
	if is_instance_valid(_telegraph_mesh):
		_telegraph_mesh.visible = true
		_telegraph_mesh.scale = Vector3.ONE * progress
	if is_instance_valid(_laser_beam_mesh) and is_instance_valid(_player_node):
		var muzzle_pos: Vector3 = muzzle.global_position if muzzle else global_position
		var target_pos: Vector3 = _player_node.global_position + Vector3(0, 0.5, 0)
		var diff := target_pos - muzzle_pos
		var dist := diff.length()
		if dist > 0.5:
			_laser_beam_mesh.visible = true
			var mid_point := muzzle_pos + diff * 0.5
			_laser_beam_mesh.global_position = mid_point
			var dir := diff.normalized()
			var up_vec := Vector3.UP if absf(dir.y) < 0.9 else Vector3.FORWARD
			_laser_beam_mesh.look_at(target_pos, up_vec)
			_laser_beam_mesh.rotate_object_local(Vector3.RIGHT, PI * 0.5)
			_laser_beam_mesh.scale = Vector3(1.0, dist, 1.0)

func _track_player(delta: float) -> void:
	if not is_instance_valid(_player_node) or not head or not barrel:
		return

	var target_pos := _player_node.global_position
	# Horizontal track (head yaw)
	var local_head_target := to_local(target_pos)
	var target_yaw := atan2(-local_head_target.x, -local_head_target.z)
	head.rotation.y = lerp_angle(head.rotation.y, target_yaw, aim_speed * delta)

	# Vertical track (barrel pitch)
	var local_barrel_target := head.to_local(target_pos)
	var flat_dist := Vector2(local_barrel_target.x, local_barrel_target.z).length()
	var target_pitch := atan2(local_barrel_target.y, flat_dist)
	target_pitch = clampf(target_pitch, deg_to_rad(-45.0), deg_to_rad(65.0))
	barrel.rotation.x = lerp_angle(barrel.rotation.x, target_pitch, aim_speed * delta)

func _fire_shot() -> bool:
	# Barrel extends 2.05m forward locally (-z). Calculate muzzle point at actual barrel tip
	# to clear the turret collision cylinder (radius 2.1m) and building rooftop edges.
	var muzzle_pos: Vector3
	if barrel:
		muzzle_pos = barrel.global_position + (-barrel.global_transform.basis.z * 2.15)
	elif muzzle:
		muzzle_pos = muzzle.global_position
	elif head:
		muzzle_pos = head.global_position + (-head.global_transform.basis.z * 2.15)
	else:
		muzzle_pos = global_position + Vector3.UP

	var fire_dir: Vector3
	if is_instance_valid(_player_node):
		var to_player := (_player_node.global_position - muzzle_pos).normalized()
		var is_hovering: bool = _player_node.has_method("is_hover_hazard_active") and _player_node.call("is_hover_hazard_active")
		var spread_factor: float = 0.15 if is_hovering else 1.0
		if _player_node.has_method("get_horizontal_speed") and float(_player_node.call("get_horizontal_speed")) > 12.0:
			spread_factor *= 1.8
		var spread := Vector3(
			randf_range(-0.02, 0.02) * spread_factor,
			randf_range(-0.015, 0.015) * spread_factor,
			randf_range(-0.02, 0.02) * spread_factor
		)
		fire_dir = (to_player + spread).normalized()
	else:
		fire_dir = (-barrel.global_transform.basis.z if barrel else -head.global_transform.basis.z).normalized()

	_log_combat("shot_attempted", "burst %d/%d" % [_shots_fired_in_burst + 1, burst_count])

	# Check muzzle clearance against Layer 1 (World) with a short forward probe to prevent false occlusion by rooftop parapets
	var space := get_world_3d().direct_space_state
	var clear_query := PhysicsRayQueryParameters3D.create(muzzle_pos, muzzle_pos + fire_dir * 0.35, 1) # Layer 1 = World
	clear_query.exclude = [get_rid()]
	var clear_hit := space.intersect_ray(clear_query)
	if not clear_hit.is_empty():
		_log_combat("shot_failed", "muzzle obstructed by %s" % str(clear_hit.collider))
		return false

	var spawn_pos: Vector3 = muzzle_pos + fire_dir * 0.20
	var scaled_damage: float = bullet_damage * CombatDirector.get_damage_multiplier()

	# Spawn projectile from pool
	var proj: Projectile = null
	var pool_node := get_tree().get_first_node_in_group("projectile_pool")
	if pool_node and pool_node.has_method("spawn_projectile"):
		proj = pool_node.spawn_projectile(spawn_pos, fire_dir, false, scaled_damage, 0, 0, 1.0, "turret", self)
	elif ProjectilePool.instance:
		proj = ProjectilePool.instance.spawn_projectile(spawn_pos, fire_dir, false, scaled_damage, 0, 0, 1.0, "turret", self)

	if proj != null:
		debug_shots_fired += 1
		if CombatDirector.instance and CombatDirector.instance.telemetry_enabled:
			CombatDirector.instance.telemetry_projectiles_created += 1
		_log_combat("shot_spawned", "id: %d" % proj.get_instance_id())
		# Directional enemy muzzle flash
		if VfxPool.instance:
			VfxPool.instance.spawn_muzzle_flash(muzzle_pos, fire_dir, true)
		else:
			var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
			if flash_scene:
				var flash := flash_scene.instantiate() as Node3D
				if flash:
					flash.transform.origin = muzzle_pos
					var target_parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
					target_parent.add_child.call_deferred(flash)

		if EventBus:
			EventBus.enemy_fired_weapon.emit(self, muzzle_pos, fire_dir, false)
		return true

	_log_combat("shot_failed", "projectile pool exhausted")
	return false

func _request_slot() -> bool:
	if _arming_timer > 0.0:
		debug_last_blocked_reason = "arming_delay"
		return false

	if CombatDirector.instance and CombatDirector.instance.telemetry_enabled:
		CombatDirector.instance.telemetry_attack_attempts += 1

	var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
	if not dir and CombatDirector.instance:
		dir = CombatDirector.instance
	if dir:
		_log_combat("slot_requested", "turret")
		var granted: bool = dir.request_attack_permission(self, CombatDirector.TOKEN_COST_TURRET, false, false, false, CombatDirector.DANGER_COST_BULLET, "turret")
		_has_attack_slot = granted
		debug_last_blocked_reason = "active" if granted else "token_denied"
		if granted:
			_log_combat("slot_granted", "turret")
		else:
			_log_combat("slot_denied", "turret")
		return granted
	_has_attack_slot = true
	debug_last_blocked_reason = "active_no_director"
	_log_combat("slot_granted", "no_director")
	return true

func _release_slot() -> void:
	if _has_attack_slot:
		var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
		if not dir and CombatDirector.instance:
			dir = CombatDirector.instance
		if dir:
			dir.release_attack_permission(self)
		_log_combat("slot_released")
	_has_attack_slot = false

func _check_line_of_sight() -> bool:
	if not is_instance_valid(_player_node) or not los_ray:
		return false

	var player_pos: Vector3 = _player_node.global_position
	var eye_pos: Vector3 = barrel.global_position if barrel else (global_position + Vector3(0, 1.4, 0))
	los_ray.global_position = eye_pos
	los_ray.target_position = los_ray.to_local(player_pos)
	los_ray.force_raycast_update()

	if los_ray.is_colliding():
		var col := los_ray.get_collider()
		if col != _player_node and not (col is Node and (col as Node).is_in_group("player")):
			return false

	return true

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive or amount <= 0.0:
		return

	var prev_hp: float = current_health
	current_health = maxf(0.0, current_health - amount)
	var actual_damage: float = prev_hp - current_health
	if actual_damage > 0.0:
		_flash_hit()
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("damage_number_spawned"):
			eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 1.2, 0), actual_damage, false, {"target_id": get_instance_id(), "is_lethal": current_health <= 0.0})

	if current_health <= 0.0:
		_die()

var _visual_meshes: Array[MeshInstance3D] = []

func _collect_visual_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child != _laser_beam_mesh:
			_visual_meshes.append(child as MeshInstance3D)
		_collect_visual_meshes(child)

func _flash_hit() -> void:
	if head:
		var tween := create_tween()
		tween.tween_property(head, "scale", Vector3(1.15, 1.15, 1.15), 0.05)
		tween.tween_property(head, "scale", Vector3(1.0, 1.0, 1.0), 0.05)
	if _visual_meshes.is_empty():
		_collect_visual_meshes(self)
	DamageFlashManager.flash_target(self, _visual_meshes)

func _die() -> void:
	if _is_dead or not is_alive:
		return
	_is_dead = true
	is_alive = false
	DamageFlashManager.clear_target(self)
	collision_layer = 0
	collision_mask = 0
	_set_telegraph(false)
	_release_slot()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)
	_release_socket()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_destroyed"):
		eb.emit_signal("enemy_destroyed", self, 100)

	if not _has_spawned_rewards:
		_has_spawned_rewards = true
		var spawn_pos := global_position + Vector3(0, 1.0, 0)
		if XpGemPool.instance:
			XpGemPool.instance.spawn_gem(spawn_pos, xp_reward)
		else:
			var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
			if xp_scene:
				var gem := xp_scene.instantiate() as Node3D
				if gem:
					if "xp_value" in gem:
						gem.xp_value = xp_reward
					gem.transform.origin = spawn_pos
					var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
					p.add_child.call_deferred(gem)

	var expl_pos := global_position + Vector3(0, 1.0, 0)
	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(expl_pos, 1.25)
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = expl_pos
				expl.scale = Vector3(1.5, 1.5, 1.5)
				var target_parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
				target_parent.add_child.call_deferred(expl)

	# Transition visual meshes to charred scrap that lingers briefly
	set_physics_process(false)
	set_process(false)
	if _visual_meshes.is_empty():
		_collect_visual_meshes(self)
	var burnt_mat := _get_burnt_mat()
	for m in _visual_meshes:
		if is_instance_valid(m):
			m.material_override = burnt_mat

	var tw := create_tween()
	if tw:
		tw.tween_interval(2.0)
		tw.tween_property(self, "position:y", position.y - 0.4, 0.6)
		tw.tween_callback(queue_free)
	else:
		get_tree().create_timer(2.6).timeout.connect(queue_free)

func _release_socket() -> void:
	if not reserved_socket_id.is_empty():
		var streamer := get_tree().get_first_node_in_group("city_streamer")
		if streamer and streamer.has_method("release_rooftop_socket"):
			streamer.release_rooftop_socket(reserved_socket_id)
		reserved_socket_id = ""

func despawn_unloaded() -> void:
	if _is_dead or not is_alive:
		return
	_is_dead = true
	is_alive = false
	_release_slot()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)
	_release_socket()
	queue_free()
