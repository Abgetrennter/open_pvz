# P0 原版植物阻塞项执行计划（Garlic / Umbrella Leaf / Imitater）

- 日期：2026-07-29
- 状态：当前执行
- 来源草案：`plans/draft/原版机制未实现项盘点.md`（2026-05-29）P0-1 / P0-2 / P0-3 三项
- 关联文档：
  - `wiki/04-roadmap-reference/46-参考项目语义索引.md`
  - `wiki/02-runtime-protocol/03-触发器系统.md` / `04-效果系统.md` / `17-实体活跃性与空间查询.md`
  - `plans/original-plant-migration-ledger.md`
  - `plans/original-plant-protocol-gaps.md`
  - `tools/formal_content_validation_map.json`（`original_plants_batch_e` / `original_plants_protocol_gaps`）

> 本计划把原版植物 49/49 的最后三个阻塞项拆成可执行任务片。只做本计划范围内的协议入口与最小机制闭环，不做表现层完整度，不做选卡 UI 大改。

---

## 一、状态与事实基线

### 草案结论（已核实仍然成立）

- 无 `archetype_original_garlic` / `archetype_original_umbrellaleaf`，无 `card_original_imitater`；`data/combat/archetypes/plants/` 与 `data/combat/cards/` 下均无对应资源。
- 无 lane reroute effect、无攻击拦截协议、无 card clone 协议。
- `tools/formal_content_validation_map.json` 中 `original_plants_batch_e` 明确记录 "Remaining work is Garlic, Umbrella Leaf, Imitater"。

### 当前代码基线（2026-07 已调查确认）

| 事实 | 位置 | 对本计划的意义 |
|------|------|----------------|
| 新增 effect 只需两处：`_register_builtin_defs`（EffectDef + param_defs）与 `_register_builtin_strategies`（策略 lambda） | `autoload/EffectRegistry.gd` | `lane_reroute` 落点明确，16 个内置 effect 已有成熟模板 |
| `entity.damaged` 事件 core 携带 `source_node` / `target_node` / `value` / `tags`；ZombieRoot 啃咬走 `take_damage(amount, self, ["bite"])` | `scripts/components/health_component.gd`、`scripts/entities/zombie_root.gd` | 区分"啃咬 vs 普通伤害"的 damage tag 已存在，无需新增攻击侧改动 |
| `when_damaged` 触发器支持 `min_damage` / `max_health_fraction_at_or_below` / `once_key`，**不支持按 damage tags 过滤** | `autoload/TriggerRegistry.gd` | Garlic"仅被啃咬触发"需要给 `when_damaged` 增加 tag 过滤参数 |
| `BaseEntity.lane_id` + `assign_lane(new_lane_id)` 已存在，但不同步世界坐标 y，也不发事件 | `scripts/entities/base_entity.gd` | 换道入口现成；需补 `BattlefieldMetrics.get_lane_y` 坐标同步与 `entity.lane_changed` 事件 |
| `SpatialIndex` 每 tick rebuild，lane 变更下一 tick 自动生效 | `scripts/battle/spatial_index.gd` | 换道无需手动刷新空间索引 |
| effect `target_mode` 已支持 `event_source` | `autoload/EffectRegistry.gd:_resolve_target` | `lane_reroute` 以 `event_source`（啃咬者）为目标，零协议新增 |
| `CardDef` 仅 6 字段（card_id / display_name / archetype_id / sun_cost / cooldown_seconds / placement_tags）；`BattleCardState` 有 `play_card` 全流程与 `enqueue_card(card_def, reason)`，冷却按 card_id 独立 | `scripts/battle/card_def.gd`、`scripts/battle/battle_card_state.gd` | Imitater clone 卡可作为独立 card instance 进入手牌，冷却天然独立 |
| 确定性随机链：`battle_seed → derive_entity_seed → derive_mechanic_seed → ShuffleBag` | `autoload/GameState.gd`、`scripts/core/runtime/shuffle_bag.gd` | Garlic 换道方向若含随机成分必须走此链 |

### 参考项目锚点（已核实存在）

| 项 | 原版规格锚点（de-pvz） | Godot 参考（PVZ-Godot-Dream） |
|----|------------------------|-------------------------------|
| Garlic | `Lawn/Plant.cpp:AnimateGarlic()`（仅动画）；实际换道逻辑在 `Lawn/Zombie.cpp:Zombie::ZombieEatPlant()`；数值取 `gPlantDefs[]` | `scripts/character/zombie/zombie_000_base.gd:update_lane_on_eat_garlic()` / `update_lane()`（收集相邻 lane → 随机取一 → 禁攻击 → 位移 → 恢复） |
| Umbrella Leaf | `Lawn/Plant.cpp:UpdateUmbrella()`（STATE_UMBRELLA_TRIGGERED → REFLECTING 状态机）、Bungee `mHitUmbrella` 流程 | `scripts/character/plant/plant_038_umbrella_leaf.gd`（Area2D 检测 Bungee 进入触发 `be_umbrella_leaf()`） |
| Imitater | `Lawn/Plant.cpp:ImitaterMorph()`（Die() 后同格 AddPlant）、`Plant::GetCost()` / `GetRefreshTime()`（clone 卡费用/冷却语义） | `scripts/ui/card/card_imitater.gd`（仅选卡 UI 逻辑，不移植） |

按 wiki 46 约定：de-pvz 提供数值与行为规格；PVZ-Godot-Dream 仅观察拆法；所有数值在任务内回 `gPlantDefs[]` 确认，不从记忆取值。

---

## 二、目标

1. Garlic：被啃咬后使啃咬者换到相邻 lane，行为确定性、边界 lane 不越界、空间索引与坐标正确同步。
2. Umbrella Leaf：拦截防护范围内的特定标签攻击（bungee / catapult / overhead 类），有显式"攻击被拦截"事件语义。
3. Imitater：card 层 clone 协议——clone 卡作为独立 card instance 进入手牌，冷却独立，放置后生成目标 archetype 并携带 imitater metadata。
4. 三项各配专项验证场景并进入 manifest，`original_plants_batch_e` 达到 14/14。

## 三、非目标

- 不新增 Mechanic family；不修改冻结协议语义（只在现有 family / registry 下新增 type、effect、参数）。
- 不为任一实体在 `BattleManager` 加特判。
- 不做 Imitater 选卡 UI / washed-out 视觉滤镜；clone target 本阶段由 scenario/卡组配置预先指定，选卡阶段交互后置。
- 不实现 Bungee Zombie 偷植物完整流程（Umbrella 反制以攻击标签验证，Bungee 完整流程属草案第三批）。
- 不做 Garlic 被啃后的形变/表情表现精度；视觉走现有 VisualProfile 占位。
- 不在本计划内处理 P1（Doom crater / Cob Cannon / coin taxonomy）。

---

## 四、任务清单

### Phase A：Garlic 换道（Effect.lane_reroute）

对草案开放问题 #1 的决策：**采用通用 `Effect.lane_reroute`**（草案倾向），不做 battle rule module；未来其他"强制路径改变"机制可复用。

| 任务 | 内容 | 触及文件 | 验收标准 |
|------|------|----------|----------|
| A1 | `when_damaged` 触发器新增 `required_damage_tags: PackedStringArray` 参数（空 = 不过滤；非空 = 事件 tags 必须全部命中） | `autoload/TriggerRegistry.gd`（param_defs + 策略判断） | 带 `["bite"]` 过滤的触发器只对啃咬伤害激活；参数进 ProtocolValidator 校验 |
| A2 | 新增 `Effect.lane_reroute`：target 解析（默认 `event_source`）→ 计算目标 lane（`direction_policy`: `random` / `prefer_up` / `prefer_down`，边界 lane 自动 fallback 到唯一可行方向）→ 调 `assign_lane` → 同步 `BattlefieldMetrics.get_lane_y` 世界坐标 → 发 `entity.lane_changed` 事件（core: entity / from_lane / to_lane / reason） | `autoload/EffectRegistry.gd`、`scripts/entities/base_entity.gd`（或 effect 内坐标同步） | random 策略走 battle_seed 派生链，同 seed 结果可复现；单 lane 棋盘不换道且不报错；下一 tick SpatialIndex 查询按新 lane 返回 |
| A3 | 新增 `archetype_original_garlic` + `card_original_garlic`：Chassis 血量、费用、冷却回 `de-pvz gPlantDefs[]` 确认；Mechanic 组合 = `Trigger.when_damaged(required_damage_tags=["bite"])` + Payload `lane_reroute` | `data/combat/archetypes/plants/`、`data/combat/cards/plants/` | 遵循 Identity → Chassis → Combat Stats → Mechanic[] 编写顺序；数值来源在资源注释中标注锚点 |
| A4 | 验证场景 `plant_original_garlic_validation` + manifest 登记 | `scenes/validation/`、`tools/validation_scenarios.json` | 见验证矩阵；全批验证无回归 |

### Phase B：Umbrella Leaf 攻击防护

对草案开放问题 #2 的决策：**先做 B1 spike 收敛协议**，因为"攻击被拦截"是新事件语义，且拦截点在现有攻击链上的挂接位置（effect 执行前 vs 事件后补偿）需要一次小规模设计确认，不在计划里赌方向。

| 任务 | 内容 | 触及文件 | 验收标准 |
|------|------|----------|----------|
| B1 (spike) | 攻击拦截协议设计：① 攻击标签（`overhead` / `bungee` / `catapult`）在现有攻击产生点（effect params / projectile template tags / controller）如何携带；② 拦截语义是"effect 执行前查询守护者并取消"还是"事件驱动补偿"；③ 防护范围表达（推荐 `SpatialIndex.spatial_query` 半径 ≈ 3x3 slot 邻域，最终以 spike 结论为准）；④ 多 Umbrella 覆盖同一目标的去重规则（建议最近者响应，其余不发事件）。产出 ≤1 页决策记录追加到本计划附录 | 只读调查 + 本文件附录 | 决策记录覆盖上述 4 点，明确 `attack.intercepted` 事件 core 字段 |
| B2 | 按 B1 结论实现防护能力（`Controller.core.protect_targets` 或 `Effect.intercept_attack` 二选一）：匹配攻击标签而非实体类名；拦截时发 `attack.intercepted`（core: protector / attacker / protected_target / attack_tags）；被拦截攻击不产生伤害 | `autoload/ControllerRegistry.gd` 或 `autoload/EffectRegistry.gd` + 相关攻击产生点补 tags | 带 `overhead` 类标签的攻击在防护范围内被取消；bite 与普通投射物不受影响 |
| B3 | 新增 `archetype_original_umbrellaleaf` + `card_original_umbrellaleaf`，数值回 `gPlantDefs[]` 确认 | `data/combat/archetypes/plants/`、`data/combat/cards/plants/` | 同 A3 标准 |
| B4 | 验证场景 `plant_original_umbrellaleaf_validation` + manifest 登记；攻击源使用已实现的 Catapult Zombie 弹道攻击（补 `catapult`/`overhead` tag）或最小合成攻击场景 | `scenes/validation/`、`tools/validation_scenarios.json` | 见验证矩阵 |

### Phase C：Imitater 卡片复制协议

对草案开放问题 #3 的决策：**clone 卡为独立 card instance、独立 card_id**（如 `card_original_imitater__<target_card_id>`），保留 target metadata（草案倾向）。cost / cooldown 语义回 `de-pvz Plant::GetCost() / GetRefreshTime()` 在 C1 内确认后定案。

| 任务 | 内容 | 触及文件 | 验收标准 |
|------|------|----------|----------|
| C1 (spike) | clone 协议定案：① `CardDef` 扩展字段（建议 `clone_source_card_id: StringName` + `clone_metadata: Dictionary`，保持向后兼容默认空）；② clone 卡 cost/cooldown 取值规则（回 de-pvz 确认后写死规则，不留运行时分支）；③ clone 解析时机（战斗初始化时由卡组配置展开，走 `enqueue_card`）。产出 ≤1 页决策记录追加到本计划附录 | 只读调查 + 本文件附录 | 决策记录覆盖 3 点，明确 `card.clone_resolved` 事件 core 字段 |
| C2 | 实现 clone 解析：`BattleCardState` 战斗初始化阶段将 clone 卡展开为独立 card instance（独立冷却槽），发 `card.clone_resolved`（core: clone_card_id / source_card_id / target_archetype_id）；clone target 无效/为空时拒绝并记录 `protocol.issue` | `scripts/battle/card_def.gd`、`scripts/battle/battle_card_state.gd` | 原卡与 clone 卡同时在手牌；`play_card` 对 clone 卡走完整放置流程；冷却互不影响 |
| C3 | 新增 `card_original_imitater` 资源（clone_source 指向目标卡，scenario 配置示例指向豌豆射手卡）；放置生成目标 archetype 时在实体 metadata 中标记 imitater 来源 | `data/combat/cards/plants/` | 放置产物是目标 archetype 实体（非独立 imitater 实体）；metadata 可被验证断言读取 |
| C4 | 验证场景 `plant_original_imitater_validation` + manifest 登记 | `scenes/validation/`、`tools/validation_scenarios.json` | 见验证矩阵 |

### 收尾任务

| 任务 | 内容 | 触及文件 |
|------|------|----------|
| D1 | `tools/formal_content_validation_map.json` 更新：`original_plants_batch_e` 移除 "Remaining work" 表述并计入 3 个新场景；`original_plants_protocol_gaps` 对应缺口标记关闭 | `tools/formal_content_validation_map.json` |
| D2 | 文档同步：`plans/original-plant-migration-ledger.md`（49/49）、`plans/original-plant-protocol-gaps.md`（G 项关闭）、`wiki/01-overview/23-当前阶段与实现路线.md` 状态快照、`wiki/02-runtime-protocol/04-效果系统.md`（lane_reroute / 拦截事件） | 对应文档 |
| D3 | 全量回归：`pwsh tools/run_all_validations.ps1 -MaxParallel 8`，基线 222 场景全过 + 新增 3 场景通过 | — |

---

## 五、依赖顺序

```
A1 ─┬─→ A3 ─→ A4 ─┐
A2 ─┘             │
B1 ─→ B2 ─→ B3 ─→ B4 ─┼─→ D1 ─→ D2 ─→ D3
C1 ─→ C2 ─→ C3 ─→ C4 ─┘
```

- A1 与 A2 可并行；A3 依赖两者。
- Phase A / B / C 相互独立，可并行推进；推荐顺序 A → B → C（A 协议增量最小，先落地建立模板；B、C 各含一个 spike）。
- D1–D3 在三条线全部收敛后执行。

## 六、验证矩阵

| 场景 id | 层 | 正向断言 | 负向断言 |
|---------|----|----------|----------|
| `plant_original_garlic_validation` | core | 僵尸啃咬 Garlic 后 `entity.lane_changed`（from ≠ to）；换道后该僵尸在新 lane 被 SpatialIndex 查询命中；同 battle_seed 重跑结果一致 | 非 bite 伤害（如投射物打 Garlic）不触发换道；边界 lane 僵尸只向唯一可行方向换道，不越界 |
| `plant_original_umbrellaleaf_validation` | core | 带 overhead 类标签的攻击命中防护范围内目标前发 `attack.intercepted`，且目标无对应 `entity.damaged` | 普通 bite / 直射投射物正常造成伤害；防护范围外同类攻击不被拦截 |
| `plant_original_imitater_validation` | core | 战斗开始发 `card.clone_resolved`；原卡与 clone 卡各自 `placement.accepted`；两卡冷却时间线独立（先后打出各自进入冷却） | clone_source 为空/无效时拒绝并出 `protocol.issue`，不进手牌；clone 卡打出不影响原卡冷却 |

单场景命令：

```powershell
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/plant_original_garlic_validation.tres"
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/plant_original_umbrellaleaf_validation.tres"
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/plant_original_imitater_validation.tres"
```

A1（trigger 参数）与 C2（card 协议）若引入新参数校验路径，视需要补 1 个 guardrail 编译验证（沿用现有 `*_compile_validation` 模式），在实施时按 A1/C2 实际改动量裁定。

## 七、DoD（完成定义）

1. 三个新验证场景通过，且 `run_all_validations.ps1` 全批（222 + 3）无回归。
2. 无任何 `BattleManager` 实体特判；新能力全部落在 EffectRegistry / TriggerRegistry / ControllerRegistry / CardState 边界内。
3. 所有随机行为（Garlic random 方向）走 battle_seed 派生链，验证场景含确定性断言。
4. 未注册/覆盖 `core.*` 之外命名空间冲突；未新增 Mechanic family。
5. 新资源数值均标注 de-pvz 锚点来源；无凭记忆填写的原版数值。
6. B1 / C1 spike 决策记录已追加到本计划附录。
7. D1 / D2 文档与 manifest 同步完成，`original_plants_batch_e` 为 14/14。

## 八、归档与更新规则

- 本计划登记于 `plans/README.md`"当前执行/维护"分区；状态变更同步该文件。
- B1 / C1 spike 结论以附录形式追加在本文件末尾，不另开文档。
- 全部 DoD 达成后：本计划移入 `plans/archive/`（建议 `plans/archive/p0-original-plant-blockers-2026-07/`）；来源草案 `plans/draft/原版机制未实现项盘点.md` 的 P0 章节标注"已拆分执行并完成"，草案其余部分（P1–P3）保留待后续拆分。
- 若实施中推翻本计划的默认决策（如 lane_reroute 改走 rule module），须先更新本计划相应章节再动代码。

---

## 附录：spike 决策记录（实施时追加）

### B1 攻击拦截协议决策（2026-07-29 定案）

1. **攻击标签携带点**：走 `ProjectileTemplate.tags`。`EntityFactory._apply_projectile_template_metadata` 已把模板 tags 写入 projectile 实例 `entity_state`（key `projectile_template_tags`），拦截判定直接读实例状态，无需扩展 launch 链。`basketball_arc.tres` 补 `overhead` / `catapult` 两个 tag 作为首个攻击源。
2. **拦截语义**：命中确认前取消（"弹开"语义）。hook 在 `projectile_root.gd::_on_hit` 的 team 校验之后、`projectile.hit` 事件与 on_hit_effect / 直接伤害之前：拦截成立时不发 `projectile.hit`、不产生任何伤害，投射物按非 pierce 路径消耗（status=intercepted + queue_free），改发 `attack.intercepted`。
3. **防护者声明与查询**：实现载体选 `Controller.core.protect_targets`（计划 B2 二选一中的 Controller 方案）。策略每帧把 `intercept_tags` / `intercept_radius`（`protect_radius_slots` 经 BattlefieldMetrics 解析，默认 1.6 slot ≈ 3x3 邻域）写入守护者 `entity_state`；命中时投射物经 `BattleManager.spatial_query`（team=目标同队、center=目标地面位置、radius=查询上限 400px）筛出带 `intercept_tags` 状态的候选，再逐个校验 ①`is_liveness_enabled("controllers")`（睡眠/失效自动失去防护）②距离 ≤ 该守护者自身 `intercept_radius` ③投射物 `projectile_template_tags` ∩ 守护者 `intercept_tags` 非空。匹配纯标签驱动，无实体特判。
4. **多守护者去重**：候选中取距被保护目标最近者响应（距离平手取 entity_id 较小者），仅该守护者发 1 次 `attack.intercepted`，其余不发事件。

`attack.intercepted` 事件（source=守护者，target=被保护目标）core 字段：`protector_id`、`protector_archetype_id`、`attacker_id`、`attacker_archetype_id`、`protected_target_id`、`protected_target_archetype_id`、`attack_tags`（=projectile template tags）、`projectile_template_id`、`lane_id`（被保护目标所在 lane）。

**B4 实施补记（2026-07-29）**：首轮验证暴露 `archetype_original_catapult` 存量数据缺陷——其篮球模板仅经 payload params 传入，archetype 级 `projectile_template` / `projectile_flight_profile` 字段为空，导致编译链无法从 flight profile 派生 `movement_mode`，`ProtocolValidator.normalize_effect_node` 填入 EffectDef 默认值 `linear` 覆盖了模板的 parabola（篮球直线飞行不命中）。按 `archetype_original_cabbagepult` 既有约定在 catapult archetype 上补齐两字段（纯数据修复，未改代码）。另：3 车道验证场景行距 60px 小于拦截半径 153.6px，跨行防护符合原版 3x3 语义，负例车道的植物需放置在拦截半径之外（lane1 蒜移至 x=448）。
### C1 card clone 协议决策（2026-07-29 定案）

1. **CardDef 扩展字段**：新增 `clone_source_card_id: StringName`（默认空）与 `clone_metadata: Dictionary`（默认空），全部向后兼容。判定规则：`clone_source_card_id` 非空即为 clone 配置卡。`ProtocolValidator._validate_card_def` 对 clone 配置卡豁免 archetype_id 必填检查（archetype 从源卡展开时解析），其余字段校验不变。
2. **cost / cooldown 取值规则**：写死为“完全取目标卡”。锚点：de-pvz `Plant::GetCost()`（Plant.cpp L5070-5073）与 `Plant::GetRefreshTime()`（L5118-5121）对 `SEED_IMITATER` 均直接返回 `theImitaterType` 的 `mSeedCost` / `mRefreshTime`，无任何 Imitater 自身加成；Imitater 定义行（L73：cost=0, refresh=750cs）仅为选卡占位，不参与运行时。实现上 clone instance 由**源卡 `duplicate()`** 生成后覆写身份字段，天然继承 archetype_id / sun_cost / cooldown_seconds / placement_tags，无运行时分支。
3. **clone 解析时机**：`BattleCardState.setup()` 读完 `scenario.card_defs` 后统一展开（保证源卡已注册，与声明顺序无关）。clone 配置卡本身不进手牌；展开产物为独立 card instance，card_id = `<clone_card_id>__<source_card_id>`（如 `card_original_imitater__card_original_peashooter`），进 `_card_defs` + `hand_order`，冷却按 card_id 键控天然独立。`clone_metadata` 写入 `imitater_source_card_id` / `clone_source_card_id`，`play_card` 时 merge 进 `spawn_card_actor` 与 `emit_entity_spawned` 的 metadata，使 `entity.spawned` core 可被验证断言读取。失败路径：clone_source 指向的源卡不存在 → 不进手牌，经 `battle.report_protocol_issues(scope="card_clone")` 发 `protocol.issue`；`card_play_requests` 引用未展开的 id 走既有 `card.play_rejected(reason=unknown_card)`。

`card.clone_resolved` 事件（战斗初始化时每张展开成功的 clone 卡发 1 次，tags `["card","clone"]`）core 字段：`clone_card_id`（展开后独立 id）、`source_card_id`（目标卡 id）、`target_archetype_id`（源卡 archetype_id）。
