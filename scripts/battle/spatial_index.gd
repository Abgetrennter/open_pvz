extends RefCounted
class_name SpatialIndex

var _all: Array = []
var _by_team: Dictionary = {}
var _by_lane: Dictionary = {}
var _by_tag: Dictionary = {}
var _by_kind: Dictionary = {}
var _snapshot_version := 0
var _insert_order: Dictionary = {}


func rebuild(entities: Array) -> void:
	_all.clear()
	_by_team.clear()
	_by_lane.clear()
	_by_tag.clear()
	_by_kind.clear()
	_insert_order.clear()

	var order := 0
	for entity in entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if not (entity is Node2D):
			continue
		_all.append(entity)
		_insert_order[entity.get_instance_id()] = order
		order += 1
		_index_entity(entity)

	for lane_id in _by_lane.keys():
		_by_lane[lane_id].sort_custom(_compare_by_x)
	_snapshot_version += 1


func query(params: Dictionary) -> Array:
	var candidates := _resolve_candidate_pool(params)
	var filtered: Array = []
	for candidate in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not (candidate is Node2D):
			continue
		if not _passes_filters(candidate, params):
			continue
		filtered.append(candidate)

	if bool(params.get("sort_by_distance", false)) and params.has("center"):
		var center := Vector2(params.get("center", Vector2.ZERO))
		filtered.sort_custom(func(a, b): return _compare_by_distance(a, b, center))
	elif bool(params.get("sort_by_x", false)):
		filtered.sort_custom(_compare_by_x)

	var max_results := int(params.get("max_results", 0))
	if max_results > 0 and filtered.size() > max_results:
		return filtered.slice(0, max_results)
	return filtered


func get_snapshot_version() -> int:
	return _snapshot_version


func _index_entity(entity: Node2D) -> void:
	var team := StringName(entity.get("team"))
	if team != StringName():
		_append_indexed(_by_team, team, entity)

	var lane_value: Variant = entity.get("lane_id")
	if lane_value is int:
		var lane_id := int(lane_value)
		if lane_id >= 0:
			_append_indexed(_by_lane, lane_id, entity)

	var tags: Variant = entity.get("tags")
	if tags is PackedStringArray or tags is Array:
		for tag in tags:
			_append_indexed(_by_tag, StringName(tag), entity)

	var kind := StringName(entity.get("entity_kind"))
	if kind != StringName():
		_append_indexed(_by_kind, kind, entity)


func _append_indexed(index: Dictionary, key: Variant, entity: Node2D) -> void:
	if not index.has(key):
		index[key] = []
	index[key].append(entity)


func _resolve_candidate_pool(params: Dictionary) -> Array:
	if params.has("tags_any") and not PackedStringArray(params.get("tags_any", PackedStringArray())).is_empty():
		return _pool_from_tags(PackedStringArray(params.get("tags_any")))
	if params.has("lane_ids") and not PackedInt32Array(params.get("lane_ids", PackedInt32Array())).is_empty():
		return _pool_from_lanes(PackedInt32Array(params.get("lane_ids")))
	if params.has("team_include"):
		var include := StringName(params.get("team_include"))
		return Array(_by_team.get(include, []))
	if params.has("team_exclude"):
		var pool: Array = []
		var exclude := StringName(params.get("team_exclude"))
		for team in _by_team.keys():
			if StringName(team) == exclude:
				continue
			pool.append_array(_by_team[team])
		return _dedupe(pool)
	if params.has("kinds") and not PackedStringArray(params.get("kinds", PackedStringArray())).is_empty():
		return _pool_from_kinds(PackedStringArray(params.get("kinds")))
	return Array(_all)


func _pool_from_tags(tags: PackedStringArray) -> Array:
	var pool: Array = []
	for tag in tags:
		pool.append_array(_by_tag.get(StringName(tag), []))
	return _dedupe(pool)


func _pool_from_lanes(lane_ids: PackedInt32Array) -> Array:
	var pool: Array = []
	for lane_id in lane_ids:
		pool.append_array(_by_lane.get(lane_id, []))
	return _dedupe(pool)


func _pool_from_kinds(kinds: PackedStringArray) -> Array:
	var pool: Array = []
	for kind in kinds:
		pool.append_array(_by_kind.get(StringName(kind), []))
	return _dedupe(pool)


func _dedupe(pool: Array) -> Array:
	var seen := {}
	var result: Array = []
	for entity in pool:
		if entity == null or not is_instance_valid(entity):
			continue
		var instance_id: int = entity.get_instance_id()
		if seen.has(instance_id):
			continue
		seen[instance_id] = true
		result.append(entity)
	return result


func _passes_filters(candidate: Node2D, params: Dictionary) -> bool:
	if params.has("team_exclude") and StringName(candidate.get("team")) == StringName(params.get("team_exclude")):
		return false
	if params.has("team_include") and StringName(candidate.get("team")) != StringName(params.get("team_include")):
		return false
	if params.has("lane_ids"):
		var lane_ids := PackedInt32Array(params.get("lane_ids", PackedInt32Array()))
		if not lane_ids.is_empty() and not lane_ids.has(int(candidate.get("lane_id"))):
			return false
	if params.has("tags_all"):
		if not _has_all_tags(candidate, PackedStringArray(params.get("tags_all", PackedStringArray()))):
			return false
	if params.has("tags_any"):
		var tags_any := PackedStringArray(params.get("tags_any", PackedStringArray()))
		if not tags_any.is_empty() and not _has_any_tag(candidate, tags_any):
			return false
	if params.has("kinds"):
		var kinds := PackedStringArray(params.get("kinds", PackedStringArray()))
		if not kinds.is_empty() and not kinds.has(String(candidate.get("entity_kind"))):
			return false

	var position := _node_ground_position(candidate)
	if params.has("x_min") and position.x < float(params.get("x_min")):
		return false
	if params.has("x_max") and position.x > float(params.get("x_max")):
		return false
	if params.has("center") and params.has("radius"):
		var center := Vector2(params.get("center"))
		if position.distance_to(center) > float(params.get("radius")):
			return false
	if params.has("height_range") and not _height_overlaps(candidate, Vector2(params.get("height_range"))):
		return false

	var filter_value: Variant = params.get("filter", null)
	if typeof(filter_value) == TYPE_CALLABLE:
		var callable := filter_value as Callable
		if callable.is_valid() and not bool(callable.call(candidate)):
			return false
	return true


func _has_any_tag(candidate: Node, tags: PackedStringArray) -> bool:
	var candidate_tags := _candidate_tags(candidate)
	for tag in tags:
		if candidate_tags.has(StringName(tag)):
			return true
	return false


func _has_all_tags(candidate: Node, tags: PackedStringArray) -> bool:
	var candidate_tags := _candidate_tags(candidate)
	for tag in tags:
		if not candidate_tags.has(StringName(tag)):
			return false
	return true


func _candidate_tags(candidate: Node) -> PackedStringArray:
	var tags: Variant = candidate.get("tags")
	if tags is PackedStringArray:
		return PackedStringArray(tags)
	if tags is Array:
		return PackedStringArray(tags)
	return PackedStringArray()


func _height_overlaps(candidate: Node, height_range: Vector2) -> bool:
	var candidate_range := Vector2(0.0, 24.0)
	if candidate.has_method("get_hit_height_range"):
		var value: Variant = candidate.call("get_hit_height_range")
		if value is Vector2:
			candidate_range = value
	return height_range.y >= candidate_range.x and height_range.x <= candidate_range.y


func _node_ground_position(node: Node) -> Vector2:
	if node != null and node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO


func _compare_by_x(a, b) -> bool:
	var a_position := _node_ground_position(a)
	var b_position := _node_ground_position(b)
	if not is_equal_approx(a_position.x, b_position.x):
		return a_position.x < b_position.x
	return _stable_id(a) < _stable_id(b)


func _compare_by_distance(a, b, center: Vector2) -> bool:
	var a_distance := center.distance_squared_to(_node_ground_position(a))
	var b_distance := center.distance_squared_to(_node_ground_position(b))
	if not is_equal_approx(a_distance, b_distance):
		return a_distance < b_distance
	return _stable_id(a) < _stable_id(b)


func _stable_id(entity) -> int:
	if entity != null and entity.has_method("get_entity_id"):
		var entity_id := int(entity.call("get_entity_id"))
		if entity_id >= 0:
			return entity_id
	if entity != null and is_instance_valid(entity):
		return int(_insert_order.get(entity.get_instance_id(), 2147483647))
	return 2147483647
