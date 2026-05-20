extends "res://scripts/ui/ui_panel_base.gd"
class_name UICardBar

signal card_selected(card_id: StringName)
signal card_deselected

var _card_defs: Array = []
var _selected_card_id: StringName = StringName()
var _card_slots: Array[Control] = []
var _current_sun := 0
var _cooldown_ready_times: Dictionary = {}


func panel_setup(battle: Node, scenario: Resource, theme: Resource = null) -> void:
	super.panel_setup(battle, scenario, theme)
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
	_track_subscribe(&"card.hand_updated", Callable(self, "_on_card_hand_updated"))


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
	cooldown_overlay.color = _get_theme().card_cooldown_overlay_color
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
			slot.modulate = _get_theme().card_unselected_modulate
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


func _on_card_hand_updated(_event_data: Variant) -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	var card_state: Node = null
	if _battle.has_method("get_card_state"):
		card_state = _battle.call("get_card_state")
	else:
		card_state = _battle.get_node_or_null("BattleCardState")
	if card_state == null or not card_state.has_method("get_card_defs_in_hand"):
		return
	_card_defs = card_state.call("get_card_defs_in_hand")
	_rebuild_ui()
	_refresh_selection()
	_refresh_affordability()


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
			cost_label.add_theme_color_override("font_color", _get_theme().card_unaffordable_text_color)
		else:
			cost_label.add_theme_color_override("font_color", _get_theme().card_affordable_text_color)


func _find_slot_by_card_id(card_id: StringName) -> Control:
	for slot in _card_slots:
		if slot != null and is_instance_valid(slot) and slot.name == String(card_id):
			return slot
	return null


func _card_color(card_id: StringName) -> Color:
	var id := String(card_id)
	var type_colors: Dictionary = _get_theme().card_type_colors
	for key: StringName in type_colors:
		if key == &"default":
			continue
		if id.contains(String(key)):
			return type_colors[key]
	return type_colors.get(&"default", Color("78909c"))
