extends "res://scripts/entities/base_entity.gd"
class_name PlantRoot

@onready var trigger_component: Variant = get_node_or_null("TriggerComponent")
@onready var health_component: Variant = get_node_or_null("HealthComponent")
@onready var debug_view_component: Variant = get_node_or_null("DebugViewComponent")

const BODY_COLOR := Color("5aa05a")
const OUTLINE_COLOR := Color("173018")
const HEALTH_GOOD := Color("72d66f")
const HEALTH_BAD := Color("c44a3d")


func _ready() -> void:
	entity_kind = &"plant"
	team = &"plant"
	super()
	entity_state["status"] = "alive"
	if health_component != null:
		health_component.damaged.connect(_on_health_changed)
		health_component.died.connect(_on_died)
	queue_redraw()


func take_damage(amount: int, source_node: Node = null, tags: PackedStringArray = PackedStringArray()) -> void:
	if health_component != null:
		health_component.take_damage(amount, source_node, tags)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-18, -28), Vector2(36, 44)), BODY_COLOR)
	draw_rect(Rect2(Vector2(-18, -28), Vector2(36, 44)), OUTLINE_COLOR, false, 2.0)
	draw_circle(Vector2(0, -34), 12.0, BODY_COLOR.lightened(0.15))
	draw_circle(Vector2(-5, -36), 2.0, OUTLINE_COLOR)
	draw_circle(Vector2(5, -36), 2.0, OUTLINE_COLOR)
	_draw_health_bar(100 if health_component == null else health_component.current_health, 100 if health_component == null else health_component.max_health)


func _draw_health_bar(current: int, maximum: int) -> void:
	var ratio: float = 1.0 if maximum <= 0 else clamp(float(current) / float(maximum), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-20, -48), Vector2(40, 6)), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(Vector2(-20, -48), Vector2(40 * ratio, 6)), HEALTH_BAD.lerp(HEALTH_GOOD, ratio))


func _on_health_changed(_amount: int) -> void:
	queue_redraw()


func _on_died() -> void:
	entity_state["status"] = "dead"
	queue_free()
