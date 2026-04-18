extends RefCounted
class_name ExtensionPackCatalog

const EXTENSION_ROOT_DIR := "res://extensions"
const MANIFEST_FILE_NAME := "extension.json"


static func list_enabled_packs(register_kind: StringName = StringName()) -> Array[Dictionary]:
	var packs: Array[Dictionary] = []
	var absolute_root := ProjectSettings.globalize_path(EXTENSION_ROOT_DIR)
	var directory := DirAccess.open(absolute_root)
	if directory == null:
		return packs

	directory.list_dir_begin()
	while true:
		var entry_name := directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with(".") or not directory.current_is_dir():
			continue
		var root_path := EXTENSION_ROOT_DIR.path_join(entry_name)
		var manifest := _load_manifest(root_path, entry_name)
		if manifest.is_empty():
			continue
		if not _pack_supports_register_kind(manifest, register_kind):
			continue
		if not _pack_enabled(manifest, root_path):
			continue
		packs.append(manifest.merged({
			"root_path": root_path,
		}))
	directory.list_dir_end()
	return packs


static func _load_manifest(root_path: String, fallback_pack_id: String) -> Dictionary:
	var manifest_path := root_path.path_join(MANIFEST_FILE_NAME)
	if not FileAccess.file_exists(manifest_path):
		var message := "Extension pack %s is missing %s." % [fallback_pack_id, MANIFEST_FILE_NAME]
		_record_manifest_issue(message)
		return {}
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		var open_message := "Extension pack %s failed to open %s." % [fallback_pack_id, MANIFEST_FILE_NAME]
		_record_manifest_issue(open_message)
		return {}
	var raw_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if not (parsed is Dictionary):
		var parse_message := "Extension pack %s has invalid JSON manifest %s." % [fallback_pack_id, MANIFEST_FILE_NAME]
		_record_manifest_issue(parse_message)
		return {}
	var manifest := Dictionary(parsed)
	var pack_id := StringName(manifest.get("pack_id", fallback_pack_id))
	if pack_id == StringName():
		var id_message := "Extension pack %s manifest must define pack_id." % fallback_pack_id
		_record_manifest_issue(id_message)
		return {}
	manifest["pack_id"] = pack_id
	if not (manifest.get("register", []) is Array):
		var register_message := "Extension pack %s manifest register must be an Array." % String(pack_id)
		_record_manifest_issue(register_message)
		return {}
	return manifest


static func _pack_supports_register_kind(manifest: Dictionary, register_kind: StringName) -> bool:
	if register_kind == StringName():
		return true
	var register_list: Array = Array(manifest.get("register", []))
	for entry in register_list:
		if StringName(entry) == register_kind:
			return true
	return false


static func _pack_enabled(manifest: Dictionary, root_path: String) -> bool:
	if bool(manifest.get("enabled_by_default", false)):
		return true
	var pack_id := StringName(manifest.get("pack_id", StringName()))
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg.begins_with("--include-extension-pack="):
			if StringName(arg.trim_prefix("--include-extension-pack=")) == pack_id:
				return true
		for activation_flag in Array(manifest.get("activation_cli_flags", [])):
			if arg == String(activation_flag):
				return true
		if arg.begins_with("--validation-scenario-id="):
			var scenario_id := StringName(arg.trim_prefix("--validation-scenario-id="))
			for activation_scenario_id in Array(manifest.get("activation_scenario_ids", [])):
				if scenario_id == StringName(activation_scenario_id):
					return true
		if arg.begins_with("--validation-scenario="):
			var scenario_path := arg.trim_prefix("--validation-scenario=")
			if scenario_path.begins_with(root_path):
				return true
			var scenario_name := StringName(scenario_path.get_file().get_basename())
			for activation_scenario_id in Array(manifest.get("activation_scenario_ids", [])):
				if scenario_name == StringName(activation_scenario_id):
					return true
	return false


static func _record_manifest_issue(message: String) -> void:
	printerr(message)
	if typeof(DebugService) != TYPE_NIL and DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(&"extension_manifest", message, &"error")
