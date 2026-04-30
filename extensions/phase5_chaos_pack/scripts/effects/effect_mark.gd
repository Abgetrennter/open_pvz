extends RefCounted

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EffectRuntimeUtilsRef = preload("res://extensions/phase5_chaos_pack/scripts/effects/effect_runtime_utils.gd")


func execute(context, params: Dictionary, _node) -> Variant:
	var result: Variant = EffectResultRef.new()
	var target: Node = EffectRuntimeUtilsRef.resolve_target(context, StringName(params.get("target_mode", &"context_target")))
	if target == null or not target.has_method("apply_mark"):
		result.success = false
		result.notes.append("mark target missing or invalid.")
		return result
	var mark_id := StringName(params.get("mark_id", StringName()))
	if mark_id == StringName():
		result.success = false
		result.notes.append("mark requires mark_id.")
		return result
	var duration := float(params.get("duration", 1.2))
	target.call("apply_mark", mark_id, duration, {
		"source_archetype_id": StringName(context.core.get("source_archetype_id", StringName())),
	})
	var mark_event: Variant = EventDataRef.create(context.source_node, target, null, PackedStringArray(["extension", "mark", "applied"]))
	mark_event.core["mark_id"] = mark_id
	mark_event.core["duration"] = duration
	EventBus.push_event(&"entity.mark_applied", mark_event)
	return result
