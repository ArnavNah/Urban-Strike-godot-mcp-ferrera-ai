class_name RunEndScreen
extends CanvasLayer

## End of run screen handling both Game Over and Victory presentations.
## Displays mission statistics, runs while paused, and routes Retry / Hangar navigation.

signal retry_requested()
signal return_to_menu_requested()

@onready var result_label: Label = %ResultLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var time_value_label: Label = %TimeValueLabel
@onready var wave_value_label: Label = %WaveValueLabel
@onready var kills_value_label: Label = %KillsValueLabel
@onready var salvage_value_label: Label = %SalvageValueLabel
@onready var retry_button: Button = %RetryButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var main_panel: PanelContainer = %MainPanel

var _is_action_taken: bool = false
var _is_won: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func display_game_over(stats: Dictionary) -> void:
	_is_won = false
	_is_action_taken = false

	if result_label:
		result_label.text = "MISSION FAILED"
		result_label.modulate = Color(1.0, 0.25, 0.25, 1.0)
	if subtitle_label:
		subtitle_label.text = "AH-9 VULTURE LOST IN ACTION"

	if retry_button:
		retry_button.text = "RETRY MISSION"

	_populate_stats(stats)
	_show_screen()

func display_victory(stats: Dictionary) -> void:
	_is_won = true
	_is_action_taken = false

	if result_label:
		result_label.text = "MISSION COMPLETE"
		result_label.modulate = Color(0.25, 1.0, 0.45, 1.0)
	if subtitle_label:
		subtitle_label.text = "EXTRACTION WINDOW SECURED // AIRSPACE CLEARED"

	if retry_button:
		retry_button.text = "PLAY AGAIN"

	_populate_stats(stats)
	_show_screen()

func _populate_stats(stats: Dictionary) -> void:
	var total_sec: float = float(stats.get("run_time", 0.0))
	var minutes := int(floorf(total_sec / 60.0))
	var seconds := int(total_sec) % 60

	if time_value_label:
		time_value_label.text = "%02d:%02d" % [minutes, seconds]

	if wave_value_label:
		var wave_num: int = int(stats.get("highest_wave", 1))
		wave_value_label.text = "%d / 10" % wave_num

	if kills_value_label:
		kills_value_label.text = str(int(stats.get("enemies_destroyed", 0)))

	if salvage_value_label:
		salvage_value_label.text = "%d CR" % int(stats.get("salvage", 0))

func _show_screen() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if anim_player and anim_player.has_animation("fade_in"):
		anim_player.play("fade_in")
	elif main_panel:
		main_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(main_panel, "modulate:a", 1.0, 0.4)

	if retry_button:
		retry_button.grab_focus()

func _on_retry_pressed() -> void:
	if _is_action_taken:
		return
	_is_action_taken = true

	emit_signal("retry_requested")
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	if _is_action_taken:
		return
	_is_action_taken = true

	emit_signal("return_to_menu_requested")
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/hangar/hangar.tscn")
