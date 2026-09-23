class_name ImpactSparksEffect
extends GPUParticles3D

var is_pooled: bool = false
var is_active: bool = false
var _remaining: float = 0.0

static var _armor_material: StandardMaterial3D = null
static var _terrain_material: StandardMaterial3D = null
static var _shield_material: StandardMaterial3D = null

static func _get_armor_mat() -> StandardMaterial3D:
	if not _armor_material:
		_armor_material = StandardMaterial3D.new()
		_armor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_armor_material.albedo_color = Color(1.0, 0.85, 0.3, 1.0)
	return _armor_material

static func _get_terrain_mat() -> StandardMaterial3D:
	if not _terrain_material:
		_terrain_material = StandardMaterial3D.new()
		_terrain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_terrain_material.albedo_color = Color(0.68, 0.64, 0.58, 0.85)
	return _terrain_material

static func _get_shield_mat() -> StandardMaterial3D:
	if not _shield_material:
		_shield_material = StandardMaterial3D.new()
		_shield_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shield_material.albedo_color = Color(0.20, 0.92, 1.0, 1.0)
	return _shield_material

func _ready() -> void:
	if is_pooled:
		_on_pooled_finish()
	else:
		play()

func play() -> void:
	play_impact(Vector3.UP, false)

func play_impact(normal: Vector3 = Vector3.UP, is_armor: bool = false, is_shield: bool = false) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	is_active = true
	_remaining = lifetime + 0.05
	
	if is_shield:
		material_override = _get_shield_mat()
	elif is_armor:
		material_override = _get_armor_mat()
	else:
		material_override = _get_terrain_mat()
	
	# Orient along surface normal so debris shoots outward
	if normal.length_squared() > 0.01:
		var norm: Vector3 = normal.normalized()
		var tangent: Vector3
		if absf(norm.dot(Vector3.UP)) > 0.95:
			tangent = norm.cross(Vector3.FORWARD).normalized()
		else:
			tangent = norm.cross(Vector3.UP).normalized()
		var binormal: Vector3 = tangent.cross(norm).normalized()
		global_transform.basis = Basis(tangent, norm, binormal)

	set_process(true)
	restart()
	emitting = true

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		if is_pooled:
			_on_pooled_finish()
		else:
			queue_free()

func _on_pooled_finish() -> void:
	emitting = false
	visible = false
	is_active = false
	set_process(false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
