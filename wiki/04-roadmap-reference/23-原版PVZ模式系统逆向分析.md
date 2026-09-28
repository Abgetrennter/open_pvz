# 原版 PVZ 模式系统逆向分析

> **reference_only（2026-09-28，P3.8b）**：本文主体（第 1-10 节，原版模式系统静态逆向事实）已迁移至知识层主文档：
>
> **E:/Code/pvz-ws/knowledge/original-mode-system-reverse.md**（页面 ID original/mode-system-reverse）
>
> 本页只保留第 11 节「对 open_pvz 的架构迁移启示」——它是 OpenPVZ 侧的设计推论，正确性由我们裁决，属项目层内容。原版事实的锚点修正一律在知识层主文档进行。

---

## 11. 对 open_pvz 的架构迁移启示

### 11.1 原版的痛点

1. **Challenge 类是 God Class**：5700 行，所有模式逻辑耦合在一起，`if/switch` 泛滥
2. **模式识别散落各处**：`IsScaryPotterLevel()` / `IsSurvivalMode()` 等 20+ 个布尔判断分布在 `Board`、`LawnApp`、`Challenge` 各处
3. **无尽/阶段逻辑不统一**：Survival 用"旗帜+波次"、砸罐/IZombie 用 `mSurvivalStage`+streak，但都复用同一个字段
4. **关卡内容硬编码**：每个 `SCARY_POTTER_N` / `I_ZOMBIE_N` 的配置直接写在 `switch` 分支里
5. **Board 与模式强耦合**：`GetNumSeedsInBank()` / `HasConveyorBeltSeedBank()` / `PickBackground()` 等全是巨型 switch

### 11.2 映射到 open_pvz 的 Mechanic 体系

#### 场景/模式标识

原版的 `GameMode` 枚举 + `GameScene` 枚举 → open_pvz 可用 `GameModeDefinition : Resource` 替代：

```
GameModeDefinition : Resource
  ├── mode_id: StringName            ← 唯一标识
  ├── category: ModeCategory         ← adventure / survival / challenge / puzzle
  ├── background: BackgroundType     ← 视觉层
  ├── sub_stages: int                ← 子关卡数（砸罐9+1, IZombie 9+1）
  ├── is_endless: bool               ← 无尽标记
  
  ├── seed_strategy: SeedStrategy    ← 自选/传送带/固定/无
  ├── seed_bank_size: int
  ├── fixed_seeds: SeedType[]        ← 固定种子列表
  ├── conveyor_seeds: SeedPoolDef    ← 传送带种子池
  
  ├── initial_sun: int               ← 初始阳光
  ├── zombie_waves: WaveDef          ← 波次定义（固定列表/动态生成/无）
  ├── zombie_pool: ZombiePoolDef     ← 允许的僵尸类型
  ├── num_waves: int                 ← 总波数
  
  ├── win_condition: WinCondition    ← 胜利条件
  ├── lose_condition: LoseCondition  ← 失败条件
  ├── stage_transition: StageTransitionDef ← 阶段流转策略
  
  ├── grid_layout: GridLayoutDef     ← 行类型覆盖
  ├── grid_items: GridItemDef[]      ← 初始格子物件（罐子/脑子/传送门）
  ├── plant_layout: PlantLayoutDef[] ← 预放置植物（IZombie）
  
  ├── cursor_type: CursorType        ← 光标类型（普通/锤子/铲子）
  ├── special_rules: Mechanic[]      ← 模式专属 Mechanic
```

#### 策略模式替代 if/switch

每种模式的独特行为注册为 `GameModeStrategy`（类似现有的 `ControllerRegistry`）：

```
GameModeStrategy (接口)
  ├── init_level()           ← 替代 Challenge::InitLevel 的 switch
  ├── start_level()          ← 替代 Challenge::StartLevel 的 switch
  ├── update()               ← 替代 Challenge::Update 的 if 链
  ├── mouse_down/up/move()   ← 替代 Challenge::Mouse 的 switch
  ├── can_plant_at()         ← 替代 Challenge::CanPlantAt
  ├── check_complete()       ← 模式专属完成判定
  └── draw_overlay()         ← 模式专属渲染
```

注册到 `GameModeRegistry`（类似 `MechanicCompilerRegistry`），运行时按 `GameModeDefinition.mode_id` 查找策略分发。

#### 阶段管理抽象

`StageManager` 组件：
```
StageManager
  ├── m_current_stage: int
  ├── m_max_stages: int          ← 0 表示无尽
  ├── stage_complete() → 根据模式策略决定:
  │   ├── 重选卡 → 弹出种子选择
  │   ├── 重新生成 → PuzzleNextStageClear()
  │   └── 结束 → 结算
  ├── difficulty_curve: Resource ← 数据驱动的难度曲线
  └── on_stage_changed: Signal
```

#### 格子物件通用化

原版 `GridItem` 的类型和状态 → open_pvz 的 `GridItemArchetype`：

```
GridItemArchetype : Resource
  ├── item_type: StringName       ← "scary_pot" / "brain" / "portal" / "gravestone"
  ├── visual_state: StringName    ← "question" / "leaf" / "zombie"
  ├── content_type: StringName    ← "seed" / "zombie" / "sun"
  ├── content_ref: Resource       ← SeedType / ZombieArchetype / sun_amount
  ├── mechanics: Mechanic[]       ← 交互行为（被砸开/被吃/传送）
```

罐子破坏 = `Trigger(on_mallet)` → `Effect(spawn_content) + Effect(remove_grid_item)`
脑子被吃 = `Trigger(on_eaten)` → `Effect(score_brain) + Effect(remove_grid_item)`

#### I, Zombie 的角色反转

- 僵尸种子卡 = `SeedPacket` 关联 `ZombieArchetype` 而非 `PlantArchetype`
- `EntityFactory` 已支持双路径实例化（植物/僵尸），扩展为支持"从种子栏放置僵尸"
- 植物阵容 = `PlantLayoutDef[]`，每条包含 `archetype + gridX + gridY` 或随机放置参数

### 11.3 分发矩阵总结

原版：
```
              ┌─ PickBackground()         → 巨型 switch (75 case)
              ├─ InitZombieWaves()        → 巨型 switch (30+ case)
GameMode ────►├─ 初始阳光/种子栏           → 巨型 switch (30+ case)
              ├─ Challenge::InitLevel     → 巨型 if/switch
              ├─ Challenge::Update        → 巨型 if 链
              └─ CheckForGameEnd()        → 4 路 if/else
```

open_pvz 目标：
```
GameModeDefinition ──► 各字段直接定义视觉/经济/波次参数
                        ├─ GameModeStrategy 注册表分发行为
                        ├─ Mechanic[] 编译链处理特殊规则
                        └─ StageManager 管理阶段流转
```

核心思路：**将原版"一个枚举贯穿全系统做 if/switch"的模式，拆解为"数据定义 + 策略注册 + Mechanic 组合"的三层架构。**
