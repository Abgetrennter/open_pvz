extends Node
class_name StateComponent

var initial_state: StringName = StringName()
var current_state: StringName = StringName()
var transitions: Array[Dictionary] = []
var bind_time := 0.0
var _processed_transition_ids: Dictionary = {}


func bind_state_specs(specs: Array) -> void:
	transitions.clear()
	_processed_transition_ids.clear()
	initial_state = StringName()
	current_state = StringName()
	bind_time = GameState.current_time
	for spec in specs:
		if not (spec is Dictionary):
			continue
		if initial_state == StringName():
			initial_state = StringName(spec.get("initial_state", StringName()))
			current_state = initial_state
		var spec_transitions: Variant = spec.get("transitions", [])
		if spec_transitions is Array:
			for transition in spec_transitions:
				if transition is Dictionary:
					transitions.append(transition.duplicate(true))
	transitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("after", 0.0)) < float(b.get("after", 0.0))
	)
	_sync_owner_state()


func has_active_states() -> bool:
	return current_state != StringName() or not transitions.is_empty()


func get_current_state() -> StringName:
	return current_state


func _physics_process(_delta: float) -> void:
	physics_process_states()


func physics_process_states() -> void:
	if not has_active_states():
		return
	var owner := get_parent()
	if owner == null or not is_instance_valid(owner):
		return
	var elapsed := GameState.current_time - bind_time
	for transition in transitions:
		var transition_id := StringName(transition.get("transition_id", StringName("%s_%s" % [
			String(transition.get("from_state", "")),
			String(transition.get("to_state", "")),
		])))
		if _processed_transition_ids.has(transition_id):
			continue
		if current_state != StringName(transition.get("from_state", current_state)):
			continue
		if elapsed + 0.001 < float(transition.get("after", 0.0)):
			continue
		current_state = StringName(transition.get("to_state", current_state))
		_processed_transition_ids[transition_id] = true
		_sync_owner_state()
		_emit_state_entered(owner, current_state)


func _sync_owner_state() -> void:
	var owner := get_parent()
	if owner == null or not is_instance_valid(owner):
		return
	if owner.has_method("set_state_value"):
		owner.call("set_state_value", &"state_stage", current_state)
		owner.call("set_state_value", &"state_bind_time", bind_time)
		owner.call("sync_runtime_state")


func _emit_state_entered(owner: Node, state_id: StringName) -> void:
	var state_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(owner, owner, null, PackedStringArray(["state", "entered"]))
	state_event.core["state_id"] = state_id
	EventBus.push_event(&"entity.state_entered", state_event)
