extends "res://scripts/entities/base_entity.gd"
class_name ProjectileRoot

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")
const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")

@onready var movement_component: Variant = get_node_or_null("MovementComponent")
@onready var hitbox_component: Variant = get_node_or_null("HitboxComponent")

@export var lifetime := 5.0

var owner_entity: Node = null
var on_hit_effect = null
var damage := 10
var _age := 0.0
var _launch_direction := Vector2.ZERO
var _launch_speed := 0.0
var _spawn_event_emitted := false
var _consumed := false


func _ready() -> void:
	entity_kind = &"projectile"
	super()
	if hitbox_component != null:
		hitbox_component.hit.connect(_on_hit)
	if movement_component != null and _launch_speed > 0.0:
		movement_component.velocity = _launch_direction.normalized() * _launch_speed
	if owner_entity != null and not _spawn_event_emitted:
		_emit_spawn_event()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	if movement_component != null:
		movement_component.physics_process_movement(self, delta)

	if _age >= lifetime:
		_expire()


func launch(direction: Vector2, speed: float, source_node: Node = null, on_hit = null, projectile_damage: int = 10) -> void:
	owner_entity = source_node
	on_hit_effect = on_hit
	damage = projectile_damage
	_launch_direction = direction
	_launch_speed = speed
	if source_node != null:
		var source_team: Variant = source_node.get("team")
		if source_team is StringName:
			team = source_team
		elif source_team is String:
			team = StringName(source_team)
		else:
			team = &"neutral"
		var source_lane: Variant = source_node.get("lane_id")
		if source_lane is int:
			assign_lane(source_lane)
	else:
		team = &"neutral"
	if movement_component != null:
		movement_component.velocity = _launch_direction.normalized() * _launch_speed
	if is_inside_tree() and not _spawn_event_emitted:
		_emit_spawn_event()


func _on_hit(target: Node) -> void:
	if _consumed:
		return
	if target == null or target == self or target == owner_entity:
		return
	if target.has_method("get") and target.get("team") == team:
		return
	_consumed = true

	var hit_event = EventDataRef.create(owner_entity, target, damage, PackedStringArray(["projectile"]))
	hit_event.runtime["depth"] = 2
	EventBus.push_event(&"projectile.hit", hit_event)

	if on_hit_effect != null:
		var context = RuleContextRef.from_event_data(&"projectile.hit", hit_event, self)
		context.source_node = owner_entity
		context.target_node = target
		EffectExecutorRef.execute_node(on_hit_effect, context)
	elif target != null and target.has_method("take_damage"):
		target.call("take_damage", damage, owner_entity, PackedStringArray(["projectile"]))

	queue_free()


func _expire() -> void:
	var expired_event = EventDataRef.create(owner_entity, self, 0, PackedStringArray(["projectile", "expired"]))
	expired_event.runtime["depth"] = 1
	EventBus.push_event(&"projectile.expired", expired_event)
	queue_free()


func _emit_spawn_event() -> void:
	_spawn_event_emitted = true
	var spawned_event = EventDataRef.create(owner_entity, self, damage, PackedStringArray(["projectile"]))
	EventBus.push_event(&"projectile.spawned", spawned_event)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color("f2c94c"))
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 12, Color("7b4f12"), 2.0)
