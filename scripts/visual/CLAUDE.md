# scripts/visual — 视觉反馈运行时

视觉反馈层运行时：与战斗结果解耦，由 autoload 注册表驱动。

## WHERE TO LOOK

| 文件 | 职责 |
|------|------|
| `visual_feedback_host.gd` | 宿主节点，订阅固定事件（projectile.hit / entity.died 等），为每个实体生成视觉层，分发到 ActionRunner |
| `visual_action_runner.gd` | 执行视觉动作：spawn_fx / play_audio / flash_actor / play_actor_animation / attach_fx / screen_overlay |
| `visual_stage_layer_service.gd` | 管理 z-order 与视觉层分组，将 layer_name 映射到宿主节点（EntityLayer / ProjectileLayer 等） |
| `visual_layer_policy.gd` | 配置每层渲染规则：11 层 z_index 基值（ground=0 ~ ui=10000）与层间排序策略 |

## KEY RULES

- 视觉反馈**不得**改变战斗结果（伤害/命中/冷却等不依赖 Tween 或粒子）
- 注册表在 `autoload/`（VisualCueRegistry / VisualFxRegistry / VisualProfileRegistry / AudioCueRegistry），运行时在本目录
- 视觉动作异步排队执行，与 game tick 解耦
- Host 订阅固定事件列表（`FIXED_EVENTS`），不动态扩展
- ActionRunner 通过 `_resolve_target` 解析动作目标，支持 context / source / event_target 等
- 新增视觉动作类型需在 ActionRunner 中添加对应 `_execute_*` 分支

## DEPENDENCIES

- `autoload/` — VisualCueRegistry, VisualFxRegistry, VisualProfileRegistry, AudioCueRegistry
- `BattleManager` — 创建 VisualFeedbackHost 实例
- `EventBus` — 接收视觉提示事件
- `DebugService` — 记录视觉事件日志
