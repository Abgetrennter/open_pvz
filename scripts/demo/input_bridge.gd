extends Node
class_name InputBridge

var _card_bar: Control = null
var _board_visual: Node2D = null
var _card_state: Node = null
var _flow_state: Node = null
var _selected_card_id: StringName = StringName()


func setup(card_bar: Control, board_visual: Node2D, card_state: Node, flow_state: Node) -> void:
	_card_bar = card_bar
	_board_visual = board_visual
	_card_state = card_state
	_flow_state = flow_state
	_card_bar.card_selected.connect(_on_card_selected)
	_card_bar.card_deselected.connect(_on_card_deselected)
	_board_visual.cell_clicked.connect(_on_cell_clicked)
	EventBus.subscribe(&"placement.accepted", Callable(self, "_on_placement_accepted"))
	EventBus.subscribe(&"card.play_rejected", Callable(self, "_on_card_rejected"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			_deselect()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			return
		if mb.button_index == KEY_ESCAPE:
			return


func _on_card_selected(card_id: StringName) -> void:
	_selected_card_id = card_id


func _on_card_deselected() -> void:
	_selected_card_id = StringName()


func _on_cell_clicked(lane_id: int, slot_index: int) -> void:
	if _selected_card_id == StringName():
		return
	if _is_terminal():
		return
	if _card_state == null or not is_instance_valid(_card_state):
		return
	if not _card_state.has_method("play_card"):
		return
	_card_state.call("play_card", _selected_card_id, lane_id, slot_index)


func _on_placement_accepted(_event_data: Variant) -> void:
	_deselect()


func _on_card_rejected(_event_data: Variant) -> void:
	_deselect()


func _deselect() -> void:
	_selected_card_id = StringName()
	if _card_bar != null and is_instance_valid(_card_bar) and _card_bar.has_method("deselect_card"):
		_card_bar.call("deselect_card")


func _is_terminal() -> bool:
	if _flow_state == null or not is_instance_valid(_flow_state):
		return false
	if _flow_state.has_method("is_terminal"):
		return bool(_flow_state.call("is_terminal"))
	return false
