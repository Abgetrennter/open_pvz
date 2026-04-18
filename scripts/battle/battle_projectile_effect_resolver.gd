extends RefCounted
class_name BattleProjectileEffectResolver

const ProtocolValidatorRef = preload("res://scripts/core/runtime/protocol_validator.gd")
const ProjectileFlightProfileRef = preload("res://scripts/projectile/projectile_flight_profile.gd")
const ProjectileTemplateRef = preload("res://scripts/core/defs/projectile_template.gd")

var _battle: Node = null


func bind_battle(battle: Node) -> void:
	_battle = battle


func resolve_projectile_effect_params(params: Dictionary) -> Dictionary:
	var resolved: Dictionary = params.duplicate(true)
	var projectile_template = resolved.get("projectile_template", null)
	if projectile_template == null or not (projectile_template is ProjectileTemplateRef):
		return resolved

	var template_errors: Array[String] = ProtocolValidatorRef.validate_projectile_template(projectile_template)
	if not template_errors.is_empty():
		_report_protocol_issues(template_errors, &"projectile_template")
		resolved.erase("projectile_template")
		return resolved

	if projectile_template.default_params is Dictionary:
		for key: Variant in projectile_template.default_params.keys():
			if not resolved.has(key):
				resolved[key] = projectile_template.default_params[key]
	if not resolved.has("flight_profile") and projectile_template.flight_profile != null:
		resolved["flight_profile"] = projectile_template.flight_profile
	if not resolved.has("lifetime") and float(projectile_template.lifetime) > 0.0:
		resolved["lifetime"] = projectile_template.lifetime
	if not resolved.has("hitbox_radius") and float(projectile_template.hitbox_radius) > 0.0:
		resolved["hitbox_radius"] = projectile_template.hitbox_radius
	return resolved


func build_projectile_movement_params(
	context,
	params: Dictionary,
	spawn_position: Vector2,
	direction: Vector2,
	speed: float
) -> Dictionary:
	var movement_params: Dictionary = {}
	var flight_profile: Resource = params.get("flight_profile", null)
	if flight_profile != null:
		var flight_errors: Array[String] = ProtocolValidatorRef.validate_projectile_flight_profile(flight_profile)
		if not flight_errors.is_empty():
			_report_protocol_issues(flight_errors, &"projectile_flight_profile")
			flight_profile = null
	if flight_profile != null and flight_profile.get_script() == ProjectileFlightProfileRef:
		movement_params = _movement_params_from_flight_profile(flight_profile)
	var movement_mode_default: Variant = movement_params.get("move_mode", &"linear")
	movement_params["move_mode"] = StringName(params.get("movement_mode", movement_mode_default))
	if params.get("ignored_entity_ids", null) is PackedInt32Array:
		movement_params["ignored_entity_ids"] = PackedInt32Array(params.get("ignored_entity_ids"))
	elif params.get("ignored_entity_ids", null) is Array:
		var ignored_ids := PackedInt32Array()
		for raw_id in Array(params.get("ignored_entity_ids")):
			ignored_ids.append(int(raw_id))
		movement_params["ignored_entity_ids"] = ignored_ids
	var move_mode: StringName = movement_params["move_mode"]

	match move_mode:
		&"parabola":
			var parabola_target: Node2D = _resolve_projectile_target_node(context)
			var configured_travel_duration := float(movement_params.get("travel_duration", -1.0))
			var default_travel_duration := _estimate_parabola_duration(spawn_position, parabola_target, speed) if configured_travel_duration <= 0.0 else configured_travel_duration
			var travel_duration := float(params.get("travel_duration", default_travel_duration))
			var impact_radius := float(params.get("impact_radius", movement_params.get("impact_radius", 34.0)))
			movement_params["start_position"] = spawn_position
			movement_params["target_node"] = parabola_target
			movement_params["target_position"] = _resolve_projectile_target_position(context, params, spawn_position, direction, speed, travel_duration, parabola_target)
			movement_params["travel_duration"] = travel_duration
			movement_params["arc_height"] = float(params.get("arc_height", movement_params.get("arc_height", 72.0)))
			movement_params["impact_radius"] = impact_radius
			movement_params["collision_padding"] = float(params.get("collision_padding", movement_params.get("collision_padding", 14.0)))
			movement_params["lead_time_scale"] = float(params.get("lead_time_scale", movement_params.get("lead_time_scale", 1.0)))
			var configured_dynamic_adjustment := float(movement_params.get("dynamic_target_adjustment", -1.0))
			var default_dynamic_adjustment := maxf(impact_radius * 1.5, _estimate_target_tracking_budget(parabola_target, travel_duration)) if configured_dynamic_adjustment < 0.0 else configured_dynamic_adjustment
			movement_params["dynamic_target_adjustment"] = float(params.get("dynamic_target_adjustment", default_dynamic_adjustment))
			movement_params["dynamic_target_axis"] = StringName(params.get("dynamic_target_axis", movement_params.get("dynamic_target_axis", &"x")))
		&"track":
			movement_params["target_node"] = _resolve_projectile_target_node(context)
			movement_params["turn_rate"] = float(params.get("turn_rate", 6.0))
		_:
			pass

	return movement_params


func _movement_params_from_flight_profile(flight_profile: Resource) -> Dictionary:
	return {
		"profile_id": StringName(flight_profile.get("profile_id")),
		"move_mode": StringName(flight_profile.get("move_mode")),
		"height_strategy": StringName(flight_profile.get("height_strategy")),
		"flight_height": float(flight_profile.get("flight_height")),
		"arc_height": float(flight_profile.get("peak_height")),
		"projection_scale": float(flight_profile.get("projection_scale")),
		"max_hit_height": float(flight_profile.get("max_hit_height")),
		"hit_strategy": StringName(flight_profile.get("hit_strategy")),
		"terminal_hit_strategy": StringName(flight_profile.get("terminal_hit_strategy")),
		"impact_radius": float(flight_profile.get("impact_radius")),
		"collision_padding": float(flight_profile.get("collision_padding")),
		"travel_duration": float(flight_profile.get("travel_duration")),
		"lead_time_scale": float(flight_profile.get("lead_time_scale")),
		"dynamic_target_adjustment": float(flight_profile.get("dynamic_target_adjustment")),
		"dynamic_target_axis": StringName(flight_profile.get("dynamic_target_axis")),
	}


func _resolve_projectile_target_position(
	context,
	params: Dictionary,
	spawn_position: Vector2,
	direction: Vector2,
	speed: float,
	travel_duration: float,
	target_node: Node2D = null
) -> Vector2:
	var explicit_target: Variant = params.get("target_position", null)
	if explicit_target is Vector2:
		return explicit_target

	if target_node != null:
		return _predict_target_position(spawn_position, target_node, travel_duration, speed, params)

	var distance := float(params.get("distance", 280.0))
	return spawn_position + direction.normalized() * distance


func _resolve_projectile_target_node(context) -> Node2D:
	if context.target_node is Node2D:
		return context.target_node as Node2D
	if context.source_node == null:
		return null
	return _find_nearest_enemy(context.source_node)


func _find_nearest_enemy(source_node: Node) -> Node2D:
	if not (source_node is Node2D):
		return null

	var source_team: Variant = source_node.get("team")
	var source_lane: Variant = source_node.get("lane_id")
	var source_position: Vector2 = _node_ground_position(source_node as Node2D)
	var best_candidate: Node2D = null
	var best_distance := INF

	for child in _battle.get_runtime_entities():
		if child == null or child == source_node:
			continue
		if not child.has_method("take_damage"):
			continue
		if not (child is Node2D):
			continue
		if child.get("team") == source_team:
			continue
		if source_lane is int and child.get("lane_id") != source_lane:
			continue

		var candidate := child as Node2D
		var distance := source_position.distance_to(_node_ground_position(candidate))
		if distance < best_distance:
			best_distance = distance
			best_candidate = candidate

	return best_candidate


func _estimate_parabola_duration(spawn_position: Vector2, target_node: Node2D, speed: float) -> float:
	if target_node == null:
		return max(0.35, 360.0 / max(speed, 1.0))
	var distance := spawn_position.distance_to(_node_ground_position(target_node))
	return max(0.35, distance / max(speed, 1.0))


func _predict_target_position(
	spawn_position: Vector2,
	target_node: Node2D,
	travel_duration: float,
	projectile_speed: float,
	params: Dictionary
) -> Vector2:
	var current_position: Vector2 = _node_ground_position(target_node)
	var lead_time_scale := float(params.get("lead_time_scale", 1.0))
	var max_lead_distance := float(params.get("max_lead_distance", max(120.0, projectile_speed * travel_duration * 1.5)))
	var lead_iterations := maxi(1, int(params.get("lead_iterations", 3)))
	var velocity: Vector2 = _estimate_entity_velocity(target_node)
	var predicted_position := current_position
	for _iteration in range(lead_iterations):
		var intercept_time := maxf(spawn_position.distance_to(predicted_position) / maxf(projectile_speed, 1.0), 0.0)
		predicted_position = current_position + velocity * intercept_time * lead_time_scale
	var predicted_offset := predicted_position - current_position
	if predicted_offset.length() > max_lead_distance:
		predicted_offset = predicted_offset.normalized() * max_lead_distance
	return current_position + predicted_offset


func _estimate_entity_velocity(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO
	if node.has_method("get_entity_state"):
		var snapshot: Dictionary = node.call("get_entity_state")
		var values: Dictionary = snapshot.get("values", {})
		var velocity_value: Variant = values.get("velocity", Vector2.ZERO)
		if velocity_value is Vector2:
			return velocity_value
	if node.has_method("get") and node.get("team") == &"zombie" and node.has_method("is_combat_active") and node.call("is_combat_active"):
		var move_speed_value: Variant = node.get("move_speed")
		if move_speed_value is float or move_speed_value is int:
			return Vector2.LEFT * float(move_speed_value)
	return Vector2.ZERO


func _node_ground_position(node: Node2D) -> Vector2:
	if node == null:
		return Vector2.ZERO
	if node.has_method("get_ground_position"):
		return Vector2(node.call("get_ground_position"))
	return node.global_position


func _estimate_target_tracking_budget(target_node: Node2D, travel_duration: float) -> float:
	if target_node == null:
		return 0.0
	return _estimate_entity_velocity(target_node).length() * travel_duration * 1.25


func _report_protocol_issues(errors: Array[String], scope: StringName) -> void:
	if _battle == null:
		return
	_battle.call("_report_protocol_issues", errors, scope)
