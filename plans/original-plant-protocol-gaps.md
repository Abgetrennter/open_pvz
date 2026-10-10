# 原版植物协议缺口清单

- 状态：当前事实
- 关联文件：`plans/original-plant-migration-ledger.md`
- 创建日期：2026-04-27
- 最后更新：2026-10-10

> 本文档记录原版植物移植过程中仍然影响“原版语义完成度”的协议缺口。规则基础设施第二轮完成后，多维 liveness、`SpatialIndex` / `spatial_query`、`height_range` 过滤和 tick budget 监控已成为当前基线；旧 Round 表述不再作为当前状态来源。
>
> 2026-10-10 植物部分覆盖批次：G-13 Cattail 精确追踪与 G-19 Gold Magnet 吸附提升到原版精确语义（详见对应行）；两行此前"部分覆盖"表述基于 2026-05-10 时点，global_track 检测与 collectible_magnet 控制器其后已进入主干。

---

## 当前结论

- 原版植物资源和卡片当前为 `49/49`：`Garlic`、`Umbrella Leaf`、`Imitater` 已于 2026-07-29 P0 阻塞批落地。
- 大部分早期协议缺口已经被现有 Mechanic / Effect / Controller / Placement 能力覆盖。
- 换道（G-22）、防护（G-23）、卡片复制（G-27）已关闭；当前真正阻塞新内容落地的缺口集中在场地变形与多格占用。
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
| G-13 | 全场追踪 targeting | 已覆盖（2026-10-10 植物部分覆盖批次精确化） | Cattail | `Detection.global_track`（全场扫描 + air 标签严格优先 = 原版 +10000 权重）与双发 burst 已在主干；本批校正：伤害 12→20（PROJECTILE_SPIKE=20，Projectile.cpp 伤害表）、弹速 3.333→2.083 slots/s（原版 velX=2.0px/tick）、burst 间隔 0.1→0.5s（UpdateShooter counter 50/0 各一发）、interval 1.35–1.5 窗口（mLaunchRate−Rand(15)）、`target_exposure_states` flying→ground+flying（GetDamageRangeFlags=11 地面+飞行）；新增 `track_target_follow` 飞行高度引用（原版追踪弹朝僵尸矩形中心飞，高度随目标——否则 lane 固定高度弹越过头地面目标，`plant_original_cattail_ground_damage_validation` 覆盖地面 20 伤） |
| G-14 | 对空高度切换 | 已覆盖最小语义 | Cactus | HeightBand / `height_range` 已覆盖对空命中；视觉/状态切换后置 |
| G-15 | 地面持续伤害 | 已覆盖（车辆交互补全 2026-09-29，与僵尸侧 Z-31 双侧联动） | Spikeweed, Spikerock | `Controller.core.ground_damage` 基础语义 + 车辆交互：`vehicle_damage` 1800（Zamboni/Catapult 一击毁）、`vehicle_hit_plant_damage`（Spikeweed 即死 / Spikerock 50 每击，450 血=9 次）；两植物拆分独立 mechanic 并挂 `spiky` 标签（同时服务 Z-29 投石车排除）；探针 `zombie_original_gargantuar_spikerock` |
| G-16 | 投射物改写 | 已覆盖 | Torchwood | `Controller.core.projectile_transform` 已覆盖 |
| G-17 | 全局飞行驱散 | 已覆盖 | Blover | `dispel_flying` + flying tag 已覆盖 |
| G-18 | 反隐机制 | 已覆盖最小语义 | Plantern | `reveal` effect 已覆盖；完整雾场/视野系统后置 |
| G-19 | 金属吸附 | 已覆盖（2026-10-10 植物部分覆盖批次补 collectible 吸附） | Magnet-shroom, Gold Magnet | metal targeting 与升级依赖已覆盖；`Controller.core.collectible_magnet` 本批补吸附飞行：吸附中 collectible 朝磁铁指数逼近（原版 lerp(0.02→0.05)/tick，远→近），<20px 到达才计值发 `collectible.magnet_collected`，抓取时发 `collectible.attracted`（含距离）；一次吸附全部合格币（上限 max_grabs=5=MAX_MAGNET_ITEMS）；扫描范围 9→20.833 slots 全屏（原版 IterateCoins 无射程限制）；年龄门 0.5s（mCoinAge≥50）；吸附中币禁点击/禁重复抓取，磁铁死亡自动释放。场景 `plant_original_goldmagnet_attraction_validation`（远距 650px 币 grab+arrival 双事件）。后置：空闲 1/50 触发、吸附后 200–300 ticks 充能、全局同时仅一磁铁吸附（概率/多实例精确值） |
| G-20 | 升级放置依赖 | 已覆盖最小语义 | E 批次升级植物 | `required_present_archetypes` 已覆盖依赖检查；替换/占位精确语义另见 G-26 |
| G-21 | 黄油眩晕 | 已覆盖 | Kernel-pult | `apply_status` + `butter_stun` 已覆盖；时长 2026-10-09 校正为 4.0s（原版 mButteredCounter=400 ticks）；车辆/飞行黄油豁免随 Z-13 status_immunities 落地；原版概率精确值后置 |
| G-22 | 换道 | 已覆盖 | Garlic | `Effect.lane_reroute` + `when_damaged(required_damage_tags)` + `entity.lane_changed` 已覆盖，无 zombie 特判；`plant_original_garlic_validation` |
| G-23 | 防护特定攻击 | 已覆盖 | Umbrella Leaf | `Controller.core.protect_targets` + `attack.intercepted`（命中前取消，标签驱动）已覆盖；`plant_original_umbrellaleaf_validation`；Bungee 完整流程后置 |
| G-24 | 金币资源 | 部分覆盖 | Marigold, Gold Magnet | Marigold `coin_generated` collectible 已覆盖；Gold Magnet 吸附飞行已于 2026-10-10 落地（见 G-19）；完整 coin/silver 面额 taxonomy 与外循环经济后置 |
| G-25 | 手动瞄准 | 基础能力已有，植物未完成 | Cob Cannon | BattleModeHost / InputProfile 已能承接手动输入；Cob Cannon 发射链未验收 |
| G-26 | 多格占用 | 未覆盖 | Cob Cannon | 需要 Placement multi_tile / composite occupant |
| G-27 | 卡片复制 | 已覆盖 | Imitater | CardDef `clone_source_card_id` + BattleCardState setup 展开 + `card.clone_resolved`，冷却独立；`plant_original_imitater_validation` |
| G-28 | 跳跃高度阻挡 | 后置 | Tall-nut | 当前无跳跃僵尸正式内容；HeightBand 基线已在，collision/jump 语义等内容驱动 |
| G-29 | 坑洞/crater | 已覆盖（2026-10-01，与僵尸侧 Z-11/Z-14 联动） | Doom-shroom | explode 新增 `crater_at_source_slot` + `crater_duration_ticks` 18000（原版 AddACrater->mGridItemCounter=18000）：爆后于源格生成 archetype_crater GridItem（occupies_blocker_role 阻挡补种，占格语义由 grid_item_crater_validation 覆盖）；battle_grid_item_state 新增 `schedule_expiry` game.tick 寿命通道（到期 remove+grid_item.removed reason expired）；场景 `plant_original_doomshroom_crater_validation`（夜环境唤醒→爆炸→坑洞落格→补种拒绝 required_empty_role_occupied 全链）。Batch N 连带修复：Doom-shroom 补 consume_self payload（原版爆后 Die()，此前爆炸后存活占 primary）；board_state 监听 entity.died|entity.consumed 即时释放 slot 角色 |
| G-30 | 随机 payload 选择 | 已覆盖 | Kernel-pult | `Emission.core.shuffle_cycle` 确定性轮换已覆盖 |

---

## 当前未完成项分层

### A. 已补机制优先验证，不需要新协议

这些能力已有资源或运行时能力，本轮已补单体验证：

- `Gloom-shroom`：`plant_original_gloomshroom_validation` 覆盖 radius_around / detected_targets 范围攻击。
- `Cattail`：`plant_original_cattail_validation` + `plant_original_cattail_priority_validation` 覆盖 global_track 跨行选择/air 严格优先/双发；2026-10-10 批次补精确参数（20 伤/2.083 slots/s/burst 0.5s/ground+flying 暴露态/target_follow 飞行高度）并以 `plant_original_cattail_ground_damage_validation` 验证地面 20 伤。后置：追踪弹转向速率年龄渐进曲线（现固定 turn_rate 近似）。
- `Winter Melon`：`plant_original_wintermelon_validation` 覆盖 upgrade dependency + terminal blast 伤害；slow/freeze 精确语义已于 2026-10-09 冰冻维度批次落地（专属 payload：explode `status_applications` 溅射减速 10s ×0.4，含飞行目标；普通 Melon-pult 保持不减速）。
- `Snow Pea / Ice-shroom`（2026-10-09 冰冻维度批次）：Snow Pea 减速校正为原版 1000 ticks ×0.4（`CHILLED_SPEED_FACTOR`，Zombie.h:33）；Ice-shroom 补冻结链（frozen 400-600 seeded ticks + slowed 20s + 20 伤 + 爆后自灭）并经 `zombie_original_chill_dimension_validation` 双侧验证。附带发现：直线投射物直撞不查高度带（雪豆可打到飞行气球，原版打不到），归投射物高度带缺口后续立项，暂以探针布局规避。
- `Gold Magnet`：`plant_original_goldmagnet_validation` 覆盖升级依赖和最小待机语义；2026-10-10 批次补 collectible 吸附飞行全链（全屏扫描/年龄门/一次吸 5/到达计值），`plant_original_goldmagnet_attraction_validation` 验证远距 grab+arrival。
- `Spikerock`：`plant_original_spikerock_validation` 覆盖 ground_damage + upgrade dependency；特殊车辆交互后置。

### B. 需要最小内容实现

已清零（2026-07-29 P0 阻塞批）：

- `Garlic`：已落地 archetype/card + `Effect.lane_reroute`（G-22 关闭）。
- `Umbrella Leaf`：已落地 archetype/card + `Controller.core.protect_targets`（G-23 关闭）。
- `Imitater`：已落地 card clone 协议，未绕开 CardState / RuntimeSpec（G-27 关闭）。

### C. 明确后置基础设施

这些能力不建议现在为单个植物提前扩基础设施：

- `Cob Cannon` 多格占用：等待 Placement multi_tile / composite occupant 设计。
- `Doom-shroom` 坑洞：等待 BoardSlot modifier / 场地变形需求成批出现。
- `Tall-nut` 跳跃阻挡：等待跳跃僵尸或越过机制进入正式内容。
- 完整金币/银币经济：等待外循环或奖励系统进入主线。

---

## 推荐下一批

E-existing-validation 与 P0 阻塞批（Garlic / Umbrella Leaf / Imitater）已完成。下一批不建议继续扩通用基础设施，推荐按内容缺口推进：

1. Cob Cannon：等待 multi_tile / composite occupant 与手动发射协议成形后再做。
2. Doom-shroom 坑洞 / 完整 coin taxonomy 等 P1 项按草案后续批次拆分。

这些项目都比对象池、碰撞矩阵或泛化 BoardSlot modifier 更贴近当前原版植物迁移目标。

---

## 维护规则

- 新缺口只在现有 Mechanic family 无法表达时登记。
- 已由 liveness / SpatialIndex / height_range 覆盖的能力，不再重复登记为协议缺口。
- 表现动画、雾场视觉、原版概率精确值、完整经济系统默认归为“精确度/表现/外循环后置”，不阻塞机制优先验证。
- 新增原版植物验证后，同步更新 `plans/original-plant-migration-ledger.md` 和 `tools/formal_content_validation_map.json`。
