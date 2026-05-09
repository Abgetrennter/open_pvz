# ADR-007 统一 Registry / Slot 生产线

- 状态：已决定
- 日期：2026-05-05
- 作者：Codex / Abget
- 关联阶段：通用扩展插槽 v2
- 关联文档：
  - [ADR-005 扩展包接入与迁移策略](ADR-005-扩展包接入与迁移策略.md)
  - [通用扩展插槽机制](../04-roadmap-reference/42-通用扩展插槽机制.md)
  - [扩展系统总体规划](../04-roadmap-reference/38-扩展系统总体规划.md)
- 关联实现：
  - `scripts/core/registry/registry_base.gd`
  - `scripts/core/registry/registry_config.gd`
  - `scripts/core/registry/registry_contributor_def.gd`
  - `autoload/ProjectileMovementRegistry.gd`
  - `autoload/MechanicCompilerRegistry.gd`
  - `autoload/EffectRegistry.gd`
  - `autoload/TriggerRegistry.gd`
  - `autoload/DetectionRegistry.gd`
  - `autoload/ControllerRegistry.gd`
- 关联验证：
  - `registry_duplicate_id_guardrail`
  - `registry_core_override_guardrail`
  - `registry_trust_level_guardrail`
  - `registry_slot_extension_probe`
  - `registry_strategy_script_guardrail`
  - `detection_registry_smoke`
  - `controller_registry_smoke`
  - `trigger_registry_smoke`

## 1. 决策摘要

项目正式采用统一 Registry / Slot 生产线：

1. 新增扩展点必须优先走 `RegistryBase + RegistryConfig + RegistryContributorDef`。
2. 可扩展 contributor 统一字段为 `id`、`tags`、`param_defs`，slot 自有字段通过派生 Resource 追加。
3. runtime script 类 slot 必须显式声明 `trust_level = trusted_runtime` 和对应 `capabilities`。
4. 扩展包不得注册或覆盖 `core.*`，重复 id 默认拒绝，不做跨包 override。
5. 每个新增 slot 必须同时提供正向 smoke 和 guardrail 验证。

## 2. 背景

通用扩展插槽 v1 已完成 `projectile_movement`、`mechanic_compilers`、`effects` 的基础开放，但各 registry 仍有局部差异：

- 扫描、去重、来源追踪和错误记录逻辑分散。
- `TriggerRegistry / DetectionRegistry / ControllerRegistry` 尚未完整资源化。
- 新增可扩展点时仍容易复制 registry 代码。
- manifest 的 `capabilities` 在部分历史包中可缺省，无法表达明确授权边界。

## 3. 最终决策

### 3.1 Registry 内核

正式引入三类基础对象：

- `RegistryContributorDef`：所有 contributor Resource 的基类，固定提供 `id / tags / param_defs`。
- `RegistryConfig`：声明 slot id、def script、manifest register kind、扩展扫描目录、信任等级、fallback id 和 core override 策略。
- `RegistryBase`：统一实现注册、注销、查询、列举、rebuild、扩展扫描、命名空间保护、重复 id 拒绝、trust/capability 校验和 protocol issue 记录。

所有开放扩展的 registry 必须继承 `RegistryBase`。运行时 registry 可以保留自己的分发 hook，例如：

- `ProjectileMovementRegistry.create_component()`
- `EffectRegistry.get_strategy()`
- `MechanicCompilerRegistry.compile_type()`
- `TriggerRegistry.evaluate_trigger()`
- `DetectionRegistry.evaluate()`
- `ControllerRegistry.process_controller()`

### 3.2 Slot 接入规范

新增 slot 的标准流程：

1. 定义继承 `RegistryContributorDef` 的 contributor Resource。
2. 创建继承 `RegistryBase` 的 registry autoload 或明确拥有者。
3. 在 `_make_registry_config()` 中声明 `slot_id / def_script / register_kind / extension_dir / required_trust`。
4. 在 `_register_builtin_defs()` 中注册内置 contributor。
5. 在 `_validate_def_specific()` 中校验 slot 专属字段和脚本接口。
6. 在 `_on_def_registered()` 中接入运行时 strategy / component / compiler。
7. 更新 `ExtensionPackCatalog.ALLOWED_REGISTER_KINDS`。
8. 补正向 smoke 和 guardrail 验证。

### 3.3 Manifest 能力边界

runtime contributor 必须同时满足：

- manifest `register` 包含对应 register kind。
- manifest `trust_level` 达到 slot 要求。
- manifest `capabilities` 显式包含对应 register kind 或 slot id。

`capabilities` 不再对 runtime slot 缺省放行。历史扩展包如果注册 runtime slot，必须补齐 capability 声明。

### 3.4 禁止事项

- 扩展包不得注册或覆盖 `core.*`。
- v1/v2 不开放跨包 override。
- 不允许扩展包新增 Mechanic family。
- 不引入插件 VM、安装器 UI 或任意启动脚本。

## 4. 结果

截至 2026-05-05：

- `ProjectileMovementRegistry / MechanicCompilerRegistry / EffectRegistry / TriggerRegistry / DetectionRegistry / ControllerRegistry` 均继承 `RegistryBase`。
- `EffectDef / TriggerDef / ProjectileMovementDef / MechanicCompilerDef / DetectionDef / ControllerDef` 均继承 `RegistryContributorDef`。
- `Trigger / Detection / Controller` 的扩展 `strategy_script` 已具备注册前校验和运行时分发。
- `MechanicCompilerRegistry` 回到统一 `rebuild_registry()` 生命周期，通过重放内置 compiler 定义与 callable 保留现有编译路径。
- validation baseline 已全量通过（场景数见 `tools/validation_scenarios.json`）。

## 5. 后续约束

- 后续发现新的可扩展点时，默认先评估是否可建模为 registry slot。
- 任何绕过 `RegistryBase` 的新注册中心都需要 ADR 或明确设计审批。
- 新增 slot 不应只补“无协议错误”smoke，必须至少覆盖一次真实运行时分发。
