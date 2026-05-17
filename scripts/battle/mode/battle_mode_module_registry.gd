extends RefCounted
class_name BattleModeModuleRegistry

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
