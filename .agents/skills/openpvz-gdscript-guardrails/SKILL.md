---
name: openpvz-gdscript-guardrails
description: Apply OpenPVZ-specific GDScript implementation guardrails adapted from general Godot 4 patterns. Use when editing or reviewing OpenPVZ .gd, .tscn, .tres, Resource definitions, visual/audio/input/UI support code, autoload or registry integrations, scene/resource loading, object pooling, timing, logging, or validation-sensitive Godot changes.
---

# OpenPVZ GDScript Guardrails

## Purpose

Use this skill to translate general Godot 4 and GDScript patterns into OpenPVZ-safe implementation choices. Treat repository rules as the source of truth: Mechanic-first runtime, .tres Resource-driven content, deterministic 100Hz simulation time, DebugService logging, and validation-manifest coverage override generic Godot examples.

## First Checks

1. Inspect `git status --short` and avoid unrelated user changes.
2. Read the nearest `AGENTS.md` for the touched module before editing.
3. For runtime or protocol changes, read the relevant wiki page before choosing an implementation.
4. Prefer the narrowest code/data/doc surface that satisfies the request.

## Godot Patterns To Keep

- Use typed GDScript signatures, typed arrays where practical, and explicit return types.
- Use `@export` for editor-authored Resource and scene properties.
- Use `@onready` and cached node references outside hot paths.
- Use signals for observation and support-layer decoupling.
- Use `Resource` classes for authorable data and `.tres` content.
- Duplicate Resource instances before mutating runtime state that must not write back to shared content.
- Use object pooling for visual, audio, projectile display, or other high-churn support-layer nodes when profiling or behavior justifies it.
- Use `ResourceLoader.load_threaded_request()` for optional or heavy visual/audio/UI assets when blocking load would harm user experience.

## OpenPVZ Overrides

- Do not hardcode behavior for a single plant, zombie, projectile, mode, or field object in GDScript.
- Do not add `print()` runtime logging outside existing validation/reporting allowances; use `DebugService`.
- Do not use `Timer`, `SceneTree.create_timer()`, `OS.get_ticks_*`, or `Time.get_ticks_*` as gameplay or rule time sources.
- Do not make visual, audio, UI, Tween, particle, or rendering behavior affect combat outcomes.
- Do not bypass `CombatArchetype + CombatMechanic[] -> RuntimeSpec -> EntityFactory` for entity behavior.
- Do not introduce direct combat duck typing such as `body.has_method("take_damage")` for real gameplay.
- Do not add standalone registry or extension mechanisms; use `RegistryBase + RegistryConfig + ContributorDef`.
- Do not modify `vendor/`.

## Preferred Mappings

| Task | Preferred OpenPVZ shape |
| --- | --- |
| New entity behavior | `.tres` `CombatArchetype` plus `CombatMechanic[]`, compiler/runtime support only if needed |
| New content data | Authorable `Resource` class and `.tres` content, not inline dictionaries in GDScript |
| New extension point | Contributor `Resource`, registry autoload via `RegistryBase`, catalog allowlist, smoke and guardrail validation |
| Logging or diagnostics | `DebugService.record_*` or existing validation reporter surfaces |
| Gameplay time, cooldown, duration, deadlines | `GameState.current_tick`, `GameState.current_time`, `GameState.fixed_dt`, or existing tick events |
| Visual/audio/UI response | Event-observing support layer with Resource-driven mapping; no combat result dependency |
| Repeated support-layer spawning | Pool only after confirming lifecycle and reset behavior are clear |
| Heavy optional asset loading | `ResourceLoader` threaded loading for support assets; avoid touching deterministic gameplay flow |

## Review Checklist

Before finalizing a GDScript change, scan for:

- `print(` in runtime files.
- `Timer`, `create_timer`, `OS.get_ticks`, or `Time.get_ticks` in gameplay paths.
- Direct entity-specific branches in `BattleManager`, registries, factories, or shared components.
- Hardcoded content values that belong in `.tres` Resources.
- Mutation of shared Resources without runtime duplication or a clear authoring-only boundary.
- New extension logic that bypasses the existing registry-slot production line.
- Visual/audio/UI code that writes gameplay state or changes validation outcomes indirectly.
- Missing validation scenario, manifest entry, or guardrail update for new behavior.

## Validation

Use the repository validation flow that matches the blast radius:

```powershell
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/<scenario>.tres"
pwsh tools/run_all_validations.ps1 -MaxParallel 8
pwsh tools/check_public_extension_release_guardrails.ps1
```

Run `git diff --check` before reporting completion. Do not stage, commit, branch, or push unless the user explicitly asks.

## Boundaries

This skill supplements, but does not replace, more specific OpenPVZ skills. Use `openpvz-validation-loop` for failing validation runs, `openpvz-reference-index` for original PVZ reference lookup, `openpvz-research-to-draft` for design research, and `openpvz-draft-to-plan` for implementation planning.
