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
