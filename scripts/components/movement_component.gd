extends Node
class_name MovementComponent

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

@export var velocity := Vector2.ZERO
var contributions: Array[Dictionary] = []
var final_velocity := Vector2.ZERO
var movement_spec: Dictionary = {}
var blackboard: Dictionary = {}
var _pending_overrides: Array[Dictionary] = []
var _pending_impulses: Array[Dictionary] = []


func add_contribution(delta_velocity: Vector2, contribution_id: StringName = StringName()) -> void:
	contributions.append({
		"id": contribution_id,
		"velocity": delta_velocity,
	})


func clear_contributions() -> void:
	contributions.clear()


func get_final_velocity() -> Vector2:
	return final_velocity


func bind_movement_spec(spec: Dictionary) -> void:
	movement_spec = spec.duplicate(true)
	blackboard.clear()
	var owner := get_parent()
	if owner != null and owner.has_method("set_state_value"):
		owner.call("set_state_value", &"movement_spec", movement_spec.duplicate(true))


func has_movement_spec() -> bool:
	return not movement_spec.is_empty()


func submit_command(command: Dictionary) -> void:
	var command_kind := StringName(command.get("command_kind", &"override"))
	match command_kind:
		&"impulse":
			_pending_impulses.append(command.duplicate(true))
		_:
			_pending_overrides.append(command.duplicate(true))


func physics_process_movement(body: Node2D, delta: float) -> void:
	physics_process_entity_movement(body, delta, velocity, &"legacy", false)


func physics_process_entity_movement(
	body: Node2D,
	delta: float,
	fallback_velocity: Vector2 = Vector2.ZERO,
	fallback_source_id: StringName = &"legacy",
	apply_status_modifier := true
) -> void:
	if body == null:
		return
	var command := _build_base_command(body, delta, fallback_velocity, fallback_source_id)
	if body.has_method("is_liveness_enabled") and not bool(body.call("is_liveness_enabled", &"movement")):
		command["ground_velocity"] = Vector2.ZERO
		command["pause_reason"] = &"movement_disabled"
		command["source_id"] = &"liveness"
	command = _merge_state_overrides(command)
	final_velocity = Vector2(command.get("ground_velocity", Vector2.ZERO))
	for contribution: Dictionary in contributions:
		final_velocity += Vector2(contribution.get("velocity", Vector2.ZERO))
	if apply_status_modifier and body.has_method("get_effective_movement_scale"):
		final_velocity *= float(body.call("get_effective_movement_scale"))
	for impulse: Dictionary in _pending_impulses:
		final_velocity += Vector2(impulse.get("ground_velocity", impulse.get("velocity", Vector2.ZERO)))

	body.position += final_velocity * delta
	var motion_state := _integrate_height(body, command, delta)
	if bool(motion_state.get("ground_contact", true)):
		_apply_terrain_ground_follow(body)
	if body != null and body.has_method("set_state_value"):
		body.call("set_state_value", &"velocity", final_velocity)
		body.call("set_state_value", &"speed", final_velocity.length())
	if body != null and body.has_method("set_motion_state"):
		body.call(
			"set_motion_state",
			float(motion_state.get("height", 0.0)),
			float(motion_state.get("height_velocity", 0.0)),
			bool(motion_state.get("ground_contact", true)),
			StringName(motion_state.get("exposure_state", &"ground")),
			StringName(command.get("source_id", fallback_source_id)),
			StringName(command.get("pause_reason", StringName()))
		)
	elif body != null and body.has_method("sync_runtime_state"):
		body.call("sync_runtime_state")
	clear_contributions()
	_pending_overrides.clear()
	_pending_impulses.clear()


func _build_base_command(body: Node2D, delta: float, fallback_velocity: Vector2, fallback_source_id: StringName) -> Dictionary:
	if not movement_spec.is_empty():
		var movement_id := StringName(movement_spec.get("movement_id", &"core.walk"))
		if typeof(MovementRegistry) != TYPE_NIL and MovementRegistry.has_method("build_command"):
			var built: Dictionary = MovementRegistry.build_command(movement_id, body, movement_spec, delta, blackboard)
			if not built.is_empty():
				return built
	var exposure_state := &"ground"
	var ground_contact := true
	if body.has_method("get_exposure_state"):
		exposure_state = StringName(body.call("get_exposure_state"))
	if body.has_method("is_ground_contact"):
		ground_contact = bool(body.call("is_ground_contact"))
	return {
		"source_id": fallback_source_id,
		"command_kind": &"base",
		"ground_velocity": fallback_velocity,
		"ground_contact": ground_contact,
		"exposure_state": exposure_state,
		"pause_reason": StringName(),
	}


func _merge_state_overrides(command: Dictionary) -> Dictionary:
	if _pending_overrides.is_empty():
		return command
	var merged := command.duplicate(true)
	for override: Dictionary in _pending_overrides:
		for key: Variant in override.keys():
			if StringName(key) == &"command_kind":
				continue
			merged[key] = override[key]
	return merged


func _integrate_height(body: Node2D, command: Dictionary, delta: float) -> Dictionary:
	var height := 0.0
	var height_velocity := 0.0
	var previous_ground_contact := true
	var previous_exposure := &"ground"
	if body.has_method("get_height"):
		height = float(body.call("get_height"))
	if body.has_method("get_height_velocity"):
		height_velocity = float(body.call("get_height_velocity"))
	if body.has_method("is_ground_contact"):
		previous_ground_contact = bool(body.call("is_ground_contact"))
	if body.has_method("get_exposure_state"):
		previous_exposure = StringName(body.call("get_exposure_state"))
	var ground_contact := bool(command.get("ground_contact", previous_ground_contact))
	var exposure_state := StringName(command.get("exposure_state", previous_exposure))
	if command.has("height"):
		height = maxf(float(command.get("height", height)), 0.0)
	if command.has("height_velocity"):
		height_velocity = float(command.get("height_velocity", height_velocity))
	var should_integrate_z := height > 0.001 or absf(height_velocity) > 0.001 or not ground_contact
	if should_integrate_z:
		height += height_velocity * delta
		height_velocity += float(command.get("gravity", -520.0)) * delta
		if height <= 0.0 and height_velocity <= 0.0:
			height = 0.0
			height_velocity = 0.0
			ground_contact = true
			if exposure_state == &"airborne":
				exposure_state = &"ground"
			if not previous_ground_contact:
				_emit_landed(body)
		else:
			ground_contact = false
			if exposure_state == &"ground":
				exposure_state = &"airborne"
	elif ground_contact:
		height = 0.0
		height_velocity = 0.0
	return {
		"height": height,
		"height_velocity": height_velocity,
		"ground_contact": ground_contact,
		"exposure_state": exposure_state,
	}


func _emit_landed(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return
	var landed_event: Variant = EventDataRef.create(body, body, null, PackedStringArray(["movement", "landed"]))
	landed_event.core["height"] = 0.0
	EventBus.push_event(&"entity.landed", landed_event)


func _apply_terrain_ground_follow(body: Node2D) -> void:
	if body == null or absf(final_velocity.y) > 0.001:
		return
	var lane_value: Variant = body.get("lane_id")
	if not (lane_value is int) or int(lane_value) < 0:
		return
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("get_battlefield_metrics"):
		return
	var metrics: Variant = battle.call("get_battlefield_metrics")
	if metrics == null or not metrics.has_method("ground_position_for"):
		return
	body.position = Vector2(metrics.call("ground_position_for", int(lane_value), body.position.x))
