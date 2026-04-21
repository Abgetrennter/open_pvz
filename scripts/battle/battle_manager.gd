extends Node2D
class_name BattleManager

signal validation_completed(status: StringName)

const BattleScenarioRef = preload("res://scripts/battle/battle_scenario.gd")
const BattleProjectileEffectResolverRef = preload("res://scripts/battle/battle_projectile_effect_resolver.gd")
const BattleValidationReporterRef = preload("res://scripts/battle/battle_validation_reporter.gd")
const BattleValidationTrackerRef = preload("res://scripts/battle/battle_validation_tracker.gd")
const BattleSpawnerRef = preload("res://scripts/battle/battle_spawner.gd")
const BattleScenarioProviderRef = preload("res://scripts/battle/battle_scenario_provider.gd")
const BattleSubsystemHostRef = preload("res://scripts/battle/battle_subsystem_host.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const DebugOverlayRef = preload("res://scripts/debug/debug_overlay.gd")

var lane_y_map := {
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
var _projectile_effect_resolver: Variant = BattleProjectileEffectResolverRef.new()
var _validation_reporter: Variant = BattleValidationReporterRef.new()
var _validation_tracker: Variant = BattleValidationTrackerRef.new()
var _spawner: Variant = BattleSpawnerRef.new()
var _scenario_provider: Variant = BattleScenarioProviderRef.new()
var _subsystem_host: Variant = BattleSubsystemHostRef.new()
var _entity_root: Node2D = null
var _collectible_root: Node2D = null
var _runtime_frame_counter := 0
var _scenario_override_failed := false


func _ready() -> void:
	_scenario_provider.bind_battle(self)
	_scenario_provider.apply_runtime_options()
	_projectile_effect_resolver.bind_battle(self)
	_validation_reporter.bind_battle(self)
	_validation_tracker.bind_battle(self)
	_spawner.bind_battle(self)
	_subsystem_host.bind_battle(self)
	if _scenario_override_failed:
		if auto_quit_on_validation:
			get_tree().quit(1)
		return
	_entity_root = _ensure_entity_root()
	_collectible_root = _ensure_collectible_root()
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
	_validation_tracker.update_validation_state()
	_validation_tracker.process_auto_quit(delta)
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
	_subsystem_host.clear_runtime_entities(_entity_root, _collectible_root)
	GameState.begin_battle(self)
	EventBus.clear()
	if DebugService.has_method("clear_logs"):
		DebugService.clear_logs()
	_validation_tracker.reset_validation()
	if EffectRegistry.has_method("rebuild_registry"):
		EffectRegistry.rebuild_registry()
	_rebuild_lane_config()
	_subsystem_host.reset_runtime_services()
	_spawner.spawn_scenario()


# -- Spawn facade delegates --

func spawn_projectile_from_effect(context, params: Dictionary, on_hit_effect = null) -> Node:
	return _spawner.spawn_projectile_from_effect(context, params, on_hit_effect)


func spawn_entity_from_effect(context, params: Dictionary, metadata: Dictionary = {}) -> Node:
	return _spawner.spawn_entity_from_effect(context, params, metadata)


func spawn_card_entity(entity_template_id: StringName, lane_id: int, slot_index: int, metadata: Dictionary = {}) -> Node:
	return _spawner.spawn_card_entity(entity_template_id, lane_id, slot_index, metadata)


func spawn_wave_entry(spawn_entry: Resource, wave_id: StringName = StringName()):
	return _spawner.spawn_wave_entry(spawn_entry, wave_id)


func finalize_spawned_entity(entity: Node, lane_id: int, hit_height_band: Resource, trigger_instances: Array, source_node: Node = null, metadata: Dictionary = {}, emit_spawn_event: bool = true) -> void:
	_spawner.finalize_spawned_entity(entity, lane_id, hit_height_band, trigger_instances, source_node, metadata, emit_spawn_event)


func _finalize_spawned_entity(entity: Node, lane_id: int, hit_height_band: Resource, trigger_instances: Array, source_node: Node = null, metadata: Dictionary = {}, emit_spawn_event: bool = true) -> void:
	finalize_spawned_entity(entity, lane_id, hit_height_band, trigger_instances, source_node, metadata, emit_spawn_event)


func emit_entity_spawned(entity: Node, lane_id: int, source_node: Node = null, metadata: Dictionary = {}) -> void:
	_spawner.emit_entity_spawned(entity, lane_id, source_node, metadata)


func _emit_entity_spawned(entity: Node, lane_id: int, source_node: Node = null, metadata: Dictionary = {}) -> void:
	emit_entity_spawned(entity, lane_id, source_node, metadata)


func apply_spawn_height_band(entity: Node, height_band: Resource) -> void:
	_spawner.apply_spawn_height_band(entity, height_band)


func _apply_spawn_height_band(entity: Node, height_band: Resource) -> void:
	apply_spawn_height_band(entity, height_band)


func bind_runtime_triggers(entity: Node, trigger_instances: Array) -> void:
	_spawner.bind_runtime_triggers(entity, trigger_instances)


func _bind_runtime_triggers(entity: Node, trigger_instances: Array) -> void:
	bind_runtime_triggers(entity, trigger_instances)


# -- Runtime entity access --

func get_runtime_entities() -> Array:
	return _subsystem_host.get_runtime_entities(_entity_root, _collectible_root)


func get_runtime_combat_entities() -> Array:
	if _entity_root == null:
		return []
	return _entity_root.get_children()


# -- Subsystem delegation --

func get_current_sun() -> int:
	var economy: Node = _subsystem_host.get_economy_state()
	if economy == null:
		return 0
	return int(economy.get_current_sun())


func try_spend_sun(cost: int, reason: StringName = &"manual_spend", source_node: Node = null, metadata: Dictionary = {}) -> bool:
	var economy: Node = _subsystem_host.get_economy_state()
	if economy == null:
		return false
	return bool(economy.try_spend_sun(cost, reason, source_node, metadata))


func validate_placement_request(request: Resource) -> Dictionary:
	var board: Node = _subsystem_host.get_board_state()
	if board == null:
		return {"valid": false, "reason": &"board_missing"}
	return board.validate_request(request)


func reject_placement_request(request: Resource, reason: StringName) -> void:
	var board: Node = _subsystem_host.get_board_state()
	if board == null:
		return
	board.reject_request(request, reason)


func commit_placement_request(request: Resource, entity: Node) -> bool:
	var board: Node = _subsystem_host.get_board_state()
	if board == null:
		return false
	return bool(board.commit_request(request, entity))


func get_entity_factory() -> RefCounted:
	return _spawner._entity_factory


# -- Lane geometry --

func is_valid_lane(lane_id: int) -> bool:
	return lane_y_map.has(lane_id)


func get_lane_ids() -> PackedInt32Array:
	var lane_ids: Array[int] = []
	for lane_key in lane_y_map.keys():
		lane_ids.append(int(lane_key))
	lane_ids.sort()
	return PackedInt32Array(lane_ids)


func get_lane_y(lane_id: int) -> float:
	return float(lane_y_map.get(lane_id, 220.0))


func _lane_y(lane_id: int) -> float:
	return float(lane_y_map.get(lane_id, 220.0))


# -- Scenario access (facade to provider) --

func get_scenario_name() -> String:
	return _scenario_provider.get_scenario_name()


func get_scenario_goals() -> PackedStringArray:
	return _scenario_provider.get_scenario_goals()


func get_scenario_description() -> String:
	return _scenario_provider.get_scenario_description()


func resolve_scenario():
	return _scenario_provider.resolve_scenario()


func _resolve_scenario():
	return resolve_scenario()


func build_default_scenario():
	return _scenario_provider.build_default_scenario()


func _build_default_scenario():
	return build_default_scenario()


func make_spawn_entry(entity_template_id: StringName, lane_id: int, x_position: float, params: Dictionary):
	return _scenario_provider.make_spawn_entry(entity_template_id, lane_id, x_position, params)


func _make_spawn_entry(entity_template_id: StringName, lane_id: int, x_position: float, params: Dictionary):
	return make_spawn_entry(entity_template_id, lane_id, x_position, params)


func make_validation_rule(
	rule_id: StringName,
	description: String,
	event_name: StringName,
	min_count: int = 1,
	max_count: int = -1,
	required_tags: PackedStringArray = PackedStringArray(),
	required_core_values: Dictionary = {}
):
	return _scenario_provider.make_validation_rule(rule_id, description, event_name, min_count, max_count, required_tags, required_core_values)


func _make_validation_rule(
	rule_id: StringName,
	description: String,
	event_name: StringName,
	min_count: int = 1,
	max_count: int = -1,
	required_tags: PackedStringArray = PackedStringArray(),
	required_core_values: Dictionary = {}
):
	return make_validation_rule(rule_id, description, event_name, min_count, max_count, required_tags, required_core_values)


# -- Validation facade delegates --

func get_validation_status() -> String:
	return _validation_tracker.get_validation_status()


func get_validation_summary_lines(limit: int = 3) -> PackedStringArray:
	return _validation_tracker.get_validation_summary_lines(limit)


func get_unsatisfied_validation_descriptions() -> PackedStringArray:
	return _validation_tracker.get_unsatisfied_validation_descriptions()


func _on_validation_event(event_name: StringName, event_data: Variant) -> void:
	_validation_tracker.on_validation_event(event_name, event_data)


# -- Private getters for extracted coordinators --

func emit_validation_completed(status: StringName) -> void:
	validation_completed.emit(status)


func _emit_validation_completed(status: StringName) -> void:
	emit_validation_completed(status)


func get_validation_reporter() -> RefCounted:
	return _validation_reporter


func _get_validation_reporter() -> RefCounted:
	return get_validation_reporter()


func get_entity_root() -> Node2D:
	return _entity_root


func _get_entity_root() -> Node2D:
	return get_entity_root()


func get_collectible_root() -> Node2D:
	return _collectible_root


func _get_collectible_root() -> Node2D:
	return get_collectible_root()


func get_projectile_effect_resolver() -> RefCounted:
	return _projectile_effect_resolver


func _get_projectile_effect_resolver() -> RefCounted:
	return get_projectile_effect_resolver()


func get_board_state() -> Node:
	return _subsystem_host.get_board_state()


func _get_board_state() -> Node:
	return get_board_state()


func get_field_object_state() -> Node:
	return _subsystem_host.get_field_object_state()


func _get_field_object_state() -> Node:
	return get_field_object_state()


func get_economy_state() -> Node:
	return _subsystem_host.get_economy_state()


func _get_economy_state() -> Node:
	return get_economy_state()


# -- Scene tree helpers --

func _ensure_entity_root() -> Node2D:
	var root := get_node_or_null("RuntimeEntities") as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "RuntimeEntities"
		add_child(root)
	return root


func _ensure_collectible_root() -> Node2D:
	var root := get_node_or_null("RuntimeCollectibles") as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "RuntimeCollectibles"
		add_child(root)
	return root


func _spawn_debug_overlay() -> void:
	var overlay: Variant = DebugOverlayRef.new()
	add_child(overlay)
	overlay.bind_battle_root(self)


# -- Debug / protocol reporting --

func _record_runtime_snapshot() -> void:
	if not DebugService.has_method("record_runtime_snapshot"):
		return
	var scenario_name := get_scenario_name()
	DebugService.record_runtime_snapshot(_runtime_frame_counter, GameState.current_time, scenario_name, get_runtime_entities())


func report_protocol_issues(errors: Array[String], scope: StringName) -> void:
	for error in errors:
		push_warning(error)
		if DebugService.has_method("record_protocol_issue"):
			DebugService.record_protocol_issue(scope, error, &"error")


func _report_protocol_issues(errors: Array[String], scope: StringName) -> void:
	report_protocol_issues(errors, scope)


# -- Rendering --

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, playfield_size), Color("d5f0b1"))
	var lane_ids := get_lane_ids()
	if lane_ids.is_empty():
		return
	var first_y := float(lane_y_map.get(lane_ids[0], 220.0))
	var last_y := float(lane_y_map.get(lane_ids[-1], 320.0))
	draw_rect(Rect2(Vector2(0, first_y - 40), Vector2(playfield_size.x, last_y - first_y + 80)), Color("b4dd7f"))
	for lane_key in lane_ids:
		var y := float(lane_y_map.get(lane_key, 220.0))
		draw_line(Vector2(80, y), Vector2(playfield_size.x - 80, y), Color("6f9d53"), 2.0)
	if lane_ids.size() > 1:
		for i in range(lane_ids.size() - 1):
			var y1 := float(lane_y_map.get(lane_ids[i], 220.0))
			var y2 := float(lane_y_map.get(lane_ids[i + 1], 320.0))
			draw_line(Vector2(80, (y1 + y2) * 0.5), Vector2(playfield_size.x - 80, (y1 + y2) * 0.5), Color("8db768"), 1.0)


func _rebuild_lane_config() -> void:
	var active_scenario = resolve_scenario()
	if active_scenario == null:
		lane_y_map = {0: 220.0, 1: 320.0}
		return
	var lane_count := int(active_scenario.get("lane_count"))
	var battlefield_preset: Variant = active_scenario.get("battlefield_preset")
	if battlefield_preset != null and battlefield_preset.get("lane_count") != null:
		lane_count = int(battlefield_preset.get("lane_count"))
	if lane_count <= 0:
		lane_count = 2
	if lane_count == 2:
		lane_y_map = {0: 220.0, 1: 320.0}
		return
	lane_y_map.clear()
	var top_y := 185.0
	var spacing := 60.0
	for i in range(lane_count):
		lane_y_map[i] = top_y + float(i) * spacing
