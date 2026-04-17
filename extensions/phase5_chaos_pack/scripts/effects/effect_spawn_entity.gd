extends RefCounted

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")


func execute(context, params: Dictionary, _node) -> Variant:
	var result: Variant = EffectResultRef.new()
	if GameState.current_battle == null or not GameState.current_battle.has_method("spawn_entity_from_effect"):
		result.success = false
		result.notes.append("No active battle manager available for spawn_entity.")
		return result

	var metadata := {
		"spawn_reason": StringName(params.get("spawn_reason", &"extension_spawn")),
	}
	var spawned_entity = GameState.current_battle.call("spawn_entity_from_effect", context, params, metadata)
	if spawned_entity == null:
		result.success = false
		result.notes.append("spawn_entity failed to create runtime entity.")
	return result
