extends Node
class_name InputRouter

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var _card_bar: Control = null
var _board_visual: Node2D = null
var _card_state: Node = null
var _flow_state: Node = null
var _selected_card_id: StringName = StringName()
var _subscriptions: Array[Dictionary] = []
var _suppress_card_selected_signal := false
var _suppress_card_deselected_signal := false
var _input_profile: Resource = null


func setup(card_bar: Control, board_visual: Node2D, card_state: Node, flow_state: Node, input_profile: Resource = null) -> void:
	_card_bar = card_bar
	_board_visual = board_visual
	_card_state = card_state
	_flow_state = flow_state
	_input_profile = input_profile
	if _card_bar != null and is_instance_valid(_card_bar):
		if _card_bar.has_signal("card_selected"):
			_card_bar.card_selected.connect(_on_card_selected)
		if _card_bar.has_signal("card_deselected"):
			_card_bar.card_deselected.connect(_on_card_deselected)
	if _board_visual != null and is_instance_valid(_board_visual) and _board_visual.has_signal("cell_clicked"):
		_board_visual.cell_clicked.connect(_on_cell_clicked)
	_track_subscribe(&"placement.accepted", Callable(self, "_on_placement_accepted"))
	_track_subscribe(&"card.play_rejected", Callable(self, "_on_card_rejected"))


func teardown() -> void:
	for tracked in _subscriptions:
		var event_name := StringName(tracked.get("event_name", StringName()))
		var callback: Callable = tracked.get("callback", Callable())
		if event_name == StringName() or not callback.is_valid():
			continue
		EventBus.unsubscribe(event_name, callback)
	_subscriptions.clear()
	_selected_card_id = StringName()
	_suppress_card_selected_signal = false
	_suppress_card_deselected_signal = false
	_card_bar = null
	_board_visual = null
	_card_state = null
	_flow_state = null
	_input_profile = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == KEY_ESCAPE:
			request_cancel()
			return
		var card_index := _card_index_for_key(key_event.keycode)
		if card_index >= 0:
			_select_card_by_index(card_index)
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			request_cancel()


func request_cancel() -> void:
	if _input_profile != null and not _input_profile.get("enable_cancel"):
		return
	_deselect(&"cancel")


func request_card_select(card_id: StringName, source: StringName = &"signal") -> void:
	if card_id == StringName():
		return
	if _is_terminal():
		return
	if _input_profile != null and not _input_profile.get("enable_card_select"):
		return
	if _selected_card_id == card_id:
		if source != &"signal":
			request_cancel()
		return
	_selected_card_id = card_id
	if source != &"signal" and _card_bar != null and is_instance_valid(_card_bar) and _card_bar.has_method("select_card"):
		_suppress_card_selected_signal = true
		_card_bar.call("select_card", card_id)
		_suppress_card_selected_signal = false
	_emit_input_action(&"input.action.card_selected", {
		"card_id": card_id,
		"source": source,
	})


func request_cell_click(lane_id: int, slot_index: int) -> void:
	_emit_input_action(&"input.action.cell_clicked", {
		"lane_id": lane_id,
		"slot_index": slot_index,
		"card_id": _selected_card_id,
	})
	if _selected_card_id == StringName():
		if _input_profile == null or _input_profile.get("enable_slot_click"):
			return
		return
	if _is_terminal():
		return
	if _input_profile != null:
		if not _input_profile.get("enable_card_place"):
			return
	if _card_state == null or not is_instance_valid(_card_state):
		return
	if not _card_state.has_method("play_card"):
		return
	_card_state.call("play_card", _selected_card_id, lane_id, slot_index)


func request_entity_click(entity_id: StringName, metadata: Dictionary = {}) -> void:
	if _input_profile != null and not _input_profile.get("enable_entity_click"):
		return
	_emit_input_action(&"input.action.entity_clicked", {
		"entity_id": entity_id,
	})


func request_slot_drag(from_lane: int, from_slot: int, to_lane: int, to_slot: int, metadata: Dictionary = {}) -> void:
	if _input_profile != null and not _input_profile.get("enable_slot_drag"):
		return
	_emit_input_action(&"input.action.slot_drag", {
		"from_lane": from_lane,
		"from_slot": from_slot,
		"to_lane": to_lane,
		"to_slot": to_slot,
	})


func _track_subscribe(event_name: StringName, callback: Callable) -> void:
	if event_name == StringName() or not callback.is_valid():
		return
	EventBus.subscribe(event_name, callback)
	_subscriptions.append({
		"event_name": event_name,
		"callback": callback,
	})


func _on_card_selected(card_id: StringName) -> void:
	if _suppress_card_selected_signal:
		_selected_card_id = card_id
		return
	request_card_select(card_id)


func _on_card_deselected() -> void:
	_selected_card_id = StringName()
	if _suppress_card_deselected_signal:
		return
	_emit_input_action(&"input.action.card_deselected", {
		"reason": &"signal",
	})


func _on_cell_clicked(lane_id: int, slot_index: int) -> void:
	request_cell_click(lane_id, slot_index)


func _on_placement_accepted(_event_data: Variant) -> void:
	_deselect(&"placed")


func _on_card_rejected(_event_data: Variant) -> void:
	_deselect(&"rejected")


func _deselect(reason: StringName) -> void:
	if _selected_card_id == StringName():
		return
	_selected_card_id = StringName()
	if _card_bar != null and is_instance_valid(_card_bar) and _card_bar.has_method("deselect_card"):
		_suppress_card_deselected_signal = true
		_card_bar.call("deselect_card")
		_suppress_card_deselected_signal = false
	_emit_input_action(&"input.action.card_deselected", {
		"reason": reason,
	})


func _is_terminal() -> bool:
	if _flow_state == null or not is_instance_valid(_flow_state):
		return false
	if _flow_state.has_method("is_terminal"):
		return bool(_flow_state.call("is_terminal"))
	return false


func _card_index_for_key(keycode: Key) -> int:
	match keycode:
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		KEY_7:
			return 6
		KEY_8:
			return 7
		KEY_9:
			return 8
		KEY_0:
			return 9
		_:
			return -1


func _select_card_by_index(card_index: int) -> void:
	if card_index < 0:
		return
	if _card_bar == null or not is_instance_valid(_card_bar):
		return
	if not _card_bar.has_method("get_card_ids"):
		return
	var card_ids: Array = _card_bar.call("get_card_ids")
	if card_index >= card_ids.size():
		return
	request_card_select(StringName(card_ids[card_index]), &"keyboard")


func _emit_input_action(event_name: StringName, metadata: Dictionary) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["input"]))
	for key: Variant in metadata.keys():
		event_data.core[key] = metadata[key]
	EventBus.push_event(event_name, event_data)
