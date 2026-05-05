extends "res://scripts/core/registry/registry_base.gd"

const MechanicCompilerDefRef = preload("res://scripts/core/defs/mechanic_compiler_def.gd")

const EXTENSION_MECHANIC_COMPILER_DIR := "data/combat/mechanic_compilers"

var _compiler_callables: Dictionary = {}
var _compiler_owners: Dictionary = {}
var _builtin_compiler_defs: Dictionary = {}
var _builtin_compiler_callables: Dictionary = {}


func _make_registry_config():
	return RegistryConfigRef.create(
		&"mechanic_compiler",
		MechanicCompilerDefRef,
		&"mechanic_compilers",
		EXTENSION_MECHANIC_COMPILER_DIR,
		&"trusted_runtime",
		StringName(),
		false
	)


func register_compiler(type_id: StringName, metadata: Dictionary = {}) -> void:
	if type_id == StringName():
		return
	_builtin_compiler_defs[type_id] = metadata.duplicate(true)
	if has(type_id):
		return
	_register_compiler_def(type_id, metadata)


func _register_compiler_def(type_id: StringName, metadata: Dictionary = {}) -> void:
	var compiler_def = MechanicCompilerDefRef.new()
	compiler_def.id = type_id
	compiler_def.family = StringName(metadata.get("family", StringName()))
	var source := {
		"kind": &"core",
		"source": &"core",
	}
	for key in metadata.keys():
		source[key] = metadata[key]
	register_def(compiler_def, source)


func register_compiler_callable(type_id: StringName, callable: Callable, metadata: Dictionary = {}) -> void:
	if type_id == StringName() or not callable.is_valid():
		return
	_builtin_compiler_callables[type_id] = {
		"callable": callable,
		"metadata": metadata.duplicate(true),
	}
	if not has(type_id):
		register_compiler(type_id, metadata)
	_compiler_callables[type_id] = callable
	var entry := Dictionary(_entries.get(type_id, {}))
	if not entry.is_empty():
		var source := Dictionary(entry.get("source", {}))
		for key in metadata.keys():
			source[key] = metadata[key]
		entry["source"] = source
		_entries[type_id] = entry


func has_compiler_callable(type_id: StringName) -> bool:
	return _compiler_callables.has(type_id)


func get_metadata(type_id: StringName) -> Dictionary:
	return Dictionary(get_entry(type_id).get("source", {}))


func compile_type(type_id: StringName, mechanic, archetype, merged_params: Dictionary) -> Dictionary:
	var callable: Callable = _compiler_callables.get(type_id, Callable())
	if not callable.is_valid():
		return {}
	var result: Variant = callable.call(mechanic, archetype, merged_params)
	if not (result is Dictionary):
		_record_issue("Mechanic compiler %s must return a Dictionary." % String(type_id))
		return {}
	return result


func _before_registry_clear() -> void:
	for id in _entries.keys():
		var source: Dictionary = Dictionary(Dictionary(_entries[id]).get("source", {}))
		if bool(source.get("extension", false)) and typeof(MechanicTypeRegistry) != TYPE_NIL and MechanicTypeRegistry.has_method("unregister_extension_type"):
			MechanicTypeRegistry.unregister_extension_type(id)


func _on_registry_cleared() -> void:
	_compiler_callables.clear()
	_compiler_owners.clear()


func _register_builtin_defs() -> void:
	for type_id in _sorted_builtin_ids(_builtin_compiler_defs):
		var id := StringName(type_id)
		_register_compiler_def(id, Dictionary(_builtin_compiler_defs[id]))
	for type_id in _sorted_builtin_ids(_builtin_compiler_callables):
		var id := StringName(type_id)
		var record := Dictionary(_builtin_compiler_callables[id])
		var callable: Callable = record.get("callable", Callable())
		if not callable.is_valid():
			continue
		var metadata := Dictionary(record.get("metadata", {}))
		if not has(id):
			_register_compiler_def(id, metadata)
		_compiler_callables[id] = callable
		var entry := Dictionary(_entries.get(id, {}))
		if not entry.is_empty():
			var source := Dictionary(entry.get("source", {}))
			for key in metadata.keys():
				source[key] = metadata[key]
			entry["source"] = source
			_entries[id] = entry


func _validate_def_specific(compiler_def: Resource, source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var type_id := StringName(compiler_def.id)
	var family_id := StringName(compiler_def.family)
	if family_id == StringName():
		errors.append("MechanicCompilerDef %s family must not be empty." % String(type_id))
	elif typeof(MechanicFamilyRegistry) != TYPE_NIL and not MechanicFamilyRegistry.has_family(family_id):
		errors.append("MechanicCompilerDef %s references unknown family %s." % [String(type_id), String(family_id)])
	if bool(source.get("extension", false)):
		if compiler_def.compiler_script == null or not (compiler_def.compiler_script is Script):
			errors.append("MechanicCompilerDef %s compiler_script must be a Script." % String(type_id))
		else:
			var owner = compiler_def.compiler_script.new()
			if owner == null or not owner.has_method("compile"):
				errors.append("MechanicCompilerDef %s compiler_script must expose compile(mechanic, archetype, merged_params)." % String(type_id))
	return errors


func _on_def_registered(entry: Dictionary) -> void:
	var compiler_def = entry.get("def", null)
	if compiler_def == null:
		return
	var type_id := StringName(compiler_def.id)
	var family_id := StringName(compiler_def.family)
	var source: Dictionary = Dictionary(entry.get("source", {}))
	if compiler_def.compiler_script != null:
		var owner = compiler_def.compiler_script.new()
		_compiler_owners[type_id] = owner
		_compiler_callables[type_id] = Callable(owner, "compile")
	if typeof(MechanicTypeRegistry) != TYPE_NIL and family_id != StringName():
		MechanicTypeRegistry.register_type(type_id, family_id, {
			"source": source.duplicate(true),
			"extension": bool(source.get("extension", false)),
		})


func _sorted_builtin_ids(source: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	for id in source.keys():
		ids.append(String(id))
	ids.sort()
	return ids
