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
	_apply_terrain_ground_follow(body)
	if body != null and body.has_method("set_state_value"):
		body.call("set_state_value", &"velocity", final_velocity)
		body.call("set_state_value", &"speed", final_velocity.length())
		body.call("sync_runtime_state")
	clear_contributions()


func _apply_terrain_ground_follow(body: Node2D) -> void:
	if body == null or absf(final_velocity.y) > 0.001:
		return
	var lane_value: Variant = body.get("lane_id")
	if not (lane_value is int) or int(lane_value) < 0:
		return
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("get_battlefield_metrics"):
		return
	var metrics: Variant = battle.call("get_battlefield_metrics")
	if metrics == null or not metrics.has_method("ground_position_for"):
		return
	body.position = Vector2(metrics.call("ground_position_for", int(lane_value), body.position.x))
