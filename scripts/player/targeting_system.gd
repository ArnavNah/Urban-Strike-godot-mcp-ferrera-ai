class_name TargetingSystem
extends Node3D

## Authoritative target acquisition component for AH-9 Vulture.
## Handles target gathering, 360-degree omnidirectional gun-arc validation,
## predictive lead aiming, building LoS raycasts, target stickiness/hysteresis,
## mission-aware scoring, and density filtering.

@export_group("Acquisition Geometry")
@export var acquisition_range: float = 110.0
@export var manual_override_settle_time: float = 0.6
@export var max_yaw_arc_deg: float = 180.0
@export var min_pitch_deg: float = -85.0
@export var max_pitch_deg: float = 45.0
@export var hysteresis_dist_threshold: float = 8.0

@export_group("Stickiness & Hysteresis")
@export var target_stickiness_time: float = 0.25
@export var persistence_score_bonus: float = 0.35
@export var switch_score_threshold_ratio: float = 0.15

var current_target: Node3D = null
var is_manual_aim: bool = false
var manual_aim_point: Vector3 = Vector3.ZERO

var _manual_settle_timer: float = 0.0
var _stickiness_timer: float = 0.0
var _cached_candidate_count: int = 0
var _current_target_has_los: bool = false

signal target_changed(new_target: Node3D)
signal manual_aim_toggled(is_manual: bool)

func _physics_process(delta: float) -> void:
	if _manual_settle_timer > 0.0:
		_manual_settle_timer -= delta
		if _manual_settle_timer <= 0.0:
			_set_manual_aim(false)

	if _stickiness_timer > 0.0:
		_stickiness_timer -= delta

	_update_auto_target()

func trigger_manual_aim(world_point: Vector3) -> void:
	manual_aim_point = world_point
	_manual_settle_timer = manual_override_settle_time
	if not is_manual_aim:
		_set_manual_aim(true)

func _set_manual_aim(manual: bool) -> void:
	if is_manual_aim != manual:
		is_manual_aim = manual
		manual_aim_toggled.emit(is_manual_aim)
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("manual_aim_state_changed"):
			eb.emit_signal("manual_aim_state_changed", is_manual_aim)

func is_jammed() -> bool:
	var jammers := get_tree().get_nodes_in_group("jammers")
	for j in jammers:
		if is_instance_valid(j) and not (j as Node).is_queued_for_deletion():
			if not ("is_alive" in j) or j.is_alive:
				return true
	return false

## Computes target position with projectile lead prediction based on target velocity.
func get_predicted_target_position(target: Node3D, muzzle_pos: Vector3, projectile_speed: float = 140.0) -> Vector3:
	if not is_instance_valid(target):
		return Vector3.ZERO
	var base_pos := _get_target_center(target)
	var vel := Vector3.ZERO
	if "velocity" in target:
		vel = target.velocity
	elif "linear_velocity" in target:
		vel = target.linear_velocity
	var dist := muzzle_pos.distance_to(base_pos)
	var t := dist / maxf(1.0, projectile_speed)
	return base_pos + vel * t

func get_aim_target_position(default_forward: Vector3) -> Vector3:
	if is_manual_aim:
		return manual_aim_point
	elif is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
		var gun_origin: Vector3 = to_global(Vector3(0.0, -0.4, -1.2))
		var aim := get_predicted_target_position(current_target, gun_origin, 140.0)
		if is_jammed():
			var jitter := Vector3(randf_range(-0.4, 0.4), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4))
			aim += jitter
		return aim
	else:
		return global_position + default_forward * 60.0

func _get_target_center(target_node: Node3D) -> Vector3:
	if not is_instance_valid(target_node):
		return Vector3.ZERO
	var y_off: float = 0.6
	if target_node is CharacterBody3D:
		y_off = 0.8
	elif target_node.has_node("CollisionShape3D"):
		var col: CollisionShape3D = target_node.get_node("CollisionShape3D") as CollisionShape3D
		if col:
			return col.global_position
	return target_node.global_position + Vector3(0.0, y_off, 0.0)

func _update_auto_target() -> void:
	var space := get_world_3d().direct_space_state
	var player_node := get_parent() as CollisionObject3D
	var player_rid: RID = player_node.get_rid() if player_node else RID()

	var gun_origin: Vector3 = to_global(Vector3(0.0, -0.4, -1.2))

	# 1. Gather all living enemies in range (EnemyRegistry spatial query + group fallback)
	var candidate_enemies: Array[Node3D] = []
	if EnemyRegistry.instance and is_instance_valid(EnemyRegistry.instance) and not EnemyRegistry.instance.is_queued_for_deletion():
		candidate_enemies = EnemyRegistry.instance.get_enemies_in_radius(gun_origin, acquisition_range)

	var raw_nodes := get_tree().get_nodes_in_group("enemies")
	for n in raw_nodes:
		var e := n as Node3D
		if is_instance_valid(e) and not candidate_enemies.has(e):
			candidate_enemies.append(e)

	var valid_candidates: Array[Dictionary] = []

	for enemy in candidate_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy == player_node:
			continue

		# Check if alive
		if "is_alive" in enemy and not enemy.is_alive:
			continue

		var target_pos: Vector3 = _get_target_center(enemy)
		var dist: float = gun_origin.distance_to(target_pos)
		if dist > acquisition_range or dist < 0.5:
			continue

		# 2. Check gun allowed aiming arc using accurate to_local transform
		var local_to_target: Vector3 = to_local(target_pos)
		var yaw: float = atan2(-local_to_target.x, -local_to_target.z)
		var flat_dist: float = Vector2(local_to_target.x, local_to_target.z).length()
		var pitch: float = atan2(local_to_target.y, flat_dist)

		if max_yaw_arc_deg < 179.9 and absf(yaw) > deg_to_rad(max_yaw_arc_deg) + 0.005:
			continue
		if pitch < deg_to_rad(min_pitch_deg) - 0.005 or pitch > deg_to_rad(max_pitch_deg) + 0.005:
			continue

		# 3. Raycast Line of Sight check (World Layer 1 blocks LoS)
		# Exclude both player and the target enemy itself so the enemy never occludes itself
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(gun_origin, target_pos, 1)
		var excludes: Array[RID] = []
		if player_rid.is_valid():
			excludes.append(player_rid)
		if enemy is CollisionObject3D:
			var erid: RID = (enemy as CollisionObject3D).get_rid()
			if erid.is_valid():
				excludes.append(erid)
		ray_query.exclude = excludes

		var hit: Dictionary = space.intersect_ray(ray_query)
		if hit.is_empty() or hit.get("collider") == enemy:
			valid_candidates.append({
				"node": enemy,
				"dist": dist,
				"yaw": yaw
			})

	_cached_candidate_count = valid_candidates.size()

	# 4. Score all candidates with Proximity, Mission-Aware & Density-Aware rules
	var best_candidate: Node3D = null
	var best_score: float = -INF
	var current_target_score: float = -INF

	for c in valid_candidates:
		var node: Node3D = c["node"] as Node3D
		var score: float = _calculate_candidate_score(node, c["dist"], c["yaw"], _cached_candidate_count)
		c["score"] = score

		if node == current_target:
			current_target_score = score

		if score > best_score:
			best_score = score
			best_candidate = node

	# 5. Target selection with persistence, stickiness, and hysteresis
	if is_instance_valid(current_target) and current_target_score > -INF:
		_current_target_has_los = true

		var req_multiplier: float = 1.0 + switch_score_threshold_ratio
		if _stickiness_timer > 0.0:
			req_multiplier += 0.15 # Stronger resistance while sticky

		if best_candidate != null and best_candidate != current_target:
			if best_score > current_target_score * req_multiplier:
				_set_current_target(best_candidate)
				_stickiness_timer = target_stickiness_time
		return

	# No valid current target with LoS
	_current_target_has_los = false
	if best_candidate != null:
		_set_current_target(best_candidate)
		_stickiness_timer = target_stickiness_time
	else:
		_clear_target()

func _calculate_candidate_score(enemy: Node3D, dist: float, local_yaw: float, candidate_count: int) -> float:
	# Alignment score: 1.0 at center line, 0.0 at 180 degrees
	var yaw_ratio: float = clampf(absf(local_yaw) / deg_to_rad(max_yaw_arc_deg), 0.0, 1.0)
	var alignment_score: float = 1.0 - yaw_ratio

	# Proximity score: 1.0 at 0m, 0.0 at acquisition range
	var proximity_score: float = 1.0 - clampf(dist / acquisition_range, 0.0, 1.0)

	# Extra close-range urgency bonus for swarms within 25m
	var close_threat_bonus: float = 0.0
	if dist <= 25.0:
		close_threat_bonus = (25.0 - dist) / 25.0 * 2.0

	# Base threat score
	var threat_weight: float = _get_enemy_threat_weight(enemy)

	# Mission-aware priority bonus
	var mission_bonus: float = _get_mission_priority_bonus(enemy)

	# Density-aware filtering: at high density (> 20), distant low-threat grunts suffer penalty
	if candidate_count > 20 and threat_weight <= 0.25 and dist > 25.0:
		if absf(local_yaw) > deg_to_rad(45.0):
			threat_weight *= 0.3

	var total_score: float = (
		alignment_score * 1.5
		+ proximity_score * 2.5
		+ close_threat_bonus
		+ threat_weight * 2.0
		+ mission_bonus
	)

	# Persistence bonus for current target
	if enemy == current_target:
		total_score += persistence_score_bonus

	return total_score

func _get_enemy_threat_weight(enemy: Node3D) -> float:
	if not is_instance_valid(enemy):
		return 0.25
	if enemy.is_in_group("bosses"):
		return 1.25
	if enemy.is_in_group("ace_gunships"):
		return 1.20
	if enemy.is_in_group("jammers"):
		return 1.15
	if enemy.is_in_group("sam_sites"):
		return 1.0
	if enemy.is_in_group("objectives"):
		return 1.0
	if enemy.is_in_group("attack_gunships"):
		return 0.90
	if enemy.is_in_group("hunters"):
		return 0.85
	if enemy.is_in_group("rocket_raiders"):
		return 0.75
	if enemy.is_in_group("transports"):
		return 0.70
	if enemy.is_in_group("tanks"):
		return 0.65
	if enemy.is_in_group("turrets"):
		return 0.60
	if enemy.is_in_group("scouts"):
		return 0.40
	if "threat_score" in enemy:
		return float(enemy.threat_score)
	return 0.25

func _get_mission_priority_bonus(enemy: Node3D) -> float:
	var bonus: float = 0.0
	if not is_instance_valid(enemy):
		return 0.0

	# Active objective targets (radar, command posts)
	if enemy.is_in_group("objectives"):
		bonus += 0.50

	# Active SAM site currently tracking/locking
	if enemy is SAMSite:
		var sam := enemy as SAMSite
		if sam.current_state == SAMSite.State.LOCKING or sam.current_state == SAMSite.State.TRACKING:
			bonus += 0.60
		else:
			bonus += 0.30

	# Enemies threatening friendly or LZ
	if enemy.is_in_group("lz_threats"):
		bonus += 0.55

	# Convoy command unit
	if enemy.is_in_group("command_units"):
		bonus += 0.45

	return bonus

func _set_current_target(new_target: Node3D) -> void:
	if new_target != current_target:
		current_target = new_target
		_current_target_has_los = current_target != null
		target_changed.emit(current_target)
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb:
			if current_target and eb.has_signal("target_acquired"):
				eb.emit_signal("target_acquired", current_target)
			elif not current_target and eb.has_signal("target_lost"):
				eb.emit_signal("target_lost")

func _clear_target() -> void:
	if current_target != null:
		current_target = null
		_current_target_has_los = false
		target_changed.emit(null)
		var eb: Node = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("target_lost"):
			eb.emit_signal("target_lost")

func has_line_of_sight(target_node: Node3D) -> bool:
	if not is_instance_valid(target_node) or target_node.is_queued_for_deletion():
		return false
	var gun_origin: Vector3 = to_global(Vector3(0.0, -0.4, -1.2))
	var target_pos: Vector3 = _get_target_center(target_node)
	var space := get_world_3d().direct_space_state
	var player_node := get_parent() as CollisionObject3D
	var player_rid: RID = player_node.get_rid() if player_node else RID()

	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(gun_origin, target_pos, 1)
	var excludes: Array[RID] = []
	if player_rid.is_valid():
		excludes.append(player_rid)
	if target_node is CollisionObject3D:
		var erid: RID = (target_node as CollisionObject3D).get_rid()
		if erid.is_valid():
			excludes.append(erid)
	ray_query.exclude = excludes

	var hit: Dictionary = space.intersect_ray(ray_query)
	return hit.is_empty() or hit.get("collider") == target_node

func get_candidate_count() -> int:
	return _cached_candidate_count

func has_los_to_current() -> bool:
	return _current_target_has_los
