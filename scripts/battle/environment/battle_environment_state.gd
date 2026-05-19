extends RefCounted
class_name BattleEnvironmentState

var profile: Resource = null
var profile_id: StringName = StringName()
var conditions: PackedStringArray = PackedStringArray()
var natural_sun_enabled := false
var natural_sun_interval_seconds := 8.0
var natural_sun_value := 25
var sun_interval_scale := 1.0
var sun_value_scale := 1.0
var light_level := 1.0
var visibility_range_slots := -1
var fog_enabled := false
var fog_start_column := -1
var fog_max_alpha := 0.0
var fog_alpha_step := 0.12
var fog_clear_default_radius_slots := 2.0
var fog_clear_default_duration := 4.0
var visual_environment_id: StringName = StringName()
var audio_environment_id: StringName = StringName()
var timeline_entries: Array[Dictionary] = []
var active_timeline_index := -1
var lane_ids := PackedInt32Array()
var board_slot_count := 0
var board_metrics: RefCounted = null
var base_fog_alpha_grid: Dictionary = {}
var clear_sources: Dictionary = {}
var final_fog_alpha_grid: Dictionary = {}


func configure_from_profile(environment_profile: Resource) -> void:
	profile = environment_profile
	if environment_profile == null:
		return
	profile_id = StringName(environment_profile.get("profile_id"))
	conditions = _normalize_conditions(environment_profile.get("initial_conditions"))
	natural_sun_enabled = bool(environment_profile.get("natural_sun_enabled"))
	natural_sun_interval_seconds = maxf(float(environment_profile.get("natural_sun_interval_seconds")), 0.1)
	natural_sun_value = maxi(int(environment_profile.get("natural_sun_value")), 1)
	sun_interval_scale = maxf(float(environment_profile.get("sun_interval_scale")), 0.01)
	sun_value_scale = maxf(float(environment_profile.get("sun_value_scale")), 0.0)
	light_level = maxf(float(environment_profile.get("light_level")), 0.0)
	visibility_range_slots = int(environment_profile.get("visibility_range_slots"))
	fog_enabled = bool(environment_profile.get("fog_enabled"))
	fog_start_column = int(environment_profile.get("fog_start_column"))
	fog_max_alpha = clampf(float(environment_profile.get("fog_max_alpha")), 0.0, 1.0)
	fog_alpha_step = clampf(float(environment_profile.get("fog_alpha_step")), 0.0, 1.0)
	fog_clear_default_radius_slots = maxf(float(environment_profile.get("fog_clear_default_radius_slots")), 0.0)
	fog_clear_default_duration = maxf(float(environment_profile.get("fog_clear_default_duration")), 0.0)
	visual_environment_id = StringName(environment_profile.get("visual_environment_id"))
	audio_environment_id = StringName(environment_profile.get("audio_environment_id"))
	timeline_entries = _normalize_timeline(environment_profile.get("timeline"))
	active_timeline_index = -1


func configure_board(new_lane_ids: PackedInt32Array, new_board_slot_count: int, metrics: RefCounted) -> void:
	lane_ids = PackedInt32Array(new_lane_ids)
	board_slot_count = maxi(new_board_slot_count, 0)
	board_metrics = metrics
	rebuild_fog()


func has_condition(condition_id: StringName) -> bool:
	return conditions.has(String(condition_id))


func get_conditions() -> PackedStringArray:
	return PackedStringArray(conditions)


func is_natural_sun_enabled() -> bool:
	return natural_sun_enabled


func get_natural_sun_interval_seconds() -> float:
	return natural_sun_interval_seconds


func get_natural_sun_value() -> int:
	return natural_sun_value


func get_sun_interval_scale() -> float:
	return sun_interval_scale


func get_sun_value_scale() -> float:
	return sun_value_scale


func get_light_level() -> float:
	return light_level


func get_visual_environment_id() -> StringName:
	return visual_environment_id


func is_day() -> bool:
	return has_condition(&"day") or has_condition(&"dawn") or has_condition(&"dusk")


func is_night() -> bool:
	return has_condition(&"night")


func apply_timeline(game_time: float) -> bool:
	var next_index := -1
	for i in range(timeline_entries.size()):
		var entry: Dictionary = timeline_entries[i]
		if game_time + 0.001 >= float(entry.get("at", 0.0)):
			next_index = i
	if next_index < 0 or next_index == active_timeline_index:
		return false
	active_timeline_index = next_index
	_apply_timeline_entry(timeline_entries[next_index])
	rebuild_fog()
	return true


func fog_alpha_at_slot(lane_id: int, slot_index: int) -> float:
	if not fog_enabled:
		return 0.0
	var lane_grid: Variant = final_fog_alpha_grid.get(lane_id, PackedFloat32Array())
	if not (lane_grid is PackedFloat32Array):
		return 0.0
	if slot_index < 0 or slot_index >= PackedFloat32Array(lane_grid).size():
		return 0.0
	return float(PackedFloat32Array(lane_grid)[slot_index])


func is_position_visible(lane_id: int, x: float) -> bool:
	if not fog_enabled:
		return true
	if visibility_range_slots >= 0 and board_metrics != null and board_metrics.has_method("world_to_slot_index"):
		var slot_index := int(board_metrics.call("world_to_slot_index", x))
		return slot_index <= visibility_range_slots or fog_alpha_at_slot(lane_id, slot_index) <= 0.0
	if board_metrics == null or not board_metrics.has_method("world_to_slot_index"):
		return true
	var resolved_slot_index := int(board_metrics.call("world_to_slot_index", x))
	return fog_alpha_at_slot(lane_id, resolved_slot_index) <= 0.0


func add_clear_source(
	source_id: StringName,
	lane_id: int,
	slot_index: int,
	radius_slots: float,
	duration: float,
	clear_mode: StringName,
	game_time: float
) -> bool:
	if source_id == StringName():
		return false
	var expires_at := -1.0
	if duration > 0.0:
		expires_at = game_time + duration
	var next_source := {
		"source_id": source_id,
		"lane_id": lane_id,
		"slot_index": slot_index,
		"radius_slots": maxf(radius_slots, 0.0),
		"clear_mode": clear_mode,
		"expires_at": expires_at,
	}
	if clear_sources.has(source_id) and _clear_source_equals(Dictionary(clear_sources[source_id]), next_source):
		return false
	clear_sources[source_id] = next_source
	rebuild_fog()
	return true


func remove_clear_source(source_id: StringName) -> bool:
	if source_id == StringName():
		return false
	var removed := clear_sources.erase(source_id)
	if removed:
		rebuild_fog()
	return removed


func update_clear_sources(game_time: float) -> bool:
	var expired_sources := PackedStringArray()
	for source_id: Variant in clear_sources.keys():
		var source: Dictionary = clear_sources[source_id]
		var expires_at := float(source.get("expires_at", -1.0))
		if expires_at >= 0.0 and game_time + 0.001 >= expires_at:
			expired_sources.append(String(source_id))
	if expired_sources.is_empty():
		return false
	for source_id in expired_sources:
		clear_sources.erase(StringName(source_id))
	rebuild_fog()
	return true


func rebuild_fog() -> void:
	base_fog_alpha_grid.clear()
	final_fog_alpha_grid.clear()
	if board_slot_count <= 0:
		return
	for lane_id in lane_ids:
		var base_grid := PackedFloat32Array()
		base_grid.resize(board_slot_count)
		for slot_index in range(board_slot_count):
			base_grid[slot_index] = _base_fog_alpha_for_slot(slot_index)
		base_fog_alpha_grid[int(lane_id)] = base_grid
		final_fog_alpha_grid[int(lane_id)] = PackedFloat32Array(base_grid)
	_apply_clear_sources_to_final_grid()


func snapshot() -> Dictionary:
	return {
		"profile_id": profile_id,
		"conditions": PackedStringArray(conditions),
		"natural_sun_enabled": natural_sun_enabled,
		"natural_sun_interval_seconds": natural_sun_interval_seconds,
		"natural_sun_value": natural_sun_value,
		"sun_interval_scale": sun_interval_scale,
		"sun_value_scale": sun_value_scale,
		"light_level": light_level,
		"visibility_range_slots": visibility_range_slots,
		"fog_enabled": fog_enabled,
		"fog_start_column": fog_start_column,
		"fog_max_alpha": fog_max_alpha,
		"fog_alpha_step": fog_alpha_step,
		"active_timeline_index": active_timeline_index,
		"clear_source_count": clear_sources.size(),
		"visual_environment_id": visual_environment_id,
		"audio_environment_id": audio_environment_id,
	}


func fog_snapshot() -> Dictionary:
	return {
		"fog_enabled": fog_enabled,
		"fog_start_column": fog_start_column,
		"fog_max_alpha": fog_max_alpha,
		"fog_alpha_step": fog_alpha_step,
		"lane_ids": PackedInt32Array(lane_ids),
		"board_slot_count": board_slot_count,
		"clear_source_count": clear_sources.size(),
	}


func _normalize_conditions(raw_conditions: Variant) -> PackedStringArray:
	var normalized := PackedStringArray()
	if raw_conditions is PackedStringArray:
		for condition in PackedStringArray(raw_conditions):
			_append_unique_condition(normalized, StringName(condition))
	elif raw_conditions is Array:
		for condition in raw_conditions:
			_append_unique_condition(normalized, StringName(condition))
	return normalized


func _append_unique_condition(target: PackedStringArray, condition_id: StringName) -> void:
	if condition_id == StringName():
		return
	if target.has(String(condition_id)):
		return
	target.append(String(condition_id))


func _normalize_timeline(raw_timeline: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not (raw_timeline is Array):
		return normalized
	for raw_entry in Array(raw_timeline):
		if not (raw_entry is Dictionary):
			continue
		var entry := Dictionary(raw_entry).duplicate(true)
		entry["at"] = maxf(float(entry.get("at", 0.0)), 0.0)
		normalized.append(entry)
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("at", 0.0)) < float(b.get("at", 0.0))
	)
	return normalized


func _apply_timeline_entry(entry: Dictionary) -> void:
	if entry.has("conditions"):
		conditions = _normalize_conditions(entry.get("conditions"))
	if entry.has("natural_sun_enabled"):
		natural_sun_enabled = bool(entry.get("natural_sun_enabled"))
	if entry.has("natural_sun_interval_seconds"):
		natural_sun_interval_seconds = maxf(float(entry.get("natural_sun_interval_seconds")), 0.1)
	if entry.has("natural_sun_value"):
		natural_sun_value = maxi(int(entry.get("natural_sun_value")), 1)
	if entry.has("sun_interval_scale"):
		sun_interval_scale = maxf(float(entry.get("sun_interval_scale")), 0.01)
	if entry.has("sun_value_scale"):
		sun_value_scale = maxf(float(entry.get("sun_value_scale")), 0.0)
	if entry.has("light_level"):
		light_level = maxf(float(entry.get("light_level")), 0.0)
	if entry.has("visibility_range_slots"):
		visibility_range_slots = int(entry.get("visibility_range_slots"))
	if entry.has("fog_enabled"):
		fog_enabled = bool(entry.get("fog_enabled"))
	if entry.has("fog_start_column"):
		fog_start_column = int(entry.get("fog_start_column"))
	if entry.has("fog_max_alpha"):
		fog_max_alpha = clampf(float(entry.get("fog_max_alpha")), 0.0, 1.0)
	if entry.has("fog_alpha_step"):
		fog_alpha_step = clampf(float(entry.get("fog_alpha_step")), 0.0, 1.0)
	if entry.has("visual_environment_id"):
		visual_environment_id = StringName(entry.get("visual_environment_id"))
	if entry.has("audio_environment_id"):
		audio_environment_id = StringName(entry.get("audio_environment_id"))


func _base_fog_alpha_for_slot(slot_index: int) -> float:
	if not fog_enabled or fog_start_column < 0 or slot_index < fog_start_column:
		return 0.0
	var fog_steps := float(slot_index - fog_start_column + 1)
	return clampf(fog_steps * fog_alpha_step, 0.0, fog_max_alpha)


func _apply_clear_sources_to_final_grid() -> void:
	for source_entry: Variant in clear_sources.values():
		if not (source_entry is Dictionary):
			continue
		var source: Dictionary = source_entry
		var clear_mode := StringName(source.get("clear_mode", &"radius"))
		if clear_mode == &"full_board":
			_clear_full_board()
			continue
		var lane_id := int(source.get("lane_id", -1))
		var slot_index := int(source.get("slot_index", -1))
		var radius_slots := int(ceil(float(source.get("radius_slots", 0.0))))
		_clear_radius(lane_id, slot_index, radius_slots)


func _clear_full_board() -> void:
	for lane_id: Variant in final_fog_alpha_grid.keys():
		var lane_grid: PackedFloat32Array = final_fog_alpha_grid[lane_id]
		for slot_index in range(lane_grid.size()):
			lane_grid[slot_index] = 0.0
		final_fog_alpha_grid[lane_id] = lane_grid


func _clear_radius(lane_id: int, slot_index: int, radius_slots: int) -> void:
	if slot_index < 0:
		return
	for target_lane_id: Variant in final_fog_alpha_grid.keys():
		if lane_id >= 0 and int(target_lane_id) != lane_id:
			continue
		var lane_grid: PackedFloat32Array = final_fog_alpha_grid[target_lane_id]
		var min_slot := maxi(slot_index - radius_slots, 0)
		var max_slot := mini(slot_index + radius_slots, lane_grid.size() - 1)
		for target_slot in range(min_slot, max_slot + 1):
			lane_grid[target_slot] = 0.0
		final_fog_alpha_grid[target_lane_id] = lane_grid


func _clear_source_equals(left: Dictionary, right: Dictionary) -> bool:
	return StringName(left.get("source_id", StringName())) == StringName(right.get("source_id", StringName())) \
		and int(left.get("lane_id", -1)) == int(right.get("lane_id", -1)) \
		and int(left.get("slot_index", -1)) == int(right.get("slot_index", -1)) \
		and is_equal_approx(float(left.get("radius_slots", 0.0)), float(right.get("radius_slots", 0.0))) \
		and StringName(left.get("clear_mode", StringName())) == StringName(right.get("clear_mode", StringName())) \
		and is_equal_approx(float(left.get("expires_at", -1.0)), float(right.get("expires_at", -1.0)))
