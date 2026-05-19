extends RefCounted
class_name BattlefieldMetrics

const LaneConfigRef = preload("res://scripts/battle/lane_config.gd")
const LaneTerrainProfileRef = preload("res://scripts/battle/lane_terrain_profile.gd")

var slot_origin_x := 160.0
var slot_spacing := 96.0
var lane_y_positions: Dictionary = {}
var lane_configs: Dictionary = {}
var playable_min_x := 80.0
var playable_max_x := 960.0


func configure_from_battle_context(battle: Node, slot_origin: float, spacing: float) -> void:
	slot_origin_x = slot_origin
	slot_spacing = maxf(spacing, 1.0)
	lane_y_positions.clear()
	lane_configs.clear()
	if battle != null and is_instance_valid(battle):
		if battle.has_method("get_lane_ids") and battle.has_method("get_lane_y"):
			for lane_id in battle.call("get_lane_ids"):
				lane_y_positions[int(lane_id)] = float(battle.call("get_lane_y", int(lane_id)))
		var playfield_size: Variant = battle.get("playfield_size")
		if playfield_size is Vector2:
			playable_max_x = float(playfield_size.x)


func configure_from_preset_and_battle(battle: Node, preset, slot_origin: float, spacing: float) -> void:
	configure_from_battle_context(battle, slot_origin, spacing)
	_apply_preset_lane_config(preset, battle)


func slot_position(lane_id: int, slot_index: int) -> Vector2:
	return ground_position_for(lane_id, slot_origin_x + float(slot_index) * slot_spacing)


func terrain_elevation_at(lane_id: int, x: float) -> float:
	var lane_config = lane_configs.get(lane_id, null)
	if lane_config == null:
		return 0.0
	var elevation := 0.0
	var profile: Variant = lane_config.get("terrain_profile")
	if profile != null and profile.get_script() == LaneTerrainProfileRef:
		var mode := StringName(profile.get("elevation_mode"))
		match mode:
			&"linear":
				elevation = _sample_linear_profile(profile, x)
			&"stepped":
				elevation = _sample_stepped_profile(profile, x)
			_:
				elevation = float(profile.get("base_elevation"))
	var slot_float := (x - slot_origin_x) / slot_spacing
	return elevation + float(lane_config.get("height_offset")) + slot_float * float(lane_config.get("slope_y_per_slot"))


func terrain_elevation_at_slot(lane_id: int, slot_index: int) -> float:
	return terrain_elevation_at(lane_id, slot_origin_x + float(slot_index) * slot_spacing)


func ground_position_for(lane_id: int, x: float) -> Vector2:
	return Vector2(x, get_lane_y(lane_id) - terrain_visual_y_offset_at(lane_id, x))


func terrain_visual_y_offset_at(lane_id: int, x: float) -> float:
	var terrain_z := terrain_elevation_at(lane_id, x)
	return terrain_z * _terrain_projection_y_scale(lane_id)


func slots_to_world(slot_count: float) -> float:
	return slot_count * slot_spacing


func resolve_slots_distance(params: Dictionary, slots_key: String, default_world: float) -> float:
	if params.has(slots_key):
		return slots_to_world(float(params.get(slots_key)))
	return default_world


func resolve_slots_speed(params: Dictionary, slots_key: String, default_world_per_sec: float) -> float:
	if params.has(slots_key):
		return slots_to_world(float(params.get(slots_key)))
	return default_world_per_sec


func resolve_range(params: Dictionary, slots_key: String, default_world: float, origin_x: float = slot_origin_x) -> float:
	var range_mode := StringName(params.get("range_mode", StringName()))
	if range_mode == &"full_lane":
		return maxf(playable_max_x - origin_x, origin_x - playable_min_x)
	return resolve_slots_distance(params, slots_key, default_world)


func world_to_slot_index(x: float) -> int:
	return int(round((x - slot_origin_x) / slot_spacing))


func get_lane_y(lane_id: int) -> float:
	return float(lane_y_positions.get(lane_id, 220.0))


func snapshot() -> Dictionary:
	return {
		"slot_origin_x": slot_origin_x,
		"slot_spacing": slot_spacing,
		"lane_y_positions": lane_y_positions.duplicate(true),
		"lane_config_count": lane_configs.size(),
		"playable_min_x": playable_min_x,
		"playable_max_x": playable_max_x,
	}


func _apply_preset_lane_config(preset, battle: Node) -> void:
	if preset == null:
		return
	var configured_lane_positions: Variant = preset.get("lane_y_positions")
	if configured_lane_positions is Array and not Array(configured_lane_positions).is_empty():
		lane_y_positions.clear()
		for i in range(Array(configured_lane_positions).size()):
			lane_y_positions[i] = float(Array(configured_lane_positions)[i])
	elif float(preset.get("lane_spacing")) > 0.0:
		lane_y_positions.clear()
		var lane_count := int(preset.get("lane_count"))
		for i in range(maxi(lane_count, 0)):
			lane_y_positions[i] = float(preset.get("lane_origin_y")) + float(i) * float(preset.get("lane_spacing"))
	var configured_lane_configs: Variant = preset.get("lane_configs")
	if configured_lane_configs is Array:
		for lane_config in configured_lane_configs:
			if lane_config != null and lane_config.get_script() == LaneConfigRef:
				lane_configs[int(lane_config.get("lane_index"))] = lane_config
	if battle != null and is_instance_valid(battle) and battle.has_method("get_lane_ids"):
		for lane_id in battle.call("get_lane_ids"):
			if not lane_y_positions.has(int(lane_id)):
				lane_y_positions[int(lane_id)] = 220.0


func _sample_linear_profile(profile: Resource, x: float) -> float:
	var slot_float := (x - slot_origin_x) / slot_spacing
	return float(profile.get("base_elevation")) + slot_float * float(profile.get("elevation_per_slot"))


func _sample_stepped_profile(profile: Resource, x: float) -> float:
	var slot_elevations := PackedFloat32Array(profile.get("slot_elevations"))
	if slot_elevations.is_empty():
		return float(profile.get("base_elevation"))
	var slot_index := int(floor((x - slot_origin_x) / slot_spacing + 0.00001))
	slot_index = clampi(slot_index, 0, slot_elevations.size() - 1)
	return float(profile.get("base_elevation")) + float(slot_elevations[slot_index])


func _terrain_projection_y_scale(lane_id: int) -> float:
	var lane_config = lane_configs.get(lane_id, null)
	if lane_config == null:
		return 1.0
	var profile: Variant = lane_config.get("terrain_profile")
	if profile == null or profile.get_script() != LaneTerrainProfileRef:
		return 1.0
	return maxf(float(profile.get("projection_y_scale")), 0.0)
