# Reanim 原生运行时全量植物视觉迁移计划

> 状态：2026-09-27 集成验收已重建并核对 48/48 株产物与绑定；此前分支完成记录不代表素材已固定。当前证据见 [集成记录](reanim-integration-2026-09-27.md)。M5 GUI 校准、性能采样与归档仍待完成。
>
> 制定日期：2026-08-01
>
> 设计来源：`plans/draft/reanim原生运行时ReanimData方案设计草案.md`
>
> 已完成基线：`plans/reanim-native-runtime-implementation-plan.md`
>
> 候选矩阵：[`plans/reanim-native-migration-candidate-matrix.md`](reanim-native-migration-candidate-matrix.md)

## 1. 目标

把当前仓库中的 48 个 `archetype_original_*` 植物全部接入私有经典素材包的原生 Reanim 视觉链：

```text
ReanimData -> ReanimPlayer -> ReanimActorDef/ReanimActor -> VisualProfileDef.actor_scene
```

当前基线：

- 48 个正式原版植物 archetype，**全部 48 株已进入私有 manifest、native actor、profile 与 `asset_index.json`**。
- **48 个 archetype 的 `visual_profile_id` 已全部正式绑定**到对应 `classic_original.entity.plant.*.visual`（私有包关闭时安全降级）。
- 私有包有 146 份 `.reanim` 源文件和对应 semantic report。
- M0 候选矩阵确认 0 株命中真实 M3 能力缺口（无 blend / text-font / unresolved_layer）；M3 为空集。
- 验证：`local_private` 10/10、公开 `smoke` 24/24、`guardrail` 20/20、`check_public_extension_release_guardrails` OK；48 actor demo headless 加载无 missing/error。

“全量完成”以 live repo 的 48 个正式 archetype 为准；尚未形成正式 archetype 的 Imitater 等内容不纳入本轮。

## 2. 边界

本计划只迁移植物视觉，不修改玩法协议。

- 不新增 Mechanic family、registry slot 或实体专用 GDScript。
- 不迁移僵尸、Credits、UI、音频和场景动画。
- 不让视觉时间、动画帧或 cue 决定伤害、命中、冷却和状态结算。
- 不预先实现没有真实植物样本命中的 attacher、text/font、blend 或 renderer 能力。
- 私有源素材与生成物继续只保存在 `local_extensions/classic_original_assets`。
- `tools/formal_content_validation_map.json` 不因纯视觉迁移改变玩法归属。

## 3. 原版语义锚点

原版行为以 `vendor/de-pvz/Sexy.TodLib/Reanimator.cpp` 为规范来源：

- `ReanimationFillInMissingData`：导入期补齐缺省帧数据。
- `GetTransformAtTime` / `MatrixFromTransform`：帧采样与矩阵语义。
- `DrawRenderGroup`：轨道绘制顺序。
- `ParseAttacherTrack`：只有真实样本命中时才启动跨文件 attacher 能力。

OpenPVZ 最终接入边界仍是 `VisualProfileDef.actor_scene`，不复制参考项目的单位专用实现。

## 4. 执行任务

### M0：冻结 30 株候选矩阵 ✅ 完成

类型：迁移 / 工具。

工作：

- 从 `data/combat/archetypes/plants/archetype_original_*.tres` 派生 48 株权威清单。
- 扣除当前 manifest 的 18 株，得到 30 株待迁移清单。
- 扩展 `tools/scan_reanim_feature_flags.ps1`，允许扫描完整 archetype 清单，而不只扫描已有 manifest entries。
- 为每株登记 source reanim、semantic report、状态/action、overlay、角度警告、不支持特性和迁移批次。

验收：30 株全部有明确来源和分类；缺源、未知字段或未支持特性必须显式列为阻塞，不能静默跳过。 ✅ 矩阵见 [`plans/reanim-native-migration-candidate-matrix.md`](reanim-native-migration-candidate-matrix.md)；扫描脚本 `-Root` 默认修正为 worktree 相对路径，`-Roster original_plants` 输出 48 株（18 yes / 30 pending），BLOCKERS=0。

建议验证：

```powershell
pwsh tools/scan_reanim_feature_flags.ps1 -Root "local_extensions/classic_original_assets" -Roster original_plants
```

M0 附带修复：

- `tools/run_reanim_native_generate.ps1` 原硬编码 `C:\Users\Administrator\Documents\open-pvz\...` 路径已改为 fallback 链（`$env:GODOT_BIN` → 项目根 `Godot_v*_win64_console.exe` → `Get-Command godot` → 报错），并支持 `-GodotExe` / `-Project` 覆盖。
- 新增 `tools/reanim_seed_root_offset.gd`（headless 诊断）：按逐帧可见 AABB 报告候选 `root_offset` + 尺寸 + vendor Y 修正建议；验证表明它对部分株（wallnut/fumeshroom/tallnut ±1px）接近，对低地株（flowerpot/seashroom/lilypad 偏 20-30px）发散，故定位为"候选 + 必须目测确认"的诊断工具，非自动推导。

### M1：简单单部件批次

类型：内容 / 迁移。

范围：无 attacher/text/font/blend，且一个 body part 足以表达状态和动作的植物；每批建议 6～10 株。

工作：补 manifest native block，生成 `ReanimData`、`ReanimActorDef`、轻量 actor、profile 和 asset index；校准 `root_offset`、state/action 和固定锚点。

验收：每株 active actor 指向 `generated/native/<id>/actor.tscn`，无专用 wrapper，gallery 目测无明显落点或状态错误。

#### M1 首批进度（2026-08-01）：✅ cherrybomb / coffeebean / gravebuster / hypnoshroom

4 株单 body part 植物已迁移：manifest `native` 块 + `reanim_data.tres` + native actor（`actor_def.tres`/`actor.tscn`/`native_report.json`）+ visual profile + composite_report + asset_index 条目。`local_private` 10 场景全部 PASSED，manifest 五方一致性检查 22 profiles 通过，demo（扩到 22 株）headless 加载无 missing/error。

附加工具：

- `tools/run_reanim_migrate_one.ps1`：单株端到端迁移（Stage A 全量导入 → import_report 复制 → manifest entry upsert（legacy 字段 + native 块）→ Stage B native-only → 直写 profile/composite_report）。`-SkipStageA` 用于 Stage A 已跑过；`-NativeJson` 传每株 root_offset/states/actions。
- `tools/reanim_importer/reanim_rebuild_asset_index.gd`：仅按 manifest 重建 `asset_index.json`，不重建 legacy actor（比全量 Stage B 快，作为批量收口备选）。

待办：

- root_offset 为 AABB 候选值，**GUI 目测校准待办**（headless 无法目测；当前值结构性正确，落点可能需微调）。
- M1 余下：blover、doomshroom（按矩阵 §5 顺序）。
- M1 之后进入 M2-a 蘑菇 blink 批（gloomshroom/iceshroom/sunshroom/magnetshroom/spikeweed/spikerock）。

每批验证：

```powershell
pwsh tools/run_all_validations.ps1 -Layers "local_private" -MaxParallel 1
```

回退：只回退本批 manifest/profile/index 条目，不影响已完成批次。

### M2：现有通用组合能力批次

类型：内容 / 迁移 / 验证。

范围：需要 body/head/overlay、host track、track visibility、clip rate、action next state 或锚点，但现有 `ReanimActorDef` 已能表达的植物。

工作：优先复用 Threepeater、pea family、Sunflower blink 和 Chomper 的既有数据模式；只有出现新的通用语义时才补一项专项验证。

验收：组合关系全部数据化；不得新增植物名判断或植物专用运行时脚本。

验证：继续运行全部 `local_private`，并对新增通用语义增加一个真实样本专项场景。

#### M2 完成记录（2026-08-02）：✅ 24 株全部迁移

按矩阵分三批完成，全部走 body + blink-overlay（body 排除 blink 轨、blink 部分仅含 blink 轨并 hosted 于 body 的 `anim_face`）复用 sunflower/wallnut 模式；蘑菇 sleep 复用 puffshroom/fumeshroom；一次性 action 复用 chomper `action_next_states`。无新增植物专用运行时脚本，无植物名判断。

- **M2-a 蘑菇 blink（6 株）**：gloomshroom、iceshroom、sunshroom、magnetshroom、spikeweed（源 `Caltrop.reanim`）、spikerock。states 含 idle/sleeping/attacking（sleep/shooting clip 存在时）。
- **M2-b shooter/pult（9 株）**：cabbagepult、kernelpult（源 `Cornpult.reanim`）、melonpult、wintermelon、starfruit、cattail、cobcannon、cactus（双高度 idlehigh/rise/lower）、goldmagnet（attract action）。shooters 走 attacking=shooting + shoot action。
- **M2-c 支持类（9 株）**：garlic、plantern、torchwood、marigold、twinsunflower（源 `TwinSunflower.reanim`，双 blink）、jalapeno（body-only，explode 一次性）、umbrellaleaf（block）、tanglekelp（grab 一次性）、potatomine（rise 一次性、armed 状态）。

### M3：真实能力缺口批次 — 空集 ✅

M0 矩阵扫描确认：48 株全部 `blend_modes_seen` 为空、无 `text/font`、`unresolved_layer_count` 为 0。`suspected_attachment_count`/`overlay_binding_count` 非零的株全部被现有 host_track/track_visibility/blink-overlay 能力吸收（18 株已迁移植物证明）。**无株命中真实能力缺口，M3 无 Spike**。

### M4：48 株正式绑定与全阵容验收 ✅

类型：content / validation。

工作：

- 将 48 个 archetype 的 `visual_profile_id` 绑定到对应 `classic_original.entity.plant.*.visual`。
- 让 manifest、profile、asset index、native actor 和 archetype binding 五方一致。
- 扩展全阵容 gallery/demo，至少覆盖 idle、主要 action、睡眠/唤醒、一次性动作和多部件植物。
- 记录一次 48 actor 场景的节点数、帧耗时和内存基线；只在实测异常时讨论 renderer 优化。

完成记录（2026-08-02）：

- `tools/bind_visual_profile_ids.ps1` 将剩余 43 个 archetype 的 `visual_profile_id` 绑定（原 5 + 新 43 = 48），idempotent，插在 `display_name` 之后。
- manifest 五方一致性检查 48 profiles valid（`check_private_classic_visual_manifest.gd`）。
- demo 扩到 48 株（8×6 网格），headless 加载无 missing/error。
- 最终验证四件全过：`local_private` 10/10、公开 `smoke` 24/24、`guardrail` 20/20、`check_public_extension_release_guardrails` OK。
- 48 actor 详细节点数/帧耗时/内存基线留作 GUI 实测（M5）。

最终验证：

```powershell
pwsh tools/run_all_validations.ps1 -Layers "local_private" -MaxParallel 1
pwsh tools/run_all_validations.ps1 -Layers "smoke" -MaxParallel 8
pwsh tools/run_all_validations.ps1 -Layers "guardrail" -MaxParallel 8
pwsh tools/check_public_extension_release_guardrails.ps1
```

### M5：文档与清理

类型：docs / migration。

工作：更新素材包 wiki、迁移底账、公开 semantic 模板和目录说明；把旧 `actors/` 路径统一改为 `generated/native/`。仅在零引用、可再生成且获得单独确认后清理旧产物。

完成后归档本计划及已完成的 18 株实施计划，更新 `plans/README.md`。

## 5. 依赖顺序

```text
M0 候选矩阵
  -> M1 简单批次
  -> M2 通用组合批次
  -> M3 真实能力缺口
  -> M4 48 株绑定与全量验证
  -> M5 文档和归档
```

M1、M2 可按候选分类交错执行；M3 不阻塞已经能用现有能力迁移的内容。

## 6. Definition of Done

- [x] live repo 的 48 个原版植物 archetype 全部有私有 native visual profile。
- [x] 48 个 profile、asset index、manifest 和 `generated/native` actor 一致（`check_private_classic_visual_manifest.gd`：48 profiles valid）。
- [x] 48 个 archetype 的 `visual_profile_id` 已正式绑定且私有包关闭时保持安全降级（`bind_visual_profile_ids.ps1` 绑定全部 48；公开 smoke/guardrail 在私有包关闭时通过）。
- [x] 没有植物专用运行时分支；所有组合通过 `ReanimActorDef` 表达（无植物名判断、无植物专用 GDScript；body+blink/face overlay、host_track、action_next_states、clip_rates 全数据化）。
- [x] 所有真实命中的不支持特性已实现或有明确、可验证的 fail-closed 处理（M0 确认 0 株命中 blend/text-font/unresolved_layer；M3 空集；attacher/overlay 计数被现有 host_track/track_visibility 吸收）。
- [x] `local_private`、public smoke、guardrail 与发布边界检查全部通过（local_private 10/10、smoke 24/24、guardrail 20/20、release guardrail OK）。
- [ ] 48 actor 性能基线已记录，没有阻塞性回退。（demo headless 加载无 missing/error；详细帧耗时/内存基线留作 M5/GUI 实测）。
- [ ] wiki、公开模板、迁移底账与代码现状一致。（M5 文档同步进行中）。
- [ ] 计划完成后按归档流程处理。（M5）。

### 残留 GUI-only 待办

- root_offset 目测校准：26 株新迁移植物用 AABB 候选值落点，headless 验证结构性正确但无法目测落点；用 GUI 窗口跑 `visual_reanim_native_actual_demo.tscn`（现已扩到 48 株，8×6 网格）逐株确认/微调 `root_offset`。
- 48 actor 详细性能基线（节点数/帧耗时/内存）在 GUI 实测时记录。
