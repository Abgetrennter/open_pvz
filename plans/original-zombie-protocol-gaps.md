# 原版僵尸协议缺口清单

- 状态：当前事实
- 关联文件：`plans/zombie-design-research-report.md`
- 创建日期：2026-09-28
- 最后更新：2026-09-28

> 本文档记录原版僵尸移植过程中仍然影响"原版语义完成度"的协议缺口，口径与 `plans/original-plant-protocol-gaps.md` 对齐。数值与行为条件以 `references/de-pvz/Lawn/Zombie.cpp`、`Zombie.h` 实测为准；本文所有锚点均在 2026-09-28 逐条回源码核证。
>
> 更新（2026-09-28，Batch F）：Z-02（Digger 出土方向）、Z-04（Yeti 逃跑触发，计时器化）、Z-09（Dolphin 落地速度）、Z-22（Jack 爆炸半径）已修正并加深探针断言；连带修复 zombie_root 中央步进下 State 时间转换不执行的链路缺口，yeti/batch_d 验证窗口提到 18s。Z-32（Dancer 重召）经探测需“成员存活检测”，当前 Detection 只扫敌军，无协议变更无法表达，维持部分覆盖。

---

## 当前结论

- 原版 `ConstEnums.h:ZombieType` 共 33 种（不含 2 个缓存变体）；OpenPVZ 已落地 26 个 `archetype_original_*`（冒险 24 + Redeye Gargantuar + Backup Dancer），批次 A-E 验证与正式映射均已登记。
- 数量缺口 7 个：Bobsled、Dr. Zomboss、Zombotany ×6，均为已裁决的 P2 独立系统（见机制盘点草案），不阻塞主线。
- **本轮源码比对发现两处与原版方向相反/不同的行为语义**（Z-02 Digger 出土方向、Z-04 Yeti 逃跑触发），属于无新协议即可修的精度偏差，建议最先处理。
- 大部分已有僵尸的验证停留在结构断言（mechanic/layer 存在），行为精度缺口集中在：状态触发条件（计时器 vs 事件）、端点行为（入水/出水/停位）、持续交互（冰道、梯子、召唤刷新）。
- 波次层 `WavePoolEntryDef` 的 `power / weight / first_allowed_wave` 已能承载 `gZombieDefs[]` 三元组，缺的是按原版解锁曲线组织的 original 正式 pool，不是协议。

---

## 缺口总览

> 状态口径：**已覆盖** = 资源与验证足以表达原版最小语义；**部分覆盖** = 资源存在但行为与原版有可证差异或缺口；**后置** = 已裁决等待外部依赖或独立设计。

| ID | 名称 | 当前状态 | 关联僵尸 | 当前判断 |
|----|------|----------|----------|----------|
| Z-01 | 速度区间随机采样 | 部分覆盖 | 几乎全部 | `PickRandomSpeed()`（`Zombie.cpp:1096`）按类型从区间采样（如普通 0.23–0.32）；当前 archetype 一律固定值（0.28）。确定性随机设施已有，缺 Movement params 的区间表达；v1 固定中值可接受，登记为精度项 |
| Z-02 | Digger 出土方向 | 已覆盖（2026-09-28） | Digger | surface state side-effect 已改向右回头（+1,0），探针断言 `surfaced` 转换的方向 |
| Z-03 | Digger 出土触发条件 | 部分覆盖 | Digger | 原版挖到最左端 `mPosX < 10.0f` 触发出土（`Zombie.cpp:2678-2679`），出土先 STUNNED 再步行；当前为固定 3 秒定时。可先用 x 阈值条件近似，精确语义见开放问题 |
| Z-04 | Yeti 逃跑触发 | 已覆盖（2026-09-28） | Yeti | flee state 已改 `trigger: "time"`（`after: 15.0`，对应原版 1500-2000 ticks 下界），探针推 1510 tick 断言无伤逃跑 |
| Z-05 | Yeti 死亡掉礼物 | 未覆盖 | Yeti | 原版 `mHasObject` 为 true 时死亡掉 4 个礼物（`Zombie.cpp:5004` IsWalkingBackwards 返回 mHasObject 佐证携带物语义）；需要 collectible/economy 配合，与植物侧 G-24 金币经济同族后置 |
| Z-06 | Yeti 稀有生成权重 | 后置（wave 层） | Yeti | `gZombieDefs[]` weight=1、startingLevel=40（`Zombie.cpp:44`）；待 Z-34 original pool 落地时一并表达 |
| Z-07 | Snorkel 接近上浮/下潜循环 | 部分覆盖 | Snorkel | 原版水中保持 submerged，接近可攻击植物上浮啃咬、吃完下潜（`Zombie.cpp:1936-1963`）；当前为 spawn 后固定 1.5 秒永久上浮。隐藏过滤验证已有，缺行为循环 |
| Z-08 | Snorkel 端点出水步行 | 部分覆盖 | Snorkel | 原版到左端 `mX <= 25` 出水转普通步行（`Zombie.cpp:1914-1919`），右端反向同理；当前 surfaced 后无端点行为 |
| Z-09 | Dolphin 落地后高速步行 | 已覆盖（2026-09-28） | Dolphin Rider | `post_landing_movement` 已改 0.9 档；探针断言落地速度 |
| Z-10 | Dolphin 入水/出水序列 | 部分覆盖 | Dolphin Rider | 原版池外步行（0.66–0.68）→ `mX>700` 入水动画 → riding → 遇植物跳（`Zombie.cpp:1762-1813`）；当前 spawn 即 leap_once，缺入水触发。表现动画后置，位置/状态语义可先补 |
| Z-11 | Zamboni 冰道生成 | 未覆盖（场地 modifier） | Zamboni | 原版行级 `mIceMinX/mIceTimer` 冰道，3000 ticks 续期（`Zombie.cpp:3908-3938`）；需 BoardSlot/field modifier，与植物侧 G-29 crater 同族，建议合并设计。Bobsled（Z-14）依赖此项 |
| Z-12 | Zamboni 位置驱动减速 | 部分覆盖 | Zamboni | 原版 `mPosX>400` 时速度从 0.25 线性降到 0.05（`UpdateZamboni :3908-3914`）；当前固定 0.25 |
| Z-13 | Zamboni/Bobsled 冰冻免疫 | 未覆盖 | Zamboni, Bobsled | `CanBeChilled()` 直接排除（`Zombie.cpp:7979-7981`）；status/element immunity 维度缺 |
| Z-14 | Bobsled 队伍 | 未覆盖（P2 后置） | Bobsled | 组实体/队列 + sled 300 血 + 冰道依赖 + 解体后 3 独立僵尸；等 Z-11 与组队语义裁决（机制盘点开放问题 6） |
| Z-15 | Balloon 水面落地死亡 | 部分覆盖 | Balloon | 原版落点为 pool 行则直接 `DieWithLoot`（`Zombie.cpp:1591-1593`）；当前落地无水陆判定。flying 20 attachment 层与落地状态机已覆盖 |
| Z-16 | Pogo 弹跳高度序列 | 部分覆盖 | Pogo | 原版三段递增高跳（普通 40 → FORWARD_2 90 → FORWARD_7 170，`Zombie.cpp:1372-1414`）；当前 `hop_cycle` 单一 jump_velocity |
| Z-17 | Pogo 弹簧破坏后步行 | 未覆盖 | Pogo | 原版 Tall-nut 碰撞或 Magnet 吸簧触发 `PogoBreak` 转步行（`Zombie.cpp:1332-1360`、`:1416-1425`）；依赖 G-19 与 Z-19 |
| Z-18 | Pole Vaulter 跳跃距离公式 | 部分覆盖 | Pole Vaulter | 原版跳跃水平速度 = (mX - plantX - 80)/动画时长，落点整体前移 150（`Zombie.cpp:1671-1686`、`:1711-1715`）；当前 leap_once 固定 jump_velocity。近似语义已有，登记精度项 |
| Z-19 | Tall-nut 跳跃阻挡 | 未覆盖（等对拍） | Pole Vaulter, Dolphin, Pogo | 原版三类跳越僵尸各自在跳跃中检测 Tall-nut 并 bonk 中断（`Zombie.cpp:1701-1708`、`:1821-1829`、`:1416-1425`）；与植物侧 G-28 互为对拍项，内容驱动 |
| Z-20 | Newspaper 狂暴速度 | 已覆盖 | Newspaper | 当前 rage 后 0.28→0.89，落在原版 0.89–0.91 区间起点；`layer_destroyed` 触发与原版 shield 摧毁一致 |
| Z-21 | Jack 引信距离语义 | 部分覆盖 | Jack-in-the-Box | 原版引信按行走距离 450+Rand(300)px 折算，1/20 概率缩为 1/3（`Zombie.cpp:430-435`）；当前为纯时间区间（start_delay 1.5–5.0 + interval 2.5–4.5）。语义差异：原版"走多远爆"，当前"多久爆"，速度区间（Z-01）落地前两者不可等价 |
| Z-22 | Jack 爆炸半径分目标 | 部分覆盖（单半径已校准 2026-09-28） | Jack-in-the-Box | 原版僵尸半径 115 / 植物半径 90（`Zombie.h:25-26`）；explode effect 协议（`allow_extra_params=false`）只支持单 `radius_slots`，已按植物面 90px≈0.94 校准；分目标双半径需 effect 协议扩展，维持部分覆盖 |
| Z-23 | Bungee 完整偷取流程 | 部分覆盖 | Bungee | 原版：整列随机选格 → 俯冲（下落 8/tick）→ 底部停 300 ticks 抓植物 → 举起飞走（`Zombie.cpp:230-247`、`:1220-1264`）；当前 on_spawned 落地伤害 + consume_self 近似，无目标选择与飞走阶段 |
| Z-24 | Bungee × Umbrella 反制 | 部分覆盖（待对拍） | Bungee | 原版落地时 `FindUmbrellaPlant` 命中即弹飞（`Zombie.cpp:1237-1250`）；植物侧 G-23 `protect_targets` 已落地，缺跨侧交互矩阵验证（interaction_matrix 双向对拍） |
| Z-25 | Ladder 持久梯子物件 | 未覆盖 | Ladder | 原版架梯生成 `GRIDITEM_LADDER`（`Board.cpp:449 AddALadder`），可被 Magnet/爆炸移除；当前 ladder 只是 500 attachment 层，无持久物件。复用 GridItem 第一片（crater）模式 |
| Z-26 | 梯子越墙共用 | 未覆盖 | Ladder, 其他步行僵尸 | 原版任意僵尸遇梯子走 `HEIGHT_UP_LADDER` 越过高墙（`Zombie.cpp:1657-1665` Pole Vaulter 分支等）；依赖 Z-25 |
| Z-27 | Catapult 停位条件 | 未覆盖 | Catapult | 原版 `mPosX <= 650 && FindCatapultTarget() && mSummonCounter > 0` 才停下开火（`Zombie.cpp:1517`）；当前 `core.periodic` 全程开火，无停位 |
| Z-28 | Catapult 弹药与弹尽步行 | 未覆盖 | Catapult | 原版 20 发（`:402`），装填 300 ticks，弹尽转普通步行啃咬（`:1546-1561`）；当前无弹药计数 |
| Z-29 | Catapult 目标选择 | 部分覆盖 | Catapult | 原版选本行最左列植物（`FindCatapultTarget :1483-1501`），无目标时盲射 mPosX-300；当前 `lane_backward + full_lane` 近似，缺"最左列"语义 |
| Z-30 | Gargantuar 投掷条件与距离 | 部分覆盖 | Gargantuar, Redeye | 原版条件 `mHasObject && HP<50% && mPosX-360 > 40`（`:2208-2213`），投掷距离 `mPosX-360 - Rand(0,100)`、屋顶减 180（`:2133-2155`）；当前 `when_damaged` HP 阈值触发已近似，距离公式缺 |
| Z-31 | Gargantuar × Spikerock 反伤 | 未覆盖 | Gargantuar, Redeye | 原版砸 Spikerock 自伤 20 且 Spikerock 有独立承伤次数（`:2049-2056`）；与植物侧 G-15 ground_damage 对拍 |
| Z-32 | Dancer 召唤刷新 | 部分覆盖 | Dancing | 原版首次入场舞步完成后召唤 4 个（row±1 同 x，本行 x±100，`SummonBackupDancers :2812-2835`），之后每 100 ticks 检查缺员即重召（`:3005-3008`）；当前 on_spawned 一次性 4 方位，缺刷新。位置与数量已对齐 |
| Z-33 | Screen Door 方向性挡弹 | 未覆盖 | Screen Door | 原版 door shield 有方向判定（`TakeShieldDamage` 路由 + directional），背面投射物直通本体；当前 `damage_layer_policy` 只有 bypass 语义，无方向维度 |
| Z-34 | Original 正式波次 pool | 未覆盖（内容层） | 全部 | `gZombieDefs[]` 的 value/startingLevel/pickWeight 三元组（`Zombie.cpp:20-53`）可直接映射 `WavePoolEntryDef.power/first_allowed_wave/weight`；协议就绪，缺 original pool 数据与衰减规则核证（衰减公式在 `Challenge.cpp`/`Board.cpp`，未逐行核证） |
| Z-35 | Dr. Zomboss | 后置（P2） | Boss | 需独立 Boss mode（踩踏/投车/火冰球/召唤/bungee 协同），已裁决不进普通 roster |
| Z-36 | Zombotany ×6 | 后置（P2） | 6 种植物头 | Pea/Wallnut/Jalapeno/Gatling/Squash/Tallnut Head，power 1–4；作为 mode/content pack 专项，复用植物 mechanic 挂 zombie 载体 |

---

## 当前未完成项分层

### A. 无新协议即可修的精度偏差（建议下一批）

> Batch F（2026-09-28）已消化 Z-02、Z-04、Z-09、Z-22（单半径校准）；剩余：

- **Z-12 Zamboni 减速**：先按两段近似（>400px 区间 0.25→0.05），或等 Z-01 区间表达一并做。
- **Z-32 Dancer 刷新**：需“成员存活检测”（原版 `NeedsMoreBackupDancers` 检查 follower 存活）；当前 Detection 只扫敌军，无协议变更无法表达，维持一次性召唤 + 底账留账。

### B. 需要最小协议/能力设计的交互

- **Z-19 Tall-nut 阻挡**：与植物侧 G-28 合并对拍，内容驱动即可，不一定新协议。
- **Z-24 Bungee × Umbrella**：双侧能力已有，补交互矩阵验证即可。
- **Z-25/Z-26 Ladder 持久物件**：复用 GridItem 第一片（crater）模式扩展。
- **Z-27/Z-28 Catapult 停位与弹药**：停位条件（x 阈值 + 目标存在）可能需要 trigger 条件扩展，弹药计数可用 runtime params 近似。
- **Z-30 Gargantuar 投掷距离**：spawn_entity payload 加落点公式参数。
- **Z-33 Screen Door 方向性**：HitPolicy/damage_layer_policy 增加方向维度，属协议扩展，需设计审批。

### C. 明确后置基础设施

- **Z-01 速度区间**：影响全部僵尸的 Movement params 表达，值得单独一轮设计（含 Z-12、Z-18、Z-21 的精确化）。
- **Z-11 冰道 + Z-14 Bobsled**：等 field modifier（与 G-29 合并设计）。
- **Z-05 Yeti 礼物 + 金币经济**：与植物侧 G-24 同族。
- **Z-35 Boss / Z-36 Zombotany**：独立模式线。
- **Z-34 original pool**：内容层，待 Z-01/Z-06 语义定形后按解锁曲线建数据。

---

## 推荐下一批

1. **Batch F（精度修正）**：Z-02、Z-04、Z-09、Z-22、Z-32 + 对应探针断言加深；全部 A 层，无协议变更。
2. **Batch G（交互对拍）**：Z-19 + Z-24（与植物侧 G-28/G-23 联合验证，入 interaction_matrix）。
3. **Batch H（Catapult/Ladder 行为）**：Z-27、Z-28、Z-29、Z-25、Z-26。
4. **设计轮**：Z-01 速度区间、Z-33 方向性、Z-11 冰道（各出一个最小设计再实施）。

---

## 维护规则

- 新缺口只在现有 Mechanic family 无法表达原版行为时登记；表现动画、音效、原版概率精确值默认归"精确度/表现后置"。
- 关闭缺口需同步：archetype/mechanic 资源、`tools/validation_scenarios.json`、`tools/formal_content_validation_map.json`（僵尸批次分组）、本表状态。
- 与植物侧缺口互为对拍的项（Z-19/G-28、Z-24/G-23、Z-31/G-15、Z-11/G-29、Z-05/G-24）关闭时应双侧联动验证，避免单侧声称完成。
- 数值结论以 `references/de-pvz`（pin 版本）为准；PVZ-Godot-Dream 仅作 Godot 表达参考。
