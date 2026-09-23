class_name BaseEncounter
extends Node3D

## Shared base class for procedural world encounters in Heli-Strike.
## Provides stable identification, chunk ownership, run-persistent completion,
## and altitude-tolerant player proximity checks.

signal encounter_started(encounter: BaseEncounter)
signal encounter_completed(encounter: BaseEncounter)
signal encounter_abandoned(encounter: BaseEncounter)

@export var encounter_id: String = ""
@export var chunk_coord: Vector2i = Vector2i.ZERO
@export var activation_radius: float = 24.0
@export var activation_height: float = 55.0

var is_active: bool = false
var is_completed: bool = false
var is_abandoned: bool = false

# Run-persistent completion and state dictionaries
static var completed_encounters: Dictionary = {}
static var active_encounter_states: Dictionary = {}

static func is_encounter_completed(id: String) -> bool:
	return completed_encounters.has(id) and bool(completed_encounters[id])

static func mark_encounter_completed(id: String) -> void:
	completed_encounters[id] = true
	if active_encounter_states.has(id):
		active_encounter_states.erase(id)

static func reset_run_encounters() -> void:
	completed_encounters.clear()
	active_encounter_states.clear()

func _ready() -> void:
	add_to_group("world_encounters")
	if encounter_id.is_empty():
		encounter_id = "%s_%d_%d_%d" % [get_class(), chunk_coord.x, chunk_coord.y, int(global_position.x + global_position.z)]

	if is_encounter_completed(encounter_id):
		is_completed = true
		_on_already_completed()

func _on_already_completed() -> void:
	queue_free()

func is_player_in_range(player: PlayerHelicopter) -> bool:
	if not is_instance_valid(player) or not player.is_alive:
		return false
	var flat_self := Vector2(global_position.x, global_position.z)
	var flat_player := Vector2(player.global_position.x, player.global_position.z)
	var horizontal_dist := flat_self.distance_to(flat_player)
	if horizontal_dist > activation_radius:
		return false

	var y_diff: float = player.global_position.y - global_position.y
	return y_diff >= -2.0 and y_diff <= activation_height

func get_active_player() -> PlayerHelicopter:
	if PlayerHelicopter.instance and is_instance_valid(PlayerHelicopter.instance) and PlayerHelicopter.instance.is_alive:
		return PlayerHelicopter.instance
	var tree := get_tree()
	if not tree:
		return null
	var nodes := tree.get_nodes_in_group("player")
	for node in nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node is PlayerHelicopter:
			if (node as PlayerHelicopter).is_alive:
				return node as PlayerHelicopter
	return null

func start_encounter() -> void:
	if is_completed or is_active:
		return
	is_active = true
	emit_signal("encounter_started", self)

func complete_encounter() -> void:
	if is_completed:
		return
	is_active = false
	is_completed = true
	mark_encounter_completed(encounter_id)
	emit_signal("encounter_completed", self)

func abandon_encounter() -> void:
	if not is_active:
		return
	is_active = false
	is_abandoned = true
	emit_signal("encounter_abandoned", self)
