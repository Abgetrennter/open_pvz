extends Node
class_name OriginalZombieValidationProbe

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const BattleSpawnEntryRef = preload("res://scripts/battle/battle_spawn_entry.gd")
const WaveComposerRef = preload("res://scripts/battle/wave_composer.gd")
const WaveRecipeDefRef = preload("res://scripts/battle/wave_recipe_def.gd")
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
	elif probe_id == &"zombie_original_catapult_leftmost":
		if not _validate_catapult_leftmost():
			push_error("original zombie probe failed: catapult leftmost targeting")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_catapult_exhaustion":
		if not _validate_catapult_exhaustion():
			push_error("original zombie probe failed: catapult ammo exhaustion")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_dancer_resummon":
		if not _validate_dancer_resummon():
			push_error("original zombie probe failed: dancer resummon")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_gargantuar_spikerock":
		if not _validate_gargantuar_spikerock():
			push_error("original zombie probe failed: gargantuar spikerock interaction")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_yeti_gift":
		if not _validate_yeti_gift():
			push_error("original zombie probe failed: yeti gift drop")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_speed_range":
		if not _validate_speed_range():
			push_error("original zombie probe failed: speed range sampling")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_vault_formula":
		if not _validate_vault_formula():
			push_error("original zombie probe failed: pole vaulter landing formula")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_jack_distance_fuse":
		if not _validate_jack_distance_fuse():
			push_error("original zombie probe failed: jack distance fuse")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_ice_trail":
		if not _validate_ice_trail():
			push_error("original zombie probe failed: ice trail field modifiers")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_bobsled_team":
		if not _validate_bobsled_team():
			push_error("original zombie probe failed: bobsled team")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_wave_pool":
		if not _validate_wave_pool():
			push_error("original zombie probe failed: original wave pool")
			return
		_emit_probe(probe_id, &"passed", {})
		_emitted[probe_id] = true
	elif probe_id == &"zombie_original_screen_door_directional":
		if not _validate_screen_door_directional():
			push_error("original zombie probe failed: screen door directional shield")
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
			return _assert_movement_source(entity, &"core.leap_once") and _assert_vault_block_params(runtime_spec) and _assert_vault_formula_params(runtime_spec)
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
			return _assert_trigger_payload(runtime_spec, &"periodically", &"explode") and _assert_jack_explode_radius(runtime_spec) and _assert_jack_fuse_params(runtime_spec)
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
	var params: Dictionary = Dictionary(movement_spec).get("params", {})
	# Original newspaper rage speed (de-pvz PickRandomSpeed
	# PHASE_NEWSPAPER_MAD: 0.89-0.91 range).
	return absf(float(params.get("move_speed_slots_per_sec_min", -1.0)) - 0.89) < 0.001 \
		and absf(float(params.get("move_speed_slots_per_sec_max", -1.0)) - 0.91) < 0.001


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
	return absf(float(params.get("move_speed_slots_per_sec_min", -1.0)) - 0.89) < 0.001 \
		and absf(float(params.get("move_speed_slots_per_sec_max", -1.0)) - 0.91) < 0.001


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


func _assert_dancing_spawn(_entity: Node) -> bool:
	# Backup dancers are summoned by per-slot vacancy triggers (de-pvz
	# SummonBackupDancers slot loop, start_delay 1.0s), not an on_spawned
	# burst. Drive the already-spawned leader past its first maintenance tick;
	# a second leader here would cross-occupy the first leader's slots.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	var base_count := _count_archetype(&"archetype_original_backup_dancer")
	_battle.call("step_simulation_ticks", 150)
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


func _validate_catapult_leftmost() -> bool:
	# Z-29 (de-pvz FindCatapultTarget :1493-1510): the catapult targets the
	# leftmost plant of its lane, skips spiky plants entirely, and never
	# targets plants closer than 100px. Lane 0 carries sunflower (x=160,
	# leftmost) + peashooter (x=400); lane 1 carries only a spikeweed.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var sunflower := _find_entity_by_archetype(&"archetype_original_sunflower", 0)
	var peashooter := _find_entity_by_archetype(&"archetype_original_peashooter", 0)
	var spikeweed := _find_entity_by_archetype(&"archetype_original_spikeweed", 1)
	if sunflower == null or peashooter == null or spikeweed == null:
		push_error("leftmost probe: scenario plants missing")
		return false
	var sunflower_before := _entity_health(sunflower)
	var peashooter_before := _entity_health(peashooter)
	var spikeweed_before := _entity_health(spikeweed)
	var catapult_lane0 := _spawn_archetype(&"archetype_original_catapult", Vector2(660.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	var catapult_lane1 := _spawn_archetype(&"archetype_original_catapult", Vector2(660.0, 320.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if catapult_lane0 == null or catapult_lane1 == null:
		push_error("leftmost probe: catapult spawn failed")
		return false
	# ~5.8s: stop at the 650 firing line, first shot (~0.4s) + parabola flight
	# lands on the leftmost plant; second shot stays inside the window.
	_battle.call("step_simulation_ticks", 350)
	var sunflower_hit := _entity_health(sunflower) < sunflower_before
	var peashooter_untouched := _entity_health(peashooter) == peashooter_before
	var spikeweed_untouched := _entity_health(spikeweed) == spikeweed_before
	if not sunflower_hit:
		push_error("leftmost probe: leftmost plant never hit")
	elif not peashooter_untouched:
		push_error("leftmost probe: nearer plant hit before the leftmost one")
	elif not spikeweed_untouched:
		push_error("leftmost probe: spiky plant targeted")
	return sunflower_hit and peashooter_untouched and spikeweed_untouched


func _validate_catapult_exhaustion() -> bool:
	# Z-28 tail (de-pvz UpdateZombieCatapult :1552-1556): when the 20th ball is
	# launched the catapult drops to PHASE_ZOMBIE_NORMAL - it leaves the firing
	# line and bites. Force the ammo counter to 19 with an expired cooldown so
	# the next tick fires the last shot and emits trigger.exhausted.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var wallnut := _find_entity_by_archetype(&"archetype_original_wallnut", 0)
	if wallnut == null:
		push_error("exhaustion probe: scenario wall-nut missing")
		return false
	var wallnut_before := _entity_health(wallnut)
	var catapult := _spawn_archetype(&"archetype_original_catapult", Vector2(660.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if catapult == null:
		push_error("exhaustion probe: catapult spawn failed")
		return false
	_battle.call("step_simulation_ticks", 10)
	var trigger_component: Variant = catapult.get_node_or_null("TriggerComponent")
	if trigger_component == null:
		push_error("exhaustion probe: no trigger component")
		return false
	var shot_instance = null
	for instance in Array(trigger_component.get("trigger_instances")):
		if int(Dictionary(instance.condition_values).get("max_trigger_count", 0)) == 20:
			shot_instance = instance
			break
	if shot_instance == null:
		push_error("exhaustion probe: shot trigger instance missing")
		return false
	shot_instance.fired_count = 19
	shot_instance.last_triggered_time = GameState.current_time - 3.0
	# ~3.3s: the forced 20th shot fires, the exhaustion transition swaps the
	# movement off the firing line, and the catapult walks into bite range.
	_battle.call("step_simulation_ticks", 200)
	var state_ref: Variant = catapult.call("get_entity_state_ref")
	if StringName(state_ref.call("get_value", &"state_stage", StringName())) != &"spent":
		push_error("exhaustion probe: state is not spent")
		return false
	var movement_spec: Variant = state_ref.call("get_value", &"movement_spec", {})
	if not (movement_spec is Dictionary) or Dictionary(movement_spec).get("params", {}).has("stop_x"):
		push_error("exhaustion probe: movement still holds the firing line")
		return false
	if _entity_health(wallnut) >= wallnut_before:
		push_error("exhaustion probe: wall-nut never damaged")
		return false
	return true


func _validate_dancer_resummon() -> bool:
	# Z-32 (de-pvz SummonBackupDancers :2812-2834 + :3005-3008): the initial
	# summon fills the four follower slots, and a killed follower is re-summoned
	# into the SAME slot on the next 100-tick maintenance pass.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var base_count := _count_archetype(&"archetype_original_backup_dancer")
	var dancer := _spawn_archetype(&"archetype_original_dancing", Vector2(520.0, 320.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if dancer == null:
		push_error("resummon probe: dancer spawn failed")
		return false
	_battle.call("step_simulation_ticks", 150)
	var after_initial := _count_archetype(&"archetype_original_backup_dancer")
	if after_initial - base_count != 4:
		push_error("resummon probe: initial summon count=%d" % (after_initial - base_count))
		return false
	var lane0_follower := _find_entity_by_archetype(&"archetype_original_backup_dancer", 0)
	if lane0_follower == null:
		push_error("resummon probe: lane-0 follower missing")
		return false
	lane0_follower.call("take_damage", 99999, null, PackedStringArray(["probe"]))
	_battle.call("step_simulation_ticks", 400)
	if _count_archetype(&"archetype_original_backup_dancer") != after_initial:
		push_error("resummon probe: follower not re-summoned")
		return false
	if _find_entity_by_archetype(&"archetype_original_backup_dancer", 0) == null:
		push_error("resummon probe: lane-0 slot stayed vacant")
		return false
	return true


func _validate_gargantuar_spikerock() -> bool:
	# Z-31 (de-pvz Zombie.cpp :2049-2056 + Plant.cpp DoRowAreaDamage/SpikeRock):
	# the Gargantuar smash on Spikerock deals 50hp per smash (450hp = 9
	# smashes) and retaliates 20 damage per smash; the Zamboni drive-over never
	# squishes spiky plants, the spikes destroy it (1800) and the Spikeweed
	# dies with it.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var spikerock := _find_entity_by_archetype(&"archetype_original_spikerock", 0)
	var spikeweed := _find_entity_by_archetype(&"archetype_original_spikeweed", 1)
	if spikerock == null or spikeweed == null:
		push_error("spikerock probe: scenario plants missing")
		return false
	var gargantuar := _spawn_archetype(&"archetype_original_gargantuar", Vector2(620.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	var zamboni := _spawn_archetype(&"archetype_original_zomboni", Vector2(680.0, 320.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if gargantuar == null or zamboni == null:
		push_error("spikerock probe: zombie spawn failed")
		return false
	var smash_hits := {"soft": 0, "self": 0, "vehicle": 0, "spike_tick": 0}
	var listener := func(event_data):
		var tags := PackedStringArray(event_data.core.get("tags", PackedStringArray()))
		var target: Variant = event_data.core.get("target_node", null)
		if target == gargantuar and tags.has("self_damage"):
			smash_hits["self"] += 1
		elif target == gargantuar and tags.has("ground_damage"):
			smash_hits["spike_tick"] += 1
		elif target == spikerock and tags.has("soft_target"):
			smash_hits["soft"] += 1
		elif target == zamboni and tags.has("vehicle"):
			smash_hits["vehicle"] += 1
	EventBus.subscribe(&"entity.damaged", listener)
	# Ticks run at 100/s: 12s covers the 9 one-second smash cycles plus the
	# zamboni drive-over, with margin past the spikerock death fade.
	_battle.call("step_simulation_ticks", 1200)
	EventBus.unsubscribe(&"entity.damaged", listener)
	var soft := int(smash_hits["soft"])
	var self_hits := int(smash_hits["self"])
	var vehicle_hits := int(smash_hits["vehicle"])
	if soft < 9:
		push_error("spikerock probe: soft smashes=%d (<9)" % soft)
		return false
	if self_hits != soft:
		push_error("spikerock probe: self retaliations=%d != soft smashes=%d" % [self_hits, soft])
		return false
	if is_instance_valid(spikerock) and _entity_health(spikerock) > 0:
		push_error("spikerock probe: spikerock survived %d smashes" % soft)
		return false
	if not is_instance_valid(gargantuar) or _entity_health(gargantuar) <= 0:
		push_error("spikerock probe: gargantuar died from retaliation")
		return false
	# The Gargantuar loses exactly the smash retaliation (20 per smash) plus
	# the spikerock's own ground spikes while standing on it (20 per tick).
	var expected_health := 3000 - 20 * soft - 20 * int(smash_hits["spike_tick"])
	if _entity_health(gargantuar) != expected_health:
		push_error("spikerock probe: gargantuar health=%d (expected %d)" % [_entity_health(gargantuar), expected_health])
		return false
	if vehicle_hits < 1 or (is_instance_valid(zamboni) and _entity_health(zamboni) > 0):
		push_error("spikerock probe: zamboni not destroyed by spikes (hits=%d)" % vehicle_hits)
		return false
	if is_instance_valid(spikeweed) and _entity_health(spikeweed) > 0:
		push_error("spikerock probe: spikeweed survived the zamboni")
		return false
	return true


func _validate_yeti_gift() -> bool:
	# Z-05 (de-pvz DropLoot :7236-7242): a killed Yeti drops 4 diamonds
	# spread out to the left of its center.
	if _battle == null or not _battle.has_method("get_economy_state"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var yeti := _spawn_archetype(&"archetype_original_yeti", Vector2(520.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if yeti == null:
		push_error("yeti gift probe: yeti spawn failed")
		return false
	yeti.call("take_damage", 99999, null, PackedStringArray(["probe"]))
	var economy: Variant = _battle.call("get_economy_state")
	if economy == null or not (economy.get("active_suns") is Dictionary):
		push_error("yeti gift probe: economy state unavailable")
		return false
	var gift_positions: Array = []
	for collectible in Dictionary(economy.get("active_suns")).values():
		if collectible == null or not is_instance_valid(collectible):
			continue
		if StringName(collectible.get("source_type")) == &"yeti_diamond":
			gift_positions.append(float((collectible as Node2D).position.x))
	if gift_positions.size() != 4:
		push_error("yeti gift probe: dropped %d gifts (expected 4)" % gift_positions.size())
		return false
	var unique_x: Dictionary = {}
	for x_value in gift_positions:
		unique_x[x_value] = true
	if unique_x.size() != 4:
		push_error("yeti gift probe: gifts stacked on one spot")
		return false
	return true


func _validate_speed_range() -> bool:
	# Z-01 (de-pvz PickRandomSpeed :1096-1155): basic zombies spawn with a
	# speed sampled per-entity from 0.23-0.32 slots/s; the roll must vary
	# across entities of the same archetype. The production path caches the
	# roll on the entity (GameState.resolve_ranged_value), so read it back.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var walkers: Array = []
	for i in range(12):
		var lane_y := 220.0 if i % 2 == 0 else 320.0
		var walker := _spawn_archetype(&"archetype_original_basic_zombie", Vector2(700.0 - 8.0 * i, lane_y), {"spawn_reason": &"original_zombie_probe"}, true)
		if walker == null:
			push_error("speed range probe: spawn %d failed" % i)
			return false
		walkers.append(walker)
	_battle.call("step_simulation_ticks", 30)
	var speeds: Array = []
	for walker in walkers:
		if not is_instance_valid(walker):
			push_error("speed range probe: walker despawned")
			return false
		var roll: Variant = null
		for meta_name in walker.get_meta_list():
			if String(meta_name).begins_with("range_roll__move_speed_slots_per_sec__"):
				roll = walker.get_meta(meta_name)
				break
		if roll == null:
			push_error("speed range probe: walker has no cached speed roll")
			return false
		speeds.append(float(roll))
	var min_allowed := 0.23 - 0.0001
	var max_allowed := 0.32 + 0.0001
	var distinct: Dictionary = {}
	for speed_value in speeds:
		var speed := float(speed_value)
		if speed < min_allowed or speed > max_allowed:
			push_error("speed range probe: sampled speed %.4f outside [0.23, 0.32]" % speed)
			return false
		distinct[String.num(speed, 4)] = true
	if distinct.size() < 2:
		push_error("speed range probe: all 12 walkers rolled the same speed")
		return false
	return true


func _assert_vault_formula_params(runtime_spec) -> bool:
	var movement_spec: Variant = runtime_spec.get("movement_spec")
	if not (movement_spec is Dictionary):
		return false
	var params: Dictionary = Dictionary(movement_spec).get("params", {})
	# Original vault landing (de-pvz Zombie.cpp:1671-1686 + :1711-1715): the
	# arc aims at plantX+80 and the landing shifts -150, netting a landing
	# fixed 70px past the vaulted plant; the approach run targets plants.
	return PackedStringArray(params.get("vault_trigger_tags", PackedStringArray())).has("plant") \
		and absf(float(params.get("vault_landing_beyond_px", -1.0)) - 70.0) < 0.001


func _assert_jack_fuse_params(runtime_spec) -> bool:
	for trigger_spec in Array(runtime_spec.get("trigger_specs")):
		if trigger_spec == null or StringName(trigger_spec.get("trigger_id")) != &"periodically":
			continue
		var conditions: Dictionary = Dictionary(trigger_spec.get("condition_values"))
		# Original walking fuse (de-pvz Zombie.cpp:429-434): 450+Rand(300)px
		# converted to a time fuse over the sampled walk speed, 1/20 early pop
		# at one third the distance, exploding exactly once.
		return absf(float(conditions.get("fuse_distance_min", -1.0)) - 450.0) < 0.001 \
			and absf(float(conditions.get("fuse_distance_max", -1.0)) - 750.0) < 0.001 \
			and int(conditions.get("max_trigger_count", 0)) == 1
	return false


func _validate_vault_formula() -> bool:
	# Z-18 (de-pvz UpdateZombiePolevaulter :1666-1686 + :1711-1715): the vaulter
	# runs fast until the first living plant enters range, then leaps with a
	# horizontal speed that lands the arc a fixed 70px past that plant. The
	# landing must clear the wall-nut without a single bite.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var wallnut := _find_entity_by_archetype(&"archetype_original_wallnut", 0)
	if wallnut == null:
		push_error("vault formula probe: scenario wall-nut missing")
		return false
	var wallnut_x := (wallnut as Node2D).position.x
	var wallnut_before := _entity_health(wallnut)
	var vaulter := _spawn_archetype(&"archetype_original_pole_vaulter", Vector2(620.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if vaulter == null:
		push_error("vault formula probe: vaulter spawn failed")
		return false
	_battle.call("step_simulation_ticks", 20)
	var run_start_x := (vaulter as Node2D).position.x
	_battle.call("step_simulation_ticks", 30)
	var run_speed := (run_start_x - (vaulter as Node2D).position.x) / 0.3
	# Pre-vault approach run (de-pvz PHASE_POLEVAULTER_PRE_VAULT: 0.66-0.68).
	if run_speed < 0.65 * 96.0 or run_speed > 0.69 * 96.0:
		push_error("vault formula probe: approach run speed %.1f px/s outside 0.66-0.68 slots/s" % run_speed)
		return false
	var landing_box := {"x": -1.0}
	var landed_listener := func(event_data):
		if event_data.core.get("target_node", null) == vaulter and landing_box["x"] < 0.0:
			landing_box["x"] = float((vaulter as Node2D).position.x)
	EventBus.subscribe(&"entity.landed", landed_listener)
	for i in range(40):
		if float(landing_box["x"]) >= 0.0:
			break
		_battle.call("step_simulation_ticks", 10)
	EventBus.unsubscribe(&"entity.landed", landed_listener)
	var landed_x := float(landing_box["x"])
	var expected_landing := wallnut_x - 70.0
	if landed_x < 0.0:
		push_error("vault formula probe: vaulter never landed")
		return false
	if absf(landed_x - expected_landing) > 14.0:
		push_error("vault formula probe: landed at %.1f, expected %.1f (wall %.1f - 70)" % [landed_x, expected_landing, wallnut_x])
		return false
	if _entity_health(wallnut) != wallnut_before:
		push_error("vault formula probe: wall-nut was bitten during the vault")
		return false
	if not is_instance_valid(vaulter):
		push_error("vault formula probe: vaulter despawned")
		return false
	var state_ref: Variant = vaulter.call("get_entity_state_ref")
	var movement_spec: Variant = state_ref.call("get_value", &"movement_spec", {})
	if not (movement_spec is Dictionary):
		push_error("vault formula probe: no post-landing movement spec")
		return false
	var params: Dictionary = Dictionary(movement_spec).get("params", {})
	# Post-vault walking drops to the default range (de-pvz PickRandomSpeed).
	if absf(float(params.get("move_speed_slots_per_sec_min", -1.0)) - 0.23) > 0.001 \
			or absf(float(params.get("move_speed_slots_per_sec_max", -1.0)) - 0.32) > 0.001:
		push_error("vault formula probe: post-landing walk is not the default range")
		return false
	return true


func _validate_jack_distance_fuse() -> bool:
	# Z-21 (de-pvz Zombie.cpp:429-434 + UpdateZombieJackInTheBox :1977-2012):
	# the fuse is a WALKING-DISTANCE draw (450+Rand(300)px, 1/20 early pop at
	# one third) converted to time over the sampled walk speed, so chewing
	# halts movement but never the fuse, and the jack explodes exactly once.
	# The ranged rolls are entity-cached (GameState.resolve_ranged_value), so
	# seeding them before stepping makes the fuse deterministic:
	# distance 600, early pop (roll 0.01 < 0.05) -> 200px, speed 0.67 ->
	# fuse = 200 * 2 / (0.67 * 96) = 6.219s.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var wallnut := _find_entity_by_archetype(&"archetype_original_wallnut", 0)
	if wallnut == null:
		push_error("jack fuse probe: scenario wall-nut missing")
		return false
	var wallnut_before := _entity_health(wallnut)
	var jack := _spawn_archetype(&"archetype_original_jack_in_the_box", Vector2(700.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if jack == null:
		push_error("jack fuse probe: jack spawn failed")
		return false
	jack.set_meta("range_roll__fuse_distance__4500000__7500000", 600.0)
	jack.set_meta("range_roll__early_roll__0__10000", 0.01)
	jack.set_meta("range_roll__move_speed_slots_per_sec__6600__6800", 0.67)
	var bind_time := float(GameState.current_time)
	var fuse_seconds := 600.0 * (1.0 / 3.0) * 2.0 / (0.67 * 96.0)
	var consume_box := {"count": 0, "time": -1.0}
	var consume_listener := func(event_data):
		if event_data.core.get("target_node", null) == jack:
			consume_box["count"] = int(consume_box["count"]) + 1
			consume_box["time"] = float(GameState.current_time)
	EventBus.subscribe(&"entity.consumed", consume_listener)
	_battle.call("step_simulation_ticks", 700)
	EventBus.unsubscribe(&"entity.consumed", consume_listener)
	var consumed_at := float(consume_box["time"])
	if int(consume_box["count"]) != 1:
		push_error("jack fuse probe: consumed %d times (expected 1)" % int(consume_box["count"]))
		return false
	var drift := absf(consumed_at - bind_time - fuse_seconds)
	if drift > 0.35:
		push_error("jack fuse probe: exploded %.3fs after spawn, expected %.3fs" % [consumed_at - bind_time, fuse_seconds])
		return false
	# queue_free defers to the frame end, so liveness cannot be probed here;
	# the exactly-once entity.consumed count carries the die-on-explode check.
	if _entity_health(wallnut) >= wallnut_before:
		push_error("jack fuse probe: wall-nut untouched by chewing or the blast")
		return false
	return true


func _validate_ice_trail() -> bool:
	# Z-11 (de-pvz UpdateZombieZamboni :3908-3938 + Zombie::GetSpeedModifier):
	# the Zamboni leaves a lane interval of ice that halves WALKING speed while
	# vehicles pass untouched, other lanes are unaffected, the interval expires
	# after its tick budget, and grid-item craters (G-29 lifetime channel)
	# expire the same way.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	var field: Variant = _battle.call("get_field_state") if _battle.has_method("get_field_state") else null
	if field == null or not field.has_method("apply_modifier") or not field.has_method("has_modifier"):
		push_error("ice trail probe: field state subsystem missing")
		return false
	_battle.call("step_simulation_ticks", 10)
	# The Zamboni drives left of spawn, laying [x-4, x+4] per step.
	var zamboni := _spawn_archetype(&"archetype_original_zomboni", Vector2(520.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if zamboni == null:
		push_error("ice trail probe: zamboni spawn failed")
		return false
	_battle.call("step_simulation_ticks", 200)
	if not bool(field.call("has_modifier", 0, &"ice_trail", 500.0)):
		push_error("ice trail probe: no ice behind the zamboni")
		return false
	# A walker on the ice walks at half its sampled roll; the lane-1 control
	# walker keeps full speed; the vehicle itself is exempt.
	var zamboni_x_before := (zamboni as Node2D).position.x
	var walker_on_ice := _spawn_archetype(&"archetype_original_basic_zombie", Vector2(500.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	var walker_control := _spawn_archetype(&"archetype_original_basic_zombie", Vector2(500.0, 320.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if walker_on_ice == null or walker_control == null:
		push_error("ice trail probe: walker spawn failed")
		return false
	_battle.call("step_simulation_ticks", 20)
	var ice_x_before := (walker_on_ice as Node2D).position.x
	var control_x_before := (walker_control as Node2D).position.x
	var zamboni_speed := (zamboni_x_before - (zamboni as Node2D).position.x) / 0.2
	_battle.call("step_simulation_ticks", 30)
	var ice_speed := (ice_x_before - (walker_on_ice as Node2D).position.x) / 0.3
	var control_speed := (control_x_before - (walker_control as Node2D).position.x) / 0.3
	var ice_roll: Variant = _read_range_roll(walker_on_ice, "move_speed_slots_per_sec")
	var control_roll: Variant = _read_range_roll(walker_control, "move_speed_slots_per_sec")
	if ice_roll == null or control_roll == null:
		push_error("ice trail probe: walker speed roll missing")
		return false
	if absf(ice_speed - float(ice_roll) * 96.0 * 0.5) > 5.0:
		push_error("ice trail probe: on-ice speed %.1f px/s, expected ~%.1f (half roll)" % [ice_speed, float(ice_roll) * 96.0 * 0.5])
		return false
	if absf(control_speed - float(control_roll) * 96.0) > 5.0:
		push_error("ice trail probe: control speed %.1f px/s, expected ~%.1f" % [control_speed, float(control_roll) * 96.0])
		return false
	if absf(zamboni_speed - 0.25 * 96.0) > 4.0:
		push_error("ice trail probe: zamboni slowed by its own ice (%.1f px/s)" % zamboni_speed)
		return false
	# Expiry: a short-lived lane-2 interval disappears after its tick budget.
	field.call("apply_modifier", 2, &"ice_trail", 100.0, 800.0, 20, -1)
	if not bool(field.call("has_modifier", 2, &"ice_trail", 500.0)):
		push_error("ice trail probe: lane-2 ice missing after apply")
		return false
	_battle.call("step_simulation_ticks", 40)
	if bool(field.call("has_modifier", 2, &"ice_trail", 500.0)):
		push_error("ice trail probe: lane-2 ice did not expire")
		return false
	# Crater lifetime (G-29 channel): a scheduled crater grid item is removed
	# after its tick budget (original mGridItemCounter countdown).
	var grid_item_state: Variant = _battle.call("get_grid_item_state") if _battle.has_method("get_grid_item_state") else null
	if grid_item_state == null or not grid_item_state.has_method("spawn_grid_item_at"):
		push_error("ice trail probe: grid item state missing")
		return false
	var crater: Node = grid_item_state.call("spawn_grid_item_at", &"archetype_crater", 1, 2, {}, true)
	if crater == null:
		push_error("ice trail probe: crater spawn failed")
		return false
	grid_item_state.call("schedule_expiry", crater, 30)
	_battle.call("step_simulation_ticks", 50)
	if grid_item_state.call("get_grid_item_at", 1, 2) != null:
		push_error("ice trail probe: crater did not expire")
		return false
	return true


func _validate_bobsled_team() -> bool:
	# Z-14 (de-pvz Zombie.cpp:450-500 + :2573-2655): the team rides a 300hp
	# sled layer at a constant 0.625 slots/s, renews the ice timer under it,
	# grinds the sled away (6/tick) once it slides past the ice's left edge,
	# and the broken sled disbands into four independent walkers while the
	# team entity consumes itself.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	var field: Variant = _battle.call("get_field_state") if _battle.has_method("get_field_state") else null
	if field == null or not field.has_method("apply_modifier"):
		push_error("bobsled probe: field state subsystem missing")
		return false
	_battle.call("step_simulation_ticks", 10)
	field.call("apply_modifier", 0, &"ice_trail", 300.0, 820.0, 3000, -1)
	var team := _spawn_archetype(&"archetype_original_bobsled_team", Vector2(700.0, 220.0), {"spawn_reason": &"original_zombie_probe"}, true)
	if team == null:
		push_error("bobsled probe: team spawn failed")
		return false
	var sled := _layer_snapshot(team, &"sled")
	if sled.is_empty() or StringName(sled.get("layer_kind", StringName())) != &"attachment" or int(sled.get("max_health", 0)) != 300:
		push_error("bobsled probe: sled layer missing or malformed")
		return false
	if StringName(team.call("get_entity_state_ref").call("get_value", &"movement_spec", {}).get("movement_id", StringName())) != &"core.drive":
		push_error("bobsled probe: team movement is not core.drive")
		return false
	_battle.call("step_simulation_ticks", 20)
	var slide_x_before := (team as Node2D).position.x
	_battle.call("step_simulation_ticks", 30)
	var slide_speed := (slide_x_before - (team as Node2D).position.x) / 0.3
	if absf(slide_speed - 0.625 * 96.0) > 4.0:
		push_error("bobsled probe: slide speed %.1f px/s, expected ~60 (0.625 slots/s)" % slide_speed)
		return false
	var consumed_box := {"count": 0}
	var consumed_listener := func(event_data):
		if event_data.core.get("target_node", null) == team and StringName(event_data.core.get("reason", StringName())) == &"bobsled_crash":
			consumed_box["count"] = int(consumed_box["count"]) + 1
	EventBus.subscribe(&"entity.consumed", consumed_listener)
	# ~6.8s of sliding to the ice edge (700 -> 290) + ~0.5s of grinding.
	var riders_seen := 0
	for i in range(16):
		_battle.call("step_simulation_ticks", 60)
		if int(consumed_box["count"]) > 0:
			riders_seen = _count_archetype(&"archetype_original_bobsled")
			break
	EventBus.unsubscribe(&"entity.consumed", consumed_listener)
	if int(consumed_box["count"]) != 1:
		push_error("bobsled probe: team consumed %d times (expected 1 after sled grind)" % int(consumed_box["count"]))
		return false
	if riders_seen != 4:
		push_error("bobsled probe: %d riders after disband (expected 4)" % riders_seen)
		return false
	var moving_riders := 0
	for rider in Array(_battle.call("get_runtime_combat_entities")):
		if rider == null or not is_instance_valid(rider) or rider.get("archetype_id") != &"archetype_original_bobsled":
			continue
		if float(rider.call("get_entity_state_ref").call("get_value", &"speed", 0.0)) > 10.0:
			moving_riders += 1
	if moving_riders < 4:
		push_error("bobsled probe: only %d/4 riders walking after disband" % moving_riders)
		return false
	return true


func _read_range_roll(entity: Node, key: String) -> Variant:
	for meta_name in entity.get_meta_list():
		if String(meta_name).begins_with("range_roll__%s__" % key):
			return entity.get_meta(meta_name)
	return null


func _validate_screen_door_directional() -> bool:
	# Z-33 (de-pvz Projectile.cpp:382-404 GetDamageFlags): frontal shots are
	# absorbed by the held shield; rear shots (leftward-flying, Split Pea back
	# head / Starfruit) and lobbed arcs (hit.overhead) bypass it straight to
	# the body. The effect-level cases pin the layer routing, the split-pea
	# case pins the projectile-side tagging.
	if _battle == null or not _battle.has_method("step_simulation_ticks"):
		return false
	_battle.call("step_simulation_ticks", 10)
	var door := _find_entity_by_archetype(&"archetype_original_screen_door", 0)
	if door == null:
		push_error("directional probe: scenario screen door zombie missing")
		return false
	var shield_before := int(_layer_snapshot(door, &"screen_door").get("current_health", -1))
	var body_before := _entity_health(door)
	# Frontal (plain projectile tags): shield absorbs, body untouched.
	_execute_damage_effect(door, {"amount": 20, "attack_tags": PackedStringArray(["projectile"]), "target_mode": &"context_target"})
	var shield_after_front := int(_layer_snapshot(door, &"screen_door").get("current_health", -1))
	if shield_after_front != shield_before - 20 or _entity_health(door) != body_before:
		push_error("directional probe: frontal shot did not land on the shield only")
		return false
	# Rear (hit.rear): body takes it, shield untouched.
	_execute_damage_effect(door, {"amount": 20, "attack_tags": PackedStringArray(["projectile", "hit.rear"]), "target_mode": &"context_target"})
	if int(_layer_snapshot(door, &"screen_door").get("current_health", -1)) != shield_after_front or _entity_health(door) != body_before - 20:
		push_error("directional probe: rear shot did not bypass the shield")
		return false
	# Overhead (hit.overhead): lobbed arcs bypass too.
	_execute_damage_effect(door, {"amount": 20, "attack_tags": PackedStringArray(["projectile", "hit.overhead"]), "target_mode": &"context_target"})
	if int(_layer_snapshot(door, &"screen_door").get("current_health", -1)) != shield_after_front or _entity_health(door) != body_before - 40:
		push_error("directional probe: lobbed shot did not bypass the shield")
		return false
	# Projectile path: a Split Pea standing to the zombie's right fires its
	# back head leftward; those peas must chip the BODY while the frontal
	# peashooter to the left chips the SHIELD.
	var body_at_start := _entity_health(door)
	var shield_at_start := int(_layer_snapshot(door, &"screen_door").get("current_health", -1))
	_battle.call("step_simulation_ticks", 420)
	var shield_after := int(_layer_snapshot(door, &"screen_door").get("current_health", -1))
	var body_after := _entity_health(door)
	if shield_after >= shield_at_start:
		push_error("directional probe: frontal peashooter never dented the shield")
		return false
	if body_after >= body_at_start:
		push_error("directional probe: rear split-pea shots never reached the body")
		return false
	return true


func _validate_wave_pool() -> bool:
	# Z-34 (de-pvz gZombieDefs Zombie.cpp:20-53): the original adventure pool
	# maps value->power, startingLevel->first_allowed_wave (the original gate
	# is waveIndex+1 >= startingLevel, i.e. 0-based startingLevel-1) and
	# pickWeight->weight; water types are gated to water lanes and the flag
	# entry stays weight-0 for flag waves only.
	var pool_res: Variant = load("res://data/combat/waves/pool_original_adventure.tres")
	if pool_res == null or not (pool_res is Resource):
		push_error("wave pool probe: pool resource missing")
		return false
	var entries: Array = Array(pool_res.get("entries"))
	if entries.size() != 24:
		push_error("wave pool probe: %d entries (expected 24)" % entries.size())
		return false
	var by_archetype: Dictionary = {}
	for entry in entries:
		var archetype_id := StringName(entry.get("archetype_id"))
		if not SceneRegistry.has_archetype(archetype_id):
			push_error("wave pool probe: unresolvable archetype %s" % String(archetype_id))
			return false
		if int(entry.get("power")) <= 0 or int(entry.get("first_allowed_wave")) < 0 or int(entry.get("weight")) < 0:
			push_error("wave pool probe: negative triple on %s" % String(archetype_id))
			return false
		by_archetype[archetype_id] = entry
	# Spot checks against gZombieDefs rows.
	var spot_checks: Dictionary = {
		&"archetype_original_basic_zombie": [1, 0, 1],
		&"archetype_original_conehead": [2, 2, 1],
		&"archetype_original_pole_vaulter": [2, 5, 5],
		&"archetype_original_screen_door": [4, 12, 5],
		&"archetype_original_zomboni": [7, 25, 10],
		&"archetype_original_bobsled_team": [3, 25, 10],
		&"archetype_original_jack_in_the_box": [3, 30, 10],
		&"archetype_original_gargantuar": [10, 47, 15],
		&"archetype_original_flag_zombie": [1, 0, 0],
	}
	for archetype_id: StringName in spot_checks.keys():
		var entry: Variant = by_archetype.get(archetype_id)
		if entry == null:
			push_error("wave pool probe: spot-check archetype missing %s" % String(archetype_id))
			return false
		var expected: Array = spot_checks[archetype_id]
		if int(entry.get("power")) != expected[0] or int(entry.get("first_allowed_wave")) != expected[1] or int(entry.get("weight")) != expected[2]:
			push_error("wave pool probe: %s triple %d/%d/%d != %d/%d/%d" % [String(archetype_id), int(entry.get("power")), int(entry.get("first_allowed_wave")), int(entry.get("weight")), expected[0], expected[1], expected[2]])
			return false
	for water_id: StringName in [&"archetype_original_snorkel", &"archetype_original_dolphin_rider", &"archetype_original_ducky_tube"]:
		if not PackedStringArray(by_archetype[water_id].get("required_spawn_tags")).has("spawn.medium.water"):
			push_error("wave pool probe: %s missing water zone gate" % String(water_id))
			return false
	# Compile a seeded recipe over the pool and check the budget gate plus
	# the wave-0 unlock curve (only basic zombies are eligible at wave 0).
	var composer := WaveComposerRef.new()
	var recipe: Resource = WaveRecipeDefRef.new()
	recipe.recipe_id = "original_pool_probe"
	recipe.total_waves = 6
	recipe.waves_per_flag = 6
	recipe.base_budget = 1
	recipe.budget_per_wave = 2
	recipe.flag_budget_multiplier = 1.0
	recipe.pool_def = pool_res
	recipe.flag_entry = by_archetype.get(&"archetype_original_flag_zombie")
	var waves: Array = composer.compile(recipe, 20261001, null)
	if waves.size() != 6:
		push_error("wave pool probe: compiled %d waves (expected 6)" % waves.size())
		return false
	var pool_ids: Dictionary = {}
	for archetype_id: StringName in by_archetype.keys():
		pool_ids[archetype_id] = true
	for wave_index in range(waves.size()):
		var wave = waves[wave_index]
		var spend := 0
		for spawn_wrapper in Array(wave.get("spawn_entries")):
			var spawn_entry: Variant = spawn_wrapper.get("spawn_entry") if spawn_wrapper.get("spawn_entry") != null else spawn_wrapper
			var archetype_id := StringName(str(spawn_entry.get("archetype_id")))
			if not pool_ids.has(archetype_id):
				push_error("wave pool probe: wave %d spawned non-pool archetype %s" % [wave_index, String(archetype_id)])
				return false
			spend += 1
			if wave_index == 0 and archetype_id != &"archetype_original_basic_zombie":
				push_error("wave pool probe: wave 0 spawned %s before its unlock wave" % String(archetype_id))
				return false
		var budget := 1 + 2 * wave_index
		if spend > budget:
			push_error("wave pool probe: wave %d spent %d > budget %d" % [wave_index, spend, budget])
			return false
	return true


func _emit_probe(probe: StringName, result: StringName, extra_core: Dictionary = {}) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["original_zombie", "validation"]))
	event_data.core["probe"] = probe
	event_data.core["result"] = result
	for key: Variant in extra_core.keys():
		event_data.core[key] = extra_core[key]
	EventBus.push_event(&"original_zombie.validation_probe", event_data)
