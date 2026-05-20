# 僵尸基础设施协议归档（2026-05）

> 状态：已完成归档
> 归档时间：2026-05-20

本目录保存原版僵尸复刻前置基础设施协议补充的实施草案。

这些文档不再作为待实施计划使用。当前事实以运行时代码、`wiki/` 正文、`tools/validation_scenarios.json` 和最新验证产物为准。

## 已完成内容

- `HealthLayerDef`、`CombatArchetype.health_layers` 与 `RuntimeSpec.health_layers`。
- `HealthComponent` 多层 HP 路由：`attachment -> shield -> helm -> body`。
- `damage_layer_policy` v1：`bypass_layer_kinds` 与 `spillover`。
- `Movement` family、`MovementDef`、`MovementRegistry` 与 `core.walk` / `core.leap_once`。
- `MovementComponent` 作为实体默认位置积分点，输出 height、ground_contact、exposure_state 等运行时状态。
- `StateComponent` transition side-effects：`set_movement`、`set_height_band`、`set_runtime_params`、`emit_event`。
- `exposure_state` 与 `weight_class` 协议，以及 Effect / HitPolicy / Projectile 命中过滤。
- 13 个专项验证场景和 4 个可视化 showcase 场景。

## 验证记录

最近一次完整验证矩阵：

- 时间：2026-05-20
- 场景数：183
- 结果：183 passed / 0 failed
- 产物：`artifacts/validation/batch_20260520_215847`

守卫检查：

- `pwsh tools/check_public_extension_release_guardrails.ps1`
- 结果：OK

## 归档文件

- [僵尸基础设施协议补充](./zombie-infrastructure-protocol-supplement.md)

## 后续观察项

- `core.hop_cycle`、`core.tunnel`、`core.drive`、`core.submerge` 仍是后续 Movement type，不属于本轮 v1。
- Screen Door 方向挡弹、泳池 lane 语义、GridItem 冰道/梯子、Dancer/Bungee/Gargantuar 完整召唤行为仍按后续僵尸内容计划处理。
- 归档草案中的历史分析仅作背景，正式协议以 wiki 正文和代码为准。
