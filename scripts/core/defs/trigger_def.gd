extends "res://scripts/core/registry/registry_contributor_def.gd"
class_name TriggerDef

@export var event_name: StringName = StringName()
@export var weight := 1
@export var max_bound_effects := 1
@export var allow_extra_conditions := false
@export var strategy_script: Script = null


func get_condition_param_def(param_name: StringName) -> Dictionary:
	for param_def in param_defs:
		if StringName(param_def.get("name", StringName())) == param_name:
			return param_def
	return {}
