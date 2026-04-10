extends Node

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

signal event_pushed(event_name: StringName, event_data: Variant)

const MAX_HISTORY := 256

var _subscribers: Dictionary = {}
var _history: Array[Dictionary] = []


func subscribe(event_name: StringName, callback: Callable, priority: int = 0) -> void:
	if not callback.is_valid():
		return

	if not _subscribers.has(event_name):
		_subscribers[event_name] = []

	for entry: Dictionary in _subscribers[event_name]:
		if entry["callable"] == callback:
			return

	_subscribers[event_name].append({
		"callable": callback,
		"priority": priority,
	})
	_subscribers[event_name].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) < int(b["priority"])
	)


func unsubscribe(event_name: StringName, callback: Callable) -> void:
	if not _subscribers.has(event_name):
		return

	_subscribers[event_name] = _subscribers[event_name].filter(func(entry: Dictionary) -> bool:
		return entry["callable"] != callback
	)

	if _subscribers[event_name].is_empty():
		_subscribers.erase(event_name)


func push_event(event_name: StringName, event_data: Variant = null) -> void:
	if event_data == null:
		event_data = EventDataRef.new()

	_record_history(event_name, event_data)
	event_pushed.emit(event_name, event_data)

	if not _subscribers.has(event_name):
		return

	var alive_entries: Array[Dictionary] = []
	for entry: Dictionary in _subscribers[event_name]:
		var callback: Callable = entry["callable"]
		if not callback.is_valid():
			continue

		var target_object := callback.get_object()
		if target_object != null and not is_instance_valid(target_object):
			continue

		alive_entries.append(entry)
		callback.call(event_data)

	_subscribers[event_name] = alive_entries


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func clear() -> void:
	_subscribers.clear()
	_history.clear()


func _record_history(event_name: StringName, event_data: Variant) -> void:
	_history.push_front({
		"event_name": event_name,
		"core": event_data.core.duplicate(true),
		"runtime": event_data.runtime.duplicate(true),
	})

	if _history.size() > MAX_HISTORY:
		_history.pop_back()
