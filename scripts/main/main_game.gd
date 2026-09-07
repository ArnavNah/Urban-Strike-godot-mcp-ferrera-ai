class_name MainGame
extends Node

## Main game scene switcher and root controller

func _ready() -> void:
	# Default entry loads the Main Menu
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")
