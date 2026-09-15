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

	# Staggered card entrance animation
	var card_idx := 0
	for child in card_container.get_children():
		if child is Control:
			var c := child as Control
			c.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_interval(float(card_idx) * 0.05)
			tw.tween_property(c, "modulate:a", 1.0, 0.15)
			card_idx += 1

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
	panel.custom_minimum_size = Vector2(275, 410)
	
	var is_evo: bool = data.get("is_evolution", false)
	var rarity: String = str(data.get("rarity", "Evolution" if is_evo else "Common"))
	var is_legendary: bool = (rarity == "Legendary")
	var is_rare: bool = (rarity == "Rare")
	var is_empty_card: bool = str(data.get("id", "")).is_empty()

	var style := StyleBoxFlat.new()
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	if is_evo:
		style.bg_color = Color(0.16, 0.08, 0.04, 0.98)
		style.border_color = Color(1.0, 0.42, 0.18, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	elif is_legendary:
		style.bg_color = Color(0.15, 0.12, 0.04, 0.98)
		style.border_color = Color(1.0, 0.82, 0.22, 1.0)
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
	elif is_rare:
		style.bg_color = Color(0.12, 0.08, 0.16, 0.98)
		style.border_color = Color(0.70, 0.45, 0.95, 0.95)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.06, 0.10, 0.14, 0.96)
		style.border_color = Color(0.25, 0.75, 0.70, 0.85)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Top metadata row: Rarity & Category
	var meta_row := HBoxContainer.new()
	meta_row.alignment = BoxContainer.ALIGNMENT_CENTER
	meta_row.add_theme_constant_override("separation", 8)
	vbox.add_child(meta_row)

	var rarity_label := Label.new()
	var rarity_text := "[ COMMON ]"
	var rarity_color := Color(0.35, 0.92, 0.82)
	if is_evo:
		rarity_text = "[ ⚡ EVOLUTION ⚡ ]"
		rarity_color = Color(1.0, 0.42, 0.18)
	elif is_legendary:
		rarity_text = "[ ★ LEGENDARY ★ ]"
		rarity_color = Color(1.0, 0.82, 0.22)
	elif is_rare:
		rarity_text = "[ RARE ]"
		rarity_color = Color(0.75, 0.52, 0.98)
	elif is_empty_card:
		rarity_text = "[ COMPLETE ]"
		rarity_color = Color(0.6, 0.8, 0.9)

	rarity_label.text = rarity_text
	rarity_label.modulate = rarity_color
	rarity_label.add_theme_font_size_override("font_size", 12)
	meta_row.add_child(rarity_label)

	var raw_cat: String = str(data.get("category", "UPGRADE")).to_upper()
	if not is_empty_card and raw_cat != "UPGRADE" and raw_cat != "EVOLUTION" and raw_cat != "LEGENDARY":
		var cat_label := Label.new()
		var prefix := "• "
		var cat_col := Color(0.75, 0.85, 0.90)
		if "PRIMARY" in raw_cat or "WEAPON" in raw_cat:
			prefix = "⚔ "
			cat_col = Color(1.0, 0.72, 0.25)
		elif "AIRFRAME" in raw_cat or "DEFENSE" in raw_cat:
			prefix = "🛡 "
			cat_col = Color(0.25, 0.90, 0.85)
		elif "SUPPORT" in raw_cat or "DRONE" in raw_cat or "ESCORT" in raw_cat:
			prefix = "🛸 "
			cat_col = Color(0.85, 0.55, 1.0)
		elif "AVIONICS" in raw_cat:
			prefix = "📡 "
			cat_col = Color(0.40, 0.80, 1.0)
		cat_label.text = "|  " + prefix + raw_cat
		cat_label.modulate = cat_col
		cat_label.add_theme_font_size_override("font_size", 12)
		meta_row.add_child(cat_label)

	# Name
	var name_label := Label.new()
	name_label.text = data.get("name", "Upgrade")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 17)
	if is_evo:
		name_label.modulate = Color(1.0, 0.95, 0.7)
	elif is_legendary:
		name_label.modulate = Color(1.0, 0.92, 0.6)
	elif is_rare:
		name_label.modulate = Color(0.92, 0.85, 1.0)
	vbox.add_child(name_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Stat values preview: Current -> Next
	var cur_val: String = str(data.get("current_value", ""))
	var next_val: String = str(data.get("next_value", ""))
	if not is_empty_card and (not cur_val.is_empty() or not next_val.is_empty()):
		var stat_panel := PanelContainer.new()
		var stat_style := StyleBoxFlat.new()
		stat_style.bg_color = Color(0.04, 0.06, 0.08, 0.75)
		stat_style.content_margin_left = 8.0
		stat_style.content_margin_right = 8.0
		stat_style.content_margin_top = 4.0
		stat_style.content_margin_bottom = 4.0
		stat_style.corner_radius_top_left = 4
		stat_style.corner_radius_top_right = 4
		stat_style.corner_radius_bottom_left = 4
		stat_style.corner_radius_bottom_right = 4
		stat_panel.add_theme_stylebox_override("panel", stat_style)

		var stat_label := Label.new()
		stat_label.text = "%s  ➜  %s" % [cur_val, next_val]
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat_label.modulate = Color(0.68, 0.90, 1.0)
		stat_label.add_theme_font_size_override("font_size", 12)
		stat_panel.add_child(stat_label)
		vbox.add_child(stat_panel)

	# Benefit (PRO)
	var benefit_label := Label.new()
	benefit_label.text = ("PRO: " if not is_empty_card else "") + data.get("benefit", "")
	benefit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	benefit_label.modulate = Color(0.35, 1.0, 0.45)
	benefit_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(benefit_label)

	# Trade-off (COST)
	var trade_label := Label.new()
	trade_label.text = ("COST: " if not is_empty_card else "") + data.get("tradeoff", "")
	trade_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_legendary:
		trade_label.modulate = Color(1.0, 0.88, 0.45)
	else:
		trade_label.modulate = Color(1.0, 0.55, 0.35)
	trade_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(trade_label)

	# Evolution prerequisites / synergy notes
	var prereq_text: String = str(data.get("prerequisites_text", ""))
	var synergy_text: String = str(data.get("evolution_synergy", ""))
	if is_evo and not prereq_text.is_empty():
		var prereq_label := Label.new()
		prereq_label.text = prereq_text
		prereq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		prereq_label.modulate = Color(1.0, 0.85, 0.3)
		prereq_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(prereq_label)
	elif not synergy_text.is_empty():
		var syn_label := Label.new()
		syn_label.text = synergy_text
		syn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		syn_label.modulate = Color(0.45, 0.85, 0.9)
		syn_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(syn_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn := Button.new()
	if is_empty_card:
		btn.text = "CONTINUE"
	elif is_evo:
		btn.text = "SELECT EVOLUTION"
	elif is_legendary:
		btn.text = "SELECT LEGENDARY"
	else:
		btn.text = "SELECT UPGRADE"

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
