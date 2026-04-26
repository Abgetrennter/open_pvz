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
			pass
		&"on_mode_teardown":
			pass
