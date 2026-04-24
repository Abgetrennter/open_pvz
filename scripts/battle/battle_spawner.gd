extends RefCounted
class_name BattleSpawner

const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const BattleSpawnEntryRef = preload("res://scripts/battle/battle_spawn_entry.gd")
const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")
const ProtocolValidatorRef = preload("res://scripts/core/runtime/protocol_validator.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const HeightBandRef = preload("res://scripts/core/defs/height_band.gd")
const ShuffleBagRef = preload("res://scripts/core/runtime/shuffle_bag.gd")

var _battle: Node = null
var _entity_factory: RefCounted = EntityFactoryRef.new()


func bind_battle(battle: Node) -> void:
	_battle = battle


func spawn_projectile_from_effect(context, params: Dictionary, on_hit_effect = null) -> Node:
	var resolver: RefCounted = _battle.get_projectile_effect_resolver()
	var direction := Vector2.RIGHT
	var resolved_params: Dictionary = resolver.resolve_projectile_effect_params(params)
	var direction_value: Variant = resolved_params.get("direction", Vector2.RIGHT)
	if direction_value is Vector2:
		direction = direction_value

	var spawn_position: Vector2 = context.position
	if resolved_params.get("spawn_position", null) is Vector2:
		spawn_position = resolved_params.get("spawn_position")
	elif context.source_node != null and context.source_node is Node2D:
		spawn_position = context.source_node.global_position + direction.normalized() * 34.0

	var burst_count := int(resolved_params.get("burst_count", 1))
	var spread_count := int(resolved_params.get("spread_count", 1))
	var spread_angle_deg := float(resolved_params.get("spread_angle", 0.0))
	var total_emissions := maxi(burst_count, 1) * maxi(spread_count, 1)
	var first_projectile: Node = null
	var base_angle := direction.angle()
	for burst_i in range(maxi(burst_count, 1)):
		for spread_i in range(maxi(spread_count, 1)):
			var spread_offset := 0.0
			if spread_count > 1:
				spread_offset = deg_to_rad(spread_angle_deg) * (float(spread_i) - float(spread_count - 1) / 2.0)
			var emission_dir := Vector2.from_angle(base_angle + spread_offset)
			var projectile_template = resolved_params.get("projectile_template", null)
			var projectile: Variant = _entity_factory.create_projectile(spawn_position, projectile_template, resolved_params)
			var speed := float(resolved_params.get("speed", 300.0))
			var damage := int(resolved_params.get("damage", 10))
			var movement_params: Dictionary = resolver.build_projectile_movement_params(
				context,
				resolved_params,
				spawn_position,
				emission_dir,
				speed
			)
			projectile.launch(emission_dir, speed, context.source_node, on_hit_effect, damage, movement_params, {
				"depth": int(context.runtime.get("depth", context.depth)),
				"chain_id": context.chain_id,
				"origin_event_name": context.event_name,
			})
			var entity_root: Node2D = _battle.get_entity_root()
			entity_root.add_child(projectile)
			if first_projectile == null:
				first_projectile = projectile
	return first_projectile


func spawn_entity_from_effect(context, params: Dictionary, metadata: Dictionary = {}) -> Node:
	var entry = BattleSpawnEntryRef.new()
	var archetype_id := StringName(params.get("archetype_id", StringName()))
	if archetype_id == StringName():
		_battle.report_protocol_issues(["spawn_entity effect must provide archetype_id."], &"spawn_entity")
		return null
	entry.archetype_id = archetype_id
	entry.lane_id = _resolve_effect_spawn_lane(context, params)
	entry.x_position = _resolve_effect_spawn_x_position(context, params)
	if params.get("spawn_overrides", null) is Dictionary:
		entry.spawn_overrides = params.get("spawn_overrides").duplicate(true)
	if params.get("hit_height_band_override", null) is Resource:
		entry.hit_height_band_override = params.get("hit_height_band_override")
	if params.get("projectile_flight_profile_override", null) is Resource:
		entry.projectile_flight_profile_override = params.get("projectile_flight_profile_override")
	if params.get("projectile_template_override", null) is Resource:
		entry.projectile_template_override = params.get("projectile_template_override")
	return _spawn_entry_internal(entry, metadata, context.source_node)


func spawn_card_entity(archetype_id: StringName, lane_id: int, slot_index: int, metadata: Dictionary = {}, emit_spawn_event: bool = false) -> Node:
	if archetype_id == StringName():
		return null
	if not SceneRegistry.has_archetype(archetype_id):
		return null
	var spawn_position := _build_board_slot_position(lane_id, slot_index)
	var board_state: Node = _battle.get_board_state()
	if board_state != null and is_instance_valid(board_state):
		spawn_position = Vector2(board_state.get_slot_world_position(lane_id, slot_index))
	var entry = BattleSpawnEntryRef.new()
	entry.entity_kind = &"plant"
	entry.archetype_id = archetype_id
	entry.lane_id = lane_id
	entry.x_position = spawn_position.x
	return _spawn_entry_internal(entry, metadata.merged({
		"spawn_reason": &"card_play",
		"slot_index": slot_index,
		"archetype_id": archetype_id,
	}), null, spawn_position, emit_spawn_event)


func spawn_card_actor(card_def: Resource, lane_id: int, slot_index: int, metadata: Dictionary = {}, emit_spawn_event: bool = false) -> Node:
	if card_def == null:
		return null
	var archetype_id := StringName(card_def.get("archetype_id"))
	if archetype_id != StringName():
		if not SceneRegistry.has_archetype(archetype_id):
			return null
		var board_state: Node = _battle.get_board_state()
		var spawn_position := _build_board_slot_position(lane_id, slot_index)
		if board_state != null and is_instance_valid(board_state):
			spawn_position = Vector2(board_state.get_slot_world_position(lane_id, slot_index))
		var entry = BattleSpawnEntryRef.new()
		entry.entity_kind = &"plant"
		entry.archetype_id = archetype_id
		entry.lane_id = lane_id
		entry.x_position = spawn_position.x
		return _spawn_entry_internal(entry, metadata.merged({
			"spawn_reason": &"card_play",
			"slot_index": slot_index,
			"archetype_id": archetype_id,
		}), null, spawn_position, emit_spawn_event)
	return null


func spawn_wave_entry(spawn_entry: Resource, wave_id: StringName = StringName()):
	return _spawn_entry_internal(spawn_entry, {
		"spawn_reason": &"wave_spawn",
		"wave_id": wave_id,
	})


func spawn_scenario() -> void:
	var active_scenario = _battle.resolve_scenario()
	if active_scenario == null:
		return
	_battle.report_protocol_issues(ProtocolValidatorRef.validate_battle_scenario(active_scenario), &"battle_scenario")
	for spawn_entry in active_scenario.spawns:
		_spawn_entry_internal(spawn_entry, {"spawn_reason": &"scenario_spawn"})
	var field_object_state: Node = _battle.get_field_object_state()
	if field_object_state != null:
		field_object_state.spawn_field_objects(active_scenario)


func finalize_spawned_entity(
	entity: Node,
	lane_id: int,
	hit_height_band: Resource,
	trigger_instances: Array,
	source_node: Node = null,
	metadata: Dictionary = {},
	emit_spawn_event: bool = true
) -> void:
	entity.assign_lane(lane_id)
	apply_spawn_height_band(entity, hit_height_band)
	var entity_root: Node2D = _battle.get_entity_root()
	entity_root.add_child(entity)
	_init_mechanic_runtime_states(entity)
	bind_runtime_triggers(entity, trigger_instances)
	if not emit_spawn_event:
		return
	emit_entity_spawned(entity, lane_id, source_node, metadata)


func _init_mechanic_runtime_states(entity: Node) -> void:
	if not entity.has_method("get_entity_id"):
		return
	var entity_id: int = int(entity.call("get_entity_id"))
	if entity_id < 0:
		return
	var entity_seed: int = GameState.derive_entity_seed(GameState.battle_seed, entity_id)
	var entity_state: Variant = entity.get("entity_state")
	if entity_state == null or not entity_state.has_method("get_value"):
		return
	var mechanic_states: Variant = entity_state.call("get_value", &"mechanic_runtime_states")
	if mechanic_states == null or not (mechanic_states is Dictionary):
		return
	for mechanic_id: StringName in mechanic_states.keys():
		var state: Dictionary = mechanic_states[mechanic_id]
		if state.get("type") == &"shuffle_bag" and state.get("seed_source") == &"mechanic":
			var pool: Array = state.get("pool", [])
			var mech_seed: int = GameState.derive_mechanic_seed(entity_seed, mechanic_id)
			var bag = ShuffleBagRef.new(pool, mech_seed)
			state["bag"] = bag
			state["seed"] = mech_seed


func emit_entity_spawned(entity: Node, lane_id: int, source_node: Node = null, metadata: Dictionary = {}) -> void:
	var spawned_event: Variant = EventDataRef.create(source_node, entity, null, PackedStringArray(["entity", String(metadata.get("spawn_reason", &"spawn"))]))
	spawned_event.core["lane_id"] = lane_id
	if entity.has_method("get_entity_id"):
		spawned_event.core["entity_id"] = int(entity.call("get_entity_id"))
	if entity.get("template_id") != null:
		spawned_event.core["entity_template_id"] = StringName(entity.get("template_id"))
	if entity.get("archetype_id") != null:
		var spawned_archetype_id := StringName(entity.get("archetype_id"))
		if spawned_archetype_id != StringName():
			spawned_event.core["archetype_id"] = spawned_archetype_id
	for key: Variant in metadata.keys():
		spawned_event.core[key] = metadata[key]
	EventBus.push_event(&"entity.spawned", spawned_event)


func apply_spawn_height_band(entity: Node, height_band: Resource) -> void:
	if height_band == null:
		return
	var height_errors: Array[String] = ProtocolValidatorRef.validate_height_band(height_band)
	if not height_errors.is_empty():
		_battle.report_protocol_issues(height_errors, &"height_band")
		return
	if height_band.get_script() != HeightBandRef:
		return
	if entity.has_method("apply_height_band"):
		entity.call("apply_height_band", height_band)


func bind_runtime_triggers(entity: Node, trigger_instances: Array) -> void:
	var trigger_component: Variant = entity.get_node_or_null("TriggerComponent")
	if trigger_component == null:
		return
	trigger_component.bind_triggers(trigger_instances)


func _spawn_entry_internal(spawn_entry, metadata: Dictionary = {}, source_node: Node = null, position_override: Variant = null, emit_spawn_event: bool = true):
	if spawn_entry == null:
		return null
	var active_scenario = _battle.resolve_scenario()
	var scenario_id: StringName = StringName() if active_scenario == null else active_scenario.scenario_id
	var spawn_errors: Array[String] = ProtocolValidatorRef.validate_battle_spawn_entry(spawn_entry, scenario_id)
	if not spawn_errors.is_empty():
		_battle.report_protocol_issues(spawn_errors, &"battle_spawn_entry")
		return null

	var spawn_resolution: Dictionary = _entity_factory.instantiate_spawn_entry(
		spawn_entry,
		Vector2(position_override) if position_override is Vector2 else _build_spawn_entry_position(spawn_entry)
	)
	if spawn_resolution.is_empty():
		return null

	var entry_kind: StringName = spawn_resolution.get("entity_kind", &"entity")
	var lane_id: int = spawn_entry.lane_id
	var hit_height_band: Resource = spawn_resolution.get("hit_height_band", null)
	var trigger_instances: Array = spawn_resolution.get("trigger_instances", [])
	var entity: Variant = spawn_resolution.get("entity", null)
	if entry_kind not in [&"plant", &"zombie"]:
		push_warning("Unsupported spawn entry kind: %s" % [String(entry_kind)])
		return null
	if entity == null or not entity.has_method("assign_lane"):
		return null
	_battle.finalize_spawned_entity(entity, lane_id, hit_height_band, trigger_instances, source_node, metadata, emit_spawn_event)
	return entity


func _resolve_effect_spawn_lane(context, params: Dictionary) -> int:
	var explicit_lane: Variant = params.get("lane_id", null)
	if explicit_lane is int and int(explicit_lane) >= 0:
		return int(explicit_lane)
	if context.target_node != null and context.target_node.get("lane_id") is int:
		return int(context.target_node.get("lane_id"))
	if context.source_node != null and context.source_node.get("lane_id") is int:
		return int(context.source_node.get("lane_id"))
	if context.owner_entity != null and context.owner_entity.get("lane_id") is int:
		return int(context.owner_entity.get("lane_id"))
	return 0


func _resolve_effect_spawn_x_position(context, params: Dictionary) -> float:
	var explicit_spawn_position: Variant = params.get("spawn_position", null)
	if explicit_spawn_position is Vector2:
		return float(explicit_spawn_position.x)
	var explicit_x: Variant = params.get("x_position", null)
	if explicit_x is float or explicit_x is int:
		return float(explicit_x)
	return float(context.position.x + float(params.get("x_offset", 0.0)))


func _build_board_slot_position(lane_id: int, slot_index: int) -> Vector2:
	var active_scenario = _battle.resolve_scenario()
	var origin_x := 160.0
	var spacing := 96.0
	if active_scenario != null:
		origin_x = float(active_scenario.get("board_slot_origin_x"))
		spacing = float(active_scenario.get("board_slot_spacing"))
	return Vector2(origin_x + float(slot_index) * spacing, float(_battle.get_lane_y(lane_id)))


func _build_spawn_entry_position(spawn_entry: Resource) -> Vector2:
	return Vector2(float(spawn_entry.get("x_position")), float(_battle.get_lane_y(int(spawn_entry.get("lane_id")))))
