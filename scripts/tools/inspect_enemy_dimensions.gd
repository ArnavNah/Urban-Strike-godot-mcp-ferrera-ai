extends SceneTree

func _init() -> void:
	print("--- INSPECTING ENEMY DIMENSIONS V2 ---")
	var enemy_files: Array[String] = [
		# Air enemies
		"res://scenes/enemies/air_scout_helicopter.tscn",
		"res://scenes/enemies/air_rocket_raider.tscn",
		"res://scenes/enemies/air_attack_gunship.tscn",
		"res://scenes/enemies/air_jammer_helicopter.tscn",
		"res://scenes/enemies/air_transport_helicopter.tscn",
		"res://scenes/enemies/air_heavy_gunship.tscn",
		"res://scenes/enemies/air_ace_gunship.tscn",
		"res://scenes/enemies/boss_archon.tscn",
		"res://scenes/enemies/hunter_helicopter.tscn",
		"res://scenes/enemies/mig_17_striker.tscn",
		# Ground enemies
		"res://scenes/enemies/ground_scout_buggy.tscn",
		"res://scenes/enemies/ground_rocket_technical.tscn",
		"res://scenes/enemies/ground_mortar_carrier.tscn",
		"res://scenes/enemies/ground_troop_carrier_apc.tscn",
		"res://scenes/enemies/ground_assault_ifv.tscn",
		"res://scenes/enemies/tank.tscn",
		"res://scenes/enemies/ground_jammer_vehicle.tscn",
		"res://scenes/enemies/ground_turret.tscn",
		"res://scenes/enemies/sam_site.tscn"
	]

	var out_path := ProjectSettings.globalize_path("res://enemy_inspection.txt")
	var f := FileAccess.open(out_path, FileAccess.WRITE)

	var world := Node3D.new()
	root.add_child(world)

	for p in enemy_files:
		if not FileAccess.file_exists(p):
			f.store_line("MISSING: %s" % p)
			continue

		var scn := load(p) as PackedScene
		if not scn:
			f.store_line("FAIL LOAD: %s" % p)
			continue

		var inst := scn.instantiate() as Node3D
		world.add_child(inst)

		var line := "\n======================================================\n"
		line += "SCENE: %s\n" % p.get_file()
		line += "Root: %s (%s)\n" % [inst.name, inst.get_class()]

		# Collision Shape
		var col: CollisionShape3D = inst.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape:
			var sh := col.shape
			if sh is CapsuleShape3D:
				line += "Collision: Capsule(r=%.2f, h=%.2f), pos=%s, rot=%s\n" % [sh.radius, sh.height, str(col.position), str(col.rotation_degrees)]
			elif sh is BoxShape3D:
				line += "Collision: Box(x=%.2f, y=%.2f, z=%.2f), pos=%s\n" % [sh.size.x, sh.size.y, sh.size.z, str(col.position)]
			elif sh is CylinderShape3D:
				line += "Collision: Cylinder(r=%.2f, h=%.2f), pos=%s\n" % [sh.radius, sh.height, str(col.position)]
			elif sh is SphereShape3D:
				line += "Collision: Sphere(r=%.2f), pos=%s\n" % [sh.radius, str(col.position)]
			else:
				line += "Collision: %s, pos=%s\n" % [sh.get_class(), str(col.position)]
		else:
			line += "Collision: NONE directly under root\n"

		# Visuals container
		var vis: Node3D = (inst.get_node_or_null("Visuals") if inst.has_node("Visuals") else inst.get_node_or_null("Body")) as Node3D
		if vis:
			line += "Visual Container: '%s' scale=%s pos=%s rot=%s\n" % [vis.name, str(vis.scale), str(vis.position), str(vis.rotation_degrees)]
		else:
			line += "Visual Container: NO 'Visuals' or 'Body' node!\n"

		# Calculate full visual AABB of all VisualInstances in inst
		var total_aabb: AABB
		var has_aabb := false
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var cur := stack.pop_back() as Node
			for c in cur.get_children():
				stack.append(c)
			if cur is VisualInstance3D and not (cur is CollisionShape3D):
				var vi := cur as VisualInstance3D
				var a: AABB = vi.get_aabb()
				if a.size.length_squared() > 0.0001:
					var xform: Transform3D = inst.global_transform.affine_inverse() * vi.global_transform
					var transformed_aabb: AABB = xform * a
					if not has_aabb:
						total_aabb = transformed_aabb
						has_aabb = true
					else:
						total_aabb = total_aabb.merge(transformed_aabb)

		if has_aabb:
			line += "Visual AABB (Local to Root): (Width X=%.2fm, Height Y=%.2fm, Length Z=%.2fm), center=%s\n" % [
				total_aabb.size.x, total_aabb.size.y, total_aabb.size.z, str(total_aabb.get_center())
			]
		else:
			line += "Visual AABB: NO visual meshes found!\n"

		# List key markers / children
		var key_names: Array[String] = ["LOSRayCast", "Muzzle", "MainRotor", "TailRotor", "Hurtbox", "Hitbox", "Shadow", "RocketOrigin", "Turret", "Barrel", "GroundRay"]
		var found_markers: Array[String] = []
		stack = [inst]
		while not stack.is_empty():
			var cur := stack.pop_back() as Node
			for c in cur.get_children():
				stack.append(c)
			for km in key_names:
				if cur.name.contains(km):
					var p3d := cur as Node3D
					if p3d:
						var local_pos: Vector3 = inst.global_transform.affine_inverse() * p3d.global_position
						found_markers.append("%s (path=%s, pos=%s)" % [cur.name, inst.get_path_to(cur), str(local_pos)])
					else:
						found_markers.append("%s (path=%s)" % [cur.name, inst.get_path_to(cur)])

		line += "Key Nodes: " + (", ".join(found_markers) if not found_markers.is_empty() else "None") + "\n"

		f.store_line(line)
		inst.queue_free()

	f.close()
	world.queue_free()
	print("--- INSPECTION V2 COMPLETE ---")
	quit(0)
