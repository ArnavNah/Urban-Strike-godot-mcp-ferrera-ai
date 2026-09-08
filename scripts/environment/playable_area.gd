class_name PlayableArea
extends Node3D

## Manages the defined tactical mission boundary around the combat city.
## Features a 3-tier boundary:
## 1. Inner Safe Area: Normal unhindered gameplay (default: 125m half-extent)
## 2. Warning Border: HUD warning message + return direction + subtle inward steering resistance (125m - 145m)
## 3. Hard Boundary: Physical collision + smooth position clamp and outward velocity zeroing (148m)

@export var safe_half_extent: float = 125.0
@export var warning_half_extent: float = 145.0
@export var hard_half_extent: float = 148.0
@export var gentle_resistance: float = 14.0
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
		var ratio := clampf((max_coord - safe_half_extent) / maxf(1.0, warning_half_extent - safe_half_extent), 0.0, 1.0)
		var dist_to_edge := maxf(0.0, hard_half_extent - max_coord)

		if not _is_currently_warning or Engine.get_physics_frames() % 6 == 0:
			_is_currently_warning = true
			if EventBus.has_signal("border_warning_changed"):
				EventBus.border_warning_changed.emit(true, return_dir, dist_to_edge)

		# Gentle inward resistance to help player turn around
		if "velocity" in target_player and target_player.velocity is Vector3:
			target_player.velocity += return_dir * (gentle_resistance * ratio * delta)
	else:
		if _is_currently_warning:
			_is_currently_warning = false
			if EventBus.has_signal("border_warning_changed"):
				EventBus.border_warning_changed.emit(false, Vector3.ZERO, 0.0)

	# The authored StaticBody3D walls perform the hard stop through normal
	# move_and_slide collision. Suppress outward velocity close to a wall,
	# and smoothly clamp position to hard_half_extent if pushed beyond.
	if max_coord >= hard_half_extent - 1.5:
		if "velocity" in target_player and target_player.velocity is Vector3:
			if abs_x >= hard_half_extent - 1.5 and target_player.velocity.x * p_pos.x > 0.0:
				target_player.velocity.x = 0.0
			if abs_z >= hard_half_extent - 1.5 and target_player.velocity.z * p_pos.z > 0.0:
				target_player.velocity.z = 0.0

	if max_coord > hard_half_extent:
		target_player.global_position.x = clampf(p_pos.x, -hard_half_extent, hard_half_extent)
		target_player.global_position.z = clampf(p_pos.z, -hard_half_extent, hard_half_extent)
