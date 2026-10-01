class_name GuidedMissile
extends Node3D

@export var speed: float = 65.0
@export var damage: float = 45.0 # GDD baseline
@export var splash_radius: float = 3.2 # GDD baseline
@export var turn_rate: float = 6.0 # Rad/s steering
@export var max_lifetime: float = 4.0

var target: Node3D = null
var is_player_missile: bool = true
var _lifetime: float = 0.0
var _has_exploded: bool = false

@onready var raycast: RayCast3D = $RayCast3D
@onready var smoke_trail: GPUParticles3D = $SmokeTrail

func _ready() -> void:
	add_to_group("homing_missiles")
	SaveSystem._apply_particle_budget(self, SaveSystem.low_particles)

func launch(start_pos: Vector3, initial_dir: Vector3, missile_target: Node3D, from_player: bool = true) -> void:
	global_position = start_pos
	look_at(start_pos + initial_dir, Vector3.UP if absf(initial_dir.y) < 0.9 else Vector3.FORWARD)
	target = missile_target
	is_player_missile = from_player
	_lifetime = 0.0
	_has_exploded = false

	if raycast:
		raycast.clear_exceptions()
		if is_player_missile:
			raycast.collision_mask = (1 << 0) | (1 << 2) # World + Enemies
		else:
			raycast.collision_mask = (1 << 0) | (1 << 1) # World + Player
			add_to_group("incoming_enemy_missiles")

func divert_to_flare(flare_pos: Vector3) -> void:
	# Fooled by defensive countermeasure flare
	target = null
	if is_in_group("incoming_enemy_missiles"):
		remove_from_group("incoming_enemy_missiles")
	# Steer erratically towards flare position or deviate
	var jitter_dir := (flare_pos - global_position).normalized() + Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	look_at(global_position + jitter_dir.normalized(), Vector3.UP)

func _exit_tree() -> void:
	if is_in_group("incoming_enemy_missiles"):
		remove_from_group("incoming_enemy_missiles")

func _physics_process(delta: float) -> void:
	if _has_exploded:
		return

	_lifetime += delta
	if _lifetime >= max_lifetime:
		explode(global_position)
		return

	# Steer toward target if target exists and is alive
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		var aim_pos: Vector3 = target.global_position + Vector3(0, 0.8, 0)
		var desired_dir := (aim_pos - global_position).normalized()
		var current_fwd := -global_transform.basis.z
		var new_fwd := current_fwd.slerp(desired_dir, turn_rate * delta).normalized()
		look_at(global_position + new_fwd, Vector3.UP if absf(new_fwd.y) < 0.9 else Vector3.FORWARD)

	var move_dist := speed * delta
	var step_vec := -global_transform.basis.z * move_dist

	# Obstacle ray check
	if raycast:
		raycast.target_position = to_local(global_position + step_vec * 1.5)
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var hit_col: Object = raycast.get_collider()
			var hit_pos := raycast.get_collision_point()
			explode(hit_pos, hit_col)
			return

	global_position += step_vec

func explode(impact_pos: Vector3, direct_collider: Object = null) -> void:
	if _has_exploded:
		return
	_has_exploded = true
	if is_in_group("incoming_enemy_missiles"):
		remove_from_group("incoming_enemy_missiles")

	# Splash damage query
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = splash_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), impact_pos)
	if is_player_missile:
		query.collision_mask = (1 << 2) # Enemies
	else:
		query.collision_mask = (1 << 1) # Player

	var results := space.intersect_shape(query, 16)
	var processed_targets: Array[Object] = []

	# If direct collider was hit, process it first
	if direct_collider != null and direct_collider.has_method("take_damage"):
		_apply_target_damage(direct_collider, impact_pos, true, 0.0)
		processed_targets.append(direct_collider)

	for r in results:
		var col: Object = r.get("collider")
		if col in processed_targets:
			continue
		if col and col.has_method("take_damage"):
			processed_targets.append(col)
			var col_pos: Vector3 = col.global_position if col is Node3D else impact_pos
			var dist := impact_pos.distance_to(col_pos)
			var is_direct: bool = (col == direct_collider or (is_instance_valid(target) and col == target))
			_apply_target_damage(col, impact_pos, is_direct, dist)

func _apply_target_damage(col: Object, impact_pos: Vector3, is_direct: bool, dist: float) -> void:
	var falloff := 1.0 if is_direct else clampf(1.0 - (dist / splash_radius), 0.35, 1.0)
	var applied_dmg: float = damage * falloff

	# Direct High-Value Payload Bonus (Phase 1):
	# Deliberate strikes against armored ground units, rooftop turrets, or dangerous combat aircraft
	# deal an enhanced 1.6x anti-armor/structural payload (72.0 damage baseline)
	if is_player_missile and is_direct and col is Node:
		var node := col as Node
		var is_high_value: bool = (
			node.is_in_group("armored_enemies")
			or node.is_in_group("tanks")
			or node.is_in_group("turrets")
			or node.is_in_group("sam_sites")
			or node.is_in_group("rocket_raiders")
			or node.is_in_group("attack_gunships")
			or node.is_in_group("ace_gunships")
			or node.is_in_group("air_enemies")
			or node.is_in_group("bosses")
			or node.is_in_group("objectives")
		)
		if is_high_value:
			applied_dmg *= 1.6

	col.take_damage(applied_dmg, self, impact_pos)
	if is_player_missile:
		var gm: Node = get_tree().get_first_node_in_group("game_manager")
		if gm and gm.has_method("record_attributed_damage"):
			gm.call("record_attributed_damage", applied_dmg, "missiles")
		var is_dead: bool = false
		if "current_health" in col and float(col.get("current_health")) <= 0.0:
			is_dead = true
		elif "is_alive" in col and col.get("is_alive") == false:
			is_dead = true
		if is_dead and gm and gm.has_method("record_attributed_kill"):
			gm.call("record_attributed_kill", "missiles")

	# Restrained camera shake & audio event for missile impact
	if EventBus:
		if EventBus.has_signal("camera_shake_requested"):
			EventBus.camera_shake_requested.emit(0.18)
		if EventBus.has_signal("missile_impact_occurred"):
			EventBus.missile_impact_occurred.emit(impact_pos, is_player_missile)

	# Spawn explosion VFX (VfxPool with fallback)
	if VfxPool.instance:
		VfxPool.instance.spawn_explosion(impact_pos, 1.1)
	else:
		var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
		if expl_scene:
			var expl := expl_scene.instantiate() as Node3D
			if expl:
				expl.transform.origin = impact_pos
				expl.scale = Vector3(1.8, 1.8, 1.8)
				var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
				parent.add_child.call_deferred(expl)

	if not is_player_missile and CombatDirector.instance:
		CombatDirector.instance.release_danger_capacity(self, CombatDirector.DANGER_COST_HOMING_MISSILE)

	queue_free()
