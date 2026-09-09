class_name PlayableArea
extends Node3D

## Manages the defined tactical mission boundary around the combat city.
## Features a 3-tier boundary:
## 1. Inner Safe Area: Normal unhindered gameplay (default: 185m half-extent)
## 2. Warning Border: HUD warning message + return direction + smooth inward steering resistance (185m - 215m)
## 3. Hard Boundary: Physical collision + smooth position clamp and outward velocity zeroing (222m)

@export var safe_half_extent: float = 185.0
@export var warning_half_extent: float = 215.0
@export var hard_half_extent: float = 222.0
@export var gentle_resistance: float = 18.0
@export var target_player: Node3D = null

var _is_currently_warning: bool = false

func _ready() -> void:
	add_to_group("playable_area")
	if not target_player:
		target_player = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_player):
		target_player = get_tree().get_first_node_in_group("player") as Node3D
		if not is_instance_valid(target_player):
			return

	var p_pos := target_player.global_position
	var abs_x := absf(p_pos.x)
	var abs_z := absf(p_pos.z)
	var max_coord := maxf(abs_x, abs_z)

	# 1. Soft Boundary / Warning Zone
	if max_coord > safe_half_extent:
		var return_vec := -Vector3(p_pos.x, 0.0, p_pos.z)
		return_vec.y = 0.0
		var return_dir := return_vec.normalized() if return_vec.length_squared() > 0.01 else Vector3.ZERO
		var linear_ratio := clampf((max_coord - safe_half_extent) / maxf(1.0, warning_half_extent - safe_half_extent), 0.0, 1.0)
		var curved_ratio := linear_ratio * linear_ratio
		var dist_to_edge := maxf(0.0, hard_half_extent - max_coord)

		if not _is_currently_warning or Engine.get_physics_frames() % 6 == 0:
			_is_currently_warning = true
			if EventBus.has_signal("border_warning_changed"):
				EventBus.border_warning_changed.emit(true, return_dir, dist_to_edge)

		# Smooth inward resistance to guide player back to the combat zone
		if "velocity" in target_player and target_player.velocity is Vector3:
			target_player.velocity += return_dir * (gentle_resistance * curved_ratio * delta)
	else:
		if _is_currently_warning:
			_is_currently_warning = false
			if EventBus.has_signal("border_warning_changed"):
				EventBus.border_warning_changed.emit(false, Vector3.ZERO, 0.0)

	# 2. Hard Boundary: Smooth progressive outward velocity dampening close to the wall
	if max_coord >= hard_half_extent - 2.5:
		if "velocity" in target_player and target_player.velocity is Vector3:
			if abs_x >= hard_half_extent - 2.5 and target_player.velocity.x * p_pos.x > 0.0:
				var wall_proximity: float = clampf((abs_x - (hard_half_extent - 2.5)) / 2.5, 0.0, 1.0)
				target_player.velocity.x *= (1.0 - wall_proximity)
			if abs_z >= hard_half_extent - 2.5 and target_player.velocity.z * p_pos.z > 0.0:
				var wall_proximity: float = clampf((abs_z - (hard_half_extent - 2.5)) / 2.5, 0.0, 1.0)
				target_player.velocity.z *= (1.0 - wall_proximity)

	# Physical safety clamp prevents escaping outside the boundary without visual snapping
	if max_coord > hard_half_extent:
		target_player.global_position.x = clampf(p_pos.x, -hard_half_extent, hard_half_extent)
		target_player.global_position.z = clampf(p_pos.z, -hard_half_extent, hard_half_extent)
