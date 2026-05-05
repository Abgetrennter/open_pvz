extends "res://scripts/projectile/movement/projectile_movement_base.gd"
class_name MyPackProjectileMovementZigzag

var direction := Vector2.RIGHT
var speed := 0.0
var amplitude := 24.0
var frequency := 4.0
var _origin_position := Vector2.ZERO
var _elapsed_time := 0.0
var _travel_distance := 0.0


func configure_movement(params: Dictionary) -> void:
	super(params)
	var direction_value: Variant = params.get("direction", Vector2.RIGHT)
	if direction_value is Vector2 and direction_value.length_squared() > 0.001:
		direction = direction_value.normalized()
	else:
		direction = Vector2.RIGHT
	speed = float(params.get("speed", 0.0))
	amplitude = float(params.get("amplitude", 24.0))
	frequency = float(params.get("frequency", 4.0))
	_origin_position = params.get("start_position", _projectile_ground_position())
	_elapsed_time = 0.0
	_travel_distance = 0.0


func physics_process_projectile_move(delta: float):
	if projectile == null:
		return _build_move_result(Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, false, &"missing_projectile")
	var previous_position: Vector2 = _projectile_ground_position()
	var previous_height := _projectile_height()
	_elapsed_time += delta
	_travel_distance += speed * delta
	var forward := direction * _travel_distance
	var side := Vector2(-direction.y, direction.x) * sin(_elapsed_time * TAU * frequency) * amplitude
	var current_position := _origin_position + forward + side
	_apply_projectile_motion_state(current_position, flight_height)
	if projectile.has_method("set_state_value"):
		projectile.call("set_state_value", &"velocity", direction * speed)
		projectile.call("set_state_value", &"speed", speed)
		projectile.call("set_state_value", &"zigzag_amplitude", amplitude)
		projectile.call("set_state_value", &"zigzag_frequency", frequency)
		projectile.call("sync_runtime_state")
	return _build_move_result(previous_position, current_position, previous_height, flight_height, true)
