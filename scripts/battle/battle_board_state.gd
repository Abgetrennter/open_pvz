extends Node
class_name BattleBoardState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const BoardSlotCatalogRef = preload("res://scripts/battle/board_slot_catalog.gd")
const BoardSlotRef = preload("res://scripts/battle/board_slot.gd")
const BoardSlotConfigRef = preload("res://scripts/battle/board_slot_config.gd")
const BattlefieldPresetRef = preload("res://scripts/battle/battlefield_preset.gd")
const BattlefieldMetricsRef = preload("res://scripts/battle/battlefield_metrics.gd")
const LaneConfigRef = preload("res://scripts/battle/lane_config.gd")
const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")
const CombatContentResolverRef = preload("res://scripts/core/runtime/combat_content_resolver.gd")

const LANE_TYPE_DEFAULTS := {
	&"grass": {
		"slot_type": &"ground",
		"base_tags": ["ground", "supports_primary"],
		"lane_traits": ["terrain.grass", "surface.ground"],
		"visual_theme": &"grass",
	},
	&"pool": {
		"slot_type": &"water",
		"base_tags": ["water"],
		"lane_traits": ["terrain.pool", "surface.water"],
		"visual_theme": &"pool_water",
	},
	&"roof": {
		"slot_type": &"roof",
		"base_tags": ["roof"],
		"lane_traits": ["terrain.roof", "terrain.high_ground", "surface.roof"],
		"visual_theme": &"roof_tile",
	},
	&"dirt": {
		"slot_type": &"dirt",
		"base_tags": [],
		"lane_traits": ["terrain.dirt", "placement.blocked"],
		"visual_theme": &"dirt",
	},
}

var battle: Node = null
var board_slot_count := 5
var board_slot_origin_x := 160.0
var board_slot_spacing := 96.0
var metrics: RefCounted = null

var _slots: Dictionary = {}
var _slot_configs: Array[Resource] = []
var _lane_configs: Dictionary = {}


func _upgrade_replacement_candidate_roles() -> Array[StringName]:
	return [&"upgrade", &"primary", &"support"]


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	var battlefield_preset = _resolve_battlefield_preset(scenario)
	board_slot_count = maxi(1, _resolve_board_slot_count(scenario, battlefield_preset))
	board_slot_origin_x = _resolve_board_slot_origin_x(scenario, battlefield_preset)
	board_slot_spacing = maxf(_resolve_board_slot_spacing(scenario, battlefield_preset), 1.0)
	metrics = BattlefieldMetricsRef.new()
	metrics.configure_from_preset_and_battle(battle, battlefield_preset, board_slot_origin_x, board_slot_spacing)
	_slot_configs.clear()
	_lane_configs.clear()
	if battlefield_preset != null:
		var configured_lane_configs: Variant = battlefield_preset.get("lane_configs")
		if configured_lane_configs is Array:
			for lane_config in configured_lane_configs:
				if lane_config != null and lane_config.get_script() == LaneConfigRef:
					_lane_configs[int(lane_config.get("lane_index"))] = lane_config
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
		"archetype_id": StringName(),
		"entity_kind": &"board_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"board_slot_count": board_slot_count,
			"metrics": {} if metrics == null else metrics.snapshot(),
			"occupied_slot_count": occupied_slots,
			"occupant_count": total_occupants,
			"slot_type_counts": slot_type_counts,
			"lane_config_count": _lane_configs.size(),
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
	rejected_event.core["lane_id"] = int(request.get("lane_id"))
	rejected_event.core["slot_index"] = int(request.get("slot_index"))
	rejected_event.core["reason"] = reason
	var slot = _resolve_slot(int(request.get("lane_id")), int(request.get("slot_index")))
	if slot != null:
		rejected_event.core["slot_type"] = slot.slot_type
		rejected_event.core["slot_tags"] = slot.get_effective_tags()
	rejected_event.core["placement_tags"] = PackedStringArray(request.get("placement_tags"))
	_append_archetype_constraint_fields(rejected_event.core, request)
	EventBus.push_event(&"placement.rejected", rejected_event)


func commit_request(request: Resource, entity: Node) -> bool:
	var slot = _resolve_slot(int(request.get("lane_id")), int(request.get("slot_index")))
	if slot == null:
		return false
	var placement_role := _resolve_placement_role(request)
	if placement_role == StringName():
		return false
	var granted_tags := _resolve_granted_placement_tags(request)
	var replacement_targets := _resolve_upgrade_replacement_targets(slot, request, placement_role)
	if not replacement_targets.is_empty():
		if not _replace_occupants(
			slot,
			replacement_targets,
			entity,
			placement_role,
			granted_tags,
			&"upgrade_replacement",
			StringName(request.get("source_id"))
		):
			return false
	else:
		slot.add_role_occupant(placement_role, entity, granted_tags)
		_bind_replacement_entity_state(slot, entity, placement_role)
	var accepted_event: Variant = EventDataRef.create(null, entity, null, PackedStringArray(["placement", "accept"]))
	accepted_event.core["request_id"] = StringName(request.get("request_id"))
	accepted_event.core["card_id"] = StringName(request.get("card_id"))
	accepted_event.core["source_id"] = StringName(request.get("source_id"))
	accepted_event.core["archetype_id"] = StringName(request.get("archetype_id"))
	accepted_event.core["lane_id"] = int(request.get("lane_id"))
	accepted_event.core["slot_index"] = int(request.get("slot_index"))
	accepted_event.core["placement_role"] = placement_role
	accepted_event.core["slot_type"] = slot.slot_type
	accepted_event.core["slot_tags"] = slot.get_effective_tags()
	accepted_event.core["placement_tags"] = PackedStringArray(request.get("placement_tags"))
	_append_archetype_constraint_fields(accepted_event.core, request)
	_append_role_occupant_fields(accepted_event.core, slot)
	if entity != null and is_instance_valid(entity) and entity.has_method("get_entity_id"):
		accepted_event.core["entity_id"] = int(entity.call("get_entity_id"))
	EventBus.push_event(&"placement.accepted", accepted_event)
	return true


func replace_occupant(
	lane_id: int,
	slot_index: int,
	replaced_role: StringName,
	replacement_entity: Node,
	replacement_role: StringName,
	reason: StringName = &"entity_replacement",
	source_id: StringName = StringName(),
	replacement_granted_tags: PackedStringArray = PackedStringArray()
) -> bool:
	var slot = _resolve_slot(lane_id, slot_index)
	if slot == null or replaced_role == StringName() or replacement_role == StringName():
		return false
	var replaced_entity: Node = slot.get_role_occupant(replaced_role)
	if replaced_entity == null or not is_instance_valid(replaced_entity):
		return false
	return _replace_occupants(
		slot,
		[{
			"role": replaced_role,
			"entity": replaced_entity,
			"granted_tags": slot.get_role_granted_tags(replaced_role),
		}],
		replacement_entity,
		replacement_role,
		replacement_granted_tags,
		reason,
		source_id
	)


func get_slot_world_position(lane_id: int, slot_index: int) -> Vector2:
	var slot = _resolve_slot(lane_id, slot_index)
	if slot == null:
		return Vector2.ZERO
	return slot.world_position


func get_lane_config(lane_id: int) -> Resource:
	return _lane_configs.get(lane_id, null)


func get_lane_traits(lane_id: int) -> PackedStringArray:
	return _resolve_lane_traits(lane_id)


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
	var archetype: Resource = _resolve_archetype(request)
	if archetype == null:
		return &"archetype_missing"
	var placement_constraints := _resolve_placement_constraints(archetype)
	if String(placement_constraints.get("entity_kind")) == "plant":
		var placement_role := _resolve_placement_role(request)
		if placement_role == StringName():
			return &"missing_placement_role"
		var allowed_slot_types: PackedStringArray = placement_constraints.get("allowed_slot_types", PackedStringArray())
		if not allowed_slot_types.is_empty() and not allowed_slot_types.has(slot.slot_type):
			return &"archetype_slot_type_mismatch"
		var required_placement_tags: PackedStringArray = placement_constraints.get("required_placement_tags", PackedStringArray())
		for required_tag in required_placement_tags:
			if not effective_tags.has(required_tag):
				return &"archetype_tag_mismatch"
		var required_present_roles: PackedStringArray = placement_constraints.get("required_present_roles", PackedStringArray())
		for required_role in required_present_roles:
			if not slot.is_role_occupied(required_role):
				return &"required_present_role_missing"
		var required_present_archetypes: PackedStringArray = placement_constraints.get("required_present_archetypes", PackedStringArray())
		var required_present_counts := _count_required_archetypes(required_present_archetypes)
		for required_arch: Variant in required_present_counts.keys():
			if int(slot.count_archetype_occupants(StringName(required_arch))) < int(required_present_counts[required_arch]):
				return &"required_present_archetype_missing"
		var required_adjacent_archetypes: PackedStringArray = placement_constraints.get("required_adjacent_archetypes", PackedStringArray())
		for required_adjacent_arch in required_adjacent_archetypes:
			if not _has_adjacent_archetype(slot, StringName(required_adjacent_arch)):
				return &"required_adjacent_archetype_missing"
		if slot.is_role_occupied(placement_role):
			var can_replace_occupied_role := placement_role == &"upgrade" and _replacement_targets_include_role(
				_resolve_upgrade_replacement_targets(slot, request, placement_role),
				placement_role
			)
			if not can_replace_occupied_role:
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
		var lane_defaults := _resolve_lane_defaults(lane_id)
		var slot_type := StringName(lane_defaults.get("slot_type", &"ground"))
		var base_tags := PackedStringArray(lane_defaults.get("base_tags", PackedStringArray()))
		for slot_index in range(board_slot_count):
			var slot = BoardSlotRef.new()
			slot.configure(
				lane_id,
				slot_index,
				metrics.slot_position(lane_id, slot_index) if metrics != null else Vector2(board_slot_origin_x + float(slot_index) * board_slot_spacing, float(battle.get_lane_y(lane_id))),
				slot_type,
				base_tags
			)
			_slots[_slot_key(lane_id, slot_index)] = slot
	_apply_slot_configs()
	_emit_slots_rebuilt()


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


func _resolve_placement_constraints(archetype: Resource) -> Dictionary:
	if archetype == null or not (archetype is CombatArchetypeRef):
		return {"entity_kind": StringName()}
	var placement_spec := CombatContentResolverRef.resolve_archetype_placement_spec(archetype)
	if not placement_spec.is_empty():
		return {
			"entity_kind": StringName(archetype.entity_kind),
			"allowed_slot_types": PackedStringArray(placement_spec.get("allowed_slot_types", PackedStringArray())),
			"required_placement_tags": PackedStringArray(placement_spec.get("required_placement_tags", PackedStringArray())),
			"granted_placement_tags": PackedStringArray(placement_spec.get("granted_placement_tags", PackedStringArray())),
			"placement_role": StringName(placement_spec.get("placement_role", StringName())),
			"required_present_roles": PackedStringArray(placement_spec.get("required_present_roles", PackedStringArray())),
			"required_present_archetypes": PackedStringArray(placement_spec.get("required_present_archetypes", PackedStringArray())),
			"required_adjacent_archetypes": _resolve_required_adjacent_archetypes(archetype),
			"required_empty_roles": PackedStringArray(placement_spec.get("required_empty_roles", PackedStringArray())),
			"placement_spec_source": StringName(placement_spec.get("source", StringName())),
			"placement_spec_mechanic_id": StringName(placement_spec.get("mechanic_id", StringName())),
			"placement_slot_type_hint": StringName(placement_spec.get("slot_type_hint", StringName())),
		}
	return {
		"entity_kind": StringName(archetype.entity_kind),
		"allowed_slot_types": PackedStringArray(archetype.allowed_slot_types),
		"required_placement_tags": PackedStringArray(archetype.required_placement_tags),
		"granted_placement_tags": PackedStringArray(archetype.granted_placement_tags),
		"placement_role": StringName(archetype.placement_role),
		"required_present_roles": PackedStringArray(archetype.required_present_roles),
		"required_present_archetypes": PackedStringArray(archetype.required_present_archetypes),
		"required_adjacent_archetypes": _resolve_required_adjacent_archetypes(archetype),
		"required_empty_roles": PackedStringArray(archetype.required_empty_roles),
		"placement_spec_source": &"archetype_field",
		"placement_spec_mechanic_id": StringName(),
		"placement_slot_type_hint": StringName(),
	}


func _append_archetype_constraint_fields(core: Dictionary, request: Resource) -> void:
	var archetype: Resource = _resolve_archetype(request)
	var constraints := _resolve_placement_constraints(archetype)
	core["placement_role"] = _resolve_placement_role(request)
	core["archetype_allowed_slot_types"] = constraints.get("allowed_slot_types", PackedStringArray())
	core["archetype_required_placement_tags"] = constraints.get("required_placement_tags", PackedStringArray())
	core["archetype_granted_placement_tags"] = constraints.get("granted_placement_tags", PackedStringArray())
	core["archetype_required_present_roles"] = constraints.get("required_present_roles", PackedStringArray())
	core["archetype_required_present_archetypes"] = constraints.get("required_present_archetypes", PackedStringArray())
	core["archetype_required_adjacent_archetypes"] = constraints.get("required_adjacent_archetypes", PackedStringArray())
	core["archetype_required_empty_roles"] = constraints.get("required_empty_roles", PackedStringArray())
	core["placement_spec_source"] = constraints.get("placement_spec_source", StringName())
	core["placement_spec_mechanic_id"] = constraints.get("placement_spec_mechanic_id", StringName())
	core["placement_slot_type_hint"] = constraints.get("placement_slot_type_hint", StringName())


func _resolve_placement_role(request: Resource) -> StringName:
	if request == null:
		return StringName()
	var explicit_role := StringName(request.get("placement_role"))
	if explicit_role != StringName():
		return explicit_role
	var placement_spec: Variant = request.get("placement_spec")
	if placement_spec is Dictionary and StringName(placement_spec.get("placement_role", StringName())) != StringName():
		return StringName(placement_spec.get("placement_role", StringName()))
	var archetype: Resource = _resolve_archetype(request)
	if archetype != null and StringName(archetype.placement_role) != StringName():
		return StringName(archetype.placement_role)
	return &"primary"


func _resolve_granted_placement_tags(request: Resource) -> PackedStringArray:
	var placement_spec: Variant = request.get("placement_spec")
	if placement_spec is Dictionary and not PackedStringArray(placement_spec.get("granted_placement_tags", PackedStringArray())).is_empty():
		return PackedStringArray(placement_spec.get("granted_placement_tags", PackedStringArray()))
	var archetype: Resource = _resolve_archetype(request)
	if archetype != null and not PackedStringArray(archetype.granted_placement_tags).is_empty():
		return PackedStringArray(archetype.granted_placement_tags)
	return PackedStringArray()


func _count_required_archetypes(required_archetypes: PackedStringArray) -> Dictionary:
	var counts: Dictionary = {}
	for raw_arch in required_archetypes:
		var archetype_id := StringName(raw_arch)
		counts[archetype_id] = int(counts.get(archetype_id, 0)) + 1
	return counts


func _has_adjacent_archetype(slot, archetype_id: StringName) -> bool:
	if slot == null or archetype_id == StringName():
		return false
	for offset in [-1, 1]:
		var adjacent_slot = _resolve_slot(int(slot.lane_id), int(slot.slot_index) + int(offset))
		if adjacent_slot != null and adjacent_slot.is_archetype_occupied(archetype_id):
			return true
	return false


func _resolve_required_adjacent_archetypes(archetype: Resource) -> PackedStringArray:
	if archetype == null or not (archetype is CombatArchetypeRef):
		return PackedStringArray()
	var compiler_hints: Variant = archetype.get("compiler_hints")
	if compiler_hints is Dictionary:
		var configured: Variant = Dictionary(compiler_hints).get("required_adjacent_archetypes", PackedStringArray())
		if configured is PackedStringArray:
			return PackedStringArray(configured)
		if configured is Array:
			return PackedStringArray(configured)
	return PackedStringArray()


func _resolve_upgrade_replacement_targets(slot, request: Resource, placement_role: StringName) -> Array:
	if slot == null or request == null or placement_role != &"upgrade":
		return []
	var archetype: Resource = _resolve_archetype(request)
	var constraints := _resolve_placement_constraints(archetype)
	var required_archetypes := PackedStringArray(constraints.get("required_present_archetypes", PackedStringArray()))
	if required_archetypes.is_empty():
		return []

	var targets: Array = []
	var used_roles: Dictionary = {}
	var used_slot_roles: Dictionary = {}
	for required_arch in required_archetypes:
		var target := _find_upgrade_replacement_target(slot, StringName(required_arch), used_roles)
		if target.is_empty():
			return []
		used_roles[StringName(target.get("role", StringName()))] = true
		used_slot_roles[_target_slot_role_key(target)] = true
		targets.append(target)
	var required_adjacent_archetypes := PackedStringArray(constraints.get("required_adjacent_archetypes", PackedStringArray()))
	for required_adjacent_arch in required_adjacent_archetypes:
		var adjacent_target := _find_adjacent_upgrade_replacement_target(slot, StringName(required_adjacent_arch), used_slot_roles)
		if adjacent_target.is_empty():
			return []
		used_slot_roles[_target_slot_role_key(adjacent_target)] = true
		targets.append(adjacent_target)
	return targets


func _find_upgrade_replacement_target(slot, archetype_id: StringName, used_roles: Dictionary) -> Dictionary:
	if slot == null or archetype_id == StringName():
		return {}
	for role in _upgrade_replacement_candidate_roles():
		if bool(used_roles.get(role, false)):
			continue
		var occupant: Node = slot.get_role_occupant(role)
		if occupant == null or not is_instance_valid(occupant):
			continue
		if not occupant.has_method("get"):
			continue
		if StringName(occupant.get("archetype_id")) != archetype_id:
			continue
		return {
			"slot": slot,
			"role": role,
			"entity": occupant,
			"granted_tags": slot.get_role_granted_tags(role),
		}
	return {}


func _find_adjacent_upgrade_replacement_target(slot, archetype_id: StringName, used_slot_roles: Dictionary) -> Dictionary:
	if slot == null or archetype_id == StringName():
		return {}
	for offset in [1, -1]:
		var adjacent_slot = _resolve_slot(int(slot.lane_id), int(slot.slot_index) + int(offset))
		if adjacent_slot == null:
			continue
		for role in _upgrade_replacement_candidate_roles():
			var slot_role_key := _slot_role_key(adjacent_slot, role)
			if bool(used_slot_roles.get(slot_role_key, false)):
				continue
			var occupant: Node = adjacent_slot.get_role_occupant(role)
			if occupant == null or not is_instance_valid(occupant):
				continue
			if not occupant.has_method("get"):
				continue
			if StringName(occupant.get("archetype_id")) != archetype_id:
				continue
			return {
				"slot": adjacent_slot,
				"role": role,
				"entity": occupant,
				"granted_tags": adjacent_slot.get_role_granted_tags(role),
			}
	return {}


func _target_slot_role_key(target: Dictionary) -> String:
	return _slot_role_key(target.get("slot", null), StringName(target.get("role", StringName())))


func _slot_role_key(slot, role: StringName) -> String:
	if slot == null:
		return "none:%s" % String(role)
	return "%d:%d:%s" % [int(slot.lane_id), int(slot.slot_index), String(role)]


func _replacement_targets_include_role(targets: Array, role: StringName) -> bool:
	for target in targets:
		if target is Dictionary and StringName(Dictionary(target).get("role", StringName())) == role:
			return true
	return false


func _replacement_targets_include_slot_entity(targets: Array, slot, entity: Node) -> bool:
	if slot == null or entity == null or not is_instance_valid(entity):
		return false
	for target in targets:
		if not (target is Dictionary):
			continue
		var target_slot = Dictionary(target).get("slot", slot)
		var target_entity: Node = Dictionary(target).get("entity", null)
		if target_slot == slot and target_entity == entity:
			return true
	return false


func _replace_occupants(
	slot,
	replacement_targets: Array,
	replacement_entity: Node,
	replacement_role: StringName,
	replacement_granted_tags: PackedStringArray,
	reason: StringName,
	source_id: StringName
) -> bool:
	if slot == null or replacement_entity == null or not is_instance_valid(replacement_entity):
		return false
	if replacement_role == StringName() or replacement_targets.is_empty():
		return false

	var inherited_tags := PackedStringArray()
	for target in replacement_targets:
		if not (target is Dictionary):
			return false
		var target_role := StringName(Dictionary(target).get("role", StringName()))
		var target_entity: Node = Dictionary(target).get("entity", null)
		var target_slot = Dictionary(target).get("slot", slot)
		if target_role == StringName() or target_entity == null or not is_instance_valid(target_entity):
			return false
		if target_slot == null:
			return false
		var existing_replacement_role: Node = target_slot.get_role_occupant(replacement_role)
		if (
			existing_replacement_role != null
			and existing_replacement_role != replacement_entity
			and not _replacement_targets_include_slot_entity(replacement_targets, target_slot, existing_replacement_role)
		):
			return false
		for tag in PackedStringArray(Dictionary(target).get("granted_tags", PackedStringArray())):
			if not inherited_tags.has(tag):
				inherited_tags.append(tag)

	for target in replacement_targets:
		var target_slot = Dictionary(target).get("slot", slot)
		target_slot.remove_role_occupant(StringName(Dictionary(target).get("role", StringName())))

	var merged_granted_tags := PackedStringArray(replacement_granted_tags)
	for tag in inherited_tags:
		if not merged_granted_tags.has(tag):
			merged_granted_tags.append(tag)
	slot.add_role_occupant(replacement_role, replacement_entity, merged_granted_tags)
	_bind_replacement_entity_state(slot, replacement_entity, replacement_role)
	for target in replacement_targets:
		var target_slot = Dictionary(target).get("slot", slot)
		if target_slot == slot:
			continue
		target_slot.add_role_occupant(replacement_role, replacement_entity, merged_granted_tags)
		_bind_replacement_footprint_state(replacement_entity, replacement_targets)

	for target in replacement_targets:
		var replaced_entity: Node = Dictionary(target).get("entity", null)
		var replaced_role := StringName(Dictionary(target).get("role", StringName()))
		var target_slot = Dictionary(target).get("slot", slot)
		if replaced_entity == null or not is_instance_valid(replaced_entity):
			continue
		_emit_entity_replaced(target_slot, replaced_entity, replaced_role, replacement_entity, replacement_role, reason, source_id)
		if replaced_entity.has_method("set_status"):
			replaced_entity.call("set_status", reason)
		replaced_entity.queue_free()
	return true


func _bind_replacement_entity_state(slot, entity: Node, placement_role: StringName) -> void:
	if slot == null or entity == null or not is_instance_valid(entity):
		return
	if entity.has_method("set_state_value"):
		entity.call("set_state_value", &"slot_index", int(slot.slot_index))
		entity.call("set_state_value", &"placement_role", placement_role)


func _bind_replacement_footprint_state(entity: Node, replacement_targets: Array) -> void:
	if entity == null or not is_instance_valid(entity) or not entity.has_method("set_state_value"):
		return
	var footprint_slots := PackedStringArray()
	for target in replacement_targets:
		if not (target is Dictionary):
			continue
		var target_slot = Dictionary(target).get("slot", null)
		if target_slot == null:
			continue
		footprint_slots.append("%d:%d" % [int(target_slot.lane_id), int(target_slot.slot_index)])
	entity.call("set_state_value", &"footprint_slots", footprint_slots)


func _emit_entity_replaced(
	slot,
	replaced_entity: Node,
	replaced_role: StringName,
	replacement_entity: Node,
	replacement_role: StringName,
	reason: StringName,
	source_id: StringName
) -> void:
	var replaced_event: Variant = EventDataRef.create(replaced_entity, replacement_entity, null, PackedStringArray(["entity", "replace", String(reason)]))
	replaced_event.core["lane_id"] = int(slot.lane_id)
	replaced_event.core["slot_index"] = int(slot.slot_index)
	replaced_event.core["replaced_entity_id"] = int(replaced_entity.call("get_entity_id")) if replaced_entity.has_method("get_entity_id") else -1
	replaced_event.core["replaced_archetype_id"] = StringName(replaced_entity.get("archetype_id")) if replaced_entity.has_method("get") else StringName()
	replaced_event.core["replaced_role"] = replaced_role
	replaced_event.core["replacement_entity_id"] = int(replacement_entity.call("get_entity_id")) if replacement_entity.has_method("get_entity_id") else -1
	replaced_event.core["replacement_archetype_id"] = StringName(replacement_entity.get("archetype_id")) if replacement_entity.has_method("get") else StringName()
	replaced_event.core["replacement_role"] = replacement_role
	replaced_event.core["reason"] = reason
	replaced_event.core["source_id"] = source_id
	EventBus.push_event(&"entity.replaced", replaced_event)


func _append_role_occupant_fields(core: Dictionary, slot) -> void:
	if slot == null:
		return
	for role_name in [&"primary", &"support", &"cover", &"blocker", &"upgrade"]:
		if not slot.role_occupants.has(role_name):
			continue
		var occupant: Node = slot.role_occupants[role_name]
		if occupant == null or not is_instance_valid(occupant):
			continue
		var prefix := String(role_name)
		core["%s_node" % prefix] = occupant
		if occupant.has_method("get_entity_id"):
			core["%s_id" % prefix] = int(occupant.call("get_entity_id"))
		if occupant.has_method("get"):
			core["%s_archetype_id" % prefix] = StringName(occupant.get("archetype_id"))


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


func _resolve_lane_defaults(lane_id: int) -> Dictionary:
	var lane_config: Resource = _lane_configs.get(lane_id, null)
	if lane_config == null:
		return {
			"slot_type": &"ground",
			"base_tags": BoardSlotCatalogRef.default_tags_for(&"ground"),
			"lane_traits": PackedStringArray(["terrain.grass", "surface.ground"]),
			"visual_theme": &"grass",
		}
	var lane_type := StringName(lane_config.get("lane_type"))
	var defaults: Dictionary = Dictionary(LANE_TYPE_DEFAULTS.get(lane_type, LANE_TYPE_DEFAULTS[&"grass"]))
	var slot_type := StringName(defaults.get("slot_type", &"ground"))
	var base_tags := PackedStringArray(defaults.get("base_tags", []))
	var explicit_slot_type := StringName(lane_config.get("slot_type_override"))
	if explicit_slot_type != StringName():
		slot_type = explicit_slot_type
	if not PackedStringArray(lane_config.get("base_tags_override")).is_empty():
		base_tags = PackedStringArray(lane_config.get("base_tags_override"))
	elif base_tags.is_empty() and slot_type != &"dirt":
		base_tags = BoardSlotCatalogRef.default_tags_for(slot_type)
	return {
		"slot_type": slot_type,
		"base_tags": base_tags,
		"lane_traits": _resolve_lane_traits(lane_id),
		"visual_theme": StringName(lane_config.get("visual_theme")) if StringName(lane_config.get("visual_theme")) != StringName() else StringName(defaults.get("visual_theme", StringName())),
	}


func _resolve_lane_traits(lane_id: int) -> PackedStringArray:
	var lane_config: Resource = _lane_configs.get(lane_id, null)
	if lane_config == null:
		return PackedStringArray(["terrain.grass", "surface.ground"])
	var lane_type := StringName(lane_config.get("lane_type"))
	var defaults: Dictionary = Dictionary(LANE_TYPE_DEFAULTS.get(lane_type, LANE_TYPE_DEFAULTS[&"grass"]))
	var traits := PackedStringArray(defaults.get("lane_traits", []))
	var explicit_traits := PackedStringArray(lane_config.get("lane_traits"))
	if not explicit_traits.is_empty():
		traits = explicit_traits
	return traits


func _emit_slots_rebuilt() -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["board", "terrain"]))
	event_data.core["slot_count"] = _slots.size()
	event_data.core["lane_config_count"] = _lane_configs.size()
	var lane_traits: Dictionary = {}
	var lane_slot_types: Dictionary = {}
	var lane_base_tags: Dictionary = {}
	var lane_y_positions: Dictionary = {}
	for lane_id in battle.get_lane_ids():
		var lane_index := int(lane_id)
		var lane_defaults := _resolve_lane_defaults(lane_index)
		lane_traits[lane_index] = _resolve_lane_traits(lane_index)
		lane_slot_types[lane_index] = StringName(lane_defaults.get("slot_type", &"ground"))
		lane_base_tags[lane_index] = PackedStringArray(lane_defaults.get("base_tags", PackedStringArray()))
		lane_y_positions[lane_index] = float(battle.get_lane_y(lane_index))
		event_data.core["lane_%d_slot_type" % lane_index] = StringName(lane_defaults.get("slot_type", &"ground"))
		event_data.core["lane_%d_base_tags" % lane_index] = PackedStringArray(lane_defaults.get("base_tags", PackedStringArray()))
		event_data.core["lane_%d_traits" % lane_index] = _resolve_lane_traits(lane_index)
		event_data.core["lane_%d_base_tag_text" % lane_index] = ",".join(PackedStringArray(lane_defaults.get("base_tags", PackedStringArray())))
		event_data.core["lane_%d_trait_text" % lane_index] = ",".join(_resolve_lane_traits(lane_index))
		event_data.core["lane_%d_y" % lane_index] = float(battle.get_lane_y(lane_index))
		var first_slot = _resolve_slot(lane_index, 0)
		if first_slot != null:
			event_data.core["lane_%d_slot_0_x" % lane_index] = float(first_slot.world_position.x)
			event_data.core["lane_%d_slot_0_y" % lane_index] = float(first_slot.world_position.y)
		if metrics != null and metrics.has_method("terrain_elevation_at_slot"):
			for slot_index in range(board_slot_count):
				event_data.core["lane_%d_terrain_slot_%d" % [lane_index, slot_index]] = float(metrics.call("terrain_elevation_at_slot", lane_index, slot_index))
	event_data.core["lane_traits"] = lane_traits
	event_data.core["lane_slot_types"] = lane_slot_types
	event_data.core["lane_base_tags"] = lane_base_tags
	event_data.core["lane_y_positions"] = lane_y_positions
	EventBus.push_event(&"board.slots_rebuilt", event_data)
