# 攻击链 4 Family 编译路径实施计划

> 状态：提议中
> 日期：2026-04-22
> 关联 ADR：ADR-002（顶层作者模型与编译链）、ADR-003（Mechanic 一级家族冻结）

---

## 一、目标

为 Targeting / Emission / Trajectory / HitPolicy 四个冻结 family 建立编译路径，使得一个 archetype 能够完全通过 `mechanics[]` 驱动攻击链，不再依赖 backend EntityTemplate 的 TriggerBinding 或 ProjectileFlightProfile 中的隐式配置。

完成后，攻击链的完整编译路径为：

```
Trigger + Targeting + Emission + Trajectory + HitPolicy + Payload
  -> 编译合并为 TriggerBinding（含完整 effect_params）
  -> 运行时不变（TriggerComponent -> EffectExecutor -> BattleSpawner -> ProjectileRoot）
```

## 二、现状分析

### 2.1 当前攻击链的数据流

```
Trigger mechanic params (interval, detection_id, scan_range)
         |
         v
    condition_values  -----> TriggerRegistry.periodically 检查 timing + DetectionRegistry 扫描目标
         |
         v
Payload mechanic params (damage, speed, direction, projectile_template)
         |
         v
    effect_params   -----> EffectRegistry.spawn_projectile -> BattleSpawner.spawn_projectile_from_effect
         |
         v
projectile_template + flight_profile -----> move_mode, hit_strategy, terminal_hit_strategy
```

### 2.2 四个 family 的数据散落位置

| Family | 当前数据位置 | 当前编译状态 |
|--------|-------------|-------------|
| Targeting | Trigger mechanic params (`detection_id`, `scan_range`) → condition_values | 已部分编译（通过 condition_values 传递给 TriggerRegistry） |
| Emission | 无独立承载；每次 trigger fire 发射 1 个抛射体；`shuffle_cycle` 仅在 `_build_mechanic_runtime_states` 中有骨架 | 未编译到 binding |
| Trajectory | `ProjectileFlightProfile` 资源（`move_mode`, `height_strategy`, `peak_height`）绑定在 projectile_template 上 | 未参与编译 |
| HitPolicy | `ProjectileFlightProfile` 资源（`hit_strategy`, `terminal_hit_strategy`）绑定在 projectile_template 上 | 未参与编译 |

### 2.3 关键约束

1. **运行时不变**：TriggerComponent、EffectExecutor、BattleSpawner、ProjectileRoot 不需要修改。这四个 family 的编译结果最终要融入现有的 `TriggerBinding.condition_values` 和 `effect_params`。
2. **向后兼容**：没有 Targeting/Emission/Trajectory/HitPolicy mechanic 的 archetype（所有当前 wrapper archetype）应继续正常工作。
3. **渐进式**：每个 family 独立可验证。不需要一次全部完成。

## 三、设计

### 3.1 核心思路

在 `_compile_trigger_payload_bindings` 中，当前只对 Trigger x Payload 做交叉积。改造为：

```
Trigger x [Targeting] x [Emission] x [Trajectory] x [HitPolicy] x Payload
```

其中 Targeting/Emission/Trajectory/HitPolicy 是可选的修饰器（0..N 个）。它们不产生独立的 TriggerBinding，而是**注入参数到已有的 TriggerBinding** 中。

具体来说：
- **Targeting mechanic** → 参数注入到 `condition_values`（覆盖/补充 detection_id, scan_range 等）
- **Emission mechanic** → 参数注入到 `effect_params`（burst_count, spread_angle 等）+ 可选 runtime_state
- **Trajectory mechanic** → 参数注入到 `effect_params`（movement_mode, flight_profile_override 等）
- **HitPolicy mechanic** → 参数注入到 `effect_params`（hit_strategy, terminal_hit_strategy 等）

### 3.2 编译流程改造

```
_compile_trigger_payload_bindings(normalized, archetype):
  1. 分离 mechanics:
     triggers = [family == Trigger | Lifecycle]
     payloads = [family == Payload]
     targeting_mods = [family == Targeting]
     emission_mods = [family == Emission]
     trajectory_mods = [family == Trajectory]
     hit_policy_mods = [family == HitPolicy]

  2. 合并修饰器参数:
     targeting_overrides = _merge_targeting_mods(targeting_mods, merged_params)
     emission_overrides = _merge_emission_mods(emission_mods, merged_params)
     trajectory_overrides = _merge_trajectory_mods(trajectory_mods, merged_params)
     hit_policy_overrides = _merge_hit_policy_mods(hit_policy_mods, merged_params)

  3. 交叉积 + 注入:
     for trigger in triggers:
       for payload in payloads:
         binding = _build_binding_from_mechanics(...)
         _inject_targeting(binding, targeting_overrides)
         _inject_emission(binding, emission_overrides)
         _inject_trajectory(binding, trajectory_overrides)
         _inject_hit_policy(binding, hit_policy_overrides)
         compiled.append(binding)

  4. 更新 _build_mechanic_runtime_states (Emission 已有骨架)
```

### 3.3 各 Family 的 type_id 设计

#### Targeting

| type_id | 含义 | 编译行为 |
|---------|------|---------|
| `core.lane_forward` | 同车道向前扫描 | condition_values 合入 `{detection_id: "lane_forward", scan_range: <from params>}` |
| `core.lane_backward` | 同车道向后扫描 | condition_values 合入 `{detection_id: "lane_backward", scan_range: <from params>}` |
| `core.always` | 无方向扫描 | condition_values 合入 `{detection_id: "always"}` |
| `core.enemies_in_radius` | 半径内所有敌人 | condition_values 合入 `{detection_id: "always", scan_range: <radius>}` （复用 always 策略） |

**注**：Targeting 的运行时已经由 DetectionRegistry 承载。编译只是把 mechanic 的 params 映射到 trigger condition_values 中已有的 `detection_id` / `scan_range` 键。

#### Emission

| type_id | 含义 | 编译行为 |
|---------|------|---------|
| `core.single` | 单发（默认行为） | effect_params 无变化 |
| `core.burst` | 连发 | effect_params 合入 `{burst_count, burst_interval}` |
| `core.shuffle_cycle` | 洗牌循环 | effect_params 合入 `{shuffle_pool}`；runtime_state 保留 shuffle_bag |
| `core.spread` | 扇形散射 | effect_params 合入 `{spread_count, spread_angle, spread_index_offset}` |

**运行时消费**：Emission 参数在 `spawn_projectile` effect 策略中被消费。当前 `spawn_projectile` 每次只发射 1 个。需要扩展 EffectRegistry 或 BattleSpawner 的 `spawn_projectile_from_effect` 以支持 burst/spread 模式。

#### Trajectory

| type_id | 含义 | 编译行为 |
|---------|------|---------|
| `core.linear` | 直线飞行 | effect_params 合入 `{movement_mode: "linear"}` |
| `core.parabola` | 抛物线 | effect_params 合入 `{movement_mode: "parabola", arc_height, peak_height}` |
| `core.track` | 追踪 | effect_params 合入 `{movement_mode: "track", turn_rate}` |

**注**：Trajectory 的运行时已经由 ProjectileMovement* 组件承载。编译只是覆盖 `movement_mode` 和相关参数。

#### HitPolicy

| type_id | 含义 | 编译行为 |
|---------|------|---------|
| `core.swept_segment` | 扫掠线段碰撞 | effect_params 合入 `{hit_strategy: "swept_segment"}` |
| `core.terminal_hitbox` | 终端命中框 | effect_params 合入 `{hit_strategy: "terminal_hitbox", terminal_hit_strategy: "impact_hitbox"}` |
| `core.terminal_radius` | 终端半径 | effect_params 合入 `{hit_strategy: "terminal_radius", terminal_hit_strategy: "impact_radius", impact_radius}` |
| `core.overlap` | 重叠检测 | effect_params 合入 `{hit_strategy: "overlap"}` |

**注**：HitPolicy 的运行时已经由 ProjectileRoot 的 `_find_hit_target_from_move_result` 承载。编译只是覆盖参数。

### 3.4 运行时消费点

| Family | 消费位置 | 需要的运行时改动 |
|--------|---------|----------------|
| Targeting | `TriggerRegistry.evaluate_trigger("periodically")` → `DetectionRegistry.evaluate` | **无改动**（已通过 condition_values 传递） |
| Emission | `BattleSpawner.spawn_projectile_from_effect` | **需要改动**：读取 burst_count / spread_count，循环发射多个抛射体 |
| Trajectory | `EntityFactory._build_effect_node_from_binding` → `_merge_projectile_binding_params` | **无改动**（movement_mode 已通过 effect_params 传递） |
| HitPolicy | `BattleSpawner.build_projectile_movement_params` | **无改动**（hit_strategy 已通过 flight_profile 或 effect_params 传递） |

## 四、实施步骤

### Phase A：Targeting 编译路径（无运行时改动）

**A1. 注册 type_id**
- `mechanic_compiler.gd` 的 `register_builtin_mechanic_types` 新增：
  - `core.lane_forward` → Targeting
  - `core.lane_backward` → Targeting
  - `core.always` → Targeting

**A2. 创建 skeleton mechanic 资源**
- `data/combat/mechanics/skeleton/` 新增：
  - `mechanic_targeting_lane_forward.tres` — `{detection_id: "lane_forward", scan_range: 900}`
  - `mechanic_targeting_lane_backward.tres` — `{detection_id: "lane_backward", scan_range: 900}`
  - `mechanic_targeting_always.tres` — `{detection_id: "always"}`

**A3. 编译注入**
- `_compile_trigger_payload_bindings` 新增 targeting 分支：
  - 收集 Targeting mechanics
  - 合并 params → `_inject_targeting(binding, targeting_params)`
  - 注入逻辑：把 `detection_id` / `scan_range` / `required_state` 写入 binding.condition_values

**A4. 验证场景**
- `targeting_compile_validation.tres`：创建一个使用独立 Targeting mechanic 的 archetype，验证生成的 TriggerBinding 的 condition_values 包含正确的 detection_id 和 scan_range
- 更新已有验证场景：把一个 archetype 的 Targeting 从 trigger mechanic params 中分离为独立 mechanic

**预计改动文件**：~5 个
**预计新增文件**：~5 个（3 个 mechanic .tres + 1 个验证 .tres + 1 个验证 .tscn）

---

### Phase B：Trajectory 编译路径（无运行时改动）

**B1. 注册 type_id**
- `core.linear` → Trajectory
- `core.parabola` → Trajectory
- `core.track` → Trajectory

**B2. 创建 skeleton mechanic 资源**
- `mechanic_trajectory_linear.tres` — `{movement_mode: "linear"}`
- `mechanic_trajectory_parabola.tres` — `{movement_mode: "parabola", arc_height: 72}`
- `mechanic_trajectory_track.tres` — `{movement_mode: "track", turn_rate: 6.0}`

**B3. 编译注入**
- `_compile_trigger_payload_bindings` 新增 trajectory 分支：
  - 收集 Trajectory mechanics
  - 合并 params → `_inject_trajectory(binding, trajectory_params)`
  - 注入逻辑：把 `movement_mode` / `arc_height` / `turn_rate` / `travel_duration` / `peak_height` 写入 binding.effect_params

**B4. 验证场景**
- `trajectory_compile_validation.tres`：创建使用独立 Trajectory mechanic 的 archetype，验证抛射体的 movement_mode 正确
- 可复用已有的 `archetype_projectile_validation` 模式

**预计改动文件**：~3 个
**预计新增文件**：~5 个

---

### Phase C：HitPolicy 编译路径（无运行时改动）

**C1. 注册 type_id**
- `core.swept_segment` → HitPolicy
- `core.terminal_hitbox` → HitPolicy
- `core.terminal_radius` → HitPolicy
- `core.overlap` → HitPolicy

**C2. 创建 skeleton mechanic 资源**
- `mechanic_hit_policy_swept_segment.tres` — `{hit_strategy: "swept_segment"}`
- `mechanic_hit_policy_terminal_hitbox.tres` — `{hit_strategy: "terminal_hitbox", terminal_hit_strategy: "impact_hitbox"}`
- `mechanic_hit_policy_terminal_radius.tres` — `{hit_strategy: "terminal_radius", terminal_hit_strategy: "impact_radius", impact_radius: 36}`
- `mechanic_hit_policy_overlap.tres` — `{hit_strategy: "overlap"}`

**C3. 编译注入**
- `_compile_trigger_payload_bindings` 新增 hit_policy 分支：
  - 收集 HitPolicy mechanics
  - 合并 params → `_inject_hit_policy(binding, hit_policy_params)`
  - 注入逻辑：把 `hit_strategy` / `terminal_hit_strategy` / `impact_radius` / `collision_padding` 写入 binding.effect_params

**C4. 验证场景**
- `hit_policy_compile_validation.tres`：验证不同 hit_strategy 的 archetype 能正确编译

**预计改动文件**：~3 个
**预计新增文件**：~6 个

---

### Phase D：Emission 编译路径（需要运行时改动）

这是最复杂的 family，因为它改变了"每次发射几个抛射体"的行为。

**D1. 注册 type_id**
- `core.single` → Emission
- `core.burst` → Emission
- `core.shuffle_cycle` → Emission（已有骨架）
- `core.spread` → Emission

**D2. 创建 skeleton mechanic 资源**
- `mechanic_emission_single.tres` — `{mode: "single"}`
- `mechanic_emission_burst.tres` — `{mode: "burst", burst_count: 2, burst_interval: 0.08}`
- `mechanic_emission_spread.tres` — `{mode: "spread", spread_count: 3, spread_angle: 15.0}`

**D3. 编译注入**
- `_compile_trigger_payload_bindings` 新增 emission 分支：
  - 收集 Emission mechanics
  - 合并 params → `_inject_emission(binding, emission_params)`
  - 注入逻辑：把 `burst_count` / `burst_interval` / `spread_count` / `spread_angle` 写入 binding.effect_params

**D4. 运行时扩展**
- `BattleSpawner.spawn_projectile_from_effect` 需要读取 emission 参数：
  - 如果 `burst_count > 1`：循环发射，每次间隔 `burst_interval`
  - 如果 `spread_count > 1`：扇形发射多个抛射体，角度偏移 `spread_angle`
  - 如果 `mode == "single"` 或无 emission params：保持当前行为
- Emission 模式可能需要延迟发射（burst 的间隔），这可以通过 Timer 或在 TriggerRegistry 的 periodically 策略中分帧发射实现
- `shuffle_cycle` 的 runtime_state 消费：每次发射时从 shuffle_bag 取出下一个 projectile_template

**D5. 验证场景**
- `emission_single_compile_validation.tres` — 单发（无变化，兼容性验证）
- `emission_burst_compile_validation.tres` — 连发（如 repeater）
- `emission_spread_compile_validation.tres` — 扇形散射（如三线射手）

**预计改动文件**：~5 个
**预计新增文件**：~7 个

---

### Phase E：集成验证与独立 archetype 示例

**E1. 创建全 mechanic 独立 archetype**
- `archetype_peashooter_full.tres`：包含 Trigger + Targeting + Emission(single) + Trajectory(linear) + HitPolicy(swept_segment) + Payload(spawn_projectile) 的完全独立 archetype，不依赖 backend EntityTemplate 的 TriggerBinding

**E2. 对比验证**
- 新建 `peashooter_full_mechanic_parity_validation.tres`：验证全 mechanic 路径的攻击行为与现有 peashooter wrapper 路径一致

**E3. 回归验证**
- 全量 `run_all_validations.ps1` 确保 66+ 验证全部通过

**预计改动文件**：~2 个
**预计新增文件**：~4 个

---

## 五、实施顺序与依赖

```
Phase A (Targeting) ──── 无运行时改动，最安全，先做
    |
    v
Phase B (Trajectory) ──── 无运行时改动
    |
    v
Phase C (HitPolicy) ──── 无运行时改动
    |
    v
Phase D (Emission) ──── 需要运行时改动，最复杂，最后做
    |
    v
Phase E (集成验证) ──── 全链路闭合
```

Phase A/B/C 可以并行，但建议按顺序逐个完成以保持验证稳定。

## 六、风险与约束

1. **effect_params 键冲突**：多个 family 可能向同一个 binding.effect_params 注入同名键。需要定义优先级（后面注入的覆盖前面的，Payload mechanic 的原始 params 优先级最低）。
2. **Emission 运行时复杂度**：burst/spread 需要在 BattleSpawner 中引入循环发射逻辑，可能需要 Timer 或多帧调度。
3. **ProtocolValidator**：新增的 type_id 需要在 ProtocolValidator 中注册白名单。
4. **向后兼容**：所有没有对应 family mechanic 的 archetype 应继续正常工作（当前所有 wrapper archetype）。

## 七、验收标准

1. 每个 Phase 都有对应的验证场景通过
2. 全量 66+ 验证无回归
3. 能够创建一个完全独立于 backend EntityTemplate TriggerBinding 的 archetype，通过 6 个 family mechanic 描述完整的攻击行为
4. 编译结果（TriggerBinding 的 condition_values 和 effect_params）包含所有注入的参数
