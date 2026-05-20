extends Node2D
class_name BaseEntity

const EntityStateRef = preload("res://scripts/core/runtime/entity_state.gd")
const LivenessEventDataRef = preload("res://scripts/core/runtime/event_data.gd")

const LIVENESS_AXES = [
	&"triggers",
	&"state",
	&"movement",
	&"controllers",
	&"targetable",
	&"damageable",
	&"collidable",
]
const LIVENESS_PRIORITY_BASE := 0
const LIVENESS_PRIORITY_STATUS := 20

@export var entity_kind: StringName = &"entity"
@export var team: StringName = &"neutral"
@export var lane_id := -1
@export var archetype_id: StringName = StringName()
@export var tags: PackedStringArray = PackedStringArray()
@export var initial_exposure_state: StringName = &"ground"
@export var weight_class: StringName = &"normal"
var entity_id := -1
var entity_state: Variant = EntityStateRef.new()
var _hit_height_range := Vector2(0.0, 24.0)
var _height := 0.0
var _height_velocity := 0.0
var _ground_contact := true
var _exposure_state: StringName = &"ground"
var _active_statuses: Dictionary = {}
var _active_marks: Dictionary = {}
var _liveness_overrides: Dictionary = {}
var _liveness_cache: Dictionary = {}
@onready var state_component: Variant = get_node_or_null("StateComponent")


func _ready() -> void:
	if entity_id == -1:
		entity_id = GameState.next_entity_id()
	_exposure_state = initial_exposure_state
	set_notify_transform(true)
	_rebuild_liveness()
	_sync_entity_state()


func get_entity_id() -> int:
	return entity_id


func get_entity_state() -> Dictionary:
	return entity_state.snapshot()


func get_entity_state_ref():
	return entity_state


func assign_lane(new_lane_id: int) -> void:
	lane_id = new_lane_id
	_sync_entity_state()


func set_status(new_status: StringName) -> void:
	entity_state.status = new_status
	_sync_entity_state()


func set_state_value(key: StringName, value: Variant) -> void:
	entity_state.set_value(key, value)


func set_health_state(current_health: int, maximum_health: int) -> void:
	entity_state.set_health(current_health, maximum_health)
	_sync_entity_state()


func set_health_layers_state(layers: Array) -> void:
	entity_state.set_health_layers(layers)
	_sync_entity_state()


func sync_runtime_state() -> void:
	_sync_entity_state()


func apply_status(status_id: StringName, duration: float, properties: Dictionary = {}) -> void:
	var expires_at := GameState.current_time + maxf(duration, 0.0)
	var liveness_overrides := _normalize_liveness_profile(Dictionary(properties.get("liveness_overrides", {})))
	_active_statuses[status_id] = {
		"status_id": status_id,
		"expires_at": expires_at,
		"movement_scale": float(properties.get("movement_scale", 1.0)),
		"liveness_overrides": liveness_overrides.duplicate(true),
	}
	if not liveness_overrides.is_empty():
		push_liveness_override(_status_liveness_source(status_id), liveness_overrides, LIVENESS_PRIORITY_STATUS)
	_sync_status_state()


func apply_mark(mark_id: StringName, duration: float, metadata: Dictionary = {}) -> void:
	var expires_at := GameState.current_time + maxf(duration, 0.0)
	_active_marks[mark_id] = {
		"mark_id": mark_id,
		"expires_at": expires_at,
		"metadata": metadata.duplicate(true),
	}
	_sync_mark_state()


func update_statuses(current_time: float) -> void:
	var expired_statuses := PackedStringArray()
	for status_id in _active_statuses.keys():
		var status_entry: Dictionary = _active_statuses[status_id]
		if current_time + 0.001 < float(status_entry.get("expires_at", 0.0)):
			continue
		expired_statuses.append(String(status_id))
	for status_id in expired_statuses:
		var removed_status := StringName(status_id)
		_active_statuses.erase(removed_status)
		pop_liveness_override(_status_liveness_source(removed_status))
		var removed_event = preload("res://scripts/core/runtime/event_data.gd").create(null, self, null, PackedStringArray(["status", "removed"]))
		removed_event.core["status_id"] = removed_status
		EventBus.push_event(&"entity.status_removed", removed_event)
	_sync_status_state()

	var expired_marks := PackedStringArray()
	for mark_id in _active_marks.keys():
		var mark_entry: Dictionary = _active_marks[mark_id]
		if current_time + 0.001 < float(mark_entry.get("expires_at", 0.0)):
			continue
		expired_marks.append(String(mark_id))
	for mark_id in expired_marks:
		var removed_mark := StringName(mark_id)
		_active_marks.erase(removed_mark)
		var removed_mark_event = preload("res://scripts/core/runtime/event_data.gd").create(null, self, null, PackedStringArray(["mark", "removed"]))
		removed_mark_event.core["mark_id"] = removed_mark
		EventBus.push_event(&"entity.mark_removed", removed_mark_event)
	_sync_mark_state()


func has_status(status_id: StringName) -> bool:
	return _active_statuses.has(status_id)


func has_mark(mark_id: StringName) -> bool:
	return _active_marks.has(mark_id)


func get_effective_movement_scale() -> float:
	var scale := 1.0
	for status_entry: Dictionary in _active_statuses.values():
		scale = minf(scale, float(status_entry.get("movement_scale", 1.0)))
	return scale


func is_liveness_enabled(axis: StringName) -> bool:
	if _liveness_cache.is_empty():
		_rebuild_liveness()
	return bool(_liveness_cache.get(axis, true))


func push_liveness_override(source_id: StringName, profile: Dictionary, priority: int = LIVENESS_PRIORITY_STATUS) -> void:
	if source_id == StringName():
		return
	var previous_profile := _liveness_cache.duplicate(true)
	var normalized_profile := _normalize_liveness_profile(profile)
	if normalized_profile.is_empty():
		_liveness_overrides.erase(source_id)
	else:
		_liveness_overrides[source_id] = {
			"profile": normalized_profile,
			"priority": priority,
		}
	_rebuild_liveness()
	_sync_entity_state()
	_emit_liveness_changed(source_id, previous_profile)


func pop_liveness_override(source_id: StringName) -> void:
	if source_id == StringName():
		return
	var previous_profile := _liveness_cache.duplicate(true)
	if not _liveness_overrides.erase(source_id):
		return
	_rebuild_liveness()
	_sync_entity_state()
	_emit_liveness_changed(source_id, previous_profile)


func is_targetable() -> bool:
	return is_runtime_alive() and is_liveness_enabled(&"targetable")


func is_damageable() -> bool:
	return is_runtime_alive() and is_liveness_enabled(&"damageable")


func is_collidable() -> bool:
	return is_runtime_alive() and is_liveness_enabled(&"collidable")


func is_runtime_alive() -> bool:
	return not is_queued_for_deletion()


func is_counted_for_objectives() -> bool:
	return is_runtime_alive()


func get_ground_position() -> Vector2:
	return global_position


func get_height() -> float:
	return _height


func get_height_velocity() -> float:
	return _height_velocity


func is_ground_contact() -> bool:
	return _ground_contact


func get_exposure_state() -> StringName:
	return _exposure_state


func set_exposure_state(exposure_state: StringName) -> void:
	if exposure_state == StringName():
		exposure_state = &"ground"
	if _exposure_state == exposure_state:
		return
	var previous := _exposure_state
	_exposure_state = exposure_state
	_sync_entity_state()
	_emit_height_state_changed(previous, _exposure_state)


func get_weight_class() -> StringName:
	return StringName(weight_class)


func set_weight_class(new_weight_class: StringName) -> void:
	weight_class = new_weight_class
	_sync_entity_state()


func set_motion_state(height: float, height_velocity: float, ground_contact: bool, exposure_state: StringName, source_id: StringName = StringName(), pause_reason: StringName = StringName()) -> void:
	var previous_exposure := _exposure_state
	_height = maxf(height, 0.0)
	_height_velocity = height_velocity
	_ground_contact = ground_contact
	if exposure_state != StringName():
		_exposure_state = exposure_state
	set_state_value(&"height", _height)
	set_state_value(&"height_velocity", _height_velocity)
	set_state_value(&"ground_contact", _ground_contact)
	set_state_value(&"exposure_state", _exposure_state)
	if source_id != StringName():
		set_state_value(&"movement_source_id", source_id)
	set_state_value(&"movement_pause_reason", pause_reason)
	_sync_entity_state()
	if previous_exposure != _exposure_state:
		_emit_height_state_changed(previous_exposure, _exposure_state)


func set_movement_spec(spec: Dictionary) -> void:
	var movement_component: Variant = get_node_or_null("MovementComponent")
	if movement_component != null and movement_component.has_method("bind_movement_spec"):
		movement_component.call("bind_movement_spec", spec)


func submit_movement_override(command: Dictionary) -> void:
	var movement_component: Variant = get_node_or_null("MovementComponent")
	if movement_component != null and movement_component.has_method("submit_command"):
		var merged := command.duplicate(true)
		merged["command_kind"] = &"override"
		movement_component.call("submit_command", merged)


func get_hit_height_range() -> Vector2:
	return Vector2(_height + _hit_height_range.x, _height + _hit_height_range.y)


func set_hit_height_range(min_height: float, max_height: float) -> void:
	_hit_height_range = Vector2(min_height, maxf(max_height, min_height))
	set_state_value(&"hit_height_range", _hit_height_range)
	_sync_entity_state()


func apply_height_band(height_band: Resource) -> void:
	if height_band == null:
		return
	if height_band.has_method("get") and height_band.get("min_height") != null and height_band.get("max_height") != null:
		set_hit_height_range(float(height_band.get("min_height")), float(height_band.get("max_height")))


func get_debug_name() -> String:
	return "%s#%d" % [String(entity_kind), entity_id]


func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = entity_state.snapshot()
	snapshot["position"] = global_position
	return snapshot


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_sync_entity_state()


func _physics_process(delta: float) -> void:
	if GameState.should_skip_node_process_for_central_step():
		return
	simulation_step(delta)


func simulation_step(_delta: float) -> void:
	if not is_liveness_enabled(&"state"):
		return
	if state_component != null and state_component.has_method("has_active_states") and bool(state_component.call("has_active_states")):
		state_component.call("physics_process_states")


func _sync_entity_state() -> void:
	entity_state.entity_id = entity_id
	entity_state.entity_kind = entity_kind
	entity_state.team = team
	entity_state.lane_id = lane_id
	entity_state.position = global_position
	entity_state.status_effects = _active_statuses.duplicate(true)
	entity_state.set_value(&"archetype_id", archetype_id)
	entity_state.set_value(&"tags", tags)
	entity_state.set_value(&"active_marks", PackedStringArray(_active_marks.keys()))
	entity_state.set_value(&"liveness", _liveness_cache.duplicate(true))
	entity_state.set_value(&"height", _height)
	entity_state.set_value(&"height_velocity", _height_velocity)
	entity_state.set_value(&"ground_contact", _ground_contact)
	entity_state.set_value(&"exposure_state", _exposure_state)
	entity_state.set_value(&"weight_class", StringName(weight_class))
	entity_state.set_value(&"targetable", is_targetable())
	entity_state.set_value(&"damageable", is_damageable())
	entity_state.set_value(&"collidable", is_collidable())
	entity_state.set_value(&"runtime_alive", is_runtime_alive())
	entity_state.set_value(&"counted_for_objectives", is_counted_for_objectives())


func _sync_status_state() -> void:
	set_state_value(&"active_statuses", PackedStringArray(_active_statuses.keys()))
	set_state_value(&"effective_movement_scale", get_effective_movement_scale())
	_sync_entity_state()


func _sync_mark_state() -> void:
	set_state_value(&"active_marks", PackedStringArray(_active_marks.keys()))
	_sync_entity_state()


func _get_base_liveness_profile() -> Dictionary:
	var profile := {}
	for axis in LIVENESS_AXES:
		profile[axis] = true
	if entity_kind == &"field_object":
		profile[&"targetable"] = false
		profile[&"damageable"] = false
		profile[&"collidable"] = false
	return profile


func _rebuild_liveness() -> void:
	var resolved := _get_base_liveness_profile()
	var priorities := {}
	for axis in LIVENESS_AXES:
		priorities[axis] = LIVENESS_PRIORITY_BASE
	for entry in _liveness_overrides.values():
		if not (entry is Dictionary):
			continue
		var profile: Dictionary = Dictionary(entry.get("profile", {}))
		var priority := int(entry.get("priority", LIVENESS_PRIORITY_STATUS))
		for axis_variant in profile.keys():
			var axis := StringName(axis_variant)
			if not resolved.has(axis):
				continue
			var current_priority := int(priorities.get(axis, LIVENESS_PRIORITY_BASE))
			var next_value := bool(profile[axis_variant])
			var current_value := bool(resolved.get(axis, true))
			if priority > current_priority or (priority == current_priority and current_value and not next_value):
				resolved[axis] = next_value
				priorities[axis] = priority
	_liveness_cache = resolved


func _normalize_liveness_profile(profile: Dictionary) -> Dictionary:
	var normalized := {}
	for key: Variant in profile.keys():
		var axis := StringName(key)
		if not LIVENESS_AXES.has(axis):
			continue
		normalized[axis] = bool(profile[key])
	return normalized


func _status_liveness_source(status_id: StringName) -> StringName:
	return StringName("status:%s" % String(status_id))


func _emit_liveness_changed(source_id: StringName, previous_profile: Dictionary) -> void:
	if previous_profile == _liveness_cache:
		return
	var changed_axes := PackedStringArray()
	for axis in LIVENESS_AXES:
		if bool(previous_profile.get(axis, true)) != bool(_liveness_cache.get(axis, true)):
			changed_axes.append(String(axis))
	if changed_axes.is_empty():
		return
	var liveness_event: Variant = LivenessEventDataRef.create(self, self, null, PackedStringArray(["liveness", String(source_id)]))
	liveness_event.core["source_id"] = source_id
	liveness_event.core["changed_axes"] = changed_axes
	for axis in LIVENESS_AXES:
		liveness_event.core[axis] = bool(_liveness_cache.get(axis, true))
	EventBus.push_event(&"entity.liveness_changed", liveness_event)


func _emit_height_state_changed(previous: StringName, current: StringName) -> void:
	var event_data: Variant = LivenessEventDataRef.create(self, self, null, PackedStringArray(["height_state"]))
	event_data.core["previous_exposure_state"] = previous
	event_data.core["exposure_state"] = current
	event_data.core["height"] = _height
	event_data.core["ground_contact"] = _ground_contact
	EventBus.push_event(&"entity.height_state_changed", event_data)
