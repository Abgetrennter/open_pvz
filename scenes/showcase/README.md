# Showcase Scenes

These scenes are thin wrappers around already-validated battle scenario resources.

The project startup scene is now a lightweight showcase hub:

- `res://scenes/main/main.tscn`

Use that hub to enter a showcase scene with buttons instead of changing the
project default startup repeatedly.

Open one of these in Godot to inspect a specific sample set without changing the
project's default startup scene:

- `minimal_validation_showcase.tscn`
- `template_instantiation_showcase.tscn`
- `template_factory_showcase.tscn`
- `height_hit_showcase.tscn`
- `terminal_explode_showcase.tscn`
- `chain_explosion_cascade_showcase.tscn`
- `splash_zone_cascade_showcase.tscn`
- `fast_pursuit_cascade_showcase.tscn`
- `multi_lane_retaliation_cascade_showcase.tscn`
- `hit_split_chaos_showcase.tscn`
- `periodic_summon_chaos_showcase.tscn`
- `apply_status_chaos_showcase.tscn`
- `knockback_chaos_showcase.tscn`
- `chain_bounce_chaos_showcase.tscn`

Phase 5 分组的额外说明见：

- `PHASE5_CHAOS_README.md`

All of them use `BattleManager` directly and keep restart enabled with `R`.
Each showcase scene also supports:

- `Esc` to return to the showcase hub
