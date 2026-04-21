extends Node2D
class_name BaseEntity

const EntityStateRef = preload("res://scripts/core/runtime/entity_state.gd")

@export var entity_kind: StringName = &"entity"
@export var team: StringName = &"neutral"
@export var lane_id := -1
@export var archetype_id: StringName = StringName()
var entity_id := -1
var template_id: StringName = StringName()
var entity_state: Variant = EntityStateRef.new()
var _hit_height_range := Vector2(0.0, 24.0)
var _active_statuses: Dictionary = {}
var _active_marks: Dictionary = {}
@onready var state_component: Variant = get_node_or_null("StateComponent")


func _ready() -> void:
	if entity_id == -1:
		entity_id = GameState.next_entity_id()
	set_notify_transform(true)
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


func sync_runtime_state() -> void:
	_sync_entity_state()


func is_combat_active() -> bool:
	return true


func apply_status(status_id: StringName, duration: float, properties: Dictionary = {}) -> void:
	var expires_at := GameState.current_time + maxf(duration, 0.0)
	_active_statuses[status_id] = {
		"status_id": status_id,
		"expires_at": expires_at,
		"movement_scale": float(properties.get("movement_scale", 1.0)),
		"blocks_attack": bool(properties.get("blocks_attack", false)),
	}
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


func is_attack_blocked() -> bool:
	for status_entry: Dictionary in _active_statuses.values():
		if bool(status_entry.get("blocks_attack", false)):
			return true
	return false


func get_ground_position() -> Vector2:
	return global_position


func get_height() -> float:
	return 0.0


func get_hit_height_range() -> Vector2:
	return _hit_height_range


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


func _physics_process(_delta: float) -> void:
	if state_component != null and state_component.has_method("has_active_states") and bool(state_component.call("has_active_states")):
		state_component.call("physics_process_states")


func _sync_entity_state() -> void:
	entity_state.entity_id = entity_id
	entity_state.template_id = template_id
	entity_state.entity_kind = entity_kind
	entity_state.team = team
	entity_state.lane_id = lane_id
	entity_state.position = global_position
	entity_state.combat_active = is_combat_active()
	entity_state.status_effects = _active_statuses.duplicate(true)
	entity_state.set_value(&"archetype_id", archetype_id)
	entity_state.set_value(&"active_marks", PackedStringArray(_active_marks.keys()))


func _sync_status_state() -> void:
	set_state_value(&"active_statuses", PackedStringArray(_active_statuses.keys()))
	set_state_value(&"effective_movement_scale", get_effective_movement_scale())
	set_state_value(&"attack_blocked", is_attack_blocked())
	_sync_entity_state()


func _sync_mark_state() -> void:
	set_state_value(&"active_marks", PackedStringArray(_active_marks.keys()))
	_sync_entity_state()
