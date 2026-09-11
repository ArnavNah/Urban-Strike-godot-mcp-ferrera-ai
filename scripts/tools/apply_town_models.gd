extends SceneTree

func _init() -> void:
	print("--- BUILDING KENNEY TOWN & OUTSKIRTS MODELS ---")
	var success := true
	success = build_town_house() and success
	success = build_town_workshop() and success
	success = build_town_cabin() and success
	success = build_water_tower() and success
	success = build_wind_turbine() and success
	success = build_solar_array() and success
	
	if not success:
		print("FAIL: Failed to build town scenes")
		quit(1)
		return
		
	success = update_outskirts_district() and success
	if success:
		print("=== OUTSKIRTS DISTRICT UPGRADED WITH KENNEY TOWN MODELS! ===")
		quit(0)
	else:
		print("FAIL: Failed to update outskirts district")
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

func build_town_house() -> bool:
	print("Building town_house_a.tscn...")
	var root := StaticBody3D.new()
	root.name = "TownHouseA"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/low-detail-building-wide-a.glb")
	model.name = "VisualModel"
	model.scale = Vector3(4.5, 4.5, 4.5)
	root.add_child(model)
	
	var roof_marker := Marker3D.new()
	roof_marker.name = "RooftopDefensePoint"
	roof_marker.transform.origin = Vector3(0, 5.0, 0)
	root.add_child(roof_marker)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 2.5, 0)
	var box := BoxShape3D.new()
	box.size = Vector3(4.6, 5.0, 2.4)
	col.shape = box
	root.add_child(col)
	
	_set_owners(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(scene, "res://scenes/environment/town/town_house_a.tscn") == OK

func build_town_workshop() -> bool:
	print("Building town_workshop.tscn...")
	var root := StaticBody3D.new()
	root.name = "TownWorkshop"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/low-detail-building-wide-b.glb")
	model.name = "VisualModel"
	model.scale = Vector3(4.5, 4.5, 4.5)
	root.add_child(model)
	
	var roof_marker := Marker3D.new()
	roof_marker.name = "RooftopDefensePoint"
	roof_marker.transform.origin = Vector3(0, 5.2, 0)
	root.add_child(roof_marker)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 2.6, 0)
	var box := BoxShape3D.new()
	box.size = Vector3(4.6, 5.2, 2.4)
	col.shape = box
	root.add_child(col)
	
	_set_owners(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(scene, "res://scenes/environment/town/town_workshop.tscn") == OK

func build_town_cabin() -> bool:
	print("Building town_cabin.tscn...")
	var root := StaticBody3D.new()
	root.name = "TownCabin"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/low-detail-building-c.glb")
	model.name = "VisualModel"
	model.scale = Vector3(4.5, 4.5, 4.5)
	root.add_child(model)
	
	var roof_marker := Marker3D.new()
	roof_marker.name = "RooftopDefensePoint"
	roof_marker.transform.origin = Vector3(0, 10.2, 0)
	root.add_child(roof_marker)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 5.1, 0)
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 10.2, 2.4)
	col.shape = box
	root.add_child(col)
	
	_set_owners(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(scene, "res://scenes/environment/town/town_cabin.tscn") == OK

func build_water_tower() -> bool:
	print("Building water_tower.tscn...")
	var root := StaticBody3D.new()
	root.name = "WaterTower"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/water-tower.glb")
	model.name = "VisualModel"
	model.scale = Vector3(3.5, 3.5, 3.5)
	root.add_child(model)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 4.0, 0)
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 8.0
	col.shape = cyl
	root.add_child(col)
	
	_set_owners(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(scene, "res://scenes/environment/town/water_tower.tscn") == OK

func build_wind_turbine() -> bool:
	print("Building wind_turbine.tscn...")
	var root := StaticBody3D.new()
	root.name = "WindTurbine"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/windmill.glb")
	model.name = "VisualModel"
	model.scale = Vector3(4.0, 4.0, 4.0)
	root.add_child(model)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 3.6, 0)
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2
	cyl.height = 7.2
	col.shape = cyl
	root.add_child(col)
	
	_set_owners(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(scene, "res://scenes/environment/town/wind_turbine.tscn") == OK

func build_solar_array() -> bool:
	print("Building solar_array.tscn...")
	var root := StaticBody3D.new()
	root.name = "SolarArray"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/solar-panel-landscape-group.glb")
	model.name = "VisualModel"
	model.scale = Vector3(3.5, 3.5, 3.5)
	root.add_child(model)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 0.45, 0)
	var box := BoxShape3D.new()
	box.size = Vector3(5.3, 0.9, 3.2)
	col.shape = box
	root.add_child(col)
	
	_set_owners(root, root)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	return ResourceSaver.save(scene, "res://scenes/environment/town/solar_array.tscn") == OK

func update_outskirts_district() -> bool:
	print("Updating outskirts.tscn with Kenney town models...")
	var out_scene: PackedScene = load("res://scenes/environment/districts/outskirts.tscn")
	if not out_scene:
		push_error("Cannot load outskirts.tscn")
		return false
	var root := out_scene.instantiate()
	
	var house_scene: PackedScene = load("res://scenes/environment/town/town_house_a.tscn")
	var workshop_scene: PackedScene = load("res://scenes/environment/town/town_workshop.tscn")
	var cabin_scene: PackedScene = load("res://scenes/environment/town/town_cabin.tscn")
	var tower_scene: PackedScene = load("res://scenes/environment/town/water_tower.tscn")
	var turbine_scene: PackedScene = load("res://scenes/environment/town/wind_turbine.tscn")
	var solar_scene: PackedScene = load("res://scenes/environment/town/solar_array.tscn")
	
	# 1. Update RuralServiceStop
	var rural := root.find_child("RuralServiceStop", true, false)
	if rural:
		var house := rural.find_child("RoadsideHouse", false, false) as Node3D
		if house and house_scene:
			var h_pos: Vector3 = house.transform.origin
			house.queue_free()
			var new_house := house_scene.instantiate() as Node3D
			new_house.name = "RoadsideHouse"
			new_house.transform.origin = h_pos
			rural.add_child(new_house)
			
		var shop := rural.find_child("RepairShop", false, false) as Node3D
		if shop and workshop_scene:
			var s_pos: Vector3 = shop.transform.origin
			shop.queue_free()
			var new_shop := workshop_scene.instantiate() as Node3D
			new_shop.name = "RepairShop"
			new_shop.transform.origin = s_pos
			rural.add_child(new_shop)
			
		if tower_scene:
			var water_tower := tower_scene.instantiate() as Node3D
			water_tower.name = "ServiceWaterTower"
			water_tower.transform.origin = Vector3(-108, 0, 42)
			rural.add_child(water_tower)
			
	# 2. Update OvergrownSettlement
	var settl := root.find_child("OvergrownSettlement", true, false)
	if settl:
		var cab := settl.find_child("AbandonedCabin", false, false) as Node3D
		if cab and cabin_scene:
			var c_pos: Vector3 = cab.transform.origin
			cab.queue_free()
			var new_cab := cabin_scene.instantiate() as Node3D
			new_cab.name = "AbandonedCabin"
			new_cab.transform.origin = c_pos
			settl.add_child(new_cab)
			
	# 3. Add Wind Turbines to LowRollingGround knolls
	var knolls := root.find_child("LowRollingGround", true, false)
	if knolls and turbine_scene:
		var turb_west := turbine_scene.instantiate()
		turb_west.name = "TurbineWest"
		turb_west.transform.origin = Vector3(-96, 2.5, 95)
		knolls.add_child(turb_west)
		
		var turb_south := turbine_scene.instantiate()
		turb_south.name = "TurbineSouth"
		turb_south.transform.origin = Vector3(-32, 2.5, 97)
		knolls.add_child(turb_south)
		
	# 4. Populate SolarArrayFarm with actual solar panel arrays
	var solar_farm := root.find_child("SolarArrayFarm", true, false)
	if solar_farm and solar_scene:
		var coords: Array[Vector3] = [
			Vector3(-155, 0.1, 28),
			Vector3(-145, 0.1, 28),
			Vector3(-155, 0.1, 38),
			Vector3(-145, 0.1, 38)
		]
		var idx := 1
		for pos in coords:
			var s_inst := solar_scene.instantiate()
			s_inst.name = "SolarBank_%02d" % idx
			s_inst.transform.origin = pos
			solar_farm.add_child(s_inst)
			idx += 1
			
	_set_owners(root, root)
	var p_scene := PackedScene.new()
	var err := p_scene.pack(root)
	if err != OK:
		push_error("Failed to pack outskirts.tscn")
		return false
	return ResourceSaver.save(p_scene, "res://scenes/environment/districts/outskirts.tscn") == OK
