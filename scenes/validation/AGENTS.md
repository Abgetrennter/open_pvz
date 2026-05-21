[根目录](../../AGENTS.md) > [scenes](../) > **validation**

# scenes/validation -- 自动化验证场景

引擎唯一测试机制；无单元测试框架。场景数量以 `tools/validation_scenarios.json` 为准。

## 场景结构

每个 `.tres` 是 `BattleScenario` Resource：`scenario_id`、`validation_time_limit`、`validation_rules[]`、`spawns[]`、经济/棋盘/卡片/波次/模式配置。可选 `.tscn` 提供自定义场景布局。

场景索引：`tools/validation_scenarios.json`（分层 smoke/core/extension/guardrail/showcase/local_private，以文件为准）。

## 验证规则模型

`BattleValidationRule`：`rule_id`、`event_name`、`min_count`、`max_count`、`required_tags[]`、`required_core_values{}`。

匹配逻辑：event_name 精确 AND `required_tags` 全部 ∈ `event.core.tags` AND `required_core_values` 全部匹配 `event.core[key]`。

- `min_count=1, max_count=-1` → 至少出现一次
- `max_count>=0` → 上界守卫

## 状态机流程

```
EventBus.event_pushed
  → BattleValidationTracker._event_matches_rule()
  → 更新规则计数
  → deadline 检查
  → pending → passed（全部满足）/ failed（任一超限或超时）
  → BattleValidationReporter 输出
  → auto-quit
```

核心实现：`scripts/battle/battle_validation_tracker.gd`（~244 行）。

## 运行命令

```powershell
# 单场景
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/<name>.tres"

# 批量（受控并行）
pwsh tools/run_all_validations.ps1 -MaxParallel 8 -Layers "smoke,core"
```

编辑器内：打开 `.tscn` 按 F6。

## 输出格式

单场景输出到 `artifacts/validation/<scenario_id>/`：

- `validation_report.json` — status、rules（含实际计数）、summary
- `debug_logs.json` — 事件历史、效果执行记录
- `godot.log` — 引擎日志
- `validation_summary.txt` — 人类可读摘要

批量产出：`summary.json`（全场景汇总）、`regression_history.jsonl`（历史记录追加）、`regression_status.json`（回归标记）。

## 特殊探针

- **VisualValidationProbe** — 验证 visual registry 完整性（cue/fx/audio/profile 注册一致性）
- **InfrastructureValidationProbe** — 验证 SpatialIndex 一致性（空间查询结果与预期匹配）
