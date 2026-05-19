# GridItem 子系统设计草案

> 日期：2026-05-19
> 状态：概念草案，供设计评审与后续 spike 使用
> 关联主题：棋盘多样性、BoardSlot 角色占位、Mechanic-first 架构、战斗模式系统
> 前置文档：棋盘多样性与环境系统设计草案（Phase 4 预留）

---

## 文档定位

本文记录 GridItem（格子物件）子系统的设计方向。GridItem 指的是占据棋盘格子的非植物、非僵尸物件——墓碑、罐子、弹坑、大脑、梯子、传送门、冰路等。

本文不作为当前实现依据，不修改冻结协议，不要求立刻进入主干。它的目标是提供完整的语义分析、数据流设计和集成方案，为后续落地提供足够清晰的边界。

本文讨论的是：

- GridItem 在 Mechanic-first 架构中的定位
- GridItem 作为实体 vs 纯 Resource 的方案比较与推荐
- GridItem 与 BoardSlot 角色占位系统的集成方式
- 各 GridItem 类型如何通过 Archetype + Mechanic[] 组合表达行为
- 新增子系统 `BattleGridItemState` 的职责
- 与棋盘多样性草案的交叉依赖与接口约定
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
| 罐子 (Scary Pot) | 隐藏内容（植物/僵尸/阳光），被打碎后释放 | Vasebreaker |
| 弹坑 (Crater) | 爆炸后留下，阻止种植一段时间 | 爆炸类植物效果 |
| 大脑 (Brain) | 僵尸需拾取，植物防守 | I, Zombie |
| 梯子 (Ladder) | 僵尸可翻越坚果墙 | 带梯僵尸放置 |
| 传送门 (Portal) | 实体从一端传送到另一端 | 传送关卡 |
| 冰路 (Ice Trail) | 僵尸减速/加速 | 冰车僵尸效果 |

当前 Open PVZ 的棋盘只支持 plant（primary/support/cover/blocker）和 field_object（LawnMower，世界坐标放置，不占格子）。没有任何机制能在运行时在格子上放置"非植物非僵尸的物件"并影响放置规则。

### 设计目标

1. **遵循 Mechanic-first**：GridItem 行为由 Archetype + Mechanic[] 组合驱动，不硬编码
2. **与 BoardSlot 共存**：GridItem 占据 BoardSlot 的角色，与 primary/support 等角色共存
3. **影响放置规则**：GridItem 能阻止或允许植物放置（如墓碑阻止、罐子被打碎后恢复）
4. **参与事件链**：GridItem 能发射和接收 EventBus 事件
5. **可被扩展包定义**：新增 GridItem 类型只需 .tres 资源
6. **与棋盘多样性草案正交**：两个系统可并行开发，不互相阻塞

---

## 方案选择

### 方案 A：GridItem 作为 Archetype 驱动的实体（推荐）

GridItem 继承 FieldObjectRoot（或新增 GridItemRoot），通过 `CombatArchetype + CombatMechanic[] → RuntimeSpec → EntityFactory` 实例化。行为由 Trigger + Effect 事件链或 Controller 连续行为驱动。

**优势**：
- 复用现有编译链、组件系统、事件链——不引入新代码路径
- 数据驱动——新增 GridItem 类型只需写 .tres
- 可参与 SpatialIndex 查询、可被 RuleModule 引用
- 可被攻击（墓碑有血量）、可发射事件（罐子被打碎）
- 扩展包可通过现有插槽机制定义新 GridItem

**代价**：
- EntityFactory 需要小改（识别 GridItem archetype 或返回通用 FieldObjectRoot）
- validate_request 需要加 1 条 tag 检查
- 新增 BattleGridItemState 子系统（约 100-150 行）

### 方案 B：GridItem 作为纯 Resource 附着在 BoardSlot 上

GridItem 是一个数据对象（继承 Resource），存储在 BoardSlot 上作为附加属性。行为由 BattleManager 硬编码或 RuleModule 驱动。

**优势**：
- 实现更轻量（不需要实例化 Node）

**代价**：
- 不参与事件链——无法通过 Trigger + Effect 表达行为
- 不被 SpatialIndex 索引——查询需要额外逻辑
- 每种行为变化需要改代码——不可扩展
- 与项目 Mechanic-first 哲学冲突

### 推荐：方案 A

方案 A 的额外成本约 50 行代码，但获得完整的系统集成和可扩展性。方案 B 虽然更轻量，但每增加一个能力都需要改代码，长期成本更高。

---

## 实体模型

### 继承链

```
BaseEntity (Node2D)
  └─ FieldObjectRoot              ← 现有，29 行
       ├─ LawnMower                ← 现有
       └─ [GridItem 使用 FieldObjectRoot 或新增 GridItemRoot]
```

GridItem 的实体基类有两种选择：

| 选择 | 做法 | 适用场景 |
|------|------|---------|
| 直接用 FieldObjectRoot | GridItem archetype 的 entity_kind 保持 `&"field_object"` | GridItem 不需要额外字段 |
| 新增 GridItemRoot | 继承 FieldObjectRoot，增加 `grid_x`/`grid_y` 字段 | GridItem 需要快速定位格子坐标 |

推荐先直接用 FieldObjectRoot——`grid_x`/`grid_y` 可通过 `entity_state` 的 `set_state_value()` 存储，不需要类字段。如果后续发现性能瓶颈或便捷性问题，再提取 GridItemRoot。

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

特定 GridItem 可通过 Mechanic 或 liveness override 修改。例如墓碑需要被攻击（damageable=true），由 State family 的 liveness_overrides 提供。

---

## BoardSlot 集成

### 角色占位

GridItem 在 BoardSlot 上以 `"grid_item"` 角色注册。与现有角色共存：

```
BoardSlot (lane=2, slot=3):
  base_tags = ["ground", "supports_primary"]
  role_occupants = {
    "primary":   Peashooter 实例,       ← 植物
    "grid_item": Tombstone 实例,        ← 格子物件
  }
  role_granted_tags = {
    "primary":   ["plant"],
    "grid_item": ["blocks_planting"],   ← 注入到 effective_tags
  }
  effective_tags = ["ground", "supports_primary", "plant", "blocks_planting"]
```

### 放置验证

GridItem 不走卡牌放置路径（`validate_request`）。它由 `BattleGridItemState` 直接管理格子绑定。

GridItem 对植物放置的影响通过 **tag 注入**实现：

1. GridItem 被 `BattleGridItemState` 放置到格子上
2. 调用 `slot.add_role_occupant("grid_item", entity, ["blocks_planting"])`
3. `blocks_planting` 被注入到 `slot.get_effective_tags()`
4. `validate_request` 新增检查：如果 `effective_tags` 包含 `blocks_planting` 且请求的 entity_kind 是 `"plant"`，拒绝放置

**validate_request 改动**：约 3 行。不修改现有检查顺序，只在现有检查链中插入一条 tag 拒绝规则。

### 格子释放

GridItem 被移除（被破坏、被打碎、过期）时：
1. `slot.remove_role_occupant("grid_item")` ——自动清除 `blocks_planting` tag
2. 格子恢复可种植状态

BoardSlot 已有的 `_prune_invalid_occupants()` 会自动清理已销毁（`queue_free`）的实体，GridItem 无需额外清理逻辑。

---

## 各类型的行为表达

### 墓碑 (Gravestone)

| 属性 | 值 |
|------|---|
| max_health | 300 |
| liveness | damageable=true（通过 liveness_override） |
| granted_placement_tags | ["blocks_planting"] |
| Mechanic | Trigger.periodically → Payload.spawn_entity(zombie) |

行为：每 30 秒在附近格子生成一只僵尸。被植物攻击（伤害 300）后销毁，释放格子。

需要的 effect：`spawn_entity`（通用——在指定位置生成实体，非投射物）

### 弹坑 (Crater)

| 属性 | 值 |
|------|---|
| max_health | -1（不可被攻击） |
| liveness | 全部默认（不可瞄准/攻击/碰撞） |
| granted_placement_tags | ["blocks_planting"] |
| Mechanic | 无（纯占位） |

行为：爆炸发生后占据格子，阻止种植。可设定定时移除（通过 State mechanic 的超时），或永久存在。

需要的 effect：`remove_grid_item`（或复用现有生命周期机制）

### 罐子 (Scary Pot)

| 属性 | 值 |
|------|---|
| max_health | 100（可被攻击） |
| liveness | damageable=true |
| granted_placement_tags | ["blocks_planting"]（未打开时） |
| Mechanic | Trigger.when_damaged → 条件(health<=0) → Effect.reveal_grid_item |

罐子被打碎后：
- 移除 "grid_item" 角色（释放格子）
- 根据罐子内容（`default_params.content_archetype_id`）在原位放置植物或生成僵尸

需要的 effect：`reveal_grid_item`（将内容实体化 + 移除罐子自身）

### 大脑 (Brain)

| 属性 | 值 |
|------|---|
| max_health | 10（可被僵尸"攻击"/拾取） |
| liveness | targetable=true, damageable=true |
| granted_placement_tags | 无（不阻止种植——I,Zombie 模式中植物已预置） |
| Mechanic | Trigger.on_death → Effect.score_brain |

行为：僵尸接触大脑时大脑死亡，触发计分。I,Zombie 模式的胜负条件基于大脑计数。

需要的 effect：`score_brain`（通知模式层计分）

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
  (LawnMower 等)                 (墓碑/罐子/弹坑等)
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
2. **波次规则**：DayNightRuleModule 在夜间关卡中按规则生成墓碑
3. **效果触发**：爆炸效果产生弹坑（`spawn_entity` effect 生成 crater archetype）
4. **模式初始化**：Vasebreaker 模式在开局时随机填充罐子

### GridItemConfig 抽象定义

```
GridItemConfig:
  archetype_id: StringName          ← 哪种 GridItem
  lane_id: int                      ← 目标行
  slot_index: int                   ← 目标列
  spawn_overrides: Dictionary       ← 运行时参数覆盖
```

### 核心 API（抽象）

| 方法 | 职责 |
|------|------|
| `setup(battle, scenario)` | 初始化，读取 grid_item_configs |
| `spawn_grid_items(scenario)` | 从配置生成 GridItem 并绑定格子 |
| `spawn_grid_item_at(archetype_id, lane_id, slot_index, overrides)` | 在指定格子生成 GridItem |
| `remove_grid_item(lane_id, slot_index)` | 移除指定格子的 GridItem |
| `get_grid_item_at(lane_id, slot_index) → Node` | 查询格子上的 GridItem |
| `get_all_grid_items() → Array` | 所有活跃 GridItem |

---

## 新增 Effect 抽象

| Effect ID | 用途 | 参数 |
|-----------|------|------|
| `spawn_entity` | 在指定位置生成实体（非投射物） | entity_kind, archetype_id, lane_id, slot_index, spawn_mode(nearby_slot/exact) |
| `reveal_grid_item` | 打开罐子：移除 grid_item 角色，在原位生成内容 | content_archetype_id |
| `score_brain` | 通知模式层大脑被拾取 | （无额外参数） |
| `remove_grid_item` | 移除目标格子的 GridItem | lane_id, slot_index |
| `teleport_entity` | 将实体传送到目标位置 | target_position |

这些 effect 需要在 EffectRegistry 中注册，遵循 `RegistryBase + EffectDef` 体系。不新增 Registry。

---

## 与棋盘多样性草案的交叉分析

### 系统关系

| 维度 | 棋盘多样性草案 | GridItem 本草案 |
|------|---------------|----------------|
| 空间粒度 | 行级（LaneConfig） | 格级（BoardSlot role） |
| 核心关注 | 地形差异（grass/pool/roof/dirt） | 格子物件（墓碑/罐子/弹坑） |
| 数据来源 | BattlefieldPreset.lane_configs[] | CombatArchetype + GridItemConfig |
| 运行时可变性 | 地形层固定；环境层可变 | GridItem 可被创建、破坏、变形 |

两个系统**正交互不阻塞**。

### 接口约定

| 接口 | 提供方 | 消费方 | 用途 |
|------|--------|--------|------|
| `is_night: bool` | DayNightRuleModule (棋盘草案) | 墓碑生成逻辑 | 决定是否产墓碑 |
| `get_lane_type(lane_id): StringName` | LaneConfig (棋盘草案) | GridItem 放置过滤 | 限制 GridItem 出现在特定行类型 |
| `is_position_in_fog(pos): bool` | FogRuleModule (棋盘草案) | 罐子视觉 | 迷雾中隐藏罐子内容 |
| `get_grid_item_at(lane, slot): Node` | BattleGridItemState (本草案) | FogRuleModule | 查询格子上的 GridItem |

### 依赖关系

```
棋盘草案 Phase 1 (LaneConfig)     GridItem Phase 1 (基础设施)
  不依赖                            不依赖
        ↓                                ↓
棋盘草案 Phase 2 (DayNight)       GridItem Phase 2 (墓碑)
  不依赖 GridItem                    依赖 DayNight（墓碑生成规则）
        ↓                                ↓
棋盘草案 Phase 3 (Roof/Fog)       GridItem Phase 3 (高级类型)
  不依赖 GridItem                    传送门可能依赖 Fog 接口
```

**核心结论**：两个系统的基础层可以并行开发。墓碑的占格和被破坏逻辑不依赖棋盘草案，但"夜间生成墓碑"的规则依赖 DayNightRuleModule。

---

## 棋盘草案 Phase 4 预留的更新

棋盘多样性草案 Phase 4 中有如下预留：

> "如果未来引入墓碑/障碍物系统，应该作为 GridItem Resource 附着在 BoardSlot 上。GridItem 应包含 item_type、block_planting。"

本草案完成后，棋盘草案 Phase 4 的预留可更新为：

- GridItem 不是纯 Resource，而是 Archetype 驱动的实体
- GridItem 通过 BoardSlot 的 `"grid_item"` role 占位，不是附加属性
- 阻止种植通过 `granted_placement_tags: ["blocks_planting"]` 注入 effective_tags
- 行为由 Mechanic 组合表达，不需要 item_type 枚举

---

## 分阶段实施建议

### Phase 1：基础设施 + 弹坑

**最小可验证单元**。弹坑是最简单的 GridItem（纯占位，无行为）。

改动范围：
- BattleGridItemState 新建（生成、格子绑定、销毁）
- GridItemConfig 资源定义
- validate_request 加 1 条 `blocks_planting` 检查
- archetype_crater .tres（纯占位，无 Mechanic）
- smoke 验证场景

### Phase 2：墓碑

改动范围：
- `spawn_entity` effect 注册
- archetype_tombstone .tres（有血量、periodically trigger + spawn_entity）
- liveness override 使墓碑 damageable
- DayNightRuleModule 联动（可选，如棋盘草案未完成则用场景配置）
- 验证场景

### Phase 3：罐子

改动范围：
- `reveal_grid_item` effect 注册
- archetype_scary_pot .tres（有血量、when_damaged trigger + reveal）
- 罐子内容实体化逻辑
- 罐子未开/已开的状态切换
- 验证场景

### Phase 4：高级类型

改动范围：
- 大脑（score_brain effect + I,Zombie 模式联动）
- 传送门（teleport_entity effect + 成对绑定）
- 梯子（mark 方案，Controller 联动）
- 冰路（slot mark 方案，Controller 联动）

---

## 不做的事

- 不新增 Mechanic family
- 不新增 Registry
- 不新增 entity_kind（GridItem 使用 `&"field_object"` 或通过 EntityFactory 识别）
- 不修改 LaneConfig 或 BattlefieldPreset（与棋盘草案解耦）
- 不实现 GridItem 的视觉表现（由 VisualProfile 系统驱动）
- 不实现 GridItem 的卡牌化（GridItem 不走手牌放置路径）

---

## 开放问题

1. **GridItemRoot 是否需要独立类？** 建议先用 FieldObjectRoot，`grid_x`/`grid_y` 通过 `set_state_value` 存储。如果发现频繁查询格子坐标导致性能问题，再提取 GridItemRoot。

2. **`blocks_planting` 的拒绝粒度？** 当前设计是"只要有 blocks_planting 就拒绝所有植物"。是否需要更细粒度（如"阻止一级放置但不阻止 cover"）？建议先做最简版本。

3. **罐子变形的原子性？** 罐子被打碎后需要在同一帧完成"移除 grid_item → 释放格子 → 放置内容实体"。是否需要事务性保证？建议通过 Effect 链的顺序执行保证。

4. **传送门的成对绑定？** 传送门如何知道自己的 partner 在哪？建议通过 `default_params.partner_lane` + `default_params.partner_slot` 存储，`BattleGridItemState` 在运行时解析。

5. **EntityFactory 如何识别 GridItem？** 当前 `_instantiate_field_object()` 按 archetype_id switch。建议：如果 archetype 的 entity_kind 是 `"field_object"` 且 placement_role 是 `"grid_item"`，直接返回 FieldObjectRoot（不需要 switch）。

---

## 参考文件

| 文件 | 用途 |
|------|------|
| `scripts/entities/field_object_root.gd` | GridItem 的基类（29 行） |
| `scripts/entities/lawn_mower.gd` | 现有 FieldObject 实现参考（158 行） |
| `scripts/battle/board_slot.gd` | 角色占位 API（130 行） |
| `scripts/battle/battle_board_state.gd` | validate_request 检查链（734 行，关键行 223-281） |
| `scripts/battle/battle_field_object_state.gd` | 现有场物件管理参考（105 行） |
| `scripts/battle/entity_factory.gd` | 实体实例化（652 行，关键行 152-183） |
| `scripts/core/defs/combat_archetype.gd` | Archetype 定义（27 行） |
| `plans/draft/棋盘多样性与环境系统设计草案.md` | 棋盘草案（Phase 4 预留 GridItem） |
