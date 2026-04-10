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


func physics_process_projectile_move(delta: float) -> bool:
	if projectile == null:
		return false
	projectile.position += direction * speed * delta
	return true
