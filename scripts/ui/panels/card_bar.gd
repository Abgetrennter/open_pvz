extends "res://scripts/ui/ui_panel_base.gd"
class_name UICardBar

signal card_selected(card_id: StringName)
signal card_deselected

var _card_defs: Array = []
var _selected_card_id: StringName = StringName()
var _card_slots: Array[Control] = []
var _current_sun := 0
var _cooldown_ready_times: Dictionary = {}


func panel_setup(battle: Node, scenario: Resource) -> void:
	super.panel_setup(battle, scenario)
	_card_defs.clear()
	_card_slots.clear()
	_selected_card_id = StringName()
	_cooldown_ready_times.clear()
	_current_sun = _resolve_initial_sun(battle, scenario)
	var configured: Variant = null if scenario == null else scenario.get("card_defs")
	if configured is Array:
		_card_defs = configured
	_rebuild_ui()
	_track_subscribe(&"resource.changed", Callable(self, "_on_resource_changed"))
	_track_subscribe(&"card.cooldown_started", Callable(self, "_on_cooldown_started"))
	_track_subscribe(&"card.play_rejected", Callable(self, "_on_card_play_rejected"))
	_track_subscribe(&"card.play_requested", Callable(self, "_on_card_play_requested"))


func panel_teardown() -> void:
	super.panel_teardown()


func get_selected_card_id() -> StringName:
	return _selected_card_id


func get_card_ids() -> Array[StringName]:
	var card_ids: Array[StringName] = []
	for card_def in _card_defs:
		card_ids.append(StringName(card_def.get("card_id")))
	return card_ids


func select_card(card_id: StringName) -> void:
	if card_id == StringName():
		deselect_card()
		return
	if _selected_card_id == card_id:
		return
	_selected_card_id = card_id
	_refresh_selection()
	card_selected.emit(card_id)


func deselect_card() -> void:
	if _selected_card_id == StringName():
		return
	_selected_card_id = StringName()
	_refresh_selection()
	card_deselected.emit()


func _resolve_initial_sun(battle: Node, scenario: Resource) -> int:
	if battle != null and is_instance_valid(battle) and battle.has_method("get_current_sun"):
		return int(battle.call("get_current_sun"))
	if scenario != null:
		return int(scenario.get("initial_sun"))
	return 0


func _rebuild_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_card_slots.clear()
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	add_child(layout)
	for card_def in _card_defs:
		var card_id := StringName(card_def.get("card_id"))
		var slot := _build_card_slot(card_def, card_id)
		layout.add_child(slot)
		_card_slots.append(slot)


func _build_card_slot(card_def: Resource, card_id: StringName) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(72.0, 90.0)
	panel.name = String(card_id)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = Vector2(48.0, 36.0)
	color_rect.color = _card_color(card_id)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(color_rect)
	var name_label := Label.new()
	var display_name = card_def.get("display_name")
	name_label.text = String(display_name if display_name != null else String(card_id))
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	var cost_label := Label.new()
	cost_label.text = "%d" % int(card_def.get("sun_cost"))
	cost_label.name = "CostLabel"
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_label)
	var cooldown_overlay := ColorRect.new()
	cooldown_overlay.name = "CooldownOverlay"
	cooldown_overlay.color = Color(0.0, 0.0, 0.0, 0.5)
	cooldown_overlay.visible = false
	cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(cooldown_overlay)
	panel.gui_input.connect(func(event: InputEvent): _on_slot_input(event, card_id))
	return panel


func _on_slot_input(event: InputEvent, card_id: StringName) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if _selected_card_id == card_id:
		deselect_card()
		return
	select_card(card_id)


func _refresh_selection() -> void:
	for slot in _card_slots:
		if slot == null or not is_instance_valid(slot):
			continue
		var is_selected := slot.name == String(_selected_card_id)
		if is_selected:
			slot.modulate = Color.WHITE
			slot.scale = Vector2(1.08, 1.08)
		else:
			slot.modulate = Color(0.8, 0.8, 0.8, 1.0)
			slot.scale = Vector2(1.0, 1.0)


func _on_resource_changed(event_data: Variant) -> void:
	_current_sun = int(event_data.core.get("after", _current_sun))
	_refresh_affordability()


func _on_cooldown_started(event_data: Variant) -> void:
	var card_id := StringName(event_data.core.get("card_id", ""))
	if card_id == StringName():
		return
	var cooldown_seconds := float(event_data.core.get("cooldown_seconds", 1.0))
	_cooldown_ready_times[card_id] = GameState.current_time + cooldown_seconds
	_start_cooldown_overlay(card_id, cooldown_seconds)


func _on_card_play_rejected(_event_data: Variant) -> void:
	pass


func _on_card_play_requested(_event_data: Variant) -> void:
	pass


func _start_cooldown_overlay(card_id: StringName, duration: float) -> void:
	var slot = _find_slot_by_card_id(card_id)
	if slot == null:
		return
	var overlay = slot.get_node_or_null("CooldownOverlay")
	if overlay == null:
		return
	overlay.visible = true
	var tween := _track_tween(create_tween())
	if tween == null:
		return
	tween.tween_property(overlay, "color:a", 0.0, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		overlay.visible = false
		overlay.color.a = 0.5
	)


func _refresh_affordability() -> void:
	for card_def in _card_defs:
		var card_id := StringName(card_def.get("card_id"))
		var slot = _find_slot_by_card_id(card_id)
		if slot == null:
			continue
		var cost_label = slot.find_child("CostLabel", false, false)
		if cost_label == null:
			continue
		var cost := int(card_def.get("sun_cost"))
		if cost > _current_sun:
			cost_label.add_theme_color_override("font_color", Color("e06060"))
		else:
			cost_label.add_theme_color_override("font_color", Color("ffffff"))


func _find_slot_by_card_id(card_id: StringName) -> Control:
	for slot in _card_slots:
		if slot != null and is_instance_valid(slot) and slot.name == String(card_id):
			return slot
	return null


func _card_color(card_id: StringName) -> Color:
	var id := String(card_id)
	if id.contains("sunflower"):
		return Color("ffd700")
	if id.contains("shooter") or id.contains("pea"):
		return Color("4caf50")
	if id.contains("wall") or id.contains("nut"):
		return Color("8d6e63")
	if id.contains("repeater"):
		return Color("2e7d32")
	if id.contains("lobber") or id.contains("cabbage"):
		return Color("66bb6a")
	return Color("78909c")
