# UI 框架层设计方案

> **文档性质**：设计文档（Design Document）
> **所属圈层**：表现、验证与治理层
> **关联系统**：战斗玩法层、输入交互层
> **状态**：待审批

---

## Context

Open PVZ 的规则引擎骨架（事件 → 触发 → 效果 → 执行链）已成熟，战斗子系统（经济、棋盘、卡片、波次、流程）均有状态类实现。当前存在一套 `scripts/demo/` 下的原型 UI（CardBar、SunCounter、BoardVisual、WaveIndicator、InputBridge、BattleResultOverlay），功能基本可用但缺乏框架层抽象——无基类、无生命周期管理、无统一状态绑定模式。

本方案的目标：**将 demo 原型提升为可组合、可测试、与引擎解耦的 UI 框架层**，作为当前阶段的**支撑层规范化方案**，为后续内容开发和表现层扩展奠定基础。

**不包含**：具体视觉美化、素材集成、动画资源、音频 UI 反馈。

---

## 1. 架构定位

### 1.1 在五层模型中的位置

```
引擎核（已完成）→ 战斗玩法层（已完成）→ 内容表达层（进行中）
                                          ↑
                              UI 框架层（本方案）  ← 表现、验证与治理层
                                          ↓
                              输入交互层（InputRouter，已有设计）
```

UI 框架层位于**战斗玩法层之上、输入交互层之下**。它：
- **观察**战斗状态（通过 EventBus 订阅）
- **呈现**战斗信息（通过 Control 节点树）
- **转发**用户操作（通过信号 → InputRouter）
- **不驱动**任何规则逻辑

### 1.2 核心原则

| 原则 | 含义 |
|------|------|
| 单向数据流 | 战斗状态 → EventBus → UI 面板 → 叶子控件。UI 永远不直接修改战斗状态 |
| UI 可选 | BattleManager 不依赖任何 UI。验证场景不创建 UI 也能正常运行 |
| 中介者模式 | 每个面板（CardBar、SunCounter）充当中介者，订阅 EventBus 并驱动子控件。叶子控件不订阅 EventBus |
| 无 UIModel 层 | 战斗子系统即 Model，EventBus 即观察通道。不引入额外的状态缓存层 |
| 资源驱动 | 面板布局参数、交互配置通过 `.tres` Resource 定义 |

### 1.3 关键架构决策

**ADR-UI-001：中介者而非直接订阅**
- 每个逻辑面板（如 CardBar）订阅 EventBus，再驱动内部子控件
- 50+ 叶子控件直接订阅 EventBus 会导致事件流不可追踪
- 中介者可批量更新、防抖、过滤

**ADR-UI-002：不设 UIModel 层**
- BattleEconomyState、BattleCardState 等已是 Model
- 面板内部可缓存渲染所需值（如 `_current_sun`），但这不是独立 Model 层

**ADR-UI-003：UI 通过 overlay 模式接入**
- BattleManager 不引用任何 UI 类型
- UI 由场景编排层（DemoBattleScene 或未来的 BattleScene）创建和接线
- 无 UI 时 BattleManager 完全可用

---

## 2. CanvasLayer 分层策略

视口 960x540。

| Layer | 名称 | 用途 | 典型内容 |
|-------|------|------|----------|
| -1 | BackgroundLayer | 战斗背景 | 棋盘背景渲染（未来） |
| 0 | （默认世界空间） | 游戏对象 | BattleManager、实体、BoardOverlay、收集物 |
| 10 | DebugLayer | 调试信息 | DebugOverlay（已有） |
| 50 | HUDLayer | 战斗 HUD | BattleHUD 容器 |
| 80 | PopupLayer | 弹出层 | 暂停菜单、确认对话框（未来） |
| 100 | ScreenLayer | 全屏覆盖 | PhaseScreen（胜利/失败） |

### 场景节点树结构

```
BattleScene (Node2D)
├── BattleManager (Node2D)               -- 不含任何 UI 代码
│   ├── RuntimeEntities/
│   ├── BattleBoardState
│   ├── BattleCardState
│   ├── BattleEconomyState
│   ├── BattleFlowState
│   └── WaveRunner
├── BoardOverlay (Node2D, 世界空间)       -- 棋盘格渲染
├── CanvasLayer(layer=50) "HUDLayer"
│   └── BattleHUD (Control, FULL_RECT, MOUSE_FILTER_IGNORE)
│       ├── SunCounter
│       ├── CardBar
│       ├── WaveProgress
│       └── (未来: ShovelButton, PauseButton)
├── CanvasLayer(layer=100) "ScreenLayer"
│   └── PhaseScreen (CanvasLayer)
└── InputRouter (Node)                   -- 场景级输入管理
```

**BoardOverlay 定位**：世界空间 Node2D，与 BattleManager、实体处于同一坐标系。原因：
- `BattleBoardState.get_slot_world_position()` 返回世界坐标，BoardOverlay 直接消费，零转换开销
- BoardCellVisual 用 Area2D 碰撞检测，与世界空间实体天然匹配
- 与现有 `demo/board_visual.gd` 模式一致
- 未来 Camera 移动/缩放时，世界空间节点自动跟随

BattleHUD 根节点使用 `MOUSE_FILTER_IGNORE`，点击事件穿透到世界空间，仅子控件拦截。

---

## 3. 核心抽象

### 3.1 UIPanelBase — HUD 面板基类

```gdscript
# scripts/ui/ui_panel_base.gd
class_name UIPanelBase
extends Control

var _battle: Node = null
var _subscriptions: Array[Dictionary] = []

func panel_setup(battle: Node, scenario: Resource) -> void:
    _battle = battle
    # 子类重写，订阅事件

func panel_teardown() -> void:
    for sub in _subscriptions:
        EventBus.unsubscribe(sub.event_name, sub.callback)
    _subscriptions.clear()

func _track_subscribe(event_name: StringName, callback: Callable) -> void:
    EventBus.subscribe(event_name, callback)
    _subscriptions.append({"event_name": event_name, "callback": callback})
```

职责：
- 统一的 setup/teardown 生命周期
- 跟踪 EventBus 订阅，teardown 时自动清理
- 提供 `_battle` 引用用于状态查询

### 3.2 UIScreenBase — 全屏覆盖基类

```gdscript
# scripts/ui/ui_screen_base.gd
class_name UIScreenBase
extends CanvasLayer

var _battle: Node = null

func screen_setup(battle: Node) -> void:
    _battle = battle

func screen_teardown() -> void:
    pass
```

现有 `BattleResultOverlay` 已遵循此模式（extends CanvasLayer, layer=100）。

### 3.3 BattleHUD — HUD 容器与生命周期管理

```gdscript
# scripts/ui/battle_hud.gd
class_name BattleHUD
extends Control

func setup(battle: Node, scenario: Resource) -> void:
    for child in get_children():
        if child.has_method("panel_setup"):
            child.panel_setup(battle, scenario)

func teardown() -> void:
    for child in get_children():
        if child.has_method("panel_teardown"):
            child.panel_teardown()
```

不使用参考项目的 MainGameSubManager 模式。原因：
- Open PVZ 已有 BattleSubsystemHost 作为协调机制
- 显式 setup/teardown 调用比 owner 引用更透明、更可测试
- UI 不是战斗子系统，不应混入子系统体系

---

## 4. 状态绑定模式

### 4.1 "拉取初值 + 订阅增量"模式

面板创建时需要当前状态（不仅是未来事件）：

```gdscript
func panel_setup(battle: Node, scenario: Resource) -> void:
    super.panel_setup(battle, scenario)
    _current_sun = int(battle.get_current_sun())        # 拉取初值
    _track_subscribe(&"resource.changed", _on_resource_changed)  # 订阅增量
```

### 4.2 事件 → 面板 → 叶子控件 流程

```
EventBus: resource.changed {after: 75, delta: 25}
  │
  ▼ SunCounter._on_resource_changed(event_data)
  │  读取 event_data.core["after"]
  │  更新 _label.text
  │  触发 scale tween 动画
  ▼
（叶控件更新完毕，无进一步传播）
```

含多子控件面板（CardBar）：

```
EventBus: resource.changed {after: 75}
  │
  ▼ CardBar._on_resource_changed(event_data)
  │  _current_sun = event_data.core.after
  │  _refresh_affordability()
  │  │  遍历 _card_slots，更新费用标签颜色
  │  ▼
（叶控件通过中介者直接操作更新）
```

### 4.3 可订阅的战斗事件清单

| 事件名 | 来源子系统 | 消费面板 |
|--------|-----------|---------|
| `resource.changed` | BattleEconomyState | SunCounter, CardBar |
| `sun.spawned` | BattleEconomyState | SunCounter（未来动画） |
| `sun.collected` | BattleEconomyState | SunCounter（飞入动画） |
| `card.cooldown_started` | BattleCardState | CardBar |
| `card.play_rejected` | BattleCardState | CardBar, InputRouter |
| `card.play_requested` | BattleCardState | CardBar |
| `placement.accepted` | BattleBoardState | BoardOverlay |
| `placement.rejected` | BattleBoardState | BoardOverlay |
| `entity.died` | HealthComponent | BoardOverlay |
| `wave.started` | WaveRunner | WaveProgress |
| `wave.completed` | WaveRunner | WaveProgress |
| `battle.phase_changed` | BattleFlowState | PhaseScreen |
| `battle.victory` | BattleFlowState | PhaseScreen |
| `battle.defeat` | BattleFlowState | PhaseScreen |

---

## 5. 输入桥接

### 5.1 UI → InputRouter（用户操作翻译为语义动作）

```
CardBar.card_selected(card_id)       → InputRouter.request_card_select(card_id)
BoardOverlay.cell_clicked(lane, slot) → InputRouter.request_cell_click(lane, slot)
SunCollectibleVisual.clicked         → BattleEconomyState.collect_sun()（直接调用）
ESC 键 (_unhandled_input)            → InputRouter.request_cancel()
```

### 5.2 InputRouter → UI（反馈信号，UI 内部关注）

```
InputRouter.card_selected(card_id)   → CardBar 高亮选中卡片
InputRouter.card_deselected          → CardBar 清除高亮
InputRouter.cell_hovered(lane, slot) → BoardOverlay 高亮格子
InputRouter.cell_unhovered(lane,slot) → BoardOverlay 清除高亮
```

反馈信号使用**直接信号**（非 EventBus），纯 UI 内部关注点。

### 5.3 键盘快捷键

通过 InputRouter 统一管理：
- `1-9`：选择对应位置卡片
- `S`：铲子模式（未来）
- `ESC`：取消选择
- `R`：重启战斗（场景级处理，不经过 InputRouter）

---

## 6. 组件规格

### 6.1 CardBar（迁移自 `scripts/demo/card_bar.gd`）

| 项目 | 说明 |
|------|------|
| 基类 | UIPanelBase |
| 消费事件 | `resource.changed`, `card.cooldown_started`, `card.play_rejected`, `card.play_requested` |
| 发射信号 | `card_selected(card_id)`, `card_deselected` |
| 状态查询 | `BattleCardState.hand_order`, `_card_defs`, `_cooldown_ready_times` |
| 子控件 | PanelContainer × N（卡片槽），每槽含 ColorRect + Label(名称) + Label(费用) + ColorRect(冷却覆盖) |
| 迁移要点 | setup() → panel_setup()；直接订阅 → _track_subscribe()；新增 _battle 引用 |

### 6.2 SunCounter（迁移自 `scripts/demo/sun_counter.gd`）

| 项目 | 说明 |
|------|------|
| 基类 | UIPanelBase |
| 消费事件 | `resource.changed` |
| 子控件 | HBoxContainer（图标 ColorRect + Label） |
| 动画 | 数值变化时 scale tween |

### 6.3 BoardOverlay（迁移自 `scripts/demo/board_visual.gd`）

| 项目 | 说明 |
|------|------|
| 基类 | Node2D（世界空间，不在 CanvasLayer 内） |
| 消费事件 | `placement.accepted`, `placement.rejected`, `entity.died` |
| 发射信号 | `cell_clicked(lane_id, slot_index)` |
| 子控件 | BoardCellVisual × (lane × slot)，Area2D 碰撞检测 |
| 状态 | normal / hover_valid / occupied / invalid |
| 迁移要点 | 保留 setup() 接口（世界空间面板不走 panel_setup），增加 _track_subscribe() |

### 6.4 WaveProgress（迁移自 `scripts/demo/wave_indicator.gd`）

| 项目 | 说明 |
|------|------|
| 基类 | UIPanelBase |
| 消费事件 | `wave.started`, `wave.completed` |
| 子控件 | Label（文本），未来增加 ProgressBar |
| 特殊行为 | 最终波次变色 + scale 脉冲 |

### 6.5 PhaseScreen（迁移自 `scripts/demo/battle_result_overlay.gd`）

| 项目 | 说明 |
|------|------|
| 基类 | UIScreenBase |
| 消费事件 | `battle.victory`, `battle.defeat`, `battle.phase_changed` |
| 子控件 | ColorRect(半透明覆盖) + Label(结果文字) |
| 扩展 | 增加 preparing 阶段显示（未来） |

---

## 7. 生命周期管理

### 7.1 战斗会话生命周期

```
1. 场景加载
2. 创建 BattleManager，加入场景树
3. BattleManager._ready() → reset_battle() → 子系统创建
4. 创建 UI 组件：
   a. 创建 CanvasLayer（HUDLayer, ScreenLayer）
   b. 创建 BattleHUD，添加面板（SunCounter, CardBar, WaveProgress）
   c. 创建 BoardOverlay（世界空间）
   d. 创建 PhaseScreen（ScreenLayer）
   e. 创建 InputRouter
   f. 调用 panel_setup(battle, scenario) / screen_setup(battle)
   g. 连接 UI 信号到 InputRouter
5. 游戏循环运行，UI 观察事件并更新
6. 战斗结束：
   a. PhaseScreen 显示结果
   b. InputRouter 进入 DISABLED 模式
   c. 玩家按 R → 重启
7. 场景退出：
   a. panel_teardown()（取消 EventBus 订阅）
   b. InputRouter 清理
```

### 7.2 重启流程

```
1. panel_teardown()  — 取消所有 EventBus 订阅
2. BattleManager.reset_battle()  — 清除 EventBus，重建子系统
3. panel_setup(battle, new_scenario)  — 重新订阅，拉取初值
```

**关键顺序**：先 teardown UI，再 reset BattleManager（因为 reset 会调用 EventBus.clear()）。

### 7.3 内存安全

- 所有 UI 节点是场景根的子节点，场景切换时自动释放
- Tween 动画在 teardown 中需要 kill，防止悬挂回调
- EventBus 订阅必须在 teardown 中显式取消

---

## 8. 文件组织

```
scripts/
├── ui/                              # 新增：UI 框架层
│   ├── ui_panel_base.gd             # HUD 面板基类 (Control)
│   ├── ui_screen_base.gd            # 全屏覆盖基类 (CanvasLayer)
│   ├── battle_hud.gd                # HUD 容器与生命周期
│   ├── panels/                      # 具体面板
│   │   ├── card_bar.gd              # 卡片选择栏
│   │   ├── sun_counter.gd           # 阳光计数器
│   │   ├── wave_progress.gd         # 波次进度
│   │   └── board_overlay.gd         # 棋盘渲染（世界空间）
│   └── screens/                     # 全屏覆盖
│       └── phase_screen.gd          # 阶段过渡屏
├── demo/                            # 现有原型（保留，不破坏）
│   ├── demo_battle_scene.gd
│   ├── card_bar.gd
│   ├── sun_counter.gd
│   ├── board_visual.gd
│   ├── wave_indicator.gd
│   ├── input_bridge.gd
│   ├── board_cell_visual.gd
│   └── battle_result_overlay.gd
```

**迁移策略**：demo/ 目录完整保留。新的 `scripts/ui/` 独立添加。未来 DemoBattleScene 可逐步切换到新框架，但不需要删除旧代码。

---

## 9. 实施阶段

### Phase 0：基础骨架（无视觉变化）

创建文件和基类：
- `scripts/ui/ui_panel_base.gd`
- `scripts/ui/ui_screen_base.gd`
- `scripts/ui/battle_hud.gd`

**验证**：新文件可实例化无报错，现有验证场景全部通过。

### Phase 1：迁移 SunCounter（最简单面板）

- `scripts/ui/panels/sun_counter.gd` 继承 UIPanelBase
- 从 demo/sun_counter.gd 迁移逻辑
- 通过 BattleHUD 接线

**验证**：Demo 场景用新 SunCounter 表现一致。

### Phase 2：迁移 WaveProgress

- `scripts/ui/panels/wave_progress.gd`
- 从 demo/wave_indicator.gd 迁移
- 增加进度条（total/complete）

**验证**：波次显示正确。

### Phase 3：迁移 CardBar（最复杂面板）

- `scripts/ui/panels/card_bar.gd`
- 多子控件、多事件订阅、信号发射
- 费用可购判断、冷却覆盖动画

**验证**：卡片选择、放置、冷却、可购性表现一致。

### Phase 4：迁移 BoardOverlay

- `scripts/ui/panels/board_overlay.gd`
- 世界空间渲染，分离背景与交互
- BoardCellVisual 可复用

**验证**：格网渲染、hover/occupied/invalid 状态正确。

### Phase 5：迁移 PhaseScreen

- `scripts/ui/screens/phase_screen.gd`
- 从 demo/battle_result_overlay.gd 迁移
- 增加 preparing 阶段显示

**验证**：胜利/失败画面正确显示。

### Phase 6：BattleHUD 编排集成

- 创建使用新框架的 DemoBattleScene 变体
- 所有面板通过 BattleHUD 统一管理

**验证**：新场景与现有 demo 功能等价。

### Phase 7：InputRouter 集成

- 替换 InputBridge 为 InputRouter
- CardBar/BoardOverlay 信号接入 InputRouter
- 键盘快捷键支持

**验证**：键盘操作（1-9, ESC）和鼠标操作均正常，现有验证场景不受影响。

### Phase 8：验证兼容性检查

- 运行全部 52 个验证场景
- 创建 `ui_framework_validation` 专用验证场景
- 确认 UI 可完全禁用

**验证**：全部场景通过，新场景验证 UI 生命周期。

---

## 10. 验证兼容性保障

### 10.1 现有场景为何安全

当前 52 个验证场景均使用编程驱动模式：
- 创建 BattleManager，加载 BattleScenario .tres
- 通过 `card_play_requests` 和 `resource_spend_requests` 驱动
- **不创建任何 UI 组件**
- 不依赖 InputBridge 或任何输入处理

### 10.2 保护措施

1. **纯增量添加** — `scripts/ui/` 不修改 `scripts/battle/`、`autoload/`、`scripts/core/` 中任何现有文件
2. **BattleManager 不变** — 唯一连接点是 `panel_setup(battle)` 参数
3. **订阅清理** — teardown 先于 EventBus.clear()
4. **验证关卡** — Phase 8 显式运行全部场景 + 创建 UI 专用场景

---

## 关键文件索引

| 文件 | 角色 |
|------|------|
| `scripts/demo/demo_battle_scene.gd` | 当前场景编排器，UI 接线参考 |
| `scripts/demo/card_bar.gd` | 最复杂 UI 组件，EventBus 订阅模式参考 |
| `scripts/demo/sun_counter.gd` | 最简单 UI 组件，状态绑定模式参考 |
| `scripts/demo/board_visual.gd` | 世界空间 UI 参考，BoardCellVisual 复用 |
| `scripts/demo/wave_indicator.gd` | 波次 UI 参考 |
| `scripts/demo/input_bridge.gd` | 输入桥接参考，将被 InputRouter 替代 |
| `scripts/demo/battle_result_overlay.gd` | 全屏覆盖参考 |
| `autoload/EventBus.gd` | 事件总线，UI 订阅/退订的契约 |
| `scripts/battle/battle_card_state.gd` | 卡片状态事件源 |
| `scripts/battle/battle_economy_state.gd` | 经济状态事件源 |
| `scripts/battle/battle_flow_state.gd` | 流程状态事件源 |
| `wiki/01-overview/34-Open PVZ 系统版图与规划分层.md` | 系统圈层定义 |
| `wiki/04-roadmap-reference/pvz-godot-dream/03-组件系统.md` | 参考项目组件架构 |
| `wiki/04-roadmap-reference/pvz-godot-dream/04-管理器与全局服务.md` | 参考项目管理器体系 |

---

## 相关文档

- [Open PVZ 系统版图与规划分层](../wiki/01-overview/34-Open%20PVZ%20系统版图与规划分层.md)
- [当前阶段与实现路线](../wiki/01-overview/23-当前阶段与实现路线.md)
- [开发路线图](../wiki/04-roadmap-reference/26-开发路线图.md)
- [参考实现-组件系统](../wiki/04-roadmap-reference/pvz-godot-dream/03-组件系统.md)
- [参考实现-管理器与全局服务](../wiki/04-roadmap-reference/pvz-godot-dream/04-管理器与全局服务.md)
