# Project Agent Notes

## Project Positioning

Treat this repository as an open PVZ-like rules engine project, not a one-off demo or a phase-task handoff repo.

The current project state is:

> Mechanic-first restructuring has completed its first three stages. `Placement` has now entered the same formalized coverage tier as the other 9 families. The active line is: keep `Archetype + Mechanic[]` as the only formal authoring path, continue closing the legacy layer, and keep content, mode, and validation growth synchronized.

That means the default priority order is:

1. backbone correctness
2. repeatable validation
3. protocol / resource / terminology consistency
4. legacy-scope tightening
5. formal content and extension growth on the shared runtime

Do not default to old "phase 4 / phase 5 / phase 6 task-list" language when describing the current mainline. Those documents are historical archive material unless a task explicitly requires historical tracing.

## Godot Paths

- Console: `E:\Code\open_pvz\Godot_v4.6.1-stable_win64_console.exe`
- GUI: `E:\Code\open_pvz\Godot_v4.6.1-stable_win64.exe`

## Default Read Order

Before doing substantial coding or documentation work in this repo, read these docs first:

1. `README.md`
2. `wiki/index.md`
3. `wiki/01-overview/23-当前阶段与实现路线.md`
4. `wiki/04-roadmap-reference/26-开发路线图.md`
5. `wiki/02-runtime-protocol/11-编译链与Mechanic系统.md`
6. `wiki/03-content-validation/32-验证矩阵.md`
7. `wiki/05-governance/29-文档规范与维护约定.md`
8. `wiki/05-governance/33-术语表.md`
9. `wiki/05-governance/37-历史归档与退役文档索引.md`
10. `wiki/decisions/README.md`

The wiki is physically organized by layer under:

- `wiki/01-overview`
- `wiki/02-runtime-protocol`
- `wiki/03-content-validation`
- `wiki/04-roadmap-reference`
- `wiki/05-governance`
- `wiki/decisions`

Historical phase material no longer belongs to the current wiki narrative. Use these locations instead:

- completed-stage and historical planning material: `plans/archive/`
- retired wiki pages: `plans/archive/wiki-retired/`
- future-direction drafts: `plans/draft/`

If you are entering for a specific task, use this shorter route:

- Project state and direction:
  - `wiki/index.md`
  - `wiki/01-overview/23-当前阶段与实现路线.md`
  - `wiki/04-roadmap-reference/26-开发路线图.md`
  - `wiki/01-overview/34-Open PVZ 系统版图与规划分层.md`
- Runtime / protocol work:
  - `wiki/01-overview/00-架构总览.md`
  - `wiki/02-runtime-protocol/03-触发器系统.md`
  - `wiki/02-runtime-protocol/04-效果系统.md`
  - `wiki/02-runtime-protocol/06-执行机制.md`
  - `wiki/02-runtime-protocol/07-事件模型.md`
  - `wiki/02-runtime-protocol/08-连续行为模型.md`
  - `wiki/02-runtime-protocol/11-编译链与Mechanic系统.md`
- Validation / workflow work:
  - `wiki/03-content-validation/12-完整工作流.md`
  - `wiki/03-content-validation/15-验证清单.md`
  - `wiki/03-content-validation/32-验证矩阵.md`
- Documentation / governance work:
  - `wiki/05-governance/27-项目开发方法论.md`
  - `wiki/05-governance/29-文档规范与维护约定.md`
  - `wiki/05-governance/31-重大决策记录模板.md`
  - `wiki/05-governance/33-术语表.md`
  - `wiki/05-governance/35-模板编写约定.md`
  - `wiki/05-governance/36-原版实体复刻工作流.md`
  - `wiki/05-governance/37-历史归档与退役文档索引.md`

`wiki/05-governance/29-文档规范与维护约定.md` is the default governance source of truth if there is ambiguity about workflow, terminology, wiki structure, archive placement, or what docs must be updated together.

## Working Rules

When making engine, runtime, validation, protocol, content, or documentation changes in this repo:

- Define the problem at the right layer first: concept, protocol, implementation, validation, content, or documentation governance.
- Do not patch a visible symptom into the backbone if the issue is really a missing abstraction or an uncaptured boundary.
- Keep backbone work, content work, showcase work, and archive work separate. A showcase-only success is not backbone completion.
- Treat `CombatArchetype + CombatMechanic[]` as the only formal top-level authoring path.
- Treat `EntityTemplate / TriggerBinding` as legacy-only terms:
  - compatibility layer
  - backend resource layer
  - migration parity layer
- Do not describe `EntityTemplate / TriggerBinding` as the formal authoring path in code comments, docs, or task summaries.
- Keep terminology aligned with `wiki/05-governance/33-术语表.md` so concept names do not drift across docs, resources, and code.
- Prefer explicit Resource-based configuration over long-lived bare dictionaries.
- Add or update validation coverage when changing core behavior. A backbone change is not complete if it only "looks right" in one scene.
- When adding or changing a validation scenario, update all relevant layers in the same pass:
  - the `.tres` scenario resource under `scenes/validation/`
  - `tools/validation_scenarios.json` if the scenario should join batch automation
  - `wiki/03-content-validation/32-验证矩阵.md`
  - `agent.md` if default validation guidance or repo-state assumptions changed
- Use logs and repeatable validation as the standard for correctness, not visual intuition alone.
- When a new abstraction is introduced, identify what older logic must migrate with it so mixed models do not remain silently active.
- If a change affects world model, protocol boundaries, validation exits, migration strategy, extension boundaries, or other system-level assumptions, create or update a decision record using `wiki/05-governance/31-重大决策记录模板.md`.
- If a change affects project assumptions, protocol boundaries, validation rules, terminology, or documentation structure, update the relevant wiki docs in the same pass.
- If a wiki page becomes mainly historical, retired, or superseded by ADR-backed current docs, move it out of `wiki/`:
  - to `plans/archive/wiki-retired/` if it is historical / superseded
  - to `plans/draft/` if it is still a future-direction draft
- After any new ADR is completed, also update at least:
  - one current-state or route page
  - one runtime / validation / governance page

## Practical Checklist

Before major changes:

- Clarify goal
- Clarify non-goals
- Clarify acceptance criteria
- Identify migration scope
- Identify the target layer: concept, protocol, implementation, validation, content, or governance
- Decide which validation scenario proves the change
- Decide whether the change requires:
  - wiki state / route updates
  - validation-matrix updates
  - an ADR-style decision record
  - archive / retired-doc handling

After major changes:

- Run headless Godot startup when the change affects runtime boot or project integrity
- Run the relevant validation scenario(s)
- Register new validation scenarios in `tools/validation_scenarios.json` if they belong in batch runs
- Update `wiki/03-content-validation/32-验证矩阵.md` if validation coverage changed
- Update current-state docs if project assumptions changed:
  - `wiki/index.md`
  - `wiki/01-overview/23-当前阶段与实现路线.md`
  - `wiki/04-roadmap-reference/26-开发路线图.md`
- Update archive indexes if pages were retired or moved to draft:
  - `wiki/05-governance/37-历史归档与退役文档索引.md`
- Check logs if behavior is spatial, event-driven, or timing-sensitive
- Update `README.md` or `agent.md` if default repo-state guidance changed

## Validation Commands

- Headless startup:
  - `& 'E:\Code\open_pvz\Godot_v4.6.1-stable_win64_console.exe' --headless --path 'E:\Code\open_pvz' --quit-after 3`
- Default single validation run:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1'`
- Minimal battle validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/minimal_battle_validation.tres'`
- Full-chain compile validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/full_chain_compile_validation.tres'`
- Placement compile validation:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/placement_compile_validation.tres'`
- Migration parity examples:
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/peashooter_migration_parity_validation.tres'`
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/sunflower_migration_parity_validation.tres'`
  - `& 'E:\Code\open_pvz\tools\run_validation.ps1' -Scenario 'res://scenes/validation/zombie_migration_parity_validation.tres'`
- Batch validation:
  - `& 'E:\Code\open_pvz\tools\run_all_validations.ps1'`
- Validation manifest:
  - `E:\Code\open_pvz\tools\validation_scenarios.json`
- Validation artifacts:
  - single-run reports go to `E:\Code\open_pvz\artifacts\validation\<timestamp>_<run_label>\`
  - batch summaries go to `E:\Code\open_pvz\artifacts\validation\batch_<timestamp>\`

## Current Reality Checks

- The repository is no longer in the old "phase 5 chaos-tech mainline" framing.
- The current formal mainline is Mechanic-first post-stage-3 consolidation.
- `tools/validation_scenarios.json` currently contains `87` validation scenarios.
- Current validation layer-tag counts are:
  - `smoke = 9`
  - `core = 67`
  - `extension = 10`
  - `guardrail = 10`
  - `migration = 3`
- `data/combat/archetypes/` currently contains `51` archetypes:
  - `39` plants
  - `10` zombies
  - `2` field objects
- The 10 Mechanic families are frozen, and current documentation now treats `Placement` as having reached the same first-round formal closure tier as the other 9 families.
- `48` current archetypes still carry `backend_entity_template*` fields, so the legacy layer still exists physically even though the first backend-free archetype batch has been detached.

## Documentation Reality Checks

- `wiki/index.md` is the current wiki entrypoint, not a phase-handoff index.
- `wiki/01-overview/23-当前阶段与实现路线.md` is the only state snapshot page.
- `wiki/04-roadmap-reference/26-开发路线图.md` is the only route / forward-priority page.
- `wiki/decisions/` remains the raw decision-record area and is not merged into current narrative pages.
- `wiki/05-governance/37-历史归档与退役文档索引.md` is the only current wiki entrypoint to archive / retired / draft material.

## Archive / Draft Locations

- Historical stage material: `E:\Code\open_pvz\plans\archive\`
- Retired wiki pages: `E:\Code\open_pvz\plans\archive\wiki-retired\`
- Future-direction wiki drafts: `E:\Code\open_pvz\plans\draft\`
