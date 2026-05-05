extends RefCounted

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")


func process(_owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
	blackboard["registry_probe_ticks"] = int(blackboard.get("registry_probe_ticks", 0)) + 1
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["registry", "probe", "controller"]))
	event_data.core["controller_id"] = &"registry_probe.controller"
	event_data.core["delta_positive"] = delta >= 0.0
	event_data.core["spec_id"] = StringName(spec.get("id", &"registry_probe.controller"))
	EventBus.push_event(&"registry.probe_controller_processed", event_data)
