extends RefCounted

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const EffectRuntimeUtilsRef = preload("res://extensions/phase5_chaos_pack/scripts/effects/effect_runtime_utils.gd")


func execute(context, params: Dictionary, _node) -> Variant:
	var result: Variant = EffectResultRef.new()
	var initial_target: Node = EffectRuntimeUtilsRef.resolve_target(context, StringName(params.get("target_mode", &"context_target")))
	if initial_target == null or not initial_target.has_method("take_damage"):
		result.success = false
		result.notes.append("chain_bounce target missing or invalid.")
		return result

	var bounce_count := maxi(1, int(params.get("bounce_count", 3)))
	var bounce_radius := float(params.get("bounce_radius", 140.0))
	var base_damage := int(params.get("base_damage", 14))
	var damage_falloff := float(params.get("damage_falloff", 0.75))
	var hit_targets: Array = [initial_target]
	_apply_bounce_damage(context, initial_target, base_damage, 0)

	var current_target: Node = initial_target
	for bounce_index in range(1, bounce_count):
		var next_target := _find_next_bounce_target(context, current_target, hit_targets, bounce_radius)
		if next_target == null:
			break
		hit_targets.append(next_target)
		var damage := maxi(1, int(round(float(base_damage) * pow(damage_falloff, bounce_index))))
		_apply_bounce_damage(context, next_target, damage, bounce_index)
		current_target = next_target

	return result


func _apply_bounce_damage(context, target: Node, damage: int, bounce_index: int) -> void:
	var tags := PackedStringArray(["effect", "chain_bounce", "extension"])
	tags = EffectRuntimeUtilsRef.append_unique_tag(tags, "bounce_%d" % bounce_index)
	target.call("take_damage", damage, context.source_node, tags, {
		"depth": int(context.runtime.get("depth", context.depth)) + 1,
		"chain_id": context.chain_id,
		"origin_event_name": context.event_name,
	})


func _find_next_bounce_target(context, current_target: Node, hit_targets: Array, bounce_radius: float) -> Node:
	if GameState.current_battle == null or not GameState.current_battle.has_method("get_runtime_combat_entities"):
		return null
	var origin := EffectRuntimeUtilsRef.node_ground_position(current_target)
	var source_team := EffectRuntimeUtilsRef.extract_team(context.source_node)
	var nearest_target: Node = null
	var nearest_distance := INF
	for entity in GameState.current_battle.call("get_runtime_combat_entities"):
		if entity == null or hit_targets.has(entity):
			continue
		if not entity.has_method("take_damage"):
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		if EffectRuntimeUtilsRef.extract_team(entity) == source_team:
			continue
		var distance := EffectRuntimeUtilsRef.node_ground_position(entity).distance_to(origin)
		if distance > bounce_radius:
			continue
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_target = entity
	return nearest_target
