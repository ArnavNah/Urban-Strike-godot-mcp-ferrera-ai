class_name BossArchon
extends CharacterBody3D

@export var max_health: float = 650.0
@export var speed_phase1: float = 12.0
@export var speed_phase2: float = 18.0
@export var speed_phase3: float = 22.0

var current_health: float = 650.0
var current_phase: int = 1
var is_alive: bool = true
var _orbit_angle: float = 0.0
var _cannon_timer: float = 0.0
var _rocket_timer: float = 0.0
var _escort_spawned: bool = false
var _player: Node3D = null
var _is_dead: bool = false
var _has_spawned_rewards: bool = false

@onready var front_rotor: Node3D = $Visuals/FrontRotor
@onready var rear_rotor: Node3D = $Visuals/RearRotor
@onready var chin_cannon: Node3D = $Visuals/ChinCannon
@onready var cannon_muzzle: Marker3D = $Visuals/ChinCannon/Muzzle
@onready var left_engine_fire: GPUParticles3D = $Visuals/LeftEngineFire
@onready var right_engine_fire: GPUParticles3D = $Visuals/RightEngineFire
@onready var core_light: OmniLight3D = $Visuals/CoreLight

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("air_enemies")
	if EnemyRegistry.instance:
		EnemyRegistry.instance.register_enemy(self, true)
	current_health = max_health
	_player = get_tree().get_first_node_in_group("player")
	if left_engine_fire:
		left_engine_fire.emitting = false
	if right_engine_fire:
		right_engine_fire.emitting = false
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("boss_spawned"):
			eb.emit_signal("boss_spawned", self)
		if eb.has_signal("boss_health_changed"):
			eb.emit_signal("boss_health_changed", current_health, max_health, current_phase)

func _exit_tree() -> void:
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	# Spin heavy tandem rotors
	if front_rotor:
		front_rotor.rotate_y(26.0 * delta)
	if rear_rotor:
		rear_rotor.rotate_y(-26.0 * delta)

	# Update Phase Thresholds (GDD: 66% and 33%)
	var hp_ratio := current_health / max_health
	if hp_ratio > 0.66:
		if current_phase != 1:
			_set_phase(1)
	elif hp_ratio > 0.33:
		if current_phase != 2:
			_set_phase(2)
	else:
		if current_phase != 3:
			_set_phase(3)

	match current_phase:
		1:
			_process_phase_1(delta)
		2:
			_process_phase_2(delta)
		3:
			_process_phase_3(delta)

func _set_phase(new_phase: int) -> void:
	current_phase = new_phase
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("boss_health_changed"):
		eb.emit_signal("boss_health_changed", current_health, max_health, current_phase)

	match current_phase:
		2:
			if left_engine_fire:
				left_engine_fire.emitting = true
			if core_light:
				core_light.light_color = Color(1.0, 0.5, 0.1)
		3:
			if left_engine_fire:
				left_engine_fire.emitting = true
			if right_engine_fire:
				right_engine_fire.emitting = true
			if core_light:
				core_light.light_color = Color(1.0, 0.15, 0.1)

func _process_phase_1(delta: float) -> void:
	# Controlled wide orbiting pattern at player's altitude
	_orbit_angle += 0.4 * delta
	var target_pos := _player.global_position + Vector3(cos(_orbit_angle), 0, sin(_orbit_angle)) * 42.0
	target_pos.y = _player.global_position.y
	_fly_toward_pos(target_pos, speed_phase1, delta)

	# Sustained chin-cannon barrages
	_cannon_timer -= delta
	if _cannon_timer <= 0.0:
		_cannon_timer = 0.16
		_fire_chin_cannon()

	# Summon single escort hunter in Phase 1
	if not _escort_spawned:
		_escort_spawned = true
		_spawn_hunter_escort()

func _process_phase_2(delta: float) -> void:
	# Faster repositioning sweeps at player's altitude
	_orbit_angle += 0.7 * delta
	var target_pos := _player.global_position + Vector3(cos(_orbit_angle), 0, sin(_orbit_angle)) * 34.0
	target_pos.y = _player.global_position.y
	_fly_toward_pos(target_pos, speed_phase2, delta)

	# Cannon fire + 4-rocket spread salvos
	_cannon_timer -= delta
	if _cannon_timer <= 0.0:
		_cannon_timer = 0.22
		_fire_chin_cannon()

	_rocket_timer -= delta
	if _rocket_timer <= 0.0:
		_rocket_timer = 3.2
		_fire_rocket_salvo(4)

func _process_phase_3(delta: float) -> void:
	# Enraged fast dive runs at player's altitude
	_orbit_angle += 1.1 * delta
	var target_pos := _player.global_position + Vector3(cos(_orbit_angle), 0, sin(_orbit_angle)) * 26.0
	target_pos.y = _player.global_position.y
	_fly_toward_pos(target_pos, speed_phase3, delta)

	# Rapid bursts + continuous missile pressure
	_cannon_timer -= delta
	if _cannon_timer <= 0.0:
		_cannon_timer = 0.11
		_fire_chin_cannon()

	_rocket_timer -= delta
	if _rocket_timer <= 0.0:
		_rocket_timer = 2.4
		_fire_rocket_salvo(6)

func _fly_toward_pos(dest: Vector3, speed: float, delta: float) -> void:
	var to_dest := dest - global_position
	var dir := to_dest.normalized()
	velocity = dir * speed
	move_and_slide()

	# Face player
	if is_instance_valid(_player):
		var face_dir := (_player.global_position - global_position).normalized()
		var target_yaw := atan2(-face_dir.x, -face_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 3.0 * delta)

func _fire_chin_cannon() -> void:
	if not is_instance_valid(_player):
		return
	var muzzle_pos: Vector3 = cannon_muzzle.global_position if cannon_muzzle else global_position
	var fire_dir := (_player.global_position - muzzle_pos).normalized()
	fire_dir += Vector3(randf_range(-0.06, 0.06), randf_range(-0.04, 0.04), randf_range(-0.06, 0.06))

	var pool := get_tree().get_first_node_in_group("projectile_pool")
	if pool and pool.has_method("spawn_projectile"):
		pool.spawn_projectile(muzzle_pos, fire_dir.normalized(), false, 5.0)

	var flash_scene: PackedScene = preload("res://scenes/vfx/muzzle_flash.tscn")
	if flash_scene:
		var flash := flash_scene.instantiate() as Node3D
		if flash:
			flash.transform.origin = muzzle_pos
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(flash)

func _fire_rocket_salvo(count: int) -> void:
	if not is_instance_valid(_player):
		return
	var missile_scene: PackedScene = preload("res://scenes/weapons/guided_missile.tscn")
	if not missile_scene:
		return

	for i in range(count):
		var missile: Node3D = missile_scene.instantiate() as Node3D
		if missile:
			var spread_offset := Vector3(randf_range(-2.5, 2.5), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0))
			var spawn_pos := global_position + spread_offset
			var fire_dir := (global_position.direction_to(_player.global_position) + Vector3(randf_range(-0.2, 0.2), 0.2, randf_range(-0.2, 0.2))).normalized()
			missile.transform.origin = spawn_pos
			missile.damage = 18.0
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(missile)
			missile.call_deferred("launch", spawn_pos, fire_dir, _player, false)

func _spawn_hunter_escort() -> void:
	var hunter_scene: PackedScene = preload("res://scenes/enemies/hunter_helicopter.tscn")
	if hunter_scene:
		var hunter := hunter_scene.instantiate() as Node3D
		if hunter:
			hunter.transform.origin = global_position + Vector3(randf_range(-15, 15), 0.0, randf_range(-15, 15))
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(hunter)

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_alive:
		return

	current_health = maxf(0.0, current_health - amount)
	_trigger_damage_flash()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("boss_health_changed"):
			eb.emit_signal("boss_health_changed", current_health, max_health, current_phase)
		if eb.has_signal("damage_number_spawned"):
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
	if EnemyRegistry.instance:
		EnemyRegistry.instance.unregister_enemy(self)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("boss_defeated"):
			eb.emit_signal("boss_defeated")
		if eb.has_signal("enemy_destroyed"):
			eb.emit_signal("enemy_destroyed", self, 1500)

	# Award large salvage
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage"):
		gm.add_salvage(500)

	# Award 2 Requisitions for Boss defeat
	var um := get_tree().get_first_node_in_group("upgrade_manager") as UpgradeManager
	if um:
		um.award_requisition(2)

	# Spawn high-value Salvage Crates
	var crate_scene: PackedScene = preload("res://scenes/pickups/salvage_crate.tscn")
	if crate_scene:
		for i in range(2):
			var crate := crate_scene.instantiate() as Node3D
			if crate:
				crate.transform.origin = global_position + Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(crate)

	# Spawn high-value Boss XP Gems (75 XP total: 3 x 25 XP)
	if not _has_spawned_rewards:
		_has_spawned_rewards = true
		var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
		if xp_scene:
			for i in range(3):
				var gem := xp_scene.instantiate() as Node3D
				if gem:
					if "xp_value" in gem:
						gem.xp_value = 25
					gem.transform.origin = global_position + Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
					var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
					p.add_child.call_deferred(gem)

	# Multi-explosion sequence using VfxPool
	for i in range(8):
		var offset := Vector3(randf_range(-3, 3), randf_range(-1, 2), randf_range(-4, 4))
		var expl_pos := global_position + offset
		if VfxPool.instance:
			VfxPool.instance.spawn_explosion(expl_pos, 2.2)
		else:
			var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
			if expl_scene:
				var expl := expl_scene.instantiate() as Node3D
				if expl:
					expl.transform.origin = expl_pos
					expl.scale = Vector3(2.8, 2.8, 2.8)
					var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
					p.add_child.call_deferred(expl)

	queue_free()
