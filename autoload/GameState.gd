extends Node

var current_battle: Node = null
var current_time := 0.0

var _next_entity_id := 1


func reset_runtime() -> void:
	current_battle = null
	current_time = 0.0
	_next_entity_id = 1


func begin_battle(battle: Node) -> void:
	current_battle = battle
	current_time = 0.0
	_next_entity_id = 1


func end_battle(battle: Node) -> void:
	if current_battle == battle:
		current_battle = null


func next_entity_id() -> int:
	var entity_id := _next_entity_id
	_next_entity_id += 1
	return entity_id


func advance_time(delta: float) -> void:
	current_time += delta
