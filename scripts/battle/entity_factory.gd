extends RefCounted
class_name EntityFactory

const PlantRootRef = preload("res://scripts/entities/plant_root.gd")
const ZombieRootRef = preload("res://scripts/entities/zombie_root.gd")
const ProjectileRootRef = preload("res://scripts/entities/projectile_root.gd")
const TriggerComponentRef = preload("res://scripts/components/trigger_component.gd")
const HealthComponentRef = preload("res://scripts/components/health_component.gd")
const MovementComponentRef = preload("res://scripts/components/movement_component.gd")
const HitboxComponentRef = preload("res://scripts/components/hitbox_component.gd")
const DebugViewComponentRef = preload("res://scripts/components/debug_view_component.gd")
const EntityTemplateRef = preload("res://scripts/core/defs/entity_template.gd")

const DEFAULT_TEMPLATE_CONFIG := {
	&"plant": {
		"max_health": 100,
		"hitbox_size": Vector2(42.0, 54.0),
		"trigger_component": true,
		"movement_component": false,
		"debug_view_component": true,
	},
	&"zombie": {
		"max_health": 120,
		"hitbox_size": Vector2(44.0, 60.0),
		"trigger_component": true,
		"movement_component": true,
		"debug_view_component": false,
	},
}

func instantiate_spawn_entry(spawn_entry: Resource, position: Vector2) -> Dictionary:
	var entity_template = _resolve_template(spawn_entry)
	var entity_kind: StringName = _resolve_entity_kind(spawn_entry, entity_template)
	var params: Dictionary = _resolve_params(spawn_entry, entity_template)
	var entity = instantiate_entity(entity_kind, position, entity_template, params)
	if entity == null:
		return {}
	return {
		"entity": entity,
		"entity_kind": entity_kind,
		"entity_template": entity_template,
		"params": params,
		"hit_height_band": _resolve_hit_height_band(spawn_entry, entity_template),
		"projectile_flight_profile": _resolve_projectile_flight_profile(spawn_entry, entity_template),
	}


func instantiate_entity(entity_kind: StringName, position: Vector2, template = null, params: Dictionary = {}):
	var entity: Variant = _instantiate_root(entity_kind, template)
	if entity == null:
		return null
	if entity is Node2D:
		(entity as Node2D).position = position
	_ensure_template_components(entity, entity_kind, template, params)
	_apply_template_metadata(entity, template)
	_apply_entity_property_overrides(entity, params)
	return entity


func create_plant(position: Vector2, template = null, params: Dictionary = {}):
	return instantiate_entity(&"plant", position, template, params)


func create_zombie(position: Vector2, template = null, params: Dictionary = {}):
	return instantiate_entity(&"zombie", position, template, params)


func create_projectile(position: Vector2):
	var projectile: Variant = ProjectileRootRef.new()
	projectile.position = position
	projectile.add_child(_make_projectile_hitbox(10.0))
	return projectile


func _resolve_template(spawn_entry: Resource):
	if spawn_entry == null or spawn_entry.get("entity_template") == null:
		return null
	var entity_template = spawn_entry.get("entity_template")
	if entity_template != null and entity_template.get_script() == EntityTemplateRef:
		return entity_template
	return null


func _resolve_entity_kind(spawn_entry: Resource, entity_template = null) -> StringName:
	if entity_template != null and StringName(entity_template.entity_kind) != StringName():
		return StringName(entity_template.entity_kind)
	return StringName(spawn_entry.get("entity_kind"))


func _resolve_params(spawn_entry: Resource, entity_template = null) -> Dictionary:
	var resolved_params: Dictionary = {}
	if entity_template != null and entity_template.default_params is Dictionary:
		resolved_params = entity_template.default_params.duplicate(true)
	var spawn_params: Variant = spawn_entry.get("params")
	if spawn_params is Dictionary:
		for key: Variant in spawn_params.keys():
			resolved_params[key] = spawn_params[key]
	return resolved_params


func _resolve_hit_height_band(spawn_entry: Resource, entity_template = null) -> Resource:
	var spawn_height_band: Variant = spawn_entry.get("hit_height_band")
	if spawn_height_band != null:
		return spawn_height_band
	if entity_template != null:
		return entity_template.hit_height_band
	return null


func _resolve_projectile_flight_profile(spawn_entry: Resource, entity_template = null) -> Resource:
	var spawn_profile: Variant = spawn_entry.get("projectile_flight_profile")
	if spawn_profile != null:
		return spawn_profile
	if entity_template != null:
		return entity_template.projectile_flight_profile
	return null


func _instantiate_root(entity_kind: StringName, template = null):
	if template is EntityTemplateRef and template.root_scene != null:
		var instantiated = template.root_scene.instantiate()
		if instantiated is Node2D:
			return instantiated
		push_warning("EntityTemplate %s root_scene must instantiate a Node2D." % String(template.template_id))
	return _instantiate_builtin_root(entity_kind)


func _instantiate_builtin_root(entity_kind: StringName):
	match entity_kind:
		&"plant":
			return PlantRootRef.new()
		&"zombie":
			return ZombieRootRef.new()
		_:
			push_warning("Unsupported entity kind for template factory: %s" % String(entity_kind))
			return null


func _ensure_template_components(entity: Node, entity_kind: StringName, template = null, params: Dictionary = {}) -> void:
	if entity == null:
		return
	var config := _default_config_for_kind(entity_kind)
	if bool(config.get("trigger_component", false)):
		_ensure_named_child(entity, "TriggerComponent", func(): return _make_trigger_component())
	if bool(config.get("movement_component", false)):
		_ensure_named_child(entity, "MovementComponent", func(): return _make_movement_component())
	var resolved_max_health := _resolve_max_health(entity_kind, template, params)
	_ensure_health_component(entity, resolved_max_health)
	var resolved_hitbox_size := _resolve_hitbox_size(entity_kind, template, params)
	_ensure_passive_hitbox(entity, resolved_hitbox_size)
	if bool(config.get("debug_view_component", false)):
		_ensure_named_child(entity, "DebugViewComponent", func(): return _make_debug_component())


func _default_config_for_kind(entity_kind: StringName) -> Dictionary:
	if DEFAULT_TEMPLATE_CONFIG.has(entity_kind):
		return DEFAULT_TEMPLATE_CONFIG[entity_kind]
	return {}


func _resolve_max_health(entity_kind: StringName, template = null, params: Dictionary = {}) -> int:
	var default_value := int(_default_config_for_kind(entity_kind).get("max_health", 100))
	if params.has("max_health"):
		return int(params.get("max_health", default_value))
	if template is EntityTemplateRef and int(template.max_health) > 0:
		return int(template.max_health)
	return default_value


func _resolve_hitbox_size(entity_kind: StringName, template = null, params: Dictionary = {}) -> Vector2:
	var default_value: Variant = _default_config_for_kind(entity_kind).get("hitbox_size", Vector2(40.0, 40.0))
	if params.has("hitbox_size") and params["hitbox_size"] is Vector2:
		return params["hitbox_size"]
	if template is EntityTemplateRef and template.hitbox_size != Vector2.ZERO:
		return template.hitbox_size
	return default_value


func _ensure_named_child(parent: Node, child_name: String, builder: Callable) -> Node:
	var existing := parent.get_node_or_null(child_name)
	if existing != null:
		return existing
	var child = builder.call()
	child.name = child_name
	parent.add_child(child)
	return child


func _ensure_health_component(entity: Node, max_health: int) -> void:
	var component := _ensure_named_child(entity, "HealthComponent", func(): return _make_health_component(max_health))
	if component != null and component.has_method("set"):
		component.set("max_health", max_health)


func _ensure_passive_hitbox(entity: Node, size: Vector2) -> void:
	var component := _ensure_named_child(entity, "HitboxComponent", func(): return _make_passive_hitbox(size))
	if component != null and component.has_method("configure_rectangle"):
		component.call("configure_rectangle", size)
		component.set("monitoring", false)
		component.set("monitorable", true)
		component.set("collision_layer", 1)
		component.set("collision_mask", 0)


func _apply_entity_property_overrides(entity: Node, params: Dictionary) -> void:
	if entity == null or params.is_empty():
		return
	var property_names: Dictionary = {}
	for property_info in entity.get_property_list():
		if not (property_info is Dictionary):
			continue
		var property_name := String(property_info.get("name", ""))
		if property_name.is_empty():
			continue
		property_names[property_name] = true
	for key: Variant in params.keys():
		var property_name := str(key)
		if not property_names.has(property_name):
			continue
		entity.set(property_name, params[key])


func _make_trigger_component():
	var component: Variant = TriggerComponentRef.new()
	component.name = "TriggerComponent"
	return component


func _make_health_component(max_health: int):
	var component: Variant = HealthComponentRef.new()
	component.name = "HealthComponent"
	component.max_health = max_health
	return component


func _make_movement_component():
	var component: Variant = MovementComponentRef.new()
	component.name = "MovementComponent"
	return component


func _make_projectile_hitbox(radius: float):
	var component: Variant = HitboxComponentRef.new()
	component.name = "HitboxComponent"
	component.monitoring = true
	component.monitorable = true
	component.collision_layer = 1
	component.collision_mask = 1
	component.configure_circle(radius)
	return component


func _make_passive_hitbox(size: Vector2):
	var component: Variant = HitboxComponentRef.new()
	component.name = "HitboxComponent"
	component.monitoring = false
	component.monitorable = true
	component.collision_layer = 1
	component.collision_mask = 0
	component.configure_rectangle(size)
	return component


func _make_debug_component():
	var component: Variant = DebugViewComponentRef.new()
	component.name = "DebugViewComponent"
	return component


func _apply_template_metadata(entity: Node, template) -> void:
	if entity == null or template == null:
		return
	if template is EntityTemplateRef and template.template_id != StringName():
		entity.set("template_id", template.template_id)
