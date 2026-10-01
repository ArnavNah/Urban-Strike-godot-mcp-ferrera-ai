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

	# 1. Translucent navy radar background & tactical glass border
	draw_circle(center, map_radius_px, Color(0.06, 0.10, 0.14, 0.85))
	draw_arc(center, map_radius_px, 0, TAU, 48, Color(0.20, 0.45, 0.60, 0.65), 1.5)

	# 2. Subtle distance range rings (50m and 100m)
	var r_50 := map_radius_px * (50.0 / radar_range_m)
	var r_100 := map_radius_px * (100.0 / radar_range_m)
	draw_arc(center, r_50, 0, TAU, 32, Color(0.20, 0.45, 0.60, 0.22), 1.0)
	draw_arc(center, r_100, 0, TAU, 40, Color(0.20, 0.45, 0.60, 0.32), 1.0)

	# Cardinal crosshair guides (subtle 3px ticks)
	var guide_col := Color(0.20, 0.45, 0.60, 0.45)
	draw_line(center + Vector2(0, -map_radius_px + 1), center + Vector2(0, -map_radius_px + 5), guide_col, 1.0)
	draw_line(center + Vector2(0, map_radius_px - 5), center + Vector2(0, map_radius_px - 1), guide_col, 1.0)
	draw_line(center + Vector2(-map_radius_px + 1, 0), center + Vector2(-map_radius_px + 5, 0), guide_col, 1.0)
	draw_line(center + Vector2(map_radius_px - 5, 0), center + Vector2(map_radius_px - 1, 0), guide_col, 1.0)

	# 3. North Indicator ("N" tick and label)
	var n_pos := center + Vector2(0, -map_radius_px - 2.0)
	var n_arrow := PackedVector2Array([
		n_pos + Vector2(0, -4),
		n_pos + Vector2(-3, 2),
		n_pos + Vector2(3, 2)
	])
	draw_colored_polygon(n_arrow, Color(0.31, 0.88, 0.93, 0.95))

	var default_font: Font = ThemeDB.fallback_font
	if default_font:
		draw_string(default_font, n_pos + Vector2(-3.5, -5.0), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.31, 0.88, 0.93, 0.95))

	if not is_instance_valid(_player):
		return

	var p_pos := _player.global_position
	var p_yaw := _player.rotation.y

	var high_contrast: bool = bool(SaveSystem.get_setting("high_contrast_indicators", false))

	# 4. Draw player arrow at center
	var fwd := Vector2(-sin(p_yaw), -cos(p_yaw))
	var right := Vector2(cos(p_yaw), -sin(p_yaw))
	var tip := center + fwd * 8.5
	var left_pt := center - fwd * 5.5 - right * 4.5
	var right_pt := center - fwd * 5.5 + right * 4.5
	var player_poly := PackedVector2Array([tip, left_pt, right_pt])
	if high_contrast:
		draw_polyline(PackedVector2Array([tip, left_pt, right_pt, tip]), Color(0.02, 0.04, 0.06, 0.95), 2.0)
	draw_colored_polygon(player_poly, Color(0.31, 0.88, 0.93, 1.0))

	# 5. Differentiated Enemy Blips
	var enemies: Array[Node3D] = []
	if EnemyRegistry.instance and is_instance_valid(EnemyRegistry.instance):
		enemies = EnemyRegistry.instance.get_enemies_in_radius(p_pos, radar_range_m)
	else:
		var raw_nodes := get_tree().get_nodes_in_group("enemies")
		for n in raw_nodes:
			if n is Node3D:
				enemies.append(n as Node3D)
	for e in enemies:
		var e3d: Node3D = e
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
			# Heavy Boss: Star/diamond with outer alert ring
			var b_rad := 7.0
			var b_diamond := PackedVector2Array([
				blip_pos + Vector2(0, -b_rad),
				blip_pos + Vector2(b_rad, 0),
				blip_pos + Vector2(0, b_rad),
				blip_pos + Vector2(-b_rad, 0)
			])
			if high_contrast:
				draw_arc(blip_pos, b_rad + 2.0, 0, TAU, 16, Color(0.02, 0.04, 0.06, 0.95), 2.0)
			draw_arc(blip_pos, b_rad + 2.0, 0, TAU, 16, Color(1.0, 0.2, 0.2, 0.8), 1.5)
			draw_colored_polygon(b_diamond, Color(1.0, 0.15, 0.15, 1.0))
		elif e.is_in_group("objectives"):
			# Objective: Gold/cyan diamond
			var d_pts := PackedVector2Array([
				blip_pos + Vector2(0, -5),
				blip_pos + Vector2(5, 0),
				blip_pos + Vector2(0, 5),
				blip_pos + Vector2(-5, 0)
			])
			if high_contrast:
				draw_polyline(PackedVector2Array([d_pts[0], d_pts[1], d_pts[2], d_pts[3], d_pts[0]]), Color(0.02, 0.04, 0.06, 0.95), 2.0)
			draw_colored_polygon(d_pts, Color(0.31, 0.88, 0.93, 1.0))
		elif e.is_in_group("sam_sites"):
			# SAM Site: Amber hexagon
			var hex_pts := PackedVector2Array([
				blip_pos + Vector2(0, -4.5),
				blip_pos + Vector2(4.0, -2.2),
				blip_pos + Vector2(4.0, 2.2),
				blip_pos + Vector2(0, 4.5),
				blip_pos + Vector2(-4.0, 2.2),
				blip_pos + Vector2(-4.0, -2.2)
			])
			if high_contrast:
				draw_polyline(PackedVector2Array([hex_pts[0], hex_pts[1], hex_pts[2], hex_pts[3], hex_pts[4], hex_pts[5], hex_pts[0]]), Color(0.02, 0.04, 0.06, 0.95), 2.0)
			draw_colored_polygon(hex_pts, Color(1.0, 0.65, 0.15, 1.0))
		elif e.is_in_group("air_enemies"):
			# Air enemy: Sharp diamond
			var a_diamond := PackedVector2Array([
				blip_pos + Vector2(0, -5),
				blip_pos + Vector2(4, 0),
				blip_pos + Vector2(0, 5),
				blip_pos + Vector2(-4, 0)
			])
			if high_contrast:
				draw_polyline(PackedVector2Array([a_diamond[0], a_diamond[1], a_diamond[2], a_diamond[3], a_diamond[0]]), Color(0.02, 0.04, 0.06, 0.95), 2.0)
			draw_colored_polygon(a_diamond, Color(1.0, 0.35, 0.25, 1.0))
		else:
			# Ground enemy: Circle
			if high_contrast:
				draw_arc(blip_pos, 4.0, 0, TAU, 12, Color(0.02, 0.04, 0.06, 0.95), 1.5)
			draw_circle(blip_pos, 3.2, Color(0.96, 0.60, 0.18, 1.0))

	# 6. World Rewards & Encounters (distinct shapes & tactical colors)
	var encounters := get_tree().get_nodes_in_group("world_encounters")
	for enc in encounters:
		var enc3d := enc as Node3D
		if not is_instance_valid(enc3d) or enc3d.is_queued_for_deletion():
			continue
		if enc3d.get("is_completed") == true:
			continue

		var diff_x: float = enc3d.global_position.x - p_pos.x
		var diff_z: float = enc3d.global_position.z - p_pos.z
		var dist_m: float = Vector2(diff_x, diff_z).length()
		if dist_m > radar_range_m:
			continue

		var px_offset: Vector2 = Vector2(diff_x, diff_z) * (map_radius_px / radar_range_m)
		var blip_pos: Vector2 = center + px_offset

		var disp_type: String = "SUPPLY"
		if enc3d.has_method("get_encounter_display_type"):
			disp_type = enc3d.get_encounter_display_type()

		match disp_type:
			"REPAIR":
				# Medical green cross (+)
				var cr_col := Color(0.20, 0.98, 0.45, 1.0)
				if high_contrast:
					draw_rect(Rect2(blip_pos - Vector2(4.5, 4.5), Vector2(9, 9)), Color(0.02, 0.04, 0.06, 0.90))
				draw_line(blip_pos + Vector2(-3.5, 0), blip_pos + Vector2(3.5, 0), cr_col, 2.0)
				draw_line(blip_pos + Vector2(0, -3.5), blip_pos + Vector2(0, 3.5), cr_col, 2.0)
			"AMMO":
				# Munitions amber upward triangle
				var am_col := Color(1.0, 0.65, 0.15, 1.0)
				var tri := PackedVector2Array([
					blip_pos + Vector2(0, -4.5),
					blip_pos + Vector2(4.0, 3.5),
					blip_pos + Vector2(-4.0, 3.5)
				])
				if high_contrast:
					draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.02, 0.04, 0.06, 0.95), 2.0)
				draw_colored_polygon(tri, am_col)
			"BEACON":
				# Pulsing gold ring with center core
				var b_col := Color(0.961, 0.725, 0.106, 1.0)
				var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
				if high_contrast:
					draw_arc(blip_pos, 5.5, 0, TAU, 16, Color(0.02, 0.04, 0.06, 0.95), 2.5)
				draw_arc(blip_pos, 5.0, 0, TAU, 16, Color(b_col.r, b_col.g, b_col.b, pulse), 1.8)
				draw_circle(blip_pos, 2.0, b_col)
			"CACHE":
				var is_unlocked: bool = bool(enc3d.get("is_unlocked"))
				var c_col := Color(0.20, 0.95, 0.40, 1.0) if is_unlocked else Color(0.95, 0.22, 0.22, 1.0)
				# Square outline (locked) or filled (unlocked)
				var sq_rect := Rect2(blip_pos - Vector2(3.5, 3.5), Vector2(7, 7))
				if high_contrast:
					draw_rect(sq_rect.grow(1.0), Color(0.02, 0.04, 0.06, 0.95), false, 2.0)
				draw_rect(sq_rect, c_col, is_unlocked, 1.6)
			_:
				# Default supply marker
				var s_col := Color(0.30, 0.75, 1.0, 1.0)
				draw_circle(blip_pos, 3.0, s_col)
