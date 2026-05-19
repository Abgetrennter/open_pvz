extends Node
class_name ProjectileMovementBase

const ProjectileMoveResultRef = preload("res://scripts/projectile/projectile_move_result.gd")

var projectile: Node2D = null
var move_mode: StringName = &"linear"
var flight_height := 0.0
var height_reference: StringName = &"terrain_follow"
var _launch_terrain_z := 0.0


func _ready() -> void:
	if get_parent() is Node2D:
		projectile = get_parent() as Node2D


func configure_movement(params: Dictionary) -> void:
	move_mode = StringName(params.get("move_mode", &"linear"))
	flight_height = float(params.get("flight_height", 0.0))
	height_reference = StringName(params.get("height_reference", &"terrain_follow"))
	var launch_position := Vector2(params.get("start_position", _projectile_ground_position()))
	_launch_terrain_z = _terrain_elevation_at(launch_position)


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


func _projectile_absolute_z() -> float:
	return _terrain_elevation_at(_projectile_ground_position()) + _projectile_height()


func _apply_projectile_motion_state(ground_position: Vector2, height: float) -> void:
	if projectile == null:
		return
	if projectile.has_method("set_projected_motion_state"):
		projectile.call("set_projected_motion_state", ground_position, height)
		return
	projectile.global_position = ground_position


func _height_above_ground_for_absolute(ground_position: Vector2, absolute_z: float) -> float:
	return maxf(absolute_z - _terrain_elevation_at(ground_position), 0.0)


func _terrain_follow_height(_ground_position: Vector2) -> float:
	return flight_height


func _launch_absolute_height(ground_position: Vector2) -> float:
	return _height_above_ground_for_absolute(ground_position, _launch_terrain_z + flight_height)


func _advance_ground_position(previous_position: Vector2, delta_position: Vector2) -> Vector2:
	var raw_position := previous_position + delta_position
	if absf(delta_position.y) > 0.001:
		return raw_position
	var lane_ground_previous := _ground_position_for_lane_x(previous_position.x, previous_position.y)
	var lane_ground_current := _ground_position_for_lane_x(raw_position.x, raw_position.y)
	var lateral_y := raw_position.y - lane_ground_previous.y
	return Vector2(raw_position.x, lane_ground_current.y + lateral_y)


func _ground_position_for_lane_x(x: float, fallback_y: float) -> Vector2:
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("get_battlefield_metrics"):
		return Vector2(x, fallback_y)
	var metrics: Variant = battle.call("get_battlefield_metrics")
	if metrics == null or not metrics.has_method("ground_position_for"):
		return Vector2(x, fallback_y)
	var lane_id := _projectile_lane_id()
	if lane_id < 0:
		return Vector2(x, fallback_y)
	return Vector2(metrics.call("ground_position_for", lane_id, x))


func _terrain_elevation_at(ground_position: Vector2) -> float:
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("get_battlefield_metrics"):
		return 0.0
	var metrics: Variant = battle.call("get_battlefield_metrics")
	if metrics == null or not metrics.has_method("terrain_elevation_at"):
		return 0.0
	var lane_id := _projectile_lane_id()
	if lane_id < 0:
		return 0.0
	return float(metrics.call("terrain_elevation_at", lane_id, ground_position.x))


func _projectile_lane_id() -> int:
	if projectile == null:
		return -1
	var lane_value: Variant = projectile.get("lane_id")
	if lane_value is int:
		return int(lane_value)
	return -1


func _node_ground_position(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return node.global_position
