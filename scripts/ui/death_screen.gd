class_name DeathScreen
extends Control

@onready var salvage_summary_label: Label = %SalvageSummaryLabel
@onready var return_button: Button = %ReturnButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("death_screen")
	visible = false
	return_button.pressed.connect(_on_return_pressed)

func display_death(lost_salvage: int, has_insurance: bool) -> void:
	if has_insurance:
		var protected_amount: int = int(lost_salvage * 0.5)
		salvage_summary_label.text = "INSURANCE ACTIVE: 50% SALVAGE PROTECTED (+%d)\nLost: %d Salvage" % [protected_amount, lost_salvage - protected_amount]
	else:
		salvage_summary_label.text = "ALL SALVAGE LOST: %d Salvage lost with aircraft.\n(Extraction Insurance unlocks in Hangar)" % lost_salvage

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return_button.grab_focus()

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hangar/hangar.tscn")
