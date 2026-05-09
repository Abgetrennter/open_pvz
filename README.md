# Open PVZ

`Open PVZ` 的主目标不是复刻原版《植物大战僵尸》，而是实现一个**开放、可组合、可扩展的 PVZ-like 规则引擎**。

这个引擎希望把"植物、僵尸、投射物、攻击、命中、死亡、轨迹、连锁"等机制拆解成更基础的语义与能力单元，从而支持：

- 自定义组合规则
- 加载外部扩展内容
- 重组原版或改版玩法
- 生成强组合、强叠加、强涌现的结果

其中，"错误技"不是与引擎并列的另一个方向，而是这个引擎当前最有辨识度、也最值得优先验证的一种能力表现。

## 项目定位

请把当前项目理解成三层：

1. **引擎层**
   目标是定义一套可组合的规则运行时，包括事件语义、效果执行、实体组合、连续行为和扩展加载。

2. **内容层**
   植物、僵尸、投射物、关卡模板、扩展包，都建立在引擎层之上。

3. **验证场景层**
   "错误技系统"是当前优先实现的核心验证场景，用来证明这套引擎确实能支撑高自由度组合与涌现。

## 架构总览

### 四层模型

1. **语义事件层** — "发生了什么"。事件如 `game.tick`、`entity.damaged`、`entity.died`、`projectile.hit` 通过 `EventBus`（autoload）流转。
2. **行为效果层** — "该做什么"。`EffectDef` -> `EffectNode`，由 `EffectExecutor` 执行。效果是原子化、可组合、可嵌套的。注册于 `EffectRegistry`。
3. **编译装配层** — "实体如何编译和组装"。`CombatArchetype` + `CombatMechanic[]` -> `MechanicCompiler` -> `RuntimeSpec` -> `EntityFactory` 实例化。10 个冻结 Mechanic family。注册于 `MechanicFamilyRegistry` / `MechanicTypeRegistry` / `MechanicCompilerRegistry`。
4. **连续行为层** — "持续对象如何更新"。抛射体使用 3D 逻辑 + 2D 投影；Controller 通过 `ControllerComponent` 每帧执行。

### 执行链

**离散事件链**：
```
EventBus -> TriggerComponent -> TriggerInstance -> RuleContext -> EffectExecutor -> Runtime Action -> EventBus
```

**编译链**（实例化时运行一次）：
```
Archetype + Mechanic[] -> NormalizedMechanicSet -> RuntimeSpec -> EntityFactory -> Runtime Nodes
```

**连续行为链**（每帧）：
```
_physics_process -> ControllerComponent -> ControllerRegistry -> Controller Strategy
```

### 全局单例 (Autoloads)

| 单例名 | 职责 |
|--------|------|
| `EventBus` | 事件分发，优先级订阅，历史追踪 |
| `DebugService` | 集中式日志：事件/触发器/效果/运行时快照/协议问题 |
| `SceneRegistry` | 场景与资源注册表，自动扫描 `data/combat/` |
| `MechanicFamilyRegistry` | Mechanic 一级 family 注册（10 个冻结 family） |
| `MechanicTypeRegistry` | Mechanic type 注册（family 下的具体 type_id） |
| `MechanicCompilerRegistry` | Mechanic per-type 编译器 callable 注册与分发 |
| `DetectionRegistry` | 目标发现策略注册 |
| `TriggerRegistry` | 触发器定义与策略注册 |
| `EffectRegistry` | 效果定义与策略注册 |
| `ControllerRegistry` | Controller 策略注册 |
| `ProjectileMovementRegistry` | 抛射体 movement 定义注册与组件创建 |
| `GameState` | 游戏状态管理（当前战斗、时间、实体 ID 分配、battle_seed） |
| `VisualCueRegistry` | 视觉提示注册 |
| `VisualFxRegistry` | 视觉特效注册 |
| `AudioCueRegistry` | 音频提示注册 |
| `VisualProfileRegistry` | 视觉外观档案注册 |

所有 registry 统一继承 `RegistryBase`（位于 `scripts/core/registry/`），共享注册、去重、信任检查、来源追踪和协议错误记录逻辑。

## 当前阶段

仓库已完成 **Mechanic-first 重构三阶段**，实体旧作者模型已归档，通用扩展插槽 v1 已落地，战斗模式组织层 v1 已进入可验证基线，视觉反馈层骨架已合入主干。

更准确地说，当前状态是：

- 引擎主干、Mechanic-first 主链和战斗玩法层已经稳定落地
- Mechanic family 已冻结为 10 个：`Trigger / Targeting / Emission / Trajectory / HitPolicy / Payload / State / Lifecycle / Placement / Controller`
- 通用扩展插槽 v1 已落地：所有 registry 统一继承 `RegistryBase`，开放 slot 包括 `projectile_movement`、`mechanic_compilers`、`effects`、`triggers`、`detections`、`controllers`
- 战斗模式组织层 v1 已落地：`BattleModeHost / BattleModeDef / BattleRuleModule / BattleInputProfile / BattleObjectiveDef`
- 视觉反馈层骨架已合入：`VisualCueRegistry / VisualFxRegistry / AudioCueRegistry / VisualProfileRegistry` + `scripts/visual/` 运行时
- 实体替换/升级系统已落地
- 爆发间隔发射已支持：Emission mechanic 支持 burst interval 配置
- 错误技、扩展入口、扩展 effect 家族与守卫体系已经完成核心收口
- 主线已进入"archetype-only 内容与回归同步"阶段

这意味着当前项目已经同时具备：

- 引擎主干：
  - 结构化事件链
  - 触发器与效果执行链
  - 实体运行时状态
  - 投射体连续行为与高度命中模型
  - 统一 Registry 注册体系（`RegistryBase` + `RegistryConfig` + `RegistryContributorDef`）
  - 视觉反馈层骨架（cue / fx / audio / profile 四个注册表 + 运行时分发）
- 内容与协议主链：
  - `CombatArchetype + CombatMechanic[] -> RuntimeSpec -> EntityFactory`（唯一正式入口）
  - 规则协议白名单与守卫
  - 10 个冻结 Mechanic family，大量内置 type
  - 扩展包可通过 `MechanicCompilerDef` 在冻结 family 下新增 type
- 战斗玩法层：
  - 阳光与资源
  - 棋盘、占位与放置（含数据驱动放置验证与实体替换/升级）
  - 卡片、费用、冷却与手牌
  - 波次、战局阶段与胜负条件
  - 状态系统
  - 场上物件与机关
  - 战斗模式组织层（mode 定义、输入能力、规则模块、胜负条件）
- 内容与发射系统：
  - 大量 archetype（plants / zombies / field_objects）
  - 战斗数据资源（.tres）
  - 爆发间隔发射（burst interval）
  - 原版植物迁移展示
- 验证与展示：
  - 验证场景（smoke / core / extension / guardrail / showcase 分层）
  - 批量回归入口（支持受控并行）
  - Showcase 场景（含原版植物花园展示）
  - 可运行的 Demo 关卡
- 扩展体系：
  - 扩展包（样例、守卫、探测等）
  - 扩展包 smoke / chaos / guardrail 已进入稳定回归
  - `core.*` 由主仓独占，扩展包不得覆盖

## 当前项目现状

结合仓库当前实现，项目现状可以概括如下：

### 1. 引擎主干已经稳定

当前已经有正式运行时主链：

```text
EventBus -> TriggerInstance / EffectExecutor -> Projectile or Damage -> EventBus
```

并且已经接入：

- `EventData`、`RuleContext`、`ProtocolValidator`
- `EntityFactory`（archetype-only 入口）
- `BaseEntity / PlantRoot / ZombieRoot / ProjectileRoot`

### 2. 编译链与 Mechanic 系统已经完成三阶段重构

- 第一阶段：完成 archetype 入口、编译链骨架和首批 archetype 闭环
- 第二阶段：完成 `Controller / State / Lifecycle` 的最小正式路径
- 第三阶段：完成多 payload、per-type dispatch、确定性随机、独立实例化与迁移对照验证

### 3. 战斗玩法闭环已经形成

核心战斗子系统已经全部进入主干：

- `BattleEconomyState` — 阳光资源管理、天降阳光、消费验证
- `BattleBoardState` — 格子系统、放置验证、槽位类型/标签、实体替换/升级
- `BattleCardState` — 卡片手牌、费用消耗、冷却管理、放置请求
- `BattleFlowState` — 战斗阶段管理（preparing / running / victory / defeat）
- `BattleFieldObjectState` — 场上物件生成、管理、事件发射
- `BattleModeHost` — 模式运行时宿主：解析 mode_def、合并 override、驱动规则模块、评估目标

### 4. 通用扩展插槽 v1 已经落地

所有 registry 统一继承 `RegistryBase`，已开放 slot：

| Slot | Registry | 说明 |
|------|----------|------|
| `projectile_movement` | `ProjectileMovementRegistry` | linear / parabola / track |
| `mechanic_compilers` | `MechanicCompilerRegistry` | 扩展包可在冻结 family 下新增 type |
| `effects` | `EffectRegistry` | 保留现有成熟路径 |
| `triggers` | `TriggerRegistry` | 支持 strategy_script 注册 |
| `detections` | `DetectionRegistry` | 支持 strategy_script 注册 |
| `controllers` | `ControllerRegistry` | 支持 strategy_script 注册 |

### 5. 视觉反馈层骨架已合入

视觉反馈层采用与游戏 registry 一致的注册模式：

| Registry | 职责 |
|----------|------|
| `VisualCueRegistry` | 视觉提示注册 |
| `VisualFxRegistry` | 视觉特效注册 |
| `AudioCueRegistry` | 音频提示注册 |
| `VisualProfileRegistry` | 角色视觉外观档案注册 |

运行时组件：`scripts/visual/` 下的 `VisualFeedbackHost`、`VisualActionRunner`、`VisualStageLayerService`、`VisualLayerPolicy`。

### 6. 内容基线已经形成

- Archetype 资源覆盖 plants / zombies / field_objects
- 战斗数据资源（.tres）：archetype、投射物模板、飞行配置、卡片、波次等
- 第一轮正式交互矩阵、正式战场语义、正式波次 / 关卡模板集
- 原版植物迁移展示

### 7. 验证体系已经进入持续回归状态

- `tools/run_validation.ps1` — 单场景验证
- `tools/run_all_validations.ps1` — 批量验证（支持 `-MaxParallel` 受控并行）
- `tools/validation_scenarios.json` — 验证场景定义，分层：smoke / core / extension / guardrail / showcase

### 8. 仓库已经有可操作 Demo

当前项目默认启动场景是 `res://scenes/main/main.tscn`，进入 Showcase Hub 后可浏览展示场景和 Demo 关卡。

## 模块结构

```text
autoload/                 全局单例（EventBus、各 Registry、GameState、视觉/音频 Registry 等）
scripts/core/defs/        资源定义（Archetype, Mechanic, TriggerDef, EffectDef 等）
scripts/core/registry/    统一注册体系基类（RegistryBase, RegistryConfig, RegistryContributorDef）
scripts/core/runtime/     运行时（MechanicCompiler, RuntimeSpec, EffectExecutor 等）
scripts/battle/           战斗协调（BattleManager, EntityFactory, 各子系统, 模式层, 升级替换）
scripts/entities/         实体类型（BaseEntity, PlantRoot, ZombieRoot, ProjectileRoot）
scripts/components/       可复用组件（HealthComponent, TriggerComponent, ControllerComponent 等）
scripts/projectile/       抛射体运动系统（linear / parabola / track）
scripts/visual/           视觉反馈运行时（VisualFeedbackHost, VisualActionRunner, StageLayerService, LayerPolicy）
scripts/debug/            调试覆盖层
data/combat/              战斗数据资源（.tres）
  archetypes/             Archetype 资源（plants / zombies / field_objects）
  projectile_templates/   投射物模板
scenes/validation/        自动化验证场景资源
scenes/showcase/          展示场景
extensions/               扩展包（样例、守卫、探测等）
tools/                    验证运行工具（PowerShell）
wiki/                     中文设计文档
vendor/                   参考实现（PVZ-Godot-Dream），不属于引擎核心
```

## 文档结构

```text
wiki/                    结构化设计文档
├── 01-overview/         架构、设计哲学、当前阶段
├── 02-runtime-protocol/ 编译链、触发器、效果、执行机制、战斗模式组织层
├── 03-content-validation/ 验证矩阵和覆盖率
├── 04-roadmap-reference/ 参考实现、扩展系统规划、通用扩展插槽机制
├── 05-governance/        Archetype 编写约定、术语表、方法论
├── decisions/            ADR 决策记录（ADR-001 ~ ADR-007+）
plans/                   规划稿、阶段总结与执行清单
plans/archive/           已完成阶段归档总览
plans/draft/             未来方向草案
vendor/                  外部参考实现子模块
```

推荐优先阅读：

1. [wiki/index.md](wiki/index.md) — Wiki 导航入口
2. [wiki/01-overview/23-当前阶段与实现路线.md](wiki/01-overview/23-当前阶段与实现路线.md) — 唯一状态快照页
3. [wiki/01-overview/00-架构总览.md](wiki/01-overview/00-架构总览.md) — 架构总览
4. [wiki/02-runtime-protocol/11-编译链与Mechanic系统.md](wiki/02-runtime-protocol/11-编译链与Mechanic系统.md) — 编译链详解
5. [wiki/02-runtime-protocol/14-战斗模式组织层.md](wiki/02-runtime-protocol/14-战斗模式组织层.md) — 战斗模式组织层
6. [wiki/04-roadmap-reference/42-通用扩展插槽机制.md](wiki/04-roadmap-reference/42-通用扩展插槽机制.md) — 通用扩展插槽
7. [wiki/decisions/README.md](wiki/decisions/README.md) — ADR 决策记录索引

## 冻结协议

第一轮协议冻结已生效。未经设计审批，不得修改以下语义：

- **Mechanic family**（10 个冻结，新增需 ADR）：Trigger / Targeting / Emission / Trajectory / HitPolicy / Payload / State / Lifecycle / Placement / Controller
- **触发器**：`periodically`、`when_damaged`、`on_death`
- **效果**：`damage`、`spawn_projectile`、`explode`

`ProtocolValidator` 在运行时强制执行参数类型、边界和资源脚本类型检查。

## 编码规范

- 所有游戏定义使用 Godot `Resource`（.tres），不使用 JSON 或外部格式
- 一个类一个文件；数据定义继承 `Resource`
- Archetype 编写顺序：Identity -> Chassis -> Combat Stats -> Mechanic[]
- Archetype 命名：`plant_role_variant`、`zombie_role_variant`
- Mechanic 命名：`family.type_id` 格式
- 事件命名：点分隔语义名（`game.tick`、`entity.damaged`、`entity.died`）
- PascalCase 用于类名，snake_case 用于变量/函数
- StringName 用于驻留标识符，RefCounted 用于系统间传递数据

## 参考实现

仓库中引入了一个参考子模块：

- `vendor/PVZ-Godot-Dream`

对应上游项目：

- [hsk-dream/PVZ-Godot-Dream](https://github.com/hsk-dream/PVZ-Godot-Dream)

这个子模块的作用是：

- 参考 Godot 下 PVZ 类项目的工程拆分
- 借鉴其事件总线、角色组件化、投射物移动组件等局部实现

它**不是**当前项目的直接代码基础。当前项目不会直接沿着其"原版复刻"主干继续开发，而是只提取适合规则引擎方向的实现经验。

## 获取项目

如果你需要连同参考子模块一起拉取：

```bash
git clone --recursive <repo-url>
```

如果已经 clone 但还没初始化子模块：

```bash
git submodule update --init --recursive
```

## 运行方式

### 在 Godot 编辑器中运行

1. 安装 Godot 4.x
2. 拉取仓库和子模块
3. 用 Godot 打开项目目录
4. 运行默认主场景 `res://scenes/main/main.tscn`

运行单个验证场景：打开 `scenes/validation/` 中的 `.tscn` 文件并按 F6。

### 自动化验证

```powershell
# 运行所有验证场景
pwsh tools/run_all_validations.ps1

# 控制并行度（默认自动取 min(CPU核心数, 4)）
pwsh tools/run_all_validations.ps1 -MaxParallel 4

# 运行单个场景
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/<scenario>.tres"
```

验证场景定义：`tools/validation_scenarios.json`
验证结果输出：`artifacts/validation/`

## 许可证

当前仓库许可证尚未最终确定。

需要注意的是，`vendor/PVZ-Godot-Dream` 子模块使用的是其上游项目自己的许可证，不等同于本仓库后续采用的许可证。
