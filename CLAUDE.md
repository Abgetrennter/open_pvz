# CLAUDE.md

> Open PVZ -- 基于 Godot 4.x (GDScript) 的可组合、可扩展 PVZ 类规则引擎。不是 Plants vs Zombies 的直接克隆；引擎优先考虑规则的开放组合和涌现式玩法，而非功能完整度。

## 变更记录 (Changelog)

| 时间 | 操作 | 说明 |
|------|------|------|
| 2026-04-15 21:39:03 | init-architect 全仓扫描 | 增量更新：新增模块结构图、模块索引表、模块级 CLAUDE.md、覆盖率报告 |

## 项目愿景

Open PVZ 是一个开放式 PVZ-like 规则引擎，核心目标是让"组合规则"成为核心玩法驱动力。项目以四层模型（语义事件 -> 行为效果 -> 组合装配 -> 连续行为）为骨架，用 Resource-based 模板系统实现无代码的内容扩展。

当前阶段：**Phase 4** -- 玩法系统集成（资源经济、棋盘/卡片系统、波次系统）。Phase 1-3（骨架搭建、模板系统、协议冻结）已完成。

## 架构总览

### 四层模型

1. **语义事件层** -- "发生了什么"。事件如 `game.tick`、`entity.damaged`、`entity.died`、`projectile.hit` 通过 `EventBus`（autoload）流转。
2. **行为效果层** -- "该做什么"。`EffectDef` -> `EffectNode`，由 `EffectExecutor` 执行。效果是原子化、可组合、可嵌套的（最大深度 5）。注册于 `EffectRegistry`。
3. **组合装配层** -- "实体如何组装"。`EntityTemplate` -> `TriggerBinding` -> 工厂装配。`TriggerDef` -> `TriggerInstance` -> `TriggerComponent` 挂载到实体。注册于 `TriggerRegistry`。
4. **连续行为层** -- "持续对象如何更新"。抛射体使用 3D 逻辑 + 2D 投影，通过 `_physics_process` 持续模拟，命中时重新进入事件链（`projectile.hit`）。

### 执行链

```
EventBus -> TriggerComponent -> TriggerInstance -> RuleContext -> EffectExecutor -> Runtime Action -> EventBus
```

### 全局单例 (Autoloads)

| 单例名 | 职责 |
|--------|------|
| `EventBus` | 事件分发，优先级订阅，历史追踪（最多 256 条） |
| `DebugService` | 集中式日志：事件/触发器/效果 |
| `SceneRegistry` | 场景与资源注册表，自动扫描 `data/combat/` |
| `TriggerRegistry` | 触发器定义与策略注册（periodically / when_damaged / on_death） |
| `EffectRegistry` | 效果定义与策略注册（damage / spawn_projectile / explode） |
| `GameState` | 游戏状态管理（当前战斗、时间、实体 ID 分配） |

### 战斗运行时子系统 (Phase 4)

| 子系统 | 类名 | 职责 |
|--------|------|------|
| 经济状态 | `BattleEconomyState` | 阳光资源管理、天降阳光、植物产阳光、消费验证 |
| 棋盘状态 | `BattleBoardState` | 格子系统、放置验证、槽位类型/标签、角色占位 |
| 卡片状态 | `BattleCardState` | 卡片手牌、费用消耗、冷却管理、放置请求流程 |
| 流程状态 | `BattleFlowState` | 战斗阶段管理（preparing / running / victory / defeat） |
| 波次运行器 | `WaveRunner` | 波次调度、敌人生成、胜败条件检测 |

## 模块结构图

```mermaid
graph TD
    Root["Open PVZ (根)"] --> Autoload["autoload"]
    Root --> Scripts["scripts"]
    Root --> Data["data/combat"]
    Root --> Scenes["scenes"]
    Root --> Tools["tools"]
    Root --> Wiki["wiki"]
    Root --> Plans["plans"]

    Scripts --> Core["scripts/core"]
    Scripts --> Battle["scripts/battle"]
    Scripts --> Entities["scripts/entities"]
    Scripts --> Components["scripts/components"]
    Scripts --> Projectile["scripts/projectile"]
    Scripts --> Debug["scripts/debug"]

    Core --> CoreDefs["core/defs"]
    Core --> CoreRuntime["core/runtime"]

    Scenes --> ScenesValidation["scenes/validation"]
    Scenes --> ScenesShowcase["scenes/showcase"]
    Scenes --> ScenesMain["scenes/main"]

    click Autoload "./autoload/CLAUDE.md" "查看 autoload 模块文档"
    click Core "./scripts/core/CLAUDE.md" "查看 core 模块文档"
    click Battle "./scripts/battle/CLAUDE.md" "查看 battle 模块文档"
    click Entities "./scripts/entities/CLAUDE.md" "查看 entities 模块文档"
    click Components "./scripts/components/CLAUDE.md" "查看 components 模块文档"
    click Projectile "./scripts/projectile/CLAUDE.md" "查看 projectile 模块文档"
    click Data "./data/combat/CLAUDE.md" "查看 data/combat 模块文档"
    click ScenesValidation "./scenes/validation/CLAUDE.md" "查看 validation 模块文档"
```

## 模块索引

| 模块路径 | 语言 | 文件数 | 职责概述 |
|----------|------|--------|----------|
| `autoload/` | GDScript | 6 | 全局单例：事件总线、注册表、游戏状态 |
| `scripts/core/defs/` | GDScript | 8 | 资源定义类：TriggerDef, EffectDef, EntityTemplate, ProjectileTemplate 等 |
| `scripts/core/runtime/` | GDScript | 7 | 运行时执行：EffectExecutor, ProtocolValidator, RuleContext, EntityState 等 |
| `scripts/battle/` | GDScript | 18 | 战斗协调：BattleManager, EntityFactory, 经济/棋盘/卡片/波次子系统 |
| `scripts/entities/` | GDScript | 4 | 实体类型：BaseEntity, PlantRoot, ZombieRoot, ProjectileRoot |
| `scripts/components/` | GDScript | 6 | 可复用组件：HealthComponent, TriggerComponent, HitboxComponent 等 |
| `scripts/projectile/` | GDScript | 5 | 抛射体运动系统：linear / parabola / track 运动模式 |
| `scripts/debug/` | GDScript | 1 | 调试覆盖层 |
| `data/combat/` | .tres | ~46 | 战斗数据资源：实体模板、抛射体模板、飞行配置、触发绑定 |
| `scenes/validation/` | .tres/.tscn | 25 | 自动化验证场景（24 个场景 + 1 个通用 tscn） |
| `scenes/showcase/` | .tscn | 9 | 展示场景 |
| `tools/` | PS1/JSON | 3 | 验证运行工具 |
| `wiki/` | Markdown | ~30 | 中文设计文档（5 个子目录） |
| `plans/` | Markdown | ~10 | 阶段规划与设计草案 |
| `vendor/` | -- | 大量 | 参考实现（PVZ-Godot-Dream），不属于引擎核心 |

## 运行与开发

### 运行项目

- 在 Godot 4.x 编辑器中打开。主场景：`res://scenes/main/main.tscn`
- 视口：960x540，窗口：1920x1080
- 物理引擎：Jolt Physics
- 渲染方式：mobile

### 验证（测试）

验证场景是主要的测试机制 -- 没有单元测试框架。

```powershell
# 运行所有验证场景
pwsh tools/run_all_validations.ps1

# 运行单个场景
pwsh tools/run_validation.ps1 -ScenarioId <id>
```

场景定义：`tools/validation_scenarios.json`（25 个场景）
场景资源：`scenes/validation/`
结果输出：`artifacts/validation/`

在 Godot 编辑器中运行单个场景：打开 `scenes/validation/` 中的 `.tscn` 文件并按 F6。

### 验证场景清单

| 场景 ID | 覆盖领域 |
|---------|----------|
| `minimal_battle_validation` | 最小引擎骨架验证 |
| `parabola_long_range_validation` | 远距离抛物线命中 |
| `height_hit_validation` | 高度段命中过滤 |
| `lane_isolation_validation` | 车道隔离验证 |
| `swept_segment_validation` | 扫掠线段碰撞 |
| `terminal_explode_validation` | 终端爆炸伤害 |
| `template_instantiation_validation` | 模板实例化 |
| `template_factory_validation` | 模板工厂运行时触发器 |
| `spawn_override_priority_validation` | 生成覆盖优先级 |
| `air_interceptor_validation` | 空中拦截器 |
| `repeater_burst_validation` | 连发射手 |
| `lobber_catalog_validation` | 投掷物目录 |
| `zombie_roster_attack_validation` | 僵尸阵容攻击 |
| `template_guardrail_validation` | 模板护栏 |
| `protocol_guardrail_validation` | 协议护栏 |
| `sun_resource_validation` | 阳光资源经济 |
| `card_flow_validation` | 卡片运行时流程 |
| `board_placement_validation` | 棋盘放置 |
| `board_slot_tag_validation` | 槽位标签验证 |
| `roof_slot_validation` | 屋顶槽位 |
| `air_slot_validation` | 空中槽位 |
| `cover_blocker_validation` | 掩体/阻挡角色 |
| `status_system_validation` | 状态系统（减速/眩晕） |
| `wave_flow_validation` | 波次与胜负流程 |
| `wave_guardrail_validation` | 波次护栏 |

## 冻结协议 (Phase 3)

第一轮协议冻结已生效。未经设计审批，不得修改以下语义：

**触发器：** `periodically` (game.tick)、`when_damaged` (entity.damaged)、`on_death` (entity.died)
**效果：** `damage`、`spawn_projectile`、`explode`
**行为键映射：** `attack` -> periodically、`when_damaged` -> when_damaged、`on_death` -> on_death

`ProtocolValidator` 在运行时强制执行参数类型、边界和资源脚本类型检查。所有新定义必须通过验证。

## 编码规范

### 资源定义

- 所有游戏定义使用 Godot `Resource` (.tres) 文件，不使用 JSON 或外部格式
- 使用 `@export` 暴露编辑器属性
- 一个类一个文件；数据定义继承 `Resource`

### 模板编写顺序

Identity -> Node/Component -> Combat -> Projectile -> Behavior

### 模板命名

- `plant_role_variant`、`zombie_role_variant`、`projectile_type`
- 文件放在 `data/combat/entity_templates/plants/` 或 `zombies/`

### 事件命名

点分隔语义名：`game.tick`、`entity.damaged`、`entity.died`、`projectile.hit`

### 目标解析模式 (effects)

`context_target`、`source`、`owner`、`event_source`、`event_target`、`enemies_in_radius`

### 代码风格

- PascalCase 用于类名，snake_case 用于变量/函数
- StringName 用于驻留标识符
- RefCounted 用于系统间传递的数据

## 测试策略

- **无单元测试框架**，验证场景是唯一的自动化测试机制
- 每个验证场景包含：`.tres` 配置（BattleScenario）+ `.tscn` 场景文件
- 验证规则通过事件匹配：事件名 + 标签 + 核心值 + 次数范围
- BattleManager 内置验证状态机：pending -> passed/failed
- 命令行支持：`--validation-auto-quit`、`--validation-print-report`、`--validation-output-dir=`
- 结果输出为 JSON：`validation_report.json` + `debug_logs.json`

## 文档

`wiki/` 目录包含中文设计文档（详见 [wiki/index.md](wiki/index.md)）：
- `01-overview/` -- 架构、设计哲学、当前阶段
- `02-runtime-protocol/` -- 触发器系统、效果系统、执行机制
- `03-content-validation/` -- 验证矩阵和覆盖率
- `04-roadmap-reference/` -- 参考实现、外部调研
- `05-governance/` -- 模板编写约定、方法论

`plans/` 目录包含阶段任务清单和设计文档。

## AI 使用指引

- 修改冻结协议前务必获得设计审批
- 新增实体功能时，必须同时创建验证场景
- 优先通过 `.tres` Resource 扩展内容，而非修改 GDScript 代码
- 调试时使用 `DebugService` 记录，不要用 `print`
- 所有抛射体运动配置通过 `ProjectileFlightProfile` Resource 驱动
- `vendor/` 目录为参考实现，不要直接修改或依赖

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
