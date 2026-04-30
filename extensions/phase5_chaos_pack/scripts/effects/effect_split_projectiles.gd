extends RefCounted

const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")


func execute(context, params: Dictionary, node) -> Variant:
	var result: Variant = EffectResultRef.new()
	if GameState.current_battle == null or not GameState.current_battle.has_method("spawn_projectile_from_effect"):
		result.success = false
		result.notes.append("No active battle manager available for split_projectiles.")
		return result

	var projectile_template: Resource = params.get("projectile_template", null)
	if projectile_template == null:
		result.success = false
		result.notes.append("split_projectiles requires projectile_template.")
		return result

	_apply_impact_damage(context, params)

	var search_radius := float(params.get("search_radius", 260.0))
	var max_targets := maxi(1, int(params.get("max_targets", 2)))
	var impact_position: Vector2 = context.position
	var targets := _find_split_targets(context, impact_position, search_radius, max_targets)
	if targets.is_empty():
		result.success = false
		result.notes.append("split_projectiles found no follow-up targets.")
		return result

	var on_hit_effect = null if node == null else node.get_child(&"on_hit")
	for target in targets:
		var split_context = context.duplicate_deep()
		split_context.position = impact_position
		split_context.target_node = target
		_apply_target_to_context(split_context, target)

		var direction := _direction_to_target(impact_position, target)
		var projectile_params: Dictionary = {
			"projectile_template": projectile_template,
			"movement_mode": StringName(params.get("movement_mode", &"track")),
			"speed": float(params.get("speed", 260.0)),
			"damage": int(params.get("damage", 12)),
			"turn_rate": float(params.get("turn_rate", 8.0)),
			"direction": direction,
			"ignored_entity_ids": PackedInt32Array([_extract_entity_id(context.target_node)]),
			"spawn_position": impact_position,
		}
		if params.get("flight_profile", null) is Resource:
			projectile_params["flight_profile"] = params.get("flight_profile")
		GameState.current_battle.call("spawn_projectile_from_effect", split_context, projectile_params, on_hit_effect)

	return result


func _apply_impact_damage(context, params: Dictionary) -> void:
	var impact_damage := int(params.get("impact_damage", 0))
	if impact_damage <= 0:
		return
	var target: Node = context.target_node
	if target == null or not target.has_method("take_damage"):
		return
	target.call("take_damage", impact_damage, context.source_node, PackedStringArray(["effect", "projectile.hit", "split_projectile"]), {
		"depth": int(context.runtime.get("depth", context.depth)) + 1,
		"chain_id": context.chain_id,
		"origin_event_name": context.event_name,
	})


func _find_split_targets(context, impact_position: Vector2, search_radius: float, max_targets: int) -> Array:
	if GameState.current_battle == null or not GameState.current_battle.has_method("get_runtime_combat_entities"):
		return []

	var source_team := _extract_team(context.source_node)
	var excluded_target: Node = context.target_node
	var candidates: Array = []
	for entity in GameState.current_battle.call("get_runtime_combat_entities"):
		if entity == null or entity == excluded_target or entity == context.owner_entity:
			continue
		if not (entity is Node2D):
			continue
		if not entity.has_method("take_damage"):
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		if _extract_team(entity) == source_team:
			continue
		var candidate_position := _node_ground_position(entity)
		var distance := impact_position.distance_to(candidate_position)
		if distance > search_radius:
			continue
		candidates.append({
			"target": entity,
			"distance": distance,
		})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
	)

	var targets: Array = []
	for candidate in candidates:
		targets.append(candidate.get("target"))
		if targets.size() >= max_targets:
			break
	return targets


func _apply_target_to_context(split_context, target: Node) -> void:
	split_context.core["target_node"] = target
	split_context.core["target_id"] = _extract_entity_id(target)
	split_context.core["target_archetype_id"] = _extract_archetype_id(target)
	split_context.core["target_kind"] = _extract_kind(target)
	split_context.core["target_lane"] = _extract_lane(target)
	split_context.core["target_team"] = _extract_team(target)


func _direction_to_target(origin: Vector2, target: Node) -> Vector2:
	var delta := _node_ground_position(target) - origin
	if delta.length_squared() <= 0.0001:
		return Vector2.RIGHT
	return delta.normalized()


func _node_ground_position(node: Node) -> Vector2:
	if node == null or not (node is Node2D):
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return (node as Node2D).global_position


func _extract_entity_id(node: Node) -> int:
	if node == null or not node.has_method("get_entity_id"):
		return -1
	return int(node.call("get_entity_id"))


func _extract_archetype_id(node: Node) -> StringName:
	if node == null:
		return StringName()
	var value: Variant = node.get("archetype_id")
	return StringName(value) if value is String or value is StringName else StringName()


func _extract_kind(node: Node) -> StringName:
	if node == null:
		return StringName()
	var value: Variant = node.get("entity_kind")
	return StringName(value) if value is String or value is StringName else StringName()


func _extract_lane(node: Node) -> int:
	if node == null:
		return -1
	var value: Variant = node.get("lane_id")
	return int(value) if value is int else -1


func _extract_team(node: Node) -> StringName:
	if node == null:
		return StringName()
	var value: Variant = node.get("team")
	return StringName(value) if value is String or value is StringName else StringName()
