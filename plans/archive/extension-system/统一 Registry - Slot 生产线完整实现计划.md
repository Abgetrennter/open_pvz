# 统一 Registry / Slot 生产线完整实现计划

## Summary

目标是把当前“局部统一”的 registry 体系升级为一套正式的 Slot 化扩展生产线：新增扩展点时只需要定义 contributor resource、slot registry 配置和少量运行时 hook，不再复制扫描、去重、信任、来源追踪、协议错误等基础逻辑。

本计划按“不保持旧接口兼容”的前提执行：允许统一字段名、重命名接口、迁移 `.tres` 资源和更新调用点。完成后，`ProjectileMovement / Effect / MechanicCompiler / Trigger / Detection / Controller` 都遵循同一套 Registry 基础协议；`MechanicFamily` 保持冻结协议目录，不作为扩展 slot。

## 当前实现情况（2026-05-05 — 已完成 ✅）

整套方案已完成，121 个验证场景全部通过。

已完成全部迁移：

- 统一 registry 内核文件已就位：
  - `scripts/core/registry/registry_contributor_def.gd`
  - `scripts/core/registry/registry_config.gd`
  - `scripts/core/registry/registry_base.gd`
- 所有 contributor def 已迁移到统一基类：
  - `EffectDef`、`TriggerDef`、`ProjectileMovementDef`、`MechanicCompilerDef`、`DetectionDef`、`ControllerDef`
- 全部 6 个 autoload registry 已继承 `RegistryBase`：
  - `ProjectileMovementRegistry` — 保留 `create_component()` 和兼容 alias
  - `MechanicCompilerRegistry` — 保留 `compile_type()` 和 callable 注册路径
  - `EffectRegistry` — 扩展扫描已清理，strategy hook 已接入 `_on_def_registered()`
  - `TriggerRegistry` — 6 内置 trigger，strategy 保留为 lambda，扩展 `strategy_script.evaluate()` 已校验并接入
  - `DetectionRegistry` — 6 内置 detection，strategy 保留为 lambda，扩展 `strategy_script.evaluate()` 已校验并接入
  - `ControllerRegistry` — 4 内置 controller，strategy 保留为 lambda，扩展 `strategy_script.process()` 已校验并接入
- `ProtocolValidator` 字段已迁移：`trigger_id → id`、`effect_id → id`、`condition_params → param_defs`
- `MechanicCompiler` 已补齐：`param_defs`、`family` metadata
- 扩展 `.tres` contributor 资源已迁移：`effect_id / move_mode / type_id → id`
- manifest 已更新：runtime slot 必须显式声明 `trust_level` 与对应 `capabilities`
- 八个新增验证场景已创建、登记到 `validation_scenarios.json` 并通过验证
- 全量验证 121/121 通过

## 执行记录（全部完成 ✅）

1. 收口 `EffectRegistry` 迁移：✅
   - 删除旧 `_register_extension_defs_and_strategies()` / `_register_extension_effect_defs()` 路径。
   - 将扩展 strategy 注册放入 `_on_def_registered()`。
   - 确认 `PROMOTED_EXTENSION_EFFECT_IDS` 使用 `effect_def.id`。

2. 迁移 `TriggerRegistry`：
   - 继承 `RegistryBase`。
   - 内置 trigger 改为 `TriggerDef.id + param_defs`。
   - 保留现有 callable strategy，内置定义注册完成后调用 `_register_builtin_strategies()`。
   - 扩展 trigger 预留 `strategy_script.evaluate(event_data, condition_values, entity_state, instance)`。

3. 迁移 `DetectionRegistry` / `ControllerRegistry`：
   - 新增内置 `DetectionDef` / `ControllerDef` contributor 注册。
   - 保留现有内置 callable strategy。
   - 扩展脚本分别要求 `evaluate(owner, params)` 和 `process(owner, spec, delta, blackboard)`。

4. 修 runtime 调用点：
   - `ProtocolValidator.validate_trigger_def()` 使用 `trigger_def.id / trigger_def.param_defs`。
   - `ProtocolValidator.validate_effect_def()` 使用 `effect_def.id`。
   - `MechanicCompiler` 读取 trigger param defs 时使用 `param_defs`。
   - `MechanicCompiler.register_builtin_mechanic_types()` 调用 `MechanicCompilerRegistry.register_compiler()` 时传入 `family`。
   - `MechanicTypeRegistry.list_type_ids()` 统一为 `list_ids()`，必要时保留短期内部别名只用于迁移。

5. 迁移扩展 contributor 资源和 manifest：
   - 仅迁移 contributor 资源字段，不迁移 `CombatMechanic.type_id`、`EffectNode.effect_id`、`ProjectileFlightProfile.move_mode` 这类运行时语义字段。
   - 更新 `ExtensionPackCatalog.ALLOWED_REGISTER_KINDS`：`triggers / detections / controllers`。
   - 统一 runtime contributor 所需 trust/capability 声明。

6. 补验证与文档：
   - 创建并登记八个新增验证场景。
   - 更新正式 wiki 与 `AGENTS.md`，明确新增 slot 必须走 `RegistryBase + RegistryConfig + ContributorDef`。

7. 验证顺序：
   - 先跑单场景：`parabola_long_range_validation`。
   - 再跑扩展 smoke：`projectile_movement_zigzag_smoke_validation`。
   - 再跑 guardrail：`extension_slot_guardrail_validation`、`extension_runtime_trust_guardrail_validation`、`extension_manifest_guardrail_validation`。
   - 八个新增 registry 场景通过后，再跑全量 `pwsh tools/run_all_validations.ps1`。

## Key Changes

- 新增统一内核：
  - `RegistryContributorDef`：所有可注册资源的基类，统一字段为 `id`、`tags`、`param_defs`。
  - `RegistryConfig`：声明 `slot_id`、`def_script`、`register_kind`、`extension_dir`、`required_trust`、`fallback_id`、`allow_core_override`。
  - `RegistryBase`：统一实现 `register_def()`、`unregister()`、`has()`、`get_def()`、`get_entry()`、`list_ids()`、`list_entries()`、`rebuild_registry()`。
  - `RegistryEntry` 使用 Dictionary 即可，不新增复杂对象；固定包含 `id / def / source / tags / enabled`。

- 统一注册流程：
  - `rebuild_registry()` 固定为：清空 entries -> 注册 builtins -> 扫描 manifest 允许的 extension resources -> 调用 `register_def()`。
  - `register_def()` 固定校验：资源非空、脚本类型、`id` 非空、命名空间、`core.*` 保护、重复 id、trust/capability/register kind、slot-specific validate。
  - 所有失败统一进入 `DebugService.record_protocol_issue(slot_id, message, "error")`。
  - 扩展包不能覆盖 `core.*`，v1 不实现跨包 override。

- 迁移现有 registry：
  - `ProjectileMovementRegistry`、`EffectRegistry`、`MechanicCompilerRegistry` 改为继承 `RegistryBase`，保留各自运行时能力：`create_component()`、`get_strategy()`、`compile_type()`。
  - `TriggerRegistry` 改为资源化 `TriggerDef` contributor，`evaluate_trigger()` 只从 registry entry 取 strategy。
  - 新增 `DetectionDef`、`ControllerDef`，将现有内置 detection/controller strategy 从裸 callable 注册迁移为内置 contributor。
  - `MechanicCompilerRegistry.list_type_ids()` 统一为 `list_ids()`；`MechanicTypeRegistry` 不再作为独立扩展入口，只作为由 compiler entries 派生的只读查询层，或直接由调用点改查 `MechanicCompilerRegistry`。
  - `MechanicFamilyRegistry` 保持冻结 family 目录职责，不迁入 `RegistryBase`。

- 统一 contributor 资源字段：
  - `ProjectileMovementDef.move_mode` 迁移为 `id`。
  - `EffectDef.effect_id` 迁移为 `id`。
  - `TriggerDef.trigger_id` 迁移为 `id`。
  - `MechanicCompilerDef.type_id` 迁移为 `id`，保留 `family`。
  - 新增 `DetectionDef.id + strategy_script`，策略脚本暴露 `evaluate(owner, params) -> Dictionary`。
  - 新增 `ControllerDef.id + strategy_script`，策略脚本暴露 `process(owner, spec, delta, blackboard) -> void`。

- manifest 与扩展扫描统一：
  - `ExtensionPackCatalog.ALLOWED_REGISTER_KINDS` 增加或确认所有 slot：`effects`、`projectile_movement`、`mechanic_compilers`、`triggers`、`detections`、`controllers`。
  - runtime script 类 slot 要求 `trusted_runtime`。
  - `data_only` 只能注册纯资源内容；不允许贡献带运行时代码的 contributor。
  - 资源扫描目录由 `RegistryConfig.extension_dir` 唯一决定。

- 文档与治理：
  - 更新正式 wiki，把“新增 slot 工作流”升级为明确工程规范。
  - 更新 `AGENTS.md`：新增扩展点必须优先走 `RegistryBase + RegistryConfig + ContributorDef`。
  - 新增或更新计划文档，记录本次 registry 归一化为通用插槽 v2。

## Test Plan

- 基础 registry guardrail：
  - 重复 id 被拒绝并记录 protocol issue。
  - 扩展包注册 `core.*` 被拒绝。
  - trust_level 不足时 runtime contributor 被拒绝。
  - `rebuild_registry()` 幂等，重复扫描不会重复注册。
  - `list_ids()` 稳定排序，`get_entry()` 返回 source 信息。

- 迁移回归：
  - 现有 projectile movement：`core.linear / core.parabola / core.track` 全部可创建组件。
  - `my_pack.zigzag` 仍能通过 extension 注册、编译、发射、命中。
  - 现有效果扩展仍能注册并执行 strategy。
  - 内置 trigger：`periodically / proximity / when_damaged / on_death / on_spawned / on_place` 行为不变。
  - 内置 detection：`always / lane_forward / lane_backward / proximity / radius_around / global_track` 行为不变。
  - 内置 controller：`core.bite / core.sweep / core.ground_damage / core.projectile_transform` 行为不变。

- 新增验证场景：
  - `registry_duplicate_id_guardrail`
  - `registry_core_override_guardrail`
  - `registry_trust_level_guardrail`
  - `detection_registry_smoke`
  - `controller_registry_smoke`
  - `trigger_registry_smoke`
  - `registry_slot_extension_probe`
  - `registry_strategy_script_guardrail`

- 回归命令：
  - 先跑 extension + guardrail 分层验证。
  - 最后跑 `pwsh tools/run_all_validations.ps1`。

## Assumptions

- 不保持旧 registry 方法兼容；所有调用点统一迁移到新接口。
- 不新增 Mechanic family；family 仍是冻结协议。
- 不实现 override、热更新、插件 VM、安装器 UI。
- Contributor 字段统一使用 `id`，不保留 `move_mode / effect_id / trigger_id / type_id` 作为长期字段。
- v1 继续使用 `.tres` Resource 扫描，不引入 JSON contributor 或任意启动脚本。
