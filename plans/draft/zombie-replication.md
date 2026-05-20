# PVZ1 原版僵尸复刻路线图

## TL;DR

> **Quick Summary**: 复刻 25 个 PVZ1 冒险模式常规僵尸，遵循植物移植方案的 Mechanic-first 架构。Wave 0 基础设施已先行落地：HealthLayer、DamageLayerPolicy、Movement v1、State side-effects、exposure/weight 过滤；后续按出场关卡和行为复杂度分 5 批（A-E）推进，每批含验证场景。
> 
> **Deliverables**:
> - 1 个僵尸基础设施协议包（HealthLayerDef + damage_layer_policy + Movement v1 + exposure/weight + 验证）
> - 25 个原版僵尸 Archetype（`archetype_original_*`）
> - 对应的 CombatMechanic 资源（复用骨架 + 按需新增）
> - 25 个单僵尸验证场景 + 5 个批次验证场景
> - 更新 `tools/validation_scenarios.json` 和 `tools/formal_content_validation_map.json`
> 
> **Estimated Effort**: XL
> **Parallel Execution**: YES - 6 waves
> **Critical Path**: Wave 0 (基础设施，已完成) → Batch A (基础近战) → Batch B (特殊移动) → Batch C (水面) → Batch D (复杂行为) → Batch E (巨人) → Final Verification

---

## Context

### Original Request
用户要求参照 `wiki/05-governance/36-原版实体复刻工作流.md` 的植物移植方案和已实现的原版植物，制定一个复刻原版僵尸的计划路线图。

### Interview Summary
**Key Discussions**:
- 范围确认：排除 Zombotany(6)、Dr. Zomboss(1)、Bobsled Team(1)，共 25 个僵尸
- 现有测试僵尸保留并行，原版用 `archetype_original_*` 命名
- HealthComponent 不支持分层血量，7 个僵尸需要 body + helm/shield 层
- 批次策略：按出场关卡 + 行为复杂度分 5 批，与植物方案对齐

**Research Findings**:
- `vendor/de-pvz` 包含权威原版数据（33 个 ZombieType，含完整 HP/速度/攻击值）
- HealthComponent 仅支持单层 HP（max_health/current_health），无分层基础设施
- 现有 bite controller 和 ranged pattern 可直接复用于大部分近战/远程僵尸
- 植物方案已建立完整的 archetype → mechanic → card → validation 工作流模式

### Metis Review
**Identified Gaps** (addressed):
- **分层血量设计已收口**：Wave 0 已落地 `HealthLayerDef`、layer 路由、过伤、layer destroyed 事件与 shield bypass 策略
- **Ducky Tube 与水面放置**：记录为协议缺口，Batch C 内处理
- **Imp/Backup Dancer 被召唤依赖**：作为独立任务，由父僵尸的 spawn_entity 效果触发
- **验证场景中僵尸不需要 CardDef**：僵尸通过 BattleSpawnEntry 生成，验证场景直接用 spawn
- **Zomboni 冰道效果**：记录为协议缺口，当前方案中 Zomboni 只实现碾压行为，冰道标记为延后
- **Screen Door 方向性挡弹**：在 HealthLayer 中以 material tag 标记 shield 方向性，具体路由逻辑后续迭代

---

## Work Objectives

### Core Objective
复刻 25 个 PVZ1 冒险模式常规僵尸，使用 CombatArchetype + CombatMechanic[] 架构，遵循与植物移植方案相同的工作流和验收标准。

### Concrete Deliverables
- `data/combat/archetypes/zombies/archetype_original_*.tres` × 25
- `data/combat/mechanics/mechanic_original_*.tres` × N（按需新增）
- `data/combat/projectile_templates/` 按需新增（如 basketball）
- `scenes/validation/zombie_original_*.tres` × 25 + 批次验证 × 5
- `tools/validation_scenarios.json` 更新（新增 ~30 个条目）
- `tools/formal_content_validation_map.json` 更新（新增 zombie_original 分组）
- 基础设施协议：`scripts/core/defs/health_layer_def.gd`、`autoload/MovementRegistry.gd`、`HealthComponent`、`MovementComponent`、`StateComponent`、暴露态/重量过滤 + 验证

### Definition of Done
- [ ] 所有 25 个原版僵尸有对应 archetype 且可被 WaveRunner 正确生成
- [x] Wave 0 基础设施正确处理 body/helm/shield/attachment 层路由、damage_layer_policy、Movement v1、State side-effects、exposure/weight 过滤
- [ ] 每个僵尸至少 1 个单体验证场景通过
- [ ] 每批至少 1 个批次验证场景通过
- [ ] `pwsh tools/run_all_validations.ps1` 全量通过
- [ ] `tools/formal_content_validation_map.json` 包含所有新增条目

### Must Have
- 原版数值以 `vendor/de-pvz` 为准（HP、速度、攻击值）
- 所有行为通过 CombatArchetype + CombatMechanic[] 驱动
- 分层血量通过 HealthComponent 扩展实现，不创建僵尸专属组件
- 新增 effect/controller 遵循 RegistryBase 模式
- 验证场景覆盖核心行为（生成、移动、攻击、死亡）

### Must NOT Have (Guardrails)
- **禁止为单个僵尸硬编码业务逻辑**：不得编写 `ConeheadZombieAI`、`GargantuarLogic` 这类命名
- **禁止 BattleManager 特判**：不得为特定僵尸在 BattleManager 中添加 if/switch 分支
- **禁止绕过 HealthLayer 系统**：不得为有护甲僵尸使用单层 max_health 合并值
- **禁止修改现有测试僵尸**：basic_walker、bucket_tank 等保持不变
- **除 ADR-008 已接受的 `Movement` 外禁止新增 Mechanic family**：后续新增 family 必须另走 ADR
- **禁止使用 `print()` 替代 DebugService**
- **Zomboni 冰道效果不在本轮实现**：只实现碾压行为，冰道标记为协议缺口延后
- **Screen Door 方向性挡弹不做完整实现**：以标签标记，具体路由逻辑后续迭代
- **不得提前建设 Boss 战模式**：Dr. Zomboss 相关设计另行成文
- **不得为僵尸创建 CardDef**：僵尸通过波次生成，非玩家放置

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** - ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES（验证场景框架）
- **Automated tests**: YES（validation scenes per zombie + batch validations）
- **Framework**: Godot validation scenes（同植物方案）
- **TDD**: No（先实现后验证，验证场景作为验收标准）

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Zombie behaviors**: Use Bash (`pwsh tools/run_validation.ps1`) — Run validation scenario, check pass/fail
- **Layered health**: Use Bash (`pwsh tools/run_validation.ps1`) — Run layered damage validation
- **Batch validation**: Use Bash (`pwsh tools/run_all_validations.ps1 -Layers smoke,core`) — Full batch regression

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 0 (Completed — foundation):
├── Task 0a: HealthLayer v1 [done]
├── Task 0b: DamageLayerPolicy v1 [done]
├── Task 0c: Movement v1 [done]
├── Task 0d: State side-effects v1 [done]
└── Task 0e: Exposure / Weight v1 [done]

Wave 1 / Batch A (After Wave 0 — basic melee, MAX PARALLEL):
├── Task 1: Basic Zombie [quick]
├── Task 2: Flag Zombie [quick]
├── Task 3: Conehead Zombie [quick]
└── Task 4: Buckethead Zombie [quick]

Wave 2 / Batch B (After Wave 1 — movement/speed variants, MAX PARALLEL):
├── Task 5: Football Zombie [quick]
├── Task 6: Screen Door Zombie [quick]
├── Task 7: Newspaper Zombie [unspecified-high]
└── Task 8: Pole Vaulting Zombie [deep]

Wave 3 / Batch C (After Wave 2 — pool/water, MAX PARALLEL):
├── Task 9: Ducky Tube Zombie [quick]
├── Task 10: Snorkel Zombie [deep]
├── Task 11: Dolphin Rider Zombie [deep]
└── Task 12: Zomboni [deep]

Wave 4 / Batch D (After Wave 3 — complex behaviors, MAX PARALLEL):
├── Task 13: Balloon Zombie [unspecified-high]
├── Task 14: Jack-in-the-Box Zombie [unspecified-high]
├── Task 15: Digger Zombie [deep]
├── Task 16: Pogo Zombie [deep]
├── Task 17: Zombie Yeti [unspecified-high]
├── Task 18: Bungee Zombie [deep]
├── Task 19: Ladder Zombie [unspecified-high]
└── Task 20: Catapult Zombie [unspecified-high]

Wave 5 / Batch E (After Wave 4 — giants & spawned, MAX PARALLEL):
├── Task 21: Dancing Zombie [deep]
├── Task 22: Backup Dancer [quick]
├── Task 23: Gargantuar [deep]
├── Task 24: Imp [quick]
└── Task 25: Redeye Gargantuar [quick]

Wave FINAL (After ALL tasks — 4 parallel reviews):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
→ Present results → Get explicit user okay

Critical Path: Task 0 → Task 3,4 → Task 5-8 → Task 12 → Task 18,23 → F1-F4 → user okay
Parallel Speedup: ~80% faster than sequential
Max Concurrent: 8 (Wave 4)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 0 | — | 3,4,5,6,7 | 0 |
| 1 | 0 | — | 1 |
| 2 | 0 | — | 1 |
| 3 | 0 | — | 1 |
| 4 | 0 | — | 1 |
| 5 | 0 | — | 2 |
| 6 | 0 | — | 2 |
| 7 | 0 | — | 2 |
| 8 | — | — | 2 |
| 9 | — | — | 3 |
| 10 | — | — | 3 |
| 11 | — | — | 3 |
| 12 | — | — | 3 |
| 13 | — | — | 4 |
| 14 | — | — | 4 |
| 15 | — | — | 4 |
| 16 | — | — | 4 |
| 17 | — | — | 4 |
| 18 | — | — | 4 |
| 19 | — | — | 4 |
| 20 | — | — | 4 |
| 21 | — | 22 | 5 |
| 22 | 21 | — | 5 |
| 23 | — | 24 | 5 |
| 24 | 23 | — | 5 |
| 25 | 23 | — | 5 |

> 注：大多数 Batch B-E 任务在技术上可与 Batch A 并行（它们不依赖分层血量，或者有护甲的已被标记依赖 Wave 0）。但为了保持批次验收完整性，建议按波次推进。实际执行中，agent 可提前开始无依赖的任务。

### Agent Dispatch Summary

- **Wave 0**: infrastructure completed — HealthLayer / DamageLayerPolicy / Movement / State side-effects / Exposure-Weight
- **Wave 1 / Batch A**: 4 tasks — T1-T4 → `quick`
- **Wave 2 / Batch B**: 4 tasks — T5,T6 → `quick`, T7 → `unspecified-high`, T8 → `deep`
- **Wave 3 / Batch C**: 4 tasks — T9 → `quick`, T10-T12 → `deep`
- **Wave 4 / Batch D**: 8 tasks — T13,T14,T17,T19,T20 → `unspecified-high`, T15,T16,T18 → `deep`
- **Wave 5 / Batch E**: 5 tasks — T21,T23 → `deep`, T22,T24,T25 → `quick`
- **FINAL**: 4 tasks — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

> Implementation + Validation = ONE Task. Never separate.
> EVERY task MUST have: Recommended Agent Profile + Parallelization info + QA Scenarios.

- [x] 0. **僵尸基础设施协议包（Wave 0）**

  **已落地范围**:
  - `HealthLayerDef` + `CombatArchetype.health_layers` + `RuntimeSpec.health_layers`，支持 `attachment -> shield -> helm -> body` 路由、过伤、`absorb_only/spill_to_next` 和 `health.layer_destroyed`。
  - `damage_layer_policy` 已接入 `Effect.damage`、`Effect.spawn_projectile`、`ProjectileTemplate.default_params` 和 projectile runtime overrides；v1 支持 `bypass_layer_kinds` 与 `spillover`。
  - ADR-008 已接受；新增 `Movement` family、`MovementRegistry`、`MovementDef`、`RuntimeSpec.movement_spec`，v1 只实现 `core.walk` 与 `core.leap_once`。
  - `MovementComponent` 成为默认位置积分点，按 `State override -> Movement base -> Status modifier -> Effect impulse -> integrate` 合并命令，并同步 `height / height_velocity / ground_contact / exposure_state`。
  - `StateComponent` transition side-effects 已支持 `set_movement`、`submit_movement_override`、`set_height_band`、`set_runtime_params`、`emit_event`，可按 `event_name` 与 `required_layer_id` 过滤 `health.layer_destroyed`。
  - `CombatArchetype.initial_exposure_state` 与 `weight_class` 已接入，HitPolicy/Effect 使用 `target_exposure_states`，默认只命中 `ground`。

  **验证入口**:
  - `health_layer_helm_routing_validation`
  - `health_layer_shield_routing_validation`
  - `health_layer_attachment_routing_validation`
  - `damage_layer_policy_bypass_shield_validation`
  - `movement_walk_validation`
  - `movement_command_merge_validation`
  - `movement_leap_z_axis_validation`
  - `movement_interrupt_validation`
  - `state_side_effect_set_movement_validation`
  - `hit_policy_exposure_ground_default_validation`
  - `hit_policy_exposure_flying_validation`
  - `hit_policy_exposure_hidden_validation`
  - `force_weight_filter_validation`

  **后续复刻约束**:
  - 有护甲、门板、气球、报纸、梯子等可击破部件的僵尸必须使用 `health_layers`，不得把总 HP 合并进 body。
  - 投手类绕过门板/盾牌时使用 `damage_layer_policy.bypass_layer_kinds=["shield"]`，不得在 projectile 或 zombie 代码里特判。
  - 新增僵尸运动默认使用 `Movement` mechanic；`hop_cycle/tunnel/drive/submerge` 只能在对应批次补设计与验证，不得塞进 `ZombieRoot` 或 `Controller` 特判。
  - `flying/submerged/underground/airborne` 必须显式 opt-in 到 `target_exposure_states`，默认攻击只命中 `ground`。

- [ ] 1. **Basic Zombie（普通僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_basic_zombie.tres`（ZombieArchetype）
    - archetype_id: `archetype_original_basic_zombie`
    - max_health: 270（仅 body，无护甲）
    - default_params: move_speed_slots_per_sec = 0.28（原版 0.23-0.32 的中间值）
    - mechanics: 复用 `skeleton/mechanic_bite_controller.tres`
    - tags: `["archetype", "zombie", "original", "basic", "walker"]`
    - hit_height_band: ground_unit
  - 创建验证场景 `scenes/validation/zombie_original_basic_zombie_validation.tres`：
    - 生成 basic_zombie + wall_barrier 作为攻击目标
    - 验证：zombie 移动到目标附近 → 咬击 → entity.damaged 事件 → 目标 HP 下降
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得修改现有 `archetype_basic_walker`
  - 不得创建僵尸专属逻辑

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 纯资源创建，复用已有 bite_controller mechanic，无代码修改
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4)
  - **Blocks**: None
  - **Blocked By**: Task 0（基础依赖，确认分层血量不破坏兼容性）

  **References**:

  **Pattern References**:
  - `data/combat/archetypes/zombies/archetype_basic_walker.tres` — 现有基础步行者模板（直接参考结构）
  - `scenes/validation/zombie_roster_attack_validation.tres` — 现有僵尸验证场景模板

  **API/Type References**:
  - `scripts/core/defs/zombie_archetype.gd` — ZombieArchetype 类定义
  - `data/combat/mechanics/skeleton/mechanic_bite_controller.tres` — 复用的 bite controller

  **External References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_NORMAL 初始化：mBodyHealth=270, speed=0.23-0.32

  **WHY Each Reference Matters**:
  - `archetype_basic_walker.tres` 是最接近的原型，新 archetype 按相同结构创建
  - `zombie_roster_attack_validation.tres` 展示了验证僵尸攻击的完整模式
  - `de-pvz/Zombie.cpp` 提供权威原版数值

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 基础僵尸生成并咬击目标
    Tool: Bash (pwsh tools/run_validation.ps1)
    Preconditions: archetype 和 validation scene 已创建
    Steps:
      1. pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/zombie_original_basic_zombie_validation.tres"
      2. 检查验证报告：entity.spawned（zombie）+ entity.damaged（target）
    Expected Result: verdict = "passed"，zombie 成功生成并造成伤害
    Failure Indicators: zombie 未生成，或未造成伤害
    Evidence: .sisyphus/evidence/task-1-basic-zombie.txt

  Scenario: 现有验证未受影响
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/zombie_roster_attack_validation.tres"
    Expected Result: verdict = "passed"
    Evidence: .sisyphus/evidence/task-1-regression.txt
  ```

  **Commit**: YES (groups with Batch A)
  - Message: `feat(zombies): add original batch A — basic melee zombies`
  - Pre-commit: `pwsh tools/run_all_validations.ps1 -Layers smoke,core`

- [ ] 2. **Flag Zombie（旗帜僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_flag_zombie.tres`
    - 与 Basic Zombie 结构相同
    - max_health: 270
    - move_speed_slots_per_sec: 0.45（比普通僵尸快）
    - tags: `["archetype", "zombie", "original", "flag"]`
  - 创建验证场景 `scenes/validation/zombie_original_flag_zombie_validation.tres`
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现"旗帜波次加速"逻辑（记录为协议缺口，属于 WaveRunner 层面）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 1, 3, 4)
  - **Parallel Group**: Wave 1
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `data/combat/archetypes/zombies/archetype_original_basic_zombie.tres`（Task 1 产出）
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_FLAG: mBodyHealth=270, speed=0.45

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 旗帜僵尸生成并以更快速度移动
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 运行 zombie_original_flag_zombie_validation
      2. 验证 zombie 在预期时间内到达目标位置（比 basic zombie 快约 60%）
    Expected Result: verdict = "passed"
    Evidence: .sisyphus/evidence/task-2-flag-zombie.txt
  ```

  **Commit**: YES (groups with Batch A)

- [ ] 3. **Conehead Zombie（路障僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_conehead.tres`
    - max_health: 270（body）
    - health_layers: [HealthLayerDef(layer_id=&"cone", layer_kind=&"helm", max_health=370, armor_type=&"CONE")]
    - move_speed_slots_per_sec: 0.28
    - mechanics: 复用 bite_controller
    - tags: `["archetype", "zombie", "original", "conehead", "armored"]`
  - 创建验证场景 `scenes/validation/zombie_original_conehead_validation.tres`：
    - 验证总 HP = 640（body 270 + cone 370）
    - 验证 cone 先吸收伤害，消亡后 `health.layer_destroyed` 事件
    - 验证过伤传递
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得用单层 max_health=640 合并（必须使用分层血量）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 1, 2, 4)
  - **Parallel Group**: Wave 1
  - **Blocks**: None
  - **Blocked By**: Task 0（依赖 HealthLayer 基础设施）

  **References**:
  - `data/combat/archetypes/zombies/archetype_original_basic_zombie.tres`（Task 1，结构模板）
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_TRAFFIC_CONE: body=270, helm=370(CONE), speed=0.23-0.32

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 路障分层吸收伤害
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 运行 zombie_original_conehead_validation
      2. 验证 200 伤害后 cone 370→170，body 仍为 270
      3. 验证 500 伤害后 cone 消亡，body 270→140
    Expected Result: verdict = "passed"，`health.layer_destroyed` 事件在 cone 消亡时触发
    Evidence: .sisyphus/evidence/task-3-conehead.txt
  ```

  **Commit**: YES (groups with Batch A)

- [ ] 4. **Buckethead Zombie（铁桶僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_buckethead.tres`
    - max_health: 270（body）
    - health_layers: [HealthLayerDef(layer_id=&"bucket", layer_kind=&"helm", max_health=1100, armor_type=&"PAIL", material_tags=["metal"])]
    - move_speed_slots_per_sec: 0.28
    - tags: `["archetype", "zombie", "original", "buckethead", "armored", "metal"]`
  - 创建验证场景（同 Conehead 模式，但更高 HP）
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得用单层 max_health=1370 合并
  - 不得实现 Magnet-shroom 吸取铁桶（标记为后续迭代）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 1, 2, 3)
  - **Parallel Group**: Wave 1
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_PAIL: body=270, helm=1100(PAIL), speed=0.23-0.32

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 铁桶分层吸收伤害
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 运行验证场景
      2. 验证 1100 伤害后 bucket 消亡，body 仍为 270
      3. 验证 1370 伤害后 zombie 死亡
    Expected Result: verdict = "passed"
    Evidence: .sisyphus/evidence/task-4-buckethead.txt
  ```

  **Commit**: YES (groups with Batch A)

- [ ] 5. **Football Zombie（橄榄球僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_football.tres`
    - max_health: 270（body）
    - health_layers: [HealthLayerDef(layer_id=&"football_helm", layer_kind=&"helm", max_health=1400, armor_type=&"FOOTBALL", material_tags=["metal"])]
    - move_speed_slots_per_sec: 0.67（高速）
    - hitbox_size: 适当增大
    - tags: `["archetype", "zombie", "original", "football", "armored", "metal", "fast"]`
  - 创建验证场景（验证高速 + 高护甲）
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得合并 HP，不得降低速度

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 6, 7, 8)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: Task 0（HealthLayer 基础设施）

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_FOOTBALL: body=270, helm=1400(FOOTBALL), speed=0.66-0.68
  - `data/combat/archetypes/zombies/archetype_brisk_runner.tres` — 高速僵尸参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 橄榄球僵尸高速移动并承受大量伤害
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 运行验证场景
      2. 验证总 HP = 1670，速度明显快于 basic zombie
    Expected Result: verdict = "passed"
    Evidence: .sisyphus/evidence/task-5-football.txt
  ```

  **Commit**: YES (groups with Batch B)

- [ ] 6. **Screen Door Zombie（铁栅门僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_screen_door.tres`
    - max_health: 270（body）
    - health_layers: [HealthLayerDef(layer_id=&"door_shield", layer_kind=&"shield", max_health=1100, armor_type=&"DOOR", material_tags=["metal", "shield", "directional"])]
    - move_speed_slots_per_sec: 0.28
    - tags: `["archetype", "zombie", "original", "screen_door", "armored", "shield", "metal"]`
  - 创建验证场景（验证高护甲）
  - 添加到 `tools/validation_scenarios.json`
  - **注意**：方向性挡弹（正面子弹被挡，背面不受影响）标记为协议缺口，当前 shield 作为通用减伤层

  **Must NOT do**:
  - 不得实现方向性伤害判定（后续迭代）
  - 不得合并 HP

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 5, 7, 8)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_DOOR: body=270, shield=1100(DOOR)
  - `vendor/de-pvz/Lawn/Zombie.h` — ShieldType 枚举

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 铁栅门分层吸收伤害
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 运行验证场景，发送 1100 伤害
      2. 验证 door 消亡，body 仍为 270
    Expected Result: verdict = "passed"
    Evidence: .sisyphus/evidence/task-6-screen-door.txt
  ```

  **Commit**: YES (groups with Batch B)

- [ ] 7. **Newspaper Zombie（报纸僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_newspaper.tres`
    - max_health: 270（body）
    - health_layers: [HealthLayerDef(layer_id=&"newspaper", layer_kind=&"shield", max_health=150, armor_type=&"PAPER")]
    - move_speed_slots_per_sec: 0.28（正常），speed_rage: 0.90（报纸被毁后）
    - 新增 mechanic `mechanic_original_newspaper_rage.tres`：
      - 使用 `Trigger/core.when_damaged` 监听
      - 条件：`health.layer_destroyed` 事件且 layer_id == "newspaper"
      - 效果：通过 State side-effect 提交 movement override，把 `move_speed_slots_per_sec` 改为 0.90（速度激增约 3 倍）
    - tags: `["archetype", "zombie", "original", "newspaper", "armored", "rage"]`
  - 创建验证场景：
    - 验证报纸吸收 150 伤害后消亡
    - 验证消亡后 zombie 速度从 0.28 变为 0.90
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得硬编码速度变化逻辑到 ZombieRoot
  - 速度变化必须通过 Mechanic 触发

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 需要新增 mechanic 实现速度变化触发，涉及 `health.layer_destroyed` 事件和 movement override
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 5, 6, 8)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_NEWSPAPER: body=270, shield=150(PAPER), speed normal=0.23-0.32, rage=0.89-0.91
  - `data/combat/mechanics/mechanic_reactive_bomber_when_damaged.tres` — when_damaged 触发器参考
  - `scripts/entities/zombie_root.gd` — 移动速度如何被修改

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 报纸被毁后速度激增
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 运行验证场景，攻击 newspaper zombie 使报纸被毁
      2. 验证 zombie 在报纸消亡后以更快速度移动
    Expected Result: 报纸消亡前移动慢，消亡后移动明显加快
    Evidence: .sisyphus/evidence/task-7-newspaper.txt

  Scenario: 报纸未受损时速度正常
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 newspaper zombie，不攻击
      2. 验证初始移动速度 = 0.28
    Expected Result: 速度正常（0.28 附近）
    Evidence: .sisyphus/evidence/task-7-newspaper-normal.txt
  ```

  **Commit**: YES (groups with Batch B)

- [ ] 8. **Pole Vaulting Zombie（撑杆跳僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_pole_vaulter.tres`
    - max_health: 500（无护甲）
    - move_speed_slots_per_sec: 0.67（跳跃前高速）
    - 新增 mechanic `mechanic_original_pole_vaulter_vault.tres`：
      - 使用 `Trigger/core.proximity`（扫描前方近距离植物）
      - 效果：触发跳跃——使用 Movement/State 组合让 zombie 跳过第一个植物，落地后速度变为 0.90（弃杆后极快）
      - 跳跃后切换为普通 bite 行为
    - **协议缺口**：完整翻越位移窗口需要在 `Movement.core.leap_once` 基础上补 Pole Vaulter 专项设计
      - 最小实现：使用 Movement + State mechanic 实现"跳跃中"状态
      - 跳跃中：无敌 + 快速向前移动 + 不可被攻击
      - 跳跃结束：恢复正常 + 速度永久改变为 0.90
    - tags: `["archetype", "zombie", "original", "pole_vaulter", "jumper"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得硬编码跳跃逻辑到 BattleManager
  - 不得为撑杆跳创建新的 Mechanic family；必须复用 ADR-008 的 `Movement`

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要在 Movement v1 基础上设计翻越触发、状态切换和速度覆盖
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 5, 6, 7)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: None（不依赖分层血量）

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_POLEVAULTER: body=500, pre_vault speed=0.66-0.68, post_vault speed=0.89-0.91
  - `data/combat/mechanics/mechanic_original_chomper_proximity.tres` — proximity trigger 参考
  - `scripts/core/defs/combat_mechanic.gd` — Mechanic family/type 定义
  - `scripts/components/movement_component.gd` — Movement 组件

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 撑杆跳翻越第一个植物
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 pole_vaulter + 前方放置 wall_barrier
      2. 验证 zombie 接近后跳过 wall_barrier
      3. 验证跳跃后速度变化
    Expected Result: zombie 跳过第一个障碍物，继续前进攻击后续目标
    Failure Indicators: zombie 停在障碍物前不跳，或跳过所有植物不停
    Evidence: .sisyphus/evidence/task-8-pole-vaulter.txt
  ```

  **Commit**: YES (groups with Batch B)

- [ ] 9. **Ducky Tube Zombie（鸭子游泳圈僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_ducky_tube.tres`
    - 与 Basic Zombie 相同结构
    - max_health: 270
    - move_speed_slots_per_sec: 0.28
    - tags: `["archetype", "zombie", "original", "ducky_tube", "water"]`
    - **协议缺口记录**：水面放置语义（water_slot）当前未实现，此 zombie 暂时作为标准 ground_unit，标记 water 标签供后续水道系统消费
  - 创建验证场景（标准 bite 验证）
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现水面放置逻辑
  - 不得修改 BattleBoardState

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 10, 11, 12)
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_DUCKY_TUBE: body=270, speed=0.23-0.32
  - `data/combat/archetypes/zombies/archetype_basic_walker.tres` — 结构参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 鸭子游泳圈僵尸生成并攻击
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 运行 zombie_original_ducky_tube_validation
      2. 验证 zombie 生成 + 咬击目标
    Expected Result: verdict = "passed"
    Evidence: .sisyphus/evidence/task-9-ducky-tube.txt
  ```

  **Commit**: YES (groups with Batch C)

- [ ] 10. **Snorkel Zombie（潜水僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_snorkel.tres`
    - max_health: 270
    - move_speed_slots_per_sec: 0.67（水面快速移动）
    - **协议缺口**：潜水/出水状态切换需要 State mechanic 扩展
      - 最小实现：使用 `State/core.sleeping` 类似模式，创建"submerged"状态
      - submerged 状态：不可被攻击（liveness_overrides: targetable=false, damageable=false）
      - 出水条件：接近植物时自动出水（proximity trigger）
      - 出水后：恢复 targetable/damageable，开始 bite 攻击
    - 新增 mechanic `mechanic_original_snorkel_submerge.tres`（State mechanic）
    - 新增 mechanic `mechanic_original_snorkel_surface.tres`（proximity trigger → 移除 submerged 状态）
    - tags: `["archetype", "zombie", "original", "snorkel", "water", "submerged"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得硬编码潜水逻辑到 ZombieRoot
  - 不得修改 liveness 系统核心

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要设计新的状态切换机制（submerged/surfaced），涉及 liveness override 和状态管理
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9, 11, 12)
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_SNORKEL: body=270, speed=0.66-0.68 (above water)
  - `data/combat/mechanics/mechanic_original_chomper_digest_status.tres` — apply_status + liveness_overrides 参考
  - `scripts/components/state_component.gd` — 状态管理组件

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 潜水状态不可被攻击，出水后可攻击
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 snorkel zombie（初始 submerged）
      2. 验证此期间攻击无效（不产生 entity.damaged 事件给 zombie）
      3. 生成前方植物，zombie 接近后出水
      4. 验证出水后可被攻击并可咬击植物
    Expected Result: submerged 期间无敌，出水后正常
    Evidence: .sisyphus/evidence/task-10-snorkel.txt
  ```

  **Commit**: YES (groups with Batch C)

- [ ] 11. **Dolphin Rider Zombie（海豚骑士僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_dolphin_rider.tres`
    - max_health: 500
    - move_speed_slots_per_sec: 0.90（陆地极快）
    - **协议缺口**：跳越水面植物需要类似 Pole Vault 的跳跃机制
      - 最小实现：复用撑杆跳的 proximity trigger + 跳跃行为
      - 跳跃后：丢弃海豚，速度降为 0.28（标准步行）
    - tags: `["archetype", "zombie", "original", "dolphin_rider", "water", "jumper"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得与 Pole Vaulter 共享跳跃逻辑（各自独立 mechanic，后续可提取共享模式）

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要复用/适配跳跃行为模式，涉及状态切换和速度变化
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9, 10, 12)
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: Task 8（可参考撑杆跳模式，但非硬依赖）

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_DOLPHIN_RIDER: body=500, walk=0.89-0.91, pool=0.3
  - `data/combat/mechanics/mechanic_original_pole_vaulter_vault.tres`（Task 8，跳跃模式参考）

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 海豚骑士跳过第一个水面植物
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 dolphin_rider + 前方 wall_barrier
      2. 验证跳过后速度降为标准步行速度
    Expected Result: 跳过第一个障碍，速度降低
    Evidence: .sisyphus/evidence/task-11-dolphin-rider.txt
  ```

  **Commit**: YES (groups with Batch C)

- [ ] 12. **Zomboni（冰车僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_zomboni.tres`
    - max_health: 1350（无护甲）
    - move_speed_slots_per_sec: 0.25（逐渐减速至 0.05，使用确定性曲线）
    - 新增 mechanic `mechanic_original_zomboni_drive.tres`：
      - 使用 Controller family，新增 type `core.drive_over`
      - 行为：每帧检测前方植物，接触即碾压（instant kill，类似 Gargantuar smash）
      - 减速曲线：随 x 位置递减速度
    - **协议缺口记录**：冰道效果不实现，仅在 tags 中标记 "ice_trail" 供后续使用
    - hit_height_band: ground_unit_large
    - tags: `["archetype", "zombie", "original", "zomboni", "vehicle", "crush"]`
  - 创建验证场景（验证碾压行为 + 高 HP）
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现冰道系统（记录为协议缺口）
  - 不得硬编码碾压逻辑到 BattleManager

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要新增 Controller type（drive_over），涉及新策略注册和碰撞检测
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9, 10, 11)
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_ZAMBONI: body=1350, speed=0.25→0.05
  - `data/combat/mechanics/skeleton/mechanic_bite_controller.tres` — Controller 注册模式参考
  - `autoload/ControllerRegistry.gd` — Controller 策略注册
  - `scripts/entities/zombie_root.gd:perform_attack_cycle_for_controller()` — Controller 执行入口

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: Zomboni 碾压路径上的植物
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 zomboni + 前方 wall_barrier
      2. 验证 zomboni 接触 wall_barrier 时目标立即死亡
    Expected Result: 植物被碾压（entity.died 事件），zomboni 不受阻挡
    Evidence: .sisyphus/evidence/task-12-zomboni.txt
  ```

  **Commit**: YES (groups with Batch C)

- [ ] 13. **Balloon Zombie（气球僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_balloon.tres`
    - max_health: 270（body）
    - health_layers: [HealthLayerDef(layer_id=&"balloon", layer_kind=&"attachment", max_health=20, armor_type=&"BALLOON")]
    - move_speed_slots_per_sec: 0.28（飞行速度）
    - hit_height_band: air_unit_low（飞行状态）
    - 新增 mechanic `mechanic_original_balloon_pop.tres`：
      - 监听 `health.layer_destroyed`（balloon 消亡）
      - 效果：切换 height_band 为 ground_unit，恢复正常步行
    - **协议缺口记录**：Cactus/Blover 弹出气球的特定交互需要在植物端实现
    - tags: `["archetype", "zombie", "original", "balloon", "flying"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现 Blover 全屏驱散（属于植物端能力）
  - 不得硬编码飞行到 ZombieRoot

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 14-20)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_BALLOON: body=270, flying=20, height=ZOMBIE_HEIGHT_FLYING
  - `data/combat/archetypes/zombies/archetype_air_scout.tres` — 飞行僵尸参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 气球被击破后落地
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 balloon zombie（air_unit_low）
      2. 攻击 balloon（20 HP）使 balloon 消亡
      3. 验证 zombie 降落到 ground_unit 高度
    Expected Result: balloon 消亡后 zombie 落地并继续步行
    Evidence: .sisyphus/evidence/task-13-balloon.txt
  ```

  **Commit**: YES (groups with Batch D)

- [ ] 14. **Jack-in-the-Box Zombie（小丑僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_jack_in_the_box.tres`
    - max_health: 500
    - move_speed_slots_per_sec: 0.67
    - 新增 mechanic `mechanic_original_jack_explode.tres`：
      - 使用 `Trigger/core.periodic`（确定性随机计时，通过 ShuffleBag）
      - 效果：倒计时结束后 `Payload/core.explode`（radius 覆盖植物 r=90 和僵尸 r=115）
      - 或使用 `Trigger/core.on_death`（被击杀时爆炸）
      - 5% 概率短引信（使用 battle_seed 派生的确定性随机）
    - tags: `["archetype", "zombie", "original", "jack_in_the_box", "explode"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得使用 OS.get_ticks_* 或 Timer（必须使用确定性随机）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13, 15-20)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_JACK_IN_THE_BOX: body=500, speed=0.66-0.68, explode radius zombie=115 plant=90
  - `data/combat/mechanics/mechanic_reactive_bomber_death_explode.tres` — 死亡爆炸参考
  - `scripts/core/runtime/shuffle_bag.gd` — 确定性随机

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 小丑僵尸爆炸造成范围伤害
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 jack_in_the_box + 周围多个目标
      2. 验证爆炸后范围内目标受到伤害
    Expected Result: 爆炸事件触发，范围内 entity.damaged 事件
    Evidence: .sisyphus/evidence/task-14-jack-box.txt
  ```

  **Commit**: YES (groups with Batch D)

- [ ] 15. **Digger Zombie（矿工僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_digger.tres`
    - max_health: 270（body）
    - health_layers: [HealthLayerDef(layer_id=&"digger_helm", layer_kind=&"helm", max_health=100, armor_type=&"DIGGER")]
    - move_speed_slots_per_sec: 0.67（地下穿行速度）
    - **协议缺口**：地下穿行需要新的 Movement 模式
      - 最小实现：使用 State mechanic 实现两个阶段
      - Phase 1 (underground)：从右侧出现，快速向左穿行（不可被攻击，liveness_overrides: targetable=false）
      - Phase 2 (emerged)：到达最左侧后出现，向右缓慢步行（speed=0.12），可被攻击
    - 新增 mechanic `mechanic_original_digger_tunnel.tres`（State: underground）
    - 新增 mechanic `mechanic_original_digger_emerge.tres`（到达左侧边界的 trigger）
    - tags: `["archetype", "zombie", "original", "digger", "underground"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得硬编码地下逻辑到 BattleManager

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要设计地下穿行的双阶段行为，涉及 liveness override、移动方向反转
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-14, 16-20)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_DIGGER: body=270, helm=100, tunnel speed=0.66-0.68, walk speed=0.12
  - `data/combat/mechanics/mechanic_original_snorkel_submerge.tres`（Task 10，状态切换参考）

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 矿工穿行后从左侧出现
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 digger（underground 状态）
      2. 验证不可被攻击
      3. 验证到达左侧后 emerge，可被攻击，向右移动
    Expected Result: underground 期间无敌，emerge 后正常
    Evidence: .sisyphus/evidence/task-15-digger.txt
  ```

  **Commit**: YES (groups with Batch D)

- [ ] 16. **Pogo Zombie（跳跳僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_pogo.tres`
    - max_health: 500
    - move_speed_slots_per_sec: 0.45
    - **协议缺口**：弹跳翻越需要类似 Pole Vault 的跳跃机制，但为持续性
      - 最小实现：使用 Movement family，后续新增 `hop_cycle` type
      - 行为：每接近一个植物时自动跳过
      - 跳跃次数：无限（直到被 Magnet-shroom 吸走弹簧，标记为后续迭代）
    - 新增 mechanic `mechanic_original_pogo_hop.tres`（Movement: hop_cycle，后续专项设计）
    - tags: `["archetype", "zombie", "original", "pogo", "jumper"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得硬编码弹跳逻辑到 BattleManager

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-15, 17-20)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_POGO: body=500, speed=0.45
  - `data/combat/mechanics/mechanic_original_pole_vaulter_vault.tres`（Task 8，跳跃模式参考）

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: Pogo 弹跳连续跳过多个植物
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 pogo + 3 个连续 wall_barrier
      2. 验证 pogo 依次跳过所有障碍
    Expected Result: pogo 跳过所有植物不被阻挡
    Evidence: .sisyphus/evidence/task-16-pogo.txt
  ```

  **Commit**: YES (groups with Batch D)

- [ ] 17. **Zombie Yeti（雪人僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_yeti.tres`
    - max_health: 1350
    - move_speed_slots_per_sec: 0.40
    - 新增 mechanic `mechanic_original_yeti_flee.tres`：
      - 使用 `Trigger/core.when_damaged` 监听首次受伤
      - 效果：反向移动速度变为 0.80（向右逃跑），标记 fleeing 状态
      - 逃跑持续一段时间后消失（或到达右侧边界后消失）
    - tags: `["archetype", "zombie", "original", "yeti", "flee", "rare"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现 Yeti 稀有生成逻辑（属于 WaveRunner 层面，记录为协议缺口）

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-16, 18-20)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_YETI: body=1350, walk speed=0.4, run speed=0.8
  - `data/combat/mechanics/mechanic_reactive_bomber_when_damaged.tres` — when_damaged 参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 雪人受伤后逃跑
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 yeti，攻击使其受伤
      2. 验证 yeti 反向移动（向右）
    Expected Result: 受伤后 yeti 向右逃跑，速度加快
    Evidence: .sisyphus/evidence/task-17-yeti.txt
  ```

  **Commit**: YES (groups with Batch D)

- [ ] 18. **Bungee Zombie（蹦极僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_bungee.tres`
    - max_health: 450
    - **协议缺口**：空降偷取植物需要新的 spawn + steal 机制
      - 最小实现：使用 Lifecycle.core.on_spawned + Payload 机制
      - Phase 1：从空中降落（spawn 在指定位置上方）
      - Phase 2：到达植物位置 → 触发 Payload（destroy_target + steal）
      - Phase 3：带着植物飞走（移动 + 消失）
      - Umbrella Leaf 阻挡标记为后续迭代
    - 新增 mechanic `mechanic_original_bungee_dive.tres`（Lifecycle: on_spawned，执行空降序列）
    - 新增 mechanic `mechanic_original_bungee_steal.tres`（Payload: destroy + 移除目标实体）
    - tags: `["archetype", "zombie", "original", "bungee", "air", "steal"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现 Umbrella Leaf 防护（植物端能力，后续迭代）

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要设计完整的空降→偷取→飞走行为序列，涉及新的 Lifecycle/Payload 组合
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-17, 19-20)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_BUNGEE: body=450, steals plants
  - `data/combat/mechanics/skeleton/mechanic_on_place_lifecycle.tres` — Lifecycle 参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 蹦极僵尸空降偷取植物
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 放置一个目标植物
      2. 生成 bungee zombie 指向该位置
      3. 验证 bungee 降落后目标植物被移除（entity.died 事件）
    Expected Result: 植物被偷走（destroyed），bungee 飞走后消失
    Evidence: .sisyphus/evidence/task-18-bungee.txt
  ```

  **Commit**: YES (groups with Batch D)

- [ ] 19. **Ladder Zombie（梯子僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_ladder.tres`
    - max_health: 500（body）
    - health_layers: [HealthLayerDef(layer_id=&"ladder", layer_kind=&"attachment", max_health=500, armor_type=&"LADDER")]
    - move_speed_slots_per_sec: 0.80（携带梯子时极快）
    - **协议缺口**：架梯越墙需要实体交互机制
      - 最小实现：梯子作为 shield 层（标准分层血量处理）
      - 架梯行为（放置 ladder 到 Tall-nut/Pumpkin 上方越过）标记为协议缺口延后
      - 当前 ladder 只作为额外 HP 层 + 快速移动
    - tags: `["archetype", "zombie", "original", "ladder", "armored"]`
  - 创建验证场景（验证高速度 + 梯子护甲层）
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现架梯越墙的完整交互

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-18, 20)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_LADDER: body=500, shield=500(LADDER), speed=0.79-0.81

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 梯子护甲层吸收伤害
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 ladder zombie
      2. 发送 500 伤害，验证 ladder 消亡，body 仍为 500
    Expected Result: ladder 消亡事件触发，body 不变
    Evidence: .sisyphus/evidence/task-19-ladder.txt
  ```

  **Commit**: YES (groups with Batch D)

- [ ] 20. **Catapult Zombie（投石车僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_catapult.tres`
    - max_health: 850
    - move_speed_slots_per_sec: 0.25（慢速）
    - 复用 ranged zombie pattern（类似 bone_thrower）
    - 新增 projectile_template `projectile_template_basketball.tres`：
      - damage: 75
      - movement: parabola（抛物线）
      - tags: `["projectile", "basketball", "zombie"]`
    - mechanics:
      - `skeleton/mechanic_periodic_no_targeting.tres`（周期触发）
      - `skeleton/mechanic_targeting_lane_backward.tres`（反向瞄准植物）
      - 新增 `mechanic_original_catapult_payload.tres`（Payload: spawn_projectile with basketball）
    - tags: `["archetype", "zombie", "original", "catapult", "ranged", "vehicle"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得硬编码投石逻辑

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 13-19)
  - **Parallel Group**: Wave 4
  - **Blocks**: None
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_CATAPULT: body=850, basketball damage=75
  - `data/combat/archetypes/zombies/archetype_bone_thrower.tres` — 远程僵尸完整参考
  - `data/combat/mechanics/mechanic_projectile_payload_bone.tres` — projectile payload 参考
  - `data/combat/projectile_templates/bone_linear.tres` — 投射物模板参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 投石车远程抛射命中植物
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 catapult + 远处 wall_barrier 目标
      2. 验证 projectile.spawned + entity.damaged（75 伤害）
    Expected Result: basketball 命中目标造成 75 伤害
    Evidence: .sisyphus/evidence/task-20-catapult.txt
  ```

  **Commit**: YES (groups with Batch D)

- [ ] 21. **Dancing Zombie（舞王僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_dancing.tres`
    - max_health: 500
    - move_speed_slots_per_sec: 0.45
    - 新增 mechanic `mechanic_original_dancing_summon.tres`：
      - 使用 `Trigger/core.periodic`（周期触发召唤）
      - 效果：`Payload/core.spawn_entity` 生成 4 个 Backup Dancer（上/下/左/右各一个）
      - 首次停止后触发一次召唤（可使用 on_spawned + delay 实现）
    - 新增 mechanic `mechanic_original_dancing_controller.tres`：
      - 使用 Movement + State side-effects 表达 moonwalk 行为（向后移动到舞台中央，然后开始召唤）
      - 到达指定位置后停止移动
    - tags: `["archetype", "zombie", "original", "dancing", "spawner"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得硬编码召唤逻辑到 BattleManager

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要设计召唤行为（spawn_entity payload）+ 停止/移动切换
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 22-25)
  - **Parallel Group**: Wave 5
  - **Blocks**: Task 22 (Backup Dancer)
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_DANCER: body=500, speed=0.45, spawns 4 BackupDancers
  - `autoload/EffectRegistry.gd` — spawn_entity 效果策略

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 舞王僵尸召唤 4 个伴舞僵尸
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 dancing zombie
      2. 验证 4 个 entity.spawned 事件（archetype_original_backup_dancer）
    Expected Result: 4 个 backup dancer 在舞王周围生成
    Evidence: .sisyphus/evidence/task-21-dancing.txt
  ```

  **Commit**: YES (groups with Batch E)

- [ ] 22. **Backup Dancer（伴舞僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_backup_dancer.tres`
    - 与 Basic Zombie 结构相同
    - max_health: 270
    - move_speed_slots_per_sec: 0.45
    - mechanics: 复用 bite_controller
    - tags: `["archetype", "zombie", "original", "backup_dancer", "spawned"]`
  - 创建验证场景（验证被召唤后的基本行为）
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现独立的召唤逻辑（仅被 Dancing Zombie 生成）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 23-25, after Task 21 archetype exists)
  - **Parallel Group**: Wave 5
  - **Blocks**: None
  - **Blocked By**: Task 21（需要 Dancing Zombie 的 spawn_entity 引用此 archetype_id）

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_BACKUP_DANCER: body=270, speed=0.45
  - `data/combat/archetypes/zombies/archetype_original_basic_zombie.tres` — 结构参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 伴舞僵尸被召唤后正常咬击
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 直接生成 backup_dancer + 前方 wall_barrier
      2. 验证咬击行为
    Expected Result: verdict = "passed"
    Evidence: .sisyphus/evidence/task-22-backup-dancer.txt
  ```

  **Commit**: YES (groups with Batch E)

- [ ] 23. **Gargantuar（巨人僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_gargantuar.tres`
    - max_health: 3000
    - move_speed_slots_per_sec: 0.25
    - hit_height_band: ground_unit_large
    - hitbox_size: 2x2 范围
    - 新增 mechanic `mechanic_original_gargantuar_smash.tres`：
      - 使用 Controller family，新增 type `core.smash`
      - 行为：每帧检测前方植物，接触即碾压（instant kill）
    - 新增 mechanic `mechanic_original_gargantuar_throw.tres`：
      - 使用 `Trigger/core.when_damaged` 监听 HP ≤ 50%
      - 效果：`Payload/core.spawn_entity` 生成 Imp（抛向左半场随机位置）
      - 仅触发一次（使用 status 标记已投掷）
    - tags: `["archetype", "zombie", "original", "gargantuar", "boss", "crush", "spawner"]`
  - 创建验证场景（验证碾压 + HP 触发投掷 Imp）
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得硬编码碾压/投掷到 BattleManager
  - 不得创建新的 Mechanic family

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 需要设计碾压控制器 + HP 阈值触发投掷的组合行为
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 21-22, 24-25)
  - **Parallel Group**: Wave 5
  - **Blocks**: Tasks 24, 25
  - **Blocked By**: None

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_GARGANTUAR: body=3000, smash instant-kill, throw Imp at ≤50%
  - `data/combat/mechanics/skeleton/mechanic_bite_controller.tres` — Controller 注册参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 巨人碾压植物
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 gargantuar + wall_barrier
      2. 验证碾压（entity.died 即时死亡）
    Expected Result: 植物被秒杀，gargantuar 不受阻挡
    Evidence: .sisyphus/evidence/task-23-gargantuar-smash.txt

  Scenario: HP ≤50% 时投掷 Imp
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 gargantuar (3000HP)
      2. 造成 1500 伤害
      3. 验证 entity.spawned（imp）
    Expected Result: Imp 被生成，且仅触发一次
    Evidence: .sisyphus/evidence/task-23-gargantuar-throw.txt
  ```

  **Commit**: YES (groups with Batch E)

- [ ] 24. **Imp（小鬼僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_imp.tres`
    - max_health: 70
    - move_speed_slots_per_sec: 0.90（极快）
    - mechanics: 复用 bite_controller
    - tags: `["archetype", "zombie", "original", "imp", "spawned", "fast"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得实现独立的投掷逻辑（仅被 Gargantuar 投掷生成）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 21-22, 25)
  - **Parallel Group**: Wave 5
  - **Blocks**: None
  - **Blocked By**: Task 23（需要 Gargantuar 的 spawn_entity 引用此 archetype_id）

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_IMP: body=70, speed=0.9
  - `data/combat/archetypes/zombies/archetype_basic_walker.tres` — 结构参考

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: Imp 快速移动并咬击
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 直接生成 imp + wall_barrier
      2. 验证快速接近 + 咬击
    Expected Result: verdict = "passed"，到达时间明显快于 basic zombie
    Evidence: .sisyphus/evidence/task-24-imp.txt
  ```

  **Commit**: YES (groups with Batch E)

- [ ] 25. **Redeye Gargantuar（红眼巨人僵尸）**

  **What to do**:
  - 创建 `data/combat/archetypes/zombies/archetype_original_redeye_gargantuar.tres`
    - 与 Gargantuar 结构相同但 HP 翻倍
    - max_health: 6000
    - 复用 Gargantuar 的所有 mechanic（smash + throw）
    - tags: `["archetype", "zombie", "original", "gargantuar", "redeye", "boss", "crush", "spawner"]`
  - 创建验证场景
  - 添加到 `tools/validation_scenarios.json`

  **Must NOT do**:
  - 不得创建新的 Mechanic type（完全复用 Gargantuar 的 mechanic）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 21-22, 24)
  - **Parallel Group**: Wave 5
  - **Blocks**: None
  - **Blocked By**: Task 23（依赖 Gargantuar mechanic 资源）

  **References**:
  - `vendor/de-pvz/Lawn/Zombie.cpp` — ZOMBIE_REDEYE_GARGANTUAR: body=6000
  - `data/combat/archetypes/zombies/archetype_original_gargantuar.tres`（Task 23，直接参考）

  **Acceptance Criteria**:

  **QA Scenarios:**

  ```
  Scenario: 红眼巨人拥有双倍 HP
    Tool: Bash (pwsh tools/run_validation.ps1)
    Steps:
      1. 生成 redeye gargantuar
      2. 造成 3000 伤害
      3. 验证 HP ≤50% 时投掷 Imp
    Expected Result: 3000 伤害后仍存活，投掷 Imp
    Evidence: .sisyphus/evidence/task-25-redeye.txt
  ```

  **Commit**: YES (groups with Batch E)

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE.
> Do NOT auto-proceed after verification. Wait for user's explicit "okay" before completing.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run validation). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run full validation suite `pwsh tools/run_all_validations.ps1`. Review all changed files for: `as any`/`@ts-ignore` equivalents in GDScript, empty catches, `print()` in prod (must use DebugService), commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names. Verify no BattleManager特判 added.
  Output: `Build [PASS/FAIL] | Validations [N/N pass] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-batch integration (zombies interacting with original plants). Test edge cases: zombie with layered health taking armor-specific damage, Gargantuar throwing Imp near plants. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes. Verify no Mechanic family was added (only new types under existing families).
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Wave 0**: `feat(zombie): add infrastructure protocol supplements` — health_layer_def.gd, MovementRegistry, HealthComponent, MovementComponent, StateComponent, EffectRegistry, validation scenes
- **Batch A**: `feat(zombies): add original batch A — basic melee zombies` — 4 archetypes + mechanics + validations
- **Batch B**: `feat(zombies): add original batch B — movement/shield zombies` — 4 archetypes + mechanics + validations
- **Batch C**: `feat(zombies): add original batch C — pool/water zombies` — 4 archetypes + mechanics + validations
- **Batch D**: `feat(zombies): add original batch D — complex behavior zombies` — 8 archetypes + mechanics + validations
- **Batch E**: `feat(zombies): add original batch E — giants & spawned zombies` — 5 archetypes + mechanics + validations
- Each commit: `pwsh tools/run_all_validations.ps1 -Layers smoke,core` must pass

---

## Success Criteria

### Verification Commands
```powershell
# 全量验证
pwsh tools/run_all_validations.ps1
# Expected: ALL PASS (145+ existing + ~30 new = 175+ scenarios)

# 单僵尸验证（示例）
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/zombie_original_basic_zombie_validation.tres"
# Expected: PASS

# 分层血量验证
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/health_layer_helm_routing_validation.tres"
# Expected: PASS

# 守卫检查
pwsh tools/check_no_legacy_entity_model.ps1
# Expected: PASS (no legacy patterns)
```

### Final Checklist
- [ ] All 25 original zombie archetypes exist in `data/combat/archetypes/zombies/`
- [ ] All archetypes use `ZombieArchetype` class (entity_kind = &"zombie")
- [ ] Layered health system works for body/helm/shield (7 zombies verified)
- [ ] Each zombie has at least 1 passing validation scenario
- [ ] Each batch has at least 1 passing batch validation scenario
- [ ] `tools/validation_scenarios.json` updated with all new scenarios
- [ ] `tools/formal_content_validation_map.json` updated with zombie_original group
- [ ] No single-zombie hardcoded logic in BattleManager or entity scripts
- [ ] No new Mechanic families added (only new types under existing families)
- [ ] All "Must NOT Have" items absent
- [ ] Existing test zombies (basic_walker etc.) unchanged
