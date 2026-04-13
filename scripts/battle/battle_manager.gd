extends Node2D
class_name BattleManager

signal validation_completed(status: StringName)

const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const BattleScenarioRef = preload("res://scripts/battle/battle_scenario.gd")
const BattleSpawnEntryRef = preload("res://scripts/battle/battle_spawn_entry.gd")
const BattleValidationRuleRef = preload("res://scripts/battle/battle_validation_rule.gd")
const HeightBandRef = preload("res://scripts/core/defs/height_band.gd")
const ProjectileTemplateRef = preload("res://scripts/core/defs/projectile_template.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const ProtocolValidatorRef = preload("res://scripts/core/runtime/protocol_validator.gd")
const DebugOverlayRef = preload("res://scripts/debug/debug_overlay.gd")
const ProjectileFlightProfileRef = preload("res://scripts/projectile/projectile_flight_profile.gd")

const LANE_Y := {
	0: 220.0,
	1: 320.0,
}

@export var tick_interval := 0.25
@export var playfield_size := Vector2(960.0, 540.0)
@export var scenario: Resource = null
@export var scenario_registry_id: StringName = StringName()
@export var allow_restart_input := true
@export var show_debug_overlay := true
@export var auto_quit_on_validation := false
@export var auto_quit_delay := 0.2
@export var print_validation_report := false
@export_file("*.tres") var scenario_override_path := ""
@export_dir var validation_output_dir := ""
@export var validation_run_label := ""
@export var enable_runtime_snapshot_logging := false
@export var runtime_snapshot_interval_frames := 10

var _tick_accumulator := 0.0
var _entity_factory: Variant = EntityFactoryRef.new()
var _entity_root: Node2D = null
var _validation_status: StringName = &"pending"
var _validation_started_at := 0.0
var _validation_deadline := 0.0
var _validation_rule_states: Array[Dictionary] = []
var _validation_counts: Dictionary = {}
var _auto_quit_timer := -1.0
var _validation_reported := false
var _runtime_frame_counter := 0
var _scenario_override_failed := false


func _ready() -> void:
	_apply_runtime_options()
	if _scenario_override_failed:
		if auto_quit_on_validation:
			get_tree().quit(1)
		return
	_entity_root = _ensure_entity_root()
	if not EventBus.event_pushed.is_connected(_on_validation_event):
		EventBus.event_pushed.connect(_on_validation_event)
	queue_redraw()
	if show_debug_overlay:
		_spawn_debug_overlay()
	reset_battle()


func _exit_tree() -> void:
	GameState.end_battle(self)


func _process(delta: float) -> void:
	GameState.advance_time(delta)
	_update_validation_state()
	_process_auto_quit(delta)
	_tick_accumulator += delta

	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		var tick_event: Variant = EventDataRef.create()
		tick_event.core["game_time"] = GameState.current_time
		EventBus.push_event(&"game.tick", tick_event)


func _physics_process(_delta: float) -> void:
	if not enable_runtime_snapshot_logging:
		return
	_runtime_frame_counter += 1
	if runtime_snapshot_interval_frames <= 0:
		runtime_snapshot_interval_frames = 1
	if _runtime_frame_counter % runtime_snapshot_interval_frames != 0:
		return
	_record_runtime_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if not allow_restart_input:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
		reset_battle()


func reset_battle() -> void:
	_tick_accumulator = 0.0
	_runtime_frame_counter = 0
	_clear_runtime_entities()
	GameState.begin_battle(self)
	EventBus.clear()
	if DebugService.has_method("clear_logs"):
		DebugService.clear_logs()
	_reset_validation()
	_spawn_scenario()


func spawn_projectile_from_effect(context, params: Dictionary, on_hit_effect = null) -> Node:
	var direction := Vector2.RIGHT
	var resolved_params: Dictionary = _resolve_projectile_effect_params(params)
	var direction_value: Variant = resolved_params.get("direction", Vector2.RIGHT)
	if direction_value is Vector2:
		direction = direction_value

	var spawn_position: Vector2 = context.position
	if context.source_node != null and context.source_node is Node2D:
		spawn_position = context.source_node.global_position + direction.normalized() * 34.0

	var projectile_template = resolved_params.get("projectile_template", null)
	var projectile: Variant = _entity_factory.create_projectile(spawn_position, projectile_template, resolved_params)
	var speed := float(resolved_params.get("speed", 300.0))
	var damage := int(resolved_params.get("damage", 10))
	var movement_params: Dictionary = _build_projectile_movement_params(context, resolved_params, spawn_position, direction, speed)
	projectile.launch(direction, speed, context.source_node, on_hit_effect, damage, movement_params, {
		"depth": int(context.runtime.get("depth", context.depth)),
		"chain_id": context.chain_id,
		"origin_event_name": context.event_name,
	})
	_entity_root.add_child(projectile)
	return projectile


func _spawn_scenario() -> void:
	var active_scenario = _resolve_scenario()
	if active_scenario == null:
		return
	_report_protocol_issues(ProtocolValidatorRef.validate_battle_scenario(active_scenario), &"battle_scenario")
	for spawn_entry in active_scenario.spawns:
		_spawn_entry(spawn_entry)


func _spawn_entry(spawn_entry) -> void:
	if spawn_entry == null:
		return
	var active_scenario = _resolve_scenario()
	var scenario_id: StringName = StringName() if active_scenario == null else active_scenario.scenario_id
	var spawn_errors: Array[String] = ProtocolValidatorRef.validate_battle_spawn_entry(spawn_entry, scenario_id)
	if not spawn_errors.is_empty():
		_report_protocol_issues(spawn_errors, &"battle_spawn_entry")
		return

	var spawn_resolution: Dictionary = _entity_factory.instantiate_spawn_entry(
		spawn_entry,
		_build_spawn_entry_position(spawn_entry)
	)
	if spawn_resolution.is_empty():
		return

	var entry_kind: StringName = spawn_resolution.get("entity_kind", &"entity")
	var lane_id: int = spawn_entry.lane_id
	var hit_height_band: Resource = spawn_resolution.get("hit_height_band", null)
	var trigger_instances: Array = spawn_resolution.get("trigger_instances", [])
	var entity: Variant = spawn_resolution.get("entity", null)
	if entry_kind not in [&"plant", &"zombie"]:
		push_warning("Unsupported spawn entry kind: %s" % [String(entry_kind)])
		return
	if entity == null or not entity.has_method("assign_lane"):
		return
	entity.assign_lane(lane_id)
	_apply_spawn_height_band(entity, hit_height_band)
	_entity_root.add_child(entity)
	_bind_runtime_triggers(entity, trigger_instances)


func _spawn_debug_overlay() -> void:
	var overlay: Variant = DebugOverlayRef.new()
	add_child(overlay)
	overlay.bind_battle_root(self)


func _bind_runtime_triggers(entity: Node, trigger_instances: Array) -> void:
	var trigger_component: Variant = entity.get_node_or_null("TriggerComponent")
	if trigger_component == null:
		return
	trigger_component.bind_triggers(trigger_instances)


func _build_projectile_movement_params(context, params: Dictionary, spawn_position: Vector2, direction: Vector2, speed: float) -> Dictionary:
	var movement_params: Dictionary = {}
	var flight_profile: Resource = params.get("flight_profile", null)
	if flight_profile != null:
		var flight_errors: Array[String] = ProtocolValidatorRef.validate_projectile_flight_profile(flight_profile)
		if not flight_errors.is_empty():
			_report_protocol_issues(flight_errors, &"projectile_flight_profile")
			flight_profile = null
	if flight_profile != null and flight_profile.get_script() == ProjectileFlightProfileRef:
		movement_params = _movement_params_from_flight_profile(flight_profile)
	var movement_mode_default: Variant = movement_params.get("move_mode", &"linear")
	movement_params["move_mode"] = StringName(params.get("movement_mode", movement_mode_default))
	var move_mode: StringName = movement_params["move_mode"]

	match move_mode:
		&"parabola":
			var parabola_target: Node2D = _resolve_projectile_target_node(context)
			var configured_travel_duration := float(movement_params.get("travel_duration", -1.0))
			var default_travel_duration := _estimate_parabola_duration(spawn_position, parabola_target, speed) if configured_travel_duration <= 0.0 else configured_travel_duration
			var travel_duration := float(params.get("travel_duration", default_travel_duration))
			var impact_radius := float(params.get("impact_radius", movement_params.get("impact_radius", 34.0)))
			movement_params["start_position"] = spawn_position
			movement_params["target_node"] = parabola_target
			movement_params["target_position"] = _resolve_projectile_target_position(context, params, spawn_position, direction, speed, travel_duration, parabola_target)
			movement_params["travel_duration"] = travel_duration
			movement_params["arc_height"] = float(params.get("arc_height", movement_params.get("arc_height", 72.0)))
			movement_params["impact_radius"] = impact_radius
			movement_params["collision_padding"] = float(params.get("collision_padding", movement_params.get("collision_padding", 14.0)))
			movement_params["lead_time_scale"] = float(params.get("lead_time_scale", movement_params.get("lead_time_scale", 1.0)))
			var configured_dynamic_adjustment := float(movement_params.get("dynamic_target_adjustment", -1.0))
			var default_dynamic_adjustment := maxf(impact_radius * 1.5, _estimate_target_tracking_budget(parabola_target, travel_duration)) if configured_dynamic_adjustment < 0.0 else configured_dynamic_adjustment
			movement_params["dynamic_target_adjustment"] = float(params.get("dynamic_target_adjustment", default_dynamic_adjustment))
			movement_params["dynamic_target_axis"] = StringName(params.get("dynamic_target_axis", movement_params.get("dynamic_target_axis", &"x")))
		&"track":
			movement_params["target_node"] = _resolve_projectile_target_node(context)
			movement_params["turn_rate"] = float(params.get("turn_rate", 6.0))
		_:
			pass

	return movement_params


func _resolve_projectile_effect_params(params: Dictionary) -> Dictionary:
	var resolved: Dictionary = params.duplicate(true)
	var projectile_template = resolved.get("projectile_template", null)
	if projectile_template == null or not (projectile_template is ProjectileTemplateRef):
		return resolved

	var template_errors: Array[String] = ProtocolValidatorRef.validate_projectile_template(projectile_template)
	if not template_errors.is_empty():
		_report_protocol_issues(template_errors, &"projectile_template")
		resolved.erase("projectile_template")
		return resolved

	if projectile_template.default_params is Dictionary:
		for key: Variant in projectile_template.default_params.keys():
			if not resolved.has(key):
				resolved[key] = projectile_template.default_params[key]
	if not resolved.has("flight_profile") and projectile_template.flight_profile != null:
		resolved["flight_profile"] = projectile_template.flight_profile
	if not resolved.has("lifetime") and float(projectile_template.lifetime) > 0.0:
		resolved["lifetime"] = projectile_template.lifetime
	if not resolved.has("hitbox_radius") and float(projectile_template.hitbox_radius) > 0.0:
		resolved["hitbox_radius"] = projectile_template.hitbox_radius
	return resolved


func _movement_params_from_flight_profile(flight_profile: Resource) -> Dictionary:
	return {
		"profile_id": StringName(flight_profile.get("profile_id")),
		"move_mode": StringName(flight_profile.get("move_mode")),
		"height_strategy": StringName(flight_profile.get("height_strategy")),
		"flight_height": float(flight_profile.get("flight_height")),
		"arc_height": float(flight_profile.get("peak_height")),
		"projection_scale": float(flight_profile.get("projection_scale")),
		"max_hit_height": float(flight_profile.get("max_hit_height")),
		"hit_strategy": StringName(flight_profile.get("hit_strategy")),
		"terminal_hit_strategy": StringName(flight_profile.get("terminal_hit_strategy")),
		"impact_radius": float(flight_profile.get("impact_radius")),
		"collision_padding": float(flight_profile.get("collision_padding")),
		"travel_duration": float(flight_profile.get("travel_duration")),
		"lead_time_scale": float(flight_profile.get("lead_time_scale")),
		"dynamic_target_adjustment": float(flight_profile.get("dynamic_target_adjustment")),
		"dynamic_target_axis": StringName(flight_profile.get("dynamic_target_axis")),
	}


func _resolve_projectile_target_position(
	context,
	params: Dictionary,
	spawn_position: Vector2,
	direction: Vector2,
	speed: float,
	travel_duration: float,
	target_node: Node2D = null
) -> Vector2:
	var explicit_target: Variant = params.get("target_position", null)
	if explicit_target is Vector2:
		return explicit_target

	if target_node != null:
		return _predict_target_position(spawn_position, target_node, travel_duration, speed, params)

	var distance := float(params.get("distance", 280.0))
	return spawn_position + direction.normalized() * distance


func _resolve_projectile_target_node(context) -> Node2D:
	if context.target_node is Node2D:
		return context.target_node as Node2D
	if context.source_node == null:
		return null
	return _find_nearest_enemy(context.source_node)


func _find_nearest_enemy(source_node: Node) -> Node2D:
	if not (source_node is Node2D):
		return null

	var source_team: Variant = source_node.get("team")
	var source_lane: Variant = source_node.get("lane_id")
	var source_position: Vector2 = _node_ground_position(source_node as Node2D)
	var best_candidate: Node2D = null
	var best_distance := INF

	for child in get_runtime_entities():
		if child == null or child == source_node:
			continue
		if not child.has_method("take_damage"):
			continue
		if not (child is Node2D):
			continue
		if child.get("team") == source_team:
			continue
		if source_lane is int and child.get("lane_id") != source_lane:
			continue

		var candidate := child as Node2D
		var distance := source_position.distance_to(_node_ground_position(candidate))
		if distance < best_distance:
			best_distance = distance
			best_candidate = candidate

	return best_candidate


func _estimate_parabola_duration(spawn_position: Vector2, target_node: Node2D, speed: float) -> float:
	if target_node == null:
		return max(0.35, 360.0 / max(speed, 1.0))
	var distance := spawn_position.distance_to(_node_ground_position(target_node))
	return max(0.35, distance / max(speed, 1.0))


func _predict_target_position(
	spawn_position: Vector2,
	target_node: Node2D,
	travel_duration: float,
	projectile_speed: float,
	params: Dictionary
) -> Vector2:
	var current_position: Vector2 = _node_ground_position(target_node)
	var lead_time_scale := float(params.get("lead_time_scale", 1.0))
	var max_lead_distance := float(params.get("max_lead_distance", max(120.0, projectile_speed * travel_duration * 1.5)))
	var lead_iterations := maxi(1, int(params.get("lead_iterations", 3)))
	var velocity: Vector2 = _estimate_entity_velocity(target_node)
	var predicted_position := current_position
	for _iteration in range(lead_iterations):
		var intercept_time := maxf(spawn_position.distance_to(predicted_position) / maxf(projectile_speed, 1.0), 0.0)
		predicted_position = current_position + velocity * intercept_time * lead_time_scale
	var predicted_offset := predicted_position - current_position
	if predicted_offset.length() > max_lead_distance:
		predicted_offset = predicted_offset.normalized() * max_lead_distance
	return current_position + predicted_offset


func _estimate_entity_velocity(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO
	if node.has_method("get_entity_state"):
		var snapshot: Dictionary = node.call("get_entity_state")
		var values: Dictionary = snapshot.get("values", {})
		var velocity_value: Variant = values.get("velocity", Vector2.ZERO)
		if velocity_value is Vector2:
			return velocity_value
	if node.has_method("get") and node.get("team") == &"zombie" and node.has_method("is_combat_active") and node.call("is_combat_active"):
		var move_speed_value: Variant = node.get("move_speed")
		if move_speed_value is float or move_speed_value is int:
			return Vector2.LEFT * float(move_speed_value)
	return Vector2.ZERO


func _node_ground_position(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return node.global_position


func _estimate_target_tracking_budget(target_node: Node2D, travel_duration: float) -> float:
	if target_node == null:
		return 0.0
	return _estimate_entity_velocity(target_node).length() * travel_duration * 1.25


func _apply_spawn_height_band(entity: Node, height_band: Resource) -> void:
	if height_band == null:
		return
	var height_errors: Array[String] = ProtocolValidatorRef.validate_height_band(height_band)
	if not height_errors.is_empty():
		_report_protocol_issues(height_errors, &"height_band")
		return
	if height_band.get_script() != HeightBandRef:
		return
	if entity.has_method("apply_height_band"):
		entity.call("apply_height_band", height_band)


func get_runtime_entities() -> Array:
	if _entity_root == null:
		return []
	return _entity_root.get_children()


func get_scenario_name() -> String:
	var active_scenario = _resolve_scenario()
	if active_scenario == null:
		return "No Scenario"
	return active_scenario.display_name


func get_scenario_goals() -> PackedStringArray:
	var active_scenario = _resolve_scenario()
	if active_scenario == null:
		return PackedStringArray()
	return active_scenario.goals


func get_scenario_description() -> String:
	var active_scenario = _resolve_scenario()
	if active_scenario == null:
		return ""
	return active_scenario.description


func get_validation_status() -> String:
	return String(_validation_status)


func get_validation_summary_lines(limit: int = 3) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var status_text := String(_validation_status).to_upper()
	var remaining_time := maxf(_validation_deadline - GameState.current_time, 0.0)
	lines.append("Validation %s" % status_text)
	if _validation_status == &"pending":
		lines.append("Window %.1fs" % remaining_time)

	var shown := 0
	for rule_state in _validation_rule_states:
		if bool(rule_state.get("satisfied", false)):
			continue
		if bool(rule_state.get("exceeded", false)):
			lines.append("Exceeded %s" % String(rule_state.get("description", "")))
		else:
			lines.append("Need %s" % String(rule_state.get("description", "")))
		shown += 1
		if shown >= limit:
			break

	if shown == 0 and _validation_status == &"passed":
		lines.append("All scenario checks satisfied.")
	elif shown == 0 and _validation_status == &"failed":
		lines.append("Window expired before checks completed.")
	return lines


func get_unsatisfied_validation_descriptions() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for rule_state in _validation_rule_states:
		if bool(rule_state.get("satisfied", false)):
			continue
		if bool(rule_state.get("exceeded", false)):
			lines.append("Exceeded %s" % String(rule_state.get("description", "")))
		else:
			lines.append(String(rule_state.get("description", "")))
	return lines


func _resolve_scenario():
	if _scenario_override_failed:
		return null
	if scenario != null and scenario.get_script() == BattleScenarioRef:
		return scenario
	if scenario_registry_id != StringName() and SceneRegistry.has_validation_scenario(scenario_registry_id):
		var registered_scenario = SceneRegistry.get_validation_scenario(scenario_registry_id)
		if registered_scenario != null and registered_scenario.get_script() == BattleScenarioRef:
			return registered_scenario
	return _build_default_scenario()


func _build_default_scenario():
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
		_make_validation_rule(&"tick", "at least one game tick event", &"game.tick"),
		_make_validation_rule(&"linear_spawn", "linear projectile spawn", &"projectile.spawned", 1, -1, PackedStringArray(["projectile"]), {"move_mode": &"linear"}),
		_make_validation_rule(&"track_spawn", "track projectile spawn", &"projectile.spawned", 1, -1, PackedStringArray(["projectile"]), {"move_mode": &"track"}),
		_make_validation_rule(&"parabola_hit", "parabola projectile hit", &"projectile.hit", 1, -1, PackedStringArray(["projectile"]), {"move_mode": &"parabola"}),
		_make_validation_rule(&"projectile_damage", "projectile damage event", &"entity.damaged", 1, -1, PackedStringArray(["projectile"])),
		_make_validation_rule(&"death_chain", "at least one death event", &"entity.died"),
		_make_validation_rule(&"explode_damage", "death-triggered explosion damage", &"entity.damaged", 1, -1, PackedStringArray(["explode", "entity.died"])),
	]
	fallback.spawns = [
		_make_spawn_entry(&"plant_basic_shooter", 0, 160.0, {"interval": 1.4, "damage": 20, "speed": 220.0}),
		_make_spawn_entry(&"plant_track_bomber", 0, 250.0, {"interval": 2.1, "damage": 15, "speed": 210.0, "movement_mode": &"track", "turn_rate": 5.5}),
		_make_spawn_entry(&"plant_cabbage_lobber", 1, 160.0, {"interval": 1.6, "damage": 20, "speed": 220.0, "travel_duration": 1.4}),
		_make_spawn_entry(&"zombie_reactive_bomber", 0, 460.0, {}),
		_make_spawn_entry(&"zombie_lane_dummy", 0, 650.0, {}),
		_make_spawn_entry(&"zombie_lane_dummy", 1, 520.0, {}),
	]
	return fallback


func _make_spawn_entry(entity_template_id: StringName, lane_id: int, x_position: float, params: Dictionary):
	var entry = BattleSpawnEntryRef.new()
	entry.entity_template_id = entity_template_id
	entry.lane_id = lane_id
	entry.x_position = x_position
	entry.spawn_overrides = params.duplicate(true)
	return entry


func _build_spawn_entry_position(spawn_entry: Resource) -> Vector2:
	return Vector2(float(spawn_entry.get("x_position")), _lane_y(int(spawn_entry.get("lane_id"))))


func _make_validation_rule(
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


func _ensure_entity_root() -> Node2D:
	var root := get_node_or_null("RuntimeEntities") as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "RuntimeEntities"
		add_child(root)
	return root


func _clear_runtime_entities() -> void:
	if _entity_root == null:
		return
	for child in _entity_root.get_children():
		_entity_root.remove_child(child)
		child.queue_free()


func _reset_validation() -> void:
	_validation_status = &"pending"
	_validation_started_at = GameState.current_time
	var active_scenario = _resolve_scenario()
	_validation_deadline = GameState.current_time + (0.0 if active_scenario == null else float(active_scenario.validation_time_limit))
	_validation_rule_states.clear()
	_validation_counts.clear()
	_auto_quit_timer = -1.0
	_validation_reported = false
	if active_scenario == null:
		return

	for validation_rule in active_scenario.validation_rules:
		if validation_rule == null or validation_rule.get_script() != BattleValidationRuleRef:
			continue
		var initial_count := 0
		_validation_rule_states.append({
			"rule_id": validation_rule.rule_id,
			"description": validation_rule.description,
			"event_name": validation_rule.event_name,
			"min_count": validation_rule.min_count,
			"max_count": validation_rule.max_count,
			"required_tags": validation_rule.required_tags,
			"required_core_values": validation_rule.required_core_values.duplicate(true),
			"count": initial_count,
			"satisfied": _is_rule_satisfied(initial_count, validation_rule.min_count, validation_rule.max_count),
			"exceeded": _is_rule_exceeded(initial_count, validation_rule.max_count),
		})


func _on_validation_event(event_name: StringName, event_data: Variant) -> void:
	if _validation_status != &"pending":
		return
	if _validation_rule_states.is_empty():
		return

	for rule_state in _validation_rule_states:
		if rule_state["event_name"] != event_name:
			continue
		if not _event_matches_rule(event_data, rule_state):
			continue
		rule_state["count"] = int(rule_state.get("count", 0)) + 1
		rule_state["exceeded"] = _is_rule_exceeded(int(rule_state["count"]), int(rule_state.get("max_count", -1)))
		rule_state["satisfied"] = _is_rule_satisfied(
			int(rule_state["count"]),
			int(rule_state.get("min_count", 1)),
			int(rule_state.get("max_count", -1))
		)
		_validation_counts[rule_state["rule_id"]] = rule_state["count"]
		if bool(rule_state.get("exceeded", false)):
			_set_validation_status(&"failed")
			return

	_refresh_validation_status()


func _event_matches_rule(event_data: Variant, rule_state: Dictionary) -> bool:
	var event_tags := PackedStringArray(event_data.core.get("tags", PackedStringArray()))
	for required_tag in PackedStringArray(rule_state.get("required_tags", PackedStringArray())):
		if not event_tags.has(required_tag):
			return false

	var required_core_values: Dictionary = rule_state.get("required_core_values", {})
	for key: Variant in required_core_values.keys():
		if event_data.core.get(key, null) != required_core_values[key]:
			return false
	return true


func _refresh_validation_status() -> void:
	if _validation_rule_states.is_empty():
		_set_validation_status(&"passed")
		return
	for rule_state in _validation_rule_states:
		if bool(rule_state.get("exceeded", false)):
			_set_validation_status(&"failed")
			return
		if not bool(rule_state.get("satisfied", false)):
			return
	if _has_deadline_confirmed_rules():
		return
	_set_validation_status(&"passed")


func _update_validation_state() -> void:
	if _validation_status != &"pending":
		return
	if _validation_deadline <= 0.0:
		return
	if GameState.current_time <= _validation_deadline:
		return
	if _all_validation_rules_satisfied():
		_set_validation_status(&"passed")
		return
	if _validation_status != &"passed":
		_set_validation_status(&"failed")


func _set_validation_status(next_status: StringName) -> void:
	if _validation_status == next_status:
		return
	_validation_status = next_status
	if next_status == &"passed" or next_status == &"failed":
		_report_validation_result()
		validation_completed.emit(next_status)
		if auto_quit_on_validation:
			_auto_quit_timer = maxf(auto_quit_delay, 0.0)


func _report_validation_result() -> void:
	if _validation_reported:
		return
	if not print_validation_report and not auto_quit_on_validation and validation_output_dir.is_empty():
		return
	_validation_reported = true

	var status_label := "PASSED" if _validation_status == &"passed" else "FAILED"
	var active_scenario = _resolve_scenario()
	var scenario_label := "unknown"
	if active_scenario != null:
		scenario_label = "%s (%s)" % [active_scenario.display_name, String(active_scenario.scenario_id)]

	if print_validation_report or auto_quit_on_validation:
		print("[Validation] %s %s" % [status_label, scenario_label])
		for line in get_validation_summary_lines(12):
			print("[Validation] %s" % line)

	_export_validation_artifacts()


func _process_auto_quit(delta: float) -> void:
	if _auto_quit_timer < 0.0:
		return
	_auto_quit_timer -= delta
	if _auto_quit_timer > 0.0:
		return
	_auto_quit_timer = -1.0
	get_tree().quit(0 if _validation_status == &"passed" else 1)


func _apply_runtime_options() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg == "--validation-auto-quit":
			auto_quit_on_validation = true
			continue
		if arg == "--validation-print-report":
			print_validation_report = true
			continue
		if arg == "--validation-no-overlay":
			show_debug_overlay = false
			continue
		if arg == "--runtime-snapshot-log":
			enable_runtime_snapshot_logging = true
			continue
		if arg.begins_with("--runtime-snapshot-interval="):
			runtime_snapshot_interval_frames = maxi(1, int(arg.trim_prefix("--runtime-snapshot-interval=")))
			continue
		if arg.begins_with("--validation-scenario="):
			scenario_override_path = arg.trim_prefix("--validation-scenario=")
			continue
		if arg.begins_with("--validation-scenario-id="):
			scenario_registry_id = StringName(arg.trim_prefix("--validation-scenario-id="))
			continue
		if arg.begins_with("--validation-output-dir="):
			validation_output_dir = arg.trim_prefix("--validation-output-dir=")
			continue
		if arg.begins_with("--validation-run-label="):
			validation_run_label = arg.trim_prefix("--validation-run-label=")
			continue

	if scenario_override_path.is_empty():
		return
	var loaded_scenario: Resource = load(scenario_override_path)
	if loaded_scenario != null and loaded_scenario.get_script() == BattleScenarioRef:
		scenario = loaded_scenario
		_scenario_override_failed = false
		return
	_scenario_override_failed = true
	push_warning("Failed to load validation scenario override: %s" % scenario_override_path)


func _record_runtime_snapshot() -> void:
	if not DebugService.has_method("record_runtime_snapshot"):
		return
	var scenario_name := get_scenario_name()
	DebugService.record_runtime_snapshot(_runtime_frame_counter, GameState.current_time, scenario_name, get_runtime_entities())


func _report_protocol_issues(errors: Array[String], scope: StringName) -> void:
	for error in errors:
		push_warning(error)
		if DebugService.has_method("record_protocol_issue"):
			DebugService.record_protocol_issue(scope, error, &"error")


func _export_validation_artifacts() -> void:
	if validation_output_dir.is_empty():
		return
	var output_dir_path := _resolved_output_dir_path()
	if output_dir_path.is_empty():
		return

	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir_path)
	if mkdir_error != OK:
		push_warning("Failed to create validation output directory: %s (error %d)" % [output_dir_path, mkdir_error])
		return

	var report_path := output_dir_path.path_join("validation_report.json")
	var summary_path := output_dir_path.path_join("validation_summary.txt")
	var debug_log_path := output_dir_path.path_join("debug_logs.json")

	var report: Dictionary = _build_validation_report()
	var summary_text := "\n".join(get_validation_summary_lines(12)) + "\n"
	var debug_payload: Dictionary = {}
	if DebugService.has_method("build_export_payload"):
		debug_payload = DebugService.build_export_payload()

	_write_json_file(report_path, report)
	_write_text_file(summary_path, summary_text)
	_write_json_file(debug_log_path, debug_payload)
	print("[Validation] Artifacts exported to %s" % output_dir_path)


func _build_validation_report() -> Dictionary:
	var active_scenario = _resolve_scenario()
	var validation_rules: Array[Dictionary] = []
	for rule_state in _validation_rule_states:
		validation_rules.append({
			"rule_id": String(rule_state.get("rule_id", "")),
			"description": String(rule_state.get("description", "")),
			"event_name": String(rule_state.get("event_name", "")),
			"min_count": int(rule_state.get("min_count", 0)),
			"max_count": int(rule_state.get("max_count", -1)),
			"count": int(rule_state.get("count", 0)),
			"satisfied": bool(rule_state.get("satisfied", false)),
			"exceeded": bool(rule_state.get("exceeded", false)),
			"required_tags": Array(PackedStringArray(rule_state.get("required_tags", PackedStringArray()))),
			"required_core_values": rule_state.get("required_core_values", {}).duplicate(true),
		})

	return {
		"scenario_id": "" if active_scenario == null else String(active_scenario.scenario_id),
		"display_name": "" if active_scenario == null else String(active_scenario.display_name),
		"description": "" if active_scenario == null else String(active_scenario.description),
		"goals": [] if active_scenario == null else Array(active_scenario.goals),
		"status": String(_validation_status),
		"summary_lines": Array(get_validation_summary_lines(12)),
		"unsatisfied_rules": Array(get_unsatisfied_validation_descriptions()),
		"validation_time_limit": 0.0 if active_scenario == null else float(active_scenario.validation_time_limit),
		"started_at": _validation_started_at,
		"finished_at": GameState.current_time,
		"counts": _validation_counts.duplicate(true),
		"run_label": validation_run_label,
		"runtime_snapshot_enabled": enable_runtime_snapshot_logging,
		"runtime_snapshot_interval_frames": runtime_snapshot_interval_frames,
		"rules": validation_rules,
	}


func _all_validation_rules_satisfied() -> bool:
	if _validation_rule_states.is_empty():
		return true
	for rule_state in _validation_rule_states:
		if bool(rule_state.get("exceeded", false)):
			return false
		if not bool(rule_state.get("satisfied", false)):
			return false
	return true


func _has_deadline_confirmed_rules() -> bool:
	for rule_state in _validation_rule_states:
		if int(rule_state.get("max_count", -1)) >= 0:
			return true
	return false


func _is_rule_satisfied(count: int, min_count: int, max_count: int) -> bool:
	if count < min_count:
		return false
	if max_count >= 0 and count > max_count:
		return false
	return true


func _is_rule_exceeded(count: int, max_count: int) -> bool:
	return max_count >= 0 and count > max_count


func _resolved_output_dir_path() -> String:
	if validation_output_dir.is_empty():
		return ""
	if validation_output_dir.begins_with("res://") or validation_output_dir.begins_with("user://"):
		return ProjectSettings.globalize_path(validation_output_dir)
	return validation_output_dir


func _write_json_file(path: String, payload: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open validation artifact for writing: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _write_text_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open validation summary for writing: %s" % path)
		return
	file.store_string(contents)
	file.close()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, playfield_size), Color("d5f0b1"))
	draw_rect(Rect2(Vector2(0, 150), Vector2(playfield_size.x, 240)), Color("b4dd7f"))
	draw_line(Vector2(80, _lane_y(0)), Vector2(playfield_size.x - 80, _lane_y(0)), Color("6f9d53"), 2.0)
	draw_line(Vector2(80, _lane_y(1)), Vector2(playfield_size.x - 80, _lane_y(1)), Color("6f9d53"), 2.0)
	draw_line(Vector2(80, 270), Vector2(playfield_size.x - 80, 270), Color("8db768"), 1.0)


func _lane_y(lane_id: int) -> float:
	return float(LANE_Y.get(lane_id, 220.0))
