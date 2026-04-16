[根目录](../../CLAUDE.md) > [scenes](../) > **validation**

# scenes/validation -- 自动化验证场景

## 模块职责

引擎的自动化测试机制。每个验证场景由一个 `.tres`（BattleScenario 配置）和可选的 `.tscn`（场景文件）组成。通过 BattleManager 的内置验证状态机执行。

## 当前场景 (25 个)

详见根 CLAUDE.md 的验证场景清单。场景定义索引文件：`tools/validation_scenarios.json`。

## 场景结构

每个 `.tres` 文件是一个 `BattleScenario` Resource，包含：
- `scenario_id` -- 唯一标识
- `display_name` / `description` / `goals` -- 描述信息
- `validation_time_limit` -- 验证时间窗口
- `spawns` -- 初始生成条目（BattleSpawnEntry 数组）
- `validation_rules` -- 验证规则（BattleValidationRule 数组）
- `initial_sun` / `sun_auto_collect_delay` -- 经济参数
- `board_slot_count` / `board_slot_spacing` / `board_slot_configs` -- 棋盘参数
- `card_defs` / `card_play_requests` -- 卡片参数
- `status_application_requests` -- 状态应用请求
- `wave_defs` -- 波次参数
- `defeat_line_x` -- 失败线

## 运行方式

```powershell
# 批量运行
pwsh tools/run_all_validations.ps1

# 单个运行
pwsh tools/run_validation.ps1 -ScenarioId <id>

# Godot 编辑器
# 打开 minimal_battle_validation.tscn，按 F6
```

## 新增验证场景步骤

1. 在 `tools/validation_scenarios.json` 中添加条目
2. 在此目录创建 `.tres` 文件（BattleScenario 配置）
3. 可选：创建 `.tscn` 场景文件（如果需要自定义场景布局）
4. 运行 `pwsh tools/run_all_validations.ps1` 验证

## 结果输出

输出到 `artifacts/validation/`，包含：
- `validation_report.json` -- 验证报告（状态、规则计数）
- `debug_logs.json` -- 调试日志（事件历史、效果执行记录）

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
