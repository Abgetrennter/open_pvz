# scripts/visual — 视觉反馈运行时

视觉反馈层运行时：与战斗结果解耦，由 autoload 注册表驱动。

## WHERE TO LOOK

| 文件 | 职责 |
|------|------|
| `visual_feedback_host.gd` | 宿主节点，订阅固定事件（projectile.hit / entity.died 等），为每个实体生成视觉层，分发到 ActionRunner |
| `visual_action_runner.gd` | 执行视觉动作：spawn_fx / play_audio / flash_actor / play_actor_animation / attach_fx / screen_overlay |
| `visual_stage_layer_service.gd` | 管理 z-order 与视觉层分组，将 layer_name 映射到宿主节点（EntityLayer / ProjectileLayer 等） |
| `visual_layer_policy.gd` | 配置每层渲染规则：11 层 z_index 基值（ground=0 ~ ui=10000）与层间排序策略 |
| `reanim/reanim_data.gd` | Reanim 不可变轨道、clip、资源引用与 feature flag 数据 |
| `reanim/reanim_player.gd` | 单实例 Reanim 播放、仿真时钟 epoch、轨道采样与动态 Sprite2D 渲染 |
| `reanim/reanim_actor_def.gd` | 多 part、host track、state/action、clip rate 与 anchor 组合定义 |
| `reanim/reanim_actor.gd` | Actor Scene Contract 适配与多 ReanimPlayer 组合运行时 |

## KEY RULES

- 视觉反馈**不得**改变战斗结果（伤害/命中/冷却等不依赖 Tween 或粒子）
- 注册表在 `autoload/`（VisualCueRegistry / VisualFxRegistry / VisualProfileRegistry / AudioCueRegistry），运行时在本目录
- 视觉动作异步排队执行，与 game tick 解耦
- Host 订阅固定事件列表（`FIXED_EVENTS`），不动态扩展
- ActionRunner 通过 `_resolve_target` 解析动作目标，支持 context / source / event_target 等
- 新增视觉动作类型需在 ActionRunner 中添加对应 `_execute_*` 分支
- Reanim 播放相位只读 `GameState.current_time`，不得用 render delta、Timer 或墙钟推进
- `ReanimData` 由实例共享且保持只读；局部 phase、pending action 与 track override 只能保存在 Player/Actor 实例
- native Reanim 继续通过 `VisualProfileDef.actor_scene` 接入，不建立独立 gameplay registry

## DEPENDENCIES

- `autoload/` — VisualCueRegistry, VisualFxRegistry, VisualProfileRegistry, AudioCueRegistry
- `BattleManager` — 创建 VisualFeedbackHost 实例
- `EventBus` — 接收视觉提示事件
- `DebugService` — 记录视觉事件日志
