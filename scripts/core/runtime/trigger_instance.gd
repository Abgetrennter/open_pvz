extends RefCounted
class_name TriggerInstance

const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")
const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")

var def_id: StringName = StringName()
var event_name: StringName = StringName()
var condition_values: Dictionary = {}
var effect_roots: Array = []
var last_triggered_time := -1000000.0
var bind_time := 0.0
var owner_entity: Node = null
var pending_context_overrides: Dictionary = {}


func bind_owner(entity: Node) -> void:
	owner_entity = entity


func set_pending_context_overrides(overrides: Dictionary) -> void:
	pending_context_overrides = overrides.duplicate(true)


func clear_pending_context_overrides() -> void:
	pending_context_overrides.clear()


func should_trigger(incoming_event_name: StringName, event_data) -> bool:
	if incoming_event_name != event_name:
		return false
	if owner_entity == null:
		return false

	var entity_state: Dictionary = {}
	if owner_entity.has_method("get_entity_state"):
		entity_state = owner_entity.call("get_entity_state")

	clear_pending_context_overrides()
	return TriggerRegistry.evaluate_trigger(def_id, event_data, condition_values, entity_state, self)


func execute(incoming_event_name: StringName, event_data) -> Array:
	var results: Array = []
	var fired := should_trigger(incoming_event_name, event_data)
	DebugService.record_trigger_execution(def_id, owner_entity, incoming_event_name, int(event_data.runtime.get("depth", 1)), fired)
	if not fired:
		return results

	last_triggered_time = GameState.current_time
	var context: Variant = RuleContextRef.from_event_data(incoming_event_name, event_data, owner_entity)
	_apply_pending_context_overrides(context)

	for effect_root in effect_roots:
		results.append(EffectExecutorRef.execute_node(effect_root, context))

	clear_pending_context_overrides()
	return results


func _apply_pending_context_overrides(context) -> void:
	if context == null or pending_context_overrides.is_empty():
		return
	if pending_context_overrides.has("target_node"):
		var target_node: Node = pending_context_overrides.get("target_node", null)
		context.target_node = target_node
		context.core["target_node"] = target_node
		context.core["target_id"] = _extract_entity_id(target_node)
		context.core["target_template_id"] = _extract_template_id(target_node)
		context.core["target_archetype_id"] = _extract_archetype_id(target_node)
		context.core["target_kind"] = _extract_entity_kind(target_node)
		context.core["target_lane"] = _extract_lane_id(target_node)
		context.core["target_team"] = _extract_team(target_node)
	for key: Variant in pending_context_overrides.keys():
		if key == "target_node":
			continue
		context.runtime[key] = pending_context_overrides[key]


func _extract_entity_id(node: Node) -> int:
	if node == null or not node.has_method("get_entity_id"):
		return -1
	return int(node.call("get_entity_id"))


func _extract_entity_kind(node: Node) -> StringName:
	if node == null:
		return StringName()
	var kind_value: Variant = node.get("entity_kind")
	if kind_value is StringName:
		return kind_value
	if kind_value is String:
		return StringName(kind_value)
	return StringName()


func _extract_template_id(node: Node) -> StringName:
	if node == null:
		return StringName()
	var template_value: Variant = node.get("template_id")
	if template_value is StringName:
		return template_value
	if template_value is String:
		return StringName(template_value)
	return StringName()


func _extract_archetype_id(node: Node) -> StringName:
	if node == null:
		return StringName()
	var archetype_value: Variant = node.get("archetype_id")
	if archetype_value is StringName:
		return archetype_value
	if archetype_value is String:
		return StringName(archetype_value)
	return StringName()


func _extract_lane_id(node: Node) -> int:
	if node == null:
		return -1
	var lane_value: Variant = node.get("lane_id")
	if lane_value is int:
		return lane_value
	return -1


func _extract_team(node: Node) -> StringName:
	if node == null:
		return StringName()
	var team_value: Variant = node.get("team")
	if team_value is StringName:
		return team_value
	if team_value is String:
		return StringName(team_value)
	return StringName()
