extends Node
class_name ProjectileMovementBase

const ProjectileMoveResultRef = preload("res://scripts/projectile/projectile_move_result.gd")

var projectile: Node2D = null
var move_mode: StringName = &"linear"
var flight_height := 0.0


func _ready() -> void:
	if get_parent() is Node2D:
		projectile = get_parent() as Node2D


func configure_movement(params: Dictionary) -> void:
	move_mode = StringName(params.get("move_mode", &"linear"))
	flight_height = float(params.get("flight_height", 0.0))


func physics_process_projectile_move(_delta: float):
	var current_position := _projectile_ground_position()
	var current_height := _projectile_height()
	if projectile != null and projectile.has_method("sync_runtime_state"):
		projectile.call("sync_runtime_state")
	return _build_move_result(current_position, current_position, current_height, current_height, true)


func _build_move_result(
	previous_position: Vector2,
	current_position: Vector2,
	previous_height: float,
	current_height: float,
	still_active: bool,
	terminal_reason: StringName = StringName()
):
	var result = ProjectileMoveResultRef.new()
	result.previous_position = previous_position
	result.current_position = current_position
	result.previous_height = previous_height
	result.current_height = current_height
	result.still_active = still_active
	result.terminal_reason = terminal_reason
	return result


func _projectile_ground_position() -> Vector2:
	if projectile == null:
		return Vector2.ZERO
	if projectile.has_method("get_ground_position"):
		return Vector2(projectile.call("get_ground_position"))
	return projectile.global_position


func _projectile_height() -> float:
	if projectile == null:
		return 0.0
	if projectile.has_method("get_height"):
		return float(projectile.call("get_height"))
	return 0.0


func _apply_projectile_motion_state(ground_position: Vector2, height: float) -> void:
	if projectile == null:
		return
	if projectile.has_method("set_projected_motion_state"):
		projectile.call("set_projected_motion_state", ground_position, height)
		return
	projectile.global_position = ground_position


func _node_ground_position(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return node.global_position
