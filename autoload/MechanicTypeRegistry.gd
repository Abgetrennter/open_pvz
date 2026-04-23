extends Node

const MechanicCompilerRef = preload("res://scripts/core/runtime/mechanic_compiler.gd")

var _type_specs: Dictionary = {}


func _ready() -> void:
	MechanicCompilerRef.register_builtin_mechanic_types()


func register_type(type_id: StringName, family_id: StringName, metadata: Dictionary = {}) -> void:
	if type_id == StringName() or family_id == StringName():
		return
	if not MechanicFamilyRegistry.has_family(family_id):
		push_error("MechanicTypeRegistry: rejected type '%s' with unknown family '%s'" % [String(type_id), String(family_id)])
		return
	_type_specs[type_id] = {
		"family_id": family_id,
		"metadata": metadata.duplicate(true),
	}


func has_type(type_id: StringName) -> bool:
	return _type_specs.has(type_id)


func get_family_id(type_id: StringName) -> StringName:
	return StringName(Dictionary(_type_specs.get(type_id, {})).get("family_id", StringName()))


func get_metadata(type_id: StringName) -> Dictionary:
	return Dictionary(Dictionary(_type_specs.get(type_id, {})).get("metadata", {}))


func list_type_ids() -> PackedStringArray:
	var keys := PackedStringArray()
	for key in _type_specs.keys():
		keys.append(String(key))
	keys.sort()
	return keys
