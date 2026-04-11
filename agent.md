# Project Agent Notes

## Project Positioning

Treat this repository as an open PVZ-like rules engine project, not a one-off demo. The current phase is:

> backbone stabilization is largely in place, validation is part of the core workflow, and the project is moving toward content-template readiness rather than broad content expansion.

That means the default priority order is:

1. backbone correctness
2. repeatable validation
3. protocol/resource cleanup
4. content/template expansion

## Godot Paths

- Console: `E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe`
- GUI: `E:\SDK\Godot\Godot_v4.6.1-stable_win64.exe`

## Default Read Order

Before doing substantial coding or "vibe coding" in this repo, read these docs first:

1. `wiki/index.md`
2. `wiki/01-overview/34-Open PVZ 系统版图与规划分层.md`
3. `wiki/01-overview/23-当前阶段与实现路线.md`
4. `wiki/04-roadmap-reference/26-开发路线图.md`
5. `wiki/03-content-validation/32-验证矩阵.md`
6. `wiki/05-governance/27-项目开发方法论.md`
7. `wiki/05-governance/28-Wiki审查与规范化建议.md`
8. `wiki/05-governance/29-文档规范与维护约定.md`
9. `wiki/05-governance/31-重大决策记录模板.md`
10. `wiki/05-governance/33-术语表.md`

The wiki is physically organized by layer under `01-overview`, `02-runtime-protocol`, `03-content-validation`, `04-roadmap-reference`, and `05-governance`.

If you are entering for a specific task, use this shorter route:

- Project direction and planning:
  - `wiki/01-overview/34-Open PVZ 系统版图与规划分层.md`
  - `wiki/01-overview/23-当前阶段与实现路线.md`
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
  - `wiki/05-governance/28-Wiki审查与规范化建议.md`
  - `wiki/05-governance/29-文档规范与维护约定.md`
  - `wiki/05-governance/31-重大决策记录模板.md`
  - `wiki/05-governance/33-术语表.md`

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
- Use logs and repeatable validation as the standard for correctness, not visual intuition alone.
- When a new abstraction is introduced, identify what older logic must migrate with it so mixed models do not remain in the codebase.
- If a change affects world model, protocol boundaries, validation exits, migration strategy, or other system-level assumptions, create or update a decision record using `wiki/05-governance/31-重大决策记录模板.md`.
- If a change affects project assumptions, protocol boundaries, validation rules, terminology, or documentation structure, update the relevant wiki docs in the same pass.

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
- Batch validation:
  - `& 'E:\Code\open_pvz\tools\run_all_validations.ps1'`
- Validation manifest:
  - `E:\Code\open_pvz\tools\validation_scenarios.json`
- Validation artifacts:
  - single-run reports go to `E:\Code\open_pvz\artifacts\validation\<timestamp>_<run_label>\`
  - batch summaries go to `E:\Code\open_pvz\artifacts\validation\batch_<timestamp>\`
