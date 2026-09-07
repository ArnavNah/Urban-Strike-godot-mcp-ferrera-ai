# XP, upgrade and pause reliability milestone

Completed 2026-09-07 using the installed Fennara 0.4.2 MCP, Godot 4.7.2, Compatibility/OpenGL. Project: URBAN Strike Rogue. Branch: codex/xp-upgrade-pause-reliability.

## Verified defects and changes

- Player magnet acquisition used full 3D distance. It now uses horizontal distance with the existing radius. Gems accelerate toward the helicopter in 3D using a clamped movement step, then award XP once. Missing progression owners no longer consume a gem.
- XP used one threshold check. It now processes every threshold, retains the existing 1.45 threshold curve, and queues each earned level in order.
- Finite upgrade choices could become empty. The modal now presents an explicit Continue option when no eligible upgrades remain. Earned levels and XP stay intact; no substitute currency, healing or other balance reward was invented.
- Upgrade and pause menus independently toggled the global pause flag. RunStateController now tracks distinct upgrade/menu pause reasons. Upgrade selection consumes pause input and preserves any earlier menu pause. An overlapping pause menu is hidden during the upgrade, then restored with focus. Held confirmation/fire input must be released before combat resumes.
- RunStateController processes while paused; its run clock now explicitly checks tree pause. Attack-slot leases now use accumulated gameplay time, replacing wall-clock expiry. Wave autostart and explosion/impact/spawn-telegraph fallback lifetime timers are pausable. Native timers, weapon cooldowns and bound tweens already inherited pause.
- Reinforced Airframe wrote the computed max_speed getter. It now changes max_forward_speed, retaining its existing +35 hull/-10% top-speed behavior.
- Hellfire now clears an existing overheat lock immediately when acquired, in addition to its existing doubled fire rate and zero heat-per-shot behavior.
- Upgrade application rejects duplicates, unoffered selections, unavailable effects and missing/dead players. Purchases are recorded only after an effect succeeds.
- Upgrade buttons have predictable focus navigation. Controller A confirmation is handled locally by the modal because the project's ui_accept action currently contains only keyboard events. InputMap was not changed.

Files changed by this milestone: scripts/player/player_helicopter.gd (magnet function only), scripts/pickups/xp_gem.gd, scripts/managers/upgrade_manager.gd, scripts/ui/level_up_menu.gd, scripts/ui/pause_menu.gd, scripts/common/run_state_controller.gd (pause ownership and clock), scripts/directors/combat_director.gd, scripts/managers/wave_manager.gd (autostart timer only), and three gameplay VFX lifetime scripts.

## Effects and explicit design conflicts

Four effects remain eligible: Twin Barrel, Overclocked Feed, Reinforced Airframe and the prerequisite-gated Hellfire Minigun. Their existing card tuning is retained.

Five incomplete effects are withheld from offers and reject direct purchases rather than presenting misleading benefits:

| Effect | Unresolved contract |
|---|---|
| Armor-Piercing Rounds | Existing generic damage multiplier did not implement ground-armor versus air specialization; armor classification is unresolved. |
| Rapid Lock | GDD specifies one target, while the card specifies an unquantified narrower cone. |
| Afterburner | GDD specifies +20% strafe/resupply drain; card specifies +25% strafe/longer deceleration. Resupply and deceleration contracts are incomplete. The invalid acceleration property reference is removed with the incomplete effect. |
| Repair Drone | GDD disables repair below 25% HP; card disables it while overheated. Existing effect was a no-op. |
| Siege Cannon | GDD specifies ground damage and a second pierced target; card describes ground blast and penetration. Existing generic damage increase supplied neither complete behavior. |

Overclocked Feed's older GDD eight-second overheat rule differs from the existing card's +25% heat per shot; this milestone preserves the implemented card tuning. The latest audit Section 10 takes precedence for future movement/camera direction, but those systems were explicitly outside this task.

## Actual verification

All milestone GDScript edits passed Fennara diagnostics. Fresh runtime preflights checked 24 attached/autoload scripts and the isolated scene with zero errors or warnings. The final two managed runtime logs contain no engine errors/warnings or failed assertions. Screenshots were visually inspected at 1280x720.

Controlled tests used a scratch copy of the battlefield with GameManager removed before launch and WaveManager autostart disabled. Runtime setup/probes are under .fennara/scripts/runtime; the fixture is .fennara/scenes/reliability_fixture.tscn. These are ignored private scratch, not production scenes.

| Check | Observed result |
|---|---|
| Altitude-independent acquisition | Ground gems collected at helicopter heights 2.6, 14 and 26; an elevated gem at 22 collected from 26. Distance decreased monotonically; exactly one award per gem. |
| Magnet boundary | Gem outside the unchanged horizontal radius remained unattracted. |
| Large award | 250 XP from level 1 produced level 4, 24/150 XP and queued levels [2,3,4]. |
| Queue confirmation | Keyboard and injected controller events each resolved exactly one choice; duplicate submissions rejected. |
| Pause ownership | Escape, controller Menu and direct pause-menu toggle could not release upgrade pause. An earlier menu pause survived upgrade completion and regained focus. |
| Paused gameplay | After 30 seconds, run time, wave/spawn timers, gun/missile cooldowns, attack-lease clock, camera/player transforms and XP matched their initial snapshot. Timers resumed afterward. |
| Exhausted pool | Three earned levels retained their remainder and each received Continue. Mouse, keyboard and controller resolved them without fake upgrades or an empty modal. Nested pause also passed. |
| Upgrade effects | Twin/Overclocked multipliers, Airframe hull/speed, Hellfire prerequisites, immediate heat-lock removal and 40 actual zero-heat shots passed. One/two/three-card pools and all withheld-effect rejections passed. |
| Other gameplay timers | Explosion, impact and telegraph survived pause, then expired after resume. Wave autostart waited through pause and entered countdown after resume. |
| Duplicate gem callback | Calling collection twice before deletion awarded XP once. |
| Final UI | Controller D-pad and left stick moved focus; A selected the focused card. Final exhausted text and mouse Continue passed after the last text edits. |

Authoritative clean runtime sessions:
- runtime-611690: queue/pause, effects, exhaustion, collection and timers.
- runtime-811665: final UI text, controller navigation and Continue smoke check.

Logs are below the Godot user-data directory:
- .fennara/tool_logs/D__GODOT_Urban-Strike-godot-mcp-ferrera-ai__15140/results/tool_182_runtime_session/runtime_session.log
- .fennara/tool_logs/D__GODOT_Urban-Strike-godot-mcp-ferrera-ai__15140/results/tool_253_runtime_session/runtime_session.log

Earlier bootstrap and externally disturbed input runs were rejected, not counted as passes. An input-free observation preceded the clean rerun. All managed test sessions were stopped.

## Save safety and scope limits

The fixture contains no GameManager/save-writing gameplay owner. This task did not run the existing broad test runner, which exercises persistence. No save was deleted, restored or overwritten by these probes.

A save_data.json appeared during concurrent workspace activity after initially being absent. Its writer was not identified. From first observation through the final controlled tests its SHA-256 remained:
218C1D4114963E05A546F73CA297F833AA752CEC915A46804D706F1DBFFC647E

Other changes appeared concurrently in camera, targeting, enemy, test, mission/endless and lifecycle files, including separate sections of WaveManager/RunStateController. They were preserved and are not claimed as milestone implementation or validation. Whole-run mission/endless/death integration and physical controller hardware were not tested. Controller coverage used Godot input-event injection.

No movement/camera behavior, gameplay input mappings, mission/endless rules or unrelated balance was intentionally changed by this milestone. No commit or merge was made.
