extends RefCounted
class_name BattleModeModuleRegistry

const BattleEnvironmentStateRef = preload("res://scripts/battle/environment/battle_environment_state.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

const ENVIRONMENT_NOCTURNAL_SLEEP_SOURCE := &"environment:nocturnal_day_sleep"
const ENVIRONMENT_NOCTURNAL_SLEEP_PRIORITY := 30
const ENVIRONMENT_FOG_SOURCE_PREFIX := "environment:fog:"

var _handlers: Dictionary = {}


func _init() -> void:
	_register_builtin_handlers()


func register_handler(module_id: StringName, handler: Callable) -> void:
	_handlers[module_id] = handler


func get_handler(module_id: StringName) -> Callable:
	if _handlers.has(module_id):
		return _handlers[module_id]
	return Callable()


func has_handler(module_id: StringName) -> bool:
	return _handlers.has(module_id)


func _register_builtin_handlers() -> void:
	register_handler(&"conveyor_cards", _handler_conveyor_cards)
	register_handler(&"manual_entity_skill", _handler_manual_entity_skill)
	register_handler(&"environment.core", _handler_environment_core)


func _handler_environment_core(action: StringName, battle: Node, module: Resource, context: Dictionary) -> void:
	match action:
		&"on_mode_setup":
			var module_params := _module_params(module)
			var environment_profile: Resource = module_params.get("environment_profile")
			if environment_profile == null:
				_report_module_issue(battle, "environment.core requires params.environment_profile.")
				return
			var environment_state: Variant = BattleEnvironmentStateRef.new()
			environment_state.configure_from_profile(environment_profile)
			_configure_environment_board(battle, environment_state)
			if battle != null and battle.has_method("set_environment_state"):
				battle.call("set_environment_state", environment_state)
			_emit_environment_changed(module, environment_state, &"on_mode_setup")
			if bool(environment_state.snapshot().get("fog_enabled", false)):
				_emit_environment_fog_updated(module, environment_state, &"initialized")
			_emit_environment_rule_applied(module, &"on_mode_setup", &"environment_initialized", environment_state.snapshot())
		&"on_battle_start":
			var environment_state: Variant = _get_environment_state(battle)
			if environment_state == null:
				return
			_sync_environment_economy(battle, environment_state)
			_apply_environment_to_all_entities(battle, module, environment_state)
			_register_existing_fog_sources(battle, module, environment_state)
			_emit_environment_rule_applied(module, &"on_battle_start", &"environment_applied_to_economy", environment_state.snapshot())
		&"on_before_game_tick":
			var environment_state: Variant = _get_environment_state(battle)
			if environment_state == null:
				return
			var game_time := float(context.get("game_time", GameState.current_time))
			_apply_environment_timeline_tick(battle, module, environment_state, game_time)
		&"on_game_tick":
			var environment_state: Variant = _get_environment_state(battle)
			if environment_state == null:
				return
			var game_time := float(context.get("game_time", GameState.current_time))
			_apply_environment_timeline_tick(battle, module, environment_state, game_time)
			if bool(environment_state.call("update_clear_sources", game_time)):
				_emit_environment_fog_updated(module, environment_state, &"clear_source_expired")
		&"on_event":
			var environment_state: Variant = _get_environment_state(battle)
			if environment_state == null:
				return
			var event_name := StringName(context.get("event_name", StringName()))
			var event_data: Variant = context.get("event_data", null)
			if event_data == null:
				return
			match event_name:
				&"placement.accepted":
					var entity: Node = event_data.core.get("target_node", null)
					_apply_nocturnal_environment_to_entity(module, environment_state, entity)
					_try_register_entity_fog_source(module, environment_state, entity, event_data)
					_gate_lifecycle_event_if_triggers_disabled(entity, event_data)
				&"entity.spawned":
					var entity: Node = event_data.core.get("target_node", null)
					_apply_nocturnal_environment_to_entity(module, environment_state, entity)
					_try_register_entity_fog_source(module, environment_state, entity, event_data)
				&"entity.died", &"entity.consumed":
					_remove_entity_fog_source(module, environment_state, event_data)
				&"environment.fog_clear_requested":
					_register_requested_fog_clear(module, environment_state, event_data)
		&"on_mode_teardown":
			if battle != null and battle.has_method("set_environment_state"):
				battle.call("set_environment_state", null)


func _handler_conveyor_cards(action: StringName, battle: Node, module: Resource, context: Dictionary) -> void:
	var mode_host: Node = battle.call("get_mode_host") if battle != null and battle.has_method("get_mode_host") else null
	if mode_host == null:
		return
	var module_params: Dictionary = {}
	var raw_params: Variant = module.get("params")
	if raw_params is Dictionary:
		module_params = raw_params
	var state_prefix := "conveyor_cards.%s" % String(module.get("module_id"))
	match action:
		&"on_mode_setup":
			mode_host.call("set_runtime_value", StringName("%s.cursor" % state_prefix), 0)
			mode_host.call("set_runtime_value", StringName("%s.last_emit_time" % state_prefix), -1.0)
		&"on_battle_start":
			var init_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(null, null, null, PackedStringArray(["mode", "rule"]))
			init_event.core["module_id"] = StringName(module.get("module_id"))
			init_event.core["source_event"] = &"on_battle_start"
			init_event.core["behavior"] = &"conveyor_initialized"
			EventBus.push_event(&"battle.mode_rule_applied", init_event)
		&"on_game_tick":
			var game_time := float(context.get("game_time", GameState.current_time))
			var interval := maxf(float(module_params.get("interval", 2.0)), 0.1)
			var last_emit_time := float(mode_host.call("get_runtime_value", StringName("%s.last_emit_time" % state_prefix), -1.0))
			if last_emit_time >= 0.0 and game_time - last_emit_time + 0.001 < interval:
				return
			var card_state: Node = battle.get_node_or_null("BattleCardState")
			if card_state == null or not card_state.has_method("get_hand_order"):
				return
			var hand_order := PackedStringArray(card_state.call("get_hand_order"))
			if hand_order.is_empty():
				return
			var configured_card_ids := PackedStringArray(module_params.get("card_ids", PackedStringArray()))
			var cycle_cards := configured_card_ids if not configured_card_ids.is_empty() else hand_order
			if cycle_cards.is_empty():
				return
			var cursor := int(mode_host.call("get_runtime_value", StringName("%s.cursor" % state_prefix), 0))
			var card_id := StringName(cycle_cards[cursor % cycle_cards.size()])
			if card_state.has_method("rotate_card_to_back") and card_state.call("has_card", card_id):
				card_state.call("rotate_card_to_back", card_id, &"conveyor_rotate")
			mode_host.call("set_runtime_value", StringName("%s.cursor" % state_prefix), cursor + 1)
			mode_host.call("set_runtime_value", StringName("%s.last_emit_time" % state_prefix), game_time)
			var mode_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(null, null, null, PackedStringArray(["mode", "rule"]))
			mode_event.core["module_id"] = StringName(module.get("module_id"))
			mode_event.core["source_event"] = &"on_game_tick"
			mode_event.core["behavior"] = &"conveyor_advance"
			mode_event.core["card_id"] = card_id
			mode_event.core["hand_order"] = PackedStringArray(card_state.call("get_hand_order"))
			EventBus.push_event(&"battle.mode_rule_applied", mode_event)
		&"on_event":
			pass
		&"on_mode_teardown":
			pass


func _handler_manual_entity_skill(action: StringName, battle: Node, module: Resource, context: Dictionary) -> void:
	match action:
		&"on_mode_setup":
			pass
		&"on_battle_start":
			pass
		&"on_game_tick":
			var mode_host: Node = battle.call("get_mode_host") if battle != null and battle.has_method("get_mode_host") else null
			if mode_host == null:
				return
			var module_params := _module_params(module)
			_refresh_manual_skill_reload_states(battle, mode_host, module, module_params)
		&"on_event":
			var event_name := StringName(context.get("event_name", StringName()))
			var event_data: Variant = context.get("event_data", null)
			if event_data == null:
				return
			var mode_host: Node = battle.call("get_mode_host") if battle != null and battle.has_method("get_mode_host") else null
			if mode_host == null:
				return
			var module_params := _module_params(module)
			var resolved_input_profile: Resource = mode_host.call("get_resolved_input_profile")
			if resolved_input_profile != null and not bool(resolved_input_profile.get("enable_manual_skill")):
				return
			var selected_key := StringName(module_params.get("selection_state_key", &"manual_skill_selected_entity_id"))
			if event_name == &"input.action.entity_clicked":
				var clicked_entity_id := int(event_data.core.get("entity_id", -1))
				mode_host.call("set_runtime_value", selected_key, clicked_entity_id)
				var selection_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(null, null, null, PackedStringArray(["mode", "selection"]))
				selection_event.core["module_id"] = StringName(module.get("module_id"))
				selection_event.core["selected_entity_id"] = clicked_entity_id
				EventBus.push_event(&"battle.mode_selection_changed", selection_event)
				return
			if event_name != &"input.action.cell_clicked":
				return
			var selected_entity_id := int(mode_host.call("get_runtime_value", selected_key, -1))
			if selected_entity_id < 0:
				return
			var score_key := StringName(module_params.get("score_key", &"score"))
			var score_gain := int(module_params.get("score_gain", 1))
			mode_host.call("increment_objective_progress", score_key, score_gain)
			var current_score := int(mode_host.call("get_objective_progress", score_key))
			var mode_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(null, null, null, PackedStringArray(["mode", "rule"]))
			mode_event.core["module_id"] = StringName(module.get("module_id"))
			mode_event.core["source_event"] = event_name
			mode_event.core["selected_entity_id"] = selected_entity_id
			mode_event.core["target_lane_id"] = int(event_data.core.get("lane_id", -1))
			mode_event.core["target_slot_index"] = int(event_data.core.get("slot_index", -1))
			mode_event.core["score_key"] = score_key
			mode_event.core["score_gain"] = score_gain
			mode_event.core["current_score"] = current_score
			EventBus.push_event(&"battle.mode_rule_applied", mode_event)
			_try_apply_manual_entity_skill(battle, mode_host, module, module_params, selected_entity_id, event_data)
		&"on_mode_teardown":
			pass


func _module_params(module: Resource) -> Dictionary:
	var raw_params: Variant = module.get("params") if module != null else {}
	return raw_params.duplicate(true) if raw_params is Dictionary else {}


func _get_environment_state(battle: Node) -> Variant:
	if battle == null or not battle.has_method("get_environment_state"):
		return null
	return battle.call("get_environment_state")


func _configure_environment_board(battle: Node, environment_state: Variant) -> void:
	if battle == null or environment_state == null or not environment_state.has_method("configure_board"):
		return
	var lane_ids := PackedInt32Array()
	if battle.has_method("get_lane_ids"):
		lane_ids = PackedInt32Array(battle.call("get_lane_ids"))
	var board_slot_count := 0
	if battle.has_method("get_board_state"):
		var board: Node = battle.call("get_board_state")
		if board != null:
			board_slot_count = int(board.get("board_slot_count"))
	var metrics: RefCounted = null
	if battle.has_method("get_battlefield_metrics"):
		var metrics_value: Variant = battle.call("get_battlefield_metrics")
		metrics = metrics_value if metrics_value is RefCounted else null
	environment_state.call("configure_board", lane_ids, board_slot_count, metrics)


func _sync_environment_economy(battle: Node, environment_state: Variant) -> void:
	var economy: Node = battle.call("get_economy_state") if battle != null and battle.has_method("get_economy_state") else null
	if economy == null:
		return
	if economy.has_method("configure_natural_sun"):
		economy.call("configure_natural_sun", environment_state.get_natural_sun_interval_seconds(), environment_state.get_natural_sun_value())
	if economy.has_method("set_natural_sun_interval_scale"):
		economy.call("set_natural_sun_interval_scale", environment_state.get_sun_interval_scale())
	if economy.has_method("set_natural_sun_value_scale"):
		economy.call("set_natural_sun_value_scale", environment_state.get_sun_value_scale())
	if economy.has_method("set_natural_sun_enabled"):
		economy.call("set_natural_sun_enabled", environment_state.is_natural_sun_enabled())


func _apply_environment_timeline_tick(battle: Node, module: Resource, environment_state: Variant, game_time: float) -> void:
	if not bool(environment_state.call("apply_timeline", game_time)):
		return
	_sync_environment_economy(battle, environment_state)
	_apply_environment_to_all_entities(battle, module, environment_state)
	_emit_environment_changed(module, environment_state, &"timeline")


func _emit_environment_changed(module: Resource, environment_state: Variant, source_event: StringName) -> void:
	var changed_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["environment", "changed"]))
	changed_event.core["module_id"] = StringName(module.get("module_id"))
	var snapshot := Dictionary(environment_state.snapshot())
	for key: Variant in snapshot.keys():
		changed_event.core[key] = snapshot[key]
	changed_event.core["source_event"] = source_event
	EventBus.push_event(&"environment.changed", changed_event)


func _apply_environment_to_all_entities(battle: Node, module: Resource, environment_state: Variant) -> void:
	if battle == null or not battle.has_method("get_runtime_combat_entities"):
		return
	for entity in battle.call("get_runtime_combat_entities"):
		if entity == null or not is_instance_valid(entity):
			continue
		_apply_nocturnal_environment_to_entity(module, environment_state, entity)


func _apply_nocturnal_environment_to_entity(module: Resource, environment_state: Variant, entity: Node) -> void:
	if not _entity_has_tag(entity, &"nocturnal"):
		return
	var sleeping_profile := {
		&"triggers": false,
		&"controllers": false,
	}
	if bool(environment_state.call("is_night")):
		if entity.has_method("pop_liveness_override"):
			entity.call("pop_liveness_override", ENVIRONMENT_NOCTURNAL_SLEEP_SOURCE)
		_emit_environment_wake(entity)
		_emit_nocturnal_state_applied(module, entity, &"night", false)
		return
	if entity.has_method("push_liveness_override"):
		entity.call("push_liveness_override", ENVIRONMENT_NOCTURNAL_SLEEP_SOURCE, sleeping_profile, ENVIRONMENT_NOCTURNAL_SLEEP_PRIORITY)
	_emit_nocturnal_state_applied(module, entity, &"day", true)


func _emit_environment_wake(entity: Node) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var wake_event: Variant = EventDataRef.create(entity, entity, null, PackedStringArray(["wake", "environment"]))
	wake_event.core["state_id"] = &"sleeping"
	wake_event.core["reason"] = &"environment_night"
	EventBus.push_event(&"entity.wake", wake_event)


func _emit_nocturnal_state_applied(module: Resource, entity: Node, phase: StringName, sleeping: bool) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var event_data: Variant = EventDataRef.create(entity, entity, null, PackedStringArray(["environment", "nocturnal"]))
	event_data.core["module_id"] = StringName(module.get("module_id"))
	event_data.core["phase"] = phase
	event_data.core["sleeping"] = sleeping
	event_data.core["triggers"] = not sleeping
	event_data.core["controllers"] = not sleeping
	EventBus.push_event(&"environment.nocturnal_state_applied", event_data)


func _gate_lifecycle_event_if_triggers_disabled(entity: Node, event_data: Variant) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	if not entity.has_method("is_liveness_enabled") or bool(entity.call("is_liveness_enabled", &"triggers")):
		return
	if not entity.has_method("get_entity_id"):
		return
	var gated_targets := PackedInt32Array(event_data.core.get("liveness_gated_target_ids", PackedInt32Array()))
	var entity_id := int(entity.call("get_entity_id"))
	if not gated_targets.has(entity_id):
		gated_targets.append(entity_id)
	event_data.core["liveness_gated_target_ids"] = gated_targets


func _register_existing_fog_sources(battle: Node, module: Resource, environment_state: Variant) -> void:
	if battle == null or not battle.has_method("get_runtime_combat_entities"):
		return
	for entity in battle.call("get_runtime_combat_entities"):
		if entity == null or not is_instance_valid(entity):
			continue
		_try_register_entity_fog_source(module, environment_state, entity, null)


func _try_register_entity_fog_source(module: Resource, environment_state: Variant, entity: Node, event_data: Variant) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var radius_slots := -1.0
	if _entity_has_tag(entity, &"plantern"):
		radius_slots = 2.0
	elif _entity_has_tag(entity, &"torchwood"):
		radius_slots = 1.0
	if radius_slots < 0.0:
		return
	var slot_index := _resolve_entity_slot_index(entity, event_data)
	var lane_id := int(entity.get("lane_id"))
	var source_id := _entity_fog_source_id(entity)
	if bool(environment_state.call("add_clear_source", source_id, lane_id, slot_index, radius_slots, 0.0, &"radius", GameState.current_time)):
		_emit_fog_clear_source_registered(module, environment_state, source_id, entity, &"persistent")


func _register_requested_fog_clear(module: Resource, environment_state: Variant, event_data: Variant) -> void:
	var source_entity_id := int(event_data.core.get("source_entity_id", event_data.core.get("source_id", -1)))
	var source_id := StringName("environment:fog:request:%d:%d" % [source_entity_id, int(round(GameState.current_time * 100.0))])
	var lane_id := int(event_data.core.get("lane_id", -1))
	var slot_index := int(event_data.core.get("slot_index", -1))
	var radius_slots := float(event_data.core.get("radius_slots", environment_state.fog_clear_default_radius_slots))
	var duration := float(event_data.core.get("duration", environment_state.fog_clear_default_duration))
	var clear_mode := StringName(event_data.core.get("clear_mode", &"radius"))
	if bool(environment_state.call("add_clear_source", source_id, lane_id, slot_index, radius_slots, duration, clear_mode, GameState.current_time)):
		_emit_fog_clear_source_registered(module, environment_state, source_id, event_data.core.get("source_node", null), &"temporary")


func _remove_entity_fog_source(module: Resource, environment_state: Variant, event_data: Variant) -> void:
	var entity: Node = event_data.core.get("target_node", event_data.core.get("source_node", null))
	var source_id := _entity_fog_source_id(entity)
	if source_id == StringName():
		var entity_id := int(event_data.core.get("target_id", event_data.core.get("source_id", -1)))
		if entity_id >= 0:
			source_id = StringName("%s%d" % [ENVIRONMENT_FOG_SOURCE_PREFIX, entity_id])
	if source_id == StringName():
		return
	if bool(environment_state.call("remove_clear_source", source_id)):
		_emit_environment_fog_updated(module, environment_state, &"clear_source_removed")
		var removed_event: Variant = EventDataRef.create(null, null, null, PackedStringArray(["environment", "fog"]))
		removed_event.core["module_id"] = StringName(module.get("module_id"))
		removed_event.core["source_id"] = source_id
		removed_event.core["clear_source_count"] = int(environment_state.snapshot().get("clear_source_count", 0))
		EventBus.push_event(&"environment.fog_clear_source_removed", removed_event)


func _emit_fog_clear_source_registered(module: Resource, environment_state: Variant, source_id: StringName, source_entity: Node, source_kind: StringName) -> void:
	var event_data: Variant = EventDataRef.create(source_entity, null, null, PackedStringArray(["environment", "fog"]))
	event_data.core["module_id"] = StringName(module.get("module_id"))
	event_data.core["source_id"] = source_id
	event_data.core["source_kind"] = source_kind
	event_data.core["clear_source_count"] = int(environment_state.snapshot().get("clear_source_count", 0))
	EventBus.push_event(&"environment.fog_clear_source_registered", event_data)
	_emit_environment_fog_updated(module, environment_state, &"clear_source_registered")


func _emit_environment_fog_updated(module: Resource, environment_state: Variant, reason: StringName) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["environment", "fog"]))
	event_data.core["module_id"] = StringName(module.get("module_id"))
	event_data.core["reason"] = reason
	var fog_snapshot := Dictionary(environment_state.fog_snapshot())
	for key: Variant in fog_snapshot.keys():
		event_data.core[key] = fog_snapshot[key]
	event_data.core["alpha_lane_0_slot_0"] = float(environment_state.call("fog_alpha_at_slot", 0, 0))
	event_data.core["alpha_lane_0_slot_1"] = float(environment_state.call("fog_alpha_at_slot", 0, 1))
	event_data.core["alpha_lane_0_slot_2"] = float(environment_state.call("fog_alpha_at_slot", 0, 2))
	event_data.core["alpha_lane_0_slot_3"] = float(environment_state.call("fog_alpha_at_slot", 0, 3))
	EventBus.push_event(&"environment.fog_updated", event_data)


func _entity_fog_source_id(entity: Node) -> StringName:
	if entity == null or not is_instance_valid(entity):
		return StringName()
	if not entity.has_method("get_entity_id"):
		return StringName()
	return StringName("%s%d" % [ENVIRONMENT_FOG_SOURCE_PREFIX, int(entity.call("get_entity_id"))])


func _resolve_entity_slot_index(entity: Node, event_data: Variant) -> int:
	if event_data != null and event_data.core.has("slot_index"):
		return int(event_data.core.get("slot_index"))
	if entity != null and entity.has_method("get_entity_state_ref"):
		var entity_state: Variant = entity.call("get_entity_state_ref")
		if entity_state != null and entity_state.has_method("get_value"):
			return int(entity_state.call("get_value", &"slot_index", -1))
	return -1


func _entity_has_tag(entity: Node, tag: StringName) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	var raw_tags: Variant = entity.get("tags")
	if raw_tags is PackedStringArray:
		return PackedStringArray(raw_tags).has(String(tag))
	if raw_tags is Array:
		return Array(raw_tags).has(tag) or Array(raw_tags).has(String(tag))
	return false


func _emit_environment_rule_applied(module: Resource, source_event: StringName, behavior: StringName, snapshot: Dictionary) -> void:
	var mode_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(null, null, null, PackedStringArray(["mode", "rule", "environment"]))
	mode_event.core["module_id"] = StringName(module.get("module_id"))
	mode_event.core["source_event"] = source_event
	mode_event.core["behavior"] = behavior
	for key: Variant in snapshot.keys():
		mode_event.core[key] = snapshot[key]
	EventBus.push_event(&"battle.mode_rule_applied", mode_event)


func _report_module_issue(battle: Node, message: String) -> void:
	if battle != null and battle.has_method("report_protocol_issues"):
		battle.call("report_protocol_issues", [message], &"battle_mode_module")


func _try_apply_manual_entity_skill(
	battle: Node,
	mode_host: Node,
	module: Resource,
	module_params: Dictionary,
	selected_entity_id: int,
	event_data: Variant
) -> void:
	var skill_type := StringName(module_params.get("skill_type", StringName()))
	if skill_type == StringName():
		return
	var source_entity := _find_runtime_entity_by_id(battle, selected_entity_id)
	if source_entity == null:
		return
	if not _manual_skill_source_allowed(source_entity, module_params):
		_emit_manual_skill_rejected(module, source_entity, &"source_not_allowed")
		return
	if not _manual_skill_is_ready(source_entity):
		_refresh_single_manual_skill_ready(source_entity, module, module_params)
	if not _manual_skill_is_ready(source_entity):
		_emit_manual_skill_rejected(module, source_entity, &"reloading")
		return
	match skill_type:
		&"area_damage":
			_apply_manual_area_damage(battle, mode_host, module, module_params, source_entity, event_data)


func _apply_manual_area_damage(
	battle: Node,
	_mode_host: Node,
	module: Resource,
	module_params: Dictionary,
	source_entity: Node,
	event_data: Variant
) -> void:
	if battle == null or not battle.has_method("spatial_query"):
		return
	var target_lane_id := int(event_data.core.get("lane_id", -1))
	var target_slot_index := int(event_data.core.get("slot_index", -1))
	var target_position := _manual_skill_target_position(battle, target_lane_id, target_slot_index)
	var radius := _resolve_manual_skill_radius(battle, module_params)
	var enemy_team := StringName(module_params.get("target_team", &"zombie"))
	var targets: Array = battle.call("spatial_query", {
		"team_include": enemy_team,
		"center": target_position,
		"radius": radius,
		"sort_by_distance": true,
		"filter": func(candidate):
			return candidate != source_entity and candidate.has_method("take_damage"),
	})
	var damage := int(module_params.get("damage", 1800))
	var tags := _manual_skill_tags(module_params)
	for target in targets:
		target.call("take_damage", damage, source_entity, tags)
	_enter_manual_skill_reload(source_entity, module, module_params)
	var fired_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(source_entity, null, damage, tags)
	fired_event.core["module_id"] = StringName(module.get("module_id"))
	fired_event.core["skill_type"] = &"area_damage"
	fired_event.core["selected_entity_id"] = int(source_entity.call("get_entity_id")) if source_entity.has_method("get_entity_id") else -1
	fired_event.core["target_lane_id"] = target_lane_id
	fired_event.core["target_slot_index"] = target_slot_index
	fired_event.core["target_position"] = target_position
	fired_event.core["radius"] = radius
	fired_event.core["damage"] = damage
	fired_event.core["hit_count"] = targets.size()
	fired_event.core["state_id"] = &"reloading"
	EventBus.push_event(&"entity.manual_skill_fired", fired_event)


func _enter_manual_skill_reload(source_entity: Node, module: Resource, module_params: Dictionary) -> void:
	var reload_seconds := maxf(float(module_params.get("reload_seconds", 0.0)), 0.0)
	if source_entity.has_method("set_state_value"):
		source_entity.call("set_state_value", &"manual_skill_ready", reload_seconds <= 0.0)
		source_entity.call("set_state_value", &"manual_skill_ready_at", GameState.current_time + reload_seconds)
		source_entity.call("set_state_value", &"manual_skill_state", &"ready" if reload_seconds <= 0.0 else &"reloading")
	if reload_seconds <= 0.0:
		return
	var reload_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(source_entity, source_entity, null, PackedStringArray(["manual_skill", "state"]))
	reload_event.core["module_id"] = StringName(module.get("module_id"))
	reload_event.core["state_id"] = &"reloading"
	reload_event.core["ready_at"] = GameState.current_time + reload_seconds
	EventBus.push_event(&"entity.manual_skill_state_changed", reload_event)


func _refresh_manual_skill_reload_states(battle: Node, mode_host: Node, module: Resource, module_params: Dictionary) -> void:
	if not module_params.has("skill_type"):
		return
	if battle == null or not battle.has_method("get_runtime_combat_entities"):
		return
	for entity in battle.call("get_runtime_combat_entities"):
		if entity == null or not is_instance_valid(entity):
			continue
		if not _manual_skill_source_allowed(entity, module_params):
			continue
		_refresh_single_manual_skill_ready(entity, module, module_params)


func _refresh_single_manual_skill_ready(source_entity: Node, module: Resource, _module_params: Dictionary) -> void:
	if source_entity == null or not is_instance_valid(source_entity):
		return
	var state_ref = source_entity.call("get_entity_state_ref") if source_entity.has_method("get_entity_state_ref") else null
	if state_ref == null or not state_ref.has_method("get_value"):
		return
	if bool(state_ref.call("get_value", &"manual_skill_ready", true)):
		return
	var ready_at := float(state_ref.call("get_value", &"manual_skill_ready_at", 0.0))
	if GameState.current_time + 0.001 < ready_at:
		return
	if source_entity.has_method("set_state_value"):
		source_entity.call("set_state_value", &"manual_skill_ready", true)
		source_entity.call("set_state_value", &"manual_skill_state", &"ready")
	var ready_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(source_entity, source_entity, null, PackedStringArray(["manual_skill", "state"]))
	ready_event.core["module_id"] = StringName(module.get("module_id"))
	ready_event.core["state_id"] = &"ready"
	EventBus.push_event(&"entity.manual_skill_state_changed", ready_event)


func _manual_skill_is_ready(source_entity: Node) -> bool:
	if source_entity == null or not source_entity.has_method("get_entity_state_ref"):
		return true
	var state_ref = source_entity.call("get_entity_state_ref")
	if state_ref == null or not state_ref.has_method("get_value"):
		return true
	return bool(state_ref.call("get_value", &"manual_skill_ready", true))


func _manual_skill_source_allowed(source_entity: Node, module_params: Dictionary) -> bool:
	var allowed_archetype_ids := PackedStringArray(module_params.get("allowed_archetype_ids", PackedStringArray()))
	if allowed_archetype_ids.is_empty():
		return true
	if source_entity == null or not source_entity.has_method("get"):
		return false
	return allowed_archetype_ids.has(String(source_entity.get("archetype_id")))


func _manual_skill_target_position(battle: Node, lane_id: int, slot_index: int) -> Vector2:
	if battle != null and battle.has_method("get_board_state"):
		var board_state: Node = battle.call("get_board_state")
		if board_state != null and board_state.has_method("get_slot_world_position"):
			return Vector2(board_state.call("get_slot_world_position", lane_id, slot_index))
	if battle != null and battle.has_method("get_battlefield_metrics"):
		var metrics: Variant = battle.call("get_battlefield_metrics")
		if metrics != null and metrics.has_method("slot_position"):
			return Vector2(metrics.call("slot_position", lane_id, slot_index))
	if battle != null and battle.has_method("get_lane_y"):
		return Vector2(160.0 + float(slot_index) * 96.0, float(battle.call("get_lane_y", lane_id)))
	return Vector2.ZERO


func _resolve_manual_skill_radius(battle: Node, module_params: Dictionary) -> float:
	if battle != null and battle.has_method("get_battlefield_metrics"):
		var metrics: Variant = battle.call("get_battlefield_metrics")
		if metrics != null and metrics.has_method("resolve_slots_distance"):
			return float(metrics.call("resolve_slots_distance", module_params, "radius_slots", 120.0))
	if module_params.has("radius_slots"):
		return float(module_params.get("radius_slots")) * 96.0
	return 120.0


func _manual_skill_tags(module_params: Dictionary) -> PackedStringArray:
	var raw_tags: Variant = module_params.get("damage_tags", PackedStringArray(["manual_skill"]))
	if raw_tags is PackedStringArray:
		return PackedStringArray(raw_tags)
	if raw_tags is Array:
		return PackedStringArray(raw_tags)
	return PackedStringArray(["manual_skill"])


func _find_runtime_entity_by_id(battle: Node, entity_id: int) -> Node:
	if entity_id < 0 or battle == null or not battle.has_method("get_runtime_combat_entities"):
		return null
	for entity in battle.call("get_runtime_combat_entities"):
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.has_method("get_entity_id") and int(entity.call("get_entity_id")) == entity_id:
			return entity
	return null


func _emit_manual_skill_rejected(module: Resource, source_entity: Node, reason: StringName) -> void:
	var rejected_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(source_entity, source_entity, null, PackedStringArray(["manual_skill", "reject"]))
	rejected_event.core["module_id"] = StringName(module.get("module_id"))
	rejected_event.core["reason"] = reason
	EventBus.push_event(&"entity.manual_skill_rejected", rejected_event)
