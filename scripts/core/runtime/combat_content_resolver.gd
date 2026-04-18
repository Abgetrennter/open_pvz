extends RefCounted
class_name CombatContentResolver

const EntityTemplateRef = preload("res://scripts/core/defs/entity_template.gd")
const ProjectileTemplateRef = preload("res://scripts/core/defs/projectile_template.gd")


static func resolve_spawn_entry_template(spawn_entry: Resource):
	if spawn_entry == null:
		return null
	var direct_template = spawn_entry.get("entity_template")
	if direct_template != null and direct_template.get_script() == EntityTemplateRef:
		return direct_template
	var template_id := StringName(spawn_entry.get("entity_template_id"))
	if template_id != StringName() and SceneRegistry.has_entity_template(template_id):
		var registered_template = SceneRegistry.get_entity_template(template_id)
		if registered_template != null and registered_template.get_script() == EntityTemplateRef:
			return registered_template
	return null


static func resolve_spawn_overrides(spawn_entry: Resource) -> Dictionary:
	if spawn_entry == null:
		return {}
	var resolved: Dictionary = {}
	var explicit_overrides: Variant = spawn_entry.get("spawn_overrides")
	if explicit_overrides is Dictionary:
		for key: Variant in explicit_overrides.keys():
			resolved[key] = explicit_overrides[key]
	return resolved


static func merge_spawn_params(spawn_entry: Resource, entity_template = null) -> Dictionary:
	var resolved_params: Dictionary = {}
	if entity_template != null and entity_template.get("default_params") is Dictionary:
		resolved_params = entity_template.get("default_params").duplicate(true)
	var spawn_overrides := resolve_spawn_overrides(spawn_entry)
	for key: Variant in spawn_overrides.keys():
		resolved_params[key] = spawn_overrides[key]
	if spawn_entry != null and spawn_entry.get("projectile_template_override") is ProjectileTemplateRef:
		resolved_params["projectile_template"] = spawn_entry.get("projectile_template_override")
	if spawn_entry != null and spawn_entry.get("projectile_flight_profile_override") != null:
		resolved_params["flight_profile"] = spawn_entry.get("projectile_flight_profile_override")
	return resolved_params


static func resolve_projectile_template(spawn_entry: Resource, entity_template = null):
	if spawn_entry != null and spawn_entry.get("projectile_template_override") is ProjectileTemplateRef:
		return spawn_entry.get("projectile_template_override")
	var spawn_overrides := resolve_spawn_overrides(spawn_entry)
	if spawn_overrides.get("projectile_template", null) is ProjectileTemplateRef:
		return spawn_overrides.get("projectile_template")
	if entity_template != null and entity_template.get("projectile_template") is ProjectileTemplateRef:
		return entity_template.get("projectile_template")
	return null


static func resolve_projectile_flight_profile(spawn_entry: Resource, entity_template = null, projectile_template = null) -> Resource:
	if spawn_entry != null and spawn_entry.get("projectile_flight_profile_override") != null:
		return spawn_entry.get("projectile_flight_profile_override")
	var spawn_overrides := resolve_spawn_overrides(spawn_entry)
	if spawn_overrides.get("flight_profile", null) != null:
		return spawn_overrides.get("flight_profile")
	if projectile_template is ProjectileTemplateRef and projectile_template.flight_profile != null:
		return projectile_template.flight_profile
	if entity_template != null:
		return entity_template.get("projectile_flight_profile")
	return null


static func resolve_spawn_hit_height_band_override(spawn_entry: Resource) -> Resource:
	if spawn_entry == null:
		return null
	return spawn_entry.get("hit_height_band_override")


static func resolve_spawn_projectile_profile_override(spawn_entry: Resource) -> Resource:
	if spawn_entry == null:
		return null
	return spawn_entry.get("projectile_flight_profile_override")


static func resolve_hit_height_band(spawn_entry: Resource, entity_template = null) -> Resource:
	var spawn_height_band: Resource = resolve_spawn_hit_height_band_override(spawn_entry)
	if spawn_height_band != null:
		return spawn_height_band
	if entity_template != null:
		return entity_template.get("hit_height_band")
	return null
