class_name GuardedCache
extends "res://scripts/encounters/base_encounter.gd"

## Guarded Upgrade Cache encounter.
## An encrypted military container locked by an active guard squad.
## Once guards are neutralized, approaching the cache triggers a free level-up upgrade draft.

var is_unlocked: bool = false
var guards: Array[Node] = []
var _container_mesh: MeshInstance3D = null
var _status_light: OmniLight3D = null
var _time: float = 0.0

func _ready() -> void:
	super._ready()
	if is_completed:
		return
	var saved := BaseEncounter.get_encounter_state(encounter_id)
	if saved.get("used", false):
		is_completed = true
		queue_free()
		return

	_build_visuals()

	if saved.get("unlocked", false):
		is_unlocked = true
		_update_unlocked_visuals()
	else:
		_spawn_guards.call_deferred()

func _build_visuals() -> void:
	_container_mesh = MeshInstance3D.new()
	_container_mesh.name = "CacheContainer"
	var box := BoxMesh.new()
	box.size = Vector3(3.2, 1.8, 2.4)
	_container_mesh.mesh = box
	_container_mesh.position = Vector3(0.0, 0.9, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.22, 0.28, 1.0)
	mat.metallic = 0.85
	mat.roughness = 0.35
	_container_mesh.material_override = mat
	add_child(_container_mesh)

	_status_light = OmniLight3D.new()
	_status_light.name = "StatusLight"
	_status_light.light_color = Color(1.0, 0.15, 0.15, 1.0) # Red = Locked
	_status_light.light_energy = 2.0
	_status_light.omni_range = 10.0
	_status_light.position = Vector3(0.0, 2.2, 0.0)
	add_child(_status_light)

func _spawn_guards() -> void:
	if is_completed or not is_inside_tree():
		return
	var tank_scene: PackedScene = load("res://scenes/enemies/tank.tscn")
	var parent := get_parent() if get_parent() else get_tree().current_scene
	if not tank_scene or not parent:
		# If tank scene is unavailable, unlock directly
		is_unlocked = true
		_update_unlocked_visuals()
		return

	# Align 2 guardian tanks along the primary road/corridor axis
	var offsets: Array[Vector3] = []
	if absf(position.x) < 5.0:
		# Road runs along Z
		offsets = [Vector3(0.0, 0.5, -14.0), Vector3(0.0, 0.5, 14.0)]
	else:
		# Road runs along X
		offsets = [Vector3(-14.0, 0.5, 0.0), Vector3(14.0, 0.5, 0.0)]

	for off in offsets:
		var tank: Node3D = tank_scene.instantiate() as Node3D
		if tank:
			parent.add_child(tank)
			tank.global_position = global_position + off
			tank.add_to_group("cache_guards")
			guards.append(tank)

func _physics_process(delta: float) -> void:
	if is_completed:
		return

	_time += delta

	# Check guards state
	if not is_unlocked:
		var has_living_guards: bool = false
		for g in guards:
			if is_instance_valid(g) and not g.is_queued_for_deletion():
				var alive_val = g.get("is_alive")
				if alive_val != null:
					if not bool(alive_val):
						continue
				elif g.has_meta("is_alive"):
					if not bool(g.get_meta("is_alive")):
						continue
				has_living_guards = true
				break
		if not has_living_guards and not guards.is_empty():
			is_unlocked = true
			BaseEncounter.set_encounter_state(encounter_id, {"unlocked": true})
			_update_unlocked_visuals()

	# If unlocked, check player collection
	if is_unlocked:
		var player := get_active_player()
		if player and is_player_in_range(player):
			_collect_cache(player)

func _update_unlocked_visuals() -> void:
	if _status_light:
		_status_light.light_color = Color(0.2, 1.0, 0.4, 1.0) # Green = Unlocked
		_status_light.light_energy = 3.5
	if _container_mesh and _container_mesh.material_override:
		var mat := _container_mesh.material_override as StandardMaterial3D
		mat.albedo_color = Color(0.12, 0.35, 0.22, 1.0)

func _collect_cache(player: PlayerHelicopter) -> void:
	BaseEncounter.set_encounter_state(encounter_id, {"used": true})
	complete_encounter()

	# 1. Trigger free upgrade draft in UpgradeManager
	if UpgradeManager.instance:
		UpgradeManager.instance.queue_free_upgrade_choice()

	# 2. Munitions reward: replenish 6 missiles
	if is_instance_valid(player) and player.missile_pod and player.missile_pod.has_method("replenish_ammo"):
		player.missile_pod.replenish_ammo(6)

	# 3. Banked salvage bonus
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage"):
		gm.call("add_salvage", 80)
	else:
		var data := SaveSystem.load_data()
		var cur_salvage: int = int(data.get("salvage", 0))
		data["salvage"] = cur_salvage + 80
		SaveSystem.save_data(data)

	# 4. Burst of salvage gems around container
	var gem_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn")
	var parent := get_parent() if get_parent() else get_tree().current_scene
	if gem_scene and parent:
		for i in range(4):
			var angle: float = (float(i) / 4.0) * TAU
			var spawn_pos: Vector3 = global_position + Vector3(cos(angle) * 2.5, 1.0, sin(angle) * 2.5)
			var gem: Node3D = gem_scene.instantiate() as Node3D
			if gem:
				parent.add_child(gem)
				gem.global_position = spawn_pos
				if "xp_value" in gem:
					gem.set("xp_value", 25)

	# 5. Visual completion
	if _status_light:
		_status_light.light_energy = 0.0
	queue_free()

func get_encounter_display_type() -> String:
	return "CACHE"

func get_encounter_status_text() -> String:
	return "READY" if is_unlocked else "LOCKED"

func get_encounter_color() -> Color:
	return Color(0.20, 0.95, 0.40, 1.0) if is_unlocked else Color(0.95, 0.22, 0.22, 1.0)
