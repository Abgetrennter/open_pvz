extends Node
class_name BattleCardState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const BattlePlacementRequestRef = preload("res://scripts/battle/placement_request.gd")
const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")
const CombatContentResolverRef = preload("res://scripts/core/runtime/combat_content_resolver.gd")
const EntityTemplateRef = preload("res://scripts/core/defs/entity_template.gd")

var battle: Node = null
var board_slot_count := 5
var hand_order: Array[StringName] = []
var selected_card_id: StringName = StringName()

var _card_defs: Dictionary = {}
var _cooldown_ready_times: Dictionary = {}
var _scheduled_requests: Array[Resource] = []
var _processed_request_indices: Dictionary = {}


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	board_slot_count = int(scenario.get("board_slot_count"))
	if board_slot_count <= 0:
		board_slot_count = 5
	_card_defs.clear()
	_cooldown_ready_times.clear()
	_scheduled_requests.clear()
	_processed_request_indices.clear()
	hand_order.clear()
	selected_card_id = StringName()

	var configured_card_defs: Variant = scenario.get("card_defs")
	if configured_card_defs is Array:
		for card_def in configured_card_defs:
			if card_def == null:
				continue
			var card_id := StringName(card_def.get("card_id"))
			if card_id == StringName():
				continue
			_card_defs[card_id] = card_def
			hand_order.append(card_id)

	var configured_requests: Variant = scenario.get("card_play_requests")
	if configured_requests is Array:
		for request in configured_requests:
			if request is Resource:
				_scheduled_requests.append(request)

	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))


func get_debug_name() -> String:
	return "card_state"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"template_id": StringName(),
		"entity_kind": &"card_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"selected_card_id": selected_card_id,
			"hand_order": PackedStringArray(hand_order),
		},
	}


func _on_game_tick(event_data: Variant) -> void:
	var game_time := float(event_data.core.get("game_time", GameState.current_time))
	for index in range(_scheduled_requests.size()):
		if _processed_request_indices.has(index):
			continue
		var request: Resource = _scheduled_requests[index]
		if request == null:
			_processed_request_indices[index] = true
			continue
		if game_time + 0.001 < float(request.get("at_time")):
			continue
		_processed_request_indices[index] = true
		play_card(StringName(request.get("card_id")), int(request.get("lane_id")), int(request.get("slot_index")), game_time)


func play_card(card_id: StringName, lane_id: int, slot_index: int, game_time: float = -1.0) -> bool:
	if game_time < 0.0:
		game_time = GameState.current_time
	selected_card_id = card_id
	_emit_card_event(&"card.selected", card_id, lane_id, slot_index, {})
	_emit_card_event(&"card.play_requested", card_id, lane_id, slot_index, {})

	var card_def = _card_defs.get(card_id, null)
	if card_def == null:
		_emit_card_rejected(card_id, lane_id, slot_index, &"unknown_card")
		selected_card_id = StringName()
		return false

	if _is_on_cooldown(card_id, game_time):
		_emit_card_rejected(card_id, lane_id, slot_index, &"on_cooldown", {
			"cooldown_remaining": maxf(float(_cooldown_ready_times.get(card_id, 0.0)) - game_time, 0.0),
		})
		selected_card_id = StringName()
		return false

	var placement_request: Resource = _build_placement_request(card_id, lane_id, slot_index, card_def)
	var placement_result: Dictionary = {}
	if battle != null and is_instance_valid(battle):
		placement_result = battle.validate_placement_request(placement_request)
	var placement_reason := StringName(placement_result.get("reason", &"placement_validation_missing"))
	if not bool(placement_result.get("valid", false)):
		if battle != null and is_instance_valid(battle):
			battle.reject_placement_request(placement_request, placement_reason)
		_emit_card_rejected(card_id, lane_id, slot_index, &"invalid_placement", {
			"placement_reason": placement_reason,
		})
		selected_card_id = StringName()
		return false

	var sun_cost := int(card_def.get("sun_cost"))
	var spend_ok := false
	if battle != null and is_instance_valid(battle):
		spend_ok = bool(battle.try_spend_sun(sun_cost, &"card_play", null, {
			"card_id": card_id,
			"lane_id": lane_id,
			"slot_index": slot_index,
		}))
	if not spend_ok:
		_emit_card_rejected(card_id, lane_id, slot_index, &"insufficient_resource")
		selected_card_id = StringName()
		return false

	var spawned_entity: Node = null
	if battle != null and is_instance_valid(battle):
		spawned_entity = battle.spawn_card_actor(card_def, lane_id, slot_index, {
			"card_id": card_id,
			"request_id": StringName(placement_request.get("request_id")),
			"archetype_id": StringName(card_def.get("archetype_id")),
		})
	if spawned_entity == null:
		_emit_card_rejected(card_id, lane_id, slot_index, &"spawn_failed")
		selected_card_id = StringName()
		return false

	if battle == null or not is_instance_valid(battle) or not bool(battle.commit_placement_request(placement_request, spawned_entity)):
		_emit_card_rejected(card_id, lane_id, slot_index, &"placement_commit_failed")
		selected_card_id = StringName()
		return false
	if battle != null and is_instance_valid(battle):
		var slot_type := StringName()
		var slot_tags := PackedStringArray()
		var resolved_slot = placement_result.get("slot", null)
		if resolved_slot != null:
			slot_type = StringName(resolved_slot.slot_type)
			slot_tags = resolved_slot.get_effective_tags()
		battle.emit_entity_spawned(spawned_entity, lane_id, null, {
			"card_id": card_id,
			"request_id": StringName(placement_request.get("request_id")),
			"placement_role": StringName(placement_request.get("placement_role")),
			"spawn_reason": &"card_play",
			"slot_index": slot_index,
			"slot_type": slot_type,
			"slot_tags": slot_tags,
			"archetype_id": StringName(card_def.get("archetype_id")),
			"entity_template_id": StringName(card_def.get("entity_template_id")),
		})
	var cooldown_seconds := float(card_def.get("cooldown_seconds"))
	_cooldown_ready_times[card_id] = game_time + maxf(cooldown_seconds, 0.0)
	_emit_card_event(&"card.cooldown_started", card_id, lane_id, slot_index, {
		"cooldown_seconds": cooldown_seconds,
	})
	selected_card_id = StringName()
	return true


func _is_on_cooldown(card_id: StringName, game_time: float) -> bool:
	return game_time + 0.001 < float(_cooldown_ready_times.get(card_id, 0.0))


func _emit_card_rejected(card_id: StringName, lane_id: int, slot_index: int, reason: StringName, metadata: Dictionary = {}) -> void:
	_emit_card_event(&"card.play_rejected", card_id, lane_id, slot_index, metadata.merged({
		"reason": reason,
	}))


func _emit_card_event(event_name: StringName, card_id: StringName, lane_id: int, slot_index: int, metadata: Dictionary) -> void:
	var card_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["card", String(event_name)]))
	card_event.core["card_id"] = card_id
	card_event.core["lane_id"] = lane_id
	card_event.core["slot_index"] = slot_index
	for key: Variant in metadata.keys():
		card_event.core[key] = metadata[key]
	EventBus.push_event(event_name, card_event)


func _build_placement_request(card_id: StringName, lane_id: int, slot_index: int, card_def) -> Resource:
	var request: Variant = BattlePlacementRequestRef.new()
	request.request_id = StringName("%s_%d_%d_%d" % [String(card_id), lane_id, slot_index, int(round(GameState.current_time * 1000.0))])
	request.card_id = card_id
	request.source_id = &"card_runtime"
	request.archetype_id = StringName(card_def.get("archetype_id"))
	request.entity_template_id = StringName(card_def.get("entity_template_id"))
	request.lane_id = lane_id
	request.slot_index = slot_index
	var placement_tags: Variant = card_def.get("placement_tags")
	request.placement_tags = PackedStringArray() if not (placement_tags is PackedStringArray) else PackedStringArray(placement_tags)
	var entity_template: Resource = _resolve_entity_template_from_card(card_def)
	if entity_template != null:
		request.placement_role = StringName(entity_template.get("placement_role"))
		if request.placement_tags.is_empty():
			request.placement_tags = PackedStringArray(entity_template.get("required_placement_tags"))
	return request


func _resolve_entity_template_from_card(card_def: Resource):
	var archetype_id := StringName(card_def.get("archetype_id"))
	if archetype_id != StringName() and SceneRegistry.has_archetype(archetype_id):
		var archetype: Resource = SceneRegistry.get_archetype(archetype_id)
		if archetype is CombatArchetypeRef:
			return CombatContentResolverRef.resolve_archetype_backend_entity_template(archetype)
	return _resolve_entity_template(StringName(card_def.get("entity_template_id")))


func _resolve_entity_template(entity_template_id: StringName):
	if entity_template_id == StringName():
		return null
	if not SceneRegistry.has_entity_template(entity_template_id):
		return null
	var entity_template: Resource = SceneRegistry.get_entity_template(entity_template_id)
	if entity_template == null or entity_template.get_script() != EntityTemplateRef:
		return null
	return entity_template
