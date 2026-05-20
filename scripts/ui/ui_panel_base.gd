extends Control
class_name UIPanelBase

const UIThemeProfileRef = preload("res://scripts/ui/theme/ui_theme_profile.gd")

var _battle: Node = null
var _subscriptions: Array[Dictionary] = []
var _active_tweens: Array[Tween] = []
var _theme_profile: Resource = null


func panel_setup(battle: Node, _scenario: Resource, theme: Resource = null) -> void:
	_battle = battle
	_theme_profile = theme if theme != null else UIThemeProfileRef.default()


func panel_teardown() -> void:
	for tracked in _subscriptions:
		var event_name := StringName(tracked.get("event_name", StringName()))
		var callback: Callable = tracked.get("callback", Callable())
		if event_name == StringName() or not callback.is_valid():
			continue
		EventBus.unsubscribe(event_name, callback)
	_subscriptions.clear()
	_kill_active_tweens()
	_battle = null


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


func _get_theme() -> Resource:
	return _theme_profile


func _resolve_icon(icon_id: StringName) -> Resource:
	return null


func _resolve_text(key: StringName) -> String:
	return str(key)
