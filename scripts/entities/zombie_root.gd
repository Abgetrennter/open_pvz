extends "res://scripts/entities/base_entity.gd"
class_name ZombieRoot

@onready var movement_component: Variant = get_node_or_null("MovementComponent")
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


func _ready() -> void:
	entity_kind = &"zombie"
	team = &"zombie"
	super()
	entity_state["status"] = "alive"
	if health_component != null:
		health_component.damaged.connect(_on_health_changed)
		health_component.died.connect(_on_died)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	_attack_cooldown = max(_attack_cooldown - delta, 0.0)
	_attack_target = _find_attack_target()

	if movement_component != null:
		movement_component.velocity = Vector2.ZERO

	if _attack_target != null:
		if movement_component != null:
			movement_component.velocity = Vector2.ZERO
		_try_attack()
	elif movement_component != null:
		movement_component.velocity = Vector2.LEFT * move_speed
		movement_component.physics_process_movement(self, delta)


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


func take_damage(amount: int, source_node: Node = null, tags: PackedStringArray = PackedStringArray()) -> void:
	if _is_dying:
		return
	if health_component != null:
		health_component.take_damage(amount, source_node, tags)


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
	entity_state["status"] = "dying"
	_attack_target = null
	if movement_component != null:
		movement_component.velocity = Vector2.ZERO
	if hitbox_component != null:
		hitbox_component.set_deferred("monitorable", false)
		hitbox_component.set_deferred("monitoring", false)
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


func _try_attack() -> void:
	if _attack_target == null or _attack_cooldown > 0.0:
		return
	if not is_instance_valid(_attack_target):
		_attack_target = null
		return

	_attack_cooldown = attack_interval
	_attack_target.call("take_damage", attack_damage, self, PackedStringArray(["bite"]))


func is_combat_active() -> bool:
	return not _is_dying
