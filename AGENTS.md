# Project Guidelines - URBAN Strike Rogue

This project is **URBAN Strike Rogue**, an arcade helicopter roguelite built with Godot 4.

## AI Assistant & Tooling Requirements

- **Mandatory Documentation & Reference Tool**: ALWAYS use **Ziva AI** / Context7 MCP (`resolve-library-id`, `query-docs`) for all Godot 4 API lookups, GDScript documentation, shader syntax, and library references.
  - Step 1: Use `resolve-library-id` with `libraryName: "godot"` (or relevant library) and your query concept.
  - Step 2: Use `query-docs` with the resolved library ID (e.g., `/websites/godotengine_en_4_7`) to retrieve exact and modern API guidance.
- **Strictly Prohibited**: Never install, call, or re-introduce Fennara MCP or its runtime daemons / autoloads. Fennara has been completely removed from this repository and environment.

## Architecture & Conventions

- **Engine Target**: Godot 4.7+ (GL Compatibility renderer).
- **Core Flight Mechanics**:
  - AH-9 Vulture flight physics utilizing `CharacterBody3D` with `MOTION_MODE_FLOATING`.
  - Realistic tilt/roll pivots, dual-stick aiming, and responsive arcade inertia.
- **Director Architecture**:
  - `CombatDirector`: Manages attack tokens (ground & air), attacker concurrency caps, and danger budgets.
  - `SpawnDirector`: Handles procedural wave spawning, authored ground/air entrances, frustum safety, and separation spacing.
  - `CityWorldStreamer`: Seamless chunk streaming, road graph continuity, and rooftop socket registries.
  - `EventBus`: Centralized event dispatch singleton (`res://scripts/common/event_bus.gd`).
- **Automated Verification**:
  - Maintain 100% test pass rate on the automated vertical slice test suite in `scenes/tests/test_runner.tscn`.
