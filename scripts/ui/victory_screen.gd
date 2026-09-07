class_name VictoryScreen
extends Control

@onready var salvage_label: Label = %SalvageLabel
@onready var extract_button: Button = %ExtractButton
@onready var endless_button: Button = %EndlessButton

var _run_salvage: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("victory_screen")
	visible = false
	extract_button.pressed.connect(_on_extract_pressed)
	endless_button.pressed.connect(_on_endless_pressed)

func display_victory(earned_salvage: int) -> void:
	_run_salvage = earned_salvage
	salvage_label.text = "RUN SALVAGE SECURED: %d\nExtract to safely bank in Hangar, or risk it for 2.0x in Endless Overdrive!" % _run_salvage
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	extract_button.grab_focus()

func _on_extract_pressed() -> void:
	visible = false
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("extract_salvage"):
		gm.extract_salvage()

func _on_endless_pressed() -> void:
	visible = false
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("enter_endless_mode"):
		gm.enter_endless_mode()
