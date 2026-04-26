# ADR-003 Mechanic 一级家族冻结

- 状态：已决定
- 日期：2026-04-21
- 作者：Codex / Abget
- 关联阶段：`Mechanic-first` 重构阶段
- 关联文档：
  - [ADR-002 顶层作者模型与编译链](ADR-002-顶层作者模型与编译链.md)
  - [Mechanic-first 重构讨论纪要](../../plans/archive/wiki-retired/decisions/Mechanic-first-重构讨论纪要.md)
  - [ADR 输入 - Mechanic-first 重构未决事项清单](../../plans/archive/wiki-retired/decisions/ADR-输入-Mechanic-first-重构未决事项清单.md)
  - [核心设计哲学](../01-overview/01-核心设计哲学.md)
  - [触发器系统](../02-runtime-protocol/03-触发器系统.md)
  - [效果系统](../02-runtime-protocol/04-效果系统.md)
  - [连续行为模型](../02-runtime-protocol/08-连续行为模型.md)
- 关联实现：
  - 未来新增 `MechanicFamilyRegistry`
  - 未来新增 `MechanicTypeRegistry`
- 关联验证：
  - family/type 协议守卫验证

## 1. 决策摘要

`Mechanic-first` 架构正式冻结 10 个一级 family：

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

后续新增能力优先走现有 family 下的 `type` 和 `param`。  
新增一级 family 必须走新的 ADR，扩展包默认不得新增一级 family。

## 2. 背景与问题

`Mechanic-first` 的最大风险不是做不出来，而是：

> 把“可组合”误解成“无限细分”。

如果一级 family 不提前冻结，系统很容易演变成：

- `BurstMechanic`
- `AuraMechanic`
- `EconomyMechanic`
- `ProjectilePoolMechanic`
- `SpecialAttackMechanic`
- `SupportMechanic`

这会迅速破坏：

- 作者心智
- 扩展包治理
- 编译器结构
- 验证边界

因此必须在真正实现前冻结一级 family，并规定新增治理规则。

## 3. 目标

本次决策目标：

1. 冻结一组少量、稳定的一级 family。
2. 明确一级 family / type / param 三层边界。
3. 防止后续通过“继续加名词”来逃避抽象治理。
4. 为扩展包注册和协议守卫提供稳定根。

## 4. 非目标

本次决策不直接冻结：

- 每个 family 下所有 type 的完整列表
- 每个 type 的所有参数字段
- family 之间所有编译优先级细节

## 5. 备选方案

### 方案 A：先不冻结，边做边长

优点：

- 最灵活

缺点：

- 几乎必然膨胀失控
- 扩展包无法稳定接入
- 文档和实现边界会持续漂移

未选原因：

- 不符合当前重构阶段需要“先定边界再放开组合”的方法论。

### 方案 B：冻结少量 family，新增优先走 `type`

优点：

- family 边界稳定
- 能把复杂度压进 type 与 param
- 作者心智可控

缺点：

- 初期需要更谨慎地设计 family 切分

选择原因：

- 这是控制复杂度的必要条件。

## 6. 最终决策

### 6.1 冻结的一级 family

正式冻结为：

1. `Trigger`
2. `Targeting`
3. `Emission`
4. `Trajectory`
5. `HitPolicy`
6. `Payload`
7. `State`
8. `Lifecycle`
9. `Placement`
10. `Controller`

### 6.2 三层边界

正式采用三层边界：

- 一级 family：行为维度
- `type`：该维度下的实现族
- `param`：该实现族的配置值

### 6.3 典型归类

#### family

- `Trajectory`
- `Payload`
- `Controller`

#### type

- `Trajectory.linear`
- `Trajectory.parabola`
- `Emission.shuffle_cycle`
- `Payload.explode`
- `Lifecycle.on_place`

#### param

- `speed`
- `damage`
- `interval`
- `radius`
- `arc_height`

### 6.4 两个明确归属

当前同时决定：

- `Economy` 不单独升为一级 family，当前统一归入 `Payload`
- `ProjectilePool / shuffle bag / 发射序列策略` 当前统一归入 `Emission`

## 7. 影响范围

### 编译器

- family 将成为编译链的一级分发入口
- 新能力默认在 family 内扩展 `type`

### 扩展包

- 扩展包注册点默认只允许新增 `type`
- family 成为主仓治理资源

### 文档

- 后续所有协议文档必须以 family 为一级目录或一级章节组织

## 8. 迁移与兼容

这项决策不直接影响旧资源运行，但会影响新架构设计方式：

- 新增能力位时，不应再随意引入新一级 `Mechanic`
- 如确有必要，必须新增 ADR

## 9. 验证方式

完成信号包括：

1. 新协议文档中明确写出 10 个一级 family。
2. 实现里存在 family/type 守卫。
3. 扩展包注册时，不能直接插入新一级 family。
4. 新增能力默认通过 `type` 扩展落地。

## 10. 风险与未决项

### 风险

1. 如果 family 切分本身错误，后续会在某个 family 内堆过多 `type`。
2. 如果没有守卫，这项决策会很快被旁路破坏。

### 未决项

- family 之间的正式编译顺序
- family/type 注册表的具体资源结构

## 11. 后续动作

1. 起草 `MechanicFamilyRegistry` 与 `MechanicTypeRegistry` 协议。
2. 在扩展包方案中明确“默认只能新增 type”。
3. 补一份 family/type/param 的正式术语表。
4. 在后续实现中为 family/type 添加协议守卫验证。
