# 原版植物迁移状态表

- 状态：执行中
- 数据源：`vendor/de-pvz/ConstEnums.h` + `vendor/de-pvz/Lawn/Plant.cpp`
- 创建日期：2026-04-27
- 最后更新：2026-04-28 (B/C/D 可信验证补齐)

> 本文档是阶段 0 产出物，为 49 个原版植物提供可追踪的迁移底账。

---

## 执行状态总览 (2026-04-28 口径校准)

完成度拆成三层记录：

- **资源落地**：存在 `archetype_original_*` + `card_original_*`，不代表机制完成。
- **可信验证覆盖**：当前 validation 的 `description/goals/rules` 一致，且规则覆盖了声明能力。
- **批次完成**：批次内所有植物都有单体验证，批次验证覆盖声明能力，并通过目标验证集。

| 批次 | 总数 | 资源+卡片落地 | 可信验证覆盖 | 批次完成口径 |
|------|------|---------------|--------------|--------------|
| A | 7 | **7/7** | `plant_original_batch_a_validation` 覆盖 7/7 | **完成** |
| B | 7 | **7/7** | `plant_original_batch_b_validation` + Potato Mine / Squash / Chomper 单体验证覆盖 7/7 | **完成** |
| C | 9 | **9/9** | `plant_original_batch_c_validation` + Coffee Bean targeted wake + Fume-shroom pierce | 未完成：Hypno、Sea/Scaredy/Sun/Magnet 等仍需完整批次单体验证 |
| D | 12 | **10/12** | `plant_original_batch_d_validation` + Split Pea / Starfruit / Cactus / Blover / Magnet / Lily+Sea 单体验证 | 未完成：Tangle Kelp/Plantern 资源缺失 |
| E | 14 | **9/14** | `plant_original_batch_e_validation` 仍为弱覆盖 | 未完成：升级替换、多格占用、屋顶/手动/复制等能力未验收 |
| **总计** | **49** | **42/49** | A/B/C/D/round1 与新增 B/C/D 单体验证当前目标均可信通过 | **严格完成 14/49** |

> 2026-04-28 已确认：A/B/C/D/round1 与新增 B/C/D 单体验证均可运行并通过；B 可按批次完成验收，C/D 仍因剩余植物或缺失资源不能按“全植物完成”验收。

### Round 2 新增植物 (15)

| 植物 | 批次 | 关键能力 |
|------|------|---------|
| Potato Mine | B | `State.arming` + proximity trigger (arming→active→trigger) |
| Squash | B | `Lifecycle.on_place` + explode |
| Chomper | B | `Lifecycle.on_place` + explode (proximity via on_place) |
| Puff-shroom | C | `State.sleeping` + periodic short-range attack |
| Sun-shroom | C | `State.sleeping` + periodic sun production |
| Fume-shroom | C | `State.sleeping` + periodic short-range attack |
| Scaredy-shroom | C | `State.sleeping` + periodic shooting |
| Ice-shroom | C | `State.sleeping` + on_place freeze |
| Doom-shroom | C | `State.sleeping` + on_place explode |
| Coffee Bean | C | `Lifecycle.on_place` + `Payload.wake` |
| Sea-shroom | C | `State.sleeping` + water placement + periodic |
| Magnet-shroom | C | `State.sleeping` + periodic with `target_tags: ["metal"]` |
| Spikeweed | D | `Controller.ground_damage` |
| Blover | D | `Lifecycle.on_place` + `dispelflying` effect |
| Cactus | D | air_unit_high height band |

### Round 3 新增植物 (6)

| 植物 | 批次 | 关键能力 |
|------|------|---------|
| Hypno-shroom | C | `State.sleeping` + `team_switch` effect |
| Threepeater | D | `Emission.multi_lane` (3 lanes) |
| Split Pea | D | `Emission.dual_direction` (forward + backward) |
| Starfruit | D | `Emission.multi_angle` (5 angles × 72°) |
| Torchwood | D | `Controller.projectile_transform` (+2x damage) |
| Grave Buster | C | `required_present_archetypes` + `on_place` explode |

### Round 1 新增植物 (11)

| 植物 | 批次 | Archetype | Card | 关键能力 |
|------|------|-----------|------|----------|
| Gatling Pea | E | `archetype_original_gatlingpea` | ✅ | 升级依赖 Repeater |
| Twin Sunflower | E | `archetype_original_twinsunflower` | ✅ | 升级依赖 Sunflower |
| Gloom-shroom | E | `archetype_original_gloomshroom` | ✅ | 升级依赖 Fume-shroom |
| Cattail | E | `archetype_original_cattail` | ✅ | 升级依赖 Lily Pad + tracking |
| Winter Melon | E | `archetype_original_wintermelon` | ✅ | 升级依赖 Melon-pult |
| Gold Magnet | E | `archetype_original_goldmagnet` | ✅ | 升级依赖 Magnet-shroom |
| Spikerock | E | `archetype_original_spikerock` | ✅ | 升级依赖 Spikeweed |
| Cob Cannon | E | `archetype_original_cobcannon` | ✅ | 升级依赖 Kernel-pult x2 |
| Cactus | D | `archetype_original_cactus` | ✅ | 对空高度段 |
| Blover (结构) | D | ⚠️ 待建 | ⚠️ 待建 | dispel_flying effect |
| Magnet-shroom (结构) | D | ⚠️ 待建 | ⚠️ 待建 | metal tag 过滤 | |

### 当前可信验证覆盖样本

| 植物 | 批次 | Archetype | Card | Validation |
|------|------|-----------|------|-------------|
| Peashooter | A | `archetype_original_peashooter` | `card_original_peashooter` | ✅ batch_a |
| Sunflower | A | `archetype_original_sunflower` | `card_original_sunflower` | ✅ batch_a |
| Wall-nut | A | `archetype_original_wallnut` | `card_original_wallnut` | ✅ batch_a |
| Snow Pea | A | `archetype_original_snowpea` | `card_original_snowpea` | ✅ batch_a |
| Repeater | A | `archetype_original_repeater` | `card_original_repeater` | ✅ batch_a |
| Cabbage-pult | A | `archetype_original_cabbagepult` | `card_original_cabbagepult` | ✅ batch_a |
| Melon-pult | A | `archetype_original_melonpult` | `card_original_melonpult` | ✅ batch_a |
| Cherry Bomb | B | `archetype_original_cherrybomb` | `card_original_cherrybomb` | ✅ batch_b |
| Tall-nut | B | `archetype_original_tallnut` | `card_original_tallnut` | ✅ batch_b |
| Pumpkin | B | `archetype_original_pumpkin` | `card_original_pumpkin` | ✅ batch_b |
| Jalapeno | B | `archetype_original_jalapeno` | `card_original_jalapeno` | ✅ batch_b |
| Potato Mine | B | `archetype_original_potatomine` | `card_original_potatomine` | ✅ single |
| Squash | B | `archetype_original_squash` | `card_original_squash` | ✅ single |
| Chomper | B | `archetype_original_chomper` | `card_original_chomper` | ✅ single |
| Coffee Bean | C | `archetype_original_coffeebean` | `card_original_coffeebean` | ✅ targeted wake |
| Fume-shroom | C | `archetype_original_fumeshroom` | `card_original_fumeshroom` | ✅ pierce |
| Threepeater | D | `archetype_original_threepeater` | `card_original_threepeater` | ✅ batch_d |
| Spikeweed | D | `archetype_original_spikeweed` | `card_original_spikeweed` | ✅ batch_d |
| Torchwood | D | `archetype_original_torchwood` | `card_original_torchwood` | ✅ batch_d |
| Split Pea | D | `archetype_original_splitpea` | `card_original_splitpea` | ✅ dual_direction |
| Starfruit | D | `archetype_original_starfruit` | `card_original_starfruit` | ✅ multi_angle |
| Cactus | D | `archetype_original_cactus` | `card_original_cactus` | ✅ air target |
| Blover | D | `archetype_original_blover` | `card_original_blover` | ✅ air-only dispel |
| Magnet-shroom | D | `archetype_original_magnetshroom` | `card_original_magnetshroom` | ✅ metal target |
| Lily Pad | D | `archetype_original_lilypad` | `card_original_lilypad` | ✅ water support |
| Sea-shroom | D | `archetype_original_seashroom` | `card_original_seashroom` | ✅ water primary |
| Flower Pot | E | `archetype_original_flowerpot` | `card_original_flowerpot` | ⚠️ 待补单体验证 |

### 当前主要缺口

1. **单体验证缺口** — C/E 中多数复杂植物仍缺单体验证，D 仍缺 Tangle Kelp/Plantern 资源，不能按完成验收。
2. **sleep/wake 精确语义** — 已修正 `entity.wake` 目标过滤，并以 Coffee Bean targeted wake 验证防止广播唤醒回归。
3. **升级替换与多格占用** — Cob Cannon 已能表达同格 + 相邻 Kernel-pult 依赖；真正替换/占用两格仍需后续协议。
4. **缺失资源** — Tangle Kelp、Plantern、Garlic、Umbrella Leaf、Marigold、Kernel-pult、Imitater 未落地。
5. **复杂行为边界** — Hypno-shroom、Gold Magnet、Cattail、Winter Melon、Cob Cannon 等仍需行为级验证。

---

## 迁移分类说明

| 分类 | 含义 |
|------|------|
| **仅需资源** | 现有 family/type 完全可表达，只需创建 Archetype + CardDef + Validation |
| **需最小 type/effect** | 现有能力基本够用，需补 1-2 个最小 effect type 或 mechanic type |
| **需协议设计** | 核心能力缺失，需正式协议设计（登记协议缺口，不阻塞其他植物） |

---

## 批次 A：基础闭环

### A-0: Peashooter (SEED_PEASHOOTER = 0)

| 属性 | 值 |
|------|-----|
| 原版名称 | Peashooter |
| 阳光费用 | 100 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 发射频率 | 150ms (fire rate, 1.5s delay between shots in original) |
| 放置条件 | 地面 |
| 攻击入口 | 周期性发射 pea 投射物 |
| 可复用资源 | `archetype_basic_shooter` (需校准数值) |
| 可复用 Mechanic | `Trigger.core.periodic` + `Targeting.core.lane_forward` + `Emission.core.single` + `Trajectory.core.linear` + `HitPolicy.core.swept_segment` + `Payload.core.spawn_projectile` |
| 可复用投射物 | `pea_linear.tres` + `linear_ground.tres` |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

### A-1: Sunflower (SEED_SUNFLOWER = 1)

| 属性 | 值 |
|------|-----|
| 原版名称 | Sunflower |
| 阳光费用 | 50 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 发射频率 | 2500ms (sun production interval) |
| 放置条件 | 地面 |
| 攻击入口 | 周期性产阳光 |
| 可复用资源 | `archetype_sunflower` (需校准数值) |
| 可复用 Mechanic | `Trigger.core.periodic` + `Payload.core.produce_sun` |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

### A-2: Wall-nut (SEED_WALLNUT = 3)

| 属性 | 值 |
|------|-----|
| 原版名称 | Wall-nut |
| 阳光费用 | 50 |
| 冷却时间 | 3.0s |
| 生命值 | 4000 |
| 子类 | NORMAL |
| 放置条件 | 地面 |
| 攻击入口 | 无（纯防御） |
| 可复用资源 | `archetype_wall_barrier` (需校准 max_health=4000, hitbox) |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

### A-3: Snow Pea (SEED_SNOWPEA = 5)

| 属性 | 值 |
|------|-----|
| 原版名称 | Snow Pea |
| 阳光费用 | 175 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 发射频率 | 150ms |
| 放置条件 | 地面 |
| 攻击入口 | 周期性发射寒冰豌豆 |
| 可复用资源 | `archetype_frost_pea` (需校准数值) |
| 可复用 Mechanic | `Trigger.core.periodic` + `Payload.core.spawn_projectile` (frost pea) |
| 可复用投射物 | `pea_frost_linear.tres` + `linear_ground.tres` |
| 分类 | **仅需资源** |
| 协议缺口 | `apply_status` 减速语义已存在，需确认原版减速比例 (约 50%) |

### A-4: Repeater (SEED_REPEATER = 7)

| 属性 | 值 |
|------|-----|
| 原版名称 | Repeater |
| 阳光费用 | 200 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 发射频率 | 150ms |
| 放置条件 | 地面 |
| 攻击入口 | 周期性双发 pea 投射物 |
| 可复用资源 | `archetype_repeater_burst` (需校准数值) |
| 可复用 Mechanic | `Trigger.core.periodic` + `Emission.core.burst` |
| 可复用投射物 | `pea_burst.tres` |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

### A-5: Cabbage-pult (SEED_CABBAGEPULT = 32)

| 属性 | 值 |
|------|-----|
| 原版名称 | Cabbage-pult |
| 阳光费用 | 100 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 发射频率 | 300ms (3s per shot) |
| 放置条件 | 地面 |
| 攻击入口 | 周期性抛投 cabbage 投射物 |
| 可复用资源 | `archetype_cabbage_lobber` (需校准数值) |
| 可复用 Mechanic | `Trigger.core.periodic` + `Trajectory.core.parabola` + `HitPolicy.core.terminal_hitbox` |
| 可复用投射物 | `cabbage_arc.tres` + `parabola_cabbage_arc.tres` |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

### A-6: Melon-pult (SEED_MELONPULT = 39)

| 属性 | 值 |
|------|-----|
| 原版名称 | Melon-pult |
| 阳光费用 | 300 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 发射频率 | 300ms (3s per shot) |
| 放置条件 | 地面 |
| 攻击入口 | 周期性抛投 melon，直击 + 溅射伤害 |
| 可复用资源 | `archetype_melon_lobber` (需校准数值) |
| 可复用 Mechanic | `Trigger.core.periodic` + `Trajectory.core.parabola` + `HitPolicy.core.terminal_radius` + `Payload.core.damage` (on_hit explode) |
| 可复用投射物 | `melon_blast.tres` + `parabola_terminal_blast.tres` |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

---

## 批次 B：即时与定时

### B-0: Cherry Bomb (SEED_CHERRYBOMB = 2)

| 属性 | 值 |
|------|-----|
| 原版名称 | Cherry Bomb |
| 阳光费用 | 150 |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | NORMAL (一次性) |
| 放置条件 | 地面 |
| 攻击入口 | 放置后爆炸 |
| 可复用 Mechanic | `Lifecycle.core.on_place` + `Payload.core.explode` |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

### B-1: Potato Mine (SEED_POTATOMINE = 4)

| 属性 | 值 |
|------|-----|
| 原版名称 | Potato Mine |
| 阳光费用 | 25 |
| 冷却时间 | 3.0s (放置后约 15s 激活) |
| 生命值 | 300 |
| 子类 | NORMAL (延迟激活) |
| 放置条件 | 地面 |
| 攻击入口 | 激活后，僵尸踩踏触发爆炸 |
| 可复用 Mechanic | `State.core.arming` + `Trigger.core.when_damaged` (需确认近距触发) |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 缺少 close-contact / proximity 触发入口；需确认 `arming` state 期间是否可被啃咬 |

### B-2: Squash (SEED_SQUASH = 17)

| 属性 | 值 |
|------|-----|
| 原版名称 | Squash |
| 阳光费用 | 50 |
| 冷却时间 | 3.0s |
| 生命值 | 300 |
| 子类 | NORMAL (一次性) |
| 放置条件 | 地面 |
| 攻击入口 | 近距目标跳跃 + 落点范围伤害 |
| 可复用 Mechanic | `Lifecycle.core.on_place` (或 proximity trigger) + `Payload.core.explode` |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 缺少近距目标搜索 + 跳跃延迟 + 落点范围 (可能需要 special targeting + delayed effect) |

### B-3: Jalapeno (SEED_JALAPENO = 20)

| 属性 | 值 |
|------|-----|
| 原版名称 | Jalapeno |
| 阳光费用 | 125 |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | NORMAL (一次性) |
| 放置条件 | 地面 |
| 攻击入口 | 整行爆炸 |
| 可复用 Mechanic | `Lifecycle.core.on_place` + `Payload.core.explode` |
| 分类 | **需最小 type/effect** |
| 协议缺口 | `explode` effect 需要整行目标筛选 (`enemies_in_lane` / `target_mode: all_in_same_lane`) |

### B-4: Chomper (SEED_CHOMPER = 6)

| 属性 | 值 |
|------|-----|
| 原版名称 | Chomper |
| 阳光费用 | 150 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面 |
| 攻击入口 | 近距离吞噬 + 消化状态 |
| 可复用 Mechanic | 近距 trigger + `State.core.growth`-like (消化) + `Payload.core.damage` (9999) |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 缺少近距离触发入口 + 吞噬消化状态 (disable attack during digest) |

### B-5: Tall-nut (SEED_TALLNUT = 23)

| 属性 | 值 |
|------|-----|
| 原版名称 | Tall-nut |
| 阳光费用 | 125 |
| 冷却时间 | 3.0s |
| 生命值 | 8000 |
| 子类 | NORMAL |
| 放置条件 | 地面 |
| 攻击入口 | 无（纯防御 + 跳跃阻挡） |
| 分类 | **仅需资源** |
| 协议缺口 | 跳跃阻挡（高度/越过交互）暂无协议；仅先做高血量防御，跳跃阻挡登记缺口 |

### B-6: Pumpkin (SEED_PUMPKINSHELL = 30)

| 属性 | 值 |
|------|-----|
| 原版名称 | Pumpkin |
| 阳光费用 | 125 |
| 冷却时间 | 3.0s |
| 生命值 | 4000 |
| 子类 | NORMAL |
| 放置条件 | 覆盖已放置植物 |
| 攻击入口 | 无（覆盖防御） |
| 可复用资源 | `archetype_pumpkin_cover` (需校准数值) |
| 可复用 Mechanic | `Placement.core.ground_slot` (cover_on_primary) |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

---

## 批次 C：夜间蘑菇

### C-0: Puff-shroom (SEED_PUFFSHROOM = 8)

| 属性 | 值 |
|------|-----|
| 原版名称 | Puff-shroom |
| 阳光费用 | 0 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 周期性短程攻击 |
| 可复用 Mechanic | `Trigger.core.periodic` + short-range `Targeting.core.lane_forward` + 近距直接伤害 |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 夜间睡眠协议 + 短程近距攻击 (scan_range 极短) |

### C-1: Sun-shroom (SEED_SUNSHROOM = 9)

| 属性 | 值 |
|------|-----|
| 原版名称 | Sun-shroom |
| 阳光费用 | 25 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 周期性产阳光，随成长变大 |
| 可复用 Mechanic | `Trigger.core.periodic` + `Payload.core.produce_sun` + `State.core.growth` |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 夜间睡眠协议 + 产出值随 growth state 切换 |

### C-2: Fume-shroom (SEED_FUMESHROOM = 10)

| 属性 | 值 |
|------|-----|
| 原版名称 | Fume-shroom |
| 阳光费用 | 75 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 短程穿透攻击 |
| 可复用 Mechanic | `Trigger.core.periodic` + short-range targeting + 穿透 hit policy |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 穿透 hit policy (damage all targets in line/cone). 夜间睡眠协议 |

### C-3: Grave Buster (SEED_GRAVEBUSTER = 11)

| 属性 | 值 |
|------|-----|
| 原版名称 | Grave Buster |
| 阳光费用 | 75 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 只能放在墓碑上 |
| 攻击入口 | 放置后吞噬墓碑 |
| 分类 | **需协议设计** |
| 协议缺口 | 墓碑目标标签 + 限定放置类型 + 吞噬墓碑交互 |

### C-4: Hypno-shroom (SEED_HYPNOSHROOM = 12)

| 属性 | 值 |
|------|-----|
| 原版名称 | Hypno-shroom |
| 阳光费用 | 75 |
| 冷却时间 | 3.0s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 被啃咬时催眠僵尸 |
| 分类 | **需协议设计** |
| 协议缺口 | 催眠反转阵营 (team switch) 协议 |

### C-5: Scaredy-shroom (SEED_SCAREDYSHROOM = 13)

| 属性 | 值 |
|------|-----|
| 原版名称 | Scaredy-shroom |
| 阳光费用 | 25 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 周期性射击，敌近停火 |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 敌近停火 (proximity detection gate on attack)。夜间睡眠协议 |

### C-6: Ice-shroom (SEED_ICESHROOM = 14)

| 属性 | 值 |
|------|-----|
| 原版名称 | Ice-shroom |
| 阳光费用 | 75 |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | NORMAL (一次性) |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 全场冻结 |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 全场范围 apply_status (freeze) + 夜间睡眠协议 |

### C-7: Doom-shroom (SEED_DOOMSHROOM = 15)

| 属性 | 值 |
|------|-----|
| 原版名称 | Doom-shroom |
| 阳光费用 | 125 |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | NORMAL (一次性) |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 大范围爆炸 + 留下坑洞 |
| 可复用 Mechanic | `Lifecycle.core.on_place` + `Payload.core.explode` |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 坑洞/crater 场地协议 + 夜间睡眠协议 |

### C-8: Coffee Bean (SEED_INSTANT_COFFEE = 35)

| 属性 | 值 |
|------|-----|
| 原版名称 | Coffee Bean |
| 阳光费用 | 75 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 放在睡眠蘑菇上 |
| 攻击入口 | 唤醒目标蘑菇 |
| 分类 | **需协议设计** |
| 协议缺口 | 唤醒协议 (需要 sleep state 和 wake trigger) |

---

## 批次 D：场地与多向攻击

### D-0: Lily Pad (SEED_LILYPAD = 16)

| 属性 | 值 |
|------|-----|
| 原版名称 | Lily Pad |
| 阳光费用 | 25 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 水面 |
| 攻击入口 | 无（水面支撑） |
| 可复用资源 | `archetype_water_pod` (需校准数值) |
| 可复用 Mechanic | `Placement.core.water_slot` |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

### D-1: Tangle Kelp (SEED_TANGLEKELP = 19)

| 属性 | 值 |
|------|-----|
| 原版名称 | Tangle Kelp |
| 阳光费用 | 25 |
| 冷却时间 | 3.0s |
| 生命值 | 300 |
| 子类 | NORMAL (一次性) |
| 放置条件 | 水面限定 |
| 攻击入口 | 拖拽水面僵尸 |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 水面限定放置 + 单目标拖拽击杀 (需要 pull/instant-kill effect) |

### D-2: Threepeater (SEED_THREEPEATER = 18)

| 属性 | 值 |
|------|-----|
| 原版名称 | Threepeater |
| 阳光费用 | 325 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 放置条件 | 地面 |
| 攻击入口 | 三行发射 pea |
| 可复用 Mechanic | `Trigger.core.periodic` + `Emission.core.spread` (multi-lane) |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 多 lane emission (同时向相邻行发射) |

### D-3: Spikeweed (SEED_SPIKEWEED = 21)

| 属性 | 值 |
|------|-----|
| 原版名称 | Spikeweed |
| 阳光费用 | 100 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面 |
| 攻击入口 | 地面持续伤害 (僵尸走过时受伤) |
| 分类 | **需协议设计** |
| 协议缺口 | 地面持续伤害 (contact damage while overlapping) + 特殊僵尸交互 (碾压) |

### D-4: Torchwood (SEED_TORCHWOOD = 22)

| 属性 | 值 |
|------|-----|
| 原版名称 | Torchwood |
| 阳光费用 | 175 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面 |
| 攻击入口 | 豌豆穿过时改为火球 |
| 分类 | **需协议设计** |
| 协议缺口 | 投射物改写 (projectile transform) 协议 |

### D-5: Sea-shroom (SEED_SEASHROOM = 24)

| 属性 | 值 |
|------|-----|
| 原版名称 | Sea-shroom |
| 阳光费用 | 0 |
| 冷却时间 | 3.0s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 放置条件 | 水面，夜间 |
| 攻击入口 | 短程水面射击 |
| 可复用 Mechanic | `Trigger.core.periodic` + `Placement.core.water_slot` + short-range targeting |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 夜间睡眠协议 + 水面放置 + 短程攻击 |

### D-6: Plantern (SEED_PLANTERN = 25)

| 属性 | 值 |
|------|-----|
| 原版名称 | Plantern |
| 阳光费用 | 25 |
| 冷却时间 | 3.0s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 反隐 + 产阳光 |
| 分类 | **需协议设计** |
| 协议缺口 | 反隐机制 (visibility / reveal 协议) |

### D-7: Cactus (SEED_CACTUS = 26)

| 属性 | 值 |
|------|-----|
| 原版名称 | Cactus |
| 阳光费用 | 125 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 放置条件 | 地面 |
| 攻击入口 | 对空/对地射击 (height toggle) |
| 可复用资源 | `archetype_air_interceptor` (参考) |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 对空高度/状态切换 (根据目标高度选择 projectile) |

### D-8: Blover (SEED_BLOVER = 27)

| 属性 | 值 |
|------|-----|
| 原版名称 | Blover |
| 阳光费用 | 100 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL (一次性) |
| 放置条件 | 地面 |
| 攻击入口 | 全局驱散飞行单位 |
| 分类 | **需协议设计** |
| 协议缺口 | 全局飞行单位驱散 effect (按飞行标签筛选目标) |

### D-9: Split Pea (SEED_SPLITPEA = 28)

| 属性 | 值 |
|------|-----|
| 原版名称 | Split Pea |
| 阳光费用 | 125 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 放置条件 | 地面 |
| 攻击入口 | 前后双向射击 |
| 可复用 Mechanic | `Trigger.core.periodic` + 多 emission (forward + backward) |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 双向 emission (同一 trigger 驱动 forward + backward 两路投射物) |

### D-10: Starfruit (SEED_STARFRUIT = 29)

| 属性 | 值 |
|------|-----|
| 原版名称 | Starfruit |
| 阳光费用 | 125 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 放置条件 | 地面 |
| 攻击入口 | 多方向射击 (5 方向) |
| 可复用 Mechanic | `Trigger.core.periodic` + `Emission.core.spread` (multi-direction) |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 多方向 emission (multi-angle 而非仅 forward) |

### D-11: Magnet-shroom (SEED_MAGNETSHROOM = 31)

| 属性 | 值 |
|------|-----|
| 原版名称 | Magnet-shroom |
| 阳光费用 | 100 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面，夜间 |
| 攻击入口 | 吸附僵尸金属装备 |
| 分类 | **需协议设计** |
| 协议缺口 | 金属目标/装备标签 + 吸附物品协议 + 夜间睡眠协议 |

---

## 批次 E：屋顶与升级植物

### E-0: Flower Pot (SEED_FLOWERPOT = 33)

| 属性 | 值 |
|------|-----|
| 原版名称 | Flower Pot |
| 阳光费用 | 25 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 屋顶 |
| 攻击入口 | 无（屋顶支撑） |
| 可复用资源 | `archetype_flower_pot_surface` (需校准数值) |
| 可复用 Mechanic | `Placement.core.roof_slot` |
| 分类 | **仅需资源** |
| 协议缺口 | 无 |

### E-1: Kernel-pult (SEED_KERNELPULT = 34)

| 属性 | 值 |
|------|-----|
| 原版名称 | Kernel-pult |
| 阳光费用 | 100 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | SHOOTER |
| 发射频率 | 300ms |
| 放置条件 | 地面/屋顶 |
| 攻击入口 | 抛投玉米/黄油 |
| 可复用 Mechanic | `Trigger.core.periodic` + `Trajectory.core.parabola` + multi-payload (corn + butter random) |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 黄油眩晕 status (特殊冻结/眩晕 duration) + 随机 payload 选择 (corn vs butter) |

### E-2: Garlic (SEED_GARLIC = 36)

| 属性 | 值 |
|------|-----|
| 原版名称 | Garlic |
| 阳光费用 | 50 |
| 冷却时间 | 7.5s |
| 生命值 | 400 |
| 子类 | NORMAL |
| 放置条件 | 地面 |
| 攻击入口 | 被啃咬时换道 |
| 分类 | **需协议设计** |
| 协议缺口 | 换道 (lane reroute) 协议，不写入 zombie/battle 特判 |

### E-3: Umbrella Leaf (SEED_UMBRELLA = 37)

| 属性 | 值 |
|------|-----|
| 原版名称 | Umbrella Leaf |
| 阳光费用 | 100 |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面 |
| 攻击入口 | 防护 bungee/catapult |
| 分类 | **需协议设计** |
| 协议缺口 | target protection 协议 (特定攻击类型免疫) |

### E-4: Marigold (SEED_MARIGOLD = 38)

| 属性 | 值 |
|------|-----|
| 原版名称 | Marigold |
| 阳光费用 | 50 |
| 冷却时间 | 3.0s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 地面 |
| 攻击入口 | 产金币/银币 |
| 分类 | **需协议设计** |
| 协议缺口 | 金币/银币资源类型 (当前经济仅支持阳光) |

### E-5: Gatling Pea (SEED_GATLINGPEA = 40)

| 属性 | 值 |
|------|-----|
| 原版名称 | Gatling Pea |
| 阳光费用 | 250 (升级费用) |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | SHOOTER (升级) |
| 放置条件 | 地面，需放置在 Repeater 上 |
| 攻击入口 | 四连发 pea |
| 可复用 Mechanic | Repeater 基础上增加 `Emission.core.burst` count=4 |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 升级放置依赖 (`required_present_roles` / upgrade placement) |

### E-6: Twin Sunflower (SEED_TWINSUNFLOWER = 41)

| 属性 | 值 |
|------|-----|
| 原版名称 | Twin Sunflower |
| 阳光费用 | 150 (升级费用) |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | NORMAL (升级) |
| 放置条件 | 地面，需放置在 Sunflower 上 |
| 攻击入口 | 双倍产阳光 |
| 可复用 Mechanic | Sunflower 基础上增加产阳光频率/值 |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 升级放置依赖 |

### E-7: Gloom-shroom (SEED_GLOOMSHROOM = 42)

| 属性 | 值 |
|------|-----|
| 原版名称 | Gloom-shroom |
| 阳光费用 | 150 (升级费用) |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | SHOOTER (升级) |
| 放置条件 | 地面，需放置在 Fume-shroom 上 |
| 攻击入口 | 环形范围穿透攻击 |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 环形范围攻击 (radius-based targeting) + 穿透 + 升级依赖 |

### E-8: Cattail (SEED_CATTAIL = 43)

| 属性 | 值 |
|------|-----|
| 原版名称 | Cattail |
| 阳光费用 | 225 (升级费用) |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | SHOOTER (升级) |
| 放置条件 | 水面，需放置在 Lily Pad 上 |
| 攻击入口 | 全场追踪 projectile |
| 可复用 Mechanic | `Trigger.core.periodic` + `Trajectory.core.track` + 全场 targeting |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 全场追踪优先级 (global tracking, 非 lane 限定) + 升级依赖 |

### E-9: Winter Melon (SEED_WINTERMELON = 44)

| 属性 | 值 |
|------|-----|
| 原版名称 | Winter Melon |
| 阳光费用 | 200 (升级费用) |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | SHOOTER (升级) |
| 放置条件 | 地面，需放置在 Melon-pult 上 |
| 攻击入口 | 抛投冰冻西瓜 (范围伤害 + 减速) |
| 可复用 Mechanic | Melon-pult 基础上加 `Payload.core.apply_status` (slow/freeze) |
| 分类 | **需最小 type/effect** |
| 协议缺口 | 升级依赖 + 溅射范围 apply_status |

### E-10: Gold Magnet (SEED_GOLD_MAGNET = 45)

| 属性 | 值 |
|------|-----|
| 原版名称 | Gold Magnet |
| 阳光费用 | 50 (升级费用) |
| 冷却时间 | 5.0s |
| 生命值 | 300 |
| 子类 | NORMAL (升级) |
| 放置条件 | 地面，需放置在 Magnet-shroom 上 |
| 攻击入口 | 吸附金币 |
| 分类 | **需协议设计** |
| 协议缺口 | 金币吸附 (collectible 协议) + 升级依赖 |

### E-11: Spikerock (SEED_SPIKEROCK = 46)

| 属性 | 值 |
|------|-----|
| 原版名称 | Spikerock |
| 阳光费用 | 125 (升级费用) |
| 冷却时间 | 5.0s |
| 生命值 | 450 (每次受击 -50) |
| 子类 | NORMAL (升级) |
| 放置条件 | 地面，需放置在 Spikeweed 上 |
| 攻击入口 | 高耐久地面持续伤害 |
| 分类 | **需协议设计** |
| 协议缺口 | 持续地面伤害 + 特殊僵尸交互 + 升级依赖 |

### E-12: Cob Cannon (SEED_COBCANNON = 47)

| 属性 | 值 |
|------|-----|
| 原版名称 | Cob Cannon |
| 阳光费用 | 500 |
| 冷却时间 | 5.0s (发射间隔 600ms) |
| 生命值 | 300 |
| 子类 | NORMAL (升级) |
| 放置条件 | 地面，需相邻两 Kernel-pult |
| 攻击入口 | 手动瞄准 + 多格占用 + 导弹发射 |
| 分类 | **需协议设计** |
| 协议缺口 | 手动瞄准 (通过 battle mode/input profile) + 多格占用 + 升级依赖 |

### E-13: Imitater (SEED_IMITATER = 48)

| 属性 | 值 |
|------|-----|
| 原版名称 | Imitater |
| 阳光费用 | 0 (复制目标植物费用) |
| 冷却时间 | 7.5s |
| 生命值 | 300 |
| 子类 | NORMAL |
| 放置条件 | 复制目标植物的放置条件 |
| 攻击入口 | 复制卡片 (不复制 runtime 节点) |
| 分类 | **需协议设计** |
| 协议缺口 | 卡片复制协议 (card clone, 不绕开 card/runtime 协议) |

---

## 批次汇总

| 批次 | 植物数 | 仅需资源 | 需最小 type/effect | 需协议设计 |
|------|--------|----------|--------------------|------------|
| A | 7 | **7** | 0 | 0 |
| B | 7 | **3** (Cherry Bomb, Tall-nut, Pumpkin) | **4** (Potato Mine, Squash, Jalapeno, Chomper) | 0 |
| C | 9 | **0** | **5** (Puff-shroom, Sun-shroom, Fume-shroom, Scaredy-shroom, Ice-shroom) | **4** (Grave Buster, Hypno-shroom, Doom-shroom, Coffee Bean) |
| D | 12 | **1** (Lily Pad) | **6** (Tangle Kelp, Threepeater, Sea-shroom, Cactus, Split Pea, Starfruit) | **5** (Spikeweed, Torchwood, Plantern, Blover, Magnet-shroom) |
| E | 14 | **1** (Flower Pot) | **6** (Kernel-pult, Gatling Pea, Twin Sunflower, Gloom-shroom, Cattail, Winter Melon) | **7** (Garlic, Umbrella Leaf, Marigold, Gold Magnet, Spikerock, Cob Cannon, Imitater) |
| **总计** | **49** | **12** | **21** | **16** |

---

## 全局协议缺口清单

| 序号 | 缺口名称 | 关联植物 | 建议落点 | 阻塞批次 |
|------|---------|---------|---------|---------|
| G-01 | 夜间蘑菇睡眠 | 所有批次 C 蘑菇 | State / Placement | C |
| G-02 | Coffee Bean 唤醒 | Coffee Bean | Lifecycle / Effect | C |
| G-03 | 催眠反转阵营 | Hypno-shroom | apply_status (team switch) | C |
| G-04 | 墓碑目标标签 | Grave Buster | 场上物件目标标签 | C |
| G-05 | 近距触发入口 | Potato Mine, Squash, Chomper | Trigger (proximity/contact) | B |
| G-06 | 整行目标筛选 | Jalapeno | Targeting / Effect (enemies_in_lane) | B |
| G-07 | 吞噬消化状态 | Chomper | State (digesting) | B |
| G-08 | 穿透 hit policy | Fume-shroom, Gloom-shroom | HitPolicy (pierce/penetrate) | C |
| G-09 | 多 lane emission | Threepeater | Emission (multi_lane) | D |
| G-10 | 双向 emission | Split Pea | Emission (dual_direction) | D |
| G-11 | 多方向 emission | Starfruit | Emission (multi_angle) | D |
| G-12 | 环形范围攻击 | Gloom-shroom | Targeting (radius_around) | E |
| G-13 | 全场追踪 targeting | Cattail | Targeting (global_track) | E |
| G-14 | 对空高度切换 | Cactus | HeightBand / State | D |
| G-15 | 地面持续伤害 | Spikeweed, Spikerock | Controller (ground_damage) | D |
| G-16 | 投射物改写 | Torchwood | Emission / projectile transform | D |
| G-17 | 全局飞行驱散 | Blover | Effect / Targeting (flying_tag) | D |
| G-18 | 反隐机制 | Plantern | Visibility/Reveal 协议 | D |
| G-19 | 金属吸附 | Magnet-shroom, Gold Magnet | Targeting (metal_tag) + Effect | D |
| G-20 | 升级放置依赖 | 批次 E 升级植物 | Placement (upgrade) | E |
| G-21 | 黄油眩晕 | Kernel-pult | apply_status (butter/stun) | E |
| G-22 | 换道 | Garlic | Effect / RuleModule | E |
| G-23 | 防护特定攻击 | Umbrella Leaf | RuleModule (protection) | E |
| G-24 | 金币资源 | Marigold, Gold Magnet | Economy / collectible | E |
| G-25 | 手动瞄准 | Cob Cannon | BattleModeHost / InputProfile | E |
| G-26 | 多格占用 | Cob Cannon | Placement (multi_tile) | E |
| G-27 | 卡片复制 | Imitater | Card layer 协议 | E |
| G-28 | 跳跃高度阻挡 | Tall-nut | HeightBand / collision | B |
| G-29 | 坑洞/crater | Doom-shroom | 场地变形协议 | C |
| G-30 | 随机 payload 选择 | Kernel-pult | Emission (shuffle/random) | E |

---

## 当前可复用资源映射

| 现有样板资源 | 对应原版植物 | 状态 |
|-------------|-------------|------|
| `archetype_basic_shooter` | Peashooter | ✅ 已迁移为 `archetype_original_peashooter` |
| `archetype_sunflower` | Sunflower | ✅ 已迁移为 `archetype_original_sunflower` |
| `archetype_wall_barrier` | Wall-nut | ✅ 已迁移为 `archetype_original_wallnut` |
| `archetype_frost_pea` | Snow Pea | ✅ 已迁移为 `archetype_original_snowpea` |
| `archetype_repeater_burst` | Repeater | ✅ 已迁移为 `archetype_original_repeater` |
| `archetype_cabbage_lobber` | Cabbage-pult | ✅ 已迁移为 `archetype_original_cabbagepult` |
| `archetype_melon_lobber` | Melon-pult | ✅ 已迁移为 `archetype_original_melonpult` |
| `archetype_pumpkin_cover` | Pumpkin | ✅ 已迁移为 `archetype_original_pumpkin` |
| `archetype_flower_pot_surface` | Flower Pot | ✅ 已迁移为 `archetype_original_flowerpot` |
| `archetype_water_pod` | Lily Pad | ✅ 已迁移为 `archetype_original_lilypad` |
| `archetype_air_interceptor` | Cactus (参考) | ⚠️ 需对空高度切换协议 |

---

## 修订记录

| 日期 | 变更 |
|------|------|
| 2026-04-27 | 初始创建：49 植物完整底账，分类，协议缺口清单 |
| 2026-04-27 | 批次 A 完成：7 个 archetype + 7 个 card + `plant_original_batch_a_validation` |
| 2026-04-27 | 批次 B 部分完成：Cherry Bomb, Jalapeno, Tall-nut, Pumpkin (4/7)，其余 3 个协议阻塞 |
| 2026-04-27 | 批次 D 部分完成：Lily Pad (1/12) |
| 2026-04-27 | 批次 E 部分完成：Flower Pot (1/14) |
| 2026-04-27 | 已创建文件：13 archetype, 13 card, 2 validation scenario (.tres) |
| 2026-04-27 | JSON 更新：`validation_scenarios.json` +2 条目, `formal_content_validation_map.json` +5 分组 |
| 2026-04-27(R1) | Round 1: G-06/G-12/G-13/G-14/G-17/G-19/G-20 全部解决，+11 植物，累计 24/49 |
| 2026-04-27(R2) | Round 2: G-01/G-02/G-05/G-07/G-15 解决，+15 植物，累计 39/49 (80%) |
| 2026-04-27(R3) | Round 3: G-03/G-04/G-08/G-09/G-10/G-11/G-16 解决，+6 植物，累计 45/49 (92%) |
| 2026-04-28 | 完成度口径校准：资源+卡片落地为 42/49；严格完成仅 A 批次 7/49；A/B/C/D/round1 目标验证可信通过但 B/C/D 仍为代表性覆盖 |
