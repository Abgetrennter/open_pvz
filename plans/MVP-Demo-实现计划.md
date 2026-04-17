# MVP Demo 实现计划

> 目标：在当前已完成的引擎骨架 + 战斗玩法子系统之上，补齐**玩家交互层**和**表现层**的最小闭环，实现一个**可实际操作的 PvZ-like 单关卡 Demo**。

---

## 一、现状盘点

### 已完成（可直接复用）

| 层 | 系统 | 状态 |
|---|---|---|
| 引擎核 | EventBus / TriggerRegistry / EffectRegistry / ProtocolValidator | 冻结、稳定、26 个验证场景覆盖 |
| 引擎核 | EntityTemplate / ProjectileTemplate / TriggerBinding 资源链 | 冻结、有 14 植物 + 7 僵尸 + 6 投射体模板 |
| 引擎核 | EntityFactory 装配链 | 完整，支持组件挂载、属性覆盖、触发器绑定 |
| 引擎核 | 投射体系统（linear / parabola / track + 3D-2D 投影） | 完整 |
| 引擎核 | 实体运行时（BaseEntity / PlantRoot / ZombieRoot / ProjectileRoot） | 完整，ZombieRoot 有自动行走 + 近战 AI |
| 玩法层 | BattleEconomyState（阳光生产 / 天降 / 收集 / 消耗） | 完整，有 sun_resource_validation |
| 玩法层 | BattleBoardState（格子 / 类型 / 标签 / 放置校验 / 占位提交） | 完整，有 board_placement_validation |
| 玩法层 | BattleCardState（手牌 / 费用 / 冷却 / play_card 完整流程） | 完整，有 card_flow_validation |
| 玩法层 | BattleFlowState（preparing / running / victory / defeat） | 完整，有 wave_flow_validation |
| 玩法层 | WaveRunner（波次调度 / 生成 / 胜负检测） | 完整 |
| 玩法层 | BattleStatusState（slow / stun 状态） | 完整 |
| 玩法层 | BattleFieldObjectState + LawnMower（割草机三态机） | 完整 |
| 表现层 | DebugOverlay（调试 HUD） | 完整 |
| 表现层 | ShowcaseHub（菜单场景选择） | 完整 |

### 未完成（Demo 必须补齐）

| 缺口 | 说明 |
|---|---|
| **玩家输入** | 当前 card play 全部由 `CardPlayRequest` 预调度驱动，无鼠标/键盘交互 |
| **阳光拾取** | `SunCollectible` 有 auto-collect 定时器，但无点击收集 |
| **棋盘格子渲染** | 格子数据存在 `BattleBoardState` 里，但场景中无可视格子节点 |
| **卡片栏 HUD** | 无卡片手牌 UI（选中、冷却遮罩、费用显示） |
| **阳光计数 HUD** | 无阳光数值显示 |
| **波次进度提示** | 无 "A huge wave of zombies is approaching" 等提示 |
| **胜负画面** | victory/defeat 状态后无画面反馈 |
| **演示关卡配置** | 无面向玩家的、有完整流程的 BattleScenario |

### 未完成（Demo 可以暂缓）

| 暂缓项 | 理由 |
|---|---|
| 精灵 / 动画系统 | 当前 `_draw()` 原始图形足够表达玩法，视觉升级后置 |
| 音频系统 | 不阻塞玩法闭环 |
| 拖拽放置 | 点击放置即可，不需要完整 drag & drop |
| 选关 / 菜单 / 存档 | 外循环，Demo 只需一个关卡 |
| 铲子 / 移除 | 先不做，玩家只放不移除 |
| 多车道 / 多地形 | Demo 固定 5 车道草地 |

---

## 二、MVP Demo 定义

### 目标体验

玩家在 Godot 中运行项目，进入 Demo 关卡，体验以下完整流程：

```
进入关卡 -> 看到草地 + 格子 + 卡片栏
    -> 天降阳光，点击收集
    -> 点击卡片选中植物
    -> 点击格子放置植物
    -> 植物自动攻击
    -> 波次僵尸从右侧进入
    -> 割草机保护底线
    -> 全部波次清除 -> 胜利画面
    -> 或僵尸突破防线 -> 失败画面
    -> 按 R 重开 / 按 Esc 返回
```

### 核心参数

| 参数 | 值 |
|---|---|
| 车道数 | 5 |
| 每车道格子数 | 9 |
| 初始阳光 | 50 |
| 天降阳光间隔 | ~8 秒 |
| 波次数 | 3 波 |
| 卡片数 | 5 张 |
| Demo 用植物 | 基础射手、向日葵（产阳光）、坚果墙、双发射手、投手 |
| Demo 用僵尸 | 基础行尸、快速僵尸、铁桶僵尸 |

---

## 三、实现拆解

### 总览：4 个 Epic，12 个 Issue

```
Epic 1: 棋盘可视化 + 格子交互          ─┐
Epic 2: 卡片栏 HUD + 阳光 HUD          ─┤── 表现层
Epic 3: 阳光点击收集 + 玩家输入桥接     ─┤── 输入层
Epic 4: Demo 关卡配置 + 胜负画面        ─┘── 内容层
```

---

### Epic 1：棋盘可视化 + 格子交互

**目标**：让 `BattleBoardState` 的逻辑格子变成可见、可点击的格子。

#### Issue 1.1：BoardVisual 节点

- **产出**：`scripts/demo/board_visual.gd`（Node2D）
- **内容**：
  - 根据 `BattleBoardState` 的格子数据（lanes x slot_count）生成 `BoardCellVisual` 子节点
  - 每个格子绘制淡绿色矩形 + 网格线
  - 暴露 `get_slot_at_world_pos(world_pos) -> {lane, slot_index}` 方法
  - 暴露信号 `cell_clicked(lane, slot_index)`
  - 鼠标悬停高亮（浅色叠加）
- **依赖**：`BattleBoardState`（已完成）
- **验证**：运行后可见 5x9 格子，鼠标悬停高亮

#### Issue 1.2：BoardCellVisual 子节点

- **产出**：`scripts/demo/board_cell_visual.gd`（Area2D）
- **内容**：
  - CollisionShape2D 矩形检测鼠标进入/点击
  - `_draw()` 绘制格子背景
  - 状态：`normal / hover / occupied / invalid`
  - 不同状态不同颜色
- **依赖**：无
- **验证**：格子可点击并切换状态

#### Issue 1.3：格子与放置系统的桥接

- **产出**：在 `board_visual.gd` 中
- **内容**：
  - `cell_clicked` 信号连接到放置请求
  - 调用 `BattleCardState.play_card(card_id, lane, slot_index)` 走完整放置链
  - 放置成功后格子状态变 `occupied`
  - 放置失败时格子闪红
  - 实体死亡后格子状态恢复 `normal`
- **依赖**：Issue 1.1 + Issue 1.2 + Epic 3 输入桥接
- **验证**：点击空格 + 选中卡片 -> 实体出现 + 格子变 occupied

---

### Epic 2：卡片栏 HUD + 阳光 HUD

**目标**：屏幕顶部显示可交互的卡片栏和阳光计数。

#### Issue 2.1：CardBar HUD

- **产出**：`scripts/demo/card_bar.gd`（Control）
- **内容**：
  - 横向排列卡片槽位（最多 5 张）
  - 每个槽位显示：植物颜色方块 + 费用数字 + 冷却遮罩
  - 点击卡片 -> 发出 `card_selected(card_id)` 信号
  - 再次点击已选中卡片 -> 取消选中
  - 冷却中的卡片灰显 + 覆盖倒计时动画
  - 费用不足时卡片显示为红色边框
- **数据来源**：从 `BattleScenario.card_defs` 读取卡片定义
- **运行时同步**：
  - 监听 `card.cooldown_started` -> 开始冷却遮罩动画
  - 监听 `resource.changed` -> 刷新费用可支付状态
- **依赖**：`CardDef`（已完成）
- **验证**：顶部卡片栏可见，点击选中高亮

#### Issue 2.2：SunCounter HUD

- **产出**：`scripts/demo/sun_counter.gd`（Control）
- **内容**：
  - 左上角显示阳光图标 + 数字
  - 监听 `resource.changed` 事件实时更新
  - 数值变化时短暂放大动画（tween）
- **依赖**：`BattleEconomyState`（已完成）
- **验证**：收集阳光后数字增加

#### Issue 2.3：WaveIndicator HUD

- **产出**：`scripts/demo/wave_indicator.gd`（Control）
- **内容**：
  - 右上角显示 "Wave 1/3" 文字
  - 监听 `wave.started` / `wave.completed` 事件更新
  - 最后一波时显示 "Final Wave!" 红色提示
- **依赖**：`BattleFlowState`（已完成）
- **验证**：波次推进时数字更新

---

### Epic 3：阳光点击收集 + 玩家输入桥接

**目标**：把鼠标点击接入阳光收集和卡片放置。

#### Issue 3.1：SunCollectible 点击收集

- **产出**：修改现有 `scripts/battle/sun_collectible.gd`
- **内容**：
  - 添加 Area2D + CollisionShape2D 用于鼠标检测
  - 鼠标点击时调用 `collect()`（已有方法）
  - 收集时播放简单飞向左上角的 tween 动画（0.3s）
  - 动画结束后 queue_free
- **注意**：当前 `SunCollectible` 已有 auto-collect 定时器，保留但延长到 12 秒
- **依赖**：`SunCollectible`（已完成）
- **验证**：点击阳光 -> 数字增加 -> 阳光消失

#### Issue 3.2：InputBridge 统一输入处理

- **产出**：`scripts/demo/input_bridge.gd`（Node）
- **内容**：
  - 持有当前选中的 `card_id`（可为 null）
  - 接收 `CardBar.card_selected` 信号 -> 更新选中状态
  - 接收 `BoardVisual.cell_clicked` 信号 -> 如果有选中卡片，调用放置
  - 点击空白区域 -> 取消选中
  - 按 Esc -> 取消选中
  - 放置成功/失败后自动取消选中
- **依赖**：Epic 1 + Epic 2
- **验证**：选中卡片 -> 点击格子 -> 植物出现

#### Issue 3.3：天降阳光的视觉呈现

- **产出**：修改 `BattleEconomyState.spawn_sun()`
- **内容**：
  - 天降阳光从屏幕顶部随机位置落下
  - 下落动画（tween，2-3 秒落到底部）
  - 落到底部后开始 12 秒 auto-collect 倒计时
  - 已有 `SunCollectible` 添加 `_draw()` 绘制黄色圆形
- **依赖**：Issue 3.1
- **验证**：阳光从天而降，点击可收集

---

### Epic 4：Demo 关卡配置 + 胜负画面

**目标**：创建一个可玩的演示关卡，配合完整流程。

#### Issue 4.1：Demo 关卡 BattleScenario 资源

- **产出**：`data/combat/validation_scenes/demo_level.tres`
- **内容**：
  - **卡片**（5 张）：
    - `sunflower`：费用 50，向日葵产阳光（用现有 plant_water_pod 改为产阳光）
    - `peashooter`：费用 100，基础射手
    - `wallnut`：费用 50，坚果墙（用现有 plant_wall_barrier）
    - `repeater`：费用 200，双发射手
    - `lobber`：费用 150，投手
  - **波次**（3 波）：
    - Wave 1（t=20s）：3 个基础行尸，分散在 3 个车道
    - Wave 2（t=45s）：5 个混合（3 基础 + 2 快速）
    - Wave 3（t=75s）：8 个混合（4 基础 + 2 快速 + 2 铁桶），标记 `is_final_wave`
  - **经济**：initial_sun=50, sky_drop_interval=8s
  - **棋盘**：5 车道 x 9 格，全部 ground 类型
  - **割草机**：每车道 1 个
  - **胜负条件**：全波清除 = 胜利，僵尸越过 defeat_line_x = 失败
  - **天降阳光**：每 8 秒一次，随机车道
- **依赖**：所有现有模板资源
- **验证**：加载后可正常运行

#### Issue 4.2：向日葵产阳光模板

- **产出**：`data/combat/entity_templates/plants/plant_sunflower.tres`
- **内容**：
  - 复用现有模板结构
  - 不设 attack trigger，而是设 sun_production_interval = 10s
  - `BattleEconomyState._process_plant_sun_production()` 已实现此逻辑（检查 `sun_production_interval` 在 entity values 中）
- **依赖**：`BattleEconomyState`（已完成）
- **验证**：向日葵每 10 秒产生一个阳光

#### Issue 4.3：DemoBattleScene 关卡场景

- **产出**：`scenes/demo/demo_level.tscn`
- **内容**：
  - 继承或复用 `BattleManager` 结构
  - 挂载 `BoardVisual`、`CardBar`、`SunCounter`、`WaveIndicator`、`InputBridge`
  - 背景色为草绿色
  - 左侧画一个小房子示意（纯 _draw 矩形）
  - 右侧为僵尸出生区
  - 尺寸 960x540，与视口一致
- **依赖**：Epic 1-3 全部 Issue
- **验证**：场景可运行、可交互

#### Issue 4.4：胜负画面

- **产出**：`scripts/demo/battle_result_overlay.gd`（CanvasLayer）
- **内容**：
  - 监听 `battle.victory` -> 显示 "Victory!" 绿色文字 + "Press R to Restart"
  - 监听 `battle.defeat` -> 显示 "Defeat!" 红色文字 + "Press R to Restart"
  - 半透明黑色背景遮罩
  - 按 R 重置战斗
- **依赖**：`BattleFlowState`（已完成）
- **验证**：胜利/失败时画面正确显示

#### Issue 4.5：DemoHub 入口

- **产出**：修改 `scripts/main/showcase_hub.gd`
- **内容**：
  - 在现有 showcase 卡片列表最前面加一张 "MVP Demo" 卡片
  - 点击后加载 `scenes/demo/demo_level.tscn`
- **依赖**：Issue 4.3
- **验证**：从主菜单可进入 Demo

---

## 四、实现顺序

```
Phase A（骨架可视化，不涉及输入）：
  Issue 1.2 BoardCellVisual
  Issue 1.1 BoardVisual
  Issue 2.1 CardBar
  Issue 2.2 SunCounter
  Issue 2.3 WaveIndicator

Phase B（输入接入）：
  Issue 3.1 SunCollectible 点击收集
  Issue 3.3 天降阳光视觉
  Issue 3.2 InputBridge
  Issue 1.3 格子-放置桥接

Phase C（关卡内容）：
  Issue 4.2 向日葵模板
  Issue 4.1 Demo 关卡 Scenario
  Issue 4.3 DemoBattleScene
  Issue 4.4 胜负画面
  Issue 4.5 DemoHub 入口
```

### 预估工作量

| Phase | Issue 数 | 预估（人时） | 说明 |
|---|---|---|---|
| Phase A | 5 | 4-6h | 纯 UI 绘制 + 事件监听，不涉及逻辑 |
| Phase B | 4 | 4-6h | 输入桥接，核心交互闭环 |
| Phase C | 5 | 3-5h | 关卡配置 + 场景组装 |
| **合计** | **14** | **11-17h** | |

---

## 五、新增文件清单

```
scripts/demo/
├── board_visual.gd          # Issue 1.1
├── board_cell_visual.gd     # Issue 1.2
├── card_bar.gd              # Issue 2.1
├── sun_counter.gd           # Issue 2.2
├── wave_indicator.gd        # Issue 2.3
├── input_bridge.gd          # Issue 3.2
└── battle_result_overlay.gd # Issue 4.4

scenes/demo/
└── demo_level.tscn          # Issue 4.3

data/combat/entity_templates/plants/
└── plant_sunflower.tres     # Issue 4.2

data/combat/validation_scenes/
└── demo_level.tres          # Issue 4.1（BattleScenario 资源）
```

修改文件：
```
scripts/battle/sun_collectible.gd       # Issue 3.1 添加点击收集
scripts/main/showcase_hub.gd            # Issue 4.5 添加 Demo 入口
```

---

## 六、不做什么

| 不做 | 理由 |
|---|---|
| 精灵/动画系统 | `_draw()` 原始图形足够表达玩法 |
| 音效/BGM | 不阻塞闭环 |
| 拖拽放置 | 点击选中 + 点击放置已足够 |
| 铲子移除 | 先做减法 |
| 多关卡/选关 | Demo 只需一关 |
| 存档 | 外循环 |
| 花盆/水塘/屋顶 | 限定草地地形 |
| 墓碑/梯子/花篮 | 后续内容 |
| Pause 菜单 | 按 R 重开 / Esc 返回即可 |

---

## 七、验收标准

Demo 完成的最低标准：

1. **可进入**：从主菜单点击 "MVP Demo" 进入关卡
2. **可见棋盘**：5x9 格子清晰可见
3. **可见卡片**：顶部卡片栏显示 5 张卡片，费用和冷却可见
4. **可见阳光**：天降阳光可见、可点击收集
5. **可放置**：选中卡片 -> 点击格子 -> 植物出现
6. **可战斗**：植物自动发射投射体，僵尸受击死亡
7. **有波次**：僵尸按 3 波时间表从右侧进入
8. **有割草机**：僵尸突破时割草机触发扫杀
9. **有结局**：全清 = 胜利画面，突破 = 失败画面
10. **可重来**：按 R 重新开始

---

## 八、与现有架构的关系

```
                       ┌──────────────┐
                       │  Demo Scene  │  scenes/demo/demo_level.tscn
                       │  (BattleMgr) │
                       └──────┬───────┘
                              │ 创建并挂载
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
      ┌───────────┐   ┌───────────┐   ┌──────────────┐
      │ BoardVisual│   │  CardBar  │   │  InputBridge │
      │ (Node2D)  │   │ (Control) │   │   (Node)     │
      └─────┬─────┘   └─────┬─────┘   └──────┬───────┘
            │               │                │
            │  cell_clicked │ card_selected  │ 组合信号
            │               │                │
            └───────┬───────┘                │
                    │                        │
                    ▼                        ▼
            ┌──────────────────────────────────┐
            │     BattleCardState.play_card()  │  已有完整链路
            │  -> validate -> spend -> spawn   │
            │  -> commit -> cooldown           │
            └──────────────────────────────────┘
```

Demo 层（`scripts/demo/`）**只负责渲染和输入**，所有逻辑仍由已有的 Battle 子系统处理。这保证了：

- 不反向污染已冻结的引擎核协议
- 不重写 BattleManager 的职责
- Demo 层可以随时被更好的 UI 替换，不影响引擎

---

## 九、向日葵产阳光的接入方式

当前 `BattleEconomyState._process_plant_sun_production()` 的实现逻辑：

1. 遍历所有 `combat_entities`
2. 检查 entity 的 `values` 字典中是否有 `sun_production_interval`
3. 如果有且冷却已过，调用 `spawn_sun()` 产生阳光

因此，向日葵只需要一个 `EntityTemplate`，其 `default_params` 包含：

```gdscript
sun_production_interval = 10.0
sun_production_value = 25
```

无需新的触发器或效果，无需修改引擎代码。

---

## 十、与路线图的关系

此 MVP Demo 属于**第四阶段的收尾交付物**，它不改变任何已冻结协议，只补齐"引擎 -> 可玩 Demo"的最后一英里。

完成后，项目状态将从：

> "引擎和玩法子系统已完成，但只能通过验证场景自动驱动"

升级为：

> "引擎 + 玩法 + 玩家交互闭环已完成，有一个可操作的单关卡 Demo"

这为后续第五阶段（错误技样例、扩展工具、外循环）提供了真实的体验验证基础。
