# GridItem 子系统设计草案

> 日期：2026-05-19
> 状态：概念草案（已按 2026-05-19 代码审查修订），供设计评审与后续 spike 使用
> 关联主题：棋盘多样性、BoardSlot 角色占位、Mechanic-first 架构、战斗模式系统
> 前置文档：棋盘多样性与地形系统设计草案（Phase 4 预留）

---

## 审查修订记录

本次修订基于当前代码现状收紧了落地边界：

- 新增 `GridItemRoot` 不再只是可选项。它的核心职责是格子生命周期、BoardSlot 释放和 GridItem 调试状态；`take_damage()` 只作为扩展型可破坏 GridItem 的可选桥接，不再作为墓碑/罐子的原版基线。
- 阻挡型 GridItem 第一版建议同时占用 `grid_item` role 和现有 `blocker` role，复用当前放置验证与 Grave Buster 的 `placement_blocker` 目标路径。
- 不再建议用粗粒度 `blocks_planting` tag 直接拒绝所有植物；这会把 Grave Buster 这类交互型植物一并拒绝。
- GridItem 的生成入口改为 `BattleGridItemState + spawn_grid_item/remove_grid_item`，不要求现有 `spawn_entity` 直接支持 field_object。
- 现有 `archetype_tombstone_blocker` 是 `plant + blocker` 的过渡资源，迁移为 GridItem 时必须保留专门兼容验证。
- 割草机不再作为 `EntityFactory` 的专用 root 特判保留；当前形态是普通 `field_object + Controller.core.sweep`，视觉由 VisualProfile / 视觉层负责。
- 原版墓碑/罐子不走普通伤害链。墓碑由 Grave Buster 这类专门交互通过 effect 移除；罐子由 Vasebreaker 模式输入或专用 effect reveal；`damageable=true` 只作为扩展能力。

## 文档定位

本文记录 GridItem（格子物件）子系统的设计方向。GridItem 指的是占据棋盘格子的非植物、非僵尸物件——墓碑、罐子、弹坑、大脑、梯子、传送门、冰路等。

本文不作为当前实现依据，不修改冻结协议，不要求立刻进入主干。它的目标是提供完整的语义分析、数据流设计和集成方案，为后续落地提供足够清晰的边界。

本文讨论的是：

- GridItem 在 Mechanic-first 架构中的定位
- GridItem 作为实体 vs 纯 Resource 的方案比较与推荐
- GridItem 与 BoardSlot 角色占位系统的集成方式
- 各 GridItem 类型如何通过 Archetype + Mechanic[] 组合表达行为
- 新增子系统 `BattleGridItemState` 的职责
- 与棋盘/地形、动态环境、生成系统、模式系统的正交边界
- 分阶段实施路线

本文不讨论：

- 修改冻结 Mechanic family
- 新增 Registry
- GridItem 的视觉表现（由 VisualProfile 驱动，不在本文范围）
- 具体的 .tres 资源编写（本文只给出抽象定义）
- 梯子的完整语义（梯子建议作为 mark 而非实体，见下文）

---

## 背景与目标

### 为什么需要 GridItem

原版 PVZ 中，战场格子不只是"有植物"或"空"两种状态。多种玩法机制依赖格子级物件：

| 物件 | 原版行为 | 出现模式 |
|------|---------|---------|
| 墓碑 (Gravestone) | 占格阻止种植，定时产僵尸 | 夜间草地关卡 |
| 罐子 (Scary Pot) | 隐藏内容（植物/僵尸/阳光），被玩家交互打开后释放 | Vasebreaker |
| 弹坑 (Crater) | 爆炸后留下，阻止种植一段时间 | 爆炸类植物效果 |
| 大脑 (Brain) | 僵尸需拾取，植物防守 | I, Zombie |
| 梯子 (Ladder) | 僵尸可翻越坚果墙 | 带梯僵尸放置 |
| 传送门 (Portal) | 实体从一端传送到另一端 | 传送关卡 |
| 冰路 (Ice Trail) | 僵尸减速/加速 | 冰车僵尸效果 |

当前 Open PVZ 的棋盘只支持 plant（primary/support/cover/blocker）和 field_object（割草机等世界坐标物件，不占格子）。没有任何机制能在运行时在格子上放置"非植物非僵尸的物件"并影响放置规则。

### 设计目标

1. **遵循 Mechanic-first**：GridItem 行为由 Archetype + Mechanic[] 组合驱动，不硬编码
2. **与 BoardSlot 共存**：GridItem 占据 BoardSlot 的角色，与 primary/support 等角色共存
3. **影响放置规则**：GridItem 能阻止或允许植物放置（如墓碑阻止、罐子 reveal 后恢复）
4. **参与事件链**：GridItem 能发射和接收 EventBus 事件
5. **可被扩展包定义**：新增 GridItem 类型只需 .tres 资源
6. **与棋盘/环境/生成系统正交**：GridItem 是格子占位实体层，不承担地形、天气、生成入口或模式目标职责

---

## 方案选择

### 方案 A：GridItem 作为 Archetype 驱动的实体（推荐）

GridItem 使用新增 `GridItemRoot`（继承 `FieldObjectRoot`），通过 `CombatArchetype + CombatMechanic[] → RuntimeSpec → EntityFactory` 实例化。行为由 Trigger + Effect 事件链或 Controller 连续行为驱动。

**优势**：
- 复用现有编译链、组件系统、事件链——不引入新代码路径
- 数据驱动——新增 GridItem 类型只需写 .tres
- 可参与 SpatialIndex 查询、可被专门交互/effect 移除或转换，可按需扩展为可破坏对象
- 可被 RuleModule、模式输入、验证和视觉层通过统一事件观察
- 扩展包可通过现有插槽机制定义新 GridItem

**代价**：
- 需要新增 `GridItemRoot`，实现格子生命周期、主动释放格子、基础调试状态，以及可选的 HealthComponent 伤害转发
- EntityFactory 需要小改：`entity_kind = &"field_object"` 且 `placement_role = &"grid_item"` 时实例化 `GridItemRoot`
- BattleGridItemState 需要负责双 role 绑定、移除和事件发射
- ProtocolValidator 需要新增 `GridItemConfig` 与 `BattleScenario.grid_item_configs` 校验

### 方案 B：GridItem 作为纯 Resource 附着在 BoardSlot 上

GridItem 是一个数据对象（继承 Resource），存储在 BoardSlot 上作为附加属性。行为由 BattleManager 硬编码或 RuleModule 驱动。

**优势**：
- 实现更轻量（不需要实例化 Node）

**代价**：
- 不参与事件链——无法通过 Trigger + Effect 表达行为
- 不被 SpatialIndex 索引——查询需要额外逻辑
- 每种行为变化需要改代码——不可扩展
- 与项目 Mechanic-first 哲学冲突

### 推荐：方案 A'

推荐采用“Archetype 驱动实体 + GridItemRoot + BattleGridItemState”的修订版方案 A'。方案 B 虽然更轻量，但每增加一个能力都需要改代码，长期成本更高。直接复用现有 `FieldObjectRoot` 也不够，因为它缺少格子生命周期、BoardSlot 主动释放和 GridItem 调试状态；`take_damage()` 为空也意味着未来扩展型可破坏 GridItem 不能复用通用 HealthComponent 链。

---

## 实体模型

### 继承链

```
BaseEntity (Node2D)
  └─ FieldObjectRoot              ← 世界坐标 field_object 通用根
       └─ GridItemRoot             ← 新增，格子物件通用根
```

GridItem 第一版直接新增 `GridItemRoot`：

| 职责 | 说明 |
|------|------|
| 保持 field_object 身份 | GridItem archetype 的 `entity_kind` 保持 `&"field_object"`，不新增 entity_kind |
| 格子生命周期 | 持有 GridItem 与 BoardSlot 的绑定元数据，移除时通知 BattleGridItemState 主动释放 role |
| 可选伤害桥接 | 对扩展型可破坏 GridItem，`take_damage()` 可转发给 HealthComponent，尊重 `is_damageable()` |
| 移除处理 | 被 effect、模式交互或可选死亡链移除时，发出 GridItem 语义事件并 queue_free |
| 格子状态 | `grid_lane_id` / `grid_slot_index` 仍写入 `entity_state`，不需要独立字段成为事实源 |

`FieldObjectRoot` 继续作为割草机等世界坐标物件的轻量基类，不承担格子生命周期和可破坏物件语义。

### 割草机降级决策

割草机不应继续作为 `EntityFactory._instantiate_field_object()` 中按 archetype_id 特判的专用 root。当前 `archetype_lawn_mower` 已经通过 `Controller.core.sweep` 表达检测、触发、移动、扫掠伤害和过期事件，运行时规则不需要依赖 `LawnMower` 子类。

目标形态：

- `archetype_lawn_mower` 保持 `entity_kind = &"field_object"`
- `EntityFactory` 对普通 field_object 默认返回 `FieldObjectRoot`
- 割草机行为由 `Controller.core.sweep` 驱动
- 割草机外观由 VisualProfile / 视觉层绘制，不由 `LawnMower._draw()` 承担
- 现有 `scripts/entities/lawn_mower.gd` 已退役为兼容脚本，不再承载割草机规则

这条决策使 `field_object` 的根节点选择保持一致：只有格子物件因生命周期和可破坏语义需要 `GridItemRoot`，不再为单个世界物件保留硬编码分支。

### 身份与 Liveness

GridItem 作为 field_object 类型，默认 liveness 为：

| 轴 | 默认值 | 说明 |
|----|--------|------|
| triggers | true | 可通过 Mechanic 获得 TriggerComponent |
| state | true | 可持有运行时状态 |
| movement | true | （field_object 默认开启，但大多数 GridItem 不移动） |
| controllers | true | 可通过 Mechanic 获得 ControllerComponent |
| targetable | **false** | 默认不可被瞄准 |
| damageable | **false** | 默认不可被攻击 |
| collidable | **false** | 默认不参与碰撞 |

特定 GridItem 可通过 Mechanic 或 liveness override 修改。例如扩展包如果需要“可被攻击的水晶/障碍物”，可以设置 `damageable=true` 并依赖 `GridItemRoot.take_damage()` 转发到 HealthComponent。原版墓碑和罐子不以普通伤害链驱动，应保持 `damageable=false`，通过 interaction/effect 移除或 reveal。

---

## BoardSlot 集成

### 角色占位

GridItem 在 BoardSlot 上以 `"grid_item"` 角色注册，作为身份 role。阻挡种植的 GridItem 第一版还应同时占用现有 `"blocker"` role，作为放置验证兼容适配。

```
BoardSlot (lane=2, slot=3):
  base_tags = ["ground", "supports_primary"]
  role_occupants = {
    "primary":   Peashooter 实例,       ← 植物
    "grid_item": Tombstone 实例,        ← 格子物件
    "blocker":   Tombstone 实例,        ← 阻挡型 GridItem 的兼容 role
  }
  role_granted_tags = {
    "primary":   ["plant"],
    "grid_item": ["grid_item", "grave"],
    "blocker":   ["placement_blocker"],
  }
  effective_tags = ["ground", "supports_primary", "plant", "grid_item", "grave", "placement_blocker"]
```

### 放置验证

GridItem 不走卡牌放置路径（`validate_request`）。它由 `BattleGridItemState` 直接管理格子绑定。

GridItem 对植物放置的影响第一版通过 **现有 role 占位**实现：

1. GridItem 被 `BattleGridItemState` 放置到格子上
2. 始终调用 `slot.add_role_occupant("grid_item", entity, granted_tags)`
3. 如果该 GridItem 阻挡种植，再调用 `slot.add_role_occupant("blocker", entity, ["placement_blocker"])`
4. 现有普通植物的 `required_empty_roles = ["blocker"]` 自然拒绝放置
5. Grave Buster 这类交互型植物仍可通过 `required_present_archetypes` 和 `target_mode = placement_blocker` 找到目标

**validate_request 改动**：第一版不新增粗粒度 `blocks_planting` 拒绝规则。若未来需要“阻止 primary 但允许 cover / support / 特定交互植物”的细粒度阻挡，应新增明确的 `required_absent_tags` / `required_grid_item_tags` / bypass 语义，而不是用一个 tag 拒绝所有 plant。

### 交互 / Effect 驱动

GridItem 第一版不把“普通攻击扣血”作为默认交互模型。GridItem 的变化应由明确的交互或 effect 驱动：

```
模式输入 / 特定植物放置 / 环境规则 / 效果请求
  -> remove_grid_item / reveal_grid_item / spawn_grid_item
  -> BattleGridItemState 更新 BoardSlot role
  -> grid_item.removed / grid_item.revealed / grid_item.spawned
```

典型例子：

- Grave Buster 放置成功后，通过 `target_mode = placement_blocker` 找到墓碑，并执行 `remove_grid_item`。
- Vasebreaker 模式点击罐子后，模式输入层执行 `reveal_grid_item`，而不是让罐子承受植物攻击。
- 爆炸类 effect 可以请求 `spawn_grid_item` 创建弹坑，也可以按设计请求 reveal 附近罐子。

`HealthComponent` / `entity.damaged` 仍可服务扩展型可破坏 GridItem，但不是墓碑和罐子的原版语义基线。

### 格子释放

GridItem 被移除（被专门交互移除、reveal、过期，或扩展型可破坏物件死亡）时：
1. `slot.remove_role_occupant("grid_item")`
2. 如果同一实体占用了 `"blocker"` role，也同步 `slot.remove_role_occupant("blocker")`
3. 格子恢复可种植状态

BoardSlot 已有的 `_prune_invalid_occupants()` 会自动清理已销毁（`queue_free`）的实体，GridItem 无需额外清理逻辑。

审查修订：不能只依赖 `_prune_invalid_occupants()` 做语义清理。`BattleGridItemState.remove_grid_item()` 应主动移除 role 并发出 `grid_item.removed`，否则验证和模式层难以观察“格子释放”。

---

## 各类型的行为表达

### 墓碑 (Gravestone)

| 属性 | 值 |
|------|---|
| max_health | -1（原版不可被普通攻击破坏） |
| liveness | damageable=false, targetable=false |
| slot roles | `grid_item` + `blocker` |
| granted_placement_tags | `["grid_item", "grave", "removable_by_gravebuster"]`；blocker role 额外授予 `["placement_blocker"]` |
| Mechanic | Trigger.periodically → 请求生成系统从墓碑入口生成 zombie |

行为：占据格子并阻挡普通植物放置；可在特定规则下请求生成僵尸。墓碑不作为普通攻击目标，移除由 Grave Buster 这类专门交互或模式/effect 完成。

需要的 effect / 事件：
- 墓碑本体通过 `spawn_grid_item` 或场景 `GridItemConfig` 创建。
- Grave Buster 放置成功后，通过 `target_mode = placement_blocker` 解析目标，再执行 `remove_grid_item`，由 `BattleGridItemState` 释放 `grid_item` / `blocker` role。
- 墓碑周期产僵尸不直接绕过生成系统，建议发布 `spawn.requested` 或调用 `BattleSpawnResolver`，由 `SpawnZoneConfig` / 临时墓碑入口与 zombie 的 `required_spawn_tags` 匹配后再实例化。

### 弹坑 (Crater)

| 属性 | 值 |
|------|---|
| max_health | -1（不可被攻击） |
| liveness | 全部默认（不可瞄准/攻击/碰撞） |
| slot roles | `grid_item` + `blocker` |
| granted_placement_tags | `["grid_item", "crater"]`；blocker role 额外授予 `["placement_blocker"]` |
| Mechanic | 无（纯占位） |

行为：爆炸发生后占据格子，阻止种植。可设定定时移除（通过 State mechanic 的超时），或永久存在。

需要的 effect：`remove_grid_item`（或复用现有生命周期机制）

### 罐子 (Scary Pot)

| 属性 | 值 |
|------|---|
| max_health | -1（原版不靠普通伤害打开） |
| liveness | damageable=false, targetable=false |
| slot roles | 未打开时 `grid_item` + `blocker` |
| granted_placement_tags | `["grid_item", "vase", "concealed"]`；blocker role 额外授予 `["placement_blocker"]` |
| Mechanic | 通常无；由 Vasebreaker 模式输入或专用 effect 调用 reveal |

罐子被玩家交互打开后：
- 移除 "grid_item" 角色（释放格子）
- 根据罐子内容（`default_params.content_archetype_id`）在原位放置植物、生成僵尸或产生阳光
- 若内容是僵尸，应通过生成系统处理原位 spawn request；若内容是植物，应走放置/实例化路径并尊重释放后的 BoardSlot 状态

需要的 effect：`reveal_grid_item`（移除罐子自身 + 根据内容类型发起对应请求）。该 effect 不应直接内置 Vasebreaker 模式逻辑；Vasebreaker 模式只决定何时、对哪个 slot 调用 reveal。

### 大脑 (Brain)

| 属性 | 值 |
|------|---|
| max_health | 10（可被僵尸"攻击"/拾取） |
| liveness | targetable=true, damageable=true |
| granted_placement_tags | 无（不阻止种植——I,Zombie 模式中植物已预置） |
| Mechanic | Trigger.on_death → 发布 `grid_item.collected` / `objective.collected` |

行为：僵尸接触大脑时大脑死亡，发出收集/目标事件。I, Zombie 模式的胜负条件由模式模块消费事件并计分。

需要的 effect / 事件：优先使用通用 `emit_event` / `objective.collected` 路径。若新增 effect，应命名为通用目标事件 effect，而不是 `score_brain` 这类模式专用 effect。

### 梯子 (Ladder)

梯子建议**不作为 GridItem 实体**，而是作为**僵尸身上的 mark**。

理由：原版中梯子的作用是让僵尸翻越坚果墙——这是僵尸自身行为的改变（跳过目标），而不是格子上的独立物件。梯子附着在僵尸身上，当僵尸遇到植物时检查是否持有 ladder mark。

实现方式：
1. 带梯僵尸的 archetype 包含 Mechanic：on_spawned → apply_mark("ladder")
2. 僵尸的 Controller 在选择路径时检查 `has_mark("ladder")`
3. 如果有 ladder mark，跳过当前植物的碰撞/伤害

### 传送门 (Portal)

| 属性 | 值 |
|------|---|
| max_health | -1 |
| granted_placement_tags | 无 |
| Mechanic | Trigger.periodically → Effect.teleport_entity |

传送门成对出现。每个传送门持有 `default_params.partner_slot`。当实体进入传送门范围时，被传送到 partner 位置。

需要的 effect：`teleport_entity`（改变实体位置）

### 冰路 (Ice Trail)

冰路建议作为**格子 mark**（BoardSlot 上的运行时状态），而非 GridItem 实体。

理由：冰路不阻止种植、不占角色、不影响碰撞——它只改变僵尸在该格子的移动速度。用 GridItem 实体过于重量级。

实现方式：
1. 冰车僵尸的 Controller 经过的格子，通过 BattleGridItemState 设置 slot mark `"icy"`
2. 僵尸 Controller 每帧检查脚下格子的 mark，如有 `"icy"` 则改变 movement_scale

---

## 新增子系统：BattleGridItemState

### 职责

管理 GridItem 的完整生命周期：生成、格子绑定、状态查询、销毁。

### 与现有子系统的关系

```
BattleFieldObjectState          BattleGridItemState
  管理世界坐标物件                管理格子坐标物件
  (割草机等)                     (墓碑/罐子/弹坑等)
        ↓                                ↓
  FieldObjectConfig              GridItemConfig
  (lane_id + x_position)         (lane_id + slot_index + archetype_id)
        ↓                                ↓
  EntityFactory                   EntityFactory
        ↓                                ↓
  实体加入场景                     实体加入场景
  不绑定 BoardSlot                绑定 BoardSlot.add_role_occupant()
```

### 生成方式

GridItem 的生成不是通过卡牌放置，而是通过以下途径：

1. **场景预配置**：BattleScenario 中的 `grid_item_configs`（类似 `field_object_configs`）
2. **环境/模式规则**：动态环境或模式模块在满足条件时调用 `BattleGridItemState.spawn_grid_item_at()`，例如夜间墓碑规则
3. **效果触发**：爆炸效果产生弹坑（`spawn_grid_item` effect 生成 crater archetype）
4. **模式初始化**：Vasebreaker 模式在开局时随机填充罐子

实现注意：`BattleGridItemState` 可以像 `BattleFieldObjectState` 一样直接使用 `EntityFactory.instantiate_spawn_entry()` 创建 `field_object`，再调用 `battle.finalize_spawned_entity()`。不要要求现有 `BattleSpawner._spawn_entry_internal()` 立刻支持 field_object，因为它当前只允许 plant / zombie。

### GridItemConfig 抽象定义

```
GridItemConfig:
  archetype_id: StringName          ← 哪种 GridItem
  lane_id: int                      ← 目标行
  slot_index: int                   ← 目标列
  occupies_blocker_role: bool       ← 是否同步占用 blocker role
  spawn_overrides: Dictionary       ← 运行时参数覆盖
```

### 核心 API（抽象）

| 方法 | 职责 |
|------|------|
| `setup(battle, scenario)` | 初始化，读取 grid_item_configs |
| `spawn_grid_items(scenario)` | 从配置生成 GridItem 并绑定格子 |
| `spawn_grid_item_at(archetype_id, lane_id, slot_index, overrides, occupies_blocker_role)` | 在指定格子生成 GridItem |
| `remove_grid_item(lane_id, slot_index)` | 移除指定格子的 GridItem |
| `get_grid_item_at(lane_id, slot_index) → Node` | 查询格子上的 GridItem |
| `get_all_grid_items() → Array` | 所有活跃 GridItem |

---

## 新增 Effect 抽象

| Effect ID | 用途 | 参数 |
|-----------|------|------|
| `spawn_grid_item` | 在指定格子生成 GridItem | archetype_id, lane_id, slot_index, occupies_blocker_role, spawn_overrides |
| `reveal_grid_item` | 打开罐子：移除 grid_item 角色，在原位生成内容；通常由模式输入或专用 effect 调用 | content_archetype_id |
| `emit_objective_event` / `emit_event` | 通知模式层某个 GridItem 目标被收集或触发 | event_name, payload |
| `remove_grid_item` | 移除目标格子的 GridItem；可按 lane/slot 或 target_mode 解析目标 | lane_id, slot_index, target_mode |
| `teleport_entity` | 将实体传送到目标位置 | target_position |

这些 effect 需要在 EffectRegistry 中注册，遵循 `RegistryBase + EffectDef` 体系。不新增 Registry。

现有 `spawn_entity` 保持“生成 plant/zombie 等普通运行时实体”的职责。是否扩展到 field_object 另行评估，不作为 GridItem 第一版前置条件。

审查修订：GridItem 触发普通实体生成时不应绕过生成系统。墓碑产僵尸、罐子释放僵尸等行为应形成 spawn request，由 `BattleSpawnResolver` / `SpawnZoneConfig` 或明确的原位生成策略处理。GridItem effect 只表达“请求生成”，不直接承担生成入口匹配规则。

---

## 与其他系统的正交边界

### 系统关系

| 维度 | 其他系统 | GridItem 本草案 |
|------|----------|----------------|
| 空间结构 | 棋盘/地形系统：`LaneConfig`、`BoardSlot`、`BattlefieldMetrics` | 只绑定已有 BoardSlot，不修改 lane/terrain |
| 环境状态 | 动态环境系统：昼夜、天气、迷雾、可见度 | 可被环境/模式触发生成，但不持有环境规则 |
| 生成入口 | 生成系统：`SpawnZoneConfig`、`BattleSpawnResolver` | 可发起 spawn request，但不匹配入口能力 |
| 模式目标 | BattleMode / RuleModule：胜负、计分、模式专属流程 | 发事件，不直接计分或判断胜负 |
| 数据来源 | BattlefieldPreset / EnvironmentProfile / SpawnZoneConfig | CombatArchetype + GridItemConfig |
| 运行时可变性 | 地形层固定；环境/生成/模式可变 | GridItem 可被创建、破坏、变形 |

GridItem 基础设施是**格子占位实体层**：它操作 `BoardSlot role_occupants`、`role_granted_tags` 和自身实体生命周期，不承担地形、天气、生成入口或模式目标职责。

### 接口约定

| 接口 | 提供方 | 消费方 | 用途 |
|------|--------|--------|------|
| `get_slot(lane, slot)` / `validate_slot_exists()` | BattleBoardState | BattleGridItemState | 绑定或释放格子 |
| `lane_traits` / `slot.effective_tags` | 棋盘/地形系统 | GridItem 放置约束校验 | 限制 GridItem 出现在某类地形上，禁止依赖 `lane_type` |
| `get_environment_state()` | 动态环境系统 | 模式/环境规则模块 | 决定是否请求生成墓碑等 GridItem |
| `BattleSpawnResolver.resolve_spawn()` | 生成系统 | GridItem effect / RuleModule | 墓碑产僵尸、罐子释放僵尸时解析生成位置 |
| `grid_item.spawned` / `grid_item.removed` / `grid_item.revealed` / `objective.collected` | BattleGridItemState / GridItem effect | BattleMode / Environment / Visual | 观察格子物件变化 |
| `get_grid_item_at(lane, slot): Node` | BattleGridItemState | 规则/视觉/验证 | 查询格子上的 GridItem |

关键约束：

- 不再使用 `get_lane_type(lane_id)` 作为通用接口。`lane_type` 已降级为模板 ID，运行时应查询 `lane_traits`、slot tags 或 metrics。
- `is_night` / `is_position_in_fog` 属于动态环境系统，不属于棋盘/地形系统。GridItem 基础设施不直接依赖它们。
- GridItem 不直接修改 `LaneConfig`、`BattlefieldPreset`、`terrain_profile` 或环境状态。
- GridItem 触发普通实体生成时，不直接决定生成入口，统一交给生成系统。

### 依赖关系

```
棋盘/地形 Phase 1 (BoardSlot/LaneConfig)    GridItem Phase 1 (基础设施)
  提供 BoardSlot / slot tags                  依赖 BoardSlot 绑定 API
        ↓                                           ↓
生成系统 Phase 2 (SpawnResolver)              GridItem Phase 2 (墓碑/罐子生成内容)
  提供 spawn request 解析                       产僵尸时依赖 SpawnResolver
        ↓                                           ↓
动态环境 Phase 2/3 (昼夜/迷雾)                GridItem 具体玩法规则
  可决定何时请求生成墓碑                       不进入 GridItem 基础设施
        ↓                                           ↓
模式系统 (Vasebreaker / I, Zombie)            GridItem 高级类型
  消费 GridItem 事件计分/胜负                  发事件，不直接判断胜负
```

**核心结论**：GridItem 基础层正交，可以在 BoardSlot API 稳定后独立实现。墓碑“占格和被专门交互移除”属于 GridItem；“夜晚是否生成墓碑”属于环境/模式规则；“墓碑产出的僵尸从哪里出现”属于生成系统。

---

## 棋盘草案 Phase 4 预留的更新

棋盘多样性草案 Phase 4 中有如下预留：

> "如果未来引入墓碑/障碍物系统，应该作为 GridItem Resource 附着在 BoardSlot 上。GridItem 应包含 item_type、block_planting。"

本草案完成后，棋盘草案 Phase 4 的预留可更新为：

- GridItem 不是纯 Resource，而是 Archetype 驱动的实体
- GridItem 通过 BoardSlot 的 `"grid_item"` role 标记身份，不是附加属性
- 阻挡型 GridItem 第一版同时占用 `"blocker"` role，复用现有放置验证
- 行为由 Mechanic 组合表达，不需要 item_type 枚举

---

## 分阶段实施建议

### Phase 1：基础设施 + 弹坑

**最小可验证单元**。弹坑是最简单的 GridItem（纯占位，无行为）。

改动范围：
- GridItemRoot 新建（继承 FieldObjectRoot，维护格子绑定，移除时通知 BattleGridItemState 释放格子；可选转发 HealthComponent 伤害）
- BattleGridItemState 新建（生成、格子绑定、销毁）
- GridItemConfig 资源定义
- BattleScenario 增加 `grid_item_configs`
- ProtocolValidator 增加 GridItemConfig 校验
- 阻挡型 GridItem 使用 `grid_item + blocker` 双 role，不新增 `blocks_planting` 硬拒绝规则
- archetype_crater .tres（纯占位，无 Mechanic）
- smoke 验证场景

### Phase 2：墓碑

改动范围：
- `spawn_grid_item` / `remove_grid_item` effect 注册（如果 Phase 1 未注册）
- archetype_tombstone_grid_item .tres（不可普通攻击，periodically trigger + spawn request 可选）
- Grave Buster 兼容：保留 `placement_blocker` 目标路径，通过 `remove_grid_item` 移除墓碑；或新增 `placement_grid_item` 后同步迁移资源
- 现有 `archetype_tombstone_blocker` 是 plant/blocker 过渡资源，迁移时不得删除旧验证，需新增等价 GridItem 验证
- 与 `BattleSpawnResolver` 联动：墓碑产僵尸时由生成系统解析入口
- 动态环境/模式联动（可选）：夜间生成墓碑由环境或模式模块发起，不写入 GridItem 基础设施
- 验证场景

### Phase 3：罐子

改动范围：
- `reveal_grid_item` effect 注册
- archetype_scary_pot .tres（不可普通攻击，携带 concealed/vase 标签和内容参数）
- Vasebreaker 模式输入：点击/锤子交互解析 slot 后调用 `reveal_grid_item`
- 罐子内容实体化请求：植物走放置/实例化路径，僵尸走生成系统，阳光走经济/掉落路径
- 罐子未开/已开的状态切换
- 验证场景

### Phase 4：高级类型

改动范围：
- 大脑（通用 objective/grid_item 事件 + I, Zombie 模式消费）
- 传送门（teleport_entity effect + 成对绑定）
- 梯子（mark 方案，Controller 联动）
- 冰路（slot mark 方案，Controller 联动）

---

## 不做的事

- 不新增 Mechanic family
- 不新增 Registry
- 不新增 entity_kind（GridItem 使用 `&"field_object"` 或通过 EntityFactory 识别）
- 不修改 LaneConfig 或 BattlefieldPreset（与棋盘草案解耦）
- 不依赖 `lane_type` 做运行时判断；如需限制地形，查询 `lane_traits`、slot tags 或 metrics
- 不承载动态环境规则；昼夜、天气、迷雾由动态环境系统或模式模块处理
- 不承载生成入口匹配；墓碑/罐子产僵尸必须走 spawn request + `BattleSpawnResolver`
- 不承载模式计分/胜负；GridItem 只发事件，模式模块消费事件
- 不实现 GridItem 的视觉表现（由 VisualProfile 系统驱动）
- 不实现 GridItem 的卡牌化（GridItem 不走手牌放置路径）
- 不把墓碑/罐子建模为原版普通伤害目标；二者通过 interaction/effect 驱动移除或 reveal
- 不在第一版扩展 `spawn_entity` 以支持 field_object；GridItem 生成走专用 `spawn_grid_item`
- 不保留割草机的 `EntityFactory` 专用 root 特判；割草机行为走 Controller，视觉走 VisualProfile / 视觉层
- 不用单一 `blocks_planting` tag 拒绝所有 plant 放置

---

## 开放问题

1. **GridItemRoot 是否需要独立类？** 本次审查后建议第一版就新增。原因是 `FieldObjectRoot` 不承担格子绑定、主动释放和 GridItem 调试状态；`take_damage()` 可作为扩展型可破坏 GridItem 的桥接能力，但墓碑/罐子不依赖它。

2. **阻挡粒度如何表达？** 第一版用 `blocker` role 表达“阻挡普通放置”。若未来需要“阻止 primary 但允许 cover/support/特定交互植物”，再补 `required_absent_tags`、`required_grid_item_tags` 或 placement bypass 语义。

3. **罐子 reveal 的原子性？** 罐子被模式输入打开后需要在同一帧完成"移除 grid_item → 释放格子 → 放置内容实体"。是否需要事务性保证？建议通过 Effect 链的顺序执行保证。

4. **传送门的成对绑定？** 传送门如何知道自己的 partner 在哪？建议通过 `default_params.partner_lane` + `default_params.partner_slot` 存储，`BattleGridItemState` 在运行时解析。

5. **EntityFactory 如何识别 GridItem？** 当前 `_instantiate_field_object()` 按 archetype_id switch。建议移除单个 archetype 的特判：如果 archetype 的 `entity_kind == &"field_object"` 且 `placement_role == &"grid_item"`，返回 `GridItemRoot`；其他 field_object 统一回退 `FieldObjectRoot`。割草机不再走专用 `LawnMower` root，而是普通 `FieldObjectRoot + Controller.core.sweep`。

---

## 参考文件

| 文件 | 用途 |
|------|------|
| `scripts/entities/field_object_root.gd` | GridItemRoot 的父类；不承担格子绑定和主动释放语义 |
| `scripts/entities/lawn_mower.gd` | 已退役兼容脚本；割草机规则由普通 field_object + `Controller.core.sweep` 承载 |
| `autoload/ControllerRegistry.gd` | `core.sweep` 已承载割草机运行时行为，降级后继续复用 |
| `scripts/battle/board_slot.gd` | 角色占位 API（130 行） |
| `scripts/battle/battle_board_state.gd` | validate_request 检查链（734 行，关键行 223-281） |
| `scripts/battle/battle_field_object_state.gd` | 现有场物件管理参考（105 行） |
| `scripts/battle/entity_factory.gd` | 实体实例化（652 行，关键行 152-183） |
| `scripts/core/defs/combat_archetype.gd` | Archetype 定义（27 行） |
| `plans/draft/棋盘多样性与地形系统设计草案.md` | 棋盘草案（Phase 4 预留 GridItem） |
