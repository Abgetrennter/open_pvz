extends "res://scripts/entities/base_entity.gd"
class_name ZombieRoot

@onready var health_component: Variant = get_node_or_null("HealthComponent")

const BODY_COLOR := Color("8b7f6b")
const OUTLINE_COLOR := Color("2d241b")
const HEALTH_GOOD := Color("72d66f")
const HEALTH_BAD := Color("c44a3d")


func _ready() -> void:
	entity_kind = &"zombie"
	team = &"zombie"
	super()
	if health_component != null:
		health_component.damaged.connect(_on_health_changed)
		health_component.died.connect(_on_died)
	queue_redraw()


func take_damage(amount: int, source_node: Node = null, tags: PackedStringArray = PackedStringArray()) -> void:
	if health_component != null:
		health_component.take_damage(amount, source_node, tags)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-18, -34), Vector2(36, 54)), BODY_COLOR)
	draw_rect(Rect2(Vector2(-18, -34), Vector2(36, 54)), OUTLINE_COLOR, false, 2.0)
	draw_rect(Rect2(Vector2(-14, -48), Vector2(28, 12)), BODY_COLOR.darkened(0.1))
	draw_circle(Vector2(-5, -42), 2.0, OUTLINE_COLOR)
	draw_circle(Vector2(5, -42), 2.0, OUTLINE_COLOR)
	_draw_health_bar(120 if health_component == null else health_component.current_health, 120 if health_component == null else health_component.max_health)


func _draw_health_bar(current: int, maximum: int) -> void:
	var ratio: float = 1.0 if maximum <= 0 else clamp(float(current) / float(maximum), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-22, -58), Vector2(44, 6)), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(Vector2(-22, -58), Vector2(44 * ratio, 6)), HEALTH_BAD.lerp(HEALTH_GOOD, ratio))


func _on_health_changed(_amount: int) -> void:
	queue_redraw()


func _on_died() -> void:
	queue_free()
