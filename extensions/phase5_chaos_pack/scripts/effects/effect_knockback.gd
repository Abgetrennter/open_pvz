extends RefCounted

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EffectRuntimeUtilsRef = preload("res://extensions/phase5_chaos_pack/scripts/effects/effect_runtime_utils.gd")


func execute(context, params: Dictionary, _node) -> Variant:
	var result: Variant = EffectResultRef.new()
	var target_mode := StringName(params.get("target_mode", &"context_target"))
	var target: Node = EffectRuntimeUtilsRef.resolve_target(context, target_mode)
	if target == null or not (target is Node2D):
		result.success = false
		result.notes.append("knockback target missing or invalid.")
		return result

	var target_node := target as Node2D
	var source_position := EffectRuntimeUtilsRef.node_ground_position(context.source_node)
	var target_position := EffectRuntimeUtilsRef.node_ground_position(target_node)
	var direction_sign := 1.0
	if source_position != Vector2.ZERO and target_position.x < source_position.x:
		direction_sign = -1.0
	var impact_damage := int(params.get("impact_damage", 0))
	if impact_damage > 0 and target_node.has_method("take_damage"):
		target_node.call("take_damage", impact_damage, context.source_node, PackedStringArray(["effect", "knockback", "projectile.hit"]), {
			"depth": int(context.runtime.get("depth", context.depth)) + 1,
			"chain_id": context.chain_id,
			"origin_event_name": context.event_name,
		})
	var distance := float(params.get("distance", 60.0))
	var before_position := target_node.global_position
	target_node.global_position += Vector2.RIGHT * distance * direction_sign
	if target_node.has_method("sync_runtime_state"):
		target_node.call("sync_runtime_state")

	var knockback_event: Variant = EventDataRef.create(context.source_node, target_node, distance, PackedStringArray(["extension", "knockback"]))
	knockback_event.core["distance"] = distance
	knockback_event.core["impact_damage"] = impact_damage
	knockback_event.core["before_position"] = before_position
	knockback_event.core["after_position"] = target_node.global_position
	EventBus.push_event(&"entity.knockback_applied", knockback_event)
	return result
