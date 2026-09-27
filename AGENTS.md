# Repository Guidelines

## Project Structure & Module Organization

OpenPVZ is a Godot 4.x/GDScript engine for composable PVZ-like rules. `scripts/` contains runtime systems; `autoload/` provides registries and services; `data/combat/` stores Resource-based content; `scenes/` contains gameplay, showcases, and validation scenes. `extensions/` holds public examples, `tools/` validation scripts, `wiki/` current documentation, and `plans/` active work and archives. Read the relevant directory-level `AGENTS.md` before editing its module.

## Build, Test, and Development Commands

Open `project.godot` in Godot; F6 runs a selected scene. From the working checkout, using PowerShell 7:

```powershell
godot --editor --path .
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/<scenario>.tres"
pwsh tools/run_all_validations.ps1 -MaxParallel 8
pwsh tools/check_docs_health.ps1
pwsh tools/check_public_extension_release_guardrails.ps1
```

Use your configured Godot executable; validation scripts accept `-GodotExe`. Batch concurrency defaults to 8; `-MaxParallel 0` selects `min(CPU cores, 8)`. Public batches exclude `local_private`; explicitly request that layer only with the private pack mounted.

## Coding Style & Architecture

Use UTF-8, existing tab indentation in GDScript, PascalCase classes, snake_case functions/files, and StringName identifiers. Author game content as `.tres` Resources with exported properties.

Preserve `CombatArchetype + CombatMechanic[] -> RuntimeSpec -> EntityFactory`. Avoid entity-specific code and BattleManager special cases. Extensions use `RegistryBase + RegistryConfig + ContributorDef`; never override `core.*`. Frozen protocol changes require design approval. Use DebugService, deterministic simulation time, and seeded randomness; presentation must not change combat outcomes. Follow the [detailed development constraints](wiki/05-governance/contributor-guide.md) for runtime, content, and extension changes.

## Testing Guidelines

Scenario validation is the automated test mechanism; no unit-test framework or coverage percentage is prescribed. Add scenarios for new entity behavior and smoke/guardrail cases for extensions. Register scenarios in `tools/validation_scenarios.json`; `.tres` defines BattleScenario, while `.tscn` is optional. Run targeted checks, then full regression before merging game changes. Inspect `artifacts/validation/` reports and distinguish automated results from visual checks. Documentation-only changes require documentation/link checks.

## Commit & Pull Request Guidelines

Use existing scoped prefixes, such as `governance:`, `docs(scope):`, and `feat(scope):`. Describe intent, affected modules, validation results, and limitations; include screenshots for visual changes. Keep commits within one repository.

## Workspace & Reading

In `pvz-ws`, the main checkout is read-only; edit in allocated worktrees and follow workspace task/closure contracts. Resolve references and private assets through workspace configuration, not checkout-relative sibling assumptions.

Start with the [Wiki index](wiki/index.md) for onboarding, current status, and architecture; load task-specific protocol pages as needed. Historical changes remain in Git history.
