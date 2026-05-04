# 原版植物协议缺口清单

- 状态：执行中 (机制补齐口径同步)
- 关联文件：`plans/original-plant-migration-ledger.md`
- 创建日期：2026-04-27
- 最后更新：2026-05-04

> 本文档记录原版植物移植过程中发现的协议能力缺失。每条缺口包含建议落点和阻塞影响。

---

## 缺口总览

| ID | 名称 | 建议落点 | 阻塞批次 | 优先级 | 状态 |
|----|------|---------|---------|--------|------|
| G-01 | 夜间蘑菇睡眠 | State / Placement | C | 高 | ⚠️ Round 2 |
| G-02 | Coffee Bean 唤醒 | Lifecycle / Effect | C | 高 | ⚠️ Round 2 |
| G-03 | 催眠反转阵营 | apply_status (team switch) | C | 高 | ⚠️ Round 2 |
| G-04 | 墓碑目标标签 | 场上物件目标标签 | C | 高 | ⚠️ Round 2 |
| G-05 | 近距触发入口 | Trigger (proximity/contact) | B | 高 | ⚠️ Round 2 |
| G-06 | 整行目标筛选 | Targeting / Effect (enemies_in_lane) | B | 中 | ✅ R1-4 |
| G-07 | 吞噬消化状态 | State (digesting) | B | 中 | ⚠️ Round 2 |
| G-08 | 穿透 hit policy | HitPolicy (pierce/penetrate) | C | 中 | ✅ R3 |
| G-09 | 多 lane emission | Emission (multi_lane) | D | 中 | ✅ R3 |
| G-10 | 双向 emission | Emission (dual_direction) | D | 中 | ✅ R3 |
| G-11 | 多方向 emission | Emission (multi_angle) | D | 中 | ✅ R3 |
| G-03 | 催眠反转阵营 | apply_status (team switch) | C | 高 | ✅ R3 |
| G-04 | 墓碑目标标签 | 场上物件目标标签 | C | 高 | ✅ R3 |
| G-16 | 投射物改写 | Emission / projectile transform | D | 高 | ✅ R3 |
| G-05 | 近距触发入口 | Trigger (proximity/contact) | B | 高 | ✅ R2 |
| G-01 | 夜间蘑菇睡眠 | State / Placement | C | 高 | ✅ R2 |
| G-02 | Coffee Bean 唤醒 | Lifecycle / Effect | C | 高 | ✅ R2 |
| G-07 | 吞噬消化状态 | State (digesting) | B | 中 | ✅ R2 |
| G-15 | 地面持续伤害 | Controller (ground_damage) | D | 高 | ✅ R2 |
| G-06 | 整行目标筛选 | Targeting / Effect (enemies_in_lane) | B | 中 | ✅ R1-4 |
| G-12 | 环形范围攻击 | Targeting (radius_around) | E | 中 | ✅ R1-2 |
| G-13 | 全场追踪 targeting | Targeting (global_track) | E | 中 | ✅ R1-3 |
| G-14 | 对空高度切换 | HeightBand / State | D | 中 | ✅ R1-7 |
| G-17 | 全局飞行驱散 | Effect / Targeting (flying_tag) | D | 中 | ✅ R1-5 |
| G-18 | 反隐机制 | reveal effect | D | 中 | ✅ 2026-05-04 |
| G-19 | 金属吸附 | Targeting (metal_tag) + Effect | D | 中 | ✅ R1-6 |
| G-20 | 升级放置依赖 | Placement (upgrade) | E | 高 | ✅ R1-1 |
| G-21 | 黄油眩晕 | apply_status (butter/stun) | E | 低 | ✅ 2026-05-04 |
| G-22 | 换道 | Effect / RuleModule | E | 中 | ⚠️ Round 3 |
| G-23 | 防护特定攻击 | RuleModule (protection) | E | 低 | ⚠️ Round 3 |
| G-24 | 金币资源 | Economy / collectible | E | 低 | ⚠️ Round 3 |
| G-25 | 手动瞄准 | BattleModeHost / InputProfile | E | 中 | ⚠️ Round 3 |
| G-26 | 多格占用 | Placement (multi_tile) | E | 中 | ⚠️ Round 3 |
| G-27 | 卡片复制 | Card layer 协议 | E | 中 | ⚠️ Round 3 |
| G-28 | 跳跃高度阻挡 | HeightBand / collision | B | 低 | ⚠️ Round 3 |
| G-29 | 坑洞/crater | 场地变形协议 | C | 低 | ⚠️ Round 3 |
| G-30 | 随机 payload 选择 | Emission.core.shuffle_cycle | E | 低 | ✅ 2026-05-04 |

**Round 1 解决**: 7/30 (G-06, G-12, G-13, G-14, G-17, G-19, G-20)
**Round 2 待解决**: 12/30
**2026-05-04 机制补齐**: G-18, G-21, G-30 已以最小正式语义覆盖；完整雾场、原版黄油概率精确值仍后置。

---

## 详细记录

### G-01: 夜间蘑菇睡眠

**关联植物**: Puff-shroom, Sun-shroom, Fume-shroom, Hypno-shroom, Scaredy-shroom, Ice-shroom, Doom-shroom, Sea-shroom, Magnet-shroom, Gloom-shroom

**原版行为**: 夜间蘑菇在白天场景自动进入睡眠状态，无法行动。

**当前缺失**: 无睡眠/唤醒状态系统。

**建议落点**: `State.core.sleeping` + `BattleRuleModule` 控制白天/夜间切换。

**阻塞**: 批次 C（所有夜间蘑菇）

---

### G-02: Coffee Bean 唤醒

**关联植物**: Coffee Bean

**原版行为**: 放置在睡眠蘑菇上后，唤醒目标蘑菇并消耗自身。

**当前缺失**: 无唤醒交互协议。

**建议落点**: `Lifecycle.core.on_place` + targeting 睡眠蘑菇 + `Payload.core.apply_status` (remove sleep)。

**阻塞**: 批次 C（Coffee Bean）

---

### G-03: 催眠反转阵营

**关联植物**: Hypno-shroom

**原版行为**: 被僵尸啃咬后，该僵尸反转阵营并攻击其他僵尸。

**当前缺失**: 无阵营切换能力。

**建议落点**: `apply_status` 扩展 `team_switch` 参数，或新增 `Effect.core.convert_team`。

**阻塞**: 批次 C（Hypno-shroom）

---

### G-05: 近距触发入口

**关联植物**: Potato Mine, Squash, Chomper

**原版行为**: 当僵尸进入近距离时触发效果（爆炸/跳跃/吞噬）。

**当前缺失**: 无 proximity/contact 类型的 trigger。当前 trigger 只有 `periodically`/`when_damaged`/`on_death`/`on_spawned`/`on_place`。

**建议落点**: 新增 `Trigger.core.proximity` 或扩展 `when_damaged` 的 proximity 变体。

**阻塞**: 批次 B（Potato Mine, Squash, Chomper）

---

### G-06: 整行目标筛选

**关联植物**: Jalapeno

**原版行为**: 对同一行的所有敌人造成伤害。

**当前缺失**: `explode` effect 的 `target_mode` 仅支持 `enemies_in_radius`，无整行筛选。

**建议落点**: 扩展 `explode` effect 的 `target_mode` 增加 `enemies_in_lane` 选项。

**阻塞**: 批次 B（Jalapeno）

---

### G-08: 穿透 hit policy

**关联植物**: Fume-shroom, Gloom-shroom

**原版行为**: 单次攻击对攻击范围内的所有敌人造成伤害。

**当前缺失**: 当前 HitPolicy 类型 (`swept_segment`, `terminal_hitbox`, `terminal_radius`, `overlap`) 不支持穿透。

**建议落点**: 新增 `HitPolicy.core.pierce` 或 `HitPolicy.core.aoe_cone`。

**阻塞**: 批次 C（Fume-shroom）, 批次 E（Gloom-shroom）

---

### G-16: 投射物改写

**关联植物**: Torchwood

**原版行为**: 豌豆穿过 Torchwood 时被改写为火球（伤害翻倍）。

**当前缺失**: 无投射物 transform/modify 协议。

**建议落点**: `Emission` 或新增 `Transform` mechanic family（需 ADR）。

**阻塞**: 批次 D（Torchwood）

---

### G-20: 升级放置依赖

**关联植物**: Gatling Pea, Twin Sunflower, Gloom-shroom, Cattail, Winter Melon, Gold Magnet, Spikerock, Cob Cannon

**原版行为**: 升级植物必须放置在对应基础植物上。

**当前缺失**: 当前 `required_present_roles` 仅检查角色存在，不足以表达"必须在某具体 archetype 上放置"。

**建议落点**: 扩展 `Placement` mechanic，新增 `required_present_archetypes` 或 `upgrade_from` 参数。

**阻塞**: 批次 E（全部升级植物）
