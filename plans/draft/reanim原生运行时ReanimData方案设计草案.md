# Reanim 原生运行时（ReanimData + ReanimPlayer + ReanimActorDef）设计草案

> 日期：2026-07-29
> 状态：设计讨论草案
> 结论等级：方向可行，但不可直接作为当前实现依据；需先完成双样本技术 Spike，再转实施计划

## 相关资料

- reanim 工具链历史规划：`plans/reanim资源转换工具链规划.md`（AnimationPlayer 转码路线，本草案的对照与回退方案）
- 视觉层设计：`plans/视觉表现层设计讨论.md`（Actor Scene Contract、Action Recipe、Part Slot）
- 原版视觉批量迁移执行方案：`plans/original-plant-visual-bulk-migration-plan.md`
- 素材包与本地私有包：`wiki/04-roadmap-reference/44-素材包系统与本地私有包.md`
- 参考项目语义索引：`wiki/04-roadmap-reference/46-参考项目语义索引.md`
- 当前实现（导入器）：`tools/reanim_importer/reanim_import_one.gd`、`reanim_generate_composites.gd`、`reanim_visual_manifest.json`
- 当前实现（运行时）：`scripts/components/visual_actor_component.gd`、`scripts/core/defs/visual_profile_def.gd`、`scripts/validation/reanim_manifest_composite_actor.gd` 及各 `visual_reanim_*_composite_actor.gd`
- 仿真时钟：`autoload/GameState.gd`、`scripts/battle/battle_manager.gd`
- 原版 Reanim 语义：`vendor/de-pvz/Sexy.TodLib/Reanimator.h`、`Reanimator.cpp`、`Attachment.h`、`Attachment.cpp`
- 原版组合语义：`vendor/de-pvz/Lawn/Plant.cpp`（ThreePeater / SplitPea 多 reanimation 实例与 track binding）
- Godot 表达参考：`vendor/PVZ-Godot-Dream/README.md`、`docs/开发相关.md`、`animation/`
- 本地私有素材包：`local_extensions/classic_original_assets/`

## TL;DR

方向可行，推荐把当前「`.reanim` → 每 track Sprite2D + AnimationPlayer 关键帧 → 巨型 `.tscn` + per-entity wrapper」改为三层数据/运行时模型：

1. **ReanimData**：一份不可变的单 reanim 定义，保存 track、帧数据、clip 与资源引用。
2. **ReanimPlayer**：播放一份 ReanimData，维护局部相位、loop、blend、track override，并生成完整 `Transform2D`。
3. **ReanimActorDef**：声明一个 actor 由哪些 ReanimPlayer 实例组成、如何通过 Part Slot / host track 绑定，以及语义 state/action 如何映射到各 part。

对外继续使用现有 `VisualProfileDef.actor_scene + VisualActorComponent`。素材包内可生成一个很小的 actor scene，由通用 `ReanimActor` 根节点引用 ReanimActorDef，并实现现有 `play_state / play_action / play_animation / set_visual_speed / get_anchor` 协议。不修改 Mechanic-first，不新增 Mechanic family，不要求新增 registry。

该方案能显著解决产物体量和组合脚本重复，但不会自动解决语义推断、锚点标定或法务发布。角度问题也不是“直绘矩阵后自然消失”，而是从 AnimationPlayer 的隐式插值，变为 ReanimPlayer 可显式选择、验证的插值策略。

## 背景与当前证据

当前迁移链：

```text
.reanim
  -> reanim_import_one.gd
  -> generated/raw/<id>/actor.tscn
     (AnimationPlayer + 每 track 一个 Sprite2D + 逐帧关键帧)
  -> actors/<id>/actor.tscn + composite wrapper
  -> VisualProfileDef.actor_scene
  -> VisualActorComponent
```

当前本地证据：

- ThreePeater 源 `.reanim` 约 90 KB，raw actor 约 2.31 MB、36,691 行，体积放大约 25.6 倍。
- SplitPea 源 `.reanim` 约 49 KB，raw actor 约 0.99 MB、12,394 行，体积放大约 20.4 倍。
- 当前 18 个 raw actor 总计约 12.35 MB。
- `visual_reanim_threepeater_composite_actor.gd` 当前为 421 行，负责 body、三个 head、clip 切换、同步、挂点和可见性。
- 当前 18 份 import report 中只有 WallNut 出现 2 条 angle warning，未发现 blend mode；因此当前方案最强的驱动力是**产物体量与组合复用**，角度修正是附带收益而不是唯一理由。
- 当前本地 146 份 `.reanim` 中，`attacher__` 主要出现在 credits 类资源；ThreePeater/GatlingPea 的组合不是自动 `attacher__` 拓扑。

## 目标

- 用紧凑、版本化、可验证的 ReanimData 取代逐帧 AnimationPlayer 序列化膨胀。
- 用 ReanimPlayer 统一实现矩阵采样、clip 播放、loop、blend、颜色/track override 和局部时钟。
- 用 ReanimActorDef / Part Slot 把多实例 actor 的组合关系从专属 GDScript wrapper 收敛为数据。
- 保持 `sim -> visual` 单向依赖，在暂停、倍速和手动 step 下可复现。
- 迁移期同时产出旧 AnimationPlayer actor 与新 ReanimData，达到对照门槛后逐角色切换。

## 非目标

- 不修改 `CombatArchetype + CombatMechanic[]` 主链。
- 不让视觉动画发射或决定伤害、命中、冷却、移动等玩法结果。
- 不在 BattleManager 或实体根脚本中增加具体角色视觉特判。
- 不承诺自动推断所有 body/head/overlay/state/action 语义；推断结果必须带来源与置信状态，并允许 manifest 人工确认。
- 不解决最终 ground anchor 标定；继续由 `VisualProfileDef.ground_offset` 承载装配修正。
- 不解决原版素材发布授权；派生产物继续属于 `local_extensions/` 本地私有边界。
- P0/P1 不追求完整覆盖 credits 文本、所有滤镜、粒子 attachment 或原版全部边缘特性；未支持特性必须结构化 fail-closed，不能静默丢失。

## 三源对比

| 维度 | OpenPVZ 当前实现 | de-pvz 原版语义 | PVZ-Godot-Dream 参考 | 本草案落点 |
|------|------------------|------------------|---------------------|------------|
| 动画承载 | AnimationPlayer + per-track Sprite2D | `Reanimation` 运行时采样并绘制 | R2Ga 转 Godot 动画 | ReanimData + ReanimPlayer |
| 变换 | rotation/skew/scale 属性关键帧 | `MatrixFromTransform` 构造完整 2×3 仿射矩阵 | 依赖 Godot 动画属性 | 采样后直接构造 `Transform2D` |
| 帧间插值 | AnimationPlayer 隐式处理 | 相邻帧对 x/y/sx/sy/kx/ky/a 做线性插值 | AnimationPlayer | 显式、可测试的兼容策略 |
| clip blend | wrapper / AnimationPlayer blend | `StartBlend` + per-track blend counter | 依赖具体动画树/播放器 | ReanimPlayer 以 sim tick 维护 blend |
| 多部件组合 | per-entity wrapper | 多 Reanimation 实例 + track attachment；另有动态 `attacher__` | 组件/场景组合 | ReanimActorDef + Part Slot；动态 attacher 独立处理 |
| 时间 | 多数 wrapper `_process(delta)` | `SECONDS_PER_UPDATE=0.01` | 渲染帧 | 实体 actor 读仿真时间，环境 actor 可用渲染时间 |

证据优先级：原版数据和语义以 `vendor/de-pvz` 为准；PVZ-Godot-Dream 只用于观察 Godot 工程组织，不复制其具体单位脚本；OpenPVZ 当前协议是最终接入边界。

## 推荐模型

### 1. ReanimData：不可变单定义 Resource

ReanimData 只描述一份 reanim 定义，不保存播放中的可变状态。建议字段：

- `schema_version`
- `source_id`、`source_hash`（用于导入可追踪性，不暴露私有源内容）
- `fps`、`frame_count`
- `image_refs[]`、可选 `font_refs[]`、`text_table[]`
- `tracks[]`
  - `name`
  - 密集或稀疏的打包帧数据
  - `x / y / sx / sy / kx / ky / alpha`
  - `image_ref_index`
  - `image_frame`：保留原版 `f` 数值，`< 0` 才表示隐藏，不能只降格成 `visible`
  - 可选 `font_ref_index / text_index`
- `clips[]`
  - `name / start_frame / frame_count`
  - `source_kind = marker | reviewed_inference | fallback_all`
  - `confirmed`
- `feature_flags`：例如 `has_text / has_font / has_attacher / has_blend_mode / has_multi_cel_image`
- 动态 `attacher__` 元数据（仅在解析能力落地后写入）

实现约束：

- 运行时不解析 `.reanim` XML。
- 缺省字段按 `ReanimationFillInMissingData` 在导入期展开，或编译为可 O(1) 采样的打包数据；不能让每个实例重复展开。
- 优先使用共享的 `PackedFloat32Array / PackedInt32Array` 或二进制 `.res`，不使用大量 `Array[Dictionary]` / 子 Resource 复制关键帧，否则可能把巨型 `.tscn` 问题换成巨型 `.tres`。
- marker clip 可作为权威候选；从 `anim_*` 可见范围推断出的 clip 只能进入报告或标记为 `reviewed_inference`，不能未经确认进入正式 state/action 映射。
- 当前 importer 的字段集合不包含 `text/font`，不能原样复用；P0 必须先补 parser parity，才能解析 `attacher__` 文本。

### 2. ReanimPlayer：单实例播放与采样

一个 ReanimPlayer 播放一份 ReanimData，并维护实例状态：

- 当前 clip、loop type、播放方向、局部相位、loop count
- `phase_at_epoch / epoch_sim_time / visual_speed`
- clip transition blend 状态与剩余 blend ticks
- per-track visible/render group、image override、track color 等实例覆盖
- base pose 与 overlay matrix
- 当前 draw snapshot（track、image、image_frame、matrix、color、blend policy）

每次采样：

1. 根据局部相位求 before/after frame 与 fraction。
2. 按明确策略插值原始字段。
3. 由 `kx/ky/sx/sy/x/y` 构造完整 `Transform2D`。
4. 应用 base pose、overlay matrix、track override 和 actor 根变换。
5. 输出 draw command 或更新动态 CanvasItem。

#### 插值语义

必须区分两种插值：

- **同一 clip 相邻帧采样**：`de-pvz:GetTransformAtTime` 对 x/y/sx/sy/kx/ky/alpha 做直接线性插值，image/frame/text 使用离散取值。
- **clip transition blend**：`de-pvz:BlendTransform` 对大角差存在原版兼容行为，当前源码锚点并不是标准 ±360° shortest-arc。

默认先实现并验证 **de-pvz 兼容模式**。如果 golden pose 证明原版大角差行为造成明显视觉缺陷，再增加显式的 corrected-shortest-arc 策略；不能用函数名或“直绘矩阵”推断角度问题已自动解决。

### 3. ReanimActorDef：组合配方 Resource

ReanimActorDef 负责单份 ReanimData 无法表达的多实例组合：

```text
ReanimActorDef
├── parts[]
│   ├── id
│   ├── reanim_data
│   ├── initial_clip / loop_type / rate
│   ├── host_part_id
│   ├── host_track
│   ├── render_order
│   └── track_visibility / image_override
├── states{}
├── actions{}
├── anchors{}
└── feature_policy
```

它与现有视觉设计中的 Part Slot / Action Recipe 对齐：

- Part Slot 描述 body/head/overlay 等部件以及 host track。
- state/action 映射把 `idle / attacking / shoot` 等稳定语义映射到一个或多个 part clip。
- Action Recipe 继续负责 root motion、视觉 cue、FX 等更高层编排；ReanimActorDef 不复制整套 Action Recipe 语言。
- ThreePeater 应由 body + 三个 head ReanimPlayer 实例组成，分别绑定 `anim_head1/2/3`；这不是动态 `attacher__` 自动解析问题。
- SplitPea、Peashooter family、GatlingPea 可作为后续同类样本。

### 4. ReanimActor：Actor Scene Contract 适配器

ReanimActor 是素材包 actor scene 的通用根节点：

- 引用一个 ReanimActorDef。
- 创建并管理一个或多个 ReanimPlayer。
- 实现 `play_state / play_action / play_animation / set_visual_speed / get_anchor`。
- 不查询玩法数据，不决定攻击时刻，不回写实体状态。
- 对未识别 action 返回 `false`，保留 VisualActorComponent 的既有回退语义。

素材包可为每个 profile 生成一个只有少量节点和 Resource 引用的轻量 `.tscn`，继续由 `VisualProfileDef.actor_scene` 加载。ReanimData / ReanimActorDef 是 VisualProfile 的内部依赖，不作为独立 contributor 注册；只有将来出现明确的跨包逻辑 ID 覆盖需求时，才重新评估是否接入 AssetRegistry。

## Renderer 边界

原版 `DrawRenderGroup` 按 track 顺序绘制，并在宿主 track 后立即绘制 attachment。单个父节点先画完所有 track、再让子 ReanimPlayer 绘制，会破坏这种交错顺序；单 CanvasItem 也不方便切换 per-track material/blend。

当前决策：

- evaluator 与 renderer 分离，ReanimPlayer 的采样结果先形成稳定 draw snapshot。
- P1 使用**运行时动态创建的 per-track CanvasItem/Sprite2D**，attachment 作为宿主 track 的子级，优先保证顺序、材质、锚点和调试可见性。
- 动态节点不序列化进生成 `.tscn`，因此不会重现当前逐帧关键帧文本膨胀。
- 只有基准数据证明节点/CanvasItem 成为瓶颈后，才实现递归扁平 draw-command 或 RenderingServer 后端。
- renderer 优化不得改变 ReanimPlayer 的采样结果或 ReanimActorDef 协议。

## 时钟契约

依赖方向恒为 **sim -> visual**。

### 实体绑定 actor

`GameState.current_time = current_tick * fixed_dt` 作为只读时间源，但不能直接使用 `frame = current_time * fps` 作为所有 clip 的相位。每个 ReanimPlayer 保存局部 epoch：

```text
phase = phase_at_epoch
      + (GameState.current_time - epoch_sim_time) * visual_speed
```

- `play()`：把局部 phase 设为 clip 起点，同时记录当前 `epoch_sim_time`。
- `set_visual_speed()`：先按旧速度结算当前 phase，再以当前仿真时间重建 epoch，避免改速跳帧。
- pause：GameState 不推进 tick，phase 自然冻结。
- simulation_speed：改变单位墙钟时间内的 sim tick 数，视觉随仿真同步慢放/快进。
- manual step：验证可直接推进固定 tick，再显式请求 player 采样。
- blend duration 使用整数 sim tick，避免渲染帧率影响结果。
- 多 part 同步通过显式 `phase_sync_group` 或 play 时复制局部 phase，不读取彼此的 `_process(delta)` 累积结果。

### Gameplay 时刻

- 开火、命中、爆炸仍由 Trigger / Effect / Combat Action Timeline 决定。
- `ShouldTriggerTimedEvent` 类能力只允许驱动 cosmetic cue，不得决定 gameplay 结算。
- 如果视觉事件到达时需要从 clip 第 0 帧播放，由事件调用 `play_action()` 建立新的局部 epoch。

### 环境/菜单 actor

没有实体绑定、也不要求验证复现的环境/菜单动画可使用 `_process(delta)`。该模式必须显式选择，不能与实体 actor 的 sim-time 模式隐式混用。

## 接入与扩展边界

- 保持 `VisualProfileDef.actor_scene` 为运行时唯一 actor 后端边界。
- 保持 `visual_profiles` register kind 与 `VisualProfileRegistry / AssetRegistry` 现状。
- ReanimData、ReanimActorDef 是素材实现内部 Resource，不新增 Mechanic family，也不新增 RegistryBase 扩展点。
- 本地私有原版素材包继续 `data_only + local_private`；通用 ReanimPlayer/ReanimActor 运行时代码如果进入主仓，只提供格式播放能力，不携带原版素材。
- 旧 AnimationPlayer actor 在迁移期保留为 fallback 与对照 oracle；不得在单个提交中全量删除旧产物和 wrapper。

## 能力边界校验

| 问题 | 修订后判断 | 条件 |
|------|------------|------|
| 巨型生成产物 | 可解决 | 必须使用 packed/binary 数据并设体积门槛，不能用 Dictionary/SubResource 重建膨胀 |
| rotation/skew 表达 | 可解决 | `Transform2D` 可精确表达采样后的 2×3 仿射矩阵 |
| 角度插值失真 | 可控但非自动解决 | 明确区分帧间插值与 clip blend，并以 golden pose 选兼容策略 |
| per-entity wrapper | 可大幅减少 | 必须补 ReanimActorDef / Part Slot；仅有 ReanimData 不够 |
| 动态 `attacher__` | 可通用化 | parser 先支持 text/font，随后补跨文件解析、循环依赖与深度限制 |
| base pose / color / override | 可通用化 | 作为 ReanimPlayer 实例状态，分阶段实现 |
| 锚点/落点标定 | 不解决 | 继续由 profile / actor 数据校准 |
| 法务与公开发布 | 不解决 | 继续 local-private 与发布门控 |
| 全部 `.reanim` 无损覆盖 | P0/P1 不承诺 | 不支持特性必须报告并 fail-closed，逐步扩展 feature policy |

## 协议缺口

实施计划前必须明确：

1. ReanimData v1 的精确 packed layout、schema migration 与 source hash 生成规则。
2. `image_frame`、多 cel texture、text/font、fullscreen track 的支持或拒绝策略。
3. clip 的权威来源：marker、人工 manifest 与 visual-layer inference 的优先级。
4. loop type：loop、play once、play once and hold、full-last-frame、负速播放的 v1 范围。
5. clip blend 的原版兼容语义与 corrected 策略是否需要同时存在。
6. Part Slot 的最小字段，以及它与现有 Action Recipe manifest 字段如何复用。
7. 跨文件 attacher 的 pack-local 解析、循环引用检测、最大递归深度和缺失资源行为。
8. renderer 的稳定 draw snapshot 格式，确保动态 CanvasItem 与未来优化后端可以对照验证。

## 验证方案与准入门槛

### 验证场景

- `visual_reanim_data_import_smoke`（`local_private`）：验证 fps、frame_count、track 数、clip、texture、image_frame、feature_flags 和 schema version。
- `visual_reanim_native_runtime_smoke`（`local_private`）：Peashooter 单实例 idle/shooting 播放，固定 tick 下检查 draw snapshot。
- `visual_reanim_sim_clock`：检查 action 从局部 0 帧开始、pause 冻结、0.5x/2x、manual step、运行中改速不跳相位。
- `visual_reanim_angle_compatibility`：使用 WallNut 大角差样本，对比 de-pvz 兼容采样与可选 corrected 策略。
- `visual_reanim_composite_threepeater`：body + 三个 head 的 host track、clip、phase sync、muzzle anchor 与当前 wrapper 对照。
- `visual_reanim_renderer_order`：检查 host track、attachment、后续 sibling track 的绘制顺序和 per-track material。
- `visual_reanim_attacher_cross_file`：后续用 credits 中真实 `attacher__...[rate/hold/once]` 样本验证跨文件挂载。

### Golden snapshot

固定 tick 下输出并比较：

```text
part_id
track_name
image_ref
image_frame
visible
Transform2D
modulate
render_order
attachment_parent
```

优先比较采样结果而不是只做像素截图；像素对照可作为 showcase 回归补充，不能替代矩阵/资源身份断言。

### 迁移准入门槛

- Peashooter 单实例和 ThreePeater 组合实例均通过固定 tick 对照。
- action 重播、暂停、倍速、manual step、运行中改速无相位跳跃。
- ThreePeater 不再依赖专属组合脚本即可表达现有 body/head 关系后，才允许退役其 wrapper。
- ReanimData 必须显著小于 raw actor；建议技术 Spike 门槛为 ThreePeater 新数据产物不超过当前 2.31 MB raw actor 的 25%。
- 记录代表性多 actor 场景的 CPU、内存、CanvasItem/draw call 基线；未达预算时优先优化 renderer，不修改数据/组合协议。
- importer 双输出、fallback 和旧路径对照均工作后，才允许进入批量迁移。

## 分阶段路线

| 阶段 | 内容 | 产出 / DoD |
|------|------|------------|
| P0 数据协议与双输出 | ReanimData v1；parser 补 `text/font/image_frame`；feature_flags；旧 actor + 新数据双输出 | Peashooter/WallNut 可生成、加载、验证；不支持特性结构化报告 |
| P1 单实例播放器 | ReanimPlayer；局部 sim-time epoch；loop/blend 基础；动态 per-track CanvasItem renderer | Peashooter body 精确回放；时钟与 golden snapshot 验证通过 |
| P2 组合配方 | ReanimActorDef；Part Slot；state/action 多 part 映射；phase sync | ThreePeater/SplitPea 至少一个组合样本无需专属 wrapper 即可表达 |
| P3 动态 attacher | 解析 `attacher__REANIM__TRACK[tag]`；跨文件引用；base pose/overlay；循环与深度 guardrail | credits 真实样本通过跨文件挂载验证 |
| P4 高阶表现与性能 | color/image/render-group override；additive/overlay；滤镜范围；renderer benchmark/可选优化后端 | 代表性 actor 视觉与性能门槛通过 |
| P5 批量迁移与收口 | 按 profile 切换；保留 fallback；逐个退役 wrapper/raw actor；更新 wiki | 本地私有包完成受控迁移，主仓公开边界不变 |

## 备选方案

- **B. 继续修 AnimationPlayer 转码**：补插值与 wrapper 生成，实施快，但逐帧文本体积和组合复杂度继续增长。适合极少量简单 actor，不适合作为全量原版素材主路径。
- **C. 手工重画/自制原生动画**：绕开 reanim 与原版素材发布问题，适合公开默认包；制作成本高，不能替代本地私有原版兼容路径。
- **D. 维持 per-entity wrapper**：可作为迁移期 oracle/fallback，不具备规模化维护价值。

## 已收敛决策

1. ReanimData 不作为独立注册贡献项，长期先作为 VisualProfile actor 后端的内部依赖。
2. ThreePeater 属于多 ReanimPlayer 实例 + Part Slot，不归类为自动 `attacher__` 样本。
3. schema version、feature flags、image_frame 与结构化 unsupported report 是 P0 必选项。
4. 实体动画使用局部 sim-time epoch，不直接用全局 `current_time * fps`。
5. P1 先使用动态 per-track CanvasItem 保证正确性；单节点 `_draw()` 不是前置决策。
6. 迁移必须双输出、可回退、逐 profile 收口，不能直接全量替换。

## 开放问题

1. ReanimData v1 是否直接纳入 text/font 渲染，还是只保留字段并对 credits 类资源 fail-closed？
2. `de-pvz:BlendTransform` 的大角差行为应完全兼容，还是只对已确认异常的资源启用 corrected-shortest-arc？
3. Part Slot 字段直接复用现有本地 `reanim_visual_manifest.json`，还是先定义最小 ReanimActorDef Resource 再让 manifest 生成它？
4. renderer 何种实测阈值触发从动态 CanvasItem 切换到扁平 draw-command / RenderingServer 后端？
5. `ground_offset` 半自动量测与现有手工校准如何并存，避免 showcase 落点回归？
