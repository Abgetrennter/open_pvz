extends Node2D
class_name BaseEntity

@export var entity_kind: StringName = &"entity"
@export var team: StringName = &"neutral"
var entity_id := -1
var template_id: StringName = StringName()
var entity_state: Dictionary = {}


func _ready() -> void:
	if entity_id == -1:
		entity_id = GameState.next_entity_id()


func get_entity_id() -> int:
	return entity_id


func get_entity_state() -> Dictionary:
	return entity_state


func get_debug_name() -> String:
	return "%s#%d" % [String(entity_kind), entity_id]


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_kind": entity_kind,
		"team": team,
		"position": global_position,
		"state": entity_state.duplicate(true),
	}
