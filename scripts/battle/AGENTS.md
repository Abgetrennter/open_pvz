# scripts/battle

战斗运行时协调：实体生成、经济、棋盘、卡片、波次、胜负、模式、验证。

## WHERE TO LOOK

### 核心协调

| 文件 | 行数 | 要点 |
|------|------|------|
| `battle_manager.gd` | 730 | tick 循环、子系统委托 facade、spatial_query() 入口、验证生命周期 |
| `entity_factory.gd` | 583 | archetype-only 实例化、组件组装、`_merge_projectile_spec_params()` 4-pass 合并 |
| `battle_scenario.gd` | 42 @export | scenario_id / 经济 / 棋盘 / 卡片 / 波次 / 模式 / 验证规则，全场景配置入口 |
| `battle_projectile_effect_resolver.gd` | -- | effect 参数解析、movement params 组装、目标预测 |
| `spatial_index.gd` | 254 | rebuild() + query(params)，详见下方空间查询 |

### 子系统（各自持有状态文件）

| 子系统 | 核心文件 | 要点 |
|--------|----------|------|
| 经济 | `battle_economy_state.gd` | 阳光余额、天降调度、`try_spend_sun()` |
| 棋盘 | `battle_board_state.gd` (734行) | 格子管理、槽位类型/标签、`validate_request()` 8 项约束、角色占位 (primary/cover/blocker) |
| 卡片 | `battle_card_state.gd` | 手牌、费用、冷却、放置请求完整流程 |
| 流程 | `battle_flow_state.gd` | preparing→running→victory/defeat，发射 `phase_changed` |
| 状态 | `battle_status_state.gd` | 定时 apply 状态、驱动实体 `update_statuses()` |
| 波次 | `wave_runner.gd` | 按时间启波、调度生成、完成检测、胜败判定 |
| 场上物件 | `battle_field_object_state.gd` | 读取 config→EntityFactory 生成→发射 spawned |

### 数据定义

`battle_spawn_entry` / `battle_validation_rule` / `card_def` / `card_play_request` / `placement_request` / `board_slot` / `board_slot_config` / `board_slot_catalog` / `wave_def` / `wave_spawn_entry` / `sun_collectible` / `sun_drop_entry` / `resource_spend_request` / `status_application_request` / `field_object_config` / `battlefield_preset` / `battlefield_metrics` / `effect_execution_request` / `battle_scenario_provider` / `battle_subsystem_host` / `battle_effect_request_state` / `battle_spawner`

### 模式层 (mode/)

| 文件 | 职责 |
|------|------|
| `battle_mode_def.gd` | 模式定义 Resource：mode_id、输入 profile、目标、规则模块 |
| `battle_mode_host.gd` | 运行时宿主：解析 mode_def、合并 override、驱动规则模块、评估目标 |
| `battle_input_profile.gd` | 输入权限模型：定义 mode 允许的交互动作 |
| `battle_rule_module.gd` | 最小可组合规则单元，参数化配置 |
| `battle_objective_def.gd` | mode 专属胜负条件 |
| `battle_mode_module_registry.gd` | module_id→callable 映射，`_init` 硬编码注册 |
| `battle_mode_input_request.gd` | 模式输入请求数据 |

## 空间查询 (SpatialIndex)

`rebuild(entities)` 重建索引；`query(params)` 多维过滤：
- **候选池选取**：tags_any > lane_ids > team_include > team_exclude > kinds > 全量
- **逐条过滤**：team / lane_ids / tags_all / tags_any / kinds / x_min+x_max / center+radius / height_range / filter(callable)
- **排序**：sort_by_distance 或 sort_by_x，稳定排序用 entity_id / insert_order
- **height_range**：Vector2(y_min, y_max)，与实体 `get_hit_height_range()` 做 overlap 检测

## CORE FLOWS

### 卡片出牌

```
card.selected → card.play_requested
  → 存在/冷却检查 → 构建 PlacementRequest
  → BattleBoardState.validate_request() [8 项约束]
  → BattleEconomyState.try_spend_sun()
  → BattleManager.spawn_card_entity()
  → BattleBoardState.commit_request()
  → card.cooldown_started
```

### 波次调度

```
WaveRunner._on_game_tick()
  → _start_due_waves() → flow_state.ensure_running() + mark_wave_started()
  → _spawn_due_entries() → battle.spawn_wave_entry()
  → _complete_finished_waves() → 全条目已生成 + 无存活敌人
  → _check_victory() → 全波完成 + 无存活敌人 → mark_victory
  → _check_defeat() → 僵尸越过 defeat_line_x → mark_defeat
```

## 验证状态机

### 组件

| 组件 | 职责 |
|------|------|
| `BattleValidationTracker` | pending→passed/failed 状态机、事件匹配、计数更新、deadline 检测、auto-quit |
| `BattleValidationReporter` | JSON/TXT 报告导出到 artifacts/ |
| `BattleScenarioProvider` | 命令行参数解析、scenario 资源加载 |

### 事件匹配

每条 `BattleValidationRule`：event_name + required_tags + required_core_values + min_count / max_count。

```
EventBus.event_pushed → _on_validation_event()
  → event_name 匹配 → _event_matches_rule() [tags + core_values]
  → count++ → exceeded? → failed / satisfied? → passed
  → deadline 到达 → _all_satisfied? → passed / failed
  → auto_quit_timer → get_tree().quit(0|1)
```
