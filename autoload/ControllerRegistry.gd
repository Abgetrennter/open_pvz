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


func process_controller(controller_id: StringName, owner: Node, spec: Dictionary, delta: float) -> void:
	var strategy: Callable = get_strategy(controller_id)
	if not strategy.is_valid():
		return
	strategy.call(owner, spec, delta)


func _register_builtin_strategies() -> void:
	register_strategy(&"core.bite", func(owner: Node, spec: Dictionary, delta: float) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if owner.get("_is_dying") == true:
			return
		if not owner.has_method("find_attack_target_for_controller"):
			return
		if not owner.has_method("perform_attack_cycle_for_controller"):
			return
		owner.call("perform_attack_cycle_for_controller", spec, delta)
	)

	register_strategy(&"core.sweep", func(owner: Node, spec: Dictionary, delta: float) -> void:
		if owner == null or not is_instance_valid(owner):
			return
		if not owner.has_method("perform_sweep_cycle_for_controller"):
			return
		owner.call("perform_sweep_cycle_for_controller", spec, delta)
	)
