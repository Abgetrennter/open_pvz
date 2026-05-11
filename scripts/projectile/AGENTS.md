# scripts/projectile

抛射体运动系统：3D 逻辑（ground + height）配 2D 投影渲染，6 个 .gd + movement/ 子目录。

## WHERE TO LOOK

| 文件 | 类 | 职责 |
|------|-----|------|
| `projectile_flight_profile.gd` | `ProjectileFlightProfile` | Resource：move_mode / height_strategy / hit_strategy / terminal_hit_strategy 及数值参数 |
| `projectile_move_result.gd` | `ProjectileMoveResult` | 帧结果：prev/cur position + height, still_active, terminal_reason |
| `movement/projectile_movement_base.gd` | `ProjectileMovementBase` | 基类：configure_movement() + physics_process_projectile_move() |
| `movement/projectile_movement_linear.gd` | `ProjectileMovementLinear` | 直线 |
| `movement/projectile_movement_parabola.gd` | `ProjectileMovementParabola` | 抛物线弧 |
| `movement/projectile_movement_track.gd` | `ProjectileMovementTrack` | 追踪曲线 |

## 运动模式对比

| 模式 | 命中策略 | 终端策略 | 关键参数 |
|------|---------|---------|----------|
| linear | swept_segment | none | speed, direction |
| parabola | terminal_hitbox | impact_hitbox | travel_duration, arc_height, impact_radius |
| track | swept_segment | none | turn_rate, target_node |

## 3D → 2D 投影

```
visual_position = ground_position + Vector2(0, -height * projection_scale)
```

运动组件写 ground_position / height，`ProjectileRoot.set_projected_motion_state()` 转为渲染坐标。注册与扩展走 `ProjectileMovementRegistry`（core.linear / core.parabola / core.track）。
