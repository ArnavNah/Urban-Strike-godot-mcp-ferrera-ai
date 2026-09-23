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

func _physics_process(delta: float) -> void:
	if is_completed:
		return

	var player := get_active_player()
	if not player or not is_player_in_range(player):
		return

	match reward_type:
		RewardType.REPAIR_STATION:
			_process_repair(player, delta)
		RewardType.AMMO_DEPOT:
			_process_ammo(player, delta)
		RewardType.EXPLORATION_CACHE:
			_process_exploration_cache(player)

func _process_repair(player: PlayerHelicopter, delta: float) -> void:
	if player.current_health < player.max_health and current_resource_pool > 0.0:
		var amount: float = minf(transfer_rate * delta, current_resource_pool)
		amount = minf(amount, player.max_health - player.current_health)
		if amount > 0.0:
			player.heal(amount)
			current_resource_pool -= amount
			if current_resource_pool <= 0.0:
				complete_encounter()
				if _halo_light:
					_halo_light.light_energy = 0.0
	elif player.current_health >= player.max_health and current_resource_pool > 0.0:
		player.heal(1.0) # Emits rate-limited hull_full_notified via player

func _process_ammo(player: PlayerHelicopter, delta: float) -> void:
	_pulse_timer += delta
	if _pulse_timer >= 1.2 and current_resource_pool > 0.0:
		_pulse_timer = 0.0
		if player.missile_pod and player.missile_pod.has_method("replenish_ammo"):
			var gained: int = player.missile_pod.replenish_ammo(1)
			if gained > 0:
				current_resource_pool -= 1.0
				if current_resource_pool <= 0.0:
					complete_encounter()
					if _halo_light:
						_halo_light.light_energy = 0.0
			elif EventBus and EventBus.has_signal("ammo_full_notified"):
				EventBus.ammo_full_notified.emit()

func _process_exploration_cache(_player: PlayerHelicopter) -> void:
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
				gem.global_position = spawn_pos
				if "xp_value" in gem:
					gem.set("xp_value", 20)
				parent.add_child(gem)

	# Direct banked salvage grant
	var data := SaveSystem.load_data()
	var cur: int = int(data.get("salvage", 0))
	data["salvage"] = cur + 60
	SaveSystem.save_data(data)

	if _halo_light:
		_halo_light.light_energy = 0.0
	queue_free()
