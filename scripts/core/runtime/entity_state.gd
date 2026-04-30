extends RefCounted
class_name EntityState

var entity_id := -1
var entity_kind: StringName = &"entity"
var team: StringName = &"neutral"
var lane_id := -1
var status: StringName = &"idle"
var position := Vector2.ZERO
var combat_active := true
var health := 0
var max_health := 0
var status_effects: Dictionary = {}
var values: Dictionary = {}


func set_value(key: StringName, value: Variant) -> void:
	values[key] = value


func get_value(key: StringName, default_value: Variant = null) -> Variant:
	return values.get(key, default_value)


func set_health(current_health: int, maximum_health: int) -> void:
	health = current_health
	max_health = maximum_health
	values["health"] = health
	values["max_health"] = max_health
	values["health_ratio"] = 0.0 if maximum_health <= 0 else float(current_health) / float(maximum_health)


func snapshot() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_kind": entity_kind,
		"team": team,
		"lane_id": lane_id,
		"status": status,
		"combat_active": combat_active,
		"position": position,
		"health": health,
		"max_health": max_health,
		"status_effects": status_effects.duplicate(true),
		"values": values.duplicate(true),
	}
