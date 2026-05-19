extends Node
class_name WaveRunner

const WaveDefRef = preload("res://scripts/battle/wave_def.gd")
const WaveSpawnEntryRef = preload("res://scripts/battle/wave_spawn_entry.gd")
const BattleSpawnResolverRef = preload("res://scripts/battle/battle_spawn_resolver.gd")
const CombatContentResolverRef = preload("res://scripts/core/runtime/combat_content_resolver.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var battle: Node = null
var flow_state: Node = null
var defeat_line_x := 80.0
var battle_goal: StringName = &"all_waves_cleared"
var defeat_conditions: PackedStringArray = PackedStringArray(["zombie_reached_goal"])
var survival_duration := 0.0
var protected_archetype_id: StringName = StringName()

var _wave_defs: Array[Resource] = []
var _started_waves: Dictionary = {}
var _completed_waves: Dictionary = {}
var _spawned_entry_indices: Dictionary = {}
var _spawned_entities: Dictionary = {}
var _spawn_resolver: RefCounted = BattleSpawnResolverRef.new()


func setup(battle_node: Node, flow_state_node: Node, scenario: Resource) -> void:
	battle = battle_node
	flow_state = flow_state_node
	battle_goal = StringName(scenario.get("battle_goal"))
	if battle_goal == StringName():
		battle_goal = &"all_waves_cleared"
	defeat_conditions = PackedStringArray(scenario.get("defeat_conditions"))
	if defeat_conditions.is_empty():
		defeat_conditions = PackedStringArray(["zombie_reached_goal"])
	survival_duration = float(scenario.get("survival_duration"))
	protected_archetype_id = StringName(scenario.get("protected_archetype_id"))
	defeat_line_x = float(scenario.get("defeat_line_x"))
	if defeat_line_x <= 0.0:
		defeat_line_x = 80.0
	_wave_defs.clear()
	_started_waves.clear()
	_completed_waves.clear()
	_spawned_entry_indices.clear()
	_spawned_entities.clear()
	var battlefield_preset: Variant = scenario.get("battlefield_preset")
	_spawn_resolver.setup(battle, battlefield_preset)

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
		"archetype_id": StringName(),
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
			"battle_goal": battle_goal,
			"defeat_conditions": PackedStringArray(defeat_conditions),
			"survival_duration": survival_duration,
			"protected_archetype_id": protected_archetype_id,
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
	_check_victory(game_time)


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
			var spawned_entity = _spawn_wave_entry(spawn_entry, wave_id)
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


func _check_victory(game_time: float) -> void:
	match battle_goal:
		&"survive_duration":
			if survival_duration > 0.0 and game_time + 0.001 >= survival_duration:
				flow_state.mark_victory(&"survival_duration_elapsed")
		_:
			if _wave_defs.is_empty():
				return
			if _completed_waves.size() < _wave_defs.size():
				return
			if _has_active_enemies():
				return
			var victory_reason: StringName = &"all_waves_cleared"
			if battle_goal == &"protect_and_clear":
				victory_reason = &"protected_and_cleared"
			flow_state.mark_victory(victory_reason)


func _check_defeat() -> void:
	if defeat_conditions.has(&"zombie_reached_goal"):
		for entity in battle.get_runtime_combat_entities():
			if entity == null or not is_instance_valid(entity):
				continue
			if entity.get("team") != &"zombie":
				continue
			if entity.has_method("is_runtime_alive") and not bool(entity.call("is_runtime_alive")):
				continue
			if not (entity is Node2D):
				continue
			if (entity as Node2D).global_position.x <= defeat_line_x:
				flow_state.mark_defeat(&"zombie_reached_goal")
				return
	if defeat_conditions.has(&"protect_archetype") and _is_protected_target_missing():
		flow_state.mark_defeat(&"protected_archetype_lost")
		return


func _wave_has_active_entities(wave_id: StringName) -> bool:
	var wave_entities: Array = Array(_spawned_entities.get(wave_id, []))
	var alive_entities: Array = []
	for entity in wave_entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_runtime_alive") and not bool(entity.call("is_runtime_alive")):
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
		if entity.has_method("is_counted_for_objectives") and not bool(entity.call("is_counted_for_objectives")):
			continue
		return true
	return false


func _is_protected_target_missing() -> bool:
	if protected_archetype_id == StringName():
		return false
	for entity in battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if StringName(entity.get("archetype_id")) != protected_archetype_id:
			continue
		if entity.has_method("is_counted_for_objectives") and not bool(entity.call("is_counted_for_objectives")):
			continue
		return false
	return true


func _spawn_wave_entry(spawn_entry: Resource, wave_id: StringName):
	var archetype = CombatContentResolverRef.resolve_spawn_entry_archetype(spawn_entry)
	var resolution: Dictionary = _spawn_resolver.resolve_spawn(spawn_entry, archetype)
	if not bool(resolution.get("ok", false)):
		_report_spawn_rejected(spawn_entry, wave_id, StringName(resolution.get("reason", StringName())))
		return null
	var lane_id := int(resolution.get("lane_id"))
	var x_position := float(resolution.get("x"))
	_emit_spawn_resolved(spawn_entry, wave_id, lane_id, x_position, StringName(resolution.get("zone_id", StringName())))
	if battle.has_method("spawn_resolved_wave_entry"):
		return battle.call("spawn_resolved_wave_entry", spawn_entry, lane_id, x_position, wave_id)
	return battle.spawn_wave_entry(spawn_entry, wave_id)


func _emit_spawn_resolved(spawn_entry: Resource, wave_id: StringName, lane_id: int, x_position: float, zone_id: StringName) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["spawn", "resolved"]))
	event_data.core["wave_id"] = wave_id
	event_data.core["lane_id"] = lane_id
	event_data.core["x_position"] = x_position
	event_data.core["zone_id"] = zone_id
	if spawn_entry != null:
		event_data.core["archetype_id"] = StringName(spawn_entry.get("archetype_id"))
	EventBus.push_event(&"spawn.resolved", event_data)


func _report_spawn_rejected(spawn_entry: Resource, wave_id: StringName, reason: StringName) -> void:
	var message := "Wave %s spawn entry rejected: %s." % [String(wave_id), String(reason)]
	if battle != null and battle.has_method("report_protocol_issues"):
		var errors: Array[String] = [message]
		battle.call("report_protocol_issues", errors, &"battle_spawn_resolver")
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["spawn", "reject"]))
	event_data.core["wave_id"] = wave_id
	event_data.core["reason"] = reason
	if spawn_entry != null:
		event_data.core["archetype_id"] = StringName(spawn_entry.get("archetype_id"))
		event_data.core["lane_id"] = int(spawn_entry.get("lane_id"))
	EventBus.push_event(&"spawn.rejected", event_data)
