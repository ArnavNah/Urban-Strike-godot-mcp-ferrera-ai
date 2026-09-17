extends SceneTree

func _init() -> void:
	print("--- STARTING CROPS CAPTURE SCRIPT ---")
	_run_captures()

func _run_captures() -> void:
	var out_dir: String = "C:/Users/Prime 3/.gemini/antigravity/brain/5fe9cfcf-9142-4405-9ae2-102264b2c914/"
	var bf_scene: PackedScene = load("res://scenes/battlefield/battlefield.tscn")
	var bf: Node3D = bf_scene.instantiate()
	root.add_child(bf)

	var save_sys = load("res://scripts/common/save_system.gd")
	if save_sys:
		save_sys.apply_graphics_preset("medium", self)

	# Allow tree to settle
	for f in range(15):
		await process_frame

	var player: Node3D = bf.find_child("PlayerHelicopter", true, false) as Node3D
	var streamer: CityWorldStreamer = bf.find_child("CityWorldStreamer", true, false) as CityWorldStreamer

	var ui: CanvasLayer = bf.find_child("UI", true, false) as CanvasLayer
	if ui:
		ui.visible = false

	# Disable combat directors / spawners so no enemy distractions clutter the architectural view
	var spawn_director = bf.find_child("SpawnDirector", true, false)
	if spawn_director:
		spawn_director.set_process(false)
	var horde_director = bf.find_child("ContinuousHordeDirector", true, false)
	if horde_director:
		horde_director.set_process(false)

	# Dedicated high-quality inspection camera with oblique Nuclear Strike-style isometric framing
	var cam := Camera3D.new()
	cam.fov = 48.0
	cam.far = 600.0
	bf.add_child(cam)
	cam.make_current()

	var targets: Array[Dictionary] = [
		{
			"file": "trees_helipad.png",
			"coord": Vector2i(0, 0),
			"heli_pos": Vector3(0.0, 7.0, 0.0),
			"cam_pos": Vector3(28.0, 24.0, 28.0),
			"cam_look": Vector3(0.0, 2.0, 0.0),
			"name": "Helipad & Perimeter Clearance"
		},
		{
			"file": "trees_commercial.png",
			"coord": Vector2i(1, 0),
			"heli_pos": Vector3(128.0, 9.0, 15.0),
			"cam_pos": Vector3(128.0, 20.0, 48.0),
			"cam_look": Vector3(128.0, 7.0, 0.0),
			"name": "Commercial District High-Rises, Planters & Street Trees"
		},
		{
			"file": "trees_industrial.png",
			"coord": Vector2i(4, 3),
			"heli_pos": Vector3(512.0, 9.0, 384.0),
			"cam_pos": Vector3(512.0 + 28.0, 24.0, 384.0 + 28.0),
			"cam_look": Vector3(512.0 - 5.0, 2.0, 384.0 - 5.0),
			"name": "Industrial District Warehouses & Perimeter Trees"
		},
		{
			"file": "trees_residential.png",
			"coord": Vector2i(5, 5),
			"heli_pos": Vector3(640.0, 9.0, 640.0),
			"cam_pos": Vector3(640.0 + 26.0, 22.0, 640.0 + 26.0),
			"cam_look": Vector3(640.0 - 6.0, 2.0, 640.0 - 6.0),
			"name": "Residential District Suburban Cabins & Lush Tree Clusters"
		},
		{
			"file": "residential_neighborhood_crops.png",
			"coord": Vector2i(5, 5),
			"heli_pos": Vector3(640.0 - 20.0, 12.0, 640.0 - 20.0),
			"cam_pos": Vector3(640.0 - 20.0 + 32.0, 28.0, 640.0 - 20.0 + 32.0),
			"cam_look": Vector3(640.0 - 20.0 - 8.0, 2.0, 640.0 - 20.0 - 8.0),
			"name": "Residential District Dense Crops & Gardens"
		}
	]

	for t in targets:
		print("Capturing %s (coord %s)..." % [t["name"], str(t["coord"])])
		if player:
			player.global_position = t["heli_pos"]
			player.velocity = Vector3.ZERO
		if streamer:
			streamer.force_update(t["coord"])

		cam.look_at_from_position(t["cam_pos"], t["cam_look"], Vector3.UP)

		# Wait frames for rendering & shadows to update
		for f in range(25):
			await process_frame

		RenderingServer.force_draw(false)
		var img: Image = root.get_viewport().get_texture().get_image()
		if img:
			var target_path: String = out_dir + str(t["file"])
			var err := img.save_png(target_path)
			print("  -> Saved %s (err=%d)" % [target_path, err])
		else:
			print("  -> FAIL: Could not get viewport image")

	print("=== CROPS CAPTURES COMPLETED! ===")
	quit(0)
