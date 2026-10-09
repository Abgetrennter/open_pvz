# 原版僵尸协议缺口清单

- 状态：当前事实
- 关联文件：`plans/zombie-design-research-report.md`
- 创建日期：2026-09-28
- 最后更新：2026-09-28

> 本文档记录原版僵尸移植过程中仍然影响"原版语义完成度"的协议缺口，口径与 `plans/original-plant-protocol-gaps.md` 对齐。数值与行为条件以 `references/de-pvz/Lawn/Zombie.cpp`、`Zombie.h` 实测为准；本文所有锚点均在 2026-09-28 逐条回源码核证。
>
> 更新（2026-09-28，Batch F）：Z-02（Digger 出土方向）、Z-04（Yeti 逃跑触发，计时器化）、Z-09（Dolphin 落地速度）、Z-22（Jack 爆炸半径）已修正并加深探针断言；连带修复 zombie_root 中央步进下 State 时间转换不执行的链路缺口，yeti/batch_d 验证窗口提到 18s。Z-32（Dancer 重召）经探测需“成员存活检测”，当前 Detection 只扫敌军，无协议变更无法表达，维持部分覆盖。
>
> 更新（2026-09-28，Batch I）：Z-25/Z-26（Ladder 持久梯子）已落地：新 GridItem `archetype_ladder_grid_item`（不占 blocker 位），`spawn_grid_item` effect 新增 `at_target_slot` 参数（从 context 目标植物解析 lane/slot），Ladder 僵尸 proximity 触发放梯（detection lane_backward + target_tags defense）；新 movement `core.climb_once`（恒速爬升 0.83 slots/s + 前移漂移 0.52，过顶后重力下落，落地切 post_climb walk）；`core.bite` 新增 `ladder_climb` 参数（遇有梯格 defense 不咬改爬，14 个地面步行 original 僵尸启用，Digger/Snorkel/Dolphin/Pogo/Balloon/Yeti 按原版语义排除）；explode effect 新增 `remove_grid_item_tags`（火清行内梯子，Jalapeno 启用）。proximity trigger def 补齐 detection_id/target_tags 正式参数。行为级验证 `zombie_original_ladder_grid_validation`（放梯/爬越不咬/对照啃咬/火清）。
>
> 更新（2026-09-29，Batch J）：Z-29（detection `target_selection: leftmost` + `target_exclude_tags` spiky + `min_scan_range` 100px，Catapult 盲射折入同拍 trigger/payload 语义附注）、Z-28 尾（periodically 弹尽发 `trigger.exhausted` 事件，Catapult 状态切 `spent` 换 walk+啃咬控制器）、Z-32（detection `team_mode: allies` + `lane_offset`/`x_offset` 槽位空缺探测 + `require_no_target`，Dancer 四槽逐位补员，槽位 x 偏移修正为原版 ±100）、Z-31/G-15 双侧（crush `soft_target_tags` Spikerock 吸收 50/自伤 20 + `ignore_target_tags` 车辆压过不压刺 + ground_damage `vehicle_damage` 1800/植物自付，Zamboni 拆分 drive_over 控制器）、Z-05（produce_sun `x_offset`，Yeti 死亡掉 4 颗 yeti_diamond）、Z-01（`move_speed_slots_per_sec_min/max` 区间 + `GameState.resolve_ranged_value` 实体级确定性采样，全表按 PickRandomSpeed 区间落数据，设计文档 `plans/zombie-speed-range-sampling.md`）落地。Z-11 冰道完成设计轮（`plans/zombie-ice-trail-field-modifier.md`），待 Bobsled/G-29 立项实施。
>
> 更新（2026-10-01，Batch K）：Z-18（leap_once 新增 `vault_trigger_tags`/`vault_trigger_exclude_tags`/`vault_trigger_scan_range` 助跑段 + `vault_landing_beyond_px` 70 落点公式：跳速 = (起跳x−(目标x−70))/滞空时间，助跑 0.66–0.68、有梯格不跳改爬、spiky 排除）、Z-21（periodically 新增 `fuse_distance_min/max`+`early_trigger_probability/scale`+`fuse_speed_factor` 距离折算定时引信：fuse = (450+Rand(300))px ÷ 实体采样速度 × ZOMBIE_LIMP_SPEED_FACTOR 2，1/20 缩 1/3，啃食不停摆引信，`max_trigger_count=1` 一次爆，explode+consume_self 双 payload）落地。探针 `zombie_original_vault_formula`/`zombie_original_jack_distance_fuse`。附注：Z-21 的 1.1s 爆开动画窗口（POP 110 ticks）与全冻停摆引信（IsImmobilizied 门）未表达；Z-18 两段式落点（弧落 plantX+80 再瞬移 −150）合并为单弧直达 plantX−70。
>
> 更新（2026-10-01，冰道批次）：Z-11（新子系统 `battle_field_state`：每 (lane,kind) 单区间+行级计时器，`apply_modifier`/`renew_lane_modifier`/`query`/`get_ice_trail_speed_scale`，事件 field.modifier_applied|expired；Zamboni `core.drive` 铺冰 3000 ticks，冰面 walk 与 bite 回退两路 ×0.5、车辆豁免）、Z-14（archetype_original_bobsled_team：橇=300 血 attachment 层、滑速 0.625 slots/s、`ice_renewal_ticks` 500 只续时不扩区间、离冰每 tick 自磨 6 点，新触发器 `core.when_layer_destroyed`（required_layer_id+max_trigger_count）驱动 4×spawn_entity 解体 + consume_self；archetype_original_bobsled 步行个体 0.23–0.32）、G-29 双侧（explode 新增 `crater_at_source_slot`+`crater_duration_ticks` 18000，复用 archetype_crater GridItem blocker 占格；battle_grid_item_state 新增 `schedule_expiry` game.tick 寿命通道）落地。探针 `zombie_original_ice_trail`/`zombie_original_bobsled_team` + 场景 `plant_original_doomshroom_crater_validation`。附注：滑行队伍不啃咬（原版 SLIDING 相无攻击分派）；队伍单体血池近似（原版 4 独立实体 270×4，宽 hitbox 由领队吸收投射物的语义下差异有限）；坑洞设计文档第 3 点的"crater 走 field modifier"按边界条款改走 GridItem 通道（格级归 GridItem）；Z-13 冰冻免疫仍开放。>
>
> 更新（2026-10-01，Batch L）：Z-33（投射物命中打方向标记：`_launch_direction.x < 0` → hit.rear、`_move_mode == parabola` → hit.overhead，事件与直伤 tags 双路；HealthLayerDef 新增 `bypass_on_damage_tags`，`_build_damage_route` 按伤害 tags 跳层；screen_door 与 ladder 两层声明 bypass；damage 效果 attack_tags 并入伤害 tags）、Z-34（`data/combat/waves/pool_original_adventure.tres`：24 条目按 gZombieDefs 三元组落位，value→power、startingLevel−1→first_allowed_wave、pickWeight→weight，水生三系挂 spawn.medium.water zone 门，flag 条目 weight 0；衰减公式已核证并记录，实施等生存模式旗帜计数器立项）。探针 `zombie_original_screen_door_directional`（正面吃盾/背面与越顶直击本体/Split Pea 后向头实战路径）+ `zombie_original_wave_pool`（三元组 spot-check/zone 门/种子编译预算与解锁曲线）。附注：melon 溅射走 on_hit 效果链不带方向标记（原版溅射为盾体双伤 DAMAGE_HITS_SHIELD_AND_BODY，本引擎仍单发路由）；backup_dancer 不入池（原版召唤专用）；redeye 仅生存模式出现（入池与否等生存模式立项再定）。>
>
> 更新（2026-10-01，Batch M）：Z-03（StateComponent 新增 `position` 触发类型（position_axis/position_compare/position_threshold），Digger tunneling→rising 于 x<10（原版 mPosX<10，Zombie.cpp:2678），rising 1.3s（原 RISING 130 ticks）→ surfaced 右行）、Z-07（Snorkel 撤固定 1.5s 上浮：新 `core.emit_event` 效果 + 双 periodically 触发（检测 lane_backward 56px 有目标→snorkel.chew_started / require_no_target→snorkel.chew_ended）+ 事件状态机 submerged↔surfaced；bite 控制器新参数 `suppress_exposure_states`（潜水不啃））、Z-08（Snorkel position 触发 x≤25 → ashore 出水转默认区间步行）、Z-10（Dolphin 陆行 0.66–0.68 → `vault_trigger_after_x` 700 位置门 → 骑乘 0.3（pre_leap_ride_speed）→ 遇植物按落点公式跃，archetype 速度从 0.9 修正为陆行区间）、Z-15（TriggerRegistry 新增 `required_lane_tags` 条件（lane traits 交集），Balloon 层碎 + terrain.pool → 9999 自伤即死，落地走路状态保留给陆地）。败线判定豁免 underground/submerged（原版相位门控：挖掘/游泳不视为抵达屋前）。探针 `zombie_original_digger_surface` + `zombie_original_aquatic_cycle`（泳池 lane 预置）。附注：Snorkel 出水后步行用默认区间（原版 PickRandomSpeed 无 SNORKEL_WALKING 特判）；Dolphin 入水动画/ RIDING 动画相未表达（位置/速度语义已补）；池 edge 700/720 区间简化为单线 700。
>
> 更新（2026-10-01，Batch N）：Z-16（hop_cycle 新增 hop_height_sequence [40,40,90,170] 循环序列，apex 高度按 sqrt(2|g|h) 折算起跳速度）、Z-17（Pogo 挂 pogo_stick 20 血 metal attachment 层；hop_cycle 中空遇 vault_blocker 走 blocked_landing_movement 并以 spillover=false 的 9999 剥层（Magnet 吸金属 20 伤同样打穿该层）→ health.layer_destroyed 状态机 bouncing→walking 0.23–0.32，对应原版 PogoBreak）、Z-22（explode 新增 radius_slots_plant/radius_slots_zombie 双半径 + blast_team_mode allies 第二遍扫己方（对应 KillAllZombiesInRadius 115 / KillAllPlantsInRadius 90，自爆者排除），Jack payload 双键落位 0.9375/1.197917）、Z-23（Bungee 重做完整流程：diving 1.9s→grabbing 3s（原版 300 ticks）→proximity 30px 检测驱动 steal（context_target 9999 + overhead/bungee 标签保留伞叶拦截）或 require_no_target 离场 consume；新增 hover bite 控制器 suppress flying）、Z-30（核证修正：原版小鬼落点恒为 mPosX−133（现状已对），真正缺的是投掷条件门 aThrowingDistance > 40 即 mPosX>400——when_damaged 新增 min_owner_x 条件挂 400）。连带引擎修复：board_state 监听 entity.died|entity.consumed 即时释放 slot 角色（原依赖 queue_free 懒清理）；Doom-shroom 补自灭 payload（原版爆后 Die()，此前爆炸后存活占格）。探针 zombie_original_batch_n_interactions + 场景 plant_original_doomshroom_crater_validation 恢复补种拒绝断言。附注：pogo 断簧后实体 metal 标签保留（Magnet 对步行体继续 20 伤/5s 的轻微近似）；bungee dive/grab 动画相未表达；Jack 爆炸自伤排除（DieNoLoot 语义由 consume 承载）。
>
> 更新（2026-10-09，冰冻维度批次）：Z-13 落地（新 `CombatArchetype.status_immunities` 维度：Zamboni/Bobsled-team 声明 slowed/frozen/butter_stun，`base_entity.apply_status` 单点门拒收不发事件；详见 Z-13 行）。chill/freeze 精确语义双侧联动：explode 新增 `status_applications` 字典参数（status_id → {duration / duration_min+duration_max 走 `GameState.resolve_ranged_value` 实体级种子采样 / movement_scale / liveness_overrides}，伤害前快照免疫资格、伤害后仅对幸存者施加——对应原版 HitIceTrap 先判 CanBeFrozen 再 TakeDamage(20) 的次序）；Snow Pea 减速校正 2.5s×0.5 → 1000 ticks×0.4（原版 DAMAGE_FREEZE 通道 `Projectile.cpp:399-402`，`CHILLED_SPEED_FACTOR` 0.4）；Winter Melon 拆专属 payload 挂同通道溅射减速（普通 Melon-pult 不减速）；Ice-shroom 补冻结链（frozen 400-600 seeded + slowed 20s ×0.4 + 20 伤 + consume 自灭，爆炸目标暴露面含 flying——原版冰豆命中飞行气球）；Kernel-pult 黄油时长 3.0→4.0s（mButteredCounter=400）；Balloon 冻结豁免走状态化（archetype 声明 frozen，drop 状态机新 `set_status_immunities` side effect 落地清空，对应 CanBeFrozen 的 IsFlying 门）。探针 `zombie_original_chill_dimension`（场景卡片放置冰菇，夜间环境唤醒）。附注：CanBeChilled 阶段性排除（挖掘/出土/催眠/Boss 相）未逐一表达；同 status 重施为覆盖式重置（原版 max() 保留）；发现直线投射物直撞不查高度带（雪豆可打飞行气球，原版打不到）——归投射物高度带缺口，后续立项，探针以 Zamboni 挡弹规避。

---

## 当前结论

- 原版 `ConstEnums.h:ZombieType` 共 33 种（不含 2 个缓存变体）；OpenPVZ 已落地 28 个 `archetype_original_*`（冒险 24 + Redeye Gargantuar + Backup Dancer + Bobsled Team + Bobsled），批次 A-E 验证与正式映射均已登记。
- 数量缺口 6 个：Dr. Zomboss、Zombotany ×6，均为已裁决的 P2 独立系统（见机制盘点草案），不阻塞主线。
- **本轮源码比对发现两处与原版方向相反/不同的行为语义**（Z-02 Digger 出土方向、Z-04 Yeti 逃跑触发），属于无新协议即可修的精度偏差，建议最先处理。
- 大部分已有僵尸的验证停留在结构断言（mechanic/layer 存在），行为精度缺口集中在：状态触发条件（计时器 vs 事件）、端点行为（入水/出水/停位）、持续交互（冰道、梯子、召唤刷新）。
- 波次层 `WavePoolEntryDef` 的 `power / weight / first_allowed_wave` 已能承载 `gZombieDefs[]` 三元组，缺的是按原版解锁曲线组织的 original 正式 pool，不是协议。

---

## 缺口总览

> 状态口径：**已覆盖** = 资源与验证足以表达原版最小语义；**部分覆盖** = 资源存在但行为与原版有可证差异或缺口；**后置** = 已裁决等待外部依赖或独立设计。

| ID | 名称 | 当前状态 | 关联僵尸 | 当前判断 |
|----|------|----------|----------|----------|
| Z-01 | 速度区间随机采样 | 已覆盖（2026-09-29） | 几乎全部 | `move_speed_slots_per_sec_min/max` 区间键 + `GameState.resolve_ranged_value` 按实体种子确定性采样（movement 与 bite 回退两路同值缓存）；全表按 PickRandomSpeed 区间落位（默认 0.23–0.32、快跑 0.66–0.68、搬梯 0.79–0.81、狂暴/海豚 0.89–0.91）；探针 `zombie_original_speed_range`。设计：`plans/zombie-speed-range-sampling.md`；Zamboni 0.25 与共享 bite post-climb 0.25 保留为注明的近似 |
| Z-02 | Digger 出土方向 | 已覆盖（2026-09-28） | Digger | surface state side-effect 已改向右回头（+1,0），探针断言 `surfaced` 转换的方向 |
| Z-03 | Digger 出土触发条件 | 已覆盖（2026-10-01） | Digger | StateComponent 新增 `position` 触发类型（axis/compare/threshold，每物理帧按 from_state 守卫评估）：tunneling 于 x<10 → rising（停走 1.3s，对应原 RISING 130 ticks）→ surfaced（右行 0.12）；败线判定豁免 underground（挖掘穿越防线不触发屋失，原版同语义）；探针 `zombie_original_digger_surface`（中途 underground/左缘出土/右行/不败线） |
| Z-04 | Yeti 逃跑触发 | 已覆盖（2026-09-28） | Yeti | flee state 已改 `trigger: "time"`（`after: 15.0`，对应原版 1500-2000 ticks 下界），探针推 1510 tick 断言无伤逃跑 |
| Z-05 | Yeti 死亡掉礼物 | 已覆盖（2026-09-29） | Yeti | on_death trigger + 4×produce_sun（新增 `x_offset` 参数，-20/-30/-40/-50 对应原版 aCenterX 偏移），source_type `yeti_diamond`、value 50；钻石计价待 G-24 经济轮核定（现为 coin 同价名义值）；原版 award 门控（mDroppedLoot/HasLevelAwardDropped）无对应系统未表达，探针 `zombie_original_yeti_gift` |
| Z-06 | Yeti 稀有生成权重 | 后置（wave 层） | Yeti | `gZombieDefs[]` weight=1、startingLevel=40（`Zombie.cpp:44`）；待 Z-34 original pool 落地时一并表达 |
| Z-07 | Snorkel 接近上浮/下潜循环 | 已覆盖（2026-10-01） | Snorkel | 撤固定 1.5s 上浮；双 periodically 触发（lane_backward 56px + target plant：有目标 emit `snorkel.chew_started` / require_no_target emit `snorkel.chew_ended`，新 `core.emit_event` 效果、信号以 owner 为 target 满足状态机归属）+ 事件状态机 submerged↔surfaced（set_height_band 切 exposure）；bite 控制器新参数 `suppress_exposure_states: [submerged]`（潜水不啃，原版上浮才吃）；探针 `zombie_original_aquatic_cycle`（submerged 接近→surfaced 啃→植物亡→re-submerged） |
| Z-08 | Snorkel 端点出水步行 | 已覆盖（2026-10-01） | Snorkel | position 触发 x≤25（submerged→ashore）：set_height_band ground + 默认区间 0.23–0.32 步行；原版右端反向（aBackwards）无对应场景未表达（引擎僵尸单向左行）；探针同 aquatic_cycle 场景口径 |
| Z-09 | Dolphin 落地后高速步行 | 已覆盖（2026-09-28） | Dolphin Rider | `post_landing_movement` 已改 0.9 档；探针断言落地速度 |
| Z-10 | Dolphin 入水/出水序列 | 已覆盖（2026-10-01） | Dolphin Rider | leap_once 复用 Batch K 助跑段 + 新 `vault_trigger_after_x` 700 位置门（左行 x≤700 才开扫）+ `pre_leap_ride_speed_slots_per_sec` 0.3 骑乘段（原版 RIDING 0.3）；archetype default_params 0.9 修正为陆行区间 0.66–0.68（原 PHASE_DOLPHIN_WALKING 落 PickRandomSpeed 0.66–0.68 支）；遇植物按 Z-18 落点公式跃、落地 0.89–0.91；探针 aquatic_cycle（陆行→过线骑乘→跃墙子→落地快走）。近似附注：入水/骑乘动画相未表达；x≤10 左端出水未表达（池 lane 全宽语义下无陆段） |
| Z-11 | Zamboni 冰道生成 | 已覆盖（2026-10-01） | Zamboni | `battle_field_state` 子系统：每 (lane,kind) 单区间 [x_min,x_max] + 行级计时器（对应 mIceMinX/mIceTimer 行全局语义）；Zamboni `core.drive` `lay_ice_trail` 每步并集扩区间、3000 ticks 幂等续期；`core.walk` 与 zombie_root bite 回退两路 `get_ice_trail_speed_scale` ×0.5（vehicle 标签豁免）；超时整体消退发 field.modifier_expired；探针 `zombie_original_ice_trail`（同 lane 半速/跨 lane 对照/车辆豁免/到期消退） |
| Z-12 | Zamboni 位置驱动减速 | 已覆盖（2026-09-28） | Zamboni | `core.drive` 新增 decel_start_x/decel_end_x/decel_min_slots_per_sec 线性减速（对应原版 0.25→0.05、x 700→300），探针断言参数 |
| Z-13 | Zamboni/Bobsled 冰冻免疫 | 已覆盖（2026-10-09，冰冻维度批次） | Zamboni, Bobsled | `CombatArchetype.status_immunities` 维度（原版 `CanBeChilled()`/`CanBeFrozen()`/`ApplyButter()` 排除，`Zombie.cpp:7982/8009/8477`）：Zamboni 与 Bobsled-team 声明 slowed/frozen/butter_stun 三项免疫，`base_entity.apply_status` 单点门（拒收不发事件），工厂从 resolved archetype 拷贝；Ice-shroom explode 的 `status_applications` 在伤害前快照资格（原版 HitIceTrap 先判 CanBeFrozen 再结算 20 伤，飞行气球免冻但同拍被打爆落地）；滑行个体（离橇步行者）保持可减速；探针 `zombie_original_chill_dimension`（车辆免疫直放拒收/雪豆 ×0.4/西瓜溅射/冰菇冻结链/气球落地清豁免）。近似附注：CanBeChilled 的阶段性排除（Digger 挖掘/出土相、Rising-from-grave、被催眠、Boss 非吐头相）未逐一表达——挖掘/入水暴露过滤已挡大部分，Boss 属 Z-35；同 status 重施为覆盖式重置而非原版 max() 保留 |
| Z-14 | Bobsled 队伍 | 已覆盖（2026-10-01） | Bobsled | archetype_original_bobsled_team（vehicle/bobsled/team）：橇=300 血 attachment 层（route_order 10 先吸收），`core.drive` 恒速 0.625 slots/s（原版 0.6px/tick）+ `ice_renewal_ticks` 500（只刷新已有冰道计时，不扩区间，对应 max(500,mIceTimer)）+ `off_ice_damage_per_tick` 6（x+10 < 冰道 x_min 起每 tick 自磨，300 血约 0.5s 破橇）；破橇走新触发器 `core.when_layer_destroyed`（required_layer_id sled）→ 4×spawn_entity（x_offset 0/50/100/150 对应原版追随者间距）+ consume_self；解体后 archetype_original_bobsled 常规步行 0.23–0.32（冰上半速）；探针 `zombie_original_bobsled_team`（橇层结构/滑速/离冰自磨/四员解体/独立行走）。近似附注：滑行期不啃咬（原版 SLIDING 相无攻击分派）；单体血池近似（原版 4×270 独立实体，本引擎单实体 270+300 层）；BOARDING 动画相未表达 |
| Z-15 | Balloon 水面落地死亡 | 已覆盖（2026-10-01） | Balloon | TriggerRegistry 新增 `required_lane_tags` 条件（battle board lane traits 交集，fail-closed）；Balloon `when_layer_destroyed`（balloon 层 + terrain.pool）→ damage 9999 即死（原版 DieWithLoot 直接亡）；陆地落地状态机保留不变；探针 aquatic_cycle（泳池 lane 爆气球→亡）。附注：1-slot 池格与全 lane 池的边界未区分（lane 级 traits 判定） |
| Z-16 | Pogo 弹跳高度序列 | 已覆盖（2026-10-01） | Pogo | hop_cycle 新增 `hop_height_sequence`（[40,40,90,170] 循环，对应原版普通 40/FORWARD_2 90/FORWARD_7 170 的三段递增近似），apex→起跳速度 sqrt(2|g|h)；探针 `zombie_original_batch_n_interactions`（断言 170px apex 达成）。附注：原版 HIGH_BOUNCE_1..6 的 50–150 中间档归并为单 170 档 |
| Z-17 | Pogo 弹簧破坏后步行 | 已覆盖（2026-10-01） | Pogo | pogo_stick 20 血 metal attachment 层（Magnet 20 伤一击剥簧）；hop_cycle 中空遇 vault_blocker（Tall-nut）以 spillover=false 9999 剥层并落 `blocked_landing_movement`；`health.layer_destroyed` 状态机 bouncing→walking（0.23–0.32，对应 PickRandomSpeed 默认档）；探针 batch_n_interactions（Tall-nut 断簧→步行）。附注：断簧后实体 metal 标签保留，Magnet 对步行体继续 20 伤/5s 为已知近似 |
| Z-18 | Pole Vaulter 跳跃距离公式 | 已覆盖（2026-10-01） | Pole Vaulter | leap_once 新增助跑段（`vault_trigger_tags` plant + `vault_trigger_exclude_tags` spiky + `vault_trigger_scan_range` 96px，同 lane、活体过滤、有梯格不跳改爬）与落点公式（`vault_landing_beyond_px` 70：跳速 = (起跳x−落点x)/滞空时间，滞空 = 2×jump_velocity/|gravity|）；落地切默认区间 walk（0.23–0.32）；探针 `zombie_original_vault_formula`（助跑速度区间/落点 ±14px/不啃咬/落地后区间）。近似附注：原版两段式（弧落 plantX+80、动画完成瞬移 −150）合并为单弧直达 plantX−70，净语义等价；原版 anim_jump 时长由 reanim 决定，本引擎用自弧物理时长归一 |
| Z-19 | Tall-nut 跳跃阻挡 | 已覆盖（2026-09-28） | Pole Vaulter, Dolphin, Pogo | leap_once 新增 `vault_block_tags` 标签驱动阻断 + `blocked_landing_movement`，Tall-nut 挂 `vault_blocker` 标签；连带修正僵尸空中不咬（原版跳跃中不啃）；`zombie_original_vault_block_validation` 行为级验证（阻挡咬 Tall-nut / 越过 Wall-nut） |
| Z-20 | Newspaper 狂暴速度 | 已覆盖 | Newspaper | 当前 rage 后 0.28→0.89，落在原版 0.89–0.91 区间起点；`layer_destroyed` 触发与原版 shield 摧毁一致 |
| Z-21 | Jack 引信距离语义 | 已覆盖（2026-10-01） | Jack-in-the-Box | periodically 新增距离折算引信参数（`fuse_distance_min/max` 450/750 + `early_trigger_probability` 0.05 + `early_trigger_scale` 1/3 + `fuse_speed_factor` 2 即 ZOMBIE_LIMP_SPEED_FACTOR）：fuse 秒数 = 距离采样 × 2 ÷ (实体采样速度×96)，速度读自 Z-01 同一缓存 roll；`max_trigger_count=1` 一次性爆炸 + explode/consume_self 双 payload（爆后自灭）；啃食停走不停引信（原版 mPhaseCounter 与移动无关）；探针 `zombie_original_jack_distance_fuse`（seeded roll 断言爆点时刻 ±0.35s/恰一次 consume/啃+爆伤害）。近似附注：POP 110 ticks 爆开动画窗口未表达（爆在阈值达时刻）；IsImmobilizied 全冻停摆引信未表达（本引擎冻结状态尚无停摆通道） |
| Z-22 | Jack 爆炸半径分目标 | 已覆盖（2026-10-01） | Jack-in-the-Box | explode 新增 `radius_slots_plant`/`radius_slots_zombie`：敌侧按植物半径 0.9375（90px）解析，`blast_team_mode: allies` 第二遍按僵尸半径 1.197917（115px）扫己方（对应 KillAllZombiesInRadius/KillAllPlantsInRadius 双调用，爆炸者自排除）；Jack payload 双键落位；探针 batch_n_interactions（80px 植物中/105px 僵尸中/130px 植物不中） |
| Z-23 | Bungee 完整偷取流程 | 已覆盖（2026-10-01） | Bungee | 重做：diving 1.9s（原版俯冲时长近似）→ grabbing 3s（原 300 ticks 抓取窗）→ proximity 30px 检测（required_state grabbing 门控）：有植物→context_target 9999 偷取（attack_tags overhead/bungee 保留伞叶拦截语义）+ consume 离场；空位→require_no_target 离场；新增 hover bite 控制器（suppress flying，悬停不啃）；探针 batch_n_interactions（俯冲→抓取→偷走→离场全链）。附注：整列随机选格由 wave 层 x_position 承载（场景内由 spawn 决定）；俯冲/举起飞走动画相未表达 |
| Z-24 | Bungee × Umbrella 反制 | 已覆盖（2026-09-28） | Bungee | damage effect 新增正式参数 `attack_tags`，effect 侧拦截与 projectile 路径同判据（intercept_tags 交集 + intercept_radius + 同 lane），Bungee drop damage 声明 overhead/bungee；`zombie_original_bungee_umbrella_validation` 探针驱动验证（覆盖植物零伤害 + 未覆盖植物命中 + attack.intercepted） |
| Z-25 | Ladder 持久梯子物件 | 已覆盖（2026-09-28） | Ladder | `archetype_ladder_grid_item` GridItem 全生命周期（放置/格占用/移除事件），`spawn_grid_item` 新增 `at_target_slot`（从 context 目标植物解析 lane/slot，对应 AddALadder(col,row)）；Ladder 僵尸 proximity（lane_backward+defense 标签）放梯；火清：explode 新增 `remove_grid_item_tags`，Jalapeno 行爆启用 |
| Z-26 | 梯子越墙共用 | 已覆盖（2026-09-28） | Ladder, 其他步行僵尸 | 新 movement `core.climb_once`（恒速爬升 0.83 slots/s≈原版 0.8px/tick、前移漂移 0.52≈0.5px/tick、climb_height 0.94≈90px、过顶重力下落、落地切 post_climb walk）；`core.bite` 新增 `ladder_climb` 参数（遇有梯格 defense 不咬改爬）；14 个地面步行 original 僵尸启用（Digger 按原版 :6964 排除，Snorkel/Dolphin/Pogo/Balloon/Yeti 特殊运动链排除）；行为级验证 ladder_grid 双 lane 对照 |
| Z-27 | Catapult 停位条件 | 已覆盖（2026-09-28） | Catapult | `core.walk` 新增 `stop_x` 位置保持参数（对应原版 mPosX<=650 火线），探针断言 |
| Z-28 | Catapult 弹药与弹尽步行 | 已覆盖（2026-09-29） | Catapult | 弹药计数（Batch G+H）+ 弹尽链路（Batch J）：TriggerInstance 达到 max_trigger_count 后一次性发 `trigger.exhausted` 事件（core 带 spec_id/fired_count），Catapult `core.rage` 状态机 armed→spent 监听之，set_movement 换无 stop_x 的 walk（区间 0.23–0.32）并激活啃咬控制器（出生即挂、停位线天然隔离）；探针 `zombie_original_catapult_exhaustion` |
| Z-29 | Catapult 目标选择 | 已覆盖（2026-09-29） | Catapult | detection 新增 `target_selection: leftmost`（按 x 升序取最左）、`target_exclude_tags`（spiky，对应 IsSpiky 排除 Spikeweed/Spikerock 两 archetype 新挂 `spiky` 标签）、`min_scan_range` 100px（对应 mX >= plantX+100）；探针 `zombie_original_catapult_leftmost`。近似附注：原版盲射 mPosX-300 仅发生在发射动画中段目标消失（300 ticks 窗口），本引擎 trigger/payload 同拍执行使该窗口不存在，无目标→不射击语义与原版一致；TOPPLANT_CATAPULT_ORDER 同格叠层取舍无对应（单植物/格） |
| Z-30 | Gargantuar 投掷条件与距离 | 已覆盖（2026-10-01，核证修正） | Gargantuar, Redeye | 核证修正：原版投掷距离变量只用于条件门与随机化，小鬼落点恒为 `mPosX - 133`（`:2161`）——现有 x_offset -133 落点本已正确；真正缺的是条件门 `aThrowingDistance > 40`（即 mPosX > 400，近屋不抛只砸）。when_damaged 新增 `min_owner_x` 条件，Gargantuar/Redeye 抛掷触发挂 400；探针 batch_n_interactions（350px 处打穿血线不出小鬼）。附注：屋顶 -180/-140 门（StageHasRoof 分支）与抛掷飞行弧（PHASE_IMP_GETTING_THROWN velX 3）未表达 |
| Z-31 | Gargantuar × Spikerock 反伤 | 已覆盖（2026-09-29，双侧联动） | Gargantuar, Redeye | crush 新增 `soft_target_tags`（spikerock）`soft_target_damage` 50（450 血=9 次承伤，即原版独立承伤次数）`soft_target_self_damage` 20；Zamboni/Catapult 拆分 `mechanic_original_drive_over_controller`（`ignore_target_tags` spiky，对应 SquishAllInSquare DRIVE_OVER 跳过）；植物侧 ground_damage 新增 `vehicle_damage` 1800 + `vehicle_hit_plant_damage`（Spikeweed 9999 即死/Spikerock 50），Spikeweed/Spikerock 各自独立 mechanic；砸 Spikeweed 仍走 9999 即压死（原版 else 分支）；探针 `zombie_original_gargantuar_spikerock`；G-15 状态同步见植物侧底账 |
| Z-32 | Dancer 召唤刷新 | 已覆盖（2026-09-29） | Dancing | 撤 on_spawned 一次性召唤，改为 4 个逐槽位维护 trigger：periodically（interval 1.67s ≈ 100 ticks）+ proximity 探测 `team_mode: allies`（detection 新增友军扫描）`target_tags: backup_dancer`（新标签）`lane_offset/x_offset`（±1 行/±100px，修正原 ±64）`scan_range` 64 + `require_no_target`（槽空才触发）；槽位 lane 越界由 trigger 侧 `is_valid_lane` 守卫短路（对应原版无效行 no-op）。近似附注：空缺按位置而非身份判定，相邻双舞王极端场景可能互相补位；mHasHead 门控未表达；探针 `zombie_original_dancer_resummon` |
| Z-33 | Screen Door 方向性挡弹 | 已覆盖（2026-10-01） | Screen Door, Ladder | projectile_root `_on_hit` 按运动打方向标记（左飞 `hit.rear` 对应 MOTION_BACKWARDS/星形 mVelX<0、抛物 `hit.overhead` 对应 MOTION_LOBBED，de-pvz Projectile.cpp:382-404），事件与直伤 tags 双路；HealthLayerDef 新增 `bypass_on_damage_tags`，`_build_damage_route(policy, tags)` 命中即跳层直击本体；screen_door（1100 shield）与 ladder（500 attachment）两层声明 bypass；damage 效果声明 attack_tags 并入伤害 tags（探针可注入标记）；探针 `zombie_original_screen_door_directional`（正面/背面/越顶三路效果级 + Split Pea 后向头实战）。近似附注：melon 溅射走 on_hit 效果链不带方向标记，且原版溅射为盾体双伤（DAMAGE_HITS_SHIELD_AND_BODY），本引擎单发路由维持近似 |
| Z-34 | Original 正式波次 pool | 已覆盖（2026-10-01，数据层） | 全部 | `data/combat/waves/pool_original_adventure.tres` 24 条目：value→power、startingLevel−1→first_allowed_wave（原版门槛 waveIndex+1 ≥ startingLevel 的 0 基换算）、pickWeight→weight；snorkel/dolphin/ducky_tube 挂 `spawn.medium.water` required_spawn_tags（对应 IsZombieTypePoolOnly 水池限定）；flag 条目 weight 0 留作 flag_entry；探针 `zombie_original_wave_pool`（三元组 spot-check + 种子编译预算/解锁曲线断言）。衰减公式已核证（Board.cpp:2478-2519：生存 endless 首现波前移 18→50 旗帜 0→15；normal/cone 权重衰减至 1/10、1/4；伽刚/雪橇出怪上限曲线；红眼旗帜波与累计上限曲线+非旗波权重 1000；Bungee endless 限旗帜波）——依赖旗帜计数器，随生存模式立项实施。backup_dancer 不入池（召唤专用），redeye/imp 照表入池 |
| Z-35 | Dr. Zomboss | 后置（P2） | Boss | 需独立 Boss mode（踩踏/投车/火冰球/召唤/bungee 协同），已裁决不进普通 roster |
| Z-36 | Zombotany ×6 | 后置（P2） | 6 种植物头 | Pea/Wallnut/Jalapeno/Gatling/Squash/Tallnut Head，power 1–4；作为 mode/content pack 专项，复用植物 mechanic 挂 zombie 载体 |

---

## 当前未完成项分层

### A. 无新协议即可修的精度偏差

> Batch F（2026-09-28）消化 Z-02/Z-04/Z-09/Z-22；Batch G+H 消化 Z-12/Z-19/Z-24/Z-27；Batch J（2026-09-29）消化 Z-01/Z-05/Z-28 尾/Z-29/Z-31/Z-32；冰冻维度批次（2026-10-09）消化 Z-13。A 层已清零，剩余精度项见各行"近似附注"（Z-27 停位无目标不放行、Z-29 盲射窗口、Z-32 身份判定、Z-13 阶段性排除等）。

### B. 需要最小协议/能力设计的交互

- **Z-19 Tall-nut 阻挡**：与植物侧 G-28 合并对拍，内容驱动即可，不一定新协议。
- **Z-24 Bungee × Umbrella**：双侧能力已有，补交互矩阵验证即可。
- **Z-25/Z-26 Ladder 持久物件**：复用 GridItem 第一片（crater）模式扩展。
- **Z-27/Z-28 Catapult 停位与弹药**：停位条件（x 阈值 + 目标存在）可能需要 trigger 条件扩展，弹药计数可用 runtime params 近似。
- **Z-30 Gargantuar 投掷距离**：spawn_entity payload 加落点公式参数。
- ~~**Z-33 Screen Door 方向性**~~（Batch L 已落地：命中方向标记 + 层级 bypass_on_damage_tags，非 HitPolicy 扩展路线）。

### C. 明确后置基础设施

- ~~**Z-01 速度区间**~~（Batch J 已落地）；~~**Z-18 撑杆距离公式 / Z-21 小丑按距离引爆**~~（Batch K 已落地，2026-10-01）。
- ~~**Z-13 冰冻免疫 + chill/freeze 精确语义**~~（冰冻维度批次已落地，2026-10-09，与植物侧 Snow Pea/Winter Melon/Ice-shroom 双侧联动）。
- ~~**Z-11 冰道 + Z-14 Bobsled**~~（冰道批次已落地，2026-10-01；G-29 坑洞生产路径同步落地）。
- ~~**Z-05 Yeti 礼物**~~（Batch J 已落地 spawn 侧）；钻石计价与经济消费面仍与 G-24 同族。
- **Z-35 Boss / Z-36 Zombotany**：独立模式线。
- ~~**Z-34 original pool**~~（Batch L 已落地，2026-10-01；生存衰减曲线已核证待生存模式立项实施）。

---

## 推荐下一批

1. ~~**Batch K（精度收尾）**：Z-18 撑杆距离公式、Z-21 小丑按行走距离引爆~~（已落地，2026-10-01）。
2. ~~**Z-33 Screen Door 方向性**~~（Batch L 已落地，2026-10-01）。
3. ~~**Z-34 original pool**~~（Batch L 已落地，2026-10-01；生存衰减曲线等生存模式立项）。
4. ~~**Z-11/Z-14/G-29**~~（冰道批次已落地，2026-10-01）。

---

## 维护规则

- 新缺口只在现有 Mechanic family 无法表达原版行为时登记；表现动画、音效、原版概率精确值默认归"精确度/表现后置"。
- 关闭缺口需同步：archetype/mechanic 资源、`tools/validation_scenarios.json`、`tools/formal_content_validation_map.json`（僵尸批次分组）、本表状态。
- 与植物侧缺口互为对拍的项（Z-19/G-28、Z-24/G-23、Z-31/G-15、Z-11/G-29、Z-05/G-24）关闭时应双侧联动验证，避免单侧声称完成。
- 数值结论以 `references/de-pvz`（pin 版本）为准；PVZ-Godot-Dream 仅作 Godot 表达参考。
