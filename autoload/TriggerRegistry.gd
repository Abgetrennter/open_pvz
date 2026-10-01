extends "res://scripts/core/registry/registry_base.gd"

const TriggerDefRef = preload("res://scripts/core/defs/trigger_def.gd")
const ProtocolValidatorRef = preload("res://scripts/core/runtime/protocol_validator.gd")

var _trigger_strategies: Dictionary = {}
var _trigger_strategy_owners: Dictionary = {}

const EXTENSION_TRIGGER_DEF_DIR := "data/combat/triggers"


func _make_registry_config():
	return RegistryConfigRef.create(
		&"triggers",
		TriggerDefRef,
		&"triggers",
		EXTENSION_TRIGGER_DEF_DIR,
		&"trusted_runtime",
		StringName(),
		false
	)


func _on_registry_cleared() -> void:
	_trigger_strategies.clear()
	_trigger_strategy_owners.clear()


func _register_builtin_defs() -> void:
	var periodically = TriggerDefRef.new()
	var periodically_params: Array[Dictionary] = [{
		"name": "interval",
		"type": "float",
		"min": 0.25,
		"max": 60.0,
	}, {
		"name": "interval_min",
		"type": "float",
		"min": 0.0,
		"max": 60.0,
	}, {
		"name": "interval_max",
		"type": "float",
		"min": 0.0,
		"max": 60.0,
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
		"name": "scan_range_slots",
		"type": "float",
		"min": 0.0,
		"max": 64.0,
	}, {
		"name": "range_mode",
		"type": "string_name",
		"options": PackedStringArray(["full_lane"]),
	}, {
		"name": "start_delay",
		"type": "float",
		"min": 0.0,
		"max": 60.0,
		"default": 0.0,
	}, {
		"name": "start_delay_min",
		"type": "float",
		"min": 0.0,
		"max": 60.0,
	}, {
		"name": "start_delay_max",
		"type": "float",
		"min": 0.0,
		"max": 60.0,
	}, {
		"name": "required_state",
		"type": "string_name",
	}, {
		"name": "target_tags",
		"type": "packed_string_array",
	}, {
		"name": "target_priority_tags",
		"type": "packed_string_array",
	}, {
		"name": "target_exclude_tags",
		"type": "packed_string_array",
	}, {
		"name": "respect_visibility",
		"type": "bool",
		"default": false,
	}, {
		"name": "max_trigger_count",
		"type": "int",
		"min": 0,
		"max": 999,
	}, {
		"name": "require_no_target",
		"type": "bool",
		"default": false,
	}, {
		"name": "target_selection",
		"type": "string_name",
		"options": PackedStringArray(["leftmost"]),
	}, {
		"name": "min_scan_range",
		"type": "float",
		"min": 0.0,
		"max": 4000.0,
	}, {
		"name": "min_scan_range_slots",
		"type": "float",
		"min": 0.0,
		"max": 64.0,
	}, {
		"name": "team_mode",
		"type": "string_name",
		"options": PackedStringArray(["enemies", "allies"]),
		"default": &"enemies",
	}, {
		"name": "lane_offset",
		"type": "int",
		"min": -2,
		"max": 2,
		}, {
			"name": "x_offset",
			"type": "float",
			"min": -400.0,
			"max": 400.0,
		}, {
			"name": "required_lane_tags",
			"type": "packed_string_array",
		}, {
			"name": "fuse_distance_min",
			"type": "float",
			"min": 1.0,
			"max": 4000.0,
		}, {
			"name": "fuse_distance_max",
			"type": "float",
			"min": 1.0,
			"max": 4000.0,
		}, {
			"name": "early_trigger_probability",
			"type": "float",
			"min": 0.0,
			"max": 1.0,
		}, {
			"name": "early_trigger_scale",
			"type": "float",
			"min": 0.01,
			"max": 1.0,
		}, {
			"name": "fuse_speed_factor",
			"type": "float",
			"min": 0.1,
			"max": 4.0,
		}]
	periodically.id = &"periodically"
	periodically.event_name = &"game.tick"
	periodically.weight = 100
	periodically.max_bound_effects = 1
	periodically.param_defs = periodically_params
	periodically.allow_extra_conditions = false
	register_def(periodically, {"kind": &"core", "source": &"core"})

	var when_damaged = TriggerDefRef.new()
	var when_damaged_params: Array[Dictionary] = [{
		"name": "min_damage",
		"type": "int",
		"min": 0,
		"max": 999,
	}, {
		"name": "max_health_fraction_at_or_below",
		"type": "float",
		"min": 0.0,
		"max": 1.0,
	}, {
		"name": "once_key",
		"type": "string_name",
	}, {
		"name": "required_damage_tags",
		"type": "packed_string_array",
	}, {
		"name": "min_owner_x",
		"type": "float",
		"min": -4000.0,
		"max": 4000.0,
	}]
	when_damaged.id = &"when_damaged"
	when_damaged.event_name = &"entity.damaged"
	when_damaged.weight = 60
	when_damaged.max_bound_effects = 1
	when_damaged.param_defs = when_damaged_params
	when_damaged.allow_extra_conditions = false
	register_def(when_damaged, {"kind": &"core", "source": &"core"})

	var when_layer_destroyed = TriggerDefRef.new()
	var when_layer_destroyed_params: Array[Dictionary] = [{
		"name": "required_layer_id",
		"type": "string_name",
	}, {
		"name": "max_trigger_count",
		"type": "int",
		"min": 0,
		"max": 999,
	}, {
		"name": "required_lane_tags",
		"type": "packed_string_array",
	}]
	when_layer_destroyed.id = &"when_layer_destroyed"
	when_layer_destroyed.event_name = &"health.layer_destroyed"
	when_layer_destroyed.weight = 60
	when_layer_destroyed.max_bound_effects = 1
	when_layer_destroyed.param_defs = when_layer_destroyed_params
	when_layer_destroyed.allow_extra_conditions = false
	register_def(when_layer_destroyed, {"kind": &"core", "source": &"core"})

	var on_death = TriggerDefRef.new()
	on_death.id = &"on_death"
	on_death.event_name = &"entity.died"
	on_death.weight = 30
	on_death.max_bound_effects = 1
	on_death.allow_extra_conditions = false
	register_def(on_death, {"kind": &"core", "source": &"core"})

	var on_spawned = TriggerDefRef.new()
	on_spawned.id = &"on_spawned"
	on_spawned.event_name = &"entity.spawned"
	on_spawned.weight = 20
	on_spawned.max_bound_effects = 1
	on_spawned.allow_extra_conditions = false
	register_def(on_spawned, {"kind": &"core", "source": &"core"})

	var on_place = TriggerDefRef.new()
	on_place.id = &"on_place"
	on_place.event_name = &"placement.accepted"
	on_place.weight = 25
	on_place.max_bound_effects = 1
	on_place.allow_extra_conditions = false
	register_def(on_place, {"kind": &"core", "source": &"core"})

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
		"name": "scan_range_slots",
		"type": "float",
		"min": 0.0,
		"max": 64.0,
	}, {
		"name": "detection_id",
		"type": "string_name",
		"default": &"proximity",
		"options": PackedStringArray(["proximity", "lane_forward", "lane_backward", "radius_around"]),
	}, {
		"name": "target_tags",
		"type": "packed_string_array",
	}, {
		"name": "target_priority_tags",
		"type": "packed_string_array",
	}, {
		"name": "target_exclude_tags",
		"type": "packed_string_array",
	}, {
		"name": "required_state",
		"type": "string_name",
	}, {
		"name": "start_delay",
		"type": "float",
		"min": 0.0,
		"max": 30.0,
		"default": 0.0,
	}, {
		"name": "respect_visibility",
		"type": "bool",
		"default": false,
	}]
	proximity.id = &"proximity"
	proximity.event_name = &"game.tick"
	proximity.weight = 80
	proximity.max_bound_effects = 1
	proximity.param_defs = proximity_params
	proximity.allow_extra_conditions = false
	register_def(proximity, {"kind": &"core", "source": &"core"})

	_register_builtin_strategies()


func _register_builtin_strategies() -> void:
	register_strategy(&"periodically", func(event_data, condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		var interval := float(condition_values.get("interval", 1.0))
		var game_time := float(event_data.core.get("game_time", 0.0))
		var required_state := StringName(condition_values.get("required_state", StringName()))
		if required_state != StringName():
			var current_state := StringName(_entity_state.get("values", {}).get(&"state_stage", StringName()))
			if current_state != required_state:
				return false

		# Walking-distance fuse (original Jack-in-the-Box init, de-pvz
		# Zombie.cpp:429-434): fuse ticks = (450+Rand(300)) / mVelX *
		# ZOMBIE_LIMP_SPEED_FACTOR, with a 1/20 early-pop at one third of the
		# distance. Expressed as a time fuse derived once from the entity's own
		# sampled walk speed, so chewing (which halts movement) never halts the
		# fuse - matching the original counter that ticks regardless of biting.
		if condition_values.has("fuse_distance_min") or condition_values.has("fuse_distance_max"):
			var fuse_owner: Node = instance.owner_entity if instance != null else null
			if fuse_owner == null:
				return false
			var distance_roll: Variant = GameState.resolve_ranged_value(fuse_owner, condition_values, "fuse_distance")
			var fuse_distance := float(distance_roll) if distance_roll != null else float(condition_values.get("fuse_distance_min", 450.0))
			var early_probability := float(condition_values.get("early_trigger_probability", 0.0))
			if early_probability > 0.0:
				var early_roll := float(GameState.resolve_ranged_value(fuse_owner, {"early_roll_min": 0.0, "early_roll_max": 1.0}, "early_roll"))
				if early_roll < early_probability:
					fuse_distance *= float(condition_values.get("early_trigger_scale", 1.0))
			var walk_speed := _resolve_fuse_walk_speed(fuse_owner)
			var speed_factor := float(condition_values.get("fuse_speed_factor", 1.0))
			var fuse_seconds := fuse_distance * speed_factor / maxf(walk_speed * 96.0, 1.0)
			return game_time + 0.0001 - instance.bind_time >= fuse_seconds

		if not _lane_tags_match(instance, condition_values):
			return false

		var start_delay := float(condition_values.get("start_delay", 0.0))
		var timing_uses_window := _condition_uses_windowed_schedule(condition_values)
		var interval_min := float(condition_values.get("interval_min", -1.0))
		var interval_max := float(condition_values.get("interval_max", -1.0))
		var start_delay_min := float(condition_values.get("start_delay_min", -1.0))
		var start_delay_max := float(condition_values.get("start_delay_max", -1.0))
		if timing_uses_window:
			instance.initialize_window_schedule(start_delay_min, start_delay_max, start_delay)
			if not instance.is_window_schedule_ready(game_time):
				return false
		else:
			if start_delay > 0.0 and instance.last_triggered_time < -999999.0:
				if game_time - instance.bind_time < start_delay:
					return false
			if game_time - instance.last_triggered_time < interval:
				return false

		var detection_id := StringName(condition_values.get("detection_id", &"always"))
		if detection_id == StringName() or detection_id == &"always":
			if timing_uses_window:
				instance.schedule_next_window(interval_min, interval_max, interval, game_time)
			return true

		if not _lane_offset_probe_in_bounds(instance, condition_values):
			return false

		var detection_params := {
			"scan_range": float(condition_values.get("scan_range", 900.0)),
			"range_mode": StringName(condition_values.get("range_mode", StringName())),
			"target_tags": PackedStringArray(condition_values.get("target_tags", PackedStringArray())),
			"target_priority_tags": PackedStringArray(condition_values.get("target_priority_tags", PackedStringArray())),
			"target_exclude_tags": PackedStringArray(condition_values.get("target_exclude_tags", PackedStringArray())),
			"respect_visibility": bool(condition_values.get("respect_visibility", false)),
			"team_mode": StringName(condition_values.get("team_mode", &"enemies")),
			"target_selection": StringName(condition_values.get("target_selection", StringName())),
		}
		if condition_values.has("scan_range_slots"):
			detection_params["scan_range_slots"] = float(condition_values.get("scan_range_slots"))
		if condition_values.has("min_scan_range"):
			detection_params["min_scan_range"] = float(condition_values.get("min_scan_range"))
		if condition_values.has("min_scan_range_slots"):
			detection_params["min_scan_range_slots"] = float(condition_values.get("min_scan_range_slots"))
		if condition_values.has("lane_offset"):
			detection_params["lane_offset"] = int(condition_values.get("lane_offset"))
		if condition_values.has("x_offset"):
			detection_params["x_offset"] = float(condition_values.get("x_offset"))
		var detection_result: Dictionary = DetectionRegistry.evaluate(detection_id, instance.owner_entity, detection_params)
		var require_no_target := bool(condition_values.get("require_no_target", false))

		if require_no_target:
			# Maintenance-style vacancy triggers (original SummonBackupDancers
			# per-slot follower check) fire when the probe finds NO matching
			# entity, so payloads must not depend on detection context.
			if bool(detection_result.get("has_target", false)):
				return false
		elif not bool(detection_result.get("has_target", false)):
			return false

		if not require_no_target:
			var detected_target_ids := PackedInt32Array()
			for target in Array(detection_result.get("targets", [])):
				if target != null and target.has_method("get_entity_id"):
					detected_target_ids.append(int(target.call("get_entity_id")))
			instance.set_pending_context_overrides({
				"target_node": detection_result.get("primary_target", null),
				"detection_id": detection_id,
				"detected_target_ids": detected_target_ids,
			})
		if timing_uses_window:
			instance.schedule_next_window(interval_min, interval_max, interval, game_time)
		return true
	)

	register_strategy(&"when_damaged", func(event_data, condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		if event_data.core.get("target_node", null) != instance.owner_entity:
			return false
		# Position-gated reactions (original Gargantuar throws only while
		# aThrowingDistance > 40, i.e. mPosX > 400, de-pvz Zombie.cpp:2208-2213).
		if condition_values.has("min_owner_x"):
			var owner: Variant = instance.owner_entity if instance != null else null
			if owner == null or not (owner is Node2D):
				return false
			if (owner as Node2D).position.x < float(condition_values.get("min_owner_x", 0.0)):
				return false
		var min_damage := int(condition_values.get("min_damage", 0))
		if int(event_data.core.get("value", 0)) < min_damage:
			return false
		var required_damage_tags := PackedStringArray(condition_values.get("required_damage_tags", PackedStringArray()))
		if not required_damage_tags.is_empty():
			var event_tags := PackedStringArray(event_data.core.get("tags", PackedStringArray()))
			for required_tag: String in required_damage_tags:
				if not event_tags.has(required_tag):
					return false
		if condition_values.has("max_health_fraction_at_or_below"):
			var maximum_health := float(event_data.core.get("max_health", 0))
			if maximum_health <= 0.0:
				return false
			var current_health := float(event_data.core.get("health", maximum_health))
			if current_health / maximum_health > float(condition_values.get("max_health_fraction_at_or_below", 1.0)) + 0.0001:
				return false
		var once_key := StringName(condition_values.get("once_key", StringName()))
		if once_key != StringName() and instance.owner_entity != null:
			var state_ref: Variant = null
			if instance.owner_entity.has_method("get_entity_state_ref"):
				state_ref = instance.owner_entity.call("get_entity_state_ref")
			if state_ref != null and state_ref.has_method("get_value"):
				var used_keys := PackedStringArray(state_ref.call("get_value", &"trigger_once_keys", PackedStringArray()))
				if used_keys.has(String(once_key)):
					return false
				used_keys.append(String(once_key))
				if instance.owner_entity.has_method("set_state_value"):
					instance.owner_entity.call("set_state_value", &"trigger_once_keys", used_keys)
		return true
	)

	register_strategy(&"when_layer_destroyed", func(event_data, condition_values: Dictionary, _entity_state: Dictionary, instance) -> bool:
		if event_data.core.get("target_node", null) != instance.owner_entity:
			return false
		if not _lane_tags_match(instance, condition_values):
			return false
		var required_layer_id := StringName(condition_values.get("required_layer_id", StringName()))
		if required_layer_id != StringName() and StringName(event_data.core.get("layer_id", StringName())) != required_layer_id:
			return false
		return true
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
		var detection_id := StringName(condition_values.get("detection_id", &"proximity"))
		if detection_id == StringName():
			detection_id = &"proximity"
		var detection_params := {
			"scan_range": scan_range,
			"target_tags": PackedStringArray(condition_values.get("target_tags", PackedStringArray())),
			"target_priority_tags": PackedStringArray(condition_values.get("target_priority_tags", PackedStringArray())),
			"target_exclude_tags": PackedStringArray(condition_values.get("target_exclude_tags", PackedStringArray())),
			"respect_visibility": bool(condition_values.get("respect_visibility", false)),
		}
		if condition_values.has("scan_range_slots"):
			detection_params["scan_range_slots"] = float(condition_values.get("scan_range_slots"))
		var detection_result: Dictionary = DetectionRegistry.evaluate(detection_id, instance.owner_entity, detection_params)
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


func register_strategy(trigger_id: StringName, strategy: Callable) -> void:
	if trigger_id == StringName() or not strategy.is_valid():
		return
	_trigger_strategies[trigger_id] = strategy


func _validate_def_specific(trigger_def: Resource, source: Dictionary) -> Array[String]:
	var errors: Array[String] = ProtocolValidatorRef.validate_trigger_def(trigger_def)
	if bool(source.get("extension", false)):
		if trigger_def.strategy_script == null or not (trigger_def.strategy_script is Script):
			errors.append("TriggerDef %s strategy_script must be a Script." % String(trigger_def.id))
		else:
			var strategy_owner = trigger_def.strategy_script.new()
			if strategy_owner == null or not strategy_owner.has_method("evaluate"):
				errors.append("TriggerDef %s strategy_script must expose evaluate(event_data, condition_values, entity_state, instance)." % String(trigger_def.id))
	return errors


func _on_def_registered(entry: Dictionary) -> void:
	var source: Dictionary = Dictionary(entry.get("source", {}))
	if bool(source.get("extension", false)):
		var def = entry.get("def", null)
		if def != null and def.strategy_script != null:
			var strategy_owner = def.strategy_script.new()
			if strategy_owner != null and strategy_owner.has_method("evaluate"):
				_trigger_strategy_owners[def.id] = strategy_owner
				_trigger_strategies[def.id] = Callable(strategy_owner, "evaluate")


func _lane_tags_match(instance, condition_values: Dictionary) -> bool:
	# Lane-scoped gating (original Balloon water-landing death on pool rows):
	# when required_lane_tags is set, the owner's lane traits must carry at
	# least one of them; missing board/battle state fails closed to no-fire.
	var required_tags := PackedStringArray(condition_values.get("required_lane_tags", PackedStringArray()))
	if required_tags.is_empty():
		return true
	var owner: Variant = instance.owner_entity if instance != null else null
	if owner == null or not is_instance_valid(owner):
		return false
	var lane_value: Variant = owner.get("lane_id")
	if not (lane_value is int) or int(lane_value) < 0:
		return false
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("get_board_state"):
		return false
	var board_state: Variant = battle.call("get_board_state")
	if board_state == null or not board_state.has_method("get_lane_traits"):
		return false
	var lane_tags: PackedStringArray = board_state.call("get_lane_traits", int(lane_value))
	for required_tag: String in required_tags:
		if lane_tags.has(required_tag):
			return true
	return false


func _condition_uses_windowed_schedule(condition_values: Dictionary) -> bool:
	for key in ["interval_min", "interval_max", "start_delay_min", "start_delay_max"]:
		if condition_values.has(key):
			return true
	return false


func _resolve_fuse_walk_speed(owner: Node) -> float:
	# The distance fuse divides by the owner's OWN sampled walk speed (the
	# original reads mVelX right after PickRandomSpeed). Resolving through the
	# same ranged-value cache the movement path uses means both consumers see
	# one roll per entity.
	var speed_params: Dictionary = {}
	if owner.has_method("get_entity_state_ref"):
		var state_ref: Variant = owner.call("get_entity_state_ref")
		if state_ref != null and state_ref.has_method("get_value"):
			var movement_spec: Variant = state_ref.call("get_value", &"movement_spec", {})
			if movement_spec is Dictionary:
				speed_params = Dictionary(Dictionary(movement_spec).get("params", {}))
	var sampled: Variant = GameState.resolve_ranged_value(owner, speed_params, "move_speed_slots_per_sec")
	if sampled != null:
		return float(sampled)
	return float(speed_params.get("move_speed_slots_per_sec", 0.275))


func _lane_offset_probe_in_bounds(instance, condition_values: Dictionary) -> bool:
	# A lane_offset vacancy probe must never fire when the probed lane falls
	# outside the board (original SummonBackupDancer simply no-ops on invalid
	# rows); firing there would clamp-summon onto the leader's own lane.
	if not condition_values.has("lane_offset") or instance == null:
		return true
	var owner: Variant = instance.owner_entity if instance != null else null
	if owner == null or not is_instance_valid(owner):
		return false
	var lane_id := int(owner.get("lane_id")) if owner.get("lane_id") != null else -1
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("is_valid_lane"):
		return false
	return bool(battle.call("is_valid_lane", lane_id + int(condition_values.get("lane_offset", 0))))
