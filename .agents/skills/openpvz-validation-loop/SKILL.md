---
name: openpvz-validation-loop
description: Run, triage, and repair OpenPVZ Godot validation failures. Use when the user asks to run validation, fix failing validation scenes, run the full validation suite, investigate headless Godot errors, or verify a completed OpenPVZ implementation.
---

# OpenPVZ Validation Loop

## Purpose

Use this skill to make validation evidence drive changes. Start from failing scenarios or a requested validation layer, find the earliest actionable error, apply the smallest fix, and rerun the relevant checks.

## Commands

Use PowerShell from the repository root:

```powershell
pwsh tools/run_all_validations.ps1
pwsh tools/run_all_validations.ps1 -MaxParallel 4
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/<scenario>.tres"
pwsh tools/check_public_extension_release_guardrails.ps1
```

Use layer or scenario filters only when the current script supports them in the checkout.

## Workflow

1. Inspect `git status --short` and avoid unrelated user changes.
2. Run the requested validation command. For broad failures, prefer the full suite first to collect clusters.
3. Read `artifacts/validation/summary.json`, failing `validation_report.json`, and relevant `debug_logs.json`.
4. Identify the earliest actionable signal:
   - first GDScript parse or compile error
   - first runtime error
   - first unsatisfied validation rule
   - first protocol issue that explains later failures
5. Patch the smallest relevant code/data/doc surface.
6. Add or adjust a validation scenario when the behavior would otherwise be unprotected.
7. Rerun the narrow failing scenario or cluster.
8. Rerun the broader suite when the blast radius touches shared runtime, registries, validation harness, or content manifests.
9. Run `git diff --check` before final reporting.

## Triage Notes

- Headless class-name failures often require `preload` script references or runtime singleton lookup instead of relying on global class names.
- Validation probes should assert the behavior they claim to cover; a smoke scene that only boots is not enough for allowlist or policy checks.
- For runtime metrics guardrails, distinguish gameplay wall-clock misuse from profiling/tick budget measurement.
- If validation script behavior changes, update `AGENTS.md` or the relevant docs.

## Guardrails

- Do not guess-fix before reading the failing report/log.
- Do not use `print()` for runtime logging outside existing allowed validation/reporting surfaces.
- Do not modify `vendor/`.
- Do not revert unrelated user changes.
- Do not commit, branch, push, or stage unless the user explicitly asks.
- Keep fixes aligned with Mechanic-first and registry-slot conventions.
