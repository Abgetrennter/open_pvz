# 扩展包 manifest 规范-v1

> 这份文档用于把 [扩展系统总体规划](../../../wiki/04-roadmap-reference/38-扩展系统总体规划.md)、[素材包系统设计草案](39-素材包系统设计草案.md) 和 [扩展包边界与依赖规则-v1](40-扩展包边界与依赖规则-v1.md) 中已经达成的共识，进一步收敛成统一的 manifest 规范。它回答的不是“当前最小 `extension.json` 里有什么字段”，而是“后续四类核心包应共享哪些元字段、不同包类型还需要哪些专属字段，以及加载器和校验器应如何围绕这份规范演进”。

---

## 文档定位

这篇文档主要回答：

- 统一 manifest 为什么现在必须正式化
- manifest 的通用字段应包含什么
- `content_pack / asset_pack / rule_pack / collection_pack` 分别需要哪些专属字段
- `trust_level`、`dependencies`、`entry_points`、`capabilities` 应如何表达
- 当前最小 `extension.json` 与未来规范是什么关系
- 后续加载器和校验器应按什么顺序演进

这篇文档不负责：

- 直接实现新的加载器
- 直接定义安装器 UI
- 代替具体 pack 内部目录模板
- 代替集合包工作流文档

配套阅读建议：

- [扩展系统总体规划](../../../wiki/04-roadmap-reference/38-扩展系统总体规划.md)
- [素材包系统设计草案](39-素材包系统设计草案.md)
- [扩展包边界与依赖规则-v1](40-扩展包边界与依赖规则-v1.md)
- [扩展与数据包](11-扩展性与社区生态.md)

---

## 一句话结论

当前建议正式把扩展包 manifest 理解成：

> 平台层的统一元信息协议，用来声明包的类型、边界、依赖、信任级别、命名空间、入口和兼容性，而不是一份“告诉扫描器去哪找目录”的简化配置。

---

## 当前最小 `extension.json` 的定位

当前仓库已经有最小版 `extension.json`，例如：

- [minimal_chaos_pack/extension.json](../../extensions/minimal_chaos_pack/extension.json)
- [phase5_chaos_pack/extension.json](../../extensions/phase5_chaos_pack/extension.json)
- [phase5_guardrail_pack/extension.json](../../extensions/phase5_guardrail_pack/extension.json)

当前字段主要只有：

- `pack_id`
- `enabled_by_default`
- `register`
- 可选 `activation_*`

这份格式在当前阶段是有价值的，因为它完成了：

- 最小扫描
- 最小启用
- 最小 smoke test

但如果后续要正式承接：

- `content_pack`
- `asset_pack`
- `rule_pack`
- `collection_pack`

那么这份最小格式已经不够表达：

- 包类型
- 信任级别
- 依赖关系
- 命名空间
- 入口类型
- 素材索引
- 集合包装配关系

所以当前建议是：

> 保留现有 `extension.json` 作为过渡格式，同时把本页定义的 manifest 规范作为后续主设计目标。

---

## manifest 的设计目标

统一 manifest 规范至少要同时服务下面 6 个目标：

1. 标识“这是什么包”
2. 标识“它能做什么”
3. 标识“它依赖谁”
4. 标识“它能开放到什么程度”
5. 标识“加载器该如何装配它”
6. 标识“校验器该如何检查它”

也就是说，它不能只回答：

- 目录在哪

还必须回答：

- 语义是什么
- 权限是什么
- 边界是什么

---

## 统一通用字段

当前建议所有扩展包都至少具备下面这些通用字段。

### 1. 身份字段

```text
pack_id
pack_type
version
display_name
description
author
license
```

### 2. 边界字段

```text
namespace
trust_level
capabilities
```

### 3. 兼容与依赖字段

```text
compatible_core_version
dependencies
optional_dependencies
conflicts
```

### 4. 加载控制字段

```text
enabled_by_default
load_priority
entry_points
register
activation_cli_flags
activation_scenario_ids
```

### 5. 扩展保留字段

```text
tags
metadata
```

---

## 推荐通用结构示例

```json
{
  "pack_id": "phase6_roster_pack",
  "pack_type": "content_pack",
  "version": "1.0.0",
  "display_name": "Phase 6 Roster Pack",
  "description": "Adds the first formal Phase 6 roster content.",
  "author": "Open PVZ Team",
  "license": "Custom",
  "namespace": "phase6_roster",
  "trust_level": "data_safe",
  "capabilities": ["content.entities", "content.cards", "content.waves"],
  "compatible_core_version": ">=0.1.0",
  "dependencies": [],
  "optional_dependencies": [],
  "conflicts": [],
  "enabled_by_default": false,
  "load_priority": 100,
  "register": ["content"],
  "entry_points": {
    "content_root": "data/combat"
  },
  "tags": ["phase6", "roster"],
  "metadata": {}
}
```

---

## `pack_type` 规范

当前建议第一轮正式支持下面 4 个主类型：

- `content_pack`
- `asset_pack`
- `rule_pack`
- `collection_pack`

后续预留但不要求立即实现：

- `localization_pack`
- `ui_theme_pack`

### 当前建议

- 加载器应把 `pack_type` 视为强约束字段
- 校验器应根据 `pack_type` 切换不同规则

---

## `trust_level` 规范

当前建议第一轮正式支持下面 3 个等级：

### 1. `data_safe`

允许：

- 纯数据资源
- 素材资源
- 本地化资源

不允许：

- 自定义运行时脚本执行

### 2. `trusted_script`

允许：

- 受控策略脚本

### 3. `internal_only`

允许：

- 更深层内部扩展

### 当前建议

- `pack_type` 不直接决定 `trust_level`
- 但默认组合建议是：
  - `content_pack -> data_safe`
  - `asset_pack -> data_safe`
  - `rule_pack -> trusted_script` 或 `data_safe`
  - `collection_pack -> data_safe`

---

## `namespace` 规范

每个包都应声明：

```text
namespace
```

### 当前建议规则

#### 主仓保留区

- `core/*`
- 或主仓稳定 ID 区

#### 扩展包区

- 应使用 manifest 声明的 `namespace`

例如：

- `phase6_roster/*`
- `classic_assets/*`
- `roof_campaign/*`

### 当前建议

- registry 在记录来源时，应能追溯到 `namespace`
- 校验器应禁止外部包在未显式允许的情况下覆盖主仓保留区

---

## `dependencies` 与 `optional_dependencies`

### `dependencies`

表示：

- 没有这些包，本包就不能工作

### `optional_dependencies`

表示：

- 没有这些包，本包仍可工作
- 但会损失某些增强能力

### 当前建议格式

第一版可以先使用字符串数组：

```json
{
  "dependencies": ["phase6_rules", "phase6_assets"],
  "optional_dependencies": ["classic_theme_assets"]
}
```

后续如果需要，再升级成对象结构：

- `pack_id`
- `version_range`
- `reason`

但第一版不建议过度复杂化。

---

## `capabilities` 规范

`capabilities` 的作用不是“列目录”，而是：

> 用声明式方式告诉平台，这个包打算提供什么类型的能力。

### 示例

`content_pack` 可能声明：

- `content.entities`
- `content.cards`
- `content.waves`
- `content.levels`
- `content.battlefields`

`asset_pack` 可能声明：

- `asset.visuals`
- `asset.audio`
- `asset.ui`

`rule_pack` 可能声明：

- `rule.effects`
- `rule.triggers`
- `rule.detections`
- `rule.goals`

`collection_pack` 可能声明：

- `collection.level_set`
- `collection.campaign`
- `collection.theme_bundle`

### 当前建议

- `capabilities` 应作为校验和 UI 展示辅助字段
- 不应替代具体入口字段

---

## `register` 规范

当前现有加载器已支持：

- `resources`
- `effects`

后续建议把它演进为更接近包语义的 register 集合：

### 第一轮建议值

- `content`
- `assets`
- `rules`
- `collections`

### 兼容建议

为兼容当前最小实现，可以在过渡阶段允许：

- `resources -> content`
- `effects -> rules`

也就是说：

- 旧 manifest 继续可用
- 新 manifest 使用更清晰的 register 值

---

## `entry_points` 规范

`entry_points` 是后续加载器最需要依赖的字段之一。

它的作用是：

- 告诉不同类型的 registry 去哪里找资源

不同 `pack_type` 的建议不同。

### `content_pack` 建议入口

```json
{
  "entry_points": {
    "content_root": "data/combat",
    "validation_root": "scenes/validation"
  }
}
```

### `asset_pack` 建议入口

```json
{
  "entry_points": {
    "asset_index": "asset_index.json",
    "theme_root": "assets"
  }
}
```

### `rule_pack` 建议入口

```json
{
  "entry_points": {
    "rule_root": "data/rules",
    "script_root": "scripts/rules"
  }
}
```

### `collection_pack` 建议入口

```json
{
  "entry_points": {
    "collection_index": "collection.json",
    "level_set_root": "collections/levels"
  }
}
```

### 当前建议

- `entry_points` 不应被压缩成单一路径
- 应保留对象结构，便于不同 `pack_type` 扩展

---

## 四类核心包的专属字段建议

### `content_pack`

建议增加：

```text
content_version
supports_core_rules
default_asset_requirements
```

### `asset_pack`

建议增加：

```text
theme_tags
fallback_pack_id
asset_index
```

### `rule_pack`

建议增加：

```text
rule_version
allows_strategy_scripts
rule_entry_points
```

### `collection_pack`

建议增加：

```text
default_enabled_packs
recommended_asset_pack
campaign_entries
```

---

## 与当前最小 `extension.json` 的兼容策略

当前建议：

### 第一阶段

- 允许继续加载当前最小 `extension.json`
- 旧字段继续工作：
  - `pack_id`
  - `enabled_by_default`
  - `register`
  - `activation_*`

### 第二阶段

- 加载器支持读取新字段
- 缺失字段时自动填默认值

### 第三阶段

- 新建包优先采用新规范
- 旧格式逐步只保留兼容支持

### 当前建议默认补全值

对于旧格式，可推导：

- `pack_type`
  - 由 `register` 粗略推导
- `trust_level`
  - 默认 `data_safe`
- `namespace`
  - 默认等于 `pack_id`

---

## 包级校验建议

manifest 规范一旦正式化，校验器至少应覆盖：

### 1. 基础字段校验

- `pack_id`
- `pack_type`
- `version`
- `namespace`
- `trust_level`

### 2. 依赖校验

- 必需依赖是否存在
- 是否循环依赖

### 3. 类型边界校验

例如：

- `asset_pack` 不应声明规则脚本入口
- `content_pack` 不应声明 strategy 脚本入口
- `collection_pack` 不应声明内容目录正文入口

### 4. 权限校验

例如：

- `data_safe` 不允许 script entry
- `trusted_script` 才允许策略脚本入口

---

## 当前建议的正式规范摘要

如果把这份 manifest 规范压缩成一组立即可执行的原则，当前建议固定为：

1. 所有扩展包都必须有统一的身份、边界、依赖和加载字段。
2. `pack_type` 必须显式声明。
3. `trust_level` 必须显式声明或可被安全推导。
4. `namespace` 必须显式声明或可被安全推导。
5. `entry_points` 应保留对象结构，而不是被压缩成单一路径。
6. `register` 应逐步从 `resources / effects` 演进到 `content / assets / rules / collections`。
7. 旧 `extension.json` 继续兼容，但不应再作为长期最终规范。

---

## 当前文档层面的正式结论

如果把这份文档收成一句话，当前最合理的正式结论是：

> `Open PVZ` 的扩展包 manifest 应尽快从“最小扫描配置”演进成“统一平台元信息协议”，并以 `pack_type / trust_level / namespace / dependencies / capabilities / entry_points` 为核心字段，作为后续所有包类型加载、校验、治理与 UI 展示的共同基础。

---

## 后续建议

如果以这份 manifest 规范作为下一阶段输入，接下来最适合继续产出：

1. `集合包与内容作者工作流草案.md`
2. `AssetRegistry 最小职责与落地顺序.md`

前者负责把你后续真正想采用的“内容作者模式”流程串起来。  
后者负责把素材包系统从设计草案继续往实现前规格推进。

---

## 相关文档

- [扩展系统总体规划](../../../wiki/04-roadmap-reference/38-扩展系统总体规划.md)
- [素材包系统设计草案](39-素材包系统设计草案.md)
- [扩展包边界与依赖规则-v1](40-扩展包边界与依赖规则-v1.md)
