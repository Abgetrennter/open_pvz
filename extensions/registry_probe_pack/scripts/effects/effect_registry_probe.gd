extends RefCounted

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")


func execute(_context, _params: Dictionary, _node) -> Variant:
	var result: Variant = EffectResultRef.new()
	var before_ids := DetectionRegistry.list_ids()
	var before_entry := DetectionRegistry.get_entry(&"registry_probe.detection")
	var source := Dictionary(before_entry.get("source", {}))

	var detection_result: Dictionary = DetectionRegistry.evaluate(&"registry_probe.detection", null, {
		"probe_id": &"registry_probe.detection",
	})
	ControllerRegistry.process_controller(&"registry_probe.controller", null, {
		"id": &"registry_probe.controller",
	}, 0.016, {})
	var trigger_result := TriggerRegistry.evaluate_trigger(
		&"registry_probe.trigger",
		null,
		{"probe_id": &"registry_probe.trigger"},
		{},
		null
	)

	DetectionRegistry.rebuild_registry()
	var after_ids := DetectionRegistry.list_ids()
	var after_entry := DetectionRegistry.get_entry(&"registry_probe.detection")
	var after_source := Dictionary(after_entry.get("source", {}))

	var probe_ok := bool(detection_result.get("has_target", false)) \
		and trigger_result \
		and before_ids == after_ids \
		and StringName(source.get("pack_id", StringName())) == &"registry_probe_pack" \
		and StringName(after_source.get("pack_id", StringName())) == &"registry_probe_pack"

	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["registry", "probe", "extension"]))
	event_data.core["probe_ok"] = probe_ok
	event_data.core["source_pack_id"] = StringName(source.get("pack_id", StringName()))
	event_data.core["after_source_pack_id"] = StringName(after_source.get("pack_id", StringName()))
	event_data.core["id_count_stable"] = before_ids == after_ids
	event_data.core["has_detection_target"] = bool(detection_result.get("has_target", false))
	event_data.core["trigger_result"] = trigger_result
	EventBus.push_event(&"registry.probe_completed", event_data)

	if not probe_ok:
		result.success = false
		result.notes.append("registry probe failed.")
	return result
