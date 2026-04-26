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
	match action:
		&"on_mode_setup":
			pass
		&"on_battle_start":
			pass
		&"on_game_tick":
			pass
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
			if event_name != &"placement.accepted" or event_data == null:
				return
			var mode_host: Node = battle.call("get_mode_host") if battle != null and battle.has_method("get_mode_host") else null
			if mode_host == null:
				return
			var module_params: Dictionary = {}
			var raw_params: Variant = module.get("params")
			if raw_params is Dictionary:
				module_params = raw_params
			var score_key := StringName(module_params.get("score_key", &"score"))
			var score_gain := int(module_params.get("score_gain", 1))
			mode_host.call("increment_objective_progress", score_key, score_gain)
			var current_score := int(mode_host.call("get_objective_progress", score_key))
			var mode_event: Variant = preload("res://scripts/core/runtime/event_data.gd").create(null, null, null, PackedStringArray(["mode", "rule"]))
			mode_event.core["module_id"] = StringName(module.get("module_id"))
			mode_event.core["source_event"] = event_name
			mode_event.core["score_key"] = score_key
			mode_event.core["score_gain"] = score_gain
			mode_event.core["current_score"] = current_score
			EventBus.push_event(&"battle.mode_rule_applied", mode_event)
		&"on_mode_teardown":
			pass
