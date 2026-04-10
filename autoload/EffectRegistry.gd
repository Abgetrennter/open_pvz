extends Node

const EffectDefRef = preload("res://scripts/core/defs/effect_def.gd")
const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")

var _effect_defs: Dictionary = {}
var _effect_strategies: Dictionary = {}


func _ready() -> void:
	_register_builtin_defs()
	_register_builtin_strategies()


func register_def(effect_def) -> void:
	if effect_def == null or effect_def.effect_id == StringName():
		return
	_effect_defs[effect_def.effect_id] = effect_def


func register_strategy(effect_id: StringName, strategy: Callable) -> void:
	if effect_id == StringName() or not strategy.is_valid():
		return
	_effect_strategies[effect_id] = strategy


func get_def(effect_id: StringName):
	return _effect_defs.get(effect_id)


func get_strategy(effect_id: StringName) -> Callable:
	return _effect_strategies.get(effect_id, Callable())


func _register_builtin_defs() -> void:
	var damage = EffectDefRef.new()
	damage.effect_id = &"damage"
	register_def(damage)

	var spawn_projectile = EffectDefRef.new()
	spawn_projectile.effect_id = &"spawn_projectile"
	register_def(spawn_projectile)

	var explode = EffectDefRef.new()
	explode.effect_id = &"explode"
	register_def(explode)


func _register_builtin_strategies() -> void:
	register_strategy(&"damage", func(context, params: Dictionary, _node) -> Variant:
		var result: Variant = EffectResultRef.new()
		var target := _resolve_target(context, params)
		var amount := int(params.get("amount", 10))
		if target != null and target.has_method("take_damage"):
			target.call("take_damage", amount, context.source_node, PackedStringArray(["effect"]))
		else:
			result.success = false
			result.notes.append("Damage target missing or invalid.")
		return result
	)

	register_strategy(&"spawn_projectile", func(context, params: Dictionary, node) -> Variant:
		var result: Variant = EffectResultRef.new()
		if GameState.current_battle == null or not GameState.current_battle.has_method("spawn_projectile_from_effect"):
			result.success = false
			result.notes.append("No active battle manager available.")
			return result

		var on_hit_effect = node.get_child(&"on_hit")
		GameState.current_battle.call("spawn_projectile_from_effect", context, params, on_hit_effect)
		return result
	)

	register_strategy(&"explode", func(context, params: Dictionary, _node) -> Variant:
		var result: Variant = EffectResultRef.new()
		var target := _resolve_target(context, params)
		var amount := int(params.get("amount", 15))
		if target != null and target.has_method("take_damage"):
			target.call("take_damage", amount, context.source_node, PackedStringArray(["explode"]))
		else:
			result.success = false
			result.notes.append("Explosion target missing or invalid.")
		return result
	)


func _resolve_target(context, params: Dictionary) -> Node:
	var target_mode := StringName(params.get("target_mode", &"context_target"))
	match target_mode:
		&"source":
			return context.source_node
		&"context_target":
			return context.target_node
		_:
			return context.target_node
