extends Node2D
class_name DemoBattleScene

const BattleManagerRef = preload("res://scripts/battle/battle_manager.gd")
const InputRouterRef = preload("res://scripts/input/input_router.gd")
const BattleHUDRef = preload("res://scripts/ui/battle_hud.gd")
const BoardOverlayRef = preload("res://scripts/ui/panels/board_overlay.gd")
const CardBarRef = preload("res://scripts/ui/panels/card_bar.gd")
const PhaseScreenRef = preload("res://scripts/ui/screens/phase_screen.gd")
const SunCounterRef = preload("res://scripts/ui/panels/sun_counter.gd")
const WaveProgressRef = preload("res://scripts/ui/panels/wave_progress.gd")

const DEMO_LANE_Y := {
	0: 185.0,
	1: 245.0,
	2: 305.0,
	3: 365.0,
	4: 425.0,
}

@export var scenario: Resource = null
@export var lane_count := 5
@export var slot_count := 9
@export var cell_size := Vector2(80.0, 56.0)

var _battle: Node2D = null
var _board_visual: Node2D = null
var _battle_hud: Control = null
var _card_bar: Control = null
var _sun_counter: Control = null
var _wave_indicator: Control = null
var _input_router: Node = null
var _result_overlay: CanvasLayer = null


func _ready() -> void:
	_spawn_battle()
	_spawn_demo_ui()
	_wire_input()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_restart()
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _restart() -> void:
	_teardown_ui()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_spawn_battle()
	_spawn_demo_ui()
	_wire_input()


func _exit_tree() -> void:
	_teardown_ui()


func _spawn_battle() -> void:
	_battle = BattleManagerRef.new()
	_battle.name = "BattleManager"
	_battle.scenario = scenario
	_battle.show_debug_overlay = false
	_battle.allow_restart_input = false
	add_child(_battle)


func _spawn_demo_ui() -> void:
	var hud_canvas := CanvasLayer.new()
	hud_canvas.layer = 50
	add_child(hud_canvas)

	_battle_hud = BattleHUDRef.new()
	_battle_hud.name = "BattleHUD"
	_battle_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_canvas.add_child(_battle_hud)

	_card_bar = CardBarRef.new()
	_card_bar.name = "CardBar"
	_card_bar.set_anchor(SIDE_LEFT, 0.0)
	_card_bar.set_anchor(SIDE_RIGHT, 1.0)
	_card_bar.set_anchor(SIDE_TOP, 0.0)
	_card_bar.set_anchor(SIDE_BOTTOM, 0.0)
	_card_bar.offset_top = 4.0
	_card_bar.offset_left = 220.0
	_card_bar.offset_bottom = 100.0
	_battle_hud.add_child(_card_bar)

	_sun_counter = SunCounterRef.new()
	_sun_counter.name = "SunCounter"
	_sun_counter.offset_left = 100.0
	_sun_counter.offset_top = 10.0
	_sun_counter.offset_bottom = 50.0
	_battle_hud.add_child(_sun_counter)

	_wave_indicator = WaveProgressRef.new()
	_wave_indicator.name = "WaveProgress"
	_wave_indicator.set_anchor(SIDE_LEFT, 0.0)
	_wave_indicator.set_anchor(SIDE_RIGHT, 0.0)
	_wave_indicator.set_anchor(SIDE_TOP, 0.0)
	_wave_indicator.set_anchor(SIDE_BOTTOM, 0.0)
	_wave_indicator.offset_left = 750.0
	_wave_indicator.offset_top = 10.0
	_wave_indicator.offset_right = 950.0
	_wave_indicator.offset_bottom = 50.0
	_battle_hud.add_child(_wave_indicator)

	_result_overlay = PhaseScreenRef.new()
	_result_overlay.name = "PhaseScreen"
	add_child(_result_overlay)

	_board_visual = BoardOverlayRef.new()
	_board_visual.name = "BoardOverlay"
	add_child(_board_visual)


func _wire_input() -> void:
	var active_scenario = _battle.call("_resolve_scenario")
	if active_scenario == null:
		return
	var board_state = _battle.get_node_or_null("BattleBoardState")
	var card_state = _battle.get_node_or_null("BattleCardState")
	var flow_state = _battle.get_node_or_null("BattleFlowState")
	_board_visual.call("setup", board_state, lane_count, slot_count, cell_size)
	if _battle_hud != null and is_instance_valid(_battle_hud) and _battle_hud.has_method("setup"):
		_battle_hud.call("setup", _battle, active_scenario)
	if _result_overlay != null and is_instance_valid(_result_overlay) and _result_overlay.has_method("screen_setup"):
		_result_overlay.call("screen_setup", _battle)

	_input_router = InputRouterRef.new()
	_input_router.name = "InputRouter"
	add_child(_input_router)
	var mode_host: Node = _battle.call("get_mode_host")
	var input_profile: Resource = null
	if mode_host != null and mode_host.has_method("get_resolved_input_profile"):
		input_profile = mode_host.call("get_resolved_input_profile")
	_input_router.call("setup", _card_bar, _board_visual, card_state, flow_state, input_profile)


func _teardown_ui() -> void:
	if _battle_hud != null and is_instance_valid(_battle_hud) and _battle_hud.has_method("teardown"):
		_battle_hud.call("teardown")
	if _board_visual != null and is_instance_valid(_board_visual) and _board_visual.has_method("teardown"):
		_board_visual.call("teardown")
	if _result_overlay != null and is_instance_valid(_result_overlay) and _result_overlay.has_method("screen_teardown"):
		_result_overlay.call("screen_teardown")
	if _input_router != null and is_instance_valid(_input_router) and _input_router.has_method("teardown"):
		_input_router.call("teardown")
