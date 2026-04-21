extends Node
class_name ControllerComponent

var controller_specs: Array[Dictionary] = []


func bind_controller_specs(specs: Array) -> void:
	controller_specs.clear()
	for spec in specs:
		if spec is Dictionary:
			controller_specs.append(spec.duplicate(true))


func has_active_controllers() -> bool:
	return not controller_specs.is_empty()


func physics_process_controllers(delta: float) -> void:
	if controller_specs.is_empty():
		return
	var owner := get_parent()
	if owner == null:
		return
	for spec in controller_specs:
		var controller_id := StringName(spec.get("controller_id", StringName()))
		if controller_id == StringName():
			continue
		ControllerRegistry.process_controller(controller_id, owner, spec, delta)
