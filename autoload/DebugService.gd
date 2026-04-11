extends Node

const MAX_EVENTS := 128
const MAX_EFFECTS := 128
const MAX_TRIGGERS := 128

var enable_event_logging := true
var enable_effect_logging := true
var enable_trigger_logging := true
var event_log: Array[Dictionary] = []
var effect_log: Array[Dictionary] = []
var trigger_log: Array[Dictionary] = []


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


func _debug_entity_name(entity: Node) -> String:
	if entity == null:
		return "<null>"
	if entity.has_method("get_debug_name"):
		return str(entity.call("get_debug_name"))
	return entity.name
