class_name MainMenu
extends Control

@onready var play_button: Button = %PlayButton
@onready var hangar_button: Button = %HangarButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_dialog: PanelContainer = %SettingsDialog
@onready var close_settings_button: Button = %CloseSettingsButton

@onready var bg_cam_rig: Node3D = get_node_or_null("SubViewportContainer/SubViewport/CamRig")
@onready var bg_rotor: Node3D = get_node_or_null("SubViewportContainer/SubViewport/HeliModel/Rotor")

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	if hangar_button:
		hangar_button.pressed.connect(_on_hangar_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	close_settings_button.pressed.connect(_on_close_settings_pressed)
	settings_dialog.visible = false
	if bg_cam_rig:
		bg_cam_rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	play_button.grab_focus()

func _physics_process(delta: float) -> void:
	if bg_cam_rig:
		bg_cam_rig.rotate_y(0.06 * delta)
	if bg_rotor:
		bg_rotor.rotate_y(28.0 * delta)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battlefield/battlefield.tscn")

func _on_hangar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hangar/hangar.tscn")

func _on_settings_pressed() -> void:
	settings_dialog.visible = true
	close_settings_button.grab_focus()

func _on_close_settings_pressed() -> void:
	settings_dialog.visible = false
	settings_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
