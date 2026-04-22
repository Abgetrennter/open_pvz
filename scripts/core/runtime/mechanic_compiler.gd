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
		&"core.on_armed": &"Lifecycle",
		&"core.on_state_enter": &"Lifecycle",
		&"core.on_expire": &"Lifecycle",
		&"core.on_removed": &"Lifecycle",
		&"core.produce_sun": &"Payload",
		&"core.damage": &"Payload",
		&"core.spawn_projectile": &"Payload",
		&"core.explode": &"Payload",
		&"core.apply_status": &"Payload",
		&"core.spawn_entity": &"Payload",
		&"core.bite": &"Controller",
		&"core.sweep": &"Controller",
		&"core.arming": &"State",
		&"core.growth": &"State",
		&"core.rage": &"State",
	}
	for type_id in type_specs.keys():
		MechanicTypeRegistry.register_type(StringName(type_id), StringName(type_specs[type_id]), {
			"compiler_version": COMPILER_VERSION,
		})
		if typeof(MechanicCompilerRegistry) != TYPE_NIL:
			MechanicCompilerRegistry.register_compiler(StringName(type_id), {
				"compiler_version": COMPILER_VERSION,
			})
	if typeof(MechanicCompilerRegistry) != TYPE_NIL:
		MechanicCompilerRegistry.register_compiler_callable(
			&"core.bite",
			_compile_controller_bite,
			{"compiler_version": COMPILER_VERSION, "family": &"Controller"}
		)
		MechanicCompilerRegistry.register_compiler_callable(
			&"core.sweep",
			_compile_controller_sweep,
			{"compiler_version": COMPILER_VERSION, "family": &"Controller"}
		)
		MechanicCompilerRegistry.register_compiler_callable(
			&"core.arming",
			_compile_state_arming,
			{"compiler_version": COMPILER_VERSION, "family": &"State"}
		)
		MechanicCompilerRegistry.register_compiler_callable(
			&"core.growth",
			_compile_state_growth,
			{"compiler_version": COMPILER_VERSION, "family": &"State"}
		)
		MechanicCompilerRegistry.register_compiler_callable(
			&"core.rage",
			_compile_state_rage,
			{"compiler_version": COMPILER_VERSION, "family": &"State"}
		)


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
	runtime_spec.root_scene = archetype.root_scene
	if archetype.max_health > 0:
		runtime_spec.max_health = archetype.max_health
	if archetype.hitbox_size != Vector2.ZERO:
		runtime_spec.hitbox_size = archetype.hitbox_size
	runtime_spec.mechanic_runtime_states = _build_mechanic_runtime_states(normalized)
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
		normalized.warnings.append("Archetype %s compiles multiple payload mechanics per trigger (%d payloads)." % [String(archetype.archetype_id), payload_mechanics.size()])

	for trigger_mechanic in trigger_mechanics:
		for payload_mechanic in payload_mechanics:
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
		&"core.on_armed":
			return {
				"behavior_key": &"on_armed",
				"trigger_id": &"on_armed",
				"event_name": &"entity.state_entered",
			}
		&"core.on_state_enter":
			return {
				"behavior_key": &"on_state_enter",
				"trigger_id": &"on_state_enter",
				"event_name": &"entity.state_entered",
			}
		&"core.on_expire":
			return {
				"behavior_key": &"on_expire",
				"trigger_id": &"on_expire",
				"event_name": &"entity.expired",
			}
		&"core.on_removed":
			return {
				"behavior_key": &"on_removed",
				"trigger_id": &"on_removed",
				"event_name": &"entity.removed",
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
	return _compile_family_specs(normalized, archetype, CombatMechanicRef.FAMILY_CONTROLLER)


static func _compile_state_specs(normalized, archetype) -> Array:
	return _compile_family_specs(normalized, archetype, CombatMechanicRef.FAMILY_STATE)


static func _compile_family_specs(normalized, archetype, family_id: StringName) -> Array:
	var compiled: Array = []
	for mechanic in normalized.mechanics:
		if not (mechanic is CombatMechanicRef):
			continue
		if StringName(mechanic.family) != family_id:
			continue
		var spec: Dictionary = {}
		if typeof(MechanicCompilerRegistry) != TYPE_NIL and MechanicCompilerRegistry.has_compiler_callable(mechanic.type_id):
			spec = MechanicCompilerRegistry.compile_type(mechanic.type_id, mechanic, archetype, normalized.merged_params)
		else:
			spec = _fallback_compile_family_spec(family_id, archetype, mechanic)
		if not spec.is_empty():
			compiled.append(spec)
	return compiled


static func _fallback_compile_family_spec(family_id: StringName, archetype, mechanic) -> Dictionary:
	match family_id:
		CombatMechanicRef.FAMILY_CONTROLLER:
			return _build_controller_spec_inline(archetype, mechanic)
		CombatMechanicRef.FAMILY_STATE:
			return _build_state_spec_inline(archetype, mechanic)
		_:
			return {}


static func _build_controller_spec_inline(archetype, mechanic) -> Dictionary:
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


static func _build_state_spec_inline(archetype, mechanic) -> Dictionary:
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
		&"core.growth":
			var growth_time: float = float(mechanic.params.get("growth_time", 30.0))
			return {
				"mechanic_id": mechanic.mechanic_id,
				"source_archetype_id": archetype.archetype_id,
				"initial_state": &"small",
				"transitions": [
					{
						"transition_id": StringName("%s__small_to_medium" % String(mechanic.mechanic_id)),
						"from_state": &"small",
						"to_state": &"medium",
						"after": growth_time * 0.5,
					},
					{
						"transition_id": StringName("%s__medium_to_mature" % String(mechanic.mechanic_id)),
						"from_state": &"medium",
						"to_state": &"mature",
						"after": growth_time,
					},
				],
			}
		&"core.rage":
			return {
				"mechanic_id": mechanic.mechanic_id,
				"source_archetype_id": archetype.archetype_id,
				"initial_state": &"calm",
				"transitions": [{
					"transition_id": StringName("%s__calm_to_rage" % String(mechanic.mechanic_id)),
					"from_state": &"calm",
					"to_state": &"rage",
					"trigger": "event",
					"event_name": &"entity.damaged",
					"trigger_threshold": float(mechanic.params.get("trigger_threshold", 0.5)),
				}],
			}
		_:
			return {}


static var _compile_controller_bite: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	return {
		"controller_id": &"core.bite",
		"mechanic_id": mechanic.mechanic_id,
		"source_archetype_id": archetype.archetype_id,
		"params": Dictionary(mechanic.params).duplicate(true),
	}

static var _compile_controller_sweep: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	return {
		"controller_id": &"core.sweep",
		"mechanic_id": mechanic.mechanic_id,
		"source_archetype_id": archetype.archetype_id,
		"params": Dictionary(mechanic.params).duplicate(true),
	}

static var _compile_state_arming: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
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

static var _compile_state_growth: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	var stages: Array = []
	var raw_stages: Variant = mechanic.params.get("stages", [])
	if raw_stages is Array:
		for i in range(raw_stages.size()):
			var stage: Variant = raw_stages[i]
			if not (stage is Dictionary):
				continue
			stages.append(stage.duplicate(true))
	if stages.is_empty():
		var growth_time: float = float(mechanic.params.get("growth_time", 30.0))
		stages = [
			{"state": &"small", "after": 0.0},
			{"state": &"medium", "after": growth_time * 0.5},
			{"state": &"mature", "after": growth_time},
		]
	var initial_state: StringName = StringName(stages[0].get("state", &"small")) if not stages.is_empty() else &"small"
	var transitions: Array = []
	for i in range(stages.size() - 1):
		var from: StringName = StringName(stages[i].get("state", StringName()))
		var to: StringName = StringName(stages[i + 1].get("state", StringName()))
		var after: float = float(stages[i + 1].get("after", 0.0))
		transitions.append({
			"transition_id": StringName("%s__growth_%d_to_%d" % [String(mechanic.mechanic_id), i, i + 1]),
			"from_state": from,
			"to_state": to,
			"after": after,
		})
	return {
		"mechanic_id": mechanic.mechanic_id,
		"source_archetype_id": archetype.archetype_id,
		"initial_state": initial_state,
		"transitions": transitions,
	}

static var _compile_state_rage: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	var trigger_threshold: float = float(mechanic.params.get("trigger_threshold", 0.5))
	return {
		"mechanic_id": mechanic.mechanic_id,
		"source_archetype_id": archetype.archetype_id,
		"initial_state": &"calm",
		"transitions": [{
			"transition_id": StringName("%s__calm_to_rage" % String(mechanic.mechanic_id)),
			"from_state": &"calm",
			"to_state": &"rage",
			"trigger": "event",
			"event_name": &"entity.damaged",
			"trigger_threshold": trigger_threshold,
		}],
	}


static func _build_mechanic_runtime_states(normalized) -> Dictionary:
	var states: Dictionary = {}
	for mechanic in normalized.mechanics:
		if not (mechanic is CombatMechanicRef):
			continue
		if mechanic.mechanic_id == StringName():
			continue
		var needs_state := false
		var initial_state: Dictionary = {}
		match StringName(mechanic.family):
			CombatMechanicRef.FAMILY_EMISSION:
				if String(mechanic.type_id) == "core.shuffle_cycle":
					needs_state = true
					var pool: Array = []
					var raw_pool: Variant = mechanic.params.get("pool", [])
					if raw_pool is Array:
						pool = raw_pool.duplicate()
					initial_state = {
						"type": &"shuffle_bag",
						"pool": pool,
						"index": 0,
						"cycle": 0,
					}
		if needs_state:
			states[String(mechanic.mechanic_id)] = initial_state
	return states


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
