# 原版植物协议缺口清单

- 状态：当前事实
- 关联文件：`plans/original-plant-migration-ledger.md`
- 创建日期：2026-04-27
- 最后更新：2026-05-10

> 本文档记录原版植物移植过程中仍然影响“原版语义完成度”的协议缺口。规则基础设施第二轮完成后，多维 liveness、`SpatialIndex` / `spatial_query`、`height_range` 过滤和 tick budget 监控已成为当前基线；旧 Round 表述不再作为当前状态来源。

---

## 当前结论

- 原版植物资源和卡片当前为 `46/49`：缺 `Garlic`、`Umbrella Leaf`、`Imitater`。
- 大部分早期协议缺口已经被现有 Mechanic / Effect / Controller / Placement 能力覆盖。
- 当前真正阻塞新内容落地的缺口集中在 3 类：换道、防护/复制、场地或多格占用。
- E 批次已有资源的机制优先单体验证已补齐；下一步应处理缺失资源或真正需要协议设计的能力，而不是新增通用基础设施。

---

## 缺口总览

| ID | 名称 | 当前状态 | 关联植物 | 当前判断 |
|----|------|----------|----------|----------|
| G-01 | 夜间蘑菇睡眠 | 已覆盖 | C 批次蘑菇、Gloom-shroom | `State.sleeping` + liveness 已覆盖行为暂停，wake 验证已存在 |
| G-02 | Coffee Bean 唤醒 | 已覆盖 | Coffee Bean | `wake` effect + targeted placement 验证已存在 |
| G-03 | 催眠反转阵营 | 已覆盖 | Hypno-shroom | `team_switch` effect 已覆盖最小语义 |
| G-04 | 墓碑目标标签 | 已覆盖 | Grave Buster | placement blocker target + required archetype 验证已存在 |
| G-05 | 近距触发入口 | 已覆盖 | Potato Mine, Squash, Chomper, Tangle Kelp | `Trigger.core.proximity` / Detection proximity 已进入主干 |
| G-06 | 整行目标筛选 | 已覆盖 | Jalapeno | `target_mode=enemies_in_lane` 已进入 EffectRegistry |
| G-07 | 吞噬消化状态 | 已覆盖 | Chomper | State + liveness 可表达 digesting 期间关闭 controller |
| G-08 | 穿透 hit policy | 已覆盖 | Fume-shroom, Gloom-shroom | pierce / detected_targets / radius 组合已覆盖机制优先语义 |
| G-09 | 多 lane emission | 已覆盖 | Threepeater | `Emission.multi_lane` 已覆盖 |
| G-10 | 双向 emission | 已覆盖 | Split Pea | `Emission.dual_direction` 已覆盖 |
| G-11 | 多方向 emission | 已覆盖 | Starfruit | `Emission.multi_angle` 已覆盖 |
| G-12 | 环形范围攻击 | 已覆盖并已验证 | Gloom-shroom | `plant_original_gloomshroom_validation` 已覆盖 `radius_around` + detected targets |
| G-13 | 全场追踪 targeting | 部分覆盖并已验证当前资源 | Cattail | `plant_original_cattail_validation` 覆盖当前 track-air projectile；是否改 `global_track` 作为精确语义后续评估 |
| G-14 | 对空高度切换 | 已覆盖最小语义 | Cactus | HeightBand / `height_range` 已覆盖对空命中；视觉/状态切换后置 |
| G-15 | 地面持续伤害 | 已覆盖 | Spikeweed, Spikerock | `Controller.core.ground_damage` 已覆盖最小语义 |
| G-16 | 投射物改写 | 已覆盖 | Torchwood | `Controller.core.projectile_transform` 已覆盖 |
| G-17 | 全局飞行驱散 | 已覆盖 | Blover | `dispel_flying` + flying tag 已覆盖 |
| G-18 | 反隐机制 | 已覆盖最小语义 | Plantern | `reveal` effect 已覆盖；完整雾场/视野系统后置 |
| G-19 | 金属吸附 | 部分覆盖并已验证升级依赖 | Magnet-shroom, Gold Magnet | metal targeting 已覆盖；`plant_original_goldmagnet_validation` 覆盖升级最小语义，collectible 吸附未完成 |
| G-20 | 升级放置依赖 | 已覆盖最小语义 | E 批次升级植物 | `required_present_archetypes` 已覆盖依赖检查；替换/占位精确语义另见 G-26 |
| G-21 | 黄油眩晕 | 已覆盖 | Kernel-pult | `apply_status` + `butter_stun` 已覆盖；原版概率精确值后置 |
| G-22 | 换道 | 未覆盖 | Garlic | 需要 lane reroute effect / rule module，不应写入 zombie 特判 |
| G-23 | 防护特定攻击 | 未覆盖 | Umbrella Leaf | 需要 target protection / attack type guard 协议 |
| G-24 | 金币资源 | 部分覆盖 | Marigold, Gold Magnet | Marigold `coin_generated` collectible 已覆盖；完整 coin/silver economy 与吸附后置 |
| G-25 | 手动瞄准 | 基础能力已有，植物未完成 | Cob Cannon | BattleModeHost / InputProfile 已能承接手动输入；Cob Cannon 发射链未验收 |
| G-26 | 多格占用 | 未覆盖 | Cob Cannon | 需要 Placement multi_tile / composite occupant |
| G-27 | 卡片复制 | 未覆盖 | Imitater | 需要 Card layer clone 协议 |
| G-28 | 跳跃高度阻挡 | 后置 | Tall-nut | 当前无跳跃僵尸正式内容；HeightBand 基线已在，collision/jump 语义等内容驱动 |
| G-29 | 坑洞/crater | 后置 | Doom-shroom | 需要 BoardSlot modifier / 场地变形；当前不作为规则基础设施主线 |
| G-30 | 随机 payload 选择 | 已覆盖 | Kernel-pult | `Emission.core.shuffle_cycle` 确定性轮换已覆盖 |

---

## 当前未完成项分层

### A. 已补机制优先验证，不需要新协议

这些能力已有资源或运行时能力，本轮已补单体验证：

- `Gloom-shroom`：`plant_original_gloomshroom_validation` 覆盖 radius_around / detected_targets 范围攻击。
- `Cattail`：`plant_original_cattail_validation` 覆盖当前 track-air projectile；全场 global_track 精确语义后续单独评估。
- `Winter Melon`：`plant_original_wintermelon_validation` 覆盖 upgrade dependency + terminal blast 伤害；slow/freeze 精确语义另列后续。
- `Gold Magnet`：`plant_original_goldmagnet_validation` 覆盖升级依赖和最小待机语义；collectible 吸附另列后置。
- `Spikerock`：`plant_original_spikerock_validation` 覆盖 ground_damage + upgrade dependency；特殊车辆交互后置。

### B. 需要最小内容实现

这些植物当前资源/card 缺失，或资源缺失导致无法进入验证：

- `Garlic`：需要新增 archetype/card，并实现 lane reroute 能力。
- `Umbrella Leaf`：需要新增 archetype/card，并实现 protection 能力。
- `Imitater`：需要新增 card clone 协议，不能绕开 CardState / RuntimeSpec。

### C. 明确后置基础设施

这些能力不建议现在为单个植物提前扩基础设施：

- `Cob Cannon` 多格占用：等待 Placement multi_tile / composite occupant 设计。
- `Doom-shroom` 坑洞：等待 BoardSlot modifier / 场地变形需求成批出现。
- `Tall-nut` 跳跃阻挡：等待跳跃僵尸或越过机制进入正式内容。
- 完整金币/银币经济：等待外循环或奖励系统进入主线。

---

## 推荐下一批

E-existing-validation 已完成。下一批不建议继续扩通用基础设施，推荐按内容缺口推进：

1. Garlic：补 archetype/card，并设计 lane reroute 的最小规则层入口。
2. Umbrella Leaf：补 archetype/card，并设计 attack protection / target guard。
3. Imitater：补 card clone 协议，保持 CardState / RuntimeSpec 边界。
4. Cob Cannon：等待 multi_tile / composite occupant 与手动发射协议成形后再做。

这些项目都比对象池、碰撞矩阵或泛化 BoardSlot modifier 更贴近当前原版植物迁移目标。

---

## 维护规则

- 新缺口只在现有 Mechanic family 无法表达时登记。
- 已由 liveness / SpatialIndex / height_range 覆盖的能力，不再重复登记为协议缺口。
- 表现动画、雾场视觉、原版概率精确值、完整经济系统默认归为“精确度/表现/外循环后置”，不阻塞机制优先验证。
- 新增原版植物验证后，同步更新 `plans/original-plant-migration-ledger.md` 和 `tools/formal_content_validation_map.json`。
