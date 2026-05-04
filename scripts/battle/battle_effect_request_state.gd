extends Node
class_name BattleEffectRequestState

const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")
const EffectNodeRef = preload("res://scripts/core/runtime/effect_node.gd")
const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")

var battle: Node = null

var _requests: Array[Resource] = []
var _processed_request_indices: Dictionary = {}


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	_requests.clear()
	_processed_request_indices.clear()
	var configured_requests: Variant = scenario.get("effect_execution_requests")
	if configured_requests is Array:
		for request in configured_requests:
			if request is Resource:
				_requests.append(request)
	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))


func get_debug_name() -> String:
	return "effect_request_state"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"archetype_id": StringName(),
		"entity_kind": &"effect_request_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"scheduled_effect_count": _requests.size(),
			"processed_effect_count": _processed_request_indices.size(),
		},
	}


func _on_game_tick(event_data: Variant) -> void:
	var game_time := float(event_data.core.get("game_time", GameState.current_time))
	for index in range(_requests.size()):
		if _processed_request_indices.has(index):
			continue
		var request: Resource = _requests[index]
		if request == null:
			_processed_request_indices[index] = true
			continue
		if game_time + 0.001 < float(request.get("at_time")):
			continue
		_processed_request_indices[index] = true
		_execute_request(request)


func _execute_request(request: Resource) -> void:
	var effect_id := StringName(request.get("effect_id"))
	if effect_id == StringName():
		return
	var context: Variant = RuleContextRef.new()
	context.event_name = &"effect.requested"
	context.owner_entity = _resolve_entity(StringName(request.get("owner_archetype_id")), int(request.get("owner_lane_id")))
	context.source_node = _resolve_entity(StringName(request.get("source_archetype_id")), int(request.get("source_lane_id")))
	context.target_node = _resolve_entity(StringName(request.get("target_archetype_id")), int(request.get("target_lane_id")))
	if context.source_node == null:
		context.source_node = context.owner_entity
	context.position = Vector2(request.get("position"))
	if context.position == Vector2.ZERO and context.owner_entity is Node2D:
		context.position = context.owner_entity.global_position
	elif context.position == Vector2.ZERO and context.source_node is Node2D:
		context.position = context.source_node.global_position
	elif context.position == Vector2.ZERO and context.target_node is Node2D:
		context.position = context.target_node.global_position
	context.runtime["depth"] = 1
	context.runtime["chain_id"] = "effect_request_%d" % int(round(GameState.current_time * 1000.0))
	context.core["source_node"] = context.source_node
	context.core["target_node"] = context.target_node
	var effect_node: Variant = EffectNodeRef.new(effect_id, Dictionary(request.get("params")).duplicate(true))
	EffectExecutorRef.execute_node(effect_node, context)


func _resolve_entity(archetype_id: StringName, lane_id: int) -> Node:
	if battle == null or not is_instance_valid(battle):
		return null
	if archetype_id == StringName() and lane_id < 0:
		return null
	for entity in battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		if archetype_id != StringName() and StringName(entity.get("archetype_id")) != archetype_id:
			continue
		if lane_id >= 0 and int(entity.get("lane_id")) != lane_id:
			continue
		return entity
	return null
