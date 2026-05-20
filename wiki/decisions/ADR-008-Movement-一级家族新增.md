# ADR-008 Movement 一级家族新增

- 状态：提议中
- 日期：2026-05-20
- 作者：Sisyphus / Abget
- 关联阶段：原版僵尸复刻
- 关联文档：
  - [ADR-003 Mechanic 一级家族冻结](ADR-003-Mechanic-一级家族冻结.md)
  - [ADR-004 连续行为、状态与生命周期正式化](ADR-004-连续行为-状态与生命周期正式化.md)
  - [编译链与 Mechanic 系统](../02-runtime-protocol/11-编译链与Mechanic系统.md)
  - [连续行为模型](../02-runtime-protocol/08-连续行为模型.md)
  - [原版实体复刻工作流](../05-governance/36-原版实体复刻工作流.md)
- 关联实现：
  - `scripts/entities/zombie_root.gd`（运动逻辑需重构）
  - `scripts/components/movement_component.gd`（需扩展）
  - `scripts/battle/entity_factory.gd`（编译链需接入）
  - 未来新增 `MovementRegistry` autoload
  - 未来新增 `MovementComponent` 增强或替代
- 关联验证：
  - Movement type 策略专项验证
  - 现有 zombie 验证场景回归
  - 僵尸原型行为验证

## 1. 决策摘要

在 10 个冻结 family 基础上，正式新增第 11 个一级 family `Movement`，专门承载实体**自主运动控制**——方向、速度、位移模式、高度变化。

现有 `Controller` 的职责聚焦为"每帧行为逻辑"（检测→攻击），`Movement` 聚焦为"每帧运动属性"（位置→方向→速度→模式）。两者组合使用，不再混合。

## 2. 背景与问题

### 2.1 当前 family 的植物偏向

ADR-003 冻结的 10 个 family 是围绕**植物攻击链**设计的：

```
Trigger → Targeting → Emission → Trajectory → HitPolicy → Payload
  + State / Lifecycle / Placement / Controller（自身管理）
```

植物是**静态发射者**——待在原地、检测敌人、发射抛射体。`Controller` 在植物侧只用于 `core.bite`（近战咬击）和 `core.ground_damage`（地刺），本质上仍是"检测→攻击"的行为逻辑。

### 2.2 僵尸的运动特征

僵尸是**自主移动实体**，其核心行为特征与植物有本质区别：

| 植物特征 | 僵尸特征 |
|---------|---------|
| 静态，不移动 | **自主移动**是核心行为 |
| 单一攻击模式 | **多阶段行为序列**（接近→特殊能力→攻击→死亡） |
| 攻击链是固定循环 | **运动方式可变**（走/跳/弹/钻/飞/碾） |
| 状态简单（alive→dying） | **运动属性可突变**（撑杆弃杆、报纸狂暴、雪人逃跑） |

### 2.3 当前代码中运动硬编码

当前 `ZombieRoot.simulation_step()` 将运动硬编码为单向左行：

```gdscript
# zombie_root.gd:95 — 所有僵尸只向左走
movement_component.velocity = Vector2.LEFT * effective_move_speed
```

原版 PVZ 中 25 种僵尸需要至少 7 种不同的运动模式：

| 运动模式 | 适用僵尸 | 与现有 Controller 的冲突 |
|---------|---------|------------------------|
| 标准步行（左行） | 大部分僵尸 | 无冲突 |
| 单次跳越（位移+无敌窗口） | Pole Vaulter, Dolphin Rider | 不是"每帧行为"，是瞬发位移 |
| 周期弹跳（跳越障碍） | Pogo | Controller 无法表达高度变化 |
| 地下穿行（不可攻击+到边转换） | Digger | 需要修改运动方向 |
| 飞行→落地（高度切换） | Balloon | 需要切换 height_band |
| 碾压前进（接触即杀+减速曲线） | Zamboni | ground_damage 接近但缺少减速曲线 |
| 反向逃跑 | Yeti | 需要修改运动方向 |

### 2.4 为什么不能塞进 Controller

如果为每种运动创建 `Controller/core.vault`、`Controller/core.bounce` 等，存在三个问题：

1. **关注点混合**：Controller 内部会同时重写运动逻辑（位移+高度+方向）和行为逻辑（检测→攻击），违反单一职责
2. **基础设施耦合**：运动修改影响 spatial_query、liveness、hitbox 等基础设施，不应封装在策略 callable 里
3. **组合性丧失**：僵尸需要同时有"怎么移动"和"做什么攻击"两个维度——当前 Controller 只有一个维度

## 3. 目标

1. 为自主移动实体提供正式的运动控制能力位。
2. 将运动关注点从 Controller/ZombieRoot 中分离出来。
3. 支持 7+ 种运动 type，覆盖原版 PVZ 25 种僵尸的运动需求。
4. 与现有 State/Controller/Lifecycle 组合使用，不破坏已冻结的 10 个 family。
5. 为 EntityFactory 编译链新增 Movement 编译路径。

## 4. 非目标

本次决策不直接冻结：

- 每个 Movement type 的完整参数字段
- Movement 与视觉动画的绑定方式
- 水面/泳池运动模式的完整语义（标记为后续迭代）
- Movement type 的扩展包接入规则（复用通用 RegistryBase 模式）

## 5. 备选方案

### 方案 A：继续在 Controller 下新增 type

将 vault/bounce/tunnel 等全部实现为 `Controller/core.*` type。

优点：
- 不新增 family，ADR-003 冻结不被打破
- ControllerRegistry 已有 callable 策略机制，可直接复用

缺点：
- Controller 的语义变成"行为逻辑 + 运动控制"混合体，丧失单一职责
- vault/bounce 策略内部需要直接修改 `owner.position`，与 MovementComponent 的 velocity 系统冲突
- State 切换无法独立控制"切换运动模式"——切换 state 时只能整体替换 controller spec，无法单独换运动
- 违反 ADR-004 第 6.1 节对 Controller 的定义："咬、扫掠、跳跃攻击、冲锋、潜水、其他每帧持续状态机"——这些是行为，不是运动

未选原因：
- 会将运动控制逻辑散布在 Controller 策略 callable 中，导致不可组合、不可独立测试
- 僵尸需要在"咬击"(Controller)的同时"弹跳"(Movement)，两者必须独立

### 方案 B：新增 Movement 一级 family

优点：
- 职责清晰：Controller = 行为策略（检测→攻击），Movement = 运动属性（位置→方向→速度→模式）
- 可组合：一个实体同时有 1 个 Movement type + 1 个 Controller type
- State 切换可以触发 Movement type 替换（潜水→浮出 = movement 从 tunnel 切换为 walk）
- 基础设施友好：Movement 输出的是物理属性（velocity, direction, height），spatial_query/liveness 可直接消费
- 为未来更多移动实体（如推车、Boss 移动）预留扩展空间

缺点：
- 需要新增 ADR 打破 ADR-003 的 10 family 冻结
- 需要新增 MovementRegistry autoload + 编译路径
- ZombieRoot 需要重构：将运动逻辑从 simulation_step 提取到 Movement 系统

选择原因：
- 这是唯一能干净支持"同时组合运动+行为"的方案
- ADR-003 明确预留了"新增 family 需走 ADR"的通道，这正是该通道的正确使用场景

### 方案 C：扩展 State 以包含运动控制

在 State 转换时附带 movement_overrides（方向、速度、模式）。

优点：
- 不新增 family
- State 已经支持 per-state liveness override，概念统一

缺点：
- State 变成"状态 + 运动"混合体
- 无法表达"同一状态下的运动渐变"（如 Zamboni 的减速曲线）
- 无法独立于状态控制运动（如 Pole Vaulter 在 vault 状态期间的复杂位移轨迹需要独立控制）

未选原因：
- 运动是持续物理过程，不是状态标记。将运动编码为状态会导致状态爆炸。

## 6. 最终决策

### 6.1 新增 Movement 一级 family

正式新增第 11 个一级 family：

```
Movement
```

职责：**实体如何移动**——方向、速度、位移模式、高度变化。

### 6.2 Movement 与 Controller 的边界

| 维度 | Movement | Controller |
|------|----------|------------|
| 语义 | 实体**怎么移动** | 实体**做什么行为** |
| 输出 | velocity, direction, position delta | 攻击/检测/效果触发 |
| 消费者 | MovementComponent, spatial_query | TriggerComponent, EffectExecutor |
| 组合性 | 同一时刻 1 个活跃 Movement | 同一时刻可多个 Controller |
| 切换方 | State 转换触发 Movement type 替换 | State 转换可启用/禁用 Controller |

**关键区别**：Controller 表达的是"策略行为"（检测到目标→攻击），Movement 表达的是"运动属性"（以什么速度向什么方向移动）。当 Pole Vaulter 咬击时（Controller 暂停运动），它仍然知道自己的 Movement 模式是"步行"——只是当前被 Controller 信号暂停了位移。

### 6.3 初始 type 清单

定义以下 `core.*` type：

| type_id | 语义 | 适用僵尸 | 关键参数 |
|---------|------|---------|---------|
| `core.walk` | 标准地面左行 | 大部分僵尸 | `move_speed_slots_per_sec`, `direction` (默认 -1) |
| `core.vault` | 单次跳越（瞬发位移+无敌窗口） | Pole Vaulter, Dolphin Rider | `jump_distance_slots`, `invulnerable_duration`, `post_vault_speed` |
| `core.bounce` | 周期弹越障碍 | Pogo | `bounce_height`, `bounce_interval`, `can_bounce_over_tags` |
| `core.tunnel` | 地下穿行（不可攻击） | Digger | `tunnel_speed`, `emerge_x`, `post_emerge_speed`, `post_emerge_direction` (+1) |
| `core.fly` | 空中飞行 | Balloon | `fly_speed`, `fly_height_band` (air_unit_low) |
| `core.drive` | 碾压前进（接触伤害+减速曲线） | Zamboni | `initial_speed`, `deceleration_curve`, `crush_damage` |
| `core.reverse_walk` | 反向步行 | Yeti (逃跑阶段) | `move_speed_slots_per_sec`, `direction` (+1) |
| `core.submerge` | 潜水移动 | Snorkel | `submerge_speed`, `surface_range` |

> 注：初始 type 清单是**建议范围**，实施时可根据编译链实际需求微调。type 可在实施阶段按需扩展。

### 6.4 Movement 与 State 的协作

State 转换可以触发 Movement type 替换：

```
State: underground → emerged
  → Movement: tunnel → walk (speed=0.12, direction=+1)

State: flying → grounded  
  → Movement: fly → walk (speed=0.28)

State: calm → enraged (Newspaper)
  → Movement: walk → walk (speed=0.89)  // 同 type，参数 override

State: approaching → fleeing (Yeti)
  → Movement: walk → reverse_walk (speed=0.80)
```

实现方式：State transition 定义中新增可选字段 `movement_override`：

```gdscript
{
  "from_state": "underground",
  "to_state": "emerged",
  "trigger": "event",
  "event_name": "entity.state_entered",
  "movement_override": {
    "type": "core.walk",
    "params": {"move_speed_slots_per_sec": 0.12, "direction": 1}
  }
}
```

### 6.5 Movement 与 Controller 的组合示例

| 僵尸 | Movement | Controller | State |
|------|----------|------------|-------|
| Normal | `core.walk` | `core.bite` | — |
| Pole Vaulter | `core.vault` → `core.walk` | `core.bite` (post-vault) | vaulting → walking |
| Pogo | `core.bounce` | — (bounce 本身是运动) | bouncing → grounded (magnet) |
| Digger | `core.tunnel` → `core.walk(dir=+1)` | `core.bite` (post-emerge) | underground → emerged |
| Balloon | `core.fly` → `core.walk` | `core.bite` (post-land) | flying → grounded |
| Zamboni | `core.drive` | — (drive 包含碾压) | — |
| Snorkel | `core.submerge` → `core.walk` | `core.bite` (surfaced) | submerged → surfaced |
| Yeti | `core.walk` → `core.reverse_walk` | `core.bite` | calm → fleeing |

### 6.6 编译链扩展

Movement 编译在 EntityFactory 中的位置：

```
CombatArchetype + CombatMechanic[]
  → NormalizedMechanicSet
  → RuntimeSpec
    + movement_spec: {type_id, params, transitions[]}
    + trigger_specs[]
    + controller_specs[]
    + state_specs[]
    + ...
  → EntityFactory.instantiate_runtime_spec()
    → 绑定 MovementComponent specs
    → 绑定 ControllerComponent specs
    → 绑定 StateComponent specs (含 movement_override)
```

MechanicCompiler 为 Movement family 注册编译 callable：

```gdscript
# 在 MechanicCompilerRegistry._register_builtin_compilers() 中
register_compiler("Movement.core.walk", _compile_walk_movement)
register_compiler("Movement.core.vault", _compile_vault_movement)
# ... 以此类推
```

### 6.7 MovementRegistry

新增 `MovementRegistry` autoload，继承 `RegistryBase`，遵循通用扩展插槽模式（与 ControllerRegistry、DetectionRegistry 等一致）。

### 6.8 向后兼容

- **不修改现有 Plant 的行为**：植物不使用 Movement family（植物不移动）
- **不修改现有测试僵尸**：basic_walker、brisk_runner 等继续使用硬编码左行，直到显式迁移
- **Movement 为可选组件**：ZombieRoot 检测 movement_spec 是否存在，不存在时 fallback 到当前硬编码行为
- **分阶段迁移**：先实现 Movement 系统 + `core.walk`，验证回归通过；再逐步迁移现有僵尸和新增特殊 Movement type

## 7. 影响范围

### 脚本

| 文件 | 影响 |
|------|------|
| `autoload/MechanicFamilyRegistry.gd` | 新增 Movement 到冻结列表 |
| `autoload/MovementRegistry.gd` | **新增** autoload |
| `autoload/ControllerRegistry.gd` | 无修改 |
| `scripts/core/defs/combat_mechanic.gd` | ALLOWED_FAMILIES 新增 Movement |
| `scripts/core/runtime/mechanic_compiler.gd` | 新增 Movement family 编译路径 |
| `scripts/entities/zombie_root.gd` | simulation_step 重构：优先使用 Movement 输出，fallback 硬编码 |
| `scripts/components/movement_component.gd` | 扩展：支持 direction、mode、MovementRegistry 策略驱动 |
| `scripts/battle/entity_factory.gd` | 编译链接入 movement_spec |
| `scripts/components/state_component.gd` | 扩展：_execute_transition 支持 movement_override |

### Resource

| 文件 | 影响 |
|------|------|
| `data/combat/mechanics/*.tres` | 新增 Movement mechanic 资源 |
| `data/combat/archetypes/zombies/*.tres` | 新增 movement 字段引用 |
| `project.godot` | 新增 MovementRegistry autoload |

### 验证

| 场景 | 类型 |
|------|------|
| `movement_walk_validation.tres` | smoke：验证 core.walk 左行 |
| `movement_vault_validation.tres` | core：验证跳越位移+无敌+速度切换 |
| `movement_regression_validation.tres` | smoke：现有僵尸行为不变 |
| 各僵尸原型行为验证 | core |

### 文档

| 文档 | 影响 |
|------|------|
| `wiki/decisions/README.md` | 新增 ADR-008 |
| `wiki/02-runtime-protocol/11-编译链与Mechanic系统.md` | 更新 family 列表为 11 个 |
| `wiki/02-runtime-protocol/08-连续行为模型.md` | 新增 Movement 章节 |
| `AGENTS.md` | 更新 autoload 清单、family 数量 |

## 8. 迁移与兼容

### 阶段 1（最小可用）

1. 新增 MovementRegistry autoload
2. 实现 `core.walk` type（等价当前硬编码行为）
3. ZombieRoot 新增 movement_spec 检测，无 spec 时 fallback 到硬编码
4. 验证：现有所有僵尸验证场景回归通过

### 阶段 2（僵尸原型）

5. 实现 `core.vault`、`core.bounce`、`core.tunnel` 等特殊 type
6. StateComponent 扩展 movement_override 支持
7. 逐个僵尸原型创建 archetype + 验证场景

### 兼容期

- 阶段 1 到阶段 2 之间，现有僵尸可继续使用硬编码运动
- 新建僵尸原型应使用 Movement family
- 兼容期无截止时间，但建议在僵尸复刻 Batch B（Pole Vaulter）之前完成阶段 1

## 9. 验证方式

### 回归验证

```powershell
pwsh tools/run_all_validations.ps1
```

所有现有验证场景必须继续通过。

### Movement smoke 测试

新增 3 个验证场景：

1. `movement_walk_validation`：僵尸使用 `Movement.core.walk` 从右向左移动，到达目标 x 位置
2. `movement_vault_validation`：僵尸使用 `Movement.core.vault` 跳越障碍物
3. `movement_regression_validation`：无 movement_spec 的僵尸（basic_walker）行为与当前一致

### 完成信号

1. MechanicFamilyRegistry.list_family_ids() 返回 11 个 family（含 Movement）
2. MovementRegistry autoload 正常注册
3. Movement mechanic 可编译到 RuntimeSpec
4. 现有僵尸验证回归通过
5. 至少 1 个新 Movement type 有验证场景覆盖

## 10. 风险与未决项

### 风险

1. **Movement 与 Controller 的执行顺序**：Movement 先更新位置，Controller 再检测目标——顺序需在 EntityFactory/编译链中明确
2. **Movement 与 MovementComponent 的关系**：当前 MovementComponent 仅做 velocity→position 映射，Movement family 需要接管 velocity 的产生逻辑
3. **跳越/弹跳的视觉表现**：Movement 控制逻辑位置，但跳越高度变化需要视觉系统配合——需明确边界

### 未决项

1. Movement type 的完整参数协议（各 type 的必选/可选参数）
2. Movement 与 height_band 切换的精确交互（Balloon 飞行→落地时 height_band 谁改？）
3. Movement 视觉反馈由 Movement 自己发射事件还是由 State 发射
4. 水面运动（swim）是否作为独立 Movement type 还是 walk 的参数变体

## 11. 后续动作

1. 在 `MechanicFamilyRegistry._register_builtin_families()` 中新增 `Movement`
2. 新增 `autoload/MovementRegistry.gd`，继承 RegistryBase
3. 在 `combat_mechanic.gd` 的 `ALLOWED_FAMILIES` 中新增 Movement
4. 实现 `Movement.core.walk` 策略和编译 callable
5. 扩展 `ZombieRoot.simulation_step()` 以消费 Movement 输出
6. 新增 smoke 验证场景
7. 回写 wiki 文档更新 family 数量

## 12. 文档影响矩阵

| 文档 | 是否受影响 | 回写动作 | 说明 |
|------|-----------|---------|------|
| 当前阶段与实现路线 | 是 | 更新 family 数量为 11 | |
| 编译链与 Mechanic 系统 | 是 | 更新 family 列表和编译链描述 | |
| 连续行为模型 | 是 | 新增 Movement 与 Controller 的边界说明 | |
| 验证矩阵 | 是 | 新增 Movement 验证场景条目 | |
| 术语表 | 是 | 新增 Movement family 术语 | |
| ADR-003 | 是 | 标注已由 ADR-008 扩展 | |
| AGENTS.md | 是 | 更新 autoload 清单和 family 数量 | |
