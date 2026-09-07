# Implementation Plan: Urban Strike Large City Battlefield & Playable Area Boundary

Transform the current minimal test arena in `scenes/battlefield/battlefield.tscn` into an expansive, readable, and believable **Urban Strike combat city** with distinct districts, modular reusable scenes, tactical rooftops, destructible props, and a defined soft/hard playable area boundary.

---

## User Review Required

> [!IMPORTANT]
> - **Flight & Gameplay Integrity**: Player flight physics, camera rig, targeting, weapons, continuous enemy spawning, enemy AI, and progression systems will remain 100% untouched.
> - **Performance on Compatibility (OpenGL 3)**: All modular environment meshes and props will use clean, low-poly geometry with unshaded or simple Lambert/StandardMaterial3D, box/cylinder collision shapes, and compound instances to ensure solid 60 FPS performance without GPU overhead.
> - **Godot Engine Serialization**: In strict accordance with the project guidelines, new `.tscn` scenes and scene modifications will be generated and saved via Godot-aware operations (`run_scene_edit_script` / engine serialization), never by raw text tampering.

---

## City Architecture & District Layout

The battlefield map ($340\text{m} \times 340\text{m}$ ground plane, $250\text{m} \times 250\text{m}$ inner safe playable zone) will be organized into **4 distinct, recognizable districts** connected by a clean road grid:

```text
                                 [NORTH]
                  DISTANT SKYLINE & INDUSTRIAL HIGHWAY
                                   ▲
                                   │
┌──────────────────────────────────┼──────────────────────────────────┐
│  DISTRICT 1: CITY CENTER         │  DISTRICT 2: INDUSTRIAL ZONE     │
│  • Dense Commercial Towers       │  • Heavy Logistics Warehouses    │
│  • Mid-Rise Office Blocks        │  • Destructible Fuel Tank Farm   │
│  • Central Civic Plaza           │  • Stacked Container Depots      │
│  • Rooftops with AA Turret Sites │  • Wide Truck Routes & Parking   │
│  (X: -60 to 30, Z: -120 to -10)  │  (X: 30 to 125, Z: -120 to 30)   │
├──────────────────────────────────┼──────────────────────────────────┤
│  DISTRICT 4: OUTSKIRTS & FIELDS  │  DISTRICT 3: MILITARY AIRBASE    │
│  • Low-Profile Repair Garages    │  • Reinforced Aircraft Hangars   │
│  • Dirt Roads & Open Terrain     │  • Radar Installation Site       │
│  • Clear Low-Altitude Corridors  │  • SAM Fortification Revetments  │
│  • Sparse Trees & Rocks          │  • Fortified Base Checkpoints    │
│  (X: -125 to -30, Z: -10 to 125) │  (X: -30 to 125, Z: 30 to 125)   │
└──────────────────────────────────┼──────────────────────────────────┘
                                   │
                                   ▼
                    DISTANT MOUNTAINS & WATERFRONT
                                 [SOUTH]
```

### Road Network
- **Central Boulevard (N-S, X = 0)**: 16m wide multi-lane avenue with road markings and sidewalks connecting Downtown, Central Plaza, and the Military Airbase.
- **Industrial Parkway (E-W, Z = 0)**: 16m wide transit artery connecting Outskirts, Central Plaza, and Industrial Warehouses.
- **Perimeter Avenues (X = ±80, Z = ±80)**: Connecting perimeter districts and providing wide maneuvering corridors for helicopter strafing runs and ground vehicle convoys.

---

## Proposed Changes

### 1. Modular Environment Scenes

We will create modular, reusable `.tscn` scenes under `res://scenes/environment/` matching the requested structure:

#### [NEW] City Scenes (`scenes/environment/city/`)
- `building_small.tscn`: Low-rise shop/office ($14\text{m} \times 8\text{m} \times 12\text{m}$) with flat roof and facade accents.
- `building_medium.tscn`: Mid-rise apartment/commercial block ($18\text{m} \times 18\text{m} \times 18\text{m}$) with roof parapet, rooftop vents, and `Marker3D` rooftop point.
- `building_large.tscn`: High-rise office tower ($24\text{m} \times 36\text{m} \times 24\text{m}$) with helipad texture and `Marker3D` rooftop defense point.
- `warehouse.tscn`: Industrial logistics warehouse ($32\text{m} \times 11\text{m} \times 22\text{m}$) with corrugated roof silhouette and roll-up bay doors.
- `parking_lot.tscn`: Asphalt parking lot ($24\text{m} \times 20\text{m}$) with stall markings and low-poly civilian vehicle props.
- `civic_plaza.tscn`: Open pedestrian plaza ($36\text{m} \times 36\text{m}$) with central monument, tile paving, and clear flight clearance.

#### [NEW] Military Scenes (`scenes/environment/military/`)
- `hangar.tscn`: Quonset/arched aircraft hangar ($28\text{m} \times 12\text{m} \times 26\text{m}$) with landing apron and interior depth.
- `checkpoint.tscn`: Fortified military gate with concrete Jersey barriers, sandbags, boom gate, and guard post.
- `radar_site.tscn`: Hardened radar installation compound with perimeter fence, generators, and concrete pad.
- `sam_site_environment.tscn`: Fortified earthen revetment / berm for anti-air missile batteries.

#### [NEW] Road Scenes (`scenes/environment/roads/`)
- `road_straight.tscn`: Straight 2-lane road section ($16\text{m}$ wide $\times 32\text{m}$ long) with asphalt material, white center dashes, and concrete sidewalks.
- `intersection.tscn`: 4-way cross intersection ($16\text{m} \times 16\text{m}$) with crosswalk decals and corner curbs.
- `road_corner.tscn`: 90-degree curved road corner with sidewalk borders.

#### [NEW] Props & Destructibles (`scenes/environment/props/`)
- `fuel_tank.tscn` & [`fuel_tank.gd`](scripts/environment/fuel_tank.gd):
  - Cylindrical industrial fuel storage tank ($5\text{m}$ diameter, $6\text{m}$ height).
  - Health: 60.0. Takes damage on Collision Layer 4 from player chaingun and missiles.
  - Visual stages: Intact $\rightarrow$ Damaged (smoke puff) $\rightarrow$ Destroyed (dramatic fiery explosion, 85 AoE damage to nearby ground enemies, charred ruin mesh).
  - Awards 50 Salvage upon demolition and drops salvage crate.
- `barrier.tscn`: Concrete Jersey barrier for road blocks and military perimeters.
- `crate.tscn`: Military logistics crates (can be destroyed by weapons).
- `fence.tscn`: Modular chainlink security fence segment.
- `streetlight.tscn`: Twin-arm city streetlamp.

---

### 2. Playable Area Boundary System

#### [NEW] [`scenes/environment/boundary/playable_area.tscn`](scenes/environment/boundary/playable_area.tscn) & [`scripts/environment/playable_area.gd`](scripts/environment/playable_area.gd)
- **Hierarchy**:
  ```text
  PlayableArea (Node3D, script: playable_area.gd)
  ├── InnerSafeArea (Area3D, BoxShape3D 250m x 250m)
  ├── WarningBorder (Area3D, BoxShape3D 290m x 290m)
  ├── HardBoundary (StaticBody3D, 4 physical invisible collision walls at +/-148m)
  └── DistantBackdrop (Node3D, low-poly mountain ridge, distant skyline silhouettes, and water plane)
  ```
- **Soft Border Mechanism**:
  - Monitors player position relative to the $125\text{m}$ safe perimeter.
  - When player enters the warning zone ($125\text{m} \le |x|, |z| \le 145\text{m}$):
    - Emits `EventBus.border_warning_changed(is_warning, return_direction, distance)`.
    - Applies a subtle corrective inward steering resistance without removing player flight control.
- **Hard Border Mechanism**:
  - The physical `HardBoundary` walls on Layer 1 (World) prevent outward penetration through normal `move_and_slide()` collision physics.
  - Post-physics position clamp ($|x|, |z| \le 148\text{m}$) zeroes outward velocity components smoothly with zero jitter or teleportation.

#### [MODIFY] [`scripts/common/event_bus.gd`](scripts/common/event_bus.gd)
- Add signal: `signal border_warning_changed(is_warning: bool, return_dir: Vector3, distance_to_edge: float)`

#### [MODIFY] [`scenes/ui/hud.tscn`](scenes/ui/hud.tscn) & [`scripts/ui/hud.gd`](scripts/ui/hud.gd)
- Add tactical boundary warning indicator:
  - Header: `⚠ WARNING: LEAVING MISSION AIRSPACE ⚠`
  - Subtext: `RETURN TO COMBAT AREA`
  - Pulsing amber alert banner that fades in when crossing the warning boundary and displays real-time distance to border.

---

### 3. Battlefield Assembly

#### [MODIFY] [`scenes/battlefield/battlefield.tscn`](scenes/battlefield/battlefield.tscn)
- Replace primitive placeholder box nodes with organized district nodes instancing modular city, military, road, and prop scenes.
- Expand ground plane to $340\text{m} \times 340\text{m}$.
- Wire the new `PlayableArea` and `DistantBackdrop`.
- Update `SpawnSystem` markers to align with the new district road intersections, military base gates, warehouse loading bays, and high-rise rooftops.

---

## Verification Plan

### Automated Tests
1. **Headless Test Suite**: Run `res://scenes/tests/test_runner.tscn` to ensure all 22 test suites pass at 100%.
2. **Boundary & Environment Unit Tests**: Add test assertions in `test_runner.gd` verifying:
   - All modular environment scenes load and instantiate cleanly.
   - `PlayableArea` soft warning triggers at $125\text{m}$ and hard boundary clamps at $148\text{m}$.
   - Destructible `FuelTank` takes damage and triggers demolition/rewards.

### Fennara Validation
1. **Scene Preflight (`validate_scene`)**: Validate `battlefield.tscn`, `playable_area.tscn`, and all modular scenes with 0 errors and 0 crashes.
2. **Script Diagnostics (`script_diagnostics`)**: Verify all new scripts (`playable_area.gd`, `fuel_tank.gd`, etc.) have 0 errors and 0 warnings.
3. **Live Runtime Session (`runtime_session` & `runtime_script`)**:
   - Fly the player helicopter from the center toward the boundary.
   - Verify HUD warning triggers and displays `RETURN TO COMBAT AREA` in the warning border.
   - Verify smooth clamping at the hard border without teleportation or physics breakdown.
   - Fire chaingun/missiles at a fuel tank to verify staged destruction, explosion VFX, and salvage reward.
