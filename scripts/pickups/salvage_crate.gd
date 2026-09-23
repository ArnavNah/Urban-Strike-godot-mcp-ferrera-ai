class_name SalvageCrate
extends Area3D

## High-value battlefield salvage crate (Intel / Hangar Currency).
## Uses Area3D pickup detection and rapid direct magnet vacuum.

enum State {
	IDLE,
	MAGNETIZED
}

@export var salvage_value: int = 50
@export var initial_magnet_speed: float = 35.0
@export var max_magnet_speed: float = 95.0
@export var magnet_accel: float = 240.0
@export var collection_radius: float = 2.8
@export var collection_radius_xz: float = 3.5
@export var collection_height: float = 35.0

var current_state: State = State.IDLE
var _target_player: Node3D = null
var _current_speed: float = 0.0
var _is_collected: bool = false
var _base_y: float = 0.5
var _bob_timer: float = 0.0

@onready var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var beacon: OmniLight3D = get_node_or_null("BeaconLight")

func _init() -> void:
	add_to_group("salvage_crates")
	add_to_group("pickups")

func _ready() -> void:
	add_to_group("salvage_crates")
	add_to_group("pickups")
	# Collision Layer 5 (value 16) for pickups
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	_base_y = global_position.y
	_bob_timer = randf() * TAU
	_ensure_persistent_parent()

func _ensure_persistent_parent() -> void:
	var p := get_parent()
	while p:
		if p.is_in_group("city_chunks") or p.name == "Encounters" or p.name == "encounters_root":
			var root_scene := get_tree().current_scene if get_tree().current_scene else get_tree().root
			reparent.call_deferred(root_scene, true)
			break
		p = p.get_parent()

func _is_line_of_sight_clear(target_pos: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var space := get_world_3d().direct_space_state
	if not space:
		return true
	var from_pos := global_position + Vector3(0.0, 0.5, 0.0)
	var ray_query := PhysicsRayQueryParameters3D.create(from_pos, target_pos, 1) # Layer 1 = World/Buildings
	ray_query.exclude = [get_rid()]
	var hit := space.intersect_ray(ray_query)
	return hit.is_empty()

## Explicit shared collection contract: checks whether player is eligible to collect
func can_collect(player: Node3D) -> bool:
	if _is_collected:
		return false
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return false
	if "is_alive" in player and not player.is_alive:
		return false
	return true

## Atomic collection execution
func collect(player: Node3D = null) -> bool:
	if _is_collected:
		return false
	var target: Node3D = player if is_instance_valid(player) else _target_player
	if not is_instance_valid(target) and is_inside_tree():
		target = get_tree().get_first_node_in_group("player") as Node3D
	if not can_collect(target):
		return false

	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage"):
		gm.call("add_salvage", salvage_value)

	var spark_scene: PackedScene = preload("res://scenes/vfx/impact_sparks.tscn")
	if spark_scene and is_inside_tree():
		var spark := spark_scene.instantiate() as Node3D
		if spark:
			spark.transform.origin = global_position
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(spark)

	queue_free()
	return true

## Backward-compatible collection hook
func _collect() -> void:
	collect(_target_player)

## Backward-compatible test and caller hook
func _try_collect(player: PlayerHelicopter) -> bool:
	return collect(player)

## Primary survivor magnet activation
func magnetize_to(player: Node3D) -> void:
	if not is_instance_valid(player) or _is_collected:
		return
	if not _is_line_of_sight_clear(player.global_position):
		return
	_target_player = player
	current_state = State.MAGNETIZED
	if _current_speed < initial_magnet_speed:
		_current_speed = initial_magnet_speed

## Backward-compatible alias for unit tests and existing calls
func set_magnet_target(player: Node3D) -> void:
	magnetize_to(player)

func _get_target_pos() -> Vector3:
	if not is_instance_valid(_target_player):
		return global_position
	if _target_player.has_node("StableTrackingPoint"):
		var marker: Node3D = _target_player.get_node("StableTrackingPoint") as Node3D
		if marker:
			return marker.global_position
	return _target_player.global_position + Vector3(0.0, 0.4, 0.0)

func _physics_process(delta: float) -> void:
	if _is_collected:
		return

	# Idle visual spin & gentle hover bob
	if current_state == State.IDLE or not is_instance_valid(_target_player) or _target_player.is_queued_for_deletion():
		if current_state == State.MAGNETIZED:
			current_state = State.IDLE
			_target_player = null
			_current_speed = 0.0
		rotate_y(2.5 * delta)
		_bob_timer += delta * 3.0
		position.y = _base_y + sin(_bob_timer) * 0.2

		# Hover proximity check: if helicopter is directly hovering overhead within horizontal reach and flight altitude
		var active_player: Node3D = _target_player
		if not is_instance_valid(active_player) and is_inside_tree():
			active_player = get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(active_player) and not active_player.is_queued_for_deletion():
			var to_p := active_player.global_position - global_position
			var flat_d := Vector2(to_p.x, to_p.z).length()
			if flat_d <= collection_radius_xz and to_p.y >= -2.0 and to_p.y <= collection_height:
				if _is_line_of_sight_clear(active_player.global_position):
					collect(active_player)
		return

	# Magnetized state: locks onto player stable tracking point with continuous sweep
	var target_pos := _get_target_pos()
	var to_target := target_pos - global_position
	var dist := to_target.length()
	var flat_dist := Vector2(to_target.x, to_target.z).length()

	# Altitude-forgiving cylindrical collection check
	if dist <= collection_radius or (flat_dist <= collection_radius_xz and absf(to_target.y) <= collection_height):
		collect(_target_player)
		return

	var player_vel: Vector3 = _target_player.velocity if ("velocity" in _target_player) else Vector3.ZERO
	var effective_max_speed := maxf(max_magnet_speed, player_vel.length() + 45.0)
	_current_speed = move_toward(_current_speed, effective_max_speed, magnet_accel * delta)
	var dir := to_target / dist if dist > 0.0001 else Vector3.UP

	# Relative continuous sweep: In the moving player's frame of reference,
	# the relative step is dir * (_current_speed * delta).
	var rel_p0 := -to_target
	var rel_step := dir * (_current_speed * delta)
	var rel_p1 := rel_p0 + rel_step

	var seg := rel_step
	var seg_len_sq := seg.length_squared()
	var closest_dist: float = minf(dist, rel_p1.length())
	if seg_len_sq > 0.00001:
		var t := clampf(-rel_p0.dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest_rel := rel_p0 + seg * t
		closest_dist = closest_rel.length()

	if closest_dist <= collection_radius or (Vector2(rel_p1.x, rel_p1.z).length() <= collection_radius_xz and absf(rel_p1.y) <= collection_height):
		collect(_target_player)
		return

	# Step world position with relative approach plus player movement feed-forward
	global_position += rel_step + player_vel * delta
