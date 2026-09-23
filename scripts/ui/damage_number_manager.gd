class_name DamageNumberManager
extends Control

## High-performance preallocated label pool for combat damage numbers.
## Replaces per-hit instantiation/destruction with zero-allocation pooling,
## camera frustum/screen culling, preset-aware active caps, multi-cue category handling,
## a 100 ms per-target aggregation window, and settings-driven display filtering.

static var instance: DamageNumberManager = null

enum DamageCategory {
	NORMAL = 0,       ## Warm-white, 16px, clean number e.g. "12"
	CRITICAL = 1,     ## Amber, 22px, pop, e.g. "★ 75"
	PLAYER_HULL = 2,  ## Red/orange, 18px, downward cue, e.g. "▼ -16"
	PLAYER_SHIELD = 3,## Cyan, 17px, e.g. "◆ -12"
	HEAL = 4,         ## Green, 17px, e.g. "▲ +25"
	BLOCKED = 5       ## Legacy placeholder (suppressed)
}
const PLAYER: int = DamageCategory.PLAYER_HULL

const PRESET_BUDGET_LOW: int = 24
const PRESET_BUDGET_MEDIUM: int = 40
const PRESET_BUDGET_HIGH: int = 56
const MAX_EFFECT_DISTANCE_SQ: float = 150.0 * 150.0
const SCREEN_CULL_MARGIN: float = 50.0
const AGGREGATION_WINDOW: float = 0.10 # 100 ms fixed aggregation window from first hit

@export var pool_size: int = 64
@export var max_active_numbers: int = 40
@export var damage_number_scene: PackedScene = null

var _pool: Array[DamageNumber] = []
var _free_labels: Array[DamageNumber] = []
var _active_labels: Array[DamageNumber] = []
var _cached_camera: Camera3D = null
var _recent_event_keys: Dictionary = {}
var _last_dedup_frame: int = -1
var _pending_buckets: Dictionary = {} # key: "%d_%d" % [target_id, category] -> Dictionary

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
	_pending_buckets.clear()

	if instance == self:
		instance = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_pool()
	_connect_events()

func _process(delta: float) -> void:
	if _pending_buckets.is_empty():
		return

	var expired_keys: Array[String] = []
	for key in _pending_buckets:
		var bucket: Dictionary = _pending_buckets[key]
		bucket["time_remaining"] -= delta
		if bucket["time_remaining"] <= 0.0:
			expired_keys.append(key)

	for key in expired_keys:
		_flush_bucket(key)

func _connect_events() -> void:
	var eb := _get_event_bus()
	if not eb:
		return
	if eb.has_signal("damage_number_spawned") and not eb.damage_number_spawned.is_connected(_on_damage_spawned):
		eb.damage_number_spawned.connect(_on_damage_spawned)
	if eb.has_signal("player_damaged_directional") and not eb.player_damaged_directional.is_connected(_on_player_damaged_directional):
		eb.player_damaged_directional.connect(_on_player_damaged_directional)
	if eb.has_signal("enemy_destroyed") and not eb.enemy_destroyed.is_connected(_on_enemy_destroyed):
		eb.enemy_destroyed.connect(_on_enemy_destroyed)

func _disconnect_events() -> void:
	var eb := _get_event_bus()
	if not eb:
		return
	if eb.has_signal("damage_number_spawned") and eb.damage_number_spawned.is_connected(_on_damage_spawned):
		eb.damage_number_spawned.disconnect(_on_damage_spawned)
	if eb.has_signal("player_damaged_directional") and eb.player_damaged_directional.is_connected(_on_player_damaged_directional):
		eb.player_damaged_directional.disconnect(_on_player_damaged_directional)
	if eb.has_signal("enemy_destroyed") and eb.enemy_destroyed.is_connected(_on_enemy_destroyed):
		eb.enemy_destroyed.disconnect(_on_enemy_destroyed)

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

func _on_damage_spawned(pos: Vector3, amount: float, is_critical: bool = false, metadata: Dictionary = {}) -> void:
	# Suppress zero, blocked, or invulnerable damage numbers
	if amount <= 0.0 or metadata.get("is_blocked", false) or metadata.get("is_invulnerable", false):
		return

	var cat := DamageCategory.NORMAL
	if metadata.get("is_heal", false):
		cat = DamageCategory.HEAL
	elif metadata.get("is_shield", false):
		cat = DamageCategory.PLAYER_SHIELD
	elif metadata.get("is_player", false) or metadata.get("target_type", "") == "player":
		cat = DamageCategory.PLAYER_HULL
	elif is_critical or metadata.get("is_critical", false):
		cat = DamageCategory.CRITICAL
	else:
		cat = DamageCategory.NORMAL

	spawn_damage_number(pos, amount, is_critical, cat, metadata)

func _on_player_damaged_directional(amount: float, hit_pos: Vector3, source_pos: Vector3, is_shield_hit: bool, metadata: Dictionary = {}) -> void:
	# Suppress zero, blocked, or invulnerable hits
	if amount <= 0.0 or metadata.get("is_blocked", false) or metadata.get("is_invulnerable", false):
		return

	var player_tid: int = metadata.get("target_id", 0)
	var meta: Dictionary = metadata.duplicate()
	meta["source_pos"] = source_pos
	meta["is_player"] = true
	if player_tid != 0:
		meta["target_id"] = player_tid

	if is_shield_hit or metadata.get("is_shield", false):
		meta["is_shield"] = true
		spawn_damage_number(hit_pos, amount, false, DamageCategory.PLAYER_SHIELD, meta)
	else:
		meta["is_hull"] = true
		spawn_damage_number(hit_pos, amount, false, DamageCategory.PLAYER_HULL, meta)

func _on_enemy_destroyed(enemy: Node3D, _points: int = 0) -> void:
	if not is_instance_valid(enemy):
		return
	var tid := enemy.get_instance_id()
	flush_target_buckets(tid)

func spawn_damage_number(
	pos: Vector3,
	amount: float,
	is_critical: bool = false,
	category: int = DamageCategory.NORMAL,
	metadata: Dictionary = {}
) -> void:
	# Global settings filter
	var setting_mode := str(SaveSystem.get_setting("damage_numbers", "all")).to_lower()
	if setting_mode == "off":
		return

	if amount <= 0.0 or metadata.get("is_blocked", false) or metadata.get("is_invulnerable", false):
		return

	var target_id: int = metadata.get("target_id", 0)
	if target_id != 0:
		# Per-target 100 ms fixed aggregation window
		var bucket_key := "%d_%d" % [target_id, category]
		if _pending_buckets.has(bucket_key):
			var bucket: Dictionary = _pending_buckets[bucket_key]
			bucket["total_amount"] += amount
			bucket["hit_count"] += 1
			bucket["last_pos"] = pos
			if is_critical:
				bucket["is_critical"] = true
			for k in metadata:
				if not bucket["metadata"].has(k):
					bucket["metadata"][k] = metadata[k]
		else:
			_pending_buckets[bucket_key] = {
				"target_id": target_id,
				"category": category,
				"total_amount": amount,
				"hit_count": 1,
				"last_pos": pos,
				"time_remaining": AGGREGATION_WINDOW,
				"is_critical": is_critical,
				"metadata": metadata.duplicate()
			}
		return

	# Untargeted fallback: immediate display with same-frame duplicate prevention
	var current_frame := Engine.get_process_frames()
	if current_frame != _last_dedup_frame:
		_last_dedup_frame = current_frame
		_recent_event_keys.clear()

	var dedup_key := "%d_%.1f_%.1f_%.1f_%.1f" % [category, amount, roundf(pos.x * 2.0) / 2.0, roundf(pos.y * 2.0) / 2.0, roundf(pos.z * 2.0) / 2.0]
	if _recent_event_keys.has(dedup_key):
		return
	_recent_event_keys[dedup_key] = true

	_display_damage_number(pos, amount, is_critical, category, metadata)

func _flush_bucket(key: String) -> void:
	if not _pending_buckets.has(key):
		return
	var bucket: Dictionary = _pending_buckets[key]
	_pending_buckets.erase(key)

	var pos: Vector3 = bucket.get("last_pos", Vector3.ZERO)
	var amount: float = bucket.get("total_amount", 0.0)
	var is_critical: bool = bucket.get("is_critical", false)
	var category: int = bucket.get("category", DamageCategory.NORMAL)
	var metadata: Dictionary = bucket.get("metadata", {})

	_display_damage_number(pos, amount, is_critical, category, metadata)

func flush_target_buckets(target_id: int) -> void:
	if _pending_buckets.is_empty():
		return
	var to_flush: Array[String] = []
	for key in _pending_buckets:
		var bucket: Dictionary = _pending_buckets[key]
		if bucket.get("target_id", 0) == target_id:
			to_flush.append(key)
	for key in to_flush:
		_flush_bucket(key)

func flush_all_buckets() -> void:
	if _pending_buckets.is_empty():
		return
	var keys: Array = _pending_buckets.keys()
	for key in keys:
		_flush_bucket(str(key))

func get_pending_bucket_count() -> int:
	return _pending_buckets.size()

func get_bucket_total(target_id: int, category: int = DamageCategory.NORMAL) -> float:
	var key := "%d_%d" % [target_id, category]
	if _pending_buckets.has(key):
		return _pending_buckets[key].get("total_amount", 0.0)
	return 0.0

func _display_damage_number(
	pos: Vector3,
	amount: float,
	is_critical: bool = false,
	category: int = DamageCategory.NORMAL,
	metadata: Dictionary = {}
) -> void:
	if amount <= 0.0 or metadata.get("is_blocked", false) or metadata.get("is_invulnerable", false):
		return

	# Settings check: 'off' / 'important_only' / 'all'
	var setting_mode := str(SaveSystem.get_setting("damage_numbers", "all")).to_lower()
	if setting_mode == "off":
		return

	var is_high_priority: bool = (
		category == DamageCategory.CRITICAL
		or category == DamageCategory.PLAYER_HULL
		or category == DamageCategory.PLAYER_SHIELD
		or category == DamageCategory.HEAL
		or amount >= 35.0
		or bool(metadata.get("is_heavy", false))
		or bool(metadata.get("is_lethal", false))
		or bool(metadata.get("is_objective", false))
	)

	if setting_mode == "important_only" and not is_high_priority:
		return

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

	# 2. Priority Slot Reservation & Active Budget Enforcement
	if _active_labels.size() >= max_active_numbers or _free_labels.is_empty():
		if is_high_priority:
			# High priority event: try to preempt the oldest low-priority active label
			var candidate_to_replace: DamageNumber = null
			var oldest_low_age: float = -1.0
			for active_lbl in _active_labels:
				if is_instance_valid(active_lbl) and not active_lbl.is_high_priority:
					if active_lbl._age > oldest_low_age:
						oldest_low_age = active_lbl._age
						candidate_to_replace = active_lbl

			if candidate_to_replace != null:
				candidate_to_replace.deactivate()
			else:
				# All active labels are already high priority: preserve hard cap
				return
		else:
			# Low priority event and budget/pool is exhausted: drop visual
			return

	if _free_labels.is_empty() or _active_labels.size() >= max_active_numbers:
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
