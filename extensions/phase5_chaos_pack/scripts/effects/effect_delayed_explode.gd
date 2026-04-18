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
		result.notes.append("delayed_explode requires an active battle runtime.")
		return result
	var runner := EffectDelayRunnerRef.new()
	battle.add_child(runner)
	var delayed_context = context.duplicate_deep()
	var delay := float(params.get("delay", 0.5))
	runner.setup(delay, func(): _fire_delayed_explode(delayed_context, params))
	return result


func _fire_delayed_explode(context, params: Dictionary) -> void:
	if GameState.current_battle == null or not GameState.current_battle.has_method("get_runtime_combat_entities"):
		return
	var center: Vector2 = EffectRuntimeUtilsRef.node_ground_position(context.target_node)
	if center == Vector2.ZERO:
		center = context.position
	var radius := float(params.get("radius", 120.0))
	var amount := int(params.get("amount", 18))
	var source_team := EffectRuntimeUtilsRef.extract_team(context.source_node)
	var delayed_event: Variant = EventDataRef.create(context.source_node, context.target_node, amount, PackedStringArray(["extension", "delayed_explode"]))
	delayed_event.core["delay"] = float(params.get("delay", 0.5))
	delayed_event.core["radius"] = radius
	EventBus.push_event(&"effect.delayed_exploded", delayed_event)
	for entity in GameState.current_battle.call("get_runtime_combat_entities"):
		if entity == null or not entity.has_method("take_damage"):
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		if EffectRuntimeUtilsRef.extract_team(entity) == source_team:
			continue
		if EffectRuntimeUtilsRef.node_ground_position(entity).distance_to(center) > radius:
			continue
		entity.call("take_damage", amount, context.source_node, PackedStringArray(["explode", "delayed_explode", "extension"]), {
			"depth": int(context.runtime.get("depth", context.depth)) + 1,
			"chain_id": context.chain_id,
			"origin_event_name": context.event_name,
		})
