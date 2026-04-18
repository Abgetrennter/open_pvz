# Open PVZ

`Open PVZ` 的主目标不是复刻原版《植物大战僵尸》，而是实现一个**开放、可组合、可扩展的 PVZ-like 规则引擎**。

这个引擎希望把“植物、僵尸、投射物、攻击、命中、死亡、轨迹、连锁”等机制拆解成更基础的语义与能力单元，从而支持：

- 自定义组合规则
- 加载外部扩展内容
- 重组原版或改版玩法
- 生成强组合、强叠加、强涌现的结果

其中，“错误技”不是与引擎并列的另一个方向，而是这个引擎当前最有辨识度、也最值得优先验证的一种能力表现。

## 项目定位

请把当前项目理解成三层：

1. **引擎层**  
   目标是定义一套可组合的规则运行时，包括事件语义、效果执行、实体组合、连续行为和扩展加载。

2. **内容层**  
   植物、僵尸、投射物、关卡模板、扩展包，都建立在引擎层之上。

3. **验证场景层**  
   “错误技系统”是当前优先实现的核心验证场景，用来证明这套引擎确实能支撑高自由度组合与涌现。

## 当前阶段

仓库当前已经完成**第一到第四阶段**，并且**第五阶段（错误技、扩展与工具期）核心起步已经收口**。当前主线正在转向第五阶段的 `v1` 规范化：把已跑通的错误技、扩展入口、扩展 effect 和回归体系收敛成可持续演进的稳定边界。

这意味着当前项目已经不再是“只有文档和原型骨架”，而是已经同时具备：

- 引擎主干：
  - 结构化事件链
  - 触发器与效果执行链
  - 实体运行时状态
  - 投射体连续行为与高度命中模型
- 内容与协议主链：
  - `EntityTemplate / ProjectileTemplate / TriggerBinding`
  - 规则协议白名单与守卫
  - 模板工厂与覆盖优先级
- 战斗玩法层：
  - 阳光与资源
  - 棋盘、占位与放置
  - 卡片、费用、冷却与手牌
  - 波次、战局阶段与胜负条件
  - 状态系统
  - 场上物件与机关
- 验证与展示：
  - 批量回归入口
  - 回归状态账本
  - Showcase Hub
  - 可运行的 Demo 关卡
- 第五阶段能力：
  - 错误技样例已进入统一回归
  - 扩展包 smoke test 已接入
  - 扩展 effect 家族与守卫专项已落地

当前最重要的工作已经不是“把最小事件链跑起来”，而是：

1. 收敛 `v1` 协议、模板和扩展包边界
2. 把验证体系拆成可维护的分层回归
3. 标准化内容接入、扩展包和调试工作流

## 当前项目现状

结合仓库当前实现，项目现状可以概括成下面 5 点：

### 1. 引擎主干已经稳定

当前已经有正式运行时主链：

```text
EventBus -> TriggerInstance / EffectExecutor -> Projectile or Damage -> EventBus
```

并且已经接入：

- `EventData`
- `RuleContext`
- `ProtocolValidator`
- `EntityFactory`
- `BaseEntity / PlantRoot / ZombieRoot / ProjectileRoot`

### 2. 战斗玩法闭环已经形成

第四阶段的核心系统已经全部进入主干，而不是继续停留在草案层：

- `BattleEconomyState`
- `BattleBoardState`
- `BattleCardState`
- `BattleFlowState`
- `BattleStatusState`
- `BattleFieldObjectState`

### 3. 仓库已经有可操作 Demo

当前项目默认启动场景是：

- `res://scenes/main/main.tscn`

它会进入 Showcase Hub，并可继续进入：

- `res://scenes/demo/demo_level.tscn`

这意味着仓库已经不只是“自动验证集合”，而是有一个可实际操作的最小 PvZ-like Demo。

### 4. 验证体系已经进入持续回归状态

当前仓库已经有：

- `tools/run_validation.ps1`
- `tools/run_all_validations.ps1`
- `tools/validation_scenarios.json`

当前批量回归清单已经覆盖 **46 个唯一验证场景 ID**，覆盖主干专项、第四阶段玩法层专项、第五阶段错误技专项、扩展包 smoke test、扩展 manifest 守卫专项和扩展 effect 守卫专项，并持续维护：

- `latest`
- `history`
- `per-scenario`

三类回归状态记录。

### 5. 第五阶段核心起步已经完成收口

当前仓库已经不只是“准备做错误技和扩展”，而是已经落地：

- 第一批和第二批错误技验证场景
- `extensions/minimal_chaos_pack` 最小扩展包 smoke test
- `extensions/phase5_chaos_pack` 扩展 effect 样例包
- `extensions/phase5_guardrail_pack` 扩展 effect 守卫包
- Showcase Hub 中的第五阶段错误技分组

因此下一步重点应从“继续证明能跑”转为“冻结边界、整理工作流、分层回归”。

## 文档结构

```text
plans/          规划稿、阶段总结与执行清单
plans/archive/  已完成阶段归档总览
wiki/           收敛后的结构化设计文档
├── index.md
├── 01-overview/
├── 02-runtime-protocol/
├── 03-content-validation/
├── 04-roadmap-reference/
└── 05-governance/
vendor/  外部参考实现子模块
```

推荐优先阅读：

1. [wiki/index.md](wiki/index.md)
2. [wiki/01-overview/23-当前阶段与实现路线.md](wiki/01-overview/23-当前阶段与实现路线.md)
3. [plans/第四阶段阶段总结.md](plans/第四阶段阶段总结.md)
4. [plans/第五阶段可执行任务清单.md](plans/第五阶段可执行任务清单.md)
5. [plans/第五阶段阶段总结.md](plans/第五阶段阶段总结.md)
6. [plans/第五阶段-v1现状盘点.md](plans/第五阶段-v1现状盘点.md)
7. [plans/第五阶段-v1协议冻结清单.md](plans/第五阶段-v1协议冻结清单.md)
8. [plans/第五阶段-v1回归分层方案.md](plans/第五阶段-v1回归分层方案.md)
9. [plans/第五阶段-v1内容工作流.md](plans/第五阶段-v1内容工作流.md)
10. [plans/第五阶段-主干编排收口计划.md](plans/第五阶段-主干编排收口计划.md)
11. [plans/第五阶段-外循环接口预留方案.md](plans/第五阶段-外循环接口预留方案.md)
12. [plans/第五阶段-v1规范化-4到8周执行路线图.md](plans/第五阶段-v1规范化-4到8周执行路线图.md)
13. [plans/archive/第一至第四阶段归档总览.md](plans/archive/第一至第四阶段归档总览.md)

## 参考实现

仓库中引入了一个参考子模块：

- `vendor/PVZ-Godot-Dream`

对应上游项目：

- [hsk-dream/PVZ-Godot-Dream](https://github.com/hsk-dream/PVZ-Godot-Dream)

这个子模块的作用是：

- 参考 Godot 下 PVZ 类项目的工程拆分
- 借鉴其事件总线、角色组件化、投射物移动组件等局部实现

它**不是**当前项目的直接代码基础。当前项目不会直接沿着其“原版复刻”主干继续开发，而是只提取适合规则引擎方向的实现经验。

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

当前仓库已经可以直接进入 Showcase Hub 和 Demo 场景进行验证与演示。

基础使用方式：

1. 安装 Godot 4.x
2. 拉取仓库和子模块
3. 用 Godot 打开项目目录
4. 运行默认主场景 `res://scenes/main/main.tscn`

如果你要跑自动化验证，可以直接使用：

```powershell
& ".\tools\run_validation.ps1"
```

或：

```powershell
& ".\tools\run_all_validations.ps1"
```

## 许可证

当前仓库许可证尚未最终确定。

需要注意的是，`vendor/PVZ-Godot-Dream` 子模块使用的是其上游项目自己的许可证，不等同于本仓库后续采用的许可证。
