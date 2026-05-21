extends Node
class_name OriginalZombieValidationProbe

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const BattleSpawnEntryRef = preload("res://scripts/battle/battle_spawn_entry.gd")
const EffectNodeRef = preload("res://scripts/core/runtime/effect_node.gd")
const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")
const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")
const MechanicCompilerRef = preload("res://scripts/core/runtime/mechanic_compiler.gd")

const BATCHES := {
	&"zombie_original_batch_a": [&"basic_zombie", &"flag_zombie", &"conehead", &"buckethead"],
	&"zombie_original_batch_b": [&"football", &"screen_door", &"newspaper", &"pole_vaulter"],
	&"zombie_original_batch_c": [&"ducky_tube", &"snorkel", &"dolphin_rider", &"zomboni"],
	&"zombie_original_batch_d": [&"balloon", &"jack_in_the_box", &"digger", &"pogo", &"yeti", &"bungee", &"ladder", &"catapult"],
	&"zombie_original_batch_e": [&"dancing", &"backup_dancer", &"gargantuar", &"imp", &"redeye_gargantuar"],
}

var _battle: Node = null
var _factory: RefCounted = EntityFactoryRef.new()
var _emitted: Dictionary = {}


func setup(battle: Node) -> void:
	_battle = battle


func _process(_delta: float) -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	var active_scenario: Variant = _battle.resolve_scenario()
	if active_scenario == null:
		return
	var scenario_id := StringName(active_scenario.scenario_id)
	var probe_id := _probe_id_for_scenario(scenario_id)
	if probe_id == StringName() or _emitted.has(probe_id):
		return
	if BATCHES.has(probe_id):
		_probe_batch(probe_id, Array(BATCHES[probe_id]))
	else:
		_probe_single(probe_id)


func _probe_id_for_scenario(scenario_id: StringName) -> StringName:
	var scenario := String(scenario_id)
	if not scenario.begins_with("zombie_original_") or not scenario.ends_with("_validation"):
		return StringName()
	return StringName(scenario.trim_suffix("_validation"))


func _probe_batch(probe_id: StringName, slugs: Array) -> void:
	for slug in slugs:
		if not _validate_slug(StringName(slug)):
			return
	_emit_probe(probe_id, &"passed", {"count": slugs.size()})
	_emitted[probe_id] = true


func _probe_single(probe_id: StringName) -> void:
	var slug := String(probe_id).trim_prefix("zombie_original_")
	if slug.is_empty():
		return
	if not _validate_slug(StringName(slug)):
		return
	_emit_probe(probe_id, &"passed", {"slug": StringName(slug)})
	_emitted[probe_id] = true


func _validate_slug(slug: StringName) -> bool:
	var archetype_id := StringName("archetype_original_%s" % String(slug))
	if not SceneRegistry.has_archetype(archetype_id):
		return false
	var archetype: Resource = SceneRegistry.get_archetype(archetype_id)
	if archetype == null:
		return false
	if StringName(archetype.get("entity_kind")) != &"zombie":
		return false
	if not _has_required_tags(archetype, PackedStringArray(["original", "zombie"])):
		return false
	var runtime_spec = MechanicCompilerRef.new().compile_spawn_entry(null, archetype)
	if runtime_spec == null:
		return false
	if Dictionary(runtime_spec.get("movement_spec")).is_empty():
		return false
	var entity := _spawn_archetype(archetype_id, _spawn_position_for(slug), {"spawn_reason": &"original_zombie_probe"}, false)
	if entity == null:
		return false
	if not _assert_common_entity(entity, archetype_id):
		return false
	match slug:
		&"conehead":
			return _assert_layer(entity, &"cone", &"helm", 370)
		&"buckethead":
			return _assert_layer(entity, &"bucket", &"helm", 1100)
		&"football":
			return _assert_layer(entity, &"football_helmet", &"helm", 1400)
		&"screen_door":
			return _assert_layer(entity, &"screen_door", &"shield", 1100)
		&"newspaper":
			return _assert_layer(entity, &"newspaper", &"shield", 150) and _assert_newspaper_rage(entity)
		&"pole_vaulter", &"dolphin_rider":
			return _assert_movement_source(entity, &"core.leap_once")
		&"ducky_tube":
			return _has_required_tags(archetype, PackedStringArray(["spawn.medium.water"]))
		&"snorkel":
			return StringName(entity.call("get_exposure_state")) == &"submerged" and _assert_hidden_exposure_filter(entity, &"submerged")
		&"zomboni":
			return _assert_movement_source(entity, &"core.drive") and _assert_controller(entity, &"core.crush")
		&"balloon":
			return _assert_layer(entity, &"balloon", &"attachment", 20) and StringName(entity.call("get_exposure_state")) == &"flying" and _assert_balloon_grounding(entity)
		&"jack_in_the_box":
			return _assert_trigger_payload(runtime_spec, &"periodically", &"explode")
		&"digger":
			return _assert_movement_source(entity, &"core.tunnel") and StringName(entity.call("get_exposure_state")) == &"underground"
		&"pogo":
			return _assert_movement_source(entity, &"core.hop_cycle")
		&"yeti":
			return _assert_yeti_flee(entity)
		&"bungee":
			return StringName(entity.call("get_exposure_state")) == &"flying" and _assert_trigger_payload(runtime_spec, &"on_spawned", &"damage")
		&"ladder":
			return _assert_layer(entity, &"ladder", &"attachment", 500)
		&"catapult":
			return _assert_trigger_payload(runtime_spec, &"periodically", &"spawn_projectile")
		&"dancing":
			return _assert_dancing_spawn(entity)
		&"gargantuar":
			return _assert_controller(entity, &"core.crush") and _assert_threshold_imp_spawn(entity, 1500)
		&"redeye_gargantuar":
			return _assert_controller(entity, &"core.crush") and _assert_threshold_imp_spawn(entity, 3000)
		_:
			return true


func _assert_common_entity(entity: Node, archetype_id: StringName) -> bool:
	if entity.get("archetype_id") != archetype_id:
		return false
	if entity.get_node_or_null("MovementComponent") == null:
		return false
	if entity.get_node_or_null("HealthComponent") == null:
		return false
	return true


func _assert_layer(entity: Node, layer_id: StringName, layer_kind: StringName, max_health: int) -> bool:
	var layer := _layer_snapshot(entity, layer_id)
	return not layer.is_empty() \
		and StringName(layer.get("layer_kind", StringName())) == layer_kind \
		and int(layer.get("max_health", 0)) == max_health


func _assert_newspaper_rage(entity: Node) -> bool:
	entity.call("take_damage", 151, null, PackedStringArray(["probe"]))
	var state_stage := StringName(entity.call("get_entity_state_ref").call("get_value", &"state_stage", StringName()))
	var movement_spec: Variant = entity.call("get_entity_state_ref").call("get_value", &"movement_spec", {})
	if state_stage != &"rage" or not (movement_spec is Dictionary):
		return false
	return absf(float(Dictionary(movement_spec).get("params", {}).get("move_speed_slots_per_sec", 0.0)) - 0.89) < 0.001


func _assert_balloon_grounding(entity: Node) -> bool:
	entity.call("take_damage", 21, null, PackedStringArray(["probe"]))
	return StringName(entity.call("get_exposure_state")) == &"ground"


func _assert_hidden_exposure_filter(entity: Node, exposure_state: StringName) -> bool:
	var before := _entity_health(entity)
	_execute_damage_effect(entity, {"amount": 20, "target_mode": &"context_target"})
	if _entity_health(entity) != before:
		return false
	_execute_damage_effect(entity, {
		"amount": 20,
		"target_mode": &"context_target",
		"target_exposure_states": PackedStringArray([String(exposure_state)]),
	})
	return _entity_health(entity) == before - 20


func _assert_movement_source(entity: Node, movement_id: StringName) -> bool:
	var movement_spec: Variant = entity.call("get_entity_state_ref").call("get_value", &"movement_spec", {})
	return movement_spec is Dictionary and StringName(Dictionary(movement_spec).get("movement_id", StringName())) == movement_id


func _assert_controller(entity: Node, controller_id: StringName) -> bool:
	var controller_component: Variant = entity.get_node_or_null("ControllerComponent")
	if controller_component == null:
		return false
	for spec in Array(controller_component.get("controller_specs")):
		if spec is Dictionary and StringName(Dictionary(spec).get("controller_id", StringName())) == controller_id:
			return true
	return false


func _assert_trigger_payload(runtime_spec, trigger_id: StringName, effect_id: StringName) -> bool:
	for trigger_spec in Array(runtime_spec.get("trigger_specs")):
		if trigger_spec == null:
			continue
		if StringName(trigger_spec.get("trigger_id")) != trigger_id:
			continue
		var effect_root: Variant = trigger_spec.get("effect_root")
		if effect_root != null and StringName(effect_root.get("effect_id")) == effect_id:
			return true
	return false


func _assert_yeti_flee(entity: Node) -> bool:
	entity.call("take_damage", 1, null, PackedStringArray(["probe"]))
	var movement_spec: Variant = entity.call("get_entity_state_ref").call("get_value", &"movement_spec", {})
	if not (movement_spec is Dictionary):
		return false
	var params: Dictionary = Dictionary(movement_spec).get("params", {})
	return StringName(entity.call("get_entity_state_ref").call("get_value", &"state_stage", StringName())) == &"fleeing" \
		and Vector2(params.get("direction", Vector2.ZERO)).x > 0.0 \
		and absf(float(params.get("move_speed_slots_per_sec", 0.0)) - 0.8) < 0.001


func _assert_dancing_spawn(entity: Node) -> bool:
	var base_count := _count_archetype(&"archetype_original_backup_dancer")
	_spawn_archetype(&"archetype_original_dancing", Vector2(520.0, 320.0), {"spawn_reason": &"dancer_probe"}, true)
	return _count_archetype(&"archetype_original_backup_dancer") - base_count == 4


func _assert_threshold_imp_spawn(entity: Node, damage: int) -> bool:
	var base_count := _count_archetype(&"archetype_original_imp")
	entity.call("take_damage", damage, null, PackedStringArray(["probe"]))
	var after_first := _count_archetype(&"archetype_original_imp")
	entity.call("take_damage", 1, null, PackedStringArray(["probe"]))
	var after_second := _count_archetype(&"archetype_original_imp")
	return after_first == base_count + 1 and after_second == after_first


func _spawn_archetype(archetype_id: StringName, position: Vector2, metadata: Dictionary = {}, emit_spawn := true) -> Node:
	if not SceneRegistry.has_archetype(archetype_id):
		return null
	var spawn_entry = BattleSpawnEntryRef.new()
	spawn_entry.entity_kind = &"zombie"
	spawn_entry.archetype_id = archetype_id
	spawn_entry.lane_id = 1 if position.y > 260.0 else 0
	spawn_entry.x_position = position.x
	var resolution: Dictionary = _factory.call("instantiate_spawn_entry", spawn_entry, position)
	var entity: Node = resolution.get("entity", null)
	if entity == null:
		return null
	if _battle != null and _battle.has_method("finalize_spawned_entity"):
		_battle.call("finalize_spawned_entity", entity, spawn_entry.lane_id, resolution.get("hit_height_band", null), Array(resolution.get("trigger_instances", [])), null, metadata, emit_spawn)
	return entity


func _execute_damage_effect(target: Node, params: Dictionary) -> void:
	var context = RuleContextRef.new()
	context.owner_entity = target
	context.source_node = target
	context.target_node = target
	context.position = target.global_position if target is Node2D else Vector2.ZERO
	context.event_name = &"original_zombie.probe"
	context.runtime = {"chain_id": "original_zombie_probe", "depth": 1}
	EffectExecutorRef.execute_node(EffectNodeRef.new(&"damage", params), context)


func _execute_spawn_effect(owner: Node, params: Dictionary) -> void:
	var context = RuleContextRef.new()
	context.owner_entity = owner
	context.source_node = owner
	context.position = owner.global_position if owner is Node2D else Vector2.ZERO
	context.event_name = &"original_zombie.probe"
	context.runtime = {"chain_id": "original_zombie_probe", "depth": 1}
	EffectExecutorRef.execute_node(EffectNodeRef.new(&"spawn_entity", params), context)


func _layer_snapshot(entity: Node, layer_id: StringName) -> Dictionary:
	var health_component: Variant = entity.get_node_or_null("HealthComponent")
	if health_component == null or not health_component.has_method("get_health_layers_snapshot"):
		return {}
	for layer in Array(health_component.call("get_health_layers_snapshot")):
		if layer is Dictionary and StringName(Dictionary(layer).get("layer_id", StringName())) == layer_id:
			return Dictionary(layer)
	return {}


func _entity_health(entity: Node) -> int:
	var health_component: Variant = entity.get_node_or_null("HealthComponent")
	if health_component == null:
		return -1
	return int(health_component.current_health)


func _count_archetype(archetype_id: StringName) -> int:
	if _battle == null or not _battle.has_method("get_runtime_combat_entities"):
		return 0
	var count := 0
	for entity in Array(_battle.call("get_runtime_combat_entities")):
		if entity != null and is_instance_valid(entity) and entity.get("archetype_id") == archetype_id:
			count += 1
	return count


func _has_required_tags(resource: Resource, required_tags: PackedStringArray) -> bool:
	var tags := PackedStringArray(resource.get("tags"))
	for tag in required_tags:
		if not tags.has(tag):
			return false
	return true


func _spawn_position_for(slug: StringName) -> Vector2:
	match slug:
		&"dancing":
			return Vector2(520.0, 320.0)
		_:
			return Vector2(520.0, 220.0)


func _emit_probe(probe: StringName, result: StringName, extra_core: Dictionary = {}) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["original_zombie", "validation"]))
	event_data.core["probe"] = probe
	event_data.core["result"] = result
	for key: Variant in extra_core.keys():
		event_data.core[key] = extra_core[key]
	EventBus.push_event(&"original_zombie.validation_probe", event_data)
