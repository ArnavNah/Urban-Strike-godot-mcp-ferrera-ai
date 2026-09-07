class_name LevelUpMenu
extends Control

@onready var card_container: HBoxContainer = %CardContainer

var _current_choices: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _selection_ready: bool = false
var _closing: bool = false
var _joy_accept_held: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("level_up_menu")
	visible = false

func display_cards(choices: Array[Dictionary], earned_level: int = 0) -> bool:
	var run := get_tree().get_first_node_in_group("run_state_controller")
	if not run or not run.set_pause_reason(&"upgrade", true):
		return false
	# An earned choice takes modal focus even if the pause menu already owns a pause.
	var pause_menu := get_tree().get_first_node_in_group("pause_menu")
	if pause_menu:
		pause_menu.visible = false
	_current_choices = choices.duplicate(true)
	_selection_ready = false
	_closing = false
	_buttons.clear()
	for child in card_container.get_children():
		card_container.remove_child(child)
		child.queue_free()
	var display_choices: Array[Dictionary] = _current_choices.duplicate(true)
	if display_choices.is_empty():
		# No invented balance reward: acknowledge the earned level without a dead modal.
		display_choices.append({
			"id": "", "name": "No upgrades available", "category": "LEVEL COMPLETE",
			"benefit": "Your earned level and XP are retained.",
			"tradeoff": "No eligible upgrades remain. Continue the run.",
		})
	for choice in display_choices:
		card_container.add_child(_create_card_widget(choice))
	for i in range(_buttons.size()):
		_buttons[i].focus_neighbor_left = _buttons[i].get_path_to(_buttons[posmod(i - 1, _buttons.size())])
		_buttons[i].focus_neighbor_right = _buttons[i].get_path_to(_buttons[(i + 1) % _buttons.size()])
	var header := $CenterContainer/VBoxContainer/Header as Label
	if header:
		header.text = "LEVEL %d // CHOOSE UPGRADE" % earned_level if not choices.is_empty() else "LEVEL %d // COMPLETE" % earned_level
	$CenterContainer/VBoxContainer/Subtitle.text = "Choose one system modification. Each standard upgrade creates strengths and trade-offs." if not choices.is_empty() else "No eligible upgrades remain. Continue to retain your earned progress."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_buttons[0].grab_focus()
	return true

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		# This project's ui_accept has keyboard events only. Keep confirmation local
		# to this modal without changing gameplay InputMap bindings.
		var was_held := _joy_accept_held
		_joy_accept_held = event.pressed
		if was_held and not event.pressed and _selection_ready:
			var focused := get_viewport().gui_get_focus_owner()
			var index := _buttons.find(focused)
			if index >= 0:
				var upgrade_id := str(_current_choices[index]["id"]) if not _current_choices.is_empty() else ""
				_on_card_selected(upgrade_id)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible:
		return
	if _joy_accept_held or Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if _closing:
		# Confirm/weapon input held through the modal must be released before resuming.
		for action in ["fire_primary", "fire_secondary", "countermeasure_flares", "pause"]:
			if Input.is_action_pressed(action):
				return
		visible = false
		_closing = false
		var run := get_tree().get_first_node_in_group("run_state_controller")
		if run:
			run.set_pause_reason(&"upgrade", false)
		var pause_menu := get_tree().get_first_node_in_group("pause_menu")
		if pause_menu and run and run.has_pause_reason(&"menu"):
			pause_menu.visible = true
			pause_menu.resume_btn.grab_focus()
	else:
		_selection_ready = true

func finish_selection() -> void:
	_selection_ready = false
	_closing = true
	for button in _buttons:
		button.disabled = true

func _create_card_widget(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 320)
	
	var style := StyleBoxFlat.new()
	if data.get("is_evolution", false):
		style.bg_color = Color(0.2, 0.12, 0.05, 0.96)
		style.border_color = Color(1.0, 0.6, 0.1, 1.0)
	else:
		style.bg_color = Color(0.1, 0.14, 0.18, 0.96)
		style.border_color = Color(0.25, 0.8, 0.7, 0.9)
	style.border_width_bottom = 3
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var cat_label := Label.new()
	cat_label.text = "[ " + data.get("category", "UPGRADE").to_upper() + " ]"
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.modulate = Color(0.4, 0.9, 0.8)
	vbox.add_child(cat_label)

	var name_label := Label.new()
	name_label.text = data.get("name", "Upgrade")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var benefit_label := Label.new()
	benefit_label.text = ("PRO: " if not str(data.get("id", "")).is_empty() else "") + data.get("benefit", "")
	benefit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	benefit_label.modulate = Color(0.3, 1.0, 0.4)
	vbox.add_child(benefit_label)

	var trade_label := Label.new()
	trade_label.text = ("COST: " if not str(data.get("id", "")).is_empty() else "") + data.get("tradeoff", "")
	trade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_label.modulate = Color(1.0, 0.5, 0.3)
	vbox.add_child(trade_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "CONTINUE" if str(data.get("id", "")).is_empty() else "SELECT UPGRADE"
	btn.custom_minimum_size = Vector2(0, 42)
	btn.pressed.connect(_on_card_selected.bind(data.get("id", "")))
	vbox.add_child(btn)
	_buttons.append(btn)

	return panel

func _on_card_selected(upgrade_id: String) -> void:
	if not visible or not _selection_ready or _closing:
		return
	_selection_ready = false
	var mgr := get_tree().get_first_node_in_group("upgrade_manager")
	if mgr:
		mgr.select_choice(upgrade_id)
