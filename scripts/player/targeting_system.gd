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

const ACQUISITION_INTERVAL: float = 0.12 # ~8.33 Hz full searches per second (in 5-10 Hz budget)
const MAX_RAYCAST_CANDIDATES: int = 6   # Raycast limited to top scoring candidates only
const LOS_LOST_GRACE_TIME: float = 0.35 # Retain lock briefly across small poles/props

var current_target: Node3D = null
var is_manual_aim: bool = false
var manual_aim_point: Vector3 = Vector3.ZERO

var _manual_settle_timer: float = 0.0
var _stickiness_timer: float = 0.0
var _acquisition_timer: float = 0.0
var _los_break_timer: float = 0.0
var _cached_candidate_count: int = 0
var _current_target_has_los: bool = false
var _last_raycast_count: int = 0
var _total_acquisitions_count: int = 0
var _total_raycasts_count: int = 0
var _jammed_check_timer: float = 0.0
var _is_jammed_cached: bool = false

signal target_changed(new_target: Node3D)
signal manual_aim_toggled(is_manual: bool)

func _physics_process(delta: float) -> void:
	if not is_inside_tree() or not get_world_3d():
		return

	_jammed_check_timer -= delta
	if _jammed_check_timer <= 0.0:
		_jammed_check_timer = 0.2
		_is_jammed_cached = _evaluate_is_jammed()

	if _manual_settle_timer > 0.0:
		_manual_settle_timer -= delta
		if _manual_settle_timer <= 0.0:
			_set_manual_aim(false)

	if _stickiness_timer > 0.0:
		_stickiness_timer -= delta

	# Immediate target validation: if current target dies or leaves world bounds, drop immediately
	if current_target != null:
		if not _is_target_valid_basic(current_target):
			_clear_target()
			_acquisition_timer = 0.0 # Trigger immediate re-acquisition

	# Throttled full target acquisition (5-10 Hz)
	if _acquisition_timer > 0.0:
		_acquisition_timer -= delta

	if _acquisition_timer <= 0.0:
		_acquisition_timer = ACQUISITION_INTERVAL
		_update_auto_target()

func _is_target_valid_basic(target: Node3D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if "is_alive" in target and not target.is_alive:
		return false

	var gun_origin: Vector3 = to_global(Vector3(0.0, -0.4, -1.2))
	var target_pos: Vector3 = _get_target_center(target)
	var dist: float = gun_origin.distance_to(target_pos)
	if dist > (acquisition_range + hysteresis_dist_threshold) or dist < 0.5:
		return false

	var local_to_target: Vector3 = to_local(target_pos)
	var yaw: float = atan2(-local_to_target.x, -local_to_target.z)
	var flat_dist: float = Vector2(local_to_target.x, local_to_target.z).length()
	var pitch: float = atan2(local_to_target.y, flat_dist)

	if max_yaw_arc_deg < 179.9 and absf(yaw) > deg_to_rad(max_yaw_arc_deg) + 0.08:
		return false
	if pitch < deg_to_rad(min_pitch_deg) - 0.08 or pitch > deg_to_rad(max_pitch_deg) + 0.08:
		return false

	return true

func trigger_manual_aim(world_point: Vector3) -> void:
	manual_aim_point = world_point
	_manual_settle_timer = manual_override_settle_time
	_acquisition_timer = 0.0
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
	return _evaluate_is_jammed()

func _evaluate_is_jammed() -> bool:
	if not is_inside_tree():
		return false
	var jammers: Array = get_tree().get_nodes_in_group("jammers")
	for jammer in jammers:
		var j := jammer as Node3D
		if not is_instance_valid(j) or j.is_queued_for_deletion():
			continue
		if "is_alive" in j and not j.is_alive:
			continue

		# The active convoy mission disrupts targeting until its objective unit is
		# destroyed. Ambient jammer enemies only affect the player within range.
		if j.is_in_group("mission_jammers"):
			return true
		var effect_range: float = 90.0
		if "jammer_effect_range" in j:
			effect_range = maxf(1.0, float(j.jammer_effect_range))
		if global_position.distance_to(j.global_position) <= effect_range:
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
	if not is_inside_tree() or not get_world_3d():
		return

	_total_acquisitions_count += 1
	var space := get_world_3d().direct_space_state
	var player_node := get_parent() as CollisionObject3D
	var player_rid: RID = player_node.get_rid() if player_node else RID()

	var gun_origin: Vector3 = to_global(Vector3(0.0, -0.4, -1.2))

	# 1. Gather all living enemies in range (EnemyRegistry spatial hash query + fallback)
	var search_range: float = acquisition_range + (hysteresis_dist_threshold if is_instance_valid(current_target) else 0.0)
	var candidate_enemies: Array[Node3D] = []
	if EnemyRegistry.instance and is_instance_valid(EnemyRegistry.instance) and not EnemyRegistry.instance.is_queued_for_deletion():
		candidate_enemies = EnemyRegistry.instance.get_enemies_in_radius(gun_origin, search_range)
	else:
		var raw_nodes := get_tree().get_nodes_in_group("enemies")
		for n in raw_nodes:
			var e := n as Node3D
			if is_instance_valid(e):
				candidate_enemies.append(e)

	# 2. Fast candidate pre-filtering (Zero raycasts performed here)
	var prefiltered: Array[Dictionary] = []
	var total_alive_in_arc: int = 0

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

		var is_cur: bool = (enemy == current_target)
		var allowed_dist: float = acquisition_range + (hysteresis_dist_threshold if is_cur else 0.0)
		if dist > allowed_dist or dist < 0.5:
			continue

		# Gun allowed aiming arc check
		var local_to_target: Vector3 = to_local(target_pos)
		var yaw: float = atan2(-local_to_target.x, -local_to_target.z)
		var flat_dist: float = Vector2(local_to_target.x, local_to_target.z).length()
		var pitch: float = atan2(local_to_target.y, flat_dist)

		if max_yaw_arc_deg < 179.9 and absf(yaw) > deg_to_rad(max_yaw_arc_deg) + 0.005:
			continue
		if pitch < deg_to_rad(min_pitch_deg) - 0.005 or pitch > deg_to_rad(max_pitch_deg) + 0.005:
			continue

		total_alive_in_arc += 1
		prefiltered.append({
			"node": enemy,
			"dist": dist,
			"yaw": yaw,
			"pos": target_pos,
			"is_cur": is_cur
		})

	_cached_candidate_count = total_alive_in_arc

	if prefiltered.is_empty():
		_last_raycast_count = 0
		_current_target_has_los = false
		_los_break_timer = 0.0
		_clear_target()
		return

	# 3. Pre-score all geometrically valid candidates BEFORE raycasting
	for c in prefiltered:
		var node: Node3D = c["node"] as Node3D
		c["score"] = _calculate_candidate_score(node, c["dist"], c["yaw"], total_alive_in_arc)

	# 4. Sort candidates descending by preliminary score
	prefiltered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)

	# 5. Limit candidates for raycasting to top MAX_RAYCAST_CANDIDATES
	var raycast_candidates: Array[Dictionary] = []
	var cur_included: bool = false

	var limit: int = mini(prefiltered.size(), MAX_RAYCAST_CANDIDATES)
	for i in range(limit):
		var cand: Dictionary = prefiltered[i]
		raycast_candidates.append(cand)
		if cand["is_cur"]:
			cur_included = true

	# Ensure current target is tested if present in prefiltered
	if not cur_included and is_instance_valid(current_target):
		for cand in prefiltered:
			if cand["is_cur"]:
				raycast_candidates.append(cand)
				break

	# 6. Perform LoS raycasts ONLY on the limited candidate subset
	_last_raycast_count = raycast_candidates.size()
	_total_raycasts_count += _last_raycast_count

	var valid_candidates: Array[Dictionary] = []
	var cur_target_los_clean: bool = false
	var cur_target_score: float = -INF

	for c in raycast_candidates:
		var enemy: Node3D = c["node"] as Node3D
		var target_pos: Vector3 = c["pos"]
		var score: float = c["score"]

		var ray_query := PhysicsRayQueryParameters3D.create(gun_origin, target_pos, 1)
		var excludes: Array[RID] = []
		if player_rid.is_valid():
			excludes.append(player_rid)
		if enemy is CollisionObject3D:
			var erid: RID = (enemy as CollisionObject3D).get_rid()
			if erid.is_valid():
				excludes.append(erid)
		ray_query.exclude = excludes

		var hit: Dictionary = space.intersect_ray(ray_query)
		var clear_los: bool = hit.is_empty() or hit.get("collider") == enemy

		if clear_los:
			valid_candidates.append(c)
			if c["is_cur"]:
				cur_target_los_clean = true
				cur_target_score = score
		elif c["is_cur"]:
			# LoS blocked for current target: check grace period
			if _los_break_timer < LOS_LOST_GRACE_TIME:
				cur_target_score = score * 0.85
				c["score"] = cur_target_score
				valid_candidates.append(c)

	# Update LoS grace state for current target
	if cur_target_los_clean:
		_los_break_timer = 0.0
		_current_target_has_los = true
	elif is_instance_valid(current_target):
		_los_break_timer += ACQUISITION_INTERVAL
		if _los_break_timer < LOS_LOST_GRACE_TIME:
			_current_target_has_los = true
		else:
			_current_target_has_los = false
			cur_target_score = -INF
	else:
		_current_target_has_los = false
		_los_break_timer = 0.0

	# 7. Select best candidate
	var best_candidate: Node3D = null
	var best_score: float = -INF

	for c in valid_candidates:
		var score: float = c["score"]
		if score > best_score:
			best_score = score
			best_candidate = c["node"] as Node3D

	# 8. Target selection with persistence, stickiness, and hysteresis
	if is_instance_valid(current_target) and cur_target_score > -INF:
		var req_multiplier: float = 1.0 + switch_score_threshold_ratio
		if _stickiness_timer > 0.0:
			req_multiplier += 0.15 # Stronger resistance while sticky

		if best_candidate != null and best_candidate != current_target:
			if best_score > cur_target_score * req_multiplier:
				_set_current_target(best_candidate)
				_stickiness_timer = target_stickiness_time
		return

	# No valid current target with LoS
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

func get_last_raycast_count() -> int:
	return _last_raycast_count

func get_total_acquisitions() -> int:
	return _total_acquisitions_count

func get_total_raycasts() -> int:
	return _total_raycasts_count
