extends RefCounted
class_name BattleScenarioProvider

const BattleScenarioRef = preload("res://scripts/battle/battle_scenario.gd")
const BattleSpawnEntryRef = preload("res://scripts/battle/battle_spawn_entry.gd")
const BattleValidationRuleRef = preload("res://scripts/battle/battle_validation_rule.gd")

var _battle: Node = null


func bind_battle(battle: Node) -> void:
	_battle = battle


func apply_runtime_options() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg == "--validation-auto-quit":
			_battle.auto_quit_on_validation = true
			continue
		if arg == "--validation-print-report":
			_battle.print_validation_report = true
			continue
		if arg == "--validation-no-overlay":
			_battle.show_debug_overlay = false
			continue
		if arg == "--runtime-snapshot-log":
			_battle.enable_runtime_snapshot_logging = true
			continue
		if arg.begins_with("--runtime-snapshot-interval="):
			_battle.runtime_snapshot_interval_frames = maxi(1, int(arg.trim_prefix("--runtime-snapshot-interval=")))
			continue
		if arg.begins_with("--validation-scenario="):
			_battle.scenario_override_path = arg.trim_prefix("--validation-scenario=")
			continue
		if arg.begins_with("--validation-scenario-id="):
			_battle.scenario_registry_id = StringName(arg.trim_prefix("--validation-scenario-id="))
			continue
		if arg.begins_with("--validation-output-dir="):
			_battle.validation_output_dir = arg.trim_prefix("--validation-output-dir=")
			continue
		if arg.begins_with("--validation-run-label="):
			_battle.validation_run_label = arg.trim_prefix("--validation-run-label=")
			continue

	if _battle.scenario_override_path.is_empty():
		return
	var loaded_scenario: Resource = load(_battle.scenario_override_path)
	if loaded_scenario != null and loaded_scenario.get_script() == BattleScenarioRef:
		_battle.scenario = loaded_scenario
		_battle._scenario_override_failed = false
		return
	_battle._scenario_override_failed = true
	push_warning("Failed to load validation scenario override: %s" % _battle.scenario_override_path)


func resolve_scenario():
	if _battle._scenario_override_failed:
		return null
	var scenario: Resource = _battle.scenario
	if scenario != null and scenario.get_script() == BattleScenarioRef:
		return scenario
	var scenario_registry_id: StringName = _battle.scenario_registry_id
	if scenario_registry_id != StringName() and SceneRegistry.has_validation_scenario(scenario_registry_id):
		var registered_scenario = SceneRegistry.get_validation_scenario(scenario_registry_id)
		if registered_scenario != null and registered_scenario.get_script() == BattleScenarioRef:
			return registered_scenario
	return build_default_scenario()


func build_default_scenario():
	var fallback = BattleScenarioRef.new()
	fallback.scenario_id = &"fallback_minimal_validation"
	fallback.display_name = "Fallback Minimal Battle Validation"
	fallback.description = "Fallback scenario used when no scene resource is assigned."
	fallback.goals = PackedStringArray([
		"Observe a full event chain from game.tick to projectile.hit to entity.damaged.",
		"Verify linear, track, and parabola projectile motion in two lanes.",
		"Verify when_damaged and on_death triggers reuse the same runtime backbone.",
	])
	fallback.validation_time_limit = 8.0
	fallback.validation_rules = [
		make_validation_rule(&"tick", "at least one game tick event", &"game.tick"),
		make_validation_rule(&"linear_spawn", "linear projectile spawn", &"projectile.spawned", 1, -1, PackedStringArray(["projectile"]), {"move_mode": &"linear"}),
		make_validation_rule(&"track_spawn", "track projectile spawn", &"projectile.spawned", 1, -1, PackedStringArray(["projectile"]), {"move_mode": &"track"}),
		make_validation_rule(&"parabola_hit", "parabola projectile hit", &"projectile.hit", 1, -1, PackedStringArray(["projectile"]), {"move_mode": &"parabola"}),
		make_validation_rule(&"projectile_damage", "projectile damage event", &"entity.damaged", 1, -1, PackedStringArray(["projectile"])),
		make_validation_rule(&"death_chain", "at least one death event", &"entity.died"),
		make_validation_rule(&"explode_damage", "death-triggered explosion damage", &"entity.damaged", 1, -1, PackedStringArray(["explode", "entity.died"])),
	]
	fallback.spawns = [
		make_spawn_entry(&"archetype_basic_shooter", 0, 160.0, {"interval": 1.4, "damage": 20, "speed": 220.0}),
		make_spawn_entry(&"archetype_track_bomber", 0, 250.0, {"interval": 2.1, "damage": 15, "speed": 210.0, "movement_mode": &"track", "turn_rate": 5.5}),
		make_spawn_entry(&"archetype_cabbage_lobber", 1, 160.0, {"interval": 1.6, "damage": 20, "speed": 220.0, "travel_duration": 1.4}),
		make_spawn_entry(&"archetype_reactive_bomber", 0, 460.0, {}),
		make_spawn_entry(&"archetype_lane_dummy", 0, 650.0, {}),
		make_spawn_entry(&"archetype_lane_dummy", 1, 520.0, {}),
	]
	return fallback


func make_spawn_entry(archetype_id: StringName, lane_id: int, x_position: float, params: Dictionary):
	var entry = BattleSpawnEntryRef.new()
	entry.archetype_id = archetype_id
	entry.lane_id = lane_id
	entry.x_position = x_position
	entry.spawn_overrides = params.duplicate(true)
	return entry


func make_validation_rule(
	rule_id: StringName,
	description: String,
	event_name: StringName,
	min_count: int = 1,
	max_count: int = -1,
	required_tags: PackedStringArray = PackedStringArray(),
	required_core_values: Dictionary = {}
):
	var rule = BattleValidationRuleRef.new()
	rule.rule_id = rule_id
	rule.description = description
	rule.event_name = event_name
	rule.min_count = min_count
	rule.max_count = max_count
	rule.required_tags = required_tags
	rule.required_core_values = required_core_values.duplicate(true)
	return rule


func get_scenario_name() -> String:
	var active_scenario = resolve_scenario()
	if active_scenario == null:
		return "No Scenario"
	return active_scenario.display_name


func get_scenario_goals() -> PackedStringArray:
	var active_scenario = resolve_scenario()
	if active_scenario == null:
		return PackedStringArray()
	return active_scenario.goals


func get_scenario_description() -> String:
	var active_scenario = resolve_scenario()
	if active_scenario == null:
		return ""
	return active_scenario.description
