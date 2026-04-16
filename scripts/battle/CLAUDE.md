[根目录](../../CLAUDE.md) > [scripts](../) > **battle**

# scripts/battle -- 战斗协调系统

## 模块职责

战斗运行时的核心模块，协调实体生成、资源经济、棋盘放置、卡片系统、波次调度和胜负判定。Phase 4 的主要实现区域。

## 关键文件

### 核心协调

| 文件 | 类名 | 职责 |
|------|------|------|
| `battle_manager.gd` | `BattleManager` | 战斗主控制器（Node2D）。管理 tick 循环、实体生成、验证状态机、抛射体生成接口。连接所有子系统 |
| `entity_factory.gd` | `EntityFactory` | 实体工厂（RefCounted）。从 EntityTemplate 实例化实体、组装组件、构建运行时触发器 |
| `battle_scenario.gd` | `BattleScenario` | 战斗场景配置（Resource）。定义生成条目、验证规则、经济参数、棋盘配置、波次定义 |

### Phase 4 子系统

| 文件 | 类名 | 职责 |
|------|------|------|
| `battle_economy_state.gd` | `BattleEconomyState` | 阳光经济：当前阳光、天降阳光调度、植物产阳光、消费验证（try_spend_sun） |
| `battle_board_state.gd` | `BattleBoardState` | 棋盘状态：格子管理、槽位类型/标签、放置验证（validate_request）、角色占位（primary/cover/blocker） |
| `battle_card_state.gd` | `BattleCardState` | 卡片运行时：手牌管理、费用消耗、冷却管理、放置请求完整流程 |
| `battle_flow_state.gd` | `BattleFlowState` | 流程状态：preparing -> running -> victory/defeat。发射 phase_changed 事件 |
| `battle_status_state.gd` | `BattleStatusState` | 状态运行时：从 scenario 读取状态应用请求、定时 apply、驱动实体 update_statuses |
| `wave_runner.gd` | `WaveRunner` | 波次调度：按时间启动波次、调度生成、检测波次完成、检测胜败条件 |

### 数据定义

| 文件 | 类名 | 职责 |
|------|------|------|
| `battle_spawn_entry.gd` | `BattleSpawnEntry` | 生成条目：entity_template + 位置 + 覆盖参数 |
| `battle_validation_rule.gd` | `BattleValidationRule` | 验证规则：event_name + tags + min/max_count |
| `card_def.gd` | `CardDef` | 卡片定义：card_id, entity_template_id, sun_cost, cooldown |
| `card_play_request.gd` | `CardPlayRequest` | 卡片出牌请求：card_id + lane_id + slot_index + at_time |
| `placement_request.gd` | `PlacementRequest` | 放置请求：entity_template_id + lane_id + slot_index + placement_tags |
| `board_slot.gd` | `BoardSlot` | 棋盘槽位：lane_id + slot_index + slot_type + base_tags + occupants |
| `board_slot_config.gd` | `BoardSlotConfig` | 槽位配置覆盖：slot_type + placement_tags |
| `board_slot_catalog.gd` | `BoardSlotCatalog` | 槽位类型目录：ground/water/roof/air + 默认标签 |
| `wave_def.gd` | `WaveDef` | 波次定义：wave_id + start_time + spawn_entries |
| `wave_spawn_entry.gd` | `WaveSpawnEntry` | 波次生成条目：spawn_time_offset + spawn_entry |
| `sun_collectible.gd` | `SunCollectible` | 阳光收集物（Node2D）：自动收集倒计时、collect 接口 |
| `sun_drop_entry.gd` | `SunDropEntry` | 阳光掉落配置 |
| `resource_spend_request.gd` | `ResourceSpendRequest` | 资源消耗请求 |
| `status_application_request.gd` | `StatusApplicationRequest` | 状态应用请求：status_id + duration + movement_scale + blocks_attack |

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
- `card_flow_validation` -- 卡片运行时
- `board_placement_validation` / `board_slot_tag_validation` / `roof_slot_validation` / `air_slot_validation` / `cover_blocker_validation` -- 棋盘放置
- `wave_flow_validation` / `wave_guardrail_validation` -- 波次系统

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
