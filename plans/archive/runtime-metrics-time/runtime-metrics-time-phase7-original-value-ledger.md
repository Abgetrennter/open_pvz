# 阶段 7 源码数值审计底账

## 常量

| 常量 | 值 | 来源 |
|------|-----|------|
| ORIGINAL_SLOT_PX | 80.0 | `vendor/de-pvz/Lawn/Board.cpp:9086` GridToPixelX: `theGridX * 80 + LAWN_XMIN` |
| ORIGINAL_TICK_HZ | 100.0 | 原版 tick 直通 Open PVZ simulation tick |
| LAWN_XMIN | 40 | `vendor/de-pvz/GameConstants.h:17` |
| BOARD_WIDTH | 800 | `vendor/de-pvz/GameConstants.h:10` |
| MAX_GRID_SIZE_X | 9 | `vendor/de-pvz/Lawn/Board.h:18` |
| MAX_GRID_SIZE_Y | 6 | `vendor/de-pvz/Lawn/Board.h:19` |

## 换算公式

- distance_slots = original_px / 80.0
- speed_slots_per_sec = original_px_per_tick / 80.0 * 100.0
- seconds = original_ticks / 100.0

## 7.2 植物迁移

### 整行射手（Peashooter / Snow Pea / Repeater）

| 字段 | 原版源码位置 | 原版值 | 换算 | 目标字段 | 目标值 | 目标资源 |
|------|-------------|--------|------|----------|--------|----------|
| 射程 | `Plant::GetPlantAttackRect()` default: `Rect(mX + 60, mY, BOARD_WIDTH, mHeight)` | 全行 | range_mode | `range_mode` | `&"full_lane"` | `data/combat/archetypes/plants/archetype_original_peashooter.tres`, `archetype_original_snowpea.tres`, `archetype_original_repeater.tres` |
| 发射周期 | `vendor/de-pvz/Lawn/Plant.cpp:25,30,32` gPlantDefs[].mLaunchRate | 150 ticks | 150/100 | interval | 1.5 秒 | （若资源仍未校准则更新） |
| 豌豆速度 | `vendor/de-pvz/Lawn/Projectile.cpp:695` UpdateNormalMotion: `mPosX += 3.33f` | 3.33 px/tick | 3.33/80*100 | `speed_slots_per_sec` | 4.1625 | 投射物模板 `pea_linear.tres`, `pea_frost_linear.tres`, `pea_burst.tres` |

**近似说明**：原版攻击矩形是 `Rect(mX + 60, mY, BOARD_WIDTH, mHeight)`，是矩形语义而非标量距离。使用 `range_mode = full_lane` 精确表达原版行为，不投影为标量。

### 短射程蘑菇

| 字段 | 原版源码位置 | 原版值 | 换算 | 目标字段 | 目标值 | 目标资源 |
|------|-------------|--------|------|----------|--------|----------|
| Puff/Sea-shroom 射程 | `Plant::GetPlantAttackRect()`: `Rect(mX + 60, mY, 230, mHeight)` | reach=60+230=290px | 290/80 | `scan_range_slots` | 3.625 | `archetype_original_puffshroom.tres`, `archetype_original_seashroom.tres` |
| Fume-shroom 射程 | `Plant::GetPlantAttackRect()`: `Rect(mX + 60, mY, 340, mHeight)` | reach=60+340=400px | 400/80 | `scan_range_slots` | 5.0 | `archetype_original_fumeshroom.tres` |

**近似说明**：原版攻击矩形投影为标量距离。"reach"定义为从 plant origin (mX) 到攻击矩形远端的水平距离。Puff-shroom: mX+60+230 = mX+290, reach=290px。Fume-shroom: mX+60+340 = mX+400, reach=400px。

### 近身触发植物

| 字段 | 原版源码位置 | 原版值 | 换算 | 目标字段 | 目标值 | 目标资源 |
|------|-------------|--------|------|----------|--------|----------|
| Potato Mine | `Plant::GetPlantAttackRect()`: `Rect(mX, mY, mWidth - 25, mHeight)`, mWidth=80 | reach=80-25=55px | 55/80 | `scan_range_slots` | 0.6875 | `archetype_original_potatomine.tres` |
| Tangle Kelp | `Plant::GetPlantAttackRect()`: `Rect(mX, mY, mWidth, mHeight)`, mWidth=80 | reach=80px | 80/80 | `scan_range_slots` | 1.0 | `archetype_original_tanglekelp.tres` |
| Hypno-shroom | 原版行为是被啃咬触发，不是主动扫描 | 接触近似≈55px | 55/80 | `scan_range_slots` | 0.6875 | `archetype_original_hypnoshroom.tres` |

**近似说明**：
- Potato Mine: 从 mX 到矩形远端 = mWidth-25 = 55px
- Tangle Kelp: 从 mX 到矩形远端 = mWidth = 80px = 1 slot
- Hypno-shroom: **协议近似**。原版行为是被啃咬触发，不是主动圆形扫描。当前 Open PVZ 实现使用 proximity trigger，55/80=0.6875 作为接触近似。

## 7.3 投射物 Profile 迁移

### 直线投射物速度

| 字段 | 原版源码位置 | 原版值 | 换算 | 目标字段 | 目标值 | 目标资源 |
|------|-------------|--------|------|----------|--------|----------|
| 豌豆/冰豌豆/爆裂豌豆速度 | `Projectile::UpdateNormalMotion():695` `mPosX += 3.33f` | 3.33 px/tick | 3.33/80*100 | `speed_slots_per_sec` | 4.1625 | `data/combat/projectile_templates/pea_linear.tres`, `pea_frost_linear.tres`, `pea_burst.tres` |
| Puff projectile | 同默认速度 3.33px/tick + `MOTION_PUFF` 生命周期 75 ticks | 3.33 px/tick | 同上 | 若使用 projectile 则 `speed_slots_per_sec` = 4.1625；若用 direct_damage 则只迁移射程 | — | 视当前实现而定 |
| Spore shot | 当前 spore_shot_linear.tres speed=180 | 无独立原版源码依据 | — | 保留 legacy | — | `spore_shot_linear.tres` |

### 抛物线投射物

| 字段 | 原版源码位置 | 原版值 | 说明 |
|------|-------------|--------|------|
| Lobbed 物理 | `Plant::Fire():4762-4765` `mVelX = aRangeX/120.0f`, `mVelZ = aRangeY/120.0f - 7.0f`, `mAccZ = 0.115f` | 120 tick 轨迹 | **本阶段不简化为 speed_slots_per_sec**；保留 travel_duration / parabola profile 语义 |

**说明**：抛物线投射物不强行归一成固定 speed_slots_per_sec。原版 120 tick 轨迹优先映射为 travel duration / parabola profile 语义。

### Splash / Impact 半径

| 字段 | 原版源码位置 | 原版值 | 换算 | 目标字段 | 目标值 | 目标资源 |
|------|-------------|--------|------|----------|--------|----------|
| impact_radius / collision_padding | — | — | — | — | — | 仅在有原版源码依据时填写 |

**说明**：impact_radius / collision_padding_slots 仅在有原版源码依据或明确 Open PVZ hitbox 近似说明时填写。否则保留 legacy profile 值并标注"非原版数值，本阶段不校准"。

## 7.4 僵尸和割草机迁移

### 普通僵尸

| 字段 | 原版源码位置 | 原版值 | 换算 | 目标字段 | 目标值 | 目标资源 |
|------|-------------|--------|------|----------|--------|----------|
| 移动速度 | `Zombie::PickRandomSpeed():1146` `RandRangeFloat(0.23f, 0.32f)` | 确定性代表值 0.275 px/tick | 0.275/80*100 | `move_speed_slots_per_sec` | 0.34375 | `data/combat/archetypes/zombies/archetype_basic_walker.tres` |

**近似说明**：原版速度是随机范围 [0.23, 0.32]。选 0.275 作为确定性代表值（范围中点）。

### 快速僵尸

| 字段 | 原版源码位置 | 原版值 | 换算 | 目标字段 | 目标值 | 目标资源 |
|------|-------------|--------|------|----------|--------|----------|
| 移动速度 | `Zombie::PickRandomSpeed():1142` `RandRangeFloat(0.89f, 0.91f)` | 代表值 0.9 px/tick | 0.9/80*100 | `move_speed_slots_per_sec` | 1.125 | `data/combat/archetypes/zombies/archetype_brisk_runner.tres` |

**映射假设**：`archetype_brisk_runner` 映射为原版"快速跑者"（Newspaper mad / Dolphin walking），速度范围 0.89~0.91 px/tick。

### 割草机

| 字段 | 原版源码位置 | 原版值 | 换算 | 目标字段 | 目标值 | 目标资源 |
|------|-------------|--------|------|----------|--------|----------|
| 移动速度 | `LawnMower::Update():223` `aSpeed = 3.33f` | 3.33 px/tick | 3.33/80*100 | `move_speed_slots_per_sec` | 4.1625 | `data/combat/archetypes/field_objects/archetype_lawn_mower.tres`, `archetype_lawn_mower_skeleton.tres` |
| 检测半径 | `GetLawnMowerAttackRect():405` `Rect(mPosX, mPosY, 50, 80)` | 50px | 50/80 | `detection_radius_slots` | 0.625 | 同上 |

**近似说明**：攻击矩形宽度 50px 作为检测半径的近似。

## 不迁移项（暂缓）

| 项目 | 原因 |
|------|------|
| spore_shot_linear speed | 无独立原版源码依据，保留 legacy |
| 抛物线投射物 speed | 原版 120 tick 轨迹不简化为 speed_slots_per_sec |
| impact_radius_slots | 无原版明确半径值可提取，保留 legacy profile 值 |
| collision_padding_slots | 无原版依据，本阶段不校准 |
