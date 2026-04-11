extends "res://scripts/projectile/movement/projectile_movement_base.gd"
class_name ProjectileMovementTrack

var direction := Vector2.RIGHT
var speed := 0.0
var turn_rate := 6.0
var target_node: Node2D = null


func configure_movement(params: Dictionary) -> void:
	super(params)
	var direction_value: Variant = params.get("direction", Vector2.RIGHT)
	if direction_value is Vector2:
		direction = direction_value.normalized()
	else:
		direction = Vector2.RIGHT
	speed = float(params.get("speed", 0.0))
	turn_rate = float(params.get("turn_rate", 6.0))
	var target_value: Variant = params.get("target_node", null)
	target_node = target_value as Node2D


func physics_process_projectile_move(delta: float):
	if projectile == null:
		return _build_move_result(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, false, &"missing_projectile")
	var previous_position: Vector2 = _projectile_ground_position()

	if is_instance_valid(target_node):
		var to_target: Vector2 = _node_ground_position(target_node) - previous_position
		if to_target.length_squared() > 0.001:
			var desired_direction: Vector2 = to_target.normalized()
			var weight: float = clamp(turn_rate * delta, 0.0, 1.0)
			direction = direction.slerp(desired_direction, weight).normalized()

	var current_position := previous_position + direction * speed * delta
	_apply_projectile_motion_state(current_position, 0.0)
	if projectile.has_method("set_state_value"):
		projectile.call("set_state_value", &"velocity", direction * speed)
		projectile.call("set_state_value", &"speed", speed)
		projectile.call("set_state_value", &"tracking_target", -1 if target_node == null or not target_node.has_method("get_entity_id") else int(target_node.call("get_entity_id")))
		projectile.call("sync_runtime_state")
	return _build_move_result(previous_position, current_position, 0.0, 0.0, true)
