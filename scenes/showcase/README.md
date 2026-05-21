# Showcase Scenes

These scenes are thin wrappers around already-validated battle scenario resources.

They are display/navigation entry points, not the source of truth for formal content organization.
Formal combat content should live in `data/combat/` and runtime battle scenarios should stay independent from showcase naming.

The project startup scene is a lightweight showcase hub:

- `res://scenes/main/main.tscn`

Use that hub to enter a showcase scene with buttons instead of changing the
project default startup repeatedly.

## Scene List (40 scenes)

All of them use `BattleManager` directly and keep restart enabled with `R`.
Each showcase scene also supports `Esc` to return to the showcase hub.

### Basic Demos & Validation (4 scenes)

- `demo_level.tscn` (in `scenes/demo/`) — Full playable MVP demo
- `minimal_validation_showcase.tscn` — Original backbone: linear/track/parabola projectiles
- `sun_click_validation.tscn` (in `scenes/validation/`) — Sun click collection event chain
- `card_place_validation.tscn` (in `scenes/validation/`) — Card placement full flow

### Archetype Compilation Chain (8 scenes)

- `archetype_sunflower_showcase.tscn` — Resource production via Trigger + Payload
- `archetype_lifecycle_showcase.tscn` — on_spawned lifecycle + produce_sun
- `archetype_on_place_showcase.tscn` — Card placement + on_place lifecycle
- `archetype_state_showcase.tscn` — State gating (arming -> active)
- `archetype_attack_showcase.tscn` — Direct damage via Trigger + Payload
- `archetype_projectile_showcase.tscn` — Linear + parabola projectile compilation
- `archetype_zombie_showcase.tscn` — Zombie archetype + bite runtime
- `archetype_mower_showcase.tscn` — Field object mower via sweep controller

### Zombie Infrastructure Protocol (4 scenes)

- `infrastructure_health_layers_showcase.tscn` — HealthLayer routing across attachment/shield/helm/body
- `infrastructure_damage_policy_showcase.tscn` — DamageLayerPolicy bypassing shield while respecting helm/body
- `infrastructure_movement_leap_showcase.tscn` — Movement.core.leap_once logical Z / airborne / landing visualization
- `infrastructure_exposure_showcase.tscn` — Exposure / HitPolicy default ground targeting and explicit opt-in states

### Content Samples (7 scenes)

- `air_interceptor_showcase.tscn` — Air tracking projectiles vs low/medium targets
- `repeater_burst_showcase.tscn` — Burst fire vs walker/runner zombies
- `lobber_catalog_showcase.tscn` — Cabbage direct + Melon splash lobber demo
- `zombie_roster_showcase.tscn` — Walker/runner/tank/heavy zombies vs bite runtime
- `sunflower_sun_production_showcase.tscn` — Multi-lane sun production with auto-collect
- `height_hit_showcase.tscn` — Height band hit rules
- `terminal_explode_showcase.tscn` — Terminal hit -> explosion chain

### Original Plant Gardens (8 scenes)

- `original_shooter_garden_showcase.tscn` — Peashooter, Repeater, Gatling, Threepeater, Split Pea
- `original_frost_control_garden_showcase.tscn` — Snow Pea, Ice-shroom, Cactus, Winter Melon, Cattail
- `original_lobber_garden_showcase.tscn` — Cabbage, Kernel-pult, Melon-pult, Starfruit
- `original_production_garden_showcase.tscn` — Sunflower, Twin Sunflower, Sun-shroom, Marigold
- `original_mushroom_garden_showcase.tscn` — Puff, Fume, Gloom, Sea, Scaredy-shroom
- `original_explosion_garden_showcase.tscn` — Cherry Bomb, Jalapeno, Doom-shroom, Potato Mine
- `original_defense_support_garden_showcase.tscn` — Wall-nut, Tall-nut, Pumpkin, Spikeweed, Spikerock, Torchwood
- `original_special_garden_showcase.tscn` — Chomper, Squash, Tangle Kelp, Cob Cannon, Blover, Hypno-shroom

### Original Zombie Migration (5 scenes)

- `original_zombie_batch_a_showcase.tscn` — Basic, Flag, Conehead, Buckethead
- `original_zombie_batch_b_showcase.tscn` — Football, Screen Door, Newspaper, Pole Vaulter
- `original_zombie_batch_c_showcase.tscn` — Ducky Tube, Snorkel, Dolphin Rider, Zomboni
- `original_zombie_batch_d_showcase.tscn` — Balloon, Jack-in-the-Box, Digger, Pogo, Yeti, Bungee, Ladder, Catapult
- `original_zombie_batch_e_showcase.tscn` — Dancing, Backup Dancer, Gargantuar, Imp, Redeye Gargantuar

### Error Techniques & Cascades (7 scenes)

- `chain_explosion_cascade_showcase.tscn` — Cascading death explosions
- `splash_zone_cascade_showcase.tscn` — Multi-target splash
- `fast_pursuit_cascade_showcase.tscn` — Tracking vs fast runner
- `multi_lane_retaliation_cascade_showcase.tscn` — Lane-isolated when_damaged retaliation
- `reactive_retaliation_chaos_showcase.tscn` — Dual repeater vs reactive retaliation
- `death_blossom_chaos_showcase.tscn` — Reactive bomber death explosion chain
- `tracking_barrage_chaos_showcase.tscn` — Ground + air tracking coexistence

## Boundary

- `scenes/showcase/` — For human-facing demonstration and navigation only.
- `scenes/validation/` — For verification scenarios and regression entry points.
- Formal combat data — Should be authored under `data/combat/` and referenced into battle scenarios as needed.
