extends Node2D
class_name UIBoardOverlay

const BoardCellVisualRef = preload("res://scripts/demo/board_cell_visual.gd")

signal cell_clicked(lane_id: int, slot_index: int)

var _cells: Dictionary = {}
var _board_state: Node = null
var _lane_count := 5
var _slot_count := 9
var _cell_size := Vector2(80.0, 56.0)
var _subscriptions: Array[Dictionary] = []


func setup(board_state: Node, lane_count: int, slot_count: int, cell_size: Vector2) -> void:
	_board_state = board_state
	_lane_count = lane_count
	_slot_count = slot_count
	_cell_size = cell_size
	_rebuild_cells()
	_track_subscribe(&"placement.accepted", Callable(self, "_on_placement_accepted"))
	_track_subscribe(&"placement.rejected", Callable(self, "_on_placement_rejected"))
	_track_subscribe(&"entity.died", Callable(self, "_on_entity_died"))


func teardown() -> void:
	for tracked in _subscriptions:
		var event_name := StringName(tracked.get("event_name", StringName()))
		var callback: Callable = tracked.get("callback", Callable())
		if event_name == StringName() or not callback.is_valid():
			continue
		EventBus.unsubscribe(event_name, callback)
	_subscriptions.clear()


func highlight_slot(lane_id: int, slot_index: int, highlight: bool) -> void:
	var cell = _cells.get(_cell_key(lane_id, slot_index), null)
	if cell != null and is_instance_valid(cell):
		cell.set_state(&"hover_valid" if highlight else &"normal")


func flash_invalid(lane_id: int, slot_index: int) -> void:
	var cell = _cells.get(_cell_key(lane_id, slot_index), null)
	if cell != null and is_instance_valid(cell):
		cell.flash_invalid()


func get_slot_at_world_pos(world_pos: Vector2) -> Dictionary:
	for cell_key in _cells:
		var cell = _cells[cell_key]
		if cell == null or not is_instance_valid(cell):
			continue
		var cell_rect := Rect2(cell.global_position, _cell_size)
		if cell_rect.has_point(world_pos):
			return {"lane_id": cell.lane_id, "slot_index": cell.slot_index}
	return {}


func _track_subscribe(event_name: StringName, callback: Callable) -> void:
	if event_name == StringName() or not callback.is_valid():
		return
	EventBus.subscribe(event_name, callback)
	_subscriptions.append({
		"event_name": event_name,
		"callback": callback,
	})


func _rebuild_cells() -> void:
	for cell_key in _cells:
		var cell = _cells[cell_key]
		if cell != null and is_instance_valid(cell):
			cell.queue_free()
	_cells.clear()
	if _board_state == null or not is_instance_valid(_board_state):
		return
	for lane_id in range(_lane_count):
		for slot_index in range(_slot_count):
			var world_pos := Vector2(_board_state.call("get_slot_world_position", lane_id, slot_index))
			var cell: Variant = BoardCellVisualRef.new()
			cell.name = "Cell_%d_%d" % [lane_id, slot_index]
			cell.configure(lane_id, slot_index, _cell_size)
			cell.position = world_pos - _cell_size * 0.5
			cell.cell_clicked.connect(_on_cell_clicked)
			add_child(cell)
			_cells[_cell_key(lane_id, slot_index)] = cell


func _on_cell_clicked(lane_id: int, slot_index: int) -> void:
	cell_clicked.emit(lane_id, slot_index)


func _on_placement_accepted(event_data: Variant) -> void:
	var lane_id := int(event_data.core.get("lane_id", -1))
	var slot_index := int(event_data.core.get("slot_index", -1))
	if lane_id < 0 or slot_index < 0:
		return
	var cell = _cells.get(_cell_key(lane_id, slot_index), null)
	if cell != null and is_instance_valid(cell):
		cell.set_state(&"occupied")


func _on_placement_rejected(event_data: Variant) -> void:
	var lane_id := int(event_data.core.get("lane_id", -1))
	var slot_index := int(event_data.core.get("slot_index", -1))
	if lane_id < 0 or slot_index < 0:
		return
	flash_invalid(lane_id, slot_index)


func _on_entity_died(event_data: Variant) -> void:
	var target = event_data.core.get("target_node", null)
	if target == null or not is_instance_valid(target):
		return
	if not target.has_method("get_entity_state"):
		return
	var state_data: Dictionary = target.call("get_entity_state")
	var slot_index := int(state_data.get("values", {}).get("slot_index", -1))
	var lane_id_val := int(state_data.get("lane_id", -1))
	if lane_id_val < 0 or slot_index < 0:
		return
	var cell = _cells.get(_cell_key(lane_id_val, slot_index), null)
	if cell != null and is_instance_valid(cell):
		cell.set_state(&"normal")


func _cell_key(lane_id: int, slot_index: int) -> String:
	return "%d:%d" % [lane_id, slot_index]
