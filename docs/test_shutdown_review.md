# Test Suite Shutdown & Teardown Ownership Review

**Date:** 2026-09-19  
**Target:** `scripts/tests/test_runner.gd`, `scripts/directors/spawn_director.gd`  
**Methodology:** Read-only static analysis and AST inspection. Per work policy, automated tests were not executed.

---

## Executive Summary

A comprehensive static audit was conducted across the 49 test suites (7,862 lines) in `scripts/tests/test_runner.gd`, along with related test runners (`performance_validation_runner.gd`, `test_sandbox.gd`, `audit_scale.gd`). The review identified four distinct architectural leak patterns that caused ObjectDB instances to linger at shutdown or be abandoned in memory:

1. **Unparented Nodes invoking `queue_free()`:**
   In Godot 4, calling `queue_free()` on a `Node` that was never added to the active `SceneTree` (via `add_child()`) fails to schedule the node for deletion because the deferred message queue is driven by the active tree. Such unparented nodes remained orphaned in the ObjectDB.
2. **Synchronous Immediate Process Exit:**
   At the end of `test_runner.gd`'s `_ready()`, `get_tree().quit()` was invoked synchronously on frame 0. Any `queue_free()` invocations issued during the final test steps were pending in the engine's message queue and had not yet been processed by the tree's idle loop before shutdown.
3. **Formation Unit Queue Ownership in `SpawnDirector`:**
   In `spawn_director.gd`, `clear_formation_queue()` and transform sanitization called `u.queue_free()` on queued units that had not yet been parented into the scene tree, preventing them from being deleted.
4. **Early Failure Path Cleanup Deficits:**
   Certain assertion failure returns aborted tests without clearing allocated formation queues or unparented inspection instances.

---

## Detailed Findings & Remediations

### 1. Unparented Nodes Calling `queue_free()`

#### Finding:
- **Test 18 (`test_continuous_horde_survival_director`):**
  A dummy enemy node (`dummy_enemy := Node3D.new()`) was instantiated to test elite modifiers and continuous wave destruction without ever being added to the SceneTree. Calling `dummy_enemy.queue_free()` left it lingering in memory.
  - **Remediation:** Added `add_child(dummy_enemy)` to `TestRunner` so `dummy_enemy` joins the scene tree lifecycle. Ensured `queue_free()` calls are guarded with `is_instance_valid()` and `not is_queued_for_deletion()`.
- **Test 29 (`test_level_up_pacing_and_continuous_spawning`):**
  Five enemy scenes (`inst`), as well as `inf`, `tank`, `sam`, `turret`, and `hunter`, were instantiated purely to inspect exported `archetype` and `xp_reward` properties without being added to the tree. Calling `queue_free()` on these unparented instances resulted in 10 leaked ObjectDB nodes.
  - **Remediation:** Replaced `queue_free()` with direct `.free()` calls for all unparented inspection nodes.
- **Test 35 (`test_xp_aggregation_and_acceptance_suite`):**
  `var up_mgr := UpgradeManager.new()` was instantiated to test drafting weights without being added to `root_node`. Calling `up_mgr.queue_free()` leaked the entire manager.
  - **Remediation:** Changed `up_mgr.queue_free()` to `up_mgr.free()`.
- **Test 36 (`test_phase_10a_population_and_spawning_foundation`):**
  `var inf := inf_scene.instantiate()` was created to test `visual_crowd_weight` and was freed via `queue_free()` without ever being added to the tree.
  - **Remediation:** Changed `inf.queue_free()` to `inf.free()`.

---

### 2. Formation Queue Teardown in `SpawnDirector`

#### Finding:
In `scripts/directors/spawn_director.gd`:
```gdscript
func clear_formation_queue() -> void:
    for item in _formation_spawn_queue:
        var u: Node3D = item.get("unit", null) as Node3D
        if is_instance_valid(u) and not u.is_inside_tree():
            u.queue_free()
```
Line 720 explicitly checked `and not u.is_inside_tree()`, but then called `u.queue_free()`. Because the unit was not inside the tree, `queue_free()` had no active SceneTree to process the deletion, leaking every unit in the queue. Additionally, line 702 called `unit.queue_free()` when a unit had a non-finite transform before being added to a parent.

#### Remediation:
Updated `clear_formation_queue()` and `_deploy_formation_unit()` to check `not u.is_inside_tree()` and call `u.free()` directly:
```gdscript
if is_instance_valid(u):
    if not u.is_inside_tree():
        u.free()
    else:
        u.queue_free()
```
In `test_runner.gd` Test 41 (Case 3), ensured `spawn_director.clear_formation_queue()` is called on all assertion failure paths before `return false`.

---

### 3. Engine Shutdown Frame Deferral

#### Finding:
`test_runner.gd` ran all 49 test suites sequentially inside `_ready()` and immediately called `get_tree().quit(0 if success else 1)` at line 130. Because Godot's deferred deletion queue is processed between frames during the main loop's idle processing, immediate termination in `_ready()` preempted the final deferred deletion sweeps, resulting in false-positive ObjectDB leak warnings on runner exit.

#### Remediation:
Appended frame-wait yields before `quit()`:
```gdscript
# Flush deferred deletion queue over process frames to allow all queue_free()
# invocations to be completely purged from Godot's ObjectDB before shutdown.
await get_tree().process_frame
await get_tree().process_frame

get_tree().quit(0 if success else 1)
```

---

## Verification

- Static AST analysis using custom python inspection script confirmed:
  - 0 unparented nodes calling `queue_free()` across all 7,862 lines.
  - 0 unparented/unfreed dangling references.
  - All EventBus test listeners properly disconnected.
- Fennara `script_diagnostics` confirmed:
  - `res://scripts/tests/test_runner.gd`: 0 errors, 0 warnings.
  - `res://scripts/directors/spawn_director.gd`: 0 errors, 0 warnings.
