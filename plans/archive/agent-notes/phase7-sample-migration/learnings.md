# Phase 7 Learnings

## 2026-05-07 Init
- Phase 7: Sample content migration using original source code values
- Core formula: distance_slots = original_px / 80.0, speed_slots_per_sec = original_px_per_tick / 80.0 * 100.0, seconds = original_ticks / 100.0
- ORIGINAL_SLOT_PX = 80.0 (from Board::GridToPixelX() / PixelToGridX())
- ORIGINAL_TICK_HZ = 100.0 (original tick maps directly to Open PVZ simulation tick)
- Priority: vendor/de-pvz source > migration ledger docs > current .tres (for location only) > current values (fallback only)

## 2026-05-07 Task 7.2: 9 plant archetype .tres migration complete
- **9 files modified** in `data/combat/archetypes/plants/`
- **Godot .tres dictionary format**: NO indentation — keys start at column 0 after newline (confirmed via hex dump: `0A-22` byte sequence)
- **StringName literals**: use `&"full_lane"` format in .tres (not just `"full_lane"`)
- **speed_slots_per_sec formula**: original_px_per_tick / 80.0 * 100.0 → 3.33/80*100 = 4.1625 (all projectile plants share this)
- **scan_range_slots formula**: original_reach_px / 80.0
  - Puff/Sea-shroom: (60+230)/80 = 3.625
  - Fume-shroom: (60+340)/80 = 5.0
  - Potato Mine: (80-25)/80 = 0.6875
  - Tangle Kelp: 80/80 = 1.0
  - Hypno-shroom: 55/80 = 0.6875 (protocol approximation from bite-trigger to proximity)
- **Undisturbed fields**: interval, damage, amount, start_delay, required_state, hit_strategy, max_penetrations, arming_time, radius, target_mode, max_health, hitbox_size, tags, mechanics — all preserved
- **Edit tool precision**: used multi-line oldString/toNewString blocks for files with 2 changes, single-line blocks for files with 1 change
- **Puff-shroom special**: uses direct_damage_payload, not projectile → only scan_range migrated, no speed field
- LSP diagnostics on .tres directory returned "no supported source files" — expected, .tres is not a source language
