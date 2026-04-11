extends Node
class_name MovementComponent

@export var velocity := Vector2.ZERO
var contributions: Array[Dictionary] = []
var final_velocity := Vector2.ZERO


func add_contribution(delta_velocity: Vector2, contribution_id: StringName = StringName()) -> void:
	contributions.append({
		"id": contribution_id,
		"velocity": delta_velocity,
	})


func clear_contributions() -> void:
	contributions.clear()


func get_final_velocity() -> Vector2:
	return final_velocity


func physics_process_movement(body: Node2D, delta: float) -> void:
	final_velocity = velocity
	for contribution: Dictionary in contributions:
		final_velocity += Vector2(contribution.get("velocity", Vector2.ZERO))

	body.position += final_velocity * delta
	if body != null and body.has_method("set_state_value"):
		body.call("set_state_value", &"velocity", final_velocity)
		body.call("set_state_value", &"speed", final_velocity.length())
		body.call("sync_runtime_state")
	clear_contributions()
