extends RefCounted

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")


func evaluate(_owner: Node, params: Dictionary) -> Dictionary:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["registry", "probe", "detection"]))
	event_data.core["probe_id"] = StringName(params.get("probe_id", &"detection"))
	EventBus.push_event(&"registry.probe_detection_evaluated", event_data)
	return {
		"has_target": true,
		"targets": [],
		"primary_target": null,
	}
