class_name CityChunk
extends Node3D

## Represents a modular 128m x 128m streamed chunk in the procedural city world.
## Supports two rendering states:
## - FULL_DETAIL (LOD 0): Full building scenes with collision, detailed roads, MultiMesh props, gameplay spawn markers.
## - HLOD (LOD 1): Lightweight skyline silhouettes and flat roads for distant horizon without collision or scene overhead.

enum DetailLevel {
	UNLOADED,
	HLOD,
	FULL_DETAIL
}

enum DistrictType {
	HELIPAD,
	HIGH_RISE,
	MID_RISE,
	INDUSTRIAL,
	RESIDENTIAL
}

const CHUNK_SIZE: float = 128.0
const HALF_SIZE: float = 64.0

const BuildingSmallScene := preload("res://scenes/environment/city/building_small.tscn")
const BuildingSmallBScene := preload("res://scenes/environment/city/building_small_b.tscn")
const BuildingMediumScene := preload("res://scenes/environment/city/building_medium.tscn")
const BuildingMediumBScene := preload("res://scenes/environment/city/building_medium_b.tscn")
const BuildingLargeScene := preload("res://scenes/environment/city/building_large.tscn")
const BuildingLargeBScene := preload("res://scenes/environment/city/building_large_b.tscn")
const WarehouseScene := preload("res://scenes/environment/city/warehouse.tscn")
const WarehouseSawtoothScene := preload("res://scenes/environment/city/warehouse_sawtooth.tscn")
const ParkingLotScene := preload("res://scenes/environment/city/parking_lot.tscn")
const CivicPlazaScene := preload("res://scenes/environment/city/civic_plaza.tscn")

const ParkedVehicleScene := preload("res://scenes/environment/props/parked_vehicle.tscn")
const WreckedVehicleScene := preload("res://scenes/environment/props/wrecked_vehicle.tscn")
const TreeClusterScene := preload("res://scenes/environment/props/tree_cluster.tscn")
const CheckpointScene := preload("res://scenes/environment/military/checkpoint.tscn")
const RadioTowerScene := preload("res://scenes/environment/military/radio_tower.tscn")
const WaterTowerScene := preload("res://scenes/environment/town/water_tower.tscn")
const SolarArrayScene := preload("res://scenes/environment/town/solar_array.tscn")
const ContainerStackScene := preload("res://scenes/environment/industrial/container_stack.tscn")
const StorageTanksScene := preload("res://scenes/environment/industrial/storage_tanks.tscn")
const BarrierScene := preload("res://scenes/environment/props/barrier.tscn")

const AsphaltMat := preload("res://resources/environment/asphalt.tres")
const AsphaltWornMat := preload("res://resources/environment/asphalt_worn.tres")
const ConcreteMat := preload("res://resources/environment/concrete.tres")
const ConcreteSidewalkMat := preload("res://resources/environment/concrete_sidewalk.tres")
const ConcreteAgedMat := preload("res://resources/environment/concrete_aged.tres")
const LineMat := preload("res://resources/environment/line.tres")
const LineWhiteMat := preload("res://resources/environment/line_white.tres")
const GrassMat := preload("res://resources/environment/grass.tres")
const SandMat := preload("res://resources/environment/sand.tres")
const RoofMat := preload("res://resources/environment/roof.tres")
const RoofMetalMat := preload("res://resources/environment/roof_metal.tres")
const RustMat := preload("res://resources/environment/rust.tres")
const BrickMat := preload("res://resources/environment/brick.tres")

# Static shared meshes and materials for props (instantiated once project-wide)
static var _shared_props_initialized: bool = false
static var _tree_trunk_mesh: CylinderMesh = null
static var _tree_lower_crown_mesh: CylinderMesh = null
static var _tree_upper_crown_mesh: CylinderMesh = null
static var _barrier_mesh: BoxMesh = null
static var _helipad_pole_mesh: CylinderMesh = null
static var _helipad_lens_mesh: SphereMesh = null
static var _crate_mesh: BoxMesh = null
static var _fence_mesh: BoxMesh = null
static var _truck_chassis_mesh: BoxMesh = null
static var _truck_cab_mesh: BoxMesh = null

static func _init_shared_prop_resources() -> void:
	if _shared_props_initialized:
		return
	_shared_props_initialized = true

	var dirt_mat := StandardMaterial3D.new()
	dirt_mat.resource_name = "Dirt"
	dirt_mat.albedo_color = Color(0.5058824, 0.44705883, 0.34117648, 1.0)
	dirt_mat.roughness = 0.92

	_tree_trunk_mesh = CylinderMesh.new()
	_tree_trunk_mesh.material = dirt_mat
	_tree_trunk_mesh.top_radius = 0.35
	_tree_trunk_mesh.bottom_radius = 0.35
	_tree_trunk_mesh.height = 3.0
	_tree_trunk_mesh.radial_segments = 12
	_tree_trunk_mesh.rings = 1

	var tree_mat := StandardMaterial3D.new()
	tree_mat.resource_name = "Tree"
	tree_mat.albedo_color = Color(0.28627452, 0.3647059, 0.2627451, 1.0)
	tree_mat.roughness = 0.92

	_tree_lower_crown_mesh = CylinderMesh.new()
	_tree_lower_crown_mesh.material = tree_mat
	_tree_lower_crown_mesh.top_radius = 0.4
	_tree_lower_crown_mesh.bottom_radius = 2.9
	_tree_lower_crown_mesh.height = 4.0
	_tree_lower_crown_mesh.radial_segments = 12
	_tree_lower_crown_mesh.rings = 1

	var grass_mat := StandardMaterial3D.new()
	grass_mat.resource_name = "Grass"
	grass_mat.albedo_color = Color(0.38431373, 0.42745098, 0.29411766, 1.0)
	grass_mat.roughness = 0.92

	_tree_upper_crown_mesh = CylinderMesh.new()
	_tree_upper_crown_mesh.material = grass_mat
	_tree_upper_crown_mesh.top_radius = 0.05
	_tree_upper_crown_mesh.bottom_radius = 2.0
	_tree_upper_crown_mesh.height = 3.5
	_tree_upper_crown_mesh.radial_segments = 12
	_tree_upper_crown_mesh.rings = 1

	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.65, 0.65, 0.62, 1.0)
	bar_mat.roughness = 0.9

	_barrier_mesh = BoxMesh.new()
	_barrier_mesh.material = bar_mat
	_barrier_mesh.size = Vector3(3.0, 1.0, 0.8)

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.15, 0.17, 0.20, 1.0)
	pole_mat.roughness = 0.9

	_helipad_pole_mesh = CylinderMesh.new()
	_helipad_pole_mesh.top_radius = 0.12
	_helipad_pole_mesh.bottom_radius = 0.15
	_helipad_pole_mesh.height = 0.7
	_helipad_pole_mesh.material = pole_mat

	var light_mat := StandardMaterial3D.new()
	light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_mat.albedo_color = Color(0.31, 0.88, 0.93, 1.0)

	_helipad_lens_mesh = SphereMesh.new()
	_helipad_lens_mesh.radius = 0.22
	_helipad_lens_mesh.height = 0.44
	_helipad_lens_mesh.material = light_mat

	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.42, 0.36, 0.26, 1.0)
	crate_mat.roughness = 0.9

	_crate_mesh = BoxMesh.new()
	_crate_mesh.size = Vector3(1.3, 1.1, 1.3)
	_crate_mesh.material = crate_mat

	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = Color(0.20, 0.22, 0.25, 1.0)

	_fence_mesh = BoxMesh.new()
	_fence_mesh.size = Vector3(12.0, 0.9, 0.15)
	_fence_mesh.material = fence_mat

	var truck_mat := StandardMaterial3D.new()
	truck_mat.albedo_color = Color(0.24, 0.28, 0.32, 1.0)
	truck_mat.roughness = 0.8

	_truck_chassis_mesh = BoxMesh.new()
	_truck_chassis_mesh.size = Vector3(2.4, 1.1, 5.2)
	_truck_chassis_mesh.material = truck_mat

	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = Color(0.18, 0.35, 0.42, 1.0)
	cab_mat.roughness = 0.7

	_truck_cab_mesh = BoxMesh.new()
	_truck_cab_mesh.size = Vector3(2.2, 1.0, 1.8)
	_truck_cab_mesh.material = cab_mat

var coord: Vector2i = Vector2i.ZERO
var detail_level: DetailLevel = DetailLevel.UNLOADED
var district_type: DistrictType = DistrictType.RESIDENTIAL
var chunk_seed: int = 0

# Containers
var roads_root: Node3D = null
var buildings_root: Node3D = null
var props_root: Node3D = null
var hlod_root: Node3D = null
var markers_root: Node3D = null

# Cached typed gameplay positions in global world space
var ground_spawn_points: Array[Vector3] = []
var rooftop_spawn_points: Array[Vector3] = []
var air_entry_positions: Array[Vector3] = []
var objective_candidates: Array[Vector3] = []
var pickup_candidates: Array[Vector3] = []
var safe_open_positions: Array[Vector3] = []

# Road configuration
var ns_is_avenue: bool = false
var ew_is_avenue: bool = false

func _init() -> void:
	pass

func setup(p_coord: Vector2i, p_detail: DetailLevel, p_seed: int) -> void:
	coord = p_coord
	chunk_seed = p_seed
	position = Vector3(float(coord.x) * CHUNK_SIZE, 0.0, float(coord.y) * CHUNK_SIZE)
	name = "Chunk_%d_%d" % [coord.x, coord.y]

	_determine_district_and_roads()
	set_detail_level(p_detail)

func _determine_district_and_roads() -> void:
	# 1. Road types: Avenues on every 2nd grid line and on axis 0
	ns_is_avenue = (coord.x == 0 or absi(coord.x) % 2 == 0)
	ew_is_avenue = (coord.y == 0 or absi(coord.y) % 2 == 0)

	# 2. District determination based on distance from city center
	if coord == Vector2i.ZERO:
		district_type = DistrictType.HELIPAD
	else:
		var dist: float = coord.length()
		if dist <= 2.2:
			district_type = DistrictType.HIGH_RISE
		elif dist <= 4.5:
			district_type = DistrictType.MID_RISE
		elif dist <= 6.5:
			district_type = DistrictType.INDUSTRIAL
		else:
			district_type = DistrictType.RESIDENTIAL

func set_detail_level(new_level: DetailLevel) -> void:
	if detail_level == new_level and detail_level != DetailLevel.UNLOADED:
		return

	detail_level = new_level

	match detail_level:
		DetailLevel.UNLOADED:
			_clear_all()
			visible = false
		DetailLevel.HLOD:
			_clear_full_detail()
			_build_hlod()
			visible = true
		DetailLevel.FULL_DETAIL:
			_clear_hlod()
			_build_full_detail()
			visible = true

func _clear_all() -> void:
	_clear_full_detail()
	_clear_hlod()
	ground_spawn_points.clear()
	rooftop_spawn_points.clear()
	air_entry_positions.clear()
	objective_candidates.clear()
	pickup_candidates.clear()
	safe_open_positions.clear()

func _clear_hlod() -> void:
	if is_instance_valid(hlod_root):
		hlod_root.queue_free()
		hlod_root = null

func _clear_full_detail() -> void:
	if is_instance_valid(roads_root):
		roads_root.queue_free()
		roads_root = null
	if is_instance_valid(buildings_root):
		buildings_root.queue_free()
		buildings_root = null
	if is_instance_valid(props_root):
		props_root.queue_free()
		props_root = null
	if is_instance_valid(markers_root):
		markers_root.queue_free()
		markers_root = null

	ground_spawn_points.clear()
	rooftop_spawn_points.clear()
	air_entry_positions.clear()
	objective_candidates.clear()
	pickup_candidates.clear()
	safe_open_positions.clear()

# ==============================================================================
# HLOD BUILDER (Lightweight distant skyline)
# ==============================================================================
func _build_hlod() -> void:
	if is_instance_valid(hlod_root):
		return

	hlod_root = Node3D.new()
	hlod_root.name = "HLOD"
	add_child(hlod_root)

	# 1. Base ground plane (unshaded / lightweight)
	var base_mesh := MeshInstance3D.new()
	base_mesh.name = "BaseGround"
	var bm := BoxMesh.new()
	bm.size = Vector3(CHUNK_SIZE, 0.1, CHUNK_SIZE)
	bm.material = AsphaltMat
	base_mesh.mesh = bm
	base_mesh.position = Vector3(0.0, 0.05, 0.0)
	base_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hlod_root.add_child(base_mesh)

	# 2. Four quadrant skyline silhouettes with district-tuned palettes
	var quad_centers: Array[Vector3] = [
		Vector3(-36.0, 0.0, -36.0),
		Vector3(36.0, 0.0, -36.0),
		Vector3(-36.0, 0.0, 36.0),
		Vector3(36.0, 0.0, 36.0)
	]

	var b_size: Vector3
	var sil_mat: Material = ConcreteMat
	match district_type:
		DistrictType.HIGH_RISE:
			b_size = Vector3(25.0, 62.0, 22.0)
			sil_mat = RoofMetalMat
		DistrictType.MID_RISE:
			b_size = Vector3(24.0, 28.0, 20.0)
			sil_mat = ConcreteSidewalkMat
		DistrictType.INDUSTRIAL:
			b_size = Vector3(28.0, 12.0, 22.0)
			sil_mat = RustMat
		DistrictType.HELIPAD:
			b_size = Vector3(18.0, 8.0, 18.0)
			sil_mat = ConcreteMat
		DistrictType.RESIDENTIAL, _:
			b_size = Vector3(18.0, 13.0, 16.0)
			sil_mat = ConcreteAgedMat

	var rng := _get_chunk_rng()

	for i in range(4):
		var center := quad_centers[i]
		var sil_mesh := MeshInstance3D.new()
		sil_mesh.name = "Silhouette_%d" % i
		var box := BoxMesh.new()
		var height_jitter: float = rng.randf_range(0.85, 1.15)
		var cur_h: float = b_size.y * height_jitter
		box.size = Vector3(b_size.x, cur_h, b_size.z)
		box.material = sil_mat
		sil_mesh.mesh = box
		sil_mesh.position = center + Vector3(0.0, cur_h * 0.5, 0.0)
		sil_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hlod_root.add_child(sil_mesh)

# ==============================================================================
# FULL DETAIL BUILDER
# ==============================================================================
func _build_full_detail() -> void:
	var rng := _get_chunk_rng()

	_build_roads()
	_build_buildings(rng)
	_build_props(rng)
	_populate_gameplay_candidates()

func _get_chunk_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var h: int = chunk_seed
	h = ((h ^ (coord.x * 73856093)) ^ (coord.y * 19349663)) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	rng.seed = h
	return rng

func _build_roads() -> void:
	roads_root = Node3D.new()
	roads_root.name = "Roads"
	add_child(roads_root)

	var ns_asphalt_w: float = 16.0 if ns_is_avenue else 9.0
	var ns_shoulder_w: float = 20.0 if ns_is_avenue else 13.0
	var ew_asphalt_w: float = 16.0 if ew_is_avenue else 9.0
	var ew_shoulder_w: float = 20.0 if ew_is_avenue else 13.0

	var boxes_by_mat: Dictionary = {}
	var add_box := func(mat: Material, size: Vector3, pos: Vector3) -> void:
		if not boxes_by_mat.has(mat):
			boxes_by_mat[mat] = []
		boxes_by_mat[mat].append([size, pos])

	# 1. Parcel underlay
	add_box.call(ConcreteAgedMat, Vector3(CHUNK_SIZE, 0.1, CHUNK_SIZE), Vector3(0.0, 0.05, 0.0))

	# 2. Road geometry: NS Road
	add_box.call(ConcreteSidewalkMat, Vector3(ns_shoulder_w, 0.12, CHUNK_SIZE), Vector3(0.0, 0.07, 0.0))
	add_box.call(AsphaltMat, Vector3(ns_asphalt_w, 0.14, CHUNK_SIZE), Vector3(0.0, 0.08, 0.0))

	# 3. Road geometry: EW Road
	add_box.call(ConcreteSidewalkMat, Vector3(CHUNK_SIZE, 0.12, ew_shoulder_w), Vector3(0.0, 0.075, 0.0))
	add_box.call(AsphaltMat, Vector3(CHUNK_SIZE, 0.145, ew_asphalt_w), Vector3(0.0, 0.085, 0.0))

	# 4. Center intersection marking / patch
	add_box.call(AsphaltMat, Vector3(ns_asphalt_w + 1.0, 0.15, ew_asphalt_w + 1.0), Vector3(0.0, 0.09, 0.0))

	# 5. Thin geometry overlays: crosswalks, stop lines, yellow centerlines
	var line_y: float = 0.153
	var stop_mat := LineWhiteMat
	var dash_mat := LineMat
	var wear_mat := AsphaltWornMat

	# North intersection approach: stop line and crosswalk
	add_box.call(stop_mat, Vector3(ns_asphalt_w * 0.9, 0.015, 0.45), Vector3(0.0, line_y, -ew_asphalt_w * 0.5 - 1.2))
	for stripe_x in [-ns_asphalt_w * 0.35, -ns_asphalt_w * 0.18, ns_asphalt_w * 0.18, ns_asphalt_w * 0.35]:
		add_box.call(stop_mat, Vector3(0.55, 0.015, 2.4), Vector3(stripe_x, line_y, -ew_asphalt_w * 0.5 - 3.2))

	# South intersection approach: stop line and crosswalk
	add_box.call(stop_mat, Vector3(ns_asphalt_w * 0.9, 0.015, 0.45), Vector3(0.0, line_y, ew_asphalt_w * 0.5 + 1.2))
	for stripe_x in [-ns_asphalt_w * 0.35, -ns_asphalt_w * 0.18, ns_asphalt_w * 0.18, ns_asphalt_w * 0.35]:
		add_box.call(stop_mat, Vector3(0.55, 0.015, 2.4), Vector3(stripe_x, line_y, ew_asphalt_w * 0.5 + 3.2))

	# East intersection approach: stop line and crosswalk
	add_box.call(stop_mat, Vector3(0.45, 0.015, ew_asphalt_w * 0.9), Vector3(ns_asphalt_w * 0.5 + 1.2, line_y, 0.0))
	for stripe_z in [-ew_asphalt_w * 0.35, -ew_asphalt_w * 0.18, ew_asphalt_w * 0.18, ew_asphalt_w * 0.35]:
		add_box.call(stop_mat, Vector3(2.4, 0.015, 0.55), Vector3(ns_asphalt_w * 0.5 + 3.2, line_y, stripe_z))

	# West intersection approach: stop line and crosswalk
	add_box.call(stop_mat, Vector3(0.45, 0.015, ew_asphalt_w * 0.9), Vector3(-ns_asphalt_w * 0.5 - 1.2, line_y, 0.0))
	for stripe_z in [-ew_asphalt_w * 0.35, -ew_asphalt_w * 0.18, ew_asphalt_w * 0.18, ew_asphalt_w * 0.35]:
		add_box.call(stop_mat, Vector3(2.4, 0.015, 0.55), Vector3(-ns_asphalt_w * 0.5 - 3.2, line_y, stripe_z))

	# Dashed yellow centerlines (NS road)
	var z_cur: float = -ew_asphalt_w * 0.5 - 6.5
	while z_cur > -62.0:
		add_box.call(dash_mat, Vector3(0.24, 0.015, 2.6), Vector3(0.0, line_y, z_cur))
		z_cur -= 5.2

	z_cur = ew_asphalt_w * 0.5 + 6.5
	while z_cur < 62.0:
		add_box.call(dash_mat, Vector3(0.24, 0.015, 2.6), Vector3(0.0, line_y, z_cur))
		z_cur += 5.2

	# Dashed yellow centerlines (EW road)
	var x_cur: float = ns_asphalt_w * 0.5 + 6.5
	while x_cur < 62.0:
		add_box.call(dash_mat, Vector3(2.6, 0.015, 0.24), Vector3(x_cur, line_y, 0.0))
		x_cur += 5.2

	x_cur = -ns_asphalt_w * 0.5 - 6.5
	while x_cur > -62.0:
		add_box.call(dash_mat, Vector3(2.6, 0.015, 0.24), Vector3(x_cur, line_y, 0.0))
		x_cur -= 5.2

	# Asphalt wear / utility patches
	add_box.call(wear_mat, Vector3(2.6, 0.01, 3.8), Vector3(-ns_asphalt_w * 0.25, line_y - 0.002, -26.0))
	add_box.call(wear_mat, Vector3(3.6, 0.01, 2.2), Vector3(24.0, line_y - 0.002, ew_asphalt_w * 0.25))

	# Lane direction arrows (North and South intersection approaches)
	add_box.call(stop_mat, Vector3(0.35, 0.015, 2.2), Vector3(-ns_asphalt_w * 0.25, line_y, -ew_asphalt_w * 0.5 - 10.0))
	add_box.call(stop_mat, Vector3(0.35, 0.015, 2.2), Vector3(ns_asphalt_w * 0.25, line_y, ew_asphalt_w * 0.5 + 10.0))

	# Yellow corner curb markings (hazard curb paint near intersection)
	var curb_corners: Array[Vector3] = [
		Vector3(-ns_asphalt_w * 0.5 - 0.35, line_y - 0.005, -ew_asphalt_w * 0.5 - 3.0),
		Vector3(ns_asphalt_w * 0.5 + 0.35, line_y - 0.005, -ew_asphalt_w * 0.5 - 3.0),
		Vector3(-ns_asphalt_w * 0.5 - 0.35, line_y - 0.005, ew_asphalt_w * 0.5 + 3.0),
		Vector3(ns_asphalt_w * 0.5 + 0.35, line_y - 0.005, ew_asphalt_w * 0.5 + 3.0)
	]
	for c_pos in curb_corners:
		add_box.call(dash_mat, Vector3(0.35, 0.015, 4.0), c_pos)

	# Helipad flat surfaces if chunk (0,0)
	if coord == Vector2i.ZERO:
		add_box.call(AsphaltMat, Vector3(24.0, 0.14, 24.0), Vector3(0.0, 0.07, 0.0))
		add_box.call(LineMat, Vector3(23.6, 0.15, 23.6), Vector3(0.0, 0.075, 0.0))
		add_box.call(ConcreteMat, Vector3(22.0, 0.16, 22.0), Vector3(0.0, 0.08, 0.0))
		add_box.call(LineMat, Vector3(0.9, 0.02, 7.5), Vector3(-2.5, 0.17, 0.0))
		add_box.call(LineMat, Vector3(0.9, 0.02, 7.5), Vector3(2.5, 0.17, 0.0))
		add_box.call(LineMat, Vector3(4.5, 0.02, 0.9), Vector3(0.0, 0.17, 0.0))

	# Commit merged static mesh with 1 surface per material
	var merged_mesh := ArrayMesh.new()
	for mat: Material in boxes_by_mat:
		var items: Array = boxes_by_mat[mat]
		if items.is_empty():
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		for box_data in items:
			var b_size: Vector3 = box_data[0]
			var b_pos: Vector3 = box_data[1]
			var bm := BoxMesh.new()
			bm.size = b_size
			st.append_from(bm, 0, Transform3D(Basis(), b_pos))
		st.commit(merged_mesh)
		var surf_idx: int = merged_mesh.get_surface_count() - 1
		merged_mesh.surface_set_material(surf_idx, mat)

	var roads_mesh_inst := MeshInstance3D.new()
	roads_mesh_inst.name = "MergedRoadGeometry"
	roads_mesh_inst.mesh = merged_mesh
	roads_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roads_root.add_child(roads_mesh_inst)

	# Helipad 3D staging props for chunk (0, 0)
	if coord == Vector2i.ZERO:
		_build_helipad_staging(roads_root)

func _build_helipad_staging(parent: Node3D) -> void:
	var staging := Node3D.new()
	staging.name = "HelipadStaging"
	parent.add_child(staging)

	_init_shared_prop_resources()

	# 1. Perimeter Boundary Lights (4 corners) with MultiMesh
	var mm_poles := MultiMeshInstance3D.new()
	mm_poles.name = "PerimeterPolesMultiMesh"
	var p_mm := MultiMesh.new()
	p_mm.transform_format = MultiMesh.TRANSFORM_3D
	p_mm.instance_count = 4
	p_mm.mesh = _helipad_pole_mesh

	var mm_lenses := MultiMeshInstance3D.new()
	mm_lenses.name = "PerimeterLensesMultiMesh"
	var l_mm := MultiMesh.new()
	l_mm.transform_format = MultiMesh.TRANSFORM_3D
	l_mm.instance_count = 4
	l_mm.mesh = _helipad_lens_mesh

	var light_corners: Array[Vector3] = [
		Vector3(-11.0, 0.0, -11.0),
		Vector3(11.0, 0.0, -11.0),
		Vector3(-11.0, 0.0, 11.0),
		Vector3(11.0, 0.0, 11.0)
	]

	for idx in range(4):
		var p_pos: Vector3 = light_corners[idx] + Vector3(0.0, 0.35, 0.0)
		var l_pos: Vector3 = light_corners[idx] + Vector3(0.0, 0.75, 0.0)
		p_mm.set_instance_transform(idx, Transform3D(Basis(), p_pos))
		l_mm.set_instance_transform(idx, Transform3D(Basis(), l_pos))

	mm_poles.multimesh = p_mm
	mm_poles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	staging.add_child(mm_poles)

	mm_lenses.multimesh = l_mm
	mm_lenses.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	staging.add_child(mm_lenses)

	# 2. Support Staging Props (Off to the sides, clear takeoff path)
	var truck := Node3D.new()
	truck.name = "SupportTruck"
	truck.position = Vector3(14.5, 0.0, 8.5)
	truck.rotation.y = deg_to_rad(-25.0)

	var chassis := MeshInstance3D.new()
	chassis.mesh = _truck_chassis_mesh
	chassis.position = Vector3(0.0, 0.8, 0.0)
	chassis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	truck.add_child(chassis)

	var cab := MeshInstance3D.new()
	cab.mesh = _truck_cab_mesh
	cab.position = Vector3(0.0, 1.6, -1.2)
	cab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	truck.add_child(cab)
	staging.add_child(truck)

	# 3. Supply Crates Stack with MultiMesh
	var mm_crates := MultiMeshInstance3D.new()
	mm_crates.name = "SupplyCratesMultiMesh"
	var c_mm := MultiMesh.new()
	c_mm.transform_format = MultiMesh.TRANSFORM_3D
	c_mm.instance_count = 4
	c_mm.mesh = _crate_mesh

	var crate_positions: Array[Vector3] = [
		Vector3(-14.2, 0.55, 8.5),
		Vector3(-14.2, 0.55, 10.0),
		Vector3(-12.8, 0.55, 9.2),
		Vector3(-13.5, 1.65, 9.2)
	]
	for c_idx in range(4):
		c_mm.set_instance_transform(c_idx, Transform3D(Basis(), crate_positions[c_idx]))
	mm_crates.multimesh = c_mm
	mm_crates.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	staging.add_child(mm_crates)

	# 4. Security Fences with MultiMesh
	var mm_fences := MultiMeshInstance3D.new()
	mm_fences.name = "SecurityFencesMultiMesh"
	var f_mm := MultiMesh.new()
	f_mm.transform_format = MultiMesh.TRANSFORM_3D
	f_mm.instance_count = 2
	f_mm.mesh = _fence_mesh
	f_mm.set_instance_transform(0, Transform3D(Basis(), Vector3(13.5, 0.45, 13.0)))
	f_mm.set_instance_transform(1, Transform3D(Basis(), Vector3(-13.5, 0.45, 13.0)))
	mm_fences.multimesh = f_mm
	mm_fences.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	staging.add_child(mm_fences)

func _build_buildings(rng: RandomNumberGenerator) -> void:
	buildings_root = Node3D.new()
	buildings_root.name = "Buildings"
	add_child(buildings_root)

	var quad_offsets: Array[Vector3] = [
		Vector3(-36.0, 0.0, -36.0),
		Vector3(36.0, 0.0, -36.0),
		Vector3(-36.0, 0.0, 36.0),
		Vector3(36.0, 0.0, 36.0)
	]

	for i in range(4):
		var pos_offset := quad_offsets[i]
		# Deterministic parcel setback within safe road bounds [-40, -32] and [32, 40]
		var setback_x: float = rng.randf_range(-1.8, 1.8)
		var setback_z: float = rng.randf_range(-1.8, 1.8)
		pos_offset += Vector3(setback_x, 0.0, setback_z)

		var scene_to_instance: PackedScene = null

		match district_type:
			DistrictType.HELIPAD:
				# Helipad chunk: low-profile structures, open tarmac
				if i == 0:
					scene_to_instance = ParkingLotScene
				elif i == 1:
					scene_to_instance = BuildingSmallScene
				elif i == 2:
					scene_to_instance = CivicPlazaScene
				else:
					scene_to_instance = BuildingSmallBScene
			DistrictType.HIGH_RISE:
				# Landmark tall compositions downtown
				if (absi(coord.x) == 1 and absi(coord.y) == 1 and i == 0):
					scene_to_instance = BuildingLargeScene
				elif (coord.x == 2 and coord.y == 0 and i == 0):
					scene_to_instance = RadioTowerScene
				else:
					var pick: int = rng.randi_range(0, 3)
					if pick == 0:
						scene_to_instance = BuildingLargeScene
					elif pick == 1:
						scene_to_instance = BuildingLargeBScene
					elif pick == 2:
						scene_to_instance = BuildingMediumScene
					else:
						scene_to_instance = BuildingMediumBScene
			DistrictType.MID_RISE:
				if (absi(coord.x) == 3 and absi(coord.y) == 1 and i == 0):
					scene_to_instance = CivicPlazaScene
				else:
					var pick_m: int = rng.randi_range(0, 4)
					if pick_m == 0:
						scene_to_instance = BuildingMediumScene
					elif pick_m == 1:
						scene_to_instance = BuildingMediumBScene
					elif pick_m == 2:
						scene_to_instance = BuildingSmallScene
					elif pick_m == 3:
						scene_to_instance = BuildingSmallBScene
					else:
						scene_to_instance = ParkingLotScene
			DistrictType.INDUSTRIAL:
				# Industrial Landmark: Water Tower Depot or Storage Complex
				if (absi(coord.x) == 4 or absi(coord.y) == 4) and i == 0:
					scene_to_instance = WaterTowerScene
				elif (absi(coord.x) == 5 and i == 0):
					scene_to_instance = StorageTanksScene
				else:
					var pick_i: int = rng.randi_range(0, 4)
					if pick_i == 0:
						scene_to_instance = WarehouseScene
					elif pick_i == 1:
						scene_to_instance = WarehouseSawtoothScene
					elif pick_i == 2:
						scene_to_instance = ContainerStackScene
					elif pick_i == 3:
						scene_to_instance = StorageTanksScene
					else:
						scene_to_instance = ParkingLotScene
			DistrictType.RESIDENTIAL, _:
				# Outskirts Landmark: Solar Array farm
				if (absi(coord.x) == 6 and absi(coord.y) == 6 and i == 0):
					scene_to_instance = SolarArrayScene
				else:
					var pick_r: int = rng.randi_range(0, 3)
					if pick_r == 0:
						scene_to_instance = BuildingSmallScene
					elif pick_r == 1:
						scene_to_instance = BuildingSmallBScene
					elif pick_r == 2:
						scene_to_instance = CivicPlazaScene
					else:
						scene_to_instance = ParkingLotScene

		if scene_to_instance:
			var b_inst := scene_to_instance.instantiate() as Node3D
			if b_inst:
				b_inst.name = "Building_Q%d" % i
				b_inst.position = pos_offset
				var rot_step: int = rng.randi_range(0, 3)
				b_inst.rotation.y = float(rot_step) * (PI * 0.5)
				buildings_root.add_child(b_inst)

func _build_props(rng: RandomNumberGenerator) -> void:
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)

	# 1. Streetlights along sidewalks
	_build_streetlight_multimesh()

	# 2. Authentic Parked and Wrecked Vehicles along curbs
	_build_vehicles(rng)

	# 3. Authentic Tree Clusters along sidewalks
	_build_tree_clusters(rng)

	# 4. Deterministic Roadside Micro-scenes
	_build_micro_scenes(rng)

func _build_streetlight_multimesh() -> void:
	var mm_inst := MultiMeshInstance3D.new()
	mm_inst.name = "StreetlightsMultiMesh"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 8

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.16
	pole_mesh.height = 7.0
	pole_mesh.material = ConcreteAgedMat
	mm.mesh = pole_mesh

	var offsets: Array[Vector3] = [
		Vector3(-10.0, 3.5, -45.0),
		Vector3(-10.0, 3.5, -20.0),
		Vector3(-10.0, 3.5, 20.0),
		Vector3(-10.0, 3.5, 45.0),
		Vector3(10.0, 3.5, -45.0),
		Vector3(10.0, 3.5, -20.0),
		Vector3(10.0, 3.5, 20.0),
		Vector3(10.0, 3.5, 45.0)
	]

	for idx in range(8):
		var t := Transform3D(Basis(), offsets[idx])
		mm.set_instance_transform(idx, t)

	mm_inst.multimesh = mm
	mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_root.add_child(mm_inst)

func _build_vehicles(rng: RandomNumberGenerator) -> void:
	var car_positions: Array[Vector3] = [
		Vector3(-12.5, 0.0, -30.0),
		Vector3(-12.5, 0.0, -21.0),
		Vector3(-12.5, 0.0, 21.0),
		Vector3(12.5, 0.0, -29.0),
		Vector3(12.5, 0.0, 23.0),
		Vector3(12.5, 0.0, 31.0)
	]

	for idx in range(car_positions.size()):
		var base_pos: Vector3 = car_positions[idx]
		var jitter_z: float = rng.randf_range(-1.2, 1.2)
		var spawn_pos: Vector3 = base_pos + Vector3(0.0, 0.0, jitter_z)
		var rot_y: float = (PI if base_pos.x < 0.0 else 0.0) + rng.randf_range(-0.06, 0.06)

		var is_wreck: bool = (district_type == DistrictType.INDUSTRIAL or district_type == DistrictType.RESIDENTIAL) and (idx == 1 or idx == 4) and (rng.randf() < 0.35)
		var v_node: Node3D = null
		if is_wreck:
			v_node = WreckedVehicleScene.instantiate() as Node3D
		else:
			v_node = ParkedVehicleScene.instantiate() as Node3D

		if v_node:
			v_node.name = "Vehicle_%d" % idx
			v_node.position = spawn_pos
			v_node.rotation.y = rot_y
			# Distance-based shadow LOD at creation time: only central chunks cast vehicle shadows
			if coord.length() > 1.0:
				for vc in v_node.find_children("*", "GeometryInstance3D", true, false):
					var v_gi := vc as GeometryInstance3D
					if v_gi:
						v_gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			props_root.add_child(v_node)

func _build_tree_clusters(rng: RandomNumberGenerator) -> void:
	_init_shared_prop_resources()

	var tree_positions: Array[Vector3] = [
		Vector3(-15.0, 0.0, -48.0),
		Vector3(-15.0, 0.0, 48.0),
		Vector3(15.0, 0.0, -48.0),
		Vector3(15.0, 0.0, 48.0),
		Vector3(-48.0, 0.0, -15.0),
		Vector3(48.0, 0.0, -15.0),
		Vector3(-48.0, 0.0, 15.0),
		Vector3(48.0, 0.0, 15.0)
	]
	var count: int = tree_positions.size()

	var mm_trunks := MultiMeshInstance3D.new()
	mm_trunks.name = "TreeTrunksMultiMesh"
	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.instance_count = count
	trunk_mm.mesh = _tree_trunk_mesh

	var mm_lower := MultiMeshInstance3D.new()
	mm_lower.name = "TreeLowerCrownsMultiMesh"
	var lower_mm := MultiMesh.new()
	lower_mm.transform_format = MultiMesh.TRANSFORM_3D
	lower_mm.instance_count = count
	lower_mm.mesh = _tree_lower_crown_mesh

	var mm_upper := MultiMeshInstance3D.new()
	mm_upper.name = "TreeUpperCrownsMultiMesh"
	var upper_mm := MultiMesh.new()
	upper_mm.transform_format = MultiMesh.TRANSFORM_3D
	upper_mm.instance_count = count
	upper_mm.mesh = _tree_upper_crown_mesh

	var shadow_crowns: GeometryInstance3D.ShadowCastingSetting = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if coord.length() > 1.5 
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)

	for idx in range(count):
		var scale_val: float = rng.randf_range(0.85, 1.22)
		var rot_y: float = rng.randf_range(0.0, TAU)
		var b := Basis().rotated(Vector3.UP, rot_y).scaled(Vector3(scale_val, scale_val, scale_val))
		var pos: Vector3 = tree_positions[idx]

		trunk_mm.set_instance_transform(idx, Transform3D(b, pos + Vector3(0.0, 1.5 * scale_val, 0.0)))
		lower_mm.set_instance_transform(idx, Transform3D(b, pos + Vector3(0.0, 4.0 * scale_val, 0.0)))
		upper_mm.set_instance_transform(idx, Transform3D(b, pos + Vector3(0.0, 6.0 * scale_val, 0.0)))

	mm_trunks.multimesh = trunk_mm
	mm_trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_root.add_child(mm_trunks)

	mm_lower.multimesh = lower_mm
	mm_lower.cast_shadow = shadow_crowns
	props_root.add_child(mm_lower)

	mm_upper.multimesh = upper_mm
	mm_upper.cast_shadow = shadow_crowns
	props_root.add_child(mm_upper)

func _build_micro_scenes(rng: RandomNumberGenerator) -> void:
	_init_shared_prop_resources()
	var barrier_transforms: Array[Transform3D] = []

	if district_type == DistrictType.INDUSTRIAL:
		if rng.randf() < 0.6:
			var b1 := Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(12.0)), Vector3(13.2, 0.5, 24.0))
			barrier_transforms.append(b1)
			var b2 := Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(-8.0)), Vector3(13.2, 0.5, 28.0))
			barrier_transforms.append(b2)
	elif district_type == DistrictType.RESIDENTIAL:
		if rng.randf() < 0.4:
			var b1 := Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(5.0)), Vector3(-13.2, 0.5, -22.0))
			barrier_transforms.append(b1)

	if not barrier_transforms.is_empty():
		var mm_barriers := MultiMeshInstance3D.new()
		mm_barriers.name = "RoadsideBarriersMultiMesh"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = barrier_transforms.size()
		mm.mesh = _barrier_mesh
		for b_idx in range(barrier_transforms.size()):
			mm.set_instance_transform(b_idx, barrier_transforms[b_idx])
		mm_barriers.multimesh = mm
		mm_barriers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		props_root.add_child(mm_barriers)

# ==============================================================================
# CANDIDATE POSITION EXTRACTION (Global World Coordinates)
# ==============================================================================
func _populate_gameplay_candidates() -> void:
	ground_spawn_points.clear()
	rooftop_spawn_points.clear()
	air_entry_positions.clear()
	objective_candidates.clear()
	pickup_candidates.clear()
	safe_open_positions.clear()

	var origin := global_position

	# 1. Ground spawn points: center intersection, 4 road sockets, alley entries
	ground_spawn_points.append(origin + Vector3(0.0, 0.3, 0.0))
	ground_spawn_points.append(origin + Vector3(0.0, 0.3, -56.0))
	ground_spawn_points.append(origin + Vector3(0.0, 0.3, 56.0))
	ground_spawn_points.append(origin + Vector3(-56.0, 0.3, 0.0))
	ground_spawn_points.append(origin + Vector3(56.0, 0.3, 0.0))
	ground_spawn_points.append(origin + Vector3(-20.0, 0.3, -20.0))
	ground_spawn_points.append(origin + Vector3(20.0, 0.3, -20.0))
	ground_spawn_points.append(origin + Vector3(-20.0, 0.3, 20.0))
	ground_spawn_points.append(origin + Vector3(20.0, 0.3, 20.0))

	# 2. Air entry positions: elevated approaches
	air_entry_positions.append(origin + Vector3(-58.0, 38.0, -58.0))
	air_entry_positions.append(origin + Vector3(58.0, 38.0, -58.0))
	air_entry_positions.append(origin + Vector3(-58.0, 38.0, 58.0))
	air_entry_positions.append(origin + Vector3(58.0, 38.0, 58.0))
	air_entry_positions.append(origin + Vector3(0.0, 45.0, -60.0))
	air_entry_positions.append(origin + Vector3(0.0, 45.0, 60.0))

	# 3. Rooftop spawn points: traverse instantiated buildings for exact roof markers
	if is_instance_valid(buildings_root):
		for b_child in buildings_root.get_children():
			if b_child is Node3D:
				var m_roof: Marker3D = b_child.get_node_or_null("RooftopDefensePoint") as Marker3D
				if not m_roof:
					m_roof = b_child.get_node_or_null("RooftopSpawnPoint") as Marker3D
				if m_roof:
					rooftop_spawn_points.append(m_roof.global_position)
				else:
					# Fallback: estimate from district height
					var est_y: float = 14.0
					match district_type:
						DistrictType.HIGH_RISE: est_y = 64.0
						DistrictType.MID_RISE: est_y = 28.0
						DistrictType.INDUSTRIAL: est_y = 12.0
						DistrictType.RESIDENTIAL, _: est_y = 14.0
					rooftop_spawn_points.append(b_child.global_position + Vector3(0.0, est_y, 0.0))

	# 4. Objective candidates: key building centers or roofs
	if not rooftop_spawn_points.is_empty():
		objective_candidates.append(rooftop_spawn_points[0])
	objective_candidates.append(origin + Vector3(36.0, 0.3, 36.0))
	objective_candidates.append(origin + Vector3(-36.0, 0.3, -36.0))

	# 5. Pickup candidates: alleys and parking bays
	pickup_candidates.append(origin + Vector3(-24.0, 0.5, -12.0))
	pickup_candidates.append(origin + Vector3(24.0, 0.5, 12.0))
	pickup_candidates.append(origin + Vector3(-12.0, 0.5, 24.0))
	pickup_candidates.append(origin + Vector3(12.0, 0.5, -24.0))

	# 6. Safe open positions: center intersection and helipad
	safe_open_positions.append(origin + Vector3(0.0, 0.3, 0.0))
	if coord == Vector2i.ZERO:
		safe_open_positions.append(origin + Vector3(0.0, 0.3, 0.0))
