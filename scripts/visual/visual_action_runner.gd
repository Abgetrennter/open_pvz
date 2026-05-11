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


func _execute_play_actor_animation(action: Dictionary, _event_data: Variant, cue_id: StringName, event_name: StringName, target_id: int) -> void:
	var target: Node = _resolve_target(action, _event_data)
	if target == null:
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"play_actor_animation",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "target node is null",
		})
		return

	var animation_name: StringName = action.get("animation", &"")
	if animation_name == StringName():
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"play_actor_animation",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "animation name is empty",
		})
		return

	var actor_component: Node = target.get_node_or_null("VisualActorComponent")
	if actor_component == null or not actor_component.has_method("_play_animation"):
		DebugService.record_visual_event({
			"cue_id": cue_id,
			"event_name": event_name,
			"action_type": &"play_actor_animation",
			"target_id": target_id,
			"result": "no_op",
			"skip_reason": "VisualActorComponent not found or missing _play_animation",
		})
		return

	actor_component.call("_play_animation", animation_name)
	DebugService.record_visual_event({
		"cue_id": cue_id,
		"event_name": event_name,
		"action_type": &"play_actor_animation",
		"target_id": target_id,
		"result": "executed",
	})


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
	if target != null and target is Node2D:
		return (target as Node2D).global_position
	if event_data != null:
		var core: Dictionary = event_data.core
		var source: Node = core.get("source_node", null)
		if source != null and source is Node2D:
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
