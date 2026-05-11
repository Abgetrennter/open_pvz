# scripts/components -- ECS 可复用组件

EntityFactory 按 entity_kind 自动挂载的 Node 子组件。

## WHERE TO LOOK

| 组件 | 核心职责 |
|------|----------|
| `HealthComponent` | 生命值；`take_damage()` → 发射 `entity.damaged` / `entity.died` |
| `TriggerComponent` | 触发器挂载；`bind_triggers()` 订阅 EventBus，事件匹配执行效果链 |
| `HitboxComponent` | 碰撞几何；`contains_world_point()`、`intersects_world_segment()` |
| `MovementComponent` | 持续移动；多贡献源叠加速度，`physics_process_movement()` 驱动 |
| `ControllerComponent` | 每帧 Controller 策略；`bind_controller_specs()` → `physics_process_controllers()` |
| `StateComponent` | 状态机；`bind_state_specs()`、时间/事件转移、liveness 覆盖 |
| `DebugViewComponent` | 调试覆盖；`snapshot()` 返回实体状态字典 |
| `VisualActorComponent` | 视觉反馈桥接；监听 EventBus 驱动动画/伤害闪烁/死亡表现 |

## MOUNTING RULES

EntityFactory 按 entity_kind 自动挂载：

| entity_kind | Trigger | Movement | Health | Hitbox | Debug | State | Controller |
|:-----------:|:-------:|:--------:|:------:|:------:|:-----:|:-----:|:----------:|
| plant | ✓ | | ✓ 100HP | ✓ 42×54 | ✓ | ✓ | ✓ |
| zombie | ✓ | ✓ | ✓ 120HP | ✓ 44×60 | | ✓ | ✓ |
| projectile | | | | | | | |

`CombatArchetype.required_components` 可追加。

## KEY INTERFACES

```gdscript
# HealthComponent
signal damaged(amount: int); signal died()
func take_damage(amount, source_node, tags, runtime_overrides)
func heal(amount: int)
# TriggerComponent
func bind_triggers(instances: Array)   # → EventBus 订阅
func clear_triggers()                  # _exit_tree 自动调用
# ControllerComponent
func bind_controller_specs(specs: Array)
func physics_process_controllers(delta: float)
# StateComponent
func bind_state_specs(specs: Array)
func get_current_state() -> StringName
func has_active_states() -> bool
```
