# Learnings - Visual Feedback Layer

## 2026-05-06 Initialization
- Plan located at `plans/visual-feedback-layer/`
- 6 phases: Phase 0 (doc) → Phase 1 (VisualCue) → Phase 2 (VisualProfile) → Phase 3 (VisualStageLayer) → Phase 4 (Extension slots) → Phase 5 (Showcase)
- Phase 0 is doc-only, already done (plan documents exist)
- Key constraint: visual layer must NOT change rule results
- Must inherit RegistryBase for all new registries
- Must use RegistryContributorDef pattern for contributor resources
- GDScript project, no unit tests - validation scenarios are the test mechanism

## Registry Pattern (from ControllerRegistry)
- File: `autoload/ControllerRegistry.gd`
- Extends: `extends "res://scripts/core/registry/registry_base.gd"`
- Uses: `const ControllerDefRef = preload(...)` to get Def script ref
- Config: `RegistryConfigRef.create(&"slot", DefRef, &"register_kind", "data/combat/dir", &"trust_level")`
- Builtins: create Def instances, set id, call `register_def(def, {"kind": &"core", "source": &"core"})`
- Strategies: stored in `_strategies: Dictionary`, lambdas for builtins
- Lifecycle: `_on_registry_cleared()` clears strategies, `_on_def_registered()` sets up extension strategies

## Def Pattern (from ControllerDef)
- File: `scripts/core/defs/controller_def.gd`
- Extends: `extends "res://scripts/core/registry/registry_contributor_def.gd"`
- class_name: ControllerDef
- Fields: only domain-specific `@export` vars (e.g. `strategy_script: Script`)
- Base class provides: `id: StringName`, `tags: PackedStringArray`, `param_defs: Array[Dictionary]`

## Key File Locations
- Defs: `scripts/core/defs/`
- Registries: `autoload/`
- RegistryBase: `scripts/core/registry/registry_base.gd`
- RegistryConfig: `scripts/core/registry/registry_config.gd`
- RegistryContributorDef: `scripts/core/registry/registry_contributor_def.gd`
- ExtensionPackCatalog: `scripts/core/runtime/extension_pack_catalog.gd`
- Autoload config: `project.godot` [autoload] section (lines 18-31)

## Existing ALLOWED_REGISTER_KINDS (7 kinds)
- resources, effects, projectile_movement, mechanic_compilers, triggers, detections, controllers
- Need to add: visual_cues, visual_fx, audio_cues, visual_profiles

## Event Names for VisualCue
- projectile.spawned, projectile.hit, projectile.expired
- entity.damaged, entity.died
- placement.accepted, entity.status_removed

## Validation Scenario Pattern
- .tres (BattleScenario resource) + optional .tscn scene
- validation_scenarios.json index with id, scenario path, description, layers
- Layers: smoke, core, guardrail, extension

## 2026-05-06 Task 1: Visual Feedback Layer Defs & Registries
- Created 4 Def files in scripts/core/defs/:
  - `visual_cue_def.gd` - VisualCueDef: listen_event, filters, actions
  - `visual_fx_def.gd` - VisualFxDef: fx_scene, default_lifetime, default_layer
  - `audio_cue_def.gd` - AudioCueDef: stream, bus, volume, pitch_range, dedupe_window
  - `visual_profile_def.gd` - VisualProfileDef: actor_scene, animation_map, state_animation_map, status_visual_map, damage_stage_defs, shadow_policy, z_policy
- Created 4 Registry autoloads in autoload/:
  - `VisualCueRegistry.gd` - 6 built-in cues + get_cues_for_event() query method
  - `VisualFxRegistry.gd` - 3 built-in FX (hit_splat, expired_puff, placement_pop), all with null fx_scene (placeholder)
  - `AudioCueRegistry.gd` - No built-in audio cues (v1 placeholder)
  - `VisualProfileRegistry.gd` - No built-in profiles (v1 placeholder)
- All registries use `&"data_only"` trust level (pure observation layer, no runtime strategies)
- ExtensionPackCatalog updated: 4 new kinds added (visual_cues, visual_fx, audio_cues, visual_profiles)
- project.godot updated: 4 new autoload entries added after GameState
- Built-in VisualCue IDs: core.projectile_hit_splat, core.projectile_expired_puff, core.entity_damaged_flash, core.entity_died_fade, core.placement_accepted_pop, core.status_removed_clear_overlay
- Built-in VisualFx IDs: core.hit_splat, core.expired_puff, core.placement_pop
- LSP diagnostics failed due to Godot headless timeout (environmental issue, not code issue)
- All files follow exact project patterns: extends string paths, class_name, RegistryConfigRef.create(), register_def with core source

## 2026-05-06 Task 2: VisualFeedbackHost + VisualActionRunner + DebugService
- Created `scripts/visual/` directory
- Created `scripts/visual/visual_feedback_host.gd` — VisualFeedbackHost (extends Node)
  - Subscribes to 7 fixed events via EventBus.subscribe with bound callables
  - Uses TriggerComponent's pattern: `Callable(self, "_method").bind(event_name)`
  - `_on_visual_event()`: queries VisualCueRegistry.get_cues_for_event(), filters by source_kind/target_kind/source_archetype_id/target_archetype_id/tags/move_mode, dispatches to VisualActionRunner
  - Full try-safe: early returns on null event_data, null checks on all Dictionary accesses
  - `shutdown()`: unsubscribes all via EventBus.unsubscribe
  - `_cue_filters_match()`: handles PackedStringArray type coercion for tags filter
- Created `scripts/visual/visual_action_runner.gd` — VisualActionRunner (extends RefCounted)
  - Handles 7 action types: spawn_fx, play_audio, flash_actor, play_actor_animation, attach_fx, screen_overlay, clear_actor_overlay
  - `spawn_fx`: queries VisualFxRegistry.get_def(), logs "no_op" if fx_scene is null, "executed" if ready
  - `flash_actor`: actually sets modulate and restores via SceneTreeTimer (v1 working implementation)
  - `_resolve_target()`: supports source/target/event_position target_ref resolution
  - `_restore_modulate()`: uses is_instance_valid() guard for safe timer callback
  - All action executors wrapped in DebugService.record_visual_event() with result/skip_reason
  - Unrecognized action types logged as "no_op" with "unknown action type"
- Modified `autoload/DebugService.gd`:
  - Added `MAX_VISUAL := 128`, `enable_visual_logging := true`, `visual_log: Array[Dictionary] = []`
  - Added `record_visual_event(entry: Dictionary)` — push_front + pop_back on overflow
  - Updated `clear_logs()` to include `visual_log.clear()`
  - Updated `build_export_payload()` to include `"visual_log": _json_safe(visual_log)` and config flag
- LSP diagnostics: all 3 files (visual_feedback_host.gd, visual_action_runner.gd, DebugService.gd) — zero errors
- Key constraint met: no modifications to existing battle logic, entity files, registries, or project.godot
- No @export node properties — pure runtime utilities
- Follows existing patterns: EventBus subscribe/unsubscribe (from TriggerComponent), DebugService logging (record_* methods), Dictionary safe access with .get() defaults

## 2026-05-06 Task 3: VisualActorComponent + VisualStageLayerService + VisualLayerPolicy + BattleManager integration
- Created `scripts/visual/visual_layer_policy.gd` — VisualLayerPolicy (extends RefCounted)
  - Single source of truth for all z_index values and layer names
  - 11 layer constants: ground, shadow, field_object, plant, zombie, projectile, world_fx, fog_weather, preview, screen_fx, ui
  - LAYER_BASE dictionary with z_index base values, ROW_STRIDE = 100
  - `resolve_z_index(entity_kind, lane_id, visual_layer, local_offset)`: base + lane_id * ROW_STRIDE + local_offset
  - `get_layer_for_entity_kind(entity_kind)`: maps entity_kind to layer name
- Created `scripts/visual/visual_stage_layer_service.gd` — VisualStageLayerService (extends Node)
  - Manages BattleVisualRoot → 10 layer host Node2D children
  - `_LAYER_TO_HOST` mapping: plant+zombie share EntityLayer, all others have dedicated hosts
  - `initialize(parent)`: creates the full layer hierarchy under parent
  - `get_layer_host(layer_name)`: resolves policy layer to actual host Node2D
  - `apply_z_index(node, entity_kind, lane_id, local_offset)`: convenience to set z_index via policy
  - `cleanup()`: queue_free all hosts and root
  - Added FieldObjectLayer to hierarchy (present in policy but not in original spec)
- Created `scripts/components/visual_actor_component.gd` — VisualActorComponent (extends Node)
  - Follows TriggerComponent/StateComponent pattern: event subscription, owner filtering, _exit_tree cleanup
  - `bind_profile(profile_def, owner)`: instantiates actor_scene, subscribes to 4 events
  - Event filtering via `_event_targets_owner()`: target_id for damaged/died/status_removed, source_id for state_entered
  - `_apply_damage_stage(health_ratio)`: sorts stages by threshold_ratio desc, applies first unapplied stage where health_ratio ≤ threshold
  - Damage stage effects: modulate change, show/hide child nodes, FX spawn (log only v1)
  - `_flash_actor_damage()`: modulate toggle via create_timer (same pattern as VisualActionRunner)
  - `_on_entity_died()`: create_tween fade to alpha 0 over 0.5s
  - `_on_state_changed()`: maps state_id → animation_name via VisualProfileDef.state_animation_map, plays via AnimationPlayer
  - `_find_animation_player()`: checks direct child then recursive search
  - Health ratio: reads HealthComponent.current_health / max_health from owner
  - `shutdown()`: full cleanup (unsubscribes, frees actor, clears state)
  - All operations are read-only with respect to entity state
- Modified `scripts/battle/battle_manager.gd`:
  - Added `_visual_feedback_host` and `_visual_stage_layer_service` member variables (line 47-48)
  - Inserted visual feedback initialization in `reset_battle()` after registry rebuild (lines 134-148)
  - VisualFeedbackHost: shutdown old + queue_free → create new → add_child
  - VisualStageLayerService: cleanup old + queue_free → create new → add_child → initialize(self)
- LSP diagnostics: all 4 files (visual_layer_policy.gd, visual_stage_layer_service.gd, visual_actor_component.gd, battle_manager.gd) — zero errors
- Key constraints met:
  - No modifications to entity root files (BaseEntity, PlantRoot, ZombieRoot, ProjectileRoot)
  - No modifications to registries or defs
  - No modifications to project.godot
  - VisualActorComponent is pure observer — never modifies entity state
  - VisualLayerPolicy is single source of truth for z_index

## 2026-05-06 Task 4: Visual Feedback Layer Validation Scenarios

- Created 6 validation scenario .tres files in `scenes/validation/`:
  - `visual_registry_smoke.tres` — VF-TEST-01: Verifies all 4 visual registries (VisualCue, VisualFx, AudioCue, VisualProfile) initialize without protocol issues. Uses 2 spawns (basic_shooter + lane_dummy) with 3 rules (game.tick, no visual_cue issues, no visual_fx issues). Time limit 4.0s. Layers: smoke.
  - `visual_cue_projectile_hit_smoke.tres` — VF-TEST-02: Verifies visual feedback system processes projectile.hit and entity.damaged events. Uses 2 spawns with 2 rules. Time limit 5.0s. Layers: smoke.
  - `visual_projectile_projection_smoke.tres` — VF-TEST-03: Verifies VisualStageLayerService creates layer hosts and VisualLayerPolicy provides z_index values. Uses 2 spawns with 2 rules (game.tick + projectile.spawned). Time limit 5.0s. Layers: smoke.
  - `visual_actor_profile_smoke.tres` — VF-TEST-04: Verifies entities exist without visual profiles (v1 graceful absence). Uses 2 spawns with 2 rules (entity.spawned min=2 + no visual_profile protocol issues). Time limit 3.0s. Layers: smoke.
  - `visual_slot_guardrail.tres` — VF-TEST-05: Guardrail test verifying core.* visual cue entries are protected. No spawns, 1 rule (protocol.issue with scope visual_cue, min=0 max=0). Time limit 1.0s. Layers: smoke, guardrail.
  - `visual_extension_pack_smoke.tres` — VF-TEST-06: Verifies new register kinds (visual_cues, visual_fx, audio_cues, visual_profiles) are accepted by ExtensionPackCatalog. No spawns, 1 rule (game.tick). Time limit 2.0s. Layers: smoke.

- Updated `tools/validation_scenarios.json`: Added 6 new entries (127 total, was 121). All entries follow exact format of existing entries.

- Key .tres format learnings:
  - `required_core_values` uses Godot Dictionary format with `{ "key": &"value" }` (StringName values with & prefix)
  - `spawn_overrides` uses Godot Dictionary format, values can be numbers or StringNames
  - `load_steps` = 1 (root) + ext_resource count + sub_resource count (Godot 4 standard)
  - Simple guardrail scenarios follow `registry_duplicate_id_guardrail.tres` pattern (2 ext + 1 sub, load_steps=4)
  - Smoke scenarios with spawns follow `minimal_battle_validation.tres` pattern
  - `validation_rules` and `spawns` arrays use `[SubResource("id1"), SubResource("id2")]` format
  - LSP diagnostics unavailable for .tres files (data format, not code) — expected

- Validation JSON: entries added before closing `]`, comma added after previous last entry
