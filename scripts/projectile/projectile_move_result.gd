extends RefCounted
class_name ProjectileMoveResult

var previous_position := Vector2.ZERO
var current_position := Vector2.ZERO
var previous_height := 0.0
var current_height := 0.0
var still_active := true
var terminal_reason: StringName = StringName()


func traveled_distance() -> float:
	return previous_position.distance_to(current_position)
