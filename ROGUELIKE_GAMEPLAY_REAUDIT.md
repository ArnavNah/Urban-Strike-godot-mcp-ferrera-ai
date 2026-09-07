# Heli-Strike: Survivors-Like Gameplay Re-audit

Date: 2026-09-06  
Workspace: `D:\Heli-Copy`  
Scope: current web build, controls/camera/environment, waves, XP, upgrades, power-ups and missions; recommendations for the Godot starting build. No gameplay changes made.

**User instruction: audit/documentation only.** Do not modify the game or begin the Godot conversion under this request. All fixes, tuning targets and implementation steps below describe future work; they are not implemented or authorized by this audit update. Earlier verification results are retained as dated evidence, not new tests performed for this documentation clarification.

## 1. Verdict

**Yes, this can become a distinctive helicopter action roguelite in Godot. No, everything does not yet match that intended experience.**

The current game is a tactical arcade helicopter shooter with survivor, cargo and extraction systems layered together. Its strongest opportunity is **flying through an urban battlefield while collecting XP and assembling an increasingly spectacular combat build**. The helicopter, destructible city, aerial/ground threats and optional objectives give it an identity worth retaining.

The missing ingredient is not another large feature list. It is a clear priority: movement, readable danger, frequent collection and meaningful build choices should dominate; fuel logistics, altitude management, cargo and extraction should support that loop.

Megabonk's developer description emphasizes hordes, loot/XP, randomized upgrades, synergies and quests. Vampire Survivors emphasizes surviving crowds and choices that snowball. These are useful design references, not requirements to copy either game's camera or every mechanic. [Megabonk](https://store.steampowered.com/app/3405340/Megabonk/) · [Vampire Survivors](https://store.steampowered.com/app/1794680/Vampire_Survivors/)

Interpretation: “questions” is treated as **quests/missions**. Literal quiz questions, dialogue choices or narrative branching would be a separate design decision.

### Intended feel: the target for the future Godot game

The audit evaluates the existing game against the following direction, rather than treating exact reproduction of every current mechanic as the final goal:

- **Identity:** an action roguelike helicopter shooter with the crowd-survival and escalating-build feel requested by the user, using Megabonk and Vampire Survivors as references.
- **Main loop:** move and evade → defeat enemies → collect satisfying XP drops → level up → choose a meaningful upgrade → face stronger encounters with a visibly stronger build.
- **Controls and camera:** responsive, consistent movement and aiming; predictable evasion; a readable battlefield. Camera management should not become a constant task during combat.
- **Progression:** upgrades should change how a run plays, with combinations and increasingly powerful attacks. Field power-ups provide immediate, clearly communicated bursts of advantage.
- **Environment:** preserve the helicopter and urban-combat identity while providing space to dodge, collect XP and read enemy attacks.
- **Missions/quests:** add purpose and optional rewards without interrupting the survival loop or forcing prolonged menu reading.
- **Waves:** document wave-based encounters as a desired direction to refine, noting that the current build already has timed waves. Timed survival versus kill-to-clear remains a design choice, not a settled requirement.
- **Project stage:** a flexible Godot starting foundation, not a final product specification; leave room for the user's additional improvements.

The subsequent controller-first and helicopter-motion discussion is consolidated in Section 10. That section takes precedence for the agreed design direction. Auto-fire defaults, precise bindings, tuning numbers, build examples and slice length remain adjustable proposals, not validated final balance.

## 2. What was actually verified

| Check | Result and limitation |
|---|---|
| Existing automated suite | 337 tests across 22 files passed. |
| Type check / production build | Both passed; build still warns about large bundles. |
| Fresh browser check, 1280×720 | Field Manual, tutorial response to movement/fire, weapon switching, opening Wave 1, combat feedback and pause/menu return checked. |
| Live combat | A rocket shot consumed ammunition; the HUD showed DOUBLE KILL, score 315 and super charge 8%. Hull was 62/100 and XP remained 0% at that observation. This demonstrates combat, not a balanced opening. |
| Targeted production-method probes | Six temporary tests passed, reproducing the dash mismatch, paused-camera drift and XP expiry; verifying altitude-independent collection, queued level-ups and offer diversity/level cap. Probes were removed afterward; they were diagnostic assertions of current behavior, not fixes. |
| Not live-validated | Sustained manual aim/flight, full mouse-orbit gesture, physical controller/touch parity, live XP-to-upgrade selection, completed missions, bosses, extraction and long-run frame rate. |

The browser controls available for this audit support discrete interactions, not a representative continuous player session. **This is not a full gameplay-feel or balance sign-off.** Some existing camera tests recreate their own geometry rather than invoking the engine, so passing them alone cannot establish camera correctness.

No `project.godot`, `.gd` or `.tscn` project was found in the web workspace during that check. A separate, already-started Godot repository was subsequently reviewed online: [Urban Strike Godot project](https://github.com/ArnavNah/Urban-Strike-godot-mcp-ferrera-ai). Continue that project; the earlier absence finding applies only to `D:\Heli-Copy`. Its source review is not a live Godot validation, and the web test results above do not establish Godot test status.

## 3. Current systems versus the intended game

| Area | Already implemented | Fit / remaining work |
|---|---|---|
| Flight | Camera-relative movement, acceleration/braking, banking, altitude safety, boost and dash | Strong base; resolve dash direction and simplify the default control load. |
| Camera | Elevated perspective, free/soft/fixed modes, yaw orbit, recenter, speed/intensity pullback, building ghosting | Suitable 3D starting point, but pause behavior is wrong and dense-city visibility needs testing. |
| Shooting | Four switchable weapons, aim assistance, ammo/reload, salvo, flares and super | More manual/tactical than the target loop. Auto-aim is not a general auto-fire mode. |
| Enemies/waves | Continuous population director, timed wave transitions, themes, miniboss/boss milestones and micro-lulls | Waves already exist; tune them instead of building a second independent director. |
| XP | Enemy gems, magnet attraction, floating rewards, XP bar, run levels and queued choices | Good foundation; expiry and pause clock are major collection risks. |
| Upgrades | 17 options; three distinct, category-diverse choices; damage/status/utility stacks | Add eligibility/caps and clearer build identities; avoid spending scarce levels on weak temporary effects. |
| Power-ups | Repair/ammo/fuel, damage/shield/speed, bomb, magnet surge, EMP and salvage caches | Plenty for a starting build. Improve readability and distinct feedback before expanding. |
| Missions | Cargo, SAM/radar destruction, elite targets, airspace clear, defend, escort, rescue and bounty logic | Already substantial. Keep optional, shorten presentation and make rewards unambiguous. |
| Environment | Streaming districts, buildings, traffic, destructibility, rooftops, weather and night operations | Distinctive, but tactical readability and open maneuvering space must take priority over detail. |

## 4. Priority defects and design gaps

P1 = fix before treating controls/progression as the port's reference. P2 = important clarity/design work for the first playable slice.

### P1 — Dash and movement use different coordinate spaces

- Normal movement projects screen input through the actual camera basis: [engine.ts](D:/Heli-Copy/src/game/engine.ts:6254).
- Keyboard double-taps pass world-axis directions directly into dash: [engine.ts](D:/Heli-Copy/src/game/engine.ts:2615), [triggerDash](D:/Heli-Copy/src/game/engine.ts:2687).
- A production-method probe at a 90-degree camera orientation produced W movement toward world -X, but the W double-tap dash toward world -Z.
- **Required:** movement and directional dash share one input-to-world conversion. Prefer a dedicated dash action; leave double-tap as an optional accessibility/control preference.

### P1 — Pause/upgrade choices do not freeze every gameplay clock

- XP gems inherit a 22-second lifetime. Their age uses supplied absolute time: [entities.ts](D:/Heli-Copy/src/game/entities.ts:4821), [expiry](D:/Heli-Copy/src/game/entities.ts:5084).
- The engine supplies `performance.now()` time, even though simulation stops while paused: [engine.ts](D:/Heli-Copy/src/game/engine.ts:6324).
- A gem alive at time 101 with spawn time 100 expired at time 123 even with zero simulation delta. Consequently, uncollected gems can disappear on resuming after a long pause/upgrade choice.
- Mission bonus deadlines and escort position/expiry also use absolute timestamps: [mission.ts](D:/Heli-Copy/src/game/mission.ts:231). These are additional source-confirmed clock risks, not completed live mission tests.
- **Required:** one pausable run clock for loot, cooldowns, statuses, deadlines and escort movement. Keep presentation/menu animation time separate. Do not expire ordinary XP after a short timer; merge/aggregate it when necessary.

### P1 — Paused camera is treated as the cinematic menu camera

- The paused/upgrade branch calls `updateCamera`, whose `!isPlaying` branch adds yaw drift before checking fixed mode: [engine.ts](D:/Heli-Copy/src/game/engine.ts:6379), [camera branch](D:/Heli-Copy/src/game/engine.ts:7781).
- The probe measured 0.32 radians of drift over ten simulated seconds, approximately 18.3 degrees, even with fixed mode selected.
- **Required:** distinguish MENU, PLAYING, PAUSED, LEVEL_UP and RESULTS. Freeze the combat camera during pause and level-up selection. A cinematic menu camera should not change the player's combat orientation.

### P2 — Some settings and instructions promise more than the runtime supports

- Arcade/Simulation is displayed and stored, but no runtime consumer of `settings.movement` was found; the helicopter update uses one arcade movement model. Implement the distinction or remove the inactive choice.
- The live Field Manual omits keyboard reload, dash, middle-mouse orbit and recenter, although these exist in source.
- Gameplay controller polling implements movement/aim/fire/dash/reload/flares/altitude/orbit/recenter, but no gameplay mappings were found there for weapon cycling, salvo, super or pause. Start handling found in the React menu is not full gameplay support: [engine.ts](D:/Heli-Copy/src/game/engine.ts:6072).
- **Required:** define one action map and generate matching keyboard/controller/help prompts. Do not label controller support complete before a controller-only run, including upgrade selection and results navigation.

### P2 — Upgrade offers can become wasteful

- `pickUpgrades` selects distinct options and favors category variety, but accepts no owned-build/cap information: [logic.ts](D:/Heli-Copy/src/game/logic.ts:1161).
- Effects such as reload and fuel efficiency reach floors, yet can still be offered. Armor also has a stated cap.
- Shield, speed and bomb spend level-up choices on an 8-second shield, 12-second speed boost or immediate blast: [engine.ts](D:/Heli-Copy/src/game/engine.ts:3319). These are legitimate emergency choices, but they compete with permanent-for-this-run improvements.
- **Required:** filter capped/ineligible upgrades, show current → next values, and separate lasting build choices from most field consumables. Rarity, rerolls, bans and evolution prerequisites are future additions, not existing features to port.

### P2 — Mission rewards are technically split but visually misleading

- Live UI simultaneously displayed a 290 CR cargo bounty and “Complete Cargo Run +0 CR.”
- The mission actually adds 12 XP and 2 salvage; its credit field is zero because cargo payment is separate: [mission.ts](D:/Heli-Copy/src/game/mission.ts:192).
- **Required:** show “Cargo bounty: 290 CR” and “Mission bonus: 12 XP + 2 salvage” in one coherent presentation. Do not make a useful mission look unrewarded.

### P2 — Endless progression and mastery need explicit rules

- Run level caps at 15, reached at 595 cumulative XP: [logic.ts](D:/Heli-Copy/src/game/logic.ts:570). Further XP cannot earn level-up choices, although waves can continue.
- Weapon mastery saves the highest level reached, but runtime weapon XP/levels reset on a new run: [engine.ts](D:/Heli-Copy/src/game/engine.ts:1372), [mastery write](D:/Heli-Copy/src/game/engine.ts:3943). It is a persistent record, not proof that those weapon-level combat bonuses carry into the next run. Other purchased meta-upgrades are separate.
- **Required:** decide run duration/cap behavior and distinguish run power, mastery records and permanent purchases in the UI/save model.

### Engineering risk — Camera obstruction is only partially addressed

The camera checks building height at its intended endpoint and compresses its boom to 65%; it does not sweep the entire boom in this method. Building ghosting is separate: [engine.ts](D:/Heli-Copy/src/game/engine.ts:7820). This is not proof every tower causes clipping, but it needs a tower/roof/orbit test matrix rather than a formula-only test.

## 5. Recommended controls and camera contract

**Keep a 3D helicopter game; make the default experience movement-first.** These are proposed Godot behaviors, not changes already made.

| Function | Current keyboard/mouse | Recommended starting behavior |
|---|---|---|
| Move | WASD / arrows, camera-relative | Retain; movement direction remains predictable at every camera yaw. |
| Aim/fire | Mouse + hold LMB | Offer an assisted auto-fire preset and a manual-aim preset. Clearly distinguish auto-aim from auto-fire. |
| Dash | Double-tap movement | Dedicated bind, using current movement direction; optional double-tap. |
| Altitude | Space/PageUp and Alt/PageDown | Default terrain-safe altitude assistance; manual altitude as an advanced option. |
| Boost | Hold Shift, consumes fuel | Retain only if it adds a useful choice beyond dash; avoid constant fuel maintenance in the opening. |
| Special abilities | Q/RMB salvo, C flares, E super | Introduce gradually; do not require all three during the first minute. |
| Weapons/reload | 1–4 / wheel; R; reload on empty when firing | Automatic reload; prototype one main weapon plus passive/automatic build effects before requiring frequent switching. |
| Orbit/recenter | Middle drag yaw; X or V | Fixed elevated default view for the first slice, optional free orbit, one clearly documented recenter bind. |
| Pause | Esc/P | Freeze combat, camera, pickups, mission clocks and upgrade state; no held-input leakage on resume. |

Current camera baseline is perspective FOV 52, distance 36 and height 28 above the aircraft, with velocity look-ahead, smoothing and speed/combat expansion. Retain these as comparison data, not unquestionable final values.

Judge the camera by whether the player can see approaching threats, a safe escape path and nearby XP. Test a somewhat higher/wider framing against the current one; do not widen FOV until enemies become unreadable. Keep screen shake restrained and independently disableable.

## 6. XP, upgrades and power-up experience

The current collection foundation is good: cyan spinning gems, attraction accelerating toward the helicopter, pickup feedback and an XP bar. Base attraction starts within 24 horizontal units; collection is within 14 units and ignores altitude. This is appropriate for a flying survivor game: collecting a ground drop should not require landing. [Collection code](D:/Heli-Copy/src/game/engine.ts:7432)

Current XP costs: level 2 at 10 total XP, level 3 at 25, level 4 at 45, level 15 at 595. Standard enemy values range from 1 for basic enemies to 3 for drones and 5 for tanks; elites grant 15 and bosses 50, with variant-specific values. A 50-XP grant at level 1 correctly queues **three** choices; queued picks are already implemented.

Recommended feedback chain:

1. Kill: readable hit/death feedback; drop position identifiable among explosions.
2. Approach: gems accelerate toward the helicopter, with short trails and a rising, rate-limited collection sound.
3. Collect: visible XP-bar gain; group floating numbers during large pickups to avoid visual noise.
4. Level up: a brief celebration, then three readable choices with actual values, owned rank and effect preview.
5. Resume: immediate visible or audible change to the build; restore the same camera and encounter state.

First-slice build examples: chain-lightning crowd control; burning explosive splash; orbiting defensive drones. Start with a small set that changes attack behavior, not only damage percentages. These are proposed build identities, not all existing content.

Suggested tuning hypotheses, to measure with new players: first kill within 5–10 seconds after GO, first level-up within 20–40 seconds, first clearly recognizable build by 2–3 minutes. Exclude tutorial time from those measurements. Do not treat these targets as current measured performance.

## 7. Waves, environment and missions

### Waves already exist

`waveDuration` begins at 45 seconds, falls by 1.5 seconds per wave, and reaches a 30-second floor. Transitions add a two-second spawn breather. Progression is time-based, **not kill-every-enemy-to-clear**. There are miniboss triggers every fifth wave and gunship bosses every tenth; the fifth-wave condition also includes tenth waves, so validate simultaneous milestone pressure. [Wave timing](D:/Heli-Copy/src/game/logic.ts:509) · [director](D:/Heli-Copy/src/game/engine.ts:5792)

Keep one director with phases: introduction → pressure → elite event → collection respite → next wave. If a separate arena/clear-wave mode is desired later, implement it as an explicit mode with different completion rules. “WAVE COMPLETE” is misleading when the previous enemies remain alive.

The normal population target is capped against 48 in the director; this is not a verified global cap across every event/boss spawn path. More enemies are not automatically better: build the feeling of hordes with clear fodder, flanking threats and a few dangerous specials. Profile before raising counts.

### Environment

- Preserve the city and destruction as the game's visual hook.
- Start in an open plaza/avenue network with escape routes in several directions; use towers to shape routes, not continuously hide combat.
- Current scenery extends to ±512 X, but the player is constrained to ±210 X. Make the playable edge readable; do not imply every visible district is accessible. [World](D:/Heli-Copy/src/game/city.ts:138) · [flight bounds](D:/Heli-Copy/src/game/entities.ts:156)
- Reserve contrast for enemies, hostile projectiles and XP. Reduce competing traffic lights, smoke, weather and background saturation when combat becomes busy.
- Keep mission targets and meaningful loot valid when streaming chunks. XP also has a separate 520-unit distance cleanup rule; preserve its value through aggregation if changing persistence.

### Missions/quests

Start with three optional, combat-compatible types: destroy an elite, defend a beacon briefly, rescue/recover a marked target. Introduce cargo and escort after the basic loop works. Show one tracked mission, its distance/progress and real rewards. Use mission success to create a short pressure relief or a useful pickup payoff; never require reading a long objective during a swarm.

The current 1280×720 view places objectives, mission, cargo, radar, XP, hull/fuel, weapon and credits around the battlefield. Collapse secondary information; prioritize the player, threats, XP, level choice and one objective.

## 8. Godot starting scope and acceptance gates

Build a **5-minute vertical slice**: one helicopter, one city arena, three enemy roles plus one elite, one main weapon with several behavior-changing upgrades, XP collection, three-card level-ups, timed waves, one optional mission, and start/pause/results/restart. A final elite can end this slice; the full boss/overdrive cadence comes later.

Use focused native systems: player controller, camera rig, weapon system, spawn director, run progression, pickup manager, mission director and UI. Store tuning/upgrade definitions as data. Keep the existing web project untouched as a reference and develop the Godot project alongside it.

For a third-person rig, Godot's `SpringArm3D` supports a collision sweep; use correct exclusions and test near-plane clearance, with building fading where still useful. [Godot camera guidance](https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html)

Use pausable gameplay processing and a pause-capable UI, plus an explicit run clock; merely pausing the scene does not make external wall-clock calculations safe. [Godot pause/process-mode guidance](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html)

Acceptance checklist:

- [ ] Movement and dash agree at 0°, 90°, 180° and 270° camera yaw on keyboard and controller.
- [ ] Pause/level choice for 30 seconds leaves XP, encounter timers, mission/escort state and camera unchanged.
- [ ] Every gameplay/settings/manual action has a real implementation and matching prompt.
- [ ] Fresh players can reach the first level-up without learning cargo/extraction/altitude management first.
- [ ] Multi-level XP awards produce exactly one valid choice per earned level; no capped/dead options.
- [ ] Three distinct builds are recognizable from what happens on screen by the end of the slice.
- [ ] Pickup behavior works across flight heights and rooftops, and no XP value is silently lost during aggregation.
- [ ] Wave transitions, overlap and elite timing are explicit; optional missions cannot block survival progression.
- [ ] Player and nearby danger stay visible around towers and in weather, with shake/flash reduction tested.
- [ ] Controller-only navigation works from launch through upgrades, pause, results and restart.
- [ ] Define target hardware and measure frame-time percentiles at peak enemies/projectiles/loot; do not infer performance from the web build passing tests.

## 9. Corrections to the earlier audit

- `RAM` identifies an enemy proximity collision, not a building collision. Buildings report `BUILDING` separately. The earlier short run does not establish environmental-collision lethality: [ram](D:/Heli-Copy/src/game/engine.ts:7138), [building damage](D:/Heli-Copy/src/game/engine.ts:3139).
- A one-second global environment-collision damage cooldown already exists. Validate its tuning rather than list it as a missing feature.
- Waves, magnet collection and multi-level upgrade queuing are already present.
- Arcade/Simulation UI and saved mastery should not be mistaken for two implemented flight models or carried-over runtime weapon levels.

**Future implementation recommendation, only after a separate request:** resolve the three P1 control/clock/camera issues in the reference or explicitly make them corrected-parity requirements, then build the small Godot survivor slice. Add content after that loop is demonstrably fun. For the present request, stop at documentation and leave the game unchanged. The project has potential, but feature count alone is not evidence of retention or commercial success.

## 10. Final design direction and Codex/Fennara handoff

### Creative direction

Combine the helicopter-combat identity the user associates with **Nuclear Strike / Urban Strike** with a modern presentation and the survival/XP/build progression they want from **Vampire Survivors / Megabonk**. These are creative references, not instructions to reproduce proprietary assets, exact maps or an entire other game's control scheme.

The player should feel like a powerful attack-helicopter pilot in an urban battle while making frequent movement, target and build decisions. Preserve ground/air threats, destruction and optional tactical missions. Prioritize readable modern lighting, silhouettes, weapon feedback and effects; do not assume the web prototype's low-resolution filter is the required final look.

### Controller-first movement with physical helicopter response

- Controller is the primary design target; keyboard/mouse remains fully supported and remappable, including every menu and upgrade screen.
- Preferred control direction: camera-relative left-stick/WASD movement, independent right-stick/mouse aim, aim assistance and a stable elevated camera. A/D move sideways, rather than turning the helicopter first. Prototype this deliberately in the existing project; it differs from its current heading-relative controller.
- Physical response means acceleration into velocity, inertia, responsive braking, collision-aware travel and gentle vertical settling. It does **not** require an uncontrolled rigid-body simulation. The existing CharacterBody3D approach can remain the foundation for a custom arcade flight model.
- Small stick deflections permit fine positioning. Full deflection provides the normal flight envelope. Keep diagonal speed bounded consistently with straight movement.
- Show subtle forward nose-down pitch, reverse/braking nose-up pitch and lateral banking. Add gentle hover bob and smooth vertical corrections; avoid repeated bouncing or abrupt altitude snaps.
- Keep visual bank/pitch/bob separate from the stable collider and camera tracking point. Aiming and projectile origins must remain consistent with the actual weapon mount.
- Prefer assisted altitude during ordinary combat and XP collection; manual altitude remains an advanced option. Define collision-safe terrain/roof clearance and ceiling behavior during implementation.
- Dash follows the movement vector in the same coordinate space. Freeze camera orientation and gameplay clocks during pause/upgrade selection.

### Proposed bindings to validate, not immutable controls

| Action | Controller | Keyboard/mouse |
|---|---|---|
| Move | Left stick | WASD |
| Manual aim | Right stick | Mouse |
| Primary fire | RT/R2 | Hold LMB |
| Secondary lock/fire | LT/L2 | Hold RMB to acquire, release to launch if valid |
| Directional dash | LB/L1 | Space |
| Flares | RB/R1 | C |
| Super | Remappable face button | E |
| Pause | Menu/Options | Esc/P |
| Optional manual altitude | Bind after controller ergonomics test | Q climb / Z descend |

Mouse motion should not rotate the camera. Controller manual aim can yield back to assistance after release; mouse override needs an intentional, tested priority rule. Do not infer automatic firing merely from assisted targeting. If the aircraft's nose follows the intended attack direction, define weapon traversal limits so independent movement and aiming do not produce misleading shots.

### Continue the existing Godot project, not a new conversion

Use [the existing repository](https://github.com/ArnavNah/Urban-Strike-godot-mcp-ferrera-ai) as the implementation base. Its movement document currently specifies heading-following flight/camera, while its broader GDD also discusses orbit; reconcile those documents against the latest user direction before implementing controls.

Carry forward the online-review findings as **Godot-specific verification items**: altitude-sensitive XP magnet acquisition, single-level processing of large XP awards, empty upgrade-offer handling, incomplete Repair Drone behavior and mismatched upgrade/player properties. Do not copy the web game's defect list into the Godot backlog as if every defect is reproduced there. Existing sphere-shaped SpringArm obstruction and scene-tree pausing are different implementations that need their own validation.

### Codex + Fennara workflow

The user intends to build with Codex and [Fennara Godot AI](https://github.com/fennaraOfficial/fennara-godot-ai). Fennara documents scene inspection, script diagnostics, screenshots, runtime errors and validation through MCP. Reading that documentation does not verify a live connection or the installed addon version.

For a future implementation task:

1. Read this audit, the project's `AGENTS.md`, and its installed `addons/fennara/ai/guidelines.md`. Discover the live tools; do not assume tool names from another MCP or addon version.
2. Confirm the active Godot project and inspect the existing scenes, scripts and diagnostics without changing anything.
3. Produce a gap checklist: existing/working, incomplete, conflicting, missing, runtime verification required. Make this audit's newest design direction explicit while retaining compatible project structure.
4. After implementation is requested, work in small milestones on a separate branch. Preserve unrelated work and the Fennara infrastructure. Use Godot-aware operations for authored scenes/resources according to the installed guidance.
5. Validate affected scripts/scenes, inspect rendered output and test controller and keyboard behavior. Record observed outcomes and limitations; a saved test log alone is not a current pass.

Suggested first message in the Godot project:

> Read ROGUELIKE_GAMEPLAY_REAUDIT.md, especially Section 10, and the project's AGENTS.md/Fennara guidelines. Inspect this existing Godot project through source review and read-only Fennara tools. Compare its current implementation with the controller-first, physics-responsive helicopter survivor direction. Produce a prioritized gap checklist and identify conflicting design instructions. Do not edit, install, download or run anything yet. Do not restart or replace the project.

This audit is ready as a **starting design and continuation brief**, not a claim that the Godot game is complete, balanced or fully tested. No game implementation is authorized by this documentation handoff alone.
