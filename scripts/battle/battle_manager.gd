extends Node2D
class_name BattleManager

const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EffectNodeRef = preload("res://scripts/core/runtime/effect_node.gd")
const TriggerInstanceRef = preload("res://scripts/core/runtime/trigger_instance.gd")
const DebugOverlayRef = preload("res://scripts/debug/debug_overlay.gd")

const LANE_Y := {
	0: 220.0,
	1: 320.0,
}

@export var tick_interval := 0.25
@export var playfield_size := Vector2(960.0, 540.0)

var _tick_accumulator := 0.0
var _entity_factory: Variant = EntityFactoryRef.new()


func _ready() -> void:
	GameState.current_battle = self
	queue_redraw()
	_spawn_debug_overlay()
	_spawn_debug_demo()


func _exit_tree() -> void:
	if GameState.current_battle == self:
		GameState.current_battle = null


func _process(delta: float) -> void:
	GameState.advance_time(delta)
	_tick_accumulator += delta

	while _tick_accumulator >= tick_interval:
		_tick_accumulator -= tick_interval
		var tick_event: Variant = EventDataRef.create()
		tick_event.core["game_time"] = GameState.current_time
		EventBus.push_event(&"game.tick", tick_event)


func spawn_projectile_from_effect(context, params: Dictionary, on_hit_effect = null) -> Node:
	var direction := Vector2.RIGHT
	var direction_value: Variant = params.get("direction", Vector2.RIGHT)
	if direction_value is Vector2:
		direction = direction_value

	var spawn_position: Vector2 = context.position
	if context.source_node != null and context.source_node is Node2D:
		spawn_position = context.source_node.global_position + direction.normalized() * 34.0

	var projectile: Variant = _entity_factory.create_projectile(spawn_position)
	var speed := float(params.get("speed", 300.0))
	var damage := int(params.get("damage", 10))
	var movement_params: Dictionary = _build_projectile_movement_params(context, params, spawn_position, direction, speed)
	projectile.launch(direction, speed, context.source_node, on_hit_effect, damage, movement_params)
	add_child(projectile)
	return projectile


func _spawn_debug_demo() -> void:
	_spawn_demo_plant(0, 160.0, 1.4, 20, 220.0)
	_spawn_demo_plant(0, 250.0, 2.1, 15, 210.0, {
		"movement_mode": &"track",
		"turn_rate": 5.5,
	})
	_spawn_demo_plant(1, 160.0, 1.6, 20, 220.0, {
		"movement_mode": &"parabola",
		"arc_height": 180.0,
		"travel_duration": 1.4,
	})

	_spawn_demo_zombie(0, 460.0)
	_spawn_demo_zombie(0, 650.0)
	_spawn_demo_zombie(1, 520.0)


func _spawn_demo_plant(lane_id: int, x_position: float, interval: float, damage: int, speed: float, effect_overrides: Dictionary = {}) -> void:
	var plant: Variant = _entity_factory.create_plant(Vector2(x_position, _lane_y(lane_id)))
	plant.assign_lane(lane_id)
	add_child(plant)
	_bind_shooter_trigger(plant, interval, damage, speed, effect_overrides)


func _spawn_demo_zombie(lane_id: int, x_position: float) -> void:
	var zombie: Variant = _entity_factory.create_zombie(Vector2(x_position, _lane_y(lane_id)))
	zombie.assign_lane(lane_id)
	add_child(zombie)


func _bind_shooter_trigger(plant: Node, interval: float, damage: int, speed: float, effect_overrides: Dictionary = {}) -> void:
	var on_hit: Variant = EffectNodeRef.new(&"damage", {
		"amount": damage,
		"target_mode": &"context_target",
	})
	var root_params: Dictionary = {
		"speed": speed,
		"direction": Vector2.RIGHT,
		"damage": damage,
	}
	for key: Variant in effect_overrides.keys():
		root_params[key] = effect_overrides[key]
	var root_effect: Variant = EffectNodeRef.new(&"spawn_projectile", root_params, {
		&"on_hit": on_hit,
	})

	var trigger: Variant = TriggerInstanceRef.new()
	trigger.def_id = &"periodically"
	trigger.event_name = &"game.tick"
	trigger.condition_values = {"interval": interval}
	trigger.effect_roots = [root_effect]

	if plant.get("trigger_component") != null:
		plant.get("trigger_component").bind_triggers([trigger])


func _spawn_debug_overlay() -> void:
	var overlay: Variant = DebugOverlayRef.new()
	add_child(overlay)
	overlay.bind_battle_root(self)


func _build_projectile_movement_params(context, params: Dictionary, spawn_position: Vector2, direction: Vector2, speed: float) -> Dictionary:
	var movement_params: Dictionary = {
		"move_mode": StringName(params.get("movement_mode", &"linear")),
	}
	var move_mode: StringName = movement_params["move_mode"]

	match move_mode:
		&"parabola":
			movement_params["start_position"] = spawn_position
			movement_params["target_position"] = _resolve_projectile_target_position(context, params, spawn_position, direction)
			movement_params["travel_duration"] = float(params.get("travel_duration", max(0.35, 360.0 / max(speed, 1.0))))
			movement_params["arc_height"] = float(params.get("arc_height", 72.0))
		&"track":
			movement_params["target_node"] = _resolve_projectile_target_node(context)
			movement_params["turn_rate"] = float(params.get("turn_rate", 6.0))
		_:
			pass

	return movement_params


func _resolve_projectile_target_position(context, params: Dictionary, spawn_position: Vector2, direction: Vector2) -> Vector2:
	var explicit_target: Variant = params.get("target_position", null)
	if explicit_target is Vector2:
		return explicit_target

	var target_node: Node2D = _resolve_projectile_target_node(context)
	if target_node != null:
		return target_node.global_position

	var distance := float(params.get("distance", 280.0))
	return spawn_position + direction.normalized() * distance


func _resolve_projectile_target_node(context) -> Node2D:
	if context.target_node is Node2D:
		return context.target_node as Node2D
	if context.source_node == null:
		return null
	return _find_nearest_enemy(context.source_node)


func _find_nearest_enemy(source_node: Node) -> Node2D:
	if not (source_node is Node2D):
		return null

	var source_team: Variant = source_node.get("team")
	var source_lane: Variant = source_node.get("lane_id")
	var source_position: Vector2 = (source_node as Node2D).global_position
	var best_candidate: Node2D = null
	var best_distance := INF

	for child in get_children():
		if child == null or child == source_node:
			continue
		if not child.has_method("take_damage"):
			continue
		if not (child is Node2D):
			continue
		if child.get("team") == source_team:
			continue
		if source_lane is int and child.get("lane_id") != source_lane:
			continue

		var candidate := child as Node2D
		var distance := source_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best_candidate = candidate

	return best_candidate


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, playfield_size), Color("d5f0b1"))
	draw_rect(Rect2(Vector2(0, 150), Vector2(playfield_size.x, 240)), Color("b4dd7f"))
	draw_line(Vector2(80, _lane_y(0)), Vector2(playfield_size.x - 80, _lane_y(0)), Color("6f9d53"), 2.0)
	draw_line(Vector2(80, _lane_y(1)), Vector2(playfield_size.x - 80, _lane_y(1)), Color("6f9d53"), 2.0)
	draw_line(Vector2(80, 270), Vector2(playfield_size.x - 80, 270), Color("8db768"), 1.0)


func _lane_y(lane_id: int) -> float:
	return float(LANE_Y.get(lane_id, 220.0))
