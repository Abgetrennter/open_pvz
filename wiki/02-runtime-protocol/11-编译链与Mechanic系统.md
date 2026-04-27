# 编译链与 Mechanic 系统

- 状态：当前事实

> 本文描述当前正式内容入口如何从 `Archetype + Mechanic[]` 编译为运行时可消费的 `RuntimeSpec`。决策边界来自 [ADR-002](../decisions/ADR-002-顶层作者模型与编译链.md)、[ADR-003](../decisions/ADR-003-Mechanic-一级家族冻结.md)、[ADR-004](../decisions/ADR-004-连续行为-状态与生命周期正式化.md)、[ADR-005](../decisions/ADR-005-扩展包接入与迁移策略.md)。

---

## 文档定位

本文主要回答：

- 当前唯一正式作者入口是什么。
- 10 个一级 family 如何理解。
- 编译链如何把 archetype 变成 `RuntimeSpec`。
- legacy 兼容层当前处于什么位置。

本文不负责：

- 替代各 family 的字段级协议说明。
- 重讲历史阶段切换。
- 把 legacy 模型重新写成正式作者入口。

---

## 当前正式作者模型

当前唯一正式顶层入口是：

> `CombatArchetype + CombatMechanic[]`

Archetype 负责定义：

- 实体身份
- 场景与组件
- 基础战斗属性
- 放置语义
- 默认投射体资源
- 编译提示与默认参数

Mechanic 负责定义：

- 离散行为入口
- 连续行为
- 状态与生命周期
- 攻击链各 family 的组合

legacy 资源当前仍存在，但只承担：

- 兼容层
- 后端素材层
- 迁移对照层

---

## 10 个冻结 family

当前冻结的一级 family 为：

1. `Trigger`
2. `Targeting`
3. `Emission`
4. `Trajectory`
5. `HitPolicy`
6. `Payload`
7. `State`
8. `Lifecycle`
9. `Placement`
10. `Controller`

当前正文统一按下面口径理解：

- `family` 是一级行为维度，只能通过 ADR 新增。
- `type` 是 family 下的实现族，可由主仓和扩展包在受控边界内继续扩展。
- `param` 是具体 type 的配置参数。

扩展包默认只能新增 `type`，不能新增 `family`。

---

## 当前编译覆盖判断

当前正文按 `10/10` family 已建立正式编译覆盖理解：

- `Trigger`
- `Targeting`
- `Emission`
- `Trajectory`
- `HitPolicy`
- `Payload`
- `State`
- `Lifecycle`
- `Placement`
- `Controller`

其中 `Placement` 当前已完成第一轮正式收口：

- compiler callable 已固定
- `RuntimeSpec.placement_spec` 已固定
- `BattleCardState / BattleBoardState` 已消费该 spec
- `archetype_field` fallback 已有验证
- 多 Placement mechanic guardrail 已有验证

---

## 编译链全貌

```text
CombatArchetype + CombatMechanic[]
            │
            ▼
NormalizedMechanicSet
            │
            ▼
RuntimeSpec
            │
            ▼
EntityFactory.instantiate_runtime_spec()
            │
            ▼
运行时节点 + 组件 + compiled triggers / controllers / states
```

### 1. Normalize

`MechanicCompiler.normalize_archetype()` 负责：

- 过滤禁用 mechanic
- 按优先级排序
- 合并 archetype 默认参数与编译提示
- 收集编译警告

### 2. Compile

`MechanicCompiler.compile_spawn_entry()` 负责：

- 通过 `MechanicCompilerRegistry` 按 `family.type_id` 分发
- 组装 `RuntimeSpec`
- 生成 trigger、controller、state 等运行时规格

### 3. Instantiate

`EntityFactory` 负责：

- 优先消费 `RuntimeSpec`
- 构建运行时节点与组件
- 绑定 controller、state、compiled trigger bindings

---

## 当前运行时关键对象

### `RuntimeSpec`

当前作为编译链的稳定中间层，承载：

- 实体身份与根场景
- 战斗属性
- 投射体配置
- compiled trigger bindings
- controller specs
- state specs
- placement spec
- mechanic runtime state

### 注册中心

当前主干中的关键注册中心包括：

- `MechanicFamilyRegistry`
- `MechanicTypeRegistry`
- `MechanicCompilerRegistry`
- `ControllerRegistry`
- `DetectionRegistry`
- `TriggerRegistry`
- `EffectRegistry`

---

## legacy 兼容层当前定位

当前仓库事实是：

- `data/combat/archetypes/` 下当前仍有 `48` 个 archetype 带有 `backend_entity_template*` 字段。
- `EntityFactory` 仍保留旧路径兜底。
- `data/combat/entity_templates/` 与 `data/combat/trigger_bindings/` 仍在仓库中。

但这些事实不改变当前正文口径：

- 它们不是正式作者入口。
- 它们只说明 legacy 收口尚未完成。
- 后续路线是继续收紧兼容层，而不是重新扩大双轨。

---

## 当前写文档时的硬约束

任何正文页如果提到 `EntityTemplate / TriggerBinding`，都必须同时满足：

1. 明确标注其为 legacy/兼容层。
2. 不再把它写成新增内容的正式入口。
3. 不与 ADR-002、ADR-005 的结论冲突。

---

## 相关文档

- [当前阶段与实现路线](../01-overview/23-当前阶段与实现路线.md)
- [开发路线图](../04-roadmap-reference/26-开发路线图.md)
- [战斗模式组织层](14-战斗模式组织层.md)
- [触发器系统](03-触发器系统.md)
- [效果系统](04-效果系统.md)
- [验证矩阵](../03-content-validation/32-验证矩阵.md)
