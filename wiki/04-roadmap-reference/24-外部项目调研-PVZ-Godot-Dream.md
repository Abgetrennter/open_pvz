# 外部项目调研：PVZ-Godot-Dream

- 状态：当前事实


## 基本信息

- 仓库地址：`https://github.com/hsk-dream/PVZ-Godot-Dream`
- 当前接入方式：Git 子模块
- 本地路径：`vendor/PVZ-Godot-Dream`
- 本地检查的最新提交：`cbaa61790775b8fe0e91d70b6533752625a6fd64`

---

## 结论先行

这个项目**不适合作为当前项目的直接开发基础**，更适合作为：

- 原版 PVZ 运行时实现细节的参考项目
- Godot 下 PVZ 类战斗系统拆分方式的参考项目
- 子弹、碰撞、角色组件化、关卡资源化的实现样本

更直接地说：

- 如果目标是做一个“高完成度原版 PVZ 复刻或传统改版”，它很适合 fork 后继续做
- 如果目标是做当前这个“触发器 + 效果树 + 随机生成 + 错误技”的新规则系统，**不建议直接在它上面 fork 开发**

---

## 为什么不建议直接 fork 作为基础

### 1. 许可证限制很强

它的 [LICENSE](../../vendor/PVZ-Godot-Dream/LICENSE) 是自定义的 `Custom Non-Commercial License`，明确禁止商业使用，包括：

- 商业公司或组织内部使用
- 销售、收费分发
- SaaS / API / 商业服务

这意味着：

- 你可以学习、研究、做非营利同人
- 但如果未来你的项目想保留更宽松的分发空间，这个基础会形成约束

### 2. 它的目标是“高质量复刻原版 PVZ”，不是规则引擎

[README](../../vendor/PVZ-Godot-Dream/README.md) 直接写明项目目标是“对原版 PVZ 进行高质量复刻（完美还原）”，并且“除僵王和部分小游戏外已经基本实现所有原版内容”。

这和当前项目方向有根本差异：

- 它的核心是还原原版行为
- 你的核心是生成新行为、允许错误技涌现

目标不同，会直接导致代码组织不同。

### 3. 代码高度围绕原版具体对象展开

这个仓库不是一个小框架，而是一个已经很完整的具体游戏工程：

- `scripts/` 下约有 `674` 个文件
- `scenes/` 下约有 `230` 个文件

并且存在大量面向具体原版单位或特例的脚本，例如：

- [component_attack_bullet_three_pea.gd](../../vendor/PVZ-Godot-Dream/scripts/character/components/attack_behavior_component/component_attack_bullet_three_pea.gd)
- [component_attack_bullet_corn.gd](../../vendor/PVZ-Godot-Dream/scripts/character/components/attack_behavior_component/component_attack_bullet_corn.gd)
- [component_attack_zombie_ladder.gd](../../vendor/PVZ-Godot-Dream/scripts/character/components/attack_behavior_component/component_attack_zombie_ladder.gd)
- [bullet_registry.gd](../../vendor/PVZ-Godot-Dream/scripts/autoload/global/bullet_registry.gd)

这说明它的抽象更像：

- “把原版植物、僵尸、子弹逐个拆成 Godot 组件”

而不是：

- “用统一规则系统生成任意组合行为”

### 4. 数据驱动有，但不是你要的那种数据驱动

[level_data.gd](../../vendor/PVZ-Godot-Dream/scripts/resources/level/level_data.gd) 说明它对关卡、卡槽、刷怪、罐子模式等做了资源化。

但它的资源化重点是：

- 原版玩法参数配置
- 关卡流程和内容白名单
- 植物/僵尸类型枚举与模式控制

不是：

- `TriggerDef`
- `EffectDef`
- `EffectNode`
- 可递归效果树
- 运行时策略注册

也就是说，它有很强的“内容配置能力”，但没有你当前最核心的“组合规则表达能力”。

### 5. 架构迁移成本会很高

当前项目想要的核心运行时是：

- 事件驱动
- 触发器实例订阅
- 效果树 DFS 执行
- 连锁深度保护
- 随机生成的能力组合

而这个项目现有的主干是：

- 原版角色场景继承体系
- 面向具体角色的组件拆分
- 具体子弹类型注册表
- 具体关卡资源与管理器

如果硬要在它上面改，你很快会遇到一个问题：

- 你不是在“扩展一个通用框架”
- 你是在“重写一个已经高度具体化的大型复刻项目”

这通常比自己搭最小运行时更慢。

### 6. GitHub 版本缺少版权相关资产

[README](../../vendor/PVZ-Godot-Dream/README.md) 和 [docs/开发相关.md](../../vendor/PVZ-Godot-Dream/docs/开发相关.md) 都说明：

- 原版相关资源因为版权原因被删除
- 完整项目资源需要额外获取

这意味着：

- 它很适合作为代码参考
- 但直接作为你当前仓库的基础工程，落地时还要处理资源缺失问题

---

## 为什么它仍然很有参考价值

### 1. 事件总线实现可以借鉴

[event_bus.gd](../../vendor/PVZ-Godot-Dream/scripts/autoload/event_bus.gd) 做了这些事情：

- 动态事件名
- 订阅 / 退订
- 优先级
- 一次性订阅
- 过滤器
- 历史记录

这套实现不等于你的最终事件系统，但很适合参考其：

- Godot 中全局事件总线的落点
- 调试模式与事件历史
- 订阅元数据管理

### 2. 子弹与移动组件拆分值得借鉴

[子弹说明文档](../../vendor/PVZ-Godot-Dream/docs/子弹说明文档.md) 和相关脚本表明它对子弹系统拆得比较清楚：

- `Bullet000Base`
- `Bullet000NormBase`
- `BulletMovementBase`
- `Linear / Parabola / Track`

这部分非常适合借鉴到你后续的最小运行时里，尤其是：

- 投射物根节点与移动组件分离
- 根节点统一驱动移动
- 特殊弹与标准弹分层

### 3. 角色“本体 + 组件”拆法可作为 Godot 工程经验

[character_000_base.gd](../../vendor/PVZ-Godot-Dream/scripts/character/character_000_base.gd) 与 [docs/开发相关.md](../../vendor/PVZ-Godot-Dream/docs/开发相关.md) 体现了一个很明确的原则：

- 根节点管基础属性与强耦合逻辑
- 其余行为交给组件

这对你当前阶段是有价值的，因为你也准备先用 Godot 原生节点方式搭骨架，而不是先上完整 ECS。

### 4. 主战斗场景的“管理器拆分”可以参考边界

[main_game_manager.gd](../../vendor/PVZ-Godot-Dream/scripts/manager/main_game_manager.gd) 展示了一个完整大场景如何拆成多个 manager。

虽然它对你来说偏重，但可以帮助你反向确定边界：

- 哪些职责可以先不做
- 哪些管理器不要在第一阶段就建太多

它更像一个“避免过度设计”的反例参考。

---

## 对当前项目的建议用法

### 建议 1：把它当参考仓库，不当主仓库

当前最稳的做法是：

- 保留为子模块
- 只在需要时查它的实现
- 不把你自己的核心代码建在它内部

这样可以避免：

- 被其许可证和结构绑定
- 被其大量原版逻辑拖着走

### 建议 2：有选择地借三块东西

优先借鉴：

1. 事件总线与调试思路
2. 投射物与移动组件拆分
3. 角色本体 + Godot 组件化组织方式

暂时不要借整套：

- 主游戏管理器体系
- 原版角色注册体系
- 原版子弹/植物/僵尸编号体系
- 原版关卡与卡槽规则

### 建议 3：继续按你自己的运行时主线写代码

当前项目仍应坚持自己的第一阶段主线：

1. `EventManager`
2. `TriggerDef / TriggerInstance / TriggerStrategy`
3. `EffectDef / EffectNode / EffectStrategy`
4. 最小植物 / 僵尸 / 投射物
5. 最小战斗演示

如果后续需要某个具体能力，例如：

- 直线子弹
- 追踪子弹
- 命中检测
- 角色受击盒组织

再回头从这个子模块里拆对应思路，而不是整体照搬。

---

## 最终判断

### 可以直接 fork 开发的前提

只有在下面这个目标下，才建议直接 fork：

- 你想做一个以原版 PVZ 规则为主、在原版框架上做传统改版的项目

### 当前项目下的推荐策略

对 `Open PVZ` 来说，更合适的策略是：

> 保留 `PVZ-Godot-Dream` 作为参考子模块，借鉴其 Godot 工程经验和局部运行时实现，但不要把当前项目直接建立在它的代码主干之上。



