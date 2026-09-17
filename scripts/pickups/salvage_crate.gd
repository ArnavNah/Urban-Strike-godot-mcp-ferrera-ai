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
		if p.is_in_group("city_chunks"):
			var root_scene := get_tree().current_scene if get_tree().current_scene else get_tree().root
			reparent.call_deferred(root_scene, true)
			break
		p = p.get_parent()

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

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 1.2, 0), salvage_value, true)

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
	_target_player = player
	current_state = State.MAGNETIZED
	if _current_speed < initial_magnet_speed:
		_current_speed = initial_magnet_speed

## Backward-compatible alias for unit tests and existing calls
func set_magnet_target(player: Node3D) -> void:
	magnetize_to(player)

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
				collect(active_player)
		return

	# Magnetized state: lock onto player and fly directly in with accelerated catch-up
	var target_pos := _target_player.global_position + Vector3(0, 0.5, 0)
	var to_player := target_pos - global_position
	var dist := to_player.length()
	var flat_dist := Vector2(to_player.x, to_player.z).length()

	# Altitude-forgiving cylindrical collection check
	if dist <= collection_radius or (flat_dist <= collection_radius_xz and absf(to_player.y) <= collection_height):
		collect(_target_player)
		return

	var player_vel: Vector3 = _target_player.velocity if ("velocity" in _target_player) else Vector3.ZERO
	var effective_max_speed := maxf(max_magnet_speed, player_vel.length() + 45.0)
	_current_speed = move_toward(_current_speed, effective_max_speed, magnet_accel * delta)
	var dir := to_player.normalized() if dist > 0.001 else Vector3.UP
	var step_vec := (dir * _current_speed + player_vel * 0.85) * delta

	# Check if step crosses target
	if step_vec.length() >= dist:
		collect(_target_player)
		return

	global_position += step_vec

	var post_to_player := target_pos - global_position
	var post_flat_dist := Vector2(post_to_player.x, post_to_player.z).length()
	if post_to_player.length() <= collection_radius or (post_flat_dist <= collection_radius_xz and absf(post_to_player.y) <= collection_height):
		collect(_target_player)
