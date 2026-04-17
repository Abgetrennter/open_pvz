extends Node2D
class_name CardPlaceValidation

const BattleManagerRef = preload("res://scripts/battle/battle_manager.gd")
const BoardVisualRef = preload("res://scripts/demo/board_visual.gd")
const CardBarRef = preload("res://scripts/demo/card_bar.gd")
const InputBridgeRef = preload("res://scripts/demo/input_bridge.gd")
const SunCounterRef = preload("res://scripts/demo/sun_counter.gd")
const WaveIndicatorRef = preload("res://scripts/demo/wave_indicator.gd")

var _battle: Node2D = null
var _card_bar: Control = null
var _board_visual: Node2D = null
var _input_bridge: Node = null
var _card_clicked := false
var _validation_passed := false
var _validation_failed := false


func _ready() -> void:
	var scenario: Resource = null
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg.begins_with("--validation-scenario="):
			var path := arg.substr(22)
			scenario = load(path)
			break
	if scenario == null:
		scenario = load("res://scenes/validation/card_place_validation.tres")
	_battle = BattleManagerRef.new()
	_battle.name = "BattleManager"
	_battle.scenario = scenario
	_battle.show_debug_overlay = false
	_battle.allow_restart_input = false
	add_child(_battle)
	EventBus.subscribe(&"game.tick", Callable(self, "_on_game_tick"))
	EventBus.subscribe(&"entity.spawned", Callable(self, "_on_entity_spawned"))
	EventBus.subscribe(&"placement.accepted", Callable(self, "_on_placement_accepted"))
	EventBus.subscribe(&"card.play_rejected", Callable(self, "_on_card_rejected"))
	yield(get_tree().create_timer(0.5), "timeout")
	_setup_demo_ui(scenario)


func _setup_demo_ui(scenario: Resource) -> void:
	var board_state = _battle.get_node_or_null("BattleBoardState")
	var card_state = _battle.get_node_or_null("BattleCardState")
	var flow_state = _battle.get_node_or_null("BattleFlowState")
	_board_visual = BoardVisualRef.new()
	_board_visual.name = "BoardVisual"
	add_child(_board_visual)
	_board_visual.call("setup", board_state, 2, 5, Vector2(80.0, 56.0))
	_card_bar = CardBarRef.new()
	_card_bar.name = "CardBar"
	add_child(_card_bar)
	_card_bar.call("setup", scenario)
	_input_bridge = InputBridgeRef.new()
	_input_bridge.name = "InputBridge"
	add_child(_input_bridge)
	_input_bridge.call("setup", _card_bar, _board_visual, card_state, flow_state)


func _on_game_tick(_event_data: Variant) -> void:
	if _card_clicked:
		return
	if _card_bar == null or not is_instance_valid(_card_bar):
		return
	if _card_bar.call("get_selected_card_id") != StringName():
		return
	if not _card_bar.has_method("_on_slot_input"):
		return
	yield(get_tree().create_timer(0.3), "timeout")
	_inject_card_click()


func _inject_card_click() -> void:
	if _card_clicked:
		return
	_card_clicked = true
	var click := InputEventMouseButton.new()
	click.position = Vector2(300.0, 50.0)
	click.global_position = Vector2(300.0, 50.0)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_viewport().push_input(click)
	var release := InputEventMouseButton.new()
	release.position = Vector2(300.0, 50.0)
	release.global_position = Vector2(300.0, 50.0)
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	get_viewport().push_input(release)
	yield(get_tree().create_timer(0.3), "timeout")
	if _card_bar.call("get_selected_card_id") != StringName():
		_inject_cell_click()
	else:
		_mark_failed("card_not_selected_after_click")


func _inject_cell_click() -> void:
	var cell_pos := Vector2(280.0, 220.0)
	var click := InputEventMouseButton.new()
	click.position = cell_pos
	click.global_position = cell_pos
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_viewport().push_input(click)
	var release := InputEventMouseButton.new()
	release.position = cell_pos
	release.global_position = cell_pos
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	get_viewport().push_input(release)


func _on_entity_spawned(event_data: Variant) -> void:
	var spawn_reason = event_data.core.get("spawn_reason")
	if spawn_reason == &"card_play":
		var template_id := StringName(event_data.core.get("template_id"))
		if template_id != StringName():
			_mark_passed("entity_spawned_from_card_%s" % String(template_id))


func _on_placement_accepted(_event_data: Variant) -> void:
	pass


func _on_card_rejected(event_data: Variant) -> void:
	_mark_failed("card_play_rejected: %s" % str(event_data.core))


func _mark_passed(reason: String) -> void:
	if _validation_passed or _validation_failed:
		return
	_validation_passed = true
	var report := {"scenario_id": "card_place_validation", "status": "passed", "reason": reason}
	_print_report(report)
	_auto_quit()


func _mark_failed(reason: String) -> void:
	if _validation_passed or _validation_failed:
		return
	_validation_failed = true
	var report := {"scenario_id": "card_place_validation", "status": "failed", "reason": reason}
	_print_report(report)
	_auto_quit()


func _print_report(report: Dictionary) -> void:
	print("[Validation] %s %s (%s)" % [report.status.to_upper(), "Card Place Validation", report.scenario_id])
	print("[Validation] Reason: %s" % report.reason)


func _auto_quit() -> void:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg == "--validation-auto-quit":
			get_tree().quit()
			return
	yield(get_tree().create_timer(1.0), "timeout")


func _process(_delta: float) -> void:
	if not _validation_passed and not _validation_failed:
		if _battle != null and is_instance_valid(_battle):
			if GameState.current_time > 15.0:
				_mark_failed("timeout_waiting_for_card_placement")
