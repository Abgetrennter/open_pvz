extends "res://scripts/entities/field_object_root.gd"
class_name LawnMower

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")

var move_speed := 300.0
var detection_radius := 50.0
var _mower_state: StringName = &"idle"
var _battle_ref: Node = null


func _ready() -> void:
	super()
	set_state_value(&"mower_state", _mower_state)
	queue_redraw()


func set_battle_ref(battle: Node) -> void:
	_battle_ref = battle


func _physics_process(delta: float) -> void:
	match _mower_state:
		&"idle":
			_check_zombie_proximity()
		&"triggered":
			_sweep(delta)


func _check_zombie_proximity() -> void:
	for entity in _get_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if not entity.has_method("is_combat_active"):
			continue
		if not bool(entity.call("is_combat_active")):
			continue
		if StringName(entity.get("team")) != &"zombie":
			continue
		if int(entity.get("lane_id")) != lane_id:
			continue
		var zombie_x: float = float(entity.get("global_position").x) if entity.get("global_position") != null else 0.0
		if zombie_x <= global_position.x + detection_radius:
			_trigger()
			return


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
	global_position.x += move_speed * delta
	for entity in _get_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		if not entity.has_method("is_combat_active"):
			continue
		if not bool(entity.call("is_combat_active")):
			continue
		if StringName(entity.get("team")) != &"zombie":
			continue
		if int(entity.get("lane_id")) != lane_id:
			continue
		var zombie_x: float = float(entity.get("global_position").x) if entity.get("global_position") != null else 0.0
		if zombie_x <= global_position.x + 20.0:
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


func _get_combat_entities() -> Array:
	if _battle_ref == null or not is_instance_valid(_battle_ref):
		if get_parent() != null and get_parent().has_method("get_runtime_combat_entities"):
			_battle_ref = get_parent().get_parent()
	if _battle_ref == null or not is_instance_valid(_battle_ref):
		return []
	if not _battle_ref.has_method("get_runtime_combat_entities"):
		return []
	return _battle_ref.call("get_runtime_combat_entities")


func _draw() -> void:
	var body_color := Color("6a8a5a") if _mower_state == &"idle" else Color("5a8a6a")
	draw_rect(Rect2(Vector2(-18, -14), Vector2(36, 28)), body_color)
	draw_rect(Rect2(Vector2(-18, -14), Vector2(36, 28)), OUTLINE_COLOR, false, 2.0)
	draw_rect(Rect2(Vector2(-12, -22), Vector2(24, 10)), body_color.darkened(0.15))
	draw_rect(Rect2(Vector2(14, -8), Vector2(10, 16)), body_color.darkened(0.1))
	draw_rect(Rect2(Vector2(-16, 14), Vector2(12, 6)), OUTLINE_COLOR)
	draw_rect(Rect2(Vector2(4, 14), Vector2(12, 6)), OUTLINE_COLOR)
