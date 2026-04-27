# Showcase Scenes

These scenes are thin wrappers around already-validated battle scenario resources.

They are display/navigation entry points, not the source of truth for formal content organization.
Formal combat content should live in `data/combat/` and runtime battle scenarios should stay independent from showcase naming.

The project startup scene is now a lightweight showcase hub:

- `res://scenes/main/main.tscn`

Use that hub to enter a showcase scene with buttons instead of changing the
project default startup repeatedly.

Open one of these in Godot to inspect a specific sample set without changing the
project's default startup scene:

- `minimal_validation_showcase.tscn`
- `archetype_sunflower_showcase.tscn`
- `archetype_lifecycle_showcase.tscn`
- `archetype_on_place_showcase.tscn`
- `archetype_state_showcase.tscn`
- `archetype_attack_showcase.tscn`
- `archetype_projectile_showcase.tscn`
- `archetype_zombie_showcase.tscn`
- `archetype_mower_showcase.tscn`
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
- `aura_chaos_showcase.tscn`
- `delayed_trigger_chaos_showcase.tscn`
- `delayed_explode_chaos_showcase.tscn`
- `mark_chaos_showcase.tscn`

Phase 5 分组的额外说明见：

- `PHASE5_CHAOS_README.md`

All of them use `BattleManager` directly and keep restart enabled with `R`.
Each showcase scene also supports:

- `Esc` to return to the showcase hub

## Boundary

- `scenes/showcase/`
  - For human-facing demonstration and navigation only.
- `scenes/validation/`
  - For verification scenarios and regression entry points.
- formal combat data
  - Should be authored under `data/combat/` and referenced into battle scenarios as needed.
