extends CanvasLayer
class_name BattleResultOverlay

var _flow_state: Node = null
var _overlay: ColorRect = null
var _label: Label = null


func setup(flow_state: Node) -> void:
	_flow_state = flow_state
	_build_ui()
	EventBus.subscribe(&"battle.victory", Callable(self, "_on_victory"))
	EventBus.subscribe(&"battle.defeat", Callable(self, "_on_defeat"))


func _build_ui() -> void:
	layer = 100
	_overlay = ColorRect.new()
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_label = Label.new()
	_label.anchors_preset = Control.PRESET_CENTER
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 48)
	_label.visible = false
	add_child(_label)


func _on_victory(_event_data: Variant) -> void:
	_show_result("Victory!", Color("4caf50"))


func _on_defeat(_event_data: Variant) -> void:
	_show_result("Defeat!", Color("e06060"))


func _show_result(text: String, color: Color) -> void:
	_label.text = text + "\nPress R to Restart"
	_label.add_theme_color_override("font_color", color)
	_label.visible = true
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.5, 0.3)
	tween.parallel().tween_property(_label, "scale", Vector2(1.0, 1.0), 0.3).from(Vector2(0.5, 0.5))
