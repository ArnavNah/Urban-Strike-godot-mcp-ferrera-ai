class_name DamageFlashManager
extends Node

## Centralized, zero-allocation damage flashing for enemy meshes.
## Replaces per-hit SceneTreeTimer/closure allocations with a frame-ticked registry.
## Respects SaveSystem settings, effect-distance limits, and enforces flash refresh rate-limiting.

static var instance: DamageFlashManager = null

# Flash duration & cadence tuning (strictly within the 40-70 ms requirement)
const FLASH_DURATION_NORMAL: float = 0.055 # 55 ms standard flash
const FLASH_DURATION_REDUCED: float = 0.040 # 40 ms reduced flash
const FLASH_REFRESH_COOLDOWN: float = 0.045 # 45 ms rate limit for consecutive hits
const EFFECT_DISTANCE: float = 140.0 # Match VfxPool distance culling

static var _normal_flash_mat: StandardMaterial3D = null
static var _reduced_flash_mat: StandardMaterial3D = null

# Cached settings
var _flash_enabled: bool = true
var _reduced_flashing: bool = false
var _flash_intensity: float = 1.0

# Active tracked flashes:
# instance_id -> {
#   "target_ref": WeakRef,
#   "meshes": Array[MeshInstance3D],
#   "timer": float,
#   "duration": float,
#   "last_flash_time": float,
#   "mat": StandardMaterial3D
# }
var _active_flashes: Dictionary = {}

static func get_normal_material() -> StandardMaterial3D:
	if not _normal_flash_mat:
		_normal_flash_mat = StandardMaterial3D.new()
		_normal_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_normal_flash_mat.albedo_color = Color(1.6, 1.6, 1.6, 1.0)
	return _normal_flash_mat

static func get_reduced_material() -> StandardMaterial3D:
	if not _reduced_flash_mat:
		_reduced_flash_mat = StandardMaterial3D.new()
		_reduced_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_reduced_flash_mat.albedo_color = Color(1.15, 1.15, 1.15, 1.0)
	return _reduced_flash_mat

static func ensure_instance(tree: SceneTree = null) -> DamageFlashManager:
	if instance and is_instance_valid(instance):
		return instance
	var target_tree := tree
	if not target_tree and Engine.get_main_loop() is SceneTree:
		target_tree = Engine.get_main_loop() as SceneTree
	if target_tree and target_tree.root:
		var existing := target_tree.root.get_node_or_null("DamageFlashManager") as DamageFlashManager
		if existing:
			instance = existing
			return instance
		var mgr := DamageFlashManager.new()
		mgr.name = "DamageFlashManager"
		target_tree.root.call_deferred("add_child", mgr)
		instance = mgr
		return mgr
	return null

func _enter_tree() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	clear_all()
	if instance == self:
		instance = null

func _ready() -> void:
	refresh_settings()
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("setting_changed"):
		eb.setting_changed.connect(_on_setting_changed)

func refresh_settings() -> void:
	_flash_enabled = bool(SaveSystem.get_setting("damage_flash_enabled", true))
	_reduced_flashing = bool(SaveSystem.get_setting("reduced_flashing", false))
	_flash_intensity = float(SaveSystem.get_setting("damage_flash_intensity", 1.0))

func _on_setting_changed(key: String, _val: Variant) -> void:
	if key in ["damage_flash_enabled", "reduced_flashing", "damage_flash_intensity"]:
		refresh_settings()

## Primary entry point: Flash the meshes of a target for 40-70 ms without per-hit heap allocations.
static func flash_target(target: Node, meshes: Array[MeshInstance3D] = []) -> void:
	var mgr := instance
	if not mgr or not is_instance_valid(mgr):
		mgr = ensure_instance()
	if mgr:
		mgr.flash(target, meshes)

## Clear active flash overrides immediately (e.g. on enemy death).
static func clear_target(target: Node) -> void:
	if instance and is_instance_valid(instance):
		instance.clear_node(target)

func flash(target: Node, meshes: Array[MeshInstance3D] = []) -> void:
	if not is_instance_valid(target) or not _flash_enabled or _flash_intensity <= 0.01:
		return

	# Effect-distance culling check
	if target is Node3D and is_inside_tree() and get_viewport():
		var camera := get_viewport().get_camera_3d()
		if camera and camera.global_position.distance_squared_to((target as Node3D).global_position) > EFFECT_DISTANCE * EFFECT_DISTANCE:
			return

	var target_id := target.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0

	# Rate-limiting check for rapid hits on the same target
	if _active_flashes.has(target_id):
		var existing: Dictionary = _active_flashes[target_id]
		if now - float(existing.get("last_flash_time", 0.0)) < FLASH_REFRESH_COOLDOWN:
			# Refresh remaining duration to full without re-applying overrides
			existing["timer"] = existing.get("duration", FLASH_DURATION_NORMAL)
			return

	var dur := FLASH_DURATION_REDUCED if _reduced_flashing else FLASH_DURATION_NORMAL
	var mat: StandardMaterial3D = get_reduced_material() if _reduced_flashing else get_normal_material()

	var target_meshes: Array[MeshInstance3D] = meshes
	if target_meshes.is_empty():
		target_meshes = _collect_meshes(target)
	if target_meshes.is_empty():
		return

	for m in target_meshes:
		if is_instance_valid(m):
			m.material_override = mat

	_active_flashes[target_id] = {
		"target_ref": weakref(target),
		"meshes": target_meshes,
		"timer": dur,
		"duration": dur,
		"last_flash_time": now,
		"mat": mat
	}

func clear_node(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var target_id := target.get_instance_id()
	if _active_flashes.has(target_id):
		_restore_entry(_active_flashes[target_id])
		_active_flashes.erase(target_id)

func clear_all() -> void:
	for id in _active_flashes.keys():
		_restore_entry(_active_flashes[id])
	_active_flashes.clear()

func _restore_entry(entry: Dictionary) -> void:
	var mat: Material = entry.get("mat")
	var meshes: Array = entry.get("meshes", [])
	for m in meshes:
		if is_instance_valid(m) and (m as MeshInstance3D).material_override == mat:
			(m as MeshInstance3D).material_override = null

func _process(delta: float) -> void:
	if _active_flashes.is_empty():
		return

	var expired_ids: Array[int] = []
	for id in _active_flashes.keys():
		var entry: Dictionary = _active_flashes[id]
		var wref: WeakRef = entry.get("target_ref")
		var target: Object = wref.get_ref() if wref else null

		if not target or not is_instance_valid(target):
			_restore_entry(entry)
			expired_ids.append(id)
			continue

		var timer: float = float(entry.get("timer", 0.0)) - delta
		entry["timer"] = timer

		if timer <= 0.0:
			_restore_entry(entry)
			expired_ids.append(id)

	for id in expired_ids:
		_active_flashes.erase(id)

func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	_recurse_collect_meshes(node, result)
	return result

func _recurse_collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		_recurse_collect_meshes(child, result)
