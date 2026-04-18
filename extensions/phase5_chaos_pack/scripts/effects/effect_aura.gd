extends RefCounted

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EffectRuntimeUtilsRef = preload("res://extensions/phase5_chaos_pack/scripts/effects/effect_runtime_utils.gd")


func execute(context, params: Dictionary, _node) -> Variant:
	var result: Variant = EffectResultRef.new()
	if GameState.current_battle == null or not GameState.current_battle.has_method("get_runtime_combat_entities"):
		result.success = false
		result.notes.append("aura requires an active battle runtime.")
		return result

	var origin_node: Node = _resolve_origin_node(context, StringName(params.get("origin_mode", &"owner")))
	if origin_node == null:
		result.success = false
		result.notes.append("aura origin missing.")
		return result

	var origin_position := EffectRuntimeUtilsRef.node_ground_position(origin_node)
	var radius := float(params.get("radius", 140.0))
	var status_id := StringName(params.get("status_id", StringName()))
	if status_id == StringName():
		result.success = false
		result.notes.append("aura requires status_id.")
		return result

	var duration := float(params.get("duration", 0.6))
	var movement_scale := float(params.get("movement_scale", 1.0))
	var blocks_attack := bool(params.get("blocks_attack", false))
	var team_mode := StringName(params.get("team_mode", &"enemies"))
	var lane_only := bool(params.get("lane_only", false))
	var source_team := EffectRuntimeUtilsRef.extract_team(origin_node)
	var source_lane := int(origin_node.get("lane_id")) if origin_node.get("lane_id") is int else -1
	var applied_count := 0

	for entity in GameState.current_battle.call("get_runtime_combat_entities"):
		if entity == null or entity == origin_node:
			continue
		if not entity.has_method("apply_status"):
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		if lane_only and source_lane >= 0 and int(entity.get("lane_id")) != source_lane:
			continue
		if not _matches_team_mode(source_team, entity, team_mode):
			continue
		if EffectRuntimeUtilsRef.node_ground_position(entity).distance_to(origin_position) > radius:
			continue
		entity.call("apply_status", status_id, duration, {
			"movement_scale": movement_scale,
			"blocks_attack": blocks_attack,
		})
		var applied_event: Variant = EventDataRef.create(origin_node, entity, null, PackedStringArray(["status", "applied", "extension", "aura"]))
		applied_event.core["status_id"] = status_id
		applied_event.core["duration"] = duration
		applied_event.core["movement_scale"] = movement_scale
		applied_event.core["blocks_attack"] = blocks_attack
		applied_event.core["radius"] = radius
		applied_event.core["team_mode"] = team_mode
		EventBus.push_event(&"entity.status_applied", applied_event)
		applied_count += 1

	if applied_count == 0:
		result.success = false
		result.notes.append("aura found no targets in range.")
	return result


func _resolve_origin_node(context, origin_mode: StringName) -> Node:
	match origin_mode:
		&"source":
			return context.source_node
		&"event_source":
			return context.core.get("source_node", context.source_node)
		_:
			return context.owner_entity


func _matches_team_mode(source_team: StringName, candidate: Node, team_mode: StringName) -> bool:
	var candidate_team := EffectRuntimeUtilsRef.extract_team(candidate)
	match team_mode:
		&"allies":
			return candidate_team == source_team
		&"all":
			return true
		_:
			return candidate_team != source_team
