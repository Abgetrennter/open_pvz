extends Node2D
class_name DemoBattleScene

const BattleManagerRef = preload("res://scripts/battle/battle_manager.gd")
const BoardVisualRef = preload("res://scripts/demo/board_visual.gd")
const CardBarRef = preload("res://scripts/demo/card_bar.gd")
const SunCounterRef = preload("res://scripts/demo/sun_counter.gd")
const WaveIndicatorRef = preload("res://scripts/demo/wave_indicator.gd")
const InputBridgeRef = preload("res://scripts/demo/input_bridge.gd")
const BattleResultOverlayRef = preload("res://scripts/demo/battle_result_overlay.gd")

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
var _card_bar: Control = null
var _sun_counter: Control = null
var _wave_indicator: Control = null
var _input_bridge: Node = null
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
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_spawn_battle()
	_spawn_demo_ui()
	_wire_input()


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

	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_canvas.add_child(hud_root)

	_card_bar = CardBarRef.new()
	_card_bar.name = "CardBar"
	_card_bar.set_anchor(SIDE_LEFT, 0.0)
	_card_bar.set_anchor(SIDE_RIGHT, 1.0)
	_card_bar.set_anchor(SIDE_TOP, 0.0)
	_card_bar.set_anchor(SIDE_BOTTOM, 0.0)
	_card_bar.offset_top = 4.0
	_card_bar.offset_left = 220.0
	_card_bar.offset_bottom = 100.0
	hud_root.add_child(_card_bar)

	_sun_counter = SunCounterRef.new()
	_sun_counter.name = "SunCounter"
	_sun_counter.offset_left = 100.0
	_sun_counter.offset_top = 10.0
	_sun_counter.offset_bottom = 50.0
	hud_root.add_child(_sun_counter)

	_wave_indicator = WaveIndicatorRef.new()
	_wave_indicator.name = "WaveIndicator"
	_wave_indicator.set_anchor(SIDE_LEFT, 0.0)
	_wave_indicator.set_anchor(SIDE_RIGHT, 0.0)
	_wave_indicator.set_anchor(SIDE_TOP, 0.0)
	_wave_indicator.set_anchor(SIDE_BOTTOM, 0.0)
	_wave_indicator.offset_left = 750.0
	_wave_indicator.offset_top = 10.0
	_wave_indicator.offset_right = 950.0
	_wave_indicator.offset_bottom = 50.0
	hud_root.add_child(_wave_indicator)

	_result_overlay = BattleResultOverlayRef.new()
	_result_overlay.name = "ResultOverlay"
	add_child(_result_overlay)

	_board_visual = BoardVisualRef.new()
	_board_visual.name = "BoardVisual"
	add_child(_board_visual)


func _wire_input() -> void:
	var active_scenario = _battle.call("_resolve_scenario")
	if active_scenario == null:
		return
	var board_state = _battle.get_node_or_null("BattleBoardState")
	var card_state = _battle.get_node_or_null("BattleCardState")
	var flow_state = _battle.get_node_or_null("BattleFlowState")

	_board_visual.call("setup", board_state, lane_count, slot_count, cell_size)
	_card_bar.call("setup", active_scenario)
	_sun_counter.call("setup", active_scenario)
	_wave_indicator.call("setup", active_scenario)
	_result_overlay.call("setup", flow_state)

	_input_bridge = InputBridgeRef.new()
	_input_bridge.name = "InputBridge"
	add_child(_input_bridge)
	_input_bridge.call("setup", _card_bar, _board_visual, card_state, flow_state)
