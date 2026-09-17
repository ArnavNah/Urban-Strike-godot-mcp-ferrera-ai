class_name DamageNumberManager
extends Control

## High-performance preallocated label pool for combat damage numbers.
## Replaces per-hit instantiation/destruction with zero-allocation pooling,
## camera frustum/screen culling, and preset-aware active caps.

static var instance: DamageNumberManager = null

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

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if EventBus and EventBus.has_signal("damage_number_spawned"):
		if EventBus.damage_number_spawned.is_connected(_on_damage_spawned):
			EventBus.damage_number_spawned.disconnect(_on_damage_spawned)

	for label in _pool:
		if is_instance_valid(label):
			label.deactivate()

	_active_labels.clear()
	_free_labels.clear()

	if instance == self:
		instance = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not damage_number_scene:
		damage_number_scene = load("res://scenes/ui/damage_number.tscn") as PackedScene

	var preset := str(SaveSystem.get_setting("graphics_preset", "medium")).to_lower()
	set_preset(preset)

	_init_pool()

	if EventBus and not EventBus.damage_number_spawned.is_connected(_on_damage_spawned):
		EventBus.damage_number_spawned.connect(_on_damage_spawned)

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

func get_active_camera() -> Camera3D:
	if is_instance_valid(_cached_camera) and _cached_camera.is_inside_tree() and _cached_camera.current:
		return _cached_camera

	if is_inside_tree():
		_cached_camera = get_viewport().get_camera_3d()

	return _cached_camera

func _on_damage_spawned(pos: Vector3, amount: float, is_critical: bool) -> void:
	var cam := get_active_camera()
	if not cam:
		return

	# 1. Frustum & Viewport Rejection
	if cam.is_position_behind(pos):
		return

	if cam.global_position.distance_squared_to(pos) > MAX_EFFECT_DISTANCE_SQ:
		return

	var screen_pos := cam.unproject_position(pos)
	var vp := get_viewport()
	if not vp:
		return

	var vp_rect := vp.get_visible_rect()
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
	label.setup(pos + jitter, amount, is_critical, self)

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
