extends "res://scripts/ui/ui_screen_base.gd"
class_name UIPhaseScreen

var _flow_state: Node = null
var _overlay: ColorRect = null
var _label: Label = null
var _subscriptions: Array[Dictionary] = []
var _active_tweens: Array[Tween] = []


func screen_setup(battle: Node) -> void:
	super.screen_setup(battle)
	_flow_state = battle.get_node_or_null("BattleFlowState") if battle != null and is_instance_valid(battle) else null
	_build_ui()
	_track_subscribe(&"battle.victory", Callable(self, "_on_victory"))
	_track_subscribe(&"battle.defeat", Callable(self, "_on_defeat"))


func screen_teardown() -> void:
	for tracked in _subscriptions:
		var event_name := StringName(tracked.get("event_name", StringName()))
		var callback: Callable = tracked.get("callback", Callable())
		if event_name == StringName() or not callback.is_valid():
			continue
		EventBus.unsubscribe(event_name, callback)
	_subscriptions.clear()
	_kill_active_tweens()
	_flow_state = null
	super.screen_teardown()


func _build_ui() -> void:
	layer = 100
	for child in get_children():
		remove_child(child)
		child.queue_free()
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


func _track_subscribe(event_name: StringName, callback: Callable) -> void:
	if event_name == StringName() or not callback.is_valid():
		return
	EventBus.subscribe(event_name, callback)
	_subscriptions.append({
		"event_name": event_name,
		"callback": callback,
	})


func _track_tween(tween: Tween) -> Tween:
	if tween == null:
		return null
	_active_tweens.append(tween)
	tween.finished.connect(func(): _active_tweens.erase(tween))
	return tween


func _kill_active_tweens() -> void:
	for tween in _active_tweens:
		if tween != null:
			tween.kill()
	_active_tweens.clear()


func _on_victory(_event_data: Variant) -> void:
	_show_result("Victory!", Color("4caf50"))


func _on_defeat(_event_data: Variant) -> void:
	_show_result("Defeat!", Color("e06060"))


func _show_result(text: String, color: Color) -> void:
	if _label == null or _overlay == null:
		return
	_label.text = text + "\nPress R to Restart"
	_label.add_theme_color_override("font_color", color)
	_label.visible = true
	var tween := _track_tween(create_tween())
	if tween == null:
		return
	tween.tween_property(_overlay, "color:a", 0.5, 0.3)
	tween.parallel().tween_property(_label, "scale", Vector2(1.0, 1.0), 0.3).from(Vector2(0.5, 0.5))
