# Open PVZ 视觉反馈层设计与路线图

## Summary

新增“视觉反馈层”作为规则引擎之外的正交表现层，核心定位是：**规则层产出事实，视觉层解释事实**。视觉反馈不得改变伤害、命中、目标选择、状态持续时间或 Effect 执行结果。

设计吸收两类参考：

- `de-pvz`：统一效果系统、显式渲染排序、Reanimation/Particle/Attachment 分离。
- `PVZ-Godot-Dream`：Godot `AnimationPlayer` 资产、FX 场景、`BodyCharacter` 状态染色、`ResourceBodyChange` 血量阶段表现。

目标架构拆成三块：

```text
EventBus / EntityState / ProjectileMoveResult
        ↓
VisualFeedbackHost
        ↓
VisualActorComponent / VisualCueRunner / VisualStageLayerService
        ↓
AnimationPlayer / Sprite2D / GPUParticles2D / AudioStreamPlayer / CanvasLayer
```

## Design

### 1. VisualActorComponent：实体持续表现

用于实体长期可见状态：

- idle / walk / attack / death 动画。
- 受击闪白、冰冻、魅惑、睡眠、灰烬等状态 overlay。
- 血量阶段贴图变化，例如坚果裂纹、僵尸掉手、掉头、防具破损。
- attachment/socket，例如头部、武器、盾牌、拖尾粒子跟随局部节点。
- 投射体本体、影子、拖尾的持续表现。

新增 `VisualProfileDef`，由 `CombatArchetype`、`ProjectileTemplate` 或 `RuntimeSpec` 可选引用。没有 profile 时使用当前 fallback 绘制逻辑，避免阻塞现有验证。

### 2. VisualCueRunner：事件型一次性反馈

用于短生命周期反馈：

- `projectile.spawned`：发射音效、枪口 FX、拖尾初始化。
- `projectile.hit`：命中特效、splat 音效、目标闪白。
- `projectile.expired`：落地、消散、水花、撞击空地。
- `entity.damaged`：受击 flash、护甲命中音效。
- `entity.died`：死亡动画、爆炸、灰烬、掉落部件。
- `placement.accepted`：种植 FX、水上种植 FX、种植音效。
- `entity.status_applied/status_removed`：冰冻、魅惑、睡眠等状态表现。

新增 `VisualCueDef`，按事件名和过滤条件匹配，执行一组内置 `VisualAction`。v1 不开放任意脚本 action，优先保证 data-only 扩展安全。

### 3. VisualStageLayerService：战场层级与环境表现

统一处理：

- 背景、雾、雨、泳池、屋顶、冰道、全屏闪光。
- lane-based z_index 排序。
- 投射体 `ground_position` 与 `projected_position` 的本体/影子分层。
- UI、临时预览、全屏特效的 CanvasLayer 归属。

采用原版 `MakeRenderOrder(layer, row, offset)` 思路，落地为 Godot `z_index`：

```text
z_index = layer_base + lane_id * row_stride + local_offset
```

默认 `row_stride = 100`，层级从低到高为：

```text
ground → shadow → field_object → plant → zombie → projectile → world_fx → fog/weather → preview → screen_fx → ui
```

## Implementation Roadmap

### Phase 1：最小事件反馈层

新增 `VisualFeedbackHost`，作为 battle 侧节点或 Autoload 订阅核心事件。

实现内置 action：

- `spawn_fx`
- `play_audio`
- `flash_actor`
- `play_actor_animation`
- `attach_fx`
- `screen_overlay`

新增资源与注册表：

- `VisualCueDef`
- `VisualFxDef`
- `AudioCueDef`
- `VisualCueRegistry`
- `VisualFxRegistry`
- `AudioCueRegistry`

所有 registry 继承 `RegistryBase`，扩展包 register kind 暂定：

```text
visual_cues
visual_fx
audio_cues
```

v1 内置 cue：

- 豌豆/普通 projectile 命中。
- projectile 过期。
- entity 受击闪白。
- entity 死亡淡出。
- 种植成功。
- 爆炸类全屏或局部反馈。

### Phase 2：实体 VisualProfile

新增 `VisualProfileDef` 和 `VisualProfileRegistry`。

`VisualProfileDef` 最少包含：

```text
id
actor_scene
animation_map
state_animation_map
status_visual_map
damage_stage_defs
shadow_policy
z_policy
```

`EntityFactory` 在实例化实体后，如果 archetype/runtime spec 有 visual profile，则挂载 `VisualActorComponent`。组件只读 owner 的 `EntityState` 和事件，不直接参与规则逻辑。

迁移顺序：

1. 植物/僵尸基础 idle actor。
2. 投射体 actor，替代 `ProjectileRoot._draw()` 的正式表现。
3. 血量阶段 visual damage stage。
4. 状态 overlay。

### Phase 3：层级与环境系统

实现 `VisualStageLayerService`：

- battle 初始化时读取 battlefield/mode 视觉 preset。
- 提供 `resolve_z_index(entity_kind, lane_id, visual_layer, local_offset)`。
- 统一投射体本体与影子定位。
- 支持 fog/weather/screen_fx 的 CanvasLayer 宿主。

这一阶段对齐原版 `Board::DrawGameObjects()` 的收益：排序规则集中，避免每个实体脚本自行猜 `z_index`。

### Phase 4：扩展包与高阶表现

开放 data-only 视觉扩展：

- 资源包可新增 actor scene、FX scene、audio cue、visual cue。
- 禁止覆盖 `core.*`。
- 重复 id 拒绝并记录 `protocol.issue`。
- 视觉脚本 action 如确需开放，单独走 `trusted_runtime`，不进入 v1。

补充 attachment/socket：

- actor scene 约定 `Sockets` 节点。
- cue action 可把 FX 挂到 `socket_id`。
- attachment 生命周期由视觉层管理，随 owner 释放自动清理。

## Test Plan

验证分三类：

- Registry smoke：所有 visual registry 初始化无 `protocol.issue`。
- Cue smoke：触发 `projectile.hit/entity.damaged/entity.died/placement.accepted` 后，记录到 debug 的 visual action request 数量符合预期。
- Guardrail：重复 id、`core.*` 覆盖、data-only 包注册 runtime action script 均被拒绝。

现有战斗验证默认不依赖像素结果。视觉失败不得导致规则验证失败，除非测试目标明确是 visual smoke/guardrail。

手动展示场景：

- 普通豌豆命中僵尸。
- 抛物线投射体本体和影子分离。
- 僵尸血量阶段破损。
- 爆炸死亡 + screen overlay。
- 雾/雨/泳池环境层级不遮挡 UI。

## Assumptions

- 视觉层不作为第 11 个 Mechanic family；它是规则事实的解释层。
- v1 优先 data-only 扩展，不开放任意视觉脚本。
- 现有 `DebugViewComponent` 与 `ProjectileRoot._draw()` 保留为 fallback/debug 表现。
- 视觉随机默认不影响规则确定性；如需要回放一致，可用 `event_id/chain_id` 派生 visual seed。
- 不追求原版一比一复刻，优先保证 Open PVZ 的资源化、注册化、可关闭、可验证。
