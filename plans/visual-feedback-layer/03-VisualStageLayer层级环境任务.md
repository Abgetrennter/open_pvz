# 03-VisualStageLayer 层级环境任务

## 文档定位

本文拆解 Phase 3：战场层级、环境表现和投射体本体/影子的统一排序。VisualStageLayerService 是视觉层的排序与环境入口。

## 背景与目标

原版 `de-pvz` 通过 `Board::DrawGameObjects()` 收集所有 RenderItem，再按 render order 排序绘制。Godot 版本需要把同类思想落到 `CanvasLayer` 与 `z_index`。

目标：

- 集中定义 lane-based `z_index`。
- 避免每个实体脚本自行猜层级。
- 支持 ground / shadow / entity / projectile / fx / fog / ui 分层。
- 支持 battlefield/mode visual preset。

## 非目标

- 不替换 Godot 渲染系统。
- 不实现完整场景编辑器。
- 不做像素级原版层级复刻。
- 不让层级服务参与命中判断。

## 前置阅读

- [00-总览与边界.md](./00-总览与边界.md)
- [02-VisualProfile实体表现层任务.md](./02-VisualProfile实体表现层任务.md)
- [../../wiki/02-runtime-protocol/08-连续行为模型.md](../../wiki/02-runtime-protocol/08-连续行为模型.md)

## 任务清单

### VF-LAYER-01：定义 `VisualLayerPolicy`

默认层级顺序固定为：

```text
ground
shadow
field_object
plant
zombie
projectile
world_fx
fog_weather
preview
screen_fx
ui
```

默认排序公式固定为：

```text
z_index = layer_base + lane_id * row_stride + local_offset
```

默认值：

```text
row_stride = 100
```

### VF-LAYER-02：实现 `VisualStageLayerService`

职责：

- 计算 z_index。
- 提供 layer host 节点。
- 接入 battle 初始化和清理。
- 给 VisualActorComponent / VisualActionRunner 提供层级查询。

推荐方法：

```text
resolve_z_index(entity_kind, lane_id, visual_layer, local_offset)
get_layer_host(visual_layer)
apply_visual_preset(preset)
```

### VF-LAYER-03：统一 lane-based z_index

要求：

- lane 内排序稳定。
- 不同 lane 按下方 lane 覆盖上方 lane 的常见 PVZ 视觉习惯。
- `lane_id = -1` 的对象使用安全默认层级。

### VF-LAYER-04：接入投射体本体/影子分层

要求：

- 本体使用 `projected_position`。
- 影子使用 `ground_position`。
- 高度不改变命中，只改变视觉投影。
- 抛物线 projectile 高飞时影子仍在地面层。

### VF-LAYER-05：接入 battlefield visual preset

visual preset 负责：

- 背景类型。
- 是否有泳池。
- 是否有雾。
- 是否有雨/暴风雨。
- 是否有屋顶倾斜。
- screen_fx 宿主配置。

v1 可先只读取并记录 preset，不要求完整背景系统。

### VF-LAYER-06：整理 fog/weather/screen_fx 宿主节点

建议宿主：

```text
BattleVisualRoot
├── GroundLayer
├── ShadowLayer
├── EntityLayer
├── ProjectileLayer
├── WorldFxLayer
├── FogWeatherLayer
├── PreviewLayer
├── ScreenFxLayer
└── UiLayer
```

## 实现说明

### 层级默认值建议

建议初始 `layer_base`：

```text
ground = 0
shadow = 1000
field_object = 2000
plant = 3000
zombie = 4000
projectile = 5000
world_fx = 6000
fog_weather = 7000
preview = 8000
screen_fx = 9000
ui = 10000
```

具体数值可在实现中调整，但必须集中定义，不散落在实体脚本。

### 与当前 BattleManager 绘制的关系

当前 `BattleManager._draw()` 可继续作为 debug/fallback 背景绘制。VisualStageLayerService 不应要求第一阶段删除它。

### 与 VisualCue 的关系

`spawn_fx` action 应请求 layer service 选择宿主和 z_index。没有 layer service 时，action 使用 owner 父节点作为 fallback。

## 推荐实现顺序

1. 定义 layer policy 常量或资源。
2. 建立 service 和 host 节点。
3. 让 VisualActionRunner 通过 service 放置 FX。
4. 让 VisualActorComponent 通过 service 设置 actor z_index。
5. 接入 projectile 本体/影子。
6. 接入 fog/weather/screen_fx host。

## 验收标准

- 同 lane 内植物、僵尸、投射体、FX 顺序稳定。
- 抛物线投射体高飞时本体和影子不混淆。
- fog/weather 不遮挡 UI。
- 全屏 FX 走独立 screen layer。
- 层级默认值只有一个集中定义来源。

## 验证要求

建议验证场景：

- `visual_projectile_projection_smoke`
- `visual_actor_profile_smoke`

验证重点：

- projectile 本体和影子节点存在且坐标来源不同。
- actor `z_index` 符合 lane + layer 公式。
- screen_fx host 层级高于 world_fx，低于或独立于 ui。

## 风险与边界

- 不要在每个实体脚本手写新的 z_index 公式。
- 不要把 roof / pool 的碰撞检测和视觉层级混在一起。
- 不要让视觉层排序改变 `BattleBoardState` 或命中策略。
