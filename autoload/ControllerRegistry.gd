extends Node

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
		var detection_id: StringName = StringName(spec.get("detection_id", &"lane_forward"))
		var scan_range: float = float(spec.params.get("attack_range", spec.params.get("scan_range", 56.0))) if spec.get("params") is Dictionary else 56.0
		var attack_interval: float = float(spec.params.get("attack_interval", 0.3)) if spec.get("params") is Dictionary else 0.3
		var attack_damage: int = int(spec.params.get("attack_damage", 10)) if spec.get("params") is Dictionary else 10
		var move_speed: float = float(spec.params.get("move_speed", 0.0)) if spec.get("params") is Dictionary else 0.0
		var attack_range: float = float(spec.params.get("attack_range", 56.0)) if spec.get("params") is Dictionary else 56.0
		if not blackboard.has("attack_cooldown"):
			blackboard["attack_cooldown"] = 0.0
		var cooldown: float = float(blackboard["attack_cooldown"])
		cooldown -= delta
		blackboard["attack_cooldown"] = cooldown
		if move_speed > 0.001 and owner is Node2D:
			(owner as Node2D).position.x += move_speed * delta
		var detection_params := {"scan_range": attack_range}
		var detection_result: Dictionary = DetectionRegistry.evaluate(detection_id, owner, detection_params)
		if not bool(detection_result.get("has_target", false)):
			return
		var target: Node = detection_result.get("primary_target", null)
		if target == null or not is_instance_valid(target):
			return
		if not target.has_method("take_damage"):
			return
		var distance := (target.global_position if target is Node2D else Vector2.ZERO).distance_to(owner.global_position if owner is Node2D else Vector2.ZERO)
		if distance <= attack_range and cooldown <= 0.0:
			target.call("take_damage", attack_damage, owner, ["bite"])
			blackboard["attack_cooldown"] = attack_interval
	)

	register_strategy(&"core.sweep", func(owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if not owner is Node2D:
			return
		var sweep_state: String = String(blackboard.get("mower_state", "idle"))
		var move_speed: float = float(spec.params.get("move_speed", 300.0)) if spec.get("params") is Dictionary else 300.0
		var detection_radius: float = float(spec.params.get("detection_radius", 50.0)) if spec.get("params") is Dictionary else 50.0
		if sweep_state == "idle":
			var detection_result: Dictionary = DetectionRegistry.evaluate(&"lane_forward", owner, {"scan_range": detection_radius})
			if bool(detection_result.get("has_target", false)):
				blackboard["mower_state"] = "triggered"
				if owner.has_method("set"):
					owner.set("_mower_state", "triggered")
				var field_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(owner, owner, null, PackedStringArray(["field_object", "activated"]))
				EventBus.push_event(&"field_object.activated", field_event)
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
				if owner.has_method("set"):
					owner.set("_mower_state", "expired")
	)
