extends Node
class_name InfrastructureValidationProbe

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const EffectNodeRef = preload("res://scripts/core/runtime/effect_node.gd")
const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")
const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")
const ProjectileRootRef = preload("res://scripts/entities/projectile_root.gd")
const StateComponentRef = preload("res://scripts/components/state_component.gd")

var _battle: Node = null
var _emitted: Dictionary = {}
var _factory: RefCounted = EntityFactoryRef.new()


func setup(battle: Node) -> void:
	_battle = battle


func _process(_delta: float) -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	var active_scenario: Variant = _battle.resolve_scenario()
	if active_scenario == null:
		return
	var scenario_id: StringName = StringName(active_scenario.scenario_id)
	if scenario_id == &"spatial_index_consistency_validation":
		_probe_spatial_index()
	elif scenario_id == &"health_layer_helm_routing_validation":
		_probe_health_layer(&"health_layer_helm_routing", &"helm", &"spill_to_next")
	elif scenario_id == &"health_layer_shield_routing_validation":
		_probe_health_layer(&"health_layer_shield_routing", &"shield", &"spill_to_next")
	elif scenario_id == &"health_layer_attachment_routing_validation":
		_probe_health_layer(&"health_layer_attachment_routing", &"attachment", &"absorb_only")
	elif scenario_id == &"damage_layer_policy_bypass_shield_validation":
		_probe_damage_layer_policy_bypass_shield()
	elif scenario_id == &"movement_walk_validation":
		_probe_movement_walk()
	elif scenario_id == &"movement_command_merge_validation":
		_probe_movement_command_merge()
	elif scenario_id == &"movement_leap_z_axis_validation":
		_probe_movement_leap_z_axis()
	elif scenario_id == &"movement_interrupt_validation":
		_probe_movement_interrupt()
	elif scenario_id == &"state_side_effect_set_movement_validation":
		_probe_state_side_effect_set_movement()
	elif scenario_id == &"hit_policy_exposure_ground_default_validation":
		_probe_exposure_ground_default()
	elif scenario_id == &"hit_policy_exposure_flying_validation":
		_probe_exposure_flying()
	elif scenario_id == &"hit_policy_exposure_hidden_validation":
		_probe_exposure_hidden()
	elif scenario_id == &"force_weight_filter_validation":
		_probe_force_weight_filter()


func _probe_spatial_index() -> void:
	if _emitted.has(&"spatial_index"):
		return
	if not _battle.has_method("spatial_query") or not _battle.has_method("get_runtime_combat_entities"):
		return
	if int(_battle.call("get_spatial_snapshot_version")) <= 0:
		return
	var entities: Array = _battle.call("get_runtime_combat_entities")
	if entities.size() < 4:
		return

	var lane_team_query: Dictionary = {
		"team_exclude": &"plant",
		"lane_ids": PackedInt32Array([1]),
		"x_min": 120.0,
		"x_max": 360.0,
		"filter": func(candidate): return _is_targetable(candidate),
		"sort_by_x": true,
	}
	if not _query_matches_scan(lane_team_query, func(candidate): return _is_targetable(candidate)):
		return
	_emit_probe(&"spatial_lane_team_x", &"passed", {"count": _battle.call("spatial_query", lane_team_query).size()})

	var tag_kind_query: Dictionary = {
		"team_include": &"zombie",
		"tags_any": PackedStringArray(["scout"]),
		"kinds": PackedStringArray(["zombie"]),
		"filter": func(candidate): return _is_targetable(candidate),
	}
	if not _query_matches_scan(tag_kind_query, func(candidate): return _is_targetable(candidate)):
		return
	_emit_probe(&"spatial_tag_kind", &"passed", {"count": _battle.call("spatial_query", tag_kind_query).size()})

	var height_query: Dictionary = {
		"team_include": &"zombie",
		"lane_ids": PackedInt32Array([1]),
		"height_range": Vector2(40.0, 80.0),
		"filter": func(candidate): return _is_targetable(candidate),
		"sort_by_x": true,
	}
	if not _query_matches_scan(height_query, func(candidate): return _is_targetable(candidate)):
		return
	_emit_probe(&"spatial_height_range", &"passed", {"count": _battle.call("spatial_query", height_query).size()})

	var stable_a: PackedInt32Array = _ids(_battle.call("spatial_query", lane_team_query))
	var stable_b: PackedInt32Array = _ids(_battle.call("spatial_query", lane_team_query))
	if stable_a != stable_b or stable_a.is_empty():
		return
	_emit_probe(&"spatial_stable_order", &"passed", {"count": stable_a.size()})
	_emitted[&"spatial_index"] = true


func _probe_health_layer(probe_id: StringName, layer_kind: StringName, overflow_policy: StringName) -> void:
	if _emitted.has(probe_id):
		return
	var zombie := _spawn_probe_entity(&"zombie", Vector2(360.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
		"health_layers": [_make_layer("probe_%s" % String(layer_kind), layer_kind, 40, overflow_policy)],
	})
	if zombie == null:
		return
	zombie.call("take_damage", 60, null, PackedStringArray(["probe"]))
	var layer := _layer_snapshot(zombie, StringName("probe_%s" % String(layer_kind)))
	if layer.is_empty():
		return
	var body_health := _entity_health(zombie)
	var expected_body := 100 if overflow_policy == &"absorb_only" else 80
	if int(layer.get("current_health", -1)) != 0 or body_health != expected_body:
		return
	_emit_probe(probe_id, &"passed", {
		"layer_kind": layer_kind,
		"body_health": body_health,
	})
	_emitted[probe_id] = true


func _probe_damage_layer_policy_bypass_shield() -> void:
	var probe_id := &"damage_layer_policy_bypass_shield"
	if _emitted.has(probe_id):
		return
	var policy := {
		"bypass_layer_kinds": PackedStringArray(["shield"]),
		"spillover": true,
	}
	var direct_ok := _apply_policy_damage_through_effect(policy)
	var projectile_ok := _apply_policy_damage_through_projectile(policy, false)
	var on_hit_ok := _apply_policy_damage_through_projectile(policy, true)
	if not (direct_ok and projectile_ok and on_hit_ok):
		return
	_emit_probe(probe_id, &"passed", {
		"direct_damage": direct_ok,
		"projectile_direct": projectile_ok,
		"projectile_on_hit": on_hit_ok,
	})
	_emitted[probe_id] = true


func _probe_movement_walk() -> void:
	var probe_id := &"movement_walk"
	if _emitted.has(probe_id):
		return
	var zombie := _spawn_probe_entity(&"zombie", Vector2(420.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
	})
	if zombie == null:
		return
	zombie.call("set_movement_spec", {
		"movement_id": &"core.walk",
		"params": {"move_speed": 100.0, "direction": Vector2.LEFT},
	})
	var movement_component: Variant = zombie.get_node_or_null("MovementComponent")
	if movement_component == null or not movement_component.has_method("physics_process_entity_movement"):
		return
	var start_x: float = zombie.global_position.x
	movement_component.call("physics_process_entity_movement", zombie, 0.25, Vector2.ZERO, &"probe", true)
	if zombie.global_position.x > start_x - 24.0:
		return
	if StringName(zombie.call("get_exposure_state")) != &"ground":
		return
	_emit_probe(probe_id, &"passed", {"delta_x": zombie.global_position.x - start_x})
	_emitted[probe_id] = true


func _probe_movement_command_merge() -> void:
	var probe_id := &"movement_command_merge"
	if _emitted.has(probe_id):
		return
	var zombie := _spawn_probe_entity(&"zombie", Vector2(420.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
	})
	if zombie == null:
		return
	zombie.call("set_movement_spec", {
		"movement_id": &"core.walk",
		"params": {"move_speed": 100.0, "direction": Vector2.LEFT},
	})
	zombie.call("apply_status", &"slow_probe", 1.0, {"movement_scale": 0.5})
	var movement_component: Variant = zombie.get_node_or_null("MovementComponent")
	if movement_component == null:
		return
	movement_component.call("submit_command", {"command_kind": &"impulse", "ground_velocity": Vector2(20.0, 0.0)})
	movement_component.call("physics_process_entity_movement", zombie, 1.0, Vector2.ZERO, &"probe", true)
	var final_velocity := Vector2(movement_component.call("get_final_velocity"))
	if absf(final_velocity.x - -30.0) > 0.01:
		return
	_emit_probe(probe_id, &"passed", {"final_velocity_x": final_velocity.x})
	_emitted[probe_id] = true


func _probe_movement_leap_z_axis() -> void:
	var probe_id := &"movement_leap_z_axis"
	if _emitted.has(probe_id):
		return
	var zombie := _spawn_probe_entity(&"zombie", Vector2(420.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
	})
	if zombie == null:
		return
	zombie.call("set_movement_spec", {
		"movement_id": &"core.leap_once",
		"params": {"move_speed": 0.0, "jump_velocity": 160.0, "gravity": -320.0},
	})
	var movement_component: Variant = zombie.get_node_or_null("MovementComponent")
	if movement_component == null:
		return
	var saw_airborne := false
	var landed := false
	for _i in range(90):
		movement_component.call("physics_process_entity_movement", zombie, 0.02, Vector2.ZERO, &"probe", true)
		if float(zombie.call("get_height")) > 0.1 and StringName(zombie.call("get_exposure_state")) == &"airborne" and not bool(zombie.call("is_ground_contact")):
			saw_airborne = true
		if saw_airborne and bool(zombie.call("is_ground_contact")) and float(zombie.call("get_height")) <= 0.001:
			landed = true
			break
	if not (saw_airborne and landed):
		return
	_emit_probe(probe_id, &"passed", {"landed": landed})
	_emitted[probe_id] = true


func _probe_movement_interrupt() -> void:
	var probe_id := &"movement_interrupt"
	if _emitted.has(probe_id):
		return
	var zombie := _spawn_probe_entity(&"zombie", Vector2(420.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
	})
	if zombie == null:
		return
	zombie.call("set_movement_spec", {
		"movement_id": &"core.walk",
		"params": {"move_speed": 100.0, "direction": Vector2.LEFT},
	})
	zombie.call("push_liveness_override", &"probe_interrupt", {&"movement": false}, 100)
	var movement_component: Variant = zombie.get_node_or_null("MovementComponent")
	if movement_component == null:
		return
	var start_x: float = zombie.global_position.x
	movement_component.call("physics_process_entity_movement", zombie, 0.5, Vector2.ZERO, &"probe", true)
	var pause_reason := StringName(zombie.call("get_entity_state_ref").call("get_value", &"movement_pause_reason", StringName()))
	if absf(zombie.global_position.x - start_x) > 0.01 or pause_reason != &"movement_disabled":
		return
	_emit_probe(probe_id, &"passed", {"pause_reason": pause_reason})
	_emitted[probe_id] = true


func _probe_state_side_effect_set_movement() -> void:
	var probe_id := &"state_side_effect_set_movement"
	if _emitted.has(probe_id):
		return
	var zombie := _spawn_probe_entity(&"zombie", Vector2(420.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
		"health_layers": [_make_layer("balloon_attachment", &"attachment", 20, &"spill_to_next")],
	})
	if zombie == null:
		return
	zombie.call("set_motion_state", 40.0, 0.0, false, &"flying", &"probe", StringName())
	var state_component := StateComponentRef.new()
	state_component.name = "StateComponent"
	zombie.add_child(state_component)
	state_component.bind_state_specs([{
		"initial_state": &"attached",
		"transitions": [{
			"transition_id": &"attachment_destroyed_to_ground",
			"from_state": &"attached",
			"to_state": &"grounded",
			"trigger": "event",
			"event_name": &"health.layer_destroyed",
			"required_layer_id": &"balloon_attachment",
			"side_effects": [{
				"type": &"set_height_band",
				"height_band": {
					"height": 0.0,
					"height_velocity": 0.0,
					"ground_contact": true,
					"exposure_state": &"ground",
				},
			}, {
				"type": &"set_movement",
				"spec": {
					"movement_id": &"core.walk",
					"params": {"move_speed": 40.0, "direction": Vector2.LEFT},
				},
			}],
		}],
	}])
	zombie.call("take_damage", 25, null, PackedStringArray(["probe"]))
	var movement_spec: Variant = zombie.call("get_entity_state_ref").call("get_value", &"movement_spec", {})
	if StringName(zombie.call("get_exposure_state")) != &"ground":
		return
	if not (movement_spec is Dictionary) or StringName(Dictionary(movement_spec).get("movement_id", StringName())) != &"core.walk":
		return
	_emit_probe(probe_id, &"passed", {"movement_id": &"core.walk", "exposure_state": &"ground"})
	_emitted[probe_id] = true


func _probe_exposure_ground_default() -> void:
	var probe_id := &"hit_policy_exposure_ground_default"
	if _emitted.has(probe_id):
		return
	var flying := _spawn_probe_entity(&"zombie", Vector2(430.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
		"initial_exposure_state": &"flying",
	})
	if flying == null:
		return
	var before := _entity_health(flying)
	_execute_damage_effect(flying, {"amount": 20, "target_mode": &"context_target"})
	if _entity_health(flying) != before:
		return
	_emit_probe(probe_id, &"passed", {"health": _entity_health(flying)})
	_emitted[probe_id] = true


func _probe_exposure_flying() -> void:
	var probe_id := &"hit_policy_exposure_flying"
	if _emitted.has(probe_id):
		return
	var flying := _spawn_probe_entity(&"zombie", Vector2(430.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
		"initial_exposure_state": &"flying",
	})
	if flying == null:
		return
	_execute_damage_effect(flying, {
		"amount": 20,
		"target_mode": &"context_target",
		"target_exposure_states": PackedStringArray(["flying"]),
	})
	if _entity_health(flying) != 80:
		return
	_emit_probe(probe_id, &"passed", {"health": _entity_health(flying)})
	_emitted[probe_id] = true


func _probe_exposure_hidden() -> void:
	var probe_id := &"hit_policy_exposure_hidden"
	if _emitted.has(probe_id):
		return
	var underground := _spawn_probe_entity(&"zombie", Vector2(430.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
		"initial_exposure_state": &"underground",
	})
	if underground == null:
		return
	_execute_damage_effect(underground, {"amount": 20, "target_mode": &"context_target"})
	if _entity_health(underground) != 100:
		return
	_execute_damage_effect(underground, {
		"amount": 20,
		"target_mode": &"context_target",
		"target_exposure_states": PackedStringArray(["underground"]),
	})
	if _entity_health(underground) != 80:
		return
	_emit_probe(probe_id, &"passed", {"health": _entity_health(underground)})
	_emitted[probe_id] = true


func _probe_force_weight_filter() -> void:
	var probe_id := &"force_weight_filter"
	if _emitted.has(probe_id):
		return
	var normal := _spawn_probe_entity(&"zombie", Vector2(360.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
		"initial_exposure_state": &"flying",
		"weight_class": &"normal",
	})
	var heavy := _spawn_probe_entity(&"zombie", Vector2(410.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
		"initial_exposure_state": &"flying",
		"weight_class": &"heavy",
	})
	var source := _spawn_probe_entity(&"plant", Vector2(320.0, 160.0), {"lane_id": 0, "max_health": 100})
	if normal == null or heavy == null or source == null:
		return
	_rebuild_spatial_index()
	var context = RuleContextRef.new()
	context.owner_entity = source
	context.source_node = source
	context.position = source.global_position
	context.event_name = &"probe.dispel"
	context.runtime = {"chain_id": "probe", "depth": 1}
	EffectExecutorRef.execute_node(EffectNodeRef.new(&"dispel_flying", {
		"amount": 20,
		"radius": 180.0,
		"target_exposure_states": PackedStringArray(["flying"]),
		"max_weight_class": &"normal",
	}), context)
	if _entity_health(normal) != 80 or _entity_health(heavy) != 100:
		return
	_emit_probe(probe_id, &"passed", {"normal_health": _entity_health(normal), "heavy_health": _entity_health(heavy)})
	_emitted[probe_id] = true


func _spawn_probe_entity(entity_kind: StringName, position: Vector2, params: Dictionary) -> Node:
	var entity: Node = null
	match entity_kind:
		&"plant":
			entity = _factory.call("create_plant", position, null, params)
		&"zombie":
			entity = _factory.call("create_zombie", position, null, params)
		_:
			entity = _factory.call("instantiate_entity", entity_kind, position, null, params)
	if entity == null:
		return null
	var lane_id := int(params.get("lane_id", 0))
	if _battle != null and _battle.has_method("finalize_spawned_entity"):
		_battle.call("finalize_spawned_entity", entity, lane_id, null, [], null, {"spawn_reason": &"infrastructure_probe"}, false)
	elif _battle != null and _battle.has_method("get_entity_root"):
		var entity_root: Node = _battle.call("get_entity_root")
		if entity_root != null:
			entity.call("assign_lane", lane_id)
			entity_root.add_child(entity)
	return entity


func _make_layer(layer_id: String, layer_kind: StringName, max_health: int, overflow_policy: StringName = &"spill_to_next") -> Dictionary:
	return {
		"layer_id": StringName(layer_id),
		"layer_kind": layer_kind,
		"max_health": max_health,
		"current_health": max_health,
		"overflow_policy": overflow_policy,
	}


func _layer_snapshot(entity: Node, layer_id: StringName) -> Dictionary:
	if entity == null:
		return {}
	var health_component: Variant = entity.get_node_or_null("HealthComponent")
	if health_component == null or not health_component.has_method("get_health_layers_snapshot"):
		return {}
	for layer in Array(health_component.call("get_health_layers_snapshot")):
		if layer is Dictionary and StringName(Dictionary(layer).get("layer_id", StringName())) == layer_id:
			return Dictionary(layer)
	return {}


func _entity_health(entity: Node) -> int:
	if entity == null:
		return -1
	var health_component: Variant = entity.get_node_or_null("HealthComponent")
	if health_component == null:
		return -1
	return int(health_component.current_health)


func _apply_policy_damage_through_effect(policy: Dictionary) -> bool:
	var target := _spawn_policy_target()
	if target == null:
		return false
	_execute_damage_effect(target, {
		"amount": 60,
		"target_mode": &"context_target",
		"damage_layer_policy": policy,
	})
	return _policy_bypassed_shield(target)


func _apply_policy_damage_through_projectile(policy: Dictionary, use_on_hit: bool) -> bool:
	var target := _spawn_policy_target()
	if target == null:
		return false
	var projectile := ProjectileRootRef.new()
	var on_hit = EffectNodeRef.new(&"damage", {
		"amount": 60,
		"target_mode": &"context_target",
	}) if use_on_hit else null
	projectile.launch(Vector2.RIGHT, 1.0, null, on_hit, 60, {
		"target_exposure_states": PackedStringArray(["ground"]),
	}, {
		"damage_layer_policy": policy,
		"chain_id": "policy_probe",
		"depth": 1,
	})
	projectile.call("_on_hit", target, &"probe")
	return _policy_bypassed_shield(target)


func _spawn_policy_target() -> Node:
	return _spawn_probe_entity(&"zombie", Vector2(430.0, 160.0), {
		"lane_id": 0,
		"max_health": 100,
		"move_speed_slots_per_sec": 0.0,
		"health_layers": [
			_make_layer("policy_attachment", &"attachment", 30, &"spill_to_next"),
			_make_layer("policy_shield", &"shield", 40, &"spill_to_next"),
			_make_layer("policy_helm", &"helm", 50, &"spill_to_next"),
		],
	})


func _policy_bypassed_shield(target: Node) -> bool:
	var attachment := _layer_snapshot(target, &"policy_attachment")
	var shield := _layer_snapshot(target, &"policy_shield")
	var helm := _layer_snapshot(target, &"policy_helm")
	if attachment.is_empty() or shield.is_empty() or helm.is_empty():
		return false
	return int(attachment.get("current_health", -1)) == 0 \
		and int(shield.get("current_health", -1)) == 40 \
		and int(helm.get("current_health", -1)) == 20 \
		and _entity_health(target) == 100


func _execute_damage_effect(target: Node, params: Dictionary) -> void:
	var context = RuleContextRef.new()
	context.owner_entity = target
	context.source_node = target
	context.target_node = target
	context.position = target.global_position if target is Node2D else Vector2.ZERO
	context.event_name = &"infrastructure.probe"
	context.runtime = {"chain_id": "infrastructure_probe", "depth": 1}
	EffectExecutorRef.execute_node(EffectNodeRef.new(&"damage", params), context)


func _rebuild_spatial_index() -> void:
	if _battle != null and _battle.has_method("_rebuild_spatial_index"):
		_battle.call("_rebuild_spatial_index")


func _query_matches_scan(query: Dictionary, extra_filter: Callable) -> bool:
	var spatial: Array = _battle.call("spatial_query", query)
	var scanned: Array = _scan_entities(query, extra_filter)
	return _ids(spatial) == _ids(scanned)


func _scan_entities(query: Dictionary, extra_filter: Callable) -> Array:
	var result: Array = []
	for candidate in _battle.call("get_runtime_combat_entities"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not (candidate is Node2D):
			continue
		if not _passes_scan_filters(candidate, query):
			continue
		if extra_filter.is_valid() and not bool(extra_filter.call(candidate)):
			continue
		result.append(candidate)
	if bool(query.get("sort_by_x", false)):
		result.sort_custom(func(a, b): return _compare_by_x(a, b))
	elif bool(query.get("sort_by_distance", false)) and query.has("center"):
		var center := Vector2(query.get("center"))
		result.sort_custom(func(a, b): return _compare_by_distance(a, b, center))
	var max_results := int(query.get("max_results", 0))
	if max_results > 0 and result.size() > max_results:
		return result.slice(0, max_results)
	return result


func _passes_scan_filters(candidate: Node2D, query: Dictionary) -> bool:
	if query.has("team_exclude") and StringName(candidate.get("team")) == StringName(query.get("team_exclude")):
		return false
	if query.has("team_include") and StringName(candidate.get("team")) != StringName(query.get("team_include")):
		return false
	if query.has("lane_ids"):
		var lane_ids := PackedInt32Array(query.get("lane_ids", PackedInt32Array()))
		if not lane_ids.is_empty() and not lane_ids.has(int(candidate.get("lane_id"))):
			return false
	if query.has("tags_any"):
		var tags_any := PackedStringArray(query.get("tags_any", PackedStringArray()))
		if not tags_any.is_empty() and not _has_any_tag(candidate, tags_any):
			return false
	if query.has("kinds"):
		var kinds := PackedStringArray(query.get("kinds", PackedStringArray()))
		if not kinds.is_empty() and not kinds.has(String(candidate.get("entity_kind"))):
			return false
	var position: Vector2 = _node_ground_position(candidate)
	if query.has("x_min") and position.x < float(query.get("x_min")):
		return false
	if query.has("x_max") and position.x > float(query.get("x_max")):
		return false
	if query.has("center") and query.has("radius"):
		if position.distance_to(Vector2(query.get("center"))) > float(query.get("radius")):
			return false
	if query.has("height_range") and not _height_overlaps(candidate, Vector2(query.get("height_range"))):
		return false
	return true


func _has_any_tag(candidate: Node, tags: PackedStringArray) -> bool:
	var raw_tags: Variant = candidate.get("tags")
	var candidate_tags: PackedStringArray = PackedStringArray()
	if raw_tags is PackedStringArray:
		candidate_tags = raw_tags
	elif raw_tags is Array:
		candidate_tags = PackedStringArray(raw_tags)
	for tag in tags:
		if candidate_tags.has(StringName(tag)):
			return true
	return false


func _height_overlaps(candidate: Node, height_range: Vector2) -> bool:
	var candidate_range := Vector2(0.0, 24.0)
	if candidate.has_method("get_hit_height_range"):
		var value: Variant = candidate.call("get_hit_height_range")
		if value is Vector2:
			candidate_range = value
	var terrain_z := _terrain_elevation_for(candidate)
	candidate_range = Vector2(terrain_z + candidate_range.x, terrain_z + candidate_range.y)
	return height_range.y >= candidate_range.x and height_range.x <= candidate_range.y


func _terrain_elevation_for(candidate: Node) -> float:
	var lane_value: Variant = candidate.get("lane_id")
	if not (lane_value is int):
		return 0.0
	if _battle == null or not _battle.has_method("get_battlefield_metrics"):
		return 0.0
	var metrics: Variant = _battle.call("get_battlefield_metrics")
	if metrics == null or not metrics.has_method("terrain_elevation_at"):
		return 0.0
	return float(metrics.call("terrain_elevation_at", int(lane_value), _node_ground_position(candidate).x))


func _is_targetable(candidate: Node) -> bool:
	return candidate != null and candidate.has_method("is_targetable") and bool(candidate.call("is_targetable"))


func _node_ground_position(node: Node) -> Vector2:
	if node != null and node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.ZERO


func _compare_by_x(a, b) -> bool:
	var ax: float = _node_ground_position(a).x
	var bx: float = _node_ground_position(b).x
	if not is_equal_approx(ax, bx):
		return ax < bx
	return _stable_id(a) < _stable_id(b)


func _compare_by_distance(a, b, center: Vector2) -> bool:
	var ad: float = center.distance_squared_to(_node_ground_position(a))
	var bd: float = center.distance_squared_to(_node_ground_position(b))
	if not is_equal_approx(ad, bd):
		return ad < bd
	return _stable_id(a) < _stable_id(b)


func _ids(nodes: Array) -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for node in nodes:
		if node != null and node.has_method("get_entity_id"):
			ids.append(int(node.call("get_entity_id")))
	return ids


func _stable_id(node: Node) -> int:
	if node != null and node.has_method("get_entity_id"):
		return int(node.call("get_entity_id"))
	return 2147483647


func _emit_probe(probe: StringName, result: StringName, extra_core: Dictionary = {}) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["infrastructure", "validation"]))
	event_data.core["probe"] = probe
	event_data.core["result"] = result
	for key: Variant in extra_core.keys():
		event_data.core[key] = extra_core[key]
	EventBus.push_event(&"infrastructure.validation_probe", event_data)
