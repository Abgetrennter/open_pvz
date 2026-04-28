extends Node

var _strategies: Dictionary = {}


func _ready() -> void:
	_register_builtin_strategies()


func register_strategy(detection_id: StringName, strategy: Callable) -> void:
	if detection_id == StringName() or not strategy.is_valid():
		return
	_strategies[detection_id] = strategy


func get_strategy(detection_id: StringName) -> Callable:
	return _strategies.get(detection_id, Callable())


func evaluate(detection_id: StringName, owner: Node, params: Dictionary = {}) -> Dictionary:
	var resolved_id := detection_id if detection_id != StringName() else &"always"
	var strategy: Callable = get_strategy(resolved_id)
	if not strategy.is_valid():
		return _empty_result()
	var raw_result: Variant = strategy.call(owner, params)
	if not (raw_result is Dictionary):
		return _empty_result()

	var normalized_targets: Array = []
	for target in Array(raw_result.get("targets", [])):
		if not (target is Node2D):
			continue
		if not is_instance_valid(target):
			continue
		normalized_targets.append(target)

	var primary_target: Node2D = null
	var raw_primary_target: Variant = raw_result.get("primary_target", null)
	if raw_primary_target is Node2D and is_instance_valid(raw_primary_target):
		primary_target = raw_primary_target as Node2D
	elif not normalized_targets.is_empty():
		primary_target = normalized_targets[0] as Node2D

	if primary_target != null and not normalized_targets.has(primary_target):
		normalized_targets.push_front(primary_target)

	var has_target := bool(raw_result.get("has_target", primary_target != null or not normalized_targets.is_empty()))
	return {
		"has_target": has_target,
		"targets": normalized_targets,
		"primary_target": primary_target,
	}


func _register_builtin_strategies() -> void:
	register_strategy(&"always", func(_owner: Node, _params: Dictionary) -> Dictionary:
		return {
			"has_target": true,
			"targets": [],
			"primary_target": null,
		}
	)

	register_strategy(&"lane_forward", func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var lane_id := int(owner.get("lane_id"))
		if lane_id < 0:
			return _empty_result()
		var scan_range := float(params.get("scan_range", 900.0))
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array([lane_id]), scan_range, &"forward", true, target_tags)
		return {
			"has_target": not targets.is_empty(),
			"targets": targets,
			"primary_target": null if targets.is_empty() else targets[0],
		}
	)

	register_strategy(&"lane_backward", func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var lane_id := int(owner.get("lane_id"))
		if lane_id < 0:
			return _empty_result()
		var scan_range := float(params.get("scan_range", 900.0))
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array([lane_id]), scan_range, &"backward", true, target_tags)
		return {
			"has_target": not targets.is_empty(),
			"targets": targets,
			"primary_target": null if targets.is_empty() else targets[0],
		}
	)

	register_strategy(&"radius_around", func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var scan_range := float(params.get("scan_range", 180.0))
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array(), scan_range, &"both", true, target_tags)
		return {
			"has_target": not targets.is_empty(),
			"targets": targets,
			"primary_target": null if targets.is_empty() else targets[0],
		}
	)

	register_strategy(&"global_track", func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var scan_range := float(params.get("scan_range", 4000.0))
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array(), scan_range, &"both", true, target_tags)
		return {
			"has_target": not targets.is_empty(),
			"targets": targets.slice(0, 1),
			"primary_target": null if targets.is_empty() else targets[0],
		}
	)

	register_strategy(&"proximity", func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var scan_range := float(params.get("scan_range", 64.0))
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array(), scan_range, &"both", true, target_tags)
		return {
			"has_target": not targets.is_empty(),
			"targets": targets,
			"primary_target": null if targets.is_empty() else targets[0],
		}
	)


func _scan_enemies(
	source: Node,
	lane_ids: PackedInt32Array,
	scan_range: float,
	direction: StringName = &"both",
	combat_active_only: bool = true,
	target_tags: PackedStringArray = PackedStringArray(),
) -> Array:
	if source == null or not (source is Node2D):
		return []
	if GameState.current_battle == null:
		return []

	var battle := GameState.current_battle
	var runtime_entities: Array = []
	if battle.has_method("get_runtime_combat_entities"):
		runtime_entities = Array(battle.call("get_runtime_combat_entities"))
	elif battle.has_method("get_runtime_entities"):
		runtime_entities = Array(battle.call("get_runtime_entities"))
	else:
		return []

	var source_team := StringName(source.get("team"))
	var source_position := _node_ground_position(source)
	var candidate_entries: Array = []

	for candidate in runtime_entities:
		if candidate == null or candidate == source:
			continue
		if not (candidate is Node2D):
			continue
		if not candidate.has_method("take_damage"):
			continue
		if candidate.get("team") == source_team:
			continue
		if not lane_ids.is_empty() and not lane_ids.has(int(candidate.get("lane_id"))):
			continue
		if not target_tags.is_empty():
			var entity_tags: PackedStringArray = PackedStringArray()
			var raw_tags: Variant = candidate.get("tags")
			if raw_tags is PackedStringArray:
				entity_tags = PackedStringArray(raw_tags)
			elif raw_tags is Array:
				entity_tags = PackedStringArray(raw_tags)
			var has_tag := false
			for target_tag in target_tags:
				if entity_tags.has(StringName(target_tag)):
					has_tag = true
					break
			if not has_tag:
				continue
		if combat_active_only and candidate.has_method("is_combat_active") and not bool(candidate.call("is_combat_active")):
			continue

		var candidate_node := candidate as Node2D
		var candidate_position := _node_ground_position(candidate_node)
		var delta := candidate_position - source_position
		if direction == &"forward" and delta.x < 0.0:
			continue
		if direction == &"backward" and delta.x > 0.0:
			continue

		var distance := source_position.distance_to(candidate_position)
		if distance > scan_range:
			continue

		candidate_entries.append({
			"node": candidate_node,
			"distance": distance,
		})

	candidate_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", INF)) < float(b.get("distance", INF))
	)

	var targets: Array = []
	for candidate_entry in candidate_entries:
		targets.append(candidate_entry.get("node"))
	return targets


func _node_ground_position(node: Node) -> Vector2:
	if node == null or not (node is Node2D):
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return (node as Node2D).global_position


func _empty_result() -> Dictionary:
	return {
		"has_target": false,
		"targets": [],
		"primary_target": null,
	}


func _resolve_target_tags(params: Dictionary) -> PackedStringArray:
	var raw: Variant = params.get("target_tags", PackedStringArray())
	if raw is PackedStringArray:
		return PackedStringArray(raw)
	if raw is Array:
		return PackedStringArray(raw)
	return PackedStringArray()
