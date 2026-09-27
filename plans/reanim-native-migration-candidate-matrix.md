# Reanim 原生迁移候选矩阵（30 株待迁移）

> 状态：M0 冻结
>
> 制定日期：2026-08-01
>
> 上游计划：[`plans/reanim-native-full-original-plant-migration-plan.md`](reanim-native-full-original-plant-migration-plan.md)
>
> 数据来源：`tools/scan_reanim_feature_flags.ps1 -Roster original_plants`（48 株扫描）+ `local_extensions/classic_original_assets/generated/reports/semantic/<Source>.semantic_report.json`（逐株 clip / track / overlay 明细）
>
> 基线：48 个 `archetype_original_*` 植物中，18 株已进私有 manifest（native 块）。本矩阵覆盖剩余 30 株。

## 1. 关键结论

- **全部 30 株都有源 `.reanim` + semantic report**，无缺源阻塞。
- **没有任何一株命中真实 M3 能力缺口**：`blend_modes_seen` 全空、无 `text/font`、`unresolved_layer_count` 全为 0。`BLOCKERS (M3) = 0`。
  - 注：`suspected_attachment_count > 0`（11 株含已迁移的 peashooter/chomper/threepeater）与 `overlay_binding_count > 0`（42 株）**不是** M3 阻塞——18 株已迁移植物常规携带这些计数值，由现有 `host_part_id`/`host_track`/`track_visibility`/blink-overlay 能力吸收。故 `attacher`/`overlay` 计数仅作信息列，不进批次门禁。
- **M3 暂为空集**；若实测阶段发现某株确需 attacher/blend 等真实能力，按计划补 fail-closed + 代表样本 Spike，不阻塞其余株。

## 2. 批次分类规则

| 批次 | 判据 | 复用模式 |
|------|------|----------|
| **M1** 单 body part | 无 `blink` 轨、无 `anim_face` 轨；clips 可由 states/actions 直接表达 | pumpkin / flowerpot / seashroom（单 body） |
| **M2** 通用组合 | 含 `blink` 和/或 `anim_face`（blink overlay + face host），或 pea-family body+head host-track，或 pult body+blink | sunflower blink-overlay / wallnut / pea family host-track / threepeater |
| **M3** 真实能力缺口 | blend / text/font / unresolved_layer > 0（**当前 0 株**） | — |

蘑菇（含 sleep）株复用 puffshroom/fumeshroom 模式（`sleeping=body:sleep` 状态 + body+blink 双 part）。一次性株（explode/grab/land）复用 chomper `action_next_states` 模式。

## 3. 30 株候选矩阵

### M1 — 单 body part 简单批（6 株，首批目标）

均无 blink/face 轨；单 body part；clips 直接映射 states/actions。

| # | plant id | source .reanim | clips (marker) | 建议 states | 建议 actions | 备注 / 蘑菇 |
|---|----------|----------------|----------------|-------------|--------------|-------------|
| 1 | cherrybomb | Cherrybomb.reanim | `explode`,`idle` | idle | explode(→idle) | 一次性爆炸；`action_next_states` explode→idle |
| 2 | doomshroom | Doomshroom.reanim | `sleep`,`explode`,`idle` | idle, sleeping | explode(→idle) | 蘑菇；一次性爆炸；sleep 状态 |
| 3 | coffeebean | Coffeebean.reanim | `idle`,`twitch`,`crumble` | idle | twitch, crumble | 最简单；仅 2 轨 |
| 4 | gravebuster | Gravebuster.reanim | `land`,`idle` | idle | land(→idle) | 一次性落地；`action_next_states` land→idle |
| 5 | hypnoshroom | Hypnoshroom.reanim | `idle`,`sleep` | idle, sleeping | — | 蘑菇；无 blink（纯 body） |
| 6 | blover | Blover.reanim | `idle`,`loop`,`blow` | idle | blow(→idle), loop? | `loop` clip 语义待实测确认（可能持续吹风）；angle_warning=78 需 demo 目测 |

> 首批 M1 执行：建议先做 cherrybomb / coffeebean / gravebuster / hypnoshroom 4 株（最简单、无 angle 警告），blover 与 doomshroom 因 angle_warning/爆炸幅度略复杂，作为首批尾巴或并入第二批。

### M2 — 通用组合批（24 株）

含 `blink` 和/或 `anim_face`，需 body + blink-overlay 双 part（blink hosted on `anim_face`）；部分还需 head/face host-track 或为 shooter/pult。

#### M2-a 蘑菇 blink 批（6 株，复用 puffshroom/fumeshroom）

| # | plant id | source .reanim | clips | 建议 states | 备注 |
|---|----------|----------------|-------|-------------|------|
| 7 | gloomshroom | GloomShroom.reanim | blink,idle,sleep,shooting,face | idle, sleeping, attacking | 蘑菇；body+blink(anim_face)；shooting action |
| 8 | iceshroom | IceShroom.reanim | idle,sleep,face,blink | idle, sleeping | 蘑菇；body+blink；一次性冰冻（无 explode clip，靠 sleep？待实测） |
| 9 | magnetshroom | Magnetshroom.reanim | blink,idle,nonactive_idle,shooting,sleep,nonactive_idle2,face,eyes,eyes2,eyes22 | idle, sleeping, nonactive, attacking | 蘑菇；clip 最多；多 eyes 轨（track_visibility 排除） |
| 10 | sunshroom | SunShroom.reanim | bigsleep,bigidle,grow,sleep,idle,face,blink | idle, bigidle, sleeping, growing | 蘑菇；`grow` 一次性（grow→bigidle action_next_states） |
| 11 | spikeweed | Caltrop.reanim | attack,idle,face,blink | idle, attacking | 非 mushroom 名但无 sleep clip；body+blink(anim_face)；近地 |
| 12 | spikerock | SpikeRock.reanim | blink,idle,attack,face,eye_leftbrow,eye_rightbrow | idle, attacking | spike 升级版；angle_warning=36 |

#### M2-b shooter / pult blink 批（9 株，body + blink/face + shooting action）

| # | plant id | source .reanim | clips | 建议 states/actions | 备注 |
|---|----------|----------------|-------|---------------------|------|
| 13 | cabbagepult | Cabbagepult.reanim | blink,idle,shooting,face | idle, attacking / shooting | pult；basket/stalk/cabbage 轨；blink+eyebrow hosted anim_face；`muzzle`/发射锚点 |
| 14 | kernelpult | Cornpult.reanim | blink,idle,shooting,full_idle,face | idle, attacking / shooting | 源名 Cornpult；butter/husk 轨；发射锚点 |
| 15 | melonpult | Melonpult.reanim | blink,idle,shooting,face | idle, attacking / shooting | pult；melon/stalk/basket 轨 |
| 16 | wintermelon | WinterMelon.reanim | blink,idle,shooting,face | idle, attacking / shooting | melonpult 变体 |
| 17 | cactus | Cactus.reanim | blink,idle,shooting,rise,idlehigh,shootinghigh,lower,face | idle, idlehigh, attacking, attackinghigh + rise/lower actions | 双高度（rise/lower 切换 idlehigh）；最复杂 shooter |
| 18 | starfruit | Starfruit.reanim | blink,idle,shoot,face | idle, attacking / shoot | face host；多向射击锚点 |
| 19 | cattail | Cattail.reanim | blink,idle,shooting,face | idle, attacking / shooting | 双向射击锚点（左右） |
| 20 | goldmagnet | GoldMagnet.reanim | blink,idle,attract,face | idle / attract action | 磁吸 action（非射击） |
| 21 | cobcannon | CobCannon.reanim | unarmed_idle,idle,shooting,charge,blink,face | idle, unarmed, attacking + charge action | 多状态（unarmed/armed）；较复杂 |

#### M2-c 简单 face/blink 支持类（9 株，body + blink/face，非 shooter）

| # | plant id | source .reanim | clips | 备注 |
|---|----------|----------------|-------|------|
| 22 | garlic | Garlic.reanim | blink,idle,face | body+blink(anim_face) |
| 23 | plantern | Plantern.reanim | idle,blink,face | body+blink；照亮（一次性？） |
| 24 | torchwood | Torchwood.reanim | idle,blink,face | body+blink；增强桩 |
| 25 | marigold | Marigold.reanim | idle,blink,face | body+blink；产阳光 |
| 26 | twinsunflower | TwinSunflower.reanim | blink,blink2,idle,face2,face | 双 face/blink（track_visibility 处理 face2/blink2） |
| 27 | jalapeno | Jalapeno.reanim | blink,idle,explode | body+blink；一次性 explode→idle |
| 28 | umbrellaleaf | Umbrellaleaf.reanim | blink,idle,block,face | body+blink；block action（挡投掷） |
| 29 | tanglekelp | Tanglekelp.reanim | blink,idle,grab,idle_aquarium,face,waterline | 水生；waterline 轨；grab 一次性（grab→idle） |
| 30 | potatomine | Potatomine.reanim | armed,rise,idle,blink,mashed,face,eye,light,glow | 多状态（armed/unarmed/mashed）；rise 一次性；clip 最多之一 |

### M3 — 真实能力缺口（0 株）

无。`blend_modes_seen` / `text` / `font` / `unresolved_layer` 全部为 0。若 M1/M2 实测发现真实缺口，按计划在此登记代表样本 Spike（每种缺口选一株），并先补 fail-closed 与专项验证。

## 4. 三株非直觉源名映射（脚本与矩阵双重标注）

| archetype id | 源 .reanim | 原因 |
|--------------|-----------|------|
| kernelpult | Cornpult.reanim | 原版 kernel-pult 内部名 Cornpult |
| spikeweed | Caltrop.reanim | 原版 spikeweed 内部名 Caltrop |
| twinsunflower | TwinSunflower.reanim | 中间大写 S（Capitalize 首字母启发式需 override） |

（已迁移的 flowerpot→Pot、repeater→PeaShooter、peashooter→PeaShooterSingle 同属此类，仅作参照。）

## 5. 建议执行顺序

1. **M1 首批（本轮）**：cherrybomb, coffeebean, gravebuster, hypnoshroom（4 株最简单，无 angle 警告，无 blink/face）。
2. **M1 尾**：blover, doomshroom。
3. **M2-a 蘑菇 blink**：gloomshroom, iceshroom, sunshroom, magnetshroom, spikeweed, spikerock。
4. **M2-b shooter/pult**：cabbagepult → kernelpult → melonpult → wintermelon（pult 族可连续复用）；再 cactus, starfruit, cattail, goldmagnet, cobcannon。
5. **M2-c 支持类**：garlic, plantern, torchwood, marigold, twinsunflower, jalapeno, umbrellaleaf, tanglekelp, potatomine。
6. **M3**：当前空；视实测。

每批完成后跑 `local_private`（10 场景）+ demo 目测；M4 时统一绑定 48 archetype `visual_profile_id` 并跑公开 smoke/guardrail。

## 6. 已知 angle_warning（信息项，非阻塞）

`angle_warning_count` 较高的株（demo 目测需留意帧间旋转连续性，但 chomper=455 已迁移证明可吸收）：blover=78, spikerock=36, hypnoshroom=22, cherrybomb=24, gravebuster=11。其余 ≤ 5 或 0。

## 7. 数据复现命令

```powershell
pwsh tools/scan_reanim_feature_flags.ps1 -Roster original_plants
```

输出 48 株总表（18 yes / 30 pending）+ 汇总（BLOCKERS=0）。本矩阵 §3 的 clip 列由各 `<Source>.semantic_report.json` 的 `animations` 字段导出。
