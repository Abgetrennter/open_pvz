extends Node

const CombatMechanicRef = preload("res://scripts/core/defs/combat_mechanic.gd")

var _families: Dictionary = {}
var _initialization_done := false


func _ready() -> void:
	_register_builtin_families()
	_initialization_done = true


func register_family(family_id: StringName, metadata: Dictionary = {}) -> void:
	if family_id == StringName():
		return
	if _initialization_done and not CombatMechanicRef.ALLOWED_FAMILIES.has(String(family_id)):
		push_error("MechanicFamilyRegistry: rejected non-frozen family '%s'. New families require an ADR." % String(family_id))
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
