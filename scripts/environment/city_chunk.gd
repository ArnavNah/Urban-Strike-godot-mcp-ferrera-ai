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
const BuildingSmallCScene := preload("res://scenes/environment/city/building_small_c.tscn")
const BuildingMediumScene := preload("res://scenes/environment/city/building_medium.tscn")
const BuildingMediumBScene := preload("res://scenes/environment/city/building_medium_b.tscn")
const BuildingMediumCScene := preload("res://scenes/environment/city/building_medium_c.tscn")
const BuildingLargeScene := preload("res://scenes/environment/city/building_large.tscn")
const BuildingLargeBScene := preload("res://scenes/environment/city/building_large_b.tscn")
const BuildingSkyscraperCScene := preload("res://scenes/environment/city/building_skyscraper_c.tscn")
const WarehouseScene := preload("res://scenes/environment/city/warehouse.tscn")
const WarehouseSawtoothScene := preload("res://scenes/environment/city/warehouse_sawtooth.tscn")
const ParkingLotScene := preload("res://scenes/environment/city/parking_lot.tscn")
const CivicPlazaScene := preload("res://scenes/environment/city/civic_plaza.tscn")

const TownHouseAScene := preload("res://scenes/environment/town/town_house_a.tscn")
const TownCabinScene := preload("res://scenes/environment/town/town_cabin.tscn")
const TownWorkshopScene := preload("res://scenes/environment/town/town_workshop.tscn")

const ParkedVehicleScene := preload("res://scenes/environment/props/parked_vehicle.tscn")
const WreckedVehicleScene := preload("res://scenes/environment/props/wrecked_vehicle.tscn")
const TreeClusterScene := preload("res://scenes/environment/props/tree_cluster.tscn")
const CheckpointScene := preload("res://scenes/environment/military/checkpoint.tscn")
const RadioTowerScene := preload("res://scenes/environment/military/radio_tower.tscn")
const WaterTowerScene := preload("res://scenes/environment/town/water_tower.tscn")
const SolarArrayScene := preload("res://scenes/environment/town/solar_array.tscn")
const ContainerStackScene := preload("res://scenes/environment/industrial/container_stack.tscn")
const StorageTanksScene := preload("res://scenes/environment/industrial/storage_tanks.tscn")
const ChimneyLargeScene := preload("res://scenes/environment/industrial/chimney_large.tscn")
const ChimneySmallScene := preload("res://scenes/environment/industrial/chimney_small.tscn")
const SolarPanelPortraitScene := preload("res://scenes/environment/industrial/solar_panel_portrait.tscn")
const BarrierScene := preload("res://scenes/environment/props/barrier.tscn")
const SupplyBeaconScript := preload("res://scripts/encounters/supply_beacon.gd")
const GuardedCacheScript := preload("res://scripts/encounters/guarded_cache.gd")
const RewardLocationScript := preload("res://scripts/encounters/reward_location.gd")
const XPBurstPickupScript := preload("res://scripts/pickups/xp_burst_pickup.gd")

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

# Static road mesh cache (keys: bitmask of ns_is_avenue, ew_is_avenue, is_helipad)
static var _cached_road_meshes: Dictionary = {}
static var _cached_building_catalog: Dictionary = {}

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
static var _kenney_tree_small_mesh: Mesh = null
static var _kenney_tree_large_mesh: Mesh = null
static var _kenney_planter_mesh: Mesh = null

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

	# Cache Kenney suburban tree and planter meshes
	var small_scene := load("res://assets/environment/vegetation/tree_small.glb") as PackedScene
	if small_scene:
		var temp_node := small_scene.instantiate() as Node3D
		if temp_node:
			var mi := temp_node.find_child("tree-small", true, false) as MeshInstance3D
			if mi and mi.mesh:
				_kenney_tree_small_mesh = mi.mesh
			temp_node.free()

	var large_scene := load("res://assets/environment/vegetation/tree_large.glb") as PackedScene
	if large_scene:
		var temp_node := large_scene.instantiate() as Node3D
		if temp_node:
			var mi := temp_node.find_child("tree-large", true, false) as MeshInstance3D
			if mi and mi.mesh:
				_kenney_tree_large_mesh = mi.mesh
			temp_node.free()

	var planter_scene := load("res://assets/environment/street_props/planter.glb") as PackedScene
	if planter_scene:
		var temp_node := planter_scene.instantiate() as Node3D
		if temp_node:
			var mi := temp_node.find_child("planter", true, false) as MeshInstance3D
			if mi and mi.mesh:
				_kenney_planter_mesh = mi.mesh
			temp_node.free()

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
var encounters_root: Node3D = null

# Cached typed gameplay positions in global world space
var ground_spawn_points: Array[Vector3] = []
var rooftop_spawn_points: Array[Vector3] = []
var air_entry_positions: Array[Vector3] = []
var objective_candidates: Array[Vector3] = []
var pickup_candidates: Array[Vector3] = []
var safe_open_positions: Array[Vector3] = []

# Rich building and rooftop socket metadata for gameplay queries
var rooftop_sockets: Array[Dictionary] = []
var building_records: Array[Dictionary] = []
var _assembly_token: int = 0
var is_fully_assembled: bool = false

# Road configuration
var ns_is_avenue: bool = false
var ew_is_avenue: bool = false

func _init() -> void:
	add_to_group("city_chunks")

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

	_assembly_token += 1
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
			var immediate: bool = (coord == Vector2i.ZERO)
			_build_full_detail(immediate)
			visible = true

func _clear_all() -> void:
	_assembly_token += 1
	is_fully_assembled = false
	_clear_full_detail()
	_clear_hlod()
	ground_spawn_points.clear()
	rooftop_spawn_points.clear()
	air_entry_positions.clear()
	objective_candidates.clear()
	pickup_candidates.clear()
	safe_open_positions.clear()
	rooftop_sockets.clear()
	building_records.clear()

func _clear_hlod() -> void:
	if is_instance_valid(hlod_root):
		hlod_root.queue_free()
		hlod_root = null

func _clear_full_detail() -> void:
	_assembly_token += 1
	is_fully_assembled = false
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
	if is_instance_valid(encounters_root):
		encounters_root.queue_free()
		encounters_root = null

	ground_spawn_points.clear()
	rooftop_spawn_points.clear()
	air_entry_positions.clear()
	objective_candidates.clear()
	pickup_candidates.clear()
	safe_open_positions.clear()
	rooftop_sockets.clear()
	building_records.clear()

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
		var x_sign: float = -1.0 if (i == 0 or i == 2) else 1.0
		var z_sign: float = -1.0 if (i == 0 or i == 1) else 1.0

		# Primary silhouette box (closer to street intersection)
		var center_a := Vector3(x_sign * 26.0, 0.0, z_sign * 26.0)
		var sil_mesh_a := MeshInstance3D.new()
		sil_mesh_a.name = "Silhouette_%d_A" % i
		var box_a := BoxMesh.new()
		var h_jitter_a: float = rng.randf_range(0.9, 1.15)
		var cur_h_a: float = b_size.y * h_jitter_a
		box_a.size = Vector3(b_size.x * 0.85, cur_h_a, b_size.z * 0.85)
		box_a.material = sil_mat
		sil_mesh_a.mesh = box_a
		sil_mesh_a.position = center_a + Vector3(0.0, cur_h_a * 0.5, 0.0)
		sil_mesh_a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hlod_root.add_child(sil_mesh_a)

		# Secondary silhouette box (deeper in the block)
		var center_b := Vector3(x_sign * 46.0, 0.0, z_sign * 46.0)
		var sil_mesh_b := MeshInstance3D.new()
		sil_mesh_b.name = "Silhouette_%d_B" % i
		var box_b := BoxMesh.new()
		var h_jitter_b: float = rng.randf_range(0.7, 1.0)
		var cur_h_b: float = b_size.y * h_jitter_b
		box_b.size = Vector3(b_size.x * 0.75, cur_h_b, b_size.z * 0.75)
		box_b.material = sil_mat
		sil_mesh_b.mesh = box_b
		sil_mesh_b.position = center_b + Vector3(0.0, cur_h_b * 0.5, 0.0)
		sil_mesh_b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hlod_root.add_child(sil_mesh_b)

# ==============================================================================
# FULL DETAIL BUILDER
# ==============================================================================
func _build_full_detail(immediate: bool = false) -> void:
	var rng := _get_chunk_rng()

	_build_roads()
	_build_buildings_stage_1(rng)
	_populate_initial_candidates()

	if immediate:
		_build_buildings_stage_2(rng)
		_build_props(rng)
		_populate_gameplay_candidates()
		_build_encounters(rng)
		is_fully_assembled = true
	else:
		is_fully_assembled = false
		var token: int = _assembly_token
		call_deferred("_finish_full_detail_assembly", token)

func _finish_full_detail_assembly(token: int) -> void:
	if token != _assembly_token or detail_level != DetailLevel.FULL_DETAIL:
		return
	var rng := _get_chunk_rng()
	_build_buildings_stage_2(rng)
	_build_props(rng)
	_populate_gameplay_candidates()
	_build_encounters(rng)
	is_fully_assembled = true

	var streamer: Node = get_parent()
	if streamer and streamer.has_method("_register_chunk_metadata"):
		streamer.call("_register_chunk_metadata", self)
		if "_markers_dirty" in streamer:
			streamer.set("_markers_dirty", true)

func _populate_initial_candidates() -> void:
	var origin := global_position
	ground_spawn_points.clear()
	ground_spawn_points.append(origin + Vector3(0.0, 0.3, 0.0))
	ground_spawn_points.append(origin + Vector3(0.0, 0.3, -56.0))
	ground_spawn_points.append(origin + Vector3(0.0, 0.3, 56.0))
	ground_spawn_points.append(origin + Vector3(-56.0, 0.3, 0.0))
	ground_spawn_points.append(origin + Vector3(56.0, 0.3, 0.0))
	safe_open_positions.clear()
	safe_open_positions.append(origin + Vector3(0.0, 0.3, 0.0))

func _build_encounters(rng: RandomNumberGenerator) -> void:
	if coord == Vector2i.ZERO or safe_open_positions.is_empty():
		return

	# ~55% probability of spawning an encounter in non-origin chunks
	var encounter_roll: float = rng.randf()
	if encounter_roll > 0.55:
		return

	encounters_root = Node3D.new()
	encounters_root.name = "Encounters"
	add_child(encounters_root)

	var spawn_pos: Vector3 = safe_open_positions[0]
	var enc_type_roll: float = rng.randf()
	var enc: Node3D = null

	if enc_type_roll < 0.28:
		# Supply Beacon
		var b: Node3D = SupplyBeaconScript.new()
		b.name = "SupplyBeacon"
		b.set("chunk_coord", coord)
		b.set("encounter_id", "supply_beacon_%d_%d" % [coord.x, coord.y])
		enc = b
	elif enc_type_roll < 0.58:
		# Guarded Upgrade Cache
		var c: Node3D = GuardedCacheScript.new()
		c.name = "GuardedCache"
		c.set("chunk_coord", coord)
		c.set("encounter_id", "guarded_cache_%d_%d" % [coord.x, coord.y])
		enc = c
	elif enc_type_roll < 0.85:
		# Reward Location (Repair Station or Ammo Depot)
		var r: Node3D = RewardLocationScript.new()
		r.name = "RewardLocation"
		r.set("chunk_coord", coord)
		r.set("encounter_id", "reward_location_%d_%d" % [coord.x, coord.y])
		r.set("reward_type", 0 if rng.randf() < 0.5 else 1) # 0=REPAIR_STATION, 1=AMMO_DEPOT
		enc = r
	else:
		# Rare XP Burst Pickup
		var p: Node3D = XPBurstPickupScript.new()
		p.name = "XPBurstPickup"
		enc = p

	if enc:
		enc.transform.origin = spawn_pos
		encounters_root.add_child(enc)

func _get_chunk_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var h: int = chunk_seed
	h = ((h ^ (coord.x * 73856093)) ^ (coord.y * 19349663)) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	rng.seed = h
	return rng

func _get_decoration_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var h: int = chunk_seed ^ 0x5F3759DF
	h = ((h ^ (coord.x * 45293047)) ^ (coord.y * 31415926)) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	rng.seed = h
	return rng

func _build_roads() -> void:
	roads_root = Node3D.new()
	roads_root.name = "Roads"
	add_child(roads_root)

	var cache_key: int = (1 if ns_is_avenue else 0) | (2 if ew_is_avenue else 0) | (4 if coord == Vector2i.ZERO else 0)
	var merged_mesh: ArrayMesh = null

	if _cached_road_meshes.has(cache_key):
		merged_mesh = _cached_road_meshes[cache_key] as ArrayMesh
	else:
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
		merged_mesh = ArrayMesh.new()
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

		_cached_road_meshes[cache_key] = merged_mesh

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

static func _get_building_catalog() -> Dictionary:
	if not _cached_building_catalog.is_empty():
		return _cached_building_catalog

	_cached_building_catalog = {
		"skyscraper_a": {
			"scene": BuildingLargeScene,
			"name": "BuildingLarge",
			"size": Vector2(29.44, 15.27),
			"height": 64.0,
			"has_flat_roof": true,
			"roof_clearance": 5.5,
			"roof_height": 64.12,
			"surface_type": "concrete",
			"marker_offset": Vector3(-8.0, 64.12, 0.0)
		},
		"skyscraper_b": {
			"scene": BuildingLargeBScene,
			"name": "BuildingLargeB",
			"size": Vector2(28.63, 13.60),
			"height": 58.24,
			"has_flat_roof": true,
			"roof_clearance": 5.0,
			"roof_height": 58.36,
			"surface_type": "concrete",
			"marker_offset": Vector3(-8.0, 58.36, 0.0)
		},
		"skyscraper_c": {
			"scene": BuildingSkyscraperCScene,
			"name": "BuildingSkyscraperC",
			"size": Vector2(13.60, 13.60),
			"height": 51.84,
			"has_flat_roof": true,
			"roof_clearance": 5.0,
			"roof_height": 51.90,
			"surface_type": "concrete",
			"marker_offset": Vector3(0.0, 51.90, 0.0)
		},
		"medium_a": {
			"scene": BuildingMediumScene,
			"name": "BuildingMedium",
			"size": Vector2(25.00, 19.87),
			"height": 27.34,
			"has_flat_roof": true,
			"roof_clearance": 7.0,
			"roof_height": 27.46,
			"surface_type": "concrete",
			"marker_offset": Vector3(0.0, 27.46, 0.0)
		},
		"medium_b": {
			"scene": BuildingMediumBScene,
			"name": "BuildingMediumB",
			"size": Vector2(22.38, 20.48),
			"height": 28.88,
			"has_flat_roof": true,
			"roof_clearance": 6.0,
			"roof_height": 29.00,
			"surface_type": "concrete",
			"center_offset": Vector3(0.0, 0.0, 0.89),
			"marker_offset": Vector3(0.0, 29.00, 0.0)
		},
		"medium_c": {
			"scene": BuildingMediumCScene,
			"name": "BuildingMediumC",
			"size": Vector2(20.84, 15.14),
			"height": 20.58,
			"has_flat_roof": true,
			"roof_clearance": 6.0,
			"roof_height": 20.65,
			"surface_type": "concrete",
			"marker_offset": Vector3(0.0, 20.65, 0.0)
		},
		"small_a": {
			"scene": BuildingSmallScene,
			"name": "BuildingSmall",
			"size": Vector2(18.46, 14.12),
			"height": 14.08,
			"has_flat_roof": true,
			"roof_clearance": 5.0,
			"roof_height": 14.20,
			"surface_type": "concrete",
			"marker_offset": Vector3(0.0, 14.20, 0.0)
		},
		"small_b": {
			"scene": BuildingSmallBScene,
			"name": "BuildingSmallB",
			"size": Vector2(13.55, 17.16),
			"height": 11.37,
			"has_flat_roof": true,
			"roof_clearance": 4.5,
			"roof_height": 11.50,
			"surface_type": "concrete",
			"marker_offset": Vector3(0.0, 11.50, 0.0)
		},
		"small_c": {
			"scene": BuildingSmallCScene,
			"name": "BuildingSmallC",
			"size": Vector2(10.60, 14.20),
			"height": 12.73,
			"has_flat_roof": true,
			"roof_clearance": 4.0,
			"roof_height": 12.75,
			"surface_type": "concrete",
			"center_offset": Vector3(0.0, 0.0, -0.9),
			"marker_offset": Vector3(0.0, 12.75, 0.0)
		},
		"warehouse_a": {
			"scene": WarehouseScene,
			"name": "Warehouse",
			"size": Vector2(28.16, 14.42),
			"height": 13.25,
			"has_flat_roof": true,
			"roof_clearance": 4.5,
			"roof_height": 12.38,
			"surface_type": "metal",
			"marker_offset": Vector3(5.4, 12.38, 0.0)
		},
		"warehouse_b": {
			"scene": WarehouseSawtoothScene,
			"name": "WarehouseSawtooth",
			"size": Vector2(26.26, 29.51),
			"height": 15.85,
			"has_flat_roof": true,
			"roof_clearance": 5.0,
			"roof_height": 12.12,
			"surface_type": "metal",
			"center_offset": Vector3(0.67, 0.0, 1.0),
			"marker_offset": Vector3(0.0, 12.12, 0.0)
		},
		"town_house": {
			"scene": TownHouseAScene,
			"name": "TownHouseA",
			"size": Vector2(5.2, 4.2),
			"height": 5.62,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 5.62,
			"surface_type": "shingle"
		},
		"town_cabin": {
			"scene": TownCabinScene,
			"name": "TownCabin",
			"size": Vector2(4.6, 3.8),
			"height": 4.52,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 4.52,
			"surface_type": "wood"
		},
		"town_workshop": {
			"scene": TownWorkshopScene,
			"name": "TownWorkshop",
			"size": Vector2(5.2, 4.2),
			"height": 5.87,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 5.87,
			"surface_type": "metal"
		},
		"parking_lot": {
			"scene": ParkingLotScene,
			"name": "ParkingLot",
			"size": Vector2(24.0, 12.0),
			"height": 0.2,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "asphalt"
		},
		"civic_plaza": {
			"scene": CivicPlazaScene,
			"name": "CivicPlaza",
			"size": Vector2(36.0, 36.0),
			"height": 6.0,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "concrete"
		},
		"container_stack": {
			"scene": ContainerStackScene,
			"name": "ContainerStack",
			"size": Vector2(5.8, 6.1),
			"height": 5.15,
			"has_flat_roof": true,
			"roof_clearance": 2.5,
			"roof_height": 5.15,
			"surface_type": "metal",
			"marker_offset": Vector3(0.0, 5.15, 0.0)
		},
		"storage_tanks": {
			"scene": StorageTanksScene,
			"name": "StorageTanks",
			"size": Vector2(15.8, 8.7),
			"height": 4.33,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "metal"
		},
		"solar_array": {
			"scene": SolarArrayScene,
			"name": "SolarArray",
			"size": Vector2(5.3, 3.1),
			"height": 0.92,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "solar"
		},
		"water_tower": {
			"scene": WaterTowerScene,
			"name": "WaterTower",
			"size": Vector2(3.0, 2.9),
			"height": 7.5,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "metal"
		},
		"radio_tower": {
			"scene": RadioTowerScene,
			"name": "RadioTower",
			"size": Vector2(12.0, 12.0),
			"height": 55.0,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "metal"
		},
		"chimney_large": {
			"scene": ChimneyLargeScene,
			"name": "ChimneyLarge",
			"size": Vector2(5.8, 5.8),
			"height": 17.0,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "metal"
		},
		"chimney_small": {
			"scene": ChimneySmallScene,
			"name": "ChimneySmall",
			"size": Vector2(3.2, 3.2),
			"height": 7.5,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "metal"
		},
		"solar_panel_portrait": {
			"scene": SolarPanelPortraitScene,
			"name": "SolarPanelPortrait",
			"size": Vector2(3.5, 4.8),
			"height": 1.44,
			"has_flat_roof": false,
			"roof_clearance": 0.0,
			"roof_height": 0.0,
			"surface_type": "solar"
		}
	}
	return _cached_building_catalog

func _place_lot_building(
	entry: Dictionary,
	u_norm: float,
	v_norm: float,
	q: int,
	lot_idx: int,
	x_inner: float,
	z_inner: float,
	block_w: float,
	block_d: float,
	occupied_rects: Array[Rect2],
	rng: RandomNumberGenerator,
	forced_rot_step: int = -1,
	fallback_keys: Array[String] = []
) -> bool:
	var cat := _get_building_catalog()
	var rot_step: int = forced_rot_step if forced_rot_step >= 0 else rng.randi_range(0, 3)
	var rot_y: float = float(rot_step) * (PI * 0.5)

	var b_size: Vector2 = entry["size"] as Vector2
	var eff_w: float = b_size.y if (rot_step % 2 == 1) else b_size.x
	var eff_d: float = b_size.x if (rot_step % 2 == 1) else b_size.y
	var half_w: float = eff_w * 0.5
	var half_d: float = eff_d * 0.5

	var b_height: float = float(entry.get("height", 10.0))
	var clearance: float = 2.0
	if b_height >= 35.0:
		clearance = 6.0
	elif b_height >= 15.0:
		clearance = 4.5
	elif b_height >= 3.0:
		clearance = 3.5

	var center_offset: Vector3 = Vector3.ZERO
	if entry.has("center_offset"):
		center_offset = entry["center_offset"] as Vector3
	var rotated_offset_x: float = center_offset.x * cos(rot_y) + center_offset.z * sin(rot_y)
	var rotated_offset_z: float = -center_offset.x * sin(rot_y) + center_offset.z * cos(rot_y)

	var min_u: float = x_inner + 1.2
	var max_u: float = 62.0 - 1.2
	var min_v: float = z_inner + 1.2
	var max_v: float = 62.0 - 1.2

	# Check if building fits within the quadrant parcel boundaries
	if eff_w > (max_u - min_u) or eff_d > (max_v - min_v):
		for fb_key: String in fallback_keys:
			if cat.has(fb_key):
				var remaining_fbs: Array[String] = []
				for k in fallback_keys:
					if k != fb_key:
						remaining_fbs.append(k)
				if _place_lot_building(cat[fb_key], u_norm, v_norm, q, lot_idx, x_inner, z_inner, block_w, block_d, occupied_rects, rng, forced_rot_step, remaining_fbs):
					return true
		return false

	var u_x: float = x_inner + u_norm * block_w
	var v_z: float = z_inner + v_norm * block_d
	u_x += rng.randf_range(-0.4, 0.4)
	v_z += rng.randf_range(-0.4, 0.4)

	u_x = clampf(u_x, min_u + half_w, max_u - half_w)
	v_z = clampf(v_z, min_v + half_d, max_v - half_d)

	var proposed_rect := Rect2(u_x - half_w, v_z - half_d, eff_w, eff_d)
	var test_rect := proposed_rect.grow(clearance * 0.5)

	var collides: bool = false
	for occ: Rect2 in occupied_rects:
		if test_rect.intersects(occ):
			collides = true
			break

	if collides:
		for fb_key: String in fallback_keys:
			if cat.has(fb_key):
				var remaining_fbs: Array[String] = []
				for k in fallback_keys:
					if k != fb_key:
						remaining_fbs.append(k)
				if _place_lot_building(cat[fb_key], u_norm, v_norm, q, lot_idx, x_inner, z_inner, block_w, block_d, occupied_rects, rng, forced_rot_step, remaining_fbs):
					return true
		return false

	occupied_rects.append(test_rect)

	var x_sign: float = -1.0 if (q == 0 or q == 2) else 1.0
	var z_sign: float = -1.0 if (q == 0 or q == 1) else 1.0
	var final_pos := Vector3(x_sign * u_x - x_sign * rotated_offset_x, 0.0, z_sign * v_z - z_sign * rotated_offset_z)

	var scene: PackedScene = entry["scene"] as PackedScene
	var b_inst := scene.instantiate() as Node3D
	if not b_inst:
		return false

	b_inst.name = "Building_Q%d_L%d" % [q, lot_idx]
	b_inst.position = final_pos
	b_inst.rotation.y = rot_y
	buildings_root.add_child(b_inst)

	var b_name: String = entry["name"] as String
	var b_rec: Dictionary = {
		"building_id": b_inst.name,
		"chunk_coord": coord,
		"building_type": b_name,
		"world_position": global_position + final_pos,
		"local_position": final_pos,
		"footprint_size": b_size,
		"effective_size": Vector2(eff_w, eff_d),
		"bounds_rect": Rect2(final_pos.x - eff_w * 0.5, final_pos.z - eff_d * 0.5, eff_w, eff_d),
		"height": entry["height"],
		"has_rooftop_socket": entry["has_flat_roof"],
		"rooftop_socket_id": ""
	}

	if entry["has_flat_roof"]:
		var m_roof: Marker3D = b_inst.get_node_or_null("RooftopDefensePoint") as Marker3D
		if not m_roof:
			m_roof = b_inst.get_node_or_null("RooftopSpawnPoint") as Marker3D

		var marker_offset: Vector3 = Vector3(0.0, entry.get("roof_height", entry["height"]), 0.0)
		if is_instance_valid(m_roof):
			marker_offset = m_roof.position
		elif entry.has("marker_offset"):
			marker_offset = entry["marker_offset"] as Vector3

		var marker_rotated: Vector3 = b_inst.transform.basis * marker_offset
		var socket_local_pos: Vector3 = final_pos + marker_rotated
		var socket_world_pos: Vector3 = global_position + socket_local_pos
		var socket_id: String = "Roof_C%d_%d_Q%d_L%d" % [coord.x, coord.y, q, lot_idx]
		b_rec["rooftop_socket_id"] = socket_id

		var equip_pos: Vector3 = Vector3.ZERO
		var m_equip: Marker3D = b_inst.get_node_or_null("RooftopPoints/Equipment") as Marker3D
		if is_instance_valid(m_equip):
			equip_pos = global_position + final_pos + (b_inst.transform.basis * m_equip.position)

		var lookout_pos: Vector3 = Vector3.ZERO
		var m_lookout: Marker3D = b_inst.get_node_or_null("RooftopPoints/Lookout") as Marker3D
		if is_instance_valid(m_lookout):
			lookout_pos = global_position + final_pos + (b_inst.transform.basis * m_lookout.position)

		var socket_data: Dictionary = {
			"socket_id": socket_id,
			"chunk_coord": coord,
			"building_id": b_inst.name,
			"building_type": b_name,
			"world_position": socket_world_pos,
			"local_position": socket_local_pos,
			"rotation_y": rot_y,
			"usable_clearance": entry["roof_clearance"],
			"height": marker_offset.y,
			"is_occupied": false,
			"surface_type": entry["surface_type"],
			"equipment_position": equip_pos,
			"lookout_position": lookout_pos
		}
		rooftop_sockets.append(socket_data)

	building_records.append(b_rec)
	return true

func _build_buildings(rng: RandomNumberGenerator) -> void:
	_build_buildings_stage_1(rng)
	_build_buildings_stage_2(rng)

func _build_buildings_stage_1(rng: RandomNumberGenerator) -> void:
	if is_instance_valid(buildings_root):
		buildings_root.queue_free()
	buildings_root = Node3D.new()
	buildings_root.name = "Buildings"
	add_child(buildings_root)

	rooftop_sockets.clear()
	building_records.clear()

	var cat := _get_building_catalog()
	var x_inner: float = 12.0 if ns_is_avenue else 8.5
	var z_inner: float = 12.0 if ew_is_avenue else 8.5
	var block_w: float = 62.0 - x_inner
	var block_d: float = 62.0 - z_inner

	for q in range(0, 2):
		_build_quadrant(q, rng, cat, x_inner, z_inner, block_w, block_d)

func _build_buildings_stage_2(rng: RandomNumberGenerator) -> void:
	if not is_instance_valid(buildings_root):
		return
	var cat := _get_building_catalog()
	var x_inner: float = 12.0 if ns_is_avenue else 8.5
	var z_inner: float = 12.0 if ew_is_avenue else 8.5
	var block_w: float = 62.0 - x_inner
	var block_d: float = 62.0 - z_inner

	for q in range(2, 4):
		_build_quadrant(q, rng, cat, x_inner, z_inner, block_w, block_d)

func _build_quadrant(q: int, rng: RandomNumberGenerator, cat: Dictionary, x_inner: float, z_inner: float, block_w: float, block_d: float) -> void:
	for _q_exec in [q]:
		var occupied_rects: Array[Rect2] = []
		match district_type:
			DistrictType.HELIPAD:
				# Chunk (0,0): Keep central 24m x 24m clear. Place low-profile structures in outer quadrant.
				var helipad_lot_entry: Dictionary
				var h_fallbacks: Array[String] = ["parking_lot", "small_c"]
				if q == 0:
					helipad_lot_entry = cat["parking_lot"]
				elif q == 1:
					helipad_lot_entry = cat["small_c"]
				elif q == 2:
					helipad_lot_entry = cat["parking_lot"]
				else:
					helipad_lot_entry = cat["small_b"]
				_place_lot_building(helipad_lot_entry, 0.52, 0.52, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, h_fallbacks)

			DistrictType.HIGH_RISE:
				var pattern_hr: int = rng.randi_range(0, 2)
				if coord.x == 2 and coord.y == 0 and q == 0:
					# Landmark Radio Tower quad
					_place_lot_building(cat["radio_tower"], 0.28, 0.28, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["medium_c"])
					_place_lot_building(cat["medium_b"], 0.74, 0.24, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_a"])
					_place_lot_building(cat["small_c"], 0.50, 0.74, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
					_place_lot_building(cat["small_b"], 0.74, 0.74, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
				elif pattern_hr == 0:
					# Archetype A: Skyscraper Anchor + Mid-Rise Flanks + Retail Infill + Parking
					var tower_entry: Dictionary = cat["skyscraper_a"] if rng.randf() < 0.5 else cat["skyscraper_b"]
					var wing_entry: Dictionary = cat["medium_b"] if rng.randf() < 0.5 else cat["medium_c"]
					var rear_entry: Dictionary = cat["skyscraper_c"] if rng.randf() < 0.6 else cat["medium_a"]
					_place_lot_building(tower_entry, 0.26, 0.24, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["skyscraper_c", "medium_a"])
					_place_lot_building(wing_entry, 0.24, 0.74, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_a", "small_c"])
					_place_lot_building(rear_entry, 0.74, 0.68, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["medium_c", "small_b"])
					_place_lot_building(cat["parking_lot"], 0.72, 0.26, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["small_c"], 0.74, 0.46, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
					_place_lot_building(cat["small_b"], 0.48, 0.74, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
				elif pattern_hr == 1:
					# Archetype B: Urban Canyons (2-3 slender towers with street shops & parking)
					var t1: Dictionary = cat["skyscraper_c"]
					var t2: Dictionary = cat["medium_a"] if rng.randf() < 0.5 else cat["skyscraper_b"]
					var t3: Dictionary = cat["skyscraper_c"] if rng.randf() < 0.6 else cat["medium_c"]
					_place_lot_building(t1, 0.22, 0.22, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_a"])
					_place_lot_building(t2, 0.74, 0.24, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["medium_c"])
					_place_lot_building(t3, 0.24, 0.74, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
					_place_lot_building(cat["small_c"], 0.74, 0.74, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["parking_lot"])
					_place_lot_building(cat["small_a"], 0.48, 0.24, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["small_b"], 0.24, 0.48, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
				else:
					# Archetype C: Civic / Tower Landmark with plaza perimeter
					var landmark_tower: Dictionary = cat["skyscraper_a"] if rng.randf() < 0.5 else cat["skyscraper_b"]
					_place_lot_building(cat["civic_plaza"], 0.44, 0.44, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["parking_lot"])
					_place_lot_building(landmark_tower, 0.80, 0.24, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["skyscraper_c", "medium_c"])
					_place_lot_building(cat["small_b"], 0.24, 0.80, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["small_c"], 0.80, 0.80, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
					_place_lot_building(cat["small_a"], 0.24, 0.24, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])

			DistrictType.MID_RISE:
				var pattern_mr: int = rng.randi_range(0, 2)
				if pattern_mr == 0:
					# Archetype A: Commercial Street Frontage & Courtyard Infill
					var m_front: Dictionary = cat["medium_b"] if rng.randf() < 0.5 else cat["medium_a"]
					var m_side: Dictionary = cat["small_a"] if rng.randf() < 0.5 else cat["small_b"]
					var m_rear: Dictionary = cat["medium_c"]
					_place_lot_building(m_front, 0.24, 0.24, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_a", "small_c"])
					_place_lot_building(m_side, 0.24, 0.74, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(m_rear, 0.74, 0.24, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
					_place_lot_building(cat["small_c"], 0.74, 0.74, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["parking_lot"])
					_place_lot_building(cat["small_c"], 0.48, 0.24, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
					_place_lot_building(cat["small_b"], 0.24, 0.48, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
				elif pattern_mr == 1:
					# Archetype B: Commercial Plaza & Retail Block
					var m_office: Dictionary = cat["medium_a"] if rng.randf() < 0.5 else cat["medium_b"]
					_place_lot_building(cat["parking_lot"], 0.26, 0.24, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(m_office, 0.74, 0.26, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["medium_c"])
					_place_lot_building(cat["small_b"], 0.24, 0.74, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["small_c"], 0.74, 0.74, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_workshop"])
					_place_lot_building(cat["small_a"], 0.74, 0.50, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
					_place_lot_building(cat["small_c"], 0.26, 0.50, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
				else:
					# Archetype C: Dense Office Quad (L-shape with annexes)
					_place_lot_building(cat["medium_c"], 0.22, 0.22, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_a"])
					_place_lot_building(cat["small_a"], 0.22, 0.74, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])
					_place_lot_building(cat["medium_b"], 0.74, 0.22, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["medium_c"])
					_place_lot_building(cat["parking_lot"], 0.74, 0.74, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["small_b"], 0.48, 0.22, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["small_c"], 0.22, 0.48, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_b"])

			DistrictType.INDUSTRIAL:
				var pattern_ind: int = rng.randi_range(0, 2)
				if pattern_ind == 0:
					# Archetype A: Logistics Yard (Warehouse + Multi-Unit Container Rows + Storage + Industrial Chimney)
					var wh: Dictionary = cat["warehouse_a"] if rng.randf() < 0.6 else cat["warehouse_b"]
					_place_lot_building(wh, 0.34, 0.24, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["medium_c"])
					_place_lot_building(cat["container_stack"], 0.22, 0.74, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["container_stack"], 0.44, 0.74, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["parking_lot"])
					_place_lot_building(cat["container_stack"], 0.66, 0.74, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["parking_lot"])
					_place_lot_building(cat["container_stack"], 0.22, 0.54, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["container_stack"], 0.44, 0.54, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["storage_tanks"], 0.74, 0.28, q, 6, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["warehouse_a"])
					_place_lot_building(cat["chimney_large"], 0.74, 0.62, q, 7, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["solar_panel_portrait", "parking_lot"])
				elif pattern_ind == 1:
					# Archetype B: Tank Farm & Storage (Storage tanks + Water tower + Chimney + Container rows)
					_place_lot_building(cat["storage_tanks"], 0.28, 0.26, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["warehouse_a"])
					_place_lot_building(cat["water_tower"], 0.72, 0.24, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["small_b"], 0.24, 0.72, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["container_stack"], 0.70, 0.70, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["parking_lot"])
					_place_lot_building(cat["container_stack"], 0.70, 0.48, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["parking_lot"])
					_place_lot_building(cat["container_stack"], 0.48, 0.72, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["storage_tanks"], 0.50, 0.26, q, 6, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["warehouse_a"])
					_place_lot_building(cat["chimney_small"], 0.24, 0.48, q, 7, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c", "small_b"])
				else:
					# Archetype C: Sawtooth Depot & Freight Staging (Depot + Chimneys + Solar Portrait + Containers)
					_place_lot_building(cat["warehouse_b"], 0.38, 0.38, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["warehouse_a"])
					_place_lot_building(cat["container_stack"], 0.78, 0.26, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["chimney_large"], 0.78, 0.46, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["chimney_small", "small_c"])
					_place_lot_building(cat["parking_lot"], 0.78, 0.72, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["container_stack"], 0.26, 0.78, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
					_place_lot_building(cat["solar_panel_portrait"], 0.48, 0.78, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["chimney_small", "small_c"])

			DistrictType.RESIDENTIAL, _:
				var pattern_res: int = rng.randi_range(0, 2)
				if pattern_res == 0:
					# Archetype A: Dense Suburban Neighborhood (3 street rows of houses, cabins & workshops)
					# Streetfront Row 1 (u ~ 0.18)
					_place_lot_building(cat["town_house"], 0.18, 0.18, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.18, 0.38, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["town_house"], 0.18, 0.58, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.18, 0.78, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					# Interior Neighborhood Row 2 (u ~ 0.46)
					_place_lot_building(cat["town_workshop"], 0.46, 0.20, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["town_house"], 0.46, 0.40, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.46, 0.60, q, 6, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["town_workshop"], 0.46, 0.80, q, 7, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					# Rear Avenue Row 3 (u ~ 0.76)
					_place_lot_building(cat["town_house"], 0.76, 0.18, q, 8, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.76, 0.38, q, 9, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["solar_array"], 0.76, 0.58, q, 10, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_house"], 0.76, 0.78, q, 11, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["small_c"])
				elif pattern_res == 1:
					# Archetype B: Homestead Farm & Workshop Crops (10-11 buildings)
					# Workshop & Utilities Wing (u ~ 0.22)
					_place_lot_building(cat["town_workshop"], 0.22, 0.22, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["town_cabin"], 0.22, 0.44, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["solar_array"], 0.22, 0.66, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["water_tower"], 0.22, 0.84, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					# Central Homestead Core (u ~ 0.50)
					_place_lot_building(cat["town_house"], 0.50, 0.22, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.50, 0.46, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["town_workshop"], 0.50, 0.72, q, 6, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					# Outer Agrarian Outbuildings (u ~ 0.76)
					_place_lot_building(cat["town_cabin"], 0.76, 0.22, q, 7, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["solar_array"], 0.76, 0.44, q, 8, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_house"], 0.76, 0.68, q, 9, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.76, 0.88, q, 10, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
				else:
					# Archetype C: Village Square & Courtyard Perimeter Ring (10-11 buildings)
					# Streetfront Flank (u ~ 0.20)
					_place_lot_building(cat["town_house"], 0.20, 0.20, q, 0, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.20, 0.46, q, 1, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["town_workshop"], 0.20, 0.74, q, 2, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					# South Outer Perimeter (v ~ 0.78)
					_place_lot_building(cat["town_house"], 0.46, 0.78, q, 3, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.74, 0.78, q, 4, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					# East Outer Flank (u ~ 0.76)
					_place_lot_building(cat["town_house"], 0.76, 0.52, q, 5, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["town_cabin"], 0.76, 0.24, q, 6, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					# North Inner Flank (v ~ 0.20)
					_place_lot_building(cat["town_workshop"], 0.46, 0.20, q, 7, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					# Courtyard Accents & Greenery Anchors
					_place_lot_building(cat["solar_array"], 0.46, 0.48, q, 8, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])
					_place_lot_building(cat["water_tower"], 0.74, 0.38, q, 9, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_house"])
					_place_lot_building(cat["town_house"], 0.76, 0.88, q, 10, x_inner, z_inner, block_w, block_d, occupied_rects, rng, -1, ["town_cabin"])

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

	var ns_shoulder_w: float = 20.0 if ns_is_avenue else 13.0
	var ew_shoulder_w: float = 20.0 if ew_is_avenue else 13.0
	var ns_pole_x: float = ns_shoulder_w * 0.5 - 0.4
	var ew_pole_z: float = ew_shoulder_w * 0.5 - 0.4

	var lamp_positions: Array[Vector3] = []
	var z_intervals: Array[float] = [-46.0, -24.0, 24.0, 46.0]
	for z_pos in z_intervals:
		lamp_positions.append(Vector3(-ns_pole_x, 3.5, z_pos))
		lamp_positions.append(Vector3(ns_pole_x, 3.5, z_pos))

	var x_intervals: Array[float] = [-46.0, -24.0, 24.0, 46.0]
	for x_pos in x_intervals:
		lamp_positions.append(Vector3(x_pos, 3.5, -ew_pole_z))
		lamp_positions.append(Vector3(x_pos, 3.5, ew_pole_z))

	# Helipad chunk (0,0): Keep central 26m takeoff perimeter completely clear
	if coord == Vector2i.ZERO:
		lamp_positions = lamp_positions.filter(func(p: Vector3) -> bool:
			return absf(p.x) > 13.0 or absf(p.z) > 13.0
		)

	mm.instance_count = lamp_positions.size()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.16
	pole_mesh.height = 7.0
	pole_mesh.material = ConcreteAgedMat
	mm.mesh = pole_mesh

	for idx in range(lamp_positions.size()):
		var t := Transform3D(Basis(), lamp_positions[idx])
		mm.set_instance_transform(idx, t)

	mm_inst.multimesh = mm
	mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props_root.add_child(mm_inst)

func _build_vehicles(rng: RandomNumberGenerator) -> void:
	var ns_asphalt_w: float = 16.0 if ns_is_avenue else 9.0
	var car_x: float = ns_asphalt_w * 0.5 - 1.1

	var car_candidates: Array[Vector3] = [
		Vector3(-car_x, 0.0, -32.0),
		Vector3(-car_x, 0.0, -22.0),
		Vector3(-car_x, 0.0, 22.0),
		Vector3(car_x, 0.0, -30.0),
		Vector3(car_x, 0.0, 24.0),
		Vector3(car_x, 0.0, 32.0)
	]

	if coord == Vector2i.ZERO:
		car_candidates = car_candidates.filter(func(p: Vector3) -> bool:
			return absf(p.x) > 13.0 or absf(p.z) > 13.0
		)

	var max_cars: int = 3 if SaveSystem.low_particles else car_candidates.size()
	for idx in range(mini(car_candidates.size(), max_cars)):
		var base_pos: Vector3 = car_candidates[idx]
		var jitter_z: float = rng.randf_range(-1.0, 1.0)
		var spawn_pos: Vector3 = base_pos + Vector3(0.0, 0.0, jitter_z)
		var rot_y: float = (PI if base_pos.x < 0.0 else 0.0) + rng.randf_range(-0.04, 0.04)

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
			var v_shadow: GeometryInstance3D.ShadowCastingSetting = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if (coord.length() > 1.0 or SaveSystem.low_particles)
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			)
			for vc in v_node.find_children("*", "GeometryInstance3D", true, false):
				var v_gi := vc as GeometryInstance3D
				if v_gi:
					v_gi.cast_shadow = v_shadow
			props_root.add_child(v_node)

func _build_tree_clusters(rng: RandomNumberGenerator) -> void:
	_init_shared_prop_resources()
	var dec_rng := _get_decoration_rng()

	# Foliage shadow casting: OFF on LOW preset (or beyond center chunks), ON on Medium/High in center area
	var shadow_setting: GeometryInstance3D.ShadowCastingSetting = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if (coord.length() > 1.5 or SaveSystem.low_particles)
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)

	# Fallback if Kenney meshes are unavailable
	if _kenney_tree_small_mesh == null:
		_build_procedural_fallback_trees(rng, shadow_setting)
		return

	var ns_shoulder_w: float = 20.0 if ns_is_avenue else 13.0
	var ew_shoulder_w: float = 20.0 if ew_is_avenue else 13.0
	var x_inner: float = 12.0 if ns_is_avenue else 8.5
	var z_inner: float = 12.0 if ew_is_avenue else 8.5

	var small_transforms: Array[Transform3D] = []
	var large_transforms: Array[Transform3D] = []
	var planter_transforms: Array[Transform3D] = []
	var placed_vegetation: Array[Dictionary] = []

	# --------------------------------------------------------------------------
	# 1. Sidewalk Avenue Trees & Planters (Replaces procedural cylinder slots)
	# --------------------------------------------------------------------------
	var tree_x: float = ns_shoulder_w * 0.5 + 2.2
	var tree_z: float = ew_shoulder_w * 0.5 + 2.2
	var sidewalk_slots: Array[Vector3] = [
		Vector3(-tree_x, 0.12, -48.0),
		Vector3(-tree_x, 0.12, 48.0),
		Vector3(tree_x, 0.12, -48.0),
		Vector3(tree_x, 0.12, 48.0),
		Vector3(-48.0, 0.12, -tree_z),
		Vector3(48.0, 0.12, -tree_z),
		Vector3(-48.0, 0.12, tree_z),
		Vector3(48.0, 0.12, tree_z)
	]

	for slot_pos in sidewalk_slots:
		if coord == Vector2i.ZERO:
			if absf(slot_pos.x) < 16.0 and absf(slot_pos.z) < 16.0:
				continue
		# Industrial district: sparse planting (skip ~50% of avenue slots)
		if district_type == DistrictType.INDUSTRIAL and dec_rng.randf() < 0.5:
			continue
		# On low particles/performance preset, scale back sidewalk planting
		if SaveSystem.low_particles and dec_rng.randf() < 0.4:
			continue

		if not _is_vegetation_position_clear(slot_pos, 1.2, placed_vegetation, x_inner, z_inner):
			continue

		var t_type := "small"
		if district_type == DistrictType.RESIDENTIAL:
			t_type = "large" if dec_rng.randf() < 0.6 else "small"
		elif district_type == DistrictType.HIGH_RISE:
			t_type = "planter" if dec_rng.randf() < 0.4 else "small"
		else:
			t_type = "small" if dec_rng.randf() < 0.7 else "large"

		_add_vegetation_instance(slot_pos, t_type, dec_rng, small_transforms, large_transforms, planter_transforms, placed_vegetation)

	# --------------------------------------------------------------------------
	# 2. Pocket Trees & Planters in Unused Gaps (District-Sensitive Density)
	# --------------------------------------------------------------------------
	var max_additional: int = 0
	match district_type:
		DistrictType.RESIDENTIAL: max_additional = 8
		DistrictType.MID_RISE: max_additional = 4
		DistrictType.HIGH_RISE: max_additional = 3
		DistrictType.INDUSTRIAL: max_additional = 2
		DistrictType.HELIPAD: max_additional = 1

	var target_additional: int = dec_rng.randi_range(int(max_additional * 0.5), max_additional)
	if SaveSystem.low_particles:
		target_additional = int(target_additional * 0.4)
	var additional_placed: int = 0

	var quad_templates: Array[Vector2] = [
		Vector2(54.0, 54.0),
		Vector2(54.0, 34.0),
		Vector2(34.0, 54.0),
		Vector2(42.0, 42.0),
		Vector2(46.0, 22.0),
		Vector2(22.0, 46.0),
		Vector2(30.0, 30.0)
	]

	for q in range(4):
		if additional_placed >= target_additional:
			break
		var x_sign: float = -1.0 if (q == 0 or q == 2) else 1.0
		var z_sign: float = -1.0 if (q == 0 or q == 1) else 1.0

		for tmpl in quad_templates:
			if additional_placed >= target_additional:
				break
			var cand_x: float = x_sign * (tmpl.x + dec_rng.randf_range(-2.0, 2.0))
			var cand_z: float = z_sign * (tmpl.y + dec_rng.randf_range(-2.0, 2.0))
			var cand_pos := Vector3(cand_x, 0.10, cand_z)

			if not _is_vegetation_position_clear(cand_pos, 1.4, placed_vegetation, x_inner, z_inner):
				continue

			var min_dist_b: float = _get_min_distance_to_buildings(cand_pos)
			var t_type := "small"
			if district_type == DistrictType.RESIDENTIAL:
				t_type = "large" if (min_dist_b >= 4.0 and dec_rng.randf() < 0.55) else "small"
			elif district_type == DistrictType.HIGH_RISE or district_type == DistrictType.MID_RISE:
				t_type = "planter" if min_dist_b < 3.2 else "small"
			else:
				t_type = "small"

			_add_vegetation_instance(cand_pos, t_type, dec_rng, small_transforms, large_transforms, planter_transforms, placed_vegetation)
			additional_placed += 1

			# In residential areas, occasionally place a companion tree to form a natural cluster of 2-3
			if district_type == DistrictType.RESIDENTIAL and additional_placed < target_additional and dec_rng.randf() < 0.65:
				var comp_angle: float = dec_rng.randf_range(0.0, TAU)
				var comp_dist: float = dec_rng.randf_range(2.8, 4.2)
				var comp_pos := cand_pos + Vector3(cos(comp_angle) * comp_dist, 0.0, sin(comp_angle) * comp_dist)
				if _is_vegetation_position_clear(comp_pos, 1.2, placed_vegetation, x_inner, z_inner):
					_add_vegetation_instance(comp_pos, "small", dec_rng, small_transforms, large_transforms, planter_transforms, placed_vegetation)
					additional_placed += 1

	# --------------------------------------------------------------------------
	# 3. Commit Batched MultiMeshInstance3D Nodes
	# --------------------------------------------------------------------------
	if not small_transforms.is_empty() and _kenney_tree_small_mesh:
		var mm_small := MultiMeshInstance3D.new()
		mm_small.name = "KenneyTreesSmallMultiMesh"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = small_transforms.size()
		mm.mesh = _kenney_tree_small_mesh
		for i in range(small_transforms.size()):
			mm.set_instance_transform(i, small_transforms[i])
		mm_small.multimesh = mm
		mm_small.cast_shadow = shadow_setting
		props_root.add_child(mm_small)

	if not large_transforms.is_empty() and _kenney_tree_large_mesh:
		var mm_large := MultiMeshInstance3D.new()
		mm_large.name = "KenneyTreesLargeMultiMesh"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = large_transforms.size()
		mm.mesh = _kenney_tree_large_mesh
		for i in range(large_transforms.size()):
			mm.set_instance_transform(i, large_transforms[i])
		mm_large.multimesh = mm
		mm_large.cast_shadow = shadow_setting
		props_root.add_child(mm_large)

	if not planter_transforms.is_empty() and _kenney_planter_mesh:
		var mm_planter := MultiMeshInstance3D.new()
		mm_planter.name = "KenneyPlantersMultiMesh"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = planter_transforms.size()
		mm.mesh = _kenney_planter_mesh
		for i in range(planter_transforms.size()):
			mm.set_instance_transform(i, planter_transforms[i])
		mm_planter.multimesh = mm
		mm_planter.cast_shadow = shadow_setting
		props_root.add_child(mm_planter)

func _add_vegetation_instance(
	pos: Vector3,
	type: String,
	rng: RandomNumberGenerator,
	small_list: Array[Transform3D],
	large_list: Array[Transform3D],
	planter_list: Array[Transform3D],
	placed: Array[Dictionary]
) -> void:
	var scale_factor: float = 10.0
	var rad: float = 1.2
	if type == "large":
		scale_factor = 10.0 * rng.randf_range(0.85, 1.15)
		rad = 1.4
	elif type == "planter":
		scale_factor = 5.0 * rng.randf_range(0.90, 1.10)
		rad = 1.0
	else:
		scale_factor = 10.0 * rng.randf_range(0.85, 1.15)
		rad = 1.2

	var rot_y: float = rng.randf_range(0.0, TAU)
	var b := Basis().rotated(Vector3.UP, rot_y).scaled(Vector3(scale_factor, scale_factor, scale_factor))
	var t := Transform3D(b, pos)

	match type:
		"large": large_list.append(t)
		"planter": planter_list.append(t)
		_: small_list.append(t)

	placed.append({
		"pos": pos,
		"type": type,
		"radius": rad
	})

func _get_min_distance_to_buildings(pos: Vector3) -> float:
	var min_d := 999.0
	for b: Dictionary in building_records:
		var b_pos: Vector3 = b["local_position"]
		var b_sz: Vector2 = b.get("effective_size", b["footprint_size"])
		var dx := maxf(0.0, absf(pos.x - b_pos.x) - b_sz.x * 0.5)
		var dz := maxf(0.0, absf(pos.z - b_pos.z) - b_sz.y * 0.5)
		var d := Vector2(dx, dz).length()
		if d < min_d:
			min_d = d
	return min_d

func _is_vegetation_position_clear(
	pos: Vector3,
	radius: float,
	placed: Array[Dictionary],
	x_inner: float,
	z_inner: float
) -> bool:
	# 1. Chunk boundary exclusion (keep 3m away from chunk seams)
	if absf(pos.x) > (60.0 - radius) or absf(pos.z) > (60.0 - radius):
		return false

	# 2. Road corridors and turning clearance
	if absf(pos.x) < (x_inner + radius + 0.6) or absf(pos.z) < (z_inner + radius + 0.6):
		return false

	# 3. Central Helipad Zone (chunk 0, 0)
	if coord == Vector2i.ZERO:
		if absf(pos.x) < 16.0 and absf(pos.z) < 16.0:
			return false

	# 4. Building footprints & setbacks
	for b: Dictionary in building_records:
		var b_pos: Vector3 = b["local_position"]
		var b_sz: Vector2 = b.get("effective_size", b["footprint_size"])
		var margin: float = 1.0
		if absf(pos.x - b_pos.x) < (b_sz.x * 0.5 + radius + margin) and absf(pos.z - b_pos.z) < (b_sz.y * 0.5 + radius + margin):
			return false

	# 5. Local gameplay spawn markers, objectives, and pickup bays
	var local_spawns: Array[Vector3] = [
		Vector3(0.0, 0.3, 0.0),
		Vector3(0.0, 0.3, -56.0),
		Vector3(0.0, 0.3, 56.0),
		Vector3(-56.0, 0.3, 0.0),
		Vector3(56.0, 0.3, 0.0),
		Vector3(-20.0, 0.3, -20.0),
		Vector3(20.0, 0.3, -20.0),
		Vector3(-20.0, 0.3, 20.0),
		Vector3(20.0, 0.3, 20.0)
	]
	for sp in local_spawns:
		if Vector2(pos.x - sp.x, pos.z - sp.z).length() < 6.0:
			return false

	var local_pickups: Array[Vector3] = [
		Vector3(-24.0, 0.5, -12.0),
		Vector3(24.0, 0.5, 12.0),
		Vector3(-12.0, 0.5, 24.0),
		Vector3(12.0, 0.5, -24.0)
	]
	for pk in local_pickups:
		if Vector2(pos.x - pk.x, pos.z - pk.z).length() < 4.8:
			return false

	var local_objectives: Array[Vector3] = [
		Vector3(36.0, 0.3, 36.0),
		Vector3(-36.0, 0.3, -36.0)
	]
	for ob in local_objectives:
		if Vector2(pos.x - ob.x, pos.z - ob.z).length() < 5.5:
			return false

	# 6. Streetlights
	var ns_shoulder_w: float = 20.0 if ns_is_avenue else 13.0
	var ew_shoulder_w: float = 20.0 if ew_is_avenue else 13.0
	var ns_pole_x: float = ns_shoulder_w * 0.5 - 0.4
	var ew_pole_z: float = ew_shoulder_w * 0.5 - 0.4
	for z_pos in [-46.0, -24.0, 24.0, 46.0]:
		if Vector2(pos.x - (-ns_pole_x), pos.z - z_pos).length() < 2.5:
			return false
		if Vector2(pos.x - ns_pole_x, pos.z - z_pos).length() < 2.5:
			return false
	for x_pos in [-46.0, -24.0, 24.0, 46.0]:
		if Vector2(pos.x - x_pos, pos.z - (-ew_pole_z)).length() < 2.5:
			return false
		if Vector2(pos.x - x_pos, pos.z - ew_pole_z).length() < 2.5:
			return false

	# 7. Parked / wrecked vehicles along curbs
	var ns_asphalt_w: float = 16.0 if ns_is_avenue else 9.0
	var car_x: float = ns_asphalt_w * 0.5 - 1.1
	for car_z in [-32.0, -22.0, 22.0, 24.0, 30.0, 32.0]:
		if Vector2(pos.x - (-car_x), pos.z - car_z).length() < 3.5:
			return false
		if Vector2(pos.x - car_x, pos.z - car_z).length() < 3.5:
			return false

	# 8. Separation from already placed vegetation in this chunk
	for other: Dictionary in placed:
		var other_pos: Vector3 = other["pos"]
		if Vector2(pos.x - other_pos.x, pos.z - other_pos.z).length() < 2.8:
			return false

	return true

func _build_procedural_fallback_trees(rng: RandomNumberGenerator, shadow_crowns: GeometryInstance3D.ShadowCastingSetting) -> void:
	var ns_shoulder_w: float = 20.0 if ns_is_avenue else 13.0
	var ew_shoulder_w: float = 20.0 if ew_is_avenue else 13.0
	var tree_x: float = ns_shoulder_w * 0.5 + 2.5
	var tree_z: float = ew_shoulder_w * 0.5 + 2.5

	var tree_positions: Array[Vector3] = [
		Vector3(-tree_x, 0.0, -48.0),
		Vector3(-tree_x, 0.0, 48.0),
		Vector3(tree_x, 0.0, -48.0),
		Vector3(tree_x, 0.0, 48.0),
		Vector3(-48.0, 0.0, -tree_z),
		Vector3(48.0, 0.0, -tree_z),
		Vector3(-48.0, 0.0, tree_z),
		Vector3(48.0, 0.0, tree_z)
	]

	if coord == Vector2i.ZERO:
		tree_positions = tree_positions.filter(func(p: Vector3) -> bool:
			return absf(p.x) > 14.0 or absf(p.z) > 14.0
		)

	var count: int = tree_positions.size()
	if count == 0:
		return

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
			var b1 := Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(12.0)), Vector3(18.2, 0.5, 24.0))
			barrier_transforms.append(b1)
			var b2 := Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(-8.0)), Vector3(18.2, 0.5, 28.0))
			barrier_transforms.append(b2)
	elif district_type == DistrictType.RESIDENTIAL:
		if rng.randf() < 0.4:
			var b1 := Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(5.0)), Vector3(-18.2, 0.5, -22.0))
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

	# 3. Rooftop spawn points: collect from rooftop_sockets with fallback
	for socket in rooftop_sockets:
		var r_pos: Vector3 = socket.get("world_position", Vector3.ZERO) as Vector3
		if not rooftop_spawn_points.has(r_pos):
			rooftop_spawn_points.append(r_pos)

	if rooftop_spawn_points.is_empty() and is_instance_valid(buildings_root):
		for b_child in buildings_root.get_children():
			if b_child is Node3D:
				var m_roof: Marker3D = b_child.get_node_or_null("RooftopDefensePoint") as Marker3D
				if not m_roof:
					m_roof = b_child.get_node_or_null("RooftopSpawnPoint") as Marker3D
				if m_roof:
					rooftop_spawn_points.append(m_roof.global_position)
				else:
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
		if rooftop_spawn_points.size() > 2:
			objective_candidates.append(rooftop_spawn_points[2])
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

func update_graphics_settings(preset_name: String = "") -> void:
	if not props_root or not is_instance_valid(props_root):
		return
	var is_low: bool = (preset_name.to_lower() == "low") if not preset_name.is_empty() else SaveSystem.low_particles
	var shadow_setting: GeometryInstance3D.ShadowCastingSetting = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if (coord.length() > 1.5 or is_low)
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	var mm_s := props_root.get_node_or_null("KenneyTreesSmallMultiMesh") as GeometryInstance3D
	if mm_s:
		mm_s.cast_shadow = shadow_setting
	var mm_l := props_root.get_node_or_null("KenneyTreesLargeMultiMesh") as GeometryInstance3D
	if mm_l:
		mm_l.cast_shadow = shadow_setting
	var mm_p := props_root.get_node_or_null("KenneyPlantersMultiMesh") as GeometryInstance3D
	if mm_p:
		mm_p.cast_shadow = shadow_setting

	var v_shadow: GeometryInstance3D.ShadowCastingSetting = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if (coord.length() > 1.0 or is_low)
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)
	for child in props_root.get_children():
		if child.name.begins_with("Vehicle_"):
			for vc in child.find_children("*", "GeometryInstance3D", true, false):
				var gi := vc as GeometryInstance3D
				if gi:
					gi.cast_shadow = v_shadow
