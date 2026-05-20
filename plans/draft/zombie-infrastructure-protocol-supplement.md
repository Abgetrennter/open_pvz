# 原版僵尸复刻基础设施与协议补充草案

- 状态：设计草案
- 日期：2026-05-20
- 关联文档：
  - `plans/draft/zombie-replication.md`
  - `plans/zombie-design-research-report.md`
  - `wiki/decisions/ADR-008-Movement-一级家族新增.md`
- 目标：补齐原版僵尸复刻前需要先冻结或最小实现的运行时协议，避免后续把特殊僵尸逻辑写进 `ZombieRoot`、`Controller` 或 `BattleManager` 特判。

## 1. 总体结论

原版僵尸复刻不应继续新增多个 Mechanic family。若 ADR-008 通过，`Movement` 应是本阶段唯一新增一级 family，其余能力落在现有 family、运行时组件、Effect/Controller type 或 Battle 子系统中。

建议本阶段 family 收敛为：

```text
Trigger / Targeting / Emission / Trajectory / HitPolicy / Payload
State / Lifecycle / Placement / Controller / Movement
```

需要新增或补充的机制不是新 family，而是以下基础设施：

1. 多层生命层与伤害路由协议。
2. `damage_layer_policy`，支持投手等伤害绕过二类防具。
3. `Movement` 编译与运行协议。
4. `State` transition 的副作用协议。
5. 伤害暴露态协议：ground / airborne / flying / submerged / underground。
6. MovementCommand 的逻辑 Z 轴协议。
7. 轻量重量 / 推力抗性协议。
8. Controller 与 Movement 的执行顺序协议。
9. 召唤、GridItem、泳池/水面等后续协议缺口记录。

## 2. HealthLayer：多层生命层

当前路线图中的 `ArmorLayerDef` 建议泛化为 `HealthLayerDef`。原因是原版并不只有“护甲”：

| 原版概念 | 建议 layer_kind | 示例 |
|----------|-----------------|------|
| 可破坏外置部件 | `attachment` | Balloon 的气球 20 HP、未来飞艇外壳 |
| 二类防具 | `shield` | Screen Door / Newspaper / Ladder |
| 一类防具 | `helm` | Cone / Bucket / Football / Digger |
| 本体 | `body` | 所有僵尸本体 HP |
| 未来扩展 | `barrier` / `energy_shield` | 可恢复护盾、临时屏障 |

`flying` 不作为默认 HealthLayer 路由层。它描述“当前是否在空中”，应放在 `exposure_state` / HitPolicy 里；气球这类可被击破后导致落地的对象，建模为 `attachment` layer。

默认处理分两阶段：

```text
命中资格：根据 exposure_state / target_exposure_states 判断能否命中
伤害承接：根据 HealthLayer.route_order 路由伤害
```

默认伤害承接路由：

```text
attachment -> shield -> helm -> body
```

第一版只实现静态 HP 层，不实现自动恢复护盾。数据结构可以预留多层能力，但运行时只做当前原版僵尸必需的静态层。

建议 `HealthLayerDef` 字段：

```gdscript
@export var layer_id: StringName = StringName()
@export var layer_kind: StringName = StringName() # attachment / shield / helm / body_extra / barrier
@export var armor_type: StringName = StringName() # cone / pail / football / door / newspaper / ladder / digger / balloon
@export var max_health := 0
@export var route_order := 0
@export var material_tags: PackedStringArray = PackedStringArray()
@export var overflow_policy: StringName = &"spill_to_next" # spill_to_next / absorb_only
```

建议默认 `route_order`：

| layer_kind | route_order |
|------------|-------------|
| `attachment` | 10 |
| `shield` | 20 |
| `helm` | 30 |
| `body_extra` | 35 |
| `body` | 40 |

`body` 可以继续由 `max_health/current_health` 表示，不必强制写成资源层；但运行时路由应把 body 视为最后一层。

## 3. 一类 / 二类防具映射

原版的一类防具和二类防具不应只作为标签存在，它们有不同伤害路由语义。

| 僵尸 | 原版字段 | layer_kind | armor_type | HP |
|------|----------|------------|------------|----|
| Conehead | `mHelmType` | `helm` | `cone` | 370 |
| Buckethead | `mHelmType` | `helm` | `pail` | 1100 |
| Football | `mHelmType` | `helm` | `football` | 1400 |
| Digger | `mHelmType` | `helm` | `digger` | 100 |
| Screen Door | `mShieldType` | `shield` | `door` | 1100 |
| Newspaper | `mShieldType` | `shield` | `newspaper` | 150 |
| Ladder | `mShieldType` | `shield` | `ladder` | 500 |
| Balloon | `mFlyingHealth` | `attachment` | `balloon` | 20 |

`shield` 与 `helm` 的差异必须进入 `HealthComponent.take_damage()` 的路由规则，否则 Screen Door、Newspaper、Ladder 与 Cone/Bucket 的差异会退化成纯数值。

Balloon 的“飞行”语义不来自 `attachment` layer 本身，而来自实体当前 `exposure_state = &"flying"` 与 `hit_height_band = air_unit_low`。`balloon` layer 被击破后，通过 State transition 或 layer destroyed 事件把 `exposure_state` 改为 `ground`，并切换到地面高度与普通步行。

## 4. DamageLayerPolicy：伤害层路由策略

投手绕过防具不应写成“投手特判”，而应由 damage 携带路由策略。

第一版建议新增 `damage_layer_policy`：

```gdscript
{
	"bypass_layer_kinds": PackedStringArray(["shield"]),
	"spillover": true
}
```

默认伤害：

```text
attachment -> shield -> helm -> body
```

投手类伤害绕过二类防具：

```text
attachment -> helm -> body
```

第一版只需要支持：

- `bypass_layer_kinds = ["shield"]`
- `spillover = true`
- 未声明 policy 时走默认路由

`bypass_layer_kinds=["shield"]` 不会绕过 `attachment`。例如气球在空中时，投手若具备命中 `flying` 的能力，仍应先击破 `balloon` attachment，再进入后续层；若某种攻击要直接打本体，必须显式声明绕过 `attachment`、`shield`、`helm`。

暂不实现：

- 按方向绕过 shield
- 百分比穿透
- 按材质减伤
- 多段分摊
- 可恢复护盾

建议落点：

| 模块 | 变更 |
|------|------|
| `Effect.damage` | 新增可选参数 `damage_layer_policy` |
| `Effect.spawn_projectile` | 允许 projectile params 传递 `damage_layer_policy` 到 on-hit damage |
| `ProjectileTemplate.default_params` | 可为 basketball 等模板配置默认 policy |
| `HealthComponent.take_damage()` | 从 `runtime_overrides` 读取 policy 并执行路由 |
| `ProtocolValidator` | 校验 layer_kind 只允许已知值 |

## 5. 可恢复护盾暂缓

多层结构允许未来加入可恢复护盾，但不作为原版僵尸复刻前置。

未来可扩展字段示例：

```gdscript
regen_policy = {
	"enabled": true,
	"delay_after_damage": 3.0,
	"rate_per_sec": 20,
	"revive_when_broken": false
}
```

暂缓原因：

- 原版 25 个冒险模式僵尸不需要自动恢复护盾。
- 需要新增固定 tick 驱动、受伤后延迟、恢复事件和验证场景。
- 容易让第一版 HealthLayer 从路由协议膨胀成完整护盾系统。

## 6. Movement 基础协议

`Movement` family 合理，但初始 type 应按“运动算法”划分，而不是按僵尸名称划分。

推荐初始/中期 type：

| type_id | 用途 |
|---------|------|
| `core.walk` | 标准线性步行；方向、速度、高度由参数决定 |
| `core.leap_once` | Pole Vaulter / Dolphin Rider 的一次性跳越 |
| `core.hop_cycle` | Pogo 的周期弹跳 |
| `core.tunnel` | Digger 地下穿行与出土 |
| `core.drive` | Zomboni 等载具运动与减速曲线 |

不建议单独新增：

| 当前想法 | 建议 |
|----------|------|
| `core.reverse_walk` | 合并进 `core.walk(direction=+1)` |
| `core.fly` | v1 可用 `core.walk + State(height_band=flying)` 表达 |
| `core.submerge` | v1 可用 `core.walk + State(liveness/exposure=submerged)` 表达 |

Movement 的输出应是运动命令，不应直接造成伤害。MovementCommand 不只描述 2D 速度，也应描述逻辑高度，供 HitPolicy、Effect、SpatialIndex、Visual 和验证场景共同消费。

```gdscript
{
	"source_id": &"movement:core.walk",
	"command_kind": &"base", # base / modifier / override / impulse
	"ground_velocity": Vector2.LEFT * speed,
	"height": 0.0,
	"height_velocity": 0.0,
	"direction": -1,
	"height_band": &"ground_unit",
	"exposure_state": &"ground",
	"ground_contact": true,
	"interruptible": true,
	"lock_ground_velocity": false,
	"pause_reason": StringName()
}
```

### MovementCommand 职责边界

Movement type 负责产生命令，`MovementComponent` 负责合并、积分、同步 runtime state。`Controller` / `State` / `Effect` 不应直接改实体位置，而应提交约束、覆盖或脉冲：

| 来源 | 推荐表达 |
|------|----------|
| `Movement.core.walk` / `leap_once` / `drive` | 生成 `command_kind=base` |
| Status 减速 / 加速 | 生成或折算为 `modifier` |
| State transition 落地 / 出土 / 切换 movement | 生成 `override`，或替换当前 movement spec |
| 推力 / 击退 / 三叶草 | 生成 `impulse` 或独立 effect 结果，由 MovementComponent 消费 |
| Controller 咬击 / crush 判定 | 可请求暂停 movement，但不直接积分位置 |

这样跳跃、载具、地下、飞行都能进入同一条执行链，避免把特殊运动散落到 `ZombieRoot` 或各个 Controller 策略中。

### 命令合并规则

第一版不做完整物理 stack，只定义稳定、可验证的合并顺序：

```text
State override
  -> Movement base
  -> Status modifiers
  -> Effect impulses
  -> MovementComponent integrate
```

建议 `command_kind` 语义：

| command_kind | 语义 |
|--------------|------|
| `base` | 当前主运动命令，同一帧通常只有一个 |
| `modifier` | 对速度、方向、重力等做有限调整 |
| `override` | 强制改写当前帧结果，例如落地归零、硬控暂停 |
| `impulse` | 一次性推力 / 击退 / 风吹结果 |

若同一帧出现多个 `override`，应按明确优先级处理并记录 `protocol.issue`，不要依赖数组顺序产生隐式结果。v1 可只允许一个 active override。

### 暂停与打断

`pause_reason` 只说明运动暂停原因，不等同于关闭 Controller。需要区分：

- 啃咬：通常暂停 ground movement，但 Controller 继续执行攻击循环。
- 冰冻 / 睡眠：可通过 liveness 同时关闭 `movement`、`controllers`、`triggers`。
- 跳跃中：默认不应被普通近战目标逻辑停在半空；除非 MovementCommand 声明 `interruptible=true` 且 Controller 明确发出 interrupt。

建议保留两个轻量字段：

```gdscript
"interruptible": true
"lock_ground_velocity": false
```

`interruptible=false` 用于 Pole Vaulter 起跳、Dolphin 跳越等必须完成的短动作；`lock_ground_velocity=true` 用于落地、僵直或被强控时锁定当前帧地面速度。

`core.leap_once` / `core.hop_cycle` 应使用真实逻辑 Z 轴，而不是纯视觉动画。`MovementComponent` 统一积分：

```text
ground_position += ground_velocity * delta
height += height_velocity * delta
height_velocity += gravity * delta
```

落地时：

```text
height = 0
height_velocity = 0
exposure_state = ground
ground_contact = true
```

建议区分：

| exposure_state | 语义 |
|----------------|------|
| `airborne` | 跳跃 / 弹跳造成的短暂离地 |
| `flying` | 自带持续飞行能力 |

这样 Blover / 三叶草等效果可以通过参数决定是否影响 `airborne`、`flying` 或二者，而不是写死。

高度协议不变量：

- `height >= 0`。
- `ground_contact == true` 只在 `height` 归零且没有继续上升速度时成立。
- `airborne` 由真实逻辑 Z 轴造成，`flying` 由实体能力或状态造成。
- 命中高度由 `height + hit_height_range` / `height_band` 派生，不由视觉投影 y 坐标决定。
- MovementCommand 只更新事实状态；是否能命中仍由 HitPolicy / Effect filter / SpatialIndex `height_range` 决定。

建议 MovementComponent 同步以下 runtime state：

```gdscript
height = 0.0
height_velocity = 0.0
ground_contact = true
exposure_state = &"ground"
movement_source_id = &"movement:core.walk"
movement_pause_reason = StringName()
```

建议事件：

| 事件 | 用途 |
|------|------|
| `entity.movement_changed` | movement spec 或主 movement source 变化 |
| `entity.height_state_changed` | `ground` / `airborne` / `flying` 等暴露态变化 |
| `entity.landed` | 逻辑 Z 轴从离地回到地面 |
| `entity.movement_blocked` | movement 被 liveness、override 或 controller 暂停 |

Zomboni 示例：

- `Movement.core.drive`：处理速度曲线和位移。
- `Controller.core.crush`：处理接触即杀。
- 冰道 GridItem / lane modifier 延后。

## 7. State transition 副作用

当前 `StateComponent` 已有 transition 与 liveness override，但复杂僵尸还需要状态切换后修改运行时配置。

建议新增 transition 可选字段：

```gdscript
{
	"from_state": &"flying",
	"to_state": &"grounded",
	"trigger": "event",
	"event_name": &"health.layer_destroyed",
	"required_layer_id": &"balloon",
	"set_movement": {
		"type_id": &"core.walk",
		"params": {
			"move_speed_slots_per_sec": 0.28,
			"direction": -1
		}
	},
	"set_height_band": &"ground_unit"
}
```

建议第一版支持的副作用：

| 字段 | 用途 |
|------|------|
| `set_movement` | 切换或覆盖当前 movement spec |
| `set_height_band` | Balloon 落地、飞行状态切换 |
| `set_runtime_params` | Newspaper 狂暴、Yeti 逃跑速度 |
| `emit_event` | 需要对外暴露的状态进入结果 |

## 8. Exposure / HitPolicy 协议

原版有 flying / submerged / underground 等命中差异。Open PVZ 还会因为真实跳跃 Z 轴产生 `airborne`。当前可用 `targetable/damageable` 与 `height_range` 表达一部分，但还缺一层“规则上是否允许命中当前暴露态”的声明。

建议拆成两个职责：

| 概念 | 职责 |
|------|------|
| `Exposure` | 目标当前处在什么受击暴露态，是目标事实 |
| `HitPolicy` | 本次命中允许打哪些暴露态，是攻击声明 |

`Exposure` 不替代 `height_range`，`HitPolicy` 不负责护甲绕过。推荐命中流程：

```text
SpatialIndex 粗筛 team/lane/x/radius/height_range
  -> liveness: targetable / collidable / damageable
  -> HitPolicy exposure filter
  -> 精确几何命中
  -> DamageLayerPolicy 路由 attachment/shield/helm/body
```

职责边界：

- `height_range` 判断空间上碰不碰得到。
- `exposure_state` 判断目标当前规则暴露态。
- `target_exposure_states` 判断本次攻击规则上能不能打。
- `DamageLayerPolicy` 判断命中后由哪层承伤。
- `flying` / `submerged` / `underground` 不进入 HealthLayer 默认路由。

建议实体 runtime state 暴露：

```gdscript
exposure_state = &"ground" # ground / airborne / flying / submerged / underground
```

建议 v1 只定义 5 个状态：

| 状态 | 语义 |
|------|------|
| `ground` | 普通地面暴露态，默认值 |
| `airborne` | 跳跃、弹起、出土等短暂离地或过渡态 |
| `flying` | 自带持续飞行能力 |
| `submerged` | 潜水 / 水下暴露态 |
| `underground` | 地下穿行 / 挖掘态 |

暂不新增 `off_ground`。原版有类似 `DAMAGES_OFF_GROUND` 的概念，但 Open PVZ 第一版可先用 `airborne` 覆盖短暂离地 / 出土 / 跳跃等过渡态，避免过早分裂。

HitPolicy / Effect 可声明：

```gdscript
target_exposure_states = PackedStringArray(["ground", "airborne", "flying"])
```

默认值建议：

- 未显式声明时，默认 `target_exposure_states=["ground"]`。
- 迁移期可允许空值表示“不检查 exposure”，但正式协议应收紧到 `ground` 默认。
- `flying`、`submerged`、`underground` 必须显式 opt-in。

示例：

| 类型 | target_exposure_states |
|------|------------------------|
| 普通地面豌豆 | `["ground"]` |
| 对空攻击 | `["flying"]` |
| 投手 / 抛物线攻击 | `["ground", "airborne"]`，是否打 `flying` 由内容显式声明 |
| 三叶草 / 推力类效果 | `["flying", "airborne"]`，再叠加 `height` 与 `weight_class` |

第一版最低要求：

- `Balloon`: `flying -> ground`
- `Pole Vaulter / Pogo / Dolphin`: `ground -> airborne -> ground`
- `Digger`: `underground -> ground`
- `Snorkel`: `submerged -> ground`

若第一版不实现完整 filter，也应至少把 `exposure_state` 同步进 `EntityState`，供验证场景和后续协议消费。

P1 结论：复杂批次前需要定下该协议。Balloon、Digger、Snorkel、Pole Vaulter、Dolphin、Pogo 都会触发暴露态差异；若不提前冻结默认值和字段名，后续很容易在 HitPolicy、Effect、HealthLayer 和 State transition 中出现多套临时过滤口径。

Balloon 示例：

```gdscript
exposure_state = &"flying"

health_layers = [{
	"layer_id": &"balloon",
	"layer_kind": &"attachment",
	"armor_type": &"balloon",
	"max_health": 20,
	"route_order": 10
}]
```

未来飞艇或天然飞行实体可以没有 `balloon` layer，直接使用 `exposure_state = &"flying"` 并让 damage 进入 `shield/helm/body` 或自定义 `body_extra`。因此 `flying` 不能被固定进 HealthLayer 默认路由。

## 9. 轻量重量 / 推力抗性协议

重量机制是非原版扩展，但适合 Open PVZ 的可组合规则目标。它不应做成真实物理质量、动量或风阻系统；第一版只作为风、推力、击退、拖拽等效果的过滤条件。

建议字段：

```gdscript
weight_class = &"normal" # light / normal / heavy / massive / fixed
```

建议顺序：

```text
light < normal < heavy < massive < fixed
```

效果参数示例：

```gdscript
{
	"target_exposure_states": PackedStringArray(["flying", "airborne"]),
	"max_weight_class": &"normal",
	"min_height": 12.0
}
```

Blover / 三叶草判断：

```text
exposure_state in target_exposure_states
and height >= min_height
and weight_class <= max_weight_class
```

示例：

| 实体 / 状态 | exposure_state | weight_class | 三叶草结果 |
|-------------|----------------|--------------|------------|
| Balloon | `flying` | `normal` | 可吹 |
| Pole Vaulter 跳跃中 | `airborne` | `normal` | 由效果参数决定 |
| Pogo 跳跃中 | `airborne` | `normal` / `heavy` | 由内容配置决定 |
| Gargantuar | `ground` / `airborne` | `massive` | 默认吹不动 |
| Zomboni | `ground` | `massive` | 默认吹不动 |
| 固定场上物件 | `ground` | `fixed` | 不受推力 |

边界：

- `weight_class` 不影响普通移动速度。
- `weight_class` 不参与伤害计算。
- `weight_class` 不替代 `exposure_state`。
- `weight_class` 不引入连续物理模拟。
- 若未来需要更细，可新增 `force_resistance` 数值；v1 不需要。

建议落点：

| 模块 | 变更 |
|------|------|
| `CombatArchetype` | 新增可选 `weight_class`，默认 `normal` |
| `EntityState` | 同步 `weight_class` |
| `Effect.dispel_flying` 或后续推力类 effect | 支持 `target_exposure_states`、`max_weight_class`、`min_height` |
| `ProtocolValidator` | 校验 `weight_class` 枚举 |

## 10. Controller / Movement 执行顺序

建议固定一帧执行顺序：

```text
State transition
  -> Controller decision
  -> Movement command generation
  -> Movement command merge
  -> MovementComponent integrate
  -> sync_runtime_state
```

边界规则：

- Controller 可以请求暂停 movement，例如正在咬击。
- Controller 不直接积分位置。
- Movement 不造成伤害。
- `MovementComponent` 是唯一默认位置积分点。
- 特殊瞬移或跳越也应通过受控 MovementCommand 表达，而不是策略脚本随意改 `owner.position`。
- State transition 可以替换 movement spec 或产生 `override`，但不绕过 MovementComponent。
- Effect 推力 / 击退可以进入 `impulse`，但命中资格仍由 Effect 自己先过滤。

## 11. 后续协议缺口

以下能力不作为 Wave 0 前置，但需要在路线图中明确归属：

| 缺口 | 建议归属 |
|------|----------|
| Screen Door 方向性挡弹 | `damage_layer_policy` v2 + projectile direction metadata |
| Magnet-shroom 吸取金属 | Effect / Controller，按 `material_tags=["metal"]` 找 layer |
| Blover / 三叶草推力 | Effect，按 `exposure_state + height + weight_class` 过滤 |
| Ladder 架梯 | GridItem / board slot modifier |
| Zomboni 冰道 | GridItem 或 lane modifier |
| 泳池 / 水面 | lane traits + spawn zone + exposure state |
| Bungee 偷植物 | Lifecycle/State 序列 + remove/replace entity effect |
| Dancer 召唤 | `Payload.spawn_entity` 扩展相对位置 / 批量 spawn |
| Gargantuar 投 Imp | HP 阈值 trigger + one-shot guard + spawn_entity |
| Yeti 稀有生成 | WaveRunner / spawn weighting，不属于 entity mechanic |

## 12. 建议落地顺序

### Wave 0a：HealthLayer v1

- 新增 `HealthLayerDef`。
- `CombatArchetype` 增加 `health_layers` 或兼容 `armor_layers` 字段。
- `HealthComponent` 支持静态多层路由。
- 支持 `layer_destroyed` 事件。
- 验证 `attachment` / `helm` / `shield` 三类路由。

### Wave 0b：DamageLayerPolicy v1

- `Effect.damage` 支持 `damage_layer_policy`。
- projectile on-hit damage 可透传 policy。
- 验证 basketball / 投手类伤害绕过 `shield`，但不绕过 `helm`。

### Wave 0c：Movement v1

- ADR-008 若通过，新增 `Movement` family。
- 新增 `RuntimeSpec.movement_spec`。
- 新增 `MovementRegistry`。
- 实现 `Movement.core.walk`。
- 定义 MovementCommand 基础字段：`source_id`、`command_kind`、`ground_velocity`、`height`、`height_velocity`、`exposure_state`、`ground_contact`、`interruptible`、`pause_reason`。
- `MovementComponent` 支持 `base / modifier / override / impulse` 的最小合并规则。
- 同步 `height`、`height_velocity`、`ground_contact`、`movement_source_id`、`movement_pause_reason` 到 runtime state。
- 新建原版 Batch A 僵尸优先走 `Movement.core.walk`。

### Wave 0d：State side-effects v1

- State transition 支持 `set_movement`、`set_height_band`、`set_runtime_params`。
- 验证 Balloon 落地、Newspaper 狂暴或 Digger 出土中的一个最小闭环。

### Wave 0e：Exposure / Weight v1

- EntityState 同步 `exposure_state`、`height`、`ground_contact`、`weight_class`。
- HitPolicy / Effect 统一使用 `target_exposure_states`。
- 默认 `target_exposure_states=["ground"]`，特殊暴露态必须显式 opt-in。
- Projectile hit candidate 与 direct damage effect 支持 exposure filter。
- `weight_class` 只作为推力/击退类 effect 过滤条件。
- 验证 Blover / 三叶草类效果可按 `flying` / `airborne` / `weight_class` 参数过滤目标。
- P1：复杂僵尸批次前冻结 Exposure / HitPolicy 字段名、默认值和验证口径。

### Wave 1：原版基础近战

- Basic / Flag / Conehead / Buckethead。
- 同时验证 `walk`、`helm` 和基础 body 伤害。

## 13. 需要回写的文档

若本草案被接受，后续需要回写：

| 文档 | 回写点 |
|------|--------|
| `plans/draft/zombie-replication.md` | Wave 0 拆分为 HealthLayer / DamageLayerPolicy / Movement / State side-effects / Exposure-Weight |
| `wiki/decisions/ADR-008-Movement-一级家族新增.md` | 收窄 Movement type 清单，删除 `reverse_walk`，拆出 `Controller.core.crush` |
| `wiki/02-runtime-protocol/04-效果系统.md` | 记录 `damage_layer_policy` |
| `wiki/02-runtime-protocol/08-连续行为模型.md` | 记录 MovementCommand 字段、命令合并、逻辑 Z 轴、Movement 与 Controller 执行顺序 |
| `wiki/02-runtime-protocol/17-实体活跃性与空间查询.md` | 记录 exposure filter 与 `height_range`、liveness、SpatialIndex 的边界 |
| `wiki/02-runtime-protocol/11-编译链与Mechanic系统.md` | 若 ADR-008 通过，family 数量更新为 11 |
| `wiki/03-content-validation/32-验证矩阵.md` | 新增 HealthLayer / Movement / damage routing / exposure filter 验证 |

## 14. 验证建议

建议新增验证场景：

| 场景 | 断言 |
|------|------|
| `health_layer_helm_routing_validation` | Cone helm 先扣，过伤进 body |
| `health_layer_shield_routing_validation` | Screen Door shield 先扣，body 不提前受伤 |
| `health_layer_attachment_routing_validation` | Balloon attachment 层击破后进入 grounded |
| `damage_layer_policy_bypass_shield_validation` | 投手伤害绕过 shield，但仍命中 helm/body |
| `movement_walk_validation` | `Movement.core.walk` 等价当前左行 |
| `movement_command_merge_validation` | base / modifier / override 的合并顺序稳定 |
| `movement_leap_z_axis_validation` | leap_once 产生 `airborne`、height 上升与落地 |
| `movement_interrupt_validation` | `interruptible=false` 的跳跃不会被普通咬击暂停在半空 |
| `state_side_effect_set_movement_validation` | 状态切换后 movement params 生效 |
| `hit_policy_exposure_ground_default_validation` | 默认 HitPolicy 只命中 `ground` |
| `hit_policy_exposure_flying_validation` | 显式对空 HitPolicy 可命中 `flying`，普通地面攻击不可命中 |
| `hit_policy_exposure_hidden_validation` | `submerged` / `underground` 默认不可被普通攻击命中 |
| `force_weight_filter_validation` | 三叶草类效果按 exposure + weight_class 过滤 |

完成标准：

- 无 layer 的实体保持现有单层 HP 行为。
- `attachment`、`helm`、`shield` 三类 layer 均有验证。
- `damage_layer_policy.bypass_layer_kinds=["shield"]` 有验证。
- 新增原版僵尸不依赖 `ZombieRoot` 硬编码左行。
- 跳跃类 Movement 同步 `height`、`exposure_state=airborne` 与 `ground_contact=false`。
- MovementCommand 合并顺序有验证，不依赖数组偶然顺序。
- `entity.landed` 或等价可观测事件可验证跳跃闭环。
- HitPolicy / Effect 统一使用 `target_exposure_states`，不再新增 `damage_exposure_filter` 并行字段。
- 默认攻击只命中 `ground`，`flying`、`submerged`、`underground` 必须显式 opt-in。
- 推力类效果可按 `weight_class` 和 `exposure_state` 过滤。
- 不新增除 `Movement` 外的其他 Mechanic family。
