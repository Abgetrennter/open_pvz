extends Resource
class_name TriggerDef

@export var trigger_id: StringName = StringName()
@export var event_name: StringName = StringName()
@export var weight := 1
@export var max_bound_effects := 1
@export var condition_params: Array[Dictionary] = []
@export var allow_extra_conditions := false
@export var tags: PackedStringArray = PackedStringArray()


func get_condition_param_def(param_name: StringName) -> Dictionary:
	for param_def in condition_params:
		if StringName(param_def.get("name", StringName())) == param_name:
			return param_def
	return {}
