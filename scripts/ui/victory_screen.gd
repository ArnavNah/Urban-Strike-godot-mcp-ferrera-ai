class_name VictoryScreen
extends Control

@onready var salvage_label: Label = %SalvageLabel
@onready var extract_button: Button = %ExtractButton
@onready var endless_button: Button = %EndlessButton

const SOUND_FOCUS: AudioStream = preload("res://assets/audio/sfx/ui/ui_focus.wav")
const SOUND_CONFIRM: AudioStream = preload("res://assets/audio/sfx/ui/ui_confirm.wav")

var _run_salvage: int = 0
var _audio_player: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("victory_screen")
	visible = false

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "VictoryAudioPlayer"
	add_child(_audio_player)

	extract_button.pressed.connect(_on_extract_pressed)
	endless_button.pressed.connect(_on_endless_pressed)

	extract_button.focus_entered.connect(_play_focus_sound)
	extract_button.mouse_entered.connect(_play_focus_sound)
	endless_button.focus_entered.connect(_play_focus_sound)
	endless_button.mouse_entered.connect(_play_focus_sound)

	# Establish seamless horizontal focus loop
	if is_inside_tree() and extract_button.is_inside_tree() and endless_button.is_inside_tree():
		extract_button.focus_neighbor_right = extract_button.get_path_to(endless_button)
		extract_button.focus_neighbor_left = extract_button.get_path_to(endless_button)
		endless_button.focus_neighbor_left = endless_button.get_path_to(extract_button)
		endless_button.focus_neighbor_right = endless_button.get_path_to(extract_button)
	else:
		extract_button.focus_neighbor_right = NodePath("../EndlessButton")
		extract_button.focus_neighbor_left = NodePath("../EndlessButton")
		endless_button.focus_neighbor_left = NodePath("../ExtractButton")
		endless_button.focus_neighbor_right = NodePath("../ExtractButton")

func _play_focus_sound() -> void:
	if _audio_player:
		_audio_player.stream = SOUND_FOCUS
		_audio_player.volume_db = -16.0
		_audio_player.play()

func _play_confirm_sound() -> void:
	if _audio_player:
		_audio_player.stream = SOUND_CONFIRM
		_audio_player.volume_db = -12.0
		_audio_player.play()

func display_victory(earned_salvage: int) -> void:
	_run_salvage = earned_salvage
	var gm := get_tree().get_first_node_in_group("game_manager")
	var kills: int = gm.enemies_killed if gm else 0
	var score: int = gm.total_score if gm else 0
	salvage_label.text = "RUN SALVAGE SECURED: %d  |  KILLS: %d  |  SCORE: %d\nExtract to safely bank in Hangar, or risk it for 2.0x in Endless Overdrive!" % [_run_salvage, kills, score]
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
