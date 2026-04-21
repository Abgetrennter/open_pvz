extends RefCounted
class_name MechanicCompiler

const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")
const CombatMechanicRef = preload("res://scripts/core/defs/combat_mechanic.gd")
const EntityTemplateRef = preload("res://scripts/core/defs/entity_template.gd")
const NormalizedMechanicSetRef = preload("res://scripts/core/runtime/normalized_mechanic_set.gd")
const RuntimeSpecRef = preload("res://scripts/core/runtime/runtime_spec.gd")
const TriggerBindingRef = preload("res://scripts/core/defs/trigger_binding.gd")

const COMPILER_VERSION := &"mechanic_first_v0"


static func register_builtin_mechanic_types() -> void:
	if typeof(MechanicTypeRegistry) == TYPE_NIL:
		return
	var type_specs := {
		&"core.periodic": &"Trigger",
		&"core.when_damaged": &"Trigger",
		&"core.on_death": &"Trigger",
		&"core.on_spawned": &"Lifecycle",
		&"core.on_place": &"Lifecycle",
		&"core.produce_sun": &"Payload",
		&"core.damage": &"Payload",
		&"core.spawn_projectile": &"Payload",
		&"core.explode": &"Payload",
		&"core.apply_status": &"Payload",
		&"core.spawn_entity": &"Payload",
		&"core.bite": &"Controller",
		&"core.sweep": &"Controller",
		&"core.arming": &"State",
	}
	for type_id in type_specs.keys():
		MechanicTypeRegistry.register_type(StringName(type_id), StringName(type_specs[type_id]), {
			"compiler_version": COMPILER_VERSION,
		})
		if typeof(MechanicCompilerRegistry) != TYPE_NIL:
			MechanicCompilerRegistry.register_compiler(StringName(type_id), {
				"compiler_version": COMPILER_VERSION,
			})


# TODO(mechanic-first): Restore explicit return annotations after the compiler
# runtime is no longer blocked by GDScript parse-order limitations.
func compile_spawn_entry(spawn_entry: Resource, archetype):
	if archetype == null or not (archetype is CombatArchetypeRef):
		return null
	var spawn_overrides: Dictionary = {}
	if spawn_entry != null and spawn_entry.get("spawn_overrides") is Dictionary:
		spawn_overrides = spawn_entry.get("spawn_overrides").duplicate(true)

	var normalized = normalize_archetype(archetype, spawn_overrides)
	var backend_template: Resource = _resolve_backend_entity_template(archetype)

	var runtime_spec = RuntimeSpecRef.new()
	runtime_spec.compiler_version = COMPILER_VERSION
	runtime_spec.source_archetype_id = archetype.archetype_id
	runtime_spec.entity_kind = archetype.entity_kind
	if runtime_spec.entity_kind == StringName() and backend_template is EntityTemplateRef:
		runtime_spec.entity_kind = backend_template.entity_kind
	runtime_spec.display_name = archetype.display_name
	runtime_spec.tags = archetype.tags
	runtime_spec.backend_entity_template = backend_template
	runtime_spec.params = normalized.merged_params.duplicate(true)
	runtime_spec.hit_height_band = _resolve_hit_height_band(archetype, backend_template)
	runtime_spec.projectile_template = _resolve_projectile_template(archetype, backend_template)
	runtime_spec.projectile_flight_profile = _resolve_projectile_flight_profile(
		archetype,
		backend_template,
		runtime_spec.projectile_template
	)
	runtime_spec.compiled_trigger_bindings = _compile_trigger_payload_bindings(normalized, archetype)
	runtime_spec.controller_specs = _compile_controller_specs(normalized, archetype)
	runtime_spec.state_specs = _compile_state_specs(normalized, archetype)
	runtime_spec.runtime_state_values = {
		&"archetype_id": archetype.archetype_id,
		&"mechanic_compiler_version": COMPILER_VERSION,
		&"mechanic_count": normalized.mechanics.size(),
	}
	runtime_spec.notes = normalized.warnings

	for mechanic in normalized.mechanics:
		if mechanic is CombatMechanicRef and mechanic.mechanic_id != StringName():
			runtime_spec.mechanic_ids.append(String(mechanic.mechanic_id))

	if runtime_spec.backend_entity_template == null:
		runtime_spec.notes.append("Archetype %s has no backend_entity_template yet; runtime falls back to skeleton-only metadata." % String(archetype.archetype_id))

	return runtime_spec


# TODO(mechanic-first): Restore explicit return annotations after the compiler
# runtime is no longer blocked by GDScript parse-order limitations.
static func normalize_archetype(archetype, spawn_overrides: Dictionary = {}):
	var normalized = NormalizedMechanicSetRef.new()
	normalized.archetype_id = archetype.archetype_id
	normalized.entity_kind = archetype.entity_kind
	normalized.compiler_hints = archetype.compiler_hints.duplicate(true)

	var backend_template: Resource = _resolve_backend_entity_template(archetype)
	if backend_template is EntityTemplateRef and backend_template.default_params is Dictionary:
		normalized.merged_params = backend_template.default_params.duplicate(true)
	if archetype.default_params is Dictionary:
		for key: Variant in archetype.default_params.keys():
			normalized.merged_params[key] = archetype.default_params[key]
	for key: Variant in spawn_overrides.keys():
		normalized.merged_params[key] = spawn_overrides[key]

	for mechanic in _sorted_enabled_mechanics(archetype):
		normalized.mechanics.append(mechanic)

	return normalized


static func _compile_trigger_payload_bindings(normalized, archetype) -> Array:
	var trigger_mechanics: Array = []
	var payload_mechanics: Array = []
	for mechanic in normalized.mechanics:
		if not (mechanic is CombatMechanicRef):
			continue
		match StringName(mechanic.family):
			CombatMechanicRef.FAMILY_TRIGGER:
				trigger_mechanics.append(mechanic)
			CombatMechanicRef.FAMILY_LIFECYCLE:
				trigger_mechanics.append(mechanic)
			CombatMechanicRef.FAMILY_PAYLOAD:
				payload_mechanics.append(mechanic)

	if trigger_mechanics.is_empty() or payload_mechanics.is_empty():
		return []

	var compiled: Array = []
	if payload_mechanics.size() > 1:
		normalized.warnings.append("Archetype %s currently compiles only the first payload mechanic per trigger." % String(archetype.archetype_id))
	var payload_mechanic = payload_mechanics[0]

	for trigger_mechanic in trigger_mechanics:
		var trigger_binding = _build_binding_from_mechanics(archetype, trigger_mechanic, payload_mechanic)
		if trigger_binding != null:
			compiled.append(trigger_binding)
	return compiled


static func _build_binding_from_mechanics(archetype, trigger_mechanic, payload_mechanic):
	var trigger_mapping := _map_trigger_type(trigger_mechanic.type_id)
	if trigger_mapping.is_empty():
		return null
	var payload_mapping := _map_payload_type(payload_mechanic.type_id)
	if payload_mapping.is_empty():
		return null

	var binding = TriggerBindingRef.new()
	binding.binding_id = StringName("%s__%s__%s" % [
		String(archetype.archetype_id),
		String(trigger_mechanic.mechanic_id),
		String(payload_mechanic.mechanic_id),
	])
	binding.behavior_key = StringName(trigger_mapping.get("behavior_key", &"attack"))
	binding.trigger_id = StringName(trigger_mapping.get("trigger_id", StringName()))
	binding.event_name = StringName(trigger_mapping.get("event_name", StringName()))
	binding.condition_values = Dictionary(trigger_mechanic.params).duplicate(true)
	binding.effect_id = StringName(payload_mapping.get("effect_id", StringName()))
	binding.effect_params = Dictionary(payload_mechanic.params).duplicate(true)
	return binding


static func _map_trigger_type(type_id: StringName) -> Dictionary:
	match type_id:
		&"core.periodic":
			return {
				"behavior_key": &"attack",
				"trigger_id": &"periodically",
				"event_name": &"game.tick",
			}
		&"core.when_damaged":
			return {
				"behavior_key": &"when_damaged",
				"trigger_id": &"when_damaged",
				"event_name": &"entity.damaged",
			}
		&"core.on_death":
			return {
				"behavior_key": &"on_death",
				"trigger_id": &"on_death",
				"event_name": &"entity.died",
			}
		&"core.on_spawned":
			return {
				"behavior_key": &"on_spawned",
				"trigger_id": &"on_spawned",
				"event_name": &"entity.spawned",
			}
		&"core.on_place":
			return {
				"behavior_key": &"on_place",
				"trigger_id": &"on_place",
				"event_name": &"placement.accepted",
			}
		_:
			return {}


static func _map_payload_type(type_id: StringName) -> Dictionary:
	match type_id:
		&"core.produce_sun":
			return {"effect_id": &"produce_sun"}
		&"core.damage":
			return {"effect_id": &"damage"}
		&"core.spawn_projectile":
			return {"effect_id": &"spawn_projectile"}
		&"core.explode":
			return {"effect_id": &"explode"}
		&"core.apply_status":
			return {"effect_id": &"apply_status"}
		&"core.spawn_entity":
			return {"effect_id": &"spawn_entity"}
		_:
			return {}


static func _compile_controller_specs(normalized, archetype) -> Array:
	var compiled: Array = []
	for mechanic in normalized.mechanics:
		if not (mechanic is CombatMechanicRef):
			continue
		if StringName(mechanic.family) != CombatMechanicRef.FAMILY_CONTROLLER:
			continue
		var controller_spec := _build_controller_spec(archetype, mechanic)
		if not controller_spec.is_empty():
			compiled.append(controller_spec)
	return compiled


static func _build_controller_spec(archetype, mechanic) -> Dictionary:
	match mechanic.type_id:
		&"core.bite":
			return {
				"controller_id": &"core.bite",
				"mechanic_id": mechanic.mechanic_id,
				"source_archetype_id": archetype.archetype_id,
				"params": Dictionary(mechanic.params).duplicate(true),
			}
		&"core.sweep":
			return {
				"controller_id": &"core.sweep",
				"mechanic_id": mechanic.mechanic_id,
				"source_archetype_id": archetype.archetype_id,
				"params": Dictionary(mechanic.params).duplicate(true),
			}
		_:
			return {}


static func _compile_state_specs(normalized, archetype) -> Array:
	var compiled: Array = []
	for mechanic in normalized.mechanics:
		if not (mechanic is CombatMechanicRef):
			continue
		if StringName(mechanic.family) != CombatMechanicRef.FAMILY_STATE:
			continue
		var state_spec := _build_state_spec(archetype, mechanic)
		if not state_spec.is_empty():
			compiled.append(state_spec)
	return compiled


static func _build_state_spec(archetype, mechanic) -> Dictionary:
	match mechanic.type_id:
		&"core.arming":
			return {
				"mechanic_id": mechanic.mechanic_id,
				"source_archetype_id": archetype.archetype_id,
				"initial_state": &"arming",
				"transitions": [{
					"transition_id": StringName("%s__arming_to_active" % String(mechanic.mechanic_id)),
					"from_state": &"arming",
					"to_state": &"active",
					"after": float(mechanic.params.get("arming_time", 0.5)),
				}],
			}
		_:
			return {}


static func _sorted_enabled_mechanics(archetype) -> Array:
	var resolved: Array = []
	for mechanic in archetype.mechanics:
		if not (mechanic is CombatMechanicRef):
			continue
		if not bool(mechanic.enabled):
			continue
		resolved.append(mechanic)
	resolved.sort_custom(func(a, b):
		return int(a.priority) < int(b.priority)
	)
	return resolved


static func _resolve_backend_entity_template(archetype) -> Resource:
	if archetype.backend_entity_template is EntityTemplateRef:
		return archetype.backend_entity_template
	if archetype.backend_entity_template_id != StringName() and SceneRegistry.has_entity_template(archetype.backend_entity_template_id):
		var resolved: Resource = SceneRegistry.get_entity_template(archetype.backend_entity_template_id)
		if resolved is EntityTemplateRef:
			return resolved
	return null


static func _resolve_hit_height_band(archetype, backend_template: Resource) -> Resource:
	if archetype.hit_height_band != null:
		return archetype.hit_height_band
	if backend_template is EntityTemplateRef:
		return backend_template.hit_height_band
	return null


static func _resolve_projectile_template(archetype, backend_template: Resource):
	if archetype.projectile_template != null:
		return archetype.projectile_template
	if backend_template is EntityTemplateRef:
		return backend_template.projectile_template
	return null


static func _resolve_projectile_flight_profile(archetype, backend_template: Resource, projectile_template) -> Resource:
	if archetype.projectile_flight_profile != null:
		return archetype.projectile_flight_profile
	if projectile_template != null and projectile_template.get("flight_profile") != null:
		return projectile_template.get("flight_profile")
	if backend_template is EntityTemplateRef:
		return backend_template.projectile_flight_profile
	return null
