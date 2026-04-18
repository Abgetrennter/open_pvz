extends RefCounted
class_name BattleSubsystemHost

const BattleEconomyStateRef = preload("res://scripts/battle/battle_economy_state.gd")
const BattleCardStateRef = preload("res://scripts/battle/battle_card_state.gd")
const BattleBoardStateRef = preload("res://scripts/battle/battle_board_state.gd")
const BattleFlowStateRef = preload("res://scripts/battle/battle_flow_state.gd")
const BattleStatusStateRef = preload("res://scripts/battle/battle_status_state.gd")
const BattleFieldObjectStateRef = preload("res://scripts/battle/battle_field_object_state.gd")
const WaveRunnerRef = preload("res://scripts/battle/wave_runner.gd")

var _battle: Node = null
var _economy_state: Node = null
var _board_state: Node = null
var _card_state: Node = null
var _status_state: Node = null
var _field_object_state: Node = null
var _flow_state: Node = null
var _wave_runner: Node = null


func bind_battle(battle: Node) -> void:
	_battle = battle


func reset_runtime_services() -> void:
	_destroy_subsystems()
	_create_subsystems()
	_setup_subsystems()


func clear_runtime_entities(entity_root: Node2D, collectible_root: Node2D) -> void:
	if entity_root != null:
		for child in entity_root.get_children():
			entity_root.remove_child(child)
			child.queue_free()
	if collectible_root == null:
		return
	for child in collectible_root.get_children():
		collectible_root.remove_child(child)
		child.queue_free()


func get_runtime_entities(entity_root: Node2D, collectible_root: Node2D) -> Array:
	var runtime_nodes: Array = []
	if entity_root != null:
		runtime_nodes.append_array(entity_root.get_children())
	if collectible_root != null:
		runtime_nodes.append_array(collectible_root.get_children())
	for sub in [_economy_state, _board_state, _card_state, _status_state, _field_object_state, _flow_state, _wave_runner]:
		if sub != null and is_instance_valid(sub):
			runtime_nodes.append(sub)
	return runtime_nodes


func get_economy_state() -> Node:
	if _economy_state != null and is_instance_valid(_economy_state):
		return _economy_state
	return null


func get_board_state() -> Node:
	if _board_state != null and is_instance_valid(_board_state):
		return _board_state
	return null


func get_card_state() -> Node:
	if _card_state != null and is_instance_valid(_card_state):
		return _card_state
	return null


func get_status_state() -> Node:
	if _status_state != null and is_instance_valid(_status_state):
		return _status_state
	return null


func get_field_object_state() -> Node:
	if _field_object_state != null and is_instance_valid(_field_object_state):
		return _field_object_state
	return null


func get_flow_state() -> Node:
	if _flow_state != null and is_instance_valid(_flow_state):
		return _flow_state
	return null


func get_wave_runner() -> Node:
	if _wave_runner != null and is_instance_valid(_wave_runner):
		return _wave_runner
	return null


func _destroy_subsystems() -> void:
	for sub in [_economy_state, _board_state, _card_state, _status_state, _field_object_state, _flow_state, _wave_runner]:
		if sub != null and is_instance_valid(sub):
			_battle.remove_child(sub)
			sub.free()
	_economy_state = null
	_board_state = null
	_card_state = null
	_status_state = null
	_field_object_state = null
	_flow_state = null
	_wave_runner = null


func _create_subsystems() -> void:
	_economy_state = BattleEconomyStateRef.new()
	_economy_state.name = "BattleEconomyState"
	_battle.add_child(_economy_state)
	_board_state = BattleBoardStateRef.new()
	_board_state.name = "BattleBoardState"
	_battle.add_child(_board_state)
	_card_state = BattleCardStateRef.new()
	_card_state.name = "BattleCardState"
	_battle.add_child(_card_state)
	_status_state = BattleStatusStateRef.new()
	_status_state.name = "BattleStatusState"
	_battle.add_child(_status_state)
	_field_object_state = BattleFieldObjectStateRef.new()
	_field_object_state.name = "BattleFieldObjectState"
	_battle.add_child(_field_object_state)
	_flow_state = BattleFlowStateRef.new()
	_flow_state.name = "BattleFlowState"
	_battle.add_child(_flow_state)
	_wave_runner = WaveRunnerRef.new()
	_wave_runner.name = "WaveRunner"
	_battle.add_child(_wave_runner)


func _setup_subsystems() -> void:
	var active_scenario = _battle.resolve_scenario()
	if active_scenario == null:
		return
	var collectible_root: Node2D = _battle.get_collectible_root()
	if _economy_state != null:
		_economy_state.setup(_battle, collectible_root, active_scenario)
	if _board_state != null:
		_board_state.setup(_battle, active_scenario)
	if _card_state != null:
		_card_state.setup(_battle, active_scenario)
	if _status_state != null:
		_status_state.setup(_battle, active_scenario)
	if _field_object_state != null:
		_field_object_state.setup(_battle, active_scenario)
	if _flow_state != null:
		_flow_state.setup(_battle, active_scenario)
	if _wave_runner != null:
		_wave_runner.setup(_battle, _flow_state, active_scenario)
