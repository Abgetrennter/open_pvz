extends "res://scripts/entities/base_entity.gd"
class_name ZombieRoot

@onready var movement_component: Variant = get_node_or_null("MovementComponent")
@onready var controller_component: Variant = get_node_or_null("ControllerComponent")
@onready var health_component: Variant = get_node_or_null("HealthComponent")
@onready var hitbox_component: Variant = get_node_or_null("HitboxComponent")

const BODY_COLOR := Color("8b7f6b")
const OUTLINE_COLOR := Color("2d241b")
const HEALTH_GOOD := Color("72d66f")
const HEALTH_BAD := Color("c44a3d")

@export var move_speed := 55.0
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
	set_state_value(&"move_speed", move_speed)
	if health_component != null:
		health_component.damaged.connect(_on_health_changed)
		health_component.died.connect(_on_died)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if controller_component != null and controller_component.has_method("has_active_controllers") and bool(controller_component.call("has_active_controllers")):
		controller_component.call("physics_process_controllers", delta)
		return

	_attack_cooldown = max(_attack_cooldown - delta, 0.0)
	_attack_target = _find_attack_target()
	var movement_scale := get_effective_movement_scale() if has_method("get_effective_movement_scale") else 1.0
	var effective_move_speed := move_speed * movement_scale

	if movement_component != null:
		movement_component.velocity = Vector2.ZERO

	if _attack_target != null:
		if movement_component != null:
			movement_component.velocity = Vector2.ZERO
		set_state_value(&"velocity", Vector2.ZERO)
		set_state_value(&"speed", 0.0)
		sync_runtime_state()
		set_state_value(&"attack_target_id", _debug_target_id())
		if is_attack_blocked():
			_attack_cooldown = attack_interval
			_emit_status_effect_observed(&"attack_blocked", {
				"movement_scale": movement_scale,
			})
			return
		_try_attack()
	elif movement_component != null:
		movement_component.velocity = Vector2.LEFT * effective_move_speed
		movement_component.physics_process_movement(self, delta)
		set_state_value(&"attack_target_id", -1)
		if movement_scale < 0.999:
			_emit_status_effect_observed(&"movement_scaled", {
				"movement_scale": movement_scale,
				"effective_move_speed": effective_move_speed,
			})


func _process(delta: float) -> void:
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
	var body_color := BODY_COLOR if not _is_dying else BODY_COLOR.darkened(0.25)
	draw_rect(Rect2(Vector2(-18, -34), Vector2(36, 54)), body_color)
	draw_rect(Rect2(Vector2(-18, -34), Vector2(36, 54)), OUTLINE_COLOR, false, 2.0)
	draw_rect(Rect2(Vector2(-14, -48), Vector2(28, 12)), body_color.darkened(0.1))
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
	var battle := get_parent()
	if battle == null:
		return null

	var best_target: Node = null
	var best_distance := INF

	for child in battle.get_children():
		if child == null or child == self:
			continue
		if not child.has_method("take_damage"):
			continue
		if not child.has_method("get"):
			continue
		if child.get("team") == team:
			continue
		if child.get("lane_id") != lane_id:
			continue
		if child.has_method("is_combat_active") and not child.call("is_combat_active"):
			continue
		if not (child is Node2D):
			continue

		var target_node := child as Node2D
		var x_distance := global_position.x - target_node.global_position.x
		if x_distance < 0.0:
			continue
		if x_distance > attack_range:
			continue
		if x_distance < best_distance:
			best_distance = x_distance
			best_target = child

	return best_target


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
	var resolved_move_speed := float(params.get("move_speed", move_speed))
	var resolved_attack_range := float(params.get("attack_range", attack_range))
	_attack_cooldown = max(_attack_cooldown - delta, 0.0)
	var movement_scale := get_effective_movement_scale() if has_method("get_effective_movement_scale") else 1.0
	var effective_move_speed := resolved_move_speed * movement_scale
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
		if is_attack_blocked():
			_attack_cooldown = resolved_attack_interval
			_emit_status_effect_observed(&"attack_blocked", {
				"movement_scale": movement_scale,
			})
			return
		if _attack_cooldown <= 0.0 and is_instance_valid(_attack_target):
			_attack_cooldown = resolved_attack_interval
			_attack_target.call("take_damage", resolved_attack_damage, self, PackedStringArray(["bite"]))
	elif movement_component != null:
		movement_component.velocity = Vector2.LEFT * effective_move_speed
		movement_component.physics_process_movement(self, delta)
		set_state_value(&"attack_target_id", -1)
		if movement_scale < 0.999:
			_emit_status_effect_observed(&"movement_scaled", {
				"movement_scale": movement_scale,
				"effective_move_speed": effective_move_speed,
			})


func _find_attack_target_with_range(resolved_attack_range: float) -> Node:
	var battle := get_parent()
	if battle == null:
		return null
	var best_target: Node = null
	var best_distance := INF
	for child in battle.get_children():
		if child == null or child == self:
			continue
		if not child.has_method("take_damage"):
			continue
		if not child.has_method("get"):
			continue
		if child.get("team") == team:
			continue
		if child.get("lane_id") != lane_id:
			continue
		if child.has_method("is_combat_active") and not child.call("is_combat_active"):
			continue
		if not (child is Node2D):
			continue
		var target_node := child as Node2D
		var x_distance := global_position.x - target_node.global_position.x
		if x_distance < 0.0:
			continue
		if x_distance > resolved_attack_range:
			continue
		if x_distance < best_distance:
			best_distance = x_distance
			best_target = child
	return best_target


func is_combat_active() -> bool:
	return not _is_dying


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
