class_name FlareDispenser
extends Node3D

@export var max_charges: int = 3
@export var recharge_time: float = 9.0
@export var flare_scene: PackedScene

var current_charges: int = 3
var _recharge_timer: float = 0.0

func _ready() -> void:
	if not flare_scene:
		flare_scene = preload("res://scenes/weapons/flare.tscn")
	current_charges = max_charges
	_notify_flares()

func _process(delta: float) -> void:
	if current_charges < max_charges:
		_recharge_timer += delta
		if _recharge_timer >= recharge_time:
			_recharge_timer = 0.0
			current_charges += 1
			_notify_flares()

func try_dispense() -> bool:
	if current_charges <= 0:
		return false

	current_charges -= 1
	_notify_flares()

	# Dispense two flares drifting rear-left and rear-right
	var fwd := global_transform.basis.z
	var right := global_transform.basis.x
	_spawn_single_flare(global_position + (-right * 0.8), (fwd * 10.0 - right * 12.0 + Vector3.UP * 2.0))
	_spawn_single_flare(global_position + (right * 0.8), (fwd * 10.0 + right * 12.0 + Vector3.UP * 2.0))

	return true

func _spawn_single_flare(pos: Vector3, vel: Vector3) -> void:
	if FlarePool.instance:
		FlarePool.instance.spawn_flare(pos, vel)
		return
	var fl: Node3D = flare_scene.instantiate() as Node3D
	if fl:
		fl.transform.origin = pos
		var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
		parent.add_child.call_deferred(fl)
		fl.call_deferred("launch", pos, vel)

func _notify_flares() -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("flares_updated"):
		eb.emit_signal("flares_updated", current_charges, max_charges, current_charges > 0)
