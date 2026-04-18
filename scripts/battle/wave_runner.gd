extends Node
class_name WaveRunner

const WaveDefRef = preload("res://scripts/battle/wave_def.gd")
const WaveSpawnEntryRef = preload("res://scripts/battle/wave_spawn_entry.gd")

var battle: Node = null
var flow_state: Node = null
var defeat_line_x := 80.0

var _wave_defs: Array[Resource] = []
var _started_waves: Dictionary = {}
var _completed_waves: Dictionary = {}
var _spawned_entry_indices: Dictionary = {}
var _spawned_entities: Dictionary = {}


func setup(battle_node: Node, flow_state_node: Node, scenario: Resource) -> void:
	battle = battle_node
	flow_state = flow_state_node
	defeat_line_x = float(scenario.get("defeat_line_x"))
	if defeat_line_x <= 0.0:
		defeat_line_x = 80.0
	_wave_defs.clear()
	_started_waves.clear()
	_completed_waves.clear()
	_spawned_entry_indices.clear()
	_spawned_entities.clear()

	var configured_wave_defs: Variant = scenario.get("wave_defs")
	if configured_wave_defs is Array:
		for wave_def in configured_wave_defs:
			if wave_def is Resource:
				_wave_defs.append(wave_def)
	_wave_defs.sort_custom(func(a: Resource, b: Resource) -> bool:
		return float(a.get("start_time")) < float(b.get("start_time"))
	)
	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))


func get_debug_name() -> String:
	return "wave_runner"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"template_id": StringName(),
		"entity_kind": &"wave_runner",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"started_wave_count": _started_waves.size(),
			"completed_wave_count": _completed_waves.size(),
			"defeat_line_x": defeat_line_x,
		},
	}


func _on_game_tick(event_data: Variant) -> void:
	if battle == null or not is_instance_valid(battle):
		return
	if flow_state == null or not is_instance_valid(flow_state):
		return
	if flow_state.is_terminal():
		return

	var game_time := float(event_data.core.get("game_time", GameState.current_time))
	_start_due_waves(game_time)
	_spawn_due_entries(game_time)
	_complete_finished_waves()
	_check_defeat()
	_check_victory()


func _start_due_waves(game_time: float) -> void:
	for wave_def in _wave_defs:
		var wave_id := StringName(wave_def.get("wave_id"))
		if _started_waves.has(wave_id):
			continue
		if game_time + 0.001 < float(wave_def.get("start_time")):
			continue
		_started_waves[wave_id] = true
		_spawned_entry_indices[wave_id] = {}
		_spawned_entities[wave_id] = []
		flow_state.ensure_running(wave_id)
		flow_state.mark_wave_started(wave_id)


func _spawn_due_entries(game_time: float) -> void:
	for wave_def in _wave_defs:
		var wave_id := StringName(wave_def.get("wave_id"))
		if not _started_waves.has(wave_id):
			continue
		var wave_start_time := float(wave_def.get("start_time"))
		var spawn_entries: Variant = wave_def.get("spawn_entries")
		if not (spawn_entries is Array):
			continue
		for index in range(spawn_entries.size()):
			var wave_spawn_entry: Resource = spawn_entries[index]
			if wave_spawn_entry == null:
				continue
			if Dictionary(_spawned_entry_indices.get(wave_id, {})).has(index):
				continue
			var scheduled_time := wave_start_time + float(wave_spawn_entry.get("spawn_time_offset"))
			if game_time + 0.001 < scheduled_time:
				continue
			var spawn_entry: Resource = wave_spawn_entry.get("spawn_entry")
			var spawned_entity = battle.spawn_wave_entry(spawn_entry, wave_id)
			var wave_entities: Array = Array(_spawned_entities.get(wave_id, []))
			if spawned_entity != null:
				wave_entities.append(spawned_entity)
			_spawned_entities[wave_id] = wave_entities
			var spawned_indices: Dictionary = Dictionary(_spawned_entry_indices.get(wave_id, {}))
			spawned_indices[index] = true
			_spawned_entry_indices[wave_id] = spawned_indices


func _complete_finished_waves() -> void:
	for wave_def in _wave_defs:
		var wave_id := StringName(wave_def.get("wave_id"))
		if not _started_waves.has(wave_id) or _completed_waves.has(wave_id):
			continue
		var spawn_entries: Variant = wave_def.get("spawn_entries")
		var total_entries: int = 0 if not (spawn_entries is Array) else spawn_entries.size()
		var spawned_indices: Dictionary = Dictionary(_spawned_entry_indices.get(wave_id, {}))
		if spawned_indices.size() < total_entries:
			continue
		if _wave_has_active_entities(wave_id):
			continue
		_completed_waves[wave_id] = true
		flow_state.mark_wave_completed(wave_id)


func _check_victory() -> void:
	if _wave_defs.is_empty():
		return
	if _completed_waves.size() < _wave_defs.size():
		return
	if _has_active_enemies():
		return
	flow_state.mark_victory(&"all_waves_cleared")


func _check_defeat() -> void:
	for entity in battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.get("team") != &"zombie":
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		if not (entity is Node2D):
			continue
		if (entity as Node2D).global_position.x <= defeat_line_x:
			flow_state.mark_defeat(&"zombie_reached_goal")
			return


func _wave_has_active_entities(wave_id: StringName) -> bool:
	var wave_entities: Array = Array(_spawned_entities.get(wave_id, []))
	var alive_entities: Array = []
	for entity in wave_entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		alive_entities.append(entity)
	_spawned_entities[wave_id] = alive_entities
	return not alive_entities.is_empty()


func _has_active_enemies() -> bool:
	for entity in battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.get("team") != &"zombie":
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		return true
	return false
