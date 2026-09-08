class_name MissileAmmoPickup
extends Area3D

## Tactical battlefield missile ammunition supply crate.
## Replenishes secondary missile ammo when low; remains in the world if player ammo is full.

@export var refill_amount: int = 2
@export var bob_speed: float = 3.2
@export var bob_amplitude: float = 0.22
@export var rotation_speed: float = 1.8
@export var collection_radius: float = 4.0

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

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _is_collected:
		return

	_bob_timer += delta * bob_speed

	if visual_root:
		visual_root.rotate_y(rotation_speed * delta)
		visual_root.position.y = _base_y + sin(_bob_timer) * bob_amplitude

	if beacon:
		beacon.light_energy = 1.8 + sin(_bob_timer * 2.0) * 0.6

## Collection handler called when player body enters
func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
	if body is PlayerHelicopter:
		_try_collect(body as PlayerHelicopter)

## Collection handler called when player collect area enters
func _on_area_entered(area: Area3D) -> void:
	if _is_collected:
		return
	var player := area.get_parent() as PlayerHelicopter
	if not player and area.owner is PlayerHelicopter:
		player = area.owner as PlayerHelicopter
	if player:
		_try_collect(player)

## External collection hook
func _collect() -> void:
	if _is_collected:
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerHelicopter
	if player:
		_try_collect(player)

## Attempt collection. If player missile ammo is full, does NOT consume the pickup.
func _try_collect(player: PlayerHelicopter) -> bool:
	if _is_collected:
		return false
	if not is_instance_valid(player) or not player.is_alive:
		return false

	var pod := player.missile_pod as MissilePod
	if not pod:
		return false

	# Full capacity rule: Do NOT consume pickup if ammo is already full!
	if pod.current_missiles >= pod.max_missiles:
		return false

	var gained: int = pod.replenish_ammo(refill_amount)
	if gained <= 0:
		return false

	_is_collected = true
	_play_pickup_feedback()
	queue_free()
	return true

func _play_pickup_feedback() -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		if eb.has_signal("missile_pickup_collected"):
			eb.emit_signal("missile_pickup_collected", refill_amount)
		if eb.has_signal("damage_number_spawned"):
			eb.emit_signal("damage_number_spawned", global_position + Vector3(0, 1.4, 0), float(refill_amount), true)

	var spark_scene: PackedScene = preload("res://scenes/vfx/impact_sparks.tscn")
	if spark_scene:
		var spark := spark_scene.instantiate() as Node3D
		if spark:
			spark.transform.origin = global_position
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(spark)
