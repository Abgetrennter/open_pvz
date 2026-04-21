extends Node

var _families: Dictionary = {}


func _ready() -> void:
	_register_builtin_families()


func register_family(family_id: StringName, metadata: Dictionary = {}) -> void:
	if family_id == StringName():
		return
	_families[family_id] = metadata.duplicate(true)


func has_family(family_id: StringName) -> bool:
	return _families.has(family_id)


func get_family_metadata(family_id: StringName) -> Dictionary:
	return Dictionary(_families.get(family_id, {}))


func list_family_ids() -> PackedStringArray:
	var keys := PackedStringArray()
	for key in _families.keys():
		keys.append(String(key))
	keys.sort()
	return keys


func _register_builtin_families() -> void:
	for family_name in [
		&"Trigger",
		&"Targeting",
		&"Emission",
		&"Trajectory",
		&"HitPolicy",
		&"Payload",
		&"State",
		&"Lifecycle",
		&"Placement",
		&"Controller",
	]:
		register_family(family_name)
