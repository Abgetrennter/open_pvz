[根目录](../../AGENTS.md) > [data](../) > **combat**

# data/combat -- 战斗数据资源

`.tres` Resource 战斗内容存放处。`SceneRegistry` autoload 启动时自动扫描。新增内容只需 `.tres`，无需改代码。

## 目录结构

```
data/combat/
  archetypes/           -- 实体定义（plants/ zombies/ field_objects/）
  mechanics/            -- Mechanic 片段（skeleton/ 为骨架，根级为具体）
  projectile_templates/ -- 抛射体内容模板
  projectile_profiles/  -- 飞行配置与命中策略
  height_bands/         -- 高度段定义
  cards/                -- 卡片定义（demo/ original/ phase6/）
  waves/                -- 波次模板（demo/ phase6/）
  levels/               -- 关卡数据（phase6/）
  modes/                -- 战斗模式、输入档案、胜负条件、规则模块
  battlefields/         -- 战场与棋盘预设（phase6/）
```

## 数据清单

### 高度段 (5)

| ID | 用途 |
|----|------|
| `ground_unit` | 地面单位标准 |
| `ground_unit_large` | 大型地面单位 |
| `air_unit_low` / `air_unit_medium` / `air_unit_high` | 低/中/高空单位 |

### 飞行配置 (9)

`linear_ground` `linear_fast_swept` `linear_air` `track_ground` `track_air` `parabola_arc` `parabola_cabbage_arc` `parabola_long_arc` `parabola_terminal_blast`

### 抛射体模板 (9)

`pea_linear` `pea_burst` `pea_frost_linear` `cabbage_arc` `melon_blast` `track_bomb` `air_spike` `bone_linear` `tar_spit_linear` `spore_shot_linear`

### 植物 Archetype (~85)

核心：`basic_shooter` `repeater_burst` `track_bomber` `cabbage_lobber` `melon_lobber` `air_interceptor` `frost_pea` `spore_summoner` `sporeling` `wall_barrier` `pumpkin_cover` `tombstone_blocker` `water_pod` `flower_pot_surface` `air_perch` `sunflower`

原版迁移：`original_peashooter` `original_sunflower` `original_wallnut` `original_cherrybomb` `original_potatomine` `original_squash` `original_chomper` `original_jalapeno` `original_repeater` `original_fumeshroom` `original_gloomshroom` `original_cattail` `original_wintermelon` 等 30+

骨架（skeleton）：`peashooter` `striker` `burst_shooter` `spread_shooter` `trajectory_shooter` `arming_striker` 等，仅供验证或继承参考

### 僵尸 Archetype (10)

`basic_walker` `brisk_runner` `bucket_tank` `air_scout` `boss_heavy` `bone_thrower` `tar_spitter` `reactive_bomber` `lane_dummy` + `basic_zombie_skeleton`

### 场物件 (2)

`lawn_mower` + `lawn_mower_skeleton`

### 卡片 (59)

`demo/` (7) `original/` (45+) `phase6/` (5)

### 波次 / 关卡 / 战场 / 模式

| 类别 | 数量 | 位置 |
|------|------|------|
| 波次 | 6 | `waves/demo/` (3) `waves/phase6/` (3) |
| 关卡 | 3 | `levels/phase6/` |
| 战场 | 3 | `battlefields/phase6/` |
| 模式 | 9 | `modes/` 含 mode、input_profile、objective、rule |

## Archetype 编写约定

- 命名：`plant_role_variant` / `zombie_role_variant` / `field_object_name`
- 字段顺序：Identity -> Chassis -> Combat Stats -> Mechanic[]
- 正式实体只用 `CombatArchetype + CombatMechanic[]`，禁止旧模型
- 放置约束走 `placement_role` / `required_placement_tags` / `granted_placement_tags`
- 归档模板在 `plans/archive/legacy-resources/`，运行时不扫描

## 关键资源类型

| 类型 | 用途 |
|------|------|
| `CombatArchetype` | 实体定义根 |
| `CombatMechanic` | 行为片段，挂载于 Archetype |
| `ProjectileTemplate` | 抛射体内容（非发射者） |
| `ProjectileFlightProfile` | 飞行轨迹与命中策略 |
| `HeightBand` | 高度区间，命中判定用 |
| `CardDef` | 卡片定义（费用/冷却/关联 archetype） |
| `WaveDef` | 波次调度模板 |
| `BattleModeDef` | 模式（输入档案 + 规则模块 + 胜负条件） |
