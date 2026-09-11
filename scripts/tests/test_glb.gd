extends SceneTree

func _init() -> void:
	var dir := DirAccess.open("res://assets/Models/GLB format")
	if not dir:
		print("Cannot open dir")
		quit(1)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var models: Array[Dictionary] = []
	while file_name != "":
		if file_name.ends_with(".glb"):
			var p := "res://assets/Models/GLB format/" + file_name
			var sc: PackedScene = load(p)
			if sc:
				var inst := sc.instantiate()
				var mesh_node: MeshInstance3D = null
				for c in inst.get_children():
					if c is MeshInstance3D:
						mesh_node = c
						break
				var sz := Vector3.ZERO
				if mesh_node:
					sz = mesh_node.get_aabb().size
				models.append({"name": file_name, "size": sz})
				inst.queue_free()
		file_name = dir.get_next()
	
	models.sort_custom(func(a, b): return a["name"] < b["name"])
	for m in models:
		print("%-32s -> Size: (%.2f, %.2f, %.2f)" % [m["name"], m["size"].x, m["size"].y, m["size"].z])
	quit(0)
