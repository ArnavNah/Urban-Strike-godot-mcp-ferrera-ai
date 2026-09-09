class_name RadarStation
extends StaticBody3D

@export var max_health: float = 120.0

var current_health: float = 120.0
var is_active: bool = true

@onready var dish: Node3D = $DishPivot
@onready var beacon_light: OmniLight3D = $BeaconLight

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("objectives")
	current_health = max_health
	is_active = true
	if EventBus:
		EventBus.radar_status_changed.emit(true)

func _process(delta: float) -> void:
	if not is_active:
		return

	if dish:
		dish.rotate_y(1.5 * delta)

	if beacon_light:
		beacon_light.light_energy = 1.0 + sin(Time.get_ticks_msec() * 0.005) * 1.5

func take_damage(amount: float, _source: Node = null, _hit_pos: Vector3 = Vector3.ZERO) -> void:
	if not is_active:
		return

	current_health = maxf(0.0, current_health - amount)
	if EventBus:
		EventBus.damage_number_spawned.emit(global_position + Vector3(0, 2.5, 0), amount, amount >= 30.0)

	if current_health <= 0.0:
		_destroy_radar()

func _destroy_radar() -> void:
	if not is_active:
		return
	is_active = false
	if EventBus:
		EventBus.radar_status_changed.emit(false)
		EventBus.enemy_destroyed.emit(self, 250)

	# Award bonus Salvage for objective
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_salvage"):
		gm.add_salvage(100)

	# Award Requisition point (major objective reward)
	var um := get_tree().get_first_node_in_group("upgrade_manager") as UpgradeManager
	if um:
		um.award_requisition(1)

	# Spawn physical Salvage Crate
	var crate_scene: PackedScene = preload("res://scenes/pickups/salvage_crate.tscn")
	if crate_scene:
		var crate := crate_scene.instantiate() as Node3D
		if crate:
			crate.transform.origin = global_position + Vector3(0.0, 0.6, 0.0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(crate)

	# Spawn multiple XP pickups (60 XP total: 4 x 15 XP)
	for i in range(4):
		var xp_scene: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")
		if xp_scene:
			var gem: Node3D = xp_scene.instantiate() as Node3D
			if gem:
				if "xp_value" in gem:
					gem.xp_value = 15
				var offset := Vector3(randf_range(-2.0, 2.0), 0.5, randf_range(-2.0, 2.0))
				gem.transform.origin = global_position + offset
				var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
				p.add_child.call_deferred(gem)

	# Destruction explosion
	var expl_scene: PackedScene = preload("res://scenes/vfx/explosion.tscn")
	if expl_scene:
		var expl := expl_scene.instantiate() as Node3D
		if expl:
			expl.transform.origin = global_position + Vector3(0, 2.0, 0)
			expl.scale = Vector3(3.0, 3.0, 3.0)
			var p := get_tree().current_scene if get_tree().current_scene else get_tree().root
			p.add_child.call_deferred(expl)

	queue_free()
