class_name Mig17Striker
extends CharacterBody3D

## High-speed straight attack-pass jet enemy using the MiG-17F model.
## Flies on a committed straight line across the player's airspace at 70-80 m/s.
## Gives a readable audio/visual vector warning before firing a high-velocity cannon burst.
## Zooms past and exits offscreen without hovering or instant swiveling in place.
## Cleans up without reward drops if it exits normally, or explodes with full rewards if shot down.

enum State {
	APPROACH,
	STRAFE,
	EXIT,
	COOLDOWN_OFFSCREEN
}

@export var max_health: float = 65.0
@export var flight_speed: float = 72.0
@export var burst_count: int = 8
@export var damage_per_shot: float = 4.0
@export var salvage_reward: int = 80
@export var xp_reward: int = 24
@export var threat_score: float = 1.0

var current_health: float = 65.0
var is_alive: bool = true
var _is_dead: bool = false
var _has_spawned_rewards: bool = false

var _current_state: State = State.APPROACH
var _flight_direction: Vector3 = Vector3.FORWARD
var _pass_target: Vector3 = Vector3.ZERO
var _player: Node3D = null
var _shots_fired: int = 0
var _shot_timer: float = 0.0
var _state_time: float = 0.0
var _has_attack_slot: bool = false
var _telegraph_active: bool = false
var _passes_completed: int = 0
var _max_passes: int = 2

var _visual_meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D = null

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var muzzle_left: Marker3D = get_node_or_null("Visuals/MuzzleLeft")
@onready var muzzle_right: Marker3D = get_node_or_null("Visuals/MuzzleRight")
@onready var warning_light: OmniLight3D = get_node_or_null("Visuals/WarningLight")

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("air_enemies")

	current_health = max_health

	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, true)

	_player = get_tree().get_first_node_in_group("player")
	_collect_visual_meshes(self)
	_setup_flash_mat()

	if visuals and warning_light:
		warning_light.visible = false

	# Setup initial pass
	_init_pass()

func _setup_flash_mat() -> void:
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1.0, 0.9, 0.8, 1.0)

func _collect_visual_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		_visual_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_visual_meshes(child)

func _init_pass() -> void:
	_current_state = State.APPROACH
	_state_time = 0.0
	_shots_fired = 0
	_shot_timer = 0.0
	_telegraph_active = false
	if warning_light:
		warning_light.visible = false

	var target_pos := Vector3.ZERO
	if is_instance_valid(_player):
		target_pos = _player.global_position

	# Pass waypoint slightly offset from player so it doesn't just ram the player directly
	var side_offset := Vector3(randf_range(-8.0, 8.0), randf_range(1.0, 4.0), randf_range(-8.0, 8.0))
	_pass_target = target_pos + side_offset
	# Ensure safe minimum flight altitude
	_pass_target.y = clampf(_pass_target.y, 14.0, 26.0)

	var to_target := (_pass_target - global_position)
	to_target.y = clampf(to_target.y, -6.0, 6.0)
	if to_target.length_squared() > 1.0:
		_flight_direction = to_target.normalized()
	else:
		_flight_direction = -global_transform.basis.z

	# Strictly align heading along flight direction (no swiveling or hovering)
	_align_transform_to_direction(_flight_direction)
	velocity = _flight_direction * flight_speed

func _align_transform_to_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.001:
		return
	var forward := dir.normalized()
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var right := forward.cross(up).normalized()
	var true_up := right.cross(forward).normalized()
	global_transform.basis = Basis(right, true_up, -forward)

func _physics_process(delta: float) -> void:
	if not is_alive or _is_dead:
		return

	_state_time += delta

	match _current_state:
		State.APPROACH:
			_process_approach(delta)
		State.STRAFE:
			_process_strafe(delta)
		State.EXIT:
			_process_exit(delta)
		State.COOLDOWN_OFFSCREEN:
			_process_cooldown(delta)

	move_and_slide()

func _process_approach(_delta: float) -> void:
	velocity = _flight_direction * flight_speed

	var dist_to_target := global_position.distance_to(_pass_target)

	# Telegraph warning when within 75m
	if dist_to_target <= 75.0 and not _telegraph_active:
		_telegraph_active = true
		if warning_light:
			warning_light.visible = true
		_request_attack_token()

	# Start firing burst when within 55m
	if dist_to_target <= 55.0:
		_current_state = State.STRAFE
		_shot_timer = 0.0

func _process_strafe(delta: float) -> void:
	velocity = _flight_direction * flight_speed

	_shot_timer -= delta
	if _shot_timer <= 0.0 and _shots_fired < burst_count:
		_shot_timer = 0.08 # 12.5 rounds per second
		_fire_jet_round()
		_shots_fired += 1

	# Check if passed the target or finished burst
	var to_target := _pass_target - global_position
	var dot := to_target.dot(_flight_direction)
	if dot < -5.0 or _shots_fired >= burst_count:
		_release_attack_token()
		if warning_light:
			warning_light.visible = false
		_current_state = State.EXIT
		_state_time = 0.0

func _process_exit(_delta: float) -> void:
	# Keep flying on committed heading
	velocity = _flight_direction * flight_speed

	var p_pos := _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	var dist := global_position.distance_to(p_pos)

	if dist > 130.0 or _state_time > 4.5:
		_passes_completed += 1
		if _passes_completed >= _max_passes:
			# Completed scheduled pass runs, clean exit without reward drops
			_clean_despawn()
		else:
			_current_state = State.COOLDOWN_OFFSCREEN
			_state_time = 0.0

func _process_cooldown(_delta: float) -> void:
	velocity = Vector3.ZERO
	if _state_time >= 5.0:
		# Reposition offscreen for pass #2
		if is_instance_valid(_player):
			var angle := randf_range(0.0, TAU)
			var offset := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(110.0, 130.0)
			global_position = _player.global_position + offset
			global_position.y = clampf(_player.global_position.y + randf_range(8.0, 16.0), 16.0, 28.0)
		_init_pass()

func _fire_jet_round() -> void:
	var muzzle_pos := global_position + (-global_transform.basis.z * 2.8)
	if _shots_fired % 2 == 0 and muzzle_left:
		muzzle_pos = muzzle_left.global_position
	elif muzzle_right:
		muzzle_pos = muzzle_right.global_position

	var target_pt := _pass_target
	if is_instance_valid(_player):
		target_pt = _player.global_position + Vector3(randf_range(-1.2, 1.2), randf_range(-0.6, 0.6), randf_range(-1.2, 1.2))
	var fire_dir := (target_pt - muzzle_pos).normalized()

	var dmg := damage_per_shot * CombatDirector.get_damage_multiplier()

	var pool: Node = get_tree().get_first_node_in_group("projectile_pool")
	if pool and pool.has_method("spawn_projectile"):
		pool.spawn_projectile(muzzle_pos, fire_dir, false, dmg)

func _request_attack_token() -> void:
	if _has_attack_slot:
		return
	if CombatDirector.instance:
		_has_attack_slot = CombatDirector.instance.request_attack_permission(
			self,
			1,
			true,
			false,
			false,
			2,
			"jet_strafe"
		)

func _release_attack_token() -> void:
	if _has_attack_slot:
		_has_attack_slot = false
		if CombatDirector.instance:
			CombatDirector.instance.release_attack_permission(self)

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO, _hit_norm: Vector3 = Vector3.UP) -> void:
	if not is_alive or _is_dead:
		return

	current_health -= amount

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 0.5, 0), amount, false)

	_flash_hit()

	if current_health <= 0.0:
		_die()

func _flash_hit() -> void:
	if _flash_mat:
		for m in _visual_meshes:
			if is_instance_valid(m):
				m.material_override = _flash_mat
		get_tree().create_timer(0.05, false).timeout.connect(func():
			for m in _visual_meshes:
				if is_instance_valid(m) and m.material_override == _flash_mat:
					m.material_override = null
		)

func _die() -> void:
	if _is_dead or not is_alive:
		return
	_is_dead = true
	is_alive = false
	_release_attack_token()

	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("enemy_destroyed"):
		eb.emit_signal("enemy_destroyed", self, salvage_reward)

	_spawn_rewards()

	var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
	if expl_scene:
		var expl := expl_scene.instantiate() as Node3D
		if expl:
			expl.transform.origin = global_position
			expl.scale = Vector3(2.2, 2.2, 2.2)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(expl)

	queue_free()

func _spawn_rewards() -> void:
	if _has_spawned_rewards:
		return
	_has_spawned_rewards = true
	var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
	if xp_scene:
		var gem := xp_scene.instantiate() as Node3D
		if gem:
			gem.transform.origin = global_position
			if gem.has_method("set_xp_value"):
				gem.set_xp_value(xp_reward)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(gem)

func _clean_despawn() -> void:
	# Exited player airspace cleanly - unregister without reward drops or token leaks
	_release_attack_token()
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)
	queue_free()
