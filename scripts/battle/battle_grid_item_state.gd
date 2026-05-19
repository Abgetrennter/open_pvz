extends Node
class_name BattleGridItemState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const BattleSpawnEntryRef = preload("res://scripts/battle/battle_spawn_entry.gd")
const GridItemRootRef = preload("res://scripts/entities/grid_item_root.gd")

var battle: Node = null
var _entity_factory: RefCounted = EntityFactoryRef.new()
var _grid_items: Array = []


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	_grid_items.clear()


func get_debug_name() -> String:
	return "grid_item_state"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"archetype_id": StringName(),
		"entity_kind": &"grid_item_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"grid_item_count": get_all_grid_items().size(),
		},
	}


func spawn_grid_items(scenario: Resource) -> void:
	if scenario == null:
		return
	var configured_configs: Variant = scenario.get("grid_item_configs")
	if not (configured_configs is Array):
		return
	for config in configured_configs:
		if config == null:
			continue
		var spawn_overrides: Dictionary = {}
		var raw_overrides: Variant = config.get("spawn_overrides")
		if raw_overrides is Dictionary:
			spawn_overrides = Dictionary(raw_overrides).duplicate(true)
		spawn_grid_item_at(
			StringName(config.get("archetype_id")),
			int(config.get("lane_id")),
			int(config.get("slot_index")),
			spawn_overrides,
			bool(config.get("occupies_blocker_role"))
		)


func spawn_grid_item_at(
	archetype_id: StringName,
	lane_id: int,
	slot_index: int,
	spawn_overrides: Dictionary = {},
	occupies_blocker_role: bool = false
) -> Node:
	if battle == null or not is_instance_valid(battle):
		return null
	var board_state: Node = battle.get_board_state() if battle.has_method("get_board_state") else null
	if board_state == null or not board_state.has_method("get_slot"):
		return null
	var slot = board_state.call("get_slot", lane_id, slot_index)
	if slot == null:
		return null
	if slot.get_role_occupant(&"grid_item") != null:
		return null
	if archetype_id == StringName() or not SceneRegistry.has_archetype(archetype_id):
		return null
	var position := Vector2(board_state.call("get_slot_world_position", lane_id, slot_index))
	var entry = BattleSpawnEntryRef.new()
	entry.entity_kind = &"field_object"
	entry.archetype_id = archetype_id
	entry.lane_id = lane_id
	entry.x_position = position.x
	entry.spawn_overrides = spawn_overrides.duplicate(true)
	var spawn_resolution: Dictionary = _entity_factory.instantiate_spawn_entry(entry, position)
	if spawn_resolution.is_empty():
		return null
	var entity: Node = spawn_resolution.get("entity", null)
	if entity == null:
		return null
	if entity.has_method("bind_grid_item_state"):
		entity.call("bind_grid_item_state", self)
	if entity.has_method("bind_grid_slot"):
		entity.call("bind_grid_slot", lane_id, slot_index, occupies_blocker_role)
	if entity.has_method("set_battle_ref"):
		entity.call("set_battle_ref", battle)
	battle.finalize_spawned_entity(entity, lane_id, spawn_resolution.get("hit_height_band", null), spawn_resolution.get("trigger_instances", []), null, {
		"spawn_reason": &"grid_item_spawn",
		"archetype_id": archetype_id,
		"grid_item_archetype_id": archetype_id,
		"slot_index": slot_index,
		"occupies_blocker_role": occupies_blocker_role,
	})
	slot.add_role_occupant(&"grid_item", entity, _grid_item_tags_for(archetype_id))
	if occupies_blocker_role:
		slot.add_role_occupant(&"blocker", entity, PackedStringArray(["placement_blocker"]))
	_grid_items.append(entity)
	_emit_grid_item_spawned(entity, lane_id, slot_index, archetype_id, occupies_blocker_role)
	return entity


func remove_grid_item(lane_id: int, slot_index: int, reason: StringName = &"grid_item_removed") -> bool:
	var entity := get_grid_item_at(lane_id, slot_index)
	if entity == null:
		return false
	return remove_grid_item_for_entity(entity, reason)


func remove_grid_item_for_entity(entity: Node, reason: StringName = &"grid_item_removed") -> bool:
	if entity == null:
		return false
	var lane_id := _resolve_entity_lane_id(entity)
	var slot_index := _resolve_entity_slot_index(entity)
	if lane_id < 0 or slot_index < 0:
		return false
	var board_state: Node = battle.get_board_state() if battle != null and battle.has_method("get_board_state") else null
	var slot = board_state.call("get_slot", lane_id, slot_index) if board_state != null and board_state.has_method("get_slot") else null
	if slot != null:
		if slot.get_role_occupant(&"grid_item") == entity:
			slot.remove_role_occupant(&"grid_item")
		if slot.get_role_occupant(&"blocker") == entity:
			slot.remove_role_occupant(&"blocker")
	_grid_items.erase(entity)
	_emit_grid_item_removed(entity, lane_id, slot_index, reason)
	if is_instance_valid(entity):
		if entity.has_method("set_status"):
			entity.call("set_status", reason)
		entity.queue_free()
	return true


func _resolve_entity_lane_id(entity: Node) -> int:
	if entity == null:
		return -1
	if entity is GridItemRootRef:
		return int((entity as GridItemRootRef).grid_lane_id)
	var lane_value: Variant = entity.get("lane_id") if entity.has_method("get") else null
	return int(lane_value) if lane_value != null else -1


func _resolve_entity_slot_index(entity: Node) -> int:
	if entity == null:
		return -1
	if entity is GridItemRootRef:
		return int((entity as GridItemRootRef).grid_slot_index)
	if entity.has_method("get_entity_state_ref"):
		var entity_state = entity.call("get_entity_state_ref")
		if entity_state != null and entity_state.has_method("get_value"):
			return int(entity_state.call("get_value", &"grid_slot_index", -1))
	return -1


func get_grid_item_at(lane_id: int, slot_index: int) -> Node:
	var board_state: Node = battle.get_board_state() if battle != null and battle.has_method("get_board_state") else null
	if board_state == null or not board_state.has_method("get_slot"):
		return null
	var slot = board_state.call("get_slot", lane_id, slot_index)
	if slot == null:
		return null
	var entity: Node = slot.get_role_occupant(&"grid_item")
	if entity != null and is_instance_valid(entity):
		return entity
	return null


func get_all_grid_items() -> Array:
	var live_items: Array = []
	for item in _grid_items:
		if item != null and is_instance_valid(item):
			live_items.append(item)
	_grid_items = live_items
	return live_items


func _grid_item_tags_for(archetype_id: StringName) -> PackedStringArray:
	var tags := PackedStringArray(["grid_item"])
	if archetype_id != StringName() and SceneRegistry.has_archetype(archetype_id):
		var archetype: Resource = SceneRegistry.get_archetype(archetype_id)
		if archetype != null:
			var granted_tags: Variant = archetype.get("granted_placement_tags")
			if granted_tags is PackedStringArray or granted_tags is Array:
				for tag in PackedStringArray(granted_tags):
					if not tags.has(tag):
						tags.append(tag)
			var archetype_tags: Variant = archetype.get("tags")
			if archetype_tags is PackedStringArray or archetype_tags is Array:
				for tag in PackedStringArray(archetype_tags):
					if String(tag) in ["grid_item", "crater", "grave", "vase"] and not tags.has(tag):
						tags.append(tag)
	return tags


func _emit_grid_item_spawned(entity: Node, lane_id: int, slot_index: int, archetype_id: StringName, occupies_blocker_role: bool) -> void:
	var event_data: Variant = EventDataRef.create(null, entity, null, PackedStringArray(["grid_item", "spawned"]))
	_append_grid_item_core(event_data.core, entity, lane_id, slot_index, archetype_id, occupies_blocker_role)
	EventBus.push_event(&"grid_item.spawned", event_data)


func _emit_grid_item_removed(entity: Node, lane_id: int, slot_index: int, reason: StringName) -> void:
	var archetype_id := StringName(entity.get("archetype_id")) if entity != null and entity.has_method("get") else StringName()
	var occupies_blocker_role := false
	if entity is GridItemRootRef:
		occupies_blocker_role = bool((entity as GridItemRootRef).occupies_blocker_role)
	var event_data: Variant = EventDataRef.create(entity, entity, null, PackedStringArray(["grid_item", "removed", String(reason)]))
	_append_grid_item_core(event_data.core, entity, lane_id, slot_index, archetype_id, occupies_blocker_role)
	event_data.core["reason"] = reason
	EventBus.push_event(&"grid_item.removed", event_data)


func _append_grid_item_core(core: Dictionary, entity: Node, lane_id: int, slot_index: int, archetype_id: StringName, occupies_blocker_role: bool) -> void:
	core["lane_id"] = lane_id
	core["slot_index"] = slot_index
	core["archetype_id"] = archetype_id
	core["grid_item_archetype_id"] = archetype_id
	core["occupies_blocker_role"] = occupies_blocker_role
	if entity != null and entity.has_method("get_entity_id"):
		core["entity_id"] = int(entity.call("get_entity_id"))
