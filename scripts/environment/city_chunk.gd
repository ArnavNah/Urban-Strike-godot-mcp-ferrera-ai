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

	# 1. Parcel underlay
	var base_mesh := MeshInstance3D.new()
	base_mesh.name = "GroundBase"
	var bm := BoxMesh.new()
	bm.size = Vector3(CHUNK_SIZE, 0.1, CHUNK_SIZE)
	bm.material = ConcreteAgedMat
	base_mesh.mesh = bm
	base_mesh.position = Vector3(0.0, 0.05, 0.0)
	roads_root.add_child(base_mesh)

	# 2. Road geometry: NS Road
	var ns_asphalt_w: float = 16.0 if ns_is_avenue else 9.0
	var ns_shoulder_w: float = 20.0 if ns_is_avenue else 13.0

	var ns_shoulder := MeshInstance3D.new()
	ns_shoulder.name = "NS_Shoulder"
	var ns_sm := BoxMesh.new()
	ns_sm.size = Vector3(ns_shoulder_w, 0.12, CHUNK_SIZE)
	ns_sm.material = ConcreteSidewalkMat
	ns_shoulder.mesh = ns_sm
	ns_shoulder.position = Vector3(0.0, 0.07, 0.0)
	roads_root.add_child(ns_shoulder)

	var ns_asphalt := MeshInstance3D.new()
	ns_asphalt.name = "NS_Asphalt"
	var ns_am := BoxMesh.new()
	ns_am.size = Vector3(ns_asphalt_w, 0.14, CHUNK_SIZE)
	ns_am.material = AsphaltMat
	ns_asphalt.mesh = ns_am
	ns_asphalt.position = Vector3(0.0, 0.08, 0.0)
	roads_root.add_child(ns_asphalt)

	# 3. Road geometry: EW Road
	var ew_asphalt_w: float = 16.0 if ew_is_avenue else 9.0
	var ew_shoulder_w: float = 20.0 if ew_is_avenue else 13.0

	var ew_shoulder := MeshInstance3D.new()
	ew_shoulder.name = "EW_Shoulder"
	var ew_sm := BoxMesh.new()
	ew_sm.size = Vector3(CHUNK_SIZE, 0.12, ew_shoulder_w)
	ew_sm.material = ConcreteSidewalkMat
	ew_shoulder.mesh = ew_sm
	ew_shoulder.position = Vector3(0.0, 0.075, 0.0)
	roads_root.add_child(ew_shoulder)

	var ew_asphalt := MeshInstance3D.new()
	ew_asphalt.name = "EW_Asphalt"
	var ew_am := BoxMesh.new()
	ew_am.size = Vector3(CHUNK_SIZE, 0.145, ew_asphalt_w)
	ew_am.material = AsphaltMat
	ew_asphalt.mesh = ew_am
	ew_asphalt.position = Vector3(0.0, 0.085, 0.0)
	roads_root.add_child(ew_asphalt)

	# 4. Center intersection marking / patch
	var inter := MeshInstance3D.new()
	inter.name = "Intersection"
	var im := BoxMesh.new()
	im.size = Vector3(ns_asphalt_w + 1.0, 0.15, ew_asphalt_w + 1.0)
	im.material = AsphaltMat
	inter.mesh = im
	inter.position = Vector3(0.0, 0.09, 0.0)
	roads_root.add_child(inter)

	# 5. Thin geometry overlays: crosswalks, stop lines, yellow centerlines
	_build_road_markings(roads_root, ns_asphalt_w, ew_asphalt_w)

	# 6. Helipad staging for chunk (0, 0)
	if coord == Vector2i.ZERO:
		_build_helipad_staging(roads_root)

func _build_road_markings(parent: Node3D, ns_w: float, ew_w: float) -> void:
	var markings_node := Node3D.new()
	markings_node.name = "RoadMarkings"
	parent.add_child(markings_node)

	var line_y: float = 0.153
	var stop_mat := LineWhiteMat
	var dash_mat := LineMat
	var wear_mat := AsphaltWornMat

	# North intersection approach: stop line and crosswalk
	var n_stop := MeshInstance3D.new()
	n_stop.name = "N_StopLine"
	var n_sm := BoxMesh.new()
	n_sm.size = Vector3(ns_w * 0.9, 0.015, 0.45)
	n_sm.material = stop_mat
	n_stop.mesh = n_sm
	n_stop.position = Vector3(0.0, line_y, -ew_w * 0.5 - 1.2)
	n_stop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings_node.add_child(n_stop)

	for stripe_x in [-ns_w * 0.35, -ns_w * 0.18, ns_w * 0.18, ns_w * 0.35]:
		var stripe := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(0.55, 0.015, 2.4)
		stm.material = stop_mat
		stripe.mesh = stm
		stripe.position = Vector3(stripe_x, line_y, -ew_w * 0.5 - 3.2)
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(stripe)

	# South intersection approach: stop line and crosswalk
	var s_stop := MeshInstance3D.new()
	s_stop.name = "S_StopLine"
	var s_sm := BoxMesh.new()
	s_sm.size = Vector3(ns_w * 0.9, 0.015, 0.45)
	s_sm.material = stop_mat
	s_stop.mesh = s_sm
	s_stop.position = Vector3(0.0, line_y, ew_w * 0.5 + 1.2)
	s_stop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings_node.add_child(s_stop)

	for stripe_x in [-ns_w * 0.35, -ns_w * 0.18, ns_w * 0.18, ns_w * 0.35]:
		var stripe := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(0.55, 0.015, 2.4)
		stm.material = stop_mat
		stripe.mesh = stm
		stripe.position = Vector3(stripe_x, line_y, ew_w * 0.5 + 3.2)
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(stripe)

	# East intersection approach: stop line and crosswalk
	var e_stop := MeshInstance3D.new()
	e_stop.name = "E_StopLine"
	var e_sm := BoxMesh.new()
	e_sm.size = Vector3(0.45, 0.015, ew_w * 0.9)
	e_sm.material = stop_mat
	e_stop.mesh = e_sm
	e_stop.position = Vector3(ns_w * 0.5 + 1.2, line_y, 0.0)
	e_stop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings_node.add_child(e_stop)

	for stripe_z in [-ew_w * 0.35, -ew_w * 0.18, ew_w * 0.18, ew_w * 0.35]:
		var stripe := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(2.4, 0.015, 0.55)
		stm.material = stop_mat
		stripe.mesh = stm
		stripe.position = Vector3(ns_w * 0.5 + 3.2, line_y, stripe_z)
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(stripe)

	# West intersection approach: stop line and crosswalk
	var w_stop := MeshInstance3D.new()
	w_stop.name = "W_StopLine"
	var w_sm := BoxMesh.new()
	w_sm.size = Vector3(0.45, 0.015, ew_w * 0.9)
	w_sm.material = stop_mat
	w_stop.mesh = w_sm
	w_stop.position = Vector3(-ns_w * 0.5 - 1.2, line_y, 0.0)
	w_stop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings_node.add_child(w_stop)

	for stripe_z in [-ew_w * 0.35, -ew_w * 0.18, ew_w * 0.18, ew_w * 0.35]:
		var stripe := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(2.4, 0.015, 0.55)
		stm.material = stop_mat
		stripe.mesh = stm
		stripe.position = Vector3(-ns_w * 0.5 - 3.2, line_y, stripe_z)
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(stripe)

	# Dashed yellow centerlines (NS road)
	var z_cur: float = -ew_w * 0.5 - 6.5
	while z_cur > -62.0:
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.24, 0.015, 2.6)
		dm.material = dash_mat
		dash.mesh = dm
		dash.position = Vector3(0.0, line_y, z_cur)
		dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(dash)
		z_cur -= 5.2

	z_cur = ew_w * 0.5 + 6.5
	while z_cur < 62.0:
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(0.24, 0.015, 2.6)
		dm.material = dash_mat
		dash.mesh = dm
		dash.position = Vector3(0.0, line_y, z_cur)
		dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(dash)
		z_cur += 5.2

	# Dashed yellow centerlines (EW road)
	var x_cur: float = ns_w * 0.5 + 6.5
	while x_cur < 62.0:
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(2.6, 0.015, 0.24)
		dm.material = dash_mat
		dash.mesh = dm
		dash.position = Vector3(x_cur, line_y, 0.0)
		dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(dash)
		x_cur += 5.2

	x_cur = -ns_w * 0.5 - 6.5
	while x_cur > -62.0:
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(2.6, 0.015, 0.24)
		dm.material = dash_mat
		dash.mesh = dm
		dash.position = Vector3(x_cur, line_y, 0.0)
		dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(dash)
		x_cur -= 5.2

	# Asphalt wear / utility patches
	var patch1 := MeshInstance3D.new()
	var pm1 := BoxMesh.new()
	pm1.size = Vector3(2.6, 0.01, 3.8)
	pm1.material = wear_mat
	patch1.mesh = pm1
	patch1.position = Vector3(-ns_w * 0.25, line_y - 0.002, -26.0)
	patch1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings_node.add_child(patch1)

	var patch2 := MeshInstance3D.new()
	var pm2 := BoxMesh.new()
	pm2.size = Vector3(3.6, 0.01, 2.2)
	pm2.material = wear_mat
	patch2.mesh = pm2
	patch2.position = Vector3(24.0, line_y - 0.002, ew_w * 0.25)
	patch2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings_node.add_child(patch2)

	# Lane direction arrows (North and South intersection approaches)
	var arrow_n_stem := MeshInstance3D.new()
	var ans_m := BoxMesh.new()
	ans_m.size = Vector3(0.35, 0.015, 2.2)
	ans_m.material = stop_mat
	arrow_n_stem.mesh = ans_m
	arrow_n_stem.position = Vector3(-ns_w * 0.25, line_y, -ew_w * 0.5 - 10.0)
	arrow_n_stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings_node.add_child(arrow_n_stem)

	var arrow_s_stem := MeshInstance3D.new()
	var ass_m := BoxMesh.new()
	ass_m.size = Vector3(0.35, 0.015, 2.2)
	ass_m.material = stop_mat
	arrow_s_stem.mesh = ass_m
	arrow_s_stem.position = Vector3(ns_w * 0.25, line_y, ew_w * 0.5 + 10.0)
	arrow_s_stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings_node.add_child(arrow_s_stem)

	# Yellow corner curb markings (hazard curb paint near intersection)
	var curb_corners: Array[Vector3] = [
		Vector3(-ns_w * 0.5 - 0.35, line_y - 0.005, -ew_w * 0.5 - 3.0),
		Vector3(ns_w * 0.5 + 0.35, line_y - 0.005, -ew_w * 0.5 - 3.0),
		Vector3(-ns_w * 0.5 - 0.35, line_y - 0.005, ew_w * 0.5 + 3.0),
		Vector3(ns_w * 0.5 + 0.35, line_y - 0.005, ew_w * 0.5 + 3.0)
	]
	for c_pos in curb_corners:
		var curb_strip := MeshInstance3D.new()
		var csm := BoxMesh.new()
		csm.size = Vector3(0.35, 0.015, 4.0)
		csm.material = dash_mat
		curb_strip.mesh = csm
		curb_strip.position = c_pos
		curb_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		markings_node.add_child(curb_strip)

func _build_helipad_staging(parent: Node3D) -> void:
	var staging := Node3D.new()
	staging.name = "HelipadStaging"
	parent.add_child(staging)

	# 1. Main Landing Apron (24m x 24m)
	var pad_base := MeshInstance3D.new()
	pad_base.name = "PadBase"
	var bm := BoxMesh.new()
	bm.size = Vector3(24.0, 0.14, 24.0)
	bm.material = AsphaltMat
	pad_base.mesh = bm
	pad_base.position = Vector3(0.0, 0.07, 0.0)
	staging.add_child(pad_base)

	# 2. Outer Safety Perimeter Rim (Yellow hazard border)
	var rim_mesh := MeshInstance3D.new()
	rim_mesh.name = "PerimeterRim"
	var rm := BoxMesh.new()
	rm.size = Vector3(23.6, 0.15, 23.6)
	rm.material = LineMat
	rim_mesh.mesh = rm
	rim_mesh.position = Vector3(0.0, 0.075, 0.0)
	staging.add_child(rim_mesh)

	var inner_pad := MeshInstance3D.new()
	inner_pad.name = "InnerPad"
	var ipm := BoxMesh.new()
	ipm.size = Vector3(22.0, 0.16, 22.0)
	ipm.material = ConcreteMat
	inner_pad.mesh = ipm
	inner_pad.position = Vector3(0.0, 0.08, 0.0)
	staging.add_child(inner_pad)

	# 3. Yellow 'H' Marking in Center
	var h_left := MeshInstance3D.new()
	h_left.name = "H_Left"
	var hm_bar := BoxMesh.new()
	hm_bar.size = Vector3(0.9, 0.02, 7.5)
	hm_bar.material = LineMat
	h_left.mesh = hm_bar
	h_left.position = Vector3(-2.5, 0.17, 0.0)
	staging.add_child(h_left)

	var h_right := MeshInstance3D.new()
	h_right.name = "H_Right"
	h_right.mesh = hm_bar
	h_right.position = Vector3(2.5, 0.17, 0.0)
	staging.add_child(h_right)

	var h_mid := MeshInstance3D.new()
	h_mid.name = "H_Mid"
	var hm_mid := BoxMesh.new()
	hm_mid.size = Vector3(4.5, 0.02, 0.9)
	hm_mid.material = LineMat
	h_mid.mesh = hm_mid
	h_mid.position = Vector3(0.0, 0.17, 0.0)
	staging.add_child(h_mid)

	# 4. Perimeter Boundary Lights (4 corners) with emissive cyan lenses
	var light_mat := StandardMaterial3D.new()
	light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light_mat.albedo_color = Color(0.31, 0.88, 0.93, 1.0)

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.15, 0.17, 0.20, 1.0)
	pole_mat.roughness = 0.9

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.15
	pole_mesh.height = 0.7
	pole_mesh.material = pole_mat

	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.22
	lens_mesh.height = 0.44
	lens_mesh.material = light_mat

	var light_corners: Array[Vector3] = [
		Vector3(-11.0, 0.0, -11.0),
		Vector3(11.0, 0.0, -11.0),
		Vector3(-11.0, 0.0, 11.0),
		Vector3(11.0, 0.0, 11.0)
	]

	for idx: int in range(light_corners.size()):
		var lp := Node3D.new()
		lp.name = "PerimeterLight_%d" % idx
		lp.position = light_corners[idx]

		var pole := MeshInstance3D.new()
		pole.mesh = pole_mesh
		pole.position = Vector3(0.0, 0.35, 0.0)
		lp.add_child(pole)

		var lens := MeshInstance3D.new()
		lens.mesh = lens_mesh
		lens.position = Vector3(0.0, 0.75, 0.0)
		lp.add_child(lens)

		staging.add_child(lp)

	# 5. Support Staging Props (Off to the sides, clear takeoff path)
	var truck := Node3D.new()
	truck.name = "SupportTruck"
	truck.position = Vector3(14.5, 0.0, 8.5)
	truck.rotation.y = deg_to_rad(-25.0)

	var truck_mat := StandardMaterial3D.new()
	truck_mat.albedo_color = Color(0.24, 0.28, 0.32, 1.0)
	truck_mat.roughness = 0.8

	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = Color(0.18, 0.35, 0.42, 1.0)
	cab_mat.roughness = 0.7

	var chassis := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(2.4, 1.1, 5.2)
	cm.material = truck_mat
	chassis.mesh = cm
	chassis.position = Vector3(0.0, 0.8, 0.0)
	truck.add_child(chassis)

	var cab := MeshInstance3D.new()
	var kbm := BoxMesh.new()
	kbm.size = Vector3(2.2, 1.0, 1.8)
	kbm.material = cab_mat
	cab.mesh = kbm
	cab.position = Vector3(0.0, 1.6, -1.2)
	truck.add_child(cab)
	staging.add_child(truck)

	# B. Supply Crates Stack (at X=-14m, Z=+9m)
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.42, 0.36, 0.26, 1.0)
	crate_mat.roughness = 0.9

	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(1.3, 1.1, 1.3)
	crate_mesh.material = crate_mat

	var crate_positions: Array[Vector3] = [
		Vector3(-14.2, 0.55, 8.5),
		Vector3(-14.2, 0.55, 10.0),
		Vector3(-12.8, 0.55, 9.2),
		Vector3(-13.5, 1.65, 9.2)
	]
	for c_idx: int in range(crate_positions.size()):
		var crate := MeshInstance3D.new()
		crate.name = "SupplyCrate_%d" % c_idx
		crate.mesh = crate_mesh
		crate.position = crate_positions[c_idx]
		staging.add_child(crate)

	# C. Restrained Perimeter Security Fencing
	var fence_mat := StandardMaterial3D.new()
	fence_mat.albedo_color = Color(0.20, 0.22, 0.25, 1.0)
	var fence_mesh := BoxMesh.new()
	fence_mesh.size = Vector3(12.0, 0.9, 0.15)
	fence_mesh.material = fence_mat

	var fence1 := MeshInstance3D.new()
	fence1.name = "SecurityFence_East"
	fence1.mesh = fence_mesh
	fence1.position = Vector3(13.5, 0.45, 13.0)
	staging.add_child(fence1)

	var fence2 := MeshInstance3D.new()
	fence2.name = "SecurityFence_West"
	fence2.mesh = fence_mesh
	fence2.position = Vector3(-13.5, 0.45, 13.0)
	staging.add_child(fence2)

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
			props_root.add_child(v_node)

func _build_tree_clusters(rng: RandomNumberGenerator) -> void:
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

	for idx in range(tree_positions.size()):
		var t_inst := TreeClusterScene.instantiate() as Node3D
		if t_inst:
			t_inst.name = "TreeCluster_%d" % idx
			var scale_val: float = rng.randf_range(0.85, 1.22)
			t_inst.position = tree_positions[idx]
			t_inst.scale = Vector3(scale_val, scale_val, scale_val)
			t_inst.rotation.y = rng.randf_range(0.0, TAU)
			props_root.add_child(t_inst)

func _build_micro_scenes(rng: RandomNumberGenerator) -> void:
	if district_type == DistrictType.INDUSTRIAL:
		if rng.randf() < 0.6:
			var b1 := BarrierScene.instantiate() as Node3D
			if b1:
				b1.name = "RoadsideBarrier_1"
				b1.position = Vector3(13.2, 0.0, 24.0)
				b1.rotation.y = deg_to_rad(12.0)
				props_root.add_child(b1)
			var b2 := BarrierScene.instantiate() as Node3D
			if b2:
				b2.name = "RoadsideBarrier_2"
				b2.position = Vector3(13.2, 0.0, 28.0)
				b2.rotation.y = deg_to_rad(-8.0)
				props_root.add_child(b2)
	elif district_type == DistrictType.RESIDENTIAL:
		if rng.randf() < 0.4:
			var b1 := BarrierScene.instantiate() as Node3D
			if b1:
				b1.name = "RoadsideBarrier_1"
				b1.position = Vector3(-13.2, 0.0, -22.0)
				b1.rotation.y = deg_to_rad(5.0)
				props_root.add_child(b1)

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
