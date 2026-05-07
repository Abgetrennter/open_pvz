extends Node

var current_battle: Node = null
var current_time := 0.0
var battle_seed := 0
var simulation_tick_hz := 100
var fixed_dt := 0.01
var current_tick := 0
var simulation_speed := 1.0
var is_simulation_paused := false
var use_central_gameplay_step := true
var is_central_step_dispatching := false

var _next_entity_id := 1


func reset_runtime() -> void:
	current_battle = null
	reset_simulation_time()
	battle_seed = 0
	_next_entity_id = 1


func begin_battle(battle: Node) -> void:
	current_battle = battle
	reset_simulation_time()
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
	# Legacy compatibility path for callers not yet migrated to fixed ticks.
	current_time += delta


func reset_simulation_time() -> void:
	current_tick = 0
	current_time = 0.0
	fixed_dt = 1.0 / maxf(float(simulation_tick_hz), 1.0)


func advance_simulation_tick() -> void:
	current_tick += 1
	current_time = float(current_tick) * fixed_dt


func get_simulation_snapshot() -> Dictionary:
	return {
		"simulation_tick_hz": simulation_tick_hz,
		"fixed_dt": fixed_dt,
		"current_tick": current_tick,
		"current_time": current_time,
		"simulation_speed": simulation_speed,
		"is_simulation_paused": is_simulation_paused,
		"use_central_gameplay_step": use_central_gameplay_step,
	}


func should_skip_node_process_for_central_step() -> bool:
	return use_central_gameplay_step and not is_central_step_dispatching


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
