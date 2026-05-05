# 视觉反馈层任务文档包

> 状态：设计拆解，尚非实现事实。
> 目标：把 `Open PVZ 视觉反馈层设计与路线图` 拆成后续 AI agent 可直接认领的任务文档。

## 文档定位

本目录只描述视觉反馈层的设计边界、任务拆分和实施路线，不直接实现代码、不新增验证场景、不更新 registry。

视觉反馈层的总目标是：

> 规则事实驱动表现，视觉层解释事实，但不反向修改规则结果。

也就是说，视觉反馈层可以播放动画、生成 FX、请求音频、更新 actor 的显示状态和排序层级，但不得修改伤害、命中、目标选择、状态持续时间或 `EffectExecutor` 的执行结果。

## 前置阅读

建议先阅读：

- [../Open PVZ 视觉反馈层设计与路线图.md](../Open%20PVZ%20视觉反馈层设计与路线图.md)
- [../../wiki/01-overview/00-架构总览.md](../../wiki/01-overview/00-架构总览.md)
- [../../wiki/02-runtime-protocol/08-连续行为模型.md](../../wiki/02-runtime-protocol/08-连续行为模型.md)
- [../../wiki/04-roadmap-reference/42-通用扩展插槽机制.md](../../wiki/04-roadmap-reference/42-通用扩展插槽机制.md)
- [../../wiki/04-roadmap-reference/pvz-godot-dream/03-组件系统.md](../../wiki/04-roadmap-reference/pvz-godot-dream/03-组件系统.md)

## 推荐阅读顺序

1. [00-总览与边界.md](./00-总览与边界.md)
2. [01-VisualCue事件反馈层任务.md](./01-VisualCue事件反馈层任务.md)
3. [02-VisualProfile实体表现层任务.md](./02-VisualProfile实体表现层任务.md)
4. [03-VisualStageLayer层级环境任务.md](./03-VisualStageLayer层级环境任务.md)
5. [04-扩展槽与资源协议任务.md](./04-扩展槽与资源协议任务.md)
6. [05-验证与回归任务.md](./05-验证与回归任务.md)
7. [06-阶段路线图与完成定义.md](./06-阶段路线图与完成定义.md)

## 任务包边界

本任务包负责：

- 明确视觉反馈层与规则层的边界。
- 拆解 VisualCue、VisualProfile、VisualStageLayer 三条实施主线。
- 明确 visual registry / extension slot 的 v1 接入方式。
- 给出验证场景和 guardrail 要求。
- 给后续实现 agent 提供任务编号、验收标准和风险边界。

本任务包不负责：

- 实现视觉反馈层代码。
- 修改 `CombatArchetype`、`ProjectileTemplate`、`RuntimeSpec` 等正式资源协议。
- 新增验证场景文件。
- 更新 `tools/validation_scenarios.json`。
- 直接迁移 `de-pvz` 或 `PVZ-Godot-Dream` 的素材与代码。

## 全局硬约束

- 不得引入新的 Mechanic family；视觉反馈不是第 11 个 family。
- 视觉层不得改变战斗结果。
- 视觉层必须可关闭、可降级、可验证。
- 无视觉资源时必须有 fallback。
- 扩展包不得覆盖 `core.*` 视觉贡献项。
- v1 不允许 data-only 扩展包注册任意视觉脚本 action。

## 完成标志

当本目录所有文档被实现侧消费后，后续实现应能逐阶段完成：

- 核心事件触发 data-only visual cue。
- 实体可选挂载 visual actor。
- 投射体本体/影子符合当前 3D 逻辑 + 2D 投影模型。
- visual registry smoke 与 guardrail 进入批量验证。
