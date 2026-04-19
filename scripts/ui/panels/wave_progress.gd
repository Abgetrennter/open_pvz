extends "res://scripts/ui/ui_panel_base.gd"
class_name UIWaveProgress

var _total_waves := 0
var _current_wave := 0
var _label: Label = null
var _is_final := false


func panel_setup(battle: Node, scenario: Resource) -> void:
	super.panel_setup(battle, scenario)
	_total_waves = 0
	_current_wave = 0
	_is_final = false
	var wave_defs: Variant = null if scenario == null else scenario.get("wave_defs")
	if wave_defs is Array:
		_total_waves = wave_defs.size()
	_build_ui()
	_track_subscribe(&"wave.started", Callable(self, "_on_wave_started"))
	_track_subscribe(&"wave.completed", Callable(self, "_on_wave_completed"))


func panel_teardown() -> void:
	super.panel_teardown()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color("ffffff"))
	_label.text = _wave_text()
	add_child(_label)


func _on_wave_started(_event_data: Variant) -> void:
	_current_wave += 1
	_is_final = _current_wave >= _total_waves
	if _label == null:
		return
	_label.text = _wave_text()
	if _is_final:
		_label.add_theme_color_override("font_color", Color("e06060"))
		var tween := _track_tween(create_tween())
		if tween == null:
			return
		tween.tween_property(_label, "scale", Vector2(1.4, 1.4), 0.15)
		tween.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.2)


func _on_wave_completed(_event_data: Variant) -> void:
	if _label != null:
		_label.text = _wave_text()


func _wave_text() -> String:
	if _total_waves <= 0:
		return "No Waves"
	if _is_final:
		return "Final Wave! (%d/%d)" % [_current_wave, _total_waves]
	if _current_wave == 0:
		return "Wave -/%d" % _total_waves
	return "Wave %d/%d" % [_current_wave, _total_waves]
