extends "res://scripts/core/registry/registry_base.gd"

const ProjectileMovementDefRef = preload("res://scripts/core/defs/projectile_movement_def.gd")
const ProjectileMovementBaseRef = preload("res://scripts/projectile/movement/projectile_movement_base.gd")
const ProjectileMovementLinearRef = preload("res://scripts/projectile/movement/projectile_movement_linear.gd")
const ProjectileMovementParabolaRef = preload("res://scripts/projectile/movement/projectile_movement_parabola.gd")
const ProjectileMovementTrackRef = preload("res://scripts/projectile/movement/projectile_movement_track.gd")

const EXTENSION_PROJECTILE_MOVEMENT_DIR := "data/combat/projectile_movements"

var _aliases: Dictionary = {}


func _make_registry_config():
	return RegistryConfigRef.create(
		&"projectile_movement",
		ProjectileMovementDefRef,
		&"projectile_movement",
		EXTENSION_PROJECTILE_MOVEMENT_DIR,
		&"trusted_runtime",
		&"core.linear",
		false
	)


func register_alias(alias_id: StringName, target_id: StringName) -> bool:
	if alias_id == StringName() or target_id == StringName():
		return false
	if has(alias_id) or _aliases.has(alias_id):
		return false
	_aliases[alias_id] = target_id
	return true


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


func _on_registry_cleared() -> void:
	_aliases.clear()


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
	movement_def.id = move_mode
	movement_def.movement_script = movement_script
	movement_def.default_hit_strategy = default_hit_strategy
	movement_def.default_terminal_hit_strategy = default_terminal_hit_strategy
	register_def(movement_def, {"kind": &"core", "source": &"core"})


func _validate_def_specific(def: Resource, _source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var move_mode := StringName(def.id)
	if def.movement_script == null or not (def.movement_script is Script):
		errors.append("ProjectileMovementDef %s movement_script must be a Script." % String(move_mode))
	elif not _script_extends_base(def.movement_script):
		errors.append("ProjectileMovementDef %s movement_script must extend ProjectileMovementBase." % String(move_mode))
	return errors


func _canonical_id(id: StringName) -> StringName:
	var current := id
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
