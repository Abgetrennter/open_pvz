extends Control
class_name WaveIndicator

var _total_waves := 0
var _current_wave := 0
var _label: Label = null
var _is_final := false


func setup(scenario: Resource) -> void:
	_total_waves = 0
	_current_wave = 0
	_is_final = false
	var wave_defs: Variant = scenario.get("wave_defs")
	if wave_defs is Array:
		_total_waves = wave_defs.size()
	_build_ui()
	EventBus.subscribe(&"wave.started", Callable(self, "_on_wave_started"))
	EventBus.subscribe(&"wave.completed", Callable(self, "_on_wave_completed"))


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color("ffffff"))
	_label.text = _wave_text()
	add_child(_label)


func _on_wave_started(event_data: Variant) -> void:
	_current_wave += 1
	_is_final = _current_wave >= _total_waves
	_label.text = _wave_text()
	if _is_final:
		_label.add_theme_color_override("font_color", Color("e06060"))
		var tween := create_tween()
		tween.tween_property(_label, "scale", Vector2(1.4, 1.4), 0.15)
		tween.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.2)


func _on_wave_completed(_event_data: Variant) -> void:
	_label.text = _wave_text()


func _wave_text() -> String:
	if _total_waves <= 0:
		return "No Waves"
	if _is_final:
		return "Final Wave! (%d/%d)" % [_current_wave, _total_waves]
	if _current_wave == 0:
		return "Wave -/%d" % _total_waves
	return "Wave %d/%d" % [_current_wave, _total_waves]
