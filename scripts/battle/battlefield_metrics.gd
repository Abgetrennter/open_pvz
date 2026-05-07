extends RefCounted
class_name BattlefieldMetrics

var slot_origin_x := 160.0
var slot_spacing := 96.0
var lane_y_positions: Dictionary = {}
var playable_min_x := 80.0
var playable_max_x := 960.0


func configure_from_battle_context(battle: Node, slot_origin: float, spacing: float) -> void:
	slot_origin_x = slot_origin
	slot_spacing = maxf(spacing, 1.0)
	lane_y_positions.clear()
	if battle != null and is_instance_valid(battle):
		if battle.has_method("get_lane_ids") and battle.has_method("get_lane_y"):
			for lane_id in battle.call("get_lane_ids"):
				lane_y_positions[int(lane_id)] = float(battle.call("get_lane_y", int(lane_id)))
		var playfield_size: Variant = battle.get("playfield_size")
		if playfield_size is Vector2:
			playable_max_x = float(playfield_size.x)


func slot_position(lane_id: int, slot_index: int) -> Vector2:
	return Vector2(slot_origin_x + float(slot_index) * slot_spacing, get_lane_y(lane_id))


func slots_to_world(slot_count: float) -> float:
	return slot_count * slot_spacing


func resolve_slots_distance(params: Dictionary, slots_key: String, legacy_key: String, default_world: float) -> float:
	if params.has(slots_key):
		return slots_to_world(float(params.get(slots_key)))
	return float(params.get(legacy_key, default_world))


func resolve_slots_speed(params: Dictionary, slots_key: String, legacy_key: String, default_world_per_sec: float) -> float:
	if params.has(slots_key):
		return slots_to_world(float(params.get(slots_key)))
	return float(params.get(legacy_key, default_world_per_sec))


func resolve_range(params: Dictionary, slots_key: String, legacy_key: String, default_world: float, origin_x: float = slot_origin_x) -> float:
	var range_mode := StringName(params.get("range_mode", StringName()))
	if range_mode == &"full_lane":
		return maxf(playable_max_x - origin_x, origin_x - playable_min_x)
	return resolve_slots_distance(params, slots_key, legacy_key, default_world)


func world_to_slot_index(x: float) -> int:
	return int(round((x - slot_origin_x) / slot_spacing))


func get_lane_y(lane_id: int) -> float:
	return float(lane_y_positions.get(lane_id, 220.0))


func snapshot() -> Dictionary:
	return {
		"slot_origin_x": slot_origin_x,
		"slot_spacing": slot_spacing,
		"lane_y_positions": lane_y_positions.duplicate(true),
		"playable_min_x": playable_min_x,
		"playable_max_x": playable_max_x,
	}
