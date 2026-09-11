extends SceneTree

## Tool script to construct Godot scenes using Kenney 3D assets.
## Complies strictly with Godot serialization guidelines.

func _init() -> void:
	print("--- STARTING KENNEY 3D ASSETS INTEGRATION ---")
	
	var success := true
	success = build_building_large() and success
	success = build_building_medium() and success
	success = build_building_small() and success
	success = build_warehouse() and success
	success = build_container_stack() and success
	success = build_storage_tanks() and success
	success = build_fuel_tank() and success
	
	if success:
		print("=== ALL MODULAR ASSET SCENES BUILT SUCCESSFULLY! ===")
	else:
		print("=== SOME SCENE BUILDS FAILED! ===")
		quit(1)
		return
		
	quit(0)

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

func build_building_large() -> bool:
	print("Building building_large.tscn...")
	var root := StaticBody3D.new()
	root.name = "BuildingLarge"
	root.collision_layer = 1
	root.collision_mask = 0
	
	# Complex composed of main skyscraper tower, secondary tower, and connecting lobby
	var tower_a := _instantiate_glb("res://assets/Models/GLB format/building-skyscraper-d.glb")
	tower_a.name = "TowerA"
	tower_a.transform.origin = Vector3(-4.0, 0, 0)
	tower_a.scale = Vector3(5.5, 4.5, 5.5)
	root.add_child(tower_a)
	
	var tower_b := _instantiate_glb("res://assets/Models/GLB format/building-skyscraper-c.glb")
	tower_b.name = "TowerB"
	tower_b.transform.origin = Vector3(4.0, 0, 0)
	tower_b.scale = Vector3(5.0, 4.2, 5.0)
	root.add_child(tower_b)
	
	var lobby := _instantiate_glb("res://assets/Models/GLB format/building-e.glb")
	lobby.name = "Podium"
	lobby.transform.origin = Vector3(0, 0, 0)
	lobby.scale = Vector3(6.0, 3.5, 6.0)
	root.add_child(lobby)
	
	# Rooftop AA Turret point
	var roof_marker := Marker3D.new()
	roof_marker.name = "RooftopDefensePoint"
	roof_marker.transform.origin = Vector3(-4.0, 24.65, 0)
	root.add_child(roof_marker)
	
	# Compound Collision Shapes
	var col_a := CollisionShape3D.new()
	col_a.name = "CollisionTowerA"
	col_a.transform.origin = Vector3(-4.0, 12.3, 0)
	var box_a := BoxShape3D.new()
	box_a.size = Vector3(7.2, 24.6, 7.8)
	col_a.shape = box_a
	root.add_child(col_a)
	
	var col_b := CollisionShape3D.new()
	col_b.name = "CollisionTowerB"
	col_b.transform.origin = Vector3(4.0, 8.55, 0)
	var box_b := BoxShape3D.new()
	box_b.size = Vector3(6.6, 17.1, 7.2)
	col_b.shape = box_b
	root.add_child(col_b)
	
	var col_p := CollisionShape3D.new()
	col_p.name = "CollisionPodium"
	col_p.transform.origin = Vector3(0, 2.9, 0)
	var box_p := BoxShape3D.new()
	box_p.size = Vector3(10.5, 5.8, 8.0)
	col_p.shape = box_p
	root.add_child(col_p)
	
	_set_owners(root, root)
	
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		push_error("Failed to pack building_large.tscn")
		return false
	err = ResourceSaver.save(scene, "res://scenes/environment/city/building_large.tscn")
	return err == OK

func build_building_medium() -> bool:
	print("Building building_medium.tscn...")
	var root := StaticBody3D.new()
	root.name = "BuildingMedium"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/building-l.glb")
	model.name = "VisualModel"
	model.scale = Vector3(5.5, 5.0, 5.5)
	root.add_child(model)
	
	var roof_marker := Marker3D.new()
	roof_marker.name = "RooftopDefensePoint"
	roof_marker.transform.origin = Vector3(0, 9.65, 0)
	root.add_child(roof_marker)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 4.8, 0)
	var box := BoxShape3D.new()
	box.size = Vector3(11.6, 9.6, 10.5)
	col.shape = box
	root.add_child(col)
	
	_set_owners(root, root)
	
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	err = ResourceSaver.save(scene, "res://scenes/environment/city/building_medium.tscn")
	return err == OK

func build_building_small() -> bool:
	print("Building building_small.tscn...")
	var root := StaticBody3D.new()
	root.name = "BuildingSmall"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/building-g.glb")
	model.name = "VisualModel"
	model.scale = Vector3(5.0, 5.0, 5.0)
	root.add_child(model)
	
	var roof_marker := Marker3D.new()
	roof_marker.name = "RooftopDefensePoint"
	roof_marker.transform.origin = Vector3(0, 6.45, 0)
	root.add_child(roof_marker)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 3.2, 0)
	var box := BoxShape3D.new()
	box.size = Vector3(8.6, 6.4, 6.6)
	col.shape = box
	root.add_child(col)
	
	_set_owners(root, root)
	
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	err = ResourceSaver.save(scene, "res://scenes/environment/city/building_small.tscn")
	return err == OK

func build_warehouse() -> bool:
	print("Building warehouse.tscn...")
	var root := StaticBody3D.new()
	root.name = "Warehouse"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var model := _instantiate_glb("res://assets/Models/GLB format/building-r.glb")
	model.name = "VisualModel"
	model.scale = Vector3(7.0, 5.5, 7.0)
	root.add_child(model)
	
	# Industrial Solar Panels on Roof
	var solar := _instantiate_glb("res://assets/Models/GLB format/solar-panel-landscape-group.glb")
	solar.name = "SolarPanels"
	solar.transform.origin = Vector3(0, 7.65, 0)
	solar.scale = Vector3(2.5, 2.5, 2.5)
	root.add_child(solar)
	
	var roof_marker := Marker3D.new()
	roof_marker.name = "RooftopDefensePoint"
	roof_marker.transform.origin = Vector3(0, 7.8, 0)
	root.add_child(roof_marker)
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 3.8, 0)
	var box := BoxShape3D.new()
	box.size = Vector3(17.5, 7.6, 9.0)
	col.shape = box
	root.add_child(col)
	
	_set_owners(root, root)
	
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	err = ResourceSaver.save(scene, "res://scenes/environment/city/warehouse.tscn")
	return err == OK

func build_container_stack() -> bool:
	print("Building container_stack.tscn...")
	var root := StaticBody3D.new()
	root.name = "ContainerStack"
	root.collision_layer = 1
	root.collision_mask = 0
	
	# Orange container
	var c_a := _instantiate_glb("res://assets/Models/GLB format/shipping-container-a.glb")
	c_a.name = "ContainerOrange"
	c_a.transform.origin = Vector3(-1.5, 0, 0)
	c_a.scale = Vector3(2.0, 2.0, 2.0)
	root.add_child(c_a)
	
	# Blue container
	var c_b := _instantiate_glb("res://assets/Models/GLB format/shipping-container-b.glb")
	c_b.name = "ContainerBlue"
	c_b.transform.origin = Vector3(1.5, 0, 0)
	c_b.scale = Vector3(2.0, 2.0, 2.0)
	root.add_child(c_b)
	
	# Green container stacked on top
	var c_c := _instantiate_glb("res://assets/Models/GLB format/shipping-container-c.glb")
	c_c.name = "ContainerGreen"
	c_c.transform.origin = Vector3(0, 2.58, 0)
	c_c.scale = Vector3(2.0, 2.0, 2.0)
	root.add_child(c_c)
	
	# Compound collision for realistic cover
	var col_1 := CollisionShape3D.new()
	col_1.name = "Collision1"
	col_1.transform.origin = Vector3(-1.5, 1.29, 0)
	var b1 := BoxShape3D.new()
	b1.size = Vector3(2.76, 2.58, 6.1)
	col_1.shape = b1
	root.add_child(col_1)
	
	var col_2 := CollisionShape3D.new()
	col_2.name = "Collision2"
	col_2.transform.origin = Vector3(1.5, 1.29, 0)
	var b2 := BoxShape3D.new()
	b2.size = Vector3(2.76, 2.58, 6.1)
	col_2.shape = b2
	root.add_child(col_2)
	
	var col_3 := CollisionShape3D.new()
	col_3.name = "Collision3"
	col_3.transform.origin = Vector3(0, 3.87, 0)
	var b3 := BoxShape3D.new()
	b3.size = Vector3(2.76, 2.58, 6.1)
	col_3.shape = b3
	root.add_child(col_3)
	
	_set_owners(root, root)
	
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	err = ResourceSaver.save(scene, "res://scenes/environment/industrial/container_stack.tscn")
	return err == OK

func build_storage_tanks() -> bool:
	print("Building storage_tanks.tscn...")
	var root := StaticBody3D.new()
	root.name = "StorageTanks"
	root.collision_layer = 1
	root.collision_mask = 0
	
	var tank1 := _instantiate_glb("res://assets/Models/GLB format/detail-tank-large.glb")
	tank1.name = "TankLargeA"
	tank1.transform.origin = Vector3(-4.5, 0, 0)
	tank1.scale = Vector3(4.5, 4.5, 4.5)
	root.add_child(tank1)
	
	var tank2 := _instantiate_glb("res://assets/Models/GLB format/detail-tank-large.glb")
	tank2.name = "TankLargeB"
	tank2.transform.origin = Vector3(4.5, 0, 0)
	tank2.scale = Vector3(4.5, 4.5, 4.5)
	root.add_child(tank2)
	
	var tank_h := _instantiate_glb("res://assets/Models/GLB format/detail-tank.glb")
	tank_h.name = "TankHorizontal"
	tank_h.transform.origin = Vector3(0, 0, 4.0)
	tank_h.scale = Vector3(4.0, 4.0, 4.0)
	root.add_child(tank_h)
	
	var col_t1 := CollisionShape3D.new()
	col_t1.name = "CollisionTankA"
	col_t1.transform.origin = Vector3(-4.5, 2.15, 0)
	var cyl1 := CylinderShape3D.new()
	cyl1.radius = 3.6
	cyl1.height = 4.3
	col_t1.shape = cyl1
	root.add_child(col_t1)
	
	var col_t2 := CollisionShape3D.new()
	col_t2.name = "CollisionTankB"
	col_t2.transform.origin = Vector3(4.5, 2.15, 0)
	var cyl2 := CylinderShape3D.new()
	cyl2.radius = 3.6
	cyl2.height = 4.3
	col_t2.shape = cyl2
	root.add_child(col_t2)
	
	var col_th := CollisionShape3D.new()
	col_th.name = "CollisionTankH"
	col_th.transform.origin = Vector3(0, 0.85, 4.0)
	var box_th := BoxShape3D.new()
	box_th.size = Vector3(3.5, 1.7, 2.2)
	col_th.shape = box_th
	root.add_child(col_th)
	
	_set_owners(root, root)
	
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	err = ResourceSaver.save(scene, "res://scenes/environment/industrial/storage_tanks.tscn")
	return err == OK

func build_fuel_tank() -> bool:
	print("Building fuel_tank.tscn...")
	var fuel_script: Script = load("res://scripts/environment/fuel_tank.gd")
	var root := StaticBody3D.new()
	root.name = "FuelTank"
	root.set_script(fuel_script)
	root.collision_layer = 4
	root.collision_mask = 1
	
	# Load large tank mesh
	var glb_tank := _instantiate_glb("res://assets/Models/GLB format/detail-tank-large.glb")
	var mesh_inst: MeshInstance3D = null
	for c in glb_tank.get_children():
		if c is MeshInstance3D:
			mesh_inst = c
			break
			
	var tank_mesh := MeshInstance3D.new()
	tank_mesh.name = "TankMesh"
	if mesh_inst:
		tank_mesh.mesh = mesh_inst.mesh
		# Transfer materials
		for i in range(mesh_inst.get_surface_override_material_count()):
			tank_mesh.set_surface_override_material(i, mesh_inst.get_surface_override_material(i))
	tank_mesh.scale = Vector3(3.5, 3.5, 3.5)
	root.add_child(tank_mesh)
	glb_tank.queue_free()
	
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.transform.origin = Vector3(0, 1.7, 0)
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.65
	cyl.height = 3.4
	col.shape = cyl
	root.add_child(col)
	
	# Smoke particles for 50% damage state
	var particles := GPUParticles3D.new()
	particles.name = "SmokeParticles"
	particles.transform.origin = Vector3(0, 3.5, 0)
	particles.emitting = false
	particles.amount = 16
	particles.lifetime = 1.2
	var ppm := ParticleProcessMaterial.new()
	ppm.direction = Vector3(0, 1, 0)
	ppm.spread = 25.0
	ppm.initial_velocity_min = 2.0
	ppm.initial_velocity_max = 4.0
	ppm.gravity = Vector3(0, 1, 0)
	ppm.scale_min = 0.6
	ppm.scale_max = 1.4
	particles.process_material = ppm
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
	sm.material = mat
	particles.draw_pass_1 = sm
	root.add_child(particles)
	
	_set_owners(root, root)
	
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		return false
	err = ResourceSaver.save(scene, "res://scenes/environment/props/fuel_tank.tscn")
	return err == OK
