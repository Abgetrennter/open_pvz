extends "res://scripts/projectile/movement/projectile_movement_base.gd"
class_name ProjectileMovementParabola

var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var travel_duration := 0.6
var arc_height := 72.0
var elapsed_time := 0.0


func configure_movement(params: Dictionary) -> void:
	super(params)
	start_position = params.get("start_position", Vector2.ZERO)
	target_position = params.get("target_position", start_position)
	travel_duration = max(float(params.get("travel_duration", 0.6)), 0.01)
	arc_height = float(params.get("arc_height", 72.0))
	elapsed_time = 0.0
	if projectile != null:
		projectile.position = start_position


func physics_process_projectile_move(delta: float) -> bool:
	if projectile == null:
		return false

	elapsed_time += delta
	var progress: float = clamp(elapsed_time / travel_duration, 0.0, 1.0)
	var base_position: Vector2 = start_position.lerp(target_position, progress)
	var arc_offset := -4.0 * arc_height * progress * (1.0 - progress)
	projectile.position = base_position + Vector2(0.0, arc_offset)
	if projectile.has_method("set_state_value"):
		projectile.call("set_state_value", &"travel_progress", progress)
		projectile.call("set_state_value", &"speed", start_position.distance_to(target_position) / travel_duration)
		projectile.call("sync_runtime_state")
	return progress < 1.0
