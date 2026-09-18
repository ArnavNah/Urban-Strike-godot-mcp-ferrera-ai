extends Node

func _ready() -> void:
	var out: Array[String] = []
	out.append("=== COMPREHENSIVE SCALE AUDIT ===")
	out.append("Scale Reference: 1 unit ~ 1 meter\n")

	var targets: Dictionary = {
		"PLAYER": {
			"Player Helicopter": "res://scenes/player/player_helicopter.tscn",
			"Mini Helicopter (Companion)": "res://scenes/companions/mini_helicopter.tscn",
		},
		"AIR ENEMIES": {
			"Air Scout Helicopter": "res://scenes/enemies/air_scout_helicopter.tscn",
			"Air Attack Gunship": "res://scenes/enemies/air_attack_gunship.tscn",
			"Air Rocket Raider": "res://scenes/enemies/air_rocket_raider.tscn",
			"Air Jammer Helicopter": "res://scenes/enemies/air_jammer_helicopter.tscn",
			"Air Heavy Gunship": "res://scenes/enemies/air_heavy_gunship.tscn",
			"Air Transport Helicopter": "res://scenes/enemies/air_transport_helicopter.tscn",
			"Air Ace Gunship": "res://scenes/enemies/air_ace_gunship.tscn",
			"Hunter Helicopter": "res://scenes/enemies/hunter_helicopter.tscn",
			"MIG-17 Striker": "res://scenes/enemies/mig_17_striker.tscn",
			"Boss Archon": "res://scenes/enemies/boss_archon.tscn",
		},
		"GROUND ENEMIES": {
			"Tank": "res://scenes/enemies/tank.tscn",
			"Ground Turret": "res://scenes/enemies/ground_turret.tscn",
			"Ground Scout Buggy": "res://scenes/enemies/ground_scout_buggy.tscn",
			"Ground Rocket Technical": "res://scenes/enemies/ground_rocket_technical.tscn",
			"Ground Mortar Carrier": "res://scenes/enemies/ground_mortar_carrier.tscn",
			"Ground Assault IFV": "res://scenes/enemies/ground_assault_ifv.tscn",
			"Ground Troop Carrier APC": "res://scenes/enemies/ground_troop_carrier_apc.tscn",
			"Ground Jammer Vehicle": "res://scenes/enemies/ground_jammer_vehicle.tscn",
			"SAM Site": "res://scenes/enemies/sam_site.tscn",
			"Infantry Cluster": "res://scenes/enemies/infantry_cluster.tscn",
		},
		"VEHICLES & PROPS": {
			"Parked Vehicle": "res://scenes/environment/props/parked_vehicle.tscn",
			"Wrecked Vehicle": "res://scenes/environment/props/wrecked_vehicle.tscn",
			"Streetlight": "res://scenes/environment/props/streetlight.tscn",
			"Tree Cluster": "res://scenes/environment/props/tree_cluster.tscn",
			"Fuel Tank": "res://scenes/environment/props/fuel_tank.tscn",
			"Crate": "res://scenes/environment/props/crate.tscn",
			"Barrier": "res://scenes/environment/props/barrier.tscn",
			"Sandbag": "res://scenes/environment/props/sandbag.tscn",
			"Antenna": "res://scenes/environment/props/antenna.tscn",
			"Fence": "res://scenes/environment/props/fence.tscn",
		},
		"BUILDINGS": {
			"Building Small": "res://scenes/environment/city/building_small.tscn",
			"Building Small B": "res://scenes/environment/city/building_small_b.tscn",
			"Building Small C": "res://scenes/environment/city/building_small_c.tscn",
			"Building Medium": "res://scenes/environment/city/building_medium.tscn",
			"Building Medium B": "res://scenes/environment/city/building_medium_b.tscn",
			"Building Medium C": "res://scenes/environment/city/building_medium_c.tscn",
			"Building Large": "res://scenes/environment/city/building_large.tscn",
			"Building Large B": "res://scenes/environment/city/building_large_b.tscn",
			"Building Skyscraper C": "res://scenes/environment/city/building_skyscraper_c.tscn",
			"Warehouse": "res://scenes/environment/city/warehouse.tscn",
			"Warehouse Sawtooth": "res://scenes/environment/city/warehouse_sawtooth.tscn",
			"Storage Tanks": "res://scenes/environment/industrial/storage_tanks.tscn",
			"Container Stack": "res://scenes/environment/industrial/container_stack.tscn",
			"Chimney Large": "res://scenes/environment/industrial/chimney_large.tscn",
			"Chimney Small": "res://scenes/environment/industrial/chimney_small.tscn",
			"Solar Panel Portrait": "res://scenes/environment/industrial/solar_panel_portrait.tscn",
			"Town Cabin": "res://scenes/environment/town/town_cabin.tscn",
			"Town House A": "res://scenes/environment/town/town_house_a.tscn",
			"Town Workshop": "res://scenes/environment/town/town_workshop.tscn",
			"Water Tower": "res://scenes/environment/town/water_tower.tscn",
			"Wind Turbine": "res://scenes/environment/town/wind_turbine.tscn",
			"Solar Array": "res://scenes/environment/town/solar_array.tscn",
		},
		"MILITARY & OBJECTIVES": {
			"Radar Station (Objective)": "res://scenes/objects/radar_station.tscn",
			"Radar Site (Military)": "res://scenes/environment/military/radar_site.tscn",
			"SAM Site (Military Env)": "res://scenes/environment/military/sam_site_environment.tscn",
			"Radio Tower": "res://scenes/environment/military/radio_tower.tscn",
			"Checkpoint": "res://scenes/environment/military/checkpoint.tscn",
			"Hangar (Military)": "res://scenes/environment/military/hangar.tscn",
		}
	}

	for category: String in targets.keys():
		out.append("==================================================")
		out.append("CATEGORY: %s" % category)
		out.append("==================================================")
		var cat_items: Dictionary = targets[category]
		for item_name: String in cat_items.keys():
			var path: String = cat_items[item_name]
			if not ResourceLoader.exists(path):
				out.append("  [%s] MISSING: %s" % [item_name, path])
				continue
			var scn: PackedScene = load(path)
			var inst: Node = scn.instantiate()
			add_child(inst)

			var root_xform: Transform3D = Transform3D.IDENTITY
			if inst is Node3D:
				root_xform = (inst as Node3D).global_transform

			var aabb: AABB = _calculate_node_visual_aabb(inst, root_xform)
			var size: Vector3 = aabb.size
			out.append("  [%s] (%s)" % [item_name, path])
			out.append("    Visual AABB: Width(X)=%.2f m, Height(Y)=%.2f m, Length(Z)=%.2f m" % [size.x, size.y, size.z])
			out.append("    Bounds Min: (%s), Max: (%s)" % [str(aabb.position), str(aabb.position + size)])

			# Extra inspection for player
			if item_name == "Player Helicopter":
				var rotor_blur := inst.find_child("RotorBlurDisc", true, false) as MeshInstance3D
				if rotor_blur and rotor_blur.mesh is CylinderMesh:
					var cm: CylinderMesh = rotor_blur.mesh as CylinderMesh
					var disc_scale: Vector3 = rotor_blur.global_transform.basis.get_scale()
					out.append("    Rotor Blur Disc: Radius=%.2f m, Diameter=%.2f m" % [cm.top_radius * disc_scale.x, cm.top_radius * disc_scale.x * 2.0])
				var top_prop := inst.find_child("TopProp", true, false) as Node3D
				if top_prop:
					var prop_aabb: AABB = _calculate_node_visual_aabb(top_prop, root_xform)
					out.append("    TopProp Visual AABB: X=%.2f m, Y=%.2f m, Z=%.2f m (Diameter=%.2f m)" % [prop_aabb.size.x, prop_aabb.size.y, prop_aabb.size.z, maxf(prop_aabb.size.x, prop_aabb.size.z)])
				var body_node := inst.find_child("Body", true, false) as Node3D
				if body_node:
					var body_aabb: AABB = _calculate_node_visual_aabb(body_node, root_xform)
					out.append("    Body Visual AABB: X=%.2f m, Y=%.2f m, Z=%.2f m" % [body_aabb.size.x, body_aabb.size.y, body_aabb.size.z])
				var col_shape := inst.find_child("CollisionShape3D", true, false) as CollisionShape3D
				if col_shape and col_shape.shape is CapsuleShape3D:
					var cs: CapsuleShape3D = col_shape.shape as CapsuleShape3D
					out.append("    Collision Capsule: Radius=%.2f m, Height=%.2f m" % [cs.radius, cs.height])
				var visuals_node := (inst.find_child("VisualRig", true, false) as Node3D) if inst.find_child("VisualRig", true, false) else (inst.find_child("Visuals", true, false) as Node3D)
				if visuals_node:
					out.append("    FlightTiltPivot/%s Scale: %s" % [visuals_node.name, str(visuals_node.scale)])

			# Extra inspection for collision shape
			var col := inst.find_child("*Collision*", true, false) as CollisionShape3D
			if col and col.shape:
				if col.shape is BoxShape3D:
					out.append("    Collision Box: %s" % str((col.shape as BoxShape3D).size))
				elif col.shape is CapsuleShape3D:
					var cs := col.shape as CapsuleShape3D
					out.append("    Collision Capsule: Radius=%.2f m, Height=%.2f m" % [cs.radius, cs.height])
				elif col.shape is CylinderShape3D:
					var cyl := col.shape as CylinderShape3D
					out.append("    Collision Cylinder: Radius=%.2f m, Height=%.2f m" % [cyl.radius, cyl.height])

			inst.queue_free()

	var out_path: String = ProjectSettings.globalize_path("res://scale_audit.txt")
	var fa := FileAccess.open(out_path, FileAccess.WRITE)
	if fa:
		for line: String in out:
			fa.store_line(line)
			print(line)
		fa.close()
		print("Wrote scale_audit.txt successfully to: %s" % out_path)
	else:
		print("ERROR: Failed to open %s for writing! Error: %d" % [out_path, FileAccess.get_open_error()])

	get_tree().quit(0)

func _calculate_node_visual_aabb(node: Node, root_xform: Transform3D) -> AABB:
	var total_aabb := AABB()
	var first := true

	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()

		if curr is Node3D and (curr as Node3D).top_level and curr != node:
			continue
		if curr is GPUParticles3D or curr is CPUParticles3D:
			continue

		if curr is VisualInstance3D:
			var vi := curr as VisualInstance3D
			var a: AABB = vi.get_aabb()
			if a.size.length_squared() > 0.0001:
				var rel_xform: Transform3D = root_xform.affine_inverse() * vi.global_transform
				var transformed_aabb: AABB = _transform_aabb(a, rel_xform)
				if first:
					total_aabb = transformed_aabb
					first = false
				else:
					total_aabb = total_aabb.merge(transformed_aabb)
		for child in curr.get_children():
			stack.append(child)

	return total_aabb

func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	var corners: Array[Vector3] = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	]
	var new_min: Vector3 = xform * corners[0]
	var new_max: Vector3 = new_min
	for i in range(1, 8):
		var p: Vector3 = xform * corners[i]
		new_min = Vector3(minf(new_min.x, p.x), minf(new_min.y, p.y), minf(new_min.z, p.z))
		new_max = Vector3(maxf(new_max.x, p.x), maxf(new_max.y, p.y), maxf(new_max.z, p.z))
	return AABB(new_min, new_max - new_min)
