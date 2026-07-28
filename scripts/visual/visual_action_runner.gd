extends RefCounted
class_name VisualActionRunner


func execute_action(action: Dictionary, event_data: Variant) -> void:
	if action.is_empty():
		return
	if event_data == null:
		return

	var action_type: StringName = action.get("type", &"")
	var cue_id: StringName = action.get("cue_id", &"")
	var event_name: StringName = event_data.runtime.get("event_name", &"")
	var target: Node = _resolve_target(action, event_data)
	var target_id: int = _get_entity_id(target)
	var target_archetype_id := _get_archetype_id(target)

	if action_type == &"spawn_fx":
		_execute_spawn_fx(action, event_data, cue_id, event_name, target, target_id)
	elif action_type == &"play_audio":
		_execute_play_audio(action, event_data, cue_id, event_name, target_id)
	elif action_type == &"flash_actor":
		_execute_flash_actor(action, event_data, cue_id, event_name, target, target_id)
	elif action_type == &"play_actor_animation":
		_execute_play_actor_animation(action, event_data, cue_id, event_name, target, target_id)
	elif action_type == &"play_actor_action":
		_execute_play_actor_action(action, event_data, cue_id, event_name, target, target_id)
	elif action_type == &"play_actor_action_sequence":
		_execute_play_actor_action_sequence(action, event_data, cue_id, event_name, target, target_id, target_archetype_id)
	elif action_type == &"play_actor_state":
		_execute_play_actor_state(action, event_data, cue_id, event_name, target, target_id)
	elif action_type == &"attach_fx":
		_execute_attach_fx(action, event_data, cue_id, event_name, target_id)
	elif action_type == &"screen_overlay":
		_execute_screen_overlay(action, event_data, cue_id, event_name)
	else:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": action_type,
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "unknown action type",
		})


# ── Target Resolution ──────────────────────────────────────────────

func _resolve_target(action: Dictionary, event_data: Variant) -> Node:
	var target_ref: StringName = action.get("target_ref", &"target")
	var core: Dictionary = event_data.core
	match target_ref:
		&"source":
			return core.get("source_node", null)
		&"target":
			return core.get("target_node", null)
		&"event_position":
			return null
		_:
			return core.get("target_node", null)


func _get_entity_id(node: Node) -> int:
	if node == null:
		return -1
	if node.has_method("get_entity_id"):
		return int(node.call("get_entity_id"))
	return -1


func _get_archetype_id(node: Node) -> StringName:
	if node == null or not is_instance_valid(node):
		return StringName()
	var value: Variant = node.get("archetype_id")
	if value is StringName:
		return value
	if value is String:
		return StringName(value)
	return StringName()


func _valid_node(value: Variant) -> Node:
	if value == null or not is_instance_valid(value):
		return null
	return value if value is Node else null


# ── Action Executors ────────────────────────────────────────────────

func _execute_spawn_fx(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, _target: Node, target_id: int) -> void:
	var fx_id: StringName = action.get("fx_id", &"")
	if fx_id == StringName():
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"spawn_fx",
			"target_id": target_id,
			"result": "skipped",
			"skip_reason": "fx_id is empty",
		})
		return

	var fx_def = VisualFxRegistry.get_def(fx_id)
	if fx_def == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"spawn_fx",
			"target_id": target_id,
			"result": "skipped",
			"skip_reason": "FX resource missing (no def for %s), degrading to no-op" % String(fx_id),
		})
		return

	if fx_def.fx_scene == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"spawn_fx",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "fx_scene is null for %s (placeholder)" % String(fx_id),
		})
		return

	# Resolve spawn position
	var spawn_pos := _resolve_spawn_position(action, _event_data, _target)

	# Resolve host layer
	var layer_name: StringName = fx_def.default_layer if fx_def.default_layer != StringName() else &"world_fx"
	var host: Node2D = _get_fx_host(layer_name)

	var fx_instance: Node2D = fx_def.fx_scene.instantiate() as Node2D
	if fx_instance == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"spawn_fx",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "fx_scene instantiate failed for %s" % String(fx_id),
		})
		return

	if host != null:
		host.add_child(fx_instance)
		fx_instance.global_position = spawn_pos
	else:
		# Fallback: add to target parent or root
		if _target != null and _target is Node2D:
			(_target as Node2D).add_child(fx_instance)
			fx_instance.global_position = spawn_pos
		else:
			fx_instance.queue_free()
			DebugService.record_visual_event({
				"cue_id": cue_id,
				"event_name": event_name,
				"action_type": &"spawn_fx",
				"target_id": target_id,
				"result": "no_op",
				"skip_reason": "no host or target for FX placement",
			})
			return

	# Auto-cleanup
	var lifetime: float = fx_def.default_lifetime if fx_def.default_lifetime > 0.0 else 1.0
	var tree := fx_instance.get_tree()
	if tree != null:
		tree.create_timer(lifetime).timeout.connect(fx_instance.queue_free, CONNECT_ONE_SHOT)

	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"spawn_fx",
		"target_id": target_id,
		"result": "executed",
	})


func _execute_play_audio(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target_id: int) -> void:
	# v1: no audio system, log request only
	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"play_audio",
		"target_id": target_id,
		"result": "no_op",
		"skip_reason": "audio system not yet implemented",
	})


func _execute_flash_actor(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target: Node, target_id: int) -> void:
	var actor_root := _resolve_actor_root(target)
	if actor_root == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"flash_actor",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "visual actor root is missing",
		})
		return

	var flash_color: Color = action.get("color", Color.WHITE)
	var flash_duration: float = float(action.get("duration", 0.1))

	var original_modulate: Color = actor_root.modulate
	actor_root.modulate = flash_color

	var tree := actor_root.get_tree()
	if tree != null:
		tree.create_timer(flash_duration).timeout.connect(_restore_modulate.bind(actor_root, original_modulate), CONNECT_ONE_SHOT)

	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"flash_actor",
		"target_id": target_id,
		"result": "executed",
	})


func _resolve_actor_root(target: Node) -> Node2D:
	if target == null:
		return null
	var visual_actor: Node = target.get_node_or_null("VisualActorComponent")
	if visual_actor != null and visual_actor.has_method("get_actor_root"):
		return visual_actor.call("get_actor_root") as Node2D
	return null


func _restore_modulate(target: Node2D, original_modulate: Color) -> void:
	if is_instance_valid(target):
		target.modulate = original_modulate


func _execute_play_actor_animation(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target: Node, target_id: int) -> void:
	_execute_visual_actor_command(
		action,
		cue_id,
		event_name,
		target,
		target_id,
		&"play_actor_animation",
		[&"animation_name", &"animation"],
		&"play_animation",
		"animation_name is empty",
		"animation '%s' is missing"
	)


func _execute_play_actor_action(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target: Node, target_id: int) -> void:
	_execute_visual_actor_command(
		action,
		cue_id,
		event_name,
		target,
		target_id,
		&"play_actor_action",
		[&"action_name", &"action"],
		&"play_action",
		"action_name is empty",
		"action '%s' is missing"
	)


func _execute_play_actor_action_sequence(action: Dictionary, event_data: Variant, cue_id: StringName, event_name: StringName, target: Node, target_id: int, target_archetype_id: StringName) -> void:
	var raw_steps: Variant = action.get("steps", [])
	if not (raw_steps is Array) or Array(raw_steps).is_empty():
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"play_actor_action_sequence",
			"target_id": target_id,
			"result": "skipped",
			"skip_reason": "steps are empty",
		})
		return

	var visual_actor := _resolve_visual_actor(target, &"play_action")
	if visual_actor == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"play_actor_action_sequence",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "visual actor component is missing",
		})
		return

	var actor_root := _resolve_actor_root(target)
	if actor_root == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"play_actor_action_sequence",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "visual actor root is missing",
		})
		return

	var original_local_position := actor_root.position
	var sequence_id := _action_value_as_string_name(action, &"sequence_id")
	var tree := actor_root.get_tree()
	for raw_step: Variant in Array(raw_steps):
		if not (raw_step is Dictionary):
			continue
		var step := Dictionary(raw_step).duplicate(true)
		var step_at := maxf(0.0, float(step.get("at", 0.0)))
		var callback := Callable(self, "_execute_actor_sequence_step").bind(
			actor_root,
			visual_actor,
			cue_id,
			event_name,
			target_id,
			target_archetype_id,
			action.duplicate(true),
			step,
			event_data,
			target,
			original_local_position,
			sequence_id,
			step_at
		)
		if step_at <= 0.0 or tree == null:
			callback.call()
		else:
			tree.create_timer(step_at).timeout.connect(callback, CONNECT_ONE_SHOT)


func _execute_actor_sequence_step(
	actor_root: Variant,
	visual_actor: Variant,
	cue_id: StringName,
	event_name: StringName,
	target_id: int,
	target_archetype_id: StringName,
	action: Dictionary,
	step: Dictionary,
	event_data: Variant,
	target: Variant,
	original_local_position: Vector2,
	sequence_id: StringName,
	step_at: float
) -> void:
	if not is_instance_valid(actor_root) or not (actor_root is Node2D):
		return
	if not is_instance_valid(visual_actor) or not (visual_actor is Node):
		return
	var actor_root_node := actor_root as Node2D
	var visual_actor_node := visual_actor as Node
	var target_node := _valid_node(target)

	var step_kind := _action_value_as_string_name(step, &"kind")
	match step_kind:
		&"actor_action":
			_execute_actor_sequence_action_step(actor_root_node, visual_actor_node, cue_id, event_name, target_id, target_archetype_id, step, event_data, target_node, sequence_id, step_at)
		&"motion":
			_execute_actor_sequence_motion_step(actor_root_node, visual_actor_node, cue_id, event_name, target_id, target_archetype_id, step, event_data, target_node, sequence_id, step_at)
		&"restore_position":
			actor_root_node.position = original_local_position
			_record_actor_sequence_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, step_kind, step_at, {
				"result": "executed",
			})
		_:
			_record_actor_sequence_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, step_kind, step_at, {
				"result": "skipped",
				"skip_reason": "unknown sequence step kind",
				"action_name": _first_string_name(step, [&"action_name", &"action"]),
			})


func _execute_actor_sequence_action_step(
	actor_root: Node2D,
	visual_actor: Node,
	cue_id: StringName,
	event_name: StringName,
	target_id: int,
	target_archetype_id: StringName,
	step: Dictionary,
	event_data: Variant,
	target: Node,
	sequence_id: StringName,
	step_at: float
) -> void:
	var command_name := _resolve_sequence_action_name(step, event_data, target, actor_root)
	if command_name == StringName():
		_record_actor_sequence_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, &"actor_action", step_at, {
			"result": "skipped",
			"skip_reason": "action_name is empty",
		})
		return

	var played: bool = visual_actor.call(&"play_action", command_name)
	var log_values := {
		"action_name": command_name,
	}
	if played:
		log_values["result"] = "executed"
	else:
		log_values["result"] = "no_op"
		log_values["skip_reason"] = "action '%s' is missing" % String(command_name)
	_record_actor_sequence_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, &"actor_action", step_at, log_values)


func _execute_actor_sequence_motion_step(
	actor_root: Node2D,
	visual_actor: Node,
	cue_id: StringName,
	event_name: StringName,
	target_id: int,
	target_archetype_id: StringName,
	step: Dictionary,
	event_data: Variant,
	target: Node,
	sequence_id: StringName,
	step_at: float
) -> void:
	var motion_position_ref := _first_string_name(step, [&"motion_position_ref", &"position_ref"])
	var motion_position := _resolve_position_ref_global_position(motion_position_ref, event_data, target)
	if not bool(motion_position.get("valid", false)):
		_record_actor_sequence_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, &"motion", step_at, {
			"result": "no_op",
			"skip_reason": "motion target is missing",
			"motion_position_ref": motion_position_ref,
		})
		return

	var destination := Vector2(motion_position.get("position", Vector2.ZERO)) + _action_value_as_vector2(step, &"motion_offset", _action_value_as_vector2(step, &"offset", Vector2.ZERO))
	var motion_distance := actor_root.global_position.distance_to(destination)
	var motion_duration := maxf(0.0, float(step.get("motion_duration", step.get("duration", 0.0))))
	if motion_duration <= 0.0:
		actor_root.global_position = destination
		_record_actor_sequence_motion_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, step_at, step, actor_root, destination, motion_position_ref, motion_duration, motion_distance)
		return

	var tween := actor_root.create_tween()
	if tween == null:
		actor_root.global_position = destination
		_record_actor_sequence_motion_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, step_at, step, actor_root, destination, motion_position_ref, motion_duration, motion_distance)
		return

	tween.tween_property(actor_root, "global_position", destination, motion_duration)
	_apply_tween_curve(tween, _action_value_as_string_name(step, &"curve"))
	tween.finished.connect(
		_finish_actor_sequence_motion_step.bind(cue_id, event_name, target_id, target_archetype_id, sequence_id, step_at, step, actor_root, destination, motion_position_ref, motion_duration, motion_distance),
		CONNECT_ONE_SHOT
	)


func _finish_actor_sequence_motion_step(
	cue_id: StringName,
	event_name: StringName,
	target_id: int,
	target_archetype_id: StringName,
	sequence_id: StringName,
	step_at: float,
	step: Dictionary,
	actor_root: Variant,
	destination: Vector2,
	motion_position_ref: StringName,
	motion_duration: float,
	motion_distance: float
) -> void:
	if not is_instance_valid(actor_root) or not (actor_root is Node2D):
		return
	var actor_root_node := actor_root as Node2D
	actor_root_node.global_position = destination
	_record_actor_sequence_motion_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, step_at, step, actor_root_node, destination, motion_position_ref, motion_duration, motion_distance)


func _record_actor_sequence_motion_event(
	cue_id: StringName,
	event_name: StringName,
	target_id: int,
	target_archetype_id: StringName,
	sequence_id: StringName,
	step_at: float,
	step: Dictionary,
	actor_root: Node2D,
	destination: Vector2,
	motion_position_ref: StringName,
	motion_duration: float,
	motion_distance: float
) -> void:
	_record_actor_sequence_event(cue_id, event_name, target_id, target_archetype_id, sequence_id, &"motion", step_at, {
		"result": "executed",
		"motion_position_ref": motion_position_ref,
		"motion_duration": motion_duration,
		"motion_offset": _action_value_as_vector2(step, &"motion_offset", _action_value_as_vector2(step, &"offset", Vector2.ZERO)),
		"motion_distance": motion_distance,
		"motion_target_distance": actor_root.global_position.distance_to(destination),
	})


func _record_actor_sequence_event(
	cue_id: StringName,
	event_name: StringName,
	target_id: int,
	target_archetype_id: StringName,
	sequence_id: StringName,
	step_kind: StringName,
	step_at: float,
	values: Dictionary
) -> void:
	var log_entry := {
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"play_actor_action_sequence",
		"target_id": target_id,
		"target_archetype_id": target_archetype_id,
		"sequence_id": sequence_id,
		"step_kind": step_kind,
		"step_at": step_at,
	}
	for key: Variant in values.keys():
		log_entry[key] = values[key]
	DebugService.record_visual_event(log_entry)


func _resolve_sequence_action_name(step: Dictionary, event_data: Variant, target: Node, actor_root: Node2D) -> StringName:
	var relative_actions: Variant = step.get("action_by_relative_x", {})
	if relative_actions is Dictionary:
		var position_ref := _first_string_name(step, [&"direction_position_ref", &"position_ref", &"motion_position_ref"])
		if position_ref == StringName():
			position_ref = &"target"
		var position_result := _resolve_position_ref_global_position(position_ref, event_data, target)
		if bool(position_result.get("valid", false)):
			var direction_key := &"left" if Vector2(position_result.get("position", Vector2.ZERO)).x < actor_root.global_position.x else &"right"
			var action_name := _dictionary_string_name(Dictionary(relative_actions), direction_key)
			if action_name != StringName():
				return action_name
	return _first_string_name(step, [&"action_name", &"action"])


func _dictionary_string_name(values: Dictionary, key: StringName) -> StringName:
	if values.has(key):
		return _variant_to_string_name(values[key])
	var string_key := String(key)
	if values.has(string_key):
		return _variant_to_string_name(values[string_key])
	return StringName()


func _variant_to_string_name(value: Variant) -> StringName:
	if value == null:
		return StringName()
	if value is StringName:
		return value
	return StringName(str(value))


func _apply_tween_curve(tween: Tween, curve: StringName) -> void:
	if tween == null:
		return
	match curve:
		&"ease_in_out":
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN_OUT)
		&"ease_in":
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN)
		&"ease_out":
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)


func _execute_play_actor_state(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target: Node, target_id: int) -> void:
	_execute_visual_actor_command(
		action,
		cue_id,
		event_name,
		target,
		target_id,
		&"play_actor_state",
		[&"state_id", &"state"],
		&"play_state",
		"state_id is empty",
		"state '%s' is missing"
	)


func _execute_visual_actor_command(
	action: Dictionary,
	cue_id: StringName,
	event_name: StringName,
	target: Node,
	target_id: int,
	action_type: StringName,
	value_keys: Array,
	method_name: StringName,
	empty_reason: String,
	missing_template: String
) -> void:
	var command_name := _first_string_name(action, value_keys)
	if command_name == StringName():
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": action_type,
			"target_id": target_id,
			"result": "skipped",
			"skip_reason": empty_reason,
		})
		return

	var visual_actor := _resolve_visual_actor(target, method_name)
	if visual_actor == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": action_type,
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "visual actor component is missing",
		})
		return

	var played: bool = visual_actor.call(method_name, command_name)
	if played:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": action_type,
			"target_id": target_id,
			"result": "executed",
		})
		return

	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": action_type,
		"target_id": target_id,
		"result": "no_op",
		"skip_reason": missing_template % String(command_name),
	})


func _first_string_name(action: Dictionary, keys: Array) -> StringName:
	for key: Variant in keys:
		var value_name := _action_value_as_string_name(action, key)
		if value_name != StringName():
			return value_name
	return StringName()


func _action_value_as_string_name(action: Dictionary, key: Variant) -> StringName:
	var value: Variant = null
	if action.has(key):
		value = action[key]
	else:
		var string_key := str(key)
		if action.has(string_key):
			value = action[string_key]
	if value == null:
		return StringName()
	if value is StringName:
		return value
	return StringName(str(value))


func _action_value_as_vector2(action: Dictionary, key: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value: Variant = null
	if action.has(key):
		value = action[key]
	else:
		var string_key := str(key)
		if action.has(string_key):
			value = action[string_key]
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback


func _resolve_position_ref_global_position(position_ref: StringName, event_data: Variant, fallback_target: Node) -> Dictionary:
	if event_data == null:
		return _node_global_position_result(fallback_target)
	var core: Dictionary = event_data.core
	match position_ref:
		&"source":
			return _node_global_position_result(core.get("source_node", null))
		&"target":
			return _node_global_position_result(core.get("target_node", null))
		&"impact_position":
			if core.has("impact_position"):
				return {
					"valid": true,
					"position": _variant_to_vector2(core.get("impact_position"), Vector2.ZERO),
				}
			return {"valid": false, "position": Vector2.ZERO}
		_:
			return _node_global_position_result(fallback_target)


func _node_global_position_result(node: Variant) -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {"valid": false, "position": Vector2.ZERO}
	if node is Node2D:
		return {
			"valid": true,
			"position": (node as Node2D).global_position,
		}
	return {"valid": false, "position": Vector2.ZERO}


func _variant_to_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback


func _resolve_visual_actor(target: Node, method_name: StringName) -> Node:
	if target == null:
		return null
	var visual_actor: Node = target.get_node_or_null("VisualActorComponent")
	if visual_actor != null and visual_actor.has_method(method_name):
		return visual_actor
	return null


func _execute_attach_fx(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target_id: int) -> void:
	var target: Node = _resolve_target(action, _event_data)
	if target == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"attach_fx",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "target node is null",
		})
		return

	var fx_id: StringName = action.get("fx_id", &"")
	if fx_id == StringName():
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"attach_fx",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "fx_id is empty",
		})
		return

	var fx_def = VisualFxRegistry.get_def(fx_id)
	if fx_def == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"attach_fx",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "FX def not found for %s" % String(fx_id),
		})
		return

	if fx_def.fx_scene == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"attach_fx",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "fx_scene is null for %s" % String(fx_id),
		})
		return

	# Resolve parent: Sockets/socket_id or target directly
	var socket_id: StringName = action.get("socket_id", &"")
	var parent: Node2D = _resolve_attach_parent(target, socket_id)
	if parent == null:
		parent = target as Node2D

	var fx_instance: Node2D = fx_def.fx_scene.instantiate() as Node2D
	if fx_instance == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"attach_fx",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "fx_scene instantiate failed",
		})
		return

	parent.add_child(fx_instance)

	var lifetime: float = float(fx_def.default_lifetime) if fx_def.default_lifetime > 0.0 else 1.0
	var tree := parent.get_tree()
	if tree != null:
		tree.create_timer(lifetime).timeout.connect(fx_instance.queue_free, CONNECT_ONE_SHOT)

	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"attach_fx",
		"target_id": target_id,
		"result": "executed",
	})


func _resolve_attach_parent(target: Node, socket_id: StringName) -> Node2D:
	if socket_id == StringName():
		return null
	var sockets: Node = target.get_node_or_null("VisualActorComponent/ActorRoot/Sockets")
	if sockets == null:
		return null
	return sockets.get_node_or_null(NodePath(socket_id)) as Node2D


func _execute_screen_overlay(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName) -> void:
	var overlay_color: Color = action.get("color", Color(0, 0, 0, 0.4))
	var duration: float = float(action.get("duration", 0.5))
	var fade_in_time: float = float(action.get("fade_in", 0.1))
	var fade_out_time: float = float(action.get("fade_out", 0.3))

	# Screen overlay needs a CanvasLayer to cover the viewport
	var canvas := CanvasLayer.new()
	canvas.layer = 90  # Above world, below UI
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"screen_overlay",
			"target_id": -1,
			"result": "no_op",
			"skip_reason": "scene tree not available",
		})
		return
	tree.root.add_child(canvas)

	var rect := ColorRect.new()
	rect.color = Color(overlay_color.r, overlay_color.g, overlay_color.b, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rect)

	var tween := rect.create_tween()
	if tween != null:
		tween.tween_property(rect, "color:a", overlay_color.a, fade_in_time)
		tween.tween_interval(duration)
		tween.tween_property(rect, "color:a", 0.0, fade_out_time)
		tween.tween_callback(canvas.queue_free)
	else:
		canvas.queue_free()

	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"screen_overlay",
		"target_id": -1,
		"result": "executed",
	})


func _resolve_spawn_position(action: Dictionary, event_data: Variant, target: Node) -> Vector2:
	# Priority: action position > target position > source position > origin
	if action.has("position"):
		return action["position"]
	var target_node := _valid_node(target)
	if target_node is Node2D:
		return (target_node as Node2D).global_position
	if event_data != null:
		var core: Dictionary = event_data.core
		var source := _valid_node(core.get("source_node", null))
		if source is Node2D:
			return (source as Node2D).global_position
	return Vector2.ZERO


func _get_fx_host(layer_name: StringName) -> Node2D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root := tree.current_scene
	if root == null:
		return null
	var host_name: StringName = _layer_to_host_name(layer_name)
	var host := root.find_child(String(host_name), false, false)
	if host != null and host is Node2D:
		return host as Node2D
	return null


func _layer_to_host_name(layer_name: StringName) -> StringName:
	match layer_name:
		&"ground":
			return &"GroundLayer"
		&"shadow":
			return &"ShadowLayer"
		&"field_object":
			return &"FieldObjectLayer"
		&"plant", &"zombie":
			return &"EntityLayer"
		&"projectile":
			return &"ProjectileLayer"
		&"world_fx":
			return &"WorldFxLayer"
		&"fog_weather":
			return &"FogWeatherLayer"
		&"preview":
			return &"PreviewLayer"
		&"screen_fx":
			return &"ScreenFxLayer"
		&"ui":
			return &"UiLayer"
		_:
			return &"WorldFxLayer"
