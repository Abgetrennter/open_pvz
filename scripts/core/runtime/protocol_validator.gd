extends RefCounted
class_name ProtocolValidator


static func ping():
	return true


static func validate_trigger_def(trigger_def) -> Array[String]:
	var errors: Array[String] = []
	if trigger_def == null:
		errors.append("TriggerDef is null.")
		return errors
	if StringName(trigger_def.trigger_id) == StringName():
		errors.append("TriggerDef.trigger_id must not be empty.")
	if StringName(trigger_def.event_name) == StringName():
		errors.append("TriggerDef.event_name must not be empty.")
	if int(trigger_def.max_bound_effects) <= 0:
		errors.append("TriggerDef.max_bound_effects must be greater than zero.")

	var seen_params: Dictionary = {}
	for param_def in trigger_def.condition_params:
		if not (param_def is Dictionary):
			errors.append("TriggerDef %s has a non-dictionary condition param." % String(trigger_def.trigger_id))
			continue
		var param_name := String(param_def.get("name", ""))
		if param_name.is_empty():
			errors.append("TriggerDef %s has a condition param without a name." % String(trigger_def.trigger_id))
			continue
		if seen_params.has(param_name):
			errors.append("TriggerDef %s has duplicate condition param %s." % [String(trigger_def.trigger_id), param_name])
			continue
		seen_params[param_name] = true
		errors.append_array(_validate_param_definition(param_def, "TriggerDef %s" % String(trigger_def.trigger_id)))
	return errors


static func validate_effect_def(effect_def) -> Array[String]:
	var errors: Array[String] = []
	if effect_def == null:
		errors.append("EffectDef is null.")
		return errors
	if StringName(effect_def.effect_id) == StringName():
		errors.append("EffectDef.effect_id must not be empty.")

	var seen_params: Dictionary = {}
	for param_def in effect_def.param_defs:
		if not (param_def is Dictionary):
			errors.append("EffectDef %s has a non-dictionary param definition." % String(effect_def.effect_id))
			continue
		var param_name := String(param_def.get("name", ""))
		if param_name.is_empty():
			errors.append("EffectDef %s has a param without a name." % String(effect_def.effect_id))
			continue
		if seen_params.has(param_name):
			errors.append("EffectDef %s has duplicate param %s." % [String(effect_def.effect_id), param_name])
			continue
		seen_params[param_name] = true
		errors.append_array(_validate_param_definition(param_def, "EffectDef %s" % String(effect_def.effect_id)))

	var seen_slots: Dictionary = {}
	for slot_def in effect_def.slots:
		if slot_def == null:
			errors.append("EffectDef %s has a null slot definition." % String(effect_def.effect_id))
			continue
		var slot_name := String(slot_def.slot_name)
		if slot_name.is_empty():
			errors.append("EffectDef %s has a slot without a name." % String(effect_def.effect_id))
			continue
		if seen_slots.has(slot_name):
			errors.append("EffectDef %s has duplicate slot %s." % [String(effect_def.effect_id), slot_name])
			continue
		seen_slots[slot_name] = true
	return errors


static func validate_height_band(height_band: Resource) -> Array[String]:
	var errors: Array[String] = []
	if height_band == null:
		errors.append("HeightBand is null.")
		return errors
	if StringName(height_band.band_id) == StringName():
		errors.append("HeightBand.band_id must not be empty.")
	if float(height_band.min_height) < 0.0:
		errors.append("HeightBand.min_height must be >= 0.")
	if float(height_band.max_height) < float(height_band.min_height):
		errors.append("HeightBand.max_height must be >= min_height.")
	return errors


static func validate_projectile_flight_profile(profile: Resource) -> Array[String]:
	var errors: Array[String] = []
	if profile == null:
		errors.append("ProjectileFlightProfile is null.")
		return errors
	if StringName(profile.profile_id) == StringName():
		errors.append("ProjectileFlightProfile.profile_id must not be empty.")

	var move_mode := String(profile.move_mode)
	if not _allowed_move_modes().has(move_mode):
		errors.append("ProjectileFlightProfile.move_mode must be one of %s." % _join_strings(_allowed_move_modes()))

	var height_strategy := String(profile.height_strategy)
	if not _allowed_height_strategies().has(height_strategy):
		errors.append("ProjectileFlightProfile.height_strategy must be one of %s." % _join_strings(_allowed_height_strategies()))

	var hit_strategy := String(profile.hit_strategy)
	if not hit_strategy.is_empty() and not _allowed_hit_strategies().has(hit_strategy):
		errors.append("ProjectileFlightProfile.hit_strategy must be one of %s." % _join_strings(_allowed_hit_strategies()))

	var terminal_hit_strategy := String(profile.terminal_hit_strategy)
	if not terminal_hit_strategy.is_empty() and not _allowed_terminal_hit_strategies().has(terminal_hit_strategy):
		errors.append("ProjectileFlightProfile.terminal_hit_strategy must be one of %s." % _join_strings(_allowed_terminal_hit_strategies()))

	var dynamic_target_axis := String(profile.dynamic_target_axis)
	if not _allowed_dynamic_target_axes().has(dynamic_target_axis):
		errors.append("ProjectileFlightProfile.dynamic_target_axis must be one of %s." % _join_strings(_allowed_dynamic_target_axes()))

	if float(profile.projection_scale) <= 0.0:
		errors.append("ProjectileFlightProfile.projection_scale must be greater than zero.")
	if float(profile.flight_height) < 0.0:
		errors.append("ProjectileFlightProfile.flight_height must be >= 0.")
	if float(profile.peak_height) < 0.0:
		errors.append("ProjectileFlightProfile.peak_height must be >= 0.")
	if float(profile.max_hit_height) < 0.0:
		errors.append("ProjectileFlightProfile.max_hit_height must be >= 0.")
	if float(profile.impact_radius) < 0.0:
		errors.append("ProjectileFlightProfile.impact_radius must be >= 0.")
	if float(profile.collision_padding) < 0.0:
		errors.append("ProjectileFlightProfile.collision_padding must be >= 0.")
	if float(profile.travel_duration) < -1.0:
		errors.append("ProjectileFlightProfile.travel_duration must be >= -1.")
	if float(profile.lead_time_scale) < 0.0:
		errors.append("ProjectileFlightProfile.lead_time_scale must be >= 0.")
	if float(profile.dynamic_target_adjustment) < -1.0:
		errors.append("ProjectileFlightProfile.dynamic_target_adjustment must be >= -1.")
	return errors


static func validate_entity_template(entity_template: Resource) -> Array[String]:
	var errors: Array[String] = []
	if entity_template == null:
		errors.append("EntityTemplate is null.")
		return errors
	if StringName(entity_template.template_id) == StringName():
		errors.append("EntityTemplate.template_id must not be empty.")
	var entity_kind := String(entity_template.entity_kind)
	if entity_kind not in ["plant", "zombie"]:
		errors.append("EntityTemplate.entity_kind must be plant or zombie.")
	if entity_template.hit_height_band != null:
		for error in validate_height_band(entity_template.hit_height_band):
			errors.append("EntityTemplate hit_height_band: %s" % error)
	if entity_template.projectile_flight_profile != null:
		for error in validate_projectile_flight_profile(entity_template.projectile_flight_profile):
			errors.append("EntityTemplate projectile_flight_profile: %s" % error)
	if not (entity_template.default_params is Dictionary):
		errors.append("EntityTemplate.default_params must be a Dictionary.")
	if int(entity_template.max_health) != -1 and int(entity_template.max_health) <= 0:
		errors.append("EntityTemplate.max_health must be -1 or greater than zero.")
	if entity_template.hitbox_size != Vector2.ZERO and (entity_template.hitbox_size.x <= 0.0 or entity_template.hitbox_size.y <= 0.0):
		errors.append("EntityTemplate.hitbox_size must be zero or a positive size.")
	return errors


static func validate_battle_scenario(scenario: Resource) -> Array[String]:
	var errors: Array[String] = []
	if scenario == null:
		errors.append("BattleScenario is null.")
		return errors
	if StringName(scenario.scenario_id) == StringName():
		errors.append("BattleScenario.scenario_id must not be empty.")
	if String(scenario.display_name).strip_edges().is_empty():
		errors.append("BattleScenario.display_name must not be empty.")
	if float(scenario.validation_time_limit) <= 0.0:
		errors.append("BattleScenario.validation_time_limit must be greater than zero.")

	for validation_rule in scenario.validation_rules:
		errors.append_array(_validate_battle_validation_rule(validation_rule, scenario.scenario_id))
	return errors


static func validate_battle_spawn_entry(spawn_entry: Resource, scenario_id: StringName = StringName()) -> Array[String]:
	var errors: Array[String] = []
	if spawn_entry == null:
		errors.append("BattleSpawnEntry is null.")
		return errors

	var scope := "BattleSpawnEntry"
	if scenario_id != StringName():
		scope = "%s in scenario %s" % [scope, String(scenario_id)]

	var entity_kind := String(spawn_entry.entity_kind)
	if spawn_entry.entity_template != null:
		for error in validate_entity_template(spawn_entry.entity_template):
			errors.append("%s entity_template: %s" % [scope, error])
		if spawn_entry.entity_template != null and StringName(spawn_entry.entity_template.get("entity_kind")) != StringName():
			entity_kind = String(spawn_entry.entity_template.get("entity_kind"))
	if entity_kind not in ["plant", "zombie"]:
		errors.append("%s.entity_kind must be plant or zombie." % scope)
	if int(spawn_entry.lane_id) < 0:
		errors.append("%s.lane_id must be >= 0." % scope)

	if spawn_entry.hit_height_band != null:
		for error in validate_height_band(spawn_entry.hit_height_band):
			errors.append("%s hit_height_band: %s" % [scope, error])

	if spawn_entry.projectile_flight_profile != null:
		for error in validate_projectile_flight_profile(spawn_entry.projectile_flight_profile):
			errors.append("%s projectile_flight_profile: %s" % [scope, error])

	return errors


static func normalize_trigger_instance(instance) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	if instance == null:
		errors.append("TriggerInstance is null.")
		return {"valid": false, "errors": errors}

	var trigger_def = TriggerRegistry.get_def(StringName(instance.def_id))
	if trigger_def == null:
		errors.append("Unknown TriggerDef %s." % String(instance.def_id))
		return {"valid": false, "errors": errors}

	var normalized_event_name := StringName(instance.event_name)
	if normalized_event_name == StringName():
		normalized_event_name = StringName(trigger_def.event_name)
	elif StringName(trigger_def.event_name) != StringName() and normalized_event_name != StringName(trigger_def.event_name):
		errors.append("TriggerInstance %s event_name must match TriggerDef event_name." % String(instance.def_id))

	var normalized_conditions: Dictionary = {}
	for param_def in trigger_def.condition_params:
		if not (param_def is Dictionary):
			continue
		var param_name := String(param_def.get("name", ""))
		if param_name.is_empty():
			continue
		if instance.condition_values.has(param_name):
			normalized_conditions[param_name] = _normalize_param_value(
				instance.condition_values[param_name],
				param_def,
				errors,
				"TriggerInstance %s" % String(instance.def_id)
			)
		elif param_def.has("default"):
			normalized_conditions[param_name] = param_def["default"]

	if not bool(trigger_def.allow_extra_conditions):
		for key: Variant in instance.condition_values.keys():
			if not normalized_conditions.has(key):
				errors.append("TriggerInstance %s has unsupported condition %s." % [String(instance.def_id), str(key)])

	if instance.effect_roots.is_empty():
		errors.append("TriggerInstance %s must bind at least one effect root." % String(instance.def_id))
	if instance.effect_roots.size() > int(trigger_def.max_bound_effects):
		errors.append("TriggerInstance %s exceeds max_bound_effects." % String(instance.def_id))

	for effect_root in instance.effect_roots:
		var normalized_effect: Dictionary = normalize_effect_node(effect_root)
		if not bool(normalized_effect.get("valid", false)):
			for error in PackedStringArray(normalized_effect.get("errors", PackedStringArray())):
				errors.append("TriggerInstance %s effect root: %s" % [String(instance.def_id), error])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"event_name": normalized_event_name,
		"condition_values": normalized_conditions,
	}


static func normalize_effect_node(node) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	if node == null:
		errors.append("EffectNode is null.")
		return {"valid": false, "errors": errors}
	if StringName(node.effect_id) == StringName():
		errors.append("EffectNode.effect_id must not be empty.")
		return {"valid": false, "errors": errors}

	var effect_def = EffectRegistry.get_def(StringName(node.effect_id))
	if effect_def == null:
		errors.append("Unknown EffectDef %s." % String(node.effect_id))
		return {"valid": false, "errors": errors}

	var normalized_params: Dictionary = {}
	for param_def in effect_def.param_defs:
		if not (param_def is Dictionary):
			continue
		var param_name := String(param_def.get("name", ""))
		if param_name.is_empty():
			continue
		if node.params.has(param_name):
			normalized_params[param_name] = _normalize_param_value(
				node.params[param_name],
				param_def,
				errors,
				"EffectNode %s" % String(node.effect_id)
			)
		elif param_def.has("default"):
			normalized_params[param_name] = param_def["default"]

	if not bool(effect_def.allow_extra_params):
		for key: Variant in node.params.keys():
			if not normalized_params.has(key):
				errors.append("EffectNode %s has unsupported param %s." % [String(node.effect_id), str(key)])

	var slot_defs: Dictionary = {}
	for slot_def in effect_def.slots:
		if slot_def == null:
			continue
		slot_defs[String(slot_def.slot_name)] = slot_def

	if not bool(effect_def.allow_extra_children):
		for child_key: Variant in node.children.keys():
			if not slot_defs.has(str(child_key)):
				errors.append("EffectNode %s has unsupported child slot %s." % [String(node.effect_id), str(child_key)])

	for slot_name: Variant in node.children.keys():
		if not slot_defs.has(str(slot_name)):
			continue
		var child = node.children[slot_name]
		if child == null:
			continue
		var slot_def = slot_defs[str(slot_name)]
		if int(slot_def.slot_type) != 1:
			continue
		if not slot_def.allowed_effect_ids.is_empty() and not slot_def.allowed_effect_ids.has(StringName(child.effect_id)):
			errors.append("EffectNode %s slot %s does not allow child effect %s." % [String(node.effect_id), str(slot_name), String(child.effect_id)])
			continue
		var child_validation: Dictionary = normalize_effect_node(child)
		if not bool(child_validation.get("valid", false)):
			for error in PackedStringArray(child_validation.get("errors", PackedStringArray())):
				errors.append("EffectNode %s slot %s: %s" % [String(node.effect_id), str(slot_name), error])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"params": normalized_params,
	}


static func _validate_battle_validation_rule(validation_rule: Resource, scenario_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if validation_rule == null:
		errors.append("BattleScenario %s contains a null validation rule." % String(scenario_id))
		return errors
	if StringName(validation_rule.rule_id) == StringName():
		errors.append("BattleScenario %s contains a validation rule without rule_id." % String(scenario_id))
	if StringName(validation_rule.event_name) == StringName():
		errors.append("BattleScenario %s validation rule %s must define event_name." % [String(scenario_id), String(validation_rule.rule_id)])
	if int(validation_rule.min_count) < 0:
		errors.append("BattleScenario %s validation rule %s min_count must be >= 0." % [String(scenario_id), String(validation_rule.rule_id)])
	if int(validation_rule.max_count) < -1:
		errors.append("BattleScenario %s validation rule %s max_count must be >= -1." % [String(scenario_id), String(validation_rule.rule_id)])
	if int(validation_rule.max_count) >= 0 and int(validation_rule.max_count) < int(validation_rule.min_count):
		errors.append("BattleScenario %s validation rule %s max_count must be >= min_count when bounded." % [String(scenario_id), String(validation_rule.rule_id)])
	return errors


static func _validate_param_definition(param_def: Dictionary, scope: String) -> Array[String]:
	var errors: Array[String] = []
	var param_type := String(param_def.get("type", ""))
	if param_type.is_empty():
		errors.append("%s has a param definition without type." % scope)
	elif not _allowed_param_types().has(param_type):
		errors.append("%s has unsupported param type %s." % [scope, param_type])
	return errors


static func _normalize_param_value(value: Variant, param_def: Dictionary, errors: PackedStringArray, scope: String) -> Variant:
	var param_name := String(param_def.get("name", "param"))
	var param_type := String(param_def.get("type", ""))
	var normalized_value: Variant = value

	match param_type:
		"int":
			if not (value is int):
				errors.append("%s param %s must be int." % [scope, param_name])
			normalized_value = int(value)
		"float":
			if not (value is float or value is int):
				errors.append("%s param %s must be float." % [scope, param_name])
			normalized_value = float(value)
		"string":
			if not (value is String or value is StringName):
				errors.append("%s param %s must be string." % [scope, param_name])
			normalized_value = String(value)
		"string_name":
			if not (value is String or value is StringName):
				errors.append("%s param %s must be StringName." % [scope, param_name])
			normalized_value = StringName(value)
		"bool":
			if not (value is bool):
				errors.append("%s param %s must be bool." % [scope, param_name])
			normalized_value = bool(value)
		"vector2":
			if not (value is Vector2):
				errors.append("%s param %s must be Vector2." % [scope, param_name])
			normalized_value = value if value is Vector2 else Vector2.ZERO
		"resource":
			if value != null and not (value is Resource):
				errors.append("%s param %s must be Resource." % [scope, param_name])
		_:
			pass

	if param_def.has("min") and (normalized_value is int or normalized_value is float):
		if float(normalized_value) < float(param_def["min"]):
			errors.append("%s param %s must be >= %s." % [scope, param_name, str(param_def["min"])])
	if param_def.has("max") and (normalized_value is int or normalized_value is float):
		if float(normalized_value) > float(param_def["max"]):
			errors.append("%s param %s must be <= %s." % [scope, param_name, str(param_def["max"])])
	if param_def.has("options"):
		var options := _variant_string_set(param_def["options"])
		var option_value := String(normalized_value)
		if not options.has(option_value):
			errors.append("%s param %s must be one of %s." % [scope, param_name, _join_strings(options)])

	return normalized_value


static func _allowed_move_modes() -> Array[String]:
	return ["linear", "track", "parabola"]


static func _allowed_height_strategies() -> Array[String]:
	return ["flat", "arc"]


static func _allowed_hit_strategies() -> Array[String]:
	return [
		"overlap",
		"terminal_hitbox",
		"terminal_radius",
		"overlap_and_terminal_hitbox",
		"overlap_and_terminal_radius",
		"swept_segment",
		"swept_segment_and_terminal_hitbox",
		"swept_segment_and_terminal_radius",
	]


static func _allowed_terminal_hit_strategies() -> Array[String]:
	return ["none", "impact_hitbox", "impact_radius"]


static func _allowed_dynamic_target_axes() -> Array[String]:
	return ["x", "y", "xy"]


static func _allowed_param_types() -> Array[String]:
	return ["int", "float", "string", "string_name", "bool", "vector2", "resource"]


static func _variant_string_set(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is PackedStringArray:
		for value in values:
			result.append(String(value))
	elif values is Array:
		for value in values:
			result.append(String(value))
	return result


static func _join_strings(values: Array[String]) -> String:
	return ", ".join(values)
