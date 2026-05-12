extends "res://scripts/core/registry/registry_base.gd"

const DetectionDefRef = preload("res://scripts/core/defs/detection_def.gd")

var _detection_strategies: Dictionary = {}
var _detection_strategy_owners: Dictionary = {}


func _make_registry_config():
	return RegistryConfigRef.create(
		&"detections",
		DetectionDefRef,
		&"detections",
		"data/combat/detections",
		&"trusted_runtime",
		StringName(),
		false
	)


func _on_registry_cleared() -> void:
	_detection_strategies.clear()
	_detection_strategy_owners.clear()


func _register_builtin_defs() -> void:
	var always_def = DetectionDefRef.new()
	always_def.id = &"always"
	register_def(always_def, {"kind": &"core", "source": &"core"})

	var lane_forward_def = DetectionDefRef.new()
	lane_forward_def.id = &"lane_forward"
	register_def(lane_forward_def, {"kind": &"core", "source": &"core"})

	var lane_backward_def = DetectionDefRef.new()
	lane_backward_def.id = &"lane_backward"
	register_def(lane_backward_def, {"kind": &"core", "source": &"core"})

	var radius_around_def = DetectionDefRef.new()
	radius_around_def.id = &"radius_around"
	register_def(radius_around_def, {"kind": &"core", "source": &"core"})

	var global_track_def = DetectionDefRef.new()
	global_track_def.id = &"global_track"
	register_def(global_track_def, {"kind": &"core", "source": &"core"})

	var proximity_def = DetectionDefRef.new()
	proximity_def.id = &"proximity"
	register_def(proximity_def, {"kind": &"core", "source": &"core"})

	_register_builtin_strategies()


func evaluate(detection_id: StringName, owner: Node, params: Dictionary = {}) -> Dictionary:
	var resolved_id := detection_id if detection_id != StringName() else &"always"
	var strategy: Callable = _detection_strategies.get(resolved_id, Callable())
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


func _validate_def_specific(detection_def: Resource, source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if bool(source.get("extension", false)):
		if detection_def.strategy_script == null or not (detection_def.strategy_script is Script):
			errors.append("DetectionDef %s strategy_script must be a Script." % String(detection_def.id))
		else:
			var strategy_owner = detection_def.strategy_script.new()
			if strategy_owner == null or not strategy_owner.has_method("evaluate"):
				errors.append("DetectionDef %s strategy_script must expose evaluate(owner, params)." % String(detection_def.id))
	return errors


func _on_def_registered(entry: Dictionary) -> void:
	var source: Dictionary = Dictionary(entry.get("source", {}))
	if not bool(source.get("extension", false)):
		return
	var detection_def = entry.get("def", null)
	if detection_def == null or detection_def.strategy_script == null:
		return
	var strategy_owner = detection_def.strategy_script.new()
	if strategy_owner == null or not strategy_owner.has_method("evaluate"):
		return
	_detection_strategy_owners[detection_def.id] = strategy_owner
	_detection_strategies[detection_def.id] = Callable(strategy_owner, "evaluate")


func _register_builtin_strategies() -> void:
	_detection_strategies[&"always"] = func(_owner: Node, _params: Dictionary) -> Dictionary:
		return {
			"has_target": true,
			"targets": [],
			"primary_target": null,
		}

	_detection_strategies[&"lane_forward"] = func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var lane_id := int(owner.get("lane_id"))
		if lane_id < 0:
			return _empty_result()
		var scan_range := _resolve_scan_range(owner, params, 900.0)
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array([lane_id]), scan_range, &"forward", target_tags, _resolve_target_priority_tags(params), _resolve_target_exclude_tags(params))
		return {
			"has_target": not targets.is_empty(),
			"targets": targets,
			"primary_target": null if targets.is_empty() else targets[0],
		}

	_detection_strategies[&"lane_backward"] = func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var lane_id := int(owner.get("lane_id"))
		if lane_id < 0:
			return _empty_result()
		var scan_range := _resolve_scan_range(owner, params, 900.0)
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array([lane_id]), scan_range, &"backward", target_tags, _resolve_target_priority_tags(params), _resolve_target_exclude_tags(params))
		return {
			"has_target": not targets.is_empty(),
			"targets": targets,
			"primary_target": null if targets.is_empty() else targets[0],
		}

	_detection_strategies[&"radius_around"] = func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var scan_range := _resolve_scan_range(owner, params, 180.0)
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array(), scan_range, &"both", target_tags, _resolve_target_priority_tags(params), _resolve_target_exclude_tags(params))
		return {
			"has_target": not targets.is_empty(),
			"targets": targets,
			"primary_target": null if targets.is_empty() else targets[0],
		}

	_detection_strategies[&"global_track"] = func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var scan_range := _resolve_scan_range(owner, params, 4000.0)
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array(), scan_range, &"both", target_tags, _resolve_target_priority_tags(params), _resolve_target_exclude_tags(params))
		return {
			"has_target": not targets.is_empty(),
			"targets": targets.slice(0, 1),
			"primary_target": null if targets.is_empty() else targets[0],
		}

	_detection_strategies[&"proximity"] = func(owner: Node, params: Dictionary) -> Dictionary:
		if owner == null or not (owner is Node2D):
			return _empty_result()
		var scan_range := _resolve_scan_range(owner, params, 64.0)
		var target_tags: PackedStringArray = _resolve_target_tags(params)
		var targets := _scan_enemies(owner, PackedInt32Array(), scan_range, &"both", target_tags, _resolve_target_priority_tags(params), _resolve_target_exclude_tags(params))
		return {
			"has_target": not targets.is_empty(),
			"targets": targets,
			"primary_target": null if targets.is_empty() else targets[0],
		}


func _scan_enemies(
	source: Node,
	lane_ids: PackedInt32Array,
	scan_range: float,
	direction: StringName = &"both",
	target_tags: PackedStringArray = PackedStringArray(),
	target_priority_tags: PackedStringArray = PackedStringArray(),
	target_exclude_tags: PackedStringArray = PackedStringArray(),
) -> Array:
	if source == null or not (source is Node2D):
		return []
	if GameState.current_battle == null:
		return []

	var battle := GameState.current_battle
	if not battle.has_method("spatial_query"):
		return []

	var source_team := StringName(source.get("team"))
	var source_position := _node_ground_position(source)
	var query := {
		"team_exclude": source_team,
		"center": source_position,
		"radius": scan_range,
		"tags_any": target_tags,
		"filter": func(candidate): return candidate != source \
			and candidate.has_method("take_damage") \
			and not _node_has_any_tag(candidate, target_exclude_tags) \
			and (not candidate.has_method("is_targetable") or bool(candidate.call("is_targetable"))),
		"sort_by_distance": true,
	}
	if not lane_ids.is_empty():
		query["lane_ids"] = lane_ids
	match direction:
		&"forward":
			query["x_min"] = source_position.x
		&"backward":
			query["x_max"] = source_position.x
	return _prioritize_targets_by_tags(battle.call("spatial_query", query), target_priority_tags)


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


func _resolve_target_priority_tags(params: Dictionary) -> PackedStringArray:
	var raw: Variant = params.get("target_priority_tags", PackedStringArray())
	if raw is PackedStringArray:
		return PackedStringArray(raw)
	if raw is Array:
		return PackedStringArray(raw)
	return PackedStringArray()


func _resolve_target_exclude_tags(params: Dictionary) -> PackedStringArray:
	var raw: Variant = params.get("target_exclude_tags", PackedStringArray())
	if raw is PackedStringArray:
		return PackedStringArray(raw)
	if raw is Array:
		return PackedStringArray(raw)
	return PackedStringArray()


func _prioritize_targets_by_tags(targets: Array, priority_tags: PackedStringArray) -> Array:
	if priority_tags.is_empty() or targets.is_empty():
		return targets
	var prioritized: Array = []
	var remaining: Array = []
	for target in targets:
		if _node_has_any_tag(target, priority_tags):
			prioritized.append(target)
		else:
			remaining.append(target)
	prioritized.append_array(remaining)
	return prioritized


func _node_has_any_tag(node: Node, tags: PackedStringArray) -> bool:
	if node == null or tags.is_empty():
		return false
	var raw_tags: Variant = node.get("tags")
	var node_tags := PackedStringArray()
	if raw_tags is PackedStringArray:
		node_tags = PackedStringArray(raw_tags)
	elif raw_tags is Array:
		node_tags = PackedStringArray(raw_tags)
	for tag in tags:
		if node_tags.has(StringName(tag)):
			return true
	return false


func _resolve_scan_range(owner: Node, params: Dictionary, default_world: float) -> float:
	var metrics := _get_battlefield_metrics()
	if metrics != null and metrics.has_method("resolve_range"):
		var origin_x := 0.0
		if owner is Node2D:
			origin_x = _node_ground_position(owner).x
		return float(metrics.call("resolve_range", params, "scan_range_slots", "scan_range", default_world, origin_x))
	if params.has("scan_range_slots"):
		return float(params.get("scan_range_slots")) * 96.0
	return float(params.get("scan_range", default_world))


func _get_battlefield_metrics() -> RefCounted:
	if GameState.current_battle == null:
		return null
	if not GameState.current_battle.has_method("get_battlefield_metrics"):
		return null
	var metrics: Variant = GameState.current_battle.call("get_battlefield_metrics")
	return metrics if metrics is RefCounted else null
