class_name MuzzleFlashEffect
extends Node3D

var is_pooled: bool = false
var is_active: bool = false
var _tween: Tween

@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D")

static var _player_flash_mat: StandardMaterial3D = null
static var _enemy_flash_mat: StandardMaterial3D = null

func _ready() -> void:
	if is_pooled:
		visible = false
		is_active = false
		set_process(false)
		set_physics_process(false)
	else:
		play()

func play(is_enemy: bool = false, base_scale: float = 1.4, dir: Vector3 = Vector3.ZERO) -> void:
	if _tween:
		_tween.kill()
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	is_active = true

	if not _player_flash_mat:
		_player_flash_mat = StandardMaterial3D.new()
		_player_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_player_flash_mat.albedo_color = Color(1.0, 0.92, 0.45, 1.0)
	if not _enemy_flash_mat:
		_enemy_flash_mat = StandardMaterial3D.new()
		_enemy_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_enemy_flash_mat.albedo_color = Color(1.0, 0.42, 0.12, 1.0)

	if mesh_instance:
		mesh_instance.material_override = _enemy_flash_mat if is_enemy else _player_flash_mat

	if dir.length_squared() > 0.01:
		var up_axis := Vector3.UP if absf(dir.y) < 0.9 else Vector3.FORWARD
		look_at(global_position + dir, up_axis)

	var start_scale := Vector3(base_scale, base_scale, base_scale * 1.35)
	scale = start_scale

	var tween := create_tween()
	_tween = tween
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.045).from(start_scale)
	if is_pooled:
		tween.tween_callback(_on_pooled_finish)
	else:
		tween.tween_callback(queue_free)

func _on_pooled_finish() -> void:
	visible = false
	is_active = false
	set_process(false)
	set_physics_process(false)
	scale = Vector3.ONE
