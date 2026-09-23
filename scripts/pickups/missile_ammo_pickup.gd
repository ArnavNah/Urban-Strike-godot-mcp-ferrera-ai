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

var _ammo_full_notify_cooldown: float = 0.0

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

	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("missile_ammo_changed"):
		eb.missile_ammo_changed.connect(_on_missile_ammo_changed)

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

func _on_missile_ammo_changed(_current: int, _maximum: int) -> void:
	if _is_collected or current_state != State.IDLE:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return
	var to_p := player.global_position - global_position
	var flat_d := Vector2(to_p.x, to_p.z).length()
	var rad: float = 18.0
	if "magnet_radius" in player:
		rad = float(player.get("magnet_radius"))
	if flat_d <= rad and absf(to_p.y) <= 40.0:
		if can_collect(player) and _is_line_of_sight_clear(player.global_position):
			magnetize_to(player)

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
		# Emit AMMO FULL notification if the reason was full ammo
		if is_instance_valid(target) and not target.is_queued_for_deletion():
			var check_pod: Node = target.get("missile_pod")
			if check_pod and is_instance_valid(check_pod):
				var cur_m: int = int(check_pod.get("current_missiles"))
				var max_m: int = int(check_pod.get("max_missiles"))
				if cur_m >= max_m and _ammo_full_notify_cooldown <= 0.0:
					var eb: Node = get_node_or_null("/root/EventBus")
					if eb and eb.has_signal("ammo_full_notified"):
						eb.emit_signal("ammo_full_notified")
						_ammo_full_notify_cooldown = 2.0
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
	_play_pickup_feedback(gained)
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

	if _ammo_full_notify_cooldown > 0.0:
		_ammo_full_notify_cooldown -= delta

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
				if _is_line_of_sight_clear(active_player.global_position):
					collect(active_player)
		return

	# Magnetized state: homing toward player cabin with accelerated catch-up
	if not can_collect(_target_player):
		current_state = State.IDLE
		_target_player = null
		_current_speed = 0.0
		return

	var target_pos := _get_target_pos()
	var to_target := target_pos - global_position
	var dist := to_target.length()
	var flat_dist := Vector2(to_target.x, to_target.z).length()

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

func _play_pickup_feedback(actual_gained: int) -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("missile_pickup_collected"):
			eb.emit_signal("missile_pickup_collected", actual_gained)

	var spark_scene: PackedScene = preload("res://scenes/vfx/impact_sparks.tscn")
	if spark_scene and is_inside_tree():
		var spark := spark_scene.instantiate() as Node3D
		if spark:
			spark.transform.origin = global_position
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(spark)
