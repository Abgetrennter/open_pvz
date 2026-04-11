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


func contains_world_point(world_point: Vector2, padding: float = 0.0) -> bool:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return false

	var local_point: Vector2 = to_local(world_point) - collision_shape.position
	var shape := collision_shape.shape
	if shape is CircleShape2D:
		return local_point.length() <= shape.radius + padding
	if shape is RectangleShape2D:
		var half_size: Vector2 = shape.size * 0.5
		return absf(local_point.x) <= half_size.x + padding and absf(local_point.y) <= half_size.y + padding
	return false


func intersects_world_segment(start_world: Vector2, end_world: Vector2, padding: float = 0.0) -> bool:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return false

	var local_start: Vector2 = to_local(start_world) - collision_shape.position
	var local_end: Vector2 = to_local(end_world) - collision_shape.position
	var shape := collision_shape.shape
	if shape is CircleShape2D:
		var radius: float = shape.radius + padding
		return _distance_squared_to_segment(Vector2.ZERO, local_start, local_end) <= radius * radius
	if shape is RectangleShape2D:
		var half_size: Vector2 = shape.size * 0.5 + Vector2.ONE * padding
		return _segment_intersects_aabb(local_start, local_end, -half_size, half_size)
	return false


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


func _distance_squared_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.00001:
		return point.distance_squared_to(start)
	var t: float = clamp((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var closest: Vector2 = start + segment * t
	return point.distance_squared_to(closest)


func _segment_intersects_aabb(start: Vector2, end: Vector2, min_point: Vector2, max_point: Vector2) -> bool:
	var delta: Vector2 = end - start
	var t_min := 0.0
	var t_max := 1.0

	for axis in range(2):
		var start_axis: float = start.x if axis == 0 else start.y
		var delta_axis: float = delta.x if axis == 0 else delta.y
		var min_axis: float = min_point.x if axis == 0 else min_point.y
		var max_axis: float = max_point.x if axis == 0 else max_point.y

		if absf(delta_axis) <= 0.00001:
			if start_axis < min_axis or start_axis > max_axis:
				return false
			continue

		var inv_delta: float = 1.0 / delta_axis
		var t1: float = (min_axis - start_axis) * inv_delta
		var t2: float = (max_axis - start_axis) * inv_delta
		if t1 > t2:
			var temp := t1
			t1 = t2
			t2 = temp
		t_min = maxf(t_min, t1)
		t_max = minf(t_max, t2)
		if t_min > t_max:
			return false

	return true
