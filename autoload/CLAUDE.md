[根目录](../CLAUDE.md) > **autoload**

# autoload -- 全局单例

## 模块职责

全局 autoload 单例，在 `project.godot` 中注册，为整个引擎提供基础设施服务。所有 autoload 在游戏启动时自动加载为场景树根节点的子节点。

## 关键文件

| 文件 | 类名 | 职责 |
|------|------|------|
| `EventBus.gd` | -- (extends Node) | 事件分发中枢。支持优先级订阅、oneshot、过滤器、历史追踪（最多 256 条）。核心方法：`push_event()`, `subscribe()`, `subscribe_ex()` |
| `GameState.gd` | -- (extends Node) | 游戏状态：当前战斗引用、游戏时间、实体 ID 分配器。核心方法：`begin_battle()`, `advance_time()`, `next_entity_id()` |
| `SceneRegistry.gd` | -- (extends Node) | 资源注册表。自动扫描正式 archetype、projectile template、validation scenario，按 ID 属性索引。提供 `get_archetype()`, `get_projectile_template()`, `get_validation_scenario()` 等 |
| `TriggerRegistry.gd` | -- (extends Node) | 触发器定义与策略注册。内置 3 个冻结触发器：`periodically`, `when_damaged`, `on_death`。策略为 lambda 函数 |
| `EffectRegistry.gd` | -- (extends Node) | 效果定义与策略注册。内置 3 个冻结效果：`damage`, `spawn_projectile`, `explode`。策略为 lambda 函数 |
| `DebugService.gd` | -- (extends Node) | 集中式调试日志。记录事件执行、触发器匹配、效果执行、协议问题 |

## 对外接口

所有 autoload 通过全局名称直接访问（如 `EventBus.push_event()`），无需 `get_node()`。

### 核心事件流

```
EventBus.push_event(&"game.tick", event_data)
  -> TriggerComponent 订阅回调
    -> TriggerInstance.execute()
      -> EffectExecutor.execute_node()
        -> EffectRegistry.get_strategy() -> strategy.call()
```

## 关键依赖

- `scripts/core/runtime/event_data.gd` -- EventBus 使用的事件数据容器
- `scripts/core/runtime/protocol_validator.gd` -- TriggerRegistry/EffectRegistry 用于定义验证
- `scripts/core/defs/` -- TriggerDef, EffectDef 等资源定义

## 相关验证场景

所有验证场景都间接测试 autoload 功能，因为 EventBus 和注册表是运行时的基础。

<!-- 由 init-architect 自动生成，时间：2026-04-15 21:39:03 -->
