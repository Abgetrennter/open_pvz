extends Node

const ProjectileMovementDefRef = preload("res://scripts/core/defs/projectile_movement_def.gd")
const ProjectileMovementBaseRef = preload("res://scripts/projectile/movement/projectile_movement_base.gd")
const ProjectileMovementLinearRef = preload("res://scripts/projectile/movement/projectile_movement_linear.gd")
const ProjectileMovementParabolaRef = preload("res://scripts/projectile/movement/projectile_movement_parabola.gd")
const ProjectileMovementTrackRef = preload("res://scripts/projectile/movement/projectile_movement_track.gd")
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")

const EXTENSION_PROJECTILE_MOVEMENT_DIR := "data/combat/projectile_movements"
const TRUST_LEVELS := {
	&"data_only": 0,
	&"rule_extended": 1,
	&"trusted_runtime": 2,
}

var _movement_defs: Dictionary = {}
var _aliases: Dictionary = {}


func _ready() -> void:
	rebuild_registry()


func register_def(movement_def, source: Dictionary = {}) -> bool:
	if movement_def == null:
		_record_issue("ProjectileMovementDef is null.")
		return false
	if movement_def.get_script() != ProjectileMovementDefRef:
		_record_issue("ProjectileMovementDef resource must use projectile_movement_def.gd.")
		return false
	var move_mode := StringName(movement_def.move_mode)
	if move_mode == StringName():
		_record_issue("ProjectileMovementDef.move_mode must not be empty.")
		return false
	if _movement_defs.has(move_mode) or _aliases.has(move_mode):
		_record_issue("Duplicate ProjectileMovementDef %s registration was ignored." % String(move_mode))
		return false
	if bool(source.get("extension", false)) and _is_core_id(move_mode):
		_record_issue("Extension projectile movement %s must not use core.* namespace." % String(move_mode))
		return false
	if movement_def.movement_script == null or not (movement_def.movement_script is Script):
		_record_issue("ProjectileMovementDef %s movement_script must be a Script." % String(move_mode))
		return false
	if not _script_extends_base(movement_def.movement_script):
		_record_issue("ProjectileMovementDef %s movement_script must extend ProjectileMovementBase." % String(move_mode))
		return false
	_movement_defs[move_mode] = {
		"def": movement_def,
		"source": source.duplicate(true),
	}
	return true


func register_alias(alias_id: StringName, target_id: StringName) -> bool:
	if alias_id == StringName() or target_id == StringName():
		return false
	if _movement_defs.has(alias_id) or _aliases.has(alias_id):
		return false
	_aliases[alias_id] = target_id
	return true


func has(move_mode: StringName) -> bool:
	return _movement_defs.has(_canonical_move_mode(move_mode))


func get_def(move_mode: StringName):
	var canonical := _canonical_move_mode(move_mode)
	var entry: Dictionary = Dictionary(_movement_defs.get(canonical, {}))
	return entry.get("def", null)


func get_default_hit_strategy(move_mode: StringName) -> StringName:
	var movement_def = get_def(move_mode)
	if movement_def == null:
		return &"swept_segment"
	return StringName(movement_def.default_hit_strategy)


func get_default_terminal_hit_strategy(move_mode: StringName) -> StringName:
	var movement_def = get_def(move_mode)
	if movement_def == null:
		return &"none"
	return StringName(movement_def.default_terminal_hit_strategy)


func create_component(move_mode: StringName):
	var movement_def = get_def(move_mode)
	if movement_def == null:
		_record_issue("Unknown projectile move_mode %s; falling back to core.linear." % String(move_mode))
		movement_def = get_def(&"core.linear")
	if movement_def == null or movement_def.movement_script == null:
		return ProjectileMovementLinearRef.new()
	var component = movement_def.movement_script.new()
	if component == null or not (component is ProjectileMovementBaseRef):
		_record_issue("Projectile movement %s failed to create a ProjectileMovementBase component." % String(move_mode))
		return ProjectileMovementLinearRef.new()
	return component


func list_ids() -> PackedStringArray:
	var keys := PackedStringArray()
	for key in _movement_defs.keys():
		keys.append(String(key))
	keys.sort()
	return keys


func rebuild_registry() -> void:
	_movement_defs.clear()
	_aliases.clear()
	_register_builtin_defs()
	_register_extension_defs()


func _register_builtin_defs() -> void:
	_register_builtin_def(&"core.linear", ProjectileMovementLinearRef, &"swept_segment", &"none")
	_register_builtin_def(&"core.parabola", ProjectileMovementParabolaRef, &"terminal_hitbox", &"impact_hitbox")
	_register_builtin_def(&"core.track", ProjectileMovementTrackRef, &"swept_segment", &"none")
	register_alias(&"linear", &"core.linear")
	register_alias(&"parabola", &"core.parabola")
	register_alias(&"track", &"core.track")


func _register_builtin_def(
	move_mode: StringName,
	movement_script: Script,
	default_hit_strategy: StringName,
	default_terminal_hit_strategy: StringName
) -> void:
	var movement_def = ProjectileMovementDefRef.new()
	movement_def.move_mode = move_mode
	movement_def.movement_script = movement_script
	movement_def.default_hit_strategy = default_hit_strategy
	movement_def.default_terminal_hit_strategy = default_terminal_hit_strategy
	register_def(movement_def, {"source": &"core"})


func _register_extension_defs() -> void:
	for pack_manifest in ExtensionPackCatalogRef.list_enabled_packs(&"projectile_movement"):
		if not _pack_allows_runtime(pack_manifest):
			_record_issue("Extension pack %s requires trust_level trusted_runtime for projectile_movement." % String(pack_manifest.get("pack_id", StringName())))
			continue
		var root_path := String(pack_manifest.get("root_path", ""))
		if root_path.is_empty():
			continue
		_register_extension_defs_in_dir(root_path.path_join(EXTENSION_PROJECTILE_MOVEMENT_DIR), pack_manifest)


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
		var movement_def := load(full_path)
		if movement_def == null or movement_def.get_script() != ProjectileMovementDefRef:
			continue
		register_def(movement_def, {
			"extension": true,
			"pack_id": StringName(pack_manifest.get("pack_id", StringName())),
			"path": full_path,
		})
	directory.list_dir_end()


func _canonical_move_mode(move_mode: StringName) -> StringName:
	var current := move_mode
	if current == StringName():
		current = &"core.linear"
	var guard := 0
	while _aliases.has(current) and guard < 8:
		current = StringName(_aliases[current])
		guard += 1
	return current


func _script_extends_base(script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == ProjectileMovementBaseRef:
			return true
		current = current.get_base_script()
	return false


func _pack_allows_runtime(pack_manifest: Dictionary) -> bool:
	var trust_level := StringName(pack_manifest.get("trust_level", &"data_only"))
	return int(TRUST_LEVELS.get(trust_level, -1)) >= int(TRUST_LEVELS[&"trusted_runtime"])


func _is_core_id(id: StringName) -> bool:
	return String(id).begins_with("core.")


func _record_issue(message: String) -> void:
	push_warning(message)
	if typeof(DebugService) != TYPE_NIL and DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(&"projectile_movement", message, &"error")
