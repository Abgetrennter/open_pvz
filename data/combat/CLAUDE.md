[根目录](../../CLAUDE.md) > [data](../) > **combat**

# data/combat -- 战斗数据资源

## 模块职责

所有战斗内容的 `.tres` Resource 文件存放处。由 `SceneRegistry` autoload 在启动时自动扫描注册。遵循"数据驱动"原则：新增内容只需添加 `.tres` 文件，无需修改代码。

## 目录结构

```
data/combat/
  entity_templates/
    plants/          -- 植物模板（14 个）
    zombies/         -- 僵尸模板（7 个）
    field_objects/     -- 场上物件模板（1 个）
  projectile_templates/ -- 抛射体模板（6 个）
  projectile_profiles/ -- 飞行配置（8 个）
  trigger_bindings/    -- 触发绑定（8 个）
  height_bands/        -- 高度段（5 个）
```

## 植物模板清单

| 模板 ID | 文件 | 类型 |
|---------|------|------|
| `plant_basic_shooter` | plants/plant_basic_shooter.tres | 基础射手 |
| `plant_track_bomber` | plants/plant_track_bomber.tres | 追踪轰炸 |
| `plant_cabbage_lobber` | plants/plant_cabbage_lobber.tres | 卷心菜投手 |
| `plant_melon_lobber` | plants/plant_melon_lobber.tres | 西瓜投手 |
| `plant_repeater_burst` | plants/plant_repeater_burst.tres | 连发射手 |
| `plant_air_interceptor` | plants/plant_air_interceptor.tres | 空中拦截 |
| `plant_wall_barrier` | plants/plant_wall_barrier.tres | 墙壁屏障 |
| `plant_water_pod` | plants/plant_water_pod.tres | 水面承载 |
| `plant_flower_pot_surface` | plants/plant_flower_pot_surface.tres | 花盆表面 |
| `plant_air_perch` | plants/plant_air_perch.tres | 空中栖架 |
| `plant_pumpkin_cover` | plants/plant_pumpkin_cover.tres | 南瓜掩体 |
| `plant_tombstone_blocker` | plants/plant_tombstone_blocker.tres | 墓碑阻挡 |

## 僵尸模板清单

| 模板 ID | 文件 |
|---------|------|
| `zombie_lane_dummy` | zombies/zombie_lane_dummy.tres |
| `zombie_reactive_bomber` | zombies/zombie_reactive_bomber.tres |
| `zombie_air_scout` | zombies/zombie_air_scout.tres |
| `zombie_basic_walker` | zombies/zombie_basic_walker.tres |
| `zombie_brisk_runner` | zombies/zombie_brisk_runner.tres |
| `zombie_bucket_tank` | zombies/zombie_bucket_tank.tres |
| `zombie_boss_heavy` | zombies/zombie_boss_heavy.tres |

## 场物件模板清单

| 模板 ID | 文件 | 类型 |
|---------|------|------|
| `field_object_lawn_mower` | field_objects/field_object_lawn_mower.tres | 割草机 |

## 模板编写约定

- 命名：`plant_role_variant` / `zombie_role_variant` / `projectile_type`
- 字段顺序：Identity -> Node/Component -> Combat -> Projectile -> Behavior
- EntityTemplate 通过 `trigger_bindings` 数组引用 TriggerBinding 资源
- TriggerBinding 通过 `behavior_key` 绑定到冻结协议
- 放置约束通过 `placement_role`, `required_placement_tags`, `granted_placement_tags` 控制

## 相关验证场景

几乎所有验证场景都使用此目录中的模板资源。

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
