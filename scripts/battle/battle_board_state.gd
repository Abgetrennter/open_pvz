extends Node
class_name BattleBoardState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const BoardSlotRef = preload("res://scripts/battle/board_slot.gd")

var battle: Node = null
var board_slot_count := 5
var board_slot_origin_x := 160.0
var board_slot_spacing := 96.0

var _slots: Dictionary = {}


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	board_slot_count = maxi(1, int(scenario.get("board_slot_count")))
	board_slot_origin_x = float(scenario.get("board_slot_origin_x"))
	board_slot_spacing = maxf(float(scenario.get("board_slot_spacing")), 1.0)
	_slots.clear()
	_rebuild_slots()
	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))


func get_debug_name() -> String:
	return "board_state"


func get_debug_snapshot() -> Dictionary:
	var occupied_slots := 0
	var total_occupants := 0
	for slot_key in _slots.keys():
		var slot = _slots[slot_key]
		if slot == null:
			continue
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
	EventBus.push_event(&"placement.rejected", rejected_event)


func commit_request(request: Resource, entity: Node) -> bool:
	var slot = _resolve_slot(int(request.get("lane_id")), int(request.get("slot_index")))
	if slot == null:
		return false
	slot.add_occupant(entity)
	if entity != null and is_instance_valid(entity) and entity.has_method("set_state_value"):
		entity.call("set_state_value", &"slot_index", int(request.get("slot_index")))
	var accepted_event: Variant = EventDataRef.create(null, entity, null, PackedStringArray(["placement", "accept"]))
	accepted_event.core["request_id"] = StringName(request.get("request_id"))
	accepted_event.core["card_id"] = StringName(request.get("card_id"))
	accepted_event.core["source_id"] = StringName(request.get("source_id"))
	accepted_event.core["entity_template_id"] = StringName(request.get("entity_template_id"))
	accepted_event.core["lane_id"] = int(request.get("lane_id"))
	accepted_event.core["slot_index"] = int(request.get("slot_index"))
	accepted_event.core["placement_tags"] = PackedStringArray(request.get("placement_tags"))
	if entity != null and is_instance_valid(entity) and entity.has_method("get_entity_id"):
		accepted_event.core["entity_id"] = int(entity.call("get_entity_id"))
	EventBus.push_event(&"placement.accepted", accepted_event)
	return true


func get_slot_world_position(lane_id: int, slot_index: int) -> Vector2:
	var slot = _resolve_slot(lane_id, slot_index)
	if slot == null:
		return Vector2.ZERO
	return slot.world_position


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
	if slot.is_occupied():
		return &"slot_occupied"
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
				PackedStringArray(["ground"])
			)
			_slots[_slot_key(lane_id, slot_index)] = slot


func _slot_key(lane_id: int, slot_index: int) -> String:
	return "%d:%d" % [lane_id, slot_index]
