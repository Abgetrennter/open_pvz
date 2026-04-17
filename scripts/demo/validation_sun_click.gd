extends Node2D
class_name SunClickValidation

const BattleManagerRef = preload("res://scripts/battle/battle_manager.gd")

var _battle: Node2D = null
var _click_injected := false
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
		scenario = load("res://scenes/validation/sun_click_validation.tres")
	_battle = BattleManagerRef.new()
	_battle.name = "BattleManager"
	_battle.scenario = scenario
	_battle.show_debug_overlay = false
	_battle.allow_restart_input = false
	add_child(_battle)
	EventBus.subscribe(&"sun.spawned", Callable(self, "_on_sun_spawned"))
	EventBus.subscribe(&"sun.collected", Callable(self, "_on_sun_collected"))
	EventBus.subscribe(&"resource.changed", Callable(self, "_on_resource_changed"))


func _on_sun_spawned(event_data: Variant) -> void:
	if _click_injected:
		return
	_click_injected = true
	var sun_value := int(event_data.core.get("value"))
	if sun_value <= 0:
		return
	var sun_position: Vector2 = event_data.core.get("event_target").global_position
	_inject_click(sun_position)


func _on_sun_collected(event_data: Variant) -> void:
	var value := int(event_data.core.get("value"))
	if value > 0:
		_mark_passed("sun_collected_with_value_%d" % value)


func _on_resource_changed(event_data: Variant) -> void:
	var after := int(event_data.core.get("after"))
	var before := int(event_data.core.get("before"))
	if after > before and after > 0:
		_mark_passed("resource_increased_to_%d" % after)


func _inject_click(world_pos: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.position = world_pos
	click.global_position = world_pos
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_viewport().push_input(click)
	var release := InputEventMouseButton.new()
	release.position = world_pos
	release.global_position = world_pos
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	get_viewport().push_input(release)


func _mark_passed(reason: String) -> void:
	if _validation_passed or _validation_failed:
		return
	_validation_passed = true
	var report := {"scenario_id": "sun_click_validation", "status": "passed", "reason": reason}
	_print_report(report)
	_auto_quit()


func _mark_failed(reason: String) -> void:
	if _validation_passed or _validation_failed:
		return
	_validation_failed = true
	var report := {"scenario_id": "sun_click_validation", "status": "failed", "reason": reason}
	_print_report(report)
	_auto_quit()


func _print_report(report: Dictionary) -> void:
	print("[Validation] %s %s (%s)" % [report.status.to_upper(), "Sun Click Validation", report.scenario_id])
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
			if GameState.current_time > 12.0:
				_mark_failed("timeout_waiting_for_sun_collection")
