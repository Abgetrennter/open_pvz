extends Node

const MechanicCompilerDefRef = preload("res://scripts/core/defs/mechanic_compiler_def.gd")
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")

const EXTENSION_MECHANIC_COMPILER_DIR := "data/combat/mechanic_compilers"
const TRUST_LEVELS := {
	&"data_only": 0,
	&"rule_extended": 1,
	&"trusted_runtime": 2,
}

var _compiler_specs: Dictionary = {}
var _compiler_callables: Dictionary = {}
var _compiler_owners: Dictionary = {}


func _ready() -> void:
	_register_extension_defs()


func register_compiler(type_id: StringName, metadata: Dictionary = {}) -> void:
	if type_id == StringName():
		return
	_compiler_specs[type_id] = metadata.duplicate(true)


func register_compiler_callable(type_id: StringName, callable: Callable, metadata: Dictionary = {}) -> void:
	if type_id == StringName() or not callable.is_valid():
		return
	_compiler_specs[type_id] = metadata.duplicate(true)
	_compiler_callables[type_id] = callable


func register_def(compiler_def, source: Dictionary = {}) -> bool:
	if compiler_def == null:
		_record_issue("MechanicCompilerDef is null.")
		return false
	if compiler_def.get_script() != MechanicCompilerDefRef:
		_record_issue("MechanicCompilerDef resource must use mechanic_compiler_def.gd.")
		return false
	var type_id := StringName(compiler_def.type_id)
	var family_id := StringName(compiler_def.family)
	if type_id == StringName():
		_record_issue("MechanicCompilerDef.type_id must not be empty.")
		return false
	if family_id == StringName():
		_record_issue("MechanicCompilerDef.family must not be empty.")
		return false
	if bool(source.get("extension", false)) and String(type_id).begins_with("core."):
		_record_issue("Extension mechanic compiler %s must not use core.* namespace." % String(type_id))
		return false
	if _compiler_specs.has(type_id):
		_record_issue("Duplicate MechanicCompilerDef %s registration was ignored." % String(type_id))
		return false
	if typeof(MechanicFamilyRegistry) != TYPE_NIL and not MechanicFamilyRegistry.has_family(family_id):
		_record_issue("MechanicCompilerDef %s references unknown family %s." % [String(type_id), String(family_id)])
		return false
	if compiler_def.compiler_script == null or not (compiler_def.compiler_script is Script):
		_record_issue("MechanicCompilerDef %s compiler_script must be a Script." % String(type_id))
		return false
	var owner = compiler_def.compiler_script.new()
	if owner == null or not owner.has_method("compile"):
		_record_issue("MechanicCompilerDef %s compiler_script must expose compile(mechanic, archetype, merged_params)." % String(type_id))
		return false
	_compiler_owners[type_id] = owner
	register_compiler_callable(type_id, Callable(owner, "compile"), {
		"family": family_id,
		"source": source.duplicate(true),
		"extension": bool(source.get("extension", false)),
	})
	if typeof(MechanicTypeRegistry) != TYPE_NIL:
		MechanicTypeRegistry.register_type(type_id, family_id, {
			"source": source.duplicate(true),
			"extension": bool(source.get("extension", false)),
		})
	return true


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
		_record_issue("Mechanic compiler %s must return a Dictionary." % String(type_id))
		return {}
	return result


func list_type_ids() -> PackedStringArray:
	var keys := PackedStringArray()
	for key in _compiler_specs.keys():
		keys.append(String(key))
	keys.sort()
	return keys


func has(type_id: StringName) -> bool:
	return has_compiler(type_id)


func rebuild_registry() -> void:
	var extension_type_ids: Array = []
	for type_id in _compiler_specs.keys():
		var metadata: Dictionary = Dictionary(_compiler_specs[type_id])
		if bool(metadata.get("extension", false)):
			extension_type_ids.append(type_id)
	for type_id in extension_type_ids:
		_compiler_specs.erase(type_id)
		_compiler_callables.erase(type_id)
		_compiler_owners.erase(type_id)
	_register_extension_defs()


func _register_extension_defs() -> void:
	for pack_manifest in ExtensionPackCatalogRef.list_enabled_packs(&"mechanic_compilers"):
		if not _pack_allows_runtime(pack_manifest):
			_record_issue("Extension pack %s requires trust_level trusted_runtime for mechanic_compilers." % String(pack_manifest.get("pack_id", StringName())))
			continue
		var root_path := String(pack_manifest.get("root_path", ""))
		if root_path.is_empty():
			continue
		_register_extension_defs_in_dir(root_path.path_join(EXTENSION_MECHANIC_COMPILER_DIR), pack_manifest)


func _register_extension_defs_in_dir(directory_path: String, pack_manifest: Dictionary) -> void:
	var absolute_path := ProjectSettings.globalize_path(directory_path)
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry_name := directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue
		var full_path := directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_register_extension_defs_in_dir(full_path, pack_manifest)
			continue
		if not entry_name.ends_with(".tres"):
			continue
		var compiler_def := load(full_path)
		if compiler_def == null or compiler_def.get_script() != MechanicCompilerDefRef:
			continue
		register_def(compiler_def, {
			"extension": true,
			"pack_id": StringName(pack_manifest.get("pack_id", StringName())),
			"path": full_path,
		})
	directory.list_dir_end()


func _pack_allows_runtime(pack_manifest: Dictionary) -> bool:
	var trust_level := StringName(pack_manifest.get("trust_level", &"data_only"))
	return int(TRUST_LEVELS.get(trust_level, -1)) >= int(TRUST_LEVELS[&"trusted_runtime"])


func _record_issue(message: String) -> void:
	push_warning(message)
	if typeof(DebugService) != TYPE_NIL and DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(&"mechanic_compiler", message, &"error")
