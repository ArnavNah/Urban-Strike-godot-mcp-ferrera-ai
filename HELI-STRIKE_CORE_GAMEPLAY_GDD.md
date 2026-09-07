# HELI-STRIKE

## Core Gameplay & Systems Design Document

**Document type:** Game Design Document / Implementation Reference  
**Status:** Working specification  
**Primary genre:** 3D Arcade Helicopter Combat Roguelite  
**Secondary genres:** Action Roguelite, Wave Survival, Vehicle Combat, Twin-Stick-Inspired Shooter, Light Extraction  
**Platform target:** PC / browser-first build  
**Player count:** Single-player  
**Current player vehicle:** AH-9 Vulture  
**Run structure:** 10 escalating waves → boss → extract or continue into Endless Overdrive

> This document combines the confirmed 12-point gameplay definition with the full HELI-STRIKE Field Manual. Confirmed core rules take priority over older or less-specific notes. Items that still require tuning are marked **TBD**.

---

## 1. Game Summary

HELI-STRIKE is a fast, accessible 3D arcade helicopter combat roguelite. The player pilots the fictional AH-9 Vulture through a battlefield filled with infantry, tanks, SAM sites, radar installations, and hostile aircraft. The helicopter uses responsive physics-based movement, but the game is deliberately not a flight simulator.

The player's skill comes from:

- Flying and positioning well.
- Strafing while keeping the helicopter's nose aligned with a target.
- Reading threat indicators and enemy attack tells.
- Using buildings and terrain as real line-of-sight cover.
- Choosing the correct target and weapon under pressure.
- Managing chaingun heat, missile locks, flares, health, and resources.
- Creating a strong build through upgrade choices with meaningful trade-offs.
- Deciding whether to extract safely or risk earned Salvage in Endless Overdrive.

The game combines:

- Arcade helicopter movement and combat.
- Twin-stick-inspired independent movement and aiming.
- Auto-assisted targeting that reduces control burden.
- Survivor-style XP collection and upgrade choices.
- Directed wave pressure instead of uncontrolled enemy spam.
- A small extraction decision and permanent Hangar progression.

### One-sentence pitch

Pilot an agile attack helicopter through ten increasingly dangerous waves, build a powerful but specialized loadout, defeat a multi-phase gunship boss, then extract your Salvage or risk everything in Endless Overdrive.

---

## 2. Design Identity

### 2.1 What HELI-STRIKE is

HELI-STRIKE is:

- A 3D arcade helicopter action game.
- A run-based roguelite.
- A wave-survival game with curated escalation.
- A positioning-focused vehicle combat game.
- A game with assisted aim rather than constant mandatory manual aim.
- A battlefield where visible enemy count and active attack pressure are separate systems.

### 2.2 What HELI-STRIKE is not

HELI-STRIKE must not become:

- A realistic helicopter simulator.
- A generic Vampire Survivors clone.
- A traditional twin-stick shooter that requires manual aiming for every bullet.
- A bullet-hell game where every visible enemy attacks at the same time.
- A circle-strafing game where air enemies endlessly chase the player.
- A wave game that scales only enemy HP and damage.
- A boss fight made by enlarging a regular enemy and multiplying its stats.
- A game where buildings are only visual decorations and projectiles pass through them.

### 2.3 Core design pillars

#### Pillar 1 — Flying is the main skill

The helicopter should feel fast, weighty, responsive, and easy to understand. The player spends attention on positioning and danger, not on wrestling with simulation controls.

#### Pillar 2 — Assisted aim, meaningful targeting

The chaingun automatically handles routine target tracking. Manual aim remains available for precision, target switching, suppression fire, or prioritizing a dangerous enemy.

#### Pillar 3 — Directed pressure, visible warfare

The battlefield may contain many enemies, but the Combat Director limits how many can actively attack. This creates the feeling of a large battle without unreadable damage spam.

#### Pillar 4 — Ground controls space; air controls tempo

Ground enemies create threat zones and defend territory. Air enemies dynamically pressure the player through deliberate attack runs and repositioning cycles.

#### Pillar 5 — Every run creates a build and a decision

Within-run upgrades should create specialization through benefits and costs. After the boss, the player must decide between banking Salvage or continuing for greater rewards.

---

## 3. Core Player Experience

The intended moment-to-moment thought process is:

1. Read nearby threats and objectives.
2. Move toward a safe and useful attack position.
3. Keep dangerous enemies in the weapon arc while avoiding exposure.
4. Let auto-aim handle the nearest valid threat or manually override it.
5. Choose between chaingun, guided ordnance, or defensive flares.
6. Break enemy line-of-sight using buildings when pressure becomes unsafe.
7. Destroy priority targets such as SAM or Radar before clearing weaker units.
8. Collect magnetized XP and select a build-defining upgrade.
9. Survive the changing enemy composition of the current wave.
10. Defeat the Archon and decide whether to extract or continue.

### Intended emotional rhythm

| Stage | Player feeling |
| --- | --- |
| Deployment | Ready, powerful, mobile |
| Early wave | Confident, learning threat language |
| Pressure increase | Alert, actively prioritizing targets |
| Level-up | Relief, anticipation, strategic choice |
| Air-enemy introduction | Surprised, hunted, forced to reposition |
| Wave 9 | Near-overwhelmed but still in control |
| Boss | Focused, challenged by readable phases |
| Extraction choice | Relief versus greed |
| Hangar | Rewarded, planning the next run |

---

## 4. Complete Gameplay Loop

### 4.1 Run loop

1. **Prepare in the Hangar**
   - Spend previously banked Salvage.
   - Choose available starting loadout options.
   - Review permanent upgrades.

2. **Deploy**
   - Enter the battlefield in the AH-9 Vulture.
   - Begin with the selected starting equipment and baseline stats.

3. **Fight**
   - Eliminate enemies.
   - Manage positioning, heat, locks, damage, and defensive cooldowns.
   - Complete the current wave and any active objective.

4. **Collect XP**
   - Enemies drop XP pickups.
   - Pickups magnetize toward the player when within collection radius.

5. **Level up**
   - Pause combat.
   - Present three upgrade cards.
   - The player selects one card.
   - Standard cards should include a meaningful trade-off or build commitment.

6. **Escalate**
   - Increase enemy composition complexity.
   - Increase the ground and air spawn budgets.
   - Increase active attack slots only at planned breakpoints.

7. **Complete wave 10 boss**
   - Fight the Archon Heavy Gunship.
   - Normal enemy pressure is reduced during the encounter.

8. **Choose a run outcome**
   - **Extract:** Bank earned Salvage safely and return to the Hangar.
   - **Endless Overdrive:** Continue into higher-risk scaling for better rewards.

9. **Return to Hangar**
   - Spend banked Salvage on permanent progression.
   - Start another run.

### 4.2 Progression layers

| Layer | Timescale | Systems |
| --- | --- | --- |
| Combat | Seconds | Movement, target priority, LOS, heat, locks, flares |
| Within-run | Minutes | XP, levels, three-card upgrades, evolutions, rarity |
| Run outcome | End of run | Extract or Endless Overdrive, Salvage banking |
| Meta progression | Between runs | Hangar upgrades, unlocks, insurance, loadout capacity |

---

## 5. Player Helicopter — AH-9 Vulture

### 5.1 Movement philosophy

The AH-9 Vulture uses physics-based arcade movement. It should preserve momentum and show convincing banking, but input response must remain fast and predictable.

The helicopter should feel:

- Aggressive rather than floaty.
- Smooth rather than robotic.
- Heavy enough to communicate mass.
- Responsive enough for close-range cover use.
- Stable enough that auto-aim and weapon feedback remain readable.

### 5.2 Confirmed baseline values

| Property | Baseline |
| --- | ---: |
| Maximum speed | 137 KPH / approximately 38.1 m/s |
| Acceleration | 42 m/s² |
| Minimum altitude | 2.6 m |
| Maximum altitude | 26 m |

These values are initial gameplay baselines and should be tuned against the final environment scale.

### 5.3 Movement behavior

- Left stick or WASD controls horizontal flight movement.
- Movement is not restricted to the helicopter's forward axis.
- The helicopter visually banks into movement.
- Q/E or controller bumpers perform lateral strafe input without forcing the nose to turn.
- Strafing exists so the player can reposition while maintaining weapon alignment.
- Visual banking must not change the actual aim solution or make the helicopter feel unstable.
- Camera heading and movement direction remain independent.
- Vertical movement must stay inside the 2.6–26 m altitude envelope.

### 5.4 Facing rules

The helicopter's body should not snap toward every auto-aim target. The chaingun or weapon mount tracks the target independently within its allowed arc. Body-facing changes should come from deliberate movement/facing logic, not from the gun choosing a target.

### 5.5 Visual response

The helicopter should communicate movement through:

- Roll while moving or strafing laterally.
- Pitch while accelerating forward or backward.
- Smooth recovery toward level flight when input is released.
- Rotor animation tied to active flight state.
- Downwash dust near the ground.
- A readable shadow to communicate altitude.

Visual tilt should be smoothed and must never produce camera shake or movement jitter.

---

## 6. Controls and Camera

### 6.1 Core control mapping

| Action | Controller | Keyboard / mouse | Result |
| --- | --- | --- | --- |
| Move | Left stick | WASD | Horizontal flight movement |
| Strafe | Bumpers | Q / E | Lateral repositioning without turning the nose |
| Aim override | Right stick | Mouse movement / aim | Temporarily overrides auto-aim |
| Camera orbit | Hold LT/L2 + right stick | **TBD** | Horizontal 360° orbit; vertical angle locked |
| Recenter camera | R3 | **TBD** | Smoothly returns camera to default heading |
| Chaingun | **TBD** | **TBD** | Fires primary weapon |
| Guided ordnance | **TBD** | **TBD** | Locks and fires rockets/missiles |
| Flares | **TBD** | **TBD** | Breaks a valid SAM/missile lock |
| Altitude | **TBD** | **TBD** | Raises or lowers the helicopter within its allowed range |

> Weapon and altitude bindings were not fully defined in the source manual. They must be finalized before the input map is treated as implementation-ready.

### 6.2 Camera behavior

- The camera follows from a high, angled third-person perspective.
- Horizontal orbit supports a full 360°.
- Vertical orbit is locked to preserve combat readability.
- Recenter should interpolate smoothly rather than snap.
- Camera movement must not rotate the helicopter automatically.
- Movement input should remain understandable while the camera is rotated.
- Camera collision handling must prevent buildings from blocking the view.
- Collision correction should move the camera closer to the helicopter and smoothly restore the normal distance after the obstruction clears.
- Camera shake should be short, weapon-specific, and capped so it never harms control.

---

## 7. Targeting and Aim Assistance

### 7.1 Default auto-aim

When no manual aim input is present, the chaingun automatically locks onto the closest valid target.

A valid target must:

- Be alive and targetable.
- Be inside the weapon's acquisition range.
- Be inside the allowed weapon arc.
- Have a clear line of sight from the weapon origin.
- Not be hidden behind a building or solid obstacle.

### 7.2 Manual override

When the player moves the right stick or uses the mouse:

- Manual aim immediately takes priority.
- The player can select a different enemy or aim at a ground point.
- Manual aim uses the same line-of-sight rules as auto-aim.
- The override remains active briefly after the last input.
- After the settle delay, aim returns smoothly to automatic target acquisition.

### 7.3 Target scoring

The default target is described as the closest valid target. A small deterministic scoring system may be used internally, but it must preserve the player's expectation that nearby threats are selected first.

Recommended scoring inputs:

- Distance.
- Whether the target is currently attacking the player.
- Whether the target is a critical threat, such as a locking SAM.
- Aim-angle difference from the current gun direction.
- Clear line of sight.

Target switching must avoid rapid flickering between two similarly scored enemies. Use target persistence and a replacement threshold.

### 7.4 Aim feedback

The HUD should distinguish:

- Auto-acquired target.
- Manually selected target.
- Missile lock in progress.
- Confirmed missile lock.
- Target obstructed by cover.
- Target outside valid weapon arc or range.

---

## 8. Weapons and Defensive Systems

### 8.1 Weapon roles

The three core systems have distinct jobs:

| System | Role | Primary limitation |
| --- | --- | --- |
| Chaingun | Fast sustained damage, especially against agile targets | Heat and overheat lockout |
| Guided rockets/missiles | High burst damage against armor, objectives, and groups | Requires lock; slower cadence |
| Flares | Break hostile missile/SAM lock | Defensive only; limited cooldown or charges |

There should be no hard enemy immunity. Weapon roles are best-fit advantages, not mandatory rock-paper-scissors rules.

### 8.2 30 mm chin-mounted chaingun

**Role:** Primary weapon  
**Baseline fire rate:** 11.5 rounds per second  
**Resource:** Heat  
**Overheat penalty:** 2.5-second firing lockout

Behavior:

- Tracks the active auto or manual aim target independently of the helicopter body.
- Builds heat while firing.
- Cools when firing stops.
- Stops firing when fully overheated.
- Clearly communicates heat through UI, audio, barrel effects, and firing cadence.
- Cannot hit targets through buildings.

### 8.3 Guided rocket and missile pods

**Role:** Secondary burst weapon  
**Baseline damage:** 45  
**Baseline splash radius:** 3.2 m  
**Baseline lock time:** 0.95 s

Behavior:

- Requires a valid target lock for guided use.
- Displays lock acquisition progress.
- Loses or pauses lock if the target is fully obstructed.
- Deals strong damage to tanks, SAM sites, radar objectives, and grouped ground units.
- May use separate rocket and missile behavior later, but the first playable slice can treat them as one guided secondary system.

### 8.4 Thermal countermeasure flares

**Role:** Defensive system  
**Confirmed effect:** Breaks a SAM/missile lock  
**Additional Field Manual effect:** Scrambles radar for 3.5 seconds

Behavior:

- Has no direct offensive damage.
- Must be timed after a lock warning or missile launch.
- Gives strong audio and visual confirmation when successful.
- Must not become a permanent immunity button.
- Uses a cooldown, limited charges, or resupply resource; exact economy is **TBD**.

### 8.5 Late-game weapons

Railgun and laser concepts are reserved for later progression. They are not part of the minimum first playable loadout unless explicitly added after the core three systems are stable.

---

## 9. Line of Sight, Cover, and Collision

Buildings and solid battlefield objects are real gameplay cover.

### 9.1 Required rules

- Player auto-aim cannot lock through buildings.
- Player manual fire cannot pass through buildings.
- Ground enemies cannot detect or fire through blocked LOS unless a specific enemy ability says otherwise.
- Air enemies must also respect projectile LOS even if their navigation is not limited by cover.
- Guided weapons must react consistently when LOS is lost.
- Explosion splash must use a clearly defined obstruction rule.

### 9.2 Recommended implementation model

- Use physics collision layers for world geometry, player projectiles, enemy projectiles, target detection, and navigation blockers.
- Perform LOS raycasts from actual weapon or sensor origins rather than entity centers where practical.
- Use the same world-obstacle definition for player and enemy targeting.
- Avoid per-frame raycasts from every inactive enemy; prioritize active attackers and nearby candidates.

### 9.3 Design purpose

Cover creates meaningful helicopter positioning. The player should be able to:

- Break a SAM lock behind a building.
- Avoid tank fire by crossing behind structures.
- Expose only long enough to launch a missile.
- Choose a safer route to an objective.

---

## 10. Enemy Design

### 10.1 Two fundamental behavior families

#### Ground enemies — territorial turrets

Ground units occupy and defend space. They use a fixed or limited movement area, a threat range, line-of-sight checks, readable aim states, and weapon cooldowns.

#### Air enemies — hunters

Air units create dynamic pressure. They approach, commit to an attack run, break away, reposition, and then start another run. They must never remain permanently glued to the player in an endless chase-circle-shoot loop.

### 10.2 Infantry Cluster

**Type:** Ground  
**Composition:** 3–6 soldiers  
**Damage:** 1.2 per shot  
**Pattern:** 3–5-round bursts  
**Role:** Low-threat pressure and early-wave teaching enemy

Rules:

- Low individual accuracy.
- Dangerous mainly when combined with other threats.
- Provides readable low-level fire without creating unavoidable chip damage.

### 10.3 Tank

**Type:** Ground  
**Cannon damage:** 12  
**Pattern:** Lane → aim → fire → reload → reposition  
**Role:** Slow, high-impact area denial

Rules:

- Turret tracks independently of the chassis.
- Aim and fire states must be readable.
- Shells should be avoidable through movement or cover.
- Repositioning should be purposeful, not constant random wandering.

### 10.4 SAM / AA Site

**Type:** Ground  
**Missile damage:** 22  
**Lock time:** 1.4 s baseline  
**Pattern:** Search → track → lock → fire → reload  
**Counter:** Flares and line-of-sight break  
**Role:** Priority threat that forces defensive action

Rules:

- Lock acquisition has an audible alarm and visible indicator.
- The player has enough warning to react.
- Buildings can interrupt acquisition or tracking according to the finalized lock rule.
- Reload windows create an opportunity to attack.

### 10.5 Hunter Helicopter

**Type:** Air  
**Baseline flank speed:** 18 m/s  
**Role:** Mobile hunter and tempo pressure

Required state cycle:

1. **Approach** — Move from a spawn or reposition point toward an attack setup position.
2. **Align** — Establish the attack vector and obtain a valid firing solution.
3. **Commit** — Enter a readable attack run; avoid abrupt direction changes.
4. **Attack** — Fire during a limited window.
5. **Break away** — Leave the player's immediate space instead of orbiting.
6. **Reposition** — Select another attack direction with a minimum separation.
7. **Cooldown** — Wait before beginning the next approach.

The Hunter should be dangerous because of repeated passes and angle changes, not because it perfectly mirrors player movement.

### 10.6 Radar objective

**Type:** Mission target / force multiplier  
**Confirmed effect:** Nearby SAM lock speed increases by 60% while Radar remains active.

Destroying Radar should:

- Remove or reduce the SAM lock-speed bonus.
- Create a clear battlefield-state change.
- Reward target prioritization over indiscriminate clearing.

### 10.7 Archon Heavy Gunship

The Archon is the wave-10 boss and has a unique model, silhouette, audio identity, attacks, and phase damage states. Full behavior appears in Section 14.

---

## 11. Spawn Director

The Spawn Director decides what exists on the battlefield. It is separate from the Combat Director, which decides what is allowed to actively attack.

### 11.1 Responsibilities

- Spend separate ground and air spawn budgets.
- Select enemy compositions allowed by the current wave.
- Spawn outside invalid or unfair positions.
- Avoid spawning directly in the player's view at close range.
- Respect minimum player distance and battlefield boundaries.
- Maintain enemy population without sudden visible pop-in.
- Stop normal spawning or reduce it during boss transitions.

### 11.2 Budget model

| Wave | Ground budget | Air budget | Introduced composition |
| ---: | ---: | ---: | --- |
| 1 | 40 | 0 | Infantry |
| 2 | 55 | 0 | Tank |
| 3 | 70 | 0 | Stronger ground pressure |
| 4 | 85 | 0 | SAM |
| 5 | 100 | 0 | Radar + combined ground combat |
| 6 | 100 | 30 | First air enemy |
| 7 | 115 | 45 | Air + Tank + Infantry |
| 8 | 130 | 60 | Air + Tank + SAM |
| 9 | 150 | 75 | Highest combined pressure |
| 10 | 50 | 25 | Archon boss + reduced support pressure |

Budget values are relative composition credits, not enemy counts. Each enemy type needs a spawn cost.

### 11.3 Spawn fairness rules

- No spawning inside buildings or collision geometry.
- No immediate firing on the same frame an enemy spawns.
- Newly spawned enemies receive an entry or preparation state.
- Dangerous enemies must not spawn inside unavoidable firing range without warning.
- Air enemies should enter from believable off-screen or distant approach points.
- Ground enemies should spawn at valid positions connected to the battlefield layout.

---

## 12. Combat Director and Attack Slots

The Combat Director controls active pressure. A battlefield can contain many enemies, but only a capped number receive permission to execute attacks.

### 12.1 Core principle

**Visible enemies are not the same as active attackers.**

Enemies without an attack slot may:

- Reposition.
- Track the player.
- Perform idle or threatening animations.
- Seek cover or staging positions.
- Wait for an attack opportunity.

They may not deal full active attack pressure until the director grants a slot.

### 12.2 Attack-slot progression

| Wave | Ground slots | Air slots |
| ---: | ---: | ---: |
| 1 | 2 | 0 |
| 2 | 2 | 0 |
| 3 | 3 | 0 |
| 4 | 3 | 0 |
| 5 | 3 | 0 |
| 6 | 3 | 1 |
| 7 | 3 | 1 |
| 8 | 4 | 2 |
| 9 | 4 | 2 |
| 10 | 2 | 1 |

### 12.3 Slot selection

The director should select attackers based on:

- Clear line of sight.
- Range and weapon readiness.
- Time waiting without a slot.
- Current spatial direction around the player.
- Enemy role and current wave composition.
- Whether another attacker already occupies the same angle.

The director should avoid:

- All attackers firing from the same direction.
- Multiple high-damage attacks landing without readable separation.
- One enemy permanently keeping a slot.
- Granting a slot to an enemy that cannot reasonably attack.

### 12.4 Slot lifecycle

1. Enemy requests permission.
2. Director evaluates pressure and suitability.
3. Director grants a ground or air slot.
4. Enemy performs one attack sequence or attack run.
5. Enemy releases the slot after attacking, losing LOS, being disabled, or timing out.
6. Director grants the available slot to another eligible enemy.

### 12.5 Boss pressure

During the Archon fight, ordinary enemy pressure drops to approximately 35–50% of normal. Support units should reinforce the boss identity without obscuring its attack patterns.

---

## 13. Wave Structure and Difficulty Curve

The ten waves form a learning curve. Difficulty increases through composition, coordination, positioning, and attack-slot pressure—not only larger HP values.

| Wave | Purpose | Expected combat lesson |
| ---: | --- | --- |
| 1 | Infantry introduction | Learn movement, chaingun, XP collection |
| 2 | Tank introduction | Read slow heavy attacks and use cover |
| 3 | Stronger ground pressure | Prioritize while moving under combined fire |
| 4 | SAM introduction | Read locks, break LOS, and use flares |
| 5 | Radar + combined ground | Destroy force multipliers and manage territory |
| 6 | First air enemy | Adapt to mobile attack runs |
| 7 | Air + Tank + Infantry | Manage threats across ground and air |
| 8 | Air + Tank + SAM | Combine flares, cover, and target priority |
| 9 | Maximum combined pressure | Demonstrate mastery before the boss |
| 10 | Archon Heavy Gunship | Read phases and complete the run climax |

### 13.1 Wave completion

The exact completion rule is **TBD**. Recommended options are:

- Clear a required enemy budget.
- Survive for a controlled duration while completing a target quota.
- Complete a wave-specific objective and remaining priority threats.

Whichever rule is selected must prevent long cleanup periods where one harmless enemy is difficult to find.

### 13.2 Between-wave pacing

The player should receive a short recovery window for:

- Collecting nearby XP.
- Reading the next-wave warning.
- Completing level-up choices.
- Reorienting the camera and helicopter.
- Receiving limited resupply if the final economy supports it.

---

## 14. Boss — Archon Heavy Gunship

### 14.1 Boss identity

The Archon must feel like a unique encounter rather than a scaled Hunter Helicopter.

Required differences:

- Unique model and silhouette.
- Larger but believable movement footprint.
- Dedicated boss health bar and phase UI.
- Unique weapon patterns.
- Visible damage accumulation.
- Dedicated audio cues and phase transitions.
- Reduced normal-enemy pressure during the fight.

### 14.2 Phase structure

#### Phase 1 — 100% to 66% HP

**Visual state:** Clean hull, pulsing core  
**Behavior:**

- Controlled orbiting movement.
- Sustained chin-cannon barrages.
- Calls in escort Hunter helicopters.
- Establishes the base attack language.

#### Phase 2 — 66% to 33% HP

**Visual state:** Left engine smoke, visible sparks, altered core color  
**Behavior:**

- Increased movement speed.
- Four-rocket spread salvos.
- More aggressive repositioning.
- Shorter safe gaps, while attacks remain readable.

#### Phase 3 — Below 33% HP

**Visual state:** Both engines burning, critical damage, heavy smoke and sparks  
**Behavior:**

- Enraged rapid cannon bursts.
- Continuous or repeated missile barrages.
- Strong final pressure pattern.
- Must remain mechanically fair despite visual intensity.

### 14.3 Phase transition rules

- Transition attacks should not start before the new phase is visually communicated.
- Existing unavoidable projectiles should not overlap unfairly with a transition.
- Each phase needs a clear audio cue.
- Visible damage must correspond to the current phase.
- Phase changes alter behavior, not only speed and damage multipliers.

### 14.4 Boss defeat

On defeat:

- Stop new hostile attacks.
- Play a distinct destruction sequence.
- Award XP and Salvage clearly.
- Present the extraction versus Endless Overdrive decision.
- Do not immediately force the player into the next state before rewards are readable.

---

## 15. XP, Leveling, and Upgrade Cards

### 15.1 XP collection

- Defeated enemies drop XP pickups.
- Pickups remain visible and readable against the environment.
- XP magnetizes when the helicopter enters the pickup radius.
- Magnet movement accelerates smoothly and does not orbit or miss the player.
- Permanent Hangar upgrades may increase baseline collection radius.
- Within-run upgrades may further increase collection behavior.

### 15.2 Level-up sequence

1. XP reaches the next-level threshold.
2. Combat and simulation pause safely.
3. Three upgrade cards appear.
4. Each card displays its benefit and cost clearly.
5. The player chooses one.
6. The chosen effect applies exactly once.
7. The UI closes and combat resumes with a short input buffer.

### 15.3 Upgrade philosophy

Standard upgrades should create a strength and a cost, limitation, or specialization. The purpose is to create builds, not a list of automatic stat increases.

Exceptions:

- Evolutions are rewards for completing a combination and may remove downsides.
- Legendary upgrades intentionally have no downside but are limited to one per run.

### 15.4 Base upgrade pool

| Slot | Upgrade | Benefit | Trade-off / limitation |
| --- | --- | --- | --- |
| Primary | Twin Barrel | +40% fire rate | −15% damage per hit |
| Primary | Armor-Piercing Rounds | +50% damage vs ground armor | −20% damage vs air |
| Primary | Tracer Rounds | +25% damage vs air, wider cone | −10% damage vs ground |
| Primary | Overclocked Feed | +20% fire rate and damage | Overheats after 8 s continuous fire |
| Secondary | Cluster Warheads | Target splits into three fragments | −25% direct-hit damage |
| Secondary | Homing Suite | +15° lock cone | +30% lock time |
| Secondary | Rapid Lock | Lock time halved | Only one target locked at a time |
| Secondary | Flak Burst | Auto-detonates near air without full lock | No ground effectiveness |
| Passive | Reinforced Airframe | +25% max HP | −10% max speed |
| Passive | Loot Magnet | +60% XP pickup radius | **Trade-off TBD** |
| Passive | Afterburner | +20% strafe speed | +15% resupply drain |
| Passive | Repair Drone | Regenerates HP after 5 s without damage | Disabled below 25% HP |

> Loot Magnet currently conflicts with the rule that every standard card costs something. Give it a real trade-off, move it to a special reward pool, or intentionally revise the global rule.

### 15.5 Rarity pool

| Rarity | Weight | Contents |
| --- | ---: | --- |
| Common | 70% | Base upgrade pool |
| Rare | 25% | Stronger, maxed, or evolution-eligible versions |
| Legendary | 5% | No-downside upgrades; maximum one per run |

Weights are initial targets and should be calculated after removing ineligible cards.

### 15.6 Evolutions

A maxed weapon upgrade plus a specific maxed passive can create an evolution. The first playable slice should ship with two stable evolutions before the full set is added.

| Combination | Evolution | Result |
| --- | --- | --- |
| Twin Barrel + Overclocked Feed | Hellfire Minigun | +100% total fire rate; overheat removed |
| Armor-Piercing + Reinforced Airframe | Siege Cannon | +80% ground damage; rounds pierce a second target |
| Tracer Rounds + Loot Magnet | Interceptor Array | Doubled cone, +50% air damage, bonus XP on kill |
| Cluster Warheads + Flak Burst | Inferno Swarm | Five-fragment clusters on every lock; affects ground and air |

### 15.7 Legendary pool

| Upgrade | Effect |
| --- | --- |
| Overdrive Core | All weapons +15% damage; all cooldowns −10% |
| Ghost Rotor | Ignore the first hit every 12 seconds |
| One More Pass | Revive once per run at 30% HP |

---

## 16. Salvage, Extraction, and Endless Overdrive

### 16.1 Salvage

Salvage is the permanent progression currency earned during a run. It is not fully safe until extracted, except for any amount protected by Hangar upgrades.

Potential sources:

- Enemy kills.
- Elite or boss kills.
- Wave completion.
- Mission objectives.
- Bonus objectives.
- Endless Overdrive multipliers.

Exact earning values are **TBD**.

### 16.2 Extraction

After defeating the Archon, the player may extract.

Extraction should:

- Bank the run's Salvage.
- End the current run successfully.
- Return the player to the Hangar.
- Clearly summarize build, waves, kills, Salvage, and permanent rewards.

### 16.3 Endless Overdrive

The player may reject safe extraction and continue.

Endless Overdrive should:

- Increase enemy budgets and composition pressure beyond wave 10.
- Increase reward multipliers.
- Continue risking unbanked Salvage.
- Avoid relying only on infinite HP scaling.
- Reuse stable enemy combinations before adding unsupported enemy types.

Exact death penalties, reward scaling, and later boss cadence are **TBD**.

---

## 17. Hangar Meta Progression

The Hangar gives permanent value to successful and partially failed runs.

| Upgrade | Permanent effect |
| --- | --- |
| Scavenger Rig | Increases Salvage yield |
| EMP Rounds | Unlocks an additional ammo type |
| Rotor Armor | Improves baseline survivability |
| Magnet Radius | Increases baseline XP pickup range |
| Second Loadout Slot | Allows two starting weapons instead of one |
| Extraction Insurance | Keeps 50% of Salvage after a failed run |
| Veteran's Instinct | Displays exact trade-off numbers on upgrade cards |
| Starting Fuel Reserve | Grants one additional resupply charge per run |
| Cosmetic Skins | Visual unlocks with no gameplay effect |

### Meta-progression principles

- Permanent power should help recovery without deleting early-run tension.
- Failed runs should still provide some progress once relevant systems are unlocked.
- The strongest unlocks should broaden build options, not only increase damage.
- Cosmetic rewards should remain gameplay-neutral.

---

## 18. Objectives

The first confirmed mission objective is **Destroy Radar Station**.

### 18.1 Objective requirements

- Objectives appear in understandable battlefield positions.
- The HUD shows direction and distance without covering the center of the screen.
- Objectives affect the battle before completion.
- Completing an objective creates a visible and mechanical change.
- Objectives award XP, Salvage, or wave progress.

### 18.2 Destroy Radar Station

While active:

- Nearby SAM sites receive +60% lock speed.
- The player receives a reason to prioritize the Radar.

When destroyed:

- The SAM bonus ends.
- The objective HUD updates immediately.
- Nearby effects and radar visuals shut down.
- The player receives a clear reward and feedback event.

### 18.3 Future objective framework

Future objectives may include delivery, defense, or extraction tasks, but they should not be added until the main combat roster and wave loop are consistently fun.

---

## 19. HUD and Combat Feedback

The HUD must communicate critical information quickly without becoming a cockpit simulator.

### 19.1 Required HUD elements

- Player health and armor state.
- Chaingun heat.
- Secondary weapon lock progress and availability.
- Flare cooldown or charges.
- Current XP and level.
- Current wave and wave progress.
- Current objective.
- Active target marker.
- Incoming SAM/missile lock warning.
- Directional off-screen threat indicators.
- Minimap with readable ground and air distinctions.
- Boss health and phase state.
- Salvage earned during the run.

### 19.2 Minimap language

| Entity | Recommended marker |
| --- | --- |
| Player | Distinct helicopter/arrow marker |
| Ground enemy | Square blip |
| Air enemy | Triangle blip |
| Objective | Unique objective icon |
| Extraction | Dedicated extraction marker |
| Boss | Large unique marker |

### 19.3 Feedback rules

- Damage numbers should not overlap into unreadable blocks.
- Critical warnings take priority over reward popups.
- Lock warnings use both visual and audio feedback.
- Off-screen indicators point toward the actual threat direction.
- Boss phase changes must be visible without relying only on the health bar.

---

## 20. Visual and Audio Direction

### 20.1 Visual direction

The current direction is stylized low-poly / blocky 3D rather than realism. The environment, helicopter, enemies, UI, VFX, and scale should feel like one consistent arcade game.

Priorities:

- Strong silhouettes.
- Readable faction and threat colors.
- Clear altitude through shadows and downwash.
- Distinct ground and air enemy profiles.
- Buildings large enough to function as cover.
- Effects that remain readable during high-pressure waves.

### 20.2 Combat VFX

Required effects include:

- Chaingun muzzle flash and tracers.
- Impact sparks and debris.
- Missile trails.
- Flare burst and decoy trail.
- Enemy destruction explosions.
- Player destruction sequence.
- Rotor downwash dust.
- Boss smoke, sparks, fire, and phase damage.

Effects should be pooled and capped to avoid performance loss during sustained firing.

### 20.3 Audio priorities

- Chaingun loop with heat/overheat state changes.
- Missile lock acquisition and confirmation.
- Incoming SAM warning.
- Successful flare break.
- Enemy attack tells.
- XP collection and level-up.
- Wave start and completion.
- Boss phase transitions.
- Unique Archon weapon and destruction sounds.

Audio should communicate gameplay state even when the relevant threat is off-screen.

---

## 21. Technical Direction

### 21.1 Current referenced stack

- React 19
- TypeScript
- Vite 6
- Three.js
- cannon-es
- Tailwind CSS
- Vitest

### 21.2 System separation

Keep major gameplay responsibilities modular:

| System | Responsibility |
| --- | --- |
| Player flight controller | Input, velocity, altitude, banking, collision |
| Camera controller | Follow, orbit, recenter, obstruction handling, shake |
| Targeting system | Candidate collection, LOS, scoring, target persistence |
| Weapon systems | Firing, heat, locks, flares, projectile behavior |
| Enemy state machines | Individual movement and attack behaviors |
| Spawn Director | Population, budgets, composition, valid spawn positions |
| Combat Director | Attack-slot allocation and pressure orchestration |
| Wave Director | Wave timing, unlocks, budgets, transitions, boss trigger |
| Objective system | Mission state, modifiers, completion, rewards |
| XP/upgrade system | Drops, collection, levels, card offers, evolutions |
| Run state | Deploy, active run, pause, victory, death, extraction, Endless |
| Meta progression | Salvage banking, Hangar upgrades, unlock persistence |
| HUD/event layer | Displays authoritative game state and warnings |

### 21.3 Performance principles

- Pool projectiles, particles, XP pickups, and common enemies.
- Avoid allocating objects inside high-frequency update loops.
- Limit expensive LOS checks to relevant candidates and active attackers.
- Use spatial queries for target selection rather than scanning the entire world.
- Keep physics and visual interpolation responsibilities separate.
- Cap simultaneous audio voices, damage numbers, particles, and decals.
- Deactivate distant enemies without breaking director accounting.

### 21.4 State ownership

Each major state should have one authoritative owner. For example:

- Combat Director owns attack permission.
- Enemy AI owns how it performs the granted attack.
- Wave Director owns wave progression.
- Spawn Director owns population creation.
- Weapon system owns heat and lock state.
- HUD reads state through events/selectors and does not control gameplay.

This prevents duplicated timers and contradictory AI decisions.

---

## 22. First Playable Slice

The first complete, representative slice should include:

### Player

- One AH-9 Vulture.
- Responsive 360° arcade movement.
- Altitude limits.
- Auto-banking and visual pitch.
- Strafe without forced nose rotation.
- Auto-aim and manual override.
- Chaingun, guided ordnance, and flares.

### Enemies and objective

- Infantry Cluster.
- Tank.
- SAM / AA Site.
- Hunter Helicopter.
- Radar objective.
- Archon Heavy Gunship boss.

### Run systems

- Ten waves.
- Separate ground and air spawn budgets.
- Separate ground and air attack slots.
- XP drops and magnet pickup.
- Three-card level-up choice.
- At least two working evolutions.
- Salvage reward.
- Extraction decision.
- Basic Endless Overdrive.
- Hangar spending and persistence.

### Presentation

- Main menu.
- In-game HUD.
- Pause screen.
- Level-up cards.
- Death/run-summary screen.
- Victory/extract/continue screen.
- Hangar UI.
- Core combat VFX and audio cues.

---

## 23. Recommended Build Order

Build and validate the game in this order:

1. **Player flight and camera**
   - Movement, altitude, banking, strafing, orbit, recenter, collision.

2. **Targeting and chaingun**
   - Auto-aim, manual override, target persistence, LOS, heat.

3. **One ground enemy**
   - Tank or simple turret with readable aim/fire/reload behavior.

4. **Combat Director**
   - Ground attack slots, request/grant/release lifecycle.

5. **Spawn Director and wave flow**
   - Valid spawning, budget spending, wave transitions.

6. **Full ground roster**
   - Infantry, Tank, SAM, Radar objective, cover interactions.

7. **Hunter Helicopter AI**
   - Approach, commit, attack, break away, reposition.

8. **Air attack slots and mixed waves**
   - Waves 6–9 and combined pressure.

9. **XP and build crafting**
   - Pickups, level-up pause, card effects, rarity, two evolutions.

10. **Archon boss**
    - Unique attacks, phase behavior, damage visuals, reduced support pressure.

11. **Extraction, Endless, and Salvage**
    - Run outcome, banking, failure rules, risk/reward scaling.

12. **Hangar and persistence**
    - Permanent upgrades, unlocks, loadout selection.

13. **Polish and performance**
    - Models, environment scale, VFX, audio, feedback, pooling, tuning.

---

## 24. Acceptance Criteria for the Core Gameplay

The core gameplay is working when all of the following are true:

### Flight

- The helicopter reaches the target top speed without feeling sluggish.
- Direction changes are responsive but visually smoothed.
- Strafing changes lateral position without automatically rotating the nose.
- The helicopter never exceeds the altitude bounds.
- Camera orbit does not change movement unpredictably.
- Banking is visual and does not create physics jitter.

### Combat

- Auto-aim consistently chooses a nearby visible target.
- Manual input overrides aim immediately and returns to auto after the settle delay.
- The gun mount aims independently from the body.
- Player and enemy projectiles do not pass through buildings.
- Chaingun heat, missile lock, and flares each have clear feedback.

### Enemy AI

- Ground enemies stay within their intended territorial behavior.
- Tanks visibly aim, fire, reload, and reposition.
- SAM locks are readable and counterable.
- Hunters perform attack runs and break away.
- No air enemy remains permanently attached to or circling the player.

### Directors and waves

- Many enemies can remain visible while only the allowed number actively attack.
- Attack slots are released reliably after attacks, death, timeout, or invalid state.
- Air enemies do not appear before wave 6.
- Wave difficulty changes through composition and pressure, not only health.
- Boss support pressure is lower than wave-9 combined pressure.

### Progression

- XP reaches the player reliably through magnet collection.
- Level-up safely pauses combat and shows exactly three eligible cards.
- Card effects do not apply twice.
- At least two evolutions can be completed in a real run.
- Salvage can be banked through extraction and spent in the Hangar.
- Endless Overdrive offers visibly higher risk and reward.

### Boss

- The Archon has three mechanically different phases.
- Phase changes occur at 66% and 33% HP.
- Visual damage matches the phase.
- The player can identify and respond to each major attack pattern.
- Defeat cleanly opens the extraction or Endless decision.

---

## 25. Open Decisions and Conflicts to Resolve

These items should be decided before the document becomes a final implementation spec:

1. **Altitude controls** — The allowed altitude range is defined, but the input mapping and whether altitude is direct or automatic are not.
2. **Weapon controls** — Fire, secondary weapon, and flare bindings are not defined in the Field Manual.
3. **Manual aim range** — The source mentions an 18 m raycast. At a 38.1 m/s top speed, this may be too short for the intended combat scale and should be validated.
4. **Air-enemy cover rule** — The source table says cover is “N/A” for air enemies, while the core rule says LOS matters for both sides. Recommended interpretation: air navigation does not rely on cover, but air weapons still require projectile LOS.
5. **Wave completion rule** — Kill budget, timer, objective completion, or a hybrid is not finalized.
6. **Upgrade cost rule** — Loot Magnet currently has no downside despite the rule that every normal card costs something.
7. **Repair Drone trade-off** — Being disabled below 25% HP may be a condition rather than a meaningful cost; decide whether this is sufficient.
8. **Flares economy** — Cooldown, charges, resupply, and Radar interaction need final values.
9. **Salvage loss** — Base failure loss and the exact role of Extraction Insurance need confirmation.
10. **Endless structure** — Scaling curve, reward multiplier, boss recurrence, and exit opportunities are not defined.
11. **Objective placement** — Procedural versus authored objective positions need confirmation.
12. **Starting loadout** — The Field Manual references one loadout while the Hangar can unlock a second loadout slot; define the initial weapon/equipment selection rules.
13. **Fuel/resupply** — Starting Fuel Reserve and Afterburner reference resupply drain, but the underlying resource system is not defined.
14. **Health and armor model** — Rotor Armor and player health exist conceptually, but baseline HP, armor behavior, repair rules, and damage invulnerability windows are not specified.

---

## 26. Final Core Gameplay Definition

HELI-STRIKE is a fast, accessible 3D arcade helicopter combat roguelite where flying and positioning are the player's main skills. The AH-9 Vulture moves with responsive physics, strafes independently of its facing, and uses assisted targeting so the player can focus on battlefield awareness rather than constant precision aiming.

Ground enemies control territory through threat ranges, heavy attacks, SAM locks, Radar support, and line-of-sight pressure. Air enemies behave as hunters that approach, commit to attack runs, break away, and reposition. A Combat Director separates visible enemy population from active attack pressure, keeping battles large and cinematic without allowing every enemy to attack simultaneously.

Each run builds across ten deliberately composed waves. The player destroys enemies, collects magnetized XP, and chooses from three upgrades that create strengths and trade-offs. Wave 10 ends with the Archon Heavy Gunship, a unique three-phase boss with visible damage and changing attacks. After victory, the player can extract and safely bank Salvage or continue into Endless Overdrive for increased risk and reward. Banked Salvage is spent in the Hangar on permanent upgrades and new build options before the next deployment.

This is the design standard every future mechanic should support.

---

## Appendix A — Confirmed Numeric Baselines

| System | Value |
| --- | ---: |
| Player top speed | 137 KPH / ~38.1 m/s |
| Player acceleration | 42 m/s² |
| Player altitude range | 2.6–26 m |
| Chaingun fire rate | 11.5 rounds/s |
| Chaingun overheat lockout | 2.5 s |
| Guided ordnance damage | 45 |
| Guided ordnance splash radius | 3.2 m |
| Guided ordnance lock time | 0.95 s |
| Flare Radar scramble | 3.5 s |
| Infantry damage | 1.2 per shot |
| Infantry burst | 3–5 rounds |
| Infantry cluster size | 3–6 soldiers |
| Tank cannon damage | 12 |
| SAM missile damage | 22 |
| SAM lock time | 1.4 s |
| Radar SAM lock-speed bonus | +60% |
| Hunter flank speed | 18 m/s |
| Boss phase thresholds | 66% and 33% HP |
| Boss normal-pressure reduction | Approximately 35–50% of normal |
| Common upgrade weight | 70% |
| Rare upgrade weight | 25% |
| Legendary upgrade weight | 5% |
| Maximum Legendaries | 1 per run |

---

## Appendix B — Source Priority

When two notes conflict, use this order:

1. The confirmed 12-point core gameplay definition.
2. Explicit system tables and numeric values in this document.
3. The original Field Manual.
4. Older project discussions and prototypes.
5. Temporary placeholder behavior.

Any change to a core pillar, enemy behavior family, ten-wave structure, boss identity, assisted aim, LOS cover, attack-slot system, extraction choice, or Hangar progression should be treated as a deliberate design revision—not an incidental implementation choice.
