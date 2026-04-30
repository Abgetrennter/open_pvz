extends Node
class_name BattleStatusState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var battle: Node = null

var _requests: Array[Resource] = []
var _processed_request_indices: Dictionary = {}


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	_requests.clear()
	_processed_request_indices.clear()
	var configured_requests: Variant = scenario.get("status_application_requests")
	if configured_requests is Array:
		for request in configured_requests:
			if request is Resource:
				_requests.append(request)
	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))


func get_debug_name() -> String:
	return "status_state"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"archetype_id": StringName(),
		"entity_kind": &"status_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"scheduled_status_count": _requests.size(),
			"processed_status_count": _processed_request_indices.size(),
		},
	}


func _on_game_tick(event_data: Variant) -> void:
	var game_time := float(event_data.core.get("game_time", GameState.current_time))
	_update_entity_statuses(game_time)
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
		var target_entity: Variant = _resolve_target_entity(request)
		if target_entity == null:
			continue
		if target_entity.has_method("apply_status"):
			target_entity.call("apply_status", StringName(request.get("status_id")), float(request.get("duration")), {
				"movement_scale": float(request.get("movement_scale")),
				"blocks_attack": bool(request.get("blocks_attack")),
			})
		var applied_event: Variant = EventDataRef.create(null, target_entity, null, PackedStringArray(["status", "applied"]))
		applied_event.core["status_id"] = StringName(request.get("status_id"))
		applied_event.core["target_archetype_id"] = StringName(request.get("target_archetype_id"))
		applied_event.core["lane_id"] = int(request.get("lane_id"))
		applied_event.core["duration"] = float(request.get("duration"))
		applied_event.core["movement_scale"] = float(request.get("movement_scale"))
		applied_event.core["blocks_attack"] = bool(request.get("blocks_attack"))
		EventBus.push_event(&"entity.status_applied", applied_event)


func _update_entity_statuses(game_time: float) -> void:
	if battle == null or not is_instance_valid(battle):
		return
	for entity in battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("update_statuses"):
			entity.call("update_statuses", game_time)


func _resolve_target_entity(request: Resource):
	if battle == null or not is_instance_valid(battle):
		return null
	var target_archetype_id := StringName(request.get("target_archetype_id"))
	var target_lane := int(request.get("lane_id"))
	for entity in battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("is_combat_active") and not bool(entity.call("is_combat_active")):
			continue
		if target_archetype_id != StringName() and StringName(entity.get("archetype_id")) != target_archetype_id:
			continue
		if target_lane >= 0 and int(entity.get("lane_id")) != target_lane:
			continue
		return entity
	return null
