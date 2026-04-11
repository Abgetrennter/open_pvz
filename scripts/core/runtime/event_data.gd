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


func ensure_runtime_defaults(event_name: StringName) -> void:
	runtime["event_name"] = event_name
	runtime["event_id"] = str(runtime.get("event_id", "%s-%d" % [str(Time.get_ticks_usec()), randi()]))
	runtime["chain_id"] = str(runtime.get("chain_id", runtime["event_id"]))
	runtime["depth"] = max(1, int(runtime.get("depth", 1)))
	runtime["timestamp"] = float(runtime.get("timestamp", GameState.current_time))


func get_depth() -> int:
	return int(runtime.get("depth", 1))


func get_chain_id() -> String:
	return str(runtime.get("chain_id", ""))


static func create(
	source_node: Node = null,
	target_node: Node = null,
	value: Variant = null,
	tags: PackedStringArray = PackedStringArray(),
	runtime_overrides: Dictionary = {}
) -> Variant:
	var event_data: Variant = EventDataRef.new()
	event_data.core = {
		"source_node": source_node,
		"target_node": target_node,
		"source_id": _extract_entity_id(source_node),
		"target_id": _extract_entity_id(target_node),
		"source_kind": _extract_entity_kind(source_node),
		"target_kind": _extract_entity_kind(target_node),
		"source_lane": _extract_lane_id(source_node),
		"target_lane": _extract_lane_id(target_node),
		"source_team": _extract_team(source_node),
		"target_team": _extract_team(target_node),
		"value": value,
		"tags": tags,
	}
	event_data.runtime = {
		"depth": 1,
		"timestamp": GameState.current_time,
	}
	for key: Variant in runtime_overrides.keys():
		event_data.runtime[key] = runtime_overrides[key]
	return event_data


static func _extract_entity_id(node: Node) -> int:
	if node == null:
		return -1
	if node.has_method("get_entity_id"):
		return int(node.call("get_entity_id"))
	return -1


static func _extract_entity_kind(node: Node) -> StringName:
	if node == null:
		return StringName()
	var kind_value: Variant = node.get("entity_kind")
	if kind_value is StringName:
		return kind_value
	if kind_value is String:
		return StringName(kind_value)
	return StringName()


static func _extract_lane_id(node: Node) -> int:
	if node == null:
		return -1
	var lane_value: Variant = node.get("lane_id")
	if lane_value is int:
		return lane_value
	return -1


static func _extract_team(node: Node) -> StringName:
	if node == null:
		return StringName()
	var team_value: Variant = node.get("team")
	if team_value is StringName:
		return team_value
	if team_value is String:
		return StringName(team_value)
	return StringName()
