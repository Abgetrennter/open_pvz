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

	if action_type == &"spawn_fx":
		_execute_spawn_fx(action, event_data, cue_id, event_name, target, target_id)
	elif action_type == &"play_audio":
		_execute_play_audio(action, event_data, cue_id, event_name, target_id)
	elif action_type == &"flash_actor":
		_execute_flash_actor(action, event_data, cue_id, event_name, target, target_id)
	elif action_type == &"play_actor_animation":
		_execute_play_actor_animation(action, event_data, cue_id, event_name, target_id)
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

	# v1: log only — future implementation will instantiate fx_scene
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


func _execute_play_actor_animation(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target_id: int) -> void:
	# v1: no animation system integration, log request only
	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"play_actor_animation",
		"target_id": target_id,
		"result": "no_op",
		"skip_reason": "animation player wiring not yet implemented",
	})


func _execute_attach_fx(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target_id: int) -> void:
	# v1: no-op skeleton
	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"attach_fx",
		"target_id": target_id,
		"result": "no_op",
		"skip_reason": "attach_fx not yet implemented",
	})


func _execute_screen_overlay(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName) -> void:
	# v1: no-op skeleton
	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"screen_overlay",
		"target_id": -1,
		"result": "no_op",
		"skip_reason": "screen_overlay not yet implemented",
	})
