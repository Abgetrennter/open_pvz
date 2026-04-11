extends Node
class_name ProjectileMovementBase

var projectile: Node2D = null
var move_mode: StringName = &"linear"


func _ready() -> void:
	if get_parent() is Node2D:
		projectile = get_parent() as Node2D


func configure_movement(params: Dictionary) -> void:
	move_mode = StringName(params.get("move_mode", &"linear"))


func physics_process_projectile_move(_delta: float) -> bool:
	if projectile != null and projectile.has_method("sync_runtime_state"):
		projectile.call("sync_runtime_state")
	return true
