class_name TacticalMinimap
extends Control

@export var radar_range_m: float = 110.0
@export var map_radius_px: float = 64.0

var _player: Node3D = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5

	# Draw radar circle background
	draw_circle(center, map_radius_px, Color(0.06, 0.1, 0.12, 0.75))
	draw_arc(center, map_radius_px, 0, TAU, 32, Color(0.25, 0.8, 0.7, 0.8), 2.0)
	draw_arc(center, map_radius_px * 0.5, 0, TAU, 24, Color(0.25, 0.8, 0.7, 0.3), 1.0)

	if not is_instance_valid(_player):
		return

	var p_pos := _player.global_position
	var p_yaw := _player.rotation.y

	# Draw player arrow at center
	var fwd := Vector2(-sin(p_yaw), -cos(p_yaw))
	var right := Vector2(cos(p_yaw), -sin(p_yaw))
	var tip := center + fwd * 9.0
	var left_pt := center - fwd * 6.0 - right * 5.0
	var right_pt := center - fwd * 6.0 + right * 5.0
	draw_colored_polygon(PackedVector2Array([tip, left_pt, right_pt]), Color(0.3, 0.95, 0.85, 1.0))

	# Draw enemies
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		var e3d := e as Node3D
		if not is_instance_valid(e3d) or e3d == _player:
			continue

		var diff_x: float = e3d.global_position.x - p_pos.x
		var diff_z: float = e3d.global_position.z - p_pos.z
		var dist_m: float = Vector2(diff_x, diff_z).length()

		if dist_m > radar_range_m:
			continue

		var px_offset: Vector2 = Vector2(diff_x, diff_z) * (map_radius_px / radar_range_m)
		var blip_pos: Vector2 = center + px_offset

		if e.is_in_group("bosses"):
			# Large pulsing star/circle for Boss
			draw_circle(blip_pos, 7.0, Color(1.0, 0.1, 0.1, 1.0))
		elif e.is_in_group("objectives"):
			# Diamond for Objectives
			draw_rect(Rect2(blip_pos - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.9, 0.2, 1.0))
		elif e.is_in_group("air_enemies"):
			# Triangle for Air enemies (GDD 19.2)
			var a_tip := blip_pos + Vector2(0, -5)
			var a_l := blip_pos + Vector2(-4, 4)
			var a_r := blip_pos + Vector2(4, 4)
			draw_colored_polygon(PackedVector2Array([a_tip, a_l, a_r]), Color(1.0, 0.35, 0.2, 1.0))
		else:
			# Square for Ground enemies (GDD 19.2)
			draw_rect(Rect2(blip_pos - Vector2(3, 3), Vector2(6, 6)), Color(0.9, 0.45, 0.2, 1.0))
