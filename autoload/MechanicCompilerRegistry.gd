extends "res://scripts/core/registry/registry_base.gd"

const MechanicCompilerDefRef = preload("res://scripts/core/defs/mechanic_compiler_def.gd")

const EXTENSION_MECHANIC_COMPILER_DIR := "data/combat/mechanic_compilers"

var _compiler_callables: Dictionary = {}
var _compiler_owners: Dictionary = {}


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
	if has(type_id):
		return
	var compiler_def = MechanicCompilerDefRef.new()
	compiler_def.id = type_id
	compiler_def.family = StringName(metadata.get("family", StringName()))
	register_def(compiler_def, {
		"kind": &"core",
		"source": &"core",
		"compiler_version": metadata.get("compiler_version", StringName()),
	})


func register_compiler_callable(type_id: StringName, callable: Callable, metadata: Dictionary = {}) -> void:
	if type_id == StringName() or not callable.is_valid():
		return
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


func rebuild_registry() -> void:
	_ensure_config()
	var extension_ids: Array = []
	for id in _entries.keys():
		var source: Dictionary = Dictionary(Dictionary(_entries[id]).get("source", {}))
		if bool(source.get("extension", false)):
			extension_ids.append(id)
	for id in extension_ids:
		_entries.erase(id)
		_compiler_callables.erase(id)
		_compiler_owners.erase(id)
		if typeof(MechanicTypeRegistry) != TYPE_NIL and MechanicTypeRegistry.has_method("unregister_extension_type"):
			MechanicTypeRegistry.unregister_extension_type(id)
	_register_extension_defs()


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
