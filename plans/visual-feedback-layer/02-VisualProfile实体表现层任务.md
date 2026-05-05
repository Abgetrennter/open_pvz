# 02-VisualProfile 实体表现层任务

## 文档定位

本文拆解 Phase 2：实体持续表现。VisualProfile 用于描述实体 actor 的长期视觉状态，VisualActorComponent 负责把实体状态解释为显示、动画、overlay 和 damage stage。

## 背景与目标

Open PVZ 当前实体根节点偏规则与调试，`ProjectileRoot._draw()` 也仍是 fallback 占位表现。VisualProfile 的目标是提供可选 actor 层，让正式内容逐步拥有可替换、可扩展的表现外壳。

目标：

- 通过 `VisualProfileDef` 描述 actor scene 和状态映射。
- 通过 `VisualActorComponent` 管理实体显示。
- 让 `EntityFactory` 可选挂载 actor，不影响无 profile 实体。
- 将血量阶段、状态 overlay、投射体影子等表现从规则组件中解耦。

## 非目标

- 不重写实体规则根节点。
- 不移除现有 fallback `_draw()`。
- 不在本阶段实现完整 AnimationTree。
- 不把 `HealthComponent` 改成视觉组件。
- 不强制所有 archetype 立刻配置 profile。

## 前置阅读

- [00-总览与边界.md](./00-总览与边界.md)
- [01-VisualCue事件反馈层任务.md](./01-VisualCue事件反馈层任务.md)
- [../../wiki/01-overview/00-架构总览.md](../../wiki/01-overview/00-架构总览.md)
- [../../wiki/02-runtime-protocol/08-连续行为模型.md](../../wiki/02-runtime-protocol/08-连续行为模型.md)

## 任务清单

### VF-PROFILE-01：新增 `VisualProfileDef`

最小字段固定为：

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

字段说明：

- `actor_scene`：实例化后作为实体表现子树。
- `animation_map`：通用动作名到动画名映射。
- `state_animation_map`：`EntityState.status` 或 `state_stage` 到动画名映射。
- `status_visual_map`：状态效果到 overlay/染色/材质策略映射。
- `damage_stage_defs`：血量阶段表现列表。
- `shadow_policy`：是否生成影子、影子跟随谁。
- `z_policy`：默认视觉层级配置。

### VF-PROFILE-02：新增 `VisualProfileRegistry`

要求：

- 继承 `RegistryBase`。
- register kind 为 `visual_profiles`。
- 内置 `core.placeholder_*` profile 可作为占位。
- 找不到 profile 时返回 null，不产生 fatal。

### VF-PROFILE-03：新增 `VisualActorComponent`

职责：

- 持有 owner 引用。
- 实例化并挂载 `actor_scene`。
- 读取 owner 的 `EntityState`。
- 订阅必要事件，例如 `entity.damaged`、`entity.died`、`entity.status_removed`。
- 执行动画切换、闪白、状态 overlay、damage stage。

要求：

- 只读 owner 状态和事件。
- 不调用规则方法修改血量、状态或目标。
- 可被关闭或卸载。

### VF-PROFILE-04：让 `EntityFactory` 可选挂载 visual actor

要求：

- 仅当 runtime spec 或 archetype 提供 visual profile 时挂载。
- 无 profile 时保持现有行为。
- profile 加载失败时记录 warning 并继续创建实体。

### VF-PROFILE-05：实现状态到动画映射

输入：

- `entity_state.status`
- `entity_state.values.state_stage`
- `entity_kind`
- `team`

输出：

- actor scene 内 `AnimationPlayer` 播放对应动画。

v1 必须支持：

- `idle`
- `moving`
- `attacking`
- `flying`
- `consumed`
- `expired`
- `dead`

### VF-PROFILE-06：实现血量阶段视觉变化

借鉴 `PVZ-Godot-Dream` 的 `ResourceBodyChange`：

- 改贴图。
- 显示节点。
- 隐藏节点。
- 激活掉落节点或生成掉落 FX request。

要求：

- 由 `VisualActorComponent` 根据 `health_ratio` 或 `entity.damaged` 判断。
- 不能由 `HealthComponent` 直接操作表现节点。
- damage stage 只影响视觉。

### VF-PROFILE-07：实现投射体 actor 与 fallback 兼容

要求：

- 有 projectile profile 时 actor 本体跟随 `projected_position`。
- 影子跟随 `ground_position`。
- 无 profile 时保留 `ProjectileRoot._draw()`。
- actor 不能参与命中判定。

## 实现说明

### Actor scene 约定

推荐 actor scene 结构：

```text
VisualActorRoot (Node2D)
├── Body
├── Shadow
├── Overlays
├── Sockets
└── AnimationPlayer
```

`Sockets` 用于后续 attachment：

```text
Sockets/Muzzle
Sockets/Head
Sockets/HitCenter
Sockets/ShadowAnchor
```

### Damage stage 规则

`damage_stage_defs` 建议按从高血量到低血量排序：

```text
threshold_ratio
sprite_changes
show_nodes
hide_nodes
spawn_fx
```

每个 stage 只执行一次，除非 actor 重建。

### 状态 overlay 合成

同一 actor 可能同时有多个状态。合成顺序建议：

```text
base_color -> hit_flash -> status_overlay -> special_overlay
```

v1 可以只实现 `modulate` 乘法合成，后续再扩展 shader。

## 推荐实现顺序

1. 定义 `VisualProfileDef` 和 registry。
2. 实现空 actor / placeholder actor。
3. 实现 `VisualActorComponent` 挂载和卸载。
4. 接入 `EntityFactory` 可选挂载。
5. 实现状态到动画映射。
6. 实现受击闪白和 damage stage。
7. 实现 projectile actor 本体/影子分离。

## 验收标准

- 无 profile 的实体仍可显示。
- 有 profile 的实体能根据 `entity_state.status` 播放基础动画。
- `entity.damaged` 后可触发闪白，不影响血量逻辑。
- 投射体本体使用 `projected_position`，影子使用 `ground_position`。
- actor scene 加载失败不影响实体创建。

## 验证要求

建议验证场景：

- `visual_actor_profile_smoke`
- `visual_projectile_projection_smoke`

验证重点：

- 运行时有 actor 节点被挂载。
- 状态变化触发动画 request。
- damage stage action request 数量符合预期。
- projectile 影子位置不等同于高空本体位置。

## 风险与边界

- 不要让 actor 节点承担 hitbox 或 movement。
- 不要让 animation call track 直接调用规则方法。
- 不要强制迁移所有实体；profile 必须是可选增强。
