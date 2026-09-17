class_name MissileAmmoPickup
extends Area3D

## Tactical battlefield missile ammunition supply crate.
## Replenishes secondary missile ammo when low; remains in the world if player ammo is full.

enum State {
	IDLE,
	MAGNETIZED
}

@export var refill_amount: int = 2
@export var bob_speed: float = 3.2
@export var bob_amplitude: float = 0.22
@export var rotation_speed: float = 1.8
@export var collection_radius: float = 4.0
@export var collection_radius_xz: float = 4.5
@export var collection_height: float = 35.0
@export var initial_magnet_speed: float = 35.0
@export var max_magnet_speed: float = 95.0
@export var magnet_accel: float = 240.0

var current_state: State = State.IDLE
var _target_player: Node3D = null
var _current_speed: float = 0.0
var _is_collected: bool = false
var _base_y: float = 0.0
var _bob_timer: float = 0.0

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var beacon: OmniLight3D = get_node_or_null("VisualRoot/BeaconLight")

func _init() -> void:
	add_to_group("missile_pickups")
	add_to_group("pickups")

func _ready() -> void:
	add_to_group("missile_pickups")
	add_to_group("pickups")

	# Pickups on collision layer 5 (value 16), monitor player CharacterBody3D on layer 2
	collision_layer = 16
	collision_mask = 2
	monitoring = true
	monitorable = true

	if visual_root:
		_base_y = visual_root.position.y
	_bob_timer = randf() * TAU

	_ensure_persistent_parent()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

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
	var pod: Node = player.get("missile_pod")
	if not pod or not is_instance_valid(pod):
		return false
	var cur_missiles: int = int(pod.get("current_missiles"))
	var max_missiles: int = int(pod.get("max_missiles"))
	if cur_missiles >= max_missiles:
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

	var pod: Node = target.get("missile_pod")
	if not pod:
		return false

	var gained: int = 0
	if pod.has_method("replenish_ammo"):
		gained = pod.call("replenish_ammo", refill_amount)
	elif "current_missiles" in pod and "max_missiles" in pod:
		var cur: int = int(pod.get("current_missiles"))
		var max_m: int = int(pod.get("max_missiles"))
		gained = mini(refill_amount, max_m - cur)
		pod.set("current_missiles", cur + gained)

	if gained <= 0:
		return false

	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_play_pickup_feedback()
	queue_free()
	return true

## Backward-compatible test and caller hook
func _try_collect(player: PlayerHelicopter) -> bool:
	return collect(player)

## Backward-compatible collection hook
func _collect() -> void:
	collect(_target_player)

## Primary survivor magnet activation
func magnetize_to(player: Node3D) -> void:
	if not is_instance_valid(player) or _is_collected:
		return
	if not can_collect(player):
		return # Do not magnetize towards player if ammo is already full
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

	_bob_timer += delta * bob_speed

	if visual_root:
		visual_root.rotate_y(rotation_speed * delta)
		visual_root.position.y = _base_y + sin(_bob_timer) * bob_amplitude

	if beacon:
		beacon.light_energy = 1.8 + sin(_bob_timer * 2.0) * 0.6

	# Idle state: hover check for flying player overhead
	if current_state == State.IDLE or not is_instance_valid(_target_player) or _target_player.is_queued_for_deletion():
		if current_state == State.MAGNETIZED:
			current_state = State.IDLE
			_target_player = null
			_current_speed = 0.0

		var active_player: Node3D = _target_player
		if not is_instance_valid(active_player) and is_inside_tree():
			active_player = get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(active_player) and not active_player.is_queued_for_deletion():
			var to_p := active_player.global_position - global_position
			var flat_d := Vector2(to_p.x, to_p.z).length()
			# Hovering directly overhead within horizontal reach and flight altitude
			if flat_d <= collection_radius_xz and to_p.y >= -2.0 and to_p.y <= collection_height:
				if can_collect(active_player):
					collect(active_player)
		return

	# Magnetized state: homing toward player cabin with accelerated catch-up
	if not can_collect(_target_player):
		current_state = State.IDLE
		_target_player = null
		_current_speed = 0.0
		return

	var target_pos := _target_player.global_position + Vector3(0, 0.5, 0)
	var to_player := target_pos - global_position
	var dist := to_player.length()
	var flat_dist := Vector2(to_player.x, to_player.z).length()

	if dist <= collection_radius or (flat_dist <= collection_radius_xz and absf(to_player.y) <= collection_height):
		collect(_target_player)
		return

	var player_vel: Vector3 = _target_player.velocity if ("velocity" in _target_player) else Vector3.ZERO
	var effective_max_speed := maxf(max_magnet_speed, player_vel.length() + 45.0)
	_current_speed = move_toward(_current_speed, effective_max_speed, magnet_accel * delta)
	var dir := to_player.normalized() if dist > 0.001 else Vector3.UP
	var step_vec := (dir * _current_speed + player_vel * 0.85) * delta

	if step_vec.length() >= dist:
		collect(_target_player)
		return

	global_position += step_vec

	var post_to_player := target_pos - global_position
	var post_flat_dist := Vector2(post_to_player.x, post_to_player.z).length()
	if post_to_player.length() <= collection_radius or (post_flat_dist <= collection_radius_xz and absf(post_to_player.y) <= collection_height):
		collect(_target_player)

## Collection handler called when player body enters
func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
	if body is PlayerHelicopter:
		collect(body)

## Collection handler called when player collect area enters
func _on_area_entered(area: Area3D) -> void:
	if _is_collected:
		return
	var player := area.get_parent() as PlayerHelicopter
	if not player and area.owner is PlayerHelicopter:
		player = area.owner as PlayerHelicopter
	if player:
		collect(player)

func _play_pickup_feedback() -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("missile_pickup_collected"):
			eb.emit_signal("missile_pickup_collected", refill_amount)
		if eb.has_signal("damage_number_spawned"):
			eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 1.4, 0), float(refill_amount), true)

	var spark_scene: PackedScene = preload("res://scenes/vfx/impact_sparks.tscn")
	if spark_scene and is_inside_tree():
		var spark := spark_scene.instantiate() as Node3D
		if spark:
			spark.transform.origin = global_position
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(spark)
