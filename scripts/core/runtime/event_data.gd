extends RefCounted
class_name EventData

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var core: Dictionary = {}
var runtime: Dictionary = {}
var ext: Dictionary = {}


func duplicate_deep() -> Variant:
	var copy: Variant = get_script().new()
	copy.core = core.duplicate(true)
	copy.runtime = runtime.duplicate(true)
	copy.ext = ext.duplicate(true)
	return copy


static func create(source_node: Node = null, target_node: Node = null, value: Variant = null, tags: PackedStringArray = PackedStringArray()) -> Variant:
	var event_data: Variant = EventDataRef.new()
	event_data.core = {
		"source_node": source_node,
		"target_node": target_node,
		"source_id": _extract_entity_id(source_node),
		"target_id": _extract_entity_id(target_node),
		"value": value,
		"tags": tags,
	}
	event_data.runtime = {
		"event_id": str(Time.get_ticks_usec()),
		"depth": 1,
		"timestamp": GameState.current_time,
	}
	return event_data


static func _extract_entity_id(node: Node) -> int:
	if node == null:
		return -1
	if node.has_method("get_entity_id"):
		return int(node.call("get_entity_id"))
	return -1
