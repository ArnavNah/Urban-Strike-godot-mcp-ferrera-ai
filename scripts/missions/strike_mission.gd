class_name StrikeMission
extends RefCounted

## Base class for dynamic strike missions in Urban Strike Rogue.

var id: String = ""
var title: String = ""
var description: String = ""
var target_position: Vector3 = Vector3.ZERO
var target_node: Node3D = null

var is_active: bool = false
var is_completed: bool = false
var is_failed: bool = false

var time_limit: float = 0.0 # 0.0 = no time limit
var elapsed_time: float = 0.0

var xp_reward: int = 50
var salvage_reward: int = 50
var requisition_reward: int = 1
var _rewards_granted: bool = false

func start(_director: Node) -> void:
	is_active = true
	is_completed = false
	is_failed = false
	_rewards_granted = false
	elapsed_time = 0.0

func update(delta: float, player: Node3D) -> Dictionary:
	elapsed_time += delta
	var dist: float = 0.0
	if is_instance_valid(player):
		var check_pos := target_position
		if is_instance_valid(target_node):
			check_pos = target_node.global_position
		dist = player.global_position.distance_to(check_pos)

	if time_limit > 0.0 and elapsed_time >= time_limit:
		is_failed = true

	return {
		"title": title,
		"detail": "%dm" % int(dist),
		"dist": dist,
		"progress": 0.0
	}

func check_completion() -> bool:
	return is_completed

func check_failure() -> bool:
	return is_failed

func on_success(director: Node) -> void:
	is_active = false
	is_completed = true
	_apply_rewards(director)

func on_failure(_director: Node) -> void:
	is_active = false
	is_failed = true

func cleanup() -> void:
	is_active = false

func _get_active_node_in_group(tree: SceneTree, group_name: String) -> Node:
	var nodes: Array = tree.get_nodes_in_group(group_name)
	for i in range(nodes.size() - 1, -1, -1):
		var n: Node = nodes[i] as Node
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			return n
	return null

func _apply_rewards(director: Node) -> void:
	if _rewards_granted:
		return
	_rewards_granted = true
	if not is_instance_valid(director) or not director.is_inside_tree():
		return
	var tree := director.get_tree()
	if not tree:
		return

	# Award XP
	if xp_reward > 0:
		var um := _get_active_node_in_group(tree, "upgrade_manager") as UpgradeManager
		if um and um.has_method("add_xp"):
			um.add_xp(xp_reward)

	# Award Requisition
	if requisition_reward > 0:
		var um := _get_active_node_in_group(tree, "upgrade_manager") as UpgradeManager
		if um and um.has_method("award_requisition"):
			um.award_requisition(requisition_reward)

	# Award Salvage
	if salvage_reward > 0:
		var gm := _get_active_node_in_group(tree, "game_manager")
		if gm and gm.has_method("add_salvage"):
			gm.add_salvage(salvage_reward)
