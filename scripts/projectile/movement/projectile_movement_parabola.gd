extends "res://scripts/projectile/movement/projectile_movement_base.gd"
class_name ProjectileMovementParabola

var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var target_node: Node2D = null
var _dynamic_target_adjustment := 0.0
var _dynamic_target_axis: StringName = &"x"
var _lead_time_scale := 1.0
var travel_duration := 0.6
var arc_height := 72.0
var elapsed_time := 0.0


func configure_movement(params: Dictionary) -> void:
	super(params)
	start_position = params.get("start_position", Vector2.ZERO)
	target_position = params.get("target_position", start_position)
	target_node = params.get("target_node", null) as Node2D
	_dynamic_target_adjustment = maxf(float(params.get("dynamic_target_adjustment", 0.0)), 0.0)
	_dynamic_target_axis = StringName(params.get("dynamic_target_axis", &"x"))
	_lead_time_scale = float(params.get("lead_time_scale", 1.0))
	travel_duration = max(float(params.get("travel_duration", 0.6)), 0.01)
	arc_height = float(params.get("arc_height", 72.0))
	elapsed_time = 0.0
	if projectile != null:
		projectile.position = start_position


func physics_process_projectile_move(delta: float):
	if projectile == null:
		return _build_move_result(Vector2.ZERO, Vector2.ZERO, false, &"missing_projectile")
	var previous_position: Vector2 = projectile.global_position

	elapsed_time += delta
	_update_target_position()
	var progress: float = clamp(elapsed_time / travel_duration, 0.0, 1.0)
	var base_position: Vector2 = start_position.lerp(target_position, progress)
	var arc_offset := -4.0 * arc_height * progress * (1.0 - progress)
	projectile.position = base_position + Vector2(0.0, arc_offset)
	if projectile.has_method("set_state_value"):
		projectile.call("set_state_value", &"travel_progress", progress)
		projectile.call("set_state_value", &"speed", start_position.distance_to(target_position) / travel_duration)
		projectile.call("set_state_value", &"target_position", target_position)
		projectile.call("sync_runtime_state")
	return _build_move_result(previous_position, projectile.global_position, progress < 1.0, &"movement_complete")


func _update_target_position() -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	if target_node.has_method("is_combat_active") and not target_node.call("is_combat_active"):
		return

	var live_target_position: Vector2 = target_node.global_position
	var remaining_time := maxf(travel_duration - elapsed_time, 0.0)
	var live_offset := _estimate_target_velocity() * remaining_time * _lead_time_scale
	match _dynamic_target_axis:
		&"x":
			live_offset = Vector2(clampf(live_offset.x, -_dynamic_target_adjustment, _dynamic_target_adjustment), 0.0)
		&"y":
			live_offset = Vector2(0.0, clampf(live_offset.y, -_dynamic_target_adjustment, _dynamic_target_adjustment))
		_:
			if live_offset.length() > _dynamic_target_adjustment and _dynamic_target_adjustment > 0.0:
				live_offset = live_offset.normalized() * _dynamic_target_adjustment

	target_position = live_target_position + live_offset


func _estimate_target_velocity() -> Vector2:
	if target_node == null:
		return Vector2.ZERO
	if target_node.has_method("get_entity_state"):
		var snapshot: Dictionary = target_node.call("get_entity_state")
		var values: Dictionary = snapshot.get("values", {})
		var velocity_value: Variant = values.get("velocity", Vector2.ZERO)
		if velocity_value is Vector2:
			return velocity_value
	if target_node.has_method("get") and target_node.get("team") == &"zombie":
		var move_speed_value: Variant = target_node.get("move_speed")
		if move_speed_value is float or move_speed_value is int:
			return Vector2.LEFT * float(move_speed_value)
	return Vector2.ZERO
