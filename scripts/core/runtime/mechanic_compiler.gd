extends RefCounted
class_name MechanicCompiler

const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")
const CombatMechanicRef = preload("res://scripts/core/defs/combat_mechanic.gd")
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
		&"core.proximity": &"Trigger",
		&"core.on_spawned": &"Lifecycle",
		&"core.on_place": &"Lifecycle",
		&"core.produce_sun": &"Payload",
		&"core.damage": &"Payload",
		&"core.spawn_projectile": &"Payload",
		&"core.explode": &"Payload",
		&"core.apply_status": &"Payload",
		&"core.spawn_entity": &"Payload",
		&"core.invoke_effect": &"Payload",
		&"core.wake": &"Payload",
		&"core.team_switch": &"Payload",
		&"core.bite": &"Controller",
		&"core.sweep": &"Controller",
		&"core.ground_damage": &"Controller",
		&"core.projectile_transform": &"Controller",
		&"core.arming": &"State",
		&"core.growth": &"State",
		&"core.rage": &"State",
		&"core.sleeping": &"State",
		&"core.lane_forward": &"Targeting",
		&"core.lane_backward": &"Targeting",
		&"core.always_target": &"Targeting",
		&"core.radius_around": &"Targeting",
		&"core.global_track": &"Targeting",
		&"core.linear": &"Trajectory",
		&"core.parabola": &"Trajectory",
		&"core.track": &"Trajectory",
		&"core.swept_segment": &"HitPolicy",
		&"core.terminal_hitbox": &"HitPolicy",
		&"core.terminal_radius": &"HitPolicy",
		&"core.overlap": &"HitPolicy",
		&"core.pierce": &"HitPolicy",
		&"core.single": &"Emission",
		&"core.burst": &"Emission",
		&"core.shuffle_cycle": &"Emission",
		&"core.spread": &"Emission",
		&"core.multi_lane": &"Emission",
		&"core.dual_direction": &"Emission",
		&"core.multi_angle": &"Emission",
		&"core.ground_slot": &"Placement",
		&"core.water_slot": &"Placement",
		&"core.roof_slot": &"Placement",
		&"core.air_slot": &"Placement",
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
		MechanicCompilerRegistry.register_compiler_callable(
			&"core.sleeping",
			_compile_state_sleeping,
			{"compiler_version": COMPILER_VERSION, "family": &"State"}
		)
		_register_targeting_callables()
		_register_trajectory_callables()
		_register_hit_policy_callables()
		_register_emission_callables()
		_register_placement_callables()


# TODO(mechanic-first): Restore explicit return annotations after the compiler
# runtime is no longer blocked by GDScript parse-order limitations.
func compile_spawn_entry(spawn_entry: Resource, archetype):
	if archetype == null or not (archetype is CombatArchetypeRef):
		return null
	var spawn_overrides: Dictionary = {}
	if spawn_entry != null and spawn_entry.get("spawn_overrides") is Dictionary:
		spawn_overrides = spawn_entry.get("spawn_overrides").duplicate(true)

	var normalized = normalize_archetype(archetype, spawn_overrides)

	var runtime_spec = RuntimeSpecRef.new()
	runtime_spec.compiler_version = COMPILER_VERSION
	runtime_spec.source_archetype_id = archetype.archetype_id
	runtime_spec.legacy_template_id = archetype.legacy_template_id
	runtime_spec.entity_kind = archetype.entity_kind
	runtime_spec.display_name = archetype.display_name
	runtime_spec.tags = archetype.tags
	runtime_spec.required_components = PackedStringArray(archetype.required_components)
	runtime_spec.optional_components = PackedStringArray(archetype.optional_components)
	runtime_spec.params = normalized.merged_params.duplicate(true)
	runtime_spec.hit_height_band = _resolve_hit_height_band(archetype)
	runtime_spec.projectile_template = _resolve_projectile_template(archetype)
	runtime_spec.projectile_flight_profile = _resolve_projectile_flight_profile(
		archetype,
		runtime_spec.projectile_template
	)
	runtime_spec.compiled_trigger_bindings = _compile_trigger_payload_bindings(normalized, archetype)
	runtime_spec.controller_specs = _compile_controller_specs(normalized, archetype)
	runtime_spec.state_specs = _compile_state_specs(normalized, archetype)
	runtime_spec.placement_spec = _compile_placement_spec(normalized, archetype)
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

	return runtime_spec


# TODO(mechanic-first): Restore explicit return annotations after the compiler
# runtime is no longer blocked by GDScript parse-order limitations.
static func normalize_archetype(archetype, spawn_overrides: Dictionary = {}):
	var normalized = NormalizedMechanicSetRef.new()
	normalized.archetype_id = archetype.archetype_id
	normalized.entity_kind = archetype.entity_kind
	normalized.compiler_hints = archetype.compiler_hints.duplicate(true)

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
	var targeting_params: Dictionary = {}
	var trajectory_params: Dictionary = {}
	var hit_policy_params: Dictionary = {}
	var emission_params: Dictionary = {}
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
			CombatMechanicRef.FAMILY_TARGETING:
				_compile_modifier_params(mechanic, archetype, normalized.merged_params, targeting_params)
			CombatMechanicRef.FAMILY_TRAJECTORY:
				_compile_modifier_params(mechanic, archetype, normalized.merged_params, trajectory_params)
			CombatMechanicRef.FAMILY_HIT_POLICY:
				_compile_modifier_params(mechanic, archetype, normalized.merged_params, hit_policy_params)
			CombatMechanicRef.FAMILY_EMISSION:
				_compile_modifier_params(mechanic, archetype, normalized.merged_params, emission_params)

	if trigger_mechanics.is_empty() or payload_mechanics.is_empty():
		return []

	var compiled: Array = []
	var has_pairing_groups := false
	for trigger_mechanic in trigger_mechanics:
		if _binding_group_for_mechanic(trigger_mechanic) != StringName():
			has_pairing_groups = true
			break
	if not has_pairing_groups:
		for payload_mechanic in payload_mechanics:
			if _binding_group_for_mechanic(payload_mechanic) != StringName():
				has_pairing_groups = true
				break
	if payload_mechanics.size() > 1 and not has_pairing_groups:
		normalized.warnings.append("Archetype %s compiles multiple payload mechanics per trigger (%d payloads)." % [String(archetype.archetype_id), payload_mechanics.size()])
	if has_pairing_groups:
		var keyed_triggers := _group_mechanics_by_binding_group(trigger_mechanics)
		var keyed_payloads := _group_mechanics_by_binding_group(payload_mechanics)
		var group_keys: Dictionary = {}
		for group_key in keyed_triggers.keys():
			group_keys[group_key] = true
		for group_key in keyed_payloads.keys():
			group_keys[group_key] = true
		for group_key in group_keys.keys():
			var grouped_triggers: Array = Array(keyed_triggers.get(group_key, []))
			var grouped_payloads: Array = Array(keyed_payloads.get(group_key, []))
			if grouped_triggers.is_empty() or grouped_payloads.is_empty():
				if StringName(group_key) != StringName():
					normalized.warnings.append("Archetype %s has unmatched trigger/payload binding_group %s." % [String(archetype.archetype_id), String(group_key)])
				continue
			if grouped_payloads.size() > 1 and StringName(group_key) == StringName():
				normalized.warnings.append("Archetype %s compiles multiple ungrouped payload mechanics per trigger (%d payloads)." % [String(archetype.archetype_id), grouped_payloads.size()])
			_compile_binding_pairs(
				archetype,
				grouped_triggers,
				grouped_payloads,
				targeting_params,
				trajectory_params,
				hit_policy_params,
				emission_params,
				normalized.merged_params,
				compiled
			)
		return compiled
	_compile_binding_pairs(
		archetype,
		trigger_mechanics,
		payload_mechanics,
		targeting_params,
		trajectory_params,
		hit_policy_params,
		emission_params,
		normalized.merged_params,
		compiled
	)
	return compiled


static func _compile_binding_pairs(
	archetype,
	trigger_mechanics: Array,
	payload_mechanics: Array,
	targeting_params: Dictionary,
	trajectory_params: Dictionary,
	hit_policy_params: Dictionary,
	emission_params: Dictionary,
	merged_params: Dictionary,
	compiled: Array
) -> void:
	for trigger_mechanic in trigger_mechanics:
		for payload_mechanic in payload_mechanics:
			var trigger_binding = _build_binding_from_mechanics(archetype, trigger_mechanic, payload_mechanic)
			if trigger_binding == null:
				continue
			_inject_targeting(trigger_binding, targeting_params, merged_params)
			_inject_trajectory(trigger_binding, trajectory_params)
			_inject_hit_policy(trigger_binding, hit_policy_params)
			_inject_emission(trigger_binding, emission_params)
			compiled.append(trigger_binding)


static func _group_mechanics_by_binding_group(mechanics: Array) -> Dictionary:
	var grouped := {}
	for mechanic in mechanics:
		var binding_group := _binding_group_for_mechanic(mechanic)
		if not grouped.has(binding_group):
			grouped[binding_group] = []
		grouped[binding_group].append(mechanic)
	return grouped


static func _binding_group_for_mechanic(mechanic) -> StringName:
	if mechanic == null or not (mechanic is CombatMechanicRef):
		return StringName()
	if not (mechanic.params is Dictionary):
		return StringName()
	return StringName(mechanic.params.get("binding_group", StringName()))


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
	var trigger_id := StringName(trigger_mapping.get("trigger_id", StringName()))
	binding.trigger_id = trigger_id
	binding.event_name = StringName(trigger_mapping.get("event_name", StringName()))
	var trigger_params := Dictionary(trigger_mechanic.params).duplicate(true)
	_strip_compile_only_params(trigger_params)
	binding.condition_values = _merge_trigger_condition_values(trigger_id, trigger_params, archetype.default_params)
	var payload_params := Dictionary(payload_mechanic.params).duplicate(true)
	_strip_compile_only_params(payload_params)
	var effect_id := StringName(payload_mapping.get("effect_id", StringName()))
	var effect_id_param := StringName(payload_mapping.get("effect_id_param", StringName()))
	if effect_id == StringName() and effect_id_param != StringName():
		effect_id = StringName(payload_params.get(String(effect_id_param), StringName()))
		payload_params.erase(String(effect_id_param))
	if effect_id == StringName():
		return null
	binding.effect_id = effect_id
	if payload_params.has("on_hit_effect_id"):
		binding.on_hit_effect_id = StringName(payload_params["on_hit_effect_id"])
		payload_params.erase("on_hit_effect_id")
	if payload_params.has("on_hit_effect_params") and payload_params["on_hit_effect_params"] is Dictionary:
		binding.on_hit_effect_params = Dictionary(payload_params["on_hit_effect_params"]).duplicate(true)
		payload_params.erase("on_hit_effect_params")
	binding.effect_params = payload_params
	return binding


static func _strip_compile_only_params(params: Dictionary) -> void:
	for compile_only_key in [&"binding_group"]:
		params.erase(String(compile_only_key))
		params.erase(compile_only_key)


static func _merge_trigger_condition_values(trigger_id: StringName, base_conditions: Dictionary, merged_params: Dictionary) -> Dictionary:
	var merged: Dictionary = base_conditions.duplicate(true)
	if merged_params.is_empty():
		return merged
	var trigger_def = TriggerRegistry.get_def(trigger_id)
	if trigger_def == null:
		return merged
	var condition_param_names: Dictionary = {}
	for param_def in trigger_def.condition_params:
		if not (param_def is Dictionary):
			continue
		var param_name := String(param_def.get("name", "")).strip_edges()
		if param_name.is_empty():
			continue
		condition_param_names[param_name] = true
	for key: Variant in merged_params.keys():
		var key_str := String(key)
		if not condition_param_names.has(key_str):
			continue
		merged[key_str] = merged_params[key]
	return merged


const _TARGETING_CONDITION_KEYS: Dictionary = {
	&"detection_id": true,
	&"scan_range": true,
	&"required_state": true,
	&"start_delay": true,
	&"target_tags": true,
}


static func _collect_mod_params(mechanic_params: Dictionary, out_params: Dictionary) -> void:
	if not (mechanic_params is Dictionary):
		return
	for key: Variant in mechanic_params.keys():
		out_params[key] = mechanic_params[key]


static func _compile_modifier_params(mechanic, archetype, merged_params: Dictionary, out_params: Dictionary) -> void:
	if typeof(MechanicCompilerRegistry) != TYPE_NIL and MechanicCompilerRegistry.has_compiler_callable(mechanic.type_id):
		var compiled: Dictionary = MechanicCompilerRegistry.compile_type(mechanic.type_id, mechanic, archetype, merged_params)
		for key: Variant in compiled.keys():
			out_params[key] = compiled[key]
	else:
		_collect_mod_params(mechanic.params, out_params)


static func _inject_targeting(binding, targeting_params: Dictionary, merged_params: Dictionary) -> void:
	if targeting_params.is_empty():
		return
	var trigger_id := StringName(binding.trigger_id)
	var trigger_def = TriggerRegistry.get_def(trigger_id)
	var condition_param_names: Dictionary = {}
	if trigger_def != null:
		for param_def in trigger_def.condition_params:
			if not (param_def is Dictionary):
				continue
			var param_name := String(param_def.get("name", "")).strip_edges()
			if not param_name.is_empty():
				condition_param_names[param_name] = true
	for key: Variant in _TARGETING_CONDITION_KEYS.keys():
		if targeting_params.has(key):
			binding.condition_values[key] = targeting_params[key]
		elif merged_params.has(key) and condition_param_names.has(String(key)):
			binding.condition_values[key] = merged_params[key]


static func _inject_trajectory(binding, trajectory_params: Dictionary) -> void:
	if trajectory_params.is_empty():
		return
	for key: Variant in trajectory_params.keys():
		binding.effect_params[key] = trajectory_params[key]


static func _inject_hit_policy(binding, hit_policy_params: Dictionary) -> void:
	if hit_policy_params.is_empty():
		return
	for key: Variant in hit_policy_params.keys():
		binding.effect_params[key] = hit_policy_params[key]


static func _inject_emission(binding, emission_params: Dictionary) -> void:
	if emission_params.is_empty():
		return
	for key: Variant in emission_params.keys():
		binding.effect_params[key] = emission_params[key]


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
		&"core.proximity":
			return {
				"behavior_key": &"proximity",
				"trigger_id": &"proximity",
				"event_name": &"game.tick",
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
		&"core.invoke_effect":
			return {"effect_id_param": &"effect_id"}
		&"core.wake":
			return {"effect_id": &"wake"}
		&"core.team_switch":
			return {"effect_id": &"team_switch"}
		_:
			return {}


static func _compile_controller_specs(normalized, archetype) -> Array:
	return _compile_family_specs(normalized, archetype, CombatMechanicRef.FAMILY_CONTROLLER)


static func _compile_state_specs(normalized, archetype) -> Array:
	return _compile_family_specs(normalized, archetype, CombatMechanicRef.FAMILY_STATE)


static func _compile_placement_spec(normalized, archetype) -> Dictionary:
	var placement_mechanics: Array = []
	for mechanic in normalized.mechanics:
		if mechanic is CombatMechanicRef and StringName(mechanic.family) == CombatMechanicRef.FAMILY_PLACEMENT:
			placement_mechanics.append(mechanic)
	if placement_mechanics.is_empty():
		var slot_type := _resolve_archetype_slot_type(archetype)
		if slot_type != StringName():
			return {
				"source": &"archetype_field",
				"allowed_slot_types": PackedStringArray(archetype.allowed_slot_types),
				"required_placement_tags": PackedStringArray(archetype.required_placement_tags),
				"granted_placement_tags": PackedStringArray(archetype.granted_placement_tags),
				"placement_role": StringName(archetype.placement_role),
				"required_present_roles": PackedStringArray(archetype.required_present_roles),
				"required_empty_roles": PackedStringArray(archetype.required_empty_roles),
				"slot_type_hint": slot_type,
			}
		return {}
	var mechanic = placement_mechanics[0]
	if typeof(MechanicCompilerRegistry) != TYPE_NIL and MechanicCompilerRegistry.has_compiler_callable(mechanic.type_id):
		return MechanicCompilerRegistry.compile_type(mechanic.type_id, mechanic, archetype, normalized.merged_params)
	var slot_type_hint := StringName(mechanic.params.get("slot_type", StringName()))
	if slot_type_hint == StringName():
		slot_type_hint = _slot_type_from_type_id(mechanic.type_id)
	return {
		"source": &"placement_mechanic",
		"mechanic_id": StringName(mechanic.mechanic_id),
		"allowed_slot_types": PackedStringArray(archetype.allowed_slot_types),
		"required_placement_tags": PackedStringArray(archetype.required_placement_tags),
		"granted_placement_tags": PackedStringArray(archetype.granted_placement_tags),
		"placement_role": StringName(archetype.placement_role),
		"required_present_roles": PackedStringArray(archetype.required_present_roles),
		"required_empty_roles": PackedStringArray(archetype.required_empty_roles),
		"slot_type_hint": slot_type_hint,
	}


static func _resolve_archetype_slot_type(archetype) -> StringName:
	if not archetype.allowed_slot_types.is_empty():
		return StringName(archetype.allowed_slot_types[0])
	if archetype.required_placement_tags.has(&"supports_air"):
		return &"air"
	if archetype.required_placement_tags.has(&"supports_roof"):
		return &"roof"
	if archetype.required_placement_tags.has(&"supports_water"):
		return &"water"
	return &"ground"


static func _slot_type_from_type_id(type_id: StringName) -> StringName:
	match type_id:
		&"core.ground_slot":
			return &"ground"
		&"core.water_slot":
			return &"water"
		&"core.roof_slot":
			return &"roof"
		&"core.air_slot":
			return &"air"
		_:
			return &"ground"


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
		&"core.ground_damage":
			return {
				"controller_id": &"core.ground_damage",
				"mechanic_id": mechanic.mechanic_id,
				"source_archetype_id": archetype.archetype_id,
				"params": Dictionary(mechanic.params).duplicate(true),
			}
		&"core.projectile_transform":
			return {
				"controller_id": &"core.projectile_transform",
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
		&"core.sleeping":
			return {
				"mechanic_id": mechanic.mechanic_id,
				"source_archetype_id": archetype.archetype_id,
				"initial_state": &"sleeping",
				"transitions": [{
					"transition_id": StringName("%s__sleeping_to_awake" % String(mechanic.mechanic_id)),
					"from_state": &"sleeping",
					"to_state": &"awake",
					"trigger": "event",
					"event_name": &"entity.wake",
				}],
			}
		_:
			return {}


static var _compile_controller_bite: Callable = func(mechanic, archetype, merged_params: Dictionary) -> Dictionary:
	var base_params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	_merge_controller_overrides(base_params, merged_params, [&"attack_damage", &"attack_interval", &"attack_range", &"move_speed", &"scan_range", &"detection_id"])
	return {
		"controller_id": &"core.bite",
		"mechanic_id": mechanic.mechanic_id,
		"source_archetype_id": archetype.archetype_id,
		"params": base_params,
	}

static var _compile_controller_sweep: Callable = func(mechanic, archetype, merged_params: Dictionary) -> Dictionary:
	var base_params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	_merge_controller_overrides(base_params, merged_params, [&"move_speed", &"detection_radius"])
	return {
		"controller_id": &"core.sweep",
		"mechanic_id": mechanic.mechanic_id,
		"source_archetype_id": archetype.archetype_id,
		"params": base_params,
	}

static func _merge_controller_overrides(base_params: Dictionary, merged_params: Dictionary, keys: Array) -> void:
	for key in keys:
		if merged_params.has(key):
			base_params[key] = merged_params[key]

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

static var _compile_state_sleeping: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	return {
		"mechanic_id": mechanic.mechanic_id,
		"source_archetype_id": archetype.archetype_id,
		"initial_state": &"sleeping",
		"transitions": [{
			"transition_id": StringName("%s__sleeping_to_awake" % String(mechanic.mechanic_id)),
			"from_state": &"sleeping",
			"to_state": &"awake",
			"trigger": "event",
			"event_name": &"entity.wake",
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
						"seed_source": &"mechanic",
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


static func _resolve_hit_height_band(archetype) -> Resource:
	if archetype.hit_height_band != null:
		return archetype.hit_height_band
	return null


static func _resolve_projectile_template(archetype):
	if archetype.projectile_template != null:
		return archetype.projectile_template
	return null


static func _resolve_projectile_flight_profile(archetype, projectile_template) -> Resource:
	if archetype.projectile_flight_profile != null:
		return archetype.projectile_flight_profile
	if projectile_template != null and projectile_template.get("flight_profile") != null:
		return projectile_template.get("flight_profile")
	return null


# --- Targeting compiler callables ---

static func _register_targeting_callables() -> void:
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.lane_forward",
		_compile_targeting_lane_forward,
		{"compiler_version": COMPILER_VERSION, "family": &"Targeting"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.lane_backward",
		_compile_targeting_lane_backward,
		{"compiler_version": COMPILER_VERSION, "family": &"Targeting"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.always_target",
		_compile_targeting_always,
		{"compiler_version": COMPILER_VERSION, "family": &"Targeting"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.radius_around",
		_compile_targeting_radius_around,
		{"compiler_version": COMPILER_VERSION, "family": &"Targeting"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.global_track",
		_compile_targeting_global_track,
		{"compiler_version": COMPILER_VERSION, "family": &"Targeting"}
	)

static var _compile_targeting_lane_forward: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	if not params.has("detection_id"):
		params["detection_id"] = &"lane_forward"
	if not params.has("scan_range"):
		params["scan_range"] = 900.0
	return params

static var _compile_targeting_lane_backward: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	if not params.has("detection_id"):
		params["detection_id"] = &"lane_backward"
	if not params.has("scan_range"):
		params["scan_range"] = 900.0
	return params

static var _compile_targeting_always: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	if not params.has("detection_id"):
		params["detection_id"] = &"always"
	return params

static var _compile_targeting_radius_around: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	if not params.has("detection_id"):
		params["detection_id"] = &"radius_around"
	if not params.has("scan_range"):
		params["scan_range"] = 180.0
	return params

static var _compile_targeting_global_track: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	if not params.has("detection_id"):
		params["detection_id"] = &"global_track"
	if not params.has("scan_range"):
		params["scan_range"] = 4000.0
	return params


# --- Trajectory compiler callables ---

static func _register_trajectory_callables() -> void:
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.linear",
		_compile_trajectory_linear,
		{"compiler_version": COMPILER_VERSION, "family": &"Trajectory"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.parabola",
		_compile_trajectory_parabola,
		{"compiler_version": COMPILER_VERSION, "family": &"Trajectory"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.track",
		_compile_trajectory_track,
		{"compiler_version": COMPILER_VERSION, "family": &"Trajectory"}
	)

static var _compile_trajectory_linear: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["movement_mode"] = &"linear"
	return params

static var _compile_trajectory_parabola: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["movement_mode"] = &"parabola"
	if not params.has("arc_height"):
		params["arc_height"] = 72.0
	return params

static var _compile_trajectory_track: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["movement_mode"] = &"track"
	if not params.has("turn_rate"):
		params["turn_rate"] = 6.0
	return params


# --- HitPolicy compiler callables ---

static func _register_hit_policy_callables() -> void:
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.swept_segment",
		_compile_hit_policy_swept_segment,
		{"compiler_version": COMPILER_VERSION, "family": &"HitPolicy"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.terminal_hitbox",
		_compile_hit_policy_terminal_hitbox,
		{"compiler_version": COMPILER_VERSION, "family": &"HitPolicy"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.terminal_radius",
		_compile_hit_policy_terminal_radius,
		{"compiler_version": COMPILER_VERSION, "family": &"HitPolicy"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.overlap",
		_compile_hit_policy_overlap,
		{"compiler_version": COMPILER_VERSION, "family": &"HitPolicy"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.pierce",
		_compile_hit_policy_pierce,
		{"compiler_version": COMPILER_VERSION, "family": &"HitPolicy"}
	)

static var _compile_hit_policy_swept_segment: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["hit_strategy"] = &"swept_segment"
	return params

static var _compile_hit_policy_terminal_hitbox: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["hit_strategy"] = &"terminal_hitbox"
	if not params.has("terminal_hit_strategy"):
		params["terminal_hit_strategy"] = &"impact_hitbox"
	return params

static var _compile_hit_policy_terminal_radius: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["hit_strategy"] = &"terminal_radius"
	if not params.has("terminal_hit_strategy"):
		params["terminal_hit_strategy"] = &"impact_radius"
	if not params.has("impact_radius"):
		params["impact_radius"] = 36.0
	return params

static var _compile_hit_policy_overlap: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["hit_strategy"] = &"overlap"
	return params

static var _compile_hit_policy_pierce: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["hit_strategy"] = &"pierce"
	if not params.has("max_penetrations"):
		params["max_penetrations"] = 5
	if not params.has("pierce_range"):
		params["pierce_range"] = 320.0
	return params


# --- Emission compiler callables ---

static func _register_emission_callables() -> void:
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.single",
		_compile_emission_single,
		{"compiler_version": COMPILER_VERSION, "family": &"Emission"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.burst",
		_compile_emission_burst,
		{"compiler_version": COMPILER_VERSION, "family": &"Emission"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.shuffle_cycle",
		_compile_emission_shuffle_cycle,
		{"compiler_version": COMPILER_VERSION, "family": &"Emission"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.spread",
		_compile_emission_spread,
		{"compiler_version": COMPILER_VERSION, "family": &"Emission"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.multi_lane",
		_compile_emission_multi_lane,
		{"compiler_version": COMPILER_VERSION, "family": &"Emission"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.dual_direction",
		_compile_emission_dual_direction,
		{"compiler_version": COMPILER_VERSION, "family": &"Emission"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.multi_angle",
		_compile_emission_multi_angle,
		{"compiler_version": COMPILER_VERSION, "family": &"Emission"}
	)

static var _compile_emission_single: Callable = func(_mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	return {"burst_count": 1}

static var _compile_emission_burst: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	if not params.has("burst_count"):
		params["burst_count"] = 2
	if int(params.get("burst_count", 1)) < 1:
		params["burst_count"] = 1
	if not params.has("burst_interval"):
		params["burst_interval"] = 0.08
	return params

static var _compile_emission_shuffle_cycle: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	if not params.has("pool"):
		params["pool"] = []
	return params

static var _compile_emission_spread: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	if not params.has("spread_count"):
		params["spread_count"] = 3
	if int(params.get("spread_count", 1)) < 2:
		params["spread_count"] = 2
	if not params.has("spread_angle"):
		params["spread_angle"] = 15.0
	return params

static var _compile_emission_multi_lane: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["emission_mode"] = &"multi_lane"
	if not params.has("lane_count"):
		params["lane_count"] = 3
	if not params.has("lane_offset"):
		params["lane_offset"] = -1
	return params

static var _compile_emission_dual_direction: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["emission_mode"] = &"dual_direction"
	return params

static var _compile_emission_multi_angle: Callable = func(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["emission_mode"] = &"multi_angle"
	if not params.has("angle_count"):
		params["angle_count"] = 5
	if not params.has("angle_spread"):
		params["angle_spread"] = 72.0
	return params


# --- Placement compiler callables ---

static func _register_placement_callables() -> void:
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.ground_slot",
		_compile_placement_ground,
		{"compiler_version": COMPILER_VERSION, "family": &"Placement"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.water_slot",
		_compile_placement_water,
		{"compiler_version": COMPILER_VERSION, "family": &"Placement"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.roof_slot",
		_compile_placement_roof,
		{"compiler_version": COMPILER_VERSION, "family": &"Placement"}
	)
	MechanicCompilerRegistry.register_compiler_callable(
		&"core.air_slot",
		_compile_placement_air,
		{"compiler_version": COMPILER_VERSION, "family": &"Placement"}
	)

static var _compile_placement_ground: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	return _build_placement_spec_from_mechanic(mechanic, archetype, &"ground")

static var _compile_placement_water: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	return _build_placement_spec_from_mechanic(mechanic, archetype, &"water")

static var _compile_placement_roof: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	return _build_placement_spec_from_mechanic(mechanic, archetype, &"roof")

static var _compile_placement_air: Callable = func(mechanic, archetype, _merged_params: Dictionary) -> Dictionary:
	return _build_placement_spec_from_mechanic(mechanic, archetype, &"air")


static func _build_placement_spec_from_mechanic(mechanic, archetype, slot_type: StringName) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	var slot_type_hint := StringName(params.get("slot_type", slot_type))
	var allowed_slot_types: Variant = params.get("allowed_slot_types", archetype.allowed_slot_types)
	if allowed_slot_types is PackedStringArray:
		allowed_slot_types = PackedStringArray(allowed_slot_types)
	elif allowed_slot_types is Array:
		allowed_slot_types = PackedStringArray(allowed_slot_types)
	else:
		allowed_slot_types = PackedStringArray(archetype.allowed_slot_types)
	var required_tags: Variant = params.get("required_placement_tags", archetype.required_placement_tags)
	if required_tags is PackedStringArray:
		required_tags = PackedStringArray(required_tags)
	elif required_tags is Array:
		required_tags = PackedStringArray(required_tags)
	else:
		required_tags = PackedStringArray(archetype.required_placement_tags)
	var granted_tags: Variant = params.get("granted_placement_tags", archetype.granted_placement_tags)
	if granted_tags is PackedStringArray:
		granted_tags = PackedStringArray(granted_tags)
	elif granted_tags is Array:
		granted_tags = PackedStringArray(granted_tags)
	else:
		granted_tags = PackedStringArray(archetype.granted_placement_tags)
	var required_present_roles: Variant = params.get("required_present_roles", archetype.required_present_roles)
	if required_present_roles is PackedStringArray:
		required_present_roles = PackedStringArray(required_present_roles)
	elif required_present_roles is Array:
		required_present_roles = PackedStringArray(required_present_roles)
	else:
		required_present_roles = PackedStringArray(archetype.required_present_roles)
	var required_present_archetypes: Variant = params.get("required_present_archetypes", archetype.required_present_archetypes)
	if required_present_archetypes is PackedStringArray:
		required_present_archetypes = PackedStringArray(required_present_archetypes)
	elif required_present_archetypes is Array:
		required_present_archetypes = PackedStringArray(required_present_archetypes)
	else:
		required_present_archetypes = PackedStringArray(archetype.required_present_archetypes)
	var required_empty_roles: Variant = params.get("required_empty_roles", archetype.required_empty_roles)
	if required_empty_roles is PackedStringArray:
		required_empty_roles = PackedStringArray(required_empty_roles)
	elif required_empty_roles is Array:
		required_empty_roles = PackedStringArray(required_empty_roles)
	else:
		required_empty_roles = PackedStringArray(archetype.required_empty_roles)
	return {
		"source": &"placement_mechanic",
		"mechanic_id": StringName(mechanic.mechanic_id),
		"allowed_slot_types": allowed_slot_types,
		"required_placement_tags": required_tags,
		"granted_placement_tags": granted_tags,
		"placement_role": StringName(params.get("placement_role", archetype.placement_role)),
		"required_present_roles": required_present_roles,
		"required_present_archetypes": required_present_archetypes,
		"required_empty_roles": required_empty_roles,
		"slot_type_hint": slot_type_hint,
	}
