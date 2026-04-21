extends Node
class_name BattleEconomyState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const SunCollectibleRef = preload("res://scripts/battle/sun_collectible.gd")

var current_sun := 0
var battle: Node = null
var collectible_root: Node = null
var auto_collect_delay := -1.0
var active_suns: Dictionary = {}

var _next_sun_id := 1
var _scheduled_drops: Array[Resource] = []
var _scheduled_spends: Array[Resource] = []
var _processed_drop_indices: Dictionary = {}
var _processed_spend_indices: Dictionary = {}


func setup(battle_node: Node, collectible_parent: Node, scenario: Resource) -> void:
	battle = battle_node
	collectible_root = collectible_parent
	current_sun = int(scenario.get("initial_sun"))
	auto_collect_delay = float(scenario.get("sun_auto_collect_delay"))
	_scheduled_drops.clear()
	_scheduled_spends.clear()
	_processed_drop_indices.clear()
	_processed_spend_indices.clear()
	active_suns.clear()
	_next_sun_id = 1

	var configured_drops: Variant = scenario.get("sun_drop_entries")
	if configured_drops is Array:
		for drop_entry in configured_drops:
			if drop_entry is Resource:
				_scheduled_drops.append(drop_entry)

	var configured_spends: Variant = scenario.get("resource_spend_requests")
	if configured_spends is Array:
		for spend_request in configured_spends:
			if spend_request is Resource:
				_scheduled_spends.append(spend_request)

	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))
	if current_sun > 0:
		_emit_resource_changed(current_sun, &"initialize", null, {})


func get_debug_name() -> String:
	return "economy:sun"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"template_id": StringName(),
		"entity_kind": &"resource_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"current_sun": current_sun,
			"active_sun_count": active_suns.size(),
		},
	}


func get_current_sun() -> int:
	return current_sun


func try_spend_sun(cost: int, reason: StringName = &"manual_spend", source_node: Node = null, metadata: Dictionary = {}) -> bool:
	if cost <= 0:
		return true
	if current_sun < cost:
		var failed_event: Variant = EventDataRef.create(source_node, null, cost, PackedStringArray(["resource", "sun", "spend_failed"]))
		failed_event.core["resource_id"] = &"sun"
		failed_event.core["cost"] = cost
		failed_event.core["current"] = current_sun
		failed_event.core["reason"] = reason
		for key: Variant in metadata.keys():
			failed_event.core[key] = metadata[key]
		EventBus.push_event(&"resource.spend_failed", failed_event)
		return false
	_emit_resource_changed(-cost, reason, source_node, metadata)
	return true


func collect_sun(collectible: Node, collector_node: Node = null) -> bool:
	if collectible == null or not is_instance_valid(collectible):
		return false
	if not active_suns.has(collectible.get_instance_id()):
		return false
	var sun_value := int(collectible.get("sun_value"))
	var collected_event: Variant = EventDataRef.create(collectible, collector_node, sun_value, PackedStringArray(["sun", "collect"]))
	var collector_id := -1
	if collector_node != null and collector_node.has_method("get_entity_id"):
		collector_id = int(collector_node.call("get_entity_id"))
	collected_event.core["sun_id"] = int(collectible.get("sun_id"))
	collected_event.core["resource_id"] = &"sun"
	collected_event.core["collector_id"] = collector_id
	collected_event.core["value"] = sun_value
	collected_event.core["source_type"] = StringName(collectible.get("source_type"))
	collected_event.core["lane_id"] = int(collectible.get("lane_id"))
	EventBus.push_event(&"sun.collected", collected_event)
	active_suns.erase(collectible.get_instance_id())
	_emit_resource_changed(sun_value, &"collect", collectible, {
		"sun_id": int(collectible.get("sun_id")),
		"source_type": StringName(collectible.get("source_type")),
	})
	if collectible.has_method("mark_collected"):
		collectible.call("mark_collected")
	return true


func spawn_sun(position: Vector2, value: int, source_node: Node = null, source_type: StringName = &"sky_drop", lane_id: int = -1, override_auto_collect_delay: float = -2.0) -> Node2D:
	if collectible_root == null or not is_instance_valid(collectible_root):
		return null
	var collectible: Variant = SunCollectibleRef.new()
	collectible.name = "SunCollectible_%d" % _next_sun_id
	collectible.position = position
	var resolved_auto_collect_delay := auto_collect_delay if override_auto_collect_delay < -1.0 else override_auto_collect_delay
	var source_entity_id := -1
	if source_node != null and source_node.has_method("get_entity_id"):
		source_entity_id = int(source_node.call("get_entity_id"))
	collectible.configure(_next_sun_id, value, source_type, lane_id, source_entity_id, self, resolved_auto_collect_delay)
	_next_sun_id += 1
	collectible_root.add_child(collectible)
	active_suns[collectible.get_instance_id()] = collectible

	var spawned_event: Variant = EventDataRef.create(source_node, collectible, value, PackedStringArray(["sun", String(source_type)]))
	spawned_event.core["sun_id"] = int(collectible.get("sun_id"))
	spawned_event.core["resource_id"] = &"sun"
	spawned_event.core["source_type"] = source_type
	spawned_event.core["lane_id"] = lane_id
	spawned_event.core["value"] = value
	EventBus.push_event(&"sun.spawned", spawned_event)
	return collectible


func _on_game_tick(event_data: Variant) -> void:
	var game_time := float(event_data.core.get("game_time", GameState.current_time))
	_process_scheduled_drops(game_time)
	_process_scheduled_spends(game_time)


func _process_scheduled_drops(game_time: float) -> void:
	for index in range(_scheduled_drops.size()):
		if _processed_drop_indices.has(index):
			continue
		var drop_entry: Resource = _scheduled_drops[index]
		if drop_entry == null:
			_processed_drop_indices[index] = true
			continue
		if game_time + 0.001 < float(drop_entry.get("at_time")):
			continue
		_processed_drop_indices[index] = true
		var lane_id := int(drop_entry.get("lane_id"))
		var spawn_position := Vector2(float(drop_entry.get("x_position")), _lane_y(lane_id))
		spawn_sun(
			spawn_position,
			int(drop_entry.get("value")),
			null,
			StringName(drop_entry.get("source_type")),
			lane_id,
			float(drop_entry.get("auto_collect_delay"))
		)


func _process_scheduled_spends(game_time: float) -> void:
	for index in range(_scheduled_spends.size()):
		if _processed_spend_indices.has(index):
			continue
		var spend_request: Resource = _scheduled_spends[index]
		if spend_request == null:
			_processed_spend_indices[index] = true
			continue
		if game_time + 0.001 < float(spend_request.get("at_time")):
			continue
		_processed_spend_indices[index] = true
		var resource_id := StringName(spend_request.get("resource_id"))
		if resource_id != &"sun":
			continue
		try_spend_sun(int(spend_request.get("cost")), StringName(spend_request.get("reason")), null, {
			"scheduled": true,
		})


func _emit_resource_changed(delta: int, reason: StringName, source_node: Node, metadata: Dictionary) -> void:
	var before := current_sun
	current_sun += delta
	var changed_event: Variant = EventDataRef.create(source_node, null, delta, PackedStringArray(["resource", "sun", String(reason)]))
	changed_event.core["resource_id"] = &"sun"
	changed_event.core["before"] = before
	changed_event.core["delta"] = delta
	changed_event.core["after"] = current_sun
	changed_event.core["reason"] = reason
	for key: Variant in metadata.keys():
		changed_event.core[key] = metadata[key]
	EventBus.push_event(&"resource.changed", changed_event)


func _lane_y(lane_id: int) -> float:
	if battle != null and is_instance_valid(battle):
		return float(battle.get_lane_y(lane_id))
	return 220.0 + lane_id * 100.0
