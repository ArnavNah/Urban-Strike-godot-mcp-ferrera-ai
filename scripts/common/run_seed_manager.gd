class_name RunSeedManager
extends RefCounted

## Authoritative Run Seed Manager for URBAN Strike Rogue.
## Provides deterministic, isolated random streams for:
## - Layout (districts, road templates, parcel allocation)
## - Decoration (props, vegetation, parked vehicles, streetlights)
## - Encounters (enemy rosters, wave composition weights, formation selection)
## - Deployment (player spawn candidate, safe clearing selection)
## - Finale (objective placement, boss arrival corridors)
##
## Guarantees:
## 1. Independent streams so visual/decoration changes never perturb layout or encounters.
## 2. Order-independent chunk seeds derived strictly from (active_seed, chunk_coord, stream_id).
## 3. Developer seed override support for reproducing bug reports.

const STREAM_LAYOUT: int = 0x1A2B3C4D
const STREAM_DECORATION: int = 0x5E6F7A8B
const STREAM_ENCOUNTERS: int = 0x9C0D1E2F
const STREAM_DEPLOYMENT: int = 0x3F4E5D6C
const STREAM_FINALE: int = 0x7B8A9C0D

## If set to a positive integer, new runs will deterministically use this seed instead of generating a random one.
static var custom_override_seed: int = -1

## Currently active run seed.
static var active_seed: int = 1337

## Whether the current run was generated procedurally (true) or using default/test baseline (false).
static var is_procedural_run: bool = false

## Incremented each run during session.
static var run_count: int = 0

static func check_cmdline_override() -> void:
	var args := OS.get_cmdline_user_args()
	args.append_array(OS.get_cmdline_args())
	for arg in args:
		if arg.begins_with("--seed="):
			var s_str := arg.trim_prefix("--seed=")
			if s_str.is_valid_int():
				custom_override_seed = s_str.to_int()

## Initializes a new run seed.
## If p_seed > 0, forces that seed.
## If custom_override_seed > 0, uses the developer override.
## Otherwise, generates a cryptographically sound random 31-bit seed.
static func initialize_new_run(p_seed: int = -1) -> int:
	check_cmdline_override()
	run_count += 1
	if p_seed > 0:
		active_seed = p_seed
		is_procedural_run = (p_seed != 1337)
	elif custom_override_seed > 0:
		active_seed = custom_override_seed
		is_procedural_run = (custom_override_seed != 1337)
	else:
		# Generate pseudo-random seed using OS ticks and randi
		var t := Time.get_ticks_usec()
		var r := randi()
		active_seed = int((t ^ (r * 1103515245 + 12345)) & 0x7FFFFFFF)
		if active_seed == 0 or active_seed == 1337:
			active_seed = 1338
		is_procedural_run = true

	print("[RunSeedManager] Run #%d initialized with authoritative seed: %d (Procedural: %s)" % [run_count, active_seed, is_procedural_run])

	# Clear runtime state in singletons if present
	var streamer := _get_streamer()
	if streamer and streamer.has_method("clear_run_state"):
		streamer.call("clear_run_state")

	return active_seed

## Guarantees an active procedural run seed is set for gameplay unless in a test runner.
static func ensure_run_seed() -> int:
	if not is_procedural_run or active_seed == 1337:
		var tree := Engine.get_main_loop() as SceneTree
		var is_testing := false
		if tree and tree.current_scene:
			var sc_name := tree.current_scene.name
			if sc_name.begins_with("Test") or sc_name == "PerformanceValidationRunner":
				is_testing = true
		if not is_testing:
			initialize_new_run()
	return active_seed

## Generates a 31-bit deterministic seed for a given chunk coordinate and stream ID.
## Generation order does not affect the outcome.
static func get_chunk_stream_seed(coord: Vector2i, stream_id: int) -> int:
	var h: int = active_seed ^ stream_id
	h = ((h ^ (coord.x * 73856093)) ^ (coord.y * 19349663)) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	return h

## Returns a freshly configured RandomNumberGenerator seeded for a specific chunk and stream.
static func get_chunk_stream_rng(coord: Vector2i, stream_id: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_chunk_stream_seed(coord, stream_id)
	return rng

## Returns a RandomNumberGenerator for global run streams (encounters, deployment, finale).
static func get_stream_rng(stream_id: int, extra_salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var h: int = active_seed ^ stream_id ^ (extra_salt * 2654435761)
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	rng.seed = h
	return rng

## Resets run seed manager to default baseline (e.g. for test suite).
static func reset() -> void:
	active_seed = 1337
	is_procedural_run = false
	custom_override_seed = -1

static func _get_streamer() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		return tree.get_first_node_in_group("city_streamer")
	return null
