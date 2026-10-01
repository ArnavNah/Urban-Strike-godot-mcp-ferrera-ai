class_name XpGemPool
extends Node3D

## Dedicated high-performance pool for XP gems.
## Pre-allocates gem instances to eliminate instantiation pauses and GC pressure
## when enemies are destroyed during combat.

static var instance: XpGemPool = null

@export var pool_size: int = 160
@export var gem_scene: PackedScene = null

var _pool: Array[XPGem] = []
var _pool_idx: int = 0

func _enter_tree() -> void:
	instance = self
	add_to_group("xp_gem_pool")

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	if not gem_scene:
		gem_scene = load("res://scenes/pickups/xp_gem.tscn")
	_init_pool()

func _init_pool() -> void:
	if not gem_scene:
		return
	for i in range(pool_size):
		var gem: XPGem = gem_scene.instantiate() as XPGem
		if gem:
			gem.is_pooled = true
			gem.deactivate()
			add_child(gem)
			_pool.append(gem)

func spawn_gem(pos: Vector3, val: int) -> XPGem:
	var count: int = _pool.size()
	if count == 0:
		return null

	# 1. Primary fast path: find an inactive gem in the circular pool buffer
	for i in range(count):
		var idx: int = (_pool_idx + i) % count
		var gem: XPGem = _pool[idx]
		if not gem.is_active:
			_pool_idx = (idx + 1) % count
			gem.activate(pos, val)
			return gem

	# 2. Pool is saturated (all slots active):
	# If an existing gem is within proximity (<= 16m), merge value into it to conserve entity count.
	# (Preserves Test 42 single-gem pool saturation assertion and tight combat cluster merges).
	var nearest_idle: XPGem = null
	var best_idle_dist_sq: float = INF
	for gem in _pool:
		if gem._is_collected:
			continue
		var d_sq: float = gem.global_position.distance_squared_to(pos)
		if d_sq < best_idle_dist_sq:
			best_idle_dist_sq = d_sq
			nearest_idle = gem

	if nearest_idle and best_idle_dist_sq <= (16.0 * 16.0):
		nearest_idle.xp_value += val
		nearest_idle._apply_visual_style()
		return nearest_idle

	# 3. Saturation without nearby gem:
	# Recycle the furthest uncollected gem relative to the player (or spawn pos).
	# Migrate its accumulated XP into the new gem at pos, so that combat always yields
	# a visible, reachable reward right where the enemy died without discarding older XP.
	var ref_pos: Vector3 = pos
	var player: Node3D = _get_player()
	if is_instance_valid(player):
		ref_pos = player.global_position

	var furthest_gem: XPGem = null
	var max_dist_sq: float = -1.0
	for gem in _pool:
		if gem._is_collected:
			continue
		var d_sq: float = gem.global_position.distance_squared_to(ref_pos)
		if d_sq > max_dist_sq:
			max_dist_sq = d_sq
			furthest_gem = gem

	if furthest_gem:
		var accumulated_val: int = val + furthest_gem.xp_value
		furthest_gem.activate(pos, accumulated_val)
		return furthest_gem

	# 4. Fallback if all slots are currently finishing collection animations:
	var oldest: XPGem = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % count
	oldest.activate(pos, val)
	return oldest

func _get_player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node3D

func reset_pool() -> void:
	for gem in _pool:
		if is_instance_valid(gem):
			gem.deactivate()
	_pool_idx = 0

func clear_pool() -> void:
	reset_pool()

func get_active_count() -> int:
	var count: int = 0
	for gem in _pool:
		if gem.is_active:
			count += 1
	return count

func get_diagnostics_summary() -> Dictionary:
	var active_count: int = 0
	var magnetized_count: int = 0
	var total_active_xp: int = 0
	for gem in _pool:
		if is_instance_valid(gem) and gem.is_active and not gem._is_collected:
			active_count += 1
			total_active_xp += gem.xp_value
			if gem.current_state == XPGem.State.MAGNETIZED:
				magnetized_count += 1
	return {
		"pool_size": _pool.size(),
		"active_gems": active_count,
		"magnetized_gems": magnetized_count,
		"total_active_xp": total_active_xp,
		"pool_idx": _pool_idx
	}
