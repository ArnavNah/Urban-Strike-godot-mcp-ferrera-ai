class_name SAMSite
extends StaticBody3D

## Surface-to-air missile site with radar lock warning tell, CombatDirector slot lease, and guided missile launch.

enum State {
	SEARCHING,
	TRACKING,
	LOCKING,
	FIRING,
	RELOADING
}

@export var max_health: float = 60.0
@export var threat_range: float = 85.0
@export var degraded_threat_range: float = 60.0
@export var base_lock_time: float = 1.4 # Radar active lock time
@export var degraded_lock_time: float = 2.4 # Radar destroyed lock time (60%+ slower)
@export var reload_time: float = 3.5
@export var missile_damage: float = 22.0 # GDD baseline
@export var missile_scene: PackedScene
@export var xp_reward: int = 25

var _is_dead: bool = false
var _has_spawned_rewards: bool = false
var current_health: float = 60.0
var current_state: State = State.SEARCHING
var is_alive: bool = true

var _state_timer: float = 0.0
var _player: Node3D = null
var _radar_active: bool = false
var _has_attack_slot: bool = false
var _lod_frame_counter: int = 0
var _cached_los: bool = false
var _los_timer: float = 0.0

@onready var radar_dish: Node3D = get_node_or_null("TurretMount/Dish")
@onready var missile_launcher: Node3D = get_node_or_null("TurretMount/Launcher")
@onready var muzzle: Marker3D = get_node_or_null("TurretMount/Launcher/Muzzle")

func _ready() -> void:
	add_to_group("armored_enemies")
	add_to_group("enemies")
	add_to_group("sam_sites")
	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, false)
	current_health = max_health
	_player = get_tree().get_first_node_in_group("player")
	if not missile_scene:
		missile_scene = preload("res://scenes/weapons/guided_missile.tscn")
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("radar_status_changed"):
		eb.radar_status_changed.connect(_on_radar_status_changed)

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

func _on_radar_status_changed(active: bool) -> void:
	_radar_active = active
	if not _radar_active and current_state == State.LOCKING and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) > degraded_threat_range:
			_release_slot()
			_warn_player(false)
			_transition_to(State.SEARCHING)

func _get_effective_lock_time() -> float:
	if _radar_active:
		return base_lock_time
	return degraded_lock_time

func _get_effective_threat_range() -> float:
	if _radar_active:
		return threat_range
	return degraded_threat_range

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(_player.global_position)

	# Distance-based AI LOD throttling (Gap 11)
	_lod_frame_counter += 1
	var step_delta := delta
	if dist > 130.0:
		if radar_dish:
			radar_dish.rotate_y(0.5 * delta)
		return # LOD 3: Culled/Dormant
	elif dist > 75.0:
		if _lod_frame_counter % 4 != 0:
			return # LOD 2: 15 Hz
		step_delta = delta * 4.0
	elif dist > 40.0:
		if _lod_frame_counter % 2 != 0:
			return # LOD 1: 30 Hz
		step_delta = delta * 2.0

	var effective_range := _get_effective_threat_range()

	# Throttled LoS check
	_los_timer -= step_delta
	if _los_timer <= 0.0:
		_los_timer = 0.15 if dist <= 40.0 else 0.3
		_cached_los = _check_los()
	var has_los := _cached_los

	if radar_dish:
		var spin_speed: float = 4.0 if _radar_active else 0.8
		radar_dish.rotate_y(spin_speed * step_delta)

	match current_state:
		State.SEARCHING:
			if dist <= effective_range and has_los:
				_transition_to(State.TRACKING)

		State.TRACKING:
			if not has_los or dist > effective_range:
				_transition_to(State.SEARCHING)
				return

			_aim_at_player(step_delta)
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				if _request_slot():
					_transition_to(State.LOCKING)
				else:
					_state_timer = 0.35 # Wait for slot

		State.LOCKING:
			if not has_los or dist > effective_range:
				_release_slot()
				_warn_player(false)
				_transition_to(State.SEARCHING)
				return

			_aim_at_player(step_delta * 1.5)
			_warn_player(true)
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_warn_player(false)
				_transition_to(State.FIRING)

		State.FIRING:
			_fire_missile()
			_release_slot()
			_transition_to(State.RELOADING)

		State.RELOADING:
			_state_timer -= step_delta
			if _state_timer <= 0.0:
				_transition_to(State.SEARCHING)

func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.SEARCHING:
			_state_timer = 0.0
		State.TRACKING:
			_state_timer = 0.3
		State.LOCKING:
			_state_timer = _get_effective_lock_time()
		State.FIRING:
			pass
		State.RELOADING:
			_state_timer = reload_time

func _aim_at_player(delta: float) -> void:
	if not is_instance_valid(_player) or not missile_launcher:
		return
	var target_pos := _player.global_position
	var local_pos := to_local(target_pos)
	var target_yaw := atan2(-local_pos.x, -local_pos.z)
	missile_launcher.rotation.y = lerp_angle(missile_launcher.rotation.y, target_yaw, 4.5 * delta)

func _warn_player(active: bool) -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("incoming_missile_warning"):
		eb.emit_signal("incoming_missile_warning", global_position, active)

func _fire_missile() -> void:
	if not is_instance_valid(_player):
		return
	var spawn_pos: Vector3 = muzzle.global_position if muzzle else global_position
	var fire_dir: Vector3 = (global_position.direction_to(_player.global_position) + Vector3.UP * 0.4).normalized()

	var missile: Node3D = missile_scene.instantiate() as Node3D
	if missile:
		missile.transform.origin = spawn_pos
		missile.damage = missile_damage
		var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
		parent.add_child.call_deferred(missile)
		missile.call_deferred("launch", spawn_pos, fire_dir, _player, false)

func _check_los() -> bool:
	if not is_instance_valid(_player):
		return false
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0, 1.8, 0)
	var target_pos := _player.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, target_pos, 1) # Layer 1 = World
	var hit := space.intersect_ray(query)
	return hit.is_empty()

func _request_slot() -> bool:
	var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
	if not dir and CombatDirector.instance:
		dir = CombatDirector.instance
	if dir:
		var granted: bool = dir.request_attack_slot(self, false)
		_has_attack_slot = granted
		return granted
	_has_attack_slot = true
	return true

func _release_slot() -> void:
	if _has_attack_slot:
		var dir := get_tree().get_first_node_in_group("combat_director") as CombatDirector
		if not dir and CombatDirector.instance:
			dir = CombatDirector.instance
		if dir:
			dir.release_attack_slot(self, false)
	_has_attack_slot = false

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return
	current_health = maxf(0.0, current_health - amount)
	_trigger_damage_flash()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 1.5, 0), amount, amount >= 30.0)
	if current_health <= 0.0:
		_die()

var _visual_meshes: Array[MeshInstance3D] = []
static var _flash_mat: StandardMaterial3D = null

func _collect_visual_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
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
		get_tree().create_timer(0.06, false).timeout.connect(func():
			for m in _visual_meshes:
				if is_instance_valid(m) and m.material_override == _flash_mat:
					m.material_override = null
		)

func _die() -> void:
	if _is_dead or not is_alive:
		return
	_is_dead = true
	is_alive = false
	_warn_player(false)
	_release_slot()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_destroyed"):
		eb.emit_signal("enemy_destroyed", self, 120)

	_spawn_xp()

	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(global_position + Vector3(0, 1.2, 0), 1.6)
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = global_position + Vector3(0, 1.2, 0)
				expl.scale = Vector3(2.0, 2.0, 2.0)
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(expl)
	queue_free()

func _spawn_xp() -> void:
	if _has_spawned_rewards:
		return
	_has_spawned_rewards = true
	var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
	if xp_scene:
		var gem := xp_scene.instantiate() as Node3D
		if gem:
			if "xp_value" in gem:
				gem.xp_value = xp_reward
			gem.transform.origin = global_position + Vector3(0, 1.0, 0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)
