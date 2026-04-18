# Combat Data Layout

This directory stores combat-facing Resource content for the runtime and validation pipeline.

## Directory Rules

- `height_bands/`
  - Height range resources for entity hit resolution.
- `projectile_profiles/`
  - Flight and hit-strategy resources.
- `projectile_templates/`
  - Projectile content templates.
- `trigger_bindings/`
  - Template behavior binding resources.
- `cards/`
  - Formal card definitions and reusable card rosters.
- `waves/`
  - Formal wave templates and spawn pacing resources.
- `levels/`
  - Reserved for formal level-side data and shared level metadata.
- `battlefields/`
  - Reserved for battlefield and board-semantics presets.
- `entity_templates/plants/`
  - Plant entity templates.
- `entity_templates/zombies/`
  - Zombie entity templates.

## Conventions

- New entity templates must not be added back into a flat `templates/` directory.
- `EntityTemplate` resources should be split by major entity kind at minimum.
- `ProjectileTemplate` resources should describe the projectile itself, not the firing entity.
- `TriggerBinding` resources should describe when a template triggers an effect, not long-lived entity stats.
- Formal battle content should prefer `data/combat/*` trees over `scenes/validation` or `scenes/showcase`.
- `scenes/validation/` is for verification scenarios.
- `scenes/showcase/` is for display wrappers only.

## First Batch Samples

### Height Bands

- `ground_unit`
- `ground_unit_large`
- `air_unit_low`
- `air_unit_medium`
- `air_unit_high`

### Projectile Profiles

- `linear_ground`
- `linear_fast_swept`
- `linear_air`
- `track_ground`
- `track_air`
- `parabola_arc`
- `parabola_cabbage_arc`
- `parabola_long_arc`
- `parabola_terminal_blast`

### Plant Templates

- `plant_basic_shooter`
- `plant_track_bomber`
- `plant_repeater_burst`
- `plant_air_interceptor`
- `plant_cabbage_lobber`
- `plant_melon_lobber`
- `plant_wall_barrier`
- `plant_frost_pea`
- `plant_spore_summoner`
- `plant_sporeling`

### Zombie Templates

- `zombie_lane_dummy`
- `zombie_reactive_bomber`
- `zombie_basic_walker`
- `zombie_brisk_runner`
- `zombie_bucket_tank`
- `zombie_air_scout`
- `zombie_boss_heavy`
- `zombie_bone_thrower`
- `zombie_tar_spitter`
