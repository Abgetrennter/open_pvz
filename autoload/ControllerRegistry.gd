extends Node

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var _controller_strategies: Dictionary = {}


func _ready() -> void:
	_register_builtin_strategies()


func register_strategy(controller_id: StringName, strategy: Callable) -> void:
	if controller_id == StringName() or not strategy.is_valid():
		return
	_controller_strategies[controller_id] = strategy


func get_strategy(controller_id: StringName) -> Callable:
	return _controller_strategies.get(controller_id, Callable())


func process_controller(controller_id: StringName, owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary = {}) -> void:
	var strategy: Callable = get_strategy(controller_id)
	if not strategy.is_valid():
		return
	strategy.call(owner, spec, delta, blackboard)


func _register_builtin_strategies() -> void:
	register_strategy(&"core.bite", func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if owner.get("_is_dying") == true:
			return
		if owner.has_method("perform_attack_cycle_for_controller"):
			owner.call("perform_attack_cycle_for_controller", spec, delta)
	)

	register_strategy(&"core.sweep", func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if not owner is Node2D:
			return
		var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
		var move_speed: float = float(params.get("move_speed", 300.0))
		var detection_radius: float = float(params.get("detection_radius", 50.0))
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
	)

	register_strategy(&"core.ground_damage", func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if not owner is Node2D:
			return
		var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
		var damage: int = int(params.get("damage", 20))
		var interval: float = float(params.get("interval", 0.5))
		var detection_range: float = float(params.get("detection_range", 48.0))
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
	)

	register_strategy(&"core.projectile_transform", func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if GameState.current_battle == null:
			return
		var params: Dictionary = spec.get("params", {}) if spec.get("params") is Dictionary else {}
		var multipler: float = float(params.get("damage_multiplier", 2.0))
		var detection_range: float = float(params.get("detection_range", 64.0))
		var last_tick: float = float(blackboard.get("last_transform_tick", 0.0))
		var current_time: float = Time.get_ticks_msec() / 1000.0
		if current_time - last_tick < 0.1:
			return
		blackboard["last_transform_tick"] = current_time
		for child in GameState.current_battle.call("get_runtime_entities"):
			if child == null or child == owner:
				continue
			if not (child is Node2D):
				continue
			if child.get("entity_kind") != &"projectile":
				continue
			if not child.has_method("modify"):
				continue
			if not _check_projectile_nearby(owner, child, detection_range):
				continue
			child.call("modify", {"damage_multiplier": multipler})
	)


func _check_projectile_nearby(owner: Node, projectile: Node, detection_range: float) -> bool:
	if owner == null or projectile == null:
		return false
	if not (owner is Node2D) or not (projectile is Node2D):
		return false
	var owner_pos: Vector2 = (owner as Node2D).global_position
	var proj_pos: Vector2 = (projectile as Node2D).global_position
	return owner_pos.distance_to(proj_pos) <= detection_range
