class_name RewardLocation
extends "res://scripts/encounters/base_encounter.gd"

## World reward location supporting 3 variants:
## - REPAIR_STATION: Emergency landing pad that continuously restores hull HP while in airspace.
## - AMMO_DEPOT: Munitions cache that replenishes guided missile salvos.
## - EXPLORATION_CACHE: Alleyway salvage cache that detonates into a cluster of salvage gems upon proximity.

enum RewardType {
	REPAIR_STATION,
	AMMO_DEPOT,
	EXPLORATION_CACHE
}

@export var reward_type: RewardType = RewardType.REPAIR_STATION
@export var max_resource_pool: float = 120.0
@export var transfer_rate: float = 20.0 # HP per second or missiles per cycle

var current_resource_pool: float = 120.0
var _pulse_timer: float = 0.0
var _pad_mesh: MeshInstance3D = null
var _halo_light: OmniLight3D = null

func _ready() -> void:
	super._ready()
	if is_completed:
		return
	var saved := BaseEncounter.get_encounter_state(encounter_id)
	if saved.get("used", false):
		is_completed = true
		queue_free()
		return
	current_resource_pool = max_resource_pool
	_build_visuals()

func _build_visuals() -> void:
	_pad_mesh = MeshInstance3D.new()
	_pad_mesh.name = "RewardPad"
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 0.2, 8.0)
	_pad_mesh.mesh = box
	_pad_mesh.position = Vector3(0.0, 0.1, 0.0)

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.8
	match reward_type:
		RewardType.REPAIR_STATION:
			mat.albedo_color = Color(0.12, 0.45, 0.25, 1.0) # Medical Green
		RewardType.AMMO_DEPOT:
			mat.albedo_color = Color(0.90, 0.55, 0.12, 1.0) # Munitions Amber
		RewardType.EXPLORATION_CACHE:
			mat.albedo_color = Color(0.25, 0.60, 0.95, 1.0) # Salvage Blue

	_pad_mesh.material_override = mat
	add_child(_pad_mesh)

	_halo_light = OmniLight3D.new()
	_halo_light.name = "HaloLight"
	_halo_light.omni_range = 14.0
	_halo_light.position = Vector3(0.0, 1.5, 0.0)
	match reward_type:
		RewardType.REPAIR_STATION:
			_halo_light.light_color = Color(0.2, 1.0, 0.4, 1.0)
		RewardType.AMMO_DEPOT:
			_halo_light.light_color = Color(1.0, 0.65, 0.15, 1.0)
		RewardType.EXPLORATION_CACHE:
			_halo_light.light_color = Color(0.3, 0.7, 1.0, 1.0)
	add_child(_halo_light)

func _physics_process(_delta: float) -> void:
	if is_completed:
		return

	var player := get_active_player()
	if not player or not is_player_in_range(player):
		return

	match reward_type:
		RewardType.REPAIR_STATION:
			_process_repair(player)
		RewardType.AMMO_DEPOT:
			_process_ammo(player)
		RewardType.EXPLORATION_CACHE:
			_process_exploration_cache(player)

func _process_repair(player: PlayerHelicopter) -> void:
	# Immediate field repair: instant +50 HP benefit or salvage if full
	var healed: float = 0.0
	if player.current_health < player.max_health:
		healed = player.heal(50.0)
	elif player.current_health >= player.max_health:
		# Already full health: reward detour with immediate salvage
		var gm := get_tree().get_first_node_in_group("game_manager")
		if gm and gm.has_method("add_salvage"):
			gm.call("add_salvage", 35)

	BaseEncounter.set_encounter_state(encounter_id, {"used": true})
	complete_encounter()

	if _halo_light:
		_halo_light.light_color = Color(0.2, 1.0, 0.4, 0.4)
		_halo_light.light_energy = 0.5
	if _pad_mesh and _pad_mesh.material_override:
		(_pad_mesh.material_override as StandardMaterial3D).albedo_color = Color(0.1, 0.22, 0.15, 0.5)

func _process_ammo(player: PlayerHelicopter) -> void:
	# Immediate munitions depot: instant full missile replenishment (+6) or salvage if full
	var gained: int = 0
	if player.missile_pod and player.missile_pod.has_method("replenish_ammo"):
		gained = player.missile_pod.replenish_ammo(6)
	if gained == 0:
		# Already full on missiles: reward detour with immediate salvage
		var gm := get_tree().get_first_node_in_group("game_manager")
		if gm and gm.has_method("add_salvage"):
			gm.call("add_salvage", 35)

	BaseEncounter.set_encounter_state(encounter_id, {"used": true})
	complete_encounter()

	if _halo_light:
		_halo_light.light_color = Color(1.0, 0.65, 0.15, 0.4)
		_halo_light.light_energy = 0.5
	if _pad_mesh and _pad_mesh.material_override:
		(_pad_mesh.material_override as StandardMaterial3D).albedo_color = Color(0.25, 0.18, 0.10, 0.5)

func _process_exploration_cache(_player: PlayerHelicopter) -> void:
	BaseEncounter.set_encounter_state(encounter_id, {"used": true})
	complete_encounter()

	# Burst into 8 salvage gems
	var gem_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn")
	var parent := get_parent() if get_parent() else get_tree().current_scene
	if gem_scene and parent:
		for i in range(8):
			var angle: float = (float(i) / 8.0) * TAU
			var spawn_pos: Vector3 = global_position + Vector3(cos(angle) * 3.5, 1.0, sin(angle) * 3.5)
			var gem: Node3D = gem_scene.instantiate() as Node3D
			if gem:
				parent.add_child(gem)
				gem.global_position = spawn_pos
				if "xp_value" in gem:
					gem.set("xp_value", 20)

	# Direct salvage grant through GameManager (with offline save fallback)
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage"):
		gm.call("add_salvage", 60)
	else:
		var data := SaveSystem.load_data()
		var cur: int = int(data.get("salvage", 0))
		data["salvage"] = cur + 60
		SaveSystem.save_data(data)

	if _halo_light:
		_halo_light.light_energy = 0.0
	queue_free()

func get_encounter_display_type() -> String:
	match reward_type:
		RewardType.REPAIR_STATION:
			return "REPAIR"
		RewardType.AMMO_DEPOT:
			return "AMMO"
		_:
			return "SUPPLY"

func get_encounter_status_text() -> String:
	match reward_type:
		RewardType.REPAIR_STATION:
			return "REPAIR"
		RewardType.AMMO_DEPOT:
			return "AMMO"
		_:
			return "SUPPLY"

func get_encounter_color() -> Color:
	match reward_type:
		RewardType.REPAIR_STATION:
			return Color(0.20, 0.98, 0.45, 1.0)
		RewardType.AMMO_DEPOT:
			return Color(1.0, 0.65, 0.15, 1.0)
		_:
			return Color(0.30, 0.75, 1.0, 1.0)
