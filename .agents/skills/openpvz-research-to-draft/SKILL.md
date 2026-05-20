---
name: openpvz-research-to-draft
description: Research an OpenPVZ feature direction and turn it into a concise draft in plans/draft. Use when the user proposes a direction, asks for analysis before implementation, asks to compare OpenPVZ with vendor/PVZ-Godot-Dream or vendor/de-pvz, or asks to create/refine a draft without coding yet.
---

# OpenPVZ Research To Draft

## Purpose

Use this skill to move a vague direction into a grounded design draft. Do not implement code while using this skill unless the user explicitly changes the task.

## Required Context

Read only the materials relevant to the direction:

- `AGENTS.md`
- `plans/README.md`
- Existing `plans/draft/*.md` near the topic
- Current wiki pages listed by `AGENTS.md` for the task type
- the wiki file matching `wiki/04-roadmap-reference/46-*` before searching reference projects
- Current runtime/data files that define the existing capability
- `vendor/de-pvz/` for original PVZ semantics and numbers
- `vendor/PVZ-Godot-Dream/` for Godot-side reference expression

Prefer `rg` for search. If `rg --files` misses vendor content, use `Get-ChildItem` on the target vendor directory.

## Workflow

1. Clarify the direction in one sentence.
2. Find the closest existing OpenPVZ concept, subsystem, validation layer, and plan/wiki owner.
3. If reference projects are relevant, use `$openpvz-reference-index` logic or the semantic index wiki to choose vendor anchors.
4. Compare three sources:
   - OpenPVZ current implementation
   - `vendor/de-pvz/` original behavior or semantic anchor
   - `vendor/PVZ-Godot-Dream/` Godot implementation pattern
5. Identify gaps as concept, protocol, implementation, validation, content, or visual/audio/UI gaps.
6. Propose the smallest coherent draft boundary.
7. Write or update `plans/draft/<topic>.md` only when the user asked for a draft artifact.
8. Do not register the draft as current implementation basis unless the user explicitly asks.

## Draft Shape

Use Chinese. Keep the draft practical and reviewable:

- title, date, status, related docs
- TL;DR
- background and objective
- non-goals
- source comparison table
- current OpenPVZ state
- recommended model and alternatives
- protocol and validation gaps
- phased route
- open questions

## Guardrails

- Preserve Mechanic-first: `CombatArchetype + CombatMechanic[]` remains the runtime content entry.
- Do not propose BattleManager entity-specific branches.
- Do not add a Mechanic family without explicit design approval.
- New extension points must follow `RegistryBase + RegistryConfig + ContributorDef`.
- Do not modify `vendor/`.
- Treat draft files as discussion artifacts, not implementation authority.
- When the topic touches validation, include at least one concrete validation idea.
