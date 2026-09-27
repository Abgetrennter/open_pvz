# 执行计划：reanim-native-full-original-plant-migration-plan.md

## 决策与范围

**范围 = M0 全量 + 驱动 M1 第一批简单单部件植物到"生成 + local_private 验证通过 + demo 目测"。** Godot 4.6.1 已确认可在 `E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe` headless 运行，生成与验证全部可执行。

依赖顺序遵循计划：`M0 -> M1 -> M2 -> M3 -> M4 -> M5`。本轮目标定为 **M0 收口 + M1 推进到首批可目测**。后续 M1 余下批次、M2/M3/M4/M5 作为后续会话，理由见"不在本轮范围"。

## 关键事实（已核验）

- **Godot 可用**：`/e/SDK/Godot/Godot_v4.6.1-stable_win64_console.exe --headless --version` → `4.6.1.stable.official...`（exit 0）。
- **48 archetype / 18 已迁移 / 30 待迁移**：blover, cabbagepult, cactus, cattail, cherrybomb, cobcannon, coffeebean, doomshroom, garlic, gloomshroom, goldmagnet, gravebuster, hypnoshroom, iceshroom, jalapeno, kernelpult, magnetshroom, marigold, melonpult, plantern, potatomine, spikerock, spikeweed, starfruit, sunshroom, tanglekelp, torchwood, twinsunflower, umbrellaleaf, wintermelon。
- **三株非直觉源名**：kernelpult→`Cornpult.reanim`、spikeweed→`Caltrop.reanim`（flowerpot→`Pot.reanim` 已迁移）。
- **生成两阶段**：Stage A `reanim_import_one.gd --reanim-data-only true` 出 `reanim_data.tres`；Stage B `reanim_generate_composites.gd --native-only true --only <id>` 据 manifest `native` 块出 `actor_def.tres`+`actor.tscn`+`native_report.json`。
- **`root_offset` 无法从源数据自动推导**：原版 `.reanim`/`resources.xml`/`reanim_data` 均无偏移字段；原版定位是 C++ `switch(SeedType)`（`vendor/de-pvz/Lawn/Plant.cpp:3569-3705`），仅约 9 个种子有 Y 微调，X 永远由 sprite 几何运行时决定。18 株现值来自"逐帧可见 AABB 推导 + 逐株目测校准"（`reanim-native-runtime-implementation-plan.md:399`）。→ **M1 每株需目测校准**，但可先用 AABB 启发式给种子值。
- **`run_reanim_native_generate.ps1` 有硬编码坏路径**（`:2-4` 指向 `C:\Users\Administrator\Documents\open-pvz\...`），本轮修复。
- semantic report 含 `suspected_attachment_count`/`blend_modes_seen`/`overlay_binding_count`/`suspected_overlay_count`/`angle_warning_count`/`unresolved_layer_count`/`animations`(clip 名+帧) / `track_summaries`(逐轨名) / `overlay_bindings` 等丰富逐项，足够支撑分类。
- `local_private` 验证层 = 10 场景（数据导入/原生运行时/仿真时钟/角度/渲染顺序/threepeater 组合/blink 覆盖/chomper 角度/包冒烟/archetype 绑定），全部带 `--include-classic-original-assets`。

## 任务

### M0-1 扩展 `tools/scan_reanim_feature_flags.ps1`

- 加 `[string]$Roster`（值：`original_plants`/`manifest`，默认 `manifest` 保持兼容）。
- 修正 `-Root` 默认为 `$PSScriptRoot/../local_extensions/classic_original_assets`（去掉他人主机路径）。
- `-Roster original_plants`：扫 `data/combat/archetypes/plants/archetype_original_*.tres` 得 48 株清单；内嵌 id→源文件名映射（含 Cornpult/Caltrop）；逐株定位 `sources/reanim/<>.reanim` 与 semantic report，**缺源/无报告显式标 BLOCKER 不静默跳过**；输出多一列 `migrated`(yes/pending)。
- 保持原 `manifest` 输出不变。

### M0-2 修复 `tools/run_reanim_native_generate.ps1`

把 `$Godot`/`$Project` 两行硬编码改为复用 `run_validation.ps1` 一致的 fallback 链（`$env:GODOT_BIN` → 项目根 `Godot_v*_win64_console.exe` → `Get-Command godot` → 报错），并支持 `-GodotExe`/`-Project` 覆盖。验证用：`-GodotExe "E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe"`。

### M0-3 冻结 30 株候选矩阵 `plans/reanim-native-migration-candidate-migration-matrix.md`

逐株登记：plant id / source .reanim / semantic flags（来自 M0-1 扫描）/ states&actions 候选（来自 `animations` clip 名）/ overlay&host-track 候选（来自 `suspected_overlays`/`overlay_bindings`/`track_summaries`）/ 批次建议（M1/M2/M3）/ 阻塞项（attacher>0 或 blend 或 text/font 或 unresolved_layer>0 → M3 BLOCKER）。按批次排序，末尾给汇总：M1 候选清单、M2 候选清单、M3 Spike 清单（每种缺口选一代表样本）。

> 用 `-Roster original_plants` 的实际扫描输出填充 flags 列，确保每株分类有据、不臆断。

### M1-1 写 `root_offset` AABB 种子工具（降低目测成本）

新增 `tools/reanim_importer/reanim_seed_root_offset.gd`（headless SceneTree 脚本）：对给定 `reanim_data.tres`，按逐帧可见 sprite 像素计算并集 AABB，输出 bottom-center 偏移作为种子 `root_offset`；对命中 `Plant.cpp:3569-3705` 已知 Y 微调的 9 个种子（flowerpot/lilypad/seashroom/pumpkin/puffshroom/scaredyshroom/coffeebean/gravebuster/spikeweed/spikerock）叠加 vendor 常数修正。打印建议值供写 manifest。**不自动改写 manifest**（保留人审）。

### M1-2 选首批 M1 简单单部件批（6-8 株，来自矩阵）

从矩阵的 M1 候选取首批：倾向于无 attacher/blend/text/font/overlay、单 body part 足以表达 idle/action 的株（典型：spikeweed, potatomine, garlic, plantern, coffeebean, gravebuster, starfruit, magnetshroom 等中选，**以矩阵扫描结果为准**）。

### M1-3 为首批每株：写 manifest `native` 块 + 生成 + 目测校准

对每株：
1. 跑 Stage A：`run_reanim_data_import.ps1 -Samples "<id>" -GodotExe ...`（先把该 id 加进 `SourceBySample` 表）。
2. 跑 M1-1 种子工具得 `root_offset` 候选。
3. 在 manifest 加 `native` 块（参照 pumpkin/flowerpot 最小模板：单 body part、states{idle}/actions、`root_offset` 种子值、必要 anchors）。
4. 跑 Stage B：`run_reanim_native_generate.ps1 -Ids "<id>" -GodotExe ...` 出 native 三件套。
5. demo 目测校准 `root_offset`/anchors，必要时回写 manifest 重生成。

### M1-4 首批验证

```
pwsh tools/run_all_validations.ps1 -Layers "local_private" -MaxParallel 1 -GodotExe "E:\SDK\Godot\Godot_v4.6.1-stable_win64_console.exe"
```
确保 10 场景全过（含 `check_private_classic_visual_manifest.gd` 五方一致性）。首轮不下调公开 smoke/guardrail（首批未绑定 archetype，公开层不受影响）。

### M1-5 扩展 demo 覆盖首批（可选，便于目测）

把首批 id 加进 `scripts/validation/visual_reanim_native_actual_demo.gd` roster（改 layout 到能容纳更多格，或只新增行），便于一次性目测。demo 为非验证脚本，改动安全。

### 收口文档

更新 `plans/reanim-native-full-original-plant-migration-plan.md`：勾选 M0 验收项 + 链接矩阵；M1 节记录首批完成株与残留。`plans/README.md` 登记矩阵文件。

## 不在本轮范围（明确排除）

- ❌ M1 余下批次（首批之后）；M2（body+head/blink/host-track 等组合）、M3（attacher/blend/text/font 真实 Spike）、M4（48 archetype `visual_profile_id` 正式绑定 + 公开 smoke/guardrail）、M5（文档归档）。
- ❌ 任何冻结协议变更、registry slot、植物专用 GDScript（符合计划 §2）。
- ❌ 改公开扩展发布边界内容；产物只在 `local_extensions/classic_original_assets`（git-ignore 嵌套仓）。

## 验收（本轮 DoD）

- [ ] `scan_reanim_feature_flags.ps1` 支持 `-Roster original_plants`，`-Root` 默认修正，输出覆盖 48 株并区分 18/30。
- [ ] `run_reanim_native_generate.ps1` 硬编码路径替换为 fallback 链。
- [ ] `plans/reanim-native-migration-candidate-matrix.md` 30 株全分类 + 批次 + 阻塞。
- [ ] `reanim_seed_root_offset.gd` 工具产出可用种子值。
- [ ] 首批 6-8 株：manifest `native` 块 + native 三件套生成 + `local_private` 10 场景全过 + demo 目测无明显落点错误。
- [ ] 计划 M0 勾选 + README 登记。

## 风险与缓解

- **目测校准是瓶颈**：M1-1 AABB 种子工具 + vendor Y 常数把每株从"纯肉眼"降到"确认/微调"；首批控制在 6-8 株，避免单会话过载。
- **某株命中 M3 能力缺口**：矩阵扫描若发现 attacher/blend/text/font，标 BLOCKER 归 M3，本轮不实现（符合计划"M3 不阻塞现有能力可迁移内容"+"无真实样本能力不实现"）。
- **某首批株实际需 host-track/blink（属 M2）**：若矩阵候选与实测冲突，把该株降级到 M2，从首批剔除，记录在矩阵。
- **三株非直觉源名**：脚本内嵌映射表 + 矩阵双重标注，避免找不到源。
- **嵌套私有仓 git 状态**：`local_extensions/classic_original_assets` 是独立 git 仓；产物提交按既有 18 株的私有包提交惯例处理（本轮默认不自动提交，生成产物落盘即可）。