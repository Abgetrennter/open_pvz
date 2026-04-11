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
		var damage_tags := PackedStringArray(context.core.get("tags", PackedStringArray()))
		if not damage_tags.has("effect"):
			damage_tags.append("effect")
		var event_tag := String(context.event_name)
		if not event_tag.is_empty() and not damage_tags.has(event_tag):
			damage_tags.append(event_tag)
		if target != null and target.has_method("take_damage"):
			target.call("take_damage", amount, context.source_node, damage_tags, {
				"depth": int(context.runtime.get("depth", context.depth)) + 1,
				"chain_id": context.chain_id,
				"origin_event_name": context.event_name,
			})
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
		var targets: Array = _resolve_targets(context, params)
		var amount := int(params.get("amount", 15))
		if targets.is_empty():
			result.success = false
			result.notes.append("Explosion targets missing or invalid.")
			return result

		for target in targets:
			if target == null or not target.has_method("take_damage"):
				continue
			target.call("take_damage", amount, context.source_node, PackedStringArray(["explode", String(context.event_name)]), {
				"depth": int(context.runtime.get("depth", context.depth)) + 1,
				"chain_id": context.chain_id,
				"origin_event_name": context.event_name,
			})
		return result
	)


func _resolve_target(context, params: Dictionary) -> Node:
	var target_mode := StringName(params.get("target_mode", &"context_target"))
	match target_mode:
		&"source":
			return context.source_node
		&"owner":
			return context.owner_entity
		&"context_target":
			return context.target_node
		&"event_source":
			return context.core.get("source_node", context.source_node)
		&"event_target":
			return context.core.get("target_node", context.target_node)
		_:
			return context.target_node


func _resolve_targets(context, params: Dictionary) -> Array:
	var target_mode := StringName(params.get("target_mode", &"context_target"))
	if target_mode != &"enemies_in_radius":
		var single_target := _resolve_target(context, params)
		return [] if single_target == null else [single_target]

	if GameState.current_battle == null:
		return []

	var center: Vector2 = context.position
	var radius := float(params.get("radius", 96.0))
	var source_team: StringName = &"neutral"
	if context.owner_entity != null and context.owner_entity.has_method("get"):
		source_team = context.owner_entity.get("team")
	elif context.source_node != null and context.source_node.has_method("get"):
		source_team = context.source_node.get("team")
	var lane_filter: Variant = params.get("lane_id", null)
	var targets: Array = []

	for child in GameState.current_battle.get_children():
		if child == null:
			continue
		if not child.has_method("take_damage"):
			continue
		if not (child is Node2D):
			continue
		if child == context.owner_entity:
			continue
		if child.get("team") == source_team:
			continue
		if lane_filter is int and child.get("lane_id") != lane_filter:
			continue
		var candidate := child as Node2D
		if candidate.global_position.distance_to(center) <= radius:
			targets.append(child)

	return targets
