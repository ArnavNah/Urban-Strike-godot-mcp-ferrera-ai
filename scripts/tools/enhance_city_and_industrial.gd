extends SceneTree

func _init() -> void:
	print("--- ENHANCING CITY SKYLINE & INDUSTRIAL DISTRICT ---")
	var success := true
	success = build_skyscraper_variant_b() and success
	success = update_central_urban() and success
	success = update_industrial() and success
	
	if success:
		print("=== CITY SKYLINE & INDUSTRIAL DISTRICT ENHANCED! ===")
		quit(0)
	else:
		print("FAIL: Skyline / Industrial enhancement failed")
		quit(1)

func _set_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.get_child_count() > 0:
			_set_owners(child, root)

func _instantiate_glb(path: String) -> Node3D:
	var res: PackedScene = load(path)
	if not res:
		push_error("Failed to load: " + path)
		return null
	return res.instantiate() as Node3D

func build_skyscraper_variant_b() -> bool:
	print("Building building_large_b.tscn...")
	var root := StaticBody3D.new()
	root.name = "BuildingLargeB"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var tower := _instantiate_glb("res://assets/Models/GLB format/building-skyscraper-b.glb")
	tower.name = "TowerMain"
	tower.transform.origin = Vector3(-2.5, 0, 0)
	tower.scale = Vector3(5.5, 4.8, 5.5)
	root.add_child(tower)
	
	var annex := _instantiate_glb("res://assets/Models/GLB format/building-skyscraper-e.glb")
	annex.name = "TowerAnnex"
	annex.transform.origin = Vector3(3.5, 0, 0)
	annex.scale = Vector3(4.8, 4.2, 4.8)
	root.add_child(annex)
	
	var roof_marker := Marker3D.new()
	roof_marker.name = "RooftopDefensePoint"
	roof_marker.transform.origin = Vector3(-2.5, 21.6, 0)
	root.add_child(roof_marker)
	
	var col_main := CollisionShape3D.new()
	col_main.name = "CollisionMain"
	col_main.transform.origin = Vector3(-2.5, 10.75, 0)
	var box_m := BoxShape3D.new()
	box_m.size = Vector3(7.5, 21.5, 7.5)
	col_main.shape = box_m
	root.add_child(col_main)
	
	var col_annex := CollisionShape3D.new()
	col_annex.name = "CollisionAnnex"
	col_annex.transform.origin = Vector3(3.5, 8.55, 0)
	var box_a := BoxShape3D.new()
	box_a.size = Vector3(6.2, 17.1, 6.0)
	col_annex.shape = box_a
	root.add_child(col_annex)
	
	_set_owners(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(scene, "res://scenes/environment/city/building_large_b.tscn") == OK

func update_central_urban() -> bool:
	print("Updating central_urban.tscn with skyscraper variety...")
	var scene: PackedScene = load("res://scenes/environment/districts/central_urban.tscn")
	if not scene:
		return false
	var root := scene.instantiate()
	
	var b_large_b_scene: PackedScene = load("res://scenes/environment/city/building_large_b.tscn")
	if b_large_b_scene:
		var fin_plaza := root.find_child("FinancialPlaza", true, false)
		if fin_plaza:
			var t_east := fin_plaza.find_child("TowerEast", false, false) as Node3D
			if t_east:
				var t_pos: Vector3 = t_east.transform.origin
				t_east.queue_free()
				var new_east := b_large_b_scene.instantiate() as Node3D
				new_east.name = "TowerEast"
				new_east.transform.origin = t_pos
				fin_plaza.add_child(new_east)
				
		var comms := root.find_child("CommunicationsBlock", true, false)
		if comms:
			# Add rooftop antenna detail near tower
			var ant := _instantiate_glb("res://assets/Models/GLB format/chimney-small.glb")
			if ant:
				ant.name = "RoofAntenna"
				ant.transform.origin = Vector3(31, 24.8, -96)
				ant.scale = Vector3(3.0, 4.0, 3.0)
				comms.add_child(ant)
				
	_set_owners(root, root)
	var p_scene := PackedScene.new()
	var err := p_scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(p_scene, "res://scenes/environment/districts/central_urban.tscn") == OK

func update_industrial() -> bool:
	print("Updating industrial.tscn with refinery chimneys and solar panels...")
	var scene: PackedScene = load("res://scenes/environment/districts/industrial.tscn")
	if not scene:
		return false
	var root := scene.instantiate()
	
	var depot := root.find_child("FuelDepot", true, false)
	if depot:
		var chimney := _instantiate_glb("res://assets/Models/GLB format/chimney-large.glb")
		if chimney:
			chimney.name = "RefineryChimney"
			chimney.transform.origin = Vector3(88, 0, 32)
			chimney.scale = Vector3(4.0, 5.0, 4.0)
			depot.add_child(chimney)
			
	var terminal := root.find_child("FreightTerminal", true, false)
	if terminal:
		var solars := _instantiate_glb("res://assets/Models/GLB format/solar-panel-portrait-group.glb")
		if solars:
			solars.name = "TerminalSolarArray"
			solars.transform.origin = Vector3(46, 0.1, 24)
			solars.scale = Vector3(3.0, 3.0, 3.0)
			terminal.add_child(solars)
			
	_set_owners(root, root)
	var p_scene := PackedScene.new()
	var err := p_scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(p_scene, "res://scenes/environment/districts/industrial.tscn") == OK
