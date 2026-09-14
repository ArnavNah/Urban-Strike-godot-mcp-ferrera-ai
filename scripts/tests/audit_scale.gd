extends SceneTree

func _init() -> void:
	print("=== AUDITING ASSET RUNTIME DIMENSIONS ===")
	var targets := {
		"Player Helicopter": "res://scenes/player/player_helicopter.tscn",
		"Car (ParkedVehicle)": "res://scenes/environment/props/parked_vehicle.tscn",
		"Road Straight": "res://scenes/environment/roads/road_straight.tscn",
		"Wide Avenue": "res://scenes/environment/roads/wide_avenue.tscn",
		"Building Small": "res://scenes/environment/city/building_small.tscn",
		"Building Small B": "res://scenes/environment/city/building_small_b.tscn",
		"Building Medium": "res://scenes/environment/city/building_medium.tscn",
		"Building Medium B": "res://scenes/environment/city/building_medium_b.tscn",
		"Building Large": "res://scenes/environment/city/building_large.tscn",
		"Building Large B": "res://scenes/environment/city/building_large_b.tscn",
		"Warehouse": "res://scenes/environment/city/warehouse.tscn",
	}

	for name: String in targets.keys():
		var path: String = targets[name]
		if not ResourceLoader.exists(path):
			print("Missing: %s" % path)
			continue
		var scn: PackedScene = load(path)
		var inst: Node = scn.instantiate()
		root.add_child(inst)

		var aabb: AABB = _calculate_node_aabb(inst)
		var size: Vector3 = aabb.size
		print("[%s]" % name)
		print("  AABB Size: X=%.2f, Y=%.2f, Z=%.2f (Center: %s)" % [size.x, size.y, size.z, str(aabb.position + size * 0.5)])

		if name == "Player Helicopter":
			var rotor_mesh := inst.find_child("RotorBlurDisc", true, false) as MeshInstance3D
			if rotor_mesh and rotor_mesh.mesh is CylinderMesh:
				var cm: CylinderMesh = rotor_mesh.mesh as CylinderMesh
				var global_r: float = cm.top_radius * rotor_mesh.global_transform.basis.get_scale().x
				print("  Rotor Blur Radius: local=%.2f, world=%.2f (world diameter=%.2f m)" % [cm.top_radius, global_r, global_r * 2.0])
			var col := inst.find_child("CollisionShape3D", true, false) as CollisionShape3D
			if col and col.shape is CapsuleShape3D:
				var cs: CapsuleShape3D = col.shape as CapsuleShape3D
				print("  Collision Capsule: Radius: %.2f, Height: %.2f" % [cs.radius, cs.height])
			var gun := inst.find_child("GunMount", true, false) as Node3D
			if gun:
				print("  GunMount Global Pos: %s" % str(gun.position))

		if name.begins_with("Building"):
			var col := inst.find_child("*Collision*", true, false) as CollisionShape3D
			if col and col.shape is BoxShape3D:
				var bs := col.shape as BoxShape3D
				print("  Collision Box: Size=%s" % str(bs.size))
			var r_pt := inst.find_child("RooftopDefensePoint", true, false) as Marker3D
			if r_pt:
				print("  RooftopDefensePoint: Pos=%s" % str(r_pt.position))

		inst.queue_free()

	quit(0)

func _calculate_node_aabb(node: Node) -> AABB:
	var total_aabb := AABB()
	var first := true

	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr is VisualInstance3D:
			var vi := curr as VisualInstance3D
			var a: AABB = vi.get_aabb()
			if a.size.length_squared() > 0.001:
				var xform: Transform3D = vi.global_transform
				var transformed_aabb: AABB = _transform_aabb(a, xform)
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
