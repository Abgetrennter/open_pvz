# 帧率设计对比分析：de-pvz vs PVZ-Godot-Dream

> 生成时间：2026-05-07
> 目的：分析两个参考实现（原版逆向工程 de-pvz、Godot 复刻版 PVZ-Godot-Dream）的帧率架构设计，为 Open PVZ 引擎的帧率决策提供参考。

---

## 1. 项目概述

| 项目 | 技术栈 | 定位 |
|------|--------|------|
| **de-pvz** | C++ (SexyAppFramework + DirectX 8) | Plants vs Zombies v0.9.9.1029 逆向工程 |
| **PVZ-Godot-Dream** | Godot 4.6 (GDScript) | 基于 Godot 的高质量 PVZ 复刻 |

---

## 2. de-pvz 帧率架构（原版 PVZ）

### 2.1 核心定时参数

```cpp
// SexyAppFramework/SexyAppBase.cpp:186
mFrameTime = 10;  // 每帧 10ms → 逻辑帧率 100 FPS（100 ticks/秒）
```

**`mFrameTime = 10` 是整个引擎的基石常量**。游戏世界以 100 ticks/秒的固定步长推进。

### 2.2 主循环架构

de-pvz 使用经典的**固定时间步长（Fixed Timestep）**模式：

```
┌─────────────────────────────────────────────────────────┐
│                   de-pvz 主循环                          │
│                                                         │
│  DoMainLoop() {                                         │
│    while (!mShutdown) {                                 │
│      UpdateApp()                                        │
│        └─ UpdateAppStep()                               │
│              ├─ UPDATESTATE_MESSAGES:                   │
│              │    处理 Windows 消息队列                    │
│              │    ProcessDemo()                          │
│              │    → 转入 UPDATESTATE_PROCESS_1            │
│              │                                          │
│              └─ UPDATESTATE_PROCESS_1/2:                │
│                   Process(allowSleep=true)               │
│                     ├─ UpdateFTimeAcc()                  │
│                     │    累积真实时间差                    │
│                     │    mUpdateFTimeAcc += deltaTime     │
│                     │    上限 200ms                       │
│                     │                                   │
│                     ├─ 计算帧时间阈值 aFrameFTime:        │
│                     │    VSync: (1000/refreshRate)/mult   │
│                     │    非VSync: mFrameTime/mult         │
│                     │                                   │
│                     ├─ 检查是否需要更新:                  │
│                     │    if (mUpdateFTimeAcc >= aFrameFTime) │
│                     │                                   │
│                     ├─ DoUpdateFrames()                  │
│                     │    └─ UpdateFrames()               │
│                     │          └─ mUpdateCount++         │
│                     │          └─ WidgetManager::UpdateFrame() │
│                     │          └─ MusicInterface::Update()     │
│                     │          └─ CleanSharedImages()    │
│                     │                                   │
│                     ├─ DoUpdateFramesF(frac)             │
│                     │    └─ WidgetManager::UpdateFrameF() │
│                     │        （VSync 插值帧）             │
│                     │                                   │
│                     ├─ mUpdateFTimeAcc -= aFrameFTime    │
│                     │    （扣除已消耗的时间）              │
│                     │                                   │
│                     └─ DrawDirtyStuff()                  │
│                          渲染脏区域                       │
│    }                                                    │
│  }                                                      │
└─────────────────────────────────────────────────────────┘
```

#### 源文件参考

| 组件 | 文件 | 行号 |
|------|------|------|
| mFrameTime 初始化 | `SexyAppFramework/SexyAppBase.cpp` | 186 |
| Process() 主循环 | `SexyAppFramework/SexyAppBase.cpp` | 5211-5478 |
| DoUpdateFrames() | `SexyAppFramework/SexyAppBase.cpp` | 2240-2310 |
| UpdateFrames() 基类 | `SexyAppFramework/SexyAppBase.cpp` | 2220-2232 |
| LawnApp::UpdateFrames() | `LawnApp.cpp` | 1586-1634 |
| DoMainLoop() | `SexyAppFramework/SexyAppBase.cpp` | 5514-5522 |
| Windows Timer 注册 | `SexyAppFramework/SexyAppBase.cpp` | 4866 |

### 2.3 LawnApp 的 UpdateFrames()

```cpp
// LawnApp.cpp:1586-1634
void LawnApp::UpdateFrames()
{
    if ((!mActive || mMinimized) && mBoard)
    {
        mBoard->ResetFPSStats();
    }

    int aUpdateCount = 1;
    if (gSlowMo)
    {
        ++gSlowMoCounter;
        if (gSlowMoCounter < 4)
            aUpdateCount = 0;   // 跳过 3/4 的逻辑帧
        else
            gSlowMoCounter = 0;
    }
    else if (gFastMo)
    {
        aUpdateCount = 20;      // 每渲染帧执行 20 个逻辑帧
    }

    for (int i = 0; i < aUpdateCount; i++)
    {
        mAppCounter++;          // 全局逻辑 tick 计数器

        if (mBoard)
            mBoard->ProcessDeleteQueue();

        SexyApp::UpdateFrames();

        mMusic->MusicUpdate();
        if (mLoadingThreadCompleted && mEffectSystem)
            mEffectSystem->ProcessDeleteQueue();

        CheckForGameEnd();
    }
}
```

### 2.4 游戏速度控制

| 模式 | 实现方式 | 有效 tick 率 |
|------|----------|-------------|
| **正常** | `mUpdateMultiplier = 1.0` | 100 ticks/s |
| **慢动作** | `gSlowMo = true`，每 4 帧执行 1 次 | 25 ticks/s |
| **快进** | `gFastMo = true`，每渲染帧 20 次 | 最高 2000 ticks/s |
| **调试变速** | `mUpdateMultiplier *= 1.5` 或 `/= 1.5` | 66.7~150 ticks/s |

#### 慢动作/快进实现细节

```cpp
// SexyAppBase.cpp:4106-4109 (ToggleSlowMo)
if (mUpdateMultiplier == 0.25)
    mUpdateMultiplier = 1.0;
else
    mUpdateMultiplier = 0.25;

// SexyAppBase.cpp:3488-3494 (快进键)
aSexyApp->mUpdateMultiplier *= 1.5;  // Ctrl+] 加速
aSexyApp->mUpdateMultiplier /= 1.5;  // Ctrl+[ 减速
aSexyApp->mUpdateMultiplier = 1;      // Ctrl+\ 重置
```

### 2.5 VSync 适配机制

当启用 VSync 时，渲染帧率被锁定到显示器刷新率（通常 60Hz）。但逻辑帧仍然需要 100Hz。de-pvz 通过**累积器模式**解决这个问题：

```cpp
// SexyAppBase.cpp:5229-5237
if (mVSyncUpdates)
{
    aFrameFTime = (1000.0 / mSyncRefreshRate) / mUpdateMultiplier;
    anUpdatesPerUpdateF = (float)(1000.0 / (mFrameTime * mSyncRefreshRate));
    // 当 VSync=60Hz, mFrameTime=10: anUpdatesPerUpdateF = 1000/(10*60) ≈ 1.67
    // 即每个 VSync 帧需要执行 ~1.67 个逻辑帧
}
else
{
    aFrameFTime = mFrameTime / mUpdateMultiplier;
    anUpdatesPerUpdateF = 1.0;
    // 非VSync时每个时间步恰好执行1个逻辑帧
}
```

`mPendingUpdatesAcc` 累积小数部分，当累积到 ≥1 时多执行一个逻辑帧：

```cpp
// SexyAppBase.cpp:5388-5406
mPendingUpdatesAcc += anUpdatesPerUpdateF;  // +1.67
mPendingUpdatesAcc -= 1.0;                  // 减去已执行的1帧

// 累积器 ≥ 1 时补一个逻辑帧
while (mPendingUpdatesAcc >= 1.0)
{
    ProcessDemo();
    bool hasRealUpdate = DoUpdateFrames();
    mPendingUpdatesAcc -= 1.0;
}
```

### 2.6 动画定时

de-pvz 使用 `mAppCounter`（100Hz tick 计数器）来驱动动画帧索引：

```cpp
// Zombie.cpp:6088
return (mApp->mAppCounter % (aFrameLength * aFramesCount)) / aFrameLength;
```

这意味着：
- `aFrameLength` = 一个动画帧持续的 tick 数（如 `aFrameLength=8` 表示 80ms/帧）
- `aFramesCount` = 总帧数
- 通过 `%` 和 `/` 运算直接在 100Hz tick 上做帧索引，**不需要 delta**

### 2.7 定时约束

| 约束 | 实现 |
|------|------|
| 累积器上限 | `mUpdateFTimeAcc = min(mUpdateFTimeAcc + deltaTime, 200.0)` — 最多补 200ms |
| 最低绘制率 | `ceil(10 * mUpdateMultiplier)` 个逻辑帧内必须绘制一次 |
| 退避检测 | VSync 损坏检测：如果 1000 个 tick 在 800ms 内跑完，认为 VSync 已坏，退回非 VSync 模式 |
| 渲染帧间 Sleep | `aTimeToNextFrame = aFrameFTime - mUpdateFTimeAcc`；Sleep 等待 |

---

## 3. PVZ-Godot-Dream 帧率架构（Godot 复刻版）

### 3.1 核心定时参数

`project.godot` 中 **没有任何帧率配置**，全部使用 Godot 默认值：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `physics/common/physics_fps` | **60 FPS** | `_physics_process` 的固定步长 (~16.67ms) |
| 渲染帧率 | **无限制** | 取决于显示器刷新率 |
| VSync | **默认启用** | `true` |
| `application/run/max_fps` | **0** (无限制) | — |

### 3.2 主循环架构

PVZ-Godot-Dream 完全依赖 Godot 的标准帧回调，**没有自定义 tick/step 系统**：

```
┌─────────────────────────────────────────────────────────┐
│           PVZ-Godot-Dream 帧率架构                       │
│                                                         │
│  _process(delta)                  // 渲染帧率，可变 delta  │
│    ├─ 僵尸移动 (component_move.gd:113)                    │
│    │    └─ delta * curr_speed * direction                 │
│    ├─ 卡片冷却 UI (card.gd:68)                            │
│    ├─ 手持物品状态机 (hand_manager.gd:29)                  │
│    ├─ 检测组件 (component_detect.gd:132)                  │
│    │    └─ 事件驱动 need_judge 标志                        │
│    ├─ 割草机移动 (lawn_mower.gd:19)                       │
│    ├─ 跳跃僵尸 (component_jump.gd:44)                     │
│    ├─ 浓雾更新 (fog.gd:47)                                │
│    └─ UI 动画 / 进度条 / 传送带                            │
│                                                         │
│  _physics_process(delta)           // 固定 60Hz           │
│    ├─ 僵尸啃食伤害 (component_attack_zombie_norm.gd:37)   │
│    │    └─ frame_counter % 8 → 有效频率 7.5Hz            │
│    ├─ HP流失 (component_hp_zombie.gd:76)                  │
│    │    └─ num_frame % 4 → 有效频率 15Hz                 │
│    ├─ 音效去重 (sound_manager.gd:21)                      │
│    │    └─ frame_num % 25 → 有效频率 2.4Hz              │
│    ├─ 抛射体直线运动 (bullet_000_linear_base.gd:19)       │
│    ├─ 抛射体抛物线运动 (bullet_000_parabola_base.gd:50)   │
│    ├─ 抛射体追踪运动 (bullet_000_track_base.gd:26)        │
│    └─ 掉落尸体 (ZombieDropBase.gd:27)                     │
│                                                         │
│  Timer 节点 (受 Engine.time_scale 影响)                   │
│    ├─ 植物攻击冷却 1.5s (component_attack_bullet_base)    │
│    ├─ 阳光生成 (day_suns_manager)                         │
│    ├─ 波次刷新 25-46s (zm_zombie_wave_refresh_manager)    │
│    ├─ 波次进度 1s (zm_zombie_wave_manager)                │
│    ├─ 战场边界 0.3s (zombie_000_base)                     │
│    ├─ 减速/冻结/黄油 (character_000_base)                  │
│    └─ 植物生长 (各植物子类)                                │
│                                                         │
│  Engine.time_scale: 1.0-8.0 (默认 1.0)                  │
│  暂停: TreePauseManager → get_tree().paused              │
└─────────────────────────────────────────────────────────┘
```

### 3.3 子采样帧率模式（硬编码 60Hz 假设）

#### a) 僵尸啃食：~7.5 Hz (60/8)

```gdscript
# scripts/character/components/attack_behavior_component/component_attack_zombie_norm.gd:19,37-43
var frame_counter := 0

func _physics_process(delta: float) -> void:
    if is_enabling and is_attack_res:
        frame_counter = wrapi(frame_counter + 1, 0, 8)
        if not is_instance_valid(detect_component.enemy_can_be_attacked):
            return
        if frame_counter == 0 and is_instance_valid(detect_component.enemy_can_be_attacked):
            detect_component.enemy_can_be_attacked.be_zombie_eat(
                int(curr_attack_value_per_min * delta * 8), owner
            )
```

**分析**：
- `frame_counter` 循环 0→7，仅在 `==0` 时造成伤害 → 每 8 个物理帧触发一次
- `delta * 8` 补偿子采样：`delta ≈ 1/60 = 0.0167`，`delta * 8 ≈ 0.133s/周期`
- `attack_value_per_min * 0.133` 将"每分钟伤害"转换为"每啃食周期伤害"
- **如果 physics FPS 不是 60，DPS 会非线性变化**

#### b) 扶梯僵尸啃食：相同模式

```gdscript
# scripts/character/components/attack_behavior_component/component_attack_zombie_ladder.gd:9-23
func _physics_process(delta: float) -> void:
    frame_counter = wrapi(frame_counter + 1, 0, 8)
    if frame_counter==0 and is_instance_valid(detect_component.enemy_can_be_attacked):
        detect_component.enemy_can_be_attacked.be_zombie_eat(...)
```

#### c) 死亡后 HP 流失：~15 Hz (60/4)

```gdscript
# scripts/character/components/hp_component/component_hp_zombie.gd:57-80
# 注释：死亡后每4帧掉一次血
var num_frame := 0

func _physics_process(delta: float) -> void:
    if owner_character.is_death and curr_hp != 0:
        num_frame = wrapi(num_frame + 1, 0, 4)
        if num_frame == 0:
            curr_hp -= max(int(delta * 50 * 4), 1)
```

`delta * 50 * 4` ≈ `(1/60) * 50 * 4 ≈ 3.33 HP/周期`，等效于 `50 HP/s`。

#### d) 音效去重：~2.4 Hz (60/25)

```gdscript
# scripts/autoload/sound_manager.gd:11-24
var curr_frame_sfx:Array[AudioStream] = []
var frame_num:=0

func _physics_process(delta: float) -> void:
    frame_num = wrapi(frame_num + 1, 0, 25)
    if frame_num == 0:
        curr_frame_sfx.clear()
```

每 25 个物理帧（~417ms）清空音效缓冲区，防止同一音效在短时间内重复播放。

### 3.4 移动系统

#### 僵尸移动（_process 驱动）

```gdscript
# scripts/character/components/component_move.gd:113-131
func _process(delta: float) -> void:
    if is_move:
        match move_mode:
            E_MoveMode.Ground:
                # 根据 ground 节点的位移反向调整僵尸位置（动画驱动）
                _walk()
            E_MoveMode.Speed:
                # 速度驱动移动
                var move_x = delta * curr_speed * owner_zombie.direction_x_root
                owner_zombie.position.x -= move_x
                move_y_correct(move_x)
```

两种移动模式：
- **Ground 模式**：动画驱动的位移，根据 `_ground` 节点的实际坐标变化来推算移动量
- **Speed 模式**：`delta * speed` 标准速率移动

#### 抛射体运动（_physics_process 驱动）

```gdscript
# scripts/bullet/component/movement/bullet_movement_linear.gd:6-7
func physics_process_bullet_move(delta: float) -> bool:
    bullet.position += bullet.direction * bullet.speed * delta
    return true
```

所有抛射体运动（linear/parabola/track）都在 `_physics_process` 中以固定步长执行。

### 3.5 Timer 定时系统

PVZ-Godot-Dream **大量使用 Godot Timer 节点**来驱动游戏节奏。所有 Timer 自动受 `Engine.time_scale` 影响。

| 系统 | Timer 用途 | 间隔 | 文件 |
|------|-----------|------|------|
| 植物攻击冷却 | `bullet_attack_cd_timer` | ~1.5s (可变) | `component_attack_bullet_base.gd:7,38` |
| 阳光生成 | `production_timer` | 可变 (毫秒/100→秒) | `day_suns_manager.gd:5-70` |
| 波次刷新 | `wave_norm_refresh_timer` | 25-46s | `zm_zombie_wave_refresh_manager.gd:17-19` |
| 波次最低时间 | `wave_min_time_timer` | 6s | `zm_zombie_wave_refresh_manager.gd:18` |
| 波次进度 | `every_wave_progress_timer` | 1s | `zm_zombie_wave_manager.gd:17` |
| 战场边界检测 | `judge_battlefield_timer` | 0.3s | `zombie_000_base.gd:231-255` |
| 植物生长 | `grow_timer` | 按植物类型 | 各植物文件 |
| 减速效果 | `all_timer[IceDecelerate]` | 效果持续时间 | `character_000_base.gd:264-311` |
| 冻结效果 | `all_timer[IceFreeze]` | 效果持续时间 | 同上 |
| 黄油眩晕 | `all_timer[Butter]` | 效果持续时间 | `zombie_000_base.gd:529-540` |
| 小丑炸弹 | `jack_bomb_timer` | 随机 | `component_bomb_jackbox.gd:6` |

**速度变化时 Timer 的处理**：

```gdscript
# component_attack_bullet_base.gd:50-59
func owner_update_speed(speed_product:float):
    if not bullet_attack_cd_timer.is_stopped():
        if speed_product == 0:
            bullet_attack_cd_timer.paused = true
        else:
            bullet_attack_cd_timer.paused = false
            bullet_attack_cd_timer.start(bullet_attack_cd_timer.time_left / speed_product)
    bullet_attack_cd_timer.wait_time = attack_cd / speed_product
```

**唯一的 `ignore_time_scale` 用例**：

```gdscript
# scary_pot.gd:326
res_random_character_static_update_timer.ignore_time_scale = true
```

### 3.6 游戏速度控制

```gdscript
# scripts/manager/main_game_manager.gd:18-23
## 游戏速度
## INFO: 游戏速度超过8会代码执行顺序会有问题，可能会导致一些莫名其妙的bug
@export var test_time_scale:=1:
    set(value):
        test_time_scale = value
        Engine.time_scale = test_time_scale
```

通过 `Engine.time_scale` 控制，影响：
- `_process(delta)` 和 `_physics_process(delta)` 中的 `delta` 值被缩放
- Godot Timer 节点的流逝速度被缩放
- Tween 动画的速度被缩放

**但不会改变物理模拟的实际步进频率**——物理仍以固定间隔运行，只是每步模拟的时间跨度被压缩/拉伸。

### 3.7 暂停系统

```gdscript
# scripts/autoload/tree_pause_manager.gd
enum E_PauseFactor {
    Menu,           # 暂停菜单
    GameOver,       # 游戏结束
    ReChooseCard,   # 重新选卡
}
```

使用 `get_tree().paused` 实现多因素暂停，同时冻结 `_process` 和 `_physics_process`。暂停期间，需要继续运行的 UI 节点设置为 `PROCESS_MODE_ALWAYS`：

```gdscript
# main_game_manager.gd:321-322
camera_2d.process_mode = Node.PROCESS_MODE_ALWAYS
card_slot_root.process_mode = Node.PROCESS_MODE_ALWAYS
```

---

## 4. 对比总结

### 4.1 核心架构差异

| 维度 | de-pvz (原版) | PVZ-Godot-Dream (复刻) |
|------|--------------|------------------------|
| **架构模式** | 固定时间步长 (Fixed Timestep) | Godot 默认回调 (Variable + Semi-fixed) |
| **逻辑帧率** | **100 FPS** (10ms/tick) | **60 FPS** 物理 + 可变渲染 |
| **物理帧率** | 无独立物理（与逻辑合一） | **60 FPS** (Godot 默认) |
| **渲染帧率** | 可变，VSync 适配；保证 ≥10 FPS | 可变，无限制 |
| **全局 tick 计数器** | `mAppCounter` (100Hz 精度) | 无 |
| **时间步进方式** | 纯固定步长，累积器补齐 | 物理半固定 + 渲染完全可变 |
| **确定性** | **高** — 固定 100Hz tick，可完全重播 | **低** — 可变 delta + 隐式帧率假设 |

### 4.2 游戏速度控制对比

| 维度 | de-pvz | PVZ-Godot-Dream |
|------|--------|-----------------|
| 正常速度 | 100 ticks/s | 60 physics FPS |
| 慢动作 | 每 4 帧执行 1 次 → 25 ticks/s | 无独立慢动作 |
| 快进 | 每渲染帧 20 次 → 最高 2000 ticks/s | `Engine.time_scale` 最大 8x |
| 倍速控制 | `mUpdateMultiplier` 乘除 1.5 | `Engine.time_scale` 直接设值 |
| 变速影响范围 | 全局 tick 率 | delta + Timer + Tween 全部缩放 |

### 4.3 伤害/HP 定时对比

| 维度 | de-pvz | PVZ-Godot-Dream |
|------|--------|-----------------|
| 僵尸啃食频率 | 基于 100Hz tick，每 N tick 一次 | `frame_counter % 8` → 7.5Hz (60/8) |
| 伤害计算 | 固定值 × tick 比例 | `attack_per_min * delta * 8` |
| 帧率依赖 | **无** — 基于 tick 间隔 | **有** — `*8` 假设 60Hz |
| HP 流失 | 基于 tick 的固定步进 | `delta * 50 * 4`，假设 60Hz |
| 动画帧选择 | `mAppCounter % (len*count) / len` | Godot AnimationPlayer 自动 |

### 4.4 VSync 对比

| 维度 | de-pvz | PVZ-Godot-Dream |
|------|--------|-----------------|
| VSync 支持 | 显式支持，有累积器适配 | 由 Godot 引擎处理 |
| 逻辑/渲染解耦 | `mPendingUpdatesAcc` 累积器 | Godot 内部处理 |
| VSync 损坏检测 | 有 — 连续 3 次超速检测后退回 | 无 |
| 跨帧补齐 | 显式：累积器 ≥1 时多执行 1 个逻辑帧 | 隐式：Godot 内部处理 |

### 4.5 定时器系统对比

| 维度 | de-pvz | PVZ-Godot-Dream |
|------|--------|-----------------|
| 定时器实现 | 无独立定时器，全部基于 tick 计数 | Godot Timer 节点 |
| 攻击冷却 | tick 计数 | Timer.wait_time |
| 波次刷新 | tick 计数 + 随机偏移 | Timer + 范围 |
| 阳光生成 | tick 计数 | Timer (毫秒/100→秒) |
| 状态效果 | tick 计数 | Timer (冰冻/黄油等) |
| 倍速感知 | 通过 tick 率变化隐式感知 | `Engine.time_scale` 自动缩放 Timer |

### 4.6 关键代码假设

| 假设 | de-pvz | PVZ-Godot-Dream |
|------|--------|-----------------|
| 逻辑帧率假设 | `mFrameTime = 10` 写死一处 | `*8`、`*4` 多处隐式假设 60Hz |
| 修改帧率的影响 | 改 `mFrameTime` 一处即可 | 需要找到所有 `*N` 硬编码并修正 |
| 累积器上限 | 200ms | 无（Godot 内部处理） |
| 渲染安全网 | 保证 ≥10 FPS 绘制 | 无显式保证 |

---

## 5. 架构图对比

### de-pvz

```
┌─────────────────────────────────────────────────────────────┐
│                        de-pvz                                │
│                                                              │
│  Windows Timer (10ms)                                        │
│    └─ WM_TIMER → UpdateApp() → Process()                    │
│         │                                                    │
│         ├─ UpdateFTimeAcc()  ←── 累积真实时间                 │
│         │                                                    │
│         ├─ [VSync?]  ──→ 计算每渲染帧需要的逻辑帧数             │
│         │    Yes: anUpdatesPerUpdateF = 1000/(10*refresh)    │
│         │    No:  anUpdatesPerUpdateF = 1.0                  │
│         │                                                    │
│         ├─ [mUpdateFTimeAcc >= aFrameFTime?]                 │
│         │    └─ DoUpdateFrames()                             │
│         │         └─ LawnApp::UpdateFrames()                 │
│         │              ├─ mAppCounter++  (100Hz 全局计数器)    │
│         │              ├─ SlowMo: 1/4 tick                   │
│         │              ├─ FastMo: 20x tick                   │
│         │              └─ Board::ProcessDeleteQueue()        │
│         │                   + WidgetManager::UpdateFrame()   │
│         │                   + MusicUpdate()                  │
│         │                   + CheckForGameEnd()              │
│         │                                                    │
│         ├─ mPendingUpdatesAcc 累积器补齐 (VSync时)            │
│         │                                                    │
│         ├─ DoUpdateFramesF(frac)  ←── VSync 插值帧           │
│         │                                                    │
│         ├─ mUpdateFTimeAcc -= aFrameFTime                     │
│         │                                                    │
│         └─ DrawDirtyStuff() ←── 渲染（保证 ≥10Hz）           │
│                                                              │
│  逻辑帧: 100 FPS 固定步长 (10ms/tick)                         │
│  渲染帧: 可变，VSync 适配                                     │
│  物理帧: 无独立物理（与逻辑帧合一）                             │
│  确定性: 高 — 固定 tick + 全局计数器                           │
└─────────────────────────────────────────────────────────────┘
```

### PVZ-Godot-Dream

```
┌─────────────────────────────────────────────────────────────┐
│                   PVZ-Godot-Dream                            │
│                                                              │
│  Godot 主循环                                                │
│    │                                                         │
│    ├─ _process(delta)  ←── 渲染帧率（可变 delta）             │
│    │    ├─ 僵尸移动 (Speed 模式: delta * speed)               │
│    │    ├─ 僵尸移动 (Ground 模式: 动画驱动)                    │
│    │    ├─ 卡片冷却 UI                                       │
│    │    ├─ 手持物品状态机                                     │
│    │    ├─ 检测组件（事件驱动 need_judge）                    │
│    │    ├─ 割草机/跳跃/浓雾                                  │
│    │    └─ UI 动画                                           │
│    │                                                         │
│    ├─ _physics_process(delta)  ←── 固定 60Hz (Godot 默认)    │
│    │    ├─ 僵尸啃食: frame_counter % 8 → 7.5Hz              │
│    │    │    └─ damage = attack_per_min * delta * 8          │
│    │    ├─ HP 流失: num_frame % 4 → 15Hz                    │
│    │    │    └─ drain = delta * 50 * 4                       │
│    │    ├─ 音效去重: frame_num % 25 → 2.4Hz                 │
│    │    ├─ 抛射体运动: delta * speed                         │
│    │    └─ 掉落尸体                                          │
│    │                                                         │
│    ├─ Timer 节点  ←── 受 Engine.time_scale 影响              │
│    │    ├─ 植物攻击冷却 (~1.5s)                              │
│    │    ├─ 阳光生成 (可变间隔)                                │
│    │    ├─ 波次刷新 (25-46s)                                 │
│    │    ├─ 状态效果 (减速/冻结/黄油)                          │
│    │    └─ 战场边界检查 (0.3s)                               │
│    │                                                         │
│    └─ Engine.time_scale: 1.0-8.0                            │
│         └─ 缩放所有 delta + Timer + Tween                    │
│                                                              │
│  逻辑帧: 60 FPS 物理 + 可变渲染                               │
│  渲染帧: 可变，无限制                                         │
│  物理帧: 60 FPS (Godot 默认)                                  │
│  确定性: 低 — 可变 delta + 隐式 60Hz 假设                     │
│  暂停: TreePauseManager → get_tree().paused                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. 对 Open PVZ 引擎的启示

### 6.1 关键发现

1. **原版 PVZ 使用 100Hz 固定 tick**：这不是随意选择。100Hz 提供了足够高的定时精度（10ms 粒度），使动画、伤害、移动等逻辑在 tick 层面上精确同步，同时避免了浮点累积误差。

2. **PVZ-Godot-Dream 的 60Hz 假设是技术债**：`delta * 8`、`delta * 4` 等硬编码因子假设物理帧率为 60Hz。如果修改 `physics/common/physics_fps`，啃食 DPS 和 HP 流失率会非线性变化。

3. **两个实现的定时精度差距显著**：de-pvz 的 100Hz tick 提供了 10ms 的定时精度；PVZ-Godot-Dream 的 Timer 节点虽然精确但粒度不统一（0.3s、1.5s 等各异），而子采样模式的有效频率（7.5Hz、15Hz）远低于 100Hz。

4. **确定性随机需要确定性 tick**：de-pvz 的 `mAppCounter` 可以作为确定性随机的种子源，而 PVZ-Godot-Dream 没有等价的全局 tick 计数器。

### 6.2 建议

1. **考虑采用固定时间步长模式**：类似 de-pvz 的累积器模式（`mUpdateFTimeAcc` + `mPendingUpdatesAcc`），将逻辑帧率与渲染帧率解耦。

2. **如果使用 Godot 默认物理帧率，避免帧计数子采样**：PVZ-Godot-Dream 的 `frame_counter % 8` 模式是一种反模式——更好的做法是直接用 Timer 或基于时间的累积器。

3. **全局 tick 计数器的价值**：对于确定性随机、动画同步、回放系统来说，一个高频（≥60Hz）的全局 tick 计数器是有价值的。

4. **`Engine.time_scale` 的局限性**：Godot 的 `Engine.time_scale` 会缩放所有 delta 和 Timer，但不会改变物理步进频率。如果需要精确的游戏速度控制，需要自行实现。
