extends Area2D
class_name BoardCellVisual

signal cell_clicked(lane_id: int, slot_index: int)
signal cell_hovered(lane_id: int, slot_index: int)
signal cell_unhovered(lane_id: int, slot_index: int)

var lane_id := 0
var slot_index := 0
var cell_size := Vector2(80.0, 56.0)
var state := &"normal"
var _hover := false
var _flash_timer := 0.0


func configure(p_lane_id: int, p_slot_index: int, p_size: Vector2) -> void:
	lane_id = p_lane_id
	slot_index = p_slot_index
	cell_size = p_size
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = cell_size
	shape.shape = rect
	shape.position = cell_size * 0.5
	add_child(shape)
	mouse_entered.connect(func(): _on_mouse_entered())
	mouse_exited.connect(func(): _on_mouse_exited())


func set_state(new_state: StringName) -> void:
	if state == new_state:
		return
	state = new_state
	queue_redraw()


func flash_invalid() -> void:
	_flash_timer = 0.4
	set_state(&"invalid")
	queue_redraw()


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cell_clicked.emit(lane_id, slot_index)


func _on_mouse_entered() -> void:
	_hover = true
	queue_redraw()
	cell_hovered.emit(lane_id, slot_index)


func _on_mouse_exited() -> void:
	_hover = false
	queue_redraw()
	cell_unhovered.emit(lane_id, slot_index)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = 0.0
			set_state(&"normal")


func _draw() -> void:
	var bg_color: Color
	match state:
		&"occupied":
			bg_color = Color("b4dd7f", 0.5)
		&"invalid":
			bg_color = Color("e06060", 0.6)
		_:
			bg_color = Color("c8e6a0", 0.4) if _hover else Color("c8e6a0", 0.2)
	draw_rect(Rect2(Vector2.ZERO, cell_size), bg_color)
	draw_rect(Rect2(Vector2.ZERO, cell_size), Color("6f9d53", 0.6), false, 1.0)
