extends RefCounted
class_name CombatContentResolver

const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")
const EntityTemplateRef = preload("res://scripts/core/defs/entity_template.gd")
const MechanicCompilerRef = preload("res://scripts/core/runtime/mechanic_compiler.gd")
const ProjectileTemplateRef = preload("res://scripts/core/defs/projectile_template.gd")


static func resolve_spawn_entry_template(spawn_entry: Resource):
	if spawn_entry == null:
		return null
	var resolved_archetype = resolve_spawn_entry_archetype(spawn_entry)
	if resolved_archetype != null:
		return resolve_archetype_backend_entity_template(resolved_archetype)
	return null


static func resolve_spawn_entry_archetype(spawn_entry: Resource):
	if spawn_entry == null:
		return null
	var direct_archetype = spawn_entry.get("archetype")
	if direct_archetype is CombatArchetypeRef:
		return direct_archetype
	var archetype_id := StringName(spawn_entry.get("archetype_id"))
	if archetype_id != StringName() and SceneRegistry.has_archetype(archetype_id):
		var registered_archetype = SceneRegistry.get_archetype(archetype_id)
		if registered_archetype is CombatArchetypeRef:
			return registered_archetype
	return null


static func resolve_archetype_backend_entity_template(archetype):
	if archetype == null or not (archetype is CombatArchetypeRef):
		return null
	if archetype.backend_entity_template is EntityTemplateRef:
		return archetype.backend_entity_template
	var backend_template_id := StringName(archetype.get("backend_entity_template_id"))
	if backend_template_id != StringName() and SceneRegistry.has_entity_template(backend_template_id):
		var resolved = SceneRegistry.get_entity_template(backend_template_id)
		if resolved is EntityTemplateRef:
			return resolved
	return null


static func resolve_spawn_entry_runtime_spec(spawn_entry: Resource):
	var archetype = resolve_spawn_entry_archetype(spawn_entry)
	if archetype == null:
		return null
	# TODO(mechanic-first): Replace reflective call() with a typed compiler
	# bridge after the new compiler graph is fully loaded in stable parse order.
	var compiler = MechanicCompilerRef.new()
	var runtime_spec = compiler.call("compile_spawn_entry", spawn_entry, archetype)
	if runtime_spec == null:
		return null
	var backend_template = resolve_archetype_backend_entity_template(archetype)
	var resolved_params = merge_spawn_params(spawn_entry, backend_template, archetype)
	if resolved_params is Dictionary:
		runtime_spec.params = resolved_params
	var resolved_projectile_template = resolve_projectile_template(spawn_entry, backend_template, archetype)
	if resolved_projectile_template != null:
		runtime_spec.projectile_template = resolved_projectile_template
	var resolved_projectile_flight_profile = resolve_projectile_flight_profile(
		spawn_entry,
		backend_template,
		resolved_projectile_template,
		archetype
	)
	if resolved_projectile_flight_profile != null:
		runtime_spec.projectile_flight_profile = resolved_projectile_flight_profile
	var resolved_hit_height_band = resolve_hit_height_band(spawn_entry, backend_template, archetype)
	if resolved_hit_height_band != null:
		runtime_spec.hit_height_band = resolved_hit_height_band
	return runtime_spec


static func resolve_spawn_overrides(spawn_entry: Resource) -> Dictionary:
	if spawn_entry == null:
		return {}
	var resolved: Dictionary = {}
	var explicit_overrides: Variant = spawn_entry.get("spawn_overrides")
	if explicit_overrides is Dictionary:
		for key: Variant in explicit_overrides.keys():
			resolved[key] = explicit_overrides[key]
	return resolved


static func merge_spawn_params(spawn_entry: Resource, entity_template = null, archetype = null) -> Dictionary:
	var resolved_params: Dictionary = {}
	if entity_template != null and entity_template.get("default_params") is Dictionary:
		resolved_params = entity_template.get("default_params").duplicate(true)
	if archetype != null and archetype.get("default_params") is Dictionary:
		for key: Variant in archetype.get("default_params").keys():
			resolved_params[key] = archetype.get("default_params")[key]
	var spawn_overrides := resolve_spawn_overrides(spawn_entry)
	for key: Variant in spawn_overrides.keys():
		resolved_params[key] = spawn_overrides[key]
	if spawn_entry != null and spawn_entry.get("projectile_template_override") is ProjectileTemplateRef:
		resolved_params["projectile_template"] = spawn_entry.get("projectile_template_override")
	if spawn_entry != null and spawn_entry.get("projectile_flight_profile_override") != null:
		resolved_params["flight_profile"] = spawn_entry.get("projectile_flight_profile_override")
	return resolved_params


static func resolve_projectile_template(spawn_entry: Resource, entity_template = null, archetype = null):
	if spawn_entry != null and spawn_entry.get("projectile_template_override") is ProjectileTemplateRef:
		return spawn_entry.get("projectile_template_override")
	var spawn_overrides := resolve_spawn_overrides(spawn_entry)
	if spawn_overrides.get("projectile_template", null) is ProjectileTemplateRef:
		return spawn_overrides.get("projectile_template")
	if archetype != null and archetype.get("projectile_template") is ProjectileTemplateRef:
		return archetype.get("projectile_template")
	if entity_template != null and entity_template.get("projectile_template") is ProjectileTemplateRef:
		return entity_template.get("projectile_template")
	return null


static func resolve_projectile_flight_profile(spawn_entry: Resource, entity_template = null, projectile_template = null, archetype = null) -> Resource:
	if spawn_entry != null and spawn_entry.get("projectile_flight_profile_override") != null:
		return spawn_entry.get("projectile_flight_profile_override")
	var spawn_overrides := resolve_spawn_overrides(spawn_entry)
	if spawn_overrides.get("flight_profile", null) != null:
		return spawn_overrides.get("flight_profile")
	if archetype != null and archetype.get("projectile_flight_profile") != null:
		return archetype.get("projectile_flight_profile")
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


static func resolve_hit_height_band(spawn_entry: Resource, entity_template = null, archetype = null) -> Resource:
	var spawn_height_band: Resource = resolve_spawn_hit_height_band_override(spawn_entry)
	if spawn_height_band != null:
		return spawn_height_band
	if archetype != null and archetype.get("hit_height_band") != null:
		return archetype.get("hit_height_band")
	if entity_template != null:
		return entity_template.get("hit_height_band")
	return null
