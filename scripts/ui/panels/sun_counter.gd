extends "res://scripts/ui/ui_panel_base.gd"
class_name UISunCounter

var _current_sun := 0
var _label: Label = null
var _icon: ColorRect = null


func panel_setup(battle: Node, scenario: Resource) -> void:
	super.panel_setup(battle, scenario)
	_current_sun = _resolve_initial_sun(scenario)
	_build_ui()
	_track_subscribe(&"resource.changed", Callable(self, "_on_resource_changed"))


func panel_teardown() -> void:
	super.panel_teardown()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	_icon = ColorRect.new()
	_icon.custom_minimum_size = Vector2(28.0, 28.0)
	_icon.color = Color("f2d25c")
	layout.add_child(_icon)
	_label = Label.new()
	_label.text = "%d" % _current_sun
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color("ffffff"))
	layout.add_child(_label)


func _resolve_initial_sun(scenario: Resource) -> int:
	if _battle != null and is_instance_valid(_battle) and _battle.has_method("get_current_sun"):
		return int(_battle.call("get_current_sun"))
	if scenario != null:
		return int(scenario.get("initial_sun"))
	return 0


func _on_resource_changed(event_data: Variant) -> void:
	var after := int(event_data.core.get("after", _current_sun))
	if after == _current_sun:
		return
	_current_sun = after
	if _label == null:
		return
	_label.text = "%d" % _current_sun
	var tween := _track_tween(create_tween())
	if tween == null:
		return
	tween.tween_property(_label, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.15)
