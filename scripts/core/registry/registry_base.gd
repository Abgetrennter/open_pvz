extends Node
class_name RegistryBase

const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")
const RegistryConfigRef = preload("res://scripts/core/registry/registry_config.gd")

const TRUST_LEVELS := {
	&"data_only": 0,
	&"rule_extended": 1,
	&"trusted_runtime": 2,
}

var _entries: Dictionary = {}
var _registry_config = null


func _ready() -> void:
	rebuild_registry()


func register_def(def: Resource, source: Dictionary = {}) -> bool:
	_ensure_config()
	if source.is_empty():
		source = {"kind": &"core", "source": &"core"}
	var errors := _validate_common(def, source)
	if errors.is_empty():
		errors.append_array(_validate_def_specific(def, source))
	if not errors.is_empty():
		for error in errors:
			_record_issue(error)
		return false
	var id := StringName(def.get("id"))
	var entry := {
		"id": id,
		"def": def,
		"source": source.duplicate(true),
		"tags": PackedStringArray(def.get("tags")),
		"enabled": true,
	}
	_entries[id] = entry
	_on_def_registered(entry)
	return true


func unregister(id: StringName) -> bool:
	if not _entries.has(id):
		return false
	_entries.erase(id)
	_on_def_unregistered(id)
	return true


func has(id: StringName) -> bool:
	return _entries.has(_canonical_id(id))


func get_def(id: StringName) -> Resource:
	var entry := get_entry(id)
	return entry.get("def", null)


func get_entry(id: StringName) -> Dictionary:
	var canonical := _canonical_id(id)
	return Dictionary(_entries.get(canonical, {})).duplicate(true)


func list_ids() -> PackedStringArray:
	var keys := PackedStringArray()
	for key in _entries.keys():
		keys.append(String(key))
	keys.sort()
	return keys


func list_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in list_ids():
		result.append(get_entry(StringName(id)))
	return result


func rebuild_registry() -> void:
	_ensure_config()
	_before_registry_clear()
	_entries.clear()
	_on_registry_cleared()
	_register_builtin_defs()
	_register_extension_defs()


func _make_registry_config():
	return RegistryConfigRef.new()


func _register_builtin_defs() -> void:
	pass


func _before_registry_clear() -> void:
	pass


func _validate_def_specific(_def: Resource, _source: Dictionary) -> Array[String]:
	return []


func _on_registry_cleared() -> void:
	pass


func _on_def_registered(_entry: Dictionary) -> void:
	pass


func _on_def_unregistered(_id: StringName) -> void:
	pass


func _canonical_id(id: StringName) -> StringName:
	if id == StringName() and _registry_config != null:
		return _registry_config.fallback_id
	return id


func _should_scan_extensions() -> bool:
	return _registry_config != null \
		and _registry_config.register_kind != StringName() \
		and not _registry_config.extension_dir.is_empty()


func _should_register_extension_resource(_def: Resource, _path: String, _pack_manifest: Dictionary) -> bool:
	return true


func _get_extension_source(path: String, pack_manifest: Dictionary) -> Dictionary:
	return {
		"kind": &"extension",
		"extension": true,
		"pack_id": StringName(pack_manifest.get("pack_id", StringName())),
		"path": path,
		"trust_level": StringName(pack_manifest.get("trust_level", &"data_only")),
	}


func _register_extension_defs() -> void:
	if not _should_scan_extensions():
		return
	for pack_manifest in ExtensionPackCatalogRef.list_enabled_packs(_registry_config.register_kind):
		if not _pack_allows_slot(pack_manifest):
			continue
		var root_path := String(pack_manifest.get("root_path", ""))
		if root_path.is_empty():
			continue
		_register_extension_defs_in_dir(root_path.path_join(_registry_config.extension_dir), pack_manifest)


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
		var def := load(full_path)
		if def == null or def.get_script() != _registry_config.def_script:
			continue
		if not _should_register_extension_resource(def, full_path, pack_manifest):
			continue
		register_def(def, _get_extension_source(full_path, pack_manifest))
	directory.list_dir_end()


func _validate_common(def: Resource, source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if def == null:
		errors.append("%s contributor is null." % String(_registry_config.slot_id))
		return errors
	if _registry_config.def_script != null and def.get_script() != _registry_config.def_script:
		errors.append("%s contributor must use %s." % [String(_registry_config.slot_id), _registry_config.def_script.resource_path])
		return errors
	var id := StringName(def.get("id"))
	if id == StringName():
		errors.append("%s contributor id must not be empty." % String(_registry_config.slot_id))
		return errors
	if bool(source.get("extension", false)) and _is_core_id(id) and not _registry_config.allow_core_override:
		errors.append("Extension %s contributor %s must not use core.* namespace." % [String(_registry_config.slot_id), String(id)])
	if _entries.has(id):
		errors.append("Duplicate %s contributor %s registration was ignored." % [String(_registry_config.slot_id), String(id)])
	return errors


func _pack_allows_slot(pack_manifest: Dictionary) -> bool:
	var trust_level := StringName(pack_manifest.get("trust_level", &"data_only"))
	var required: StringName = StringName(_registry_config.required_trust)
	if int(TRUST_LEVELS.get(trust_level, -1)) < int(TRUST_LEVELS.get(required, 0)):
		_record_issue("Extension pack %s requires trust_level %s for %s." % [
			String(pack_manifest.get("pack_id", StringName())),
			String(required),
			String(_registry_config.register_kind),
		])
		return false
	var capabilities := Array(pack_manifest.get("capabilities", []))
	if capabilities.is_empty():
		_record_issue("Extension pack %s manifest capabilities must include %s." % [
			String(pack_manifest.get("pack_id", StringName())),
			String(_registry_config.register_kind),
		])
		return false
	for capability in capabilities:
		var capability_id := StringName(capability)
		if capability_id == _registry_config.register_kind or capability_id == _registry_config.slot_id:
			return true
	_record_issue("Extension pack %s manifest capabilities must include %s." % [
		String(pack_manifest.get("pack_id", StringName())),
		String(_registry_config.register_kind),
	])
	return false


func _ensure_config() -> void:
	if _registry_config == null:
		_registry_config = _make_registry_config()


func _is_core_id(id: StringName) -> bool:
	return String(id).begins_with("core.")


func _record_issue(message: String) -> void:
	push_warning(message)
	var scope := &"registry"
	if _registry_config != null and _registry_config.slot_id != StringName():
		scope = _registry_config.slot_id
	if typeof(DebugService) != TYPE_NIL and DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(scope, message, &"error")
