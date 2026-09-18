extends SceneTree

func _init() -> void:
	print("--- STARTING ENEMY HIERARCHY CAPTURE ---")
	_run_captures()

func _run_captures() -> void:
	var out_dir: String = "C:/Users/Prime 3/.gemini/antigravity/brain/5fe9cfcf-9142-4405-9ae2-102264b2c914/"
	var bf_scene: PackedScene = load("res://scenes/battlefield/battlefield.tscn")
	var bf: Node3D = bf_scene.instantiate()
	root.add_child(bf)

	var save_sys = load("res://scripts/common/save_system.gd")
	if save_sys:
		save_sys.apply_graphics_preset("medium", self)

	for f in range(15):
		await process_frame

	var ui: CanvasLayer = bf.find_child("UI", true, false) as CanvasLayer
	if ui:
		ui.visible = false

	# Disable ambient spawners
	var spawn_director = bf.find_child("SpawnDirector", true, false)
	if spawn_director:
		spawn_director.set_process(false)
	var horde_director = bf.find_child("ContinuousHordeDirector", true, false)
	if horde_director:
		horde_director.set_process(false)

	var staging_root := Node3D.new()
	staging_root.name = "StagingRoot"
	bf.add_child(staging_root)

	var cam := Camera3D.new()
	cam.fov = 46.0
	cam.far = 800.0
	bf.add_child(cam)
	cam.make_current()

	# -------------------------------------------------------------
	# Capture 1: Air Hierarchy Showcase
	# -------------------------------------------------------------
	var player_scn := load("res://scenes/player/player_helicopter.tscn") as PackedScene
	var mini_scn := load("res://scenes/companions/mini_helicopter.tscn") as PackedScene

	var air_scenes: Array[Dictionary] = [
		{"path": "res://scenes/enemies/air_scout_helicopter.tscn", "pos": Vector3(-28.0, 16.0, 10.0)},
		{"path": "res://scenes/enemies/air_rocket_raider.tscn", "pos": Vector3(-18.0, 16.0, 10.0)},
		{"path": "res://scenes/enemies/air_attack_gunship.tscn", "pos": Vector3(-8.0, 16.0, 10.0)},
		{"path": "res://scenes/enemies/hunter_helicopter.tscn", "pos": Vector3(8.0, 16.0, 10.0)},
		{"path": "res://scenes/enemies/air_jammer_helicopter.tscn", "pos": Vector3(18.0, 16.0, 10.0)},
		{"path": "res://scenes/enemies/air_ace_gunship.tscn", "pos": Vector3(28.0, 16.0, 10.0)},
		{"path": "res://scenes/enemies/air_transport_helicopter.tscn", "pos": Vector3(-22.0, 16.0, -12.0)},
		{"path": "res://scenes/enemies/mig_17_striker.tscn", "pos": Vector3(-6.0, 16.0, -12.0)},
		{"path": "res://scenes/enemies/air_heavy_gunship.tscn", "pos": Vector3(12.0, 16.0, -12.0)},
		{"path": "res://scenes/enemies/boss_archon.tscn", "pos": Vector3(0.0, 18.0, -38.0)}
	]

	# Spawn player and mini drone at center
	var pl := player_scn.instantiate() as Node3D
	pl.position = Vector3(0.0, 16.0, 10.0)
	staging_root.add_child(pl)

	var mini_drone := mini_scn.instantiate() as Node3D
	mini_drone.position = Vector3(3.5, 16.5, 12.0)
	staging_root.add_child(mini_drone)

	for info in air_scenes:
		var scn := load(info["path"]) as PackedScene
		if scn:
			var inst := scn.instantiate() as Node3D
			inst.position = info["pos"]
			inst.set_process(false)
			inst.set_physics_process(false)
			staging_root.add_child(inst)

	cam.position = Vector3(0.0, 52.0, 56.0)
	cam.look_at(Vector3(0.0, 16.0, -2.0), Vector3.UP)

	for f in range(12):
		await process_frame

	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(out_dir + "enemy_hierarchy_air.png")
	print("Saved enemy_hierarchy_air.png")

	# Clear staging root
	for c in staging_root.get_children():
		c.queue_free()

	for f in range(5):
		await process_frame

	# -------------------------------------------------------------
	# Capture 2: Ground Hierarchy Showcase
	# -------------------------------------------------------------
	var ground_scenes: Array[Dictionary] = [
		{"path": "res://scenes/enemies/ground_scout_buggy.tscn", "pos": Vector3(-32.0, 0.0, 0.0)},
		{"path": "res://scenes/enemies/ground_rocket_technical.tscn", "pos": Vector3(-22.0, 0.0, 0.0)},
		{"path": "res://scenes/enemies/ground_mortar_carrier.tscn", "pos": Vector3(-12.0, 0.0, 0.0)},
		{"path": "res://scenes/enemies/ground_troop_carrier_apc.tscn", "pos": Vector3(-2.0, 0.0, 0.0)},
		{"path": "res://scenes/enemies/ground_jammer_vehicle.tscn", "pos": Vector3(8.0, 0.0, 0.0)},
		{"path": "res://scenes/enemies/ground_assault_ifv.tscn", "pos": Vector3(18.0, 0.0, 0.0)},
		{"path": "res://scenes/enemies/tank.tscn", "pos": Vector3(28.0, 0.0, 0.0)},
		{"path": "res://scenes/enemies/ground_turret.tscn", "pos": Vector3(38.0, 0.0, 0.0)}
	]

	# Add hovering player helicopter for size perspective
	var pl_ground := player_scn.instantiate() as Node3D
	pl_ground.position = Vector3(0.0, 9.0, 16.0)
	staging_root.add_child(pl_ground)

	var mini_g := mini_scn.instantiate() as Node3D
	mini_g.position = Vector3(3.5, 9.5, 18.0)
	staging_root.add_child(mini_g)

	for info in ground_scenes:
		var scn := load(info["path"]) as PackedScene
		if scn:
			var inst := scn.instantiate() as Node3D
			inst.position = info["pos"]
			inst.set_process(false)
			inst.set_physics_process(false)
			staging_root.add_child(inst)

	cam.position = Vector3(0.0, 32.0, 42.0)
	cam.look_at(Vector3(2.0, 1.5, 2.0), Vector3.UP)

	for f in range(12):
		await process_frame

	img = root.get_viewport().get_texture().get_image()
	img.save_png(out_dir + "enemy_hierarchy_ground.png")
	print("Saved enemy_hierarchy_ground.png")

	# Clear staging root
	for c in staging_root.get_children():
		c.queue_free()

	for f in range(5):
		await process_frame

	# -------------------------------------------------------------
	# Capture 3: In-Game Oblique Combat Readability
	# -------------------------------------------------------------
	var combat_pl := player_scn.instantiate() as Node3D
	combat_pl.position = Vector3(0.0, 15.0, 12.0)
	staging_root.add_child(combat_pl)

	var combat_mini := mini_scn.instantiate() as Node3D
	combat_mini.position = Vector3(3.2, 15.5, 14.2)
	staging_root.add_child(combat_mini)

	var scout := (load("res://scenes/enemies/air_scout_helicopter.tscn") as PackedScene).instantiate() as Node3D
	scout.position = Vector3(-12.0, 14.5, -8.0)
	scout.rotation_degrees = Vector3(0.0, 150.0, 0.0)
	staging_root.add_child(scout)

	var gunship := (load("res://scenes/enemies/air_attack_gunship.tscn") as PackedScene).instantiate() as Node3D
	gunship.position = Vector3(14.0, 16.0, -14.0)
	gunship.rotation_degrees = Vector3(0.0, -140.0, 0.0)
	staging_root.add_child(gunship)

	var heavy := (load("res://scenes/enemies/air_heavy_gunship.tscn") as PackedScene).instantiate() as Node3D
	heavy.position = Vector3(-4.0, 19.0, -32.0)
	heavy.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	staging_root.add_child(heavy)

	var tank_inst := (load("res://scenes/enemies/tank.tscn") as PackedScene).instantiate() as Node3D
	tank_inst.position = Vector3(6.0, 0.0, -6.0)
	tank_inst.rotation_degrees = Vector3(0.0, -45.0, 0.0)
	staging_root.add_child(tank_inst)

	var apc_inst := (load("res://scenes/enemies/ground_troop_carrier_apc.tscn") as PackedScene).instantiate() as Node3D
	apc_inst.position = Vector3(-8.0, 0.0, 2.0)
	apc_inst.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	staging_root.add_child(apc_inst)

	# Combat camera distance & angle (~45 deg oblique isometric)
	cam.position = Vector3(0.0, 42.0, 48.0)
	cam.look_at(Vector3(0.0, 10.0, -6.0), Vector3.UP)

	for f in range(12):
		await process_frame

	img = root.get_viewport().get_texture().get_image()
	img.save_png(out_dir + "enemy_readability_combat.png")
	print("Saved enemy_readability_combat.png")

	print("--- ALL ENEMY HIERARCHY CAPTURES COMPLETE ---")
	quit(0)
