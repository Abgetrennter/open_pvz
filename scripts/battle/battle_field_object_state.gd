extends Node
class_name BattleFieldObjectState

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const BattleSpawnEntryRef = preload("res://scripts/battle/battle_spawn_entry.gd")
const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")

var battle: Node = null
var _entity_factory: RefCounted = EntityFactoryRef.new()
var _field_objects: Array = []


func setup(battle_node: Node, scenario: Resource) -> void:
	battle = battle_node
	_field_objects.clear()


func get_debug_name() -> String:
	return "field_object_state"


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": -1,
		"template_id": StringName(),
		"entity_kind": &"field_object_state",
		"team": &"neutral",
		"lane_id": -1,
		"status": &"active",
		"position": Vector2.ZERO,
		"health": 0,
		"max_health": 0,
		"values": {
			"field_object_count": _field_objects.size(),
		},
	}


func spawn_field_objects(scenario: Resource) -> void:
	var configured_configs: Variant = scenario.get("field_object_configs")
	if not configured_configs is Array:
		return
	for config in configured_configs:
		if config == null:
			continue
		_spawn_field_object(config, scenario)


func get_field_objects() -> Array:
	return _field_objects


func _spawn_field_object(config: Resource, scenario: Resource) -> void:
	var archetype_id := StringName(config.get("archetype_id"))
	var lane_id_value: Variant = config.get("lane_id")
	var lane_id := int(lane_id_value) if lane_id_value != null else 0
	var x_position_value: Variant = config.get("x_position")
	var x_position := float(x_position_value) if x_position_value != null else 80.0
	var spawn_overrides: Dictionary = {}
	var raw_overrides: Variant = config.get("spawn_overrides")
	if raw_overrides is Dictionary:
		spawn_overrides = raw_overrides
	var position := _build_spawn_position(lane_id, x_position)
	if archetype_id != StringName() and SceneRegistry.has_archetype(archetype_id):
		var entry = BattleSpawnEntryRef.new()
		entry.entity_kind = &"field_object"
		entry.archetype_id = archetype_id
		entry.lane_id = lane_id
		entry.x_position = x_position
		entry.spawn_overrides = spawn_overrides
		var spawn_resolution: Dictionary = _entity_factory.instantiate_spawn_entry(entry, position)
		if spawn_resolution.is_empty():
			return
		var entity = spawn_resolution.get("entity", null)
		if entity == null:
			return
		if entity.has_method("set_battle_ref"):
			entity.call("set_battle_ref", battle)
		battle.finalize_spawned_entity(entity, lane_id, spawn_resolution.get("hit_height_band", null), spawn_resolution.get("trigger_instances", []), null, {
			"spawn_reason": &"field_object_spawn",
			"archetype_id": archetype_id,
			"object_template_id": StringName(entity.get("template_id")),
		})
		_field_objects.append(entity)
		_emit_field_object_spawned(entity, lane_id, StringName(entity.get("template_id")), archetype_id)
		return
	return


func _build_spawn_position(lane_id: int, x_position: float) -> Vector2:
	var lane_y := 220.0
	if battle != null:
		lane_y = battle.get_lane_y(lane_id)
	return Vector2(x_position, lane_y)


func _emit_field_object_spawned(entity: Node, lane_id: int, template_id: StringName, archetype_id: StringName = StringName()) -> void:
	var spawned_event: Variant = EventDataRef.create(null, entity, null, PackedStringArray(["field_object", "spawned"]))
	spawned_event.core["lane_id"] = lane_id
	if entity.has_method("get_entity_id"):
		spawned_event.core["entity_id"] = int(entity.call("get_entity_id"))
	spawned_event.core["object_template_id"] = template_id
	spawned_event.core["archetype_id"] = archetype_id
	EventBus.push_event(&"field_object.spawned", spawned_event)
