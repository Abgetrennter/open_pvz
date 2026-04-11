extends "res://scripts/projectile/movement/projectile_movement_base.gd"
class_name ProjectileMovementLinear

var direction := Vector2.RIGHT
var speed := 0.0


func configure_movement(params: Dictionary) -> void:
	super(params)
	var direction_value: Variant = params.get("direction", Vector2.RIGHT)
	if direction_value is Vector2:
		direction = direction_value.normalized()
	else:
		direction = Vector2.RIGHT
	speed = float(params.get("speed", 0.0))


func physics_process_projectile_move(delta: float):
	if projectile == null:
		return _build_move_result(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, false, &"missing_projectile")
	var previous_position: Vector2 = _projectile_ground_position()
	var current_position := previous_position + direction * speed * delta
	_apply_projectile_motion_state(current_position, 0.0)
	if projectile.has_method("set_state_value"):
		projectile.call("set_state_value", &"velocity", direction * speed)
		projectile.call("set_state_value", &"speed", speed)
		projectile.call("sync_runtime_state")
	return _build_move_result(previous_position, current_position, 0.0, 0.0, true)
