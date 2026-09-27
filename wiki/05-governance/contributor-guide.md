# 开发约束与按需阅读

- 状态：当前事实

本文承接根目录 [AGENTS.md](../../AGENTS.md) 的详细开发约束。修改运行时、内容或扩展前阅读相关部分；架构、阶段状态与模块清单由现有专题页维护，文件数量以源码为准。

## 实体与内容

- 唯一实体运行时入口是 `CombatArchetype + CombatMechanic[] -> RuntimeSpec -> EntityFactory`；不恢复 `EntityTemplate` / `TriggerBinding`。
- 游戏定义使用 `.tres` Resource，数据定义继承 `Resource`，用 `@export` 暴露编辑器属性，一个类一个文件。JSON 扩展 manifest 不属于游戏定义资源。
- Archetype 编写顺序：Identity → Chassis → Combat Stats → Mechanic[]。文件置于 `data/combat/archetypes/` 的 plants、zombies 或 field_objects 子目录；名称采用 `plant_role_variant`、`zombie_role_variant`。
- 不编写 `PeaShooterAttack` 等实体专属业务类，也不在 BattleManager 中为实体或模式添加特判；模式差异通过 `BattleModeHost / BattleRuleModule` 表达。
- Mechanic 使用 family/type 语义，例如 `Controller.core.bite`；事件使用 `entity.damaged` 等点分隔名称。
- PascalCase 类名、snake_case 变量/函数、StringName 驻留标识符、RefCounted 系统间数据。沿用现有 GDScript 的 Tab 缩进与 UTF-8 编码。
- 全范围查询使用 `range_mode = "full_lane"` 或显式 lane 查询，不用 `4000.0` / `99999.0` 模拟；不用 `-999999.0` 哨兵替代明确状态。
- `_LEGACY_TO_SEMANTIC_OVERRIDE_KEYS` 和 `legacy_*` 仅是迁移桥接，不作为新增内容的作者接口。

## 时间、随机与表现

- 游戏逻辑使用 GameState 的 100Hz 固定 tick 与派生时间，不使用 `OS.get_ticks_*` 或 Godot Timer 节点驱动玩法。
- 随机行为遵循 `battle_seed` 派生链和 ShuffleBag 协议；UI/渲染不消费玩法随机数。
- Tween、粒子与视觉反馈不得决定伤害、命中或冷却等战斗结果。
- 运行时日志使用 DebugService；只有 DebugService 自身和 validation reporter 可使用其原有直接输出路径。
- 抛射体基础配置使用 `ProjectileFlightProfile`；新增飞行类型接入 `ProjectileMovementDef + ProjectileMovementRegistry`，实体运动接入 `MovementDef + MovementRegistry`。

## 冻结协议与扩展

- 修改冻结语义须先获设计审批；新增 Mechanic family 须有 ADR。family 清单以 `CombatMechanic.ALLOWED_FAMILIES` 为准。
- 保留 `periodically` → `game.tick`、`when_damaged` → `entity.damaged`、`on_death` → `entity.died` 的触发语义，以及 `damage`、`spawn_projectile`、`explode` 的冻结效果协议。
- ProtocolValidator 的参数类型、边界和资源脚本检查不得绕过。
- 新扩展点统一走 `RegistryBase + RegistryConfig + ContributorDef`：定义 contributor Resource，接入 registry 和 `ExtensionPackCatalog.ALLOWED_REGISTER_KINDS`，添加 smoke/guardrail 场景并更新 Wiki。
- contributor 公共字段为 `id`、`tags`、`param_defs`；运行时代码 slot 要求 `trust_level = "trusted_runtime"`。
- 扩展包只能在已有 family 下新增 type，不能新增 family，也不能注册或覆盖 `core.*`。
- 默认不跨包 override；重复 ID 拒绝并记录 `protocol.issue`。

## 验证与交付

- 新增实体行为必须同时添加验证场景；索引与分层以 `tools/validation_scenarios.json` 为准。
- `.tres` 为 BattleScenario 配置；仅需自定义布局时补 `.tscn`，不要求每个场景都配对。
- 事件验证匹配事件名、标签、核心值及次数范围；保留 `validation_report.json`、`debug_logs.json`、`godot.log`、`engine.log` 和批次 summary。
- 批量默认并行度为 8；传入非正 `-MaxParallel` 时取 `min(CPU 核心数, 8)`。按机器负载降低并行度。
- 默认批次排除 `local_private`；私有包验证须显式选择该层并配置挂载。公开发布验证应能在无私有素材挂载时通过。
- 文档变更检查链接与文档健康输出；游戏变更合并前完成全量回归。静态、headless 与人工视觉验证分别记录，不互相代替。

## 按任务读取

| 任务 | 入口 |
|---|---|
| 初次进入 | [上手路径](../01-overview/03-15分钟上手路径.md)、[当前阶段](../01-overview/23-当前阶段与实现路线.md)、[架构总览](../01-overview/00-架构总览.md) |
| 运行时 | [编译链](../02-runtime-protocol/11-编译链与Mechanic系统.md)、[事件模型](../02-runtime-protocol/07-事件模型.md)、[连续行为](../02-runtime-protocol/08-连续行为模型.md) |
| 距离与时间 | [距离度量](../02-runtime-protocol/15-战斗距离与棋盘度量.md)、[仿真时间](../02-runtime-protocol/16-帧率与仿真时间.md)、[空间查询](../02-runtime-protocol/17-实体活跃性与空间查询.md) |
| 内容与验证 | [模板约定](35-模板编写约定.md)、[实体复刻](36-原版实体复刻工作流.md)、[验证工作流](../03-content-validation/12-完整工作流.md)、[验证矩阵](../03-content-validation/32-验证矩阵.md) |
| 扩展与素材 | [通用插槽](../04-roadmap-reference/42-通用扩展插槽机制.md)、[包边界](../04-roadmap-reference/43-扩展包边界与依赖规则.md)、[私有素材包](../04-roadmap-reference/44-素材包系统与本地私有包.md)、[Manifest](../04-roadmap-reference/45-扩展包Manifest规范.md) |
| 治理与决策 | [文档维护](29-文档规范与维护约定.md)、[ADR 索引](../decisions/README.md)、[完整 Wiki 索引](../index.md) |

## 工作区路径

`pvz-ws` 的主检出是只读基准，修改使用工作区分配的池槽。通过工作区根 `pvz-ws.config.json` 与 `pin.json` 定位第三方参考和外部工具，不能假定 worktree 上一级就是工作区根。参考镜像只读、固定版本、不参与构建；私有原始和派生素材不进入公开仓。任务领取、分别提交和槽收尾遵循工作区合同。
