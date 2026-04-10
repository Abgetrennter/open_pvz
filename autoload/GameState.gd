extends Node

var current_battle: Node = null
var current_time := 0.0

var _next_entity_id := 1


func next_entity_id() -> int:
	var entity_id := _next_entity_id
	_next_entity_id += 1
	return entity_id


func advance_time(delta: float) -> void:
	current_time += delta
