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
	projectile.launch(direction, speed, context.source_node, on_hit_effect, damage)
	add_child(projectile)
	return projectile


func _spawn_debug_demo() -> void:
	_spawn_demo_plant(0, 160.0, 1.4, 20, 220.0)
	_spawn_demo_plant(0, 250.0, 2.1, 15, 210.0)
	_spawn_demo_plant(1, 160.0, 1.6, 20, 220.0)

	_spawn_demo_zombie(0, 460.0)
	_spawn_demo_zombie(0, 650.0)
	_spawn_demo_zombie(1, 520.0)


func _spawn_demo_plant(lane_id: int, x_position: float, interval: float, damage: int, speed: float) -> void:
	var plant: Variant = _entity_factory.create_plant(Vector2(x_position, _lane_y(lane_id)))
	plant.assign_lane(lane_id)
	add_child(plant)
	_bind_shooter_trigger(plant, interval, damage, speed)


func _spawn_demo_zombie(lane_id: int, x_position: float) -> void:
	var zombie: Variant = _entity_factory.create_zombie(Vector2(x_position, _lane_y(lane_id)))
	zombie.assign_lane(lane_id)
	add_child(zombie)


func _bind_shooter_trigger(plant: Node, interval: float, damage: int, speed: float) -> void:
	var on_hit: Variant = EffectNodeRef.new(&"damage", {
		"amount": damage,
		"target_mode": &"context_target",
	})
	var root_effect: Variant = EffectNodeRef.new(&"spawn_projectile", {
		"speed": speed,
		"direction": Vector2.RIGHT,
		"damage": damage,
	}, {
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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, playfield_size), Color("d5f0b1"))
	draw_rect(Rect2(Vector2(0, 150), Vector2(playfield_size.x, 240)), Color("b4dd7f"))
	draw_line(Vector2(80, _lane_y(0)), Vector2(playfield_size.x - 80, _lane_y(0)), Color("6f9d53"), 2.0)
	draw_line(Vector2(80, _lane_y(1)), Vector2(playfield_size.x - 80, _lane_y(1)), Color("6f9d53"), 2.0)
	draw_line(Vector2(80, 270), Vector2(playfield_size.x - 80, 270), Color("8db768"), 1.0)


func _lane_y(lane_id: int) -> float:
	return float(LANE_Y.get(lane_id, 220.0))
