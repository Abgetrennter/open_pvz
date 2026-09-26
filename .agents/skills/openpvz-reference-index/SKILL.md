---
name: openpvz-reference-index
description: Find and apply the right OpenPVZ reference-project anchors in E:/Code/pvz-ws/references/de-pvz and E:/Code/pvz-ws/references/PVZ-Godot-Dream. Use when the user asks to compare with original PVZ, inspect de-pvz, inspect PVZ-Godot-Dream, extract original values or behavior, or locate reference files before drafting, planning, or implementing.
---

# OpenPVZ Reference Index

## Purpose

Use this skill to route reference-project research before reading large vendor trees. Start from the semantic index, then inspect only the relevant source files.

## Required First Read

Read the wiki file matching `wiki/04-roadmap-reference/46-*` before searching vendor code.

## Source Priority

1. `E:/Code/pvz-ws/references/de-pvz/` is the original-spec source for numbers, enums, tick semantics, resource ids, board coordinates, and behavior conditions.
2. `E:/Code/pvz-ws/references/PVZ-Godot-Dream/` is a Godot expression reference for nodes, components, scenes, animation, UI, and engineering organization.
3. OpenPVZ code and resources are the final target. Do not copy either reference project directly.

If `de-pvz` and `PVZ-Godot-Dream` disagree about original behavior, trust `de-pvz` and mention the discrepancy.

## Workflow

1. Classify the user task: plant, zombie, board/grid, projectile, UI/input, visual/audio, mode, extension, or validation.
2. Use the semantic index to choose the first vendor files.
3. Search targeted anchors with `rg`; use `Get-ChildItem` if vendor discovery is unreliable.
4. Extract only the facts needed for the current task.
5. Translate those facts into OpenPVZ terms:
   - `CombatArchetype`
   - `CombatMechanic`
   - registry slot
   - battle subsystem
   - resource definition
   - validation scenario
6. Report source paths and anchor names, not only conclusions.

## Common Anchors

- Plants: `E:/Code/pvz-ws/references/de-pvz/Lawn/Plant.cpp:gPlantDefs[]`, `ConstEnums.h:SeedType`
- Zombies: `E:/Code/pvz-ws/references/de-pvz/Lawn/Zombie.cpp:gZombieDefs[]`, `Zombie.h`
- Board metrics: `E:/Code/pvz-ws/references/de-pvz/GameConstants.h`, `E:/Code/pvz-ws/references/de-pvz/Lawn/Board.cpp`
- Projectiles: `E:/Code/pvz-ws/references/de-pvz/Lawn/Projectile.cpp`
- Resources: `E:/Code/pvz-ws/references/de-pvz/Resources.cpp`, `Resources.h`
- Reanim: `E:/Code/pvz-ws/references/de-pvz/Sexy.TodLib/Reanimator.*`, `Attachment.*`
- Godot components: `E:/Code/pvz-ws/references/PVZ-Godot-Dream/scripts/character/components/`
- Godot managers: `E:/Code/pvz-ws/references/PVZ-Godot-Dream/scripts/manager/`
- Godot level resources: `E:/Code/pvz-ws/references/PVZ-Godot-Dream/scripts/resources/level/`, `level_game_para/`

## Guardrails

- Do not modify `references/` (moved from vendor/, see root pin.json).
- Do not treat external wiki, memory, or prior summaries as final numeric evidence.
- Do not import `PVZ-Godot-Dream` concrete unit scripts as OpenPVZ entity-specific logic.
- Do not bypass Mechanic-first or registry conventions.
- When writing drafts or plans, cite the exact reference path and explain whether it is original spec or Godot implementation reference.
