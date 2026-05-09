extends Node
class_name ControllerComponent

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var controller_specs: Array[Dictionary] = []
var blackboard: Dictionary = {}
var _controllers_disabled_reported := false


func bind_controller_specs(specs: Array) -> void:
	controller_specs.clear()
	blackboard.clear()
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
	if owner.has_method("is_liveness_enabled") and not bool(owner.call("is_liveness_enabled", &"controllers")):
		if owner.has_method("on_controllers_disabled"):
			owner.call("on_controllers_disabled", delta)
		_emit_controllers_disabled(owner)
		return
	_controllers_disabled_reported = false
	for spec in controller_specs:
		var controller_id := StringName(spec.get("controller_id", StringName()))
		if controller_id == StringName():
			continue
		var mechanic_id := StringName(spec.get("mechanic_id", controller_id))
		if not blackboard.has(mechanic_id):
			blackboard[mechanic_id] = {}
		var mechanic_bb: Dictionary = blackboard[mechanic_id]
		ControllerRegistry.process_controller(controller_id, owner, spec, delta, mechanic_bb)


func _emit_controllers_disabled(owner: Node) -> void:
	if _controllers_disabled_reported:
		return
	_controllers_disabled_reported = true
	var observed_event: Variant = EventDataRef.create(owner, null, null, PackedStringArray(["status", "controllers_disabled"]))
	observed_event.core["effect"] = &"controllers_disabled"
	EventBus.push_event(&"status.effect_observed", observed_event)
