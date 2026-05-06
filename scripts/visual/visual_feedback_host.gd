extends Node
class_name VisualFeedbackHost

const VisualActionRunnerRef = preload("res://scripts/visual/visual_action_runner.gd")

const FIXED_EVENTS: PackedStringArray = [
	&"projectile.spawned",
	&"projectile.hit",
	&"projectile.expired",
	&"entity.damaged",
	&"entity.died",
	&"placement.accepted",
	&"entity.status_removed",
]

var _subscriptions: Dictionary = {}
var _action_runner: RefCounted = null


func _ready() -> void:
	_action_runner = VisualActionRunnerRef.new()
	_subscribe_all()


func _subscribe_all() -> void:
	for event_name: StringName in FIXED_EVENTS:
		if _subscriptions.has(event_name):
			continue
		var callback := Callable(self, "_on_visual_event").bind(event_name)
		_subscriptions[event_name] = callback
		EventBus.subscribe(event_name, callback)


func shutdown() -> void:
	for event_name: Variant in _subscriptions.keys():
		EventBus.unsubscribe(event_name, _subscriptions[event_name])
	_subscriptions.clear()
	_action_runner = null


func _on_visual_event(event_data: Variant, event_name: StringName) -> void:
	# Try-safe: visual failures MUST NOT propagate to battle logic
	if event_data == null:
		return

	var cues: Array[Dictionary] = VisualCueRegistry.get_cues_for_event(event_name)
	if cues.is_empty():
		return

	for entry in cues:
		var cue_def = entry.get("def", null)
		if cue_def == null:
			DebugService.record_visual_event({
				"cue_id": &"",
				"event_name": event_name,
				"action_type": &"",
				"target_id": -1,
				"result": "skipped",
				"skip_reason": "cue_def is null",
			})
			continue

		if not _cue_filters_match(cue_def, event_data):
			DebugService.record_visual_event({
				"cue_id": cue_def.id,
				"event_name": event_name,
				"action_type": &"",
				"target_id": -1,
				"result": "skipped",
				"skip_reason": "filters did not match",
			})
			continue

		for action: Dictionary in cue_def.actions:
			if action.is_empty():
				continue
			var action_with_cue := action.duplicate(true)
			action_with_cue["cue_id"] = cue_def.id
			_action_runner.execute_action(action_with_cue, event_data)


func _cue_filters_match(cue_def: Resource, event_data: Variant) -> bool:
	var filters: Dictionary = cue_def.filters
	if filters.is_empty():
		return true

	var core: Dictionary = event_data.core

	# source_kind filter
	if filters.has("source_kind"):
		var expected = filters["source_kind"]
		var actual = core.get("source_kind", StringName())
		if actual != expected:
			return false

	# target_kind filter
	if filters.has("target_kind"):
		var expected = filters["target_kind"]
		var actual = core.get("target_kind", StringName())
		if actual != expected:
			return false

	# source_archetype_id filter
	if filters.has("source_archetype_id"):
		var expected = filters["source_archetype_id"]
		var actual = core.get("source_archetype_id", StringName())
		if actual != expected:
			return false

	# target_archetype_id filter
	if filters.has("target_archetype_id"):
		var expected = filters["target_archetype_id"]
		var actual = core.get("target_archetype_id", StringName())
		if actual != expected:
			return false

	# tags filter: all filter tags must be present in event tags
	if filters.has("tags"):
		var filter_tags: PackedStringArray = filters["tags"]
		if not (filter_tags is PackedStringArray):
			filter_tags = PackedStringArray(filters["tags"])
		var event_tags: PackedStringArray = core.get("tags", PackedStringArray())
		if not (event_tags is PackedStringArray):
			event_tags = PackedStringArray()
		for tag: String in filter_tags:
			if tag not in event_tags:
				return false

	# move_mode filter
	if filters.has("move_mode"):
		var expected = filters["move_mode"]
		var actual = core.get("move_mode", StringName())
		if actual != expected:
			return false

	# profile_id filter
	if filters.has("profile_id"):
		var expected = filters["profile_id"]
		var actual = core.get("profile_id", StringName())
		if actual != expected:
			return false

	return true
