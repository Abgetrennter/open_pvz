# Project Agent Notes

## Project Positioning

Treat this repository as an open PVZ-like rules engine project, not a one-off demo. The current phase is:

> phases 1 through 4 are complete, the backbone and battle-play layer are already in place, and the project is now in phase 5: chaos-tech examples, extension entry points, and tooling.

That means the default priority order is:

1. backbone correctness
2. repeatable validation
3. protocol/resource consistency
4. expressive sample coverage on the shared runtime
5. extension/tooling readiness

## Godot Paths

- Console: `E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe`
- GUI: `E:\SDK\Godot\Godot_v4.6.1-stable_win64.exe`

## Default Read Order

Before doing substantial coding or "vibe coding" in this repo, read these docs first:

1. `README.md`
2. `wiki/index.md`
3. `wiki/01-overview/23-当前阶段与实现路线.md`
4. `plans/第四阶段阶段总结.md`
5. `plans/第五阶段可执行任务清单.md`
6. `plans/archive/第一至第四阶段归档总览.md`
7. `wiki/04-roadmap-reference/26-开发路线图.md`
8. `wiki/03-content-validation/32-验证矩阵.md`
9. `wiki/05-governance/27-项目开发方法论.md`
10. `wiki/05-governance/29-文档规范与维护约定.md`
11. `wiki/05-governance/31-重大决策记录模板.md`
12. `wiki/05-governance/33-术语表.md`

The wiki is physically organized by layer under `01-overview`, `02-runtime-protocol`, `03-content-validation`, `04-roadmap-reference`, and `05-governance`.
Completed stage records and historical handoff docs are now being moved under `plans/archive/` instead of staying in `wiki/` current-governance slots.

If you are entering for a specific task, use this shorter route:

- Project direction and planning:
  - `README.md`
  - `wiki/01-overview/34-Open PVZ 系统版图与规划分层.md`
  - `wiki/01-overview/23-当前阶段与实现路线.md`
  - `plans/第四阶段阶段总结.md`
  - `plans/第五阶段可执行任务清单.md`
  - `wiki/04-roadmap-reference/26-开发路线图.md`
- Runtime and protocol work:
  - `wiki/01-overview/02-系统架构.md`
  - `wiki/02-runtime-protocol/03-触发器系统.md`
  - `wiki/02-runtime-protocol/04-效果系统.md`
  - `wiki/02-runtime-protocol/06-执行机制.md`
  - `wiki/02-runtime-protocol/07-事件模型.md`
  - `wiki/02-runtime-protocol/08-连续行为模型.md`
- Validation and workflow work:
  - `wiki/03-content-validation/12-完整工作流.md`
  - `wiki/03-content-validation/15-验证清单.md`
  - `wiki/03-content-validation/32-验证矩阵.md`
- Documentation and governance work:
  - `wiki/05-governance/27-项目开发方法论.md`
  - `wiki/05-governance/29-文档规范与维护约定.md`
  - `wiki/05-governance/31-重大决策记录模板.md`
  - `wiki/05-governance/33-术语表.md`
  - `plans/archive/第一至第四阶段归档总览.md`

Use `wiki/05-governance/28-Wiki审查与规范化建议.md` and `wiki/05-governance/30-Wiki内容审查报告.md` as historical review records, not as default current-state entry points.

`wiki/05-governance/27-项目开发方法论.md` is the default process guide for this repository. If there is ambiguity about workflow, wiki structure, terminology, or what should be updated together, use the governance docs as the source of truth.

## Working Rules

When making engine, runtime, validation, or protocol changes in this repo:

- Define the problem at the right level first: concept, protocol, implementation, validation, or content.
- Do not patch visible symptoms directly into the backbone if the issue is really a missing abstraction.
- Separate backbone work, content work, and demo work. Do not treat a demo-only fix as backbone completion.
- Prefer explicit Resource-based configuration over long-lived bare dictionaries.
- Keep terminology aligned with `wiki/05-governance/33-术语表.md` so concept names do not drift across docs, resources, and code.
- Add or update validation coverage when changing core behavior. A backbone change is not complete if it only "looks right" in one scene.
- When adding or changing a validation scenario, update all of the following in the same pass:
  - the `.tres` scenario resource under `scenes/validation/`
  - `tools/validation_scenarios.json` if the scenario should join batch automation
  - `wiki/03-content-validation/32-验证矩阵.md`
  - `agent.md` if command examples or default validation guidance change
- Use logs and repeatable validation as the standard for correctness, not visual intuition alone.
- When a new abstraction is introduced, identify what older logic must migrate with it so mixed models do not remain in the codebase.
- If a change affects world model, protocol boundaries, validation exits, migration strategy, or other system-level assumptions, create or update a decision record using `wiki/05-governance/31-重大决策记录模板.md`.
- If a change affects project assumptions, protocol boundaries, validation rules, terminology, or documentation structure, update the relevant wiki docs in the same pass.
- If a wiki document becomes primarily a completed-stage handoff, freeze-range record, or historical cleanup note, prefer moving it to `plans/archive/` and then update `wiki/index.md`, `README.md`, and any local cross-references in the same pass.

## Practical Checklist

Before major changes:

- Clarify goal
- Clarify non-goals
- Clarify acceptance criteria
- Identify migration scope
- Identify the target layer: concept, protocol, implementation, validation, or content
- Decide which validation scenario proves the change
- Decide whether the change needs a wiki update or an ADR-style decision record

After major changes:

- Run headless Godot startup
- Run the relevant validation scenario(s)
- Register new validation scenarios in `tools/validation_scenarios.json` if they belong in batch runs
- Update `wiki/03-content-validation/32-验证矩阵.md` if validation coverage changed
- Update `README.md` or `agent.md` if default phase/state or validation entry guidance changed
- Check logs if behavior is spatial, event-driven, or timing-sensitive
- Update wiki/resources/decision records if protocol, workflow, terminology, or project assumptions changed

## Validation Commands

- Headless startup:
  - `& 'E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'E:\Code\open_pvz' --quit-after 3`
- Default single validation run:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1'`
- Minimal battle validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/minimal_battle_validation.tres'`
- Long-range parabola validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/parabola_long_range_validation.tres'`
- Height-hit validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/height_hit_validation.tres'`
- Lane-isolation validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/lane_isolation_validation.tres'`
- Target-acquisition validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/target_acquisition_validation.tres'`
- Batch validation:
  - `& 'E:\Code\open_pvz\tools\run_all_validations.ps1'`
- Validation manifest:
  - `E:\Code\open_pvz\tools\validation_scenarios.json`
- Validation artifacts:
  - single-run reports go to `E:\Code\open_pvz\artifacts\validation\<timestamp>_<run_label>\`
  - batch summaries go to `E:\Code\open_pvz\artifacts\validation\batch_<timestamp>\`

## Current Reality Checks

- The project is no longer in early backbone-only convergence; phase 4 has already landed.
- The current active direction is not "prepare for phase 4", but "execute phase 5 without destabilizing the shared runtime".
- `tools/validation_scenarios.json` currently contains 27 unique validation scenario IDs.
- The first-stage detection system is now part of the runtime:
  - `autoload/DetectionRegistry.gd`
  - `lane_forward`
  - `always`
  - `target_acquisition_validation`
