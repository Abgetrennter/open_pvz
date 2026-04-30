extends Node
class_name BattleModeHost

const BattleModeModuleRegistryRef = preload("res://scripts/battle/mode/battle_mode_module_registry.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var _battle: Node = null
var _mode_def: Resource = null
var _scenario: Resource = null
var _module_registry: RefCounted = null

var _resolved_mode_id: StringName = StringName()
var _resolved_input_profile: Resource = null
var _resolved_objective_def: Resource = null
var _resolved_rule_modules: Array[Resource] = []
var _scheduled_input_requests: Array[Resource] = []

var _objective_progress: Dictionary = {}
var _objective_completed := false
var _objective_failed := false
var _runtime_state: Dictionary = {}
var _processed_input_request_indices: Dictionary = {}
var _latest_entity_id_by_archetype: Dictionary = {}


func setup(battle: Node, scenario: Resource, mode_def: Resource = null) -> void:
	_battle = battle
	_scenario = scenario
	_mode_def = mode_def
	_module_registry = BattleModeModuleRegistryRef.new()
	_resolved_mode_id = StringName()
	_resolved_input_profile = null
	_resolved_objective_def = null
	_resolved_rule_modules = []
	_scheduled_input_requests = []
	_objective_progress = {}
	_objective_completed = false
	_objective_failed = false
	_runtime_state = {}
	_processed_input_request_indices.clear()
	_latest_entity_id_by_archetype.clear()
	if _mode_def == null:
		return
	_resolve_mode()
	_emit_mode_event(
		&"battle.mode_initialized",
		{
			"mode_id": _resolved_mode_id,
			"rule_module_count": _resolved_rule_modules.size(),
			"has_input_profile": _resolved_input_profile != null,
			"has_objective_def": _resolved_objective_def != null,
			"input_profile_id": StringName(_resolved_input_profile.get("profile_id")) if _resolved_input_profile != null else StringName(),
			"objective_id": StringName(_resolved_objective_def.get("objective_id")) if _resolved_objective_def != null else StringName(),
		},
		PackedStringArray(["mode", "initialized"])
	)
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
	_scheduled_input_requests = []
	_objective_progress = {}
	_objective_completed = false
	_objective_failed = false
	_runtime_state = {}
	_processed_input_request_indices.clear()
	_latest_entity_id_by_archetype.clear()


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


func get_mode_runtime_snapshot() -> Dictionary:
	return {
		"mode_id": _resolved_mode_id,
		"objective_progress": _objective_progress.duplicate(true),
		"objective_completed": _objective_completed,
		"objective_failed": _objective_failed,
		"runtime_state": _runtime_state.duplicate(true),
		"scheduled_input_count": _scheduled_input_requests.size(),
	}


func on_battle_start() -> void:
	if _mode_def == null:
		return
	_emit_mode_event(
		&"battle.mode_started",
		{
			"mode_id": _resolved_mode_id,
			"rule_module_count": _resolved_rule_modules.size(),
		},
		PackedStringArray(["mode", "started"])
	)
	_dispatch_modules(&"on_battle_start", {})


func on_tick(game_time: float) -> void:
	if _mode_def == null:
		return
	_process_input_requests(game_time)
	_dispatch_modules(&"on_game_tick", {"game_time": game_time})
	_evaluate_objective(game_time)


func on_event(event_name: StringName, event_data: Variant) -> void:
	if _mode_def == null:
		return
	_track_runtime_event(event_name, event_data)
	_dispatch_modules(&"on_event", {"event_name": event_name, "event_data": event_data})


func increment_objective_progress(key: StringName, amount: int = 1) -> void:
	var current := int(_objective_progress.get(key, 0))
	_objective_progress[key] = current + amount


func set_objective_progress(key: StringName, value: int) -> void:
	_objective_progress[key] = value


func get_objective_progress(key: StringName) -> int:
	return int(_objective_progress.get(key, 0))


func set_runtime_value(key: StringName, value: Variant) -> void:
	_runtime_state[key] = value


func get_runtime_value(key: StringName, default_value: Variant = null) -> Variant:
	return _runtime_state.get(key, default_value)


func clear_runtime_value(key: StringName) -> void:
	_runtime_state.erase(key)


func get_debug_name() -> String:
	return "mode_host"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"archetype_id": StringName(),
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
			"objective_progress": _objective_progress.duplicate(true),
			"runtime_state": _runtime_state.duplicate(true),
			"scheduled_input_count": _scheduled_input_requests.size(),
		},
	}


func _resolve_mode() -> void:
	_resolved_mode_id = StringName(_mode_def.get("mode_id"))
	_resolved_input_profile = _resolve_input_profile()
	_resolved_objective_def = _resolve_objective_def()
	_resolved_rule_modules = _resolve_rule_modules()
	_scheduled_input_requests = _resolve_input_requests()


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
	var modules_by_id: Dictionary = {}
	if _mode_def != null:
		var mode_modules: Variant = _mode_def.get("rule_modules")
		if mode_modules != null:
			for m in mode_modules:
				if m == null or not m.get("enabled"):
					continue
				modules_by_id[StringName(m.get("module_id"))] = m
	if _scenario != null:
		var scenario_modules: Variant = _scenario.get("mode_rule_modules")
		if scenario_modules != null:
			for m in scenario_modules:
				if m == null or not m.get("enabled"):
					continue
				modules_by_id[StringName(m.get("module_id"))] = m
	var modules: Array[Resource] = []
	for module_id in modules_by_id.keys():
		modules.append(modules_by_id[module_id])
	modules.sort_custom(func(a, b): return int(a.get("priority")) < int(b.get("priority")))
	return modules


func _resolve_input_requests() -> Array[Resource]:
	if _scenario == null:
		return []
	var resolved: Array[Resource] = []
	var configured_requests: Variant = _scenario.get("mode_input_requests")
	if configured_requests is Array:
		for input_request in configured_requests:
			if input_request is Resource:
				resolved.append(input_request)
	return resolved


func _dispatch_modules(action: StringName, context: Dictionary) -> void:
	if _module_registry == null or _battle == null:
		return
	for module in _resolved_rule_modules:
		var module_id: StringName = StringName(module.get("module_id"))
		var handler: Callable = _module_registry.get_handler(module_id)
		if handler.is_valid():
			handler.call(action, _battle, module, context)


func _process_input_requests(game_time: float) -> void:
	for index in range(_scheduled_input_requests.size()):
		if _processed_input_request_indices.has(index):
			continue
		var input_request: Resource = _scheduled_input_requests[index]
		if input_request == null:
			_processed_input_request_indices[index] = true
			continue
		if game_time + 0.001 < float(input_request.get("at_time")):
			continue
		_processed_input_request_indices[index] = true
		_execute_input_request(input_request)


func _execute_input_request(input_request: Resource) -> void:
	var action_name := StringName(input_request.get("action_name"))
	match action_name:
		&"entity_click":
			if not _is_input_action_enabled(action_name):
				return
			var resolved_entity_id := _resolve_input_request_entity_id(input_request)
			if resolved_entity_id < 0:
				_report_input_request_issue("entity_click could not resolve a runtime entity.")
				return
			var metadata: Dictionary = _duplicate_request_metadata(input_request)
			metadata["entity_id"] = resolved_entity_id
			_emit_input_action(&"input.action.entity_clicked", metadata)
		&"cell_click":
			if not _is_input_action_enabled(action_name):
				return
			var payload := _duplicate_request_metadata(input_request)
			payload["lane_id"] = int(input_request.get("lane_id"))
			payload["slot_index"] = int(input_request.get("slot_index"))
			payload["card_id"] = StringName()
			_emit_input_action(&"input.action.cell_clicked", payload)
		&"slot_drag":
			if not _is_input_action_enabled(action_name):
				return
			var payload := _duplicate_request_metadata(input_request)
			payload["from_lane"] = int(input_request.get("from_lane"))
			payload["from_slot"] = int(input_request.get("from_slot"))
			payload["to_lane"] = int(input_request.get("to_lane"))
			payload["to_slot"] = int(input_request.get("to_slot"))
			_emit_input_action(&"input.action.slot_drag", payload)
		&"cancel":
			if not _is_input_action_enabled(action_name):
				return
			_emit_input_action(&"input.action.card_deselected", {
				"reason": &"mode_scripted_cancel",
			})


func _duplicate_request_metadata(input_request: Resource) -> Dictionary:
	var metadata: Dictionary = {}
	var raw_metadata: Variant = input_request.get("metadata")
	if raw_metadata is Dictionary:
		metadata = raw_metadata.duplicate(true)
	metadata["source"] = metadata.get("source", &"mode_scripted")
	return metadata


func _resolve_input_request_entity_id(input_request: Resource) -> int:
	var explicit_entity_id := int(input_request.get("entity_id"))
	if explicit_entity_id >= 0:
		return explicit_entity_id
	var entity_archetype_id := StringName(input_request.get("entity_archetype_id"))
	if entity_archetype_id != StringName():
		return int(_latest_entity_id_by_archetype.get(entity_archetype_id, -1))
	return -1


func _is_input_action_enabled(action_name: StringName) -> bool:
	if _resolved_input_profile == null:
		return true
	match action_name:
		&"entity_click":
			return bool(_resolved_input_profile.get("enable_entity_click"))
		&"cell_click":
			return bool(_resolved_input_profile.get("enable_slot_click"))
		&"slot_drag":
			return bool(_resolved_input_profile.get("enable_slot_drag"))
		&"cancel":
			return bool(_resolved_input_profile.get("enable_cancel"))
	return true


func _track_runtime_event(event_name: StringName, event_data: Variant) -> void:
	if event_data == null:
		return
	if event_name == &"entity.spawned":
		var entity_id := int(event_data.core.get("entity_id", -1))
		if entity_id < 0:
			return
		var archetype_id := StringName(event_data.core.get("archetype_id", StringName()))
		if archetype_id != StringName():
			_latest_entity_id_by_archetype[archetype_id] = entity_id
		_track_objective_target_seen(archetype_id)
	elif event_name == &"entity.died":
		_track_objective_target_seen(StringName(event_data.core.get("target_archetype_id", StringName())))


func _emit_input_action(event_name: StringName, metadata: Dictionary) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["input"]))
	for key: Variant in metadata.keys():
		event_data.core[key] = metadata[key]
	EventBus.push_event(event_name, event_data)


func _report_input_request_issue(message: String) -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	if _battle.has_method("report_protocol_issues"):
		_battle.call("report_protocol_issues", [message], &"battle_mode_input_request")


func _evaluate_objective(game_time: float) -> void:
	if _resolved_objective_def == null or _battle == null:
		return
	if _objective_completed or _objective_failed:
		return
	var flow_state: Node = _resolve_flow_state()
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
		&"protect_archetype":
			is_win = _check_protect_archetype(flow_state, params)
			reason = &"protect_archetype"
		&"clear_special_targets":
			is_win = _check_clear_special_targets(params)
			reason = &"clear_special_targets"
		&"defeat_named_spawn":
			is_win = _check_defeat_named_spawn(params)
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


func _check_protect_archetype(flow_state: Node, params: Dictionary) -> bool:
	var archetype_id := _resolve_protected_archetype_id(params, flow_state)
	if archetype_id == StringName():
		return false
	var protected_alive := not _is_archetype_missing(archetype_id)
	_objective_progress[&"protected_alive"] = 1 if protected_alive else 0
	if not protected_alive:
		if not _objective_failed and flow_state.has_method("mark_defeat"):
			_objective_failed = true
			flow_state.call("mark_defeat", &"protected_archetype_lost")
		return false
	return _check_all_waves_cleared(flow_state)


func _check_clear_special_targets(params: Dictionary) -> bool:
	var target_archetype_ids := PackedStringArray(params.get("target_archetype_ids", PackedStringArray()))
	var seen_key := _objective_seen_state_key(target_archetype_ids)
	var has_seen_target := bool(_runtime_state.get(seen_key, false))
	var remaining_count := _count_active_matching_entities(target_archetype_ids)
	_objective_progress[&"remaining_targets"] = remaining_count
	return has_seen_target and remaining_count == 0


func _check_defeat_named_spawn(params: Dictionary) -> bool:
	var target_archetype_ids := PackedStringArray()
	var archetype_id := StringName(params.get("archetype_id", StringName()))
	if archetype_id != StringName():
		target_archetype_ids.append(String(archetype_id))
	var seen_key := _objective_seen_state_key(target_archetype_ids)
	var has_seen_target := bool(_runtime_state.get(seen_key, false))
	var remaining_count := _count_active_matching_entities(target_archetype_ids)
	_objective_progress[&"remaining_named_spawns"] = remaining_count
	return has_seen_target and remaining_count == 0


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


func _resolve_flow_state() -> Node:
	if _battle == null:
		return null
	var flow_state := _battle.get_node_or_null("BattleFlowState")
	if flow_state != null:
		return flow_state
	if _battle.has_method("get_flow_state"):
		var resolved: Variant = _battle.call("get_flow_state")
		if resolved is Node:
			return resolved
	return null


func _resolve_protected_archetype_id(params: Dictionary, flow_state: Node) -> StringName:
	var archetype_id := StringName(params.get("archetype_id", StringName()))
	if archetype_id != StringName():
		return archetype_id
	if flow_state != null and flow_state.get("protected_archetype_id") != null:
		archetype_id = StringName(flow_state.get("protected_archetype_id"))
		if archetype_id != StringName():
			return archetype_id
	if _scenario != null:
		return StringName(_scenario.get("protected_archetype_id"))
	return StringName()


func _is_archetype_missing(archetype_id: StringName) -> bool:
	if archetype_id == StringName() or _battle == null:
		return false
	for entity in _battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if StringName(entity.get("archetype_id")) != archetype_id:
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		return false
	return true


func _count_active_matching_entities(target_archetype_ids: PackedStringArray) -> int:
	if _battle == null:
		return 0
	var count := 0
	for entity in _battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		if _matches_objective_target(entity, target_archetype_ids):
			count += 1
	return count


func _matches_objective_target(entity: Node, target_archetype_ids: PackedStringArray) -> bool:
	var archetype_id := StringName(entity.get("archetype_id"))
	if archetype_id != StringName() and target_archetype_ids.has(String(archetype_id)):
		return true
	return false


func _track_objective_target_seen(archetype_id: StringName) -> void:
	if _resolved_objective_def == null:
		return
	var objective_type := StringName(_resolved_objective_def.get("objective_type"))
	if objective_type not in [&"clear_special_targets", &"defeat_named_spawn"]:
		return
	var params: Dictionary = _resolved_objective_def.get("params")
	var target_archetype_ids := PackedStringArray(params.get("target_archetype_ids", PackedStringArray()))
	var target_archetype_id := StringName(params.get("archetype_id", StringName()))
	if target_archetype_id != StringName() and not target_archetype_ids.has(String(target_archetype_id)):
		target_archetype_ids.append(String(target_archetype_id))
	if archetype_id != StringName() and target_archetype_ids.has(String(archetype_id)):
		_runtime_state[_objective_seen_state_key(target_archetype_ids)] = true


func _objective_seen_state_key(target_archetype_ids: PackedStringArray) -> StringName:
	return StringName("objective_seen|%s" % ",".join(target_archetype_ids))


func _emit_mode_event(event_name: StringName, metadata: Dictionary, tags: PackedStringArray = PackedStringArray()) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, tags)
	for key: Variant in metadata.keys():
		event_data.core[key] = metadata[key]
	EventBus.push_event(event_name, event_data)
