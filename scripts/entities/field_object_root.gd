extends "res://scripts/entities/base_entity.gd"
class_name FieldObjectRoot

const BODY_COLOR := Color("8a8a6a")
const OUTLINE_COLOR := Color("3a3a2a")


func _ready() -> void:
	entity_kind = &"field_object"
	team = &"field_object"
	super()
	set_status(&"idle")
	queue_redraw()


func is_combat_active() -> bool:
	return false


func activate() -> void:
	set_status(&"active")


func deactivate() -> void:
	set_status(&"idle")


func take_damage(
	_amount: int,
	_source_node: Node = null,
	_tags: PackedStringArray = PackedStringArray(),
	_runtime_overrides: Dictionary = {}
) -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), BODY_COLOR)
	draw_rect(Rect2(Vector2(-16, -16), Vector2(32, 32)), OUTLINE_COLOR, false, 2.0)
	draw_line(Vector2(-8, 0), Vector2(8, 0), OUTLINE_COLOR, 2.0)
	draw_line(Vector2(0, -8), Vector2(0, 8), OUTLINE_COLOR, 2.0)
