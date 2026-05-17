# 扩展系统草案目录

本目录收集 `Open PVZ` 扩展系统的早期设计草案，当前**不作为仓库实现依据**。

## 目录定位

- **属性**：设计草案（draft），不是当前协议，不是当前规范。
- **时效**：反映写作时点的设想，后续实现可能完全偏离。
- **升级路径**：某一份草案真正开始实装时，才会被提升为 wiki 正式文档；未提升前不应被代码或正式资源引用。

## 当前草案列表

| 文件 | 议题 | 可消费程度 |
|------|------|------------|
| 37-扩展包新增效果与效果外置策略 | 扩展包注册新效果、效果主仓内置 vs 外置的边界 | 概念草案 |

## 已归档 / 已提升

| 文件 | 去向 |
|------|------|
| 42-通用扩展插槽规范草案-v1 | 已提升为 [通用扩展插槽机制](../../../wiki/04-roadmap-reference/42-通用扩展插槽机制.md)，原草案归档到 [`plans/archive/extension-system/`](../../archive/extension-system/) |
| 40-扩展包边界与依赖规则-v1 | 已提升为 [扩展包边界与依赖规则](../../../wiki/04-roadmap-reference/43-扩展包边界与依赖规则.md)，本目录草案仅作历史材料 |
| 39-素材包系统设计草案 | 已提升为 [素材包系统与本地私有包](../../../wiki/04-roadmap-reference/44-素材包系统与本地私有包.md)，本目录草案仅作历史材料 |
| 41-扩展包-manifest-规范-v1 | 已提升为 [扩展包 Manifest 规范](../../../wiki/04-roadmap-reference/45-扩展包Manifest规范.md)，本目录草案仅作历史材料 |

## 当前已落地的扩展能力（真实现）

- [`extensions/minimal_chaos_pack`](../../../extensions/minimal_chaos_pack)
- [`extensions/phase5_chaos_pack`](../../../extensions/phase5_chaos_pack)
- [`extensions/phase5_guardrail_pack`](../../../extensions/phase5_guardrail_pack)
- [`scripts/core/runtime/extension_pack_catalog.gd`](../../../scripts/core/runtime/extension_pack_catalog.gd)

以上为当前扩展系统真实状态，任何新扩展讨论应先对齐它们。

## 与 wiki 的关系

- wiki 正式入口：[扩展系统总体规划](../../../wiki/04-roadmap-reference/38-扩展系统总体规划.md)
- 通用扩展插槽正式入口：[通用扩展插槽机制](../../../wiki/04-roadmap-reference/42-通用扩展插槽机制.md)
- 包边界正式入口：[扩展包边界与依赖规则](../../../wiki/04-roadmap-reference/43-扩展包边界与依赖规则.md)
- 素材包正式入口：[素材包系统与本地私有包](../../../wiki/04-roadmap-reference/44-素材包系统与本地私有包.md)
- Manifest 正式入口：[扩展包 Manifest 规范](../../../wiki/04-roadmap-reference/45-扩展包Manifest规范.md)

## 何时从 draft 提升

任一草案被提升到 wiki 的前提：

1. 主干已开始实装对应能力。
2. 至少一个验证场景覆盖相应路径。
3. 草案里的字段与实际代码一致。

未满足以上任何一条，不应从 draft 提升。
