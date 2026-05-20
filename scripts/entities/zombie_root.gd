extends "res://scripts/entities/base_entity.gd"
class_name ZombieRoot

@onready var movement_component: Variant = get_node_or_null("MovementComponent")
@onready var controller_component: Variant = get_node_or_null("ControllerComponent")
@onready var health_component: Variant = get_node_or_null("HealthComponent")
@onready var hitbox_component: Variant = get_node_or_null("HitboxComponent")

# ── Fallback visual constants (per archetype tag category) ──────────
# Priority order: boss > explode > tank > air > fast > ranged > basic

const CATEGORY_COLORS := {
	&"boss":      {"body": Color("4a3a2a"), "outline": Color("1a1008")},  # dark
	&"explode":   {"body": Color("8a3a2a"), "outline": Color("3a1008")},  # red-brown
	&"tank":      {"body": Color("5a5a5a"), "outline": Color("1a1a1a")},  # gray
	&"air":       {"body": Color("5a8aaa"), "outline": Color("1a3a5a")},  # sky blue
	&"fast":      {"body": Color("9a8a5a"), "outline": Color("3a2a10")},  # yellow-brown
	&"ranged":    {"body": Color("8a6a4a"), "outline": Color("3a2010")},  # orange-brown
	&"basic":     {"body": Color("8b7f6b"), "outline": Color("2d241b")},  # brown (default)
	&"special":   {"body": Color("7a6a8a"), "outline": Color("2a1a3a")},  # purple-gray (fallback)
}

const HEALTH_GOOD := Color("72d66f")
const HEALTH_BAD := Color("c44a3d")

@export var move_speed := 55.0
@export var move_speed_slots_per_sec := -1.0
@export var attack_range := 56.0
@export var attack_interval := 1.0
@export var attack_damage := 10
@export var death_feedback_duration := 0.65

var _attack_cooldown := 0.0
var _attack_target: Node = null
var _is_dying := false
var _death_elapsed := 0.0
var _last_status_effect_signature := ""


func _ready() -> void:
	entity_kind = &"zombie"
	team = &"zombie"
	_attack_cooldown = attack_interval
	super()
	set_status(&"alive")
	set_state_value(&"attack_damage", attack_damage)
	set_state_value(&"move_speed", _resolve_move_speed())
	if health_component != null:
		health_component.damaged.connect(_on_health_changed)
		health_component.died.connect(_on_died)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if GameState.should_skip_node_process_for_central_step():
		return
	simulation_step(delta)


func simulation_step(delta: float) -> void:
	if _is_dying:
		return
	if controller_component != null and controller_component.has_method("has_active_controllers") and bool(controller_component.call("has_active_controllers")):
		controller_component.call("physics_process_controllers", delta)
		return

	_attack_cooldown = max(_attack_cooldown - delta, 0.0)
	_attack_target = _find_attack_target()
	var movement_scale := get_effective_movement_scale()

	if movement_component != null:
		movement_component.velocity = Vector2.ZERO

	if _attack_target != null:
		if movement_component != null:
			movement_component.velocity = Vector2.ZERO
		set_state_value(&"velocity", Vector2.ZERO)
		set_state_value(&"speed", 0.0)
		sync_runtime_state()
		set_state_value(&"attack_target_id", _debug_target_id())
		if not is_liveness_enabled(&"controllers"):
			_attack_cooldown = attack_interval
			_emit_status_effect_observed(&"controllers_disabled", {
				"movement_scale": movement_scale,
			})
			return
		_try_attack()
	elif movement_component != null:
		_process_forward_movement(delta, _resolve_move_speed())
		set_state_value(&"attack_target_id", -1)
		if movement_scale < 0.999:
			_emit_status_effect_observed(&"movement_scaled", {
				"movement_scale": movement_scale,
				"effective_move_speed": _resolve_move_speed() * movement_scale,
			})


func _process(delta: float) -> void:
	_process_death_feedback(delta)


func _process_death_feedback(delta: float) -> void:
	if not _is_dying:
		return

	_death_elapsed += delta
	var progress: float = clamp(_death_elapsed / death_feedback_duration, 0.0, 1.0)
	rotation_degrees = lerpf(0.0, 88.0, progress)
	modulate.a = 1.0 - progress
	position.y += 18.0 * delta
	if progress >= 1.0:
		queue_free()




func take_damage(
	amount: int,
	source_node: Node = null,
	tags: PackedStringArray = PackedStringArray(),
	runtime_overrides: Dictionary = {}
) -> void:
	if _is_dying:
		return
	if health_component != null:
		health_component.take_damage(amount, source_node, tags, runtime_overrides)


func _draw() -> void:
	if get_node_or_null("VisualActorComponent") != null:
		return

	var category: StringName = _resolve_fallback_category()
	var colors: Dictionary = CATEGORY_COLORS.get(category, CATEGORY_COLORS[&"special"])
	var body_color: Color = colors["body"] if not _is_dying else colors["body"].darkened(0.25)
	var outline_color: Color = colors["outline"]
	var head_color: Color = body_color.darkened(0.1)

	# ── Category-specific body dimensions ──
	var bw: float = 18.0  # half-width
	var bh_top: float = -34.0
	var bh_bot: float = 20.0
	match category:
		&"boss":   bw = 24.0; bh_top = -44.0; bh_bot = 22.0
		&"tank":   bw = 22.0; bh_top = -36.0
		&"air":    bw = 14.0; bh_top = -28.0; bh_bot = 12.0
		&"fast":   bw = 14.0; bh_top = -30.0; bh_bot = 14.0
		&"explode": bw = 16.0

	# Body
	draw_rect(Rect2(Vector2(-bw, bh_top), Vector2(bw * 2, bh_bot - bh_top)), body_color)
	draw_rect(Rect2(Vector2(-bw, bh_top), Vector2(bw * 2, bh_bot - bh_top)), outline_color, false, 2.0)

	# ── Head / top marker per category ──
	match category:
		&"boss":
			# Large head with crown-like spikes
			draw_rect(Rect2(Vector2(-bw + 2, bh_top - 14), Vector2(bw * 2 - 4, 16)), head_color.darkened(0.15), true)
			var pts: PackedVector2Array = [Vector2(-8, bh_top - 14), Vector2(0, bh_top - 24), Vector2(8, bh_top - 14)]
			draw_colored_polygon(pts, head_color.lightened(0.1))
			draw_polyline(pts, outline_color, 1.5, true)
			draw_circle(Vector2(-4, bh_top - 7), 2.0, outline_color)
			draw_circle(Vector2(4, bh_top - 7), 2.0, outline_color)

		&"tank":
			# Heavy bucket-like head
			draw_rect(Rect2(Vector2(-bw + 2, bh_top - 12), Vector2(bw * 2 - 4, 14)), head_color, true)
			draw_line(Vector2(-bw + 2, bh_top), Vector2(bw - 2, bh_top), outline_color, 3.0)
			draw_circle(Vector2(-4, bh_top - 6), 2.0, outline_color)
			draw_circle(Vector2(4, bh_top - 6), 2.0, outline_color)

		&"air":
			# Floating, wings
			draw_circle(Vector2(0, bh_top - 4), 7.0, head_color)
			draw_circle(Vector2(0, bh_top - 4), 7.0, outline_color, false, 1.5)
			# wings
			draw_line(Vector2(-bw, bh_top + 4), Vector2(-bw - 10, bh_top - 4), outline_color, 2.0)
			draw_line(Vector2(bw, bh_top + 4), Vector2(bw + 10, bh_top - 4), outline_color, 2.0)
			draw_circle(Vector2(-2, bh_top - 5), 1.5, outline_color)
			draw_circle(Vector2(2, bh_top - 5), 1.5, outline_color)

		&"fast":
			# Lean, tilted forward
			draw_rect(Rect2(Vector2(-bw + 1, bh_top - 10), Vector2(bw * 2 - 2, 12)), head_color, true)
			# speed lines
			draw_line(Vector2(-bw - 4, bh_top + 6), Vector2(-bw - 10, bh_top + 8), outline_color, 1.5)
			draw_line(Vector2(-bw - 4, bh_top + 10), Vector2(-bw - 8, bh_top + 14), outline_color, 1.5)
			draw_circle(Vector2(-3, bh_top - 4), 1.5, outline_color)
			draw_circle(Vector2(3, bh_top - 4), 1.5, outline_color)

		&"ranged":
			# Aiming pose, projectile arc indicator
			draw_rect(Rect2(Vector2(-bw + 2, bh_top - 10), Vector2(bw * 2 - 4, 12)), head_color, true)
			draw_arc(Vector2(bw + 6, bh_top), 8.0, deg_to_rad(20.0), deg_to_rad(160.0), 8, outline_color, 1.5)
			draw_circle(Vector2(-3, bh_top - 4), 1.5, outline_color)
			draw_circle(Vector2(3, bh_top - 4), 1.5, outline_color)

		&"explode":
			# Red bomb marker
			draw_rect(Rect2(Vector2(-bw + 2, bh_top - 8), Vector2(bw * 2 - 4, 10)), head_color.darkened(0.2), true)
			var cx: float = 0.0; var cy: float = bh_top - 8
			for i: int in range(6):
				var a := deg_to_rad(float(i * 60 - 90))
				var r_outer := 8.0 if i % 2 == 0 else 4.0
				draw_line(Vector2(cx + cos(a) * 3, cy + sin(a) * 3), Vector2(cx + cos(a) * r_outer, cy + sin(a) * r_outer), outline_color, 1.5)
			draw_circle(Vector2(-2, bh_top - 2), 1.5, outline_color)
			draw_circle(Vector2(2, bh_top - 2), 1.5, outline_color)

		_:
			# Default head (standard zombie)
			draw_rect(Rect2(Vector2(-bw + 4, bh_top - 12), Vector2(bw * 2 - 8, 14)), head_color, true)
			draw_circle(Vector2(-4, bh_top - 6), 2.0, outline_color)
			draw_circle(Vector2(4, bh_top - 6), 2.0, outline_color)

	var drawn_health := 120
	var drawn_max_health := 120
	if health_component != null:
		drawn_health = int(health_component.call("get_total_health")) if health_component.has_method("get_total_health") else int(health_component.current_health)
		drawn_max_health = int(health_component.call("get_total_max_health")) if health_component.has_method("get_total_max_health") else int(health_component.max_health)
	_draw_health_bar(drawn_health, drawn_max_health, bw)

# ── Fallback visual helpers ──────────────────────────────────────────

func _resolve_fallback_category() -> StringName:
	if _has_any_tag(["boss", "heavy"]):
		return &"boss"
	if _has_any_tag(["explode", "reactive"]):
		return &"explode"
	if _has_any_tag(["armored", "tank", "metal"]):
		return &"tank"
	if _has_any_tag(["air", "scout"]):
		return &"air"
	if _has_any_tag(["fast", "runner"]):
		return &"fast"
	if _has_any_tag(["ranged", "special_attack"]):
		return &"ranged"
	return &"basic"

func _has_any_tag(candidates: Array) -> bool:
	for t: String in candidates:
		if StringName(t) in tags:
			return true
	return false


func _draw_health_bar(current: int, maximum: int, half_width: float = 18.0) -> void:
	var ratio: float = 1.0 if maximum <= 0 else clamp(float(current) / float(maximum), 0.0, 1.0)
	var bar_w: float = half_width * 2.0 + 4.0
	var bar_top: float = -58.0
	draw_rect(Rect2(Vector2(-half_width - 2, bar_top), Vector2(bar_w, 6)), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(Vector2(-half_width - 2, bar_top), Vector2(bar_w * ratio, 6)), HEALTH_BAD.lerp(HEALTH_GOOD, ratio))


func _on_health_changed(_amount: int) -> void:
	queue_redraw()


func _on_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	_death_elapsed = 0.0
	set_status(&"dying")
	_attack_target = null
	if movement_component != null:
		movement_component.velocity = Vector2.ZERO
	if hitbox_component != null:
		hitbox_component.set_deferred("monitorable", false)
		hitbox_component.set_deferred("monitoring", false)
	sync_runtime_state()
	queue_redraw()


func _find_attack_target() -> Node:
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("spatial_query"):
		return null
	var targets: Array = battle.call("spatial_query", {
		"team_exclude": team,
		"lane_ids": PackedInt32Array([lane_id]),
		"center": global_position,
		"radius": attack_range,
		"x_min": global_position.x - attack_range,
		"x_max": global_position.x,
		"filter": func(candidate): return candidate != self and candidate.has_method("take_damage") and _matches_default_attack_exposure(candidate) and (not candidate.has_method("is_targetable") or bool(candidate.call("is_targetable"))),
		"sort_by_distance": true,
		"max_results": 1,
	})
	return null if targets.is_empty() else targets[0]


func find_attack_target_for_controller(_spec: Dictionary = {}) -> Node:
	return _find_attack_target()


func _try_attack() -> void:
	if _attack_target == null or _attack_cooldown > 0.0:
		return
	if not is_instance_valid(_attack_target):
		_attack_target = null
		return

	_attack_cooldown = attack_interval
	_attack_target.call("take_damage", attack_damage, self, PackedStringArray(["bite"]))


func perform_attack_cycle_for_controller(spec: Dictionary, delta: float) -> void:
	var params: Dictionary = Dictionary(spec.get("params", {}))
	var resolved_attack_interval := float(params.get("attack_interval", attack_interval))
	var resolved_attack_damage := int(params.get("attack_damage", attack_damage))
	var resolved_move_speed := _resolve_move_speed(params)
	var resolved_attack_range := float(params.get("attack_range", attack_range))
	_attack_cooldown = max(_attack_cooldown - delta, 0.0)
	var movement_scale := get_effective_movement_scale()
	if movement_component != null:
		movement_component.velocity = Vector2.ZERO
	_attack_target = _find_attack_target_with_range(resolved_attack_range)
	if _attack_target != null:
		if movement_component != null:
			movement_component.velocity = Vector2.ZERO
		set_state_value(&"velocity", Vector2.ZERO)
		set_state_value(&"speed", 0.0)
		sync_runtime_state()
		set_state_value(&"attack_target_id", _debug_target_id())
		if not is_liveness_enabled(&"controllers"):
			_attack_cooldown = resolved_attack_interval
			_emit_status_effect_observed(&"controllers_disabled", {
				"movement_scale": movement_scale,
			})
			return
		if _attack_cooldown <= 0.0 and is_instance_valid(_attack_target):
			_attack_cooldown = resolved_attack_interval
			_attack_target.call("take_damage", resolved_attack_damage, self, PackedStringArray(["bite"]))
	elif movement_component != null:
		_process_forward_movement(delta, resolved_move_speed)
		set_state_value(&"attack_target_id", -1)
		if movement_scale < 0.999:
			_emit_status_effect_observed(&"movement_scaled", {
				"movement_scale": movement_scale,
				"effective_move_speed": resolved_move_speed * movement_scale,
			})


func on_controllers_disabled(_delta: float) -> void:
	_attack_cooldown = attack_interval
	if movement_component != null:
		movement_component.velocity = Vector2.ZERO
	set_state_value(&"velocity", Vector2.ZERO)
	set_state_value(&"speed", 0.0)
	sync_runtime_state()


func _process_forward_movement(delta: float, base_move_speed: float) -> void:
	if movement_component == null:
		return
	if not is_liveness_enabled(&"movement"):
		set_state_value(&"velocity", Vector2.ZERO)
		set_state_value(&"speed", 0.0)
		sync_runtime_state()
		return
	var fallback_velocity := Vector2.LEFT * base_move_speed
	if movement_component.has_method("physics_process_entity_movement"):
		movement_component.call("physics_process_entity_movement", self, delta, fallback_velocity, &"legacy.zombie_walk", true)
	else:
		movement_component.velocity = fallback_velocity * get_effective_movement_scale()
		movement_component.physics_process_movement(self, delta)


func _find_attack_target_with_range(resolved_attack_range: float) -> Node:
	var battle := GameState.current_battle
	if battle == null or not battle.has_method("spatial_query"):
		return null
	var targets: Array = battle.call("spatial_query", {
		"team_exclude": team,
		"lane_ids": PackedInt32Array([lane_id]),
		"center": global_position,
		"radius": resolved_attack_range,
		"x_min": global_position.x - resolved_attack_range,
		"x_max": global_position.x,
		"filter": func(candidate): return candidate != self and candidate.has_method("take_damage") and _matches_default_attack_exposure(candidate) and (not candidate.has_method("is_targetable") or bool(candidate.call("is_targetable"))),
		"sort_by_distance": true,
		"max_results": 1,
	})
	return null if targets.is_empty() else targets[0]


func _matches_default_attack_exposure(candidate: Node) -> bool:
	if candidate == null:
		return false
	if candidate.has_method("get_exposure_state"):
		return StringName(candidate.call("get_exposure_state")) == &"ground"
	return true


func is_runtime_alive() -> bool:
	return not _is_dying


func is_counted_for_objectives() -> bool:
	return is_runtime_alive()


func _resolve_move_speed(params: Dictionary = {}) -> float:
	var source_params := {
		"move_speed_slots_per_sec": move_speed_slots_per_sec,
	}
	for key: Variant in params.keys():
		source_params[key] = params[key]
	var metrics := _get_battlefield_metrics()
	if metrics != null and metrics.has_method("resolve_slots_speed"):
		return float(metrics.call("resolve_slots_speed", source_params, "move_speed_slots_per_sec", move_speed))
	return float(source_params.get("move_speed_slots_per_sec", move_speed_slots_per_sec)) * 96.0


func _get_battlefield_metrics() -> RefCounted:
	if GameState.current_battle == null:
		return null
	if not GameState.current_battle.has_method("get_battlefield_metrics"):
		return null
	var metrics: Variant = GameState.current_battle.call("get_battlefield_metrics")
	return metrics if metrics is RefCounted else null


func _debug_target_id() -> int:
	if _attack_target != null and _attack_target.has_method("get_entity_id"):
		return int(_attack_target.call("get_entity_id"))
	return -1


func _emit_status_effect_observed(effect: StringName, metadata: Dictionary) -> void:
	var signature := "%s:%s" % [String(effect), JSON.stringify(metadata)]
	if _last_status_effect_signature == signature:
		return
	_last_status_effect_signature = signature
	var observed_event = preload("res://scripts/core/runtime/event_data.gd").create(self, _attack_target if _attack_target != null else null, null, PackedStringArray(["status", String(effect)]))
	observed_event.core["effect"] = effect
	for key: Variant in metadata.keys():
		observed_event.core[key] = metadata[key]
	EventBus.push_event(&"status.effect_observed", observed_event)
