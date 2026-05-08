# Legacy 兼容层收口 + RuntimeTriggerSpec 引入

## TL;DR

> **Quick Summary**: 一次性移除 legacy 兼容层残余，统一实体身份为 `archetype_id`，并用 `RuntimeTriggerSpec` 替换 `TriggerBinding` 作为编译链中间体。
> 
> **Deliverables**:
> - 新增 `RuntimeTriggerSpec` RefCounted 类，替换编译链中 TriggerBinding 的角色
> - 删除 `entity_template.gd` 死类
> - 从 CombatArchetype / RuntimeSpec 中删除 `legacy_template_id` 字段
> - 所有事件核心值从 `*_template_id` 迁移到 `*_archetype_id`
> - 95 个 archetype .tres 中删除 `legacy_template_id` 行
> - 56 个验证 .tres 中更新 `required_core_values` 键名
> - 105/105 验证场景全通过
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Task 1 → Task 5 → Task 6 → Task 7 → Task 8 → Task 9 → FINAL

---

## Context

### Original Request

用户要求讨论如何收口 legacy 兼容层，彻底将其去掉。经过深入分析后确认要做两件事：
1. 将 `legacy_template_id` 身份别名全部迁移到 `archetype_id`
2. 引入 `RuntimeTriggerSpec` 替换 `TriggerBinding` 作为编译中间体

### Interview Summary

**Key Discussions**:
- 所有 95 个 archetype 已完成 backend-free 脱钩（数据层已干净）
- `entity_template.gd` 是死代码，唯一消费者是 protocol_validator 用来拒绝它
- `TriggerBinding` 已被收编为编译中间体，但名字误导且带 3 个死字段
- Controller/State 编译产物用 Dictionary，Trigger 编译产物用 Resource — 结构不一致
- 路线 B（身份迁移）+ 路线 C（编译中间体重写）合并执行

**Research Findings**:
- 事件系统同时携带 `*_archetype_id` 和 `*_template_id`，验证规则检查两者
- 56/96 验证 .tres 文件中有 207 处 `*_template_id` 引用
- `card_place_validation.gd` 已有 `archetype_id` fallback 逻辑
- `ProjectileTemplate.template_id` 是投射体身份，与实体 template_id 无关 — 不迁移
- `battle_flow_state.protected_template_id` 用于败北条件检测 — 需迁移

### Self-Analysis (Metis unavailable — manual gap analysis)

**Identified Gaps** (addressed):
- RuntimeTriggerSpec 需要同时支持 TriggerBinding 的所有有效字段 → 设计中只保留有效字段
- `entity.template_id` 属性被广泛读取（`entity.get("template_id")`）→ 需在 entity 基类中统一改为 archetype_id
- `trigger_instance.gd:_extract_template_id()` 方法 → 需删除或改为 _extract_archetype_id
- 验证 .tres 文件中 `target_template_id` 的值需要从 template 名映射到 archetype_id → 值映射清单已确认
- `battle_scenario.protected_template_id` 字段 → 改为 `protected_archetype_id`

---

## Work Objectives

### Core Objective

彻底清除 legacy 兼容层，使 `archetype_id` 成为实体唯一身份标识，使 `RuntimeTriggerSpec` 成为编译链唯一触发器中间体。

### Concrete Deliverables

- `scripts/core/runtime/runtime_trigger_spec.gd` — 新的编译中间体类
- 删除 `scripts/core/defs/entity_template.gd`
- `legacy_template_id` 字段从 CombatArchetype、RuntimeSpec、BattleModeInputRequest 中移除
- `entity.template_id` 属性全部改为 `entity.archetype_id`
- 95 个 archetype .tres 中 `legacy_template_id` 行删除
- 56 个验证 .tres 中 `required_core_values` 键名从 `*_template_id` 改为 `*_archetype_id`
- 105/105 验证场景通过

### Definition of Done

- [ ] `pwsh tools/run_all_validations.ps1` → 105/105 PASS
- [ ] 全仓库搜索 `legacy_template_id` → 0 匹配（排除 archive）
- [ ] 全仓库搜索 `backend_entity_template` → 仅在 archive 中
- [ ] `entity_template.gd` 文件已删除
- [ ] `TriggerBinding` 不再被 `mechanic_compiler.gd` 或 `entity_factory.gd` import

### Must Have

- 所有 105 个验证场景回归通过
- `archetype_id` 成为事件系统中实体的唯一身份字段
- `RuntimeTriggerSpec` 替换 TriggerBinding 成为 MechanicCompiler 的唯一编译输出格式
- 编译链输出结构一致：Trigger/Controller/State 三种 spec 同构

### Must NOT Have (Guardrails)

- **不得修改 `ProjectileTemplate.template_id`** — 这是投射体身份，与实体无关
- **不得修改 `trigger_binding.gd` 文件本身** — 保留给 archive 兼容，只移除运行时使用
- **不得修改 vendor/ 目录** — 参考实现不属于引擎
- **不得新增 Mechanic family 或修改冻结协议** — 这不是架构扩展
- **不得在本次工作中添加新内容（植物/僵尸/关卡）** — 纯收口工作
- **不得改变验证规则的业务语义** — 只做键名迁移，不改匹配逻辑
- **不得引入新的 @export 字段到 CombatArchetype** — 是删除，不是添加

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (validation scenarios)
- **Automated tests**: None (no unit test framework)
- **Framework**: Validation scenarios via `pwsh tools/run_all_validations.ps1`
- **Total scenarios**: 105

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Core engine**: Use Bash (Godot headless validation) — Run validation scenarios, check JSON reports
- **Data files**: Use Bash (grep/Select-String) — Verify field removal, verify no orphaned references

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — foundation):
├── Task 1: Create RuntimeTriggerSpec class [quick]
├── Task 2: Delete entity_template.gd + clean protocol_validator guards [quick]
└── Task 3: Remove legacy_template_id from CombatArchetype + RuntimeSpec + BattleModeInputRequest defs [quick]

Wave 2 (After Wave 1 — core code migration):
├── Task 4: MechanicCompiler: replace TriggerBinding → RuntimeTriggerSpec output [deep]
├── Task 5: EntityFactory: consume RuntimeTriggerSpec, remove entity.template_id writes [deep]
├── Task 6: Event system: migrate *_template_id → *_archetype_id in all battle scripts [unspecified-high]
├── Task 7: BattleModeHost + BattleFlowState: migrate template_id lookups [quick]
└── Task 8: Protocol validator: update TriggerBinding validation → RuntimeTriggerSpec [quick]

Wave 3 (After Wave 2 — data migration):
├── Task 9: Remove legacy_template_id from all 95 archetype .tres files [unspecified-high]
├── Task 10: Update 56 validation .tres files: rename required_core_values keys [unspecified-high]
├── Task 11: Update card_place_validation.gd: simplify legacy fallback [quick]
└── Task 12: Update wiki docs: current stage description [writing]

Wave 4 (After Wave 3 — verification + cleanup):
├── Task 13: Full regression: 105/105 validation scenarios [unspecified-high]
└── Task 14: Cleanup: update CLAUDE.md / AGENTS.md module docs [quick]

Wave FINAL (After ALL tasks — 4 parallel reviews):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Real manual QA [unspecified-high]
└── Task F4: Scope fidelity check [deep]
→ Present results → Get explicit user okay

Critical Path: Task 1 → Task 4 → Task 5 → Task 9 → Task 10 → Task 13 → FINAL
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 5 (Wave 2)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 | — | 4, 5 | 1 |
| 2 | — | 8 | 1 |
| 3 | — | 4, 5, 6, 7 | 1 |
| 4 | 1, 3 | 5, 8 | 2 |
| 5 | 1, 3, 4 | 6, 9 | 2 |
| 6 | 3 | 9, 10 | 2 |
| 7 | 3 | 9, 10 | 2 |
| 8 | 2, 4 | 13 | 2 |
| 9 | 5, 6, 7 | 13 | 3 |
| 10 | 6, 7 | 13 | 3 |
| 11 | 5, 6 | 13 | 3 |
| 12 | — | — | 3 |
| 13 | 8, 9, 10, 11 | FINAL | 4 |
| 14 | 13 | FINAL | 4 |
| F1-F4 | 13, 14 | — | FINAL |

### Agent Dispatch Summary

- **Wave 1**: 3 tasks — T1 → `quick`, T2 → `quick`, T3 → `quick`
- **Wave 2**: 5 tasks — T4 → `deep`, T5 → `deep`, T6 → `unspecified-high`, T7 → `quick`, T8 → `quick`
- **Wave 3**: 4 tasks — T9 → `unspecified-high`, T10 → `unspecified-high`, T11 → `quick`, T12 → `writing`
- **Wave 4**: 2 tasks — T13 → `unspecified-high`, T14 → `quick`
- **FINAL**: 4 tasks — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 1. 创建 RuntimeTriggerSpec 类

  **What to do**:
  - 创建 `scripts/core/runtime/runtime_trigger_spec.gd`，继承 `RefCounted`
  - 只包含 TriggerBinding 的有效字段（去掉 `binding_id`、`behavior_key`、`enabled` 三个死字段）
  - 有效字段：`trigger_id: StringName`、`event_name: StringName`、`condition_values: Dictionary`、`effect_id: StringName`、`effect_params: Dictionary`、`on_hit_effect: Dictionary`（嵌套结构，替代扁平的 on_hit_effect_id + on_hit_effect_params）、`projectile_template: Resource`
  - `on_hit_effect` 结构：`{ "effect_id": StringName, "effect_params": Dictionary }`
  - 不继承 Resource，不使用 @export — 这是纯编译中间体

  **Must NOT do**:
  - 不要删除或修改 `trigger_binding.gd` 文件
  - 不要使用 @export 或 extends Resource
  - 不要在此任务中修改 mechanic_compiler 或 entity_factory

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 单文件创建，结构明确，无依赖
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `scripts/core/runtime/runtime_spec.gd` — 看它的 RefCounted 模式（extends RefCounted, var 字段声明）
  - `scripts/core/defs/trigger_binding.gd` — 当前 TriggerBinding 的字段定义，理解哪些字段有效

  **API/Type References**:
  - `scripts/core/runtime/mechanic_compiler.gd:308-346` — `_build_binding_from_mechanics()` 看 TriggerBinding 的哪些字段被赋值
  - `scripts/battle/entity_factory.gd:378-432` — `_build_triggers_from_bindings()` 看哪些字段被读取

  **WHY Each Reference Matters**:
  - runtime_spec.gd: 理解 RefCounted 中间体的声明风格
  - trigger_binding.gd: 对比新旧结构，确认死字段有哪些
  - mechanic_compiler:316: 确认编译器实际写入了哪些字段
  - entity_factory:386-432: 确认工厂实际读取了哪些字段

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: RuntimeTriggerSpec 类文件存在且结构正确
    Tool: Bash
    Preconditions: 文件已创建
    Steps:
      1. 检查 Test-Path "scripts/core/runtime/runtime_trigger_spec.gd" → True
      2. 检查文件内容包含 "class_name RuntimeTriggerSpec"
      3. 检查文件内容包含 "extends RefCounted"
      4. 检查文件内容包含 "var trigger_id: StringName"
      5. 检查文件内容包含 "var on_hit_effect: Dictionary"
      6. 检查文件内容 NOT 包含 "binding_id"
      7. 检查文件内容 NOT 包含 "behavior_key"
      8. 检查文件内容 NOT 包含 "@export"
    Expected Result: 文件存在，extends RefCounted，有 trigger_id/event_name/condition_values/effect_id/effect_params/on_hit_effect/projectile_template，无死字段
    Failure Indicators: 文件不存在，包含 binding_id 或 @export
    Evidence: .sisyphus/evidence/task-1-spec-created.txt

  Scenario: RuntimeTriggerSpec 不被任何运行时代码引用（Wave 1 只创建不接入）
    Tool: Bash
    Preconditions: 文件已创建
    Steps:
      1. 搜索 scripts/ 中除 runtime_trigger_spec.gd 本身外引用 RuntimeTriggerSpec 的文件 → 应为 0
    Expected Result: 无运行时引用
    Evidence: .sisyphus/evidence/task-1-no-runtime-refs.txt
  ```

  **Commit**: YES (groups with 2, 3)
  - Message: `refactor(core): remove entity_template, add RuntimeTriggerSpec, remove legacy_template_id defs`
  - Files: `scripts/core/runtime/runtime_trigger_spec.gd`
  - Pre-commit: 无（此阶段尚不接入运行时）

- [ ] 2. 删除 entity_template.gd + 清理 protocol_validator 守卫

  **What to do**:
  - 删除 `scripts/core/defs/entity_template.gd`
  - 在 `protocol_validator.gd` 中移除 `validate_entity_template` 方法中对 EntityTemplate 的检测和拒绝逻辑（L452-454 区域）
  - 移除 protocol_validator 中对 EntityTemplate 类的 preload（如果有）
  - 移除 `validate_combat_archetype` 中对 `backend_entity_template` / `backend_entity_template_id` 的退休守卫（L337-341 区域），因为数据层已完全干净

  **Must NOT do**:
  - 不要修改 `trigger_binding.gd`
  - 不要修改 `combat_archetype.gd`（Task 3 负责）
  - 不要删除 archive 中的 entity_template .tres 文件

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 单文件删除 + 临近代码清理，逻辑简单
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 8
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `scripts/core/defs/entity_template.gd` — 要删除的文件，确认只有 24 行且无其他文件运行时依赖
  - `scripts/core/runtime/protocol_validator.gd:337-341` — backend_entity_template 退休守卫
  - `scripts/core/runtime/protocol_validator.gd:452-454` — EntityTemplate 退休守卫

  **WHY Each Reference Matters**:
  - entity_template.gd: 确认删除安全性
  - protocol_validator:337-341: 这些守卫现在已无意义（数据层完全干净），可以移除
  - protocol_validator:452-454: EntityTemplate 类删除后，这些检测也无法工作，需同步移除

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: entity_template.gd 已删除
    Tool: Bash
    Steps:
      1. Test-Path "scripts/core/defs/entity_template.gd" → False
    Expected Result: 文件不存在
    Evidence: .sisyphus/evidence/task-2-deleted.txt

  Scenario: protocol_validator 中无 EntityTemplate 引用
    Tool: Bash
    Steps:
      1. 搜索 protocol_validator.gd 中 "EntityTemplate" → 0 匹配
      2. 搜索 protocol_validator.gd 中 "backend_entity_template" → 0 匹配
    Expected Result: 守卫代码已清理
    Evidence: .sisyphus/evidence/task-2-validator-clean.txt
  ```

  **Commit**: YES (groups with 1, 3)
  - Message: (同 Task 1 commit)
  - Files: `scripts/core/defs/entity_template.gd` (deleted), `scripts/core/runtime/protocol_validator.gd`

- [ ] 3. 从类型定义中移除 legacy_template_id 字段

  **What to do**:
  - `scripts/core/defs/combat_archetype.gd` — 删除 `@export var legacy_template_id: StringName` 行
  - `scripts/core/runtime/runtime_spec.gd` — 删除 `var legacy_template_id: StringName` 行
  - `scripts/battle/mode/battle_mode_input_request.gd` — 删除 `@export var legacy_template_id: StringName` 行
  - 注意：这只是字段定义删除。消费者（mechanic_compiler、entity_factory 等）的迁移在 Task 4-7 中进行

  **Must NOT do**:
  - 不要修改消费者代码（Task 4-7 负责）
  - 不要修改 .tres 数据文件（Task 9 负责）
  - 不要删除 `trigger_binding.gd`

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 3 个文件各删 1 行
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Tasks 4, 5, 6, 7
  - **Blocked By**: None

  **References**:

  **API/Type References**:
  - `scripts/core/defs/combat_archetype.gd:6` — `@export var legacy_template_id: StringName`
  - `scripts/core/runtime/runtime_spec.gd:6` — `var legacy_template_id: StringName`
  - `scripts/battle/mode/battle_mode_input_request.gd:9` — `@export var legacy_template_id: StringName`

  **WHY Each Reference Matters**:
  - 这三个是 legacy_template_id 的唯一定义点，删除后消费者必须在 Wave 2 中迁移

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: 三个文件中 legacy_template_id 字段已删除
    Tool: Bash
    Steps:
      1. 搜索 combat_archetype.gd 中 "legacy_template_id" → 0 匹配
      2. 搜索 runtime_spec.gd 中 "legacy_template_id" → 0 匹配
      3. 搜索 battle_mode_input_request.gd 中 "legacy_template_id" → 0 匹配
    Expected Result: 三个定义已清除
    Evidence: .sisyphus/evidence/task-3-defs-removed.txt
  ```

  **Commit**: YES (groups with 1, 2)
  - Message: (同 Task 1 commit)
  - Files: `scripts/core/defs/combat_archetype.gd`, `scripts/core/runtime/runtime_spec.gd`, `scripts/battle/mode/battle_mode_input_request.gd`

- [ ] 4. MechanicCompiler: 替换 TriggerBinding → RuntimeTriggerSpec 输出

  **What to do**:
  - 修改 `scripts/core/runtime/mechanic_compiler.gd`
  - 添加 `const RuntimeTriggerSpecRef = preload("res://scripts/core/runtime/runtime_trigger_spec.gd")`
  - 在 `_build_binding_from_mechanics()` 中将 `TriggerBindingRef.new()` 替换为 `RuntimeTriggerSpecRef.new()`
  - 将 `binding.binding_id = ...` 行删除（RuntimeTriggerSpec 无此字段）
  - 将 `binding.behavior_key = ...` 行删除（RuntimeTriggerSpec 无此字段）
  - 将 `binding.on_hit_effect_id` 和 `binding.on_hit_effect_params` 合并为 `binding.on_hit_effect = { "effect_id": ..., "effect_params": ... }`
  - 其余字段赋值（trigger_id, event_name, condition_values, effect_id, effect_params, projectile_template）保持不变
  - 在 `_inject_targeting` / `_inject_trajectory` / `_inject_hit_policy` / `_inject_emission` 中，参数注入逻辑不变（仍是操作 binding.condition_values 和 binding.effect_params）
  - 删除 `const TriggerBindingRef = preload(...)` 行（不再需要）
  - 删除 `runtime_spec.legacy_template_id = archetype.legacy_template_id` 行

  **Must NOT do**:
  - 不要修改 `entity_factory.gd`（Task 5 负责）
  - 不要修改 `trigger_binding.gd`
  - 不要修改 .tres 文件

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: mechanic_compiler.gd 是 1231 行的核心编译器，需要精确修改 ~30 处引用，理解编译逻辑
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Task 1 and 3)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 5, 8
  - **Blocked By**: Tasks 1, 3

  **References**:

  **Pattern References**:
  - `scripts/core/runtime/runtime_trigger_spec.gd` — 新类结构（Task 1 产物）
  - `scripts/core/runtime/mechanic_compiler.gd:308-346` — `_build_binding_from_mechanics()` 当前实现

  **API/Type References**:
  - `scripts/core/runtime/mechanic_compiler.gd:8` — `const TriggerBindingRef = preload(...)` 要替换
  - `scripts/core/runtime/mechanic_compiler.gd:316` — `TriggerBindingRef.new()` 要替换
  - `scripts/core/runtime/mechanic_compiler.gd:317-321` — binding_id, behavior_key 赋值要删除
  - `scripts/core/runtime/mechanic_compiler.gd:339-344` — on_hit 字段要合并

  **Test References**:
  - `scenes/validation/full_chain_compile_validation.tres` — 完整编译链验证
  - `scenes/validation/targeting_compile_validation.tres` — targeting 注入验证
  - `scenes/validation/emission_burst_compile_validation.tres` — emission 注入验证

  **WHY Each Reference Matters**:
  - mechanic_compiler:308-346: 这是需要修改的核心函数，必须逐行理解哪些赋值保留、哪些删除、哪些改格式
  - runtime_trigger_spec.gd: 确认新类的字段名和类型，确保赋值匹配
  - 编译链验证场景: 修改后必须通过的测试

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: MechanicCompiler 不再引用 TriggerBindingRef
    Tool: Bash
    Steps:
      1. 搜索 mechanic_compiler.gd 中 "TriggerBindingRef" → 0 匹配
      2. 搜索 mechanic_compiler.gd 中 "TriggerBinding" → 0 匹配
      3. 搜索 mechanic_compiler.gd 中 "RuntimeTriggerSpecRef" → ≥1 匹配
      4. 搜索 mechanic_compiler.gd 中 "binding_id" → 0 匹配
      5. 搜索 mechanic_compiler.gd 中 "behavior_key" → 仅在 _map_trigger_type 的返回值中有 "behavior_key" 键（这是映射字典，不是字段赋值），确认无 binding.behavior_key 赋值
    Expected Result: 编译器已完全切换到 RuntimeTriggerSpec
    Evidence: .sisyphus/evidence/task-4-compiler-migrated.txt

  Scenario: 编译链验证场景通过
    Tool: Bash
    Preconditions: Task 5 (EntityFactory) 也已完成
    Steps:
      1. pwsh tools/run_validation.ps1 -ScenarioId full_chain_compile_validation
      2. pwsh tools/run_validation.ps1 -ScenarioId targeting_compile_validation
      3. pwsh tools/run_validation.ps1 -ScenarioId emission_burst_compile_validation
    Expected Result: 所有编译链场景通过
    Failure Indicators: 任何验证失败
    Evidence: .sisyphus/evidence/task-4-compile-chain-pass.txt
  ```

  **Commit**: YES (groups with 5)
  - Message: `refactor(compile): replace TriggerBinding with RuntimeTriggerSpec in compilation chain`
  - Files: `scripts/core/runtime/mechanic_compiler.gd`

- [ ] 5. EntityFactory: 消费 RuntimeTriggerSpec，移除 entity.template_id 写入

  **What to do**:
  - 修改 `scripts/battle/entity_factory.gd`
  - 将 `const TriggerBindingRef = preload("res://scripts/core/defs/trigger_binding.gd")` 替换为 `const RuntimeTriggerSpecRef = preload("res://scripts/core/runtime/runtime_trigger_spec.gd")`
  - 在 `_build_triggers_from_bindings()` 中：
    - 将 `binding is TriggerBindingRef` 检查改为 `binding is RuntimeTriggerSpecRef`（或检查字段存在性）
    - `binding.trigger_id` → 不变
    - `binding.event_name` → 不变
    - `binding.condition_values` → 不变
    - `binding.effect_id` → 不变
    - `binding.effect_params` → 不变
    - `binding.on_hit_effect_id` → 改为 `binding.on_hit_effect.get("effect_id", &"damage")`
    - `binding.on_hit_effect_params` → 改为 `binding.on_hit_effect.get("effect_params", {})`
    - `binding.projectile_template` → 不变
    - 删除 `binding.enabled` 检查（RuntimeTriggerSpec 无此字段，编译时已过滤）
  - 在 `_instantiate_runtime_spec()` 中：
    - 删除 `runtime_spec.legacy_template_id` 读取和 `entity.set("template_id", ...)` 写入（L95-98）
    - 保留 `runtime_spec.source_archetype_id` → `entity.set("archetype_id", ...)` 逻辑
  - 在 `_apply_template_metadata()` 中：
    - 删除 `template.legacy_template_id` 读取和 `entity.set("template_id", ...)` 写入（L364-365）
    - 删除 `entity.call("set_state_value", &"legacy_template_id", ...)` 写入（L368）
  - 在 `_instantiate_field_object()` 中：
    - 将 `match StringName(template.legacy_template_id)` 改为 `match StringName(template.archetype_id)`，并更新匹配值（如 `&"archetype_lawn_mower"` → 但需确认 archetype_id 值）
  - 在 `_make_minimal_archetype_for_root()` 中：
    - 删除 `archetype.legacy_template_id = runtime_spec.legacy_template_id`（L612）

  **Must NOT do**:
  - 不要删除 `trigger_binding.gd` 文件
  - 不要修改 .tres 文件
  - 不要修改其他 battle 脚本（Task 6-7 负责）

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: entity_factory.gd 是 642 行的核心工厂，需要精确修改 ~15 处引用
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Tasks 1, 3, 4)
  - **Parallel Group**: Wave 2 (after Task 4)
  - **Blocks**: Tasks 6, 9
  - **Blocked By**: Tasks 1, 3, 4

  **References**:

  **Pattern References**:
  - `scripts/core/runtime/runtime_trigger_spec.gd` — 新类结构
  - `scripts/battle/entity_factory.gd:378-432` — `_build_triggers_from_bindings()` 当前实现

  **API/Type References**:
  - `scripts/battle/entity_factory.gd:20` — `const TriggerBindingRef = preload(...)` 要替换
  - `scripts/battle/entity_factory.gd:387` — `binding is TriggerBindingRef` 要替换
  - `scripts/battle/entity_factory.gd:418` — `binding is TriggerBindingRef` 要替换
  - `scripts/battle/entity_factory.gd:95-98` — legacy_template_id 写入要删除
  - `scripts/battle/entity_factory.gd:364-368` — legacy_template_id 写入要删除
  - `scripts/battle/entity_factory.gd:199-203` — field_object 路由要迁移

  **WHY Each Reference Matters**:
  - L378-432: 核心消费逻辑，理解 TriggerBinding 的每个字段如何被读取
  - L95-98, L364-368: entity.template_id 的写入点，删除后实体不再有 template_id
  - L199-203: field_object 按 legacy_template_id 路由到 LawnMower，需要改为 archetype_id

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: EntityFactory 不再引用 TriggerBindingRef 或 legacy_template_id
    Tool: Bash
    Steps:
      1. 搜索 entity_factory.gd 中 "TriggerBindingRef" → 0 匹配
      2. 搜索 entity_factory.gd 中 "legacy_template_id" → 0 匹配
      3. 搜索 entity_factory.gd 中 "RuntimeTriggerSpecRef" → ≥1 匹配
    Expected Result: 工厂已完全切换
    Evidence: .sisyphus/evidence/task-5-factory-migrated.txt

  Scenario: 实体实例化验证通过
    Tool: Bash
    Steps:
      1. pwsh tools/run_validation.ps1 -ScenarioId archetype_instantiation_validation
      2. pwsh tools/run_validation.ps1 -ScenarioId archetype_attack_validation
    Expected Result: PASS
    Evidence: .sisyphus/evidence/task-5-instantiation-pass.txt
  ```

  **Commit**: YES (groups with 4)
  - Message: (同 Task 4 commit)
  - Files: `scripts/battle/entity_factory.gd`

- [ ] 6. 事件系统: 迁移 *_template_id → *_archetype_id

  **What to do**:
  - 修改以下 battle 脚本，将所有事件 core value 中 `*_template_id` 替换为 `*_archetype_id`：
  - `scripts/battle/battle_board_state.gd`:
    - L61: `"template_id": StringName()` → `"archetype_id": StringName()`
    - L405: `core["%s_template_id" % prefix] = StringName(occupant.get("template_id"))` → `core["%s_archetype_id" % prefix] = StringName(occupant.get("archetype_id"))`
  - `scripts/battle/battle_card_state.gd`:
    - L59: `"template_id": StringName()` → `"archetype_id": StringName()`
  - `scripts/battle/battle_economy_state.gd`:
    - L56: `"template_id": StringName()` → `"archetype_id": StringName()`
  - `scripts/battle/battle_field_object_state.gd`:
    - L26: `"template_id": StringName()` → `"archetype_id": StringName()`
    - L83: `"object_template_id": StringName(entity.get("template_id"))` → `"object_archetype_id": StringName(entity.get("archetype_id"))`
    - L103: `spawned_event.core["object_template_id"]` → `spawned_event.core["object_archetype_id"]`
  - `scripts/battle/battle_spawner.gd`:
    - L208: `var legacy_template_id := StringName(entity.get("template_id"))` → 改为 `var spawned_archetype_id := StringName(entity.get("archetype_id"))`
    - L209-210: `legacy_template_id` → `spawned_archetype_id`，`spawned_event.core["legacy_template_id"]` → `spawned_event.core["archetype_id"]`
  - `scripts/battle/battle_status_state.gd`:
    - L31: `"template_id": StringName()` → `"archetype_id": StringName()`
    - L69: `applied_event.core["target_template_id"]` → `applied_event.core["target_archetype_id"]`
    - L90-97: `target_template_id` → `target_archetype_id`，`entity.get("template_id")` → `entity.get("archetype_id")`

  **Must NOT do**:
  - 不要修改 ProjectileTemplate 相关的 template_id
  - 不要修改 validation .tres 文件（Task 10 负责）
  - 不要修改 card_place_validation.gd（Task 11 负责）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 涉及 7 个文件的系统性替换，需要仔细检查每个替换点的上下文
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (can run alongside Task 7)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 9, 10
  - **Blocked By**: Task 3

  **References**:

  **API/Type References**:
  - `scripts/battle/battle_board_state.gd:405` — `core["%s_template_id" % prefix]` 写入
  - `scripts/battle/battle_spawner.gd:208-210` — `entity.get("template_id")` 读取
  - `scripts/battle/battle_field_object_state.gd:83,103` — `object_template_id` 写入
  - `scripts/battle/battle_status_state.gd:69,90-97` — `target_template_id` 使用

  **WHY Each Reference Matters**:
  - 每个替换点都需要确认：字段名从 `template_id` 改为 `archetype_id`，值来源从 `entity.get("template_id")` 改为 `entity.get("archetype_id")`

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: 事件系统代码中不再有 entity.get("template_id") 调用
    Tool: Bash
    Steps:
      1. 搜索 scripts/battle/ 下所有 .gd 文件中 'entity.get("template_id")' → 0 匹配
      2. 搜索 scripts/battle/ 下所有 .gd 文件中 '"template_id"' → 0 匹配（排除注释）
      3. 搜索 scripts/battle/ 下所有 .gd 文件中 'legacy_template_id' → 0 匹配
    Expected Result: 所有 template_id 引用已清除
    Evidence: .sisyphus/evidence/task-6-events-migrated.txt

  Scenario: 事件发射验证通过
    Tool: Bash
    Steps:
      1. pwsh tools/run_validation.ps1 -ScenarioId archetype_mower_runtime_validation
      2. pwsh tools/run_validation.ps1 -ScenarioId field_object_mower_validation
    Expected Result: PASS（field_object 场景验证 object_archetype_id 正确发射）
    Evidence: .sisyphus/evidence/task-6-events-pass.txt
  ```

  **Commit**: YES (groups with 7, 8)
  - Message: `refactor(battle): migrate event identity from template_id to archetype_id`
  - Files: `scripts/battle/battle_board_state.gd`, `scripts/battle/battle_card_state.gd`, `scripts/battle/battle_economy_state.gd`, `scripts/battle/battle_field_object_state.gd`, `scripts/battle/battle_spawner.gd`, `scripts/battle/battle_status_state.gd`

- [ ] 7. BattleModeHost + BattleFlowState: 迁移 template_id 查找

  **What to do**:
  - `scripts/battle/mode/battle_mode_host.gd`:
    - L335-337: `var legacy_template_id := StringName(input_request.get("legacy_template_id"))` → 改为 `var archetype_lookup_id := StringName(input_request.get("archetype_id"))`
    - `_latest_entity_id_by_template` 字典重命名为 `_latest_entity_id_by_archetype`
    - L366-370: 事件中的 `legacy_template_id` → `archetype_id`，`_latest_entity_id_by_template` → `_latest_entity_id_by_archetype`
  - `scripts/battle/battle_flow_state.gd`:
    - `protected_template_id` 字段 → `protected_archetype_id`
    - L30: `protected_template_id = scenario.get("protected_template_id")` → `protected_archetype_id = scenario.get("protected_archetype_id")`
    - L56: 事件 core 中的 `protected_template_id` → `protected_archetype_id`
  - `scripts/battle/battle_scenario.gd`:
    - `@export var protected_template_id` → `@export var protected_archetype_id`

  **Must NOT do**:
  - 不要修改 validation .tres 文件（Task 10 负责）
  - 不要修改 archetype .tres 文件（Task 9 负责）

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 3 个文件，各改 2-4 处变量名
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 6)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 9, 10
  - **Blocked By**: Task 3

  **References**:

  **API/Type References**:
  - `scripts/battle/mode/battle_mode_host.gd:335-370` — template_id 实体查找
  - `scripts/battle/battle_flow_state.gd:14,30,40,56` — protected_template_id 字段
  - `scripts/battle/battle_scenario.gd:27` — @export 字段定义

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: BattleModeHost 和 BattleFlowState 中无 template_id 引用
    Tool: Bash
    Steps:
      1. 搜索 battle_mode_host.gd 中 "template_id" → 0 匹配
      2. 搜索 battle_flow_state.gd 中 "template_id" → 0 匹配
      3. 搜索 battle_scenario.gd 中 "protected_template_id" → 0 匹配
      4. 搜索 battle_scenario.gd 中 "protected_archetype_id" → ≥1 匹配
    Expected Result: 所有 template_id 引用已迁移
    Evidence: .sisyphus/evidence/task-7-mode-migrated.txt

  Scenario: 模式层验证通过
    Tool: Bash
    Steps:
      1. pwsh tools/run_validation.ps1 -ScenarioId mode_basic_validation
      2. pwsh tools/run_validation.ps1 -ScenarioId mode_no_mode_guardrail
    Expected Result: PASS
    Evidence: .sisyphus/evidence/task-7-mode-pass.txt
  ```

  **Commit**: YES (groups with 6, 8)
  - Message: (同 Task 6 commit)
  - Files: `scripts/battle/mode/battle_mode_host.gd`, `scripts/battle/battle_flow_state.gd`, `scripts/battle/battle_scenario.gd`

- [ ] 8. Protocol Validator: 更新 TriggerBinding 验证 → RuntimeTriggerSpec

  **What to do**:
  - 修改 `scripts/core/runtime/protocol_validator.gd`
  - 替换所有 `TriggerBindingRef` preload 和引用
  - L9: `const TriggerBindingRef = preload(...)` → 替换为 RuntimeTriggerSpecRef
  - L395-445: `validate_trigger_binding` 方法中：
    - 将 `trigger_binding.get_script() != TriggerBindingRef` 检查改为 RuntimeTriggerSpecRef 检查
    - 将 `TriggerBinding.xxx must not be empty` 错误消息改为 `RuntimeTriggerSpec.xxx must not be empty`
    - 保持验证逻辑不变（trigger_id 非空、behavior_key → 移除、event_name → 保留等）
    - 移除对 `binding_id` 的验证（RuntimeTriggerSpec 无此字段）
    - 移除对 `behavior_key` 的验证（RuntimeTriggerSpec 无此字段）
    - 移除对 `enabled` 的验证（RuntimeTriggerSpec 无此字段）
    - `on_hit_effect_id` 和 `on_hit_effect_params` 的验证改为检查 `on_hit_effect` Dictionary
  - 移除 `validate_spawn_entry` 中对 `entity_template_id` 的拒绝检查（L797-803）
  - 移除 `validate_battle_scenario_cards` 中对 `entity_template_id` 的拒绝检查（L1055-1066）
  - 移除 `validate_battle_mode_input_request` 中对 `legacy_template_id` 的检查（L625-627），改为验证 archetype_id

  **Must NOT do**:
  - 不要删除 `trigger_binding.gd` 文件
  - 不要削弱验证严格度 — 只做字段名迁移

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 单文件，主要是替换字段名和类型检查
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Tasks 2, 4)
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 2, 4

  **References**:

  **API/Type References**:
  - `scripts/core/runtime/protocol_validator.gd:9` — TriggerBindingRef preload
  - `scripts/core/runtime/protocol_validator.gd:395-445` — validate_trigger_binding
  - `scripts/core/runtime/protocol_validator.gd:625-627` — input_request legacy_template_id 检查
  - `scripts/core/runtime/protocol_validator.gd:797-803` — spawn_entry entity_template_id 拒绝
  - `scripts/core/runtime/protocol_validator.gd:1055-1066` — card_def entity_template_id 拒绝

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: protocol_validator 中无 TriggerBindingRef 引用
    Tool: Bash
    Steps:
      1. 搜索 protocol_validator.gd 中 "TriggerBindingRef" → 0 匹配
      2. 搜索 protocol_validator.gd 中 "RuntimeTriggerSpecRef" → ≥1 匹配
      3. 搜索 protocol_validator.gd 中 "binding_id" → 0 匹配（非注释）
      4. 搜索 protocol_validator.gd 中 "behavior_key" → 仅在 FROZEN_TRIGGER_BEHAVIOR_SPECS 中保留（这是冻结协议常量）
    Expected Result: 验证器已切换到 RuntimeTriggerSpec
    Evidence: .sisyphus/evidence/task-8-validator-migrated.txt
  ```

  **Commit**: YES (groups with 6, 7)
  - Message: (同 Task 6 commit)
  - Files: `scripts/core/runtime/protocol_validator.gd`

- [ ] 9. 从 95 个 archetype .tres 中移除 legacy_template_id 行

  **What to do**:
  - 遍历 `data/combat/archetypes/` 下所有 95 个 .tres 文件
  - 删除每个文件中包含 `legacy_template_id = &"..."` 的行
  - 确保删除后文件格式正确（无多余空行）
  - 注意：`legacy_template_id = StringName()` 的行也需要删除（虽然值是空的）

  **Must NOT do**:
  - 不要修改 `archetype_id`、`entity_kind`、`mechanics` 等其他字段
  - 不要删除文件本身
  - 不要修改 archive 中的文件

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 95 个文件的批量修改，需要确保不破坏 .tres 格式
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on Tasks 5, 6, 7)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 5, 6, 7

  **References**:

  **Pattern References**:
  - `data/combat/archetypes/plants/archetype_basic_shooter.tres` — 典型 archetype 结构，找到 `legacy_template_id` 行的位置

  **WHY Each Reference Matters**:
  - 需要确认 .tres 中 legacy_template_id 行的精确格式，确保正则/脚本替换不误伤

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: 所有 archetype .tres 中无 legacy_template_id
    Tool: Bash
    Steps:
      1. 搜索 data/combat/archetypes/ 下所有 .tres 文件中 "legacy_template_id" → 0 匹配
      2. 确认 95 个文件仍然存在且非空
    Expected Result: 所有 legacy_template_id 行已删除
    Evidence: .sisyphus/evidence/task-9-archetypes-clean.txt

  Scenario: archetype 实例化仍然正常
    Tool: Bash
    Steps:
      1. pwsh tools/run_validation.ps1 -ScenarioId archetype_instantiation_validation
      2. pwsh tools/run_validation.ps1 -ScenarioId archetype_attack_validation
      3. pwsh tools/run_validation.ps1 -ScenarioId archetype_projectile_validation
    Expected Result: PASS
    Evidence: .sisyphus/evidence/task-9-archetypes-pass.txt
  ```

  **Commit**: YES (groups with 10, 11)
  - Message: `refactor(data): remove legacy_template_id from archetypes and validation rules`
  - Files: `data/combat/archetypes/**/*.tres`

- [ ] 10. 更新 56 个验证 .tres 文件: 重命名 required_core_values 键名

  **What to do**:
  - 遍历 `scenes/validation/` 下所有 96 个 .tres 文件
  - 在 `required_core_values` 字典中：
    - `source_template_id` → `source_archetype_id`
    - `target_template_id` → `target_archetype_id`
    - `object_template_id` → `object_archetype_id`
  - 同时需要更新键对应的值：从 template 名（如 `&"plant_wall_barrier"`）改为 archetype_id（如 `&"archetype_striker_skeleton"`）
  - **关键**：值的映射关系来自 archetype .tres 中 `legacy_template_id → archetype_id` 的对应。映射清单（从数据中提取）：
    - `plant_basic_shooter` → `archetype_basic_shooter`
    - `plant_sunflower` → `archetype_sunflower`
    - `plant_wall_barrier` → `archetype_wall_barrier`
    - `zombie_basic_walker` → `archetype_basic_walker`
    - `zombie_lane_dummy` → `archetype_lane_dummy`
    - `zombie_air_scout` → `archetype_air_scout`
    - `field_object_lawn_mower` → `archetype_lawn_mower`
    - ...（完整映射需从数据中提取，执行时用脚本自动完成）
  - 注意：有些验证规则可能同时有 `source_archetype_id` 和 `source_template_id`，此时只删除 `source_template_id` 行，保留 `source_archetype_id`

  **Must NOT do**:
  - 不要改变验证规则的业务逻辑（event_name, min_count, max_count 不变）
  - 不要删除验证规则本身
  - 不要修改 validation_scenarios.json（它只记录 id 和路径，不含 template_id）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 56 个文件的批量修改 + 值映射需要精确，是本次最容易出错的步骤
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9, 11)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 6, 7

  **References**:

  **Pattern References**:
  - `scenes/validation/archetype_attack_validation.tres` — 典型验证规则结构，同时有 `target_archetype_id` 和 `target_template_id`

  **API/Type References**:
  - `scripts/battle/battle_validation_tracker.gd:195-205` — `_event_matches_rule()` 匹配逻辑：`event_data.core.get(key) == required_core_values[key]`

  **WHY Each Reference Matters**:
  - archetype_attack_validation.tres: 理解 required_core_values 中 template_id 和 archetype_id 共存的结构
  - battle_validation_tracker.gd: 理解匹配逻辑，确保键名改后值也要对应

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: 验证 .tres 中无 template_id 引用
    Tool: Bash
    Steps:
      1. 搜索 scenes/validation/ 下所有 .tres 文件中 "template_id" → 0 匹配
      2. 搜索 scenes/validation/ 下所有 .tres 文件中 "archetype_id" → ≥50 匹配（原来有 template_id 的地方现在都是 archetype_id）
    Expected Result: 所有 template_id 键名已替换
    Evidence: .sisyphus/evidence/task-10-validation-keys-migrated.txt
  ```

  **Commit**: YES (groups with 9, 11)
  - Message: (同 Task 9 commit)
  - Files: `scenes/validation/**/*.tres`

- [ ] 11. 更新 card_place_validation.gd: 简化 legacy fallback

  **What to do**:
  - 修改 `scripts/validation/card_place_validation.gd`
  - L141-147: `_on_entity_spawned()` 中，当前先查 `legacy_template_id` 再 fallback 到 `archetype_id`
  - 简化为只查 `archetype_id`：
    ```
    var archetype_id := StringName(event_data.core.get("archetype_id"))
    if archetype_id != StringName():
        _mark_passed("entity_spawned_from_card_%s" % String(archetype_id))
    ```

  **Must NOT do**:
  - 不要修改其他 validation 脚本

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 单文件，删 3 行改 1 行
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9, 10)
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 13
  - **Blocked By**: Tasks 5, 6

  **References**:
  - `scripts/validation/card_place_validation.gd:138-147` — 当前 fallback 逻辑

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: card_place_validation 通过
    Tool: Bash
    Steps:
      1. pwsh tools/run_validation.ps1 -ScenarioId card_place_validation
    Expected Result: PASS
    Evidence: .sisyphus/evidence/task-11-card-place-pass.txt
  ```

  **Commit**: YES (groups with 9, 10)
  - Message: (同 Task 9 commit)
  - Files: `scripts/validation/card_place_validation.gd`

- [ ] 12. 更新 Wiki 文档: 当前阶段描述

  **What to do**:
  - 更新 `wiki/01-overview/23-当前阶段与实现路线.md`：
    - 「当前一句话」：更新为"legacy 兼容层已完全收口"
    - 删除「legacy 兼容层仍未物理收口」段落
    - 更新「当前主线正在推进什么」段落
    - 更新资源与验证基线数字（95 archetype, 105 validation scenarios）
  - 更新 `wiki/decisions/` — 考虑添加 ADR-007 记录本次收口决策

  **Must NOT do**:
  - 不要修改代码文件

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: 中文文档更新
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (independent of code changes)
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `wiki/01-overview/23-当前阶段与实现路线.md` — 当前阶段文档
  - `wiki/decisions/README.md` — ADR 索引

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Wiki 文档更新
    Tool: Bash
    Steps:
      1. 确认 23-当前阶段与实现路线.md 不再包含 "48 个 archetype 仍保留"
      2. 确认文档包含 "legacy 兼容层已完全收口" 或等效描述
    Expected Result: 文档反映最新状态
    Evidence: .sisyphus/evidence/task-12-wiki-updated.txt
  ```

  **Commit**: YES
  - Message: `docs(wiki): update current stage description for legacy cleanup`
  - Files: `wiki/01-overview/23-当前阶段与实现路线.md`, possibly `wiki/decisions/ADR-007-*.md`

---

- [ ] 13. 全量回归: 105/105 验证场景

  **What to do**:
  - 运行 `pwsh tools/run_all_validations.ps1`
  - 确认 105/105 全部通过
  - 如果有失败：分析失败原因，定位到具体 Task 的遗漏，修复后重新运行
  - 输出完整回归报告到 `.sisyphus/evidence/task-13-regression/`

  **Must NOT do**:
  - 不要跳过失败的场景
  - 不要修改验证场景的通过条件来掩盖失败

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 需要运行全量回归、分析结果、可能需要调试和修复
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on ALL prior tasks)
  - **Parallel Group**: Wave 4
  - **Blocks**: FINAL
  - **Blocked By**: Tasks 8, 9, 10, 11

  **References**:
  - `tools/run_all_validations.ps1` — 回归入口
  - `tools/validation_scenarios.json` — 105 个场景定义

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: 105/105 验证通过
    Tool: Bash
    Steps:
      1. pwsh tools/run_all_validations.ps1
      2. 解析输出，确认所有场景状态为 passed
    Expected Result: 105 pass, 0 fail
    Failure Indicators: 任何场景失败
    Evidence: .sisyphus/evidence/task-13-full-regression.txt
  ```

  **Commit**: YES (groups with 14)
  - Message: `chore: verify full regression pass after legacy cleanup`
  - Pre-commit: `pwsh tools/run_all_validations.ps1`

- [ ] 14. 清理: 更新 CLAUDE.md / AGENTS.md 模块文档

  **What to do**:
  - 更新 `AGENTS.md`：
    - 更新模块索引表（entity_template.gd 已删除，runtime_trigger_spec.gd 新增）
    - 更新「当前已经成立的事实」段落
    - 更新 autoload 描述（如果 TriggerBinding 相关的注册有变化）
  - 更新 `scripts/core/CLAUDE.md`：
    - defs 表格中移除 EntityTemplate 行
    - runtime 表格中添加 RuntimeTriggerSpec 行
  - 更新 `scripts/battle/CLAUDE.md`：
    - EntityFactory 描述中移除 TriggerBinding 引用，添加 RuntimeTriggerSpec 引用
    - BattleScenario 描述中 `protected_template_id` → `protected_archetype_id`

  **Must NOT do**:
  - 不要修改代码文件

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 文档更新，结构明确
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 13, but should run after 13 confirms pass)
  - **Parallel Group**: Wave 4
  - **Blocks**: FINAL
  - **Blocked By**: Task 13

  **References**:
  - `AGENTS.md` — 项目根文档
  - `scripts/core/CLAUDE.md` — core 模块文档
  - `scripts/battle/CLAUDE.md` — battle 模块文档

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: 文档更新完成
    Tool: Bash
    Steps:
      1. 搜索 AGENTS.md 中 "EntityTemplate" → 仅在迁移历史描述中出现，不在"当前"表格中
      2. 搜索 scripts/core/CLAUDE.md 中 "RuntimeTriggerSpec" → ≥1 匹配
      3. 搜索 scripts/battle/CLAUDE.md 中 "protected_archetype_id" → ≥1 匹配
    Expected Result: 文档反映最新代码结构
    Evidence: .sisyphus/evidence/task-14-docs-updated.txt
  ```

  **Commit**: YES (groups with 13)
  - Message: `chore: update module docs for legacy cleanup`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run all 105 validation scenarios. Review all changed files for: `as any`/`@ts-ignore` equivalents in GDScript, empty catches, commented-out code, unused imports/preloads, leftover `legacy_template_id` or `template_id` references in runtime code. Check AI slop: excessive comments, over-abstraction.
  Output: `Validations [105/105] | Lint [PASS/FAIL] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Run `pwsh tools/run_all_validations.ps1`. Verify each validation scenario result in artifacts/validation/. Test cross-task integration: archetype instantiation + event emission + validation matching all work with new archetype_id identity. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [105/105 pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes. Specifically verify: `ProjectileTemplate.template_id` was NOT touched, `trigger_binding.gd` file still exists, `vendor/` untouched.
  Output: `Tasks [14/14 compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Task 1-3**: `refactor(core): remove entity_template, add RuntimeTriggerSpec, remove legacy_template_id defs` — runtime_trigger_spec.gd, entity_template.gd (deleted), combat_archetype.gd, runtime_spec.gd, battle_mode_input_request.gd
- **Task 4-5**: `refactor(compile): replace TriggerBinding with RuntimeTriggerSpec in compilation chain` — mechanic_compiler.gd, entity_factory.gd
- **Task 6-8**: `refactor(battle): migrate event identity from template_id to archetype_id` — battle_spawner.gd, battle_board_state.gd, battle_card_state.gd, battle_economy_state.gd, battle_field_object_state.gd, battle_flow_state.gd, battle_scenario.gd, battle_status_state.gd, battle_mode_host.gd, protocol_validator.gd
- **Task 9-11**: `refactor(data): remove legacy_template_id from archetypes and validation rules` — 95 archetype .tres, 56 validation .tres, card_place_validation.gd
- **Task 12**: `docs(wiki): update current stage description for legacy cleanup` — wiki/01-overview/23-当前阶段与实现路线.md
- **Task 13-14**: `chore: update module docs and verify full regression` — AGENTS.md, CLAUDE.md files
- Pre-commit for each: `pwsh tools/run_all_validations.ps1` must show all pass

---

## Success Criteria

### Verification Commands
```powershell
pwsh tools/run_all_validations.ps1  # Expected: 105/105 PASS
Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse | Select-String -Pattern "legacy_template_id"  # Expected: 0 matches (excluding archive)
Get-ChildItem -Path "data\combat\archetypes" -Filter "*.tres" -Recurse | Select-String -Pattern "legacy_template_id"  # Expected: 0 matches
Test-Path "scripts/core/defs/entity_template.gd"  # Expected: False
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] 105/105 validation scenarios pass
- [ ] Zero `legacy_template_id` in runtime code (excluding archive)
- [ ] Zero `entity_template.gd` file
- [ ] `RuntimeTriggerSpec` used as sole trigger compilation output
