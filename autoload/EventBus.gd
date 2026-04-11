extends Node

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

signal event_pushed(event_name: StringName, event_data: Variant)

const MAX_HISTORY := 256

var _subscribers: Dictionary = {}
var _history: Array[Dictionary] = []


func subscribe(event_name: StringName, callback: Callable, priority: int = 0) -> void:
	subscribe_ex(event_name, callback, priority)


func subscribe_ex(
	event_name: StringName,
	callback: Callable,
	priority: int = 0,
	oneshot: bool = false,
	filter: Callable = Callable()
) -> void:
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
		"oneshot": oneshot,
		"filter": filter,
	})
	_subscribers[event_name].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["priority"]) > int(b["priority"])
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
	var is_event_object: bool = event_data != null and event_data is RefCounted and event_data.has_method("ensure_runtime_defaults")
	if not is_event_object:
		var normalized_event: Variant = EventDataRef.new()
		if event_data is Dictionary:
			normalized_event.core = event_data.duplicate(true)
		event_data = normalized_event
	event_data.ensure_runtime_defaults(event_name)

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

		var filter_callable: Callable = entry.get("filter", Callable())
		if filter_callable.is_valid() and not bool(filter_callable.call(event_data)):
			alive_entries.append(entry)
			continue

		callback.call(event_data)
		if not bool(entry.get("oneshot", false)):
			alive_entries.append(entry)

	_subscribers[event_name] = alive_entries


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func clear() -> void:
	_subscribers.clear()
	_history.clear()


func _record_history(event_name: StringName, event_data: Variant) -> void:
	_history.push_front({
		"event_name": event_name,
		"event_id": event_data.runtime.get("event_id", ""),
		"chain_id": event_data.runtime.get("chain_id", ""),
		"depth": int(event_data.runtime.get("depth", 0)),
		"timestamp": float(event_data.runtime.get("timestamp", 0.0)),
		"core": event_data.core.duplicate(true),
		"runtime": event_data.runtime.duplicate(true),
	})

	if _history.size() > MAX_HISTORY:
		_history.pop_back()
