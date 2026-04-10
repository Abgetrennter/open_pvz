extends Area2D
class_name HitboxComponent

signal hit(target: Node)


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func configure_circle(radius: float) -> void:
	var collision_shape := _ensure_collision_shape()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape


func configure_rectangle(size: Vector2) -> void:
	var collision_shape := _ensure_collision_shape()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision_shape.shape = shape


func _ensure_collision_shape() -> CollisionShape2D:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	return collision_shape


func _on_area_entered(area: Area2D) -> void:
	hit.emit(area.get_parent())


func _on_body_entered(body: Node) -> void:
	hit.emit(body)
