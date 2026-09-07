class_name SaveSystem
extends RefCounted

## Persistent save system for Hangar upgrades, accessibility settings, and run telemetry.

const SAVE_PATH: String = "user://save_data.json"

static func get_default_data() -> Dictionary:
	return {
		"salvage": 0,
		"upgrades": {
			"scavenger_rig": 0,
			"rotor_armor": 0,
			"magnet_radius": 0,
			"extraction_insurance": false
		},
		"settings": {
			"move_deadzone": 0.15,
			"aim_deadzone": 0.12,
			"aim_assist_intensity": 1.0,
			"camera_shake": 1.0,
			"screen_vignette": true
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
