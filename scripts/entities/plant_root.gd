extends "res://scripts/entities/base_entity.gd"
class_name PlantRoot

@onready var trigger_component: Variant = get_node_or_null("TriggerComponent")
@onready var health_component: Variant = get_node_or_null("HealthComponent")
@onready var debug_view_component: Variant = get_node_or_null("DebugViewComponent")
@onready var controller_component: Variant = get_node_or_null("ControllerComponent")

# ── Fallback visual constants (per archetype tag category) ──────────
# Priority order: explode > producer > mushroom > defense > water > lobber > shooter

const CATEGORY_COLORS := {
	&"explode":   {"body": Color("d44a3d"), "outline": Color("5a1812")},  # red
	&"producer":  {"body": Color("e8c840"), "outline": Color("6b5a10")},  # gold
	&"mushroom":  {"body": Color("7b5ea7"), "outline": Color("2e1a4a")},  # purple
	&"defense":   {"body": Color("8b6914"), "outline": Color("3d2a05")},  # brown
	&"water":     {"body": Color("3a8f8f"), "outline": Color("0e3a3a")},  # teal
	&"lobber":    {"body": Color("8aaa40"), "outline": Color("2e4010")},  # yellow-green
	&"shooter":   {"body": Color("5aa05a"), "outline": Color("173018")},  # green (default)
	&"special":   {"body": Color("5a7a8a"), "outline": Color("1a2a3a")},  # blue-gray (fallback)
}

const HEALTH_GOOD := Color("72d66f")
const HEALTH_BAD := Color("c44a3d")


func _ready() -> void:
	entity_kind = &"plant"
	team = &"plant"
	super()
	set_status(&"alive")
	set_state_value(&"can_fire", true)
	if health_component != null:
		health_component.damaged.connect(_on_health_changed)
		health_component.died.connect(_on_died)
	queue_redraw()


func take_damage(
	amount: int,
	source_node: Node = null,
	tags: PackedStringArray = PackedStringArray(),
	runtime_overrides: Dictionary = {}
) -> void:
	if health_component != null:
		health_component.take_damage(amount, source_node, tags, runtime_overrides)


func _physics_process(delta: float) -> void:
	if GameState.should_skip_node_process_for_central_step():
		return
	simulation_step(delta)


func simulation_step(delta: float) -> void:
	super(delta)
	if controller_component != null and controller_component.has_method("physics_process_controllers"):
		controller_component.call("physics_process_controllers", delta)


func _draw() -> void:
	if get_node_or_null("VisualActorComponent") != null:
		return

	var category: StringName = _resolve_fallback_category()
	var colors: Dictionary = CATEGORY_COLORS.get(category, CATEGORY_COLORS[&"special"])
	var body_color: Color = colors["body"]
	var outline_color: Color = colors["outline"]
	var head_color: Color = body_color.lightened(0.15)

	# ── Category-specific body dimensions ──
	var bw: float = 18.0  # half-width
	var bh_top: float = -28.0
	var bh_bot: float = 16.0
	match category:
		&"explode":   bw = 14.0; bh_top = -24.0; bh_bot = 8.0
		&"defense":   bw = 22.0; bh_top = -22.0; bh_bot = 12.0
		&"mushroom":  bw = 16.0; bh_top = -22.0; bh_bot = 8.0
		&"water":     bw = 20.0

	# Body
	draw_rect(Rect2(Vector2(-bw, bh_top), Vector2(bw * 2, bh_bot - bh_top)), body_color)
	draw_rect(Rect2(Vector2(-bw, bh_top), Vector2(bw * 2, bh_bot - bh_top)), outline_color, false, 2.0)

	# ── Head / top marker per category ──
	match category:
		&"producer":
			# round head + sun rays
			draw_circle(Vector2(0, bh_top - 6), 9.0, head_color)
			draw_circle(Vector2(0, bh_top - 6), 9.0, outline_color, false, 1.5)
			draw_circle(Vector2(-3, bh_top - 7), 2.0, outline_color)
			draw_circle(Vector2(3, bh_top - 7), 2.0, outline_color)
			# sun rays
			for angle_deg: int in [0, 45, 90, 135, 180, 225, 270, 315]:
				var rad := deg_to_rad(float(angle_deg))
				var inner := Vector2(cos(rad), sin(rad)) * 5.0
				var outer := Vector2(cos(rad), sin(rad)) * 10.0
				draw_line(Vector2(0, bh_top - 6) + inner, Vector2(0, bh_top - 6) + outer, head_color, 1.5)

		&"explode":
			# starburst
			var cx: float = 0.0
			var cy: float = bh_top - 8
			var pts: PackedVector2Array
			for i: int in range(10):
				var a := deg_to_rad(float(i * 36 - 90))
				var r := 10.0 if i % 2 == 0 else 5.0
				pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
			draw_colored_polygon(pts, head_color)
			draw_polyline(pts, outline_color, 1.5, true)

		&"defense":
			# flat top, no head — just thicker top line
			draw_line(Vector2(-bw + 2, bh_top), Vector2(bw - 2, bh_top), outline_color, 3.0)

		&"mushroom":
			# dome cap
			var cap_y: float = bh_top - 4
			draw_rect(Rect2(Vector2(-bw - 4, cap_y - 6), Vector2(bw * 2 + 8, 12)), body_color.darkened(0.1), true)
			draw_circle(Vector2(-4, cap_y - 2), 2.0, outline_color)
			draw_circle(Vector2(4, cap_y - 2), 2.0, outline_color)

		&"water":
			# waves on top
			draw_circle(Vector2(0, bh_top - 4), 6.0, head_color)
			draw_circle(Vector2(0, bh_top - 4), 6.0, outline_color, false, 1.5)
			draw_arc(Vector2(0, bh_top - 4), 8.0, deg_to_rad(0.0), deg_to_rad(180.0), 16, outline_color, 1.5)

		&"lobber":
			# arc / lob trajectory
			draw_circle(Vector2(0, bh_top - 5), 7.0, head_color)
			draw_arc(Vector2(0, bh_top - 5), 8.0, deg_to_rad(0.0), deg_to_rad(180.0), 12, outline_color, 2.0)
			draw_circle(Vector2(-3, bh_top - 6), 1.5, outline_color)
			draw_circle(Vector2(3, bh_top - 6), 1.5, outline_color)

		&"shooter":
			# round head + eyes (default look)
			draw_circle(Vector2(0, bh_top - 6), 10.0, head_color)
			draw_circle(Vector2(0, bh_top - 6), 10.0, outline_color, false, 1.5)
			draw_circle(Vector2(-3, bh_top - 7), 2.0, outline_color)
			draw_circle(Vector2(3, bh_top - 7), 2.0, outline_color)

		_:
			draw_circle(Vector2(0, bh_top - 5), 8.0, head_color)
			draw_circle(Vector2(0, bh_top - 5), 8.0, outline_color, false, 1.5)
			draw_circle(Vector2(-3, bh_top - 6), 1.5, outline_color)
			draw_circle(Vector2(3, bh_top - 6), 1.5, outline_color)

	_draw_health_bar(100 if health_component == null else health_component.current_health, 100 if health_component == null else health_component.max_health, bw)

# ── Fallback visual helpers ──────────────────────────────────────────

func _resolve_fallback_category() -> StringName:
	# Priority-ordered tag dispatch. First matching tag wins.
	if _has_any_tag(["explode", "bomber"]):
		return &"explode"
	if _has_any_tag(["producer"]) or _has_all_tags(["sun"]):
		return &"producer"
	if _has_all_tags(["mushroom", "nocturnal"]):
		return &"mushroom"
	if _has_any_tag(["defense", "wall", "cover", "barrier"]):
		return &"defense"
	if _has_any_tag(["water"]):
		return &"water"
	if _has_any_tag(["lobber"]):
		return &"lobber"
	if _has_any_tag(["shooter"]):
		return &"shooter"
	return &"special"

func _has_any_tag(candidates: Array) -> bool:
	for t: String in candidates:
		if StringName(t) in tags:
			return true
	return false

func _has_all_tags(candidates: Array) -> bool:
	for t: String in candidates:
		if not (StringName(t) in tags):
			return false
	return true


func _draw_health_bar(current: int, maximum: int, half_width: float = 18.0) -> void:
	var ratio: float = 1.0 if maximum <= 0 else clamp(float(current) / float(maximum), 0.0, 1.0)
	var bar_w: float = half_width * 2.0 + 4.0
	var bar_top: float = -48.0
	draw_rect(Rect2(Vector2(-half_width - 2, bar_top), Vector2(bar_w, 6)), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(Vector2(-half_width - 2, bar_top), Vector2(bar_w * ratio, 6)), HEALTH_BAD.lerp(HEALTH_GOOD, ratio))


func _on_health_changed(_amount: int) -> void:
	queue_redraw()


func _on_died() -> void:
	set_status(&"dead")
	sync_runtime_state()
	queue_free()
