extends RefCounted
class_name EntityFactory

const PlantRootRef = preload("res://scripts/entities/plant_root.gd")
const ZombieRootRef = preload("res://scripts/entities/zombie_root.gd")
const FieldObjectRootRef = preload("res://scripts/entities/field_object_root.gd")
const LawnMowerRef = preload("res://scripts/entities/lawn_mower.gd")
const ProjectileRootRef = preload("res://scripts/entities/projectile_root.gd")
const EffectNodeRef = preload("res://scripts/core/runtime/effect_node.gd")
const TriggerInstanceRef = preload("res://scripts/core/runtime/trigger_instance.gd")
const TriggerComponentRef = preload("res://scripts/components/trigger_component.gd")
const HealthComponentRef = preload("res://scripts/components/health_component.gd")
const MovementComponentRef = preload("res://scripts/components/movement_component.gd")
const HitboxComponentRef = preload("res://scripts/components/hitbox_component.gd")
const DebugViewComponentRef = preload("res://scripts/components/debug_view_component.gd")
const EntityTemplateRef = preload("res://scripts/core/defs/entity_template.gd")
const ProjectileTemplateRef = preload("res://scripts/core/defs/projectile_template.gd")
const TriggerBindingRef = preload("res://scripts/core/defs/trigger_binding.gd")
const ProjectileFlightProfileRef = preload("res://scripts/projectile/projectile_flight_profile.gd")
const CombatContentResolverRef = preload("res://scripts/core/runtime/combat_content_resolver.gd")

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
	&"field_object": {
		"max_health": -1,
		"hitbox_size": Vector2(36.0, 36.0),
		"trigger_component": false,
		"movement_component": false,
		"debug_view_component": true,
	},
}
const SPAWN_ENTRY_RESERVED_PARAMS := {
	"interval": true,
	"damage": true,
	"speed": true,
	"effect_overrides": true,
	"on_hit_effect_id": true,
	"on_hit_effect_params": true,
}

func instantiate_spawn_entry(spawn_entry: Resource, position: Vector2) -> Dictionary:
	var entity_template = _resolve_template(spawn_entry)
	if entity_template == null:
		return {}
	var entity_kind: StringName = _resolve_entity_kind(spawn_entry, entity_template)
	var params: Dictionary = _resolve_params(spawn_entry, entity_template)
	var projectile_template: Resource = _resolve_projectile_template(spawn_entry, entity_template)
	var projectile_flight_profile: Resource = _resolve_projectile_flight_profile(spawn_entry, entity_template, projectile_template)
	var entity = instantiate_entity(entity_kind, position, entity_template, params)
	if entity == null:
		return {}
	return {
		"entity": entity,
		"entity_kind": entity_kind,
		"entity_template": entity_template,
		"params": params,
		"hit_height_band": _resolve_hit_height_band(spawn_entry, entity_template),
		"projectile_template": projectile_template,
		"projectile_flight_profile": projectile_flight_profile,
		"trigger_instances": build_runtime_triggers(entity_kind, entity_template, params, projectile_flight_profile, projectile_template),
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
	_apply_runtime_param_metadata(entity, params)
	return entity


func create_plant(position: Vector2, template = null, params: Dictionary = {}):
	return instantiate_entity(&"plant", position, template, params)


func create_zombie(position: Vector2, template = null, params: Dictionary = {}):
	return instantiate_entity(&"zombie", position, template, params)


func create_projectile(position: Vector2, projectile_template = null, params: Dictionary = {}):
	var projectile: Variant = _instantiate_projectile_root(projectile_template)
	if projectile == null:
		projectile = ProjectileRootRef.new()
	projectile.position = position
	_apply_projectile_template_metadata(projectile, projectile_template)
	_ensure_projectile_hitbox(projectile, _resolve_projectile_hitbox_radius(projectile_template, params))
	_apply_projectile_property_overrides(projectile, projectile_template, params)
	return projectile


func build_runtime_triggers(
	entity_kind: StringName,
	template = null,
	params: Dictionary = {},
	projectile_flight_profile: Resource = null,
	projectile_template = null
) -> Array:
	var trigger_bindings: Array = _resolve_trigger_bindings(template)
	if trigger_bindings.is_empty():
		return []
	return _build_triggers_from_bindings(trigger_bindings, entity_kind, params, projectile_flight_profile, projectile_template)


func _resolve_template(spawn_entry: Resource):
	return CombatContentResolverRef.resolve_spawn_entry_template(spawn_entry)


func _resolve_entity_kind(spawn_entry: Resource, entity_template = null) -> StringName:
	if entity_template != null and StringName(entity_template.entity_kind) != StringName():
		return StringName(entity_template.entity_kind)
	return StringName(spawn_entry.get("entity_kind"))


func _resolve_params(spawn_entry: Resource, entity_template = null) -> Dictionary:
	return CombatContentResolverRef.merge_spawn_params(spawn_entry, entity_template)


func _resolve_hit_height_band(spawn_entry: Resource, entity_template = null) -> Resource:
	return CombatContentResolverRef.resolve_hit_height_band(spawn_entry, entity_template)


func _resolve_projectile_flight_profile(spawn_entry: Resource, entity_template = null, projectile_template = null) -> Resource:
	var resolved_profile: Resource = CombatContentResolverRef.resolve_projectile_flight_profile(spawn_entry, entity_template, projectile_template)
	if resolved_profile != null:
		return resolved_profile
	var spawn_overrides := _resolve_spawn_overrides(spawn_entry)
	if spawn_overrides.get("projectile_template", null) is ProjectileTemplateRef:
		var spawn_projectile_template = spawn_overrides.get("projectile_template")
		if spawn_projectile_template.flight_profile != null:
			return spawn_projectile_template.flight_profile
	if entity_template != null and entity_template.get("projectile_template") is ProjectileTemplateRef:
		var template_projectile_template = entity_template.get("projectile_template")
		if template_projectile_template.flight_profile != null:
			return template_projectile_template.flight_profile
	return null


func _resolve_projectile_template(spawn_entry: Resource, entity_template = null):
	return CombatContentResolverRef.resolve_projectile_template(spawn_entry, entity_template)


func _resolve_spawn_overrides(spawn_entry: Resource) -> Dictionary:
	return CombatContentResolverRef.resolve_spawn_overrides(spawn_entry)


func _instantiate_root(entity_kind: StringName, template = null):
	if template is EntityTemplateRef and template.root_scene != null:
		var instantiated = template.root_scene.instantiate()
		if instantiated is Node2D:
			return instantiated
		push_warning("EntityTemplate %s root_scene must instantiate a Node2D." % String(template.template_id))
	return _instantiate_builtin_root(entity_kind, template)


func _instantiate_builtin_root(entity_kind: StringName, template = null):
	match entity_kind:
		&"plant":
			return PlantRootRef.new()
		&"zombie":
			return ZombieRootRef.new()
		&"field_object":
			return _instantiate_field_object(template)
		_:
			push_warning("Unsupported entity kind for template factory: %s" % String(entity_kind))
			return null


func _instantiate_field_object(template):
	if template is EntityTemplateRef:
		match StringName(template.template_id):
			&"field_object_lawn_mower":
				return LawnMowerRef.new()
	return FieldObjectRootRef.new()


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
	_ensure_required_template_components(entity, template)


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


func _apply_runtime_param_metadata(entity: Node, params: Dictionary) -> void:
	if entity == null or params.is_empty():
		return
	if not entity.has_method("set_state_value"):
		return


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
		if entity.has_method("set_state_value"):
			entity.call("set_state_value", &"template_tags", template.tags)
			entity.call("set_state_value", &"template_required_components", template.required_components)
			entity.call("set_state_value", &"template_optional_components", template.optional_components)


func _build_simple_effect_node(effect_id: StringName, effect_params: Dictionary):
	return EffectNodeRef.new(effect_id, effect_params.duplicate(true))


func _resolve_trigger_bindings(template) -> Array:
	if template is EntityTemplateRef and template.trigger_bindings is Array:
		var resolved: Array = []
		for binding in template.trigger_bindings:
			if binding is TriggerBindingRef:
				resolved.append(binding)
		return resolved
	return []


func _build_triggers_from_bindings(
	trigger_bindings: Array,
	entity_kind: StringName,
	params: Dictionary,
	projectile_flight_profile: Resource,
	projectile_template
) -> Array:
	var triggers: Array = []
	for binding in trigger_bindings:
		if not (binding is TriggerBindingRef):
			continue
		if not bool(binding.enabled):
			continue
		var trigger = TriggerInstanceRef.new()
		trigger.def_id = StringName(binding.trigger_id)
		trigger.event_name = StringName(binding.event_name)
		trigger.condition_values = _merge_binding_condition_values(binding, params)
		trigger.bind_time = GameState.current_time
		var effect_node = _build_effect_node_from_binding(binding, entity_kind, params, projectile_flight_profile, projectile_template)
		if effect_node != null:
			trigger.effect_roots = [effect_node]
			triggers.append(trigger)
	return triggers


func _merge_binding_condition_values(binding, params: Dictionary) -> Dictionary:
	var merged: Dictionary = binding.condition_values.duplicate(true)
	for key: Variant in merged.keys():
		if params.has(key):
			merged[key] = params[key]
	return merged


func _build_effect_node_from_binding(
	binding,
	entity_kind: StringName,
	params: Dictionary,
	projectile_flight_profile: Resource,
	projectile_template
):
	if binding == null or not (binding is TriggerBindingRef):
		return null
	var effect_id := StringName(binding.effect_id)
	if effect_id == StringName():
		return null
	var effect_params: Dictionary = binding.effect_params.duplicate(true)
	if effect_id == &"spawn_projectile":
		effect_params = _merge_projectile_binding_params(effect_params, params, projectile_flight_profile, projectile_template, binding.projectile_template)
		return EffectNodeRef.new(effect_id, effect_params, {
			&"on_hit": _build_binding_on_hit_effect_node(binding, params),
		})
	for key: Variant in params.keys():
		if effect_params.has(key):
			effect_params[key] = params[key]
	return _build_simple_effect_node(effect_id, effect_params)


func _merge_projectile_binding_params(
	effect_params: Dictionary,
	params: Dictionary,
	projectile_flight_profile: Resource,
	template_projectile_template,
	binding_projectile_template
) -> Dictionary:
	var merged: Dictionary = {}
	var resolved_projectile_template = null
	if params.get("projectile_template", null) is ProjectileTemplateRef:
		resolved_projectile_template = params.get("projectile_template")
	elif binding_projectile_template is ProjectileTemplateRef:
		resolved_projectile_template = binding_projectile_template
	else:
		resolved_projectile_template = template_projectile_template
	if resolved_projectile_template is ProjectileTemplateRef and resolved_projectile_template.default_params is Dictionary:
		merged = resolved_projectile_template.default_params.duplicate(true)
	for key: Variant in params.keys():
		if _is_spawn_projectile_override_key(key):
			merged[key] = params[key]
	for key: Variant in effect_params.keys():
		merged[key] = effect_params[key]
	for key: Variant in params.keys():
		if effect_params.has(key) or _is_spawn_projectile_override_key(key):
			merged[key] = params[key]
	if resolved_projectile_template is ProjectileTemplateRef:
		merged["projectile_template"] = resolved_projectile_template
		if not merged.has("flight_profile") and resolved_projectile_template.flight_profile != null:
			merged["flight_profile"] = resolved_projectile_template.flight_profile
	if not merged.has("flight_profile") and projectile_flight_profile != null:
		merged["flight_profile"] = projectile_flight_profile
	if not merged.has("movement_mode") and merged.get("flight_profile", null) is ProjectileFlightProfileRef:
		merged["movement_mode"] = StringName(merged["flight_profile"].get("move_mode"))
	return merged


func _is_spawn_projectile_override_key(key: Variant) -> bool:
	return str(key) in [
		"projectile_template",
		"flight_profile",
		"movement_mode",
		"travel_duration",
		"arc_height",
		"impact_radius",
		"collision_padding",
		"lead_time_scale",
		"dynamic_target_adjustment",
		"dynamic_target_axis",
		"max_lead_distance",
		"lead_iterations",
		"target_position",
		"distance",
		"lifetime",
		"hitbox_radius",
	]


func _build_binding_on_hit_effect_node(binding, params: Dictionary):
	var effect_id := StringName(params.get("on_hit_effect_id", binding.on_hit_effect_id))
	var effect_params: Dictionary = binding.on_hit_effect_params.duplicate(true)
	var override_on_hit_params: Dictionary = {}
	if params.get("on_hit_effect_params", null) is Dictionary:
		override_on_hit_params = params.get("on_hit_effect_params").duplicate(true)
		for key: Variant in override_on_hit_params.keys():
			effect_params[key] = override_on_hit_params[key]
	if effect_id == StringName():
		effect_id = &"damage"
		if not effect_params.has("target_mode"):
			effect_params["target_mode"] = &"context_target"
	var on_hit_effect_def = EffectRegistry.get_def(effect_id)
	var supports_amount := false
	if on_hit_effect_def != null and on_hit_effect_def.has_method("get_param_def"):
		supports_amount = not Dictionary(on_hit_effect_def.call("get_param_def", &"amount")).is_empty()
	if supports_amount:
		if params.has("damage") and not override_on_hit_params.has("amount"):
			effect_params["amount"] = params.get("damage")
		elif not effect_params.has("amount"):
			effect_params["amount"] = params.get("damage", binding.effect_params.get("damage", 10))
	return EffectNodeRef.new(effect_id, effect_params)


func _instantiate_projectile_root(projectile_template):
	if projectile_template is ProjectileTemplateRef and projectile_template.root_scene != null:
		var instantiated = projectile_template.root_scene.instantiate()
		if instantiated is Node2D:
			return instantiated
		push_warning("ProjectileTemplate %s root_scene must instantiate a Node2D." % String(projectile_template.template_id))
	return ProjectileRootRef.new()


func _ensure_projectile_hitbox(projectile: Node, radius: float) -> void:
	var existing := projectile.get_node_or_null("HitboxComponent")
	if existing == null:
		projectile.add_child(_make_projectile_hitbox(radius))
		return
	if existing.has_method("configure_circle"):
		existing.call("configure_circle", radius)
		existing.set("monitoring", true)
		existing.set("monitorable", true)
		existing.set("collision_layer", 1)
		existing.set("collision_mask", 1)


func _resolve_projectile_hitbox_radius(projectile_template, params: Dictionary) -> float:
	if params.get("hitbox_radius", null) is float or params.get("hitbox_radius", null) is int:
		return float(params.get("hitbox_radius"))
	if projectile_template is ProjectileTemplateRef and float(projectile_template.hitbox_radius) > 0.0:
		return float(projectile_template.hitbox_radius)
	return 10.0


func _apply_projectile_template_metadata(projectile: Node, projectile_template) -> void:
	if projectile == null or not (projectile_template is ProjectileTemplateRef):
		return
	if projectile_template.template_id != StringName():
		projectile.set("template_id", projectile_template.template_id)
	if projectile.has_method("set_state_value"):
		projectile.call("set_state_value", &"template_tags", projectile_template.tags)
		projectile.call("set_state_value", &"projectile_template_id", projectile_template.template_id)


func _apply_projectile_property_overrides(projectile: Node, projectile_template, params: Dictionary) -> void:
	if projectile == null:
		return
	if projectile_template is ProjectileTemplateRef and float(projectile_template.lifetime) > 0.0 and projectile.has_method("set"):
		projectile.set("lifetime", projectile_template.lifetime)
	if params.has("lifetime") and projectile.has_method("set"):
		projectile.set("lifetime", params["lifetime"])


func _ensure_required_template_components(entity: Node, template) -> void:
	if entity == null or not (template is EntityTemplateRef):
		return
	for component_name in template.required_components:
		match String(component_name):
			"TriggerComponent":
				_ensure_named_child(entity, "TriggerComponent", func(): return _make_trigger_component())
			"MovementComponent":
				_ensure_named_child(entity, "MovementComponent", func(): return _make_movement_component())
			"DebugViewComponent":
				_ensure_named_child(entity, "DebugViewComponent", func(): return _make_debug_component())
			_:
				pass
