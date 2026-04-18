extends RefCounted

const EffectDelayRunnerRef = preload("res://scripts/core/runtime/effect_delay_runner.gd")
const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EffectRuntimeUtilsRef = preload("res://extensions/phase5_chaos_pack/scripts/effects/effect_runtime_utils.gd")


func execute(context, params: Dictionary, _node) -> Variant:
	var result: Variant = EffectResultRef.new()
	var battle := GameState.current_battle
	if battle == null:
		result.success = false
		result.notes.append("delayed_trigger requires an active battle runtime.")
		return result
	var runner := EffectDelayRunnerRef.new()
	battle.add_child(runner)
	var delayed_context = context.duplicate_deep()
	var delay := float(params.get("delay", 0.5))
	runner.setup(delay, func(): _fire_delayed_trigger(delayed_context, params))
	return result


func _fire_delayed_trigger(context, params: Dictionary) -> void:
	var target: Node = EffectRuntimeUtilsRef.resolve_target(context, StringName(params.get("target_mode", &"context_target")))
	if target == null or not target.has_method("take_damage"):
		return
	var amount := int(params.get("amount", 12))
	var delayed_event: Variant = EventDataRef.create(context.source_node, target, amount, PackedStringArray(["extension", "delayed_trigger"]))
	delayed_event.core["delay"] = float(params.get("delay", 0.5))
	EventBus.push_event(&"effect.delayed_triggered", delayed_event)
	target.call("take_damage", amount, context.source_node, PackedStringArray(["effect", "delayed_trigger", "extension"]), {
		"depth": int(context.runtime.get("depth", context.depth)) + 1,
		"chain_id": context.chain_id,
		"origin_event_name": context.event_name,
	})
