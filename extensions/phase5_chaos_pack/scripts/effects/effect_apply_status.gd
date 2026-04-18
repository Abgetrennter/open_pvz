extends RefCounted

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EffectRuntimeUtilsRef = preload("res://extensions/phase5_chaos_pack/scripts/effects/effect_runtime_utils.gd")


func execute(context, params: Dictionary, _node) -> Variant:
	var result: Variant = EffectResultRef.new()
	var target_mode := StringName(params.get("target_mode", &"context_target"))
	var target: Node = EffectRuntimeUtilsRef.resolve_target(context, target_mode)
	if target == null or not target.has_method("apply_status"):
		result.success = false
		result.notes.append("apply_status target missing or invalid.")
		return result

	var status_id := StringName(params.get("status_id", StringName()))
	if status_id == StringName():
		result.success = false
		result.notes.append("apply_status requires status_id.")
		return result

	var duration := float(params.get("duration", 1.0))
	var movement_scale := float(params.get("movement_scale", 1.0))
	var blocks_attack := bool(params.get("blocks_attack", false))
	target.call("apply_status", status_id, duration, {
		"movement_scale": movement_scale,
		"blocks_attack": blocks_attack,
	})

	var applied_event: Variant = EventDataRef.create(context.source_node, target, null, PackedStringArray(["status", "applied", "extension"]))
	applied_event.core["status_id"] = status_id
	applied_event.core["duration"] = duration
	applied_event.core["movement_scale"] = movement_scale
	applied_event.core["blocks_attack"] = blocks_attack
	EventBus.push_event(&"entity.status_applied", applied_event)
	return result
