extends RefCounted
class_name ExtensionPackCatalog

const EXTENSION_ROOT_DIR := "res://extensions"
const LOCAL_EXTENSION_ROOT_DIR := "res://local_extensions"
const EXTENSION_MANIFEST_FIXTURE_ROOT_DIR := "res://extensions_manifest_fixtures"
const MANIFEST_FILE_NAME := "extension.json"
const ALLOWED_REGISTER_KINDS := {
	&"resources": true,
	&"effects": true,
	&"projectile_movement": true,
	&"mechanic_compilers": true,
	&"triggers": true,
	&"detections": true,
	&"controllers": true,
	&"visual_cues": true,
	&"visual_fx": true,
	&"audio_cues": true,
	&"visual_profiles": true,
}
const ALLOWED_TRUST_LEVELS := {
	&"data_only": true,
	&"rule_extended": true,
	&"trusted_runtime": true,
}
const ALLOWED_PACK_TYPES := {
	&"rule_pack": true,
	&"content_pack": true,
	&"asset_pack": true,
	&"collection_pack": true,
}
const ALLOWED_PUBLISH_POLICIES := {
	&"public": true,
	&"local_private": true,
}
const MANIFEST_GUARDRAIL_SCENARIO_IDS := {
	&"extension_manifest_guardrail_validation": true,
}
const PRIVATE_REFERENCE_MARKERS := [
	"res://vendor/out_files",
	"vendor/out_files",
	"res://local_extensions",
	"local_extensions",
]
const PUBLIC_PACKAGE_FORBIDDEN_EXTENSIONS := [
	".reanim",
]

static var _session_enabled_pack_ids: Dictionary = {}


static func list_enabled_packs(register_kind: StringName = StringName()) -> Array[Dictionary]:
	var packs: Array[Dictionary] = []
	for root_dir in _list_scan_roots():
		_scan_root(root_dir, register_kind, packs)
	return packs


static func enable_pack_for_current_session(pack_id: StringName) -> void:
	if pack_id == StringName():
		return
	_session_enabled_pack_ids[pack_id] = true


static func _list_scan_roots() -> Array[String]:
	var roots: Array[String] = [EXTENSION_ROOT_DIR, LOCAL_EXTENSION_ROOT_DIR]
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
	if manifest.has("trust_level"):
		var trust_level := StringName(manifest.get("trust_level", StringName()))
		if trust_level == StringName() or not ALLOWED_TRUST_LEVELS.has(trust_level):
			var trust_message := "Extension pack %s manifest trust_level must be one of data_only, rule_extended, trusted_runtime." % String(pack_id)
			_record_manifest_issue(trust_message)
			return {}
		manifest["trust_level"] = trust_level
	else:
		manifest["trust_level"] = &"data_only"
	var activation_cli_error := _validate_string_array_field(manifest, "activation_cli_flags", pack_id)
	if not activation_cli_error.is_empty():
		_record_manifest_issue(activation_cli_error)
		return {}
	var activation_scenario_error := _validate_string_array_field(manifest, "activation_scenario_ids", pack_id)
	if not activation_scenario_error.is_empty():
		_record_manifest_issue(activation_scenario_error)
		return {}
	var capabilities_error := _validate_string_array_field(manifest, "capabilities", pack_id)
	if not capabilities_error.is_empty():
		_record_manifest_issue(capabilities_error)
		return {}
	var package_boundary_error := _validate_package_boundary_fields(manifest, pack_id)
	if not package_boundary_error.is_empty():
		_record_manifest_issue(package_boundary_error)
		return {}
	var private_reference_error := _validate_public_manifest_references(manifest, pack_id)
	if not private_reference_error.is_empty():
		_record_manifest_issue(private_reference_error)
		return {}
	var public_file_error := _validate_public_package_files(root_path, manifest)
	if not public_file_error.is_empty():
		_record_manifest_issue(public_file_error)
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
	if _session_enabled_pack_ids.has(pack_id):
		return true
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


static func _validate_package_boundary_fields(manifest: Dictionary, pack_id: StringName) -> String:
	if manifest.has("pack_type"):
		var pack_type := StringName(manifest.get("pack_type", StringName()))
		if pack_type == StringName() or not ALLOWED_PACK_TYPES.has(pack_type):
			return "Extension pack %s manifest pack_type must be one of asset_pack, collection_pack, content_pack, rule_pack." % String(pack_id)
		manifest["pack_type"] = pack_type

	var publish_policy := StringName(manifest.get("publish_policy", &"public"))
	if publish_policy == StringName() or not ALLOWED_PUBLISH_POLICIES.has(publish_policy):
		return "Extension pack %s manifest publish_policy must be one of public, local_private." % String(pack_id)
	manifest["publish_policy"] = publish_policy

	if publish_policy != &"local_private":
		if bool(manifest.get("contains_original_assets", false)):
			return "Extension pack %s manifest contains_original_assets requires publish_policy local_private." % String(pack_id)
		if bool(manifest.get("generated_from_private_source", false)):
			return "Extension pack %s manifest generated_from_private_source requires publish_policy local_private." % String(pack_id)
	return ""


static func _validate_public_manifest_references(manifest: Dictionary, pack_id: StringName) -> String:
	if StringName(manifest.get("publish_policy", &"public")) != &"public":
		return ""
	var bad_reference := _find_private_reference_in_value(manifest)
	if bad_reference.is_empty():
		return ""
	return "Extension pack %s public manifest must not reference private path %s." % [String(pack_id), bad_reference]


static func _find_private_reference_in_value(value: Variant) -> String:
	if value is String or value is StringName:
		var text := String(value).replace("\\", "/")
		for marker in PRIVATE_REFERENCE_MARKERS:
			if text.contains(String(marker)):
				return String(marker)
		return ""
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			var key_result := _find_private_reference_in_value(key)
			if not key_result.is_empty():
				return key_result
			var value_result := _find_private_reference_in_value((value as Dictionary)[key])
			if not value_result.is_empty():
				return value_result
	if value is Array:
		for item in value:
			var item_result := _find_private_reference_in_value(item)
			if not item_result.is_empty():
				return item_result
	return ""


static func _validate_public_package_files(root_path: String, manifest: Dictionary) -> String:
	if StringName(manifest.get("publish_policy", &"public")) != &"public":
		return ""
	var pack_id := StringName(manifest.get("pack_id", StringName()))
	var forbidden_file := _find_forbidden_public_package_file(root_path)
	if forbidden_file.is_empty():
		return ""
	return "Extension pack %s public package must not contain private source file %s." % [String(pack_id), forbidden_file]


static func _find_forbidden_public_package_file(root_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(root_path)
	var directory := DirAccess.open(absolute_path)
	if directory == null:
		return ""
	directory.list_dir_begin()
	while true:
		var entry_name := directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue
		var full_path := root_path.path_join(entry_name)
		if directory.current_is_dir():
			var nested := _find_forbidden_public_package_file(full_path)
			if not nested.is_empty():
				directory.list_dir_end()
				return nested
			continue
		var lower_name := entry_name.to_lower()
		for extension in PUBLIC_PACKAGE_FORBIDDEN_EXTENSIONS:
			if lower_name.ends_with(String(extension)):
				directory.list_dir_end()
				return full_path
	directory.list_dir_end()
	return ""


static func _record_manifest_issue(message: String) -> void:
	printerr(message)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var debug_service := tree.root.get_node_or_null("DebugService")
	if debug_service != null and debug_service.has_method("record_protocol_issue"):
		debug_service.record_protocol_issue(&"extension_manifest", message, &"error")
