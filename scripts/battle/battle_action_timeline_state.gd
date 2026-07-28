extends Node
class_name BattleActionTimelineState

const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")
const EffectNodeRef = preload("res://scripts/core/runtime/effect_node.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")

var battle: Node = null

var _actions: Array[Dictionary] = []
var _next_action_serial := 0


func setup(battle_node: Node, _scenario: Resource) -> void:
	battle = battle_node
	_actions.clear()
	_next_action_serial = 0
	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))


func get_debug_name() -> String:
	return "action_timeline_state"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"archetype_id": StringName(),
		"entity_kind": &"action_timeline_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"active_action_count": _actions.size(),
			"next_action_serial": _next_action_serial,
		},
	}


func start_action(context, params: Dictionary) -> bool:
	if context == null:
		_record_issue("start_action_timeline requires a context.")
		return false
	var action_id := StringName(params.get("action_id", StringName()))
	if action_id == StringName():
		_record_issue("start_action_timeline requires action_id.")
		return false

	var source_node := _resolve_source_node(context)
	var target_node := _resolve_target_node(context, params, source_node)
	if target_node == null and StringName(params.get("target_mode", &"context_target")) != &"none":
		_record_issue("start_action_timeline could not resolve target for %s." % String(action_id))
		return false

	_next_action_serial += 1
	var impact_phase := StringName(params.get("impact_phase", &"impact"))
	var phases := _normalize_phases(params.get("phase_offsets", {}), impact_phase)
	var action := {
		"instance_id": StringName("%s_%d_%d" % [String(action_id), _entity_id(source_node), _next_action_serial]),
		"action_id": action_id,
		"source_node": source_node,
		"target_node": target_node,
		"impact_position": _resolve_impact_position(context, target_node, source_node),
		"start_tick": GameState.current_tick,
		"start_time": GameState.current_time,
		"phases": phases,
		"emitted_phases": {},
		"impact_phase": impact_phase,
		"impact_effect_id": StringName(params.get("impact_effect_id", StringName())),
		"impact_effect_params": Dictionary(params.get("impact_effect_params", {})).duplicate(true),
		"impact_executed": false,
		"finished": false,
		"chain_id": str(context.runtime.get("chain_id", context.chain_id)),
		"depth": int(context.runtime.get("depth", context.depth)),
	}
	_process_action(action)
	if not bool(action.get("finished", false)):
		_actions.append(action)
	return true


func _on_game_tick(_event_data: Variant) -> void:
	var remaining: Array[Dictionary] = []
	for action: Dictionary in _actions:
		_process_action(action)
		if not bool(action.get("finished", false)):
			remaining.append(action)
	_actions = remaining


func _process_action(action: Dictionary) -> void:
	var elapsed := maxf(GameState.current_time - float(action.get("start_time", GameState.current_time)), 0.0)
	var phases: Array = Array(action.get("phases", []))
	var emitted: Dictionary = Dictionary(action.get("emitted_phases", {}))
	var impact_phase := StringName(action.get("impact_phase", &"impact"))
	for phase_info in phases:
		if not (phase_info is Dictionary):
			continue
		var phase := StringName(phase_info.get("phase", StringName()))
		if phase == StringName() or emitted.has(phase):
			continue
		if elapsed + 0.000001 < float(phase_info.get("offset", 0.0)):
			continue
		emitted[phase] = true
		action["emitted_phases"] = emitted
		_emit_phase(action, phase, elapsed)
		if phase == impact_phase and not bool(action.get("impact_executed", false)):
			action["impact_executed"] = true
			_execute_impact(action)

	action["finished"] = _all_phases_emitted(action)


func _emit_phase(action: Dictionary, phase: StringName, elapsed: float) -> void:
	var source_node := _node_from_action(action, "source_node")
	var target_node := _node_from_action(action, "target_node")

	var event_tags := PackedStringArray(["combat_action", String(action.get("action_id", StringName())), String(phase)])
	var event_data: Variant = EventDataRef.create(source_node, target_node, null, event_tags, {
		"chain_id": str(action.get("chain_id", "")),
		"depth": int(action.get("depth", 1)) + 1,
	})
	event_data.core["action_id"] = StringName(action.get("action_id", StringName()))
	event_data.core["action_instance_id"] = StringName(action.get("instance_id", StringName()))
	event_data.core["phase"] = phase
	event_data.core["impact_phase"] = StringName(action.get("impact_phase", &"impact"))
	event_data.core["impact_position"] = Vector2(action.get("impact_position", Vector2.ZERO))
	event_data.core["elapsed"] = elapsed
	event_data.core["start_tick"] = int(action.get("start_tick", 0))
	event_data.core["phase_tick"] = GameState.current_tick
	EventBus.push_event(&"combat_action.phase", event_data)


func _execute_impact(action: Dictionary) -> void:
	var effect_id := StringName(action.get("impact_effect_id", StringName()))
	if effect_id == StringName():
		return
	var source_node := _node_from_action(action, "source_node")
	var target_node := _node_from_action(action, "target_node")
	if source_node == null:
		return

	var context: Variant = RuleContextRef.new()
	context.event_name = &"combat_action.phase"
	context.owner_entity = source_node
	context.source_node = source_node
	context.target_node = target_node
	context.position = Vector2(action.get("impact_position", Vector2.ZERO))
	context.chain_id = str(action.get("chain_id", ""))
	context.depth = int(action.get("depth", 1)) + 1
	context.runtime["chain_id"] = context.chain_id
	context.runtime["depth"] = context.depth
	context.core["source_node"] = source_node
	context.core["target_node"] = target_node
	context.core["action_id"] = StringName(action.get("action_id", StringName()))
	context.core["action_instance_id"] = StringName(action.get("instance_id", StringName()))
	context.core["phase"] = StringName(action.get("impact_phase", &"impact"))
	context.core["impact_position"] = context.position
	var effect_node: Variant = EffectNodeRef.new(effect_id, Dictionary(action.get("impact_effect_params", {})).duplicate(true))
	EffectExecutorRef.execute_node(effect_node, context)


func _all_phases_emitted(action: Dictionary) -> bool:
	var emitted: Dictionary = Dictionary(action.get("emitted_phases", {}))
	for phase_info in Array(action.get("phases", [])):
		if not (phase_info is Dictionary):
			continue
		if not emitted.has(StringName(phase_info.get("phase", StringName()))):
			return false
	return true


func _resolve_source_node(context) -> Node:
	var source_node := _valid_node(context.source_node)
	if source_node != null:
		return source_node
	var owner_node := _valid_node(context.owner_entity)
	if owner_node != null:
		return owner_node
	var source_value: Variant = context.core.get("source_node", null)
	return _valid_node(source_value)


func _resolve_target_node(context, params: Dictionary, source_node: Node) -> Node:
	var target_mode := StringName(params.get("target_mode", &"context_target"))
	match target_mode:
		&"none":
			return null
		&"source":
			return source_node
		&"owner":
			return _valid_node(context.owner_entity)
		&"context_target":
			return _valid_node(context.target_node)
		&"event_source":
			var event_source: Variant = context.core.get("source_node", context.source_node)
			return _valid_node(event_source)
		&"event_target":
			var event_target: Variant = context.core.get("target_node", context.target_node)
			return _valid_node(event_target)
		&"enemies_in_radius":
			var targets := _resolve_enemies_in_radius(context, params, source_node)
			return targets[0] if not targets.is_empty() else null
		_:
			return _valid_node(context.target_node)


func _resolve_enemies_in_radius(context, params: Dictionary, source_node: Node) -> Array:
	if battle == null or not is_instance_valid(battle) or not battle.has_method("spatial_query"):
		return []
	var center := _node_ground_position(source_node)
	if center == Vector2.ZERO:
		center = _node_ground_position(context.owner_entity)
	if center == Vector2.ZERO:
		center = _node_ground_position(context.target_node)
	var source_team := _node_team(source_node)
	if source_team == StringName():
		source_team = _node_team(context.owner_entity)
	var radius := _resolve_slots_distance(params, "radius_slots", float(params.get("radius", 96.0)))
	var target_tags := _packed_string_array(params.get("target_tags", PackedStringArray()))
	return battle.call("spatial_query", {
		"team_exclude": source_team,
		"center": center,
		"radius": radius,
		"sort_by_distance": true,
		"max_results": 1,
		"filter": func(candidate):
			if candidate == source_node:
				return false
			if candidate.has_method("is_targetable") and not bool(candidate.call("is_targetable")):
				return false
			if candidate.has_method("is_damageable") and not bool(candidate.call("is_damageable")):
				return false
			if not target_tags.is_empty() and not _node_has_any_tag_or_status(candidate, target_tags):
				return false
			if not _matches_target_exposure(candidate, params):
				return false
			return candidate is Node2D,
	})


func _resolve_impact_position(context, target_node: Node, source_node: Node) -> Vector2:
	var target_position := _node_ground_position(target_node)
	if target_position != Vector2.ZERO:
		return target_position
	var source_position := _node_ground_position(source_node)
	if source_position != Vector2.ZERO:
		return source_position
	return Vector2(context.position)


func _normalize_phases(raw_phases: Variant, impact_phase: StringName) -> Array[Dictionary]:
	var phases: Array[Dictionary] = []
	if raw_phases is Dictionary:
		for raw_phase: Variant in Dictionary(raw_phases).keys():
			var phase := StringName(raw_phase)
			if phase == StringName():
				continue
			phases.append({
				"phase": phase,
				"offset": maxf(float(Dictionary(raw_phases)[raw_phase]), 0.0),
			})
	elif raw_phases is Array:
		for raw_entry in raw_phases:
			if not (raw_entry is Dictionary):
				continue
			var phase := StringName(raw_entry.get("phase", StringName()))
			if phase == StringName():
				continue
			phases.append({
				"phase": phase,
				"offset": maxf(float(raw_entry.get("offset", 0.0)), 0.0),
			})
	if phases.is_empty():
		phases.append({"phase": impact_phase, "offset": 0.0})
	if not _has_phase(phases, impact_phase):
		var last_offset := 0.0
		for phase_info: Dictionary in phases:
			last_offset = maxf(last_offset, float(phase_info.get("offset", 0.0)))
		phases.append({"phase": impact_phase, "offset": last_offset})
	phases.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_offset := float(a.get("offset", 0.0))
		var b_offset := float(b.get("offset", 0.0))
		if not is_equal_approx(a_offset, b_offset):
			return a_offset < b_offset
		return String(a.get("phase", StringName())) < String(b.get("phase", StringName()))
	)
	return phases


func _has_phase(phases: Array[Dictionary], phase: StringName) -> bool:
	for phase_info: Dictionary in phases:
		if StringName(phase_info.get("phase", StringName())) == phase:
			return true
	return false


func _node_from_action(action: Dictionary, key: String) -> Node:
	var value: Variant = action.get(key, null)
	return _valid_node(value)


func _valid_node(value: Variant) -> Node:
	if value == null or not is_instance_valid(value):
		return null
	return value if value is Node else null


func _resolve_slots_distance(params: Dictionary, slots_key: String, default_world: float) -> float:
	if battle != null and battle.has_method("get_battlefield_metrics"):
		var metrics: Variant = battle.call("get_battlefield_metrics")
		if metrics != null and metrics.has_method("resolve_slots_distance"):
			return float(metrics.call("resolve_slots_distance", params, slots_key, default_world))
	if params.has(slots_key):
		return float(params.get(slots_key)) * 96.0
	return default_world


func _matches_target_exposure(target: Variant, params: Dictionary) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var allowed_states := _packed_string_array(params.get("target_exposure_states", PackedStringArray(["ground"])))
	if allowed_states.is_empty():
		return true
	var exposure_state := &"ground"
	if target is Node and target.has_method("get_exposure_state"):
		exposure_state = StringName(target.call("get_exposure_state"))
	return allowed_states.has(String(exposure_state))


func _node_has_any_tag_or_status(node: Node, expected_tags: PackedStringArray) -> bool:
	var raw_tags: Variant = node.get("tags")
	var node_tags := PackedStringArray()
	if raw_tags is PackedStringArray:
		node_tags = PackedStringArray(raw_tags)
	elif raw_tags is Array:
		node_tags = PackedStringArray(raw_tags)
	for expected_tag in expected_tags:
		if node_tags.has(StringName(expected_tag)):
			return true
		if node.has_method("has_status") and bool(node.call("has_status", StringName(expected_tag))):
			return true
	return false


func _packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return PackedStringArray(value)
	if value is Array:
		return PackedStringArray(value)
	if value is String or value is StringName:
		return PackedStringArray([String(value)])
	return PackedStringArray()


func _node_ground_position(node: Variant) -> Vector2:
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return (node as Node2D).global_position


func _node_team(node: Variant) -> StringName:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return StringName()
	var value: Variant = node.get("team")
	return StringName(value) if value is String or value is StringName else StringName()


func _entity_id(node: Variant) -> int:
	if node != null and is_instance_valid(node) and node is Node and node.has_method("get_entity_id"):
		return int(node.call("get_entity_id"))
	return -1


func _record_issue(message: String) -> void:
	if DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(&"action_timeline", message, &"error")
