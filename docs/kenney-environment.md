# Kenney environment integration

## Additional building placement

Follow-up request: added 24 saved building instances under each district's `AdditionalBuildings` container: 11 downtown, 5 industrial, and 8 outskirts. Reused the existing Kenney modules, preserving their colliders and rooftop markers. Placement checks exclude road strips, objective/pickup clearances, parking areas, and existing structures with a four-metre separation margin. Crowded candidates were skipped. Existing building positions were not changed.

All three edited district scenes validate without errors (existing autoload warnings remain). Runtime checks now cover 91 matching model/collider bounds, three supported roof markers, three cover rays, and two clear main avenues. Inspected three updated district screenshots; expanded previews are in `.fennara/screenshots/kenney/urban-expanded.png` and `outskirts-expanded.png`. Earlier regression and performance measurements below precede this density increase; they were not repeated for this placement-only change.

Implemented September 12, 2026, using the supplied imported GLBs in `assets/Models/GLB format/`. The supplied license is retained at `assets/License.txt`.

## Saved game changes

- Downtown uses two tower compositions, two mid-rise variants, and two small-building variants. Industrial placements use warehouse and sawtooth-factory variants, rooftop solar/chimney details, detailed storage tanks, and orange/blue/green container stacks.
- Outskirts uses town houses, workshops, cabins, a water tower, two windmills, and solar arrays. The existing block positions, roads, terrain, boundaries, and military layout are preserved.
- Removed accidental duplicate model geometry and overlapping old/new building instances from the previous partial integration. Imported scenes retain their instance boundaries rather than copying their internal meshes into every district.
- World building collision uses unscaled BoxShape3D nodes fitted to transformed imported model bounds. Multi-part towers, tanks, and containers have separate boxes rather than one oversized enclosing wall.
- FuelTank retains its existing script, TankMesh node contract, 60 HP, collision-layer bitmask 4, smoke, explosion, area damage, salvage hooks, and burnt-mesh behavior. Other solid replacement buildings use world-layer bitmask 1.
- RooftopDefensePoint, RooftopSpawnPoint, and RooftopPoints/Equipment and Lookout are retained/restored in building modules. The three battlefield rooftop source markers keep their names and now sit on the replacement roofs. Ground/air spawn sources, objective locations, and pickup locations retain their authored coordinates.
- Refreshed scene resource references in the battlefield and military district to eliminate stale UID warnings introduced by the partial replacement.

No gameplay script, player controller, camera script, progression system, mission logic, enemy roster, or test runner was changed.

## Measured scale examples

| Asset | Final approximate dimensions in metres |
| --- | --- |
| Main downtown tower | 7.04 wide × 24.62 high × 7.63 deep |
| Alternate main tower | 6.80 × 22.40 × 6.80 |
| Mid-rise variants | 10.42 × 8.82 × 6.21 / 8.95 × 9.63 × 6.40 |
| Warehouse | 15.65 × 7.66 × 8.01 |
| Sawtooth factory, excluding chimney | 13.13 × 7.50 × 14.76 |
| Individual container | 2.76 × 2.58 × 6.09 |
| Town house | 5.20 × 5.50 × 4.20 |
| Water tower | 2.98 × 7.50 × 2.91 |
| Windmill | 2.42 × 9.26 × 4.51 |

Actual imported bounds determined scale rather than the plan's estimated asset units. In particular, containers need approximately 7.4× source scale to match the intended cover size; the earlier 2× scale produced tiny visible containers inside large invisible colliders.

## Verification

- Existing full regression suite: all 32 tests pass, exit code 0, both before and after integration. Tests 22 and 23 pass unchanged.
- The headless suite emits the same 11 baseline engine error messages before and after (nine detached-transform queries and two camera projection queries). These are existing test-context issues, not a clean-error-log result.
- Godot-aware saved-scene validation: no errors. Existing detached-scene autoload/reference warnings remain; battlefield validation reports the same 29 warnings as baseline.
- Live physics checks: 66 imported component bounds match their colliders; all three rooftop markers have supporting building collision; all three sampled buildings block cover rays; both main avenue centreline rays are clear (8/8 focused checks).
- Runtime fuel-tank probe: damage and half-health smoke work; destruction disables collision, applies nearby damage, preserves the burnt mesh, and does not repeat rewards. A probe cleanup error was corrected and the probe passed in a fresh process; no product-code change was needed.
- Three input-driven flight segments at 10 m altitude travelled approximately 51–52 m each through urban, industrial, and outskirts corridors. These are short route checks, not an exhaustive map flight.
- Camera obstruction sample near a tower shortened the spring arm from 52.56 m to 40.01 m; the gameplay screenshot was inspected for clipping.
- Actual connected editor: Godot 4.7.1 stable, Compatibility/OpenGL, Intel Iris Xe, 1280×720 runtime viewport.
- Initial short flight samples: 51–60 FPS. After a three-second warm-up, a twelve-second industrial combat sample measured 58–60 FPS. This does not establish a locked 60 FPS across the entire map or late-run enemy counts. Player health was temporarily raised only in runtime probes to avoid interrupting measurements; saved gameplay values were untouched.

## Local evidence

Diagnostic district views and a normal-camera combat capture are saved in `.fennara/screenshots/kenney/`. The diagnostic views use a temporary elevated camera; they are not the gameplay camera.

Regression logs: `.fennara/kenney-baseline-stdout.log`, `.fennara/kenney-baseline-stderr.log`, `.fennara/kenney-final-stdout.log`, and `.fennara/kenney-final-stderr.log`.

Reusable review/physics/flight probes are under `.fennara/scripts/runtime/kenney_*.gd`. One-off scene-authoring workers stay in `.fennara/tmp/editor_scripts/` and are not part of runtime gameplay. Existing user-provided tool scripts were left intact.
