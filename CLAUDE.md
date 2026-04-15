# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Open PVZ — a composable, extensible PVZ-like rule engine built in Godot 4.x (GDScript). Not a direct Plants vs Zombies clone; the engine prioritizes open combination of rules and emergent gameplay over feature completeness.

Current stage: Phase 4 — gameplay systems integration (resource economy, board/card system, wave system). Phases 1-3 (backbone, templates, protocol freeze) are complete.

## Running and Testing

### Running the Project
- Open in Godot 4.x editor. Main scene: `res://scenes/main/main.tscn`
- Viewport: 960x540, window: 1920x1080

### Validation (Testing)
Validation scenarios are the primary test mechanism — there is no unit test framework.

```powershell
# Run all validation scenarios
pwsh tools/run_all_validations.ps1

# Run a single scenario
pwsh tools/run_validation.ps1 -ScenarioId <id>
```

Scenario definitions: `tools/validation_scenarios.json`
Scenario scenes: `scenes/validation/`
Results output: `artifacts/validation/`

To run a single scenario from the Godot editor, open its `.tscn` file in `scenes/validation/` and press F6 (Run Current Scene).

## Architecture

### Four-Layer Model

1. **Semantic Event Layer** — "What happened." Events like `game.tick`, `entity.damaged`, `entity.died`, `projectile.hit` flow through `EventBus` (autoload).
2. **Behavior Layer** — "What to do." `EffectDef` → `EffectNode` executed by `EffectExecutor`. Effects are atomic, composable, nestable (max depth 5). Registered in `EffectRegistry`.
3. **Composition Layer** — "How entities are assembled." `EntityTemplate` → `TriggerBinding` → factory assembly. `TriggerDef` → `TriggerInstance` → `TriggerComponent` on entities. Registered in `TriggerRegistry`.
4. **Continuous Behavior Layer** — "How persistent objects update." Projectiles use 3D logic with 2D projection, continuous simulation via `_physics_process`, re-enter event chain on `projectile.hit`.

### Execution Chain
```
EventBus → TriggerComponent → TriggerInstance → RuleContext → EffectExecutor → Runtime Action → EventBus
```

### Key Autoloads (global singletons)
- `EventBus` — event dispatch with priority subscriptions, history tracking (256 max)
- `DebugService` — centralized logging for events/triggers/effects
- `SceneRegistry` — scene management
- `TriggerRegistry` — trigger definition and strategy registry
- `EffectRegistry` — effect definition and strategy registry
- `GameState` — game state management

### Directory Layout (key paths)
- `scripts/core/defs/` — Resource definitions (TriggerDef, EffectDef, EntityTemplate, etc.)
- `scripts/core/runtime/` — Execution logic (EffectExecutor, ProtocolValidator, Context, EntityState)
- `scripts/battle/` — Battle coordination (BattleManager, entity factory, board/card state)
- `scripts/entities/` — Entity types (base_entity → plant_root, zombie_root, projectile_root)
- `scripts/components/` — Reusable behaviors (health, trigger, hitbox, movement)
- `data/combat/` — Template resources organized by type (entity_templates/plants/, entity_templates/zombies/, height_bands/, projectile_templates/, etc.)
- `scenes/validation/` — Automated test scenarios (.tscn + .tres)
- `wiki/` — Structured design documentation (Chinese language)

## Frozen Protocol (Phase 3)

The first protocol freeze is in effect. Do not change the semantics of these without explicit design approval:

**Triggers:** `periodically` (game.tick), `when_damaged` (entity.damaged), `on_death` (entity.died)
**Effects:** `damage`, `spawn_projectile`, `explode`
**Behavior keys:** `attack` → periodically, `when_damaged` → when_damaged, `on_death` → on_death

`ProtocolValidator` enforces parameter types, bounds, and resource script types at runtime. All new definitions must pass validation.

## Conventions

### Resource Definitions
- All game definitions use Godot `Resource` (.tres) files, not JSON or external formats
- Use `@export` for editor-visible properties
- One class per file; extend `Resource` for data definitions

### Template Writing Order
Identity → Node/Component → Combat → Projectile → Behavior

### Template Naming
- `plant_role_variant`, `zombie_role_variant`, `projectile_type`
- Files go in `data/combat/entity_templates/plants/` or `zombies/`

### Event Naming
Dot-separated semantic names: `game.tick`, `entity.damaged`, `entity.died`, `projectile.hit`

### Target Resolution Modes (effects)
`context_target`, `source`, `owner`, `event_source`, `event_target`, `enemies_in_radius`

### Code Style
- PascalCase for class names, snake_case for variables/functions
- StringName for interned identifiers
- RefCounted for data passed between systems

## Documentation

The `wiki/` directory contains comprehensive design documentation in Chinese:
- `01-overview/` — architecture, design philosophy, current stage
- `02-runtime-protocol/` — trigger system, effect system, execution mechanism
- `03-content-validation/` — validation matrix and coverage
- `04-roadmap-reference/` — reference implementations
- `05-governance/` — template writing conventions, methodology

The `plans/` directory contains phase task lists and design documents.

## Validation Scenarios

When adding new engine features, create a validation scenario:
1. Add entry to `tools/validation_scenarios.json`
2. Create scene in `scenes/validation/`
3. Define scenario config as `.tres` resource (BattleScenario)
4. Run via `pwsh tools/run_all_validations.ps1`
