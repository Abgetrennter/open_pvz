extends Node

const MAX_EVENTS := 128
const MAX_EFFECTS := 128

var enable_event_logging := true
var enable_effect_logging := true
var event_log: Array[Dictionary] = []
var effect_log: Array[Dictionary] = []


func _ready() -> void:
	EventBus.event_pushed.connect(_on_event_pushed)


func _on_event_pushed(event_name: StringName, event_data: Variant) -> void:
	if not enable_event_logging:
		return

	event_log.push_front({
		"event_name": event_name,
		"depth": int(event_data.runtime.get("depth", 0)),
		"source": event_data.core.get("source_id", ""),
		"target": event_data.core.get("target_id", ""),
	})
	if event_log.size() > MAX_EVENTS:
		event_log.pop_back()


func record_effect_execution(effect_id: StringName, context: Variant, depth: int) -> void:
	if not enable_effect_logging:
		return

	effect_log.push_front({
		"effect_id": effect_id,
		"event_name": context.event_name,
		"depth": depth,
		"source": _debug_entity_name(context.source_node),
		"target": _debug_entity_name(context.target_node),
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
