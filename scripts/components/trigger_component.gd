extends Node
class_name TriggerComponent

const ProtocolValidatorRef = preload("res://scripts/core/runtime/protocol_validator.gd")

@export var auto_subscribe := true

var trigger_instances: Array = []
var _event_callables: Dictionary = {}


func _ready() -> void:
	if auto_subscribe and not trigger_instances.is_empty():
		subscribe_all()


func _exit_tree() -> void:
	clear_triggers()


func bind_triggers(instances: Array) -> void:
	clear_triggers()
	var normalized_instances: Array = []
	for instance in instances:
		var validation: Dictionary = ProtocolValidatorRef.normalize_trigger_instance(instance)
		if not bool(validation.get("valid", false)):
			for error in PackedStringArray(validation.get("errors", PackedStringArray())):
				push_warning(error)
				if DebugService.has_method("record_protocol_issue"):
					DebugService.record_protocol_issue(&"trigger_instance", error, &"error")
			continue
		instance.event_name = StringName(validation.get("event_name", instance.event_name))
		instance.condition_values = Dictionary(validation.get("condition_values", instance.condition_values))
		normalized_instances.append(instance)

	trigger_instances = normalized_instances
	for instance in trigger_instances:
		instance.bind_owner(get_parent())

	if is_inside_tree() and auto_subscribe:
		subscribe_all()


func clear_triggers() -> void:
	for event_name: Variant in _event_callables.keys():
		EventBus.unsubscribe(event_name, _event_callables[event_name])
	_event_callables.clear()
	trigger_instances.clear()


func subscribe_all() -> void:
	for instance in trigger_instances:
		if _event_callables.has(instance.event_name):
			continue

		var callback := Callable(self, "_on_event").bind(instance.event_name)
		_event_callables[instance.event_name] = callback
		EventBus.subscribe(instance.event_name, callback)


func _on_event(event_data, event_name: StringName) -> void:
	var owner := get_parent()
	if owner != null and owner.has_method("is_liveness_enabled") and not bool(owner.call("is_liveness_enabled", &"triggers")) and _should_gate_disabled_trigger(owner, event_name, event_data):
		return
	for instance in trigger_instances:
		if instance.event_name == event_name:
			instance.execute(event_name, event_data)


func _should_gate_disabled_trigger(owner: Node, event_name: StringName, event_data) -> bool:
	if not _is_lifecycle_event(event_name):
		return true
	if event_data == null:
		return false
	var gated_targets: Variant = event_data.core.get("liveness_gated_target_ids", PackedInt32Array())
	if not (gated_targets is PackedInt32Array):
		return false
	if owner.has_method("get_entity_id") and PackedInt32Array(gated_targets).has(int(owner.call("get_entity_id"))):
		return true
	return false


func _is_lifecycle_event(event_name: StringName) -> bool:
	return event_name == &"placement.accepted" or event_name == &"entity.spawned" or event_name == &"entity.died"
