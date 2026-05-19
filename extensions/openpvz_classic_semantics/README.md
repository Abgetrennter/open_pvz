# OpenPVZ Classic Semantics

This public extension pack contains only templates and semantic notes for the local private classic reanim import workflow.

It must not contain original `.reanim`, `.png`, `.ogg`, or Godot resources generated from private original assets. Private sources and generated actor/profile resources belong in a local private asset pack outside the public release set.

Use this pack as the stable, publishable reference for:

- reanim track semantic classification
- Action Recipe fields
- Part Slot naming
- expected private asset pack layout
- `asset_index.json` runtime asset index shape

The private asset pack should keep source files and runtime files separate:

- `sources/`: private original inputs only.
- `generated/raw/`: raw importer outputs used for debugging and composite construction.
- `actors/` and `data/combat/visual_profiles/`: OpenPVZ runtime assets.
- `asset_index.json`: logical visual IDs mapped to runtime assets, source inputs, and generated reports.
