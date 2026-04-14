extends Node2D
class_name SunCollectible

var sun_id := -1
var sun_value := 25
var source_type: StringName = &"sky_drop"
var lane_id := -1
var source_entity_id := -1
var auto_collect_delay := -1.0
var collected := false

var _age := 0.0
var _economy_state: Node = null


func configure(
	new_sun_id: int,
	new_value: int,
	new_source_type: StringName,
	new_lane_id: int,
	new_source_entity_id: int,
	economy_state: Node,
	new_auto_collect_delay: float
) -> void:
	sun_id = new_sun_id
	sun_value = new_value
	source_type = new_source_type
	lane_id = new_lane_id
	source_entity_id = new_source_entity_id
	_economy_state = economy_state
	auto_collect_delay = new_auto_collect_delay
	queue_redraw()


func _process(delta: float) -> void:
	if collected:
		return
	_age += delta
	if auto_collect_delay < 0.0:
		return
	if _age < auto_collect_delay:
		return
	if _economy_state == null or not is_instance_valid(_economy_state):
		return
	if _economy_state.has_method("collect_sun"):
		_economy_state.call("collect_sun", self, null)


func get_debug_name() -> String:
	return "sun#%d" % sun_id


func get_debug_snapshot() -> Dictionary:
	return {
		"entity_id": sun_id,
		"template_id": StringName(),
		"entity_kind": &"sun",
		"team": &"neutral",
		"lane_id": lane_id,
		"status": &"collected" if collected else &"idle",
		"position": global_position,
		"health": 0,
		"max_health": 0,
		"values": {
			"sun_value": sun_value,
			"source_type": source_type,
			"source_entity_id": source_entity_id,
			"auto_collect_delay": auto_collect_delay,
		},
	}


func mark_collected() -> void:
	if collected:
		return
	collected = true
	queue_free()


func _draw() -> void:
	var fill_color := Color("f2d25c")
	var outline_color := Color("8a6113")
	draw_circle(Vector2.ZERO, 14.0, fill_color)
	draw_circle(Vector2.ZERO, 14.0, outline_color, false, 2.0)
	draw_circle(Vector2(-5.0, -4.0), 2.0, outline_color)
	draw_circle(Vector2(5.0, -4.0), 2.0, outline_color)
	draw_arc(Vector2.ZERO, 6.0, 0.4, PI - 0.4, 12, outline_color, 2.0)
