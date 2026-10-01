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
> 更新（2026-10-01，Batch L）：Z-33（投射物命中打方向标记：`_launch_direction.x < 0` → hit.rear、`_move_mode == parabola` → hit.overhead，事件与直伤 tags 双路；HealthLayerDef 新增 `bypass_on_damage_tags`，`_build_damage_route` 按伤害 tags 跳层；screen_door 与 ladder 两层声明 bypass；damage 效果 attack_tags 并入伤害 tags）、Z-34（`data/combat/waves/pool_original_adventure.tres`：24 条目按 gZombieDefs 三元组落位，value→power、startingLevel−1→first_allowed_wave、pickWeight→weight，水生三系挂 spawn.medium.water zone 门，flag 条目 weight 0；衰减公式已核证并记录，实施等生存模式旗帜计数器立项）。探针 `zombie_original_screen_door_directional`（正面吃盾/背面与越顶直击本体/Split Pea 后向头实战路径）+ `zombie_original_wave_pool`（三元组 spot-check/zone 门/种子编译预算与解锁曲线）。附注：melon 溅射走 on_hit 效果链不带方向标记（原版溅射为盾体双伤 DAMAGE_HITS_SHIELD_AND_BODY，本引擎仍单发路由）；backup_dancer 不入池（原版召唤专用）；redeye 仅生存模式出现（入池与否等生存模式立项再定）。

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
| Z-03 | Digger 出土触发条件 | 部分覆盖 | Digger | 原版挖到最左端 `mPosX < 10.0f` 触发出土（`Zombie.cpp:2678-2679`），出土先 STUNNED 再步行；当前为固定 3 秒定时。可先用 x 阈值条件近似，精确语义见开放问题 |
| Z-04 | Yeti 逃跑触发 | 已覆盖（2026-09-28） | Yeti | flee state 已改 `trigger: "time"`（`after: 15.0`，对应原版 1500-2000 ticks 下界），探针推 1510 tick 断言无伤逃跑 |
| Z-05 | Yeti 死亡掉礼物 | 已覆盖（2026-09-29） | Yeti | on_death trigger + 4×produce_sun（新增 `x_offset` 参数，-20/-30/-40/-50 对应原版 aCenterX 偏移），source_type `yeti_diamond`、value 50；钻石计价待 G-24 经济轮核定（现为 coin 同价名义值）；原版 award 门控（mDroppedLoot/HasLevelAwardDropped）无对应系统未表达，探针 `zombie_original_yeti_gift` |
| Z-06 | Yeti 稀有生成权重 | 后置（wave 层） | Yeti | `gZombieDefs[]` weight=1、startingLevel=40（`Zombie.cpp:44`）；待 Z-34 original pool 落地时一并表达 |
| Z-07 | Snorkel 接近上浮/下潜循环 | 部分覆盖 | Snorkel | 原版水中保持 submerged，接近可攻击植物上浮啃咬、吃完下潜（`Zombie.cpp:1936-1963`）；当前为 spawn 后固定 1.5 秒永久上浮。隐藏过滤验证已有，缺行为循环 |
| Z-08 | Snorkel 端点出水步行 | 部分覆盖 | Snorkel | 原版到左端 `mX <= 25` 出水转普通步行（`Zombie.cpp:1914-1919`），右端反向同理；当前 surfaced 后无端点行为 |
| Z-09 | Dolphin 落地后高速步行 | 已覆盖（2026-09-28） | Dolphin Rider | `post_landing_movement` 已改 0.9 档；探针断言落地速度 |
| Z-10 | Dolphin 入水/出水序列 | 部分覆盖 | Dolphin Rider | 原版池外步行（0.66–0.68）→ `mX>700` 入水动画 → riding → 遇植物跳（`Zombie.cpp:1762-1813`）；当前 spawn 即 leap_once，缺入水触发。表现动画后置，位置/状态语义可先补 |
| Z-11 | Zamboni 冰道生成 | 已覆盖（2026-10-01） | Zamboni | `battle_field_state` 子系统：每 (lane,kind) 单区间 [x_min,x_max] + 行级计时器（对应 mIceMinX/mIceTimer 行全局语义）；Zamboni `core.drive` `lay_ice_trail` 每步并集扩区间、3000 ticks 幂等续期；`core.walk` 与 zombie_root bite 回退两路 `get_ice_trail_speed_scale` ×0.5（vehicle 标签豁免）；超时整体消退发 field.modifier_expired；探针 `zombie_original_ice_trail`（同 lane 半速/跨 lane 对照/车辆豁免/到期消退） |
| Z-12 | Zamboni 位置驱动减速 | 已覆盖（2026-09-28） | Zamboni | `core.drive` 新增 decel_start_x/decel_end_x/decel_min_slots_per_sec 线性减速（对应原版 0.25→0.05、x 700→300），探针断言参数 |
| Z-13 | Zamboni/Bobsled 冰冻免疫 | 未覆盖 | Zamboni, Bobsled | `CanBeChilled()` 直接排除（`Zombie.cpp:7979-7981`）；status/element immunity 维度缺 |
| Z-14 | Bobsled 队伍 | 已覆盖（2026-10-01） | Bobsled | archetype_original_bobsled_team（vehicle/bobsled/team）：橇=300 血 attachment 层（route_order 10 先吸收），`core.drive` 恒速 0.625 slots/s（原版 0.6px/tick）+ `ice_renewal_ticks` 500（只刷新已有冰道计时，不扩区间，对应 max(500,mIceTimer)）+ `off_ice_damage_per_tick` 6（x+10 < 冰道 x_min 起每 tick 自磨，300 血约 0.5s 破橇）；破橇走新触发器 `core.when_layer_destroyed`（required_layer_id sled）→ 4×spawn_entity（x_offset 0/50/100/150 对应原版追随者间距）+ consume_self；解体后 archetype_original_bobsled 常规步行 0.23–0.32（冰上半速）；探针 `zombie_original_bobsled_team`（橇层结构/滑速/离冰自磨/四员解体/独立行走）。近似附注：滑行期不啃咬（原版 SLIDING 相无攻击分派）；单体血池近似（原版 4×270 独立实体，本引擎单实体 270+300 层）；BOARDING 动画相未表达 |
| Z-15 | Balloon 水面落地死亡 | 部分覆盖 | Balloon | 原版落点为 pool 行则直接 `DieWithLoot`（`Zombie.cpp:1591-1593`）；当前落地无水陆判定。flying 20 attachment 层与落地状态机已覆盖 |
| Z-16 | Pogo 弹跳高度序列 | 部分覆盖 | Pogo | 原版三段递增高跳（普通 40 → FORWARD_2 90 → FORWARD_7 170，`Zombie.cpp:1372-1414`）；当前 `hop_cycle` 单一 jump_velocity |
| Z-17 | Pogo 弹簧破坏后步行 | 未覆盖 | Pogo | 原版 Tall-nut 碰撞或 Magnet 吸簧触发 `PogoBreak` 转步行（`Zombie.cpp:1332-1360`、`:1416-1425`）；依赖 G-19 与 Z-19 |
| Z-18 | Pole Vaulter 跳跃距离公式 | 已覆盖（2026-10-01） | Pole Vaulter | leap_once 新增助跑段（`vault_trigger_tags` plant + `vault_trigger_exclude_tags` spiky + `vault_trigger_scan_range` 96px，同 lane、活体过滤、有梯格不跳改爬）与落点公式（`vault_landing_beyond_px` 70：跳速 = (起跳x−落点x)/滞空时间，滞空 = 2×jump_velocity/|gravity|）；落地切默认区间 walk（0.23–0.32）；探针 `zombie_original_vault_formula`（助跑速度区间/落点 ±14px/不啃咬/落地后区间）。近似附注：原版两段式（弧落 plantX+80、动画完成瞬移 −150）合并为单弧直达 plantX−70，净语义等价；原版 anim_jump 时长由 reanim 决定，本引擎用自弧物理时长归一 |
| Z-19 | Tall-nut 跳跃阻挡 | 已覆盖（2026-09-28） | Pole Vaulter, Dolphin, Pogo | leap_once 新增 `vault_block_tags` 标签驱动阻断 + `blocked_landing_movement`，Tall-nut 挂 `vault_blocker` 标签；连带修正僵尸空中不咬（原版跳跃中不啃）；`zombie_original_vault_block_validation` 行为级验证（阻挡咬 Tall-nut / 越过 Wall-nut） |
| Z-20 | Newspaper 狂暴速度 | 已覆盖 | Newspaper | 当前 rage 后 0.28→0.89，落在原版 0.89–0.91 区间起点；`layer_destroyed` 触发与原版 shield 摧毁一致 |
| Z-21 | Jack 引信距离语义 | 已覆盖（2026-10-01） | Jack-in-the-Box | periodically 新增距离折算引信参数（`fuse_distance_min/max` 450/750 + `early_trigger_probability` 0.05 + `early_trigger_scale` 1/3 + `fuse_speed_factor` 2 即 ZOMBIE_LIMP_SPEED_FACTOR）：fuse 秒数 = 距离采样 × 2 ÷ (实体采样速度×96)，速度读自 Z-01 同一缓存 roll；`max_trigger_count=1` 一次性爆炸 + explode/consume_self 双 payload（爆后自灭）；啃食停走不停引信（原版 mPhaseCounter 与移动无关）；探针 `zombie_original_jack_distance_fuse`（seeded roll 断言爆点时刻 ±0.35s/恰一次 consume/啃+爆伤害）。近似附注：POP 110 ticks 爆开动画窗口未表达（爆在阈值达时刻）；IsImmobilizied 全冻停摆引信未表达（本引擎冻结状态尚无停摆通道） |
| Z-22 | Jack 爆炸半径分目标 | 部分覆盖（单半径已校准 2026-09-28） | Jack-in-the-Box | 原版僵尸半径 115 / 植物半径 90（`Zombie.h:25-26`）；explode effect 协议（`allow_extra_params=false`）只支持单 `radius_slots`，已按植物面 90px≈0.94 校准；分目标双半径需 effect 协议扩展，维持部分覆盖 |
| Z-23 | Bungee 完整偷取流程 | 部分覆盖 | Bungee | 原版：整列随机选格 → 俯冲（下落 8/tick）→ 底部停 300 ticks 抓植物 → 举起飞走（`Zombie.cpp:230-247`、`:1220-1264`）；当前 on_spawned 落地伤害 + consume_self 近似，无目标选择与飞走阶段 |
| Z-24 | Bungee × Umbrella 反制 | 已覆盖（2026-09-28） | Bungee | damage effect 新增正式参数 `attack_tags`，effect 侧拦截与 projectile 路径同判据（intercept_tags 交集 + intercept_radius + 同 lane），Bungee drop damage 声明 overhead/bungee；`zombie_original_bungee_umbrella_validation` 探针驱动验证（覆盖植物零伤害 + 未覆盖植物命中 + attack.intercepted） |
| Z-25 | Ladder 持久梯子物件 | 已覆盖（2026-09-28） | Ladder | `archetype_ladder_grid_item` GridItem 全生命周期（放置/格占用/移除事件），`spawn_grid_item` 新增 `at_target_slot`（从 context 目标植物解析 lane/slot，对应 AddALadder(col,row)）；Ladder 僵尸 proximity（lane_backward+defense 标签）放梯；火清：explode 新增 `remove_grid_item_tags`，Jalapeno 行爆启用 |
| Z-26 | 梯子越墙共用 | 已覆盖（2026-09-28） | Ladder, 其他步行僵尸 | 新 movement `core.climb_once`（恒速爬升 0.83 slots/s≈原版 0.8px/tick、前移漂移 0.52≈0.5px/tick、climb_height 0.94≈90px、过顶重力下落、落地切 post_climb walk）；`core.bite` 新增 `ladder_climb` 参数（遇有梯格 defense 不咬改爬）；14 个地面步行 original 僵尸启用（Digger 按原版 :6964 排除，Snorkel/Dolphin/Pogo/Balloon/Yeti 特殊运动链排除）；行为级验证 ladder_grid 双 lane 对照 |
| Z-27 | Catapult 停位条件 | 已覆盖（2026-09-28） | Catapult | `core.walk` 新增 `stop_x` 位置保持参数（对应原版 mPosX<=650 火线），探针断言 |
| Z-28 | Catapult 弹药与弹尽步行 | 已覆盖（2026-09-29） | Catapult | 弹药计数（Batch G+H）+ 弹尽链路（Batch J）：TriggerInstance 达到 max_trigger_count 后一次性发 `trigger.exhausted` 事件（core 带 spec_id/fired_count），Catapult `core.rage` 状态机 armed→spent 监听之，set_movement 换无 stop_x 的 walk（区间 0.23–0.32）并激活啃咬控制器（出生即挂、停位线天然隔离）；探针 `zombie_original_catapult_exhaustion` |
| Z-29 | Catapult 目标选择 | 已覆盖（2026-09-29） | Catapult | detection 新增 `target_selection: leftmost`（按 x 升序取最左）、`target_exclude_tags`（spiky，对应 IsSpiky 排除 Spikeweed/Spikerock 两 archetype 新挂 `spiky` 标签）、`min_scan_range` 100px（对应 mX >= plantX+100）；探针 `zombie_original_catapult_leftmost`。近似附注：原版盲射 mPosX-300 仅发生在发射动画中段目标消失（300 ticks 窗口），本引擎 trigger/payload 同拍执行使该窗口不存在，无目标→不射击语义与原版一致；TOPPLANT_CATAPULT_ORDER 同格叠层取舍无对应（单植物/格） |
| Z-30 | Gargantuar 投掷条件与距离 | 部分覆盖 | Gargantuar, Redeye | 原版条件 `mHasObject && HP<50% && mPosX-360 > 40`（`:2208-2213`），投掷距离 `mPosX-360 - Rand(0,100)`、屋顶减 180（`:2133-2155`）；当前 `when_damaged` HP 阈值触发已近似，距离公式缺 |
| Z-31 | Gargantuar × Spikerock 反伤 | 已覆盖（2026-09-29，双侧联动） | Gargantuar, Redeye | crush 新增 `soft_target_tags`（spikerock）`soft_target_damage` 50（450 血=9 次承伤，即原版独立承伤次数）`soft_target_self_damage` 20；Zamboni/Catapult 拆分 `mechanic_original_drive_over_controller`（`ignore_target_tags` spiky，对应 SquishAllInSquare DRIVE_OVER 跳过）；植物侧 ground_damage 新增 `vehicle_damage` 1800 + `vehicle_hit_plant_damage`（Spikeweed 9999 即死/Spikerock 50），Spikeweed/Spikerock 各自独立 mechanic；砸 Spikeweed 仍走 9999 即压死（原版 else 分支）；探针 `zombie_original_gargantuar_spikerock`；G-15 状态同步见植物侧底账 |
| Z-32 | Dancer 召唤刷新 | 已覆盖（2026-09-29） | Dancing | 撤 on_spawned 一次性召唤，改为 4 个逐槽位维护 trigger：periodically（interval 1.67s ≈ 100 ticks）+ proximity 探测 `team_mode: allies`（detection 新增友军扫描）`target_tags: backup_dancer`（新标签）`lane_offset/x_offset`（±1 行/±100px，修正原 ±64）`scan_range` 64 + `require_no_target`（槽空才触发）；槽位 lane 越界由 trigger 侧 `is_valid_lane` 守卫短路（对应原版无效行 no-op）。近似附注：空缺按位置而非身份判定，相邻双舞王极端场景可能互相补位；mHasHead 门控未表达；探针 `zombie_original_dancer_resummon` |
| Z-33 | Screen Door 方向性挡弹 | 已覆盖（2026-10-01） | Screen Door, Ladder | projectile_root `_on_hit` 按运动打方向标记（左飞 `hit.rear` 对应 MOTION_BACKWARDS/星形 mVelX<0、抛物 `hit.overhead` 对应 MOTION_LOBBED，de-pvz Projectile.cpp:382-404），事件与直伤 tags 双路；HealthLayerDef 新增 `bypass_on_damage_tags`，`_build_damage_route(policy, tags)` 命中即跳层直击本体；screen_door（1100 shield）与 ladder（500 attachment）两层声明 bypass；damage 效果声明 attack_tags 并入伤害 tags（探针可注入标记）；探针 `zombie_original_screen_door_directional`（正面/背面/越顶三路效果级 + Split Pea 后向头实战）。近似附注：melon 溅射走 on_hit 效果链不带方向标记，且原版溅射为盾体双伤（DAMAGE_HITS_SHIELD_AND_BODY），本引擎单发路由维持近似 |
| Z-34 | Original 正式波次 pool | 已覆盖（2026-10-01，数据层） | 全部 | `data/combat/waves/pool_original_adventure.tres` 24 条目：value→power、startingLevel−1→first_allowed_wave（原版门槛 waveIndex+1 ≥ startingLevel 的 0 基换算）、pickWeight→weight；snorkel/dolphin/ducky_tube 挂 `spawn.medium.water` required_spawn_tags（对应 IsZombieTypePoolOnly 水池限定）；flag 条目 weight 0 留作 flag_entry；探针 `zombie_original_wave_pool`（三元组 spot-check + 种子编译预算/解锁曲线断言）。衰减公式已核证（Board.cpp:2478-2519：生存 endless 首现波前移 18→50 旗帜 0→15；normal/cone 权重衰减至 1/10、1/4；伽刚/雪橇出怪上限曲线；红眼旗帜波与累计上限曲线+非旗波权重 1000；Bungee endless 限旗帜波）——依赖旗帜计数器，随生存模式立项实施。backup_dancer 不入池（召唤专用），redeye/imp 照表入池 |
| Z-35 | Dr. Zomboss | 后置（P2） | Boss | 需独立 Boss mode（踩踏/投车/火冰球/召唤/bungee 协同），已裁决不进普通 roster |
| Z-36 | Zombotany ×6 | 后置（P2） | 6 种植物头 | Pea/Wallnut/Jalapeno/Gatling/Squash/Tallnut Head，power 1–4；作为 mode/content pack 专项，复用植物 mechanic 挂 zombie 载体 |

---

## 当前未完成项分层

### A. 无新协议即可修的精度偏差

> Batch F（2026-09-28）消化 Z-02/Z-04/Z-09/Z-22；Batch G+H 消化 Z-12/Z-19/Z-24/Z-27；Batch J（2026-09-29）消化 Z-01/Z-05/Z-28 尾/Z-29/Z-31/Z-32。A 层已清零，剩余精度项见各行"近似附注"（Z-27 停位无目标不放行、Z-29 盲射窗口、Z-32 身份判定等）。

### B. 需要最小协议/能力设计的交互

- **Z-19 Tall-nut 阻挡**：与植物侧 G-28 合并对拍，内容驱动即可，不一定新协议。
- **Z-24 Bungee × Umbrella**：双侧能力已有，补交互矩阵验证即可。
- **Z-25/Z-26 Ladder 持久物件**：复用 GridItem 第一片（crater）模式扩展。
- **Z-27/Z-28 Catapult 停位与弹药**：停位条件（x 阈值 + 目标存在）可能需要 trigger 条件扩展，弹药计数可用 runtime params 近似。
- **Z-30 Gargantuar 投掷距离**：spawn_entity payload 加落点公式参数。
- ~~**Z-33 Screen Door 方向性**~~（Batch L 已落地：命中方向标记 + 层级 bypass_on_damage_tags，非 HitPolicy 扩展路线）。

### C. 明确后置基础设施

- ~~**Z-01 速度区间**~~（Batch J 已落地）；~~**Z-18 撑杆距离公式 / Z-21 小丑按距离引爆**~~（Batch K 已落地，2026-10-01）。
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
