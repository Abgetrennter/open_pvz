extends Node

const TriggerDefRef = preload("res://scripts/core/defs/trigger_def.gd")
const ProtocolValidatorRef = preload("res://scripts/core/runtime/protocol_validator.gd")

var _trigger_defs: Dictionary = {}
var _trigger_strategies: Dictionary = {}


func _ready() -> void:
	_register_builtin_defs()
	_register_builtin_strategies()


func register_def(trigger_def) -> void:
	if trigger_def == null or trigger_def.trigger_id == StringName():
		return
	var errors: Array[String] = ProtocolValidatorRef.validate_trigger_def(trigger_def)
	if not errors.is_empty():
		for error in errors:
			push_warning(error)
			if DebugService.has_method("record_protocol_issue"):
				DebugService.record_protocol_issue(&"trigger_def", error, &"error")
		return
	_trigger_defs[trigger_def.trigger_id] = trigger_def


func register_strategy(trigger_id: StringName, strategy: Callable) -> void:
	if trigger_id == StringName() or not strategy.is_valid():
		return
	_trigger_strategies[trigger_id] = strategy


func get_def(trigger_id: StringName):
	return _trigger_defs.get(trigger_id)


func evaluate_trigger(
	trigger_id: StringName,
	event_data,
	condition_values: Dictionary,
	entity_state: Dictionary,
	instance
) -> bool:
	var strategy: Callable = _trigger_strategies.get(trigger_id, Callable())
	if not strategy.is_valid():
		return false
	return bool(strategy.call(event_data, condition_values, entity_state, instance))


func _register_builtin_defs() -> void:
	var periodically = TriggerDefRef.new()
	var periodically_params: Array[Dictionary] = [{
		"name": "interval",
		"type": "float",
		"min": 0.25,
		"max": 10.0,
	}, {
		"name": "detection_id",
		"type": "string_name",
		"default": &"always",
		"options": PackedStringArray(["always", "lane_forward", "lane_backward", "proximity", "radius_around", "global_track"]),
	}, {
		"name": "scan_range",
		"type": "float",
		"min": 1.0,
		"max": 4000.0,
		"default": 900.0,
	}, {
		"name": "start_delay",
		"type": "float",
		"min": 0.0,
		"max": 30.0,
		"default": 0.0,
	}, {
		"name": "required_state",
		"type": "string_name",
	}, {
		"name": "target_tags",
		"type": "packed_string_array",
	}]
	periodically.trigger_id = &"periodically"
	periodically.event_name = &"game.tick"
	periodically.weight = 100
	periodically.max_bound_effects = 1
	periodically.condition_params = periodically_params
	periodically.allow_extra_conditions = false
	register_def(periodically)

	var when_damaged = TriggerDefRef.new()
	var when_damaged_params: Array[Dictionary] = [{
		"name": "min_damage",
		"type": "int",
		"min": 0,
		"max": 999,
	}]
	when_damaged.trigger_id = &"when_damaged"
	when_damaged.event_name = &"entity.damaged"
	when_damaged.weight = 60
	when_damaged.max_bound_effects = 1
	when_damaged.condition_params = when_damaged_params
	when_damaged.allow_extra_conditions = false
	register_def(when_damaged)

	var on_death = TriggerDefRef.new()
	on_death.trigger_id = &"on_death"
	on_death.event_name = &"entity.died"
	on_death.weight = 30
	on_death.max_bound_effects = 1
	on_death.allow_extra_conditions = false
	register_def(on_death)

	var on_spawned = TriggerDefRef.new()
	on_spawned.trigger_id = &"on_spawned"
	on_spawned.event_name = &"entity.spawned"
	on_spawned.weight = 20
	on_spawned.max_bound_effects = 1
	on_spawned.allow_extra_conditions = false
	register_def(on_spawned)

	var on_place = TriggerDefRef.new()
	on_place.trigger_id = &"on_place"
	on_place.event_name = &"placement.accepted"
	on_place.weight = 25
	on_place.max_bound_effects = 1
	on_place.allow_extra_conditions = false
	register_def(on_place)

	var proximity = TriggerDefRef.new()
	var proximity_params: Array[Dictionary] = [{
		"name": "interval",
		"type": "float",
		"min": 0.1,
		"max": 10.0,
		"default": 0.25,
	}, {
		"name": "scan_range",
		"type": "float",
		"min": 1.0,
		"max": 4000.0,
		"default": 64.0,
	}, {
		"name": "required_state",
		"type": "string_name",
	}, {
		"name": "start_delay",
		"type": "float",
		"min": 0.0,
		"max": 30.0,
		"default": 0.0,
	}]
	proximity.trigger_id = &"proximity"
	proximity.event_name = &"game.tick"
	proximity.weight = 80
	proximity.max_bound_effects = 1
	proximity.condition_params = proximity_params
	proximity.allow_extra_conditions = false
	register_def(proximity)


func _register_builtin_strategies() -> void:
	register_strategy(&"periodically", func(event_data, condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		var interval := float(condition_values.get("interval", 1.0))
		var game_time := float(event_data.core.get("game_time", 0.0))
		var required_state := StringName(condition_values.get("required_state", StringName()))
		if required_state != StringName():
			var current_state := StringName(_entity_state.get("values", {}).get(&"state_stage", StringName()))
			if current_state != required_state:
				return false

		var start_delay := float(condition_values.get("start_delay", 0.0))
		if start_delay > 0.0 and instance.last_triggered_time < -999999.0:
			if game_time - instance.bind_time < start_delay:
				return false

		if game_time - instance.last_triggered_time < interval:
			return false

		var detection_id := StringName(condition_values.get("detection_id", &"always"))
		if detection_id == StringName() or detection_id == &"always":
			return true

		var detection_result: Dictionary = DetectionRegistry.evaluate(detection_id, instance.owner_entity, {
			"scan_range": float(condition_values.get("scan_range", 900.0)),
			"target_tags": PackedStringArray(condition_values.get("target_tags", PackedStringArray())),
		})
		if not bool(detection_result.get("has_target", false)):
			return false

		var detected_target_ids := PackedInt32Array()
		for target in Array(detection_result.get("targets", [])):
			if target != null and target.has_method("get_entity_id"):
				detected_target_ids.append(int(target.call("get_entity_id")))
		instance.set_pending_context_overrides({
			"target_node": detection_result.get("primary_target", null),
			"detection_id": detection_id,
			"detected_target_ids": detected_target_ids,
		})
		return true
	)

	register_strategy(&"when_damaged", func(event_data, condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		if event_data.core.get("target_node", null) != instance.owner_entity:
			return false
		var min_damage := int(condition_values.get("min_damage", 0))
		return int(event_data.core.get("value", 0)) >= min_damage
	)

	register_strategy(&"on_death", func(event_data, _condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		return event_data.core.get("target_node", null) == instance.owner_entity
	)

	register_strategy(&"on_spawned", func(event_data, _condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		return event_data.core.get("target_node", null) == instance.owner_entity
	)

	register_strategy(&"on_place", func(event_data, _condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		return event_data.core.get("target_node", null) == instance.owner_entity
	)

	register_strategy(&"proximity", func(event_data, condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		var interval := float(condition_values.get("interval", 0.25))
		var game_time := float(event_data.core.get("game_time", 0.0))
		var required_state := StringName(condition_values.get("required_state", StringName()))
		if required_state != StringName():
			var current_state := StringName(_entity_state.get("values", {}).get(&"state_stage", StringName()))
			if current_state != required_state:
				return false

		var start_delay := float(condition_values.get("start_delay", 0.0))
		if start_delay > 0.0 and instance.last_triggered_time < -999999.0:
			if game_time - instance.bind_time < start_delay:
				return false

		if game_time - instance.last_triggered_time < interval:
			return false

		var scan_range := float(condition_values.get("scan_range", 64.0))
		var detection_result: Dictionary = DetectionRegistry.evaluate(&"proximity", instance.owner_entity, {
			"scan_range": scan_range,
			"target_tags": PackedStringArray(condition_values.get("target_tags", PackedStringArray())),
		})
		if not bool(detection_result.get("has_target", false)):
			return false

		var detected_target_ids := PackedInt32Array()
		for target in Array(detection_result.get("targets", [])):
			if target != null and target.has_method("get_entity_id"):
				detected_target_ids.append(int(target.call("get_entity_id")))
		instance.set_pending_context_overrides({
			"target_node": detection_result.get("primary_target", null),
			"detection_id": &"proximity",
			"detected_target_ids": detected_target_ids,
		})
		return true
	)
