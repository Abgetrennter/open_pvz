# 僵尸设计研究报告：三源综合分析

- 状态：设计讨论
- 日期：2026-05-20
- 作者：Sisyphus
- 事实来源：`vendor/de-pvz/`（原版反编译）、`vendor/PVZ-Godot-Dream/`（参考实现）、本项目代码与 wiki
- 可作为当前实现依据：是（分析结论），否（需设计审批后执行）

> 维护注记（2026-05-20）：本文的研究结论仍可用；基础设施执行口径已由 `plans/draft/zombie-infrastructure-protocol-supplement.md` 和正式 wiki 回写收口。旧文中的 `ArmorLayerDef / armor_layers` 统一按 `HealthLayerDef / health_layers` 理解；`core.vault/core.bounce` 只表示后续复杂 Movement type 需求，v1 已落地类型为 `core.walk` 与 `core.leap_once`。

---

## 1. 研究目标

基于三个来源，综合分析僵尸内容的设计方案：

1. **原版 de-pvz**（C++ 反编译）：权威数值来源，25 种冒险僵尸的 HP/速度/护甲/行为定义
2. **PVZ-Godot-Dream**（GDScript 参考实现）：架构参考，26 种僵尸的继承/组件/行为模式
3. **Open PVZ**（本项目）：当前实现状态，10 种测试/正式僵尸 archetype

核心问题：
- 原版 25 种僵尸需要哪些行为能力？
- 当前 Mechanic-first 架构能否覆盖？
- 需要哪些基础设施扩展？

---

## 2. 原版僵尸数值速查表

> 来源：`vendor/de-pvz/Lawn/Zombie.cpp` — `ZombieInitialize()` + `PickRandomSpeed()`

### 2.1 HP 与护甲系统

原版使用**四层伤害路由**（`TakeDamage`，Zombie.cpp）：

```
Flying HP → Shield HP → Helm HP → Body HP（过伤传递）
```

| # | 类型 | Body | Shield | Helm | Flying | 总有效HP | 护甲材质 |
|---|------|------|--------|------|--------|----------|---------|
| 1 | Normal | 270 | — | — | — | **270** | — |
| 2 | Flag | 270 | — | — | — | **270** | — |
| 3 | Conehead | 270 | — | 370(CONE) | — | **640** | 塑料 |
| 4 | Pole Vaulter | 500 | — | — | — | **500** | — |
| 5 | Buckethead | 270 | — | 1100(PAIL) | — | **1370** | 金属 |
| 6 | Newspaper | 270 | 150(PAPER) | — | — | **420** | 纸质 |
| 7 | Screen Door | 270 | 1100(DOOR) | — | — | **1370** | 金属+方向性 |
| 8 | Football | 270 | — | 1400(FOOTBALL) | — | **1670** | 金属 |
| 9 | Dancer | 500 | — | — | — | **500** | — |
| 10 | Backup Dancer | 270 | — | — | — | **270** | — |
| 11 | Ducky Tube | 270 | — | — | — | **270** | — |
| 12 | Snorkel | 270 | — | — | — | **270** | — |
| 13 | Zamboni | 1350 | — | — | — | **1350** | — |
| 14 | Bobsled | 270×4 | 300(sled) | — | — | **队1380** | — |
| 15 | Dolphin Rider | 500 | — | — | — | **500** | — |
| 16 | Jack-in-the-Box | 500 | — | — | — | **500** | — |
| 17 | Balloon | 270 | — | — | 20 | **290** | — |
| 18 | Digger | 270 | — | 100(DIGGER) | — | **370** | 金属(可被磁力吸取) |
| 19 | Pogo | 500 | — | — | — | **500** | 金属弹簧 |
| 20 | Yeti | 1350 | — | — | — | **1350** | — |
| 21 | Bungee | 450 | — | — | — | **450** | — |
| 22 | Ladder | 500 | 500(LADDER) | — | — | **1000** | 金属+防火 |
| 23 | Catapult | 850 | — | — | — | **850** | — |
| 24 | Gargantuar | 3000 | — | — | — | **3000** | — |
| 25 | Imp | 70 | — | — | — | **70** | — |

### 2.2 速度系统

原版使用 `PickRandomSpeed()` 为每种僵尸分配速度区间：

| 速度类别 | 速度值（slots/sec 估算） | 适用僵尸 |
|----------|------------------------|---------|
| 极慢 | ~0.12 | Digger 步行 |
| 慢 | 0.23-0.32 | Normal, Cone, Bucket, Door, Balloon(落地) |
| 中慢 | ~0.40 | Yeti |
| 中等 | ~0.45 | Flag, Dancer, Backup, Pogo |
| 快 | 0.66-0.68 | Pole Vaulter, Football, Snorkel, Jack-in-the-Box, Digger(穿行) |
| 更快 | 0.79-0.81 | Ladder |
| 很快 | 0.89-0.91 | Newspaper(狂暴), Dolphin(步行), Pole Vaulter(弃杆后) |
| 逃跑 | ~0.80 | Yeti 逃跑 |
| 冰冻 | ×0.4 | 所有僵尸被冰冻后 |

### 2.3 行为分类

按行为复杂度将 25 种僵尸分为 6 类：

| 类别 | 僵尸 | 核心行为模式 |
|------|------|------------|
| **基础近战** | Normal, Flag, Conehead, Buckethead | 步行 + 咬 |
| **高速重甲** | Football, Screen Door | 快速步行 + 咬 + 高护甲 |
| **移动变体** | Pole Vaulter, Pogo, Digger | 跳越/弹跳/穿行 + 咬 |
| **水面** | Ducky Tube, Snorkel, Dolphin Rider | 水陆两用/潜水/跳越 |
| **远程/特殊** | Newspaper, Jack-in-the-Box, Balloon, Yeti, Bungee, Ladder, Catapult | 狂暴/爆炸/飞行/偷取/搭桥/投篮 |
| **巨型/召唤** | Gargantuar, Imp, Dancer, Backup Dancer | 砸击+投掷/被召唤/跳舞+召唤 |

---

## 3. 参考实现架构分析

> 来源：`vendor/PVZ-Godot-Dream/`

### 3.1 继承 + 组件模式

```
Node2D → Character000Base → Zombie000Base → Zombie001Norm / Zombie004PoleVaulter / ...
```

关键组件：
- **HpComponentZombie**：三层护甲（body + armor1 + armor2），5 种攻击模式
- **MoveComponent**：双模式（Ground/Speed），多因子使能门
- **DetectComponent**：Area2D 射线检测，按 BeAttackStatus 过滤
- **AttackComponent**：咬击/碾压/投篮，8 帧攻击循环
- **JumpComponent**：通用跳越（撑杆/海豚共用）
- **BeAttackStatus**：位掩码（Norm/Jump/DownPool/Sky/DownGround）

### 3.2 波次生成系统

- **Power-based**：每种僵尸有 power 值（Norm=1, Cone=2, Bucket=4, Football=7, Gargantuar=10）
- **Wave power**：`wave/3 + 1`（大波 ×2.5）
- **Row types**：Land / Pool / Both
- **Weight decay**：Norm/Cone 权重随波次递减，增加难度

---

## 4. 本项目现状与差距

### 4.1 已实现的 10 种僵尸

| Archetype | 模拟原版 | Mechanic | 差距 |
|-----------|---------|----------|------|
| `basic_walker` | ≈ Normal | bite | HP 270，速度 0.34，基本匹配 |
| `brisk_runner` | — | bite | 测试用高速僵尸 |
| `bucket_tank` | ≠ Buckethead | bite | HP 500（应为 body270+helm1100=1370） |
| `air_scout` | ≠ Balloon | bite | 无飞行层，无落地机制 |
| `boss_heavy` | ≠ Gargantuar | bite | 无砸击，无投掷 |
| `bone_thrower` | — | ranged | ✅ 验证远程攻击 |
| `tar_spitter` | — | ranged+status | ✅ 验证状态施加 |
| `reactive_bomber` | — | explode | ✅ 验证触发/爆炸 |
| `lane_dummy` | — | bite | 测试靶标 |
| `basic_zombie_skeleton` | — | bite | 编译管线测试 |

### 4.2 基础设施差距

| 优先级 | 差距 | 影响范围 | 原版参考 |
|--------|------|---------|---------|
| **P0** | 分层血量系统 | 7+ 护甲僵尸 | de-pvz: Flying→Shield→Helm→Body |
| **P1** | 运动控制家族（Movement） | 7 运动变体僵尸 | 见 ADR-008 |
| **P1** | 跳越/翻越能力 | Pole Vaulter, Dolphin Rider, Pogo | PVZ-Godot-Dream: JumpComponent |
| **P2** | 水面/泳池语义 | Ducky Tube, Snorkel, Dolphin Rider | de-pvz: ZombieTypeCanGoInPool |
| **P2** | 多阶段行为序列 | Bungee, Digger, Dancer | PVZ-Godot-Dream: Phase/state machine |
| **P3** | 方向性护盾 | Screen Door | de-pvz: ShieldType 方向判定 |
| **P3** | 召唤/生成 Entity | Dancer, Gargantuar | Payload.spawn_entity ✅ 已有 |

---

## 5. Family 适配分析

### 5.1 可直接复用的 Family（无需修改）

| Family | 已有 type | 覆盖的僵尸行为 |
|--------|----------|---------------|
| Trigger | periodically, when_damaged, on_death, on_spawned, proximity | 远程射击、受伤触发、死亡爆炸 |
| Targeting | lane_backward, proximity, radius_around, global_track | 远程僵尸的目标发现 |
| Payload | damage, spawn_projectile, explode, apply_status, spawn_entity | 伤害、投射、爆炸、召唤 |
| Placement | — | 僵尸不需要（波次生成） |

### 5.2 需要新增 type 的 Family

| Family | 需新增 type | 用途 |
|--------|-----------|------|
| Controller | `core.crush` (碾压), `core.catapult_fire` (投篮) | Zamboni, Catapult 的攻击行为 |
| State | 支持含 movement_override 的转换 | Digger 出土、Balloon 落地等状态驱动运动切换 |
| Effect | `modify_param` (修改实体参数如速度) | Newspaper 狂暴、Yeti 逃跑的速度变更 |

### 5.3 需要新增的 Family

**Movement**（详见 ADR-008）：

| type_id | 语义 | 适用僵尸 |
|---------|------|---------|
| `core.walk` | 标准左行 | 大部分僵尸 |
| `core.leap_once` + 后续 vault 专项 | 单次跳越基础设施 | Pole Vaulter, Dolphin Rider |
| 后续 `hop_cycle` | 周期弹越 | Pogo |
| `core.tunnel` | 地下穿行 | Digger |
| `core.fly` | 空中飞行 | Balloon |
| `core.drive` | 碾压前进+减速 | Zamboni |
| `core.reverse_walk` | 反向步行 | Yeti 逃跑 |
| `core.submerge` | 潜水移动 | Snorkel |

---

## 6. 僵尸 Mechanic 组合设计

每种原版僵尸的 Mechanic 组合方案：

### 6.1 基础近战（4 种）

| 僵尸 | Movement | Controller | State | Payload | 特殊 |
|------|----------|------------|-------|---------|------|
| Normal | `core.walk(0.28)` | `core.bite` | — | — | — |
| Flag | `core.walk(0.45)` | `core.bite` | — | — | 旗帜波次标记（WaveRunner 层） |
| Conehead | `core.walk(0.28)` | `core.bite` | — | — | health_layers: [{cone: 370, helm}] |
| Buckethead | `core.walk(0.28)` | `core.bite` | — | — | health_layers: [{bucket: 1100, helm, metal}] |

### 6.2 高速重甲（2 种）

| 僵尸 | Movement | Controller | State | Payload | 特殊 |
|------|----------|------------|-------|---------|------|
| Football | `core.walk(0.67)` | `core.bite` | — | — | health_layers: [{football_helm: 1400, helm, metal}] |
| Screen Door | `core.walk(0.28)` | `core.bite` | — | — | health_layers: [{door: 1100, shield, metal, directional}] |

### 6.3 移动变体（3 种）

| 僵尸 | Movement | Controller | State | 特殊 |
|------|----------|------------|-------|------|
| Pole Vaulter | `core.leap_once` + 后续 vault 专项 → `core.walk(0.89)` | `core.bite` | vaulting → walking | vault 触发: proximity |
| Pogo | 后续 `hop_cycle` → `core.walk(0.45)` | `core.bite` | bouncing → grounded | bounce 失去弹簧: magnet |
| Digger | 后续 `tunnel` → `core.walk(0.12, dir=+1)` | `core.bite` | underground → emerged | health_layers: [{digger_helm: 100, helm}] |

### 6.4 水面（3 种）

| 僵尸 | Movement | Controller | State | 特殊 |
|------|----------|------------|-------|------|
| Ducky Tube | `core.walk(0.28)` | `core.bite` | — | water 标签（水面语义延后） |
| Snorkel | `core.submerge` → `core.walk(0.67)` | `core.bite` | submerged → surfaced | 潜水: untargetable + damageable=false |
| Dolphin Rider | `core.leap_once` + 后续 vault/pool 专项 → `core.walk(0.28)` | `core.bite` | riding → walking | 复用跳跃基础设施，跳跃后降速 |

### 6.5 远程/特殊（7 种）

| 僵尸 | Movement | Controller | Trigger | Payload | 特殊 |
|------|----------|------------|---------|---------|------|
| Newspaper | `core.walk(0.28→0.89)` | `core.bite` | when_damaged(armor_destroyed) | modify_param(speed) | armor: [{paper: 150}] |
| Jack-in-the-Box | `core.walk(0.67)` | — | periodically(ShuffleBag timer) | explode(r=90/115) | 确定性随机引信 |
| Balloon | `core.fly` → `core.walk(0.28)` | `core.bite` | when_damaged(balloon_destroyed) | — | flying_hp: 20 |
| Yeti | `core.walk(0.4)` → `core.reverse_walk(0.8)` | `core.bite` | when_damaged(first_hit) | modify_param(speed, direction) | 逃跑→消失 |
| Bungee | — | — | on_spawned | destroy_target + remove_entity | 空降序列：降→偷→飞 |
| Ladder | `core.walk(0.80)` | `core.bite` | proximity(plant) | spawn_entity(ladder_field_object) | armor: [{ladder: 500, metal}] |
| Catapult | `core.walk(0.28)` | — | periodically | spawn_projectile(parabola, 20发) | 停位射击 |

### 6.6 巨型/召唤（4 种）

| 僵尸 | Movement | Controller | Trigger | Payload | 特殊 |
|------|----------|------------|---------|---------|------|
| Gargantuar | `core.walk(0.28)` | `core.crush` | when_damaged(HP<1500) | spawn_entity(imp) | HP=3000 |
| Imp | `core.walk(0.9)` | `core.bite` | on_spawned | — | 被投掷生成 |
| Dancer | `core.walk(0.45)` | `core.bite` | periodically | spawn_entity(backup_dancer)×4 | HP=500 |
| Backup Dancer | `core.walk(0.45)` | `core.bite` | — | — | 被召唤，HP=270 |

---

## 7. 协议缺口追踪

以下为僵尸实现中需要标记为"延后"的协议缺口：

| 缺口 | 影响僵尸 | 当前处理 | 延后理由 |
|------|---------|---------|---------|
| 水面/泳池 lane 语义 | Ducky Tube, Snorkel, Dolphin Rider | 标记 water 标签 | 需 BattleBoardState 扩展 |
| 冰道效果 | Zamboni | 标记 ice_trail 标签 | 需 Board 场景物件系统 |
| Screen Door 方向性 | Screen Door | shield 作为通用减伤层 | 需 HitPolicy 扩展 |
| Magnet-shroom 吸取金属 | Bucket, Football, Digger, Pogo, Ladder | 延后 | 需植物端能力 |
| Blover 驱散飞行 | Balloon | 延后 | 需植物端能力 |
| Umbrella Leaf 防护 | Bungee | 延后 | 需植物端能力 |
| Tall-nut 阻挡跳越 | Pole Vaulter, Pogo | Movement 内部处理 | vault/bounce 检测高坚果标签 |
| Boss 战模式 | Dr. Zomboss | 不在本轮范围 | 需独立设计 |
| Yeti 稀有生成 | Yeti | WaveRunner 层处理 | 生成权重=1 |
| Bobsled 4 人小队 | Bobsled | 不在本轮范围 | 依赖冰道系统 |

---

## 8. 建议的执行路线

### Phase 0（前置，BLOCKING）

- **P0a**: 分层血量系统 — `HealthLayerDef` + HealthComponent 扩展
- **P0b**: Movement family 基础设施 — MovementRegistry + `core.walk` / `core.leap_once` + 回归验证

### Phase 1（Batch A — 基础近战，全部 quick）

- Normal, Flag, Conehead, Buckethead
- 全部使用 `core.walk` + `core.bite`
- Conehead/Buckethead 使用 health_layers

### Phase 2（Batch B — 高速/特殊移动）

- Football, Screen Door: health_layers + 高速 walk
- Newspaper: armor + when_damaged → speed boost
- Pole Vaulter: `core.leap_once` + 后续 vault 专项 Movement

### Phase 3（Batch C — 水面/载具）

- Ducky Tube: 标准 walk + water 标签
- Snorkel: `core.submerge` Movement
- Dolphin Rider: 复用 vault
- Zamboni: `core.drive` Movement

### Phase 4（Batch D — 复杂行为）

- Balloon, Jack-in-the-Box, Digger, Pogo, Yeti, Bungee, Ladder, Catapult

### Phase 5（Batch E — 巨型/召唤）

- Dancer, Backup Dancer, Gargantuar, Imp

---

## 9. 关联文档

- [ADR-008 Movement 一级家族新增](../wiki/decisions/ADR-008-Movement-一级家族新增.md)
- [僵尸复刻路线图草案](draft/zombie-replication.md)
- [原版实体复刻工作流](../wiki/05-governance/36-原版实体复刻工作流.md)
- [编译链与 Mechanic 系统](../wiki/02-runtime-protocol/11-编译链与Mechanic系统.md)
- [连续行为模型](../wiki/02-runtime-protocol/08-连续行为模型.md)

---

## 10. 数据来源索引

| 来源 | 关键文件 | 用途 |
|------|---------|------|
| de-pvz | `Lawn/Zombie.cpp` ZombieInitialize() | 权威 HP/速度/护甲数值 |
| de-pvz | `Lawn/Zombie.h` | Zombie 类字段定义（四层血量） |
| de-pvz | `Lawn/Challenge.cpp` gZombieDefs[] | 僵尸定义表（分值/起始关/权重） |
| de-pvz | `ConstEnums.h` ZombieType 枚举 | 33 种僵尸类型枚举 |
| PVZ-Godot-Dream | `scripts/character/zombie/zombie_000_base.gd` | 僵尸基类架构 |
| PVZ-Godot-Dream | `scripts/character/components/component_move.gd` | 双模式运动系统 |
| PVZ-Godot-Dream | `scripts/character/components/hp_component/component_hp_zombie.gd` | 三层护甲 HP 系统 |
| PVZ-Godot-Dream | `scripts/character/components/component_jump.gd` | 通用跳越组件 |
| PVZ-Godot-Dream | `scripts/manager/zombie_manager/zm_zombie_wave_create_manager.gd` | Power-based 波次生成 |
| Open PVZ | `scripts/entities/zombie_root.gd` | 当前僵尸运行时 |
| Open PVZ | `data/combat/archetypes/zombies/` | 10 种僵尸 archetype |
| Open PVZ | `plans/draft/zombie-replication.md` | 25 僵尸复刻计划草案 |
