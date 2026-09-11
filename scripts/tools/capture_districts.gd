extends SceneTree

func _init() -> void:
	print("--- STARTING DISTRICT CAPTURE SCRIPT ---")
	_run_captures()

func _run_captures() -> void:
	var bf_scene: PackedScene = load("res://scenes/battlefield/battlefield.tscn")
	var bf: Node3D = bf_scene.instantiate()
	root.add_child(bf)
	
	# Hide UI
	var ui := bf.get_node_or_null("UI")
	if ui:
		(ui as CanvasItem).visible = false
		
	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.far = 1000.0
	bf.add_child(camera)
	camera.make_current()
	
	var targets: Array[Dictionary] = [
		{"name": "01_kenney_city_urban.png", "pos": Vector3(130, 45, -20), "look": Vector3(65, 5, -80)},
		{"name": "02_kenney_industrial_district.png", "pos": Vector3(120, 40, 110), "look": Vector3(65, 5, 45)},
		{"name": "03_kenney_outskirts_town.png", "pos": Vector3(-45, 35, 110), "look": Vector3(-85, 3, 50)},
		{"name": "04_kenney_battlefield_overview.png", "pos": Vector3(180, 140, 180), "look": Vector3(0, 0, 0)}
	]
	
	var out_dir: String = "C:/Users/Prime 3/.gemini/antigravity/brain/8ca32915-61d4-4eba-8ea3-db58a37aea64/captures/"
	
	for t in targets:
		print("Framing target: ", t["name"])
		camera.look_at_from_position(t["pos"], t["look"], Vector3.UP)
		# Wait several frames for renderer to present
		for f in range(25):
			await process_frame
		
		RenderingServer.force_draw(false)
		var img: Image = root.get_viewport().get_texture().get_image()
		if img:
			var target_file: String = out_dir + str(t["name"])
			var err := img.save_png(target_file)
			print("Saved screenshot (err=", err, "): ", target_file)
		else:
			print("FAIL: Could not get viewport image")
			
	print("=== ALL CAPTURES COMPLETE! ===")
	quit(0)
