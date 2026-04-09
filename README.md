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

仓库当前仍处于**文档收敛 + 原型骨架搭建期**。

当前最重要的不是 GUI、编辑器或完整内容量，而是先跑通一条最小闭环：

1. 实体进入战场
2. 事件被广播
3. 触发器命中条件
4. 效果被执行
5. 生成投射物或直接造成伤害
6. 命中后继续触发后续事件

只要这条链稳定，后面的错误技生成、扩展加载和编辑器才有真实落点。

## 当前设计共识

结合现有设计稿和参考实现，当前已经形成下面这些共识：

- 项目的北极星仍然是“开放式 PVZ-like 规则引擎”
- 错误技是引擎的旗舰验证能力，不是项目的全部定义
- 第一阶段优先用 Godot 原生节点、组件和 `Autoload` 搭运行时
- 不在第一阶段就押注完整 ECS 化
- 定义层第一阶段优先使用 Godot `Resource`
- 投射物系统优先采用“根节点 + MovementComponent”
- 调试能力必须作为第一阶段正式需求

## 当前建议的核心抽象

引擎层当前建议围绕以下抽象推进：

- **Event / Context**
  - 定义发生了什么，以及一次事件链中的共享语义数据
- **Effect**
  - 最小行为单元，可组合、可排序、可嵌套
- **Entity Template**
  - 用基础能力和组件组合出植物、僵尸、投射物等实体
- **Continuous Simulation**
  - 处理投射物与持续运动，不依赖离散事件补丁式修补
- **Extension Pack**
  - 加载自定义效果、模板、轨迹、资源

错误技相关的当前重点实现则是：

- 触发器系统
- 效果树
- 随机生成器
- 命中连锁
- 基于规则组合产生的非常规行为

## 当前推荐的 Godot 骨架

第一阶段更适合的落地形式大致如下：

```text
Autoload
├── EventBus
├── DebugService
└── SceneRegistry

Battle
├── BattleManager
└── EntityFactory

PlantRoot
├── TriggerComponent
├── HealthComponent
└── DebugViewComponent

ZombieRoot
├── HealthComponent
└── StateComponent

ProjectileRoot
├── HitboxComponent
├── MovementComponent
└── ProjectileRuntime
```

核心执行链：

```text
EventBus -> TriggerInstance / EffectExecutor -> Projectile or Damage -> EventBus
```

## 第一阶段范围

第一阶段不追求“大而全”，只追求引擎主干可用。

建议范围：

- 事件：
  - `game.tick`
  - `entity.damaged`
  - `projectile.hit`
  - `entity.died`
- 基础效果：
  - `damage`
  - `spawn_projectile`
  - `explode`
- 基础触发：
  - 周期触发
  - 受伤触发
  - 死亡触发
- 连续行为：
  - 直线移动
  - 一种附加贡献项轨迹
- 调试能力：
  - 事件日志
  - 效果执行顺序
  - 连锁深度
  - 实体状态快照

当前明确不优先：

- 完整 ECS 架构
- 高级渲染管线
- 可视化编辑器
- 社区工坊式生态
- 大规模 GUI 包装

## 文档结构

```text
plans/   原始设计稿与整合稿
wiki/    收敛后的结构化设计文档
vendor/  外部参考实现子模块
```

推荐优先阅读：

1. [plans/pvz_like_engine_design_doc_v_1.md](plans/pvz_like_engine_design_doc_v_1.md)
2. [wiki/index.md](wiki/index.md)
3. [wiki/00-核心架构总览.md](wiki/00-核心架构总览.md)
4. [wiki/23-当前阶段与实现路线.md](wiki/23-当前阶段与实现路线.md)

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

当前仓库主要用于设计整理和原型准备。

基础使用方式：

1. 安装 Godot 4.x
2. 拉取仓库和子模块
3. 用 Godot 打开项目目录

README 不承诺当前仓库已经存在完整可玩的游戏循环；它只描述项目当前收敛后的真实目标和推进方式。

## 许可证

当前仓库许可证尚未最终确定。

需要注意的是，`vendor/PVZ-Godot-Dream` 子模块使用的是其上游项目自己的许可证，不等同于本仓库后续采用的许可证。
