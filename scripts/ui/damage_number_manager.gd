class_name DamageNumberManager
extends Control

## High-performance preallocated label pool for combat damage numbers.
## Replaces per-hit instantiation/destruction with zero-allocation pooling,
## camera frustum/screen culling, preset-aware active caps, and multi-cue category handling.

static var instance: DamageNumberManager = null

enum DamageCategory {
	NORMAL = 0,    # Cream/off-white, 16px, clean number e.g. "12"
	CRITICAL = 1,  # Radiant gold, 22px, strong pop, e.g. "★ 75"
	PLAYER = 2,    # Vivid red, 18px, downward cue, e.g. "▼ -16"
	BLOCKED = 3    # Cool steel cyan, 15px, e.g. "[SHIELD] 0" or "BLOCKED"
}

const PRESET_BUDGET_LOW: int = 24
const PRESET_BUDGET_MEDIUM: int = 40
const PRESET_BUDGET_HIGH: int = 56
const MAX_EFFECT_DISTANCE_SQ: float = 150.0 * 150.0
const SCREEN_CULL_MARGIN: float = 50.0

@export var pool_size: int = 64
@export var max_active_numbers: int = 40
@export var damage_number_scene: PackedScene = null

var _pool: Array[DamageNumber] = []
var _free_labels: Array[DamageNumber] = []
var _active_labels: Array[DamageNumber] = []
var _cached_camera: Camera3D = null
var _recent_event_keys: Dictionary = {}
var _last_dedup_frame: int = -1

func _get_event_bus() -> Node:
	if is_inside_tree():
		return get_tree().root.get_node_or_null("EventBus")
	return null

func _init() -> void:
	_init_pool()

func _enter_tree() -> void:
	instance = self
	var preset := str(SaveSystem.get_setting("graphics_preset", "medium")).to_lower()
	set_preset(preset)
	_init_pool()
	_connect_events()

func _exit_tree() -> void:
	_disconnect_events()

	for label in _pool:
		if is_instance_valid(label):
			label.deactivate()

	_active_labels.clear()
	_free_labels.clear()
	_recent_event_keys.clear()

	if instance == self:
		instance = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_pool()
	_connect_events()

func _connect_events() -> void:
	var eb := _get_event_bus()
	if not eb:
		return
	if eb.has_signal("damage_number_spawned") and not eb.damage_number_spawned.is_connected(_on_damage_spawned):
		eb.damage_number_spawned.connect(_on_damage_spawned)
	if eb.has_signal("player_damaged_directional") and not eb.player_damaged_directional.is_connected(_on_player_damaged_directional):
		eb.player_damaged_directional.connect(_on_player_damaged_directional)

func _disconnect_events() -> void:
	var eb := _get_event_bus()
	if not eb:
		return
	if eb.has_signal("damage_number_spawned") and eb.damage_number_spawned.is_connected(_on_damage_spawned):
		eb.damage_number_spawned.disconnect(_on_damage_spawned)
	if eb.has_signal("player_damaged_directional") and eb.player_damaged_directional.is_connected(_on_player_damaged_directional):
		eb.player_damaged_directional.disconnect(_on_player_damaged_directional)

func set_preset(preset_name: String) -> void:
	match preset_name.to_lower():
		"low":
			max_active_numbers = PRESET_BUDGET_LOW
		"high":
			max_active_numbers = PRESET_BUDGET_HIGH
		_:
			max_active_numbers = PRESET_BUDGET_MEDIUM

func _init_pool() -> void:
	if not _pool.is_empty():
		return

	if not damage_number_scene:
		damage_number_scene = load("res://scenes/ui/damage_number.tscn") as PackedScene

	for i in range(pool_size):
		var label: DamageNumber = null
		if damage_number_scene:
			label = damage_number_scene.instantiate() as DamageNumber
		if not label:
			label = DamageNumber.new()

		label.name = "DamageLabel_%d" % i
		label.is_active = false
		label.visible = false
		label.set_process(false)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.manager = self

		add_child(label)
		_pool.append(label)
		_free_labels.append(label)

func set_camera(cam: Camera3D) -> void:
	_cached_camera = cam

func get_active_camera() -> Camera3D:
	if is_instance_valid(_cached_camera) and (_cached_camera.current or not is_inside_tree()):
		return _cached_camera

	if is_inside_tree():
		var vp := get_viewport()
		if vp:
			_cached_camera = vp.get_camera_3d()

	return _cached_camera

func _on_damage_spawned(pos: Vector3, amount: float, is_critical: bool) -> void:
	var cat := DamageCategory.NORMAL
	if amount <= 0.0:
		cat = DamageCategory.BLOCKED
	elif is_critical:
		cat = DamageCategory.CRITICAL
	spawn_damage_number(pos, amount, is_critical, cat)

func _on_player_damaged_directional(amount: float, hit_pos: Vector3, source_pos: Vector3, is_shield_hit: bool) -> void:
	if is_shield_hit or amount <= 0.0:
		spawn_damage_number(hit_pos, 0.0, false, DamageCategory.BLOCKED, {"is_blocked": true, "source_pos": source_pos})
	else:
		spawn_damage_number(hit_pos, amount, false, DamageCategory.PLAYER, {"is_player": true, "source_pos": source_pos})

func spawn_damage_number(
	pos: Vector3,
	amount: float,
	is_critical: bool = false,
	category: int = DamageCategory.NORMAL,
	metadata: Dictionary = {}
) -> void:
	# Duplicate Prevention: drop identical category/amount/approx-pos events in the same frame
	var current_frame := Engine.get_process_frames()
	if current_frame != _last_dedup_frame:
		_last_dedup_frame = current_frame
		_recent_event_keys.clear()

	var dedup_key := "%d_%.1f_%.1f_%.1f_%.1f" % [category, amount, roundf(pos.x * 2.0) / 2.0, roundf(pos.y * 2.0) / 2.0, roundf(pos.z * 2.0) / 2.0]
	if _recent_event_keys.has(dedup_key):
		return
	_recent_event_keys[dedup_key] = true

	var cam := get_active_camera()
	if not cam or not cam.is_inside_tree():
		return

	# 1. Frustum & Viewport Rejection
	if cam.is_position_behind(pos):
		return

	if cam.global_position.distance_squared_to(pos) > MAX_EFFECT_DISTANCE_SQ:
		return

	var screen_pos := cam.unproject_position(pos)
	var vp := get_viewport()
	var vp_rect: Rect2
	if vp:
		vp_rect = vp.get_visible_rect()
	else:
		vp_rect = Rect2(Vector2.ZERO, Vector2(1280, 720))

	if not vp_rect.grow(SCREEN_CULL_MARGIN).has_point(screen_pos):
		return

	# 2. Immediate Active Budget Enforcement (including same-frame bursts)
	if _active_labels.size() >= max_active_numbers:
		return

	if _free_labels.is_empty():
		return

	# 3. Label Allocation & Setup
	var label: DamageNumber = _free_labels.pop_back()
	_active_labels.append(label)

	var jitter := Vector3(
		randf_range(-0.35, 0.35),
		randf_range(0.3, 0.7),
		randf_range(-0.35, 0.35)
	)
	label.setup(pos + jitter, amount, is_critical, self, category, metadata)

func _on_label_deactivated(label: DamageNumber) -> void:
	_active_labels.erase(label)
	if not _free_labels.has(label):
		_free_labels.append(label)

func get_active_count() -> int:
	return _active_labels.size()

func get_free_count() -> int:
	return _free_labels.size()

func get_pool_size() -> int:
	return _pool.size()
