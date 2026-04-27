[根目录](../../CLAUDE.md) > [scripts](../) > **battle**

# scripts/battle -- 战斗协调系统

## 模块职责

战斗运行时的核心模块，协调实体生成、资源经济、棋盘放置、卡片系统、波次调度和胜负判定。Phase 4 的主要实现区域。

## 关键文件

### 核心协调

| 文件 | 类名 | 职责 |
|------|------|------|
| `battle_manager.gd` | `BattleManager` | 战斗主控制器（Node2D）。管理 tick 循环、实体生成、验证状态机、抛射体生成接口。连接所有子系统 |
| `entity_factory.gd` | `EntityFactory` | 实体工厂（RefCounted）。从 RuntimeSpec 实例化实体、组装组件、构建 mechanic-first 运行时触发器 |
| `battle_scenario.gd` | `BattleScenario` | 战斗场景配置（Resource）。定义生成条目、验证规则、经济参数、棋盘配置、波次定义 |
| `battle_projectile_effect_resolver.gd` | `BattleProjectileEffectResolver` | 投射体 effect 参数解析、movement params 组装、目标解析与预测 |
| `battle_validation_reporter.gd` | `BattleValidationReporter` | 验证报告构建、artifact 导出、JSON/text 写入 |

### Phase 4 子系统

| 文件 | 类名 | 职责 |
|------|------|------|
| `battle_economy_state.gd` | `BattleEconomyState` | 阳光经济：当前阳光、天降阳光调度、植物产阳光、消费验证（try_spend_sun） |
| `battle_board_state.gd` | `BattleBoardState` | 棋盘状态：格子管理、槽位类型/标签、放置验证（validate_request）、角色占位（primary/cover/blocker） |
| `battle_card_state.gd` | `BattleCardState` | 卡片运行时：手牌管理、费用消耗、冷却管理、放置请求完整流程 |
| `battle_flow_state.gd` | `BattleFlowState` | 流程状态：preparing -> running -> victory/defeat。发射 phase_changed 事件 |
| `battle_status_state.gd` | `BattleStatusState` | 状态运行时：从 scenario 读取状态应用请求、定时 apply、驱动实体 update_statuses |
| `wave_runner.gd` | `WaveRunner` | 波次调度：按时间启动波次、调度生成、检测波次完成、检测胜败条件 |
| `battle_field_object_state.gd` | `BattleFieldObjectState` | 场上物件状态：从 scenario 读取 field_object_configs、通过 EntityFactory 生成物件、发射 spawned 事件 |

### 数据定义

| 文件 | 类名 | 职责 |
|------|------|------|
| `battle_spawn_entry.gd` | `BattleSpawnEntry` | 生成条目：archetype_id + 位置 + 覆盖参数 |
| `battle_validation_rule.gd` | `BattleValidationRule` | 验证规则：event_name + tags + min/max_count |
| `card_def.gd` | `CardDef` | 卡片定义：card_id, archetype_id, sun_cost, cooldown |
| `card_play_request.gd` | `CardPlayRequest` | 卡片出牌请求：card_id + lane_id + slot_index + at_time |
| `placement_request.gd` | `PlacementRequest` | 放置请求：archetype_id + lane_id + slot_index + placement_tags |
| `board_slot.gd` | `BoardSlot` | 棋盘槽位：lane_id + slot_index + slot_type + base_tags + occupants |
| `board_slot_config.gd` | `BoardSlotConfig` | 槽位配置覆盖：slot_type + placement_tags |
| `board_slot_catalog.gd` | `BoardSlotCatalog` | 槽位类型目录：ground/water/roof/air + 默认标签 |
| `wave_def.gd` | `WaveDef` | 波次定义：wave_id + start_time + spawn_entries |
| `wave_spawn_entry.gd` | `WaveSpawnEntry` | 波次生成条目：spawn_time_offset + spawn_entry |
| `sun_collectible.gd` | `SunCollectible` | 阳光收集物（Node2D）：自动收集倒计时、collect 接口 |
| `sun_drop_entry.gd` | `SunDropEntry` | 阳光掉落配置 |
| `resource_spend_request.gd` | `ResourceSpendRequest` | 资源消耗请求 |
| `status_application_request.gd` | `StatusApplicationRequest` | 状态应用请求：status_id + duration + movement_scale + blocks_attack |
| `field_object_config.gd` | `FieldObjectConfig` | 场上物件配置：archetype_id + lane_id + x_position + spawn_overrides |

### 模式层 (mode/)

| 文件 | 类名 | 职责 |
| --- | --- | --- |
| `mode/battle_mode_def.gd` | `BattleModeDef` | 模式定义（Resource）：mode_id、输入 profile、目标定义、规则模块 |
| `mode/battle_input_profile.gd` | `BattleInputProfile` | 输入权限模型（Resource）：定义 mode 允许的交互动作 |
| `mode/battle_rule_module.gd` | `BattleRuleModule` | 规则模块（Resource）：最小可组合规则单元，参数化配置 |
| `mode/battle_objective_def.gd` | `BattleObjectiveDef` | 目标定义（Resource）：mode 专属胜负条件 |
| `mode/battle_mode_host.gd` | `BattleModeHost` | 模式运行时宿主（Node）：解析 mode_def、合并 override、驱动规则模块、评估目标 |
| `mode/battle_mode_module_registry.gd` | `BattleModeModuleRegistry` | 模块 handler 注册表（RefCounted）：module_id -> callable 映射 |

## 核心流程

### 卡片出牌流程

```
card.selected -> card.play_requested
  -> 检查卡片存在 -> 检查冷却 -> 构建 PlacementRequest
  -> BattleBoardState.validate_request()
    -> 检查车道/槽位/标签/角色占位
  -> BattleEconomyState.try_spend_sun()
  -> BattleManager.spawn_card_entity()
  -> BattleBoardState.commit_request()
  -> card.cooldown_started
```

### 波次流程

```
WaveRunner._on_game_tick()
  -> _start_due_waves() -> flow_state.ensure_running() + mark_wave_started()
  -> _spawn_due_entries() -> battle.spawn_wave_entry()
  -> _complete_finished_waves() -> 所有条目已生成 + 无存活敌人
  -> _check_victory() -> 所有波次完成 + 无存活敌人 -> mark_victory("all_waves_cleared")
  -> _check_defeat() -> 僵尸越过 defeat_line_x -> mark_defeat("zombie_reached_goal")
```

## 相关验证场景

- `minimal_battle_validation` -- 最小骨架
- `sun_resource_validation` -- 阳光经济循环
- `card_flow_validation` / `card_place_validation` -- 卡片运行时与数据驱动放置
- `board_placement_validation` / `board_slot_tag_validation` / `roof_slot_validation` / `air_slot_validation` / `cover_blocker_validation` -- 棋盘放置
- `placement_compile_validation` / `placement_runtime_spec_validation` / `placement_field_fallback_validation` / `placement_guardrail_validation` -- Placement family 编译、运行时与守卫
- `wave_flow_validation` / `wave_guardrail_validation` -- 波次系统
- `field_object_mower_validation` -- 场上物件割草机
- `mode_basic_validation` -- 模式层基本初始化
- `mode_manual_aim_lane_validation` -- 手动技能试点闭环
- `mode_input_profile_guard_validation` -- 输入 profile 守卫
- `mode_objective_score_validation` -- 分数目标推进
- `mode_objective_protect_template_validation` -- protect_template 目标
- `mode_objective_clear_special_targets_validation` -- clear_special_targets 目标
- `mode_objective_defeat_named_spawn_validation` -- defeat_named_spawn 目标
- `mode_module_override_validation` -- scenario module 覆盖语义
- `mode_conveyor_cards_validation` -- conveyor_cards 最小能力
- `mode_no_mode_guardrail` -- 无 mode 向后兼容 guardrail

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
