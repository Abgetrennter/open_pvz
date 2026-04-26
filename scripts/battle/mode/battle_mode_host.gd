extends Node
class_name BattleModeHost

const BattleModeModuleRegistryRef = preload("res://scripts/battle/mode/battle_mode_module_registry.gd")

var _battle: Node = null
var _mode_def: Resource = null
var _scenario: Resource = null
var _module_registry: RefCounted = null

var _resolved_mode_id: StringName = StringName()
var _resolved_input_profile: Resource = null
var _resolved_objective_def: Resource = null
var _resolved_rule_modules: Array[Resource] = []

var _objective_progress: Dictionary = {}
var _objective_completed := false
var _objective_failed := false


func setup(battle: Node, scenario: Resource, mode_def: Resource = null) -> void:
	_battle = battle
	_scenario = scenario
	_mode_def = mode_def
	_module_registry = BattleModeModuleRegistryRef.new()
	_resolved_mode_id = StringName()
	_resolved_input_profile = null
	_resolved_objective_def = null
	_resolved_rule_modules = []
	_objective_progress = {}
	_objective_completed = false
	_objective_failed = false
	if _mode_def == null:
		return
	_resolve_mode()
	_dispatch_modules(&"on_mode_setup", {})


func teardown() -> void:
	_dispatch_modules(&"on_mode_teardown", {})
	_mode_def = null
	_scenario = null
	_battle = null
	_module_registry = null
	_resolved_mode_id = StringName()
	_resolved_input_profile = null
	_resolved_objective_def = null
	_resolved_rule_modules = []
	_objective_progress = {}
	_objective_completed = false
	_objective_failed = false


func get_mode_def() -> Resource:
	return _mode_def


func get_resolved_input_profile() -> Resource:
	return _resolved_input_profile


func get_resolved_objective_def() -> Resource:
	return _resolved_objective_def


func get_resolved_rule_modules() -> Array[Resource]:
	return _resolved_rule_modules


func get_resolved_mode_id() -> StringName:
	return _resolved_mode_id


func on_tick(game_time: float) -> void:
	if _mode_def == null:
		return
	_dispatch_modules(&"on_game_tick", {"game_time": game_time})
	_evaluate_objective(game_time)


func on_event(event_name: StringName, event_data: Variant) -> void:
	if _mode_def == null:
		return
	_dispatch_modules(&"on_event", {"event_name": event_name, "event_data": event_data})


func get_debug_name() -> String:
	return "mode_host"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"template_id": StringName(),
		"entity_kind": &"battle_mode_host",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active" if _mode_def != null else &"none",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"mode_id": _resolved_mode_id,
			"has_input_profile": _resolved_input_profile != null,
			"has_objective_def": _resolved_objective_def != null,
			"rule_module_count": _resolved_rule_modules.size(),
			"objective_completed": _objective_completed,
			"objective_failed": _objective_failed,
		},
	}


func _resolve_mode() -> void:
	_resolved_mode_id = StringName(_mode_def.get("mode_id"))
	_resolved_input_profile = _resolve_input_profile()
	_resolved_objective_def = _resolve_objective_def()
	_resolved_rule_modules = _resolve_rule_modules()


func _resolve_input_profile() -> Resource:
	if _scenario == null:
		return _mode_def.get("input_profile") if _mode_def != null else null
	var override: Variant = _scenario.get("input_profile_override")
	if override != null:
		return override
	return _mode_def.get("input_profile") if _mode_def != null else null


func _resolve_objective_def() -> Resource:
	if _scenario == null:
		return _mode_def.get("objective_def") if _mode_def != null else null
	var override: Variant = _scenario.get("objective_override")
	if override != null:
		return override
	return _mode_def.get("objective_def") if _mode_def != null else null


func _resolve_rule_modules() -> Array[Resource]:
	var modules: Array[Resource] = []
	if _mode_def != null:
		var mode_modules: Variant = _mode_def.get("rule_modules")
		if mode_modules != null:
			for m in mode_modules:
				if m != null and m.get("enabled"):
					modules.append(m)
	if _scenario != null:
		var scenario_modules: Variant = _scenario.get("mode_rule_modules")
		if scenario_modules != null:
			for m in scenario_modules:
				if m != null and m.get("enabled"):
					modules.append(m)
	modules.sort_custom(func(a, b): return int(a.get("priority")) < int(b.get("priority")))
	return modules


func _dispatch_modules(action: StringName, context: Dictionary) -> void:
	if _module_registry == null or _battle == null:
		return
	for module in _resolved_rule_modules:
		var module_id: StringName = StringName(module.get("module_id"))
		var handler: Callable = _module_registry.get_handler(module_id)
		if handler.is_valid():
			handler.call(action, _battle, module, context)


func _evaluate_objective(game_time: float) -> void:
	if _resolved_objective_def == null or _battle == null:
		return
	if _objective_completed or _objective_failed:
		return
	var flow_state: Node = _battle.get_node_or_null("BattleModeHost/BattleFlowState")
	if flow_state == null:
		flow_state = _battle.get("get_flow_state").call() if _battle.has_method("get_flow_state") else null
	if flow_state == null:
		return
	if flow_state.has_method("is_terminal") and flow_state.call("is_terminal"):
		return
	var obj_type: StringName = StringName(_resolved_objective_def.get("objective_type"))
	var params: Dictionary = _resolved_objective_def.get("params")
	var reason: StringName = StringName()
	var is_win := false
	match obj_type:
		&"all_waves_cleared":
			is_win = _check_all_waves_cleared(flow_state)
			reason = &"all_waves_cleared"
		&"survive_duration":
			is_win = _check_survive_duration(game_time, params)
			reason = &"survive_duration"
		&"score_threshold":
			is_win = _check_score_threshold(params)
			reason = &"score_threshold"
		&"combo_threshold":
			is_win = _check_combo_threshold(params)
			reason = &"combo_threshold"
		&"collect_resource":
			is_win = _check_collect_resource(params)
			reason = &"collect_resource"
		&"protect_template":
			reason = &"protect_template"
		&"clear_special_targets":
			reason = &"clear_special_targets"
		&"defeat_named_spawn":
			reason = &"defeat_named_spawn"
	if is_win:
		_objective_completed = true
		if flow_state.has_method("mark_victory"):
			flow_state.call("mark_victory", reason)
	_check_failure_conditions(game_time, flow_state)


func _check_all_waves_cleared(flow_state: Node) -> bool:
	if flow_state.has_method("get"):
		var completed: Variant = flow_state.get("completed_wave_ids")
		var active: Variant = flow_state.get("active_wave_id")
		if completed == null:
			return false
		if active != null and StringName(active) != StringName():
			return false
		return completed.size() > 0
	return false


func _check_survive_duration(game_time: float, params: Dictionary) -> bool:
	var target: float = float(params.get("duration", 60.0))
	return game_time >= target


func _check_score_threshold(params: Dictionary) -> bool:
	var target: int = int(params.get("threshold", 0))
	var current: int = int(_objective_progress.get("score", 0))
	return current >= target


func _check_combo_threshold(params: Dictionary) -> bool:
	var target: int = int(params.get("threshold", 0))
	var current: int = int(_objective_progress.get("combo", 0))
	return current >= target


func _check_collect_resource(params: Dictionary) -> bool:
	var target: int = int(params.get("amount", 0))
	var current: int = int(_objective_progress.get("collected", 0))
	return current >= target


func _check_failure_conditions(game_time: float, flow_state: Node) -> void:
	if _resolved_objective_def == null:
		return
	var failure_conditions: PackedStringArray = _resolved_objective_def.get("failure_conditions")
	for condition in failure_conditions:
		var failed := false
		var reason := StringName(condition)
		match StringName(condition):
			&"time_expired":
				var limit: float = float(_resolved_objective_def.get("params").get("time_limit", 0.0))
				if limit > 0.0 and game_time >= limit:
					failed = true
					reason = &"time_expired"
		if failed and not _objective_failed:
			_objective_failed = true
			if flow_state.has_method("mark_defeat"):
				flow_state.call("mark_defeat", reason)
			return
