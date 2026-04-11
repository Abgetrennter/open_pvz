extends "res://scripts/entities/base_entity.gd"
class_name ProjectileRoot

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")
const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")
const ProjectileMovementLinearRef = preload("res://scripts/projectile/movement/projectile_movement_linear.gd")
const ProjectileMovementParabolaRef = preload("res://scripts/projectile/movement/projectile_movement_parabola.gd")
const ProjectileMovementTrackRef = preload("res://scripts/projectile/movement/projectile_movement_track.gd")

@onready var movement_component: Variant = get_node_or_null("MovementComponent")
@onready var hitbox_component: Variant = get_node_or_null("HitboxComponent")

@export var lifetime := 5.0

const PROJECTILE_COLOR_LINEAR := Color("f2c94c")
const PROJECTILE_COLOR_TRACK := Color("5cc8ff")
const PROJECTILE_COLOR_PARABOLA := Color("ff8a3d")
const PROJECTILE_OUTLINE_COLOR := Color("7b4f12")

var owner_entity: Node = null
var on_hit_effect = null
var damage := 10
var _age := 0.0
var _launch_direction := Vector2.ZERO
var _launch_speed := 0.0
var _spawn_event_emitted := false
var _consumed := false
var _move_mode: StringName = &"linear"
var _runtime_overrides: Dictionary = {}
var _impact_radius := 20.0


func _ready() -> void:
	entity_kind = &"projectile"
	super()
	set_status(&"flying")
	movement_component = get_node_or_null("MovementComponent")
	_enforce_single_movement_component(movement_component)
	if hitbox_component != null:
		hitbox_component.hit.connect(_on_hit)
	if owner_entity != null and not _spawn_event_emitted:
		_emit_spawn_event()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	if movement_component != null:
		var still_active: bool = movement_component.physics_process_projectile_move(delta)
		if not still_active and not _consumed:
			if _move_mode == &"parabola":
				var landing_target: Node = _find_terminal_hit_target()
				if landing_target != null:
					_on_hit(landing_target)
					return
			_expire()
			return

	if _age >= lifetime:
		_expire()


func launch(
	direction: Vector2,
	speed: float,
	source_node: Node = null,
	on_hit = null,
	projectile_damage: int = 10,
	movement_params: Dictionary = {},
	runtime_overrides: Dictionary = {}
) -> void:
	owner_entity = source_node
	on_hit_effect = on_hit
	damage = projectile_damage
	_runtime_overrides = runtime_overrides.duplicate(true)
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
	_ensure_movement_component(StringName(movement_params.get("move_mode", &"linear")))
	if movement_component != null:
		var full_movement_params: Dictionary = movement_params.duplicate(true)
		full_movement_params["direction"] = _launch_direction
		full_movement_params["speed"] = _launch_speed
		full_movement_params["move_mode"] = StringName(full_movement_params.get("move_mode", &"linear"))
		_move_mode = full_movement_params["move_mode"]
		_impact_radius = float(full_movement_params.get("impact_radius", 20.0))
		full_movement_params["start_position"] = global_position
		movement_component.configure_movement(full_movement_params)
		queue_redraw()
	set_state_value(&"damage", damage)
	set_state_value(&"move_mode", _move_mode)
	set_state_value(&"owner_id", -1 if owner_entity == null or not owner_entity.has_method("get_entity_id") else int(owner_entity.call("get_entity_id")))
	sync_runtime_state()
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

	var hit_runtime := _runtime_overrides.duplicate(true)
	hit_runtime["depth"] = int(hit_runtime.get("depth", 1)) + 1
	var hit_event = EventDataRef.create(owner_entity, target, damage, PackedStringArray(["projectile"]), hit_runtime)
	hit_event.core["move_mode"] = _move_mode
	EventBus.push_event(&"projectile.hit", hit_event)

	if on_hit_effect != null:
		var context = RuleContextRef.from_event_data(&"projectile.hit", hit_event, self)
		context.source_node = owner_entity
		context.target_node = target
		EffectExecutorRef.execute_node(on_hit_effect, context)
	elif target != null and target.has_method("take_damage"):
		target.call("take_damage", damage, owner_entity, PackedStringArray(["projectile"]), {
			"depth": int(hit_event.runtime.get("depth", 1)) + 1,
			"chain_id": str(hit_event.runtime.get("chain_id", "")),
			"origin_event_name": &"projectile.hit",
		})

	set_status(&"consumed")
	sync_runtime_state()
	queue_free()


func _expire() -> void:
	_consumed = true
	set_status(&"expired")
	sync_runtime_state()
	var expired_runtime := _runtime_overrides.duplicate(true)
	expired_runtime["depth"] = int(expired_runtime.get("depth", 1)) + 1
	var expired_event = EventDataRef.create(owner_entity, self, 0, PackedStringArray(["projectile", "expired"]), expired_runtime)
	expired_event.core["move_mode"] = _move_mode
	EventBus.push_event(&"projectile.expired", expired_event)
	queue_free()


func _find_terminal_hit_target() -> Node:
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("get_runtime_entities"):
		return null

	var best_target: Node2D = null
	var best_distance := INF
	for candidate in battle.call("get_runtime_entities"):
		if candidate == null or candidate == self or candidate == owner_entity:
			continue
		if not candidate.has_method("take_damage"):
			continue
		if not (candidate is Node2D):
			continue
		if candidate.has_method("get") and candidate.get("team") == team:
			continue
		if candidate.has_method("is_combat_active") and not candidate.call("is_combat_active"):
			continue
		var candidate_node := candidate as Node2D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance > _impact_radius:
			continue
		if distance < best_distance:
			best_distance = distance
			best_target = candidate_node

	return best_target


func _emit_spawn_event() -> void:
	_spawn_event_emitted = true
	var spawned_runtime := _runtime_overrides.duplicate(true)
	spawned_runtime["depth"] = int(spawned_runtime.get("depth", 1)) + 1
	var spawned_event = EventDataRef.create(owner_entity, self, damage, PackedStringArray(["projectile"]), spawned_runtime)
	spawned_event.core["move_mode"] = _move_mode
	EventBus.push_event(&"projectile.spawned", spawned_event)


func _draw() -> void:
	var body_color := _projectile_color()
	var radius := 8.0 if _move_mode != &"parabola" else 10.0
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 12, PROJECTILE_OUTLINE_COLOR, 2.0)
	if _move_mode == &"track":
		draw_circle(Vector2(-5.0, 0.0), 3.0, Color(1.0, 1.0, 1.0, 0.35))
	elif _move_mode == &"parabola":
		draw_circle(Vector2(0.0, -4.0), 3.0, Color(1.0, 0.95, 0.7, 0.45))


func _ensure_movement_component(move_mode: StringName) -> void:
	var desired_script = _movement_script_for_mode(move_mode)
	_enforce_single_movement_component(movement_component)
	if movement_component != null and movement_component.get_script() == desired_script and _movement_component_count() == 1:
		return

	if movement_component != null:
		remove_child(movement_component)
		movement_component.queue_free()

	movement_component = desired_script.new()
	movement_component.name = "MovementComponent"
	add_child(movement_component)
	_enforce_single_movement_component(movement_component)


func _movement_script_for_mode(move_mode: StringName):
	match move_mode:
		&"parabola":
			return ProjectileMovementParabolaRef
		&"track":
			return ProjectileMovementTrackRef
		_:
			return ProjectileMovementLinearRef


func _projectile_color() -> Color:
	match _move_mode:
		&"track":
			return PROJECTILE_COLOR_TRACK
		&"parabola":
			return PROJECTILE_COLOR_PARABOLA
		_:
			return PROJECTILE_COLOR_LINEAR


func _movement_component_count() -> int:
	return _collect_movement_components().size()


func _collect_movement_components() -> Array:
	var components: Array = []
	for child in get_children():
		if child == null:
			continue
		if child.name != "MovementComponent":
			continue
		if not child.has_method("physics_process_projectile_move"):
			continue
		components.append(child)
	return components


func _enforce_single_movement_component(preferred_component = null) -> void:
	var components: Array = _collect_movement_components()
	if components.is_empty():
		movement_component = null
		return

	var kept_component = preferred_component
	if kept_component == null or not components.has(kept_component):
		kept_component = components.back()

	for component in components:
		if component == kept_component:
			continue
		remove_child(component)
		component.queue_free()

	movement_component = kept_component
