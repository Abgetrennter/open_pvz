# Legacy gameplay field data/combat migration checklist

生成时间：2026-05-08

## 阶段 0 基线

- 当前 `git status --short` 只显示 `vendor/de-pvz` 为既有脏状态；本次迁移不得触碰或提交 `vendor/`。
- 全量验证通过：`137 / 137 passed`。
- 批次目录：`artifacts/validation/batch_20260508_224621`。
- `pwsh tools/check_runtime_metrics_time_guardrails.ps1 -IncludeExistingContent` 按预期失败，说明活跃内容仍有 legacy gameplay 字段。

## 阶段 1 迁移规则

统一目标：内容层只写语义字段；运行时可以继续把语义字段转换成 world-unit 参数，但 `.tres` 内容不再直接暴露 legacy world-unit gameplay 字段。

| Legacy 字段 | 目标字段 | 默认换算 |
| --- | --- | --- |
| `"speed"` | `"speed_slots_per_sec"` | `speed / 96.0` |
| `"move_speed"` | `"move_speed_slots_per_sec"` | `move_speed / 96.0` |
| `"scan_range"` | `"scan_range_slots"` 或 `"range_mode": &"full_lane"` | 有明确整行语义时用 `range_mode`，否则 `scan_range / 96.0` |
| `"radius"` | `"radius_slots"` | `radius / 96.0` |
| `"impact_radius"` | `"impact_radius_slots"` | `impact_radius / 96.0` |
| `"collision_padding"` | `"collision_padding_slots"` | `collision_padding / 96.0` |
| `"detection_range"` | `"detection_range_slots"` | `detection_range / 96.0` |

注意事项：
- 这一步只做字段语义迁移，默认保持当前行为等价；不要顺手做数值再校准。
- 原版植物里已经有原版 ledger 支撑的字段，可以继续沿用原版语义值；尚未校准的 legacy 字段先按当前行为等价迁移。
- `scan_range = 900.0` 不要机械替换。对 `lane_forward/lane_backward` 这类“整行够远即可”的检测，优先使用 `"range_mode": &"full_lane"`。
- `scan_range = 4000.0` 和 `radius = 4000.0` 表达全场/超大范围语义；阶段 2 可以先按 `41.666667` slots 保持行为，后续再引入更明确的 global/full_board 语义。
- `projectile_profiles/*.tres` 使用 `impact_radius = ...` / `collision_padding = ...` 属性赋值，不是字典字段；guardrail 需要后续补扫这类写法。

常用换算表：

| World value | Slots value |
| --- | --- |
| `0.0` | `0.0` |
| `8.0` | `0.083333` |
| `10.0` | `0.104167` |
| `12.0` | `0.125` |
| `14.0` | `0.145833` |
| `16.0` | `0.166667` |
| `20.0` | `0.208333` |
| `22.0` | `0.229167` |
| `24.0` | `0.25` |
| `28.0` | `0.291667` |
| `30.0` | `0.3125` |
| `34.0` | `0.354167` |
| `36.0` | `0.375` |
| `40.0` | `0.416667` |
| `48.0` | `0.5` |
| `55.0` | `0.572917` |
| `64.0` | `0.666667` |
| `80.0` | `0.833333` |
| `120.0` | `1.25` |
| `150.0` | `1.5625` |
| `170.0` | `1.770833` |
| `180.0` | `1.875` |
| `190.0` | `1.979167` |
| `220.0` | `2.291667` |
| `240.0` | `2.5` |
| `250.0` | `2.604167` |
| `260.0` | `2.708333` |
| `300.0` | `3.125` |
| `320.0` | `3.333333` |
| `900.0` | `9.375` 或 `range_mode = &"full_lane"` |
| `1000.0` | `10.416667` |
| `4000.0` | `41.666667` |

## 实际迁移规模

`data/combat` 当前命中：

- 字典字段：118 处，90 个文件。
- Resource 属性赋值：18 处，9 个 projectile profile 文件。
- 总计：136 处，99 个文件。

按字段统计：

- `"speed"`：45 处。
- `"scan_range"`：39 处。
- `"radius"`：21 处。
- `"move_speed"`：10 处。
- `"detection_range"`：2 处。
- `"impact_radius"` 字典字段：1 处。
- `impact_radius = ...` profile 属性：9 处。
- `collision_padding = ...` profile 属性：9 处。

## 阶段 2 建议执行顺序

### 2A Projectile profiles

先迁 Resource 属性字段，行为最容易保持等价：

- `data/combat/projectile_profiles/linear_air.tres`
- `data/combat/projectile_profiles/linear_fast_swept.tres`
- `data/combat/projectile_profiles/linear_ground.tres`
- `data/combat/projectile_profiles/parabola_arc.tres`
- `data/combat/projectile_profiles/parabola_cabbage_arc.tres`
- `data/combat/projectile_profiles/parabola_long_arc.tres`
- `data/combat/projectile_profiles/parabola_terminal_blast.tres`
- `data/combat/projectile_profiles/track_air.tres`
- `data/combat/projectile_profiles/track_ground.tres`

动作：
- `impact_radius = X` -> `impact_radius_slots = X / 96.0`
- `collision_padding = X` -> `collision_padding_slots = X / 96.0`

### 2B Projectile templates

再迁 projectile template 默认速度：

- `data/combat/projectile_templates/air_spike.tres`
- `data/combat/projectile_templates/bone_linear.tres`
- `data/combat/projectile_templates/cabbage_arc.tres`
- `data/combat/projectile_templates/melon_blast.tres`
- `data/combat/projectile_templates/spore_shot_linear.tres`
- `data/combat/projectile_templates/tar_spit_linear.tres`
- `data/combat/projectile_templates/track_bomb.tres`

动作：
- `"speed": X` -> `"speed_slots_per_sec": X / 96.0`

### 2C Reusable mechanics

迁共享 mechanic，降低后续 archetype 的重复参数压力：

- `data/combat/mechanics/mechanic_original_blover_dispel.tres`
- `data/combat/mechanics/mechanic_original_cherrybomb_explode.tres`
- `data/combat/mechanics/mechanic_original_chomper_devour.tres`
- `data/combat/mechanics/mechanic_original_doomshroom_explode.tres`
- `data/combat/mechanics/mechanic_original_iceshroom_explode.tres`
- `data/combat/mechanics/mechanic_original_jalapeno_lane_explode.tres`
- `data/combat/mechanics/mechanic_original_kernelpult_payload.tres`
- `data/combat/mechanics/mechanic_original_potatomine_explode.tres`
- `data/combat/mechanics/mechanic_original_squash_explode.tres`
- `data/combat/mechanics/mechanic_projectile_payload_bone.tres`
- `data/combat/mechanics/mechanic_projectile_payload_burst.tres`
- `data/combat/mechanics/mechanic_projectile_payload_cabbage.tres`
- `data/combat/mechanics/mechanic_projectile_payload_frost.tres`
- `data/combat/mechanics/mechanic_projectile_payload_melon.tres`
- `data/combat/mechanics/mechanic_projectile_payload_spike.tres`
- `data/combat/mechanics/mechanic_projectile_payload_spore.tres`
- `data/combat/mechanics/mechanic_projectile_payload_tar.tres`
- `data/combat/mechanics/mechanic_projectile_payload_track.tres`
- `data/combat/mechanics/mechanic_reactive_bomber_death_explode.tres`
- `data/combat/mechanics/mechanic_reveal_payload_radius.tres`

动作：
- `"speed": X` -> `"speed_slots_per_sec": X / 96.0`
- `"radius": X` -> `"radius_slots": X / 96.0`

### 2D Skeleton mechanics

迁 skeleton mechanic，使新内容复制出来就是 semantic 字段：

- `data/combat/mechanics/skeleton/mechanic_bite_controller.tres`
- `data/combat/mechanics/skeleton/mechanic_controller_ground_damage.tres`
- `data/combat/mechanics/skeleton/mechanic_controller_projectile_transform.tres`
- `data/combat/mechanics/skeleton/mechanic_hit_policy_terminal_radius.tres`
- `data/combat/mechanics/skeleton/mechanic_periodic_attack_lane_forward.tres`
- `data/combat/mechanics/skeleton/mechanic_projectile_payload_cabbage.tres`
- `data/combat/mechanics/skeleton/mechanic_projectile_payload_pea.tres`
- `data/combat/mechanics/skeleton/mechanic_proximity_trigger.tres`
- `data/combat/mechanics/skeleton/mechanic_sweep_controller.tres`
- `data/combat/mechanics/skeleton/mechanic_targeting_global_track.tres`
- `data/combat/mechanics/skeleton/mechanic_targeting_lane_backward.tres`
- `data/combat/mechanics/skeleton/mechanic_targeting_lane_forward.tres`
- `data/combat/mechanics/skeleton/mechanic_targeting_radius_around.tres`

动作：
- `"move_speed": X` -> `"move_speed_slots_per_sec": X / 96.0`
- `"detection_range": X` -> `"detection_range_slots": X / 96.0`
- `"impact_radius": X` -> `"impact_radius_slots": X / 96.0`
- `"speed": X` -> `"speed_slots_per_sec": X / 96.0`
- `"scan_range": 900.0` on lane targeting -> `"range_mode": &"full_lane"`
- `"scan_range": 64.0/180.0/4000.0` -> `"scan_range_slots": X / 96.0`

### 2E Zombie archetypes

迁僵尸移动和远程检测：

- `data/combat/archetypes/zombies/archetype_air_scout.tres`
- `data/combat/archetypes/zombies/archetype_basic_zombie_skeleton.tres`
- `data/combat/archetypes/zombies/archetype_bone_thrower.tres`
- `data/combat/archetypes/zombies/archetype_boss_heavy.tres`
- `data/combat/archetypes/zombies/archetype_bucket_tank.tres`
- `data/combat/archetypes/zombies/archetype_lane_dummy.tres`
- `data/combat/archetypes/zombies/archetype_reactive_bomber.tres`
- `data/combat/archetypes/zombies/archetype_tar_spitter.tres`

动作：
- `"move_speed": X` -> `"move_speed_slots_per_sec": X / 96.0`
- `"scan_range": 900.0` -> `"range_mode": &"full_lane"` 或 `"scan_range_slots": 9.375`，按 detection 语义复核。

### 2F Non-original plant archetypes

迁 demo/skeleton/phase 内容：

- `data/combat/archetypes/plants/archetype_air_interceptor.tres`
- `data/combat/archetypes/plants/archetype_arming_striker_skeleton.tres`
- `data/combat/archetypes/plants/archetype_basic_shooter.tres`
- `data/combat/archetypes/plants/archetype_burst_shooter_skeleton.tres`
- `data/combat/archetypes/plants/archetype_cabbage_lobber.tres`
- `data/combat/archetypes/plants/archetype_cabbage_skeleton.tres`
- `data/combat/archetypes/plants/archetype_frost_pea.tres`
- `data/combat/archetypes/plants/archetype_full_chain_shooter_skeleton.tres`
- `data/combat/archetypes/plants/archetype_hit_policy_shooter_skeleton.tres`
- `data/combat/archetypes/plants/archetype_melon_lobber.tres`
- `data/combat/archetypes/plants/archetype_multi_payload_skeleton.tres`
- `data/combat/archetypes/plants/archetype_peashooter_skeleton.tres`
- `data/combat/archetypes/plants/archetype_repeater_burst.tres`
- `data/combat/archetypes/plants/archetype_spore_summoner.tres`
- `data/combat/archetypes/plants/archetype_sporeling.tres`
- `data/combat/archetypes/plants/archetype_spread_shooter_skeleton.tres`
- `data/combat/archetypes/plants/archetype_striker_skeleton.tres`
- `data/combat/archetypes/plants/archetype_targeting_striker_skeleton.tres`
- `data/combat/archetypes/plants/archetype_track_bomber.tres`
- `data/combat/archetypes/plants/archetype_trajectory_shooter_skeleton.tres`

动作：
- `"speed": X` -> `"speed_slots_per_sec": X / 96.0`
- `"scan_range": 900.0` -> `"range_mode": &"full_lane"`，如果该 archetype 使用非 lane detection 再改为 `scan_range_slots`。

### 2G Original plant archetypes

最后迁 original 中还没语义化的字段，避免与后续原版精校混在一起：

- `data/combat/archetypes/plants/archetype_original_blover.tres`
- `data/combat/archetypes/plants/archetype_original_cabbagepult.tres`
- `data/combat/archetypes/plants/archetype_original_cactus.tres`
- `data/combat/archetypes/plants/archetype_original_cattail.tres`
- `data/combat/archetypes/plants/archetype_original_cherrybomb.tres`
- `data/combat/archetypes/plants/archetype_original_chomper.tres`
- `data/combat/archetypes/plants/archetype_original_cobcannon.tres`
- `data/combat/archetypes/plants/archetype_original_doomshroom.tres`
- `data/combat/archetypes/plants/archetype_original_gatlingpea.tres`
- `data/combat/archetypes/plants/archetype_original_gravebuster.tres`
- `data/combat/archetypes/plants/archetype_original_iceshroom.tres`
- `data/combat/archetypes/plants/archetype_original_jalapeno.tres`
- `data/combat/archetypes/plants/archetype_original_kernelpult.tres`
- `data/combat/archetypes/plants/archetype_original_magnetshroom.tres`
- `data/combat/archetypes/plants/archetype_original_melonpult.tres`
- `data/combat/archetypes/plants/archetype_original_potatomine.tres`
- `data/combat/archetypes/plants/archetype_original_scaredyshroom.tres`
- `data/combat/archetypes/plants/archetype_original_splitpea.tres`
- `data/combat/archetypes/plants/archetype_original_squash.tres`
- `data/combat/archetypes/plants/archetype_original_starfruit.tres`
- `data/combat/archetypes/plants/archetype_original_threepeater.tres`
- `data/combat/archetypes/plants/archetype_original_wintermelon.tres`

动作：
- 已有原版语义字段的植物不重复处理。
- 未校准字段先按当前行为等价迁移；原版精确值校对另开任务。
- `cattail/magnetshroom/blover` 的 2000/4000 范围先保持等价迁移为 slots，后续再决定是否引入全场语义字段。

## 阶段 2 完成记录

完成时间：2026-05-11

- 2A Projectile profiles：9/9 文件，新增 `impact_radius_slots` / `collision_padding_slots`
- 2B Projectile templates：6/6 文件（pea_linear 已提前迁移），`"speed"` → `"speed_slots_per_sec"`
- 2C Reusable mechanics：20/20 文件，`"speed"` → `"speed_slots_per_sec"`，`"radius"` → `"radius_slots"`
- 2D Skeleton mechanics：13/13 文件，含 lane targeting 的 `scan_range` → `range_mode`
- 2E Zombie archetypes：8/8 文件，`"move_speed"` → `"move_speed_slots_per_sec"`，lane targeting 的 `scan_range` → `range_mode`
- 2F Non-original plant archetypes：20/20 文件，`"speed"` / `"scan_range"` 全部迁移
- 2G Original plant archetypes：22/22 文件，`"speed"` / `"scan_range"` / `"radius"` 全部迁移

验收：
- `data/combat` 字典字段 0 残留（rg 检查通过）
- Resource 属性字段保留向后兼容

## 阶段 2 验收

完成 `data/combat` 迁移后运行：

```powershell
git diff --check
rg -n '"(scan_range|impact_radius|collision_padding|detection_range|radius|distance|speed|move_speed)"\s*:' "data/combat"
rg -n '^(impact_radius|collision_padding|detection_radius|detection_range|radius|distance|speed|move_speed|scan_range)\s*=' "data/combat"
pwsh tools/check_runtime_metrics_time_guardrails.ps1 -IncludeExistingContent
pwsh tools/run_all_validations.ps1
```

预期：
- `data/combat` 不再出现 legacy gameplay 字段。
- guardrail 仍可能因为 `scenes/validation` 或 `extensions` 失败，这是后续阶段目标。
- 全量验证必须继续通过。
