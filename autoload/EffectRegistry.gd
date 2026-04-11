extends Node

const EffectDefRef = preload("res://scripts/core/defs/effect_def.gd")
const EffectSlotDefRef = preload("res://scripts/core/defs/effect_slot_def.gd")
const EffectResultRef = preload("res://scripts/core/runtime/effect_result.gd")
const ProtocolValidatorRef = preload("res://scripts/core/runtime/protocol_validator.gd")

var _effect_defs: Dictionary = {}
var _effect_strategies: Dictionary = {}


func _ready() -> void:
	_register_builtin_defs()
	_register_builtin_strategies()


func register_def(effect_def) -> void:
	if effect_def == null or effect_def.effect_id == StringName():
		return
	var errors: Array[String] = ProtocolValidatorRef.validate_effect_def(effect_def)
	if not errors.is_empty():
		for error in errors:
			push_warning(error)
			if DebugService.has_method("record_protocol_issue"):
				DebugService.record_protocol_issue(&"effect_def", error, &"error")
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
	var damage_param_defs: Array[Dictionary] = [{
		"name": "amount",
		"type": "int",
		"min": 0,
		"max": 9999,
		"default": 10,
	}, {
		"name": "target_mode",
		"type": "string_name",
		"default": &"context_target",
		"options": PackedStringArray(["source", "owner", "context_target", "event_source", "event_target"]),
	}]
	damage.param_defs = damage_param_defs
	damage.allow_extra_params = false
	damage.allow_extra_children = false
	register_def(damage)

	var spawn_projectile = EffectDefRef.new()
	spawn_projectile.effect_id = &"spawn_projectile"
	var spawn_projectile_param_defs: Array[Dictionary] = [{
		"name": "speed",
		"type": "float",
		"min": 1.0,
		"max": 12000.0,
		"default": 300.0,
	}, {
		"name": "direction",
		"type": "vector2",
		"default": Vector2.RIGHT,
	}, {
		"name": "damage",
		"type": "int",
		"min": 0,
		"max": 9999,
		"default": 10,
	}, {
		"name": "movement_mode",
		"type": "string_name",
		"default": &"linear",
		"options": PackedStringArray(["linear", "track", "parabola"]),
	}, {
		"name": "distance",
		"type": "float",
		"min": 1.0,
		"max": 4000.0,
		"default": 280.0,
	}, {
		"name": "turn_rate",
		"type": "float",
		"min": 0.0,
		"max": 30.0,
		"default": 6.0,
	}, {
		"name": "arc_height",
		"type": "float",
		"min": 0.0,
		"max": 1000.0,
		"default": 72.0,
	}, {
		"name": "impact_radius",
		"type": "float",
		"min": 0.0,
		"max": 500.0,
		"default": 20.0,
	}, {
		"name": "collision_padding",
		"type": "float",
		"min": 0.0,
		"max": 200.0,
		"default": 10.0,
	}, {
		"name": "travel_duration",
		"type": "float",
		"min": -1.0,
		"max": 10.0,
		"default": -1.0,
	}, {
		"name": "lead_time_scale",
		"type": "float",
		"min": 0.0,
		"max": 5.0,
		"default": 1.0,
	}, {
		"name": "dynamic_target_adjustment",
		"type": "float",
		"min": -1.0,
		"max": 2000.0,
		"default": -1.0,
	}, {
		"name": "dynamic_target_axis",
		"type": "string_name",
		"default": &"x",
		"options": PackedStringArray(["x", "y", "xy"]),
	}, {
		"name": "max_lead_distance",
		"type": "float",
		"min": 0.0,
		"max": 5000.0,
	}, {
		"name": "lead_iterations",
		"type": "int",
		"min": 1,
		"max": 8,
		"default": 3,
	}, {
		"name": "flight_profile",
		"type": "resource",
	}]
	spawn_projectile.param_defs = spawn_projectile_param_defs
	var on_hit_slot = EffectSlotDefRef.new()
	on_hit_slot.slot_name = &"on_hit"
	on_hit_slot.slot_type = EffectSlotDefRef.SlotType.EFFECT
	spawn_projectile.slots = [on_hit_slot]
	spawn_projectile.allow_extra_params = false
	spawn_projectile.allow_extra_children = false
	register_def(spawn_projectile)

	var explode = EffectDefRef.new()
	explode.effect_id = &"explode"
	var explode_param_defs: Array[Dictionary] = [{
		"name": "amount",
		"type": "int",
		"min": 0,
		"max": 9999,
		"default": 15,
	}, {
		"name": "target_mode",
		"type": "string_name",
		"default": &"context_target",
		"options": PackedStringArray(["source", "owner", "context_target", "event_source", "event_target", "enemies_in_radius"]),
	}, {
		"name": "radius",
		"type": "float",
		"min": 0.0,
		"max": 1000.0,
		"default": 96.0,
	}, {
		"name": "lane_id",
		"type": "int",
		"min": 0,
		"max": 16,
	}]
	explode.param_defs = explode_param_defs
	explode.allow_extra_params = false
	explode.allow_extra_children = false
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

	var center: Vector2 = _node_ground_position(context.owner_entity)
	if center == Vector2.ZERO:
		center = _node_ground_position(context.target_node)
	if center == Vector2.ZERO:
		center = _node_ground_position(context.source_node)
	var radius := float(params.get("radius", 96.0))
	var source_team: StringName = &"neutral"
	if context.owner_entity != null and context.owner_entity.has_method("get"):
		source_team = context.owner_entity.get("team")
	elif context.source_node != null and context.source_node.has_method("get"):
		source_team = context.source_node.get("team")
	var lane_filter: Variant = params.get("lane_id", null)
	var targets: Array = []

	if not GameState.current_battle.has_method("get_runtime_entities"):
		return targets

	for child in GameState.current_battle.call("get_runtime_entities"):
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
		if _node_ground_position(candidate).distance_to(center) <= radius:
			targets.append(child)

	return targets


func _node_ground_position(node: Node) -> Vector2:
	if node == null or not (node is Node2D):
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return (node as Node2D).global_position
