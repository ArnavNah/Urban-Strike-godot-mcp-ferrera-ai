class_name XPGem
extends Area3D

## Reusable survivor-style XP pickup node.
## Uses Area3D detection, rapid direct acceleration, and physical sweep collection.

enum State {
	IDLE,
	MAGNETIZED
}

@export var xp_value: int = 5
@export var initial_magnet_speed: float = 36.0
@export var max_magnet_speed: float = 95.0
@export var magnet_accel: float = 250.0
@export var collection_radius: float = 2.8

var current_state: State = State.IDLE
var _target_player: Node3D = null
var _current_speed: float = 0.0
var _is_collected: bool = false
var _bob_timer: float = 0.0
var _base_y: float = 0.4

@onready var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")

func _init() -> void:
	add_to_group("xp_gems")
	add_to_group("pickups")

func _ready() -> void:
	add_to_group("xp_gems")
	add_to_group("pickups")
	# Collision Layer 5 (value 16) for pickups
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	monitorable = true
	_base_y = global_position.y
	_bob_timer = randf() * TAU

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

	# Idle state or lost player target
	if current_state == State.IDLE or not is_instance_valid(_target_player) or _target_player.is_queued_for_deletion():
		if current_state == State.MAGNETIZED:
			current_state = State.IDLE
			_target_player = null
			_current_speed = 0.0
		rotate_y(3.0 * delta)
		_bob_timer += delta * 3.5
		position.y = _base_y + sin(_bob_timer) * 0.15
		return

	# Magnetized state: locks onto player stable tracking point with full relative velocity feed-forward
	var target_pos := _get_target_pos()
	var to_target := target_pos - global_position
	var dist := to_target.length()

	# Direct volume entry check
	if dist <= collection_radius:
		_collect()
		return

	# Rapid smooth acceleration toward max magnet speed
	_current_speed = move_toward(_current_speed, max_magnet_speed, magnet_accel * delta)
	var dir := to_target / dist if dist > 0.0001 else Vector3.UP
	var player_vel: Vector3 = _target_player.velocity if ("velocity" in _target_player) else Vector3.ZERO

	# In the moving player's frame of reference, gem approaches directly along dir at _current_speed
	var step_vec := (dir * _current_speed + player_vel) * delta
	var p0 := global_position
	var p1 := p0 + step_vec

	# Continuous line segment sweep against target collection volume to prevent tunneling or overshoot
	var seg := p1 - p0
	var seg_len_sq := seg.length_squared()
	var closest_dist: float = dist
	if seg_len_sq > 0.00001:
		var t := clampf((target_pos - p0).dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest_point := p0 + seg * t
		closest_dist = (closest_point - target_pos).length()

	if closest_dist <= collection_radius:
		_collect()
		return

	global_position = p1

func _collect() -> void:
	if _is_collected:
		return
	var mgr := get_tree().get_first_node_in_group("upgrade_manager")
	if not mgr or not mgr.has_method("add_xp"):
		return # Retain XP if progression manager is not yet active
	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	mgr.add_xp(xp_value)
	queue_free()
