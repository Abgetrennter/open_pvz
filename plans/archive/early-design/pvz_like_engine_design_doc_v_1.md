# 开放式 PVZ-like 引擎设计文档 v0.1

## 1. 目标

本项目不是原版《植物大战僵尸》的逐像素复刻，而是一个开放式、可组合、可移植的规则引擎。核心目标是：

- 允许用户加载不同的数据包（mod / pack）。
- 允许 mod 提供“效果原子”和“实体模板”。
- 允许用户通过编辑器手动组合实体。
- 允许同一语义阶段内的效果顺序显式定义，并将顺序视为数据的一部分。
- 允许出现强组合、强叠加、强涌现的行为，甚至允许“错误技”式结果。
- 不以商业级稳定性为前提，而以实验性、表达力和可扩展性为核心。

---

## 2. 设计原则

### 2.1 语义固定，组合开放

系统的宏观语义阶段固定：

- BeforeX：准备/修改阶段
- OnX：执行阶段
- AfterX：结果/连锁阶段

但同一阶段内的 effect 顺序是显式数据，可配置、可迁移、可导出。

### 2.2 effect 是原子能力，实体是组合结果

- effect：最小行为单元。
- entity：多个 effect 组合后的结果。
- mod：提供 effect 和 entity 模板。

### 2.3 状态分层

- context：一次事件链中使用的瞬时状态。
- entity.state：实体持久状态。
- mod 私有数据：通过命名空间隔离管理。

### 2.4 连续行为与离散事件分离

- 离散事件：攻击、命中、死亡、生成。
- 连续行为：运动、转向、加速度、寿命衰减。

连续行为不应依赖“每帧 hook 式修补”，而应作为引擎原生能力。

### 2.5 自由组合优先于强约束

系统允许依赖、允许顺序、允许混乱，前提是这些都被显式建模为数据。

---

## 3. 核心架构

整体结构：

1. Event Layer（语义层）
2. Effect Layer（行为层）
3. Assembly Layer（组合层）
4. Continuous Simulation Layer（连续模拟层）

### 3.1 Event Layer

负责定义“发生了什么”。例如：

- on_spawn
- on_tick
- on_attack
- on_projectile_spawn
- on_hit
- on_damage
- on_death

事件必须有明确语义，不能无限膨胀为大量模糊事件名。

### 3.2 Effect Layer

负责定义“对这个事件做什么”。

effect 通过共享 context 读取和修改当前事件链的状态，并可以：

- 修改输入参数
- 设置标记
- 追加新事件
- 创建实体
- 修改实体持久状态

### 3.3 Assembly Layer

负责定义某个实体由哪些 effect 组成，以及这些 effect 在各阶段的顺序。

例：

```json
{
  "entity": "peashooter",
  "phases": {
    "BeforeAttack": ["choose_target", "validate_cost"],
    "OnAttack": ["spawn_pea"],
    "AfterAttack": ["play_sound", "trigger_chain"]
  }
}
```

### 3.4 Continuous Simulation Layer

负责每帧更新实体的持续行为，尤其是弹道、速度、寿命、碰撞等。

建议将其抽象为“贡献项叠加”模型，而不是单一轨迹类型切换。

---

## 4. 事件模型

### 4.1 三阶段模型

每一个高层行为都可分为三段：

- BeforeX：可修改。
- OnX：只读执行。
- AfterX：只读结果。

例如攻击：

- BeforeAttack：修改目标、伤害、是否取消。
- OnAttack：确认攻击发生。
- AfterAttack：触发连锁、附加效果。

### 4.2 事件上下文 context

context 是一次事件链中的共享对象，建议结构：

```json
{
  "core": {
    "damage": 10,
    "source": "entity_id",
    "target": "entity_id",
    "canceled": false,
    "tags": ["projectile"]
  },
  "runtime": {
    "event_id": "uuid",
    "depth": 1,
    "timestamp": 123456
  },
  "mods": {
    "modA": {
      "stack": 3
    }
  }
}
```

### 4.3 context 规则

- core：引擎语义字段，所有 effect 可读写。
- runtime：调试、递归控制、追踪。
- mods：mod 私有临时状态，必须按 mod_id 命名空间隔离。

### 4.4 事件触发方式

- 事件可由 effect 触发。
- 新事件建议进入队列，而不是直接深递归调用。
- 必须支持事件深度控制与追踪 ID。

---

## 5. Effect 执行模型

### 5.1 中间件式管线

同一阶段内的 effect 以管线形式依次执行：

```text
context -> effect1 -> effect2 -> effect3 -> ...
```

每个 effect 都可以：

- 读取 context
- 修改 context
- 生成新实体
- 追加新事件

### 5.2 阶段内顺序

阶段内顺序是显式数据，例如：

```json
{
  "phase": "AfterAttack",
  "effects": [
    { "id": "double_damage", "order": 10 },
    { "id": "explode", "order": 20 }
  ]
}
```

顺序作为数据的一部分，便于迁移与导出。

### 5.3 短路策略

需要明确是否允许 effect 提前终止后续流程。

建议：

- Before 阶段允许 cancel。
- On / After 阶段默认只读，尽量不短路。
- 若允许短路，必须明确标注。

---

## 6. Entity 设计

### 6.1 Entity 的定义

entity 不是写死的对象，而是 effect 的组合结果。

示例：

```json
{
  "entity": "peashooter",
  "phases": {
    "BeforeAttack": ["choose_target"],
    "OnAttack": ["spawn_projectile"],
    "AfterAttack": ["trigger_after_effects"]
  },
  "components": [
    "health",
    "cooldown",
    "team"
  ]
}
```

### 6.2 entity.state

用于持久状态，例如：

- 累积层数
- 冷却
- 标记
- buff / debuff

它与 context 分离，不应混淆。

---

## 7. 连续行为模型

### 7.1 设计动机

需要支持：

- 直线弹道
- 正弦弹道
- 追踪弹道
- 磁力偏转
- 螺旋、圆弧、随机曲线

这些不能只靠事件 hook 处理，而应作为引擎原生的连续行为系统。

### 7.2 叠加式动力学

推荐使用“贡献项叠加”的方式，而不是单一轨迹模式切换。

每帧：

1. 收集所有组件输出的速度增量或力。
2. 合成。
3. 更新 velocity。
4. 更新 position。

形式上可写为：

```text
v(t+1) = v(t) + ΣΔv_i
position += velocity * dt
```

### 7.3 连续行为的原则

- 组件只能输出贡献项，不能直接破坏全局状态。
- 所有贡献项应共享同一时间基准。
- 叠加顺序尽量可交换，减少顺序耦合。

### 7.4 轨迹实现方式

推荐把“直线、正弦、磁力、追踪”等都视为力或速度贡献，而不是独立轨迹类型。

这使得：

- 轨迹可叠加
- 轨迹可组合
- 轨迹可导出为数据

---

## 8. mod 结构

### 8.1 mod 的职责

一个 mod 可以提供：

- effect 原子
- entity 模板
- 连续行为组件
- 资源
- 事件处理脚本

### 8.2 mod 命名空间

必须强制命名空间隔离：

```text
mods.<mod_id>.<variable>
```

避免 mod 之间的私有状态冲突。

### 8.3 mod 私有变量

允许 mod 维护自己的临时变量和状态，但默认不应被其他 mod 依赖。

技术上可以读取，规范上不应依赖。

---

## 9. 编辑器设计

### 9.1 作用

编辑器负责把 effect、顺序、阶段、持续组件组合成实体。

### 9.2 主要功能

- 拖拽组合 effect
- 调整阶段归属
- 调整阶段内顺序
- 查看 context 流转
- 预览组合结果
- 导出为 data pack / mod pack

### 9.3 编辑器原则

- 普通模式：提供默认组合。
- 高级模式：允许显式顺序和高级参数。
- 允许用户为移植目标手动重建逻辑。

---

## 10. 迁移与兼容

### 10.1 兼容的定义

不是直接兼容原版 mod，而是：

- 在统一规范下迁移原有改版逻辑。
- 将行为拆成 effect + 顺序 + 阶段。
- 用新引擎的实体和组件重建原效果。

### 10.2 迁移对象

适合迁移的内容：

- 原版改版中的植物能力
- 子弹轨迹变化
- 命中触发机制
- 连锁触发效果
- 特殊行为组合

### 10.3 迁移方式

- 将原逻辑拆成阶段。
- 将原效果拆成 effect。
- 将顺序显式编码。
- 如有连续行为，则映射到动力学组件。

---

## 11. 示例映射

### 11.1 胆小菇无条件射击

- BeforeAttack：检查资源和冷却
- OnAttack：强制生成子弹
- AfterAttack：无或触发附加效果

### 11.2 双发射手命中后双发

- OnHit：触发两次射击请求
- 限制可通过 cooldown / tick 计数器实现

### 11.3 卷心菜上射

- 用运动组件或速度贡献实现初速度方向变化。

### 11.4 磁力菇使子弹偏转

- 每帧对 projectile 的 velocity 施加偏转贡献。

### 11.5 正弦子弹轨迹

- 在连续层按时间函数产生 y 方向增量。

---

## 12. 调试与可观测性

这是实验性系统能否使用的关键。

### 12.1 必须支持

- event trace
- context dump
- depth 追踪
- effect 执行顺序记录
- entity 生命周期记录

### 12.2 调试目标

- 能看到某个结果是由哪些 effect 组合出来的。
- 能看到顺序如何影响结果。
- 能回放事件链。

---

## 13. 风险点

### 13.1 context 污染

如果 core、mods、runtime 混在一起，系统会失控。

### 13.2 顺序耦合过深

顺序作为数据是允许的，但要清楚这会产生不同语义组合。

### 13.3 连锁爆炸

事件递归和连续叠加容易导致性能问题，需要 runtime 限制。

### 13.4 effect 粒度失衡

- 太粗：无法组合。
- 太细：mod 作者难以使用。

---

## 14. 建议的最小可实现版本（MVP）

先实现以下最小闭环：

1. 一个攻击事件。
2. 三个阶段：BeforeAttack / OnAttack / AfterAttack。
3. 一个共享 context。
4. 三个 effect：
   - damage ×2
   - damage +5
   - after 触发一次额外攻击
5. 一个 projectile entity。
6. 两种连续贡献：
   - 线性
   - 正弦偏移

验证以下能力：

- 阶段是否生效。
- 顺序是否能改变结果。
- 连续行为是否可以叠加。
- 事件链是否可追踪。

---

## 15. 结论

这套系统的核心不是“PVZ clone”，而是：

> 一个以语义事件为主干、以 effect 管线为执行模型、以连续动力学为补充层的开放式组合引擎。

它能支持：

- 实体组合
- 效果组合
- 顺序显式化
- 轨迹可编程
- mod 可迁移
- 错误技式涌现

这正是项目的目标。

