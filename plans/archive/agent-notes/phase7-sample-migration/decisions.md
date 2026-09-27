# Phase 7 Decisions

## 2026-05-07 Init
- Strategy: Source code direct calculation priority, not reverse-engineering from current Open PVZ values
- Zombies/lawn mowers included in Phase 7 but audited independently from de-pvz source, not from plant migration docs
- Lobbed projectiles NOT simplified to fixed speed_slots_per_sec this phase; keep travel_duration / parabola profile semantics
- full_lane range_mode preferred over large numeric scan_range values
- Don't beautify numbers - use exact formula results, keep up to 6 decimal places
