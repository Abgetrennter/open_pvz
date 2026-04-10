extends RefCounted
class_name RuleContext

const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")

var event_name: StringName = StringName()
var source_node: Node = null
var target_node: Node = null
var position := Vector2.ZERO
var core: Dictionary = {}
var runtime: Dictionary = {}
var state: Dictionary = {}


func duplicate_deep() -> Variant:
	var copy: Variant = get_script().new()
	copy.event_name = event_name
	copy.source_node = source_node
	copy.target_node = target_node
	copy.position = position
	copy.core = core.duplicate(true)
	copy.runtime = runtime.duplicate(true)
	copy.state = state.duplicate(true)
	return copy


static func from_event_data(event_name_value: StringName, event_data, owner_entity: Node = null) -> Variant:
	var context: Variant = RuleContextRef.new()
	context.event_name = event_name_value
	context.source_node = event_data.core.get("source_node", owner_entity)
	context.target_node = event_data.core.get("target_node", null)
	context.core = event_data.core.duplicate(true)
	context.runtime = event_data.runtime.duplicate(true)
	if owner_entity != null and owner_entity.has_method("get_entity_state"):
		context.state = owner_entity.call("get_entity_state")
	if owner_entity != null and owner_entity is Node2D:
		context.position = owner_entity.global_position
	elif context.target_node != null and context.target_node is Node2D:
		context.position = context.target_node.global_position
	return context
