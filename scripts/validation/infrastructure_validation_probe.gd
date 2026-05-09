extends Node
class_name InfrastructureValidationProbe

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var _battle: Node = null
var _emitted: Dictionary = {}


func setup(battle: Node) -> void:
	_battle = battle


func _process(_delta: float) -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	var active_scenario: Variant = _battle.resolve_scenario()
	if active_scenario == null:
		return
	var scenario_id: StringName = StringName(active_scenario.scenario_id)
	if scenario_id == &"spatial_index_consistency_validation":
		_probe_spatial_index()


func _probe_spatial_index() -> void:
	if _emitted.has(&"spatial_index"):
		return
	if not _battle.has_method("spatial_query") or not _battle.has_method("get_runtime_combat_entities"):
		return
	if int(_battle.call("get_spatial_snapshot_version")) <= 0:
		return
	var entities: Array = _battle.call("get_runtime_combat_entities")
	if entities.size() < 4:
		return

	var lane_team_query: Dictionary = {
		"team_exclude": &"plant",
		"lane_ids": PackedInt32Array([1]),
		"x_min": 120.0,
		"x_max": 360.0,
		"filter": func(candidate): return _is_targetable(candidate),
		"sort_by_x": true,
	}
	if not _query_matches_scan(lane_team_query, func(candidate): return _is_targetable(candidate)):
		return
	_emit_probe(&"spatial_lane_team_x", &"passed", {"count": _battle.call("spatial_query", lane_team_query).size()})

	var tag_kind_query: Dictionary = {
		"team_include": &"zombie",
		"tags_any": PackedStringArray(["scout"]),
		"kinds": PackedStringArray(["zombie"]),
		"filter": func(candidate): return _is_targetable(candidate),
	}
	if not _query_matches_scan(tag_kind_query, func(candidate): return _is_targetable(candidate)):
		return
	_emit_probe(&"spatial_tag_kind", &"passed", {"count": _battle.call("spatial_query", tag_kind_query).size()})

	var height_query: Dictionary = {
		"team_include": &"zombie",
		"lane_ids": PackedInt32Array([1]),
		"height_range": Vector2(40.0, 80.0),
		"filter": func(candidate): return _is_targetable(candidate),
		"sort_by_x": true,
	}
	if not _query_matches_scan(height_query, func(candidate): return _is_targetable(candidate)):
		return
	_emit_probe(&"spatial_height_range", &"passed", {"count": _battle.call("spatial_query", height_query).size()})

	var stable_a: PackedInt32Array = _ids(_battle.call("spatial_query", lane_team_query))
	var stable_b: PackedInt32Array = _ids(_battle.call("spatial_query", lane_team_query))
	if stable_a != stable_b or stable_a.is_empty():
		return
	_emit_probe(&"spatial_stable_order", &"passed", {"count": stable_a.size()})
	_emitted[&"spatial_index"] = true


func _query_matches_scan(query: Dictionary, extra_filter: Callable) -> bool:
	var spatial: Array = _battle.call("spatial_query", query)
	var scanned: Array = _scan_entities(query, extra_filter)
	return _ids(spatial) == _ids(scanned)


func _scan_entities(query: Dictionary, extra_filter: Callable) -> Array:
	var result: Array = []
	for candidate in _battle.call("get_runtime_combat_entities"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not (candidate is Node2D):
			continue
		if not _passes_scan_filters(candidate, query):
			continue
		if extra_filter.is_valid() and not bool(extra_filter.call(candidate)):
			continue
		result.append(candidate)
	if bool(query.get("sort_by_x", false)):
		result.sort_custom(func(a, b): return _compare_by_x(a, b))
	elif bool(query.get("sort_by_distance", false)) and query.has("center"):
		var center := Vector2(query.get("center"))
		result.sort_custom(func(a, b): return _compare_by_distance(a, b, center))
	var max_results := int(query.get("max_results", 0))
	if max_results > 0 and result.size() > max_results:
		return result.slice(0, max_results)
	return result


func _passes_scan_filters(candidate: Node2D, query: Dictionary) -> bool:
	if query.has("team_exclude") and StringName(candidate.get("team")) == StringName(query.get("team_exclude")):
		return false
	if query.has("team_include") and StringName(candidate.get("team")) != StringName(query.get("team_include")):
		return false
	if query.has("lane_ids"):
		var lane_ids := PackedInt32Array(query.get("lane_ids", PackedInt32Array()))
		if not lane_ids.is_empty() and not lane_ids.has(int(candidate.get("lane_id"))):
			return false
	if query.has("tags_any"):
		var tags_any := PackedStringArray(query.get("tags_any", PackedStringArray()))
		if not tags_any.is_empty() and not _has_any_tag(candidate, tags_any):
			return false
	if query.has("kinds"):
		var kinds := PackedStringArray(query.get("kinds", PackedStringArray()))
		if not kinds.is_empty() and not kinds.has(String(candidate.get("entity_kind"))):
			return false
	var position: Vector2 = _node_ground_position(candidate)
	if query.has("x_min") and position.x < float(query.get("x_min")):
		return false
	if query.has("x_max") and position.x > float(query.get("x_max")):
		return false
	if query.has("center") and query.has("radius"):
		if position.distance_to(Vector2(query.get("center"))) > float(query.get("radius")):
			return false
	if query.has("height_range") and not _height_overlaps(candidate, Vector2(query.get("height_range"))):
		return false
	return true


func _has_any_tag(candidate: Node, tags: PackedStringArray) -> bool:
	var raw_tags: Variant = candidate.get("tags")
	var candidate_tags: PackedStringArray = PackedStringArray()
	if raw_tags is PackedStringArray:
		candidate_tags = raw_tags
	elif raw_tags is Array:
		candidate_tags = PackedStringArray(raw_tags)
	for tag in tags:
		if candidate_tags.has(StringName(tag)):
			return true
	return false


func _height_overlaps(candidate: Node, height_range: Vector2) -> bool:
	var candidate_range := Vector2(0.0, 24.0)
	if candidate.has_method("get_hit_height_range"):
		var value: Variant = candidate.call("get_hit_height_range")
		if value is Vector2:
			candidate_range = value
	return height_range.y >= candidate_range.x and height_range.x <= candidate_range.y


func _is_targetable(candidate: Node) -> bool:
	return candidate != null and candidate.has_method("is_targetable") and bool(candidate.call("is_targetable"))


func _node_ground_position(node: Node) -> Vector2:
	if node != null and node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO


func _compare_by_x(a, b) -> bool:
	var ax: float = _node_ground_position(a).x
	var bx: float = _node_ground_position(b).x
	if not is_equal_approx(ax, bx):
		return ax < bx
	return _stable_id(a) < _stable_id(b)


func _compare_by_distance(a, b, center: Vector2) -> bool:
	var ad: float = center.distance_squared_to(_node_ground_position(a))
	var bd: float = center.distance_squared_to(_node_ground_position(b))
	if not is_equal_approx(ad, bd):
		return ad < bd
	return _stable_id(a) < _stable_id(b)


func _ids(nodes: Array) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for node in nodes:
		if node != null and node.has_method("get_entity_id"):
			ids.append(int(node.call("get_entity_id")))
	return ids


func _stable_id(node: Node) -> int:
	if node != null and node.has_method("get_entity_id"):
		return int(node.call("get_entity_id"))
	return 2147483647


func _emit_probe(probe: StringName, result: StringName, extra_core: Dictionary = {}) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["infrastructure", "validation"]))
	event_data.core["probe"] = probe
	event_data.core["result"] = result
	for key: Variant in extra_core.keys():
		event_data.core[key] = extra_core[key]
	EventBus.push_event(&"infrastructure.validation_probe", event_data)
