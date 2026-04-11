extends Node
class_name ProjectileMovementBase

const ProjectileMoveResultRef = preload("res://scripts/projectile/projectile_move_result.gd")

var projectile: Node2D = null
var move_mode: StringName = &"linear"


func _ready() -> void:
	if get_parent() is Node2D:
		projectile = get_parent() as Node2D


func configure_movement(params: Dictionary) -> void:
	move_mode = StringName(params.get("move_mode", &"linear"))


func physics_process_projectile_move(_delta: float):
	var current_position := Vector2.ZERO if projectile == null else projectile.global_position
	if projectile != null and projectile.has_method("sync_runtime_state"):
		projectile.call("sync_runtime_state")
	return _build_move_result(current_position, current_position, true)


func _build_move_result(
	previous_position: Vector2,
	current_position: Vector2,
	still_active: bool,
	terminal_reason: StringName = StringName()
):
	var result = ProjectileMoveResultRef.new()
	result.previous_position = previous_position
	result.current_position = current_position
	result.still_active = still_active
	result.terminal_reason = terminal_reason
	return result
