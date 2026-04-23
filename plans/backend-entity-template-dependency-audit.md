# backend_entity_template 依赖盘点与收缩

日期：2026-04-24

## 目标

把 `backend_entity_template` 从“运行时默认依赖层”收缩为“编译期补位层”。

当前阶段不追求一次性删除所有 backend template，而是先回答三件事：

1. 当前代码到底还从 backend 读了哪些字段。
2. 这些字段应该上移到 `CombatArchetype`，还是在编译期固化进 `RuntimeSpec`。
3. 哪些读取已经可以立刻收缩，哪些还需要先补内容资源。

## 当前字段级依赖

### A. 已经不再依赖 backend 的字段

这些字段当前已经能只靠 archetype / runtime 工作：

- `root_scene`
  - 代码现状：没有 backend fallback 读取链路。
  - 结论：保持在 archetype 层即可。
- `required_components`
  - 代码现状：已改为由 archetype / runtime 驱动实例化。
  - 结论：保留在 archetype，并在编译期抄入 `RuntimeSpec.required_components`。
- `optional_components`
  - 代码现状：已改为由 archetype 元数据提供。
  - 结论：保留在 archetype，并在编译期抄入 `RuntimeSpec.optional_components`。
- placement 约束
  - 包括：
    - `placement_role`
    - `allowed_slot_types`
    - `required_placement_tags`
    - `granted_placement_tags`
    - `required_present_roles`
    - `required_empty_roles`
  - 代码现状：本次已把 `BattleCardState / BattleBoardState` 的 placement 推导改为只读 archetype。
  - 结论：归属 archetype，不应再从 backend 读取。

### B. 当前仍然从 backend 读的字段

#### 1. `default_params`

- 读取位置：
  - `MechanicCompiler.normalize_archetype()`
  - `CombatContentResolver.merge_spawn_params()`
- 当前作用：
  - 作为 archetype 默认参数的后备来源。
  - 再和 `spawn_overrides` 合并，最终写入 `RuntimeSpec.params`。
- 结论：
  - 长期归属：`CombatArchetype.default_params`
  - 过渡策略：保留 backend fallback，直到所有 archetype 把正式默认值补齐。
  - 下一步：给所有 archetype 补齐稳定默认值后，删除 fallback。

#### 2. `hit_height_band`

- 读取位置：
  - `MechanicCompiler._resolve_hit_height_band()`
  - `CombatContentResolver.resolve_hit_height_band()`
- 当前作用：
  - 编译期 / spawn 解析期补位高度段。
  - 最终落到 `RuntimeSpec.hit_height_band`。
- 结论：
  - 长期归属：`CombatArchetype.hit_height_band`
  - 编译期产物：`RuntimeSpec.hit_height_band`
  - backend 应只作为迁移期 fallback。

#### 3. `projectile_template`

- 读取位置：
  - `MechanicCompiler._resolve_projectile_template()`
  - `CombatContentResolver.resolve_projectile_template()`
- 当前作用：
  - 补位投射物资源。
  - 最终落到 `RuntimeSpec.projectile_template`。
- 结论：
  - 长期归属：`CombatArchetype.projectile_template`
  - 编译期产物：`RuntimeSpec.projectile_template`
  - backend 应只作为迁移期 fallback。

#### 4. `projectile_flight_profile`

- 读取位置：
  - `MechanicCompiler._resolve_projectile_flight_profile()`
  - `CombatContentResolver.resolve_projectile_flight_profile()`
- 当前作用：
  - 补位飞行配置。
  - 最终落到 `RuntimeSpec.projectile_flight_profile`。
- 结论：
  - 优先归属：`CombatArchetype.projectile_flight_profile`
  - 若飞行配置天然从 projectile template 派生，则可在编译期解析后直接固化进 `RuntimeSpec`
  - backend 应只作为迁移期 fallback。

#### 5. `entity_kind`

- 读取位置：
  - `MechanicCompiler.compile_spawn_entry()` 中仅剩一处 backend fallback
- 当前作用：
  - 仅在 archetype 未显式填写时兜底。
- 结论：
  - 长期归属：`CombatArchetype.entity_kind`
  - 当前主仓 archetype 已普遍显式填写，属于可删除 fallback 的候选项。

#### 6. `backend_entity_template` 整体资源对象

- 读取位置：
  - `RuntimeSpec.backend_entity_template`
  - `EntityFactory._instantiate_runtime_spec()` 的参数合并与 legacy trigger fallback
  - `ProtocolValidator.validate_combat_archetype()` 用于校验 backend skeleton
- 当前作用：
  - 编译期 fallback 数据源
  - 迁移期校验对象
- 结论：
  - 不应再作为实例化/放置/组件元数据主来源
  - 后续目标是把它压缩成“编译期可选输入”而不是 `RuntimeSpec` 的运行时常驻字段

## 本次已完成的收缩

### 1. placement 链路去 backend 化

已完成：

- `BattleCardState` 不再通过 backend template 取放置角色和放置标签
- `BattleBoardState` 不再通过 backend template 取放置约束

结果：

- placement 判断现在只认 archetype
- backend placement 字段从运行时关键路径移除

### 2. 实例化链路去 backend 元数据化

已完成：

- `RuntimeSpec` 新增：
  - `required_components`
  - `optional_components`
- `MechanicCompiler` 在编译期把 archetype 组件元数据固化进 `RuntimeSpec`
- `EntityFactory` 在 runtime spec 实例化时优先用 archetype/runtime 元数据驱动：
  - 组件补齐
  - metadata 写入
  - `max_health`
  - `hitbox_size`

结果：

- backend template 不再是 runtime 实例化时的组件/元数据主来源

## 剩余推荐收缩顺序

### 第一优先级：内容迁移

先把下列字段批量补到 archetype 资源：

- `hit_height_band`
- `projectile_template`
- `projectile_flight_profile`
- 缺失的 `default_params`

原因：

- 这是当前 backend fallback 最主要的真实来源
- 迁完后可以直接删除 compiler / resolver 中的大部分 backend fallback

### 第二优先级：编译链去 fallback

在内容补齐后收掉：

- `MechanicCompiler.normalize_archetype()` 对 backend `default_params` 的 fallback
- `MechanicCompiler._resolve_hit_height_band()`
- `MechanicCompiler._resolve_projectile_template()`
- `MechanicCompiler._resolve_projectile_flight_profile()`
- `CombatContentResolver` 中对应 fallback

### 第三优先级：RuntimeSpec 去 backend 常驻字段

当上面两步完成后：

- 把 `RuntimeSpec.backend_entity_template` 降为调试/兼容字段，或直接删除
- `EntityFactory._instantiate_runtime_spec()` 不再接触 backend template

## 当前建议

下一步最值得继续做的是：

1. 批量把 archetype 缺失的 `hit_height_band / projectile_template / projectile_flight_profile` 从 backend 提升到 archetype。
2. 然后删除 `MechanicCompiler` 与 `CombatContentResolver` 的对应 backend fallback。

这会把 backend 依赖从“字段补位层”继续压缩到只剩 `default_params` 和少量兼容校验层。
