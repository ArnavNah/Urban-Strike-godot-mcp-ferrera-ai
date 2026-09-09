class_name MissionDirector
extends Node

## Manages dynamic Strike-style combat objectives during continuous survival gameplay.
## Sequence: IDLE -> OFFERED -> ACTIVE -> RESOLVING -> COOLDOWN -> IDLE
## Enemies continuously spawn; missions influence focus/formations without clearing enemies or waves.

enum State {
	IDLE,
	OFFERED,
	ACTIVE,
	RESOLVING,
	COOLDOWN
}

@export var initial_delay: float = 20.0
@export var mission_cooldown: float = 45.0
@export var auto_start_missions: bool = true

var current_state: State = State.IDLE
var current_mission: StrikeMission = null
var _state_timer: float = 0.0
var _hud_update_timer: float = 0.0

var _mission_queue: Array[String] = [
	"destroy_radar",
	"destroy_jammer",
	"secure_lz"
]
var _mission_index: int = 0
var _player: Node3D = null

func _ready() -> void:
	add_to_group("mission_director")
	_state_timer = initial_delay
	current_state = State.IDLE
	_resolve_player()

func _resolve_player() -> void:
	if not is_instance_valid(_player) and is_inside_tree():
		_player = get_tree().get_first_node_in_group("player") as Node3D

func _get_event_bus() -> Node:
	if is_instance_valid(EventBus):
		return EventBus
	if is_inside_tree() and get_tree():
		return get_tree().root.get_node_or_null("EventBus")
	return null

func _process(delta: float) -> void:
	if get_tree().paused:
		return

	if not is_instance_valid(_player):
		_resolve_player()

	match current_state:
		State.IDLE:
			_state_timer -= delta
			if _state_timer <= 0.0 and auto_start_missions:
				offer_next_mission()

		State.OFFERED:
			_state_timer -= delta
			if _state_timer <= 0.0:
				current_state = State.ACTIVE

		State.ACTIVE:
			if not current_mission:
				current_state = State.IDLE
				_state_timer = mission_cooldown
				return

			_hud_update_timer -= delta
			if _hud_update_timer <= 0.0:
				_hud_update_timer = 0.2
				var update_info := current_mission.update(0.2, _player)
				var eb: Node = _get_event_bus()
				if eb and eb.has_signal("mission_updated"):
					eb.emit_signal(
						"mission_updated",
						current_mission.id,
						str(update_info.get("title", current_mission.title)),
						str(update_info.get("detail", "")),
						float(update_info.get("progress", 0.0))
					)

			if current_mission.check_completion():
				resolve_mission(true)
			elif current_mission.check_failure():
				resolve_mission(false)

		State.RESOLVING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				current_state = State.COOLDOWN
				_state_timer = mission_cooldown

		State.COOLDOWN:
			_state_timer -= delta
			if _state_timer <= 0.0:
				current_state = State.IDLE
				_state_timer = 5.0

func offer_next_mission() -> void:
	if _mission_queue.is_empty():
		return
	var next_id := _mission_queue[_mission_index % _mission_queue.size()]
	_mission_index += 1

	var eb: Node = _get_event_bus()
	if eb and eb.has_signal("mission_offered"):
		eb.emit_signal("mission_offered", next_id, next_id.replace("_", " ").to_upper())

	start_mission_by_id(next_id)

func start_mission_by_id(mission_id: String) -> StrikeMission:
	if current_mission and current_mission.is_active:
		current_mission.cleanup()

	var mission: StrikeMission = null
	match mission_id:
		"destroy_radar":
			mission = DestroyRadarMission.new()
		"destroy_jammer":
			mission = JammerConvoyMission.new()
		"secure_lz":
			mission = SecureLZMission.new()
		_:
			mission = DestroyRadarMission.new()

	current_mission = mission
	current_mission.start(self)
	current_state = State.ACTIVE
	_hud_update_timer = 0.0

	var eb: Node = _get_event_bus()
	if eb and eb.has_signal("mission_started"):
		eb.emit_signal(
			"mission_started",
			current_mission.id,
			current_mission.title,
			current_mission.description,
			current_mission.target_position
		)

	return current_mission

func resolve_mission(success: bool) -> void:
	if not current_mission:
		current_state = State.COOLDOWN
		_state_timer = mission_cooldown
		return

	current_state = State.RESOLVING
	_state_timer = 2.5

	var eb: Node = _get_event_bus()
	if success:
		current_mission.on_success(self)
		if eb and eb.has_signal("mission_completed"):
			var reward_text := "+%d XP  [+1 REQ]" % current_mission.xp_reward
			eb.emit_signal("mission_completed", current_mission.id, current_mission.title, reward_text)
	else:
		current_mission.on_failure(self)
		if eb and eb.has_signal("mission_failed"):
			eb.emit_signal("mission_failed", current_mission.id, current_mission.title, "MISSION FAILED")

	current_mission.cleanup()
	current_mission = null

func abort_current_mission() -> void:
	if current_mission:
		current_mission.cleanup()
		current_mission = null
	current_state = State.IDLE
	_state_timer = mission_cooldown
	var eb: Node = _get_event_bus()
	if eb and eb.has_signal("mission_failed"):
		eb.emit_signal("mission_failed", "", "", "")
