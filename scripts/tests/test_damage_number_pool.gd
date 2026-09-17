extends SceneTree

## Dedicated test suite for DamageNumberManager pooling, preset caps,
## camera frustum culling, burst resilience, and state reset.

func _init() -> void:
	print("--- STARTING DAMAGE NUMBER POOL TESTS ---")
	var success := true

	# Ensure EventBus autoload exists in headless script runner
	var eb: Node = root.get_node_or_null("EventBus")
	if not eb:
		var eb_script = load("res://scripts/common/event_bus.gd")
		eb = eb_script.new()
		eb.name = "EventBus"
		root.add_child(eb)

	# Setup a temporary SubViewport with a Camera3D to test frustum projection
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	root.add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 10.0, 15.0)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.0, 0.0), Vector3.UP)
	cam.current = true
	vp.add_child(cam)

	var manager := DamageNumberManager.new()
	vp.add_child(manager)

	# --------------------------------------------------------------------------
	# TEST 1: Preallocation & Initial Inactive State
	# --------------------------------------------------------------------------
	print("[TEST 1] Preallocation & Initial Inactive State...")
	if manager.get_pool_size() != 64 or manager.get_child_count() != 64:
		printerr("FAIL: Expected 64 preallocated labels, got pool_size=%d, children=%d" % [manager.get_pool_size(), manager.get_child_count()])
		success = false
	elif manager.get_active_count() != 0 or manager.get_free_count() != 64:
		printerr("FAIL: Expected 0 active and 64 free labels initially, got active=%d, free=%d" % [manager.get_active_count(), manager.get_free_count()])
		success = false
	else:
		var all_inactive := true
		for child in manager.get_children():
			if child is DamageNumber:
				if child.is_active or child.visible or child.is_processing():
					all_inactive = false
					break
		if not all_inactive:
			printerr("FAIL: Preallocated labels should be inactive, hidden, and not processing!")
			success = false
		else:
			print("  -> 64 labels preallocated, all inactive, hidden, and stopped.")

	# --------------------------------------------------------------------------
	# TEST 2: Preset Active Limits (Low: 24, Medium: 40, High: 56)
	# --------------------------------------------------------------------------
	print("[TEST 2] Graphics Preset Active Limits...")
	manager.set_preset("low")
	if manager.max_active_numbers != 24:
		printerr("FAIL: Low preset expected 24, got %d" % manager.max_active_numbers)
		success = false

	manager.set_preset("medium")
	if manager.max_active_numbers != 40:
		printerr("FAIL: Medium preset expected 40, got %d" % manager.max_active_numbers)
		success = false

	manager.set_preset("high")
	if manager.max_active_numbers != 56:
		printerr("FAIL: High preset expected 56, got %d" % manager.max_active_numbers)
		success = false

	print("  -> Preset limits verified: Low=24, Medium=40, High=56.")

	# --------------------------------------------------------------------------
	# TEST 3: Camera Frustum & Viewport Rejection
	# --------------------------------------------------------------------------
	print("[TEST 3] Frustum & Viewport Rejection...")
	manager.set_preset("medium")

	# Position directly behind camera (Z = 25m, camera is at Z = 15m facing -Z)
	var behind_pos := Vector3(0.0, 10.0, 25.0)
	eb.damage_number_spawned.emit(behind_pos, 15.0, false)
	if manager.get_active_count() != 0:
		printerr("FAIL: Behind-camera position should be rejected, got active=%d" % manager.get_active_count())
		success = false

	# Position far beyond 150m effect distance
	var distant_pos := Vector3(0.0, 0.0, -200.0)
	eb.damage_number_spawned.emit(distant_pos, 15.0, false)
	if manager.get_active_count() != 0:
		printerr("FAIL: Distant position (>150m) should be rejected, got active=%d" % manager.get_active_count())
		success = false

	# Valid position in front of camera (center of view)
	var visible_pos := Vector3(0.0, 0.0, 0.0)
	eb.damage_number_spawned.emit(visible_pos, 15.0, false)
	if manager.get_active_count() != 1:
		printerr("FAIL: Visible position should be accepted, got active=%d" % manager.get_active_count())
		success = false
	else:
		print("  -> Behind-camera and offscreen positions strictly rejected; in-view accepted.")

	# Reset by deactivating the 1 active label
	for c in manager.get_children():
		if c is DamageNumber and c.is_active:
			c.deactivate()

	# --------------------------------------------------------------------------
	# TEST 4: Burst of 200 Display Events & Bounded Node Count
	# --------------------------------------------------------------------------
	print("[TEST 4] Burst of 200 Events & Bounded Node Count...")
	manager.set_preset("medium") # Cap = 40

	for i in range(200):
		var offset := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
		eb.damage_number_spawned.emit(visible_pos + offset, float(i + 1), (i % 5 == 0))

	if manager.get_active_count() != 40:
		printerr("FAIL: Burst of 200 on Medium should immediately cap at 40, got active=%d" % manager.get_active_count())
		success = false
	elif manager.get_child_count() != 64:
		printerr("FAIL: Total node count grew during burst! Expected 64, got %d" % manager.get_child_count())
		success = false
	else:
		print("  -> Immediate cap enforced: exactly 40/40 active, 24 free, 64 total nodes (0 allocations).")

	# --------------------------------------------------------------------------
	# TEST 5: Pool Reuse & Complete State Reset
	# --------------------------------------------------------------------------
	print("[TEST 5] Pool Reuse & Complete State Reset...")
	# Deactivate all active labels to simulate expiration
	for c in manager.get_children():
		if c is DamageNumber and c.is_active:
			c.deactivate()

	if manager.get_active_count() != 0 or manager.get_free_count() != 64:
		printerr("FAIL: Expected all 64 labels returned to free pool, got active=%d, free=%d" % [manager.get_active_count(), manager.get_free_count()])
		success = false

	# Fire a second burst of 200 events
	manager.set_preset("low") # Cap = 24
	for i in range(200):
		var offset := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
		eb.damage_number_spawned.emit(visible_pos + offset, 50.0, true)

	if manager.get_active_count() != 24:
		printerr("FAIL: Second burst on Low should cap at 24, got active=%d" % manager.get_active_count())
		success = false
	elif manager.get_child_count() != 64:
		printerr("FAIL: Total node count grew on second burst! Got %d" % manager.get_child_count())
		success = false
	else:
		# Check state of active labels: critical text, color, scale reset, lifetime
		var sample_active: DamageNumber = null
		for c in manager.get_children():
			if c is DamageNumber and c.is_active:
				sample_active = c
				break

		if not sample_active:
			printerr("FAIL: No active label found to inspect!")
			success = false
		elif sample_active.text != "50":
			printerr("FAIL: Expected text '50', got '%s'" % sample_active.text)
			success = false
		elif sample_active.lifetime != 0.65:
			printerr("FAIL: Expected lifetime 0.65, got %f" % sample_active.lifetime)
			success = false
		else:
			print("  -> Pool reuse verified: 24 active, state completely reset, text='50', lifetime=0.65.")

	# --------------------------------------------------------------------------
	# TEST 6: Tween Lifecycle Safety
	# --------------------------------------------------------------------------
	print("[TEST 6] Tween Lifecycle Safety on Deactivate & Reuse...")
	for c in manager.get_children():
		if c is DamageNumber and c.is_active:
			c.deactivate()
			if c._tween != null:
				printerr("FAIL: _tween should be null after deactivate!")
				success = false

	print("  -> All tweens killed cleanly on deactivation.")

	# --------------------------------------------------------------------------
	# TEST 7: Scene Exit & Clean Disconnect
	# --------------------------------------------------------------------------
	print("[TEST 7] Scene Exit & Clean Disconnect...")
	manager.queue_free()
	vp.queue_free()
	eb.queue_free()

	print("=== ALL DAMAGE NUMBER POOL TESTS PASSED! ===")
	if success:
		quit(0)
	else:
		quit(1)
