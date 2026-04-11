extends Node

const MAX_EVENTS := 128
const MAX_EFFECTS := 128
const MAX_TRIGGERS := 128
const MAX_RUNTIME_SNAPSHOTS := 128
const MAX_PROTOCOL_ISSUES := 64

var enable_event_logging := true
var enable_effect_logging := true
var enable_trigger_logging := true
var enable_runtime_snapshot_logging := true
var enable_protocol_logging := true
var event_log: Array[Dictionary] = []
var effect_log: Array[Dictionary] = []
var trigger_log: Array[Dictionary] = []
var runtime_snapshot_log: Array[Dictionary] = []
var protocol_log: Array[Dictionary] = []


func _ready() -> void:
	EventBus.event_pushed.connect(_on_event_pushed)


func _on_event_pushed(event_name: StringName, event_data: Variant) -> void:
	if not enable_event_logging:
		return

	event_log.push_front({
		"event_name": event_name,
		"event_id": str(event_data.runtime.get("event_id", "")),
		"chain_id": str(event_data.runtime.get("chain_id", "")),
		"depth": int(event_data.runtime.get("depth", 0)),
		"source": _debug_entity_name(event_data.core.get("source_node", null)),
		"target": _debug_entity_name(event_data.core.get("target_node", null)),
		"value": event_data.core.get("value", null),
		"tags": PackedStringArray(event_data.core.get("tags", PackedStringArray())),
	})
	if event_log.size() > MAX_EVENTS:
		event_log.pop_back()
	_print_event_trace(event_name, event_data)


func clear_logs() -> void:
	event_log.clear()
	effect_log.clear()
	trigger_log.clear()
	runtime_snapshot_log.clear()
	protocol_log.clear()


func build_export_payload() -> Dictionary:
	return {
		"config": {
			"enable_event_logging": enable_event_logging,
			"enable_effect_logging": enable_effect_logging,
			"enable_trigger_logging": enable_trigger_logging,
			"enable_runtime_snapshot_logging": enable_runtime_snapshot_logging,
			"enable_protocol_logging": enable_protocol_logging,
		},
		"event_log": _json_safe(event_log),
		"effect_log": _json_safe(effect_log),
		"trigger_log": _json_safe(trigger_log),
		"runtime_snapshot_log": _json_safe(runtime_snapshot_log),
		"protocol_log": _json_safe(protocol_log),
	}


func record_protocol_issue(scope: StringName, message: String, severity: StringName = &"warning") -> void:
	if not enable_protocol_logging:
		return
	protocol_log.push_front({
		"scope": scope,
		"message": message,
		"severity": severity,
	})
	if protocol_log.size() > MAX_PROTOCOL_ISSUES:
		protocol_log.pop_back()
	print("[Protocol][%s][%s] %s" % [String(severity).to_upper(), String(scope), message])


func record_trigger_execution(trigger_id: StringName, owner_entity: Node, event_name: StringName, depth: int, fired: bool) -> void:
	if not enable_trigger_logging:
		return

	trigger_log.push_front({
		"trigger_id": trigger_id,
		"owner": _debug_entity_name(owner_entity),
		"event_name": event_name,
		"depth": depth,
		"fired": fired,
	})
	if trigger_log.size() > MAX_TRIGGERS:
		trigger_log.pop_back()


func record_effect_execution(effect_id: StringName, context: Variant, depth: int, result = null) -> void:
	if not enable_effect_logging:
		return

	effect_log.push_front({
		"effect_id": effect_id,
		"event_name": context.event_name,
		"chain_id": context.chain_id,
		"depth": depth,
		"source": _debug_entity_name(context.source_node),
		"target": _debug_entity_name(context.target_node),
		"success": true if result == null else bool(result.success),
		"notes": PackedStringArray([] if result == null else result.notes),
	})
	if effect_log.size() > MAX_EFFECTS:
		effect_log.pop_back()


func record_runtime_snapshot(frame_index: int, battle_time: float, scenario_name: String, entities: Array) -> void:
	if not enable_runtime_snapshot_logging:
		return

	var lines: PackedStringArray = PackedStringArray()
	for entity in entities:
		if entity == null:
			continue
		lines.append(_runtime_entity_line(entity))

	var snapshot := {
		"frame": frame_index,
		"time": battle_time,
		"scenario": scenario_name,
		"lines": lines,
	}
	runtime_snapshot_log.push_front(snapshot)
	if runtime_snapshot_log.size() > MAX_RUNTIME_SNAPSHOTS:
		runtime_snapshot_log.pop_back()

	print("[RuntimeSnapshot] frame=%d time=%.2f scenario=%s entities=%d" % [frame_index, battle_time, scenario_name, lines.size()])
	for line in lines:
		print("[RuntimeSnapshot] %s" % line)


func snapshot_entity(entity: Node) -> Dictionary:
	if entity == null:
		return {}

	var snapshot := {
		"name": entity.name,
		"script": entity.get_script(),
	}

	if entity.has_method("get_debug_snapshot"):
		snapshot["state"] = entity.call("get_debug_snapshot")

	return snapshot


func _runtime_entity_line(entity: Node) -> String:
	var entity_name := _debug_entity_name(entity)
	if not entity.has_method("get_debug_snapshot"):
		return entity_name

	var snapshot: Dictionary = entity.call("get_debug_snapshot")
	var values: Dictionary = snapshot.get("values", {})
	var position: Vector2 = snapshot.get("position", Vector2.ZERO)
	return "%s lane=%s status=%s pos=(%.1f, %.1f) health=%d/%d values=%s" % [
		entity_name,
		str(snapshot.get("lane_id", -1)),
		String(snapshot.get("status", "")),
		position.x,
		position.y,
		int(snapshot.get("health", 0)),
		int(snapshot.get("max_health", 0)),
		str(values),
	]


func _debug_entity_name(entity: Node) -> String:
	if entity == null:
		return "<null>"
	if entity.has_method("get_debug_name"):
		return str(entity.call("get_debug_name"))
	return entity.name


func _print_event_trace(event_name: StringName, event_data: Variant) -> void:
	if event_name not in [&"projectile.spawned", &"projectile.hit", &"projectile.expired", &"entity.damaged", &"entity.died"]:
		return
	print("[EventTrace] %s src=%s tgt=%s value=%s tags=%s core=%s" % [
		String(event_name),
		_debug_entity_name(event_data.core.get("source_node", null)),
		_debug_entity_name(event_data.core.get("target_node", null)),
		str(event_data.core.get("value", null)),
		str(event_data.core.get("tags", PackedStringArray())),
		str(event_data.core),
	])


func _json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var converted: Dictionary = {}
		for key: Variant in value.keys():
			converted[str(key)] = _json_safe(value[key])
		return converted
	if value is Array:
		var converted_array: Array = []
		for item in value:
			converted_array.append(_json_safe(item))
		return converted_array
	if value is PackedStringArray:
		return Array(value)
	if value is StringName:
		return String(value)
	if value is Vector2:
		return {
			"x": value.x,
			"y": value.y,
		}
	return value
