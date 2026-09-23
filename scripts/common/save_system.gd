class_name SaveSystem
extends RefCounted

## Persistent save system for Hangar upgrades, accessibility settings, and run telemetry.

const SAVE_PATH: String = "user://save_data.json"
static var low_particles: bool = false

static func get_default_data() -> Dictionary:
	return {
		"salvage": 0,
		"selected_loadout": "balanced",
		"upgrades": {
			"scavenger_rig": 0,
			"rotor_armor": 0,
			"magnet_radius": 0,
			"extraction_insurance": false
		},
		"settings": {
			"screen_shake_enabled": true,
			"screen_shake_intensity": 1.0,
			"damage_flash_enabled": true,
			"damage_flash_intensity": 1.0,
			"reduced_flashing": false,
			"volume_master": 1.0,
			"volume_sfx": 1.0,
			"volume_music": 1.0,
			"move_deadzone": 0.15,
			"aim_deadzone": 0.12,
			"aim_sensitivity": 1.0,
			"aim_exponent": 1.45,
			"controller_glyph_mode": "auto",
			"high_contrast_indicators": false,
			"aim_assist_intensity": 1.0,
			"camera_shake": 1.0,
			"screen_vignette": true,
			"camera_mode": "chase",
			"graphics_preset": "medium",
			"damage_numbers": "all"
		},
		"telemetry": {
			"total_runs": 0,
			"total_kills": 0,
			"total_salvage_banked": 0,
			"boss_victories": 0,
			"recent_runs": []
		}
	}

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return get_default_data()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return get_default_data()

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_str)
	if err == OK and json.data is Dictionary:
		var merged := get_default_data()
		var incoming: Dictionary = json.data as Dictionary
		for k in incoming.keys():
			if merged.has(k) and merged[k] is Dictionary and incoming[k] is Dictionary:
				var sub_merged: Dictionary = (merged[k] as Dictionary).duplicate()
				var sub_inc: Dictionary = incoming[k] as Dictionary
				for sub_k in sub_inc.keys():
					sub_merged[sub_k] = sub_inc[sub_k]
				merged[k] = sub_merged
			else:
				merged[k] = incoming[k]
		return merged

	return get_default_data()

static func save_data(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func get_selected_loadout() -> String:
	var data := load_data()
	return String(data.get("selected_loadout", "balanced"))

static func set_selected_loadout(loadout_id: String) -> void:
	var data := load_data()
	data["selected_loadout"] = loadout_id
	save_data(data)

static func get_all_settings() -> Dictionary:
	var data := load_data()
	return data.get("settings", {}).duplicate()

static func get_setting(key: String, default_val: Variant = null) -> Variant:
	var data := load_data()
	var settings: Dictionary = data.get("settings", {})
	if settings.has(key):
		return settings[key]
	return default_val

static func set_setting(key: String, val: Variant) -> void:
	var data := load_data()
	if not data.has("settings") or not (data["settings"] is Dictionary):
		data["settings"] = {}
	data["settings"][key] = val
	save_data(data)
	var tree := Engine.get_main_loop() as SceneTree
	var eb: Node = tree.root.get_node_or_null("EventBus") if tree and tree.root else null
	if eb and eb.has_signal("setting_changed"):
		eb.emit_signal("setting_changed", key, val)
	if key == "graphics_preset" and val is String:
		apply_graphics_preset(val, tree)

static func apply_graphics_preset(preset_name: String, tree: SceneTree = null) -> void:
	if not tree:
		tree = Engine.get_main_loop() as SceneTree
	preset_name = preset_name.to_lower()
	low_particles = preset_name == "low"
	var shadow_dist: float = 150.0
	var glow_int: float = 0.12
	var glow_hdr: float = 1.15
	var fog_begin: float = 160.0
	var fog_end: float = 400.0
	var max_explosions: int = 6
	var max_sparks: int = 12
	var max_flashes: int = 12
	var effect_dist: float = 140.0
	var detail_rad: int = 1
	var hlod_rad: int = 3

	match preset_name:
		"low":
			shadow_dist = 110.0
			glow_int = 0.08
			glow_hdr = 1.25
			fog_begin = 140.0
			fog_end = 340.0
			max_explosions = 4
			max_sparks = 6
			max_flashes = 8
			effect_dist = 110.0
			hlod_rad = 2
		"high":
			shadow_dist = 180.0
			glow_int = 0.15
			glow_hdr = 1.10
			fog_begin = 180.0
			fog_end = 450.0
			max_explosions = 8
			max_sparks = 16
			max_flashes = 16
			effect_dist = 160.0
			hlod_rad = 3
		_: # "medium" default
			shadow_dist = 150.0
			glow_int = 0.12
			glow_hdr = 1.15
			fog_begin = 160.0
			fog_end = 400.0
			max_explosions = 6
			max_sparks = 12
			max_flashes = 12
			effect_dist = 140.0
			hlod_rad = 3

	if tree:
		var root := tree.current_scene if tree.current_scene else tree.root
		if root:
			var light := root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
			if light:
				light.directional_shadow_max_distance = shadow_dist
			var env_node := root.find_child("WorldEnvironment", true, false) as WorldEnvironment
			if env_node and env_node.environment:
				env_node.environment.glow_intensity = glow_int
				env_node.environment.glow_hdr_threshold = glow_hdr
				env_node.environment.glow_bloom = 0.0
				env_node.environment.fog_enabled = true
				env_node.environment.fog_mode = Environment.FOG_MODE_DEPTH
				env_node.environment.fog_depth_begin = fog_begin
				env_node.environment.fog_depth_end = fog_end
				env_node.environment.volumetric_fog_enabled = false
			var streamer := root.find_child("CityWorldStreamer", true, false)
			if streamer:
				if streamer.has_method("apply_graphics_preset"):
					streamer.call("apply_graphics_preset", preset_name)
				else:
					if "full_detail_radius" in streamer:
						streamer.full_detail_radius = detail_rad
					if "hlod_radius" in streamer:
						streamer.hlod_radius = hlod_rad
	if VfxPool.instance:
		VfxPool.instance.max_active_explosions = max_explosions
		VfxPool.instance.max_active_sparks = max_sparks
		VfxPool.instance.max_active_flashes = max_flashes
		VfxPool.instance.effect_distance = effect_dist
	if DamageNumberManager.instance:
		DamageNumberManager.instance.set_preset(preset_name)
	if tree:
		_apply_particle_budget(tree.root, preset_name == "low")

static func _apply_particle_budget(node: Node, low: bool) -> void:
	# Run only on preset changes/startup, never per frame.
	if node is GPUParticles3D:
		var particles: GPUParticles3D = node as GPUParticles3D
		particles.amount_ratio = 0.5 if low else 1.0
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.visibility_range_end = 110.0 if low else 150.0
	for child in node.get_children():
		_apply_particle_budget(child, low)


static func record_run_telemetry(run_stats: Dictionary) -> void:
	var data := load_data()
	if not data.has("telemetry") or not (data["telemetry"] is Dictionary):
		data["telemetry"] = get_default_data()["telemetry"]

	var tel: Dictionary = data["telemetry"] as Dictionary
	tel["total_runs"] = int(tel.get("total_runs", 0)) + 1
	tel["total_kills"] = int(tel.get("total_kills", 0)) + int(run_stats.get("enemies_killed", 0))
	tel["total_salvage_banked"] = int(tel.get("total_salvage_banked", 0)) + int(run_stats.get("salvage_banked", 0))
	if bool(run_stats.get("boss_defeated", false)):
		tel["boss_victories"] = int(tel.get("boss_victories", 0)) + 1

	var recent: Array = tel.get("recent_runs", []) as Array
	recent.append(run_stats)
	# Keep only last 10 runs
	while recent.size() > 10:
		recent.remove_at(0)
	tel["recent_runs"] = recent

	data["telemetry"] = tel
	save_data(data)
