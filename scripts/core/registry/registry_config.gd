extends RefCounted
class_name RegistryConfig

var slot_id: StringName = StringName()
var def_script: Script = null
var register_kind: StringName = StringName()
var extension_dir := ""
var required_trust: StringName = &"data_only"
var fallback_id: StringName = StringName()
var allow_core_override := false


static func create(
	new_slot_id: StringName,
	new_def_script: Script,
	new_register_kind: StringName,
	new_extension_dir: String,
	new_required_trust: StringName = &"data_only",
	new_fallback_id: StringName = StringName(),
	new_allow_core_override := false
) -> RefCounted:
	var config = load("res://scripts/core/registry/registry_config.gd").new()
	config.slot_id = new_slot_id
	config.def_script = new_def_script
	config.register_kind = new_register_kind
	config.extension_dir = new_extension_dir
	config.required_trust = new_required_trust
	config.fallback_id = new_fallback_id
	config.allow_core_override = new_allow_core_override
	return config
