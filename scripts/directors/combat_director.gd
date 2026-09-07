class_name CombatDirector
extends Node

## GDD Section 12: Manages attack slots and battlefield pressure.
## Explicit slot lease with automatic timeout protection.

@export var max_ground_attack_slots: int = 2
@export var max_air_attack_slots: int = 1
@export var slot_lease_duration: float = 6.0

# Maps Node3D -> float (expiry timestamp in seconds)
var _ground_slot_holders: Dictionary = {}
var _air_slot_holders: Dictionary = {}

var _gameplay_time: float = 0.0

static var instance: CombatDirector

func _enter_tree() -> void:
	instance = self
	add_to_group("combat_director")

func _process(delta: float) -> void:
	if not get_tree().paused:
		_gameplay_time += delta
	_cleanup_slots()

func set_wave_limits(ground: int, air: int) -> void:
	max_ground_attack_slots = ground
	max_air_attack_slots = air
	_cleanup_slots()

func request_attack_slot(enemy: Node3D, is_air: bool = false) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false

	_cleanup_slots()
	var now := _gameplay_time

	if is_air:
		if _air_slot_holders.has(enemy):
			# Refresh lease
			_air_slot_holders[enemy] = now + slot_lease_duration
			return true
		if _air_slot_holders.size() < max_air_attack_slots:
			_air_slot_holders[enemy] = now + slot_lease_duration
			return true
		return false
	else:
		if _ground_slot_holders.has(enemy):
			# Refresh lease
			_ground_slot_holders[enemy] = now + slot_lease_duration
			return true
		if _ground_slot_holders.size() < max_ground_attack_slots:
			_ground_slot_holders[enemy] = now + slot_lease_duration
			return true
		return false

func release_attack_slot(enemy: Node3D, is_air: bool = false) -> void:
	if is_air:
		_air_slot_holders.erase(enemy)
	else:
		_ground_slot_holders.erase(enemy)

func has_attack_slot(enemy: Node3D, is_air: bool = false) -> bool:
	if is_air:
		return _air_slot_holders.has(enemy)
	return _ground_slot_holders.has(enemy)

func _cleanup_slots() -> void:
	var now := _gameplay_time

	# Clean ground slots
	var dead_ground: Array[Node3D] = []
	for e in _ground_slot_holders.keys():
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			dead_ground.append(e)
		elif now > _ground_slot_holders[e]:
			# Lease expired
			dead_ground.append(e)
	for d in dead_ground:
		_ground_slot_holders.erase(d)

	# Clean air slots
	var dead_air: Array[Node3D] = []
	for e in _air_slot_holders.keys():
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			dead_air.append(e)
		elif now > _air_slot_holders[e]:
			# Lease expired
			dead_air.append(e)
	for d in dead_air:
		_air_slot_holders.erase(d)

func get_debug_slot_info() -> Dictionary:
	_cleanup_slots()
	var ground_names: Array[String] = []
	for e in _ground_slot_holders.keys():
		if is_instance_valid(e):
			ground_names.append(e.name)

	var air_names: Array[String] = []
	for e in _air_slot_holders.keys():
		if is_instance_valid(e):
			air_names.append(e.name)

	return {
		"ground_used": _ground_slot_holders.size(),
		"ground_max": max_ground_attack_slots,
		"ground_holders": ground_names,
		"air_used": _air_slot_holders.size(),
		"air_max": max_air_attack_slots,
		"air_holders": air_names
	}
