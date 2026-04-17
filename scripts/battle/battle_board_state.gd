extends Node
class_name BattleBoardState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const BoardSlotCatalogRef = preload("res://scripts/battle/board_slot_catalog.gd")
const BoardSlotRef = preload("res://scripts/battle/board_slot.gd")
const BoardSlotConfigRef = preload("res://scripts/battle/board_slot_config.gd")
const EntityTemplateRef = preload("res://scripts/core/defs/entity_template.gd")

var battle: Node = null
var board_slot_count := 5
var board_slot_origin_x := 160.0
var board_slot_spacing := 96.0

var _slots: Dictionary = {}
var _slot_configs: Array[Resource] = []


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	board_slot_count = maxi(1, int(scenario.get("board_slot_count")))
	board_slot_origin_x = float(scenario.get("board_slot_origin_x"))
	board_slot_spacing = maxf(float(scenario.get("board_slot_spacing")), 1.0)
	_slot_configs.clear()
	var configured_slot_configs: Variant = scenario.get("board_slot_configs")
	if configured_slot_configs is Array:
		for slot_config in configured_slot_configs:
			if slot_config is Resource:
				_slot_configs.append(slot_config)
	_slots.clear()
	_rebuild_slots()
	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))


func get_debug_name() -> String:
	return "board_state"


func get_debug_snapshot() -> Dictionary:
	var occupied_slots := 0
	var total_occupants := 0
	var slot_type_counts: Dictionary = {}
	for slot_key in _slots.keys():
		var slot = _slots[slot_key]
		if slot == null:
			continue
		slot_type_counts[String(slot.slot_type)] = int(slot_type_counts.get(String(slot.slot_type), 0)) + 1
		var occupant_count := int(slot.occupant_count())
		total_occupants += occupant_count
		if occupant_count > 0:
			occupied_slots += 1
	return {
		"entity_id": -1,
		"template_id": StringName(),
		"entity_kind": &"board_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"board_slot_count": board_slot_count,
			"occupied_slot_count": occupied_slots,
			"occupant_count": total_occupants,
			"slot_type_counts": slot_type_counts,
		},
	}


func validate_request(request: Resource) -> Dictionary:
	var reason := _placement_reason(request)
	return {
		"valid": reason == StringName(),
		"reason": reason,
		"slot": _resolve_slot(int(request.get("lane_id")), int(request.get("slot_index"))),
	}


func reject_request(request: Resource, reason: StringName) -> void:
	var rejected_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["placement", "reject"]))
	rejected_event.core["request_id"] = StringName(request.get("request_id"))
	rejected_event.core["card_id"] = StringName(request.get("card_id"))
	rejected_event.core["source_id"] = StringName(request.get("source_id"))
	rejected_event.core["entity_template_id"] = StringName(request.get("entity_template_id"))
	rejected_event.core["lane_id"] = int(request.get("lane_id"))
	rejected_event.core["slot_index"] = int(request.get("slot_index"))
	rejected_event.core["reason"] = reason
	var slot = _resolve_slot(int(request.get("lane_id")), int(request.get("slot_index")))
	if slot != null:
		rejected_event.core["slot_type"] = slot.slot_type
		rejected_event.core["slot_tags"] = slot.get_effective_tags()
	rejected_event.core["placement_tags"] = PackedStringArray(request.get("placement_tags"))
	_append_template_constraint_fields(rejected_event.core, request)
	EventBus.push_event(&"placement.rejected", rejected_event)


func commit_request(request: Resource, entity: Node) -> bool:
	var slot = _resolve_slot(int(request.get("lane_id")), int(request.get("slot_index")))
	if slot == null:
		return false
	var placement_role := _resolve_placement_role(request)
	if placement_role == StringName():
		return false
	slot.add_role_occupant(placement_role, entity, _resolve_granted_placement_tags(request))
	if entity != null and is_instance_valid(entity) and entity.has_method("set_state_value"):
		entity.call("set_state_value", &"slot_index", int(request.get("slot_index")))
		entity.call("set_state_value", &"placement_role", placement_role)
	var accepted_event: Variant = EventDataRef.create(null, entity, null, PackedStringArray(["placement", "accept"]))
	accepted_event.core["request_id"] = StringName(request.get("request_id"))
	accepted_event.core["card_id"] = StringName(request.get("card_id"))
	accepted_event.core["source_id"] = StringName(request.get("source_id"))
	accepted_event.core["entity_template_id"] = StringName(request.get("entity_template_id"))
	accepted_event.core["lane_id"] = int(request.get("lane_id"))
	accepted_event.core["slot_index"] = int(request.get("slot_index"))
	accepted_event.core["placement_role"] = placement_role
	accepted_event.core["slot_type"] = slot.slot_type
	accepted_event.core["slot_tags"] = slot.get_effective_tags()
	accepted_event.core["placement_tags"] = PackedStringArray(request.get("placement_tags"))
	_append_template_constraint_fields(accepted_event.core, request)
	if entity != null and is_instance_valid(entity) and entity.has_method("get_entity_id"):
		accepted_event.core["entity_id"] = int(entity.call("get_entity_id"))
	EventBus.push_event(&"placement.accepted", accepted_event)
	return true


func get_slot_world_position(lane_id: int, slot_index: int) -> Vector2:
	var slot = _resolve_slot(lane_id, slot_index)
	if slot == null:
		return Vector2.ZERO
	return slot.world_position


func get_debug_slot_lines(limit: int = 4) -> PackedStringArray:
	var lines := PackedStringArray()
	var slot_keys: Array = _slots.keys()
	slot_keys.sort()
	for slot_key in slot_keys:
		var slot = _slots[slot_key]
		if slot == null:
			continue
		if int(slot.occupant_count()) <= 0:
			continue
		lines.append(_debug_slot_line(slot))
		if lines.size() >= maxi(limit, 1):
			break
	if lines.is_empty():
		lines.append("<empty>")
	return lines


func is_valid_lane(lane_id: int) -> bool:
	return battle != null and is_instance_valid(battle) and battle.has_method("is_valid_lane") and bool(battle.call("is_valid_lane", lane_id))


func _on_game_tick(_event_data: Variant) -> void:
	for slot_key in _slots.keys():
		var slot = _slots[slot_key]
		if slot != null:
			slot.occupant_count()


func _placement_reason(request: Resource) -> StringName:
	if request == null:
		return &"request_missing"
	var lane_id := int(request.get("lane_id"))
	var slot_index := int(request.get("slot_index"))
	if not is_valid_lane(lane_id):
		return &"invalid_lane"
	if slot_index < 0 or slot_index >= board_slot_count:
		return &"invalid_slot"
	var slot = _resolve_slot(lane_id, slot_index)
	if slot == null:
		return &"slot_missing"
	var requested_tags := PackedStringArray(request.get("placement_tags"))
	if requested_tags.is_empty():
		return &"missing_placement_tag"
	var effective_tags: PackedStringArray = slot.get_effective_tags()
	for placement_tag in requested_tags:
		if not effective_tags.has(placement_tag):
			return &"slot_tag_mismatch"
	var template: Resource = _resolve_entity_template(request)
	if template == null:
		return &"template_missing"
	if template.get_script() == EntityTemplateRef and String(template.get("entity_kind")) == "plant":
		var placement_role := _resolve_placement_role(request)
		if placement_role == StringName():
			return &"missing_placement_role"
		var allowed_slot_types := PackedStringArray(template.get("allowed_slot_types"))
		if not allowed_slot_types.is_empty() and not allowed_slot_types.has(slot.slot_type):
			return &"template_slot_type_mismatch"
		var required_placement_tags := PackedStringArray(template.get("required_placement_tags"))
		for required_tag in required_placement_tags:
			if not effective_tags.has(required_tag):
				return &"template_tag_mismatch"
		var required_present_roles := PackedStringArray(template.get("required_present_roles"))
		for required_role in required_present_roles:
			if not slot.is_role_occupied(required_role):
				return &"required_present_role_missing"
		if slot.is_role_occupied(placement_role):
			return &"placement_role_occupied"
		var required_empty_roles := PackedStringArray(template.get("required_empty_roles"))
		for required_empty_role in required_empty_roles:
			if slot.is_role_occupied(required_empty_role):
				return &"required_empty_role_occupied"
	return StringName()


func _resolve_slot(lane_id: int, slot_index: int):
	return _slots.get(_slot_key(lane_id, slot_index), null)


func _rebuild_slots() -> void:
	if battle == null or not is_instance_valid(battle):
		return
	var lane_ids: Array[int] = []
	if battle.has_method("get_lane_ids"):
		for lane_id in battle.call("get_lane_ids"):
			lane_ids.append(int(lane_id))
	if lane_ids.is_empty():
		lane_ids = [0, 1]
	lane_ids.sort()
	for lane_id in lane_ids:
		for slot_index in range(board_slot_count):
			var slot = BoardSlotRef.new()
			slot.configure(
				lane_id,
				slot_index,
				Vector2(board_slot_origin_x + float(slot_index) * board_slot_spacing, float(battle.call("_lane_y", lane_id))),
				&"ground",
				BoardSlotCatalogRef.default_tags_for(&"ground")
			)
			_slots[_slot_key(lane_id, slot_index)] = slot
	_apply_slot_configs()


func _apply_slot_configs() -> void:
	for slot_config in _slot_configs:
		if slot_config == null or slot_config.get_script() != BoardSlotConfigRef:
			continue
		var lane_id := int(slot_config.get("lane_id"))
		var slot_index := int(slot_config.get("slot_index"))
		var slot = _resolve_slot(lane_id, slot_index)
		if slot == null:
			continue
		var placement_tags: Variant = slot_config.get("placement_tags")
		var slot_type := StringName(slot_config.get("slot_type"))
		slot.slot_type = slot_type
		if placement_tags is PackedStringArray and not PackedStringArray(placement_tags).is_empty():
			slot.base_tags = PackedStringArray(placement_tags)
		else:
			slot.base_tags = BoardSlotCatalogRef.default_tags_for(slot_type)


func _resolve_entity_template(request: Resource) -> Resource:
	if request == null:
		return null
	var entity_template_id := StringName(request.get("entity_template_id"))
	if entity_template_id == StringName():
		return null
	if not SceneRegistry.has_entity_template(entity_template_id):
		return null
	return SceneRegistry.get_entity_template(entity_template_id)


func _append_template_constraint_fields(core: Dictionary, request: Resource) -> void:
	var template: Resource = _resolve_entity_template(request)
	if template == null or template.get_script() != EntityTemplateRef:
		return
	core["placement_role"] = _resolve_placement_role(request)
	core["template_allowed_slot_types"] = PackedStringArray(template.get("allowed_slot_types"))
	core["template_required_placement_tags"] = PackedStringArray(template.get("required_placement_tags"))
	core["template_granted_placement_tags"] = PackedStringArray(template.get("granted_placement_tags"))
	core["template_required_present_roles"] = PackedStringArray(template.get("required_present_roles"))
	core["template_required_empty_roles"] = PackedStringArray(template.get("required_empty_roles"))


func _resolve_placement_role(request: Resource) -> StringName:
	if request == null:
		return StringName()
	var explicit_role := StringName(request.get("placement_role"))
	if explicit_role != StringName():
		return explicit_role
	var template: Resource = _resolve_entity_template(request)
	if template == null or template.get_script() != EntityTemplateRef:
		return StringName()
	return StringName(template.get("placement_role"))


func _resolve_granted_placement_tags(request: Resource) -> PackedStringArray:
	var template: Resource = _resolve_entity_template(request)
	if template == null or template.get_script() != EntityTemplateRef:
		return PackedStringArray()
	return PackedStringArray(template.get("granted_placement_tags"))


func _slot_key(lane_id: int, slot_index: int) -> String:
	return "%d:%d" % [lane_id, slot_index]


func _debug_slot_line(slot) -> String:
	var role_keys: Array = slot.role_occupants.keys()
	role_keys.sort()
	var role_parts: PackedStringArray = PackedStringArray()
	for role in role_keys:
		role_parts.append("%s=%s" % [String(role), _debug_slot_occupant_name(slot.role_occupants[role])])
	return "L%d S%d %s %s" % [
		int(slot.lane_id),
		int(slot.slot_index),
		String(slot.slot_type),
		", ".join(role_parts),
	]


func _debug_slot_occupant_name(entity: Node) -> String:
	if entity == null or not is_instance_valid(entity):
		return "<null>"
	if entity.has_method("get_debug_name"):
		return String(entity.call("get_debug_name"))
	return entity.name
