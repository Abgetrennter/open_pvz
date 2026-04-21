extends Node

var _compiler_specs: Dictionary = {}


func register_compiler(type_id: StringName, metadata: Dictionary = {}) -> void:
	if type_id == StringName():
		return
	_compiler_specs[type_id] = metadata.duplicate(true)


func has_compiler(type_id: StringName) -> bool:
	return _compiler_specs.has(type_id)


func get_metadata(type_id: StringName) -> Dictionary:
	return Dictionary(_compiler_specs.get(type_id, {}))
