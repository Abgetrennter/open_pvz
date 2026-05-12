extends "res://scripts/core/registry/registry_base.gd"

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const ControllerDefRef = preload("res://scripts/core/defs/controller_def.gd")

var _controller_strategies: Dictionary = {}
var _controller_strategy_owners: Dictionary = {}


func _make_registry_config():
	return RegistryConfigRef.create(
		&"controllers",
		ControllerDefRef,
		&"controllers",
		"data/combat/controllers",
		&"trusted_runtime",
		StringName(),
		false
	)


func _on_registry_cleared() -> void:
	_controller_strategies.clear()
	_controller_strategy_owners.clear()


func _register_builtin_defs() -> void:
	var bite_def = ControllerDefRef.new()
	bite_def.id = &"core.bite"
	register_def(bite_def, {"kind": &"core", "source": &"core"})

	var sweep_def = ControllerDefRef.new()
	sweep_def.id = &"core.sweep"
	register_def(sweep_def, {"kind": &"core", "source": &"core"})

	var ground_damage_def = ControllerDefRef.new()
	ground_damage_def.id = &"core.ground_damage"
	register_def(ground_damage_def, {"kind": &"core", "source": &"core"})

	var projectile_transform_def = ControllerDefRef.new()
	projectile_transform_def.id = &"core.projectile_transform"
	register_def(projectile_transform_def, {"kind": &"core", "source": &"core"})

	var collectible_magnet_def = ControllerDefRef.new()
	collectible_magnet_def.id = &"core.collectible_magnet"
	register_def(collectible_magnet_def, {"kind": &"core", "source": &"core"})

	var proximity_liveness_def = ControllerDefRef.new()
	proximity_liveness_def.id = &"core.proximity_liveness"
	register_def(proximity_liveness_def, {"kind": &"core", "source": &"core"})

	_register_builtin_strategies()


func process_controller(controller_id: StringName, owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary = {}) -> void:
	var strategy: Callable = _controller_strategies.get(controller_id, Callable())
	if not strategy.is_valid():
		return
	strategy.call(owner, spec, delta, blackboard)


func _validate_def_specific(controller_def: Resource, source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if bool(source.get("extension", false)):
		if controller_def.strategy_script == null or not (controller_def.strategy_script is Script):
			errors.append("ControllerDef %s strategy_script must be a Script." % String(controller_def.id))
		else:
			var strategy_owner = controller_def.strategy_script.new()
			if strategy_owner == null or not strategy_owner.has_method("process"):
				errors.append("ControllerDef %s strategy_script must expose process(owner, spec, delta, blackboard)." % String(controller_def.id))
	return errors


func _on_def_registered(entry: Dictionary) -> void:
	var source: Dictionary = Dictionary(entry.get("source", {}))
	if not bool(source.get("extension", false)):
		return
	var controller_def = entry.get("def", null)
	if controller_def == null or controller_def.strategy_script == null:
		return
	var strategy_owner = controller_def.strategy_script.new()
	if strategy_owner == null or not strategy_owner.has_method("process"):
		return
	_controller_strategy_owners[controller_def.id] = strategy_owner
	_controller_strategies[controller_def.id] = Callable(strategy_owner, "process")


func _register_builtin_strategies() -> void:
	_controller_strategies[&"core.bite"] = func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if owner.get("_is_dying") == true:
			return
		if owner.has_method("perform_attack_cycle_for_controller"):
			owner.call("perform_attack_cycle_for_controller", spec, delta)

	_controller_strategies[&"core.sweep"] = func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if not owner is Node2D:
			return
		var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
		var move_speed: float = _resolve_slots_speed(params, "move_speed_slots_per_sec", "move_speed", 300.0)
		var detection_radius: float = _resolve_slots_distance(params, "detection_radius_slots", "detection_radius", 50.0)
		var sweep_state: String = String(blackboard.get("mower_state", "idle"))
		if sweep_state == "idle":
			var detection_result: Dictionary = DetectionRegistry.evaluate(&"lane_forward", owner, {"scan_range": detection_radius})
			if bool(detection_result.get("has_target", false)):
				blackboard["mower_state"] = "triggered"
				var activated_event: Variant = EventDataRef.create(owner, owner, null, PackedStringArray(["field_object", "activated"]))
				activated_event.core["entity_id"] = int(owner.get("entity_id")) if owner.get("entity_id") != null else -1
				activated_event.core["lane_id"] = int(owner.get("lane_id")) if owner.get("lane_id") != null else -1
				activated_event.core["object_type"] = &"mower"
				EventBus.push_event(&"field_object.activated", activated_event)
		elif sweep_state == "triggered":
			var owner_2d: Node2D = owner as Node2D
			owner_2d.position.x += move_speed * delta
			var detection_result: Dictionary = DetectionRegistry.evaluate(&"lane_forward", owner, {"scan_range": 20.0})
			for target in Array(detection_result.get("targets", [])):
				if target == null or not is_instance_valid(target):
					continue
				if not target.has_method("take_damage"):
					continue
				target.call("take_damage", 9999, owner, ["mower", "sweep"])
			if owner_2d.position.x > 1000.0:
				blackboard["mower_state"] = "expired"
				var expired_event: Variant = EventDataRef.create(owner, owner, null, PackedStringArray(["field_object", "expired"]))
				expired_event.core["entity_id"] = int(owner.get("entity_id")) if owner.get("entity_id") != null else -1
				expired_event.core["lane_id"] = int(owner.get("lane_id")) if owner.get("lane_id") != null else -1
				expired_event.core["object_type"] = &"mower"
				EventBus.push_event(&"field_object.expired", expired_event)
				owner.queue_free()

	_controller_strategies[&"core.ground_damage"] = func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if not owner is Node2D:
			return
		var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
		var damage: int = int(params.get("damage", 20))
		var interval: float = float(params.get("interval", 0.5))
		var detection_range: float = _resolve_slots_distance(params, "detection_range_slots", "detection_range", 48.0)
		var acc_time: float = float(blackboard.get("acc_time", 0.0))
		acc_time += delta
		if acc_time < interval:
			blackboard["acc_time"] = acc_time
			return
		blackboard["acc_time"] = acc_time - interval
		var detection_result: Dictionary = DetectionRegistry.evaluate(&"radius_around", owner, {"scan_range": detection_range})
		for target in Array(detection_result.get("targets", [])):
			if target == null or not is_instance_valid(target):
				continue
			if not target.has_method("take_damage"):
				continue
			target.call("take_damage", damage, owner, ["ground_damage", "spike"])

	_controller_strategies[&"core.projectile_transform"] = func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if not owner is Node2D:
			return
		if GameState.current_battle == null:
			return
		var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
		var multipler: float = float(params.get("damage_multiplier", 2.0))
		var detection_range: float = _resolve_slots_distance(params, "detection_range_slots", "detection_range", 64.0)
		var last_tick: float = float(blackboard.get("last_transform_tick", -999999.0))
		var current_time: float = GameState.current_time
		if current_time - last_tick < 0.1:
			return
		blackboard["last_transform_tick"] = current_time
		if not GameState.current_battle.has_method("spatial_query"):
			return
		var projectiles: Array = GameState.current_battle.call("spatial_query", {
			"kinds": PackedStringArray(["projectile"]),
			"center": (owner as Node2D).global_position,
			"radius": detection_range,
			"filter": func(candidate):
				return candidate != owner and candidate.has_method("modify"),
		})
		for child in projectiles:
			child.call("modify", {"damage_multiplier": multipler})

	_controller_strategies[&"core.collectible_magnet"] = func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		_process_collectible_magnet(owner, spec, delta, blackboard)

	_controller_strategies[&"core.proximity_liveness"] = func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		_process_proximity_liveness(owner, spec, delta, blackboard)


func _process_collectible_magnet(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	if not owner is Node2D:
		return
	if GameState.current_battle == null or not GameState.current_battle.has_method("get_economy_state"):
		return
	var economy: Node = GameState.current_battle.call("get_economy_state")
	if economy == null or not is_instance_valid(economy):
		return
	var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
	var interval: float = maxf(float(params.get("interval", 1.0)), 0.01)
	var acc_time: float = float(blackboard.get("acc_time", 0.0)) + delta
	if acc_time < interval:
		blackboard["acc_time"] = acc_time
		return
	blackboard["acc_time"] = acc_time - interval
	var collectible: Node = _find_collectible_magnet_target(owner as Node2D, economy, params)
	if collectible == null:
		return
	var collected_value := int(collectible.get("sun_value"))
	var source_type := StringName(collectible.get("source_type"))
	var sun_id := int(collectible.get("sun_id"))
	if not economy.call("collect_sun", collectible, owner):
		return
	var collected_event: Variant = EventDataRef.create(owner, collectible, collected_value, PackedStringArray(["collectible", "magnet"]))
	collected_event.core["collector_id"] = int(owner.call("get_entity_id")) if owner.has_method("get_entity_id") else -1
	collected_event.core["collector_archetype_id"] = StringName(owner.get("archetype_id")) if owner.get("archetype_id") != null else StringName()
	collected_event.core["sun_id"] = sun_id
	collected_event.core["source_type"] = source_type
	collected_event.core["value"] = collected_value
	EventBus.push_event(&"collectible.magnet_collected", collected_event)


func _find_collectible_magnet_target(owner: Node2D, economy: Node, params: Dictionary) -> Node:
	var active_suns: Dictionary = Dictionary(economy.get("active_suns")) if economy.get("active_suns") is Dictionary else {}
	if active_suns.is_empty():
		return null
	var scan_range: float = _resolve_slots_distance(params, "scan_range_slots", "scan_range", 4000.0)
	var allowed_source_types := _resolve_source_type_filter(params.get("source_types", PackedStringArray(["coin_generated"])))
	var best_collectible: Node = null
	var best_distance := INF
	var best_sun_id := 9223372036854775807
	for candidate in active_suns.values():
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate is Node2D:
			continue
		if bool(candidate.get("collected")):
			continue
		var source_type := StringName(candidate.get("source_type"))
		if not allowed_source_types.is_empty() and not allowed_source_types.has(source_type):
			continue
		var distance := owner.global_position.distance_to((candidate as Node2D).global_position)
		if distance > scan_range:
			continue
		var sun_id := int(candidate.get("sun_id"))
		if best_collectible == null or distance < best_distance or (is_equal_approx(distance, best_distance) and sun_id < best_sun_id):
			best_collectible = candidate
			best_distance = distance
			best_sun_id = sun_id
	return best_collectible


func _process_proximity_liveness(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	if not owner is Node2D:
		return
	var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
	var interval: float = maxf(float(params.get("interval", 0.1)), 0.01)
	var acc_time: float = float(blackboard.get("acc_time", 0.0)) + delta
	if acc_time < interval:
		blackboard["acc_time"] = acc_time
		return
	blackboard["acc_time"] = acc_time - interval
	var scan_range: float = _resolve_slots_distance(params, "scan_range_slots", "scan_range", 96.0)
	var detection_id := StringName(params.get("detection_id", &"proximity"))
	var detection_result: Dictionary = DetectionRegistry.evaluate(detection_id, owner, {
		"scan_range": scan_range,
		"target_tags": PackedStringArray(params.get("target_tags", PackedStringArray())),
	})
	var has_target := bool(detection_result.get("has_target", false))
	var source_id := StringName(params.get("source_id", spec.get("mechanic_id", &"proximity_liveness")))
	var active_state := StringName(params.get("active_state", &"active"))
	var inactive_state := StringName(params.get("inactive_state", &"inactive"))
	if has_target:
		var profile: Dictionary = Dictionary(params.get("liveness_overrides", {})).duplicate(true)
		if not profile.is_empty() and owner.has_method("push_liveness_override"):
			owner.call("push_liveness_override", source_id, profile, 10)
		if owner.has_method("set_state_value"):
			owner.call("set_state_value", &"proximity_liveness_state", active_state)
	else:
		if owner.has_method("pop_liveness_override"):
			owner.call("pop_liveness_override", source_id)
		if owner.has_method("set_state_value"):
			owner.call("set_state_value", &"proximity_liveness_state", inactive_state)


func _resolve_source_type_filter(raw_value: Variant) -> Array[StringName]:
	var resolved: Array[StringName] = []
	if raw_value is PackedStringArray:
		for source_type in PackedStringArray(raw_value):
			resolved.append(StringName(source_type))
	elif raw_value is Array:
		for source_type in Array(raw_value):
			resolved.append(StringName(source_type))
	elif raw_value != null:
		resolved.append(StringName(raw_value))
	return resolved


func _resolve_slots_distance(params: Dictionary, slots_key: String, legacy_key: String, default_world: float) -> float:
	var metrics := _get_battlefield_metrics()
	if metrics != null and metrics.has_method("resolve_slots_distance"):
		return float(metrics.call("resolve_slots_distance", params, slots_key, legacy_key, default_world))
	if params.has(slots_key):
		return float(params.get(slots_key)) * 96.0
	return float(params.get(legacy_key, default_world))


func _resolve_slots_speed(params: Dictionary, slots_key: String, legacy_key: String, default_world_per_sec: float) -> float:
	var metrics := _get_battlefield_metrics()
	if metrics != null and metrics.has_method("resolve_slots_speed"):
		return float(metrics.call("resolve_slots_speed", params, slots_key, legacy_key, default_world_per_sec))
	if params.has(slots_key):
		return float(params.get(slots_key)) * 96.0
	return float(params.get(legacy_key, default_world_per_sec))


func _get_battlefield_metrics() -> RefCounted:
	if GameState.current_battle == null:
		return null
	if not GameState.current_battle.has_method("get_battlefield_metrics"):
		return null
	var metrics: Variant = GameState.current_battle.call("get_battlefield_metrics")
	return metrics if metrics is RefCounted else null
