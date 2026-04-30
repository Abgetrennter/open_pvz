extends "res://scripts/entities/base_entity.gd"
class_name ProjectileRoot

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const RuleContextRef = preload("res://scripts/core/runtime/rule_context.gd")
const EffectExecutorRef = preload("res://scripts/core/runtime/effect_executor.gd")
const ProjectileMovementLinearRef = preload("res://scripts/projectile/movement/projectile_movement_linear.gd")
const ProjectileMovementParabolaRef = preload("res://scripts/projectile/movement/projectile_movement_parabola.gd")
const ProjectileMovementTrackRef = preload("res://scripts/projectile/movement/projectile_movement_track.gd")
const ProjectileMoveResultRef = preload("res://scripts/projectile/projectile_move_result.gd")

@onready var movement_component: Variant = get_node_or_null("MovementComponent")
@onready var hitbox_component: Variant = get_node_or_null("HitboxComponent")

@export var lifetime := 5.0
@export var projectile_template_id: StringName = StringName()

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
var _collision_padding := 10.0
var _hit_strategy: StringName = &"overlap"
var _terminal_hit_strategy: StringName = &"impact_hitbox"
var _ground_position := Vector2.ZERO
var _height := 0.0
var _max_hit_height := 24.0
var _projection_scale := 1.0
var _flight_profile_id: StringName = StringName()
var _ignored_entity_ids: PackedInt32Array = PackedInt32Array()
var _pierce_hit_entity_ids: Array = []
var _max_penetrations := 5
var _pierce_count := 0


func _ready() -> void:
	entity_kind = &"projectile"
	super()
	set_status(&"flying")
	_ground_position = global_position
	_apply_projected_transform()
	movement_component = get_node_or_null("MovementComponent")
	_enforce_single_movement_component(movement_component)
	if hitbox_component != null:
		hitbox_component.hit.connect(_on_hitbox_overlap)
	if owner_entity != null and not _spawn_event_emitted:
		_emit_spawn_event()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_age += delta
	var move_result = null
	if movement_component != null:
		move_result = movement_component.physics_process_projectile_move(delta)
	if move_result == null:
		move_result = ProjectileMoveResultRef.new()
		move_result.previous_position = _ground_position
		move_result.current_position = _ground_position
		move_result.previous_height = _height
		move_result.current_height = _height
		move_result.still_active = true

	if not _consumed:
		var in_flight_target: Node = _find_hit_target_from_move_result(move_result)
		if in_flight_target != null:
			_on_hit(in_flight_target, &"in_flight")
			return
		if not bool(move_result.still_active):
			var terminal_reason: StringName = &"movement_end"
			if move_result.terminal_reason != StringName():
				terminal_reason = move_result.terminal_reason
			_resolve_terminal_state(terminal_reason)
			return

	if _age >= lifetime and not _consumed:
		_resolve_terminal_state(&"lifetime_end")


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
	_ground_position = global_position
	_height = 0.0
	_apply_projected_transform()
	var debug_target_position: Variant = _ground_position
	var debug_target_node: Variant = null
	if movement_component != null:
		var full_movement_params: Dictionary = movement_params.duplicate(true)
		full_movement_params["direction"] = _launch_direction
		full_movement_params["speed"] = _launch_speed
		full_movement_params["move_mode"] = StringName(full_movement_params.get("move_mode", &"linear"))
		_move_mode = full_movement_params["move_mode"]
		_impact_radius = float(full_movement_params.get("impact_radius", 20.0))
		_collision_padding = float(full_movement_params.get("collision_padding", 10.0))
		_max_hit_height = float(full_movement_params.get("max_hit_height", 24.0))
		_projection_scale = float(full_movement_params.get("projection_scale", 1.0))
		_flight_profile_id = StringName(full_movement_params.get("profile_id", StringName()))
		var configured_hit_strategy := StringName(full_movement_params.get("hit_strategy", StringName()))
		_hit_strategy = configured_hit_strategy if configured_hit_strategy != StringName() else _default_hit_strategy_for_mode(_move_mode)
		var configured_terminal_strategy := StringName(full_movement_params.get("terminal_hit_strategy", StringName()))
		_terminal_hit_strategy = configured_terminal_strategy if configured_terminal_strategy != StringName() else _terminal_strategy_for_hit_strategy(_hit_strategy)
		_max_penetrations = maxi(1, int(full_movement_params.get("max_penetrations", _max_penetrations)))
		_ignored_entity_ids = PackedInt32Array(full_movement_params.get("ignored_entity_ids", PackedInt32Array()))
		full_movement_params["start_position"] = _ground_position
		debug_target_position = full_movement_params.get("target_position", _ground_position)
		debug_target_node = full_movement_params.get("target_node", null)
		movement_component.configure_movement(full_movement_params)
		queue_redraw()
	set_state_value(&"damage", damage)
	set_state_value(&"move_mode", _move_mode)
	set_state_value(&"owner_id", -1 if owner_entity == null or not owner_entity.has_method("get_entity_id") else int(owner_entity.call("get_entity_id")))
	set_state_value(&"launch_speed", _launch_speed)
	set_state_value(&"launch_direction", _launch_direction)
	set_state_value(&"impact_radius", _impact_radius)
	set_state_value(&"collision_padding", _collision_padding)
	set_state_value(&"hit_strategy", _hit_strategy)
	set_state_value(&"terminal_hit_strategy", _terminal_hit_strategy)
	set_state_value(&"ground_position", _ground_position)
	set_state_value(&"height", _height)
	set_state_value(&"max_hit_height", _max_hit_height)
	set_state_value(&"projection_scale", _projection_scale)
	set_state_value(&"profile_id", _flight_profile_id)
	set_state_value(&"target_position", debug_target_position)
	set_state_value(&"target_id", -1 if debug_target_node == null or not debug_target_node.has_method("get_entity_id") else int(debug_target_node.call("get_entity_id")))
	sync_runtime_state()
	if is_inside_tree() and not _spawn_event_emitted:
		_emit_spawn_event()


func _on_hit(target: Node, terminal_reason: StringName = StringName()) -> void:
	if _consumed:
		return
	if target == null or target == self or target == owner_entity:
		return
	if _is_ignored_target(target):
		return
	if _hit_strategy == &"pierce":
		if _pierce_hit_entity_ids.has(target.get_instance_id()):
			return
		if _pierce_count >= _max_penetrations:
			return
	if target.has_method("get") and target.get("team") == team:
		return

	if _hit_strategy == &"pierce":
		_pierce_hit_entity_ids.append(target.get_instance_id())
		_pierce_count += 1
	else:
		_consumed = true

	var hit_runtime := _runtime_overrides.duplicate(true)
	hit_runtime["depth"] = int(hit_runtime.get("depth", 1)) + 1
	var hit_event = EventDataRef.create(owner_entity, target, damage, PackedStringArray(["projectile"]), hit_runtime)
	hit_event.core["move_mode"] = _move_mode
	hit_event.core["profile_id"] = _flight_profile_id
	if terminal_reason != StringName():
		hit_event.core["terminal_reason"] = terminal_reason
	set_state_value(&"terminal_reason", terminal_reason)
	set_state_value(&"last_result", &"hit")
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
	if _hit_strategy == &"pierce" and _pierce_count < _max_penetrations:
		return
	queue_free()


func _on_hitbox_overlap(target: Node) -> void:
	if not _allows_overlap_hit():
		return
	if _is_ignored_target(target):
		return
	if not _matches_height_range(target, _height, _height):
		return
	_on_hit(target, &"overlap")


func _expire(terminal_reason: StringName = StringName()) -> void:
	_consumed = true
	set_status(&"expired")
	sync_runtime_state()
	var expired_runtime := _runtime_overrides.duplicate(true)
	expired_runtime["depth"] = int(expired_runtime.get("depth", 1)) + 1
	var expired_event = EventDataRef.create(owner_entity, self, 0, PackedStringArray(["projectile", "expired"]), expired_runtime)
	expired_event.core["move_mode"] = _move_mode
	expired_event.core["profile_id"] = _flight_profile_id
	if terminal_reason != StringName():
		expired_event.core["terminal_reason"] = terminal_reason
	set_state_value(&"terminal_reason", terminal_reason)
	set_state_value(&"last_result", &"expired")
	EventBus.push_event(&"projectile.expired", expired_event)
	queue_free()


func _resolve_terminal_state(terminal_reason: StringName) -> void:
	var terminal_target: Node = _find_terminal_hit_target()
	if terminal_target != null:
		_on_hit(terminal_target, terminal_reason)
		return
	_expire(terminal_reason)


func _find_hit_target_from_move_result(move_result) -> Node:
	if move_result == null:
		return null
	match _hit_strategy:
		&"pierce", &"swept_segment", &"swept_segment_and_terminal_hitbox", &"swept_segment_and_terminal_radius":
			return _find_segment_hit_target(
				Vector2(move_result.previous_position),
				Vector2(move_result.current_position),
				float(move_result.previous_height),
				float(move_result.current_height)
			)
		_:
			return null


func _find_terminal_hit_target() -> Node:
	if _terminal_hit_strategy == &"none":
		return null
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("get_runtime_entities"):
		return null

	var best_target: Node2D = null
	var best_distance := INF
	for candidate in battle.call("get_runtime_entities"):
		if candidate == null or candidate == self or candidate == owner_entity:
			continue
		if _is_ignored_target(candidate):
			continue
		if _hit_strategy == &"pierce" and _pierce_hit_entity_ids.has(candidate.get_instance_id()):
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
		if _matches_terminal_hit_target(candidate_node):
			return candidate_node
		var distance := _ground_position.distance_to(_candidate_ground_position(candidate_node))
		if distance > _impact_radius:
			continue
		if distance < best_distance:
			best_distance = distance
			best_target = candidate_node

	return best_target


func _find_segment_hit_target(start_position: Vector2, end_position: Vector2, previous_height: float, current_height: float) -> Node:
	if start_position == end_position:
		return null
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("get_runtime_entities"):
		return null

	var best_target: Node2D = null
	var best_score := INF
	for candidate in battle.call("get_runtime_entities"):
		if candidate == null or candidate == self or candidate == owner_entity:
			continue
		if _is_ignored_target(candidate):
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
		if not _matches_height_range(candidate_node, previous_height, current_height):
			continue
		var candidate_hitbox := candidate_node.get_node_or_null("HitboxComponent")
		var intersects := false
		if candidate_hitbox != null and candidate_hitbox.has_method("intersects_world_segment"):
			intersects = bool(candidate_hitbox.call("intersects_world_segment", start_position, end_position, _collision_padding))
		else:
			intersects = _segment_distance_squared(start_position, end_position, _candidate_ground_position(candidate_node)) <= _impact_radius * _impact_radius
		if not intersects:
			continue
		var score := start_position.distance_squared_to(_candidate_ground_position(candidate_node))
		if score < best_score:
			best_score = score
			best_target = candidate_node
	return best_target


func _matches_terminal_hit_target(candidate_node: Node2D) -> bool:
	if not _matches_height_range(candidate_node, _height, _height):
		return false
	match _terminal_hit_strategy:
		&"impact_hitbox":
			var candidate_hitbox := candidate_node.get_node_or_null("HitboxComponent")
			if candidate_hitbox != null and candidate_hitbox.has_method("contains_world_point"):
				return bool(candidate_hitbox.call("contains_world_point", _ground_position, maxf(_impact_radius, _collision_padding)))
			return _ground_position.distance_to(_candidate_ground_position(candidate_node)) <= _impact_radius
		&"impact_radius":
			return _ground_position.distance_to(_candidate_ground_position(candidate_node)) <= _impact_radius
		_:
			return _ground_position.distance_to(_candidate_ground_position(candidate_node)) <= _impact_radius


func _default_hit_strategy_for_mode(move_mode: StringName) -> StringName:
	match move_mode:
		&"parabola":
			return &"terminal_hitbox"
		&"track":
			return &"swept_segment"
		_:
			return &"swept_segment"


func _terminal_strategy_for_hit_strategy(hit_strategy: StringName) -> StringName:
	match hit_strategy:
		&"terminal_hitbox", &"overlap_and_terminal_hitbox", &"swept_segment_and_terminal_hitbox":
			return &"impact_hitbox"
		&"terminal_radius", &"swept_segment_and_terminal_radius":
			return &"impact_radius"
		_:
			return &"none"


func _allows_overlap_hit() -> bool:
	match _hit_strategy:
		&"overlap", &"overlap_and_terminal_hitbox", &"overlap_and_terminal_radius":
			return true
		_:
			return false


func _segment_distance_squared(start_position: Vector2, end_position: Vector2, point: Vector2) -> float:
	var segment: Vector2 = end_position - start_position
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.00001:
		return start_position.distance_squared_to(point)
	var t: float = clamp((point - start_position).dot(segment) / length_squared, 0.0, 1.0)
	var closest: Vector2 = start_position + segment * t
	return closest.distance_squared_to(point)


func _emit_spawn_event() -> void:
	_spawn_event_emitted = true
	var spawned_runtime := _runtime_overrides.duplicate(true)
	spawned_runtime["depth"] = int(spawned_runtime.get("depth", 1)) + 1
	var spawned_event = EventDataRef.create(owner_entity, self, damage, PackedStringArray(["projectile"]), spawned_runtime)
	spawned_event.core["move_mode"] = _move_mode
	spawned_event.core["profile_id"] = _flight_profile_id
	EventBus.push_event(&"projectile.spawned", spawned_event)


func _draw() -> void:
	var body_color := _projectile_color()
	var radius := 8.0 if _move_mode != &"parabola" else 10.0
	if _height > 0.0:
		var shadow_size := maxf(4.0, radius - _height * 0.02)
		draw_circle(Vector2(0.0, _height), shadow_size, Color(0.0, 0.0, 0.0, 0.18))
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


func get_ground_position() -> Vector2:
	return _ground_position


func get_height() -> float:
	return _height


func get_hit_height_range() -> Vector2:
	return Vector2(0.0, _max_hit_height)


func set_projected_motion_state(ground_position: Vector2, height: float) -> void:
	_ground_position = ground_position
	_height = maxf(height, 0.0)
	_apply_projected_transform()
	set_state_value(&"ground_position", _ground_position)
	set_state_value(&"height", _height)
	set_state_value(&"projected_position", global_position)
	queue_redraw()


func _apply_projected_transform() -> void:
	global_position = _ground_position + Vector2(0.0, -_height * _projection_scale)


func _candidate_ground_position(candidate: Node2D) -> Vector2:
	if candidate.has_method("get_ground_position"):
		return Vector2(candidate.call("get_ground_position"))
	return candidate.global_position


func _matches_height_range(candidate: Node, previous_height: float, current_height: float) -> bool:
	var min_hit_height := 0.0
	var max_hit_height := 24.0
	if candidate != null and candidate.has_method("get_hit_height_range"):
		var hit_range: Variant = candidate.call("get_hit_height_range")
		if hit_range is Vector2:
			min_hit_height = hit_range.x
			max_hit_height = hit_range.y
	var segment_min_height := minf(previous_height, current_height)
	var segment_max_height := maxf(previous_height, current_height)
	return segment_max_height >= min_hit_height and segment_min_height <= max_hit_height


func _projectile_color() -> Color:
	match _move_mode:
		&"track":
			return PROJECTILE_COLOR_TRACK
		&"parabola":
			return PROJECTILE_COLOR_PARABOLA
		_:
			return PROJECTILE_COLOR_LINEAR


func _is_ignored_target(target: Node) -> bool:
	if target == null or not target.has_method("get_entity_id"):
		return false
	return _ignored_entity_ids.has(int(target.call("get_entity_id")))


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


func modify(params: Dictionary) -> void:
	if params.has("damage_multiplier"):
		damage = int(round(float(damage) * float(params["damage_multiplier"])))
	if params.has("damage"):
		damage = int(params["damage"])
	if params.has("hit_strategy"):
		_hit_strategy = StringName(params["hit_strategy"])
