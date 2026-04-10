extends Node
class_name MovementComponent

@export var velocity := Vector2.ZERO
var contributions: Array[Vector2] = []


func add_contribution(delta_velocity: Vector2) -> void:
	contributions.append(delta_velocity)


func clear_contributions() -> void:
	contributions.clear()


func physics_process_movement(body: Node2D, delta: float) -> void:
	var final_velocity := velocity
	for contribution: Vector2 in contributions:
		final_velocity += contribution

	body.position += final_velocity * delta
	clear_contributions()
