class_name PauseMenu
extends Control

@onready var resume_btn: Button = %ResumeButton
@onready var restart_btn: Button = %RestartButton
@onready var menu_btn: Button = %MenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()

func toggle_pause() -> void:
	var run := get_tree().get_first_node_in_group("run_state_controller")
	if not run or run.has_pause_reason(&"upgrade") or run._is_ending_guarded:
		return
	# A modal/results pause cannot be released by the pause menu.
	if get_tree().paused and not visible:
		return
	var new_state := not visible
	if not run.set_pause_reason(&"menu", new_state):
		return
	visible = new_state
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if new_state:
		resume_btn.grab_focus()

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_restart_pressed() -> void:
	if not visible or _upgrade_is_open():
		return
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	if not visible or _upgrade_is_open():
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _upgrade_is_open() -> bool:
	var run := get_tree().get_first_node_in_group("run_state_controller")
	return run != null and run.has_pause_reason(&"upgrade")
