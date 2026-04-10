extends Node2D
class_name BattleManager

const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const EffectNodeRef = preload("res://scripts/core/runtime/effect_node.gd")
const TriggerInstanceRef = preload("res://scripts/core/runtime/trigger_instance.gd")

@export var tick_interval := 0.25
@export var playfield_size := Vector2(960.0, 540.0)

var _tick_accumulator := 0.0
var _entity_factory: Variant = EntityFactoryRef.new()


func _ready() -> void:
	GameState.current_battle = self
	queue_redraw()
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
	var projectile: Variant = _entity_factory.create_projectile(context.position)

	var direction := Vector2.RIGHT
	var direction_value: Variant = params.get("direction", Vector2.RIGHT)
	if direction_value is Vector2:
		direction = direction_value

	var speed := float(params.get("speed", 300.0))
	var damage := int(params.get("damage", 10))
	projectile.launch(direction, speed, context.source_node, on_hit_effect, damage)
	add_child(projectile)
	return projectile


func _spawn_debug_demo() -> void:
	var plant: Variant = _entity_factory.create_plant(Vector2(160, 220))
	var zombie: Variant = _entity_factory.create_zombie(Vector2(640, 220))
	add_child(plant)
	add_child(zombie)

	var on_hit: Variant = EffectNodeRef.new(&"damage", {
		"amount": 20,
		"target_mode": &"context_target",
	})
	var root_effect: Variant = EffectNodeRef.new(&"spawn_projectile", {
		"speed": 220.0,
		"direction": Vector2.RIGHT,
		"damage": 20,
	}, {
		&"on_hit": on_hit,
	})

	var trigger: Variant = TriggerInstanceRef.new()
	trigger.def_id = &"periodically"
	trigger.event_name = &"game.tick"
	trigger.condition_values = {"interval": 1.5}
	trigger.effect_roots = [root_effect]

	if plant.trigger_component != null:
		plant.trigger_component.bind_triggers([trigger])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, playfield_size), Color("d5f0b1"))
	draw_rect(Rect2(Vector2(0, 150), Vector2(playfield_size.x, 140)), Color("b4dd7f"))
	draw_line(Vector2(80, 220), Vector2(playfield_size.x - 80, 220), Color("6f9d53"), 2.0)
	draw_line(Vector2(80, 280), Vector2(playfield_size.x - 80, 280), Color("6f9d53"), 2.0)
