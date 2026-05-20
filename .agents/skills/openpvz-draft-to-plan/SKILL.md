---
name: openpvz-draft-to-plan
description: Convert an OpenPVZ draft or mature design discussion into an implementation plan. Use when the user asks to turn a plans/draft document into a plan, split work into tasks, define DoD, choose validation commands, or prepare a feature for execution without coding yet.
---

# OpenPVZ Draft To Plan

## Purpose

Use this skill after a draft has stabilized enough to become executable work. The result is a scoped implementation plan, not code.

## Required Context

Read:

- `AGENTS.md`
- `plans/README.md`
- The target `plans/draft/*.md`
- Any linked plan/wiki documents
- the wiki file matching `wiki/04-roadmap-reference/46-*` when the plan depends on original/reference behavior
- Current code paths named by the draft
- `tools/validation_scenarios.json` and `tools/formal_content_validation_map.json` when validation coverage changes

If the draft depends on original behavior, use `$openpvz-reference-index` logic or the semantic index wiki to re-check the relevant `vendor/de-pvz/` and `vendor/PVZ-Godot-Dream/` anchors before planning.

## Workflow

1. State the plan objective in one sentence.
2. Classify each required change as concept, protocol, runtime, content, validation, docs, or migration.
3. Reject or defer items that are outside the draft boundary.
4. Split work into the smallest useful implementation tasks.
5. For each task, specify:
   - files or modules likely touched
   - dependency on earlier tasks
   - acceptance criteria
   - validation command
   - rollback or review risk
6. Define final Definition of Done.
7. State whether `plans/README.md` should be updated and under which status.

## Plan Shape

Use Chinese. Prefer a compact markdown plan:

- status and source draft
- objective
- non-goals
- task list
- dependency order
- validation matrix
- DoD
- archive/update rules

## Guardrails

- Do not silently expand scope beyond the draft.
- Prefer spike tasks when a protocol decision is still uncertain.
- Keep implementation slices small enough for Codex to execute and verify in one turn when possible.
- Every runtime or content task needs a validation task or an explicit reason why existing validation is enough.
- Do not plan git commit, branch, push, or PR steps unless the user explicitly asks.
- Do not make the draft a current fact source until `plans/README.md` is updated intentionally.
