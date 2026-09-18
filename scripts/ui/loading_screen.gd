class_name LoadingScreen
extends Control

## Polished asynchronous tactical loading screen for Heli-Strike.
## Manages threaded loading of the battlefield scene with real progress polling,
## indeterminate radar animation, smooth cinematic transitions, error recovery (retry/return),
## and seamless curtain handoff into combat.

@export var target_scene_path: String = "res://scenes/battlefield/battlefield.tscn"
@export var min_display_time: float = 0.85

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var status_label: Label = %StatusLabel
@onready var progress_label: Label = %ProgressLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var hint_label: Label = %HintLabel
@onready var radar_reticle: Control = %RadarReticle
@onready var error_container: VBoxContainer = %ErrorContainer
@onready var error_message_label: Label = %ErrorMessageLabel
@onready var retry_button: Button = %RetryButton
@onready var menu_button: Button = %MenuButton
@onready var fade_curtain: ColorRect = %FadeCurtain if has_node("%FadeCurtain") else null

const TACTICAL_STATUSES: Array[String] = [
	"INITIALIZING TACTICAL AIRSPACE...",
	"ACQUIRING SATELLITE TELEMETRY...",
	"ESTABLISHING SECURE COMMS LINK...",
	"LOADING COMBAT DIRECTORS...",
	"WARMING DEFENSIVE SUBSYSTEMS...",
	"DEPLOYING AH-9 VULTURE..."
]

const TACTICAL_HINTS: Array[String] = [
	"TACTICAL ADVICE: Flare dispensers decoy hostile radar-guided SAM missiles.",
	"TACTICAL ADVICE: The 30mm chin turret auto-tracks hostile vehicles in a 360-degree arc.",
	"TACTICAL ADVICE: Banking into turns tightens your orbit around skyscraper corners.",
	"TACTICAL ADVICE: Salvage crates drop from destroyed elite assets and boss units.",
	"TACTICAL ADVICE: Collect XP gems to draft weapons and airframe upgrades during combat."
]

var _elapsed_display_time: float = 0.0
var _is_loading: bool = false
var _is_transitioning: bool = false
var _load_failed: bool = false
var _reticle_angle: float = 0.0
var _status_timer: float = 0.0
var _status_index: int = 0
var _progress_smooth: float = 0.0
var _loaded_scene: PackedScene = null
var _transition_tween: Tween = null
var _status_tween: Tween = null
var _hold_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Guarantee normal unpaused time scale when entering loading screen
	get_tree().paused = false
	Engine.time_scale = 1.0

	# Pre-cache static materials for XP pickups
	XPGem._ensure_static_materials()

	if error_container:
		error_container.visible = false
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

	if radar_reticle:
		radar_reticle.draw.connect(_on_radar_reticle_draw)

	_pick_random_hint()

	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if "--hold-loading" in user_args:
		min_display_time = 999.0
	elif "--fast-loading" in user_args:
		min_display_time = 0.25

	# Smooth entrance fade-in
	_play_entrance_transition()

	start_load(target_scene_path)

func _play_entrance_transition() -> void:
	if fade_curtain:
		fade_curtain.modulate.a = 1.0
		var tw: Tween = create_tween()
		tw.tween_property(fade_curtain, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _pick_random_hint() -> void:
	if hint_label and not TACTICAL_HINTS.is_empty():
		hint_label.text = TACTICAL_HINTS[randi() % TACTICAL_HINTS.size()]

func start_load(path: String) -> void:
	if _is_transitioning:
		return

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()

	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS

	if fade_curtain and not _load_failed:
		fade_curtain.modulate.a = 0.0

	target_scene_path = path
	_is_loading = true
	_load_failed = false
	_is_transitioning = false
	_elapsed_display_time = 0.0
	_progress_smooth = 0.0
	_loaded_scene = null
	_hold_timer = 0.0

	if error_container:
		error_container.visible = false
	if progress_bar:
		progress_bar.value = 0.0
		progress_bar.visible = true
	if progress_label:
		progress_label.text = "0%"
		progress_label.visible = true
	if status_label:
		status_label.text = TACTICAL_STATUSES[0]
		status_label.modulate.a = 1.0
		status_label.visible = true

	var err: Error = ResourceLoader.load_threaded_request(target_scene_path)
	if err != OK:
		_handle_load_failure("RESOURCE LOADER ERROR: Code %d" % err)

func _process(delta: float) -> void:
	_elapsed_display_time += delta
	_reticle_angle = fmod(_reticle_angle + delta * 3.2, TAU)
	if radar_reticle:
		radar_reticle.queue_redraw()

	if not _is_loading or _load_failed or _is_transitioning:
		return

	# Smoothly cycle tactical status messages with gentle cross-fade
	_status_timer += delta
	if _status_timer >= 0.85 and _loaded_scene == null:
		_status_timer = 0.0
		_status_index = (_status_index + 1) % TACTICAL_STATUSES.size()
		_fade_status_text(TACTICAL_STATUSES[_status_index])

	# Poll threaded load status only while scene has not been retrieved
	var target_pct: float = 0.0
	if _loaded_scene != null:
		target_pct = 100.0
	else:
		var progress_arr: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target_scene_path, progress_arr)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not progress_arr.is_empty() and progress_arr[0] != null:
					target_pct = float(progress_arr[0]) * 100.0
			ResourceLoader.THREAD_LOAD_LOADED:
				target_pct = 100.0
				_loaded_scene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
				if _loaded_scene == null or not _loaded_scene.can_instantiate():
					_handle_load_failure("LOAD FAILED: Resource is not a valid instantiable scene '%s'" % target_scene_path)
					return
			ResourceLoader.THREAD_LOAD_FAILED:
				_handle_load_failure("LOAD FAILED: Unable to load '%s'" % target_scene_path)
				return
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_handle_load_failure("LOAD FAILED: Invalid resource '%s'" % target_scene_path)
				return

	# Smoothly interpolate progress bar without snapping or freezing
	var progress_speed: float = 120.0
	if _loaded_scene != null:
		# When loaded, pace the progress smoothly to 100% across the remaining display time
		var remaining_time: float = maxf(0.04, min_display_time - _elapsed_display_time)
		var needed_speed: float = (100.0 - _progress_smooth) / remaining_time
		progress_speed = maxf(progress_speed, needed_speed)

	_progress_smooth = move_toward(_progress_smooth, target_pct, delta * progress_speed)
	if progress_bar:
		progress_bar.value = _progress_smooth
	if progress_label:
		progress_label.text = "%d%%" % int(_progress_smooth)

	# When 100% is reached and scene is loaded
	if _loaded_scene != null and _progress_smooth >= 99.9 and _elapsed_display_time >= min_display_time:
		if progress_bar:
			progress_bar.value = 100.0
		if progress_label:
			progress_label.text = "100%"
		if status_label and status_label.text != "AIRSPACE READY // ENGAGING":
			_fade_status_text("AIRSPACE READY // ENGAGING")

		# Brief tactical engagement hold (0.18s) before engaging smooth exit
		_hold_timer += delta
		if _hold_timer >= 0.18:
			_finalize_transition()
		return

func _fade_status_text(new_text: String) -> void:
	if not status_label:
		return
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()

	_status_tween = create_tween()
	_status_tween.tween_property(status_label, "modulate:a", 0.2, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_status_tween.tween_callback(func() -> void:
		status_label.text = new_text
	)
	_status_tween.tween_property(status_label, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _finalize_transition() -> void:
	if _is_transitioning or _loaded_scene == null:
		return
	_is_transitioning = true
	_is_loading = false

	# Lock input during final swap
	mouse_filter = Control.MOUSE_FILTER_STOP
	if progress_bar:
		progress_bar.value = 100.0
	if progress_label:
		progress_label.text = "100%"
	if status_label:
		status_label.text = "AIRSPACE READY // ENGAGING"

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	# Seamless exit transition:
	# Fade screen to dark tactical curtain, then handoff cleanly to target scene with entry curtain
	if fade_curtain:
		_transition_tween = create_tween()
		_transition_tween.tween_property(fade_curtain, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_transition_tween.tween_callback(_execute_seamless_scene_swap)
	else:
		_transition_tween = create_tween()
		_transition_tween.tween_property(self, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_transition_tween.tween_callback(_execute_seamless_scene_swap)

func _execute_seamless_scene_swap() -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return

	var new_scene: Node = _loaded_scene.instantiate()
	if not new_scene:
		modulate.a = 1.0
		if fade_curtain:
			fade_curtain.modulate.a = 0.0
		mouse_filter = Control.MOUSE_FILTER_PASS
		_handle_load_failure("SCENE ACTIVATION FAILED: Instantiation returned null")
		return

	# Add temporary smooth entry curtain to new scene so it fades in seamlessly
	var entry_curtain := CanvasLayer.new()
	entry_curtain.name = "SceneEntryCurtain"
	entry_curtain.layer = 128
	var rect := ColorRect.new()
	rect.name = "CurtainRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	rect.color = Color(0.02, 0.03, 0.06, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_curtain.add_child(rect)
	new_scene.add_child(entry_curtain)

	if get_parent() == tree.root:
		tree.root.add_child(new_scene)
		tree.current_scene = new_scene

		var fade_tw: Tween = entry_curtain.create_tween()
		fade_tw.tween_property(rect, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade_tw.tween_callback(entry_curtain.queue_free)

		queue_free()
	else:
		# Fallback for nested or test runner nodes
		var err: Error = tree.change_scene_to_packed(_loaded_scene)
		if err != OK:
			modulate.a = 1.0
			if fade_curtain:
				fade_curtain.modulate.a = 0.0
			mouse_filter = Control.MOUSE_FILTER_PASS
			_handle_load_failure("SCENE ACTIVATION FAILED: Code %d" % err)

func _handle_load_failure(msg: String) -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	if _status_tween and _status_tween.is_valid():
		_status_tween.kill()

	modulate.a = 1.0
	if fade_curtain:
		fade_curtain.modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	_is_loading = false
	_load_failed = true
	_is_transitioning = false

	if error_message_label:
		error_message_label.text = msg
	if error_container:
		error_container.visible = true
	if progress_bar:
		progress_bar.visible = false
	if progress_label:
		progress_label.visible = false
	if status_label:
		status_label.text = "DEPLOYMENT ABORTED"
		status_label.modulate.a = 1.0
	if retry_button:
		retry_button.grab_focus()

func _on_retry_pressed() -> void:
	start_load(target_scene_path)

func _on_menu_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	if fade_curtain:
		var tw: Tween = create_tween()
		tw.tween_property(fade_curtain, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _on_radar_reticle_draw() -> void:
	if not radar_reticle:
		return
	var center: Vector2 = radar_reticle.size * 0.5
	var radius: float = minf(center.x, center.y) - 6.0
	if radius <= 4.0:
		return

	var ring_col := Color(0.20, 0.45, 0.60, 0.35)
	var sweep_col := Color(0.31, 0.88, 0.93, 0.85)

	# Radar circles
	radar_reticle.draw_arc(center, radius, 0, TAU, 36, ring_col, 1.2)
	radar_reticle.draw_arc(center, radius * 0.6, 0, TAU, 28, ring_col, 1.0)
	radar_reticle.draw_arc(center, radius * 0.25, 0, TAU, 20, ring_col, 1.0)

	# Crosshair ticks
	radar_reticle.draw_line(center + Vector2(0, -radius), center + Vector2(0, radius), ring_col, 1.0)
	radar_reticle.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), ring_col, 1.0)

	# Rotating sweep line
	var sweep_end: Vector2 = center + Vector2(cos(_reticle_angle), sin(_reticle_angle)) * radius
	radar_reticle.draw_line(center, sweep_end, sweep_col, 2.0)

	# Subtle rotating sweep wedge / trailing arc
	var trail_points := PackedVector2Array([center])
	for i in range(12):
		var ang: float = _reticle_angle - float(i) * 0.05
		trail_points.append(center + Vector2(cos(ang), sin(ang)) * radius)
	var trail_col := Color(0.31, 0.88, 0.93, 0.12)
	radar_reticle.draw_colored_polygon(trail_points, trail_col)
