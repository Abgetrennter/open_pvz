extends Node

var _compiler_specs: Dictionary = {}
var _compiler_callables: Dictionary = {}


func register_compiler(type_id: StringName, metadata: Dictionary = {}) -> void:
	if type_id == StringName():
		return
	_compiler_specs[type_id] = metadata.duplicate(true)


func register_compiler_callable(type_id: StringName, callable: Callable, metadata: Dictionary = {}) -> void:
	if type_id == StringName() or not callable.is_valid():
		return
	_compiler_specs[type_id] = metadata.duplicate(true)
	_compiler_callables[type_id] = callable


func has_compiler(type_id: StringName) -> bool:
	return _compiler_specs.has(type_id)


func has_compiler_callable(type_id: StringName) -> bool:
	return _compiler_callables.has(type_id)


func get_metadata(type_id: StringName) -> Dictionary:
	return Dictionary(_compiler_specs.get(type_id, {}))


func compile_type(type_id: StringName, mechanic, archetype, merged_params: Dictionary) -> Dictionary:
	var callable: Callable = _compiler_callables.get(type_id, Callable())
	if not callable.is_valid():
		return {}
	var result: Variant = callable.call(mechanic, archetype, merged_params)
	if not (result is Dictionary):
		return {}
	return result


func list_type_ids() -> PackedStringArray:
	var keys := PackedStringArray()
	for key in _compiler_specs.keys():
		keys.append(String(key))
	keys.sort()
	return keys
