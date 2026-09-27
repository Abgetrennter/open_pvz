# 原版植物视觉批量迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把原版植物视觉从 5 株试点推进到可批量生产、可验证、可分批接入正式 `CombatArchetype.visual_profile_id` 的迁移流程。

**Architecture:** 原版 `.reanim/png` 仍只作为本地私有输入；运行时只消费 `classic_original_assets` 私有包中的 `actor.tscn`、`VisualProfileDef`、`VisualCueDef` 和 `asset_index.json`。主仓只保存公开工具、验证脚本、archetype 的 `visual_profile_id` 绑定和文档；私有素材、生成物和原始资源保留在 ignored 的 `local_extensions/classic_original_assets` 嵌套仓库。

**Tech Stack:** Godot 4.6.1、GDScript、OpenPVZ `AssetRegistry` / `VisualProfileRegistry` / `VisualCueRegistry`、`local_private` validation layer、PowerShell 验证入口。

---

## 状态与来源

- 状态：当前执行/维护。Task 1 已完成；Task 2 的 A1 自动生成与索引检查已完成，等待人工/截图校准 `ground_offset` 后再进入 formal binding。
- 日期：2026-05-27。
- 关联文档：
  - `plans/原版图像移植工作文档.md`
  - `plans/original-plant-migration-ledger.md`
  - `plans/original-plant-protocol-gaps.md`
  - `wiki/04-roadmap-reference/46-参考项目语义索引.md`
- 当前基线：
  - 私有包 manifest：`local_extensions/classic_original_assets/manifests/reanim_visual_manifest.local.json` 当前 18 个 entries。
  - 私有包 runtime profile：`local_extensions/classic_original_assets/data/combat/visual_profiles/plants/` 当前 18 个 `.tres`。
  - 视觉运行时链路（2026-08-01）：18 株 profile 与 `asset_index.json` 的 active `actor_scene` 已全部由旧链 wrapper actor（`actors/<id>/`）切到新链 `ReanimActor + ReanimActorDef + ReanimData`（`generated/native/<id>/actor.tscn`），详见 `plans/reanim-native-runtime-implementation-plan.md` 的 T6 执行记录；旧 `actors/<id>/` 产物已删除，manifest 仅保留其可选再生成目标。
  - 主仓 formal binding：`archetype_original_peashooter`、`archetype_original_sunflower`、`archetype_original_threepeater`、`archetype_original_chomper`、`archetype_original_squash` 已绑定 `classic_original.entity.plant.*.visual`。
  - 原版背景与 800x600 画布已对齐；草地背景按 `position = Vector2(-220, 0)`，植物展示按原版 `LAWN_XMIN = 40`、`LAWN_YMIN = 80`、格宽 `80`、草地行高 `100` 换算，并叠加 profile `ground_offset`。

## 非目标

- 不修改 `vendor/`。
- 不把 `local_extensions/classic_original_assets` 私有素材发布到主仓。
- 不在战斗逻辑里加入植物物种特判；特殊动作只能通过现有语义事件、`Combat Action Timeline`、`VisualCueDef` 和 actor action 表达。
- 不让视觉动画、Tween、粒子或 UI 改变命中、伤害、冷却、目标锁定和生命周期结算。
- 不要求第一轮批量迁移一次完成全部 49 个原版 seed；每批必须能独立验证和回滚。
- 不把展示场景里的手写像素偏移作为锚点来源；物种级锚点只写入私有包 `VisualProfileDef.ground_offset`。

## 迁移分层

| 层级 | 完成定义 | 主要位置 | 允许进入下一层的条件 |
|------|----------|----------|----------------------|
| 源素材层 | `.reanim`、贴图和 `resources.xml` 可在私有包中定位 | `local_extensions/classic_original_assets/sources/` | 语义报告可生成，且关键贴图可解析 |
| raw actor 层 | 单株生成 `actor.tscn`、`visual_profile.tres`、`import_report.json` | `local_extensions/classic_original_assets/generated/raw/<plant>/` | `ResourceLoader.load(actor.tscn)` 成功，`unresolved_texture_count == 0` 或有明确解释 |
| composite profile 层 | manifest 生成正式 actor/profile/report/index | `actors/`、`data/combat/visual_profiles/`、`generated/reports/`、`asset_index.json` | `AssetRegistry.resolve_visual_profile(profile_id)` 能解析 actor |
| formal binding 层 | 正式 `CombatArchetype.visual_profile_id` 指向 profile | `data/combat/archetypes/plants/*.tres` | local_private 验证和展示检查通过 |
| visual cue 层 | 攻击、吞噬、跳砸、爆炸、睡眠等动作由 cue 触发 | `local_extensions/classic_original_assets/data/combat/visual_cues/` | 语义事件触发日志可验证，规则结算不依赖视觉 |

## 批次策略

每批建议 8 到 12 株。普通批次优先扩大覆盖面；特殊批次单独处理 action/cue/timeline。

| 批次 | 目标 | 候选植物 | 备注 |
|------|------|----------|------|
| A1 普通站桩与简单状态 | 扩大 idle / shoot / sleep / damage override 的稳定样本 | `repeater`、`snowpea`、`gatlingpea`、`splitpea`、`puffshroom`、`scaredyshroom`、`fumeshroom`、`seashroom`、`wallnut`、`tallnut`、`pumpkin`、`lilypad`、`flowerpot` | 只接入 actor/profile 和必要 state/action map；不新增战斗协议 |
| A2 投手与常规支援 | 验证 projectile/action 节奏和较复杂 body/head 结构 | `cabbagepult`、`kernelpult`、`melonpult`、`wintermelon`、`cactus`、`starfruit`、`torchwood`、`marigold`、`plantern`、`magnetshroom`、`goldmagnet` | `kernelpult` 源资源名为 `Cornpult.reanim`；投射物/范围效果另走 visual cue 或占位 |
| B 一次性与延迟动作 | 接入 explode、arming、consume_self、睡眠/唤醒等动作表现 | `cherrybomb`、`jalapeno`、`doomshroom`、`iceshroom`、`potatomine`、`gravebuster`、`tanglekelp`、`coffeebean`、`hypnoshroom`、`blover` | 只在规则层已有语义事件时绑定 cue；缺事件先记录到 protocol gaps |
| C 地形/占用/复杂 actor | 处理多格、覆盖层、泳池/屋顶/炮台等高风险视觉 | `cattail`、`cobcannon`、`spikeweed`、`spikerock`、`garlic`、`umbrellaleaf`、`imitater` | `garlic`、`umbrellaleaf`、`imitater` 若主仓 archetype 未完成，先允许停在 composite profile 层，不做 formal binding |

## 执行任务

### Task 1: 建立批量迁移清单与自动检查入口

**Files:**
- Create: `tools/check_private_classic_visual_manifest.gd`
- Modify: `tools/check_private_classic_asset_pack.gd`
- Modify: `scripts/validation/visual_validation_probe.gd`
- Modify: `tools/check_original_plant_showcase_visual_binding.gd`
- Modify: `plans/原版图像移植工作文档.md`

- [x] 读取 `local_extensions/classic_original_assets/manifests/reanim_visual_manifest.local.json`，生成 manifest entries、profile ids、actor paths、source reanim paths 的检查结果。
- [x] 把 `tools/check_private_classic_asset_pack.gd` 中硬编码 5 个 `REQUIRED_PROFILE_IDS` 收敛为从 `asset_index.json` 或 manifest 派生；保留一个最小核心样本列表只用于验证旧试点没有回退。
- [x] 把 `scripts/validation/visual_validation_probe.gd` 的 `PRIVATE_CLASSIC_PROFILE_IDS` 与 `PRIVATE_CLASSIC_ARCHETYPE_TO_PROFILE` 改成可从 `CombatArchetype.visual_profile_id` 和私有包索引派生；失败信息必须能指出具体 archetype/profile。
- [x] 扩展 `tools/check_original_plant_showcase_visual_binding.gd`，让它按“已绑定列表 + 未绑定占位列表”检查，不再只认 5 株。
- [x] 在 `plans/原版图像移植工作文档.md` 增加“批量迁移检查入口”小节，记录新增脚本职责和运行命令。

**Acceptance:**
- 新检查脚本能报告当前 5 个 profile 全部有效。
- 现有 5 株绑定验证仍通过。
- 未绑定植物仍显示占位，不被误判为失败。

**Validation:**

```powershell
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_private_classic_visual_manifest.gd -- --include-classic-original-assets
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_private_classic_asset_pack.gd -- --include-classic-original-assets
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_original_plant_showcase_visual_binding.gd -- --include-classic-original-assets
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/visual_private_classic_asset_pack_smoke.tres" -ExtraUserArgs "--include-classic-original-assets"
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/visual_private_classic_archetype_binding_smoke.tres" -ExtraUserArgs "--include-classic-original-assets"
```

**Rollback risk:** 低。失败时回退检查脚本即可，不影响私有素材。

### Task 2: A1 批 raw actor 与 composite profile 生成

**Files:**
- Modify: `local_extensions/classic_original_assets/manifests/reanim_visual_manifest.local.json`
- Generate: `local_extensions/classic_original_assets/generated/raw/<plant>/`
- Generate: `local_extensions/classic_original_assets/actors/<plant>/actor.tscn`
- Generate: `local_extensions/classic_original_assets/data/combat/visual_profiles/plants/<plant>.tres`
- Generate: `local_extensions/classic_original_assets/generated/reports/<plant>.import_report.json`
- Generate: `local_extensions/classic_original_assets/generated/reports/<plant>.composite_report.json`
- Generate: `local_extensions/classic_original_assets/asset_index.json`

- [x] 对 A1 候选生成语义报告，先读报告再写 manifest，不凭植物名猜动画段。
- [x] 对 A1 每株运行 raw import，输出到 `generated/raw/<plant>/`。
- [x] 在 manifest 中为每株写入 `id`、`profile_id`、`raw_actor_scene`、`actor_scene_out_path`、`profile_out_path`、`report_out_path`、`import_report`、`source_reanim`、`source_resources`、`state_animation_map`、`action_animation_map`、`profile_tags`。
- [x] 运行 composite 生成，刷新 `asset_index.json`。
- [ ] 人工打开 A1 actor gallery，校正每株 `ground_offset`；校正值只写入生成后的 profile 或 manifest 可复现字段，不写入展示场景。

**Source map for A1:**

| plant key | source reanim | archetype |
|-----------|---------------|-----------|
| `repeater` | `PeaShooter.reanim`（源树没有独立 `Repeater.reanim`，按原版资源复用处理） | `archetype_original_repeater` |
| `snowpea` | `SnowPea.reanim` | `archetype_original_snowpea` |
| `gatlingpea` | `GatlingPea.reanim` | `archetype_original_gatlingpea` |
| `splitpea` | `SplitPea.reanim` | `archetype_original_splitpea` |
| `puffshroom` | `PuffShroom.reanim` | `archetype_original_puffshroom` |
| `scaredyshroom` | `ScaredyShroom.reanim` | `archetype_original_scaredyshroom` |
| `fumeshroom` | `FumeShroom.reanim` | `archetype_original_fumeshroom` |
| `seashroom` | `SeaShroom.reanim` | `archetype_original_seashroom` |
| `wallnut` | `Wallnut.reanim` | `archetype_original_wallnut` |
| `tallnut` | `Tallnut.reanim` | `archetype_original_tallnut` |
| `pumpkin` | `Pumpkin.reanim` | `archetype_original_pumpkin` |
| `lilypad` | `LilyPad.reanim` | `archetype_original_lilypad` |
| `flowerpot` | `Pot.reanim` | `archetype_original_flowerpot` |

**Validation:**

```powershell
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/reanim_importer/reanim_import_one.gd -- --source-dir res://local_extensions/classic_original_assets/sources/reanim --image-root res://local_extensions/classic_original_assets/sources/reanim --resources res://local_extensions/classic_original_assets/sources/properties/resources.xml --out-dir res://local_extensions/classic_original_assets/generated/reports/semantic
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/reanim_importer/reanim_generate_composites.gd -- --manifest res://local_extensions/classic_original_assets/manifests/reanim_visual_manifest.local.json
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_private_classic_visual_manifest.gd -- --include-classic-original-assets
```

**Rollback risk:** 中。私有包生成物可从 manifest 重建；若某株报告不稳定，先从 manifest 移除该 entry，保留报告作为调查材料。

### Task 3: A1 formal binding 与展示扩展

**Files:**
- Modify: `data/combat/archetypes/plants/archetype_original_*.tres`
- Modify: `scripts/validation/visual_private_classic_archetype_gallery.gd`
- Modify: `scripts/main/original_migrated_plants_battlefield_showcase.gd`
- Modify: `tools/check_original_migrated_plants_on_battlefield_showcase.gd`
- Modify: `scenes/showcase/README.md`
- Modify: `scripts/main/showcase_hub.gd` only if display text changes

- [ ] 为 A1 中已通过 manifest 检查的 archetype 写入 `visual_profile_id = &"classic_original.entity.plant.<plant>.visual"`。
- [ ] 把 `visual_private_classic_archetype_gallery.gd` 调整为按已绑定 archetype 自动分页或滚动展示，避免 20 株以上挤出 800x600 画布。
- [ ] `original_migrated_plants_battlefield_showcase.gd` 保持“原版背景实景样本”定位；若展示超过 9 株，按页面切换或 lane/col 表展示，不恢复手写像素位置。
- [ ] `tools/check_original_migrated_plants_on_battlefield_showcase.gd` 检查 grid-derived position、`ground_offset`、可见纹理和 pack metadata；对不在当前页面的植物不做位置断言。

**Acceptance:**
- A1 已绑定植物在主页面原版植物展示里替换为真实 actor。
- 未绑定植物仍保持占位。
- 实景展示中所有出现的植物按原版 grid 公式对齐。

**Validation:**

```powershell
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_original_plant_showcase_visual_binding.gd -- --include-classic-original-assets
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_original_migrated_plants_on_battlefield_showcase.gd -- --include-classic-original-assets
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/visual_private_classic_archetype_binding_smoke.tres" -ExtraUserArgs "--include-classic-original-assets"
```

**Rollback risk:** 中。单株失败时只移除该 archetype 的 `visual_profile_id` 和 manifest entry，不影响同批其他植物。

### Task 4: 特殊动作 cue 接入规则

**Files:**
- Modify/Create: `local_extensions/classic_original_assets/data/combat/visual_cues/plants/*.tres`
- Modify: `tools/check_original_plant_showcase_visual_binding.gd`
- Modify: `plans/original-plant-protocol-gaps.md` when required rule event is missing
- Modify: `plans/原版图像移植工作文档.md`

- [ ] 对 B 批一次性和延迟动作植物，先确认当前机制是否已经发出可订阅的语义事件，例如 `placement.accepted`、`entity.state_entered`、`combat_action.phase`、`entity.damaged`、`entity.consumed`。
- [ ] 有语义事件时，用私有包 `VisualCueDef` 播放 actor action 或 actor action sequence。
- [ ] 缺少语义事件时，不在 actor 或展示脚本里补战斗逻辑；把缺口写入 `plans/original-plant-protocol-gaps.md`，等待规则层补事件。
- [ ] 对每个新增 cue，在 `tools/check_original_plant_showcase_visual_binding.gd` 增加 visual action log 断言。

**Acceptance:**
- Chomper/Squash 现有 cue 不回退。
- 新增特殊植物 cue 只响应语义事件，不直接查询或修改战斗结果。
- 视觉 action 缺失时记录视觉失败，不影响 validation 的战斗事件。

**Validation:**

```powershell
./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_original_plant_showcase_visual_binding.gd -- --include-classic-original-assets
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/plant_original_squash_validation.tres" -ExtraUserArgs "--include-classic-original-assets"
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/plant_original_squash_no_immediate_damage_validation.tres" -ExtraUserArgs "--include-classic-original-assets"
pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/plant_original_squash_locked_impact_position_validation.tres" -ExtraUserArgs "--include-classic-original-assets"
```

**Rollback risk:** 中。cue 可按文件级禁用或移除；不得为了保留 cue 修改战斗结算。

### Task 5: 每批收口与文档账本

**Files:**
- Modify: `plans/original-plant-visual-bulk-migration-plan.md`
- Modify: `plans/原版图像移植工作文档.md`
- Modify: `plans/original-plant-migration-ledger.md` only when visual status is added as a separate column or appendix
- Modify: `plans/README.md`

- [ ] 每批完成后记录：source reanim、raw actor、composite profile、formal binding、visual cue、validation 结果。
- [ ] 对失败植物记录停在哪一层，不能把“源素材存在”写成“runtime 已迁移”。
- [ ] 如果某批引入新的协议缺口，更新 `plans/original-plant-protocol-gaps.md`，并在本方案的批次表里标记为 blocked-by-protocol。
- [ ] 保持 `plans/README.md` 中本文件为“当前执行/维护”，直到所有已选择批次完成并归档。

**Acceptance:**
- 文档能回答每株植物处在五层迁移中的哪一层。
- 新增 profile 的数量、manifest entries 数量、formal binding 数量互相可解释。
- 验证命令和结果记录到文档，不只停留在聊天结论。

**Validation:**

```powershell
git diff --check
```

**Rollback risk:** 低。文档更新可独立回滚。

## 依赖顺序

1. 先完成 Task 1，让检查入口从 5 株硬编码升级为可随 manifest 扩展。
2. 再执行 Task 2，生成 A1 私有包资源。
3. A1 每株通过 manifest 检查后，执行 Task 3 绑定到正式 archetype。
4. B/C 批只在 A1 流程稳定后推进；特殊动作必须走 Task 4。
5. 每批结束执行 Task 5，再决定下一批。

## 验证矩阵

| 验证目标 | 命令 | 通过标准 |
|----------|------|----------|
| 私有包启用与索引解析 | `./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_private_classic_asset_pack.gd -- --include-classic-original-assets` | 所有 manifest/profile/index/actor/source 检查通过 |
| manifest 批量一致性 | `./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_private_classic_visual_manifest.gd -- --include-classic-original-assets` | manifest、asset_index、profile、actor、source reanim 数量一致 |
| 主页面原版植物绑定 | `./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_original_plant_showcase_visual_binding.gd -- --include-classic-original-assets` | 已绑定为真实 actor，未绑定仍为占位，特殊 cue 日志符合预期 |
| 原版背景实景展示 | `./Godot_v4.6.1-stable_win64_console.exe --headless --path . --script res://tools/check_original_migrated_plants_on_battlefield_showcase.gd -- --include-classic-original-assets` | 背景和展示植物按原版 grid + `ground_offset` 对齐 |
| local_private validation | `pwsh tools/run_all_validations.ps1 -Layers "local_private" -MaxParallel 1` | local_private 层全部通过 |
| 相邻战斗回归 | `pwsh tools/run_validation.ps1 -Scenario "res://scenes/validation/visual_private_classic_archetype_binding_smoke.tres" -ExtraUserArgs "--include-classic-original-assets"` | 已绑定 archetype 均挂载私有 profile actor |
| diff hygiene | `git diff --check` | 无空白错误 |

## Definition of Done

每个批次完成必须满足：

- 批次内每株植物明确标记为 `source`、`raw_actor`、`composite_profile`、`formal_binding`、`visual_cue` 中的最高完成层级。
- 所有 formal binding 都能通过 `AssetRegistry.resolve_visual_profile()` 解析到私有包 profile。
- 所有 formal binding 都在主页面或 gallery 中显示真实 actor。
- 实景展示中的植物不使用手写像素偏移，位置来自原版 grid 公式和 profile `ground_offset`。
- 特殊动作只由语义事件驱动 visual cue，不改变战斗结算。
- `vendor/out_files/` 没有进入 git diff。
- `local_private` 验证、相关 check 脚本和 `git diff --check` 通过。
- 本方案、原版图像移植工作文档或迁移底账记录了本批结果。

## 归档规则

- 本文件在批量迁移期间登记为 `plans/README.md` 的“当前执行/维护”。
- 当普通批次和特殊批次都完成，且长期事实已合并进 `plans/original-plant-migration-ledger.md` 或 wiki 后，将本文件移入 `plans/archive/`。
- `plans/原版图像移植工作文档.md` 保留为工作底稿和历史材料；本文件作为批量执行方案，不替代该工作文档中的调查细节。
