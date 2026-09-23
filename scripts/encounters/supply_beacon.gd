class_name SupplyBeacon
extends "res://scripts/encounters/base_encounter.gd"

## Optional risk-reward zone hold encounter.
## Player must maintain airspace over the beacon for the required capture duration
## while fending off automated defensive reinforcements.
## Rewards full missile replenishment, hull repair, and banked salvage gems.

@export var capture_time_required: float = 10.0
@export var abandonment_timeout: float = 8.0

var capture_progress: float = 0.0
var abandonment_timer: float = 0.0
var _has_spawned_guards: bool = false
var _ring_mesh: MeshInstance3D = null
var _antenna_mesh: MeshInstance3D = null
var _indicator_light: OmniLight3D = null
var _time: float = 0.0

func _ready() -> void:
	super._ready()
	if is_completed:
		return
	_build_visuals()

func _build_visuals() -> void:
	# Ground ring indicator
	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.name = "CaptureRing"
	var torus := TorusMesh.new()
	torus.inner_radius = activation_radius - 0.5
	torus.outer_radius = activation_radius
	torus.rings = 32
	torus.ring_segments = 16
	_ring_mesh.mesh = torus
	_ring_mesh.position = Vector3(0.0, 0.2, 0.0)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.961, 0.725, 0.106, 0.6)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mesh.material_override = ring_mat
	add_child(_ring_mesh)

	# Central antenna pylon
	_antenna_mesh = MeshInstance3D.new()
	_antenna_mesh.name = "BeaconAntenna"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.5
	cylinder.height = 6.0
	_antenna_mesh.mesh = cylinder
	_antenna_mesh.position = Vector3(0.0, 3.0, 0.0)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.2, 0.24, 0.28, 1.0)
	pole_mat.metallic = 0.8
	pole_mat.roughness = 0.4
	_antenna_mesh.material_override = pole_mat
	add_child(_antenna_mesh)

	# Beacon pulsing light
	_indicator_light = OmniLight3D.new()
	_indicator_light.name = "BeaconLight"
	_indicator_light.light_color = Color(0.961, 0.725, 0.106, 1.0)
	_indicator_light.light_energy = 2.0
	_indicator_light.omni_range = 16.0
	_indicator_light.position = Vector3(0.0, 6.2, 0.0)
	add_child(_indicator_light)

func _physics_process(delta: float) -> void:
	if is_completed:
		return

	_time += delta
	var player := get_active_player()
	var in_range := is_player_in_range(player) if player else false

	if in_range:
		abandonment_timer = 0.0
		if not is_active:
			start_encounter()
			_trigger_defense_wave()

		capture_progress += delta
		_pulse_visuals(true, delta)

		if capture_progress >= capture_time_required:
			_grant_rewards(player)
			complete_encounter()
	elif is_active:
		abandonment_timer += delta
		_pulse_visuals(false, delta)
		if abandonment_timer >= abandonment_timeout:
			capture_progress = 0.0
			abandon_encounter()

func _pulse_visuals(is_capturing: bool, _delta: float) -> void:
	if not _ring_mesh or not _ring_mesh.material_override:
		return
	var mat := _ring_mesh.material_override as StandardMaterial3D
	var speed: float = 3.0 + (capture_progress / capture_time_required) * 6.0 if is_capturing else 1.5
	var alpha: float = 0.4 + 0.3 * sin(_time * speed)
	mat.albedo_color = Color(0.961, 0.725, 0.106, alpha) if is_capturing else Color(0.6, 0.6, 0.7, 0.3)
	if _indicator_light:
		_indicator_light.light_energy = 1.5 + 1.5 * sin(_time * speed)

func _trigger_defense_wave() -> void:
	if _has_spawned_guards:
		return
	_has_spawned_guards = true
	var tree := get_tree()
	if not tree:
		return
	var spawn_dir := tree.get_first_node_in_group("spawn_director")
	if spawn_dir and spawn_dir.has_method("request_encounter_reinforcements"):
		spawn_dir.call("request_encounter_reinforcements", global_position, 2)

func _grant_rewards(player: PlayerHelicopter) -> void:
	if is_instance_valid(player):
		# 1. Full missile reload
		if player.missile_pod and player.missile_pod.has_method("replenish_ammo"):
			player.missile_pod.replenish_ammo(6)
		# 2. Hull repair
		if player.has_method("heal"):
			player.heal(40.0)

	# 3. Spawn high-value salvage gems around the beacon
	var gem_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn")
	var parent := get_parent() if get_parent() else get_tree().current_scene
	if gem_scene and parent:
		for i in range(5):
			var angle: float = (float(i) / 5.0) * TAU
			var spawn_pos: Vector3 = global_position + Vector3(cos(angle) * 4.0, 1.2, sin(angle) * 4.0)
			var gem: Node3D = gem_scene.instantiate() as Node3D
			if gem:
				gem.global_position = spawn_pos
				if "xp_value" in gem:
					gem.set("xp_value", 35)
				parent.add_child(gem)

	# Turn light green on completion
	if _indicator_light:
		_indicator_light.light_color = Color(0.2, 1.0, 0.4, 1.0)
		_indicator_light.light_energy = 3.0
	if _ring_mesh and _ring_mesh.material_override:
		(_ring_mesh.material_override as StandardMaterial3D).albedo_color = Color(0.2, 1.0, 0.4, 0.8)
