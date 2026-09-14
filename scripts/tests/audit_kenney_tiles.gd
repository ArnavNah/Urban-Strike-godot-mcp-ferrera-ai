extends SceneTree

func _init() -> void:
	print("=== KENNEY 3D ROAD TILES AUDIT ===")
	var dir_path := "res://assets/kenney/3d_road_tiles/models/"
	var dir := DirAccess.open(dir_path)
	if not dir:
		print("Error opening: ", dir_path)
		quit(1)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".gltf"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()

	print("Total glTF files found: ", str(files.size()))

	var materials_seen: Dictionary = {}
	var sizes_seen: Dictionary = {}
	var info_list: Array[Dictionary] = []

	for fname: String in files:
		var full_path := dir_path + fname
		var scn: PackedScene = load(full_path)
		if not scn:
			print("Failed to load: ", fname)
			continue
		var inst: Node = scn.instantiate()
		root.add_child(inst)

		var aabb: AABB = _calc_node_aabb(inst)
		var mats: Array[String] = []
		_gather_materials(inst, mats)
		for m in mats:
			materials_seen[m] = materials_seen.get(m, 0) + 1

		var size_key := "%.2f x %.2f x %.2f" % [aabb.size.x, aabb.size.y, aabb.size.z]
		sizes_seen[size_key] = sizes_seen.get(size_key, 0) + 1

		var item: Dictionary = {
			"file": fname,
			"aabb_pos": [aabb.position.x, aabb.position.y, aabb.position.z],
			"aabb_size": [aabb.size.x, aabb.size.y, aabb.size.z],
			"materials": mats
		}
		info_list.append(item)
		inst.queue_free()

	print("\n--- Unique Dimensions ---")
	for k in sizes_seen.keys():
		print("  ", k, ": count = ", sizes_seen[k])

	print("\n--- Materials Seen ---")
	for m in materials_seen.keys():
		print("  ", m, ": count = ", materials_seen[m])

	var file := FileAccess.open("res://docs/kenney_audit_raw.json", FileAccess.WRITE)
	if file:
		var json_str := JSON.stringify(info_list, "\t")
		file.store_string(json_str)
		file.close()
		print("Wrote raw audit to res://docs/kenney_audit_raw.json")

	quit(0)

func _calc_node_aabb(node: Node) -> AABB:
	var total_aabb := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is VisualInstance3D:
			var vi := cur as VisualInstance3D
			var local_aabb: AABB = vi.get_aabb()
			if local_aabb.size.length_squared() > 0.0001:
				var world_aabb: AABB = vi.global_transform * local_aabb
				if first:
					total_aabb = world_aabb
					first = false
				else:
					total_aabb = total_aabb.merge(world_aabb)
		for child in cur.get_children():
			stack.append(child)
	return total_aabb

func _gather_materials(node: Node, mats: Array[String]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_surface_override_material(s)
				if not mat:
					mat = mi.mesh.surface_get_material(s)
				if mat and not mats.has(mat.resource_name):
					mats.append(mat.resource_name)
	for child in node.get_children():
		_gather_materials(child, mats)
