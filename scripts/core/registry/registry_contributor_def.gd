extends Resource
class_name RegistryContributorDef

@export var id: StringName = StringName()
@export var tags: PackedStringArray = PackedStringArray()
@export var param_defs: Array[Dictionary] = []


func get_param_def(param_name: StringName) -> Dictionary:
	for param_def in param_defs:
		if StringName(param_def.get("name", StringName())) == param_name:
			return param_def
	return {}
