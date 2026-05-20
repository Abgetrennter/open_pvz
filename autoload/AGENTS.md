[根目录](../AGENTS.md) > **autoload**

# autoload -- 全局单例层，引擎基础设施的唯一入口

## OVERVIEW

18 个 autoload 单例：2 个核心服务（EventBus、GameState）、13 个注册表（11 继承 RegistryBase）、1 个素材解析服务、1 个场景索引、1 个调试服务。

## WHERE TO LOOK

| 文件 | 类型 | 职责 |
|------|------|------|
| `EventBus.gd` | Node | 事件分发中枢：优先级订阅、oneshot、过滤器、256 条历史环形缓冲 |
| `GameState.gd` | Node | 战斗状态：当前战斗引用、100Hz tick 时间、实体 ID 分配、battle_seed |
| `DebugService.gd` | Node | 集中式日志：事件/触发器/效果/快照/协议问题，除 validator reporter 外唯一日志出口 |
| `SceneRegistry.gd` | Node | 资源索引：扫描 `data/combat/` 下 archetype / projectile_template / validation_scenario |
| `MechanicFamilyRegistry.gd` | Node | 11 个冻结 Mechanic family 注册（冻结，新增需 ADR） |
| `MechanicTypeRegistry.gd` | Node | Mechanic type 注册（family 下的具体 type_id，委托 MechanicCompiler 注册内置 type） |
| `MechanicCompilerRegistry.gd` | RegistryBase | per-type 编译器 callable 注册与分发 |
| `DetectionRegistry.gd` | RegistryBase | 目标发现策略：always / lane_forward / lane_backward / proximity / radius_around / global_track |
| `TriggerRegistry.gd` | RegistryBase | 触发器策略：periodically / when_damaged / on_death / on_spawned / on_place / proximity |
| `EffectRegistry.gd` | RegistryBase | 效果策略（1212 行，12 内置效果）：damage / spawn_projectile / explode / apply_status / spawn_entity / replace_entity / produce_sun / dispel_flying / wake / team_switch / consume_self / reveal。最大 lambda 策略段 |
| `ControllerRegistry.gd` | RegistryBase | Controller 策略：core.bite / core.sweep / core.ground_damage / core.projectile_transform |
| `ProjectileMovementRegistry.gd` | RegistryBase | 抛射体 movement：core.linear / core.parabola / core.track，含组件创建 |
| `MovementRegistry.gd` | RegistryBase | 实体自主运动：core.walk / core.leap_once，输出 movement command |
| `VisualCueRegistry.gd` | RegistryBase | 视觉提示注册与分发 |
| `VisualFxRegistry.gd` | RegistryBase | 视觉特效注册与分发 |
| `VisualProfileRegistry.gd` | RegistryBase | 角色视觉外观档案注册 |
| `AudioCueRegistry.gd` | RegistryBase | 音频提示注册与分发 |
| `AssetRegistry.gd` | Node | 素材索引解析：从已启用 asset_pack 的 `asset_index.json` 解析逻辑表现 ID |

## EXECUTION CHAIN

```
离散事件链（每 tick 触发）：
EventBus.push_event(event_name, EventData)
  └─ TriggerComponent._on_event()
       └─ TriggerInstance.execute()
            └─ EffectExecutor.execute_node(EffectNode, RuleContext)
                 └─ EffectRegistry.get_strategy(effect_id).call(ctx)
                      └─ 可能再次 push_event() → 形成事件链（最大深度 5）

编译链（实例化时一次性）：
MechanicCompilerRegistry.get_compiler(type_id).call(mechanic, archetype)
  └─ 输出 RuntimeSpec 片段 → EntityFactory 组装

连续行为链（每帧）：
MovementComponent._physics_process()
  └─ MovementRegistry.build_command(entity, delta)
ControllerComponent._physics_process()
  └─ ControllerRegistry.get_strategy(id).call(entity, delta)
```

## STRUCTURE

```
autoload/
├── EventBus.gd              # 事件中枢，一切运行时行为的起点
├── GameState.gd              # 战斗状态与 ID 分配
├── DebugService.gd           # 全局日志（禁止用 print 替代）
├── SceneRegistry.gd          # 资源索引（扫描 data/combat/）
├── MechanicFamilyRegistry.gd # family 注册（独立 Node，不继承 RegistryBase）
├── MechanicTypeRegistry.gd   # type 注册（独立 Node）
├── *Registry.gd              # 其余 11 个注册表，均继承 RegistryBase
├── AssetRegistry.gd          # 运行时素材索引解析服务（v1：visual_profile）
└── CLAUDE.md                 # 本文件
```

## 关键依赖

- `scripts/core/registry/registry_base.gd` -- 11 个 Registry autoload 的基类，提供注册、去重、信任检查、来源追踪
- `scripts/core/runtime/protocol_validator.gd` -- 所有注册表用于定义验证（参数类型、边界、资源脚本类型）
- `scripts/core/defs/` -- TriggerDef / EffectDef / DetectionDef / ControllerDef / ProjectileMovementDef / MovementDef / MechanicCompilerDef 等资源定义
- `scripts/core/runtime/event_data.gd` -- EventBus 事件数据容器

## 反模式（autoload 专属）

- **禁止用 `print()` 替代 `DebugService`**：除 DebugService 自身和 validation reporter 外，所有运行时日志走 DebugService
- **禁止注册表 autoload 绕开 RegistryBase**：新增扩展点必须走 `RegistryBase + RegistryConfig + ContributorDef`
- **禁止扩展包注册 `core.*` 命名空间**：`core.*` 由主仓独占
- **禁止 autoload 之间循环依赖**：EventBus 无依赖；GameState 仅依赖 EventBus；各 Registry 可依赖 EventBus 和 DebugService，不可互相引用
- **禁止在注册表 autoload 中硬编码业务逻辑**：策略用 lambda/callable 注册，autoload 本身只做注册和分发
