class_name XPBurstPickup
extends Area3D

## Rare XP Collection-Burst Pickup ("Vacuum Core").
## Upon collection, gathers all free-floating XP gems across the battlefield
## and magnetizes them to the player using bounded batching (15 gems/frame)
## to eliminate frame-time spikes.

@export var collection_radius: float = 4.0
@export var collection_radius_xz: float = 5.0
@export var collection_height: float = 35.0

var _is_collected: bool = false
var _mesh: MeshInstance3D = null
var _halo: OmniLight3D = null
var _time: float = 0.0

# Batch magnetizing queue
var _pending_gems: Array[XPGem] = []
var _target_player: PlayerHelicopter = null

func _ready() -> void:
	add_to_group("pickups")
	add_to_group("xp_burst_pickups")

	collision_layer = 16
	collision_mask = 2
	monitoring = true
	monitorable = true

	var col_shape := CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var cyl := CylinderShape3D.new()
	cyl.radius = collection_radius_xz
	cyl.height = collection_height
	col_shape.shape = cyl
	col_shape.position = Vector3(0.0, collection_height * 0.5, 0.0)
	add_child(col_shape)

	_build_visuals()
	_ensure_persistent_parent()

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _ensure_persistent_parent() -> void:
	var p := get_parent()
	while p:
		if p.is_in_group("city_chunks") or p.name == "Encounters" or p.name == "encounters_root":
			var root_scene := get_tree().current_scene if get_tree().current_scene else get_tree().root
			reparent.call_deferred(root_scene, true)
			break
		p = p.get_parent()

func _is_line_of_sight_clear(target_pos: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var space := get_world_3d().direct_space_state
	if not space:
		return true
	var from_pos := global_position + Vector3(0.0, 1.2, 0.0)
	var ray_query := PhysicsRayQueryParameters3D.create(from_pos, target_pos, 1) # Layer 1 = World/Buildings
	ray_query.exclude = [get_rid()]
	var hit := space.intersect_ray(ray_query)
	return hit.is_empty()

func can_collect(player: Node3D) -> bool:
	if _is_collected:
		return false
	if not is_instance_valid(player) or player.is_queued_for_deletion():
		return false
	if "is_alive" in player and not player.is_alive:
		return false
	if not _is_line_of_sight_clear(player.global_position):
		return false
	return true

func collect(player: Node3D = null) -> bool:
	if _is_collected:
		return false
	var target: Node3D = player if is_instance_valid(player) else _target_player
	if not is_instance_valid(target) and is_inside_tree():
		target = get_tree().get_first_node_in_group("player") as Node3D
	if not can_collect(target):
		return false
	_collect(target as PlayerHelicopter)
	return true

func _build_visuals() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "BurstCoreMesh"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_mesh.mesh = sphere
	_mesh.position = Vector3(0.0, 1.2, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.85, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.85, 1.0, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.roughness = 0.1
	_mesh.material_override = mat
	add_child(_mesh)

	_halo = OmniLight3D.new()
	_halo.name = "BurstHalo"
	_halo.light_color = Color(0.3, 0.85, 1.0, 1.0)
	_halo.light_energy = 3.0
	_halo.omni_range = 15.0
	_halo.position = Vector3(0.0, 1.5, 0.0)
	add_child(_halo)

func _physics_process(delta: float) -> void:
	_time += delta
	if not _is_collected:
		if _mesh:
			_mesh.position.y = 1.2 + sin(_time * 3.0) * 0.25
			_mesh.rotate_y(2.5 * delta)
		if _halo:
			_halo.light_energy = 2.5 + 1.0 * sin(_time * 4.0)

		# Distance check with active player
		var player := PlayerHelicopter.instance
		if not is_instance_valid(player) and is_inside_tree():
			player = get_tree().get_first_node_in_group("player") as PlayerHelicopter
		if is_instance_valid(player) and player.is_alive:
			var to_p := player.global_position - global_position
			var flat_d := Vector2(to_p.x, to_p.z).length()
			if (to_p.length() <= collection_radius or (flat_d <= collection_radius_xz and to_p.y >= -2.0 and to_p.y <= collection_height)) and _is_line_of_sight_clear(player.global_position):
				collect(player)
	else:
		_process_gem_batch()

func _on_area_entered(area: Area3D) -> void:
	if _is_collected:
		return
	var player := area.get_parent() as PlayerHelicopter
	if not player and area.owner is PlayerHelicopter:
		player = area.owner as PlayerHelicopter
	if player and _is_line_of_sight_clear(player.global_position):
		collect(player)

func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
	if body is PlayerHelicopter and _is_line_of_sight_clear(body.global_position):
		collect(body as PlayerHelicopter)

func _collect(player: PlayerHelicopter) -> void:
	if _is_collected:
		return
	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_target_player = player

	# Find all idle gems in the scene tree
	var tree := get_tree()
	if tree:
		var gem_nodes := tree.get_nodes_in_group("xp_gems")
		for node in gem_nodes:
			if is_instance_valid(node) and not node.is_queued_for_deletion() and node is XPGem:
				var gem: XPGem = node as XPGem
				if gem.current_state == XPGem.State.IDLE and gem.is_active:
					_pending_gems.append(gem)

	# Hide visuals
	if _mesh:
		_mesh.visible = false
	if _halo:
		_halo.light_energy = 0.0

func _process_gem_batch() -> void:
	if not is_instance_valid(_target_player) or not _target_player.is_alive:
		_pending_gems.clear()
		_target_player = null
		queue_free()
		return

	# Magnetize at most 15 gems per physics frame
	var batch_size: int = 15
	var count: int = 0
	while not _pending_gems.is_empty() and count < batch_size:
		var gem: XPGem = _pending_gems.pop_back()
		count += 1
		if is_instance_valid(gem) and not gem.is_queued_for_deletion():
			if gem.current_state == XPGem.State.IDLE:
				gem.magnetize_to(_target_player)

	if _pending_gems.is_empty():
		_target_player = null
		queue_free()
