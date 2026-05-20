extends "res://scripts/core/registry/registry_base.gd"

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const MovementDefRef = preload("res://scripts/core/defs/movement_def.gd")

const EXTENSION_MOVEMENT_DIR := "data/combat/movements"

var _movement_strategies: Dictionary = {}
var _movement_strategy_owners: Dictionary = {}


func _make_registry_config():
	return RegistryConfigRef.create(
		&"movement",
		MovementDefRef,
		&"movement",
		EXTENSION_MOVEMENT_DIR,
		&"trusted_runtime",
		&"core.walk",
		false
	)


func _on_registry_cleared() -> void:
	_movement_strategies.clear()
	_movement_strategy_owners.clear()


func _register_builtin_defs() -> void:
	var walk_def = MovementDefRef.new()
	walk_def.id = &"core.walk"
	register_def(walk_def, {"kind": &"core", "source": &"core"})

	var leap_def = MovementDefRef.new()
	leap_def.id = &"core.leap_once"
	register_def(leap_def, {"kind": &"core", "source": &"core"})
	_register_builtin_strategies()


func build_command(movement_id: StringName, owner: Node, spec: Dictionary, delta: float, blackboard: Dictionary = {}) -> Dictionary:
	var strategy: Callable = _movement_strategies.get(movement_id, Callable())
	if not strategy.is_valid():
		return {}
	return Dictionary(strategy.call(owner, spec, delta, blackboard))


func _validate_def_specific(movement_def: Resource, source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if bool(source.get("extension", false)):
		if movement_def.strategy_script == null or not (movement_def.strategy_script is Script):
			errors.append("MovementDef %s strategy_script must be a Script." % String(movement_def.id))
		else:
			var strategy_owner = movement_def.strategy_script.new()
			if strategy_owner == null or not strategy_owner.has_method("build_command"):
				errors.append("MovementDef %s strategy_script must expose build_command(owner, spec, delta, blackboard)." % String(movement_def.id))
	return errors


func _on_def_registered(entry: Dictionary) -> void:
	var source: Dictionary = Dictionary(entry.get("source", {}))
	if not bool(source.get("extension", false)):
		return
	var movement_def = entry.get("def", null)
	if movement_def == null or movement_def.strategy_script == null:
		return
	var strategy_owner = movement_def.strategy_script.new()
	if strategy_owner == null or not strategy_owner.has_method("build_command"):
		return
	_movement_strategy_owners[movement_def.id] = strategy_owner
	_movement_strategies[movement_def.id] = Callable(strategy_owner, "build_command")


func _register_builtin_strategies() -> void:
	_movement_strategies[&"core.walk"] = func(owner: Node, spec: Dictionary, _delta: float, _blackboard: Dictionary) -> Dictionary:
		var params: Dictionary = Dictionary(spec.get("params", {}))
		var fallback_speed := float(params.get("move_speed", 55.0))
		var move_speed := _resolve_slots_speed(params, "move_speed_slots_per_sec", fallback_speed)
		var direction := Vector2(params.get("direction", Vector2.LEFT))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.LEFT
		return {
			"source_id": &"movement:core.walk",
			"command_kind": &"base",
			"ground_velocity": direction.normalized() * move_speed,
			"ground_contact": true,
			"exposure_state": &"ground",
			"interruptible": true,
			"pause_reason": StringName(),
		}

	_movement_strategies[&"core.leap_once"] = func(owner: Node, spec: Dictionary, _delta: float, blackboard: Dictionary) -> Dictionary:
		var params: Dictionary = Dictionary(spec.get("params", {}))
		var fallback_speed := float(params.get("move_speed", 80.0))
		var move_speed := _resolve_slots_speed(params, "move_speed_slots_per_sec", fallback_speed)
		var direction := Vector2(params.get("direction", Vector2.LEFT))
		if direction.length_squared() <= 0.0001:
			direction = Vector2.LEFT
		var height := 0.0
		var ground_contact := true
		if owner != null and owner.has_method("get_height"):
			height = float(owner.call("get_height"))
		if owner != null and owner.has_method("is_ground_contact"):
			ground_contact = bool(owner.call("is_ground_contact"))
		if bool(blackboard.get("landed", false)):
			return {
				"source_id": &"movement:core.leap_once",
				"command_kind": &"base",
				"ground_velocity": direction.normalized() * move_speed,
				"ground_contact": true,
				"exposure_state": &"ground",
				"interruptible": true,
				"pause_reason": StringName(),
			}
		if bool(blackboard.get("started", false)) and ground_contact and height <= 0.001:
			blackboard["landed"] = true
			return {
				"source_id": &"movement:core.leap_once",
				"command_kind": &"base",
				"ground_velocity": direction.normalized() * move_speed,
				"ground_contact": true,
				"exposure_state": &"ground",
				"interruptible": true,
				"pause_reason": StringName(),
			}
		var command := {
			"source_id": &"movement:core.leap_once",
			"command_kind": &"base",
			"ground_velocity": direction.normalized() * move_speed,
			"ground_contact": false,
			"exposure_state": &"airborne",
			"gravity": float(params.get("gravity", -520.0)),
			"interruptible": false,
			"pause_reason": StringName(),
		}
		if not bool(blackboard.get("started", false)):
			blackboard["started"] = true
			command["height_velocity"] = float(params.get("jump_velocity", 220.0))
		return command


func _resolve_slots_speed(params: Dictionary, slots_key: String, default_world_per_sec: float) -> float:
	var metrics := _get_battlefield_metrics()
	if metrics != null and metrics.has_method("resolve_slots_speed"):
		return float(metrics.call("resolve_slots_speed", params, slots_key, default_world_per_sec))
	if params.has(slots_key):
		return float(params.get(slots_key)) * 96.0
	return default_world_per_sec


func _get_battlefield_metrics() -> RefCounted:
	if GameState.current_battle == null:
		return null
	if not GameState.current_battle.has_method("get_battlefield_metrics"):
		return null
	var metrics: Variant = GameState.current_battle.call("get_battlefield_metrics")
	return metrics if metrics is RefCounted else null
