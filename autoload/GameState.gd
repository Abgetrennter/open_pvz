extends Node

var current_battle: Node = null
var current_time := 0.0
var battle_seed := 0

var _next_entity_id := 1


func reset_runtime() -> void:
	current_battle = null
	current_time = 0.0
	battle_seed = 0
	_next_entity_id = 1


func begin_battle(battle: Node) -> void:
	current_battle = battle
	current_time = 0.0
	_next_entity_id = 1
	battle_seed = _derive_default_battle_seed(battle)


func end_battle(battle: Node) -> void:
	if current_battle == battle:
		current_battle = null


func next_entity_id() -> int:
	var entity_id := _next_entity_id
	_next_entity_id += 1
	return entity_id


func advance_time(delta: float) -> void:
	current_time += delta


func set_battle_seed(seed: int) -> void:
	battle_seed = seed


func _derive_default_battle_seed(battle: Node) -> int:
	if battle != null and battle.has_method("resolve_scenario"):
		var scenario = battle.call("resolve_scenario")
		if scenario != null and scenario.get("scenario_id") != null:
			return hash(String(scenario.get("scenario_id")))
	if battle != null:
		return hash(String(battle.name))
	return 0


static func derive_entity_seed(battle_seed_val: int, entity_id: int) -> int:
	return hash(str(battle_seed_val) + "_" + str(entity_id))


static func derive_mechanic_seed(entity_seed_val: int, mechanic_id: StringName) -> int:
	return hash(str(entity_seed_val) + "_" + String(mechanic_id))
