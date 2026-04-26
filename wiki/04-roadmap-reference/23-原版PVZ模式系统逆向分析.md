# 原版 PVZ 模式系统逆向分析

> 来源：`vendor/de-pvz`（反编译 C++ 代码），分析原版 Plants vs. Zombies 如何实现迷你游戏、无尽模式、砸罐子（Vasebreaker）、我是僵尸（I, Zombie），以及场景/模式区分机制。

---

## 目录

1. [全局架构](#1-全局架构)
2. [两层标识体系：GameScene + GameMode](#2-两层标识体系gamescene--gamemode)
3. [场景流转状态机](#3-场景流转状态机)
4. [模式规则注入的五个层面](#4-模式规则注入的五个层面)
5. [无尽模式 Survival / Endless](#5-无尽模式-survival--endless)
6. [砸罐子 Vasebreaker / Scary Potter](#6-砸罐子-vasebreaker--scary-potter)
7. [我是僵尸 I, Zombie](#7-我是僵尸-i-zombie)
8. [其他迷你游戏概览](#8-其他迷你游戏概览)
9. [关卡结束的分支判断](#9-关卡结束的分支判断)
10. [ChallengeDefinition — 纯 UI 数据](#10-challengedefinition--纯-ui-数据)
11. [对 open_pvz 的架构迁移启示](#11-对-open_pvz-的架构迁移启示)

---

## 1. 全局架构

### 1.1 核心类关系

```
LawnApp (全局应用)
  ├── mGameMode: GameMode 枚举          ← 规则标识（75 种）
  ├── mGameScene: GameScenes 枚举       ← 场景标识（8 种）
  ├── mBoard: Board*                    ← 唯一的战斗场景容器
  │     ├── mChallenge: Challenge*      ← 所有非常规模式逻辑（5700 行）
  │     ├── mSeedBank: SeedBank*        ← 种子栏/传送带
  │     ├── mCutScene: CutScene*        ← 过场动画
  │     ├── mBackground: BackgroundType ← 背景类型
  │     ├── mZombies / mPlants / mProjectiles / mCoins / mGridItems / mLawnMowers
  │     └── mChallenge->mSurvivalStage  ← 阶段计数（无尽/砸罐/IZombie 共用）
  ├── mGameSelector: GameSelector*      ← 主菜单
  ├── mSeedChooserScreen                ← 选卡界面
  ├── mAwardScreen                      ← 奖励界面
  └── mChallengeScreen                  ← 模式选择界面
```

### 1.2 Challenge 类的角色

Challenge 类不是接口/策略模式，而是一个 **巨型单一类**，包含所有非常规模式逻辑。通过 `mApp->mGameMode` 枚举做大量 `if/switch` 分支分发。

**关键入口点：**

| 入口 | 调用时机 | 作用 |
|------|---------|------|
| `Challenge::InitLevel()` | `Board::InitLevel()` 末尾 | 按模式设置初始物件（罐子/植物/传送门等） |
| `Challenge::StartLevel()` | `Board::StartLevel()` | 按模式设置光标/倒计时/提示 |
| `Challenge::Update()` | `Board` 每帧 | 按模式分发到对应 Update 函数 |
| `Challenge::MouseDown/Up/Move()` | 鼠标输入 | 按模式做特殊处理 |
| `Challenge::InitZombieWaves()` | 波次初始化 | 按模式设置允许出现的僵尸类型 |

**关键状态字段：**

| 字段 | 类型 | 作用 |
|------|------|------|
| `mChallengeState` | `ChallengeState` 枚举 | 子状态机（如砸罐锤击中、老虎机转动中） |
| `mChallengeStateCounter` | int | 子状态计时器 |
| `mSurvivalStage` | int | 当前"第几轮"（无尽/砸罐/IZombie 共用） |
| `mChallengeScore` | int | 累计得分（IZombie 的脑子计数） |
| `mScaryPotterPots` | int | 当前场上罐子数量 |
| `mRainCounter` | int | 下雨/天气计时器 |

### 1.3 ChallengeState 子状态枚举

```cpp
enum ChallengeState {
    STATECHALLENGE_NORMAL,                    // 正常
    STATECHALLENGE_BEGHOULED_MOVING,          // 宝石迷阵拖拽中
    STATECHALLENGE_BEGHOULED_FALLING,         // 宝石迷阵下落中
    STATECHALLENGE_BEGHOULED_NO_MATCHES,      // 宝石迷阵无匹配
    STATECHALLENGE_SLOT_MACHINE_ROLLING,      // 老虎机转动
    STATECHALLENGE_STORM_FLASH_1/2/3,         // 暴风雨闪电
    STATECHALLENGE_ZEN_FADING,                // 禅境花园渐变
    STATECHALLENGE_SCARY_POTTER_MALLETING,    // 砸罐锤击中
    STATECHALLENGE_LAST_STAND_ONSLAUGHT,      // 坚不可摧进攻中
    STATECHALLENGE_TREE_JUST_GREW,            // 智慧树刚生长
    STATECHALLENGE_TREE_GIVE_WISDOM,          // 智慧树给予智慧
    STATECHALLENGE_TREE_WAITING_TO_BABBLE,    // 智慧树等待说话
    STATECHALLENGE_TREE_BABBLING,             // 智慧树说话中
};
```

---

## 2. 两层标识体系：GameScene + GameMode

原版用两个正交维度标识"当前在干什么"：

| 维度 | 字段 | 类型 | 作用 |
|------|------|------|------|
| **场景** | `mGameScene` | `GameScenes` 枚举 (8 值) | 当前在哪个 UI 界面 |
| **模式** | `mGameMode` | `GameMode` 枚举 (~75 值) | 当前 Board 的游戏规则 |

### GameScenes 枚举

```cpp
enum GameScenes {
    SCENE_LOADING = 0,       // 加载中
    SCENE_MENU = 1,          // 主菜单
    SCENE_LEVEL_INTRO = 2,   // 关卡介绍/选卡
    SCENE_PLAYING = 3,       // 战斗进行中
    SCENE_ZOMBIES_WON = 4,   // 失败
    SCENE_AWARD = 5,         // 奖励结算
    SCENE_CREDIT = 6,        // 通关演职员表
    SCENE_CHALLENGE = 7,     // 模式选择界面
};
```

### GameMode 枚举

```cpp
enum GameMode {
    // 冒险模式 (1)
    GAMEMODE_ADVENTURE,

    // 生存模式 - 普通 (5)
    GAMEMODE_SURVIVAL_NORMAL_STAGE_1 ~ _STAGE_5,
    // 生存模式 - 困难 (5)
    GAMEMODE_SURVIVAL_HARD_STAGE_1 ~ _STAGE_5,
    // 生存模式 - 无尽 (5)
    GAMEMODE_SURVIVAL_ENDLESS_STAGE_1 ~ _STAGE_5,

    // 迷你游戏 (20)
    GAMEMODE_CHALLENGE_WAR_AND_PEAS,
    GAMEMODE_CHALLENGE_WALLNUT_BOWLING,
    GAMEMODE_CHALLENGE_SLOT_MACHINE,
    GAMEMODE_CHALLENGE_RAINING_SEEDS,
    GAMEMODE_CHALLENGE_BEGHOULED,
    GAMEMODE_CHALLENGE_INVISIGHOUL,
    GAMEMODE_CHALLENGE_SEEING_STARS,
    GAMEMODE_CHALLENGE_ZOMBIQUARIUM,
    GAMEMODE_CHALLENGE_BEGHOULED_TWIST,
    GAMEMODE_CHALLENGE_LITTLE_TROUBLE,
    GAMEMODE_CHALLENGE_PORTAL_COMBAT,
    GAMEMODE_CHALLENGE_COLUMN,
    GAMEMODE_CHALLENGE_BOBSLED_BONANZA,
    GAMEMODE_CHALLENGE_SPEED,
    GAMEMODE_CHALLENGE_WHACK_A_ZOMBIE,
    GAMEMODE_CHALLENGE_LAST_STAND,
    GAMEMODE_CHALLENGE_WAR_AND_PEAS_2,
    GAMEMODE_CHALLENGE_WALLNUT_BOWLING_2,
    GAMEMODE_CHALLENGE_POGO_PARTY,
    GAMEMODE_CHALLENGE_FINAL_BOSS,
    // ... 更多迷你游戏 + Limbo 模式

    // 砸罐子 (10)
    GAMEMODE_SCARY_POTTER_1 ~ _9,
    GAMEMODE_SCARY_POTTER_ENDLESS,

    // 我是僵尸 (10)
    GAMEMODE_PUZZLE_I_ZOMBIE_1 ~ _9,
    GAMEMODE_PUZZLE_I_ZOMBIE_ENDLESS,

    // 特殊
    GAMEMODE_UPSELL,
    GAMEMODE_INTRO,
};
```

### 模式类型判断函数

`LawnApp` 提供一组布尔辅助函数做模式分类：

| 函数 | 范围 |
|------|------|
| `IsAdventureMode()` | `mGameMode == GAMEMODE_ADVENTURE` |
| `IsSurvivalMode()` | `>= SURVIVAL_NORMAL_STAGE_1 && <= SURVIVAL_ENDLESS_STAGE_5` |
| `IsSurvivalNormal(mode)` | 普通 5 关 |
| `IsSurvivalHard(mode)` | 困难 5 关 |
| `IsSurvivalEndless(mode)` | 无尽 5 关 |
| `IsPuzzleMode()` | 砸罐子 + I, Zombie |
| `IsChallengeMode()` | `!Adventure && !Puzzle && !Survival` |
| `IsScaryPotterLevel()` | `>= SCARY_POTTER_1 && <= SCARY_POTTER_9` 或冒险 Level 35 |
| `IsIZombieLevel()` | `I_ZOMBIE_1` ~ `I_ZOMBIE_ENDLESS` |
| `IsWhackAZombieLevel()` | 打地鼠关卡或冒险 Level 15 |
| `IsContinuousChallenge()` | 宝石迷阵/老虎机/艺术挑战等无种子栏的连续模式 |

---

## 3. 场景流转状态机

### 3.1 完整流转路径

```
启动
 │
 ▼
SCENE_LOADING (LoadingThreadProc)
 │
 ▼
ShowGameSelector() → SCENE_MENU
 │  用户选择模式
 ▼
PreNewGame(gameMode)
 │  设定 mGameMode
 │  尝试加载存档 (TryLoadGame)
 │  → NewGame()
 │
 ▼
NewGame():
 │  MakeNewBoard()          → new Board(this), 挂到 WidgetManager
 │  Board::InitLevel()      → 根据 mGameMode 初始化所有规则（5 层注入）
 │  mGameScene = SCENE_LEVEL_INTRO
 │  ShowSeedChooserScreen() → 选卡界面（覆盖在 Board 之上）
 │  CutScene::StartLevelIntro()
 │
 │  用户选完卡 / 跳过动画
 ▼
StartPlaying():
 │  KillSeedChooserScreen()
 │  Board::StartLevel()     → Challenge::StartLevel()
 │  mGameScene = SCENE_PLAYING
 │
 │  战斗进行中...
 │
 ▼
关卡结束触发 → CheckForGameEnd()
 │  根据 mGameMode 决定路由：
 │
 ├── 冒险模式:
 │   ├── 首次冒险 Level < 50  → ShowAwardScreen() → SCENE_AWARD
 │   ├── Level == 50 (最终)   → ShowAwardScreen(CREDITS) → SCENE_AWARD
 │   ├── Boss 关 (10/20/30/40/49) → ShowAwardScreen() → SCENE_AWARD
 │   └── 普通关               → PreNewGame() → 自动下一关
 │
 ├── 生存模式:
 │   ├── 非最终阶段           → mSurvivalStage++ → InitSurvivalStage() → 重选卡
 │   └── 最终阶段             → KillBoard() → ShowAwardScreen/ChallengeScreen
 │
 ├── 解谜模式 (砸罐/IZombie):
 │   └── KillBoard() → ShowAwardScreen/ChallengeScreen → SCENE_CHALLENGE
 │
 └── 迷你游戏:
     └── KillBoard() → ShowAwardScreen/ChallengeScreen → SCENE_CHALLENGE
```

### 3.2 关键函数说明

| 函数 | 文件 | 作用 |
|------|------|------|
| `PreNewGame(mode, lookForSave)` | LawnApp.cpp:402 | 设置 mGameMode → 尝试读档 → NewGame() |
| `NewGame()` | LawnApp.cpp:468 | MakeNewBoard + InitLevel + 设 SCENE_LEVEL_INTRO + 弹选卡 |
| `MakeNewBoard()` | LawnApp.cpp:420 | KillBoard() → new Board(this) → 注册到 WidgetManager |
| `StartPlaying()` | LawnApp.cpp:431 | KillSeedChooserScreen + Board::StartLevel + 设 SCENE_PLAYING |
| `EndLevel()` | LawnApp.cpp:625 | KillBoard → 冒险模式自动 NewGame，其他模式重建 Board |
| `CheckForGameEnd()` | LawnApp.cpp:1446 | 关卡完成后的路由决策 |
| `ShowGameSelector()` | LawnApp.cpp:482 | KillBoard → 创建 GameSelector → SCENE_MENU |
| `ShowAwardScreen()` | LawnApp.cpp:517 | 创建 AwardScreen → SCENE_AWARD |
| `ShowChallengeScreen()` | LawnApp.cpp:560 | 创建 ChallengeScreen → SCENE_CHALLENGE |

### 3.3 Board 的创建与销毁

**Board 是唯一的游戏场景容器**。所有模式共用同一个 `Board` 类，差异完全通过 `mGameMode` + `Challenge` 分发。

```cpp
// LawnApp.cpp:420
void LawnApp::MakeNewBoard() {
    KillBoard();               // 先销毁旧 Board
    mBoard = new Board(this);  // 构造函数中设定 mApp->mBoard = this
    mBoard->Resize(0, 0, mWidth, mHeight);
    mWidgetManager->AddWidget(mBoard);
    mWidgetManager->BringToBack(mBoard);
    mWidgetManager->SetFocus(mBoard);
}
```

Board 构造函数中：
- 初始化所有数据数组（Zombies/Plants/Projectiles/Coins/GridItems/LawnMowers）
- 创建 CursorObject、SeedBank、CutScene、Challenge 等子系统
- 按模式设置菜单按钮样式（禅境花园/Last Stand 有特殊的商店按钮）

**生存模式特殊**：不 KillBoard，而是复用同一个 Board 实例调用 `InitSurvivalStage()`。

### 3.4 挂件（Widget）堆叠

原版使用 WidgetManager 做 UI 层叠。在 SCENE_LEVEL_INTRO 时：

```
底层: Board (全屏)
  └─ 覆盖: SeedChooserScreen (选卡)
  └─ 覆盖: CutScene (过场动画)
```

进入 SCENE_PLAYING 后：
```
底层: Board (全屏)
  └─ 覆盖: 各种 Dialog (暂停/商店/戴夫对话)
```

---

## 4. 模式规则注入的五个层面

Board 构造后，`InitLevel()` 是规则注入的主入口。它按顺序做了 5 件事：

```
              ┌─ PickBackground()         → 视觉层 (背景/格子类型)
              ├─ InitZombieWaves()        → 战术层 (僵尸类型+波数)
GameMode ────►├─ 初始阳光/种子栏配置       → 经济层 (资源)
              ├─ Challenge::InitLevel()   → 模式层 (罐子/植物/传送门等)
              ├─ Challenge::StartLevel()  → 行为层 (光标/倒计时/提示)
              └─ Challenge::Update()      → 运行层 (每帧模式专属逻辑)
```

### 4.1 视觉层 — PickBackground()

`Board::PickBackground()` (Board.cpp:868) 是一个巨型 `switch(mGameMode)` 将 ~75 个模式映射到 10 种背景。

**背景类型 → 推导关系：**

```
BACKGROUND_1_DAY / GREENHOUSE / TREEOFWISDOM
  → PlantRow: [NORMAL, NORMAL, NORMAL, NORMAL, NORMAL, DIRT]
  → StageHasPool: false, StageHasRoof: false, StageIsNight: false

BACKGROUND_2_NIGHT
  → PlantRow: [NORMAL, NORMAL, NORMAL, NORMAL, NORMAL, DIRT]
  → StageHasPool: false, StageHasRoof: false, StageIsNight: true

BACKGROUND_3_POOL / ZOMBIQUARIUM / BACKGROUND_4_FOG
  → PlantRow: [NORMAL, NORMAL, POOL, POOL, NORMAL, NORMAL]
  → StageHasPool: true, StageHasRoof: false

BACKGROUND_5_ROOF / BACKGROUND_6_BOSS
  → PlantRow: [NORMAL×5, DIRT]
  → StageHasPool: false, StageHasRoof: true
```

**模式到背景的映射：**

| 背景 | 模式 |
|------|------|
| DAY | 生存 Stage 1, 豌豆之战, 保龄球, 老虎机, 看星星, 艺术挑战(坚果), 晴天, 重新铺草, 大时代, 冰关, 铲子, 松鼠 |
| NIGHT | 生存 Stage 2, 宝石迷阵, 传送门, 打地鼠, 墓碑危机, 砸罐子全部, I, Zombie 全部 |
| POOL | 生存 Stage 3, 小鬼关, 雪橇, 极速, 坚不可摧, 豌豆之战2, 试玩/介绍 |
| FOG | 生存 Stage 4, 下雨种子, 隐身关, 空袭, 暴风雨 |
| ROOF | 生存 Stage 5, 列阵, 弹跳派对, 高重力, 蹦极闪击 |
| BOSS | 最终 Boss |
| ZOMBIQUARIUM | 僵尸水族馆 |
| GREENHOUSE | 禅境花园 |
| TREEOFWISDOM | 智慧树 |

冒险模式下按关卡号映射：Level 1-10→Day, 11-20→Night, 21-30→Pool, 31-40→Fog, 41-49→Roof, 50→Boss。

### 4.2 战术层 — InitZombieWaves()

`Challenge::InitZombieWaves()` (Challenge.cpp:2544) 按 `mGameMode` 设定 `mBoard->mZombieAllowed[]` 布尔数组。

`Board::PickZombieWaves()` (Board.cpp:573) 根据 `mNumWaves` 和 `mZombieAllowed[]` 生成每波的僵尸列表。

**波数按模式：**

| 模式 | 波数 |
|------|------|
| 生存/坚不可摧 | 10 或 20（由 `GetNumWavesPerSurvivalStage()` 决定） |
| 禅境花园/智慧树/松鼠 | 0 |
| 打地鼠 | 12 |
| 保龄球/空袭/墓碑/高重力/传送门/豌豆/隐身 | 20 |
| 暴风雨/小鬼/蹦极/列阵/铲子/豌豆2/保龄球2/弹跳 | 30 |
| 其他 | 40 |

### 4.3 经济层 — 初始阳光与种子栏

**初始阳光：**

| 模式 | 初始阳光 |
|------|---------|
| 砸罐子 / 宝石迷阵 / 打地鼠 | 0 |
| Last Stand | 5000 |
| I, Zombie | 150 |
| 冒险 Level 1 (首次) | 150 |
| 其他 | 50 |

**种子供给方式（三种）：**

| 供给方式 | 判断函数 | 适用模式 |
|---------|---------|---------|
| 无种子栏 | `IsChallengeWithoutSeedBank()` | 下雨种子/打地鼠/砸罐/松鼠/禅境花园/智慧树 |
| 传送带 | `HasConveyorBeltSeedBank()` | 保龄球/Boss/铲子关/暴风雨/蹦极/传送门/列阵/隐身/小鬼 |
| 固定种子 | 硬编码 `switch` | 老虎机(3)/冰关(6)/I,Zombie(3~9)/砸罐(1)/打地鼠(3) |
| 自选种子 | `ChooseSeedsOnCurrentLevel()=true` | 冒险模式(>Level 7) / 生存模式 |

**种子栏槽数按模式：**

| 模式 | 槽数 |
|------|------|
| 砸罐子 | 1 (仅樱桃炸弹) |
| 打地鼠 | 3 (土豆雷/墓碑吞噬者/樱桃炸弹或冰菇) |
| 无种子栏模式 | 0 |
| 传送带 | 10 |
| 老虎机 | 3 (向日葵/豌豆/寒冰) |
| 冰关 | 6 |
| 宝石迷阵/宝石迷阵旋转 | 0 |
| 僵尸水族馆 | 2 |
| I, Zombie 1~4 | 3 |
| I, Zombie 5~7 | 4 |
| I, Zombie 8 | 6 |
| I, Zombie 9 | 8 |
| I, Zombie Endless | 9 |
| 冒险/生存 | 玩家购买数 + 6（上限为可用种子数） |

### 4.4 模式层 — Challenge::InitLevel()

按模式设置初始物件：

| 模式 | InitLevel 行为 |
|------|--------------|
| 下雨种子 | 设置天气计时器，播放雨声 |
| 暴风雨 | 设闪电状态，播放雨声 |
| 最终 Boss | 传送带加种子，设倒计时 |
| 禅境花园 | 初始化花园 |
| 列阵 | 传送带加种子 |
| 隐身关 | 传送带加种子 |
| I, Zombie | `IZombieInitLevel()` — 放脑子、植物阵容 |
| 砸罐子 | `ScaryPotterPopulate()` — 放罐子 |
| 宝石迷阵旋转 | 初始化选择网格坐标 |
| 智慧树 | `TreeOfWisdomInit()` |
| 冒险 Level 5 (首次) | 预放 3 个豌豆射手 |

### 4.5 行为层 — Challenge::StartLevel() + Update()

**StartLevel 按模式行为：**

| 模式 | StartLevel |
|------|-----------|
| 打地鼠 | 设锤子光标，设僵尸倒计时 |
| 暴风雨 | 设闪电状态 |
| 雪橇 | 全地面永久冰面 |
| 保龄球 | 加初始坚果，设传送带 |
| 铲子/松鼠 | `ShovelAddWallnuts()` |
| 砸罐子 | `ScaryPotterStart()` 显示提示 |
| 生存(首轮) | 显示旗帜数提示 |
| Last Stand(首轮) | 显示旗帜数提示 |
| 宝石迷阵 | `BeghouledMakeStartBoard()` |
| 传送门 | `PortalStart()` |
| 列阵 | 设当前波为 9 |
| 空袭/雪橇 | 设长倒计时 |
| 弹跳派对 | 设超长倒计时 |
| 僵尸水族馆 | 生成 2 只潜水僵尸 |
| I, Zombie | `IZombieStart()` |
| 松鼠 | `SquirrelStart()` |

**Update 每帧分发：**

```cpp
void Challenge::Update() {
    if (mApp->IsStormyNightLevel()) UpdateStormyNight();
    // 暂停检查
    if (HasConveyorBeltSeedBank()) UpdateConveyorBelt();
    if (Beghouled) UpdateBeghouled();
    if (ScaryPotterLevel) ScaryPotterUpdate();
    if (WhackAZombieLevel) WhackAZombieUpdate();
    if (IZombieLevel) IZombieUpdate();
    if (SlotMachineLevel) UpdateSlotMachine();
    if (Speed) double UpdateGame();
    if (RainingSeeds) UpdateRainingSeeds();
    if (PortalCombat) UpdatePortalCombat();
    if (SquirrelLevel) SquirrelUpdate();
    if (Zombiquarium) ZombiquariumUpdate();
    if (TreeOfWisdom) TreeOfWisdomUpdate();
    if (LastStand) LastStandUpdate();
}
```

---

## 5. 无尽模式 Survival / Endless

### 5.1 模式分类

| 类型 | GameMode 范围 | 每轮波数 | 目标旗帜数 |
|------|--------------|---------|-----------|
| `SURVIVAL_NORMAL` (普通) | `_STAGE_1` ~ `_STAGE_5` | 10 波 | 5 旗 |
| `SURVIVAL_HARD` (困难) | `_STAGE_1` ~ `_STAGE_5` | 20 波 | 10 旗 |
| `SURVIVAL_ENDLESS` (无尽) | `_STAGE_1` ~ `_STAGE_5` | 20 波 | 无上限 |

常量定义：
```cpp
const int SURVIVAL_NORMAL_FLAGS = 5;
const int SURVIVAL_HARD_FLAGS = 10;
```

### 5.2 阶段流转 (mSurvivalStage)

每轮完成后：
1. `mNextSurvivalStageCounter` 设为 500 ticks 开始倒计时
2. 倒计时结束后进入阶段完成处理

**旗帜进度计算：**
```cpp
GetSurvivalFlagsCompleted() =
    mSurvivalStage * GetNumWavesPerSurvivalStage() / GetNumWavesPerFlag()
    + mCurrentWave / GetNumWavesPerFlag()
```

**最终阶段判定：**
```cpp
bool Board::IsFinalSurvivalStage() {
    int aFlags = GetNumWavesPerSurvivalStage() * (mSurvivalStage + 1) / GetNumWavesPerFlag();
    if (IsSurvivalNormal) return aFlags >= 5;   // 普通到 5 旗结束
    if (IsSurvivalHard) return aFlags >= 10;     // 困难到 10 旗结束
    return false;  // 无尽永不结束
}
```

### 5.3 阶段流转流程

```
关卡进行中
 │
 ▼
最后一波完成 → mBoardFadeOutCounter 倒计时
 │
 ▼
mNextSurvivalStageCounter = 500 开始倒计时
 │  显示进度条和旗帜数提示
 ▼
倒计时结束 → CheckForGameEnd()
 │
 ├── IsFinalSurvivalStage():
 │   → SurvivalSaveScore()
 │   → KillBoard()
 │   → ShowAwardScreen() 或 ShowChallengeScreen()
 │
 └── !IsFinalSurvivalStage():
     → mSurvivalStage++
     → KillGameSelector()
     → Board::InitSurvivalStage()
         → InitZombieWaves()
         → SCENE_LEVEL_INTRO
         → ShowSeedChooserScreen()  (重选卡)
         → CutScene::StartLevelIntro()
```

### 5.4 难度递增 — InitZombieWavesSurvival()

```cpp
void Challenge::InitZombieWavesSurvival() {
    mBoard->mZombieAllowed[ZOMBIE_NORMAL] = true;

    // 第一轮：随机二选一
    if (aLevelRNG.Next(5) == 0)
        mBoard->mZombieAllowed[ZOMBIE_NEWSPAPER] = true;
    else
        mBoard->mZombieAllowed[ZOMBIE_TRAFFIC_CONE] = true;

    // 后续轮次：随机抽取，容量随 stage 增长
    int aCapacity = min(mSurvivalStage + 1, 9);  // 最多同时 9 种
    while (aCapacity > 0) {
        ZombieType aRandZombie = (ZombieType)aLevelRNG.Next(NUM_ZOMBIE_TYPES);
        // 各种过滤条件...
        mBoard->mZombieAllowed[aRandZombie] = true;
        aCapacity--;
    }
}
```

**限制条件：**
- 池子僵尸不出现在无水池关卡
- 屋面不出矿工/舞王
- 墓碑关卡不出扫雪车
- 前 10 旗不出红眼巨人
- 普通生存不出潜水以后的高级僵尸
- Yeti/Zombotany/特殊生成僵尸被排除

### 5.5 僵尸强度缩放

```cpp
// Board.cpp 波次生成时
if (IsSurvivalEndless && mSurvivalStage > 0)
    aZombiePoints = (mSurvivalStage * waves + wave + 10) * 2 / 5 + 1;
else if (IsSurvivalMode && mSurvivalStage > 0)
    aZombiePoints = (mSurvivalStage * waves + wave) * 2 / 5 + 1;
```

僵尸点数随 `(stage * waves + wave)` 线性增长，后期每波出更多高价值僵尸。

### 5.6 种子重选

```cpp
bool Board::IsSurvivalStageWithRepick() {
    return mApp->IsSurvivalMode() && !IsFinalSurvivalStage();
}
```

每轮结束且非最终阶段时，弹出种子选择界面允许重新选卡。存档在每轮开始时删除。

---

## 6. 砸罐子 Vasebreaker / Scary Potter

### 6.1 模式结构

`GAMEMODE_SCARY_POTTER_1` ~ `GAMEMODE_SCARY_POTTER_9` + `GAMEMODE_SCARY_POTTER_ENDLESS`。

共 9 个固定关卡 + 1 个无尽模式。冒险模式 Level 35 也是砸罐关卡（3 个 stage）。

### 6.2 核心数据结构

罐子是 `GridItem`，类型 `GRIDITEM_SCARY_POT`。

**罐子内容类型：**
```cpp
enum ScaryPotType {
    SCARYPOT_NONE = 0,
    SCARYPOT_SEED = 1,    // 植物/种子
    SCARYPOT_ZOMBIE = 2,  // 僵尸
    SCARYPOT_SUN = 3,     // 阳光
};
```

**罐子外观状态（`GridItemState`）：**
```cpp
GRIDITEM_STATE_SCARY_POT_QUESTION = 3,  // 问号（未知内容）
GRIDITEM_STATE_SCARY_POT_LEAF = 4,      // 叶子标记（里面是植物）
GRIDITEM_STATE_SCARY_POT_ZOMBIE = 5,    // 僵尸头标记（里面是僵尸）
```

### 6.3 关卡组装 — ScaryPotterPopulate()

`Challenge::ScaryPotterPopulate()` (Challenge.cpp:3880) 是关卡组装核心：

**步骤：**
1. 初始化 `TodWeightedGridArray[54]`（最大 9×6 格子）做权重随机放置
2. `ScaryPotterDontPlaceInCol(col)` — 排除左侧几列作为安全区
3. `ScaryPotterPlacePot(type, zombieType, seedType, count, gridArray, count)` — 放置指定数量罐子
4. `ScaryPotterChangePotType(state, count)` — 将部分罐子改为可见内容标记
5. `mScaryPotterPots = ScaryPotterCountPots()` — 记录罐子总数

**各关卡配置示例：**

| 关卡 | 安全区 | 植物罐 | 僵尸罐 | 特殊标记 |
|------|--------|--------|--------|---------|
| SCARY_POTTER_1 | 列 0-3 | 豌豆×5, 寒冰×5, 倭瓜×5 | 普通×6, 铁桶×3, 小丑×1 | 叶子×2 |
| SCARY_POTTER_9 | 列 0-1 | 左射×6, 寒冰×2, 豌豆×2, 三线×2, 倭瓜×5, 土豆雷×1, 坚果×1, 路灯×1 | 普通×8, 铁桶×5, 小丑×1, 巨人×1 | 叶子×2 |
| ENDLESS | 列 0-1 | 同上 + 阳光罐×1 | 普通×(8-Garg), 铁桶×5, 小丑×1, 巨人×(1+extra) | 叶子×2 |

**无尽模式难度递增：**
```cpp
int aNumExtraGargantuars = ClampInt(mSurvivalStage / 10, 0, 8);
// 每 10 轮多一个巨人罐，最多额外 8 个
```

### 6.4 玩法流程

```
点击罐子
 │
 ▼
ScaryPotterMalletPot(gridItem)
 │  记录网格坐标
 │  播放锤子动画
 │  mChallengeState = STATECHALLENGE_SCARY_POTTER_MALLETING
 │
 ▼
ScaryPotterUpdate() 等待动画完成
 │
 ▼
ScaryPotterOpenPot(gridItem)
 │  switch (mScaryPotType):
 │    SCARYPOT_SEED   → AddCoin(USABLE_SEED_PACKET)
 │    SCARYPOT_ZOMBIE → AddZombieInRow(zombieType, gridY)
 │    SCARYPOT_SUN    → AddCoin(SUN) × sunCount
 │  GridItemDie()
 │  播放音效 + 粒子效果
 │
 ▼
检查完成: ScaryPotterIsCompleted()
 │  所有 GRIDITEM_SCARY_POT 消失 && 无敌方僵尸
 │
 ├── 未完成 → 继续
 ├── 完成(非最终阶段) → PuzzlePhaseComplete() → 掉奖励/下一阶段
 └── 完成(最终阶段) → SpawnLevelAward()
```

### 6.5 Jack-in-the-box 特殊交互

小丑僵尸爆炸会炸开周围罐子：
```cpp
void Challenge::ScaryPotterJackExplode(posX, posY) {
    // 遍历爆炸范围(±1格)内的所有罐子并打开
    for each gridItem in range(1,1):
        ScaryPotterOpenPot(gridItem);
}
```

### 6.6 阶段流转

```cpp
void Challenge::PuzzleNextStageClear() {
    // 杀死所有僵尸和植物
    // 清除所有 GridItem（罐子/脑子等）
    // 清除所有种子卡硬币
    mSurvivalStage++;
    // 播放闪光特效
}
```

- 固定关卡（SCARY_POTTER_1~9）：只有 1 个 stage
- 冒险 Level 35：3 个 stage
- 无尽模式：每完成一轮 `mSurvivalStage++`，每 10 轮掉奖励

---

## 7. 我是僵尸 I, Zombie

### 7.1 模式结构

`GAMEMODE_PUZZLE_I_ZOMBIE_1` ~ `GAMEMODE_PUZZLE_I_ZOMBIE_9` + `GAMEMODE_PUZZLE_I_ZOMBIE_ENDLESS`。

### 7.2 角色反转机制

玩家操作**僵尸**（从种子栏选僵尸类型，放置到格子），目标是让僵尸吃掉左侧的**脑子** (`GRIDITEM_IZOMBIE_BRAIN`)。

**僵尸"种子"类型映射：**
```
SEED_ZOMBIE_NORMAL       → ZOMBIE_NORMAL
SEED_ZOMBIE_TRAFFIC_CONE → ZOMBIE_TRAFFIC_CONE
SEED_ZOMBIE_POLEVAULTER  → ZOMBIE_POLEVAULTER
SEED_ZOMBIE_PAIL         → ZOMBIE_PAIL
SEED_ZOMBIE_LADDER       → ZOMBIE_LADDER
SEED_ZOMBIE_DIGGER       → ZOMBIE_DIGGER
SEED_ZOMBIE_BUNGEE       → ZOMBIE_BUNGEE
SEED_ZOMBIE_FOOTBALL     → ZOMBIE_FOOTBALL
SEED_ZOMBIE_BALLOON      → ZOMBIE_BALLOON
SEED_ZOMBIE_SCREEN_DOOR  → ZOMBIE_DOOR
SEED_ZOMBONI             → ZOMBIE_ZAMBONI
SEED_ZOMBIE_POGO         → ZOMBIE_POGO
SEED_ZOMBIE_DANCER       → ZOMBIE_DANCER
SEED_ZOMBIE_GARGANTUAR   → ZOMBIE_GARGANTUAR
SEED_ZOMBIE_IMP           → ZOMBIE_IMP
```

### 7.3 关卡组装 — IZombieInitLevel()

`Challenge::IZombieInitLevel()` (Challenge.cpp:4528)：

**步骤：**
1. `mChallengeScore = 0`
2. 在第 0 列每行放置一个脑子 `GRIDITEM_IZOMBIE_BRAIN`（共 5 个）
3. 按 GameMode 硬编码放置植物阵容（固定关卡）
4. 每株植物通过 `IZombieSetupPlant()` 冻结动画（使植物静止但可被攻击）

**植物放置逻辑：**
```cpp
void Challenge::IZombiePlacePlants(seedType, count, gridY) {
    int aColumns = 6;   // 默认可用列数
    // I_ZOMBIE_1~5: 4 列
    // I_ZOMBIE_6~8, ENDLESS: 5 列
    // I_ZOMBIE_9: 6 列

    // 限制行范围
    int aMinGridY = (gridY == -1) ? 0 : gridY;
    int aMaxGridY = (gridY == -1) ? 4 : gridY;

    // 坚果和火炬树桩只出现在靠右 3 列
    // 权重随机选择格子放置
}
```

**无尽模式随机阵容：**
```cpp
case GAMEMODE_PUZZLE_I_ZOMBIE_ENDLESS: {
    // 向日葵/小蘑菇比例随 stage 调整
    int aPuffshroomCount = RandRangeInt(ClampInt(2 + stage/3, 2, 4), ...);
    int aSunflowerCount = 8 - aPuffshroomCount;

    // 随机选阵型：
    if (formationHit == 0 && stage >= 1) {
        // 5 种强阵型：输出阵/爆炸阵/倾斜阵/穿刺阵/回复阵
    } else {
        // 3 种弱阵型：综合阵/控制阵/即死阵
    }
}
```

**各关卡植物阵容概要：**

| 关卡 | 核心植物 | 列数 |
|------|---------|------|
| I_ZOMBIE_1 | 向日葵×9, 倭瓜×3, 豌豆×6, 寒冰×2 | 4 |
| I_ZOMBIE_2 | 地刺, 向日葵, 豌豆, 寒冰 | 4 |
| I_ZOMBIE_3 | 土豆雷, 向日葵, 火炬, 豌豆, 分裂豌豆 | 4 |
| I_ZOMBIE_4 | 坚果墙(5行), 向日葵, 豌豆, 寒冰, 大喷 | 4 |
| I_ZOMBIE_5 | 向日葵, 仙人掌, 磁力菇, 豌豆, 寒冰 | 4 |
| I_ZOMBIE_6 | 大蒜, 向日葵, 火炬, 地刺, 倭瓜, 玉米 | 5 |
| I_ZOMBIE_7 | 向日葵, 土豆雷×9, 大嘴花×8 | 5 |
| I_ZOMBIE_8 | 坚果, 磁力菇, 豌豆, 倭瓜, 土豆雷, 向日葵 | 5 |
| I_ZOMBIE_9 | 高坚果, 火炬, 多种植物混合 | 6 |
| ENDLESS | 随机阵型 | 6 |

### 7.4 胜负判定

**胜利条件：** 吃掉 5 个脑子 (`I_ZOMBIE_WINNING_SCORE = 5`)

```cpp
void Challenge::IZombieScoreBrain(brain) {
    mChallengeScore++;
    if (mChallengeScore == I_ZOMBIE_WINNING_SCORE) {
        if (IsEndlessIZombie)
            PuzzlePhaseComplete();  // 下一轮
        else
            SpawnLevelAward();       // 通关
    }
    DropLootPiece();  // 掉落奖励
}
```

**失败条件：** 场上无僵尸 + 阳光不足 50 + 无活跃植物动作

```cpp
void Challenge::IZombieUpdate() {
    // 让无动作僵尸随机变速
    // 检查是否有活跃植物动作（倭瓜下落/大嘴花咀嚼/土豆雷爆炸）
    // 失败判定
    if (mZombies.mSize == 0 && sunMoney < 50 && !levelAward && !anActive) {
        mBoard->ZombiesWon(nullptr);  // 游戏失败
    }
}
```

**巨人踩脑：** 巨人僵尸踩到脑子直接得分
```cpp
void Challenge::IZombieSquishBrain(brain) {
    brain->mGridItemState = GRIDITEM_STATE_BRAIN_SQUISHED;
    IZombieScoreBrain(brain);
}
```

### 7.5 经济系统

```cpp
void Challenge::IZombiePlantDropRemainingSun(plant) {
    if (plant->mSeedType == SEED_SUNFLOWER) {
        int aSunCount = plant->mPlantHealth / 40 + 1;
        for (i = 0; i < aSunCount; i++)
            AddCoin(SUN);
    }
}
```

向日葵被杀时按剩余血量掉落阳光，其他植物被杀不产生阳光。阳光用于购买僵尸"种子"。

### 7.6 放置限制

```cpp
PlantingReason Challenge::CanPlantAt(gridX, gridY, seedType) {
    // I, Zombie 模式下：
    // 1. 只能放在"红线"右侧
    // 2. 不能放在已有僵尸的格子
    // 3. 蹦极僵尸特殊：只能放在列 ≥ aColumns
    // 4. 其他僵尸：只能放在列 < aColumns
}
```

---

## 8. 其他迷你游戏概览

| 模式 | GameMode | 核心玩法特征 | 关键实现手段 | 背景类型 |
|------|----------|-------------|-------------|---------|
| **保龄球** | WALLNUT_BOWLING / _2 | 传送带提供坚果，弹射消灭僵尸 | `UpdateConveyorBelt()` + 物理碰撞弹射 | DAY |
| **豌豆之战** | WAR_AND_PEAS / _2 | 豌豆头/坚果头僵尸互战 | 僵尸类型限制为 Zombotany 系列 | DAY / POOL |
| **老虎机** | SLOT_MACHINE | 拉"拉杆"随机出种子 | `UpdateSlotMachine()` + `ChallengeState` 状态机 | DAY |
| **下雨种子** | RAINING_SEEDS | 天降随机种子卡，无种子栏 | `UpdateRainingSeeds()` + 天气渲染 | FOG |
| **宝石迷阵** | BEGHOULED | 三消匹配植物，匹配后攻击僵尸 | `BeghouledBoardState` + 匹配检测/重力下落/填充 | NIGHT |
| **宝石迷阵旋转** | BEGHOULED_TWIST | 旋转 2×2 区域进行三消 | 同上 + `BeghouledTwistMouseDown()` | NIGHT |
| **隐身关** | INVISIGHOUL | 僵尸完全隐形，传送带供种 | 僵尸渲染隐藏 + 传送带 | FOG |
| **看星星** | SEEING_STARS | 填充星果到指定图案 | `gArtChallengeStarFruit[6][9]` 图案比对 | DAY |
| **僵尸水族馆** | ZOMBIQUARIUM | 喂脑给潜水僵尸，收集阳光养更多 | `ZombiquariumSpawnSnorkle()` + `ZombiquariumDropBrain()` | ZOMBIQUARIUM |
| **小鬼关** | LITTLE_TROUBLE | 只有迷你/小鬼僵尸 | 僵尸类型限制 + 传送带 | POOL |
| **传送门** | PORTAL_COMBAT | 格子上出现传送门对，僵尸穿行 | `GridItem`(PORTAL_CIRCLE/SQUARE) + `GetOtherPortal()` | NIGHT |
| **列阵** | COLUMN | 同一列重复种植，传送带供种 | 传送带 + 列复制机制 | ROOF |
| **雪橇** | BOBSLED_BONANZA | 全冰面，只有雪橇+扫雪车 | 永久冰面 `mIceTimer = INT_MAX` | POOL |
| **极速** | SPEED | 僵尸移动速度极快 | `mBoard->UpdateGame()` 双倍调用 | POOL |
| **打地鼠** | WHACK_A_ZOMBIE | 锤子砸破土中冒出的僵尸 | `CURSOR_TYPE_HAMMER` + `MouseDownWhackAZombie()` | NIGHT |
| **坚不可摧** | LAST_STAND | 初始大量阳光，布置后自动防御 | `LastStandUpdate()` + 布置/进攻阶段切换 | POOL |
| **弹跳派对** | POGO_PARTY | 只有弹跳僵尸 | 僵尸类型限制 | ROOF |
| **最终 Boss** | FINAL_BOSS | 巨型僵尸 Boss 战 | 传送带 + 特殊 Boss 行为 | BOSS |
| **艺术挑战** | ART_CHALLENGE_* | 用特定植物填充图案 | `gArtChallengeWallnut[6][9]` 等图案数据 | DAY |
| **晴天** | SUNNY_DAY | 额外阳光掉落 | 阳光频率增加 | DAY |
| **重新铺草** | RESODDED | 部分行为泥土地 | `mPlantRow` 设为 DIRT | DAY |
| **大时代** | BIG_TIME | 大型僵尸出现 | 僵尸类型增加 | DAY |
| **空袭** | AIR_RAID | 只有气球僵尸 | 僵尸类型限制 | FOG |
| **冰关** | ICE | 磨菇主题关卡 | 固定 6 种种子 | LIMBO |
| **高重力** | HIGH_GRAVITY | 抛射体下坠更快 | 抛射体物理参数修改 | ROOF |
| **墓碑危机** | GRAVE_DANGER | 僵尸死后留下墓碑 | `GraveDangerSpawnRandomGrave()` | NIGHT |
| **铲子关** | SHOVEL | 只能用铲子清除坚果 | `ShovelAddWallnuts()` + 无种子 | LIMBO |
| **暴风雨** | STORMY_NIGHT | 闪电间歇照亮战场 | `UpdateStormyNight()` + 闪电视觉效果 | FOG |
| **蹦极闪击** | BUNGEE_BLITZ | 蹦极僵尸持续空降 | 每旗波固定 5 只蹦极 | ROOF |
| **松鼠** | SQUIRREL | 寻找隐藏松鼠 | `SquirrelUpdate()` + `GRIDITEM_SQUIRREL` | LIMBO |
| **智慧树** | TREE_OF_WISDOM | 禅境花园变种，喂肥智慧树 | `TreeOfWisdomUpdate/Grow/Fertilize()` | TREEOFWISDOM |
| **禅境花园** | ZEN_GARDEN | 养花浇水，非战斗 | `ZenGarden` 子系统 | GREENHOUSE |

---

## 9. 关卡结束的分支判断

`LawnApp::CheckForGameEnd()` (LawnApp.cpp:1446) 是最终的分流器：

```cpp
void LawnApp::CheckForGameEnd() {
    if (mBoard == nullptr || !mBoard->mLevelComplete) return;

    bool aUnlockedNewChallenge = UpdatePlayerProfileForFinishingLevel();

    if (IsAdventureMode()) {
        KillBoard();
        if (IsFirstTimeAdventureMode && level < 50)
            ShowAwardScreen(AWARD_FORLEVEL);
        else if (level == FINAL_LEVEL)
            ShowAwardScreen(AWARD_CREDITS_ZOMBIENOTE);
        else if (level == 9/19/29/39/49)
            ShowAwardScreen(AWARD_FORLEVEL);
        else
            PreNewGame(mGameMode, false);  // 自动下一关
    }
    else if (IsSurvivalMode()) {
        if (IsFinalSurvivalStage()) {
            KillBoard();
            ShowAwardScreen() 或 ShowChallengeScreen(CHALLENGE_PAGE_SURVIVAL);
        } else {
            mChallenge->mSurvivalStage++;
            KillGameSelector();
            mBoard->InitSurvivalStage();  // 重选卡，继续
        }
    }
    else if (IsPuzzleMode()) {
        KillBoard();
        ShowAwardScreen() 或 ShowChallengeScreen(CHALLENGE_PAGE_PUZZLE);
    }
    else {  // ChallengeMode
        KillBoard();
        ShowAwardScreen() 或 ShowChallengeScreen(CHALLENGE_PAGE_CHALLENGE);
    }
}
```

**关键差异：**
- **冒险模式**：KillBoard 后可能自动进入下一关（不回主菜单）
- **生存模式**：不 KillBoard，复用 Board 调用 `InitSurvivalStage()` 重选卡
- **解谜/迷你模式**：KillBoard 后回到模式选择界面

---

## 10. ChallengeDefinition — 纯 UI 数据

`ChallengeDefinition` (ChallengeScreen.h:59) 不参与任何规则逻辑，纯粹是 ChallengeScreen 的显示数据：

```cpp
class ChallengeDefinition {
public:
    GameMode mChallengeMode;      // 对应哪个 GameMode
    int mChallengeIconIndex;      // 图标索引
    ChallengePage mPage;          // 在哪个分页
    int mRow, mCol;               // 在分页内的网格位置
    const SexyChar* mChallengeName; // 显示名称
};
```

**分页：**
```cpp
enum ChallengePage {
    CHALLENGE_PAGE_SURVIVAL = 0,    // 生存模式
    CHALLENGE_PAGE_CHALLENGE = 1,   // 迷你游戏
    CHALLENGE_PAGE_LIMBO = 2,       // 隐藏/特殊模式
    CHALLENGE_PAGE_PUZZLE = 3,      // 解谜模式
};
```

75 个模式全部硬编码在一个 `gChallengeDefs[]` 静态数组中 (ChallengeScreen.cpp:15)。

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
