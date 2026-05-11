# scripts/entities -- 实体类型

> 所有运行时实体根节点。`BaseEntity` 派生 `PlantRoot` / `ZombieRoot` / `ProjectileRoot` / `FieldObjectRoot` → `LawnMower`。每个实体携带 `EntityState`（RefCounted）做状态追踪。

## WHERE TO LOOK

| 文件 | 类 | 继承 | 一句话 |
|------|----|------|--------|
| `base_entity.gd` | `BaseEntity` | Node2D | entity_id / team / lane_id / archetype_id / entity_state / 高度段 |
| `plant_root.gd` | `PlantRoot` | BaseEntity | team="plant"，take_damage 委托 HealthComponent |
| `zombie_root.gd` | `ZombieRoot` | BaseEntity | team="zombie"，move_speed + 自动移动 + take_damage |
| `projectile_root.gd` | `ProjectileRoot` | BaseEntity | 飞行状态 / 3D→2D 投影 / 命中检测（swept_segment / terminal / overlap）/ on_hit 效果链 |
| `field_object_root.gd` | `FieldObjectRoot` | BaseEntity | team="field_object"，默认不参与 targetable/damageable/collidable |
| `lawn_mower.gd` | `LawnMower` | FieldObjectRoot | idle→triggered→expired 状态机，扫掠同车道僵尸 |

## CORE INTERFACES

**BaseEntity**
- `assign_lane(lane_id)` / `set_state_value(key, value)` / `get_entity_state() -> Dictionary`
- `apply_height_band(height_band)`
- `is_liveness_enabled(axis) -> bool`
- `is_targetable()` / `is_damageable()` / `is_collidable()`

**ProjectileRoot**
- `launch(direction, speed, source_node, on_hit_effect, damage, movement_params, runtime_overrides)`
- `set_projected_motion_state(ground_position, height)` -- 运动组件每帧调用
- 命中策略：overlap / swept_segment / terminal_hitbox / terminal_radius 及组合

## DEPENDENCIES

- 由 `EntityFactory`（scripts/battle/）实例化
- 使用 `scripts/components/`（HealthComponent, TriggerComponent, HitboxComponent）
- 使用 `scripts/projectile/movement/` 运动策略
- 通过 `EventBus` 发射 `projectile.spawned` / `projectile.hit` / `projectile.expired`
