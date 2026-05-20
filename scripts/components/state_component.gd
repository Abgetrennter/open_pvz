extends Node
class_name StateComponent

var initial_state: StringName = StringName()
var current_state: StringName = StringName()
var transitions: Array[Dictionary] = []
var state_liveness: Dictionary = {}
var bind_time := 0.0
var _processed_transition_ids: Dictionary = {}
var _event_callables: Dictionary = {}
var _active_liveness_source: StringName = StringName()


func _exit_tree() -> void:
	_unsubscribe_all()


func bind_state_specs(specs: Array) -> void:
	transitions.clear()
	state_liveness.clear()
	_clear_state_liveness_override()
	_processed_transition_ids.clear()
	_unsubscribe_all()
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
		var spec_liveness: Variant = spec.get("state_liveness", {})
		if spec_liveness is Dictionary:
			for state_key: Variant in spec_liveness.keys():
				state_liveness[StringName(state_key)] = Dictionary(spec_liveness[state_key]).duplicate(true)
	transitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_trigger: String = String(a.get("trigger", "time"))
		var b_trigger: String = String(b.get("trigger", "time"))
		if a_trigger == "time" and b_trigger == "time":
			return float(a.get("after", 0.0)) < float(b.get("after", 0.0))
		if a_trigger == "time":
			return true
		return false
	)
	_subscribe_event_transitions()
	_apply_state_liveness_override(current_state)
	_sync_owner_state()


func has_active_states() -> bool:
	return current_state != StringName() or not transitions.is_empty()


func get_current_state() -> StringName:
	return current_state


func _physics_process(_delta: float) -> void:
	if GameState.should_skip_node_process_for_central_step():
		return
	physics_process_states()


func physics_process_states() -> void:
	if not has_active_states():
		return
	var owner := get_parent()
	if owner == null or not is_instance_valid(owner):
		return
	var elapsed := GameState.current_time - bind_time
	_process_time_transitions(owner, elapsed)


func _process_time_transitions(owner: Node, elapsed: float) -> void:
	for transition in transitions:
		var trigger_type: String = String(transition.get("trigger", "time"))
		if trigger_type != "time":
			continue
		if not _try_execute_transition(transition, elapsed):
			break


func _try_execute_transition(transition: Dictionary, elapsed: float = 0.0) -> bool:
	var transition_id := StringName(transition.get("transition_id", StringName("%s_%s" % [
		String(transition.get("from_state", "")),
		String(transition.get("to_state", "")),
	])))
	if _processed_transition_ids.has(transition_id):
		return true
	var from_state := StringName(transition.get("from_state", current_state))
	if current_state != from_state:
		return true
	var trigger_type: String = String(transition.get("trigger", "time"))
	if trigger_type == "time":
		if elapsed + 0.001 < float(transition.get("after", 0.0)):
			return false
	elif trigger_type == "event":
		return true
	return _execute_transition(transition, {
		"trigger": trigger_type,
		"elapsed": elapsed,
	})


func _subscribe_event_transitions() -> void:
	for transition in transitions:
		var trigger_type: String = String(transition.get("trigger", "time"))
		if trigger_type != "event":
			continue
		var listen_event := StringName(transition.get("event_name", StringName()))
		if listen_event == StringName():
			continue
		if _event_callables.has(listen_event):
			continue
		var callback := Callable(self, "_on_state_event").bind(listen_event)
		_event_callables[listen_event] = callback
		EventBus.subscribe(listen_event, callback)


func _unsubscribe_all() -> void:
	for event_name: Variant in _event_callables.keys():
		EventBus.unsubscribe(event_name, _event_callables[event_name])
	_event_callables.clear()


func _on_state_event(event_data, event_name: StringName) -> void:
	var owner := get_parent()
	if owner == null or not is_instance_valid(owner):
		return
	if not _event_targets_owner(event_data, owner):
		return
	for transition in transitions:
		var trigger_type: String = String(transition.get("trigger", "time"))
		if trigger_type != "event":
			continue
		var listen_event := StringName(transition.get("event_name", StringName()))
		if listen_event != event_name:
			continue
		var required_state := StringName(transition.get("required_state_id", StringName()))
		if required_state != StringName():
			var event_state_id := StringName(_event_core(event_data).get("state_id", StringName()))
			if event_state_id != required_state:
				continue
		var required_layer_id := StringName(transition.get("required_layer_id", StringName()))
		if required_layer_id != StringName():
			var event_layer_id := StringName(_event_core(event_data).get("layer_id", StringName()))
			if event_layer_id != required_layer_id:
				continue
		var from_state := StringName(transition.get("from_state", current_state))
		if current_state != from_state:
			continue
		var transition_id := StringName(transition.get("transition_id", StringName("%s_%s" % [
			String(transition.get("from_state", "")),
			String(transition.get("to_state", "")),
		])))
		if _processed_transition_ids.has(transition_id):
			continue
		_execute_transition(transition, {
			"trigger": "event",
			"event_name": event_name,
		})
		break


func _event_core(event_data) -> Dictionary:
	if event_data == null:
		return {}
	var event_core: Variant = event_data.get("core") if event_data.has_method("get") else null
	if event_core is Dictionary:
		return event_core
	return {}


func _event_targets_owner(event_data, owner: Node) -> bool:
	var event_core := _event_core(event_data)
	if event_core.is_empty():
		return true
	var target_node: Variant = event_core.get("target_node", null)
	if target_node is Node:
		return target_node == owner
	var target_id := int(event_core.get("target_id", -1))
	if target_id >= 0 and owner.has_method("get_entity_id"):
		return target_id == int(owner.call("get_entity_id"))
	return true


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


func _execute_transition(transition: Dictionary, reason: Dictionary = {}) -> bool:
	var owner := get_parent()
	if owner == null or not is_instance_valid(owner):
		return true
	var transition_id := StringName(transition.get("transition_id", StringName("%s_%s" % [
		String(transition.get("from_state", "")),
		String(transition.get("to_state", "")),
	])))
	if _processed_transition_ids.has(transition_id):
		return true
	var from_state := StringName(transition.get("from_state", current_state))
	if current_state != from_state:
		_emit_state_transition_rejected(owner, from_state, StringName(transition.get("to_state", current_state)), transition_id, reason)
		return false
	var previous_state := current_state
	var next_state := StringName(transition.get("to_state", current_state))
	_emit_state_exited(owner, previous_state)
	_clear_state_liveness_override()
	current_state = next_state
	_processed_transition_ids[transition_id] = true
	_apply_state_liveness_override(current_state)
	_sync_owner_state()
	_apply_transition_side_effects(owner, transition)
	_emit_state_entered(owner, current_state)
	return true


func _apply_transition_side_effects(owner: Node, transition: Dictionary) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var side_effects: Variant = transition.get("side_effects", [])
	if side_effects is Dictionary:
		_apply_transition_side_effect(owner, Dictionary(side_effects))
	elif side_effects is Array:
		for side_effect in Array(side_effects):
			if side_effect is Dictionary:
				_apply_transition_side_effect(owner, Dictionary(side_effect))


func _apply_transition_side_effect(owner: Node, side_effect: Dictionary) -> void:
	var effect_type := StringName(side_effect.get("type", StringName()))
	if effect_type == StringName():
		for key in [&"set_movement", &"set_height_band", &"set_runtime_params", &"emit_event", &"submit_movement_override"]:
			if side_effect.has(key):
				effect_type = key
				break
	match effect_type:
		&"set_movement":
			var movement_spec: Dictionary = {}
			var raw_spec: Variant = side_effect.get("spec", side_effect.get("set_movement", {}))
			if raw_spec is Dictionary:
				movement_spec = Dictionary(raw_spec).duplicate(true)
			if owner.has_method("set_movement_spec"):
				owner.call("set_movement_spec", movement_spec)
		&"submit_movement_override":
			var command: Dictionary = {}
			var raw_command: Variant = side_effect.get("command", side_effect.get("submit_movement_override", {}))
			if raw_command is Dictionary:
				command = Dictionary(raw_command).duplicate(true)
			if owner.has_method("submit_movement_override"):
				owner.call("submit_movement_override", command)
		&"set_height_band":
			_apply_height_side_effect(owner, side_effect.get("height_band", side_effect.get("set_height_band", {})))
		&"set_runtime_params":
			var raw_params: Variant = side_effect.get("params", side_effect.get("set_runtime_params", {}))
			if raw_params is Dictionary:
				_apply_runtime_params(owner, Dictionary(raw_params))
		&"emit_event":
			_emit_side_effect_event(owner, side_effect.get("event", side_effect.get("emit_event", {})))
		_:
			pass


func _apply_height_side_effect(owner: Node, raw_value: Variant) -> void:
	if raw_value is Resource:
		if owner.has_method("apply_height_band"):
			owner.call("apply_height_band", raw_value)
		return
	if not (raw_value is Dictionary):
		return
	var height_params := Dictionary(raw_value)
	if height_params.has("hit_height_range") and owner.has_method("set_hit_height_range"):
		var hit_range: Variant = height_params.get("hit_height_range")
		if hit_range is Vector2:
			owner.call("set_hit_height_range", float(hit_range.x), float(hit_range.y))
	var height := float(height_params.get("height", owner.call("get_height") if owner.has_method("get_height") else 0.0))
	var height_velocity := float(height_params.get("height_velocity", owner.call("get_height_velocity") if owner.has_method("get_height_velocity") else 0.0))
	var ground_contact := bool(height_params.get("ground_contact", owner.call("is_ground_contact") if owner.has_method("is_ground_contact") else true))
	var exposure_state := StringName(height_params.get("exposure_state", owner.call("get_exposure_state") if owner.has_method("get_exposure_state") else &"ground"))
	if owner.has_method("set_motion_state"):
		owner.call("set_motion_state", height, height_velocity, ground_contact, exposure_state, &"state_side_effect", StringName())


func _apply_runtime_params(owner: Node, params: Dictionary) -> void:
	for key: Variant in params.keys():
		var state_key := StringName(key)
		if owner.has_method("set_state_value"):
			owner.call("set_state_value", state_key, params[key])
		if _owner_has_property(owner, String(key)):
			owner.set(String(key), params[key])
	if owner.has_method("sync_runtime_state"):
		owner.call("sync_runtime_state")


func _emit_side_effect_event(owner: Node, raw_event: Variant) -> void:
	var event_name := StringName()
	var tags := PackedStringArray(["state", "side_effect"])
	var core: Dictionary = {}
	if raw_event is Dictionary:
		var event_def := Dictionary(raw_event)
		event_name = StringName(event_def.get("event_name", StringName()))
		if event_def.get("tags", null) is PackedStringArray:
			tags = PackedStringArray(event_def.get("tags"))
		elif event_def.get("tags", null) is Array:
			tags = PackedStringArray(event_def.get("tags"))
		if event_def.get("core", null) is Dictionary:
			core = Dictionary(event_def.get("core")).duplicate(true)
	elif raw_event != null:
		event_name = StringName(raw_event)
	if event_name == StringName():
		return
	var event_data: Variant = preload("res://scripts/core/runtime/event_data.gd").create(owner, owner, null, tags)
	for key: Variant in core.keys():
		event_data.core[key] = core[key]
	event_data.core["state_id"] = current_state
	EventBus.push_event(event_name, event_data)


func _owner_has_property(owner: Node, property_name: String) -> bool:
	for property_info in owner.get_property_list():
		if property_info is Dictionary and String(property_info.get("name", "")) == property_name:
			return true
	return false


func _state_liveness_source(state_id: StringName) -> StringName:
	if state_id == StringName():
		return StringName()
	return StringName("state:%s" % String(state_id))


func _apply_state_liveness_override(state_id: StringName) -> void:
	var owner := get_parent()
	if owner == null or not is_instance_valid(owner):
		return
	if not owner.has_method("push_liveness_override"):
		return
	var profile := Dictionary(state_liveness.get(state_id, {}))
	if profile.is_empty():
		_active_liveness_source = StringName()
		return
	var source_id := _state_liveness_source(state_id)
	owner.call("push_liveness_override", source_id, profile, 10)
	_active_liveness_source = source_id


func _clear_state_liveness_override() -> void:
	if _active_liveness_source == StringName():
		return
	var owner := get_parent()
	if owner != null and is_instance_valid(owner) and owner.has_method("pop_liveness_override"):
		owner.call("pop_liveness_override", _active_liveness_source)
	_active_liveness_source = StringName()


func _emit_state_exited(owner: Node, state_id: StringName) -> void:
	var state_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(owner, owner, null, PackedStringArray(["state", "exited"]))
	state_event.core["state_id"] = state_id
	EventBus.push_event(&"entity.state_exited", state_event)


func _emit_state_transition_rejected(owner: Node, from_state: StringName, to_state: StringName, transition_id: StringName, reason: Dictionary) -> void:
	var state_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(owner, owner, null, PackedStringArray(["state", "rejected"]))
	state_event.core["from_state"] = from_state
	state_event.core["to_state"] = to_state
	state_event.core["transition_id"] = transition_id
	state_event.core["reason"] = reason.duplicate(true)
	EventBus.push_event(&"entity.state_transition_rejected", state_event)
