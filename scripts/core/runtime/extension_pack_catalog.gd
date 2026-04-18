extends RefCounted
class_name ExtensionPackCatalog

const EXTENSION_ROOT_DIR := "res://extensions"
const EXTENSION_MANIFEST_FIXTURE_ROOT_DIR := "res://extensions_manifest_fixtures"
const MANIFEST_FILE_NAME := "extension.json"
const ALLOWED_REGISTER_KINDS := {
	&"resources": true,
	&"effects": true,
}
const MANIFEST_GUARDRAIL_SCENARIO_IDS := {
	&"extension_manifest_guardrail_validation": true,
}


static func list_enabled_packs(register_kind: StringName = StringName()) -> Array[Dictionary]:
	var packs: Array[Dictionary] = []
	for root_dir in _list_scan_roots():
		_scan_root(root_dir, register_kind, packs)
	return packs


static func _list_scan_roots() -> Array[String]:
	var roots: Array[String] = [EXTENSION_ROOT_DIR]
	if _should_include_manifest_fixture_root():
		roots.append(EXTENSION_MANIFEST_FIXTURE_ROOT_DIR)
	return roots


static func _scan_root(root_dir: String, register_kind: StringName, packs: Array[Dictionary]) -> void:
	var absolute_root := ProjectSettings.globalize_path(root_dir)
	var directory := DirAccess.open(absolute_root)
	if directory == null:
		return

	directory.list_dir_begin()
	while true:
		var entry_name := directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with(".") or not directory.current_is_dir():
			continue
		var root_path := root_dir.path_join(entry_name)
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
	var json := JSON.new()
	var parse_status := json.parse(raw_text)
	if parse_status != OK or not (json.data is Dictionary):
		var parse_message := "Extension pack %s has invalid JSON manifest %s." % [fallback_pack_id, MANIFEST_FILE_NAME]
		_record_manifest_issue(parse_message)
		return {}
	var manifest := Dictionary(json.data)
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
	for register_entry in Array(manifest.get("register", [])):
		if not (register_entry is String or register_entry is StringName):
			var entry_message := "Extension pack %s manifest register entries must be strings." % String(pack_id)
			_record_manifest_issue(entry_message)
			return {}
		var register_kind := StringName(register_entry)
		if register_kind == StringName() or not ALLOWED_REGISTER_KINDS.has(register_kind):
			var allowed_values := PackedStringArray()
			for key in ALLOWED_REGISTER_KINDS.keys():
				allowed_values.append(String(key))
			allowed_values.sort()
			var invalid_register_message := "Extension pack %s manifest register entries must be one of %s." % [
				String(pack_id),
				", ".join(Array(allowed_values)),
			]
			_record_manifest_issue(invalid_register_message)
			return {}
	if manifest.has("enabled_by_default") and not (manifest.get("enabled_by_default") is bool):
		var enabled_message := "Extension pack %s manifest enabled_by_default must be a bool." % String(pack_id)
		_record_manifest_issue(enabled_message)
		return {}
	var activation_cli_error := _validate_string_array_field(manifest, "activation_cli_flags", pack_id)
	if not activation_cli_error.is_empty():
		_record_manifest_issue(activation_cli_error)
		return {}
	var activation_scenario_error := _validate_string_array_field(manifest, "activation_scenario_ids", pack_id)
	if not activation_scenario_error.is_empty():
		_record_manifest_issue(activation_scenario_error)
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


static func _should_include_manifest_fixture_root() -> bool:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg == "--include-manifest-guardrail-extension-fixtures":
			return true
		if arg.begins_with("--validation-scenario-id="):
			var scenario_id := StringName(arg.trim_prefix("--validation-scenario-id="))
			if MANIFEST_GUARDRAIL_SCENARIO_IDS.has(scenario_id):
				return true
		if arg.begins_with("--validation-scenario="):
			var scenario_name := StringName(arg.trim_prefix("--validation-scenario=").get_file().get_basename())
			if MANIFEST_GUARDRAIL_SCENARIO_IDS.has(scenario_name):
				return true
	return false


static func _validate_string_array_field(manifest: Dictionary, field_name: String, pack_id: StringName) -> String:
	if not manifest.has(field_name):
		return ""
	var raw_value: Variant = manifest.get(field_name, [])
	if not (raw_value is Array):
		return "Extension pack %s manifest %s must be an Array." % [String(pack_id), field_name]
	for entry in Array(raw_value):
		if not (entry is String or entry is StringName):
			return "Extension pack %s manifest %s entries must be non-empty strings." % [String(pack_id), field_name]
		if String(entry).strip_edges().is_empty():
			return "Extension pack %s manifest %s entries must be non-empty strings." % [String(pack_id), field_name]
	return ""


static func _record_manifest_issue(message: String) -> void:
	printerr(message)
	if typeof(DebugService) != TYPE_NIL and DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(&"extension_manifest", message, &"error")
