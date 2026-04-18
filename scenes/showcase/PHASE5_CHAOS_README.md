# Phase 5 Chaos Showcase

这个分组集中展示第五阶段错误技的两类内容：

## 1. 正式级联样例

- `chain_explosion_cascade_showcase.tscn`
- `splash_zone_cascade_showcase.tscn`
- `fast_pursuit_cascade_showcase.tscn`
- `multi_lane_retaliation_cascade_showcase.tscn`

这 4 个场景对齐提交 `7617055`，用于展示第五阶段第一批正式错误技验证样例。

## 2. 扩展能力样例

- `hit_split_chaos_showcase.tscn`
- `periodic_summon_chaos_showcase.tscn`
- `apply_status_chaos_showcase.tscn`
- `knockback_chaos_showcase.tscn`
- `chain_bounce_chaos_showcase.tscn`
- `aura_chaos_showcase.tscn`
- `delayed_trigger_chaos_showcase.tscn`
- `delayed_explode_chaos_showcase.tscn`
- `mark_chaos_showcase.tscn`

这 9 个场景用于展示第五阶段后续扩展能力：

- 扩展包新增最小 `on_hit` 效果位
- 扩展包新增最小 `spawn_entity` 效果位
- 扩展包新增 `apply_status` 控制效果
- 扩展包新增 `knockback` 位移效果
- 扩展包新增 `chain_bounce` 多目标跳链伤害
- 扩展包新增 `aura` 持续范围控制效果
- 扩展包新增 `delayed_trigger` 时序型单体触发效果
- 扩展包新增 `delayed_explode` 时序型范围爆炸效果
- 扩展包新增 `mark` 独立标记生命周期效果

它们的目标不是替代正式级联样例，而是证明扩展入口已经可以承接更强的内容表达力。
