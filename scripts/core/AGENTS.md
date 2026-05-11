# scripts/core -- 资源定义、运行时执行、统一注册基类

三个子目录：`defs/`（19 文件，Resource 定义）、`runtime/`（16 文件，编译/验证/执行逻辑）、`registry/`（3 文件，RegistryBase 体系）。77 文件总计。

## WHERE TO LOOK -- defs/

| 文件 | 类 | 干什么 |
|------|-----|--------|
| `combat_archetype.gd` | CombatArchetype | 实体入口：id / entity_kind / stats / mechanics[] |
| `combat_mechanic.gd` | CombatMechanic | 行为单元：family / type_id / priority / params |
| `trigger_def.gd` | TriggerDef | 触发器 contributor：id / tags / param_defs |
| `effect_def.gd` | EffectDef | 效果 contributor：id / param_defs / slots |
| `effect_slot_def.gd` | EffectSlotDef | 效果槽：slot_name / allowed_effect_ids |
| `detection_def.gd` | DetectionDef | 目标发现 contributor：id / tags / param_defs |
| `controller_def.gd` | ControllerDef | Controller contributor：id / tags / param_defs |
| `projectile_template.gd` | ProjectileTemplate | 抛射体内容：template_id / flight_profile / hitbox_radius |
| `projectile_movement_def.gd` | ProjectileMovementDef | movement contributor：id / tags / param_defs |
| `mechanic_compiler_def.gd` | MechanicCompilerDef | 扩展编译器 contributor |
| `height_band.gd` | HeightBand | 高度段：band_id / min_height / max_height |
| `movement_contribution_def.gd` | MovementContributionDef | 运动贡献定义 |
| `plant_archetype.gd` | PlantArchetype | 植物 archetype 便捷子类 |
| `zombie_archetype.gd` | ZombieArchetype | 僵尸 archetype 便捷子类 |
| `projectile_archetype.gd` | ProjectileArchetype | 投射物 archetype 便捷子类 |
| `visual_cue_def.gd` | VisualCueDef | 视觉提示定义 |
| `visual_fx_def.gd` | VisualFxDef | 视觉特效定义 |
| `visual_profile_def.gd` | VisualProfileDef | 外观档案定义 |
| `audio_cue_def.gd` | AudioCueDef | 音频提示定义 |

## WHERE TO LOOK -- runtime/

| 文件 | 类 | 干什么 |
|------|-----|--------|
| `mechanic_compiler.gd` | MechanicCompiler | **1335 行**。编译入口 `compile_spawn_entry()`，49 内置 type，binding group 配对，per-type dispatch 到各 compiler callable |
| `protocol_validator.gd` | ProtocolValidator | **1553 行**。15 个 static validate_*() 方法，`FROZEN_TRIGGER_BEHAVIOR_SPECS` 守卫冻结语义，所有定义必经此验证 |
| `effect_executor.gd` | EffectExecutor | 递归执行 EffectNode 树，最大深度 5，调用 EffectRegistry 策略 |
| `extension_pack_catalog.gd` | ExtensionPackCatalog | 扩展包加载：扫描 `extensions/`，`ALLOWED_REGISTER_KINDS`(7 种)、`ALLOWED_TRUST_LEVELS`、guardrail 场景校验 |
| `runtime_spec.gd` | RuntimeSpec | 编译产物：从 archetype + mechanics 生成的完整运行时规格 |
| `runtime_trigger_spec.gd` | RuntimeTriggerSpec | 编译后触发器：trigger_id / event_name / condition_values / effect_root |
| `normalized_mechanic_set.gd` | NormalizedMechanicSet | Mechanic 去重归并，按 family 分组 |
| `shuffle_bag.gd` | ShuffleBag | 确定性随机：battle_seed 派生链，抽完不重复 |
| `rule_context.gd` | RuleContext | 触发器/效果间状态传递：source / target / position / event_data |
| `event_data.gd` | EventData | 事件容器：core（游戏数据）+ runtime（链式追踪） |
| `effect_node.gd` | EffectNode | 效果树节点：effect_id / params / children[] |
| `effect_result.gd` | EffectResult | 执行结果：success / terminated / notes |
| `trigger_instance.gd` | TriggerInstance | 运行时触发器实例，绑定 owner，条件检查 + 效果链 |
| `entity_state.gd` | EntityState | 实体快照，RefCounted，系统间安全传递 |
| `effect_delay_runner.gd` | EffectDelayRunner | 延迟效果调度 |
| `combat_content_resolver.gd` | CombatContentResolver | 内容解析与引用补全 |

## WHERE TO LOOK -- registry/

| 文件 | 类 | 干什么 |
|------|-----|--------|
| `registry_base.gd` | RegistryBase | 统一基类。register_def() / unregister() / has() / get_def() / list_ids() / rebuild_registry()。内置 hook：`_register_builtin_defs()` / `_validate_def_specific()` / `_on_def_registered()`。扩展包扫描 `_register_extension_defs()` |
| `registry_config.gd` | RegistryConfig | 配置：slot_id / def_script / register_kind / extension_dir / required_trust / allow_core_override |
| `registry_contributor_def.gd` | RegistryContributorDef | 统一 contributor Resource：id / tags / param_defs。TriggerDef/EffectDef/DetectionDef/ControllerDef/ProjectileMovementDef/MechanicCompilerDef 均继承此类 |

## KEY INTERFACES

**验证链**：`ProtocolValidator.validate_combat_archetype()` -> `validate_combat_mechanic()` (per mechanic) -> 类型/边界/脚本检查 -> 返回 issues[]。所有 archetype 在 `EntityFactory` 实例化前必经此链。

**编译链**：`MechanicCompiler.compile_spawn_entry(spawn_entry, archetype)` -> `NormalizedMechanicSet` -> per-family binding group 配对 -> per-type compiler dispatch -> `RuntimeSpec`（含 `RuntimeTriggerSpec[]`、stats、flags）。

**注册链**：autoload 单例继承 `RegistryBase`，实现 `_make_registry_config()` 和 `_register_builtin_defs()`。扩展包 def 经 `ExtensionPackCatalog` 扫描后调用 `register_def(def, source)`，走 `_validate_common()` + `_validate_def_specific()` + 信任检查 + `core.*` 保护。

## ANTI-PATTERNS

- **不得绕开 RegistryBase 自建注册逻辑**。新增扩展点必须：定义 ContributorDef -> 创建 autoload 继承 RegistryBase -> 实现 hook -> 接入 ALLOWED_REGISTER_KINDS
- **不得绕开 ProtocolValidator 新增 def 类型**。新 contributor def 必须有对应的 validate_*() 方法
- **不得为单个实体硬编码编译路径**。所有行为走 `CombatArchetype + CombatMechanic[]` 通用编译链
- **扩展包不得覆盖 `core.*`**，`_is_core_id()` 在 register_def() 内强制拦截
- **不得修改 FROZEN_TRIGGER_BEHAVIOR_SPECS**，需 ADR 审批
