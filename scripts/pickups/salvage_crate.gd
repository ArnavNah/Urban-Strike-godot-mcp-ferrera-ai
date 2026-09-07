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

## Primary survivor magnet activation
func magnetize_to(player: Node3D) -> void:
	if not is_instance_valid(player):
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
	if current_state == State.IDLE or not is_instance_valid(_target_player):
		rotate_y(2.5 * delta)
		_bob_timer += delta * 3.0
		position.y = _base_y + sin(_bob_timer) * 0.2
		return

	# Magnetized state: lock onto player and fly directly in
	var target_pos := _target_player.global_position + Vector3(0, 0.5, 0)
	var to_player := target_pos - global_position
	var dist := to_player.length()

	# Altitude-forgiving collection check
	var flat_dist := Vector2(to_player.x, to_player.z).length()
	if dist <= collection_radius or (flat_dist <= 3.5 and absf(to_player.y) <= 35.0):
		_collect()
		return

	_current_speed = move_toward(_current_speed, max_magnet_speed, magnet_accel * delta)
	var player_vel: Vector3 = _target_player.velocity if ("velocity" in _target_player) else Vector3.ZERO
	var dir := to_player.normalized() if dist > 0.001 else Vector3.UP
	var step_vec := (dir * _current_speed + player_vel * 0.8) * delta

	if step_vec.length() >= dist:
		_collect()
		return

	global_position += step_vec

	var post_to_player := target_pos - global_position
	var post_flat_dist := Vector2(post_to_player.x, post_to_player.z).length()
	if post_to_player.length() <= collection_radius or (post_flat_dist <= 3.5 and absf(post_to_player.y) <= 35.0):
		_collect()

func _collect() -> void:
	if _is_collected:
		return
	_is_collected = true

	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage"):
		gm.call("add_salvage", salvage_value)

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("damage_number_spawned"):
		eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 1.2, 0), salvage_value, true)

	var spark_scene: PackedScene = preload("res://scenes/vfx/impact_sparks.tscn")
	if spark_scene:
		var spark := spark_scene.instantiate() as Node3D
		if spark:
			spark.transform.origin = global_position
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(spark)

	queue_free()
