[根目录](../../CLAUDE.md) > [scripts](../) > **core**

# scripts/core -- 核心定义与运行时

## 模块职责

引擎的核心抽象层，包含所有资源定义类（defs）和运行时执行逻辑（runtime）。这是四层模型中"行为层"和"组合层"的代码基础。

## 子目录

### defs/ -- 资源定义

| 文件 | 类名 | 职责 |
|------|------|------|
| `trigger_def.gd` | `TriggerDef` | 触发器定义：trigger_id, event_name, condition_params, max_bound_effects |
| `effect_def.gd` | `EffectDef` | 效果定义：effect_id, param_defs, slots, 允许额外参数/子效果 |
| `effect_slot_def.gd` | `EffectSlotDef` | 效果槽定义：slot_name, slot_type, allowed_effect_ids |
| `entity_template.gd` | `EntityTemplate` | 实体模板：template_id, entity_kind, 组件配置, 放置约束, trigger_bindings |
| `trigger_binding.gd` | `TriggerBinding` | 触发绑定：将 behavior_key 映射到 trigger_id + effect_id + 参数 |
| `projectile_template.gd` | `ProjectileTemplate` | 抛射体模板：template_id, flight_profile, default_params, lifetime, hitbox_radius |
| `height_band.gd` | `HeightBand` | 高度段定义：band_id, min_height, max_height |
| `movement_contribution_def.gd` | `MovementContributionDef` | 运动贡献定义 |

### runtime/ -- 运行时执行

| 文件 | 类名 | 职责 |
|------|------|------|
| `effect_executor.gd` | `EffectExecutor` | 效果执行器：递归执行 EffectNode 树，最大深度 5，调用 EffectRegistry 策略 |
| `protocol_validator.gd` | `ProtocolValidator` | 协议验证器：验证所有定义和运行时数据的完整性。冻结协议的守门人 |
| `rule_context.gd` | `RuleContext` | 规则上下文：在触发器和效果执行间传递状态（source/target/position/event_data） |
| `trigger_instance.gd` | `TriggerInstance` | 触发器实例：运行时触发器，绑定 owner 实体，执行条件检查和效果链 |
| `effect_node.gd` | `EffectNode` | 效果节点：效果树的节点，包含 effect_id, params, children |
| `effect_result.gd` | `EffectResult` | 效果执行结果：success, terminated, notes |
| `entity_state.gd` | `EntityState` | 实体状态快照：RefCounted，可在系统间安全传递 |
| `event_data.gd` | `EventData` | 事件数据容器：core（游戏数据）+ runtime（链式追踪） |

## 关键接口

### ProtocolValidator -- 验证入口

```gdscript
# 冻结协议行为规范
FROZEN_TRIGGER_BEHAVIOR_SPECS = {
    "attack":       { trigger_id: "periodically", event_name: "game.tick" },
    "when_damaged":  { trigger_id: "when_damaged", event_name: "entity.damaged" },
    "on_death":     { trigger_id: "on_death",     event_name: "entity.died" },
}

# 主要验证方法
validate_trigger_def(trigger_def) -> Array[String]
validate_effect_def(effect_def) -> Array[String]
validate_entity_template(entity_template) -> Array[String]  # retired guardrail: always rejects official EntityTemplate use
validate_battle_scenario(scenario) -> Array[String]
validate_battle_spawn_entry(spawn_entry) -> Array[String]
normalize_trigger_instance(instance) -> Dictionary
normalize_effect_node(node) -> Dictionary
```

## 依赖关系

- 被 `autoload/` 中的注册表使用
- 被 `scripts/battle/` 中的 BattleManager 和 EntityFactory 使用
- 被 `scripts/components/trigger_component.gd` 使用

## 相关验证场景

- `protocol_guardrail_validation` -- 协议护栏验证
- `template_guardrail_validation` -- 模板护栏验证
- `template_instantiation_validation` -- 模板实例化
- `template_factory_validation` -- 模板工厂

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
