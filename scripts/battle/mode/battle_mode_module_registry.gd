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
			pass
		&"on_event":
			var event_name := StringName(context.get("event_name", StringName()))
			var event_data: Variant = context.get("event_data", null)
			if event_data == null:
				return
			var mode_host: Node = battle.call("get_mode_host") if battle != null and battle.has_method("get_mode_host") else null
			if mode_host == null:
				return
			var module_params: Dictionary = {}
			var raw_params: Variant = module.get("params")
			if raw_params is Dictionary:
				module_params = raw_params
			var resolved_input_profile: Resource = mode_host.call("get_resolved_input_profile")
			if resolved_input_profile != null and not bool(resolved_input_profile.get("enable_manual_skill")):
				return
			var selected_key := StringName(module_params.get("selection_state_key", &"manual_skill_selected_entity_id"))
			if event_name == &"input.action.entity_clicked":
				mode_host.call("set_runtime_value", selected_key, int(event_data.core.get("entity_id", -1)))
				var selection_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(null, null, null, PackedStringArray(["mode", "selection"]))
				selection_event.core["module_id"] = StringName(module.get("module_id"))
				selection_event.core["selected_entity_id"] = int(event_data.core.get("entity_id", -1))
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
		&"on_mode_teardown":
			pass
