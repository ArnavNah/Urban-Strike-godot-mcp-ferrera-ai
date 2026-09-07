# Heli-Strike — Godot Player Movement and Camera Implementation

## Instructions for the Godot AI agent

Implement this specification directly inside the existing Heli-Strike Godot project using the installed Fennara Godot AI MCP.

Use real Godot scenes, nodes, resources, Input Map actions, collision bodies, and editor properties. Use GDScript only for behavior that requires code. Do not create script-only replacements for systems Godot already provides.

Read `HELI-STRIKE_CORE_GAMEPLAY_GDD.md` from the project root before changing the project. Inspect the existing player and camera implementation, then modify the real scenes and scripts instead of creating a disconnected prototype.

This implementation is limited to:

- Helicopter flight movement
- Yaw turning
- Independent strafing
- Altitude movement
- Helicopter visual banking and pitch
- Rotor animation if missing
- Third-person chase camera
- Camera collision handling

Do not rewrite:

- Shooting
- Auto-aim or manual aiming
- Enemy AI
- Wave spawning
- Combat Director
- Player health
- XP and upgrades
- HUD
- Menus
- Save data
- Environment layout

Preserve all existing signals, groups, exported references, weapon origins, targeting references, and gameplay connections.

---

## Intended gameplay feel

The helicopter must feel like a fast arcade attack helicopter, not a realistic flight simulator.

The player should be able to:

- Accelerate quickly and feel intense movement immediately.
- Turn the helicopter through a full 360 degrees.
- Keep the camera smoothly behind the helicopter while turning.
- Strafe sideways without rotating the nose.
- Continue aiming at an enemy while repositioning sideways.
- Climb and descend within a controlled gameplay altitude.
- Feel momentum without the controls becoming slow or heavy.
- See the helicopter bank, pitch, and react visually without tilting the collider.

The camera is not a free-orbit mouse camera. The helicopter rotates through 360 degrees, and the camera follows its heading. Mouse and right-stick input must remain available for weapon aiming.

---

## Required Godot scene structure

Use the existing player and camera scenes when possible. Adapt their hierarchy to match this responsibility separation.

```text
PlayerHeli (CharacterBody3D)
├── CollisionShape3D
├── VisualPivot (Node3D)
│   └── HelicopterModel
│       ├── MainRotor
│       ├── TailRotor
│       └── Existing weapon visuals
├── StableTrackingPoint (Marker3D)
├── Existing WeaponOrigin / Muzzle nodes
└── Existing gameplay nodes

World / Gameplay Level
└── ChaseCameraRig (Node3D)
    └── SpringArm3D
        └── CameraRollPivot (Node3D)
            └── Camera3D
```

### Node responsibilities

#### `PlayerHeli`

- Must be a `CharacterBody3D`.
- Owns gameplay position, yaw heading, velocity, and collision.
- Remains upright except for Y-axis heading rotation.
- Uses floating motion mode.
- Calls `move_and_slide()` once per physics tick.

#### `VisualPivot`

- Contains the visible helicopter model.
- Receives visual pitch, roll, and hover breathing.
- Must not move or rotate the collider.
- Must not move weapon raycast origins unless those origins are intentionally attached to the visible weapon assembly.

#### `StableTrackingPoint`

- Provides a stable player position for the camera.
- Must not inherit hover breathing, pitch, or roll from `VisualPivot`.
- Keep it under the main `CharacterBody3D`, outside the visual pivot.

#### `ChaseCameraRig`

- Exists in world space instead of under the helicopter model.
- Follows the stable gameplay transform.
- Calculates camera position and look target separately.
- Must not inherit the helicopter model's pitch, roll, or hover animation.

#### `SpringArm3D`

- Handles camera obstruction against buildings and environment geometry.
- Does not provide movement smoothing.
- Must exclude the player's collider RID.
- Uses the project's existing environment collision mask.

#### `CameraRollPivot`

- Applies only the subtle cinematic camera roll.
- Uses an absolute roll value every frame.
- Must never accumulate rotation continuously.

---

## Input Map

Reuse equivalent existing Input Map actions. If they do not exist, add the following actions using the Godot editor/Input Map rather than hard-coded key polling.

| Input action | Keyboard | Controller | Function |
| --- | --- | --- | --- |
| `heli_throttle_forward` | W / Up | Left stick up | Forward movement |
| `heli_throttle_reverse` | S / Down | Left stick down | Reverse / air braking |
| `heli_turn_left` | A / Left | Left stick left | Yaw left |
| `heli_turn_right` | D / Right | Left stick right | Yaw right |
| `heli_strafe_left` | Q | Left bumper | Move left without turning |
| `heli_strafe_right` | E | Right bumper | Move right without turning |
| `heli_climb` | Shift | Existing climb input | Increase altitude |
| `heli_descend` | Ctrl / C | Existing descend input | Decrease altitude |

Do not connect mouse movement to camera orbit. Preserve mouse and right-stick actions already used by manual weapon aiming.

Apply controller dead zones through the Input Map. Use a starting dead zone around `0.15`, but preserve a working project-specific value if one already exists.

---

## Player movement implementation

### Godot physics rules

Implement flight movement in `_physics_process(delta)`.

Use:

```gdscript
motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
```

Set `CharacterBody3D.velocity` in metres per second, then call:

```gdscript
move_and_slide()
```

Call it exactly once per physics tick.

Do not multiply `velocity` by `delta`. Do not manually add `velocity * delta` to `global_position` when using `move_and_slide()`.

### Exported movement values

Add the values to the player script as exported variables or place them in the project's existing helicopter stats/resource system.

```gdscript
@export_category("Arcade Flight")
@export var max_speed: float = 38.0
@export var acceleration_stat: float = 42.0
@export var horizontal_response_scale: float = 0.16
@export var coasting_response: float = 4.8
@export var strafe_speed: float = 24.0
@export var reverse_scale: float = 0.65

@export_category("Yaw")
@export var max_yaw_rate: float = 2.85
@export var yaw_input_response: float = 14.0
@export var yaw_release_response: float = 18.0

@export_category("Altitude")
@export var climb_speed: float = 13.0
@export var vertical_response: float = 9.0
@export var min_altitude: float = 2.6
@export var max_altitude: float = 26.0
```

`38 m/s` is approximately `137 KPH`.

The default active horizontal response is:

```text
42.0 × 0.16 = 6.72 per second
```

### Exponential response helper

Use one frame-rate-independent response function:

```gdscript
func exp_response(rate: float, delta: float) -> float:
    return 1.0 - exp(-rate * delta)
```

Do not smooth the same value multiple times. Input should feed directly into target velocity, then actual velocity should receive one exponential smoothing stage.

---

## Yaw turning

Read a signed turn input:

```gdscript
var turn_input := Input.get_axis("heli_turn_right", "heli_turn_left")
```

If the current project uses the opposite sign convention, change the input order so:

- A turns left.
- D turns right.

Calculate yaw:

```gdscript
var target_yaw_rate := turn_input * max_yaw_rate
var yaw_response := yaw_input_response if abs(turn_input) > 0.001 else yaw_release_response
var yaw_weight := exp_response(yaw_response, delta)

current_yaw_rate = lerp(current_yaw_rate, target_yaw_rate, yaw_weight)
rotate_y(current_yaw_rate * delta)
```

Important behavior:

- Maximum yaw rate is `2.85 rad/s`.
- Turn entry uses response `14.0`.
- Turn release uses response `18.0`.
- Releasing the stick/key must stop yaw decisively.
- Do not instantly set Y rotation from raw input.
- Do not use the visual model's bank rotation as the gameplay heading.

---

## Heading-relative forward and strafe movement

Godot's standard forward direction is local negative Z.

```gdscript
var forward := -global_transform.basis.z
var right := global_transform.basis.x

forward.y = 0.0
right.y = 0.0

forward = forward.normalized()
right = right.normalized()
```

Read throttle and strafe separately:

```gdscript
var raw_throttle := Input.get_axis("heli_throttle_reverse", "heli_throttle_forward")
var strafe_input := Input.get_axis("heli_strafe_left", "heli_strafe_right")

var throttle_input := raw_throttle
if throttle_input < 0.0:
    throttle_input *= reverse_scale
```

Calculate the target horizontal velocity:

```gdscript
var target_forward_velocity := forward * throttle_input * max_speed
var target_strafe_velocity := right * strafe_input * strafe_speed
var target_horizontal_velocity := target_forward_velocity + target_strafe_velocity
```

Do not rotate the helicopter when Q/E strafing is used.

Do not normalize the combined forward and strafe velocity. The intended reference behavior allows strong diagonal movement when forward and strafe inputs are held together.

### Horizontal velocity response

```gdscript
var has_horizontal_input := abs(raw_throttle) > 0.001 or abs(strafe_input) > 0.001
var active_response := acceleration_stat * horizontal_response_scale
var response_rate := active_response if has_horizontal_input else coasting_response
var movement_weight := exp_response(response_rate, delta)

var current_horizontal := Vector3(velocity.x, 0.0, velocity.z)
current_horizontal = current_horizontal.lerp(target_horizontal_velocity, movement_weight)

velocity.x = current_horizontal.x
velocity.z = current_horizontal.z
```

This creates:

- Quick acceleration while input is held.
- Controlled coasting after release.
- Stronger intensity than a slow `move_toward()` implementation.
- Frame-rate-independent movement response.

Do not add another acceleration lerp elsewhere.

---

## Altitude movement

Read collective input:

```gdscript
var collective_input := Input.get_axis("heli_descend", "heli_climb")
var target_vertical_velocity := collective_input * climb_speed
var vertical_weight := exp_response(vertical_response, delta)

velocity.y = lerp(velocity.y, target_vertical_velocity, vertical_weight)
```

The helicopter must remain between `2.6 m` and `26 m` gameplay altitude.

Use collision-safe movement first, then enforce the altitude bounds without moving through geometry.

When reaching the upper altitude limit:

- Prevent further upward movement.
- Clear positive vertical velocity.
- Preserve downward input response.

When reaching the lower altitude limit:

- Prevent further downward movement.
- Clear negative vertical velocity.
- Preserve upward input response.

Do not use the visual hover animation when calculating gameplay altitude.

---

## Collision behavior

Use the player's `CollisionShape3D` and `CharacterBody3D.move_and_slide()`.

Do not recreate browser-style building collision using manual AABB checks or position push-outs.

Required behavior:

- Buildings block the helicopter.
- The helicopter slides along walls instead of stopping completely.
- The helicopter cannot pass through rooftops when climbing.
- The helicopter does not teleport away from a collision.
- The collider stays upright.

Preserve existing collision layers and masks unless they prevent proper environment collision.

---

## Helicopter visual movement

Apply visual motion only to `VisualPivot`.

### Exported visual values

```gdscript
@export_category("Visual Flight Response")
@export var turn_roll_multiplier: float = 0.16
@export var strafe_roll_multiplier: float = 0.32
@export var throttle_pitch_multiplier: float = 0.24
@export var vertical_pitch_multiplier: float = 0.02
@export var visual_response: float = 8.5
@export var hover_frequency: float = 2.4
@export var hover_amount: float = 0.08
```

### Visual roll and pitch

```gdscript
var target_roll := -current_yaw_rate * turn_roll_multiplier
target_roll -= strafe_input * strafe_roll_multiplier

var target_pitch := raw_throttle * throttle_pitch_multiplier
target_pitch -= velocity.y * vertical_pitch_multiplier

var visual_weight := exp_response(visual_response, delta)
visual_roll = lerp(visual_roll, target_roll, visual_weight)
visual_pitch = lerp(visual_pitch, target_pitch, visual_weight)
```

Apply these to `VisualPivot.rotation` without replacing its Y heading:

- Pitch uses the correct model-local X axis.
- Roll uses the correct model-local Z axis.
- The main `CharacterBody3D` keeps only its gameplay yaw.

Because imported helicopter models can face different local axes, correct the visual signs at the pivot or model-import orientation. Do not reverse gameplay movement to fix a model-facing issue.

Expected visual result:

- Left turn banks left.
- Right turn banks right.
- Left strafe leans left.
- Right strafe leans right.
- Forward acceleration adds visible nose pitch.
- Climbing and descending influence pitch slightly.

### Hover breathing

```gdscript
hover_time += delta
var hover_offset := sin(hover_time * hover_frequency) * hover_amount
```

Apply `hover_offset` only to the local Y position of the visible model/pivot.

It must not affect:

- Player collision
- Camera tracking
- Player gameplay altitude
- Enemy target position
- Auto-aim
- Projectile direction
- Weapon raycasts

### Rotor animation

Keep the existing rotor implementation if it works.

If rotor animation is missing:

```gdscript
@export var main_rotor_speed: float = 48.0
@export var tail_rotor_speed: float = 72.0
```

Rotate the actual main-rotor and tail-rotor nodes around their correct local axes. Do not rotate the whole helicopter mesh.

---

## Chase camera implementation

### Camera behavior

The camera should:

- Stay behind the helicopter's current heading.
- Follow turns smoothly through a complete 360 degrees.
- Pull farther away as horizontal speed increases.
- Rise slightly as speed increases.
- Rise with player altitude.
- Look ahead of the helicopter's nose.
- Also lead toward the real velocity direction during strafing.
- Look downward toward the battlefield at higher altitude.
- Add a small amount of helicopter bank to the camera.
- Move closer when buildings obstruct the view.

The camera should not:

- Orbit from normal mouse movement.
- Control the helicopter's movement direction.
- Inherit full helicopter roll or pitch.
- Inherit hover breathing.
- use multiple smoothing scripts.

### Camera exported values

```gdscript
@export_category("Camera Composition")
@export var base_distance: float = 31.0
@export var speed_distance_bonus: float = 5.5
@export var base_height: float = 22.0
@export var altitude_height_scale: float = 0.42
@export var speed_height_bonus: float = 2.0
@export var base_lookahead: float = 16.0
@export var speed_lookahead_bonus: float = 8.0
@export var velocity_lookahead_scale: float = 0.25
@export var look_height_scale: float = 0.35
@export var look_height_offset: float = 1.2

@export_category("Camera Response")
@export var horizontal_camera_response: float = 6.5
@export var vertical_camera_response: float = 5.5
@export var look_response: float = 9.0
@export var camera_roll_scale: float = 0.15
```

Set `Camera3D.fov` to `50.0`.

Preserve project-specific near and far clipping values if changing them would clip existing buildings, enemies, effects, or the battlefield.

---

## Camera target calculations

Use the player's stable world position and gameplay heading.

```gdscript
var player_position := tracked_player.global_position

var forward := -tracked_player.global_transform.basis.z
forward.y = 0.0
forward = forward.normalized()

var horizontal_velocity := Vector3(
    tracked_player.velocity.x,
    0.0,
    tracked_player.velocity.z
)

var horizontal_speed := horizontal_velocity.length()
var speed_ratio := clamp(horizontal_speed / tracked_player.max_speed, 0.0, 1.2)
```

### Dynamic camera distance

```gdscript
var camera_distance := base_distance + speed_ratio * speed_distance_bonus
```

At higher speed, the camera moves up to `5.5 m` farther away.

### Dynamic camera height

```gdscript
var camera_height := base_height
camera_height += (player_position.y - 2.4) * altitude_height_scale
camera_height += speed_ratio * speed_height_bonus
```

### Dynamic look-ahead

```gdscript
var lookahead_distance := base_lookahead + speed_ratio * speed_lookahead_bonus
```

### Desired camera position

```gdscript
var desired_camera_position := player_position
desired_camera_position -= forward * camera_distance
desired_camera_position += Vector3.UP * camera_height
```

### Desired look target

```gdscript
var desired_look_position := player_position
desired_look_position += forward * lookahead_distance
desired_look_position += horizontal_velocity * velocity_lookahead_scale
desired_look_position.y = player_position.y * look_height_scale + look_height_offset
```

The heading look-ahead frames where the helicopter is facing. The velocity lead frames where it is actually moving during strafing and momentum.

---

## Camera smoothing

Update camera presentation once per rendered frame from `_process(delta)` using the stable/interpolated player world transform supported by the installed Godot version.

Use separate smoothing for horizontal position, vertical position, and look target.

```gdscript
var horizontal_weight := exp_response(horizontal_camera_response, delta)
var vertical_weight := exp_response(vertical_camera_response, delta)
var look_weight := exp_response(look_response, delta)

smoothed_camera_position.x = lerp(
    smoothed_camera_position.x,
    desired_camera_position.x,
    horizontal_weight
)

smoothed_camera_position.z = lerp(
    smoothed_camera_position.z,
    desired_camera_position.z,
    horizontal_weight
)

smoothed_camera_position.y = lerp(
    smoothed_camera_position.y,
    desired_camera_position.y,
    vertical_weight
)

smoothed_look_position = smoothed_look_position.lerp(
    desired_look_position,
    look_weight
)
```

Initialize both smoothed values immediately when the player is assigned or the gameplay scene starts. Do not initialize them at `Vector3.ZERO` and let the camera fly across the level at spawn.

Do not add another camera lerp in a parent node, SpringArm script, AnimationPlayer, or player script.

---

## SpringArm3D camera collision

Use `SpringArm3D` only to shorten the camera distance when geometry blocks the view.

Implementation approach:

1. Set `ChaseCameraRig.global_position` to the smoothed look target.
2. Calculate the direction from the look target to the smoothed desired camera position.
3. Orient the rig so the SpringArm's positive Z axis extends toward the desired camera position.
4. Set `SpringArm3D.spring_length` to the distance between the look target and desired camera position.
5. Keep `CameraRollPivot` and `Camera3D` beneath the SpringArm.
6. Exclude the player's collider RID with `add_excluded_object()`.
7. Set the SpringArm collision mask to environment/building geometry only.

Do not make the SpringArm collide with:

- Player bullets
- XP pickups
- Enemy projectiles
- UI helpers
- Trigger areas
- The player's collider

Do not manually teleport the camera after the SpringArm resolves collision.

---

## Camera rotation and cinematic bank

Aim the camera toward `smoothed_look_position` using world up.

Apply camera bank on `CameraRollPivot`:

```gdscript
camera_roll_pivot.rotation.z = tracked_player.visual_roll * camera_roll_scale
```

The value must be assigned, not incremented.

The camera receives only 15% of the helicopter's visual roll. It must feel subtle and should not rotate the entire horizon as strongly as the model.

---

## Preventing slow or artificial movement

Remove or disable conflicting logic that does any of the following:

- Smooths raw movement input before calculating target velocity.
- Smooths target velocity and then smooths actual velocity again.
- Applies player acceleration in both `_process()` and `_physics_process()`.
- Calls `move_and_slide()` more than once.
- Multiplies `CharacterBody3D.velocity` by `delta`.
- Moves the `CharacterBody3D` with both `global_position` and `move_and_slide()`.
- Parents the camera to the banked helicopter model.
- Calculates movement direction from the already-smoothed camera direction.
- Lets mouse aiming rotate the camera rig.
- Lets auto-aim rotate the whole helicopter body.
- Uses two current cameras or two active camera scripts.
- Lets an AnimationPlayer overwrite player or camera transforms.
- Adds custom smoothing on top of SpringArm collision handling.

Each responsibility must have only one response stage:

| Responsibility | Response stage |
| --- | --- |
| Yaw | Angular velocity response |
| Forward/strafe | Horizontal velocity response |
| Altitude | Vertical velocity response |
| Model banking | VisualPivot response |
| Camera position | World-space camera response |
| Camera aiming | Look-target response |

---

## Integration boundaries

### Shooting and aiming

- Mouse/right-stick input remains manual weapon aim.
- Auto-aim may rotate the gun/turret assembly only.
- Auto-aim must not rotate `PlayerHeli`, `VisualPivot`, or `ChaseCameraRig`.
- Preserve current muzzle nodes and weapon ray origins.
- Camera movement must not change projectile direction unless the existing manual-aim system intentionally uses a camera ray.

### Enemy targeting

- Enemies should continue tracking the stable player body or existing target marker.
- Do not make enemies track the hover-breathing visual model.
- Preserve the player's current groups and target-registration signals.

### Stats and upgrades

If the project already stores helicopter stats in a Resource or upgrade system:

- Keep that system.
- Use its final maximum speed and acceleration values.
- Do not create duplicate stat variables with different ownership.
- Preserve turbine/permanent-upgrade modifiers.

### Environment

- Do not alter the existing environment layout.
- Do not resize or reposition buildings as part of this task.
- Only correct collision layers/masks needed by the player and camera.

---

## Implementation order

Implement in this order:

1. Read the root gameplay GDD.
2. Inspect the existing player scene, player script, Input Map, camera scene, camera script, and transform-writing animations.
3. Keep the existing gameplay connections and identify conflicting movement/camera logic.
4. Establish the `CharacterBody3D` and `VisualPivot` responsibility separation.
5. Implement heading, yaw response, forward/reverse movement, and independent strafing.
6. Implement climb/descend movement and altitude bounds.
7. Connect native collision and floating `move_and_slide()` behavior.
8. Add model-only pitch, roll, and hover breathing.
9. Move camera tracking into a world-space chase rig.
10. Implement dynamic distance, height, velocity lead, and look-target smoothing.
11. Configure SpringArm obstruction and player exclusion.
12. Preserve aiming, weapons, enemy targeting, stats, and existing scene connections.

Do not create a second disconnected player or camera demo scene. Implement this inside the real gameplay scene used by the project.

---

## Final instruction to the Godot AI agent

Use the Fennara Godot AI MCP to make these changes directly in the current project. Do not respond with hypothetical snippets only.

Keep the implementation component-based and Godot-native:

- `CharacterBody3D` for flight collision and movement
- `CollisionShape3D` for the helicopter collider
- `Node3D` visual pivot for banking
- `Marker3D` for a stable tracking point
- `SpringArm3D` for camera obstruction
- `Camera3D` for the final view
- Input Map actions for controls
- Existing Resources/signals/groups for project integration

Do not add unrelated features, third-party camera packages, placeholder systems, or broad refactors. The result should replace only the current movement and camera implementation while keeping the rest of Heli-Strike intact.
