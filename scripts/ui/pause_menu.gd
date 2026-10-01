class_name PauseMenu
extends Control

@onready var resume_btn: Button = %ResumeButton
@onready var restart_btn: Button = %RestartButton
@onready var menu_btn: Button = %MenuButton

const SettingsMenuClass = preload("res://scripts/ui/settings_menu.gd")
var settings_btn: Button = null
var _settings_menu: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_menu")
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

	settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "SETTINGS"
	settings_btn.custom_minimum_size = Vector2(220, 44)
	settings_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_btn.add_theme_font_size_override("font_size", 18)
	if resume_btn and is_instance_valid(resume_btn.get_parent()):
		resume_btn.get_parent().add_child(settings_btn)
		resume_btn.get_parent().move_child(settings_btn, resume_btn.get_index() + 1)
	settings_btn.pressed.connect(_on_settings_pressed)

	# Establish seamless vertical looping focus navigation
	resume_btn.focus_neighbor_top = resume_btn.get_path_to(menu_btn)
	resume_btn.focus_neighbor_bottom = resume_btn.get_path_to(settings_btn)
	settings_btn.focus_neighbor_top = settings_btn.get_path_to(resume_btn)
	settings_btn.focus_neighbor_bottom = settings_btn.get_path_to(restart_btn)
	restart_btn.focus_neighbor_top = restart_btn.get_path_to(settings_btn)
	restart_btn.focus_neighbor_bottom = restart_btn.get_path_to(menu_btn)
	menu_btn.focus_neighbor_top = menu_btn.get_path_to(restart_btn)
	menu_btn.focus_neighbor_bottom = menu_btn.get_path_to(resume_btn)


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

func _on_settings_pressed() -> void:
	if not _settings_menu:
		_settings_menu = SettingsMenuClass.new()
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.name = "PauseSettingsCenter"
		center.add_child(_settings_menu)
		add_child(center)
		_settings_menu.closed.connect(func():
			center.visible = false
			if settings_btn:
				settings_btn.grab_focus()
		)
	_settings_menu.get_parent().visible = true
	_settings_menu.call("open_menu")



func _on_restart_pressed() -> void:
	if not visible or _upgrade_is_open():
		return
	get_tree().paused = false
	RunSeedManager.initialize_new_run()
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	if not visible or _upgrade_is_open():
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _upgrade_is_open() -> bool:
	var run := get_tree().get_first_node_in_group("run_state_controller")
	return run != null and run.has_pause_reason(&"upgrade")
