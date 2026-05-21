# 僵尸波次管理器 WaveRunner 设计草案

> 日期：2026-05-21
> 状态：已归档；Phase 1-4 最小切片已落地，正式事实已同步到 `wiki/02-runtime-protocol/18-波次与组波系统.md`；本文仅作为历史设计讨论记录
> 关联主题：WaveRunner、WaveDef、BattleSpawnResolver、BattleModeHost、原版僵尸迁移、正式波次模板

---

## TL;DR

WaveRunner 不应演化成“僵尸生成大脑”或原版 `Board` 式上帝类。更稳的方向是把波次系统拆成三层：

1. **波次定义层**：显式 `WaveDef[]`，用于 validation、showcase、手工调优关卡和剧情关。
2. **规则化组波层**：`WaveRecipeDef + WavePoolDef + WaveAdvancePolicy`，把原版式 power budget、权重、旗帜波、解锁规则、特殊注入编译成普通 `WaveDef[]` 或运行时 `WavePlan`。
3. **波次执行层**：`WaveRunner` 只消费已经解析好的计划，按固定 simulation tick 推进 wave state、投放 spawn entry、发事件、做基础胜败判定。

自定义能力应落在“定义/组波/模式模块”三个受控入口，而不是让 WaveRunner 执行任意脚本逻辑。

---

## 2026-05-21 落地记录

本草案已完成一个最小实现闭环，目标是验证设计边界，而不是一次性实现完整 Adventure / Survival / 特殊模式系统。

| Phase | 当前落地 |
|-------|----------|
| Phase 0 | 固定 `WaveRunner` 执行器边界：显式 `WaveDef[]` 与 `wave_recipe` 共存；WaveRunner 不执行任意脚本。 |
| Phase 1 | 新增 `WaveRecipeDef` / `WavePoolDef` / `WavePoolEntryDef` / `WaveComposer`，在 setup 阶段编译普通 `WaveDef[]`，覆盖 `wave_recipe_compile_validation`。 |
| Phase 2 | 新增 `WaveAdvancePolicyDef`，支持 `absolute_time` 与 `timer_with_health_threshold`；运行时发 `wave.advance_triggered` 与 `wave.huge_approaching`，覆盖 `wave_advance_health_threshold_validation`。 |
| Phase 3 | `WavePoolEntryDef.required_spawn_tags` 与 archetype `spawn.medium.*` 可参与 recipe 预过滤；显式 spawn zone contract 下仍由 `BattleSpawnResolver` 做最终裁判，覆盖 `wave_recipe_spawn_zone_filter_validation` 与 `wave_recipe_roof_spawn_zone_validation`。 |
| Phase 4 | 新增受控 `WaveInjectionRuleDef`，按 `wave_index` 注入配置化 entry；未开放任意 composer 脚本或完整特殊小游戏接管，覆盖 `wave_recipe_special_injection_validation`。 |

新增验证已接入 `tools/validation_scenarios.json` 与 `tools/formal_content_validation_map.json` 的 `wave_and_level_structure_v1`。`WavePoolEntryDef.archetype` 与 `archetype_id` 语义已对齐 `BattleSpawnEntry`，用于 validation 或局部 recipe 内联测试资源。

---

## 背景与目标

当前 Open PVZ 已经具备最小波次闭环：

- `BattleScenario.wave_defs` 声明波次。
- `WaveDef` 描述 `wave_id`、`start_time` 和 `spawn_entries`。
- `WaveSpawnEntry` 描述波内 spawn offset。
- `BattleSpawnEntry` 描述实体类型、archetype、lane、x、spawn overrides。
- `WaveRunner` 订阅 `game.tick`，启动到期 wave，投放到期 spawn entry，追踪 wave completion，并连接基础胜败条件。
- `BattleSpawnResolver` 已经承接 spawn zone、ground / water / roof 等生成入口合法性。

这套结构对验证场景、showcase 和少量手写关卡足够，但面对原版风格关卡和后续可自定义内容时会遇到两个问题：

1. 纯手写 `WaveDef` 会让正式关卡大量复制粘贴，不利于长期维护。
2. 如果把 power budget、权重衰减、旗帜波、特殊注入、提前刷新全部塞进 WaveRunner，会破坏当前 battle 子系统边界。

本文目标是讨论一个可自定义、可验证、可逐步落地的 WaveRunner 增强方向。

---

## 非目标

- 不把 WaveRunner 改成关卡总控。
- 不在 BattleManager 中加入具体僵尸或具体模式分支。
- 不修改冻结 Mechanic family。
- 不把僵尸行为逻辑放进波次系统；僵尸行为仍由 `CombatArchetype + CombatMechanic[]` 表达。
- 不直接复制 vendor 实现。
- 不让扩展包通过任意 GDScript 接管核心 wave loop。
- 不在第一阶段实现完整 Adventure、Survival Endless、Whack-a-Zombie、I, Zombie 全模式。

---

## 三源对比

| 来源 | 观察 | 对 Open PVZ 的启发 |
|------|------|-------------------|
| 当前 Open PVZ | `WaveRunner` 是轻量执行器；`WaveDef` 是显式波次表；spawn 最终走 `BattleSpawner`；生成入口合法性已经有 `BattleSpawnResolver`。 | 保留执行器职责，不把组波算法和地形合法性回流进 WaveRunner。 |
| 原版 de-pvz | `Board::PickZombieWaves()` 预生成每波僵尸列表；`Board::UpdateZombieSpawning()` 用倒计时、旗帜波提示、当前波剩余血量阈值推进；`gZombieDefs[]` 提供 value / starting level / pick weight；`gZombieAllowedLevels[]` 控制关卡可用僵尸。 | 组波算法应是“计划生成器”，运行时推进可支持固定时间和血量阈值，但不必复刻原版 Board 大类结构。 |
| PVZ-Godot-Dream | 拆成 `ZombieWaveManager`、`ZombieWaveCreateManager`、`ZombieWaveRefreshManager`、`ZombieChooseRowSystem`；支持 power budget、权重、行类型、半血提前刷新、旗帜波和特殊僵尸注入。 | 可借鉴职责拆分：组波、刷新策略、选行策略分离。但 Open PVZ 应用 Resource + fixed tick + validation 方式表达。 |

参考锚点：

- 原版规格：`vendor/de-pvz/Lawn/Board.cpp:Board::PickZombieWaves`，用于理解 power budget、旗帜波、固定注入和预生成波次列表。
- 原版推进：`vendor/de-pvz/Lawn/Board.cpp:Board::UpdateZombieSpawning`，用于理解倒计时、huge wave 提示和血量阈值提前推进。
- 原版数据：`vendor/de-pvz/Lawn/Zombie.cpp:gZombieDefs[]` 与 `vendor/de-pvz/Lawn/Challenge.cpp:gZombieAllowedLevels[]`，用于 value、starting level、pick weight 和关卡允许表。
- Godot 参考：`vendor/PVZ-Godot-Dream/scripts/manager/zombie_manager/zm_zombie_wave_create_manager.gd`，用于 power-based 组波参考。
- Godot 参考：`vendor/PVZ-Godot-Dream/scripts/manager/zombie_manager/zm_zombie_wave_refresh_manager.gd`，用于半血/全灭/最短时间刷新参考。
- 当前实现：`scripts/battle/wave_runner.gd`、`scripts/battle/wave_def.gd`、`scripts/battle/wave_spawn_entry.gd`、`scripts/battle/battle_spawn_resolver.gd`。

---

## 当前 OpenPVZ 状态

### 已有能力

- `WaveDef` 可显式定义波次。
- `WaveRunner` 可按 `start_time + spawn_time_offset` 调度 spawn entry。
- `wave.started` / `wave.completed` 已进入 UI 与验证观察面。
- 胜利目标支持 `all_waves_cleared`、`survive_duration`、`protect_and_clear` 等旧主链目标。
- `BattleModeHost` 已承接 mode-level objective 和 rule module。
- `BattleSpawnResolver` 已经从地形草稿方向落地，负责 spawn zone 与入口能力匹配。
- 原版 25 个 `archetype_original_*` 僵尸已经进入资源树，可作为正式波次池候选。

### 主要缺口

| 缺口类型 | 说明 |
|----------|------|
| 内容复用缺口 | 手写 `WaveDef[]` 对正式关卡可控，但上量后会复制大量波次模板。 |
| 组波协议缺口 | 没有 Resource 化的 power budget、权重、解锁波次、保底注入、旗帜波规则。 |
| 推进策略缺口 | 当前以绝对时间为主，尚未表达“最短时间 + 当前波剩余血量阈值 + 正常超时”的原版式推进。 |
| 自定义边界缺口 | 需要明确哪些自定义是内容配置，哪些属于 mode module，哪些需要 trusted runtime。 |
| 验证缺口 | 需要覆盖 deterministic generation、flag wave insertion、spawn zone filter、advance policy 等专项。 |

---

## 推荐模型

### 1. WaveRunner：只做执行器

WaveRunner 的职责建议固定为：

- 读取已经解析好的 wave plan。
- 按 `GameState.current_tick/current_time` 推进 wave。
- 启动 wave 并发出 `wave.started`。
- 在 spawn entry 到期时调用 `BattleSpawnResolver.resolve_spawn()`。
- 通过 `BattleSpawner.spawn_resolved_wave_entry()` 投放实体。
- 维护每个 wave 的 spawned entity 集合。
- 根据 completion policy 判断 `wave.completed`。
- 发出 UI / audio / debug 需要的波次事件。
- 做现有旧 battle goal / defeat condition 主链判定。

WaveRunner 不应负责：

- 计算僵尸池。
- 解释原版关卡 allowed table。
- 根据地形挑行。
- 决定具体僵尸行为。
- 处理特殊小游戏完整流程。
- 直接执行扩展包脚本。

### 2. WaveComposer：规则化组波

新增概念 `WaveComposer` 或等价编译器，职责是把规则资源编译成普通 `WaveDef[]` 或内部 `WavePlan`。

输入：

- `WaveRecipeDef`
- `WavePoolDef`
- battlefield / spawn zone 摘要
- battle seed
- 可选 mode context

输出：

- 一组稳定排序的 `WaveDef`
- 或只读运行时 `WavePlan`，其中每个 wave 含 resolved `WaveSpawnEntry[]`

设计原则：

- 组波发生在 battle setup 阶段，不在每 tick 随机生成。
- 随机必须从 `GameState.battle_seed` 派生，保证验证复现。
- 编译输出必须可 debug snapshot / validation 观察。
- 如果 recipe 无法编译，应走 `protocol.issue`，不要进入半运行状态。

### 3. WaveRecipeDef：组波规则

建议字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `recipe_id` | `StringName` | 稳定 id。 |
| `total_waves` | `int` | 总波数。 |
| `waves_per_flag` | `int` | 每几波一个旗帜波，原版常见 10。 |
| `start_delay` | `float` | 第一波前延迟。 |
| `base_spacing` | `float` | 普通绝对时间模式的基础间隔。 |
| `budget_curve_id` | `StringName` | 预算曲线，如 `original.linear_wave_div3`。 |
| `flag_budget_multiplier` | `float` | 旗帜波预算倍率，原版约 2.5。 |
| `pool_def` | `Resource` | 可选僵尸池。 |
| `advance_policy` | `Resource` | 推进策略。 |
| `guaranteed_rules` | `Array` | 保底注入规则，如新僵尸首次展示、最终波补齐。 |
| `special_injection_rules` | `Array` | 大波特殊注入，如 bungee、墓碑、海草类。第一阶段可暂缓。 |

### 4. WavePoolDef：候选僵尸池

建议字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `pool_id` | `StringName` | 稳定 id。 |
| `entries` | `Array[WavePoolEntryDef]` | 候选项。 |
| `weight_decay_rules` | `Array` | 权重随波次或 flag 递减规则。 |
| `spawn_medium_policy` | `StringName` | 是否要求 entry tags 与 spawn zone 匹配。 |

`WavePoolEntryDef` 建议字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `archetype_id` | `StringName` | 目标僵尸 archetype。 |
| `power` | `int` | 预算消耗，对应原版 `mZombieValue`。 |
| `weight` | `int` | 初始抽取权重，对应原版 `mPickWeight`。 |
| `first_allowed_wave` | `int` | 第几波后可出现。 |
| `max_per_wave` | `int` | 单波上限，可选。 |
| `max_per_stage` | `int` | 单阶段上限，可选。 |
| `required_spawn_tags` | `PackedStringArray` | ground / water / roof 等入口需求，通常来自 archetype tags。 |
| `entry_tags` | `PackedStringArray` | 如 `flag_candidate`、`spawned_only`、`rare`。 |

第一阶段可以先不新增独立 `WavePoolEntryDef` 类，先在 draft/plan 中固定字段，再决定 Resource 形态。

### 5. WaveAdvancePolicy：波次推进策略

建议支持三类：

| 策略 | 语义 | 用途 |
|------|------|------|
| `absolute_time` | 完全按 `WaveDef.start_time` 和 offset 推进。 | 当前兼容、validation、showcase。 |
| `timer_with_health_threshold` | 每波开始后设正常倒计时；达到最短时间后，若当前波剩余有效血量低于阈值，则提前推进。 | 原版 adventure / survival 风格。 |
| `all_dead_then_next` | 当前波全部死亡后推进，可带最短时间和最大等待。 | 旗前波、部分模式。 |

推进策略必须使用 simulation tick / `GameState.current_time`，不得使用 Godot `Timer` 或墙钟时间。

### 6. 自定义能力分层

| 自定义档位 | 作者写什么 | 适用场景 | 运行时落点 |
|------------|------------|----------|------------|
| 显式波次 | `WaveDef[]` + `WaveSpawnEntry[]` | validation、showcase、剧情关、精调关卡 | WaveRunner 直接执行。 |
| 规则化波次 | `WaveRecipeDef` + `WavePoolDef` + `WaveAdvancePolicy` | 普通正式关卡、Adventure-like、Survival-like | setup 时编译为 `WavePlan`。 |
| 模式级改写 | `BattleModeDef` + `BattleRuleModule` | 锤僵尸、我是僵尸、墓碑关、特殊小游戏 | BattleModeHost 驱动，必要时禁用或替换自然波次。 |
| 受信扩展 | trusted runtime contributor | 外部规则包需要新增组波算法 | 后续若开放，必须走 `RegistryBase + RegistryConfig + ContributorDef`。 |

核心边界：

> WaveRunner 支持自定义结果，不直接支持任意脚本逻辑。

---

## 数据流草案

```text
BattleScenario
  ├─ explicit wave_defs?
  │    └─ WaveRunner consumes as-is
  └─ wave_recipe?
       ├─ WaveComposer.compile(recipe, pool, battlefield, battle_seed)
       ├─ protocol validation
       └─ WaveRunner consumes compiled WavePlan

WaveRunner on game.tick
  ├─ advance wave state
  ├─ emit wave.started / wave.huge_approaching / wave.completed
  ├─ resolve spawn via BattleSpawnResolver
  ├─ spawn via BattleSpawner
  └─ evaluate battle goal / defeat conditions
```

### 旗帜波

旗帜波应是 wave metadata + content injection，而不是 ZombieRoot 特判：

- composer 标记 `wave_kind = "flag"` 或 `is_flag_wave = true`。
- composer 插入 `archetype_original_flag_zombie`。
- WaveRunner 发 `wave.huge_approaching` / `wave.started`。
- UI / audio 订阅事件表现大波提示。

### Yeti 稀有生成

Yeti 稀有生成属于组波规则，不属于实体 mechanic：

- `WavePoolEntryDef.entry_tags` 标记 `rare`。
- recipe 可声明 `rare_spawn_policy`，如只在特定阶段或 seed 条件下允许。
- composer 决定是否注入 `archetype_original_yeti`。
- WaveRunner 只执行结果。

### Bungee / 墓碑 / 海草类特殊注入

第一阶段只登记，不急着实现。

后续建议：

- 如果是“大波额外注入几个僵尸”，可作为 `special_injection_rule` 编译成 spawn entry。
- 如果需要修改棋盘或选择植物目标，优先走 mode rule module 或受控 effect，而不是 WaveRunner 内联。
- 如果依赖 GridItem，例如墓碑生成僵尸，应由 GridItem / field object / mode module 发起 `spawn_entity` 或提供 spawn entry，WaveRunner 不直接管理墓碑生命周期。

---

## 协议与验证缺口

### 协议缺口

| 缺口 | 建议归属 |
|------|----------|
| `BattleScenario` 是否新增 `wave_recipe` | battle scenario / protocol validator |
| `WaveRecipeDef` Resource 类型 | scripts/battle 或 data/combat/waves |
| `WavePoolDef` Resource 类型 | data/combat/waves 或 data/combat/levels |
| `WaveAdvancePolicy` Resource 类型 | scripts/battle |
| deterministic seed 派生 | GameState / WaveComposer |
| compiled plan debug snapshot | WaveRunner / DebugService |
| recipe guardrail | ProtocolValidator |

### 验证建议

| 验证场景 | 目标 |
|----------|------|
| `wave_recipe_compile_validation` | 同一 seed 下 recipe 编译输出稳定，wave 数、flag wave、spawn 数符合预期。 |
| `wave_recipe_flag_injection_validation` | 每个 flag wave 自动包含 flag zombie，并发出 `wave.huge_approaching` / `wave.started`。 |
| `wave_advance_health_threshold_validation` | 当前波有效血量低于阈值且最短时间已过时，下一波提前开始。 |
| `wave_spawn_zone_recipe_validation` | water-only 僵尸不会被编译或解析到 ground-only spawn zone；失败进入 `spawn.rejected` 或 protocol issue。 |
| `wave_recipe_guardrail_validation` | 空 pool、负 power、重复 id、无效 archetype、无法满足 spawn tags 时被拦截，且不产生 `entity.spawned`。 |
| `wave_recipe_custom_pool_validation` | 自定义 pool 权重和 first_allowed_wave 生效。 |

---

## 方案选项

### 方案 A：只扩展显式 WaveDef

做法：给 `WaveDef` 增加更多字段，例如 `wave_kind`、`completion_policy`、`huge_warning_time`。

优点：

- 实现最小。
- 和当前验证场景高度兼容。

缺点：

- 不解决大量正式关卡复制问题。
- power budget / 权重 / 解锁规则仍然没有统一表达。

适合短期补 UI / audio 大波提示，不适合作为完整生成系统。

### 方案 B：Recipe 编译成 WaveDef（推荐）

做法：保留现有显式 `WaveDef`，新增 recipe/pool/policy 作为可选上层。setup 阶段编译成 WaveRunner 可消费的计划。

优点：

- 保持 WaveRunner 简单。
- 支持显式自定义和规则化自定义。
- 易于验证编译输出。
- 不破坏现有 validation/showcase。

缺点：

- 需要新增一层资源和 validator。
- 第一阶段需要明确哪些字段先做，避免设计过厚。

这是推荐路线。

### 方案 C：模式模块完全接管波次

做法：普通 WaveRunner 保持不变，所有复杂生成都在 `BattleModeHost` rule module 里做。

优点：

- 对现有 WaveRunner 改动小。
- 特殊小游戏自由度最高。

缺点：

- 普通正式关卡也会被迫写 mode module。
- 配置化关卡创作门槛高。
- 容易让模式模块变成新的大泥球。

适合特殊模式，不适合作为普通波次系统主入口。

---

## 推荐分阶段路线

### Phase 0：文档与字段收口

- 固定 `WaveRunner` 职责边界。
- 固定 recipe / pool / advance policy 最小字段。
- 明确显式波次与规则化波次共存策略。
- 明确 `WaveRunner` 不执行任意脚本。
- 当前状态：已完成最小落地。

### Phase 1：最小 Recipe 编译

- 新增 `WaveRecipeDef` / `WavePoolDef` 最小 Resource。
- 支持：
  - total waves
  - waves per flag
  - base budget curve `wave / 3 + 1`
  - flag multiplier
  - weighted pool
  - first allowed wave
  - deterministic seed
- 编译输出为现有 `WaveDef[]` 或内部 `WavePlan`。
- 不做特殊注入，不做 survival endless。
- 当前状态：已完成最小落地，输出为普通 `WaveDef[]`。

### Phase 2：推进策略

- 新增 `WaveAdvancePolicy`。
- 支持 `absolute_time` 与 `timer_with_health_threshold`。
- 用当前波 spawned entities 的 objective-counted health 计算阈值。
- 发出 `wave.huge_approaching` 事件，供 UI / audio 使用。
- 当前状态：已完成最小落地；提前推进通过 `wave.advance_triggered` 观察。

### Phase 3：spawn zone 与地形联动

- recipe 编译或 spawn resolve 阶段尊重 archetype spawn tags。
- 覆盖 ground/water/roof 第一轮正式验证。
- 保持 `BattleSpawnResolver` 是生成入口合法性的唯一运行时裁判。
- 当前状态：已完成 ground-only 对 water-only entry 的 recipe 预过滤验证，并补齐 roof 显式 spawn zone 对 `spawn.medium.roof` / `spawn.medium.ground` entry 的保留与解析验证。

### Phase 4：模式与特殊注入

- 把 Bungee、墓碑生成、海草、Whack-a-Zombie、I, Zombie 等放到 mode module 或受控 injection rule。
- 评估是否需要开放 trusted `wave_composer` 扩展 slot。
- 当前状态：已完成受控 injection rule；未开放 trusted composer slot。

---

## 开放问题

1. `WaveRecipeDef` 应挂在 `BattleScenario.wave_recipe`，还是进入正式 `LevelDef` 后再接入？
2. 编译输出是否需要保存为调试 artifact，方便关卡作者查看实际波次？
3. `WavePoolDef` 的 `power/weight/first_allowed_wave` 是否应直接从 zombie archetype metadata 派生，还是独立维护？
4. 当前 `HealthComponent` 是否能提供足够统一的“当前有效血量”接口给 advance policy？
5. `wave.huge_approaching` 的 timing 应用秒表达还是 tick 表达？建议运行时转为 tick。
6. 受信扩展是否真的需要自定义 composer，还是先只允许自定义 pool/recipe/policy 参数？

---

## 当前结论

WaveRunner 的长期设计应围绕一个简单判断：

> 波次系统要支持高度自定义，但自定义应发生在 Resource 化定义、规则化编译和 mode module 三个边界内；WaveRunner 本体只负责确定性执行和战局事件。

这符合 KISS：执行器保持小；符合 YAGNI：第一阶段只做最小 recipe；符合 DRY：正式关卡共享 pool/recipe；也符合 SOLID：组波、调度、生成合法性、模式偏转各自有清晰职责。
