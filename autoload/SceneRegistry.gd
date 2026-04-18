extends Node

const MAIN_SCENE := "res://scenes/main/main.tscn"
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")
const VALIDATION_SCENARIO_DIR := "res://scenes/validation"
const ENTITY_TEMPLATE_DIRS := [
	"res://data/combat/entity_templates/plants",
	"res://data/combat/entity_templates/zombies",
	"res://data/combat/entity_templates/field_objects",
]
const PROJECTILE_TEMPLATE_DIR := "res://data/combat/projectile_templates"
const TRIGGER_BINDING_DIR := "res://data/combat/trigger_bindings"
const EXTENSION_VALIDATION_DIR := "scenes/validation"
const EXTENSION_ENTITY_TEMPLATE_DIRS := [
	"data/combat/entity_templates/plants",
	"data/combat/entity_templates/zombies",
	"data/combat/entity_templates/field_objects",
]
const EXTENSION_PROJECTILE_TEMPLATE_DIR := "data/combat/projectile_templates"
const EXTENSION_TRIGGER_BINDING_DIR := "data/combat/trigger_bindings"
var _scene_cache: Dictionary = {}
var _resource_cache: Dictionary = {}
var _validation_scenario_paths: Dictionary = {}
var _entity_template_paths: Dictionary = {}
var _projectile_template_paths: Dictionary = {}
var _trigger_binding_paths: Dictionary = {}


func _ready() -> void:
	rebuild_content_registries()


func load_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]

	var scene := load(path) as PackedScene
	if scene != null:
		_scene_cache[path] = scene
	return scene


func load_resource(path: String) -> Resource:
	if _resource_cache.has(path):
		return _resource_cache[path]

	var resource := load(path) as Resource
	if resource != null:
		_resource_cache[path] = resource
	return resource


func rebuild_content_registries() -> void:
	_validation_scenario_paths.clear()
	_entity_template_paths.clear()
	_projectile_template_paths.clear()
	_trigger_binding_paths.clear()

	_register_resources_by_id(VALIDATION_SCENARIO_DIR, &"scenario_id", _validation_scenario_paths)
	for directory_path in ENTITY_TEMPLATE_DIRS:
		_register_resources_by_id(directory_path, &"template_id", _entity_template_paths)
	_register_resources_by_id(PROJECTILE_TEMPLATE_DIR, &"template_id", _projectile_template_paths)
	_register_resources_by_id(TRIGGER_BINDING_DIR, &"binding_id", _trigger_binding_paths)
	_register_extension_content()


func get_validation_scenario(scenario_id: StringName) -> Resource:
	var path := String(_validation_scenario_paths.get(scenario_id, ""))
	if path.is_empty():
		return null
	return load_resource(path)


func get_entity_template(template_id: StringName) -> Resource:
	var path := String(_entity_template_paths.get(template_id, ""))
	if path.is_empty():
		return null
	return load_resource(path)


func get_projectile_template(template_id: StringName) -> Resource:
	var path := String(_projectile_template_paths.get(template_id, ""))
	if path.is_empty():
		return null
	return load_resource(path)


func get_trigger_binding(binding_id: StringName) -> Resource:
	var path := String(_trigger_binding_paths.get(binding_id, ""))
	if path.is_empty():
		return null
	return load_resource(path)


func list_validation_scenario_ids() -> PackedStringArray:
	return _sorted_keys(_validation_scenario_paths)


func list_entity_template_ids() -> PackedStringArray:
	return _sorted_keys(_entity_template_paths)


func list_projectile_template_ids() -> PackedStringArray:
	return _sorted_keys(_projectile_template_paths)


func list_trigger_binding_ids() -> PackedStringArray:
	return _sorted_keys(_trigger_binding_paths)


func has_validation_scenario(scenario_id: StringName) -> bool:
	return _validation_scenario_paths.has(scenario_id)


func has_entity_template(template_id: StringName) -> bool:
	return _entity_template_paths.has(template_id)


func has_projectile_template(template_id: StringName) -> bool:
	return _projectile_template_paths.has(template_id)


func has_trigger_binding(binding_id: StringName) -> bool:
	return _trigger_binding_paths.has(binding_id)


func _register_resources_by_id(directory_path: String, id_property: StringName, registry: Dictionary) -> void:
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
			_register_resources_by_id(full_path, id_property, registry)
			continue
		if not entry_name.ends_with(".tres"):
			continue

		var resource := load_resource(full_path)
		if resource == null:
			continue
		var resource_id := StringName(resource.get(id_property))
		if resource_id == StringName():
			continue
		if registry.has(resource_id):
			_report_duplicate_resource_id(resource_id, String(registry[resource_id]), full_path, id_property)
			continue
		registry[resource_id] = full_path

	directory.list_dir_end()


func _sorted_keys(registry: Dictionary) -> PackedStringArray:
	var keys: Array = registry.keys()
	keys.sort()
	var result := PackedStringArray()
	for key in keys:
		result.append(String(key))
	return result


func _register_extension_content() -> void:
	for pack_manifest in ExtensionPackCatalogRef.list_enabled_packs(&"resources"):
		_register_extension_root(String(pack_manifest.get("root_path", "")))


func _register_extension_root(extension_root: String) -> void:
	_register_resources_by_id(extension_root.path_join(EXTENSION_VALIDATION_DIR), &"scenario_id", _validation_scenario_paths)
	for relative_dir in EXTENSION_ENTITY_TEMPLATE_DIRS:
		_register_resources_by_id(extension_root.path_join(relative_dir), &"template_id", _entity_template_paths)
	_register_resources_by_id(extension_root.path_join(EXTENSION_PROJECTILE_TEMPLATE_DIR), &"template_id", _projectile_template_paths)
	_register_resources_by_id(extension_root.path_join(EXTENSION_TRIGGER_BINDING_DIR), &"binding_id", _trigger_binding_paths)


func _report_duplicate_resource_id(resource_id: StringName, existing_path: String, duplicate_path: String, id_property: StringName) -> void:
	var message := "SceneRegistry duplicate %s %s from %s conflicts with %s." % [
		String(id_property),
		String(resource_id),
		duplicate_path,
		existing_path,
	]
	push_warning(message)
	if DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(&"scene_registry", message, &"error")
