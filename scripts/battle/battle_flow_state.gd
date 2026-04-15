extends Node
class_name BattleFlowState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var phase: StringName = &"preparing"
var active_wave_id: StringName = StringName()
var completed_wave_ids: PackedStringArray = PackedStringArray()
var victory_reason: StringName = StringName()
var defeat_reason: StringName = StringName()


func setup(_battle: Node, _scenario: Resource) -> void:
	phase = &"preparing"
	active_wave_id = StringName()
	completed_wave_ids = PackedStringArray()
	victory_reason = StringName()
	defeat_reason = StringName()


func get_debug_name() -> String:
	return "flow_state"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"template_id": StringName(),
		"entity_kind": &"battle_flow_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": phase,
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"active_wave_id": active_wave_id,
			"completed_wave_ids": PackedStringArray(completed_wave_ids),
			"victory_reason": victory_reason,
			"defeat_reason": defeat_reason,
		},
	}


func is_terminal() -> bool:
	return phase in [&"victory", &"defeat"]


func ensure_running(wave_id: StringName) -> void:
	active_wave_id = wave_id
	if phase == &"preparing":
		_change_phase(&"running", &"wave_started")


func mark_wave_started(wave_id: StringName) -> void:
	active_wave_id = wave_id
	var wave_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["wave", "started"]))
	wave_event.core["wave_id"] = wave_id
	EventBus.push_event(&"wave.started", wave_event)


func mark_wave_completed(wave_id: StringName) -> void:
	if not completed_wave_ids.has(String(wave_id)):
		completed_wave_ids.append(String(wave_id))
	var wave_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["wave", "completed"]))
	wave_event.core["wave_id"] = wave_id
	EventBus.push_event(&"wave.completed", wave_event)


func mark_victory(reason: StringName) -> void:
	if is_terminal():
		return
	victory_reason = reason
	_change_phase(&"victory", reason)
	var victory_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["battle", "victory"]))
	victory_event.core["reason"] = reason
	EventBus.push_event(&"battle.victory", victory_event)


func mark_defeat(reason: StringName) -> void:
	if is_terminal():
		return
	defeat_reason = reason
	_change_phase(&"defeat", reason)
	var defeat_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["battle", "defeat"]))
	defeat_event.core["reason"] = reason
	EventBus.push_event(&"battle.defeat", defeat_event)


func _change_phase(next_phase: StringName, reason: StringName) -> void:
	if phase == next_phase:
		return
	var before := phase
	phase = next_phase
	var phase_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["battle", "phase"]))
	phase_event.core["before"] = before
	phase_event.core["after"] = next_phase
	phase_event.core["reason"] = reason
	if active_wave_id != StringName():
		phase_event.core["wave_id"] = active_wave_id
	EventBus.push_event(&"battle.phase_changed", phase_event)
