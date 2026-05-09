extends "res://scripts/entities/field_object_root.gd"
class_name LawnMower

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

@onready var controller_component: Variant = get_node_or_null("ControllerComponent")

var move_speed := 300.0
var move_speed_slots_per_sec := -1.0
var detection_radius := 50.0
var detection_radius_slots := -1.0
var _mower_state: StringName = &"idle"
var _battle_ref: Node = null


func _ready() -> void:
	super()
	set_state_value(&"mower_state", _mower_state)
	queue_redraw()


func set_battle_ref(battle: Node) -> void:
	_battle_ref = battle


func _physics_process(delta: float) -> void:
	if GameState.should_skip_node_process_for_central_step():
		return
	simulation_step(delta)


func simulation_step(delta: float) -> void:
	if controller_component != null and controller_component.has_method("has_active_controllers") and bool(controller_component.call("has_active_controllers")):
		controller_component.call("physics_process_controllers", delta)
		return
	match _mower_state:
		&"idle":
			_check_zombie_proximity()
		&"triggered":
			_sweep(delta)


func _check_zombie_proximity() -> void:
	if not _query_zombies_ahead(_resolve_slots_distance(detection_radius_slots, detection_radius), false).is_empty():
		_trigger()


func _trigger() -> void:
	_mower_state = &"triggered"
	set_state_value(&"mower_state", _mower_state)
	var activated_event: Variant = EventDataRef.create(self, self, null, PackedStringArray(["field_object", "activated"]))
	activated_event.core["entity_id"] = entity_id
	activated_event.core["lane_id"] = lane_id
	activated_event.core["object_type"] = &"mower"
	EventBus.push_event(&"field_object.activated", activated_event)
	queue_redraw()


func _sweep(delta: float) -> void:
	global_position.x += _resolve_slots_speed(move_speed_slots_per_sec, move_speed) * delta
	for entity in _query_zombies_ahead(20.0, true):
		entity.call("take_damage", 9999, self, PackedStringArray(["mower", "sweep"]))
	if global_position.x > 1000.0:
		_expire()


func _expire() -> void:
	_mower_state = &"expired"
	set_state_value(&"mower_state", _mower_state)
	var expired_event: Variant = EventDataRef.create(self, self, null, PackedStringArray(["field_object", "expired"]))
	expired_event.core["entity_id"] = entity_id
	expired_event.core["lane_id"] = lane_id
	expired_event.core["object_type"] = &"mower"
	EventBus.push_event(&"field_object.expired", expired_event)
	queue_free()


func _draw() -> void:
	var body_color := Color("6a8a5a") if _mower_state == &"idle" else Color("5a8a6a")
	draw_rect(Rect2(Vector2(-18, -14), Vector2(36, 28)), body_color)
	draw_rect(Rect2(Vector2(-18, -14), Vector2(36, 28)), OUTLINE_COLOR, false, 2.0)
	draw_rect(Rect2(Vector2(-12, -22), Vector2(24, 10)), body_color.darkened(0.15))
	draw_rect(Rect2(Vector2(14, -8), Vector2(10, 16)), body_color.darkened(0.1))
	draw_rect(Rect2(Vector2(-16, 14), Vector2(12, 6)), OUTLINE_COLOR)
	draw_rect(Rect2(Vector2(4, 14), Vector2(12, 6)), OUTLINE_COLOR)


func perform_sweep_cycle_for_controller(spec: Dictionary, delta: float) -> void:
	var params: Dictionary = Dictionary(spec.get("params", {}))
	var resolved_move_speed := _resolve_slots_speed(float(params.get("move_speed_slots_per_sec", move_speed_slots_per_sec)), float(params.get("move_speed", move_speed)))
	var resolved_detection_radius := _resolve_slots_distance(float(params.get("detection_radius_slots", detection_radius_slots)), float(params.get("detection_radius", detection_radius)))
	match _mower_state:
		&"idle":
			_check_zombie_proximity_with_radius(resolved_detection_radius)
		&"triggered":
			_sweep_with_speed(delta, resolved_move_speed)


func _check_zombie_proximity_with_radius(resolved_detection_radius: float) -> void:
	if not _query_zombies_ahead(resolved_detection_radius, false).is_empty():
		_trigger()


func _sweep_with_speed(delta: float, resolved_move_speed: float) -> void:
	global_position.x += resolved_move_speed * delta
	for entity in _query_zombies_ahead(20.0, true):
		entity.call("take_damage", 9999, self, PackedStringArray(["mower", "sweep"]))
	if global_position.x > 1000.0:
		_expire()


func _query_zombies_ahead(max_forward_distance: float, require_collidable: bool) -> Array:
	var battle := _resolve_battle_ref()
	if battle == null or not battle.has_method("spatial_query"):
		return []
	return battle.call("spatial_query", {
		"team_include": &"zombie",
		"lane_ids": PackedInt32Array([lane_id]),
		"x_max": global_position.x + max_forward_distance,
		"filter": func(candidate):
			if not candidate.has_method("take_damage"):
				return false
			if require_collidable:
				return candidate.has_method("is_collidable") and bool(candidate.call("is_collidable"))
			return candidate.has_method("is_targetable") and bool(candidate.call("is_targetable")),
	})


func _resolve_battle_ref() -> Node:
	if _battle_ref != null and is_instance_valid(_battle_ref):
		return _battle_ref
	if GameState.current_battle != null and is_instance_valid(GameState.current_battle):
		_battle_ref = GameState.current_battle
		return _battle_ref
	return null


func _resolve_slots_distance(slots_value: float, legacy_world: float) -> float:
	if slots_value >= 0.0:
		return _slots_to_world(slots_value)
	return legacy_world


func _resolve_slots_speed(slots_value: float, legacy_world_per_sec: float) -> float:
	if slots_value >= 0.0:
		return _slots_to_world(slots_value)
	return legacy_world_per_sec


func _slots_to_world(slot_count: float) -> float:
	var battle := _battle_ref
	if battle == null or not is_instance_valid(battle):
		battle = GameState.current_battle
	if battle != null and battle.has_method("get_battlefield_metrics"):
		var metrics: Variant = battle.call("get_battlefield_metrics")
		if metrics is RefCounted and metrics.has_method("slots_to_world"):
			return float(metrics.call("slots_to_world", slot_count))
	return slot_count * 96.0
