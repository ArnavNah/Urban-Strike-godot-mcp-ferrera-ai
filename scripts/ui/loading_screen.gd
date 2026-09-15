class_name LoadingScreen
extends Control

## Polished asynchronous tactical loading screen for Heli-Strike.
## Manages threaded loading of the battlefield scene with real progress polling,
## indeterminate radar animation, error recovery (retry/return), and clean scene transition.

@export var target_scene_path: String = "res://scenes/battlefield/battlefield.tscn"
@export var min_display_time: float = 0.35

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

	start_load(target_scene_path)

func _pick_random_hint() -> void:
	if hint_label and not TACTICAL_HINTS.is_empty():
		hint_label.text = TACTICAL_HINTS[randi() % TACTICAL_HINTS.size()]

func start_load(path: String) -> void:
	if _is_transitioning:
		return

	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS

	target_scene_path = path
	_is_loading = true
	_load_failed = false
	_is_transitioning = false
	_elapsed_display_time = 0.0
	_progress_smooth = 0.0
	_loaded_scene = null

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

	# Cycle tactical status message periodically
	_status_timer += delta
	if _status_timer >= 0.75:
		_status_timer = 0.0
		_status_index = (_status_index + 1) % TACTICAL_STATUSES.size()
		if status_label:
			status_label.text = TACTICAL_STATUSES[_status_index]

	# If scene is already loaded and acquired, maintain 100% and await min_display_time
	if _loaded_scene != null:
		_progress_smooth = 100.0
		if progress_bar:
			progress_bar.value = 100.0
		if progress_label:
			progress_label.text = "100%"
		if _elapsed_display_time >= min_display_time:
			_finalize_transition()
		return

	# Poll threaded load status
	var progress_arr: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target_scene_path, progress_arr)

	var target_pct: float = 0.0
	if not progress_arr.is_empty() and progress_arr[0] != null:
		target_pct = float(progress_arr[0]) * 100.0

	# Smoothly interpolate progress bar
	_progress_smooth = move_toward(_progress_smooth, maxf(_progress_smooth, target_pct), delta * 140.0)
	if progress_bar:
		progress_bar.value = _progress_smooth
	if progress_label:
		progress_label.text = "%d%%" % int(_progress_smooth)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass
		ResourceLoader.THREAD_LOAD_LOADED:
			_loaded_scene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
			_progress_smooth = 100.0
			if progress_bar:
				progress_bar.value = 100.0
			if progress_label:
				progress_label.text = "100%"

			if _loaded_scene == null or not _loaded_scene.can_instantiate():
				_handle_load_failure("LOAD FAILED: Resource is not a valid instantiable scene '%s'" % target_scene_path)
				return

			# Wait for minimum display time and valid scene
			if _elapsed_display_time >= min_display_time:
				_finalize_transition()
		ResourceLoader.THREAD_LOAD_FAILED:
			_handle_load_failure("LOAD FAILED: Unable to load '%s'" % target_scene_path)
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_handle_load_failure("LOAD FAILED: Invalid resource '%s'" % target_scene_path)

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

	_transition_tween = create_tween()
	_transition_tween.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_callback(func() -> void:
		var err: Error = get_tree().change_scene_to_packed(_loaded_scene)
		if err != OK:
			modulate.a = 1.0
			mouse_filter = Control.MOUSE_FILTER_PASS
			_handle_load_failure("SCENE ACTIVATION FAILED: Code %d" % err)
	)

func _handle_load_failure(msg: String) -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	modulate.a = 1.0
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
	if retry_button:
		retry_button.grab_focus()

func _on_retry_pressed() -> void:
	start_load(target_scene_path)

func _on_menu_pressed() -> void:
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
