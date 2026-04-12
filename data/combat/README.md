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
- `entity_templates/plants/`
  - Plant entity templates.
- `entity_templates/zombies/`
  - Zombie entity templates.

## Conventions

- New entity templates must not be added back into a flat `templates/` directory.
- `EntityTemplate` resources should be split by major entity kind at minimum.
- `ProjectileTemplate` resources should describe the projectile itself, not the firing entity.
- `TriggerBinding` resources should describe when a template triggers an effect, not long-lived entity stats.
