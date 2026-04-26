# vendor 参考实现：游戏模式系统分析

- 状态：当前事实
- 分析范围：`vendor/Godot-PVZ`（C# 版本）、`vendor/PVZ-Godot-Dream`（GDScript 版本）
- 关联文档：[原版 PVZ 模式系统逆向分析](23-原版PVZ模式系统逆向分析.md)、[外部项目调研 PVZ-Godot-Dream](24-外部项目调研-PVZ-Godot-Dream.md)

---

## 目录

1. [Godot-PVZ 现状评估](#1-godot-pvz-现状评估)
2. [PVZ-Godot-Dream 架构总览](#2-pvz-godot-dream-架构总览)
3. [关卡数据结构](#3-关卡数据结构)
4. [砸罐子 (Vasebreaker) 实现](#4-砸罐子-vasebreaker-实现)
5. [我是僵尸 (I, Zombie) 实现](#5-我是僵尸-i-zombie-实现)
6. [传送带 (Conveyor Belt) 实现](#6-传送带-conveyor-belt-实现)
7. [保龄球 (Bowling) 实现](#7-保龄球-bowling-实现)
8. [生存/无尽模式 (Survival/Endless) 实现](#8-生存无尽模式-survivalendless-实现)
9. [锤僵尸 (Whack-a-Zombie) 实现](#9-锤僵尸-whack-a-zombie-实现)
10. [对 Open PVZ 的架构迁移启示](#10-对-open-pvz-的架构迁移启示)

---

## 1. Godot-PVZ 现状评估

> 源码路径：`vendor/Godot-PVZ/src/plants-vs-zombies/`
> 语言：C# (Godot 4.x)

### 1.1 已实现内容

Godot-PVZ 实现了一个基础的冒险模式战斗框架：

| 系统 | 实现状态 | 关键文件 |
|------|---------|---------|
| 主游戏循环 | 已实现 | `MainGame/MainGame.cs` (691 行) |
| 场景系统 | 已实现 | `MainGame/Common/Scene.cs` — `LawnDayScene`、`PoolDayScene`（未使用） |
| 波次出怪 | 已实现 | `MainGame/Zombies/ZombieWeightsAndGrades.cs` — 权重随机 + 等级系统 |
| 僵尸基类 | 已实现 | `MainGame/Zombies/Zombie.cs` — 状态机（行走/啃食/断臂/掉头/死亡） |
| 植物基类 | 已实现 | `MainGame/Plants/Plants.cs` — 种植/扣血/释放 |
| 种子银行 | 已实现 | `MainGame/SeedBank.cs` — 阳光计数/更新 |
| 实体继承链 | 已实现 | `Entity → HealthEntity → Plants / Zombie` |
| 护甲系统 | 已实现 | `MainGame/Armor/` — 8 种护甲类型 |
| 状态效果 | 已实现 | `MainGame/Effects/` — 冻结/减速/狂暴 + `StatusEffectManager` |
| 状态机 | 已实现 | `MainGame/Common/StateMachine.cs` — 泛型，支持延迟切换和循环模式 |

### 1.2 未实现内容

| 功能 | 状态 | 证据 |
|------|------|------|
| 迷你游戏 | 未实现 | 无任何 MiniGame 目录或代码 |
| 无尽/生存模式 | 未实现 | `ZombieMaxWave = 20` 硬编码，无多轮循环 |
| 砸罐子 | 未实现 | 无罐子/GridItem 相关代码 |
| 我是僵尸 | 未实现 | 无僵尸放置/大脑相关代码 |
| 传送带 | 未实现 | 无传送带卡槽代码 |
| 多场景切换 | 未实现 | `PoolDayScene` 已定义但未使用 |
| 关卡系统 | 未实现 | 无关卡数据/选关界面 |

### 1.3 波次系统详情

`ZombieWeightsAndGrades.cs` 实现了一个简化的出怪系统：

```
僵尸权重表：
  Normal:    4000 (等级 1)
  Conehead:  2000 (等级 2)
  Screendoor: 1500 (等级 3)
  Buckethead: 1000 (等级 4)

波次容量 = int(int(currentWave * 0.8) / 2) + 1
大波 (每10波) 容量 *= 2.5

出怪行选择算法：
  使用平滑权重系统（参考 wiki.pvz1.com 出怪机制）
  Weight_i, LastPicked_i, SecondLastPicked_i
  → SmoothWeight_i = WeightP_i * clamp(PLast + PSecondLast, 0.01, 100)
```

### 1.4 主菜单状态

主菜单素材中包含 Vasebreaker 和 Survival 按钮纹理（`art/MainMenu/SelectorScreen_Survival_button.png`、`SelectorScreen_Vasebreaker_button.png`），但 `StartAdventureButton.cs` 直接跳转到唯一的 `MainGame.tscn`，无模式选择逻辑。

---

## 2. PVZ-Godot-Dream 架构总览

> 源码路径：`vendor/PVZ-Godot-Dream/`
> 语言：GDScript (Godot 4.x)
> 详细架构分析见 [pvz-godot-dream/](pvz-godot-dream/)

### 2.1 游戏模式入口体系

`MainSceneRegistry` 枚举定义了所有场景/模式入口：

**战斗场景 (0-2)：**

| 枚举值 | 含义 | 场景文件 |
|--------|------|----------|
| `MainGameFront` (0) | 前院战斗（白天/黑夜） | `MainGame01Front.tscn` |
| `MainGameBack` (1) | 后院战斗（泳池/浓雾） | `MainGame02Back.tscn` |
| `MainGameRoof` (2) | 屋顶战斗 | `MainGame03Roof.tscn` |

**选关/菜单场景 (100+)：**

| 枚举值 | 含义 | 场景文件 |
|--------|------|----------|
| `StartMenu` (100) | 主菜单 | `01StartMenu.tscn` |
| `ChooseLevelAdventure` (101) | 冒险模式选关 | `02AdventureChooesLevel.tscn` |
| `ChooseLevelMiniGame` (102) | 迷你游戏选关 | `03MiniGameChooesLevel.tscn` |
| `ChooseLevelPuzzle` (103) | 益智/砸罐子选关 | `04PuzzleChooesLevel.tscn` |
| `ChooseLevelSurvival` (104) | 生存模式选关 | `05SurvivalChooesLevel.tscn` |
| `ChooseLevelCustom` (105) | 自定义关卡选关 | `06CustomChooesLevel.tscn` |

主菜单提供 5 个模式入口按钮 + 3 个辅助功能（花园/图鉴/商店），统一使用 `get_tree().change_scene_to_file()` 切换。

### 2.2 核心设计理念：数据驱动的统一参数化

PVZ-Godot-Dream 的核心设计是 **统一的参数化关卡数据驱动一切模式差异**。所有模式共用同一套战斗框架（`MainGameManager`），差异完全通过 `ResourceLevelData` 的 `@export` 字段组合表达。

```
                  ┌─ game_sences        → 战斗场景 (前院/后院/屋顶)
                  ├─ card_mode          → 卡牌策略 (Normal/ConveyorBelt/Coin)
                  ├─ monster_mode       → 出怪模式 (Null/Norm/HammerZombie)
                  ├─ is_pot_mode        → 罐子模式开关
ResourceLevelData ┤─ is_zombie_mode     → 我是僵尸开关
                  ├─ is_bowling_stripe  → 保龄球红线
                  ├─ game_round         → 多轮/无尽 (-1=无尽)
                  └─ max_wave           → 总波次
```

### 2.3 核心管理器清单

| 管理器 | 职责 | 文件 |
|--------|------|------|
| `MainGameManager` | 游戏阶段状态机、多轮循环主控 | `scripts/manager/main_game_manager.gd` |
| `ZombieManager` | 僵尸生成、出怪种类递增 | `scripts/manager/zombie_manager/zombie_manager.gd` |
| `PlantCellManager` | 植物格子管理、罐子生成、多轮植物处理 | `scripts/manager/plant_cell_manager/plant_cell_manager.gd` |
| `CardManager` | 卡牌系统、策略模式分发到三种卡槽 | `scripts/manager/card_manager.gd` |
| `GameItemManager` | 场上物件（大脑/锤子/保龄球红线等） | `scripts/manager/game_item_manager/game_item_manager.gd` |

---

## 3. 关卡数据结构

### 3.1 ResourceLevelData 概览

`ResourceLevelData`（`scripts/resources/level/level_data.gd`）是一个大型 `Resource` 类，按 `@export_group` 分为 8 个参数区：

#### 参数区 1：选关与存档（运行时变量，非 export）

```gdscript
var game_mode          # 游戏模式标识
var level_page         # 关卡所在页码
var level_id           # 关卡唯一标识（4位补零字符串）
var save_game_name     # 存档文件名 "{mode}_{page}_{id}"
```

#### 参数区 2：关卡背景参数

```gdscript
@export var game_sences           # 战斗场景类型 (Front/Back/Roof)
@export var game_round: int       # 轮次, -1=无尽
@export var game_BG               # 背景 (FrontDay/FrontNight/Pool/Fog/Roof)
@export var game_BGM              # 背景音乐 (8种, 含MiniGame/Boss/Puzzle)
@export var is_fog / is_rain / is_day / is_day_sun / is_lawn_mover
@export var all_pre_plant_data    # 预种植植物列表
```

#### 参数区 3：关卡流程参数

```gdscript
@export var look_show_zombie      # 开局展示僵尸
@export var can_choosed_card      # 是否能选卡（传送带强制false）
@export var crazy_dave_dialog     # 戴夫对话
```

#### 参数区 4：出怪参数

```gdscript
@export var monster_mode          # 出怪模式 (Null/Norm/HammerZombie)
@export var is_mini_zombie        # 小僵尸开关
@export var zombie_multy          # 出怪倍率
@export var max_wave              # 总波次
@export var zombie_refresh_types  # 僵尸种类刷新列表
@export var is_bungi / range_num_bungi   # 蹦极僵尸
# 锤僵尸子参数：速度、速度提升、上限
# 墓碑参数：是否有墓碑、初始墓碑数
```

#### 参数区 5：卡片参数

```gdscript
@export var card_mode             # 卡槽模式 (Null/Norm/ConveyorBelt/Coin)
@export var is_seed_rain          # 种子雨开关
# 正常卡槽：max_choosed_card_num, start_sun, 预选卡列表
# 传送带参数：植物/僵尸类型概率表、出卡顺序、出卡速度
# 种子雨参数：独立的概率表和顺序表
```

#### 参数区 6：罐子参数

```gdscript
@export var is_pot_mode
@export var pot_mode              # 生成模式 (Null/Weight/Fixd)
@export var pot_col_range         # 罐子列范围
@export var is_can_look_random_res_pot   # 结果随机罐子是否永久可观察
@export var is_save_plant_on_pot_mode    # 多轮是否保留植物
# Weight 模式参数：weight_res_fiexd, candidate_plant_pot, candidate_zombie_pot, weight_pot_type
# Fixd 模式参数：random_pot_plant, random_pot_zombie, plant_pot, zombie_pot, random_pot_num_on_fixed_mode
```

#### 参数区 7：我是僵尸参数

```gdscript
@export var is_zombie_mode
@export var plant_col_on_zombie_mode           # 植物列数
@export var all_plants_weight_on_zombie_mode   # 植物随机权重池
@export var all_must_plants_on_zombie_mode     # 必选植物表
```

#### 参数区 8：迷你游戏物品参数

```gdscript
# 保龄球红线：列限制、种植/僵尸区域控制
# 锤子
```

### 3.2 参数约束修正

`init_para()` 方法在游戏开始时根据参数组合做一次性约束修正：

```gdscript
func _apply_card_mode_constraints():
    match card_mode:
        ConveyorBelt:
            can_choosed_card = false   # 传送带模式禁止选卡
            is_day_sun = false         # 禁止天降阳光

func _apply_zombie_mode_rules():
    if is_zombie_mode:
        is_zombie_can_home = false     # 禁止僵尸自动回家
```

### 3.3 关卡选择流程

`ChooseLevel`（`scripts/choose_level/choose_level.gd`）逻辑：

1. 冒险模式默认开放 1 关，其他模式默认开放 3 关，自定义全开放
2. 无尽关卡（`game_round == -1`）永远开放，不占名额
3. 点击关卡 -> 设置 `Global.game_para` -> 根据 `game_sences` 加载对应战斗场景
4. 从游戏退出时通过 `level_page` 恢复页码

---

## 4. 砸罐子 (Vasebreaker) 实现

### 4.1 架构概览

| 类 | 文件 | 职责 |
|----|------|------|
| `ScaryPot` | `scripts/main_game_item/scary_pot.gd` | 罐子本体，状态管理、内容决定、观察机制 |
| `PlantCellManager` | `scripts/manager/plant_cell_manager/plant_cell_manager.gd` | 罐子生成管理器，两种模式入口 |
| `PlantCell` | `scripts/main_game_item/plant_cell.gd` | 植物格子，罐子的载体 |
| `PotAllVaseChunks` | `scripts/main_game_item/pot_all_vase_chunks.gd` | 碎片容器，生成多块碎片 |
| `PotVaseChunkDrop` | `scripts/main_game_item/pot_vase_chunks.gd` | 单块碎片，物理弹跳动画 |
| `PotHammer` | `scripts/main_game_item/pot_hammer.gd` | 砸罐子锤子动画 |

### 4.2 罐子状态管理

**罐子类型枚举：**

```gdscript
enum E_PotType {
    Random,   # 随机罐子（外观未知）
    Plant,    # 植物罐子（绿色外观）
    Zombie,   # 僵尸罐子（僵尸色外观）
}
```

**核心状态变量：**

```gdscript
var is_open := false              # 是否已打开
var pot_type: E_PotType           # 罐子类型（决定外观）
var is_fixed_res := true          # 是否为固定结果（vs 开罐时随机）
var curr_plant_type: PlantType    # 罐内植物
var curr_zombie_type: ZombieType  # 罐内僵尸
```

**状态流转：**

```
[生成] init_pot() → 设置 pot_type / is_fixed_res / 内容类型
  │
  ▼
[存在中] 鼠标悬停 → 高亮(modulate=2,2,2); 植物靠近 → 可观察虚影
  │
  ▼
[被打开] open_pot() → is_open=true → 碎片动画 → 生成内容 → queue_free()
```

### 4.3 两种罐子生成模式

#### Weight 模式（权重随机）

`PlantCellManager.create_all_pot_on_weigth_mode()` 每个格子独立生成：

1. 罐子外观类型由 `weight_pot_type: Vector3i` 控制（默认 `(6,2,2)` = Random 60%/Plant 20%/Zombie 20%）
2. 是否固定结果由 `weight_res_fiexd` 控制（默认 1.0 = 100% 固定）
3. 具体内容从 `candidate_plant_pot` / `candidate_zombie_pot` 候选池按权重选取

#### Fixd 模式（固定数量+随机位置）

`PlantCellManager.create_all_pot_on_fixed_mode()` 预定义数量，按优先级分配位置：

```
优先级分配顺序：
1. 陆地僵尸罐子 (按行类型 Land/Pool 先分配)
2. 水路僵尸罐子
3. Both 类型僵尸罐子
4. 随机外观僵尸罐子 (random_pot_zombie)
5. 固定外观僵尸罐子 (zombie_pot)
6. 随机外观植物罐子 (random_pot_plant)
7. 固定外观植物罐子 (plant_pot)
8. 结果随机罐子 (random_pot_num_on_fixed_mode)
9. 剩余空格子 → 默认结果随机 Random 类型
```

### 4.4 开罐时的随机内容决定

非固定结果罐子在打开瞬间才决定内容：

```gdscript
func random_res():
    match pot_type:
        E_PotType.Random:
            if randf() <= 0.5:  # 50% 植物
                curr_plant_type = whitelist_plant_types_with_pot.pick_random()
            else:               # 50% 僵尸
                curr_zombie_type = whitelist[当前行僵尸类型].pick_random()
        E_PotType.Plant:
            curr_plant_type = whitelist_plant_types_with_pot.pick_random()
        E_PotType.Zombie:
            curr_zombie_type = whitelist[当前行僵尸类型].pick_random()
```

僵尸选择考虑当前行的行类型（Land/Pool），水路行只抽水路僵尸。

### 4.5 三种开罐途径

| 方式 | 函数 | 触发者 |
|------|------|--------|
| 锤子砸 | `open_pot_be_hammar()` | 玩家点击罐子 |
| 爆炸 | `open_pot_be_bomb()` | 小丑僵尸 (JackboxBomb) 爆炸波及 |
| 巨人踩 | `open_pot_be_gargantuar()` | 伽刚特尔巨人僵尸攻击 |

三者统一调用 `open_pot()`，有幂等性保护（`if is_open: return`）。

### 4.6 碎片物理动画

`PotAllVaseChunks` 生成 8~12 个碎片，每个碎片有：
- 水平速度 [-30, 30] px/s
- 旋转速度 [-5, 5] rad/s
- 随机偏移和帧图

`PotVaseChunkDrop` 实现简易物理：
```gdscript
gravity = 500.0
bounce_damping = 0.5
每帧: velocity.y += gravity * delta; position += velocity * delta
落地: velocity.y = -velocity.y * bounce_damping (或淡出消失)
```

碎片颜色根据罐子类型变化（三种外观 = 三种颜色碎片）。

### 4.7 观察/预览机制

特定植物靠近罐子时可"看穿"显示虚影：
- `add_plant_can_look_pot(plant)` — 注册观察者
- 有观察者时隐藏罐子前壁、显示角色虚影
- 所有观察者死亡 → 恢复（除非永久可观察的结果随机罐子）
- 结果随机罐子的虚影每 0.3 秒在候选角色间随机切换

### 4.8 胜利条件

```gdscript
# PlantCellManager.pot_open_update()
func pot_open_update(is_zombie, glo_pos):
    curr_pot_num -= 1
    if curr_pot_num == 0:
        if is_zombie or zombie_manager.curr_zombie_num != 0:
            end_wave_zombie   # 还有僵尸，等全灭
        else:
            create_trophy     # 直接胜利，生成奖杯
```

条件：所有罐子打开 + 场上无僵尸。

---

## 5. 我是僵尸 (I, Zombie) 实现

### 5.1 角色翻转设计

| 维度 | 普通模式 | 我是僵尸模式 |
|------|---------|------------|
| 玩家操控 | 植物（防守方） | 僵尸（通过卡牌放置） |
| 经济资源 | 阳光 | 大脑（复用 `sun_cost` 字段） |
| 敌方单位 | 僵尸自动刷出 | 植物预设在场地上（按权重随机） |
| 胜利目标 | 消灭所有僵尸 | 吃掉所有大脑（每行一个） |
| 卡牌系统 | 植物卡牌 | 僵尸卡牌（复用完整卡牌系统） |

### 5.2 大脑 (Brain) 系统

`brain_on_zombie_mode.gd`：
- 继承 `MainGameItemBase`，HP=100
- 每行一个大脑，放在第一列植物格位置
- 被啃食掉血，被碾过即死
- 死亡发射 `signal_brain_death` + 掉落金币动画

`gim_brain.gd`（大脑管理器）：
- `create_all_brain_on_zombie_mode()` 为每行创建大脑（x=20, y=该行僵尸生成点）
- 追踪 `curr_brain_num` 计数器
- `curr_brain_num == 0` → 发射 `"create_trophy"`（胜利）

### 5.3 僵尸卡牌放置系统

#### 卡牌数据复用

```gdscript
# card_base.gd 同时支持植物和僵尸
@export var card_plant_type: PlantType
@export var card_zombie_type: ZombieType
@export var sun_cost: int = 100       # 僵尸卡复用此字段
@export var cool_time: float = 7.5

# all_cards.gd 维护两个独立字典
@export var all_plant_card_prefabs: Dictionary[PlantType, Card]
@export var all_zombie_card_prefabs: Dictionary[ZombieType, Card]
```

#### 放置逻辑

`hm_character.gd`（手持管理器）：
- 点击僵尸卡片 → 检查格子 `can_common_zombie` + 僵尸地形类型匹配
- 虚影显示：地形匹配 alpha=0.5，不匹配隐藏
- 点击种植：`zombie_manager.create_norm_zombie()` 放置到格子中心 x + 行僵尸生成点 y

#### 僵尸放置限制

```gdscript
# I, Zombie 模式下：
# 1. 只能放在"红线"右侧
# 2. 不能放在已有僵尸的格子
# 3. 蹦极僵尸特殊：只能放在列 ≥ aColumns
# 4. 其他僵尸：只能放在列 < aColumns
```

### 5.4 植物阵容生成

`PlantCellManager.create_plant_on_zombie_mode()`：
1. 收集可放置格子（按 `plant_col_on_zombie_mode` 列数限制）
2. 先放必选植物 (`all_must_plants_on_zombie_mode`)，随机打散位置
3. 剩余格子从随机池 (`plant_random_pool_on_zombie_mode`) 按权重填充
4. 多轮更新：向日葵权重随轮次递减 `max(9-round, 1)` 增加难度

### 5.5 经济来源

- 向日葵被啃食时 `_on_be_eat_once()` 产出阳光
- 向日葵死亡时 `_on_character_death()` 也产出阳光
- 其他植物被杀不产阳光
- 阳光用于购买僵尸"种子"

### 5.6 模式特定行为

- 僵尸速度统一为 1.0（`random_speed_range = Vector2(1, 1)`）
- 土豆地雷即放即炸（跳过准备时间）
- 向日葵禁用自动产阳组件
- 僵尸到达最左侧啃食大脑

---

## 6. 传送带 (Conveyor Belt) 实现

### 6.1 策略模式分发

`CardManager` 通过 `match card_mode` 分发到三种卡槽：

```gdscript
match game_para.card_mode:
    Norm:        → CardSlotNorm (正常选卡/战斗卡槽)
    ConveyorBelt: → CardSlotConveyorBelt (传送带)
    Coin:        → CardSlotCoin (金币购买)
```

### 6.2 卡片生成算法

两层决策架构（`card_slot_conveyor_belt.gd`）：

```gdscript
func _create_new_card():
    # 第一层：查固定顺序字典
    if card_order_plant.has(all_num_card):
        return all_plant_card_prefabs[card_order_plant[all_num_card]]
    elif card_order_zombie.has(all_num_card):
        return all_zombie_card_prefabs[card_order_zombie[all_num_card]]

    # 第二层：走随机池
    return card_random_pool.get_random_card()
```

随机池使用 **Alias Method（别名法）** 实现 O(1) 加权随机采样：
- 先决定植物还是僵尸阵营
- 再在阵营内按权重抽取具体卡片
- `RandomPicker` 类构建别名表，保证每次 `get_random_item()` O(1)

### 6.3 传送带参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `num_card_max` | 10 | 卡片上限 |
| `create_new_card_cd` | 5 秒 | 基础出卡间隔 |
| `create_new_card_speed` | 从关卡数据读取 | 速度倍率，实际 CD = 5/speed |
| `conveyor_velocity` | 30 px/帧 | 滑动速度 |

### 6.4 视觉滚动动画

```gdscript
func _process(delta):
    if is_working:
        for i in curr_cards.size():
            if curr_cards[i].position.x > all_card_pos_x_target[i]:
                curr_cards[i].position.x -= delta * conveyor_velocity
            else:
                curr_cards[i].position.x = all_card_pos_x_target[i]
```

新卡片从右侧生成，以 30px/帧滑动到目标位置。10 个目标位置等间距分布（50px 间隔）。齿轮装饰动画独立控制。出场/退场用 Tween 滑入/滑出。

### 6.5 强制约束

传送带模式自动应用：
- `can_choosed_card = false`（禁止选卡）
- `is_day_sun = false`（禁止天降阳光）
- 无冷却时间、无阳光消耗

---

## 7. 保龄球 (Bowling) 实现

### 7.1 三种保龄球子弹

均继承自 `BulletLinear000Base`：

| 类型 | 类名 | 行为 |
|------|------|------|
| 普通 | `Bullet1001Bowling` | 碰僵尸后跳行，到达新行继续攻击 |
| 爆炸 | `Bullet1002BowlingBomb` | 碰到第一个敌人范围爆炸，一次消耗 |
| 巨型 | `Bullet1003BowlingBig` | 碰到即杀，穿透所有敌人持续前进 |

### 7.2 普通保龄球行间弹跳

核心运动逻辑：
1. 沿直线前进（`direction: Vector2.RIGHT`）
2. 碰僵尸后 `_update_direction()` 修改 `direction.y` 偏离当前行
3. 到达下一行 y 坐标附近时，攻击缓存敌人并继续前进

方向更新规则：
```gdscript
func _update_direction():
    if lane == 0: direction.y = 1           # 第0行只能向下
    elif lane == last_lane: direction.y = -1 # 最后行只能向上
    else:
        if direction.y == 0: direction.y = 1 or -1 (随机)
        else: direction.y *= -1              # 反弹
```

视觉效果：`body_correct.rotation += rotation_speed * delta`（持续旋转模拟滚动）。

### 7.3 保龄球红线 (WallnutBowlingStripe)

红线将棋盘分为左右两半，通过四个布尔标志控制：

| 标志 | 保龄球配置 | 含义 |
|------|-----------|------|
| `left_can_plant` | true | 左侧可种植（保龄球坚果） |
| `right_can_plant` | false | 右侧不可种植（滚动区域） |
| `left_can_zombie` | true | 左侧可有僵尸 |
| `right_can_zombie` | true | 右侧可有僵尸（僵尸从右进） |

### 7.4 与传送带配合

保龄球关卡完整工作流：
1. `card_mode = ConveyorBelt` + `is_bowling_stripe = true`
2. 传送带固定前 3 张不同保龄球（普通→爆炸→巨型）
3. 之后按权重随机（普通 50%/爆炸 25%/巨型 25%）
4. 玩家在红线左侧放置保龄球坚果 → 角色消失 → 发射保龄球子弹

---

## 8. 生存/无尽模式 (Survival/Endless) 实现

### 8.1 无尽标识

```gdscript
@export var game_round: int = 1   # -1 表示无尽
```

当 `game_round = -1` 时，`curr_game_round`（从 1 递增）永远不等于 -1，永不创建奖杯。

### 8.2 多轮循环核心流程

```
最后一波全灭 / 49秒超时
  │
  ▼
create_trophy()
  └─ curr_round != game_round(-1)?
     └─ start_next_round_game()
        ├─ save_game() (植物/波次/阳光/卡槽/小推车)
        ├─ 等待 3s + 暂停游戏
        ├─ curr_game_round++
        ├─ 暂停天降阳光
        ├─ 卡牌冷却重置 + 回收到选卡槽
        ├─ 更新出怪种类 (min(round*2, 8) + 3 固定种)
        ├─ max_wave += 30 (波次累加)
        ├─ 保留植物 / 清除重铺(僵尸模式/罐子模式)
        ├─ 重新选卡
        └─ main_game_start()
```

### 8.3 出怪强度递增

#### 种类递增

```
第 1 轮：固定 3 种（普僵 + 路障 + 铁桶）
第 2 轮起：3 固定 + min(round*2, 8) 额外种
  → 第2轮: 6种, 第3轮: 8种, 第4轮+: 10种(上限)
```

额外种类从白名单随机抽取，蹦极僵尸自动转为 `is_bungi` 标记。

#### 波次战力递增

```gdscript
func calculate_wave_power_limit(wave, is_big_wave):
    var base = wave / 3 + 1
    if is_big_wave: return int(base * 2.5) * zombie_multy
    return base * zombie_multy
```

#### 权重调整

波次 5~25 之间：
```
普僵权重: 4000 → 400 (递减 -180/波)
路障权重: 4000 → 1000 (递减 -150/波)
```

越往后高级僵尸出现概率越高。

#### 波次累加

`max_wave` 每轮 +30（累加），后续轮次从一开始就面对更高战力僵尸。

### 8.4 多轮状态管理

| 状态 | 生存模式 | 僵尸模式 | 罐子模式 |
|------|---------|---------|---------|
| 植物 | 保留 | 清除+重新随机 | 按 `is_save_plant_on_pot_mode` |
| 阳光 | 继承（存档传递） | 继承 | 继承 |
| 卡牌冷却 | 全部重置 | 全部重置 | 全部重置 |
| 选卡 | 允许重选 | 允许重选 | 允许重选 |
| 天降阳光 | 暂停→恢复 | 暂停→恢复 | 暂停→恢复 |

### 8.5 存档系统

```gdscript
# save_game_main_game.gd
curr_game_round: int              # 当前轮次
plant_cell_manager_data           # 所有植物格子数据
curr_max_wave: int                # 累加后的最大波次
curr_wave: int                    # 当前波次
day_sun_curr_sun_sum_value: int   # 天降阳光已产出总量
card_manager_data: Dictionary     # 卡槽数据（含阳光余额）
lawn_mover_manager_data: Dictionary # 小推车数据
```

存档时机：每轮结束时 `start_next_round_game()` 开头。读档时机：`game_round != 1` 时自动加载。

### 8.6 失败条件

僵尸进房（`on_zombie_go_home`）直接触发游戏失败，不区分无尽/普通模式。无尽模式无胜利条件。

---

## 9. 锤僵尸 (Whack-a-Zombie) 实现

### 9.1 全局锤子道具

`hammer.gd`（`scripts/main_game_item/mini_game_items/hammer.gd`）：

```gdscript
# 核心行为
- 跟随鼠标: position = get_global_mouse_position()
- 隐藏系统光标: Input.set_mouse_mode(MOUSE_MODE_HIDDEN)
- 左键点击: 播放 "Hammer_whack_zombie" 动画
- 锤击检测: Area2D 碰撞 → 选择最左边的僵尸 → 造成 1800 伤害
- 掉落阳光: 僵尸被锤死时 pred_sun 概率掉落 3 个阳光
- 只在 MAIN_GAME 阶段激活
```

### 9.2 罐子锤子 vs 全局锤子

| 维度 | PotHammer（罐子锤子） | Hammer（全局锤子） |
|------|---------------------|-------------------|
| 用途 | 砸罐子时的动画 | 锤僵尸迷你游戏的全局道具 |
| 生命周期 | `activate_it()` → 播放动画 → `queue_free()` | 跟随整个关卡 |
| 交互方式 | 自动播放 | 跟随鼠标，玩家点击触发 |
| 伤害 | 无（只触发开罐） | 1800 伤害 |

---

## 10. 对 Open PVZ 的架构迁移启示

### 10.1 PVZ-Godot-Dream 的设计优点

1. **完全数据驱动**：所有模式参数通过 `ResourceLevelData` 的 `@export` 在编辑器中配置，无需改代码
2. **高度复用**：僵尸模式复用植物卡牌系统、大脑复用 `sun_cost`、手持管理器统一处理植物/僵尸放置
3. **Alias Method O(1) 采样**：传送带卡片随机池性能优秀
4. **碎片物理轻量级**：重力+弹跳+旋转衰减，无物理引擎依赖

### 10.2 PVZ-Godot-Dream 的设计问题

1. **散弹枪修改**：`is_zombie_mode` 布尔开关散布在 20+ 个文件中，修改一个模式需要检查所有相关文件
2. **巨类 Resource**：`ResourceLevelData` 承载了 8 个参数组、数十个字段，职责过重
3. **布尔组合爆炸**：模式差异通过大量布尔开关的组合表达，缺少正交分类
4. **运行时 if 链**：`MainGameManager` 中大量 `if is_zombie_mode` / `if is_pot_mode` 分支

### 10.3 Open PVZ 的 Mechanic-first 架构优势

Open PVZ 的 Mechanic-first 架构天然适合解决上述问题：

| PVZ-Godot-Dream 方式 | Open PVZ 方式 |
|---------------------|---------------|
| `is_zombie_mode` 散布 20+ 文件 | Mechanic 组合在编译时一次性注入 |
| 运行时 `if is_pot_mode` | `PotMechanic` 编译为 `RuntimeSpec` 的一部分 |
| 卡槽策略 switch | `CardSlotStrategy` 注册表分发 |
| `game_round = -1` + `curr_round` 比较 | `BattleFlowState` 阶段机扩展循环 |

### 10.4 推荐的模式抽象

```
GameModeDefinition : Resource
  ├── mode_id: StringName
  ├── category: ModeCategory         # adventure / survival / challenge / puzzle
  ├── scene_type: SceneType          # front / back / roof
  ├── seed_strategy: SeedStrategy    # choose / conveyor / fixed / none
  ├── zombie_wave_policy: WavePolicy # fixed / dynamic / survival
  ├── stage_policy: StagePolicy      # single / multi / endless
  ├── win_condition: WinCondition    # all_zombies_dead / all_brains_eaten / all_pots_open
  ├── grid_items: GridItemDef[]      # 罐子/大脑/传送门/墓碑
  ├── mechanics: Mechanic[]          # 模式专属 Mechanic 组合
  └── special_rules: Resource        # 模式特定参数（保龄球/锤子等）
```

各模式差异封装为不同 Mechanic 组合，通过 Archetype 编译链一次性注入，运行时无需检查布尔标志。

### 10.5 关键迁移要点

1. **罐子系统**：需要新的 Mechanic family 或 Entity 子系统，罐子作为 GridItem 存在而非 PlantCell 特殊状态
2. **僵尸放置**：`EntityFactory` 已支持双路径实例化，扩展为支持"从种子栏放置僵尸"
3. **传送带**：需要 `CardSlotStrategy` 接口 + Alias Method 随机池
4. **多轮循环**：`BattleFlowState` 阶段机扩展，`WaveRunner` 增加轮次递增和强度缩放
5. **存档**：需要跨轮次的状态快照/恢复机制
