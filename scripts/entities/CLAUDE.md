[根目录](../../CLAUDE.md) > [scripts](../) > **entities**

# scripts/entities -- 实体类型

## 模块职责

定义引擎中所有实体的根节点类型。采用继承链：`BaseEntity` -> `PlantRoot` / `ZombieRoot` / `ProjectileRoot`。每个实体附带 `EntityState`（RefCounted）用于状态追踪。

## 关键文件

| 文件 | 类名 | 继承 | 职责 |
|------|------|------|------|
| `base_entity.gd` | `BaseEntity` | Node2D | 所有实体基类。管理 entity_id, team, lane_id, template_id, entity_state, 高度段 |
| `plant_root.gd` | `PlantRoot` | BaseEntity | 植物根节点。team = "plant"，包含 take_damage 接口（委托给 HealthComponent） |
| `zombie_root.gd` | `ZombieRoot` | BaseEntity | 僵尸根节点。team = "zombie"，包含 move_speed、自动移动逻辑、take_damage 接口 |
| `projectile_root.gd` | `ProjectileRoot` | BaseEntity | 抛射体根节点。管理飞行状态、3D-2D 投影、命中检测（swept_segment / terminal / overlap）、on_hit 效果链 |
| `field_object_root.gd` | `FieldObjectRoot` | BaseEntity | 场上物件根节点。team = "field_object"，is_combat_active() -> false，提供 activate/deactivate 生命周期 |
| `lawn_mower.gd` | `LawnMower` | FieldObjectRoot | 割草机：idle → triggered → expired 状态机，检测同车道僵尸并扫掠击杀 |

## 核心接口

### BaseEntity
- `assign_lane(lane_id)` -- 分配车道
- `set_state_value(key, value)` -- 设置状态值
- `get_entity_state()` -> Dictionary -- 获取状态快照
- `apply_height_band(height_band)` -- 应用高度段
- `is_combat_active()` -> bool -- 是否处于战斗状态

### ProjectileRoot
- `launch(direction, speed, source_node, on_hit_effect, damage, movement_params, runtime_overrides)` -- 发射抛射体
- `set_projected_motion_state(ground_position, height)` -- 更新 3D 运动状态（由运动组件调用）
- 命中策略：`overlap`, `swept_segment`, `terminal_hitbox`, `terminal_radius` 及组合
- 命中后执行 on_hit_effect 或直接 `take_damage`

## 依赖关系

- 由 `EntityFactory` 实例化
- 使用 `scripts/components/` 中的组件（HealthComponent, TriggerComponent, HitboxComponent）
- 使用 `scripts/projectile/movement/` 中的运动策略
- 通过 `EventBus` 发射事件（`projectile.spawned`, `projectile.hit`, `projectile.expired`）

## 相关验证场景

- `minimal_battle_validation` -- 基础实体生成和交互
- `height_hit_validation` -- 高度段过滤
- `swept_segment_validation` -- 扫掠碰撞
- `template_instantiation_validation` -- 模板身份保持

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
