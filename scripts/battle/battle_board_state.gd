extends Node
class_name BattleBoardState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const BoardSlotCatalogRef = preload("res://scripts/battle/board_slot_catalog.gd")
const BoardSlotRef = preload("res://scripts/battle/board_slot.gd")
const BoardSlotConfigRef = preload("res://scripts/battle/board_slot_config.gd")
const BattlefieldPresetRef = preload("res://scripts/battle/battlefield_preset.gd")
const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")
const CombatContentResolverRef = preload("res://scripts/core/runtime/combat_content_resolver.gd")
const EntityTemplateRef = preload("res://scripts/core/defs/entity_template.gd")

var battle: Node = null
var board_slot_count := 5
var board_slot_origin_x := 160.0
var board_slot_spacing := 96.0

var _slots: Dictionary = {}
var _slot_configs: Array[Resource] = []


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	var battlefield_preset = _resolve_battlefield_preset(scenario)
	board_slot_count = maxi(1, _resolve_board_slot_count(scenario, battlefield_preset))
	board_slot_origin_x = _resolve_board_slot_origin_x(scenario, battlefield_preset)
	board_slot_spacing = maxf(_resolve_board_slot_spacing(scenario, battlefield_preset), 1.0)
	_slot_configs.clear()
	if battlefield_preset != null:
		for slot_config in battlefield_preset.board_slot_configs:
			if slot_config is Resource:
				_slot_configs.append(slot_config)
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
	rejected_event.core["archetype_id"] = StringName(request.get("archetype_id"))
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
	accepted_event.core["archetype_id"] = StringName(request.get("archetype_id"))
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
	return battle != null and is_instance_valid(battle) and bool(battle.is_valid_lane(lane_id))


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
	var placement_constraints := _resolve_placement_constraints(request, template)
	if String(placement_constraints.get("entity_kind")) == "plant":
		var placement_role := _resolve_placement_role(request)
		if placement_role == StringName():
			return &"missing_placement_role"
		var allowed_slot_types: PackedStringArray = placement_constraints.get("allowed_slot_types", PackedStringArray())
		if not allowed_slot_types.is_empty() and not allowed_slot_types.has(slot.slot_type):
			return &"template_slot_type_mismatch"
		var required_placement_tags: PackedStringArray = placement_constraints.get("required_placement_tags", PackedStringArray())
		for required_tag in required_placement_tags:
			if not effective_tags.has(required_tag):
				return &"template_tag_mismatch"
		var required_present_roles: PackedStringArray = placement_constraints.get("required_present_roles", PackedStringArray())
		for required_role in required_present_roles:
			if not slot.is_role_occupied(required_role):
				return &"required_present_role_missing"
		if slot.is_role_occupied(placement_role):
			return &"placement_role_occupied"
		var required_empty_roles: PackedStringArray = placement_constraints.get("required_empty_roles", PackedStringArray())
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
	for lane_id in battle.get_lane_ids():
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
				Vector2(board_slot_origin_x + float(slot_index) * board_slot_spacing, float(battle.get_lane_y(lane_id))),
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
	var archetype_id := StringName(request.get("archetype_id"))
	if archetype_id != StringName():
		if not SceneRegistry.has_archetype(archetype_id):
			return null
		var archetype: Resource = SceneRegistry.get_archetype(archetype_id)
		if archetype is CombatArchetypeRef:
			return CombatContentResolverRef.resolve_archetype_backend_entity_template(archetype)
	var entity_template_id := StringName(request.get("entity_template_id"))
	if entity_template_id == StringName():
		return null
	if not SceneRegistry.has_entity_template(entity_template_id):
		return null
	return SceneRegistry.get_entity_template(entity_template_id)


func _resolve_archetype(request: Resource) -> Resource:
	var archetype_id := StringName(request.get("archetype_id"))
	if archetype_id == StringName():
		return null
	if not SceneRegistry.has_archetype(archetype_id):
		return null
	var archetype: Resource = SceneRegistry.get_archetype(archetype_id)
	if archetype is CombatArchetypeRef:
		return archetype
	return null


func _resolve_placement_constraints(request: Resource, template: Resource) -> Dictionary:
	var template_constraints := _extract_template_placement(template)
	var archetype: Resource = _resolve_archetype(request)
	if archetype == null:
		return template_constraints
	var has_explicit_placement := not PackedStringArray(archetype.allowed_slot_types).is_empty() or PackedStringArray(archetype.required_placement_tags) != PackedStringArray(["supports_primary"]) or not PackedStringArray(archetype.granted_placement_tags).is_empty()
	if has_explicit_placement:
		return {
			"entity_kind": StringName(archetype.entity_kind) if StringName(archetype.entity_kind) != StringName() else template_constraints.get("entity_kind", StringName()),
			"allowed_slot_types": PackedStringArray(archetype.allowed_slot_types),
			"required_placement_tags": PackedStringArray(archetype.required_placement_tags),
			"granted_placement_tags": PackedStringArray(archetype.granted_placement_tags),
			"placement_role": StringName(archetype.placement_role),
			"required_present_roles": PackedStringArray(archetype.required_present_roles),
			"required_empty_roles": PackedStringArray(archetype.required_empty_roles),
		}
	return template_constraints


func _extract_template_placement(template: Resource) -> Dictionary:
	if template != null and template.get_script() == EntityTemplateRef:
		return {
			"entity_kind": StringName(template.get("entity_kind")),
			"allowed_slot_types": PackedStringArray(template.get("allowed_slot_types")),
			"required_placement_tags": PackedStringArray(template.get("required_placement_tags")),
			"granted_placement_tags": PackedStringArray(template.get("granted_placement_tags")),
			"placement_role": StringName(template.get("placement_role")),
			"required_present_roles": PackedStringArray(template.get("required_present_roles")),
			"required_empty_roles": PackedStringArray(template.get("required_empty_roles")),
		}
	return {"entity_kind": StringName()}


func _append_template_constraint_fields(core: Dictionary, request: Resource) -> void:
	var template: Resource = _resolve_entity_template(request)
	var constraints := _resolve_placement_constraints(request, template)
	core["placement_role"] = _resolve_placement_role(request)
	core["template_allowed_slot_types"] = constraints.get("allowed_slot_types", PackedStringArray())
	core["template_required_placement_tags"] = constraints.get("required_placement_tags", PackedStringArray())
	core["template_granted_placement_tags"] = constraints.get("granted_placement_tags", PackedStringArray())
	core["template_required_present_roles"] = constraints.get("required_present_roles", PackedStringArray())
	core["template_required_empty_roles"] = constraints.get("required_empty_roles", PackedStringArray())


func _resolve_placement_role(request: Resource) -> StringName:
	if request == null:
		return StringName()
	var explicit_role := StringName(request.get("placement_role"))
	if explicit_role != StringName():
		return explicit_role
	var archetype: Resource = _resolve_archetype(request)
	if archetype != null and StringName(archetype.placement_role) != &"primary":
		return StringName(archetype.placement_role)
	var template: Resource = _resolve_entity_template(request)
	if template != null and template.get_script() == EntityTemplateRef:
		return StringName(template.get("placement_role"))
	return &"primary"


func _resolve_granted_placement_tags(request: Resource) -> PackedStringArray:
	var archetype: Resource = _resolve_archetype(request)
	if archetype != null and not PackedStringArray(archetype.granted_placement_tags).is_empty():
		return PackedStringArray(archetype.granted_placement_tags)
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


func _resolve_battlefield_preset(scenario: Resource):
	if scenario == null:
		return null
	var preset: Variant = scenario.get("battlefield_preset")
	if preset != null and preset.get_script() == BattlefieldPresetRef:
		return preset
	return null


func _resolve_board_slot_count(scenario: Resource, battlefield_preset) -> int:
	if battlefield_preset != null and int(battlefield_preset.board_slot_count) > 0:
		return int(battlefield_preset.board_slot_count)
	return int(scenario.get("board_slot_count"))


func _resolve_board_slot_origin_x(scenario: Resource, battlefield_preset) -> float:
	if battlefield_preset != null:
		return float(battlefield_preset.board_slot_origin_x)
	return float(scenario.get("board_slot_origin_x"))


func _resolve_board_slot_spacing(scenario: Resource, battlefield_preset) -> float:
	if battlefield_preset != null:
		return float(battlefield_preset.board_slot_spacing)
	return float(scenario.get("board_slot_spacing"))
