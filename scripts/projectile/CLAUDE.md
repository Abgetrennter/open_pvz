[根目录](../../CLAUDE.md) > [scripts](../) > **projectile**

# scripts/projectile -- 抛射体运动系统

## 模块职责

抛射体的运动模式实现。使用 3D 逻辑（地面位置 + 高度）配合 2D 投影渲染。每帧通过 `_physics_process` 更新运动状态。

## 关键文件

| 文件 | 类名 | 职责 |
|------|------|------|
| `projectile_flight_profile.gd` | `ProjectileFlightProfile` | 飞行配置 Resource：move_mode, height_strategy, hit_strategy, terminal_hit_strategy, 各种数值参数 |
| `projectile_move_result.gd` | `ProjectileMoveResult` | 运动帧结果：previous/current position + height, still_active, terminal_reason |
| `movement/projectile_movement_base.gd` | `ProjectileMovementBase` | 运动基类：configure_movement(), physics_process_projectile_move() |
| `movement/projectile_movement_linear.gd` | `ProjectileMovementLinear` | 直线运动：恒定方向和速度 |
| `movement/projectile_movement_parabola.gd` | `ProjectileMovementParabola` | 抛物线运动：起点到目标的弧线轨迹，arc_height 控制弧高，支持动态目标追踪 |
| `movement/projectile_movement_track.gd` | `ProjectileMovementTrack` | 追踪运动：turn_rate 控制转向速率，持续追踪目标节点 |

## 运动模式对比

| 模式 | 轨迹 | 命中策略默认值 | 终端策略默认值 | 关键参数 |
|------|------|---------------|---------------|----------|
| `linear` | 直线 | swept_segment | none | speed, direction |
| `parabola` | 抛物线弧 | terminal_hitbox | impact_hitbox | travel_duration, arc_height, impact_radius |
| `track` | 追踪曲线 | swept_segment | none | turn_rate, target_node |

## 3D-2D 投影

```
visual_position = ground_position + Vector2(0, -height * projection_scale)
```

运动组件更新 `ground_position` 和 `height`，由 `ProjectileRoot.set_projected_motion_state()` 转换为 2D 渲染位置。

## 相关验证场景

- `parabola_long_range_validation` -- 远距离抛物线
- `height_hit_validation` -- 高度段命中
- `lane_isolation_validation` -- 车道隔离
- `swept_segment_validation` -- 扫掠线段
- `terminal_explode_validation` -- 终端爆炸

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
