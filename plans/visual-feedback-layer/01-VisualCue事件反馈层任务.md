# 01-VisualCue 事件反馈层任务

## 文档定位

本文拆解 Phase 1：事件型一次性视觉反馈。VisualCue 是视觉反馈层的最小可用入口，用于把规则事件映射为短生命周期表现动作。

## 背景与目标

当前项目已有稳定事件链，`projectile.hit`、`entity.damaged`、`entity.died` 等事件已经能表达战斗事实。VisualCue 的目标是监听这些事件，执行声明式视觉 action。

目标：

- 通过 `VisualFeedbackHost` 统一订阅事件。
- 通过 `VisualCueRegistry` 注册 cue。
- 通过 `VisualActionRunner` 执行内置 action。
- 所有 action request 可记录、可测试、可降级。

## 非目标

- 不实现实体长期 actor 状态机。
- 不替换 `ProjectileRoot._draw()`。
- 不开放任意脚本 action。
- 不新增复杂 timeline 系统。
- 不实现完整音频系统，只发起 audio cue 请求或调用后续音频服务接口。

## 前置阅读

- [00-总览与边界.md](./00-总览与边界.md)
- [../../wiki/02-runtime-protocol/07-事件模型.md](../../wiki/02-runtime-protocol/07-事件模型.md)
- [../../wiki/04-roadmap-reference/42-通用扩展插槽机制.md](../../wiki/04-roadmap-reference/42-通用扩展插槽机制.md)

## 任务清单

### VF-CUE-01：新增 `VisualCueDef`

定义视觉 cue 贡献项资源。

最小字段：

```text
id
listen_event
filters
actions
tags
```

要求：

- 继承统一 contributor 基类，字段命名对齐 `RegistryContributorDef`。
- `id` 使用 `core.*` 或扩展包命名空间。
- `listen_event` 是 StringName。
- `filters` 是 Dictionary，仅用于匹配事件事实。
- `actions` 是数组，元素为内置 action 描述。

### VF-CUE-02：新增 `VisualFxDef`

定义 FX 场景资源贡献项。

最小字段：

```text
id
fx_scene
default_lifetime
default_layer
tags
```

要求：

- `fx_scene` 必须实例化为 `Node2D` 或可被宿主管理的节点。
- 资源缺失时 action 降级为 no-op，并记录 visual warning。

### VF-CUE-03：新增 `AudioCueDef`

定义音频 cue 资源贡献项。

最小字段：

```text
id
stream
bus
volume
pitch_range
dedupe_window
tags
```

要求：

- v1 可先只记录 audio action request。
- 若已有音频服务，则通过服务播放；否则保持 no-op fallback。

### VF-CUE-04：新增 `VisualCueRegistry`

注册并查询 `VisualCueDef`。

要求：

- 继承 `RegistryBase`。
- `_make_registry_config()` 声明 `slot_id = visual_cues`。
- `_register_builtin_defs()` 注册首批 `core.*` cue。
- 对重复 id、非法 def、`core.*` 覆盖记录 `protocol.issue`。

### VF-CUE-05：新增 `VisualFeedbackHost`

作为事件反馈入口。

职责：

- 订阅首批固定事件。
- 从 `VisualCueRegistry` 查询匹配 cue。
- 将匹配到的 action 交给 `VisualActionRunner`。
- 记录 cue 匹配、跳过原因和 action request。

首批监听事件固定为：

```text
projectile.spawned
projectile.hit
projectile.expired
entity.damaged
entity.died
placement.accepted
entity.status_removed
```

### VF-CUE-06：实现内置 `VisualActionRunner`

内置 action 固定为：

```text
spawn_fx
play_audio
flash_actor
play_actor_animation
attach_fx
screen_overlay
```

要求：

- 不执行扩展包脚本。
- action target 只解析 source / target / event position / projectile state。
- action 失败不抛出到战斗主链。
- 每个 action request 都可被 debug 记录。

### VF-CUE-07：添加核心内置 cue

首批 `core.*` cue 建议：

- `core.projectile_hit_splat`
- `core.projectile_expired_puff`
- `core.entity_damaged_flash`
- `core.entity_died_fade`
- `core.placement_accepted_pop`
- `core.status_removed_clear_overlay`

## 实现说明

### Cue 匹配规则

`VisualFeedbackHost` 收到事件后：

1. 按 `listen_event` 获取候选 cue。
2. 用 `filters` 匹配 `event_data.core/runtime/ext`。
3. 对通过匹配的 cue 依序执行 `actions`。
4. 每一步写入 visual debug log。

v1 的 filter 只做最小匹配：

- `source_kind`
- `target_kind`
- `source_archetype_id`
- `target_archetype_id`
- `tags`
- `move_mode`
- `profile_id`

### Action target 解析

默认 target：

- `source`：`event_data.core.source_node`
- `target`：`event_data.core.target_node`
- `event_position`：优先 target，再 source，再空。
- `projectile_ground_position`：当 source 或 target 支持 `get_ground_position()` 时读取。

## 推荐实现顺序

1. 建立 def 和 registry。
2. 建立 host，先只记录匹配，不执行表现。
3. 实现 `spawn_fx` 和 `flash_actor`。
4. 实现 `play_audio` request。
5. 实现 attachment 和 screen overlay 的 no-op 骨架。
6. 添加内置 cue。
7. 补 smoke 和 guardrail 验证。

## 验收标准

- 未配置 visual cue 时现有验证不受影响。
- cue 匹配失败不得中断战斗。
- 所有视觉 action 请求进入 DebugService 或 visual debug log。
- data-only cue 不执行任意脚本。
- 资源缺失时记录 warning，不抛出 fatal。

## 验证要求

新增或规划以下验证：

- `visual_registry_smoke`
- `visual_cue_projectile_hit_smoke`
- `visual_slot_guardrail`

验证重点：

- registry 初始化无 `protocol.issue`。
- 触发 `projectile.hit` 后产生预期 action request。
- data-only 包无法注册 runtime action script。

## 风险与边界

- 不要把 VisualCue 做成 Effect 的子类型；它是表现层 cue。
- 不要让 cue 回写事件，避免形成视觉事件循环。
- 不要在具体 projectile / plant / zombie 脚本里硬编码 cue 逻辑。
