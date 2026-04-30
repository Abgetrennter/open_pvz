[根目录](../../CLAUDE.md) > [scripts](../) > **components**

# scripts/components -- 可复用组件

## 模块职责

ECS 风格的可复用组件，通过 EntityFactory 在实体实例化时自动挂载。每个组件是一个 Node 子节点。

## 关键文件

| 文件 | 类名 | 职责 |
|------|------|------|
| `health_component.gd` | `HealthComponent` | 生命值管理。take_damage() 触发 entity.damaged / entity.died 事件。heal() 恢复生命 |
| `trigger_component.gd` | `TriggerComponent` | 触发器挂载。bind_triggers() 接受 TriggerInstance 数组，自动订阅 EventBus 并在事件匹配时执行效果链 |
| `hitbox_component.gd` | `HitboxComponent` | 碰撞检测。支持矩形/圆形配置、contains_world_point()、intersects_world_segment() 查询 |
| `movement_component.gd` | `MovementComponent` | 基础移动。用于僵尸等需要持续移动的实体 |
| `debug_view_component.gd` | `DebugViewComponent` | 调试视图。显示实体状态信息的可视化覆盖 |

## 组件挂载规则

EntityFactory 根据 entity_kind 自动挂载组件：

| entity_kind | TriggerComponent | MovementComponent | HealthComponent | HitboxComponent | DebugViewComponent |
|-------------|:-:|:-:|:-:|:-:|:-:|
| plant | Yes | No | Yes (100 HP) | Yes (42x54) | Yes |
| zombie | Yes | Yes | Yes (120 HP) | Yes (44x60) | No |

CombatArchetype 的 `required_components` 字段可要求额外组件。

## 关键接口

### HealthComponent
```gdscript
signal damaged(amount: int)
signal died()
take_damage(amount, source_node, tags, runtime_overrides)
heal(amount)
```

### TriggerComponent
```gdscript
bind_triggers(instances: Array)  # 绑定运行时触发器实例
clear_triggers()                  # 清理所有订阅
```

## 相关验证场景

所有涉及实体交互的验证场景都会测试组件功能。

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
