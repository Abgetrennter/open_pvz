extends RefCounted

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")


func evaluate(_event_data, condition_values: Dictionary, _entity_state: Dictionary, _instance) -> bool:
	var probe_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["registry", "probe", "trigger"]))
	probe_event.core["trigger_id"] = &"registry_probe.trigger"
	probe_event.core["probe_id"] = StringName(condition_values.get("probe_id", &"trigger"))
	EventBus.push_event(&"registry.probe_trigger_evaluated", probe_event)
	return true
