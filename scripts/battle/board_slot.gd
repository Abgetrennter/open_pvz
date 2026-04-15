extends RefCounted
class_name BoardSlot

var lane_id := 0
var slot_index := 0
var slot_type: StringName = &"ground"
var base_tags: PackedStringArray = PackedStringArray(["ground", "supports_primary"])
var role_occupants: Dictionary = {}
var role_granted_tags: Dictionary = {}
var world_position := Vector2.ZERO


func configure(
	new_lane_id: int,
	new_slot_index: int,
	new_world_position: Vector2,
	new_slot_type: StringName,
	new_placement_tags: PackedStringArray
) -> void:
	lane_id = new_lane_id
	slot_index = new_slot_index
	world_position = new_world_position
	slot_type = new_slot_type
	base_tags = PackedStringArray(new_placement_tags)


func is_occupied() -> bool:
	_prune_invalid_occupants()
	return not role_occupants.is_empty()


func is_role_occupied(role: StringName) -> bool:
	_prune_invalid_occupants()
	return role_occupants.has(role)


func add_role_occupant(role: StringName, entity: Node, granted_tags: PackedStringArray = PackedStringArray()) -> void:
	_prune_invalid_occupants()
	if entity == null or role == StringName():
		return
	role_occupants[role] = entity
	role_granted_tags[role] = PackedStringArray(granted_tags)


func remove_role_occupant(role: StringName) -> void:
	role_occupants.erase(role)
	role_granted_tags.erase(role)


func get_effective_tags() -> PackedStringArray:
	_prune_invalid_occupants()
	var effective_tags := PackedStringArray(base_tags)
	for role: Variant in role_granted_tags.keys():
		var tags := PackedStringArray(role_granted_tags.get(role, PackedStringArray()))
		for tag in tags:
			if not effective_tags.has(tag):
				effective_tags.append(tag)
	return effective_tags


func occupant_count() -> int:
	_prune_invalid_occupants()
	return role_occupants.size()


func snapshot() -> Dictionary:
	_prune_invalid_occupants()
	var occupant_ids: Dictionary = {}
	for role: Variant in role_occupants.keys():
		var entity: Node = role_occupants[role]
		if entity != null and is_instance_valid(entity) and entity.has_method("get_entity_id"):
			occupant_ids[String(role)] = int(entity.call("get_entity_id"))
	return {
		"lane_id": lane_id,
		"slot_index": slot_index,
		"slot_type": slot_type,
		"base_tags": PackedStringArray(base_tags),
		"effective_tags": get_effective_tags(),
		"occupant_ids": occupant_ids,
		"world_position": world_position,
	}


func _prune_invalid_occupants() -> void:
	var stale_roles: Array[StringName] = []
	for role: Variant in role_occupants.keys():
		var entity: Node = role_occupants[role]
		if entity == null or not is_instance_valid(entity):
			stale_roles.append(StringName(role))
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			stale_roles.append(StringName(role))
	for role in stale_roles:
		remove_role_occupant(role)
