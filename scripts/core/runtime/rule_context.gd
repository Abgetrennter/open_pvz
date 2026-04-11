extends RefCounted
class_name RuleContext

const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")

var event_name: StringName = StringName()
var owner_entity: Node = null
var source_node: Node = null
var target_node: Node = null
var position := Vector2.ZERO
var chain_id := ""
var depth := 1
var core: Dictionary = {}
var runtime: Dictionary = {}
var state: Dictionary = {}
var entity_state = null


func duplicate_deep() -> Variant:
	var copy: Variant = get_script().new()
	copy.event_name = event_name
	copy.owner_entity = owner_entity
	copy.source_node = source_node
	copy.target_node = target_node
	copy.position = position
	copy.chain_id = chain_id
	copy.depth = depth
	copy.core = core.duplicate(true)
	copy.runtime = runtime.duplicate(true)
	copy.state = state.duplicate(true)
	copy.entity_state = entity_state
	return copy


static func from_event_data(event_name_value: StringName, event_data, owner_entity: Node = null) -> Variant:
	var context: Variant = RuleContextRef.new()
	var source_node: Node = event_data.core.get("source_node", null)
	var target_node: Node = event_data.core.get("target_node", null)
	context.event_name = event_name_value
	context.owner_entity = owner_entity
	context.source_node = owner_entity if source_node == null else source_node
	context.target_node = target_node
	context.core = event_data.core.duplicate(true)
	context.runtime = event_data.runtime.duplicate(true)
	context.chain_id = str(event_data.runtime.get("chain_id", ""))
	context.depth = int(event_data.runtime.get("depth", 1))
	if owner_entity != null and owner_entity.has_method("get_entity_state_ref"):
		context.entity_state = owner_entity.call("get_entity_state_ref")
	if owner_entity != null and owner_entity.has_method("get_entity_state"):
		context.state = owner_entity.call("get_entity_state")
	if owner_entity != null and owner_entity is Node2D:
		context.position = owner_entity.global_position
	elif context.target_node != null and context.target_node is Node2D:
		context.position = context.target_node.global_position
	elif context.source_node != null and context.source_node is Node2D:
		context.position = context.source_node.global_position
	return context
