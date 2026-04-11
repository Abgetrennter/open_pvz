extends RefCounted
class_name TriggerInstance

const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")
const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")

var def_id: StringName = StringName()
var event_name: StringName = StringName()
var condition_values: Dictionary = {}
var effect_roots: Array = []
var last_triggered_time := -1000000.0
var owner_entity: Node = null


func bind_owner(entity: Node) -> void:
	owner_entity = entity


func should_trigger(incoming_event_name: StringName, event_data) -> bool:
	if incoming_event_name != event_name:
		return false
	if owner_entity == null:
		return false

	var entity_state: Dictionary = {}
	if owner_entity.has_method("get_entity_state"):
		entity_state = owner_entity.call("get_entity_state")

	return TriggerRegistry.evaluate_trigger(def_id, event_data, condition_values, entity_state, self)


func execute(incoming_event_name: StringName, event_data) -> Array:
	var results: Array = []
	var fired := should_trigger(incoming_event_name, event_data)
	DebugService.record_trigger_execution(def_id, owner_entity, incoming_event_name, int(event_data.runtime.get("depth", 1)), fired)
	if not fired:
		return results

	last_triggered_time = GameState.current_time
	var context: Variant = RuleContextRef.from_event_data(incoming_event_name, event_data, owner_entity)

	for effect_root in effect_roots:
		results.append(EffectExecutorRef.execute_node(effect_root, context))

	return results
