extends RefCounted
class_name BoardSlot

var lane_id := 0
var slot_index := 0
var placement_tags: PackedStringArray = PackedStringArray(["ground"])
var occupants: Array[Node] = []
var world_position := Vector2.ZERO


func configure(new_lane_id: int, new_slot_index: int, new_world_position: Vector2, new_placement_tags: PackedStringArray) -> void:
	lane_id = new_lane_id
	slot_index = new_slot_index
	world_position = new_world_position
	placement_tags = PackedStringArray(new_placement_tags)


func is_occupied() -> bool:
	_prune_invalid_occupants()
	return not occupants.is_empty()


func add_occupant(entity: Node) -> void:
	_prune_invalid_occupants()
	if entity == null:
		return
	for existing in occupants:
		if existing == entity:
			return
	occupants.append(entity)


func remove_occupant(entity: Node) -> void:
	occupants = occupants.filter(func(existing: Node) -> bool:
		return existing != entity
	)


func occupant_count() -> int:
	_prune_invalid_occupants()
	return occupants.size()


func snapshot() -> Dictionary:
	_prune_invalid_occupants()
	var occupant_ids: Array[int] = []
	for entity in occupants:
		if entity != null and is_instance_valid(entity) and entity.has_method("get_entity_id"):
			occupant_ids.append(int(entity.call("get_entity_id")))
	return {
		"lane_id": lane_id,
		"slot_index": slot_index,
		"placement_tags": PackedStringArray(placement_tags),
		"occupant_ids": occupant_ids,
		"world_position": world_position,
	}


func _prune_invalid_occupants() -> void:
	occupants = occupants.filter(func(entity: Node) -> bool:
		if entity == null or not is_instance_valid(entity):
			return false
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			return false
		return true
	)
