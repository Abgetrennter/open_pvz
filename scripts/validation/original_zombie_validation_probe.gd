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
	elif probe_id == &"zombie_original_bungee_umbrella":
		if not _validate_bungee_umbrella_interception():
			push_error("original zombie probe failed: bungee umbrella interception")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_ladder_grid":
		if not _validate_ladder_grid_behavior():
			push_error("original zombie probe failed: ladder grid behavior")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
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
			push_error("original zombie probe failed at slug: %s (%s)" % [String(slug), String(probe_id)])
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
		&"pole_vaulter":
			return _assert_movement_source(entity, &"core.leap_once") and _assert_vault_block_params(runtime_spec)
		&"dolphin_rider":
			return _assert_movement_source(entity, &"core.leap_once") and _assert_dolphin_post_landing_speed(runtime_spec) and _assert_vault_block_params(runtime_spec)
		&"ducky_tube":
			return _has_required_tags(archetype, PackedStringArray(["spawn.medium.water"]))
		&"snorkel":
			return StringName(entity.call("get_exposure_state")) == &"submerged" and _assert_hidden_exposure_filter(entity, &"submerged")
		&"zomboni":
			return _assert_movement_source(entity, &"core.drive") and _assert_controller(entity, &"core.crush") and _assert_zomboni_decel_params(runtime_spec)
		&"balloon":
			return _assert_layer(entity, &"balloon", &"attachment", 20) and StringName(entity.call("get_exposure_state")) == &"flying" and _assert_balloon_grounding(entity)
		&"jack_in_the_box":
			return _assert_trigger_payload(runtime_spec, &"periodically", &"explode") and _assert_jack_explode_radius(runtime_spec)
		&"digger":
			return _assert_movement_source(entity, &"core.tunnel") and StringName(entity.call("get_exposure_state")) == &"underground" and _assert_digger_surface_direction(runtime_spec)
		&"pogo":
			return _assert_movement_source(entity, &"core.hop_cycle")
		&"yeti":
			return _assert_yeti_flee(entity)
		&"bungee":
			return StringName(entity.call("get_exposure_state")) == &"flying" and _assert_trigger_payload(runtime_spec, &"on_spawned", &"damage") and _assert_bungee_attack_tags(runtime_spec)
		&"ladder":
			return _assert_layer(entity, &"ladder", &"attachment", 500)
		&"catapult":
			return _assert_trigger_payload(runtime_spec, &"periodically", &"spawn_projectile") and _assert_catapult_hold_and_ammo(runtime_spec)
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
	# Original Yeti flees on a timer (de-pvz UpdateYeti: phase counter), not on
	# damage. Step simulation time past the flee threshold without damaging the
	# entity, then assert the flee movement side effect.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 1510)
	var state_ref: Variant = entity.call("get_entity_state_ref")
	if StringName(state_ref.call("get_value", &"state_stage", StringName())) != &"fleeing":
		return false
	var movement_spec: Variant = state_ref.call("get_value", &"movement_spec", {})
	if not (movement_spec is Dictionary):
		return false
	var params: Dictionary = Dictionary(movement_spec).get("params", {})
	return Vector2(params.get("direction", Vector2.ZERO)).x > 0.0 \
		and absf(float(params.get("move_speed_slots_per_sec", 0.0)) - 0.8) < 0.001


func _assert_digger_surface_direction(runtime_spec) -> bool:
	for state_spec in Array(runtime_spec.get("state_specs")):
		if state_spec == null:
			continue
		for transition in Array(state_spec.get("transitions", [])):
			if StringName(transition.get("to_state", StringName())) != &"surfaced":
				continue
			for side_effect in Array(transition.get("side_effects", [])):
				if StringName(Dictionary(side_effect).get("type", StringName())) != &"set_movement":
					continue
				var spec: Variant = Dictionary(side_effect).get("spec", {})
				if not (spec is Dictionary):
						return false
				var params: Dictionary = Dictionary(spec).get("params", {})
				# Original digger surfaces and walks back to the right (de-pvz
				# IsWalkingBackwards: PHASE_DIGGER_WALKING returns true).
				return Vector2(params.get("direction", Vector2.ZERO)).x > 0.0
	return false


func _assert_dolphin_post_landing_speed(runtime_spec) -> bool:
	var movement_spec: Variant = runtime_spec.get("movement_spec")
	if not (movement_spec is Dictionary):
		return false
	var post_landing: Variant = Dictionary(movement_spec).get("params", {}).get("post_landing_movement", null)
	if not (post_landing is Dictionary):
		return false
	var params: Dictionary = Dictionary(post_landing).get("params", {})
	# Original dolphin rider walks fast after landing (de-pvz PickRandomSpeed
	# PHASE_DOLPHIN_WALKING: 0.89-0.91), pool riding is the slow phase.
	return absf(float(params.get("move_speed_slots_per_sec", 0.0)) - 0.9) < 0.001


func _assert_jack_explode_radius(runtime_spec) -> bool:
	for trigger_spec in Array(runtime_spec.get("trigger_specs")):
		if trigger_spec == null:
			continue
		var effect_root: Variant = trigger_spec.get("effect_root")
		if effect_root == null or StringName(effect_root.get("effect_id")) != &"explode":
			continue
		var params: Dictionary = Dictionary(effect_root.get("params"))
		# Original jack explosion radius (de-pvz Zombie.h: zombie radius 115px,
		# plant radius 90px; single-radius model tracks the plant-facing radius).
		return absf(float(params.get("radius_slots", 0.0)) - 0.94) < 0.001
	return false


func _assert_vault_block_params(runtime_spec) -> bool:
	var movement_spec: Variant = runtime_spec.get("movement_spec")
	if not (movement_spec is Dictionary):
		return false
	var params: Dictionary = Dictionary(movement_spec).get("params", {})
	# Original vaulters are blocked by Tall-nut (de-pvz PHASE_POLEVAULTER_IN_VAULT
	# bonk etc.); blocking is tag-driven via vault_block_tags.
	return PackedStringArray(params.get("vault_block_tags", PackedStringArray())).has("vault_blocker")


func _assert_zomboni_decel_params(runtime_spec) -> bool:
	var movement_spec: Variant = runtime_spec.get("movement_spec")
	if not (movement_spec is Dictionary):
		return false
	var params: Dictionary = Dictionary(movement_spec).get("params", {})
	# Original Zamboni decelerates 0.25 -> 0.05 while approaching (de-pvz
	# UpdateZamboni mPosX>400 linear curve).
	return absf(float(params.get("decel_start_x", -1.0)) - 400.0) < 0.001 \
		and absf(float(params.get("decel_min_slots_per_sec", -1.0)) - 0.05) < 0.001


func _assert_bungee_attack_tags(runtime_spec) -> bool:
	for trigger_spec in Array(runtime_spec.get("trigger_specs")):
		if trigger_spec == null:
			continue
		var effect_root: Variant = trigger_spec.get("effect_root")
		if effect_root == null or StringName(effect_root.get("effect_id")) != &"damage":
			continue
		var params: Dictionary = Dictionary(effect_root.get("params"))
		var attack_tags := PackedStringArray(params.get("attack_tags", PackedStringArray()))
		# Original Bungee drop is interceptable by Umbrella Leaf (de-pvz
		# BungeeLanding FindUmbrellaPlant); declared via overhead attack tags.
		return attack_tags.has("overhead") and attack_tags.has("bungee")
	return false


func _assert_catapult_hold_and_ammo(runtime_spec) -> bool:
	var movement_spec: Variant = runtime_spec.get("movement_spec")
	if not (movement_spec is Dictionary):
		return false
	var hold_ok := absf(float(Dictionary(movement_spec).get("params", {}).get("stop_x", -1.0)) - 650.0) < 0.001
	var ammo_ok := false
	for trigger_spec in Array(runtime_spec.get("trigger_specs")):
		if trigger_spec == null:
			continue
		if StringName(trigger_spec.get("trigger_id")) != &"periodically":
			continue
		# Original catapult carries 20 basketballs and stops at the firing
		# line (de-pvz mSummonCounter = 20, mPosX <= 650).
		var conditions: Dictionary = Dictionary(trigger_spec.get("condition_values"))
		ammo_ok = int(conditions.get("max_trigger_count", 0)) == 20
	return hold_ok and ammo_ok


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


func _validate_bungee_umbrella_interception() -> bool:
	# The bungee drop damage fires from the entity.spawned event chain, before
	# the spatial index has rebuilt for same-frame spawns. Step a few ticks
	# after scenario setup so the protectors are indexed, then execute the
	# drop damage effect directly against both covered and uncovered plants.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var covered := _find_entity_by_archetype(&"archetype_original_wallnut", 0)
	var uncovered := _find_entity_by_archetype(&"archetype_original_wallnut", 1)
	var umbrella := _find_entity_by_archetype(&"archetype_original_umbrellaleaf", 0)
	if covered == null or uncovered == null or umbrella == null:
		return false
	var covered_before := _entity_health(covered)
	var uncovered_before := _entity_health(uncovered)
	var intercepted_box := {"hit": false}
	var listener := func(event_data):
		if StringName(event_data.core.get("via", StringName())) == &"effect_damage":
			intercepted_box["hit"] = true
	EventBus.subscribe(&"attack.intercepted", listener)
	_execute_damage_effect(covered, {
		"amount": 9999,
		"attack_tags": PackedStringArray(["overhead", "bungee"]),
		"target_mode": &"context_target",
	})
	_execute_damage_effect(uncovered, {
		"amount": 9999,
		"attack_tags": PackedStringArray(["overhead", "bungee"]),
		"target_mode": &"context_target",
	})
	EventBus.unsubscribe(&"attack.intercepted", listener)
	var intercepted := bool(intercepted_box["hit"])
	if not intercepted:
		push_error("bungee probe: no interception event")
	elif _entity_health(covered) != covered_before:
		push_error("bungee probe: covered damaged")
	elif _entity_health(uncovered) != 0:
		push_error("bungee probe: uncovered health=%d" % _entity_health(uncovered))
	return intercepted \
		and _entity_health(covered) == covered_before \
		and _entity_health(uncovered) == 0


func _validate_ladder_grid_behavior() -> bool:
	# Behavior-level ladder pass (de-pvz UpdateLadder/UpdateClimbingLadder):
	# wall-nuts are pre-planted via scenario spawns; the probe steps a few
	# ticks so the plants are indexed, then drops a Ladder zombie and a basic
	# walker in front of them. The Ladder zombie must place a ladder grid item
	# on the covered slot, climb over without chewing, and pass the wall; the
	# uncovered walker must chew its wall-nut normally.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var covered_wall := _find_entity_by_archetype(&"archetype_original_wallnut", 0)
	var uncovered_wall := _find_entity_by_archetype(&"archetype_original_wallnut", 1)
	if covered_wall == null or uncovered_wall == null:
		return false
	var covered_before := _entity_health(covered_wall)
	var uncovered_before := _entity_health(uncovered_wall)
	var ladder_zombie := _spawn_archetype(&"archetype_original_ladder", Vector2(320.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	var walker_zombie := _spawn_archetype(&"archetype_original_basic_zombie", Vector2(320.0, 320.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if ladder_zombie == null or walker_zombie == null:
		return false
	# ~4.0s: ladder place (within 0.6s of approach), climb (1.1s), fall
	# (0.6s), resume walking; walker covers 64px to its wall and chews.
	_battle.call("step_simulation_ticks", 400)
	var grid_item_state: Variant = (_battle.call("get_grid_item_state") if _battle.has_method("get_grid_item_state") else null)
	if grid_item_state == null or not grid_item_state.has_method("get_grid_item_at"):
		return false
	var metrics: Variant = (_battle.call("get_battlefield_metrics") if _battle.has_method("get_battlefield_metrics") else null)
	if metrics == null or not metrics.has_method("world_to_slot_index"):
		return false
	var covered_slot := int(metrics.call("world_to_slot_index", (covered_wall as Node2D).position.x))
	var ladder_item: Node = grid_item_state.call("get_grid_item_at", 0, covered_slot)
	if ladder_item == null or not is_instance_valid(ladder_item):
		push_error("ladder probe: no ladder grid item on covered slot")
		return false
	var ladder_tags: Variant = ladder_item.get("tags")
	if not PackedStringArray(ladder_tags).has("ladder_grid_item"):
		push_error("ladder probe: grid item on covered slot is not a ladder")
		return false
	var uncovered_slot := int(metrics.call("world_to_slot_index", (uncovered_wall as Node2D).position.x))
	if grid_item_state.call("get_grid_item_at", 1, uncovered_slot) != null:
		push_error("ladder probe: uncovered slot unexpectedly occupied")
		return false
	if not is_instance_valid(ladder_zombie) or (ladder_zombie as Node2D).position.x > (covered_wall as Node2D).position.x - 40.0:
		push_error("ladder probe: ladder zombie did not pass the covered wall (x=%.1f)" % (ladder_zombie.position.x if is_instance_valid(ladder_zombie) else -1.0))
		return false
	if _entity_health(covered_wall) != covered_before:
		push_error("ladder probe: covered wall-nut was chewed")
		return false
	if _entity_health(uncovered_wall) >= uncovered_before:
		push_error("ladder probe: uncovered wall-nut was not chewed")
		return false
	# Fire clears lane ladders (Plant.cpp:4286): execute the jalapeno lane
	# explode against lane 0 and verify the ladder grid item is removed.
	var removed_box := {"hit": false}
	var grid_listener := func(event_data):
		if StringName(event_data.core.get("reason", StringName())) == &"explode_cleared":
			removed_box["hit"] = true
	EventBus.subscribe(&"grid_item.removed", grid_listener)
	var explode_context = RuleContextRef.new()
	explode_context.owner_entity = covered_wall
	explode_context.source_node = covered_wall
	explode_context.target_node = covered_wall
	explode_context.position = (covered_wall as Node2D).global_position
	explode_context.event_name = &"original_zombie.probe"
	explode_context.runtime = {"chain_id": "original_zombie_probe", "depth": 1}
	explode_context.core["lane_id"] = 0
	EffectExecutorRef.execute_node(EffectNodeRef.new(&"explode", {
		"amount": 1,
		"remove_grid_item_tags": PackedStringArray(["ladder_grid_item"]),
		"target_mode": &"context_target",
	}), explode_context)
	EventBus.unsubscribe(&"grid_item.removed", grid_listener)
	if not bool(removed_box["hit"]):
		push_error("ladder probe: explode effect missing or ladder not cleared")
		return false
	return true


func _find_entity_by_archetype(archetype_id: StringName, lane_id: int) -> Node:
	if _battle == null or not _battle.has_method("get_runtime_combat_entities"):
		return null
	for entity in Array(_battle.call("get_runtime_combat_entities")):
		if entity != null and is_instance_valid(entity) \
				and entity.get("archetype_id") == archetype_id \
				and int(entity.get("lane_id")) == lane_id:
			return entity
	return null


func _emit_probe(probe: StringName, result: StringName, extra_core: Dictionary = {}) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["original_zombie", "validation"]))
	event_data.core["probe"] = probe
	event_data.core["result"] = result
	for key: Variant in extra_core.keys():
		event_data.core[key] = extra_core[key]
	EventBus.push_event(&"original_zombie.validation_probe", event_data)
