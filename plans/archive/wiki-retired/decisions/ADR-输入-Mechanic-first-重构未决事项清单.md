# ADR 输入 - Mechanic-first 重构未决事项清单

- 状态：已归档（正式 ADR 已落地，主线实现已切主）
- 日期：2026-04-21
- 作者：Codex / Abget
- 关联阶段：路线切换评估
- 旧路线归档分支：`codex/archive-triggerbinding-first`
- 关联文档：
  - [架构总览](../01-overview/00-架构总览.md)
  - [核心设计哲学](../01-overview/01-核心设计哲学.md)
  - [当前阶段与实现路线](../01-overview/23-当前阶段与实现路线.md)
  - [触发器系统](../02-runtime-protocol/03-触发器系统.md)
  - [效果系统](../02-runtime-protocol/04-效果系统.md)
  - [执行机制](../02-runtime-protocol/06-执行机制.md)
  - [连续行为模型](../02-runtime-protocol/08-连续行为模型.md)
  - [编译链与 Mechanic 系统](../02-runtime-protocol/11-编译链与Mechanic系统.md)
  - [扩展系统总体规划](../04-roadmap-reference/38-扩展系统总体规划.md)
  - [原版实体复刻工作流](../05-governance/36-原版实体复刻工作流.md)
  - [重大决策记录模板](../05-governance/31-重大决策记录模板.md)

## 1. 文档目的

这不是最终 ADR，也不是实现方案正文。

这份文档最初的目标是把当前 `Mechanic-first` 重构讨论中**仍然需要拍板的事项**收敛成一份 ADR 输入清单，避免后续讨论继续停留在抽象概念层。

当前已经形成的高层共识包括：

- 项目主目标仍然是“开放规则引擎”，错误技是验证表达力的重要场景，而不是唯一产品目标。
- 仅以 `TriggerBinding` 为中心的作者模型难以承载未来的连续行为、生命周期、随机序列和扩展包能力。
- 顶层作者抽象更适合提升为 `Archetype + Mechanic[]`。
- 离散事件与连续行为必须继续分离，不能把所有能力都压进触发器。
- 扩展包如果继续存在，应更多面向 `Mechanic` 层，而不是直接面向 `TriggerBinding`。

本清单只回答一个问题：

> 如果主线决定切换到 `Mechanic-first`，还有哪些关键事项必须先做 ADR 级决策？

截至 2026-04-21 晚间，这份清单中的核心议题已经拆分并回写为正式 ADR：

- [ADR-001 路线切换与重构范围](ADR-001-路线切换与重构范围.md)
- [ADR-002 顶层作者模型与编译链](ADR-002-顶层作者模型与编译链.md)
- [ADR-003 Mechanic 一级家族冻结](ADR-003-Mechanic-一级家族冻结.md)
- [ADR-004 连续行为、状态与生命周期正式化](ADR-004-连续行为-状态与生命周期正式化.md)
- [ADR-005 扩展包接入与迁移策略](ADR-005-扩展包接入与迁移策略.md)

因此，这份文档现在的定位更接近：

- 决策输入归档
- ADR 目录导航
- 讨论到正式决策之间的桥接记录

截至 2026-04-22，代码主线已经完成到下面这个实际状态：

- `Archetype + Mechanic[]` 已经成为主线作者入口，`cards / waves / levels / validation / showcase / extensions` 都已补齐 `archetype_id` 主路径。
- 扩展包迁移已打通，`minimal_chaos_pack`、`phase5_chaos_pack`、`phase5_guardrail_pack` 的正式验证均可通过新主链运行。
- 运行时桥接与装配链已经落地到：
  - `CombatContentResolver`
  - `EntityFactory`
  - `BattleSpawner`
  - `BattleCardState`
  - `BattleBoardState`
- 当前整仓批量验证已全绿：
  - `tools/run_all_validations.ps1`
  - `66 / 66 passed`
- 旧 `EntityTemplate / TriggerBinding` **尚未物理删除**，但已经降级为：
  - legacy 兼容层
  - 后端素材
  - 迁移对照验证入口

也就是说，这份文档中的“未决事项”已经不再对应当前主线的真实状态；当前仓库状态更接近：

- 逻辑上已经切主
- 工程上仍保留有限兼容层
- 是否进一步“物理删除旧入口资源与兼容代码”将是新的收尾决策，而不是本清单里的原始未决问题

---

## 2. 未决事项总览

| ID | 议题 | 优先级 | 当前推荐方向 |
|----|------|--------|--------------|
| D1 | 是否正式切换主路线 | P0 | 已决定：切换主路线，进入重构阶段 |
| D2 | 重构范围边界 | P0 | 已决定：保留底层运行时骨架，重做上层作者模型与装配编译链 |
| D3 | 顶层作者模型替换方式 | P0 | 已决定：见 [ADR-002](ADR-002-顶层作者模型与编译链.md) |
| D4 | Compiler / RuntimeSpec 形态 | P0 | 已决定：见 [ADR-002](ADR-002-顶层作者模型与编译链.md) |
| D5 | 一级 Mechanic 家族冻结 | P0 | 已决定：见 [ADR-003](ADR-003-Mechanic-一级家族冻结.md) |
| D6 | Continuous Controller 正式化 | P1 | 已决定：见 [ADR-004](ADR-004-连续行为-状态与生命周期正式化.md) |
| D7 | State / Lifecycle 正式关系 | P1 | 已决定：见 [ADR-004](ADR-004-连续行为-状态与生命周期正式化.md) |
| D8 | 随机与机制私有状态协议 | P1 | 已决定：见 [ADR-004](ADR-004-连续行为-状态与生命周期正式化.md) |
| D9 | 扩展包注册与信任边界 | P1 | 已决定：见 [ADR-005](ADR-005-扩展包接入与迁移策略.md) |
| D10 | 迁移策略与验证闭环 | P1 | 已决定：见 [ADR-005](ADR-005-扩展包接入与迁移策略.md) |

### 当前实施状态补充

| 项目 | 当前状态 | 说明 |
|----|----|----|
| 主线作者入口 | 已切主 | 主线内容入口已切到 `Archetype + Mechanic[]` |
| 运行时编译链 | 已落地 | `Archetype -> RuntimeSpec -> RuntimeAssembler/Factory` 已接通 |
| 扩展包迁移 | 已完成主线迁移 | 现有正式扩展包已能通过新主链验证 |
| showcase / validation | 已切主 | 主页面与正式验证已以 archetype-first 为主 |
| 旧作者入口 | 未物理删除 | 仅作为 legacy 兼容层 / 后端素材继续存在 |
| 整仓回归 | 已通过 | `run_all_validations.ps1` 当前为 `66 / 66 passed` |

---

## 3. D1 - 是否正式切换主路线

> 当前状态：**已决定**

### 问题

当前 wiki 的主叙事仍然是“第七阶段输入准备”，重点是继续扩展正式内容与关卡：

- [当前阶段与实现路线](../01-overview/23-当前阶段与实现路线.md)
- [开发路线图](../04-roadmap-reference/26-开发路线图.md)

而 `Mechanic-first` 重构意味着：

- 主线不再是“继续加厚内容”
- 主线变成“重新定义顶层作者模型和装配链”

这已经不是局部改造，而是路线切换。

### 备选方案

#### 方案 A：保持当前路线不变

- 继续按第七阶段口径推进
- `Mechanic-first` 仅作为远期草案

优点：

- 不打断当前内容生产
- 风险最低

缺点：

- 会继续在旧作者模型上堆内容
- 后续重构成本更高

#### 方案 B：切换主路线，进入重构阶段

- 主线从“加内容”切到“重构架构”
- 旧路线留档，主分支进入新架构探索

优点：

- 能在资产规模进一步膨胀前完成抽象纠偏
- 不再被 `TriggerBinding-first` 绑架

缺点：

- 短期会显著降低新增内容速度
- 需要同步修正文档主叙事

### 已决定内容

选择 **方案 B：切换主路线，进入重构阶段**。

当前决定的落点包括：

- “第七阶段输入准备”不再作为当前主线叙事继续推进
- 当前主线切换为 `Mechanic-first` 重构准备 / 实施
- 旧路线已通过分支 `codex/archive-triggerbinding-first` 归档
- 本决策将由正式 ADR 沉淀为：
  - [ADR-001 路线切换与重构范围](ADR-001-路线切换与重构范围.md)

### 还需补证

- 是否允许在重构期间继续接受少量主仓内容变更
- 是否需要建立单独的“重构看板 / 里程碑文档”

---

## 4. D2 - 重构范围边界

> 当前状态：**已决定**

### 问题

`Mechanic-first` 需要重做哪些层，必须先划清边界，否则工程上会从“重构作者模型”滑向“重写整个战斗内核”。

### 备选方案

#### 方案 A：全栈重构

- 从作者模型一直重构到底层运行时

优点：

- 最干净

缺点：

- 风险极高
- 周期过长
- 容易丢掉当前验证资产

#### 方案 B：只重构上层作者与编译装配链

- 保留底层执行骨架
- 重做作者资源、编译层、工厂装配层

优点：

- 风险可控
- 能复用当前大量 runtime 与验证资产

缺点：

- 新旧层之间需要一段时间的中间适配

### 已决定内容

选择 **方案 B：只重构上层作者与编译装配链**，明确：

**保留：**

- `EventBus`
- `EventData`
- `RuleContext`
- `EffectExecutor`
- 现有投射体空间模型
- `BattleBoardState / WaveRunner / Validation` 主框架

**重做：**

- 顶层作者模型
- `EntityFactory` 的装配逻辑
- `TriggerBinding` 的作者入口地位
- 目前散落在实体 root 的专属强逻辑组织方式

同时明确不采用：

- 全栈重构到底层事件与执行主干
- 为追求“最干净”而重写当前已稳定的验证基础设施

### 还需补证

- `HealthComponent / MovementComponent / HitboxComponent` 是否整体保留
- `TriggerRegistry / EffectRegistry` 在新结构中是保留还是降级为后端服务

---

## 5. D3 - 顶层作者模型替换方式

> 当前状态：**已决定**，见 [ADR-002 顶层作者模型与编译链](ADR-002-顶层作者模型与编译链.md)

### 问题

新架构的顶层作者模型到底是什么？

### 备选方案

#### 方案 A：`EntityTemplate + Mechanic[]`

- 在旧模板上增量加入 `mechanics`

优点：

- 改动小

缺点：

- 旧模型概念仍然滞留在顶层
- 容易形成“双中心”

#### 方案 B：`Archetype + Mechanic[]`

- 新建 `PlantArchetype / ZombieArchetype / ProjectileArchetype`
- 旧 `EntityTemplate / TriggerBinding / ProjectileTemplate` 降为底层编译产物或兼容层

优点：

- 顶层抽象清晰
- 与未来随机生成和扩展包更一致

缺点：

- 文档与资源组织要同步迁移

#### 方案 C：双轨并存长期共存

- 新旧模型长期共存

优点：

- 迁移阻力最小

缺点：

- 架构复杂度最高
- 很容易拖成长期技术债

### 当前推荐

选择 **方案 B**。

即：

- `Archetype + Mechanic[]` 成为正式作者入口
- `EntityTemplate / TriggerBinding / ProjectileTemplate` 不再作为顶层规范继续扩写

### 还需补证

- 新的目录组织如何命名
- 卡片、关卡、波次是否直接引用 `Archetype ID`

---

## 6. D4 - Compiler / RuntimeSpec 形态

> 当前状态：**已决定**，见 [ADR-002 顶层作者模型与编译链](ADR-002-顶层作者模型与编译链.md)

### 问题

`Mechanic-first` 不可能直接由工厂实例化，必须存在编译层。

### 备选方案

#### 方案 A：单阶段编译

`Mechanic[] -> Runtime Nodes`

优点：

- 结构简单

缺点：

- 冲突检查、预算缩放、随机展开、扩展包解析容易全部塞进一个大函数

#### 方案 B：多阶段编译

建议形态：

`Mechanic[] -> NormalizedMechanicSet -> RuntimeSpec -> RuntimeAssembler`

优点：

- 更适合做守卫、日志、验证和扩展

缺点：

- 初期实现成本更高

### 当前推荐

选择 **方案 B**。

建议至少保留三层：

1. `NormalizedMechanicSet`
2. `RuntimeSpec`
3. `RuntimeAssembler`

### 还需补证

- `RuntimeSpec` 是否落地为 `Resource`
- 编译时随机展开与运行时随机状态如何分层

---

## 7. D5 - 一级 Mechanic 家族冻结

> 当前状态：**已决定**，见 [ADR-003 Mechanic 一级家族冻结](ADR-003-Mechanic-一级家族冻结.md)

### 问题

如果不提前冻结一级 family，`Mechanic-first` 很容易演化为“无限新增机制名词”的架构。

### 备选方案

#### 方案 A：先不冻结，边做边长

优点：

- 灵活

缺点：

- 几乎必然失控

#### 方案 B：冻结少量 family，新增优先走 `type`

优点：

- 组合边界稳定
- 更利于扩展包治理

缺点：

- 前期需要更谨慎地抽象

### 当前推荐

选择 **方案 B**。

当前建议冻结的一级 family：

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

治理规则建议：

- 新增一级 family 必须走 ADR
- 扩展包默认不能新增一级 family
- 新能力优先增加 `type`

### 还需补证

- `Economy` 是否需要单独 family，还是始终归入 `Payload`
- `ProjectilePool` 更适合作为 `Emission` 子类型还是独立 family

---

## 8. D6 - Continuous Controller 正式化

> 当前状态：**已决定**，见 [ADR-004 连续行为、状态与生命周期正式化](ADR-004-连续行为-状态与生命周期正式化.md)

### 问题

当前连续行为文档主要围绕投射体，而像僵尸咬、扫掠、跳跃、潜水这类持续控制逻辑还没有正式的统一承载位。

### 备选方案

#### 方案 A：继续允许写在 root 脚本里

优点：

- 实现快

缺点：

- 与 `Mechanic-first` 目标冲突
- 会继续积累特例逻辑

#### 方案 B：引入 `Controller` 正式 family

优点：

- 连续行为有了统一正式入口
- 可组合、可扩展、可验证

缺点：

- 需要额外设计 controller 生命周期与黑板状态

### 当前推荐

选择 **方案 B**。

建议新增：

- `ControllerRegistry`
- `ControllerComponent`
- controller-local runtime state / blackboard

### 还需补证

- 一个实体是否允许多个 controller 并存
- controller 与 `State` / `Lifecycle` 的触发顺序如何定义

---

## 9. D7 - State / Lifecycle 正式关系

> 当前状态：**已决定**，见 [ADR-004 连续行为、状态与生命周期正式化](ADR-004-连续行为-状态与生命周期正式化.md)

### 问题

当前状态系统偏轻量，生命周期节点也不完整，难以直接承载：

- 土豆雷武装
- Sun-shroom 成长
- Newspaper 暴怒
- 放置即爆 / 成熟后切换

### 备选方案

#### 方案 A：继续把这些写成零散字段和特殊判断

缺点：

- 会快速破坏统一性

#### 方案 B：把 `State` 和 `Lifecycle` 提升为正式 family

优点：

- 生命周期入口和阶段状态能被统一表达

缺点：

- 需要定义状态切换与规则触发的边界

### 当前推荐

选择 **方案 B**。

建议：

- `State` 负责持久阶段、成长、武装、狂暴等实体持久状态
- `Lifecycle` 负责 `on_place / on_arm / on_expire / on_removed / on_state_enter`

### 还需补证

- `State` 与 `status effect` 的关系是否统一
- 临时状态与阶段状态是否拆成两套协议

---

## 10. D8 - 随机与 Mechanic 私有状态协议

> 当前状态：**已决定**，见 [ADR-004 连续行为、状态与生命周期正式化](ADR-004-连续行为-状态与生命周期正式化.md)

### 问题

错误技如果要正式进入主线，随机必须是可回放、可验证、可解释的。像“乱序发射所有抛射物”这类效果还需要 mechanic-local runtime state。

### 备选方案

#### 方案 A：运行时直接使用非确定性随机

优点：

- 实现快

缺点：

- 验证不可复现
- 录像与回放困难

#### 方案 B：统一使用确定性随机和机制私有状态

优点：

- 与验证、回放、调试体系相容

缺点：

- 需要额外定义 seed 与状态存储协议

### 当前推荐

选择 **方案 B**。

建议：

- battle seed 作为全局随机根
- entity / mechanic 派生 seed
- 明确允许 mechanic-local runtime state

典型状态：

- shuffle bag
- index
- cycle
- burst queue

### 还需补证

- 随机展开发生在生成期、编译期还是运行期
- 日志里如何记录随机决议结果

---

## 11. D9 - 扩展包注册与信任边界

> 当前状态：**已决定**，见 [ADR-005 扩展包接入与迁移策略](ADR-005-扩展包接入与迁移策略.md)

### 问题

在 `Mechanic-first` 下，扩展包不再主要扩 `TriggerBinding`，而是扩：

- `Archetype`
- `MechanicSet`
- family 下的 `type`
- 必要时扩展运行时代码

这要求扩展包注册模型同步升级。

### 备选方案

#### 方案 A：沿用现有思路，只把概念名字换掉

缺点：

- 很快会遇到 family/type/compiler/controller 的注册边界问题

#### 方案 B：新增 Mechanic 层注册中心

建议包括：

- `MechanicFamilyRegistry`
- `MechanicTypeRegistry`
- `MechanicCompilerRegistry`
- `ControllerRegistry`

### 当前推荐

选择 **方案 B**。

扩展包能力建议分层：

- `content_pack`
- `rule_pack`
- `runtime_pack`
- `asset_pack`
- `collection_pack`

并保留信任分级：

- `data_only`
- `rule_extended`
- `trusted_runtime`

### 还需补证

- 是否保留现有扩展包分类命名
- 版本冲突与禁用降级策略如何与现有规划对齐

---

## 12. D10 - 迁移策略与验证闭环

> 当前状态：**已决定**，见 [ADR-005 扩展包接入与迁移策略](ADR-005-扩展包接入与迁移策略.md)

### 问题

如果决定切路线，不能只讨论架构，还必须先定义：

- 新旧模型如何迁移
- 最小验证闭环是什么

### 备选方案

#### 方案 A：双轨期迁移

- 老模型继续可跑
- 新模型逐步接管

优点：

- 风险低

缺点：

- 中期复杂度高

#### 方案 B：一次性切换

- 停止旧作者模型
- 直接迁移一批基线 archetype

优点：

- 结构干净

缺点：

- 短期破坏性大

### 当前推荐

当前更倾向 **方案 A 的短期过渡 + 方案 B 的中期目标**：

- 短期允许极小双轨期
- 中期明确废弃旧作者模型

首批必须跑通的 archetype 建议：

1. 向日葵
2. 豌豆射手
3. 卷心菜投手
4. 基础僵尸
5. 土豆雷或樱桃炸弹

对应覆盖：

- 经济
- 直线攻击
- 抛射攻击
- 连续 controller
- 生命周期 / 状态机制

### 还需补证

- 旧验证场景复用比例
- 新旧资源并存时 `SceneRegistry` 如何解析

---

## 13. 建议的 ADR 拆分顺序

这份输入清单已经拆成下面 5 份正式 ADR：

1. **ADR-001 路线切换与重构范围**
   - 覆盖 D1、D2
2. **ADR-002 顶层作者模型与编译链**
   - 覆盖 D3、D4
3. **ADR-003 Mechanic 一级家族冻结**
   - 覆盖 D5
4. **ADR-004 连续行为、状态与生命周期**
   - 覆盖 D6、D7、D8
5. **ADR-005 扩展包接入与迁移策略**
   - 覆盖 D9、D10

---

## 14. 当前推荐的下一步动作

1. 基于 [ADR-001 路线切换与重构范围](ADR-001-路线切换与重构范围.md) 回写 wiki 主叙事。
2. 在 wiki 中标记下列文档进入“待替代”状态：
   - [当前阶段与实现路线](../01-overview/23-当前阶段与实现路线.md)
   - [开发路线图](../04-roadmap-reference/26-开发路线图.md)
   - [编译链与 Mechanic 系统](../02-runtime-protocol/11-编译链与Mechanic系统.md)
   - [触发器系统](../02-runtime-protocol/03-触发器系统.md)
3. 补一份“Mechanic-first 架构总览”正文，而不是只保留讨论纪要。
4. 选定首批 5 个 archetype 作为编译链验证对象。
5. 在实现前先冻结一级 family 名单和新增治理规则。

---

## 15. 结论

当前 `Mechanic-first` 方向本身已经有足够讨论基础，后续不再缺“概念发散”，而是缺**冻结决策**。

因此，接下来最重要的不是继续细分更多 `Mechanic`，而是：

- 明确路线是否切换
- 明确重构边界
- 明确顶层模型与编译链
- 明确 family 治理
- 明确扩展包与迁移策略

如果以上 5 组问题不先拍板，后续实现大概率会再次滑回“在旧模型上局部补丁”的路径。
