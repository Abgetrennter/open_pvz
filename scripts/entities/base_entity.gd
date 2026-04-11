extends Node2D
class_name BaseEntity

const EntityStateRef = preload("res://scripts/core/runtime/entity_state.gd")

@export var entity_kind: StringName = &"entity"
@export var team: StringName = &"neutral"
@export var lane_id := -1
var entity_id := -1
var template_id: StringName = StringName()
var entity_state: Variant = EntityStateRef.new()
var _hit_height_range := Vector2(0.0, 24.0)


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


func _sync_entity_state() -> void:
	entity_state.entity_id = entity_id
	entity_state.template_id = template_id
	entity_state.entity_kind = entity_kind
	entity_state.team = team
	entity_state.lane_id = lane_id
	entity_state.position = global_position
	entity_state.combat_active = is_combat_active()
