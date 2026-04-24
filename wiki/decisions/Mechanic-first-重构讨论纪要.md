# Mechanic-first 重构讨论纪要

- 状态：历史归档


> 本文用于保存 `Mechanic-first` 路线的前置讨论结论。它不是正式 ADR，也不是最终协议文档，而是把已经讨论过、短期内不希望遗忘的共识集中整理下来。

---

## 1. 文档定位

这篇文档主要回答：

- 为什么当前项目会考虑从 `TriggerBinding-first` 转向 `Mechanic-first`
- `Mechanic` 在这里到底是什么意思，不是什么意思
- 我们目前已经讨论清楚了哪些边界
- `Mechanic-first` 与连续行为、随机效果、扩展包系统分别是什么关系

这篇文档不负责：

- 代替正式 ADR
- 代替未来的 `Mechanic` 协议正文
- 直接冻结字段和目录结构

对应的 ADR 输入清单见：

- [ADR 输入 - Mechanic-first 重构未决事项清单](ADR-输入-Mechanic-first-重构未决事项清单.md)

---

## 2. 背景

当前主仓已经形成了以：

- `EntityTemplate`
- `TriggerBinding`
- `ProjectileTemplate`
- `EffectDef`

为核心的模板与运行时主链。

这条链已经证明了很多东西：

- 事件驱动主干是成立的
- `Trigger + Effect` 的组合足以表达一批植物、僵尸和错误技样例
- 向日葵产阳光已经成功从经济子系统轮询迁移到触发器系统
- 扩展包和验证体系也已经有了基础落点

但在继续讨论“错误技自由组合植物系统”时，当前模型暴露出几个明显问题：

1. `TriggerBinding` 更像运行时装配件，不像顶层作者抽象。
2. 连续行为、生命周期、成长、接近触发、随机序列等能力很难自然落在 `TriggerBinding-first` 模型里。
3. 继续在旧模型上补丁，后续很容易形成越来越多的局部特判。

因此讨论逐步收敛到一个判断：

> 如果项目未来要真正以“高组合、可扩展、可随机生成的机制系统”为核心，顶层作者模型应提升为 `Archetype + Mechanic[]`。

---

## 3. 什么是 Mechanic

### 3.1 当前讨论中的定义

这里的 `Mechanic` 不是“一个具体植物技能成品”，也不是“一个运行时类名”。

当前更合适的定义是：

> `Mechanic` 是行为维度上的可替换模块。

也就是说，它表达的是：

- 某个植物/僵尸/投射物拥有哪些能力维度
- 这些维度如何组合
- 这些维度由什么运行时子系统承载

### 3.2 它不是什么

`Mechanic` 不是：

- 一个植物专属脚本
- 一个具体表现特例
- 一个简单数值字段
- 一个“把所有东西都再包一层”的万能字典

如果一个“机制”只服务一个具体单位、只是一个局部数值、或者只是某个实现分支的小差异，它通常不应该升格为一级 `Mechanic`。

---

## 4. 为什么不是“所有东西都改成触发器”

当前讨论已经明确了一条非常重要的边界：

> `Mechanic-first` 不是“万物触发器化”。

原因很直接：

- 离散事件和连续行为在项目哲学里本来就应该分离
- 有些行为天然适合 `Trigger + Effect`
- 有些行为天然属于持续状态机或空间运动模型

典型例子：

### 适合走触发器的

- 向日葵产阳光
- 受伤反击
- 死亡爆炸
- 放置后立即爆炸
- 命中后施加减速

这些属于“离散触发 -> 直接副作用”。

### 不适合强塞进触发器的

- 僵尸近战啃食
- 跳跃
- 扫掠
- 潜水
- 投射物飞行更新

这些属于“连续控制 / 连续状态机 / 连续空间更新”。

因此我们得出的结论是：

- `Trigger` 只是一级 family 之一
- 不是整个系统的唯一作者入口

---

## 5. Mechanic-first 的总体模型

当前讨论收敛出的新方向是：

```text
Archetype
  -> Mechanics[]
  -> Compiler
  -> RuntimeSpec
  -> Runtime Systems
```

其中：

- `Archetype` 是顶层作者资源
- `Mechanic[]` 是该 archetype 的能力组合
- `Compiler` 负责把高层机制编译成底层可执行规格
- `RuntimeSpec` 是编译后的稳定运行时规格
- 最终由多个运行时子系统共同消费

这个方向的核心判断是：

> 顶层作者抽象应该是“机制组合”，不是“触发绑定组合”。

---

## 6. 顶层不宜无限细分

关于 `Mechanic` 最重要的一轮讨论，不是“能不能继续拆”，而是“拆到什么层级必须停下来”。

当前形成的共识是：

> 只把“稳定复用的结构差异”提升为 `Mechanic`；纯参数差异、纯局部实现差异、纯视觉差异，不提升。

### 6.1 三层边界

我们已经把大多数能力差异收敛为三层：

- `一级 Mechanic`：行为维度
- `type`：该维度下的实现族
- `param`：该实现族的配置值

### 6.2 典型判断

#### 应该是一级 Mechanic

- `Trigger`
- `Targeting`
- `Emission`
- `Trajectory`
- `HitPolicy`
- `Payload`
- `State`
- `Lifecycle`
- `Placement`
- `Controller`

#### 应该是 `type`

- `Trajectory.linear`
- `Trajectory.parabola`
- `Trajectory.track`
- `Emission.single`
- `Emission.five_star`
- `Emission.shuffle_cycle`
- `Payload.damage`
- `Payload.explode`
- `Trigger.periodic`
- `Lifecycle.on_place`

#### 应该是 `param`

- `interval`
- `damage`
- `arc_height`
- `speed`
- `radius`
- `duration`
- `turn_rate`
- `pierce_count`

### 6.3 一条治理规则

当前讨论里已经明确倾向：

> 一级 family 应尽量少，新增能力优先走 `type`，最后才考虑新增一级 family。

---

## 7. 攻击系统拆分结论

攻击系统是当前讨论最多的一块，也最适合作为 `Mechanic-first` 的样板。

当前收敛出的拆分图是：

```text
AttackTrigger
  -> Targeting
  -> Emission
  -> Trajectory
  -> HitPolicy
  -> Payload
```

这条拆分链的核心价值在于：

- 把“什么时候攻击”
- “朝谁打”
- “一次发几个”
- “单个实例怎么飞”
- “怎么命中”
- “命中后做什么”

从一个混在一起的“攻击技能”里拆开。

### 7.1 关键澄清

#### 直射变抛射还能复用吗

能。

通常只需要替换：

- `Trajectory.type`

而不需要重做整套攻击机制。

#### 裂荚和杨桃是轨迹问题吗

不完全是。

- 裂荚更多是 `Emission` / `Targeting` 问题
- 杨桃很多情况下也是 `Emission` 的多方向发射拓扑问题
- 只有“单个投射物如何沿空间路径移动”才主要属于 `Trajectory`

#### 轨迹是否应该成为正式 Mechanic

如果项目未来明确要支持：

- 直线
- 抛物线
- 追踪
- 正弦
- Bezier
- 各类曲线轨迹

那么轨迹已经不应该只是小参数，而应提升为正式 family：`Trajectory`

---

## 8. 什么是“纯周期 + 纯副作用”

在讨论向日葵产阳光与僵尸啃食时，我们提到了“纯周期 + 纯副作用”。

这里的意思不是函数式编程里的“纯函数”，而是：

- 触发条件主要只依赖时间
- 触发后直接做一个动作
- 中间没有复杂持续状态机

典型例子：

- 每隔 N 秒产一份阳光
- 每隔 N 秒召唤一个单位
- 每隔 N 秒对周围敌人施加一次光环效果

这类行为很适合：

`Trigger(periodic) -> Payload(effect)`

相反，僵尸啃食这类“扫描目标、停步、进入攻击态、冷却、被状态阻断”的行为，不属于这个范畴。

---

## 9. 错误技植物的自动生成结论

关于“错误技植物如何自动生成”，当前讨论已经形成一个比较稳定的流程：

```text
底盘 / Chassis
  -> 开槽位 / Slots
  -> 按权重抽取 Mechanics
  -> 冲突检查与预算归一化
  -> 编译为 RuntimeSpec
  -> 实例化到战场并运行
```

关键点包括：

### 9.1 先生成合法 Mechanic 组合

不是直接随机拼触发器，也不是直接随机拼 effect。

而是先从：

- chassis
- slot budget
- compatibility rules
- weighting rules

中生成一组合法的 `Mechanic[]`。

### 9.2 再编译成运行时规格

生成出的高层机制会编译成：

- `RuleSpec`
- `ProjectileSpec`
- `StateSpec`
- `ControllerSpec`
- `LifecycleSpec`

### 9.3 运行时由多个子系统共同消费

因此，错误技植物不是一个“专属脚本植物”，而是一份组合程序的运行结果。

---

## 10. 经典随机效果的建模结论

关于“乱序发射所有抛射物”这类经典随机效果，我们已经明确了一个重要判断：

> 这不是简单的 `chance` 参数，而是一个带持久状态的发射序列机制。

当前讨论倾向的建模方式是：

- `ProjectilePool`
- `Emission.type = shuffle_cycle`
- `mechanic-local runtime state`

### 10.1 为什么不是纯随机抽一个

如果只是每次攻击随机选一个：

- 不能保证遍历整个池子
- 容易连续重复
- 没有“乱序轮转”的经典体感

### 10.2 更接近目标的语义

真正接近经典效果的是：

1. 取一个抛射物池
2. 洗牌
3. 逐个发射
4. 发完一轮后重新洗牌

也就是典型的 `shuffle bag / shuffled cycle`。

### 10.3 为什么它需要 mechanic-local runtime state

因为运行时必须记住：

- 当前 bag
- 当前 index
- 当前 cycle
- 可能还包括 burst queue

所以这类机制不能只靠一次性 effect 表达。

### 10.4 随机必须可复现

当前讨论明确倾向：

- 随机应该走确定性 seed
- 便于验证、回放、调试、bug 复现

---

## 11. 扩展包系统的结合结论

关于 `Mechanic-first` 如何与扩展包结合，当前已经有较清晰的方向：

### 11.1 扩展包不再主要面向 TriggerBinding

扩展包应优先面向：

- `Archetype`
- `MechanicSet`
- family 下的 `type`
- 必要时运行时代码扩展

### 11.2 建议的扩展层级

当前讨论里建议的包能力层级是：

- `content_pack`
- `rule_pack`
- `runtime_pack`
- `asset_pack`
- `collection_pack`

以及信任级别：

- `data_only`
- `rule_extended`
- `trusted_runtime`

### 11.3 关键治理原则

当前讨论已经非常明确地倾向：

- 扩展包默认只能新增 `type`
- 一级 family 由主仓冻结和治理
- 新 family 不应由扩展包随意定义

### 11.4 注册中心需要升级

如果走 `Mechanic-first`，当前以：

- `TriggerRegistry`
- `EffectRegistry`
- `DetectionRegistry`

为主的注册方式，需要升级为更高层的：

- `MechanicFamilyRegistry`
- `MechanicTypeRegistry`
- `MechanicCompilerRegistry`
- `ControllerRegistry`

---

## 12. 当前已经形成的高层推荐方向

截至本次讨论，已经形成的高层推荐方向可以压成下面 8 条：

1. 项目若要真正承载错误技自由组合，应考虑从 `TriggerBinding-first` 切换到 `Mechanic-first`。
2. 顶层作者抽象应提升为 `Archetype + Mechanic[]`。
3. 连续行为、生命周期、状态阶段必须成为正式能力位，不能全部硬塞进触发器。
4. 一级 family 必须尽早冻结，避免无限膨胀。
5. 新能力优先新增 `type`，而不是新增一级 family。
6. 随机效果必须走确定性随机，并允许 mechanic-local runtime state。
7. 扩展包默认只允许新增 `type`，高信任包才允许新增运行时代码。
8. 架构上更合理的方向是“保留底层执行骨架，重做顶层作者模型和编译链”。

---

## 13. 当前仍未拍板的地方

虽然这份文档保存的是“已讨论过的内容”，但也需要明确：并不是所有事情都已经决定了。

仍需进入正式 ADR 的核心未决项包括：

- 是否正式切换主路线
- 重构范围到底有多大
- 顶层作者模型是否彻底替换旧模型
- Compiler / RuntimeSpec 的精确形态
- 一级 family 的正式冻结版本
- Controller / State / Lifecycle 的正式协议
- 扩展包注册和信任边界
- 迁移策略和首批验证闭环

这些内容请转到：

- [ADR 输入 - Mechanic-first 重构未决事项清单](ADR-输入-Mechanic-first-重构未决事项清单.md)

---

## 14. 建议的后续文档关系

如果后续正式推进，建议文档体系形成下面的结构：

1. **讨论纪要**
   - 保存本次对话里已经形成的非正式共识
2. **ADR 输入**
   - 提炼出必须拍板的决策项
3. **正式 ADR**
   - 对具体问题逐条做出项目级决定
4. **正式协议文档**
   - 把拍板后的结果写成实现规范

这篇文档对应的是第 1 层。

---

## 15. 结语

当前这轮讨论最重要的成果，不是又多创造了几个术语，而是把一个容易继续发散的方向，逐步压缩成了一组更明确的边界：

- 什么该是 `Mechanic`
- 什么不该是 `Mechanic`
- 为什么 `TriggerBinding-first` 不是终态
- 为什么连续行为不能被忽略
- 为什么随机效果和扩展包都需要更高层的正式抽象

因此，这篇纪要的价值不在于它“已经定案”，而在于它保留了：

- 为什么会想到 `Mechanic-first`
- 当前已经形成了哪些判断
- 后续 ADR 应该站在什么基础上继续推进
