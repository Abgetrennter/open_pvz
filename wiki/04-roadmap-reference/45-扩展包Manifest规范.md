# 扩展包 Manifest 规范

- 状态：正式设计
- 提升日期：2026-05-17
- 来源草案：`plans/draft/extension-system/41-扩展包-manifest-规范-v1.md`
- 配套阅读：[扩展系统总体规划](38-扩展系统总体规划.md)、[扩展包边界与依赖规则](43-扩展包边界与依赖规则.md)、[素材包系统与本地私有包](44-素材包系统与本地私有包.md)、[通用扩展插槽机制](42-通用扩展插槽机制.md)

---

## 一句话结论

扩展包 manifest 是平台层元信息协议，用来声明包身份、类型、发布策略、依赖、信任级别、入口和能力。当前加载器只实现了最小兼容字段；正式规范在兼容当前代码的基础上，明确后续演进目标。

---

## 当前兼容字段

当前 [extension_pack_catalog.gd](../../scripts/core/runtime/extension_pack_catalog.gd) 已支持：

```json
{
  "pack_id": "my_pack",
  "enabled_by_default": false,
  "register": ["resources"],
  "trust_level": "data_only",
  "capabilities": ["resources"],
  "activation_cli_flags": [],
  "activation_scenario_ids": []
}
```

当前有效 `trust_level`：

```text
data_only
rule_extended
trusted_runtime
```

当前有效 `register`：

```text
resources
effects
projectile_movement
mechanic_compilers
triggers
detections
controllers
visual_cues
visual_fx
audio_cues
visual_profiles
```

短期新增包必须继续使用这些字段，避免和当前加载器脱节。

---

## 正式通用字段

正式 manifest 目标字段：

```json
{
  "pack_id": "classic_original_assets",
  "pack_type": "asset_pack",
  "version": "0.1.0",
  "display_name": "Classic Original Assets",
  "description": "Local private asset pack generated from user-owned original resources.",
  "author": "local",
  "license": "local_private",
  "namespace": "classic_original",
  "trust_level": "data_only",
  "publish_policy": "local_private",
  "contains_original_assets": true,
  "generated_from_private_source": true,
  "compatible_core_version": ">=0.1.0",
  "dependencies": [],
  "optional_dependencies": [],
  "conflicts": [],
  "enabled_by_default": false,
  "load_priority": 100,
  "register": ["visual_profiles", "visual_cues", "visual_fx", "audio_cues"],
  "capabilities": ["visual_profiles", "visual_cues", "visual_fx", "audio_cues"],
  "entry_points": {
    "visual_root": "data/combat",
    "asset_index": "asset_index.json"
  },
  "tags": ["classic", "local_private"],
  "metadata": {}
}
```

字段分组：

| 分组 | 字段 |
|------|------|
| 身份 | `pack_id`、`pack_type`、`version`、`display_name`、`description`、`author`、`license` |
| 边界 | `namespace`、`trust_level`、`publish_policy`、`capabilities` |
| 私有素材 | `contains_original_assets`、`generated_from_private_source` |
| 兼容与依赖 | `compatible_core_version`、`dependencies`、`optional_dependencies`、`conflicts` |
| 加载 | `enabled_by_default`、`load_priority`、`register`、`entry_points`、`activation_cli_flags`、`activation_scenario_ids` |
| 扩展 | `tags`、`metadata` |

---

## pack_type

正式包类型：

```text
rule_pack
content_pack
asset_pack
collection_pack
```

兼容说明：

- 当前加载器尚未强制 `pack_type`。
- 新包应主动填写。
- 旧包可由 `register` 粗略推导，但不建议长期依赖推导。

---

## trust_level

正式规范采用当前代码中的信任级别，避免草案与实现分裂：

| trust_level | 说明 |
|-------------|------|
| `data_only` | 只能注册纯数据资源和素材资源 |
| `rule_extended` | 可注册受控规则扩展 |
| `trusted_runtime` | 可注册运行时代码能力，如 movement、compiler、controller |

当前 registry 会按 `RegistryConfig.required_trust` 拒绝信任级别不足的包。

---

## publish_policy

正式新增发布策略字段：

| publish_policy | 说明 |
|----------------|------|
| `public` | 可提交、可发布、可被 CI 默认消费 |
| `local_private` | 本机私有，默认 ignored，不进入发布物 |

规则：

- 缺失时默认为 `public`。
- `contains_original_assets == true` 时必须为 `local_private`。
- `generated_from_private_source == true` 时必须为 `local_private`，除非派生产物明确可发布。
- `collection_pack` 依赖任何 `local_private` 包时，自己也应为 `local_private`。
- 项目级 debug 开关只能改变本机开发期加载行为，不能改变 manifest 的发布策略；例如 `openpvz/debug/enable_classic_original_assets` 只允许让本机 `classic_original_assets` 默认可见，包本身仍必须保持 `local_private` 与 `enabled_by_default = false`。

---

## entry_points

`entry_points` 是后续完整加载器的主要入口字段。

建议：

```json
{
  "entry_points": {
    "content_root": "data/combat",
    "validation_root": "scenes/validation",
    "visual_root": "data/combat",
    "asset_index": "asset_index.json",
    "collection_index": "collection.json"
  }
}
```

当前过渡期：

- RegistryBase 仍按各自 `RegistryConfig.extension_dir` 扫描。
- `entry_points` 可以先写入 manifest，作为未来 loader 和校验器输入。
- 不要用 `entry_points` 替代现有 `register`，两者在过渡期并存。

---

## asset_index

`asset_pack` 后续应提供 `asset_index`：

```json
{
  "entity.plant.peashooter.visual": "data/combat/visual_profiles/plants/peashooter.tres",
  "vfx.jalapeno.lane_fire": "data/combat/visual_fx/jalapeno_lane_fire.tres",
  "sfx.projectile.pea.hit": "audio/pea_hit.ogg",
  "card.plant.peashooter.icon": "ui/cards/peashooter.png"
}
```

当前最小 `AssetRegistry` 已启用 `visual_profile` 解析，但 `visual_profiles` 等现有 slot 注册仍保留为兼容和回退路径。

原版私有素材包当前采用 `openpvz.asset_index.v1` 过渡格式：`assets` 保存正式逻辑 ID 条目，`visual_profiles` 保留为兼容字段。条目至少包含 `kind`、`path`，视觉条目可附带 `actor_scene`、`source`、`generated` 和 `semantic` 元数据。该索引由 `AssetIndexCatalog` 读取，由 `AssetRegistry.resolve_visual_profile()` 作为运行时入口消费。

---

## dependencies

建议第一版使用字符串数组：

```json
{
  "dependencies": ["openpvz_classic_content", "classic_original_assets"],
  "optional_dependencies": ["openpvz_placeholder_assets"]
}
```

约束：

- `rule_pack` 不依赖 `content_pack`。
- `content_pack` 可以依赖 `rule_pack`。
- `asset_pack` 不依赖具体内容文件路径。
- `collection_pack` 可以依赖前三类包。
- 依赖 `local_private` 包的 collection 默认也是 `local_private`。

---

## register 与 capabilities

`register` 表示包希望当前 loader 扫描哪些 slot。

`capabilities` 表示包声明自己提供哪些能力。

当前 `RegistryBase._pack_allows_slot()` 要求 capabilities 包含对应 register kind 或 slot id，因此两者都要填。

示例：

```json
{
  "register": ["visual_profiles", "visual_fx"],
  "capabilities": ["visual_profiles", "visual_fx"]
}
```

未来可以增加更语义化 capability，例如 `asset.visuals`，但短期不能替代当前 register kind。

---

## 本地原版素材包示例

```json
{
  "pack_id": "classic_original_assets",
  "pack_type": "asset_pack",
  "version": "0.1.0",
  "display_name": "Classic Original Assets",
  "namespace": "classic_original",
  "trust_level": "data_only",
  "publish_policy": "local_private",
  "contains_original_assets": true,
  "generated_from_private_source": true,
  "enabled_by_default": false,
  "register": ["visual_profiles", "visual_cues", "visual_fx", "audio_cues"],
  "capabilities": ["visual_profiles", "visual_cues", "visual_fx", "audio_cues"],
  "activation_cli_flags": ["--include-classic-original-assets"],
  "entry_points": {
    "visual_root": "data/combat",
    "asset_index": "asset_index.json"
  },
  "tags": ["classic", "local_private"]
}
```

当前开发期 `project.godot` 默认打开 `openpvz/debug/enable_classic_original_assets = true`，用于让主页面和 showcase 直接消费本机私有原版素材。该开关不属于 manifest，发布前应关闭；显式 CLI 启用仍保留为可复现验证入口。

---

## 校验规则

正式校验器应覆盖：

- `pack_id` 非空。
- `register` 只包含允许值。
- `trust_level` 是当前支持值。
- `capabilities` 包含每个 register kind。
- 外部包不得注册 `core.*`。
- `publish_policy` 合法。
- `contains_original_assets` 或 `generated_from_private_source` 为 true 时，`publish_policy` 必须为 `local_private`。
- `public` 包不得引用 `vendor/out_files` 或 `local_extensions`。
- `asset_pack` 不应声明规则脚本入口。
- `content_pack` 不应声明真实素材正文。
- `collection_pack` 不应包含大量内容或素材正文。

---

## 兼容路线

1. 当前继续支持最小 `extension.json`。
2. 新包开始填写 `pack_type`、`namespace`、`publish_policy`、`entry_points`。
3. 加载器逐步读取 `local_extensions`、`dependencies`、`load_priority`。
4. `AssetRegistry` 已先落地 `visual_profile` 最小解析；后续再扩展 `asset_index` 的主题覆盖、音频、FX 和包依赖策略。
5. `collection_pack` 落地后启用 `collection_index` 和包组合入口。
