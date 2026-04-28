extends RefCounted
class_name ProtocolValidator

const CombatArchetypeRef = preload("res://scripts/core/defs/combat_archetype.gd")
const CombatMechanicRef = preload("res://scripts/core/defs/combat_mechanic.gd")
const EntityFactoryRef = preload("res://scripts/battle/entity_factory.gd")
const HeightBandRef = preload("res://scripts/core/defs/height_band.gd")
const ProjectileTemplateRef = preload("res://scripts/core/defs/projectile_template.gd")
const TriggerBindingRef = preload("res://scripts/core/defs/trigger_binding.gd")
const CardDefRef = preload("res://scripts/battle/card_def.gd")
const BattleCardPlayRequestRef = preload("res://scripts/battle/card_play_request.gd")
const BoardSlotCatalogRef = preload("res://scripts/battle/board_slot_catalog.gd")
const BoardSlotConfigRef = preload("res://scripts/battle/board_slot_config.gd")
const BattlefieldPresetRef = preload("res://scripts/battle/battlefield_preset.gd")
const StatusApplicationRequestRef = preload("res://scripts/battle/status_application_request.gd")
const FieldObjectConfigRef = preload("res://scripts/battle/field_object_config.gd")
const WaveSpawnEntryRef = preload("res://scripts/battle/wave_spawn_entry.gd")
const WaveDefRef = preload("res://scripts/battle/wave_def.gd")
const SunDropEntryRef = preload("res://scripts/battle/sun_drop_entry.gd")
const BattleResourceSpendRequestRef = preload("res://scripts/battle/resource_spend_request.gd")
const ProjectileFlightProfileRef = preload("res://scripts/projectile/projectile_flight_profile.gd")
const CombatContentResolverRef = preload("res://scripts/core/runtime/combat_content_resolver.gd")
const BattleModeDefRef = preload("res://scripts/battle/mode/battle_mode_def.gd")
const BattleInputProfileRef = preload("res://scripts/battle/mode/battle_input_profile.gd")
const BattleObjectiveDefRef = preload("res://scripts/battle/mode/battle_objective_def.gd")
const BattleRuleModuleRef = preload("res://scripts/battle/mode/battle_rule_module.gd")
const BattleModeInputRequestRef = preload("res://scripts/battle/mode/battle_mode_input_request.gd")
const BattleModeModuleRegistryRef = preload("res://scripts/battle/mode/battle_mode_module_registry.gd")
const FROZEN_TRIGGER_BEHAVIOR_SPECS := {
	&"attack": {
		"trigger_id": &"periodically",
		"event_name": &"game.tick",
	},
	&"when_damaged": {
		"trigger_id": &"when_damaged",
		"event_name": &"entity.damaged",
	},
	&"on_death": {
		"trigger_id": &"on_death",
		"event_name": &"entity.died",
	},
	&"on_spawned": {
		"trigger_id": &"on_spawned",
		"event_name": &"entity.spawned",
	},
	&"on_place": {
		"trigger_id": &"on_place",
		"event_name": &"placement.accepted",
	},
	&"proximity": {
		"trigger_id": &"proximity",
		"event_name": &"game.tick",
	},
}

const SPAWN_ENTRY_RESERVED_PARAMS := {
	"interval": true,
	"amount": true,
	"damage": true,
	"speed": true,
	"effect_overrides": true,
	"on_hit_effect_id": true,
	"on_hit_effect_params": true,
}
const ALLOWED_SPAWN_OVERRIDE_KEYS := {
	"interval": true,
	"amount": true,
	"damage": true,
	"speed": true,
	"effect_overrides": true,
	"on_hit_effect_id": true,
	"on_hit_effect_params": true,
	"projectile_template": true,
	"flight_profile": true,
	"movement_mode": true,
	"travel_duration": true,
	"arc_height": true,
	"impact_radius": true,
	"collision_padding": true,
	"lead_time_scale": true,
	"dynamic_target_adjustment": true,
	"dynamic_target_axis": true,
	"max_lead_distance": true,
	"lead_iterations": true,
	"target_position": true,
	"distance": true,
	"radius": true,
	"target_mode": true,
	"lifetime": true,
	"hitbox_radius": true,
	"hit_strategy": true,
	"terminal_hit_strategy": true,
	"max_penetrations": true,
	"pierce_range": true,
	"emission_mode": true,
	"lane_count": true,
	"lane_offset": true,
	"lane_id": true,
	"angle_count": true,
	"angle_spread": true,
	"turn_rate": true,
	"move_speed": true,
	"attack_damage": true,
	"attack_interval": true,
	"max_health": true,
	"hitbox_size": true,
	"detection_radius": true,
	"scan_range": true,
	"detection_id": true,
	"target_tags": true,
	"required_state": true,
	"arming_time": true,
	"start_delay": true,
	"value": true,
	"source_type": true,
	"offset_y": true,
}


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
	if height_band.get_script() != HeightBandRef:
		errors.append("HeightBand resource must use height_band.gd.")
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
	if profile.get_script() != ProjectileFlightProfileRef:
		errors.append("ProjectileFlightProfile resource must use projectile_flight_profile.gd.")
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


static func validate_projectile_template(projectile_template: Resource) -> Array[String]:
	var errors: Array[String] = []
	if projectile_template == null:
		errors.append("ProjectileTemplate is null.")
		return errors
	if projectile_template.get_script() != ProjectileTemplateRef:
		errors.append("ProjectileTemplate resource must use projectile_template.gd.")
		return errors
	if StringName(projectile_template.template_id) == StringName():
		errors.append("ProjectileTemplate.template_id must not be empty.")
	if projectile_template.flight_profile != null:
		for error in validate_projectile_flight_profile(projectile_template.flight_profile):
			errors.append("ProjectileTemplate flight_profile: %s" % error)
	if not (projectile_template.default_params is Dictionary):
		errors.append("ProjectileTemplate.default_params must be a Dictionary.")
	if float(projectile_template.lifetime) != -1.0 and float(projectile_template.lifetime) <= 0.0:
		errors.append("ProjectileTemplate.lifetime must be -1 or greater than zero.")
	if float(projectile_template.hitbox_radius) <= 0.0:
		errors.append("ProjectileTemplate.hitbox_radius must be greater than zero.")
	return errors


static func validate_combat_mechanic(mechanic: Resource) -> Array[String]:
	# TODO(mechanic-first): Tighten this validator once the first-stage family/type
	# protocol is frozen into dedicated registry data instead of permissive skeletons.
	var errors: Array[String] = []
	if mechanic == null:
		errors.append("CombatMechanic is null.")
		return errors
	if not (mechanic is CombatMechanicRef):
		errors.append("CombatMechanic resource must use combat_mechanic.gd or a subclass.")
		return errors
	if StringName(mechanic.mechanic_id) == StringName():
		errors.append("CombatMechanic.mechanic_id must not be empty.")
	if StringName(mechanic.family) == StringName():
		errors.append("CombatMechanic.family must not be empty.")
	elif String(mechanic.family) not in CombatMechanicRef.ALLOWED_FAMILIES:
		errors.append("CombatMechanic.family must be one of %s." % _join_strings(CombatMechanicRef.ALLOWED_FAMILIES))
	elif typeof(MechanicFamilyRegistry) != TYPE_NIL and not MechanicFamilyRegistry.has_family(StringName(mechanic.family)):
		errors.append("CombatMechanic.family %s must be registered in MechanicFamilyRegistry." % String(mechanic.family))
	if StringName(mechanic.type_id) == StringName():
		errors.append("CombatMechanic.type_id must not be empty.")
	elif typeof(MechanicTypeRegistry) != TYPE_NIL:
		if MechanicTypeRegistry.has_type(StringName(mechanic.type_id)):
			var registered_family := MechanicTypeRegistry.get_family_id(StringName(mechanic.type_id))
			if registered_family != StringName() and registered_family != StringName(mechanic.family):
				errors.append("CombatMechanic.type_id %s must belong to family %s." % [String(mechanic.type_id), String(registered_family)])
	if not (mechanic.params is Dictionary):
		errors.append("CombatMechanic.params must be a Dictionary.")
	return errors


static func validate_combat_archetype(archetype: Resource) -> Array[String]:
	var errors: Array[String] = []
	if archetype == null:
		errors.append("CombatArchetype is null.")
		return errors
	if not (archetype is CombatArchetypeRef):
		errors.append("CombatArchetype resource must use combat_archetype.gd or a subclass.")
		return errors
	if StringName(archetype.archetype_id) == StringName():
		errors.append("CombatArchetype.archetype_id must not be empty.")
	if String(archetype.entity_kind) not in ["plant", "zombie", "field_object", "projectile"]:
		errors.append("CombatArchetype.entity_kind must be plant, zombie, field_object, or projectile.")
	if not (archetype.default_params is Dictionary):
		errors.append("CombatArchetype.default_params must be a Dictionary.")
	if not (archetype.compiler_hints is Dictionary):
		errors.append("CombatArchetype.compiler_hints must be a Dictionary.")
	elif bool(archetype.compiler_hints.get("migrated_wrapper", false)):
		errors.append("CombatArchetype.compiler_hints must not include migrated_wrapper. Wrapper archetypes must be migrated to native mechanics.")
	if not (archetype.mechanics is Array):
		errors.append("CombatArchetype.mechanics must be an Array.")
	else:
		for mechanic in archetype.mechanics:
			for error in validate_combat_mechanic(mechanic):
				errors.append("CombatArchetype mechanics: %s" % error)
	if archetype.get("backend_entity_template") != null:
		errors.append("CombatArchetype.backend_entity_template is retired. Move data onto archetype fields and mechanics.")
	var backend_id_value: Variant = archetype.get("backend_entity_template_id")
	if backend_id_value != null and String(backend_id_value) != "":
		errors.append("CombatArchetype.backend_entity_template_id is retired. Use legacy_template_id only for event identity.")
	if not _can_validate_native_archetype(archetype):
		errors.append("CombatArchetype must define native runtime data through archetype fields or mechanics.")
	var placement_errors := _validate_archetype_placement_spec(archetype)
	for error in placement_errors:
		errors.append("CombatArchetype placement_spec: %s" % error)
	return errors


static func _validate_archetype_placement_spec(archetype: Resource) -> Array[String]:
	var errors: Array[String] = []
	if archetype == null or not (archetype is CombatArchetypeRef):
		return errors
	if StringName(archetype.entity_kind) != &"plant":
		return errors
	var enabled_placement_mechanics := 0
	for mechanic in archetype.mechanics:
		if not (mechanic is CombatMechanicRef):
			continue
		if not bool(mechanic.enabled):
			continue
		if StringName(mechanic.family) == CombatMechanicRef.FAMILY_PLACEMENT:
			enabled_placement_mechanics += 1
	if enabled_placement_mechanics > 1:
		errors.append("plant archetype must not define multiple enabled Placement mechanics.")
	var placement_spec := CombatContentResolverRef.resolve_archetype_placement_spec(archetype)
	if placement_spec.is_empty():
		errors.append("plant archetype must resolve a non-empty placement_spec.")
		return errors
	if StringName(placement_spec.get("placement_role", StringName())) == StringName():
		errors.append("placement_spec.placement_role must not be empty.")
	var required_tags := PackedStringArray(placement_spec.get("required_placement_tags", PackedStringArray()))
	if required_tags.is_empty():
		errors.append("placement_spec.required_placement_tags must not be empty for plant archetypes.")
	return errors


static func _can_validate_native_archetype(archetype: Resource) -> bool:
	if archetype == null or not (archetype is CombatArchetypeRef):
		return false
	if not archetype.mechanics.is_empty():
		return true
	if archetype.max_health <= 0:
		return false
	if archetype.hitbox_size == Vector2.ZERO:
		return false
	if archetype.hit_height_band == null:
		return false
	return true


static func validate_trigger_binding(trigger_binding: Resource) -> Array[String]:
	var errors: Array[String] = []
	if trigger_binding == null:
		errors.append("TriggerBinding is null.")
		return errors
	if trigger_binding.get_script() != TriggerBindingRef:
		errors.append("TriggerBinding resource must use trigger_binding.gd.")
		return errors
	if StringName(trigger_binding.binding_id) == StringName():
		errors.append("TriggerBinding.binding_id must not be empty.")
	if StringName(trigger_binding.behavior_key) == StringName():
		errors.append("TriggerBinding.behavior_key must not be empty.")
	else:
		var behavior_key := StringName(trigger_binding.behavior_key)
		var expected_behavior := _trigger_behavior_spec(behavior_key)
		if expected_behavior.is_empty():
			errors.append("TriggerBinding.behavior_key must be one of %s." % _join_strings(_allowed_trigger_behavior_keys()))
		else:
			var expected_trigger_id := StringName(expected_behavior.get("trigger_id", StringName()))
			if StringName(trigger_binding.trigger_id) != StringName() and StringName(trigger_binding.trigger_id) != expected_trigger_id:
				errors.append("TriggerBinding %s behavior_key %s must use trigger_id %s." % [
					String(trigger_binding.binding_id),
					String(behavior_key),
					String(expected_trigger_id),
				])
	if StringName(trigger_binding.trigger_id) == StringName():
		errors.append("TriggerBinding.trigger_id must not be empty.")
	if StringName(trigger_binding.effect_id) == StringName():
		errors.append("TriggerBinding.effect_id must not be empty.")
	if not (trigger_binding.condition_values is Dictionary):
		errors.append("TriggerBinding.condition_values must be a Dictionary.")
	if not (trigger_binding.effect_params is Dictionary):
		errors.append("TriggerBinding.effect_params must be a Dictionary.")
	if not (trigger_binding.on_hit_effect_params is Dictionary):
		errors.append("TriggerBinding.on_hit_effect_params must be a Dictionary.")
	if StringName(trigger_binding.trigger_id) != StringName():
		var trigger_def = TriggerRegistry.get_def(StringName(trigger_binding.trigger_id))
		if trigger_def == null:
			errors.append("TriggerBinding %s references unknown trigger_id %s." % [
				String(trigger_binding.binding_id),
				String(trigger_binding.trigger_id),
			])
		elif trigger_binding.condition_values is Dictionary:
			var trigger_normalization := _normalize_trigger_event_and_conditions(
				StringName(trigger_binding.event_name),
				trigger_binding.condition_values,
				trigger_def,
				"TriggerBinding %s" % String(trigger_binding.binding_id)
			)
			for error in PackedStringArray(trigger_normalization.get("errors", PackedStringArray())):
				errors.append(String(error))
	if trigger_binding.projectile_template != null:
		for error in validate_projectile_template(trigger_binding.projectile_template):
			errors.append("TriggerBinding projectile_template: %s" % error)
	return errors


static func validate_entity_template(entity_template: Resource) -> Array[String]:
	var errors: Array[String] = []
	if entity_template == null:
		errors.append("EntityTemplate is null.")
		return errors
	errors.append("EntityTemplate is retired. Official content must use CombatArchetype + CombatMechanic + RuntimeSpec.")
	return errors


static func validate_battle_mode_def(mode_def: Resource) -> Array[String]:
	var errors: Array[String] = []
	if mode_def == null:
		errors.append("BattleModeDef is null.")
		return errors
	if mode_def.get_script() != BattleModeDefRef:
		errors.append("BattleModeDef resource must use battle_mode_def.gd.")
		return errors
	if StringName(mode_def.get("mode_id")) == StringName():
		errors.append("BattleModeDef.mode_id must not be empty.")
	if String(mode_def.get("display_name")).strip_edges().is_empty():
		errors.append("BattleModeDef.display_name must not be empty.")
	var category := StringName(mode_def.get("category"))
	if category == StringName():
		errors.append("BattleModeDef.category must not be empty.")
	elif category not in [&"standard", &"adventure", &"survival", &"challenge", &"puzzle"]:
		errors.append("BattleModeDef.category must be standard, adventure, survival, challenge, or puzzle.")
	var input_profile: Variant = mode_def.get("input_profile")
	if input_profile != null:
		for error in validate_battle_input_profile(input_profile):
			errors.append("BattleModeDef input_profile: %s" % error)
	var objective_def: Variant = mode_def.get("objective_def")
	if objective_def != null:
		for error in validate_battle_objective_def(objective_def):
			errors.append("BattleModeDef objective_def: %s" % error)
	var rule_modules: Variant = mode_def.get("rule_modules")
	if not (rule_modules is Array):
		errors.append("BattleModeDef.rule_modules must be an Array.")
	else:
		for rule_module in rule_modules:
			for error in validate_battle_rule_module(rule_module):
				errors.append("BattleModeDef rule_modules: %s" % error)
	return errors


static func validate_battle_input_profile(input_profile: Resource) -> Array[String]:
	var errors: Array[String] = []
	if input_profile == null:
		errors.append("BattleInputProfile is null.")
		return errors
	if input_profile.get_script() != BattleInputProfileRef:
		errors.append("BattleInputProfile resource must use battle_input_profile.gd.")
		return errors
	if StringName(input_profile.get("profile_id")) == StringName():
		errors.append("BattleInputProfile.profile_id must not be empty.")
	for field_name in [
		"enable_card_select",
		"enable_card_place",
		"enable_slot_click",
		"enable_entity_click",
		"enable_slot_drag",
		"enable_swap",
		"enable_manual_skill",
		"enable_rhythm_hit",
		"enable_cancel",
	]:
		if not (input_profile.get(field_name) is bool):
			errors.append("BattleInputProfile.%s must be bool." % field_name)
	if bool(input_profile.get("enable_card_place")) and not bool(input_profile.get("enable_slot_click")):
		errors.append("BattleInputProfile.enable_card_place currently requires enable_slot_click.")
	if bool(input_profile.get("enable_swap")) and not bool(input_profile.get("enable_slot_drag")):
		errors.append("BattleInputProfile.enable_swap currently requires enable_slot_drag.")
	if bool(input_profile.get("enable_manual_skill")) and not bool(input_profile.get("enable_entity_click")):
		errors.append("BattleInputProfile.enable_manual_skill currently requires enable_entity_click.")
	if not (input_profile.get("input_tags") is PackedStringArray):
		errors.append("BattleInputProfile.input_tags must be a PackedStringArray.")
	return errors


static func validate_battle_objective_def(objective_def: Resource) -> Array[String]:
	var errors: Array[String] = []
	if objective_def == null:
		errors.append("BattleObjectiveDef is null.")
		return errors
	if objective_def.get_script() != BattleObjectiveDefRef:
		errors.append("BattleObjectiveDef resource must use battle_objective_def.gd.")
		return errors
	if StringName(objective_def.get("objective_id")) == StringName():
		errors.append("BattleObjectiveDef.objective_id must not be empty.")
	var objective_type := StringName(objective_def.get("objective_type"))
	if objective_type == StringName():
		errors.append("BattleObjectiveDef.objective_type must not be empty.")
	elif objective_type not in [&"all_waves_cleared", &"survive_duration", &"protect_template", &"score_threshold", &"combo_threshold", &"clear_special_targets", &"collect_resource", &"defeat_named_spawn"]:
		errors.append("BattleObjectiveDef.objective_type must be one of all_waves_cleared, survive_duration, protect_template, score_threshold, combo_threshold, clear_special_targets, collect_resource, defeat_named_spawn.")
	if not (objective_def.get("params") is Dictionary):
		errors.append("BattleObjectiveDef.params must be a Dictionary.")
	else:
		var params: Dictionary = objective_def.get("params")
		match objective_type:
			&"survive_duration":
				if float(params.get("duration", 0.0)) <= 0.0:
					errors.append("BattleObjectiveDef survive_duration requires params.duration > 0.")
			&"score_threshold", &"combo_threshold":
				if int(params.get("threshold", 0)) <= 0:
					errors.append("BattleObjectiveDef %s requires params.threshold > 0." % String(objective_type))
			&"clear_special_targets":
				var target_template_ids := PackedStringArray(params.get("target_template_ids", PackedStringArray()))
				var target_archetype_ids := PackedStringArray(params.get("target_archetype_ids", PackedStringArray()))
				if target_template_ids.is_empty() and target_archetype_ids.is_empty():
					errors.append("BattleObjectiveDef clear_special_targets requires params.target_template_ids or params.target_archetype_ids.")
			&"collect_resource":
				if int(params.get("amount", 0)) <= 0:
					errors.append("BattleObjectiveDef collect_resource requires params.amount > 0.")
				if StringName(params.get("resource_id")) == StringName():
					errors.append("BattleObjectiveDef collect_resource requires params.resource_id.")
			&"defeat_named_spawn":
				if StringName(params.get("template_id")) == StringName() and StringName(params.get("archetype_id")) == StringName():
					errors.append("BattleObjectiveDef defeat_named_spawn requires params.template_id or params.archetype_id.")
	if not (objective_def.get("failure_conditions") is PackedStringArray):
		errors.append("BattleObjectiveDef.failure_conditions must be a PackedStringArray.")
	else:
		for condition in PackedStringArray(objective_def.get("failure_conditions")):
			if StringName(condition) not in [&"time_expired"]:
				errors.append("BattleObjectiveDef.failure_conditions entries must currently be time_expired.")
		if PackedStringArray(objective_def.get("failure_conditions")).has(&"time_expired"):
			var params: Dictionary = objective_def.get("params") if objective_def.get("params") is Dictionary else {}
			if float(params.get("time_limit", 0.0)) <= 0.0:
				errors.append("BattleObjectiveDef failure condition time_expired requires params.time_limit > 0.")
	if not (objective_def.get("summary_tags") is PackedStringArray):
		errors.append("BattleObjectiveDef.summary_tags must be a PackedStringArray.")
	return errors


static func validate_battle_rule_module(rule_module: Resource) -> Array[String]:
	var errors: Array[String] = []
	if rule_module == null:
		errors.append("BattleRuleModule is null.")
		return errors
	if rule_module.get_script() != BattleRuleModuleRef:
		errors.append("BattleRuleModule resource must use battle_rule_module.gd.")
		return errors
	if StringName(rule_module.get("module_id")) == StringName():
		errors.append("BattleRuleModule.module_id must not be empty.")
	if String(rule_module.get("display_name")).strip_edges().is_empty():
		errors.append("BattleRuleModule.display_name must not be empty.")
	if not (rule_module.get("enabled") is bool):
		errors.append("BattleRuleModule.enabled must be bool.")
	if not (rule_module.get("params") is Dictionary):
		errors.append("BattleRuleModule.params must be a Dictionary.")
	if not (rule_module.get("tags") is PackedStringArray):
		errors.append("BattleRuleModule.tags must be a PackedStringArray.")
	var registry := BattleModeModuleRegistryRef.new()
	var module_id := StringName(rule_module.get("module_id"))
	if module_id != StringName() and not registry.has_handler(module_id):
		errors.append("BattleRuleModule.module_id %s must be registered in BattleModeModuleRegistry." % String(module_id))
	return errors


static func validate_battle_mode_input_request(input_request: Resource) -> Array[String]:
	var errors: Array[String] = []
	if input_request == null:
		errors.append("BattleModeInputRequest is null.")
		return errors
	if input_request.get_script() != BattleModeInputRequestRef:
		errors.append("BattleModeInputRequest resource must use battle_mode_input_request.gd.")
		return errors
	if float(input_request.get("at_time")) < 0.0:
		errors.append("BattleModeInputRequest.at_time must be >= 0.")
	var action_name := StringName(input_request.get("action_name"))
	if action_name == StringName():
		errors.append("BattleModeInputRequest.action_name must not be empty.")
	elif action_name not in [&"entity_click", &"cell_click", &"slot_drag", &"cancel"]:
		errors.append("BattleModeInputRequest.action_name must be one of entity_click, cell_click, slot_drag, cancel.")
	match action_name:
		&"entity_click":
			var entity_id := int(input_request.get("entity_id"))
			var entity_archetype_id := StringName(input_request.get("entity_archetype_id"))
			var legacy_template_id := StringName(input_request.get("legacy_template_id"))
			if entity_id < 0 and entity_archetype_id == StringName() and legacy_template_id == StringName():
				errors.append("BattleModeInputRequest entity_click requires entity_id, entity_archetype_id, or legacy_template_id.")
		&"cell_click":
			if int(input_request.get("lane_id")) < 0:
				errors.append("BattleModeInputRequest cell_click requires lane_id >= 0.")
			if int(input_request.get("slot_index")) < 0:
				errors.append("BattleModeInputRequest cell_click requires slot_index >= 0.")
		&"slot_drag":
			if int(input_request.get("from_lane")) < 0 or int(input_request.get("from_slot")) < 0:
				errors.append("BattleModeInputRequest slot_drag requires from_lane/from_slot >= 0.")
			if int(input_request.get("to_lane")) < 0 or int(input_request.get("to_slot")) < 0:
				errors.append("BattleModeInputRequest slot_drag requires to_lane/to_slot >= 0.")
	if not (input_request.get("metadata") is Dictionary):
		errors.append("BattleModeInputRequest.metadata must be a Dictionary.")
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
	if int(scenario.get("initial_sun")) < 0:
		errors.append("BattleScenario.initial_sun must be >= 0.")
	if float(scenario.get("sun_auto_collect_delay")) < -1.0:
		errors.append("BattleScenario.sun_auto_collect_delay must be >= -1.")
	var battlefield_preset = _resolve_battlefield_preset(scenario)
	if battlefield_preset != null:
		errors.append_array(validate_battlefield_preset(battlefield_preset))
	var resolved_board_slot_count := _resolve_scenario_board_slot_count(scenario, battlefield_preset)
	if resolved_board_slot_count <= 0:
		errors.append("BattleScenario.board_slot_count must be > 0.")
	var resolved_board_slot_spacing := _resolve_scenario_board_slot_spacing(scenario, battlefield_preset)
	if resolved_board_slot_spacing <= 0.0:
		errors.append("BattleScenario.board_slot_spacing must be > 0.")
	if float(scenario.get("defeat_line_x")) <= 0.0:
		errors.append("BattleScenario.defeat_line_x must be > 0.")
	var battle_goal := StringName(scenario.get("battle_goal"))
	if battle_goal != StringName() and battle_goal not in [&"all_waves_cleared", &"survive_duration", &"protect_and_clear"]:
		errors.append("BattleScenario.battle_goal must be all_waves_cleared, survive_duration, or protect_and_clear.")
	var defeat_conditions := PackedStringArray(scenario.get("defeat_conditions"))
	for defeat_condition in defeat_conditions:
		if StringName(defeat_condition) not in [&"zombie_reached_goal", &"protect_template"]:
			errors.append("BattleScenario.defeat_conditions entries must be zombie_reached_goal or protect_template.")
	if battle_goal == &"survive_duration" and float(scenario.get("survival_duration")) <= 0.0:
		errors.append("BattleScenario.survival_duration must be > 0 when battle_goal is survive_duration.")
	if defeat_conditions.has("protect_template") and StringName(scenario.get("protected_template_id")) == StringName():
		errors.append("BattleScenario.protected_template_id must not be empty when defeat_conditions includes protect_template.")

	var mode_def: Variant = scenario.get("mode_def")
	if mode_def != null:
		for error in validate_battle_mode_def(mode_def):
			errors.append("BattleScenario mode_def: %s" % error)
	var mode_rule_modules: Variant = scenario.get("mode_rule_modules")
	if not (mode_rule_modules is Array):
		errors.append("BattleScenario.mode_rule_modules must be an Array.")
	elif mode_def == null and not Array(mode_rule_modules).is_empty():
		errors.append("BattleScenario.mode_rule_modules requires mode_def.")
	elif mode_rule_modules is Array:
		for rule_module in mode_rule_modules:
			for error in validate_battle_rule_module(rule_module):
				errors.append("BattleScenario mode_rule_modules: %s" % error)
	var objective_override: Variant = scenario.get("objective_override")
	if objective_override != null:
		if mode_def == null:
			errors.append("BattleScenario.objective_override requires mode_def.")
		for error in validate_battle_objective_def(objective_override):
			errors.append("BattleScenario objective_override: %s" % error)
	var input_profile_override: Variant = scenario.get("input_profile_override")
	if input_profile_override != null:
		if mode_def == null:
			errors.append("BattleScenario.input_profile_override requires mode_def.")
		for error in validate_battle_input_profile(input_profile_override):
			errors.append("BattleScenario input_profile_override: %s" % error)
	var mode_input_requests: Variant = scenario.get("mode_input_requests")
	if not (mode_input_requests is Array):
		errors.append("BattleScenario.mode_input_requests must be an Array.")
	elif mode_def == null and not Array(mode_input_requests).is_empty():
		errors.append("BattleScenario.mode_input_requests requires mode_def.")
	else:
		for input_request in Array(mode_input_requests):
			for error in validate_battle_mode_input_request(input_request):
				errors.append("BattleScenario mode_input_requests: %s" % error)

	var configured_board_slot_configs: Variant = scenario.get("board_slot_configs")
	if configured_board_slot_configs is Array:
		for slot_config in configured_board_slot_configs:
			errors.append_array(_validate_board_slot_config(slot_config, scenario.scenario_id, resolved_board_slot_count))

	var configured_sun_drop_entries: Variant = scenario.get("sun_drop_entries")
	if configured_sun_drop_entries is Array:
		for sun_drop_entry in configured_sun_drop_entries:
			errors.append_array(_validate_sun_drop_entry(sun_drop_entry, scenario.scenario_id))

	var configured_resource_spend_requests: Variant = scenario.get("resource_spend_requests")
	if configured_resource_spend_requests is Array:
		for spend_request in configured_resource_spend_requests:
			errors.append_array(_validate_resource_spend_request(spend_request, scenario.scenario_id))

	var configured_card_defs: Variant = scenario.get("card_defs")
	if configured_card_defs is Array:
		for card_def in configured_card_defs:
			errors.append_array(_validate_card_def(card_def, scenario.scenario_id))

	var configured_card_play_requests: Variant = scenario.get("card_play_requests")
	if configured_card_play_requests is Array:
		for play_request in configured_card_play_requests:
			errors.append_array(_validate_card_play_request(play_request, scenario.scenario_id, int(scenario.get("board_slot_count"))))

	var configured_status_application_requests: Variant = scenario.get("status_application_requests")
	if configured_status_application_requests is Array:
		for status_request in configured_status_application_requests:
			errors.append_array(_validate_status_application_request(status_request, scenario.scenario_id))

	var configured_wave_defs: Variant = scenario.get("wave_defs")
	if configured_wave_defs is Array:
		for wave_def in configured_wave_defs:
			errors.append_array(_validate_wave_def(wave_def, scenario.scenario_id))

	var configured_field_object_configs: Variant = scenario.get("field_object_configs")
	if configured_field_object_configs is Array:
		for field_object_config in configured_field_object_configs:
			errors.append_array(_validate_field_object_config(field_object_config, scenario.scenario_id))

	for validation_rule in scenario.validation_rules:
		errors.append_array(_validate_battle_validation_rule(validation_rule, scenario.scenario_id))
	return errors


static func validate_battlefield_preset(battlefield_preset: Resource) -> Array[String]:
	var errors: Array[String] = []
	if battlefield_preset == null:
		errors.append("BattlefieldPreset is null.")
		return errors
	if battlefield_preset.get_script() != BattlefieldPresetRef:
		errors.append("BattlefieldPreset resource must use battlefield_preset.gd.")
		return errors
	if StringName(battlefield_preset.get("preset_id")) == StringName():
		errors.append("BattlefieldPreset.preset_id must not be empty.")
	if int(battlefield_preset.get("lane_count")) <= 0:
		errors.append("BattlefieldPreset.lane_count must be > 0.")
	var board_slot_count := int(battlefield_preset.get("board_slot_count"))
	if board_slot_count <= 0:
		errors.append("BattlefieldPreset.board_slot_count must be > 0.")
	if float(battlefield_preset.get("board_slot_spacing")) <= 0.0:
		errors.append("BattlefieldPreset.board_slot_spacing must be > 0.")
	var configured_slot_configs: Variant = battlefield_preset.get("board_slot_configs")
	if configured_slot_configs is Array:
		for slot_config in configured_slot_configs:
			errors.append_array(_validate_board_slot_config(slot_config, StringName(battlefield_preset.get("preset_id")), board_slot_count))
	return errors


static func validate_battle_spawn_entry(spawn_entry: Resource, scenario_id: StringName = StringName()) -> Array[String]:
	var errors: Array[String] = []
	if spawn_entry == null:
		errors.append("BattleSpawnEntry is null.")
		return errors

	var scope := "BattleSpawnEntry"
	if scenario_id != StringName():
		scope = "%s in scenario %s" % [scope, String(scenario_id)]

	var resolved_archetype = CombatContentResolverRef.resolve_spawn_entry_archetype(spawn_entry)
	var entity_kind := String(spawn_entry.entity_kind)
	var legacy_entity_template_value: Variant = spawn_entry.get("entity_template_id")
	if resolved_archetype == null:
		errors.append("%s must resolve an archetype through archetype/archetype_id." % scope)
	if StringName(spawn_entry.get("archetype_id")) != StringName() and resolved_archetype == null:
		errors.append("%s.archetype_id must resolve through SceneRegistry." % scope)
	if (legacy_entity_template_value != null and String(legacy_entity_template_value) != "") or spawn_entry.get("entity_template") != null:
		errors.append("%s must not define entity_template/entity_template_id. Official content must spawn through archetype only." % scope)
	if resolved_archetype != null:
		for error in validate_combat_archetype(resolved_archetype):
			errors.append("%s archetype: %s" % [scope, error])
		if StringName(resolved_archetype.get("entity_kind")) != StringName():
			entity_kind = String(resolved_archetype.get("entity_kind"))
	if entity_kind not in ["plant", "zombie", "field_object"]:
		errors.append("%s.entity_kind must be plant, zombie, or field_object." % scope)
	if int(spawn_entry.lane_id) < 0:
		errors.append("%s.lane_id must be >= 0." % scope)

	var hit_height_band_override: Resource = CombatContentResolverRef.resolve_spawn_hit_height_band_override(spawn_entry)
	if hit_height_band_override != null:
		for error in validate_height_band(hit_height_band_override):
			errors.append("%s hit_height_band: %s" % [scope, error])

	var projectile_profile_override: Resource = CombatContentResolverRef.resolve_spawn_projectile_profile_override(spawn_entry)
	if projectile_profile_override != null:
		for error in validate_projectile_flight_profile(projectile_profile_override):
			errors.append("%s projectile_flight_profile: %s" % [scope, error])
	var raw_spawn_overrides: Variant = spawn_entry.get("spawn_overrides")
	if raw_spawn_overrides != null and not (raw_spawn_overrides is Dictionary):
		errors.append("%s.spawn_overrides must be a Dictionary." % scope)
	if spawn_entry.get("projectile_template_override") != null and not (spawn_entry.get("projectile_template_override") is ProjectileTemplateRef):
		errors.append("%s.projectile_template_override must be a ProjectileTemplate resource." % scope)
	if spawn_entry.get("projectile_flight_profile_override") != null:
		for error in validate_projectile_flight_profile(spawn_entry.get("projectile_flight_profile_override")):
			errors.append("%s projectile_flight_profile_override: %s" % [scope, error])
	var projectile_template = CombatContentResolverRef.resolve_projectile_template(spawn_entry, resolved_archetype)
	if projectile_template != null:
		for error in validate_projectile_template(projectile_template):
			errors.append("%s projectile_template: %s" % [scope, error])
	errors.append_array(_validate_projectile_config_consistency(
		CombatContentResolverRef.merge_spawn_params(spawn_entry, resolved_archetype),
		projectile_template,
		"%s params" % scope
	))

	errors.append_array(_validate_entity_runtime_params(
		entity_kind,
		CombatContentResolverRef.merge_spawn_params(spawn_entry, resolved_archetype),
		"%s params" % scope
	))
	if resolved_archetype != null:
		errors.append_array(_validate_archetype_compiled_bindings(
			StringName(entity_kind),
			resolved_archetype,
			spawn_entry,
			"%s archetype compiled_bindings" % scope
		))
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

	var trigger_normalization := _normalize_trigger_event_and_conditions(
		StringName(instance.event_name),
		instance.condition_values,
		trigger_def,
		"TriggerInstance %s" % String(instance.def_id)
	)
	for error in PackedStringArray(trigger_normalization.get("errors", PackedStringArray())):
		errors.append(String(error))
	var normalized_event_name := StringName(trigger_normalization.get("event_name", instance.event_name))
	var normalized_conditions: Dictionary = Dictionary(trigger_normalization.get("condition_values", instance.condition_values))

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
	var effect_strategy: Callable = EffectRegistry.get_strategy(StringName(node.effect_id))
	if not effect_strategy.is_valid():
		errors.append("EffectDef %s has no registered strategy." % String(node.effect_id))
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
		if not _effect_allowed_in_slot(child, slot_def):
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


static func _effect_allowed_in_slot(child, slot_def) -> bool:
	if child == null or slot_def == null:
		return false
	var child_effect_id := StringName(child.effect_id)
	if slot_def.allowed_effect_ids.is_empty() and slot_def.allowed_effect_tags.is_empty():
		return true
	if slot_def.allowed_effect_ids.has(child_effect_id):
		return true
	if slot_def.allowed_effect_tags.is_empty():
		return false
	var child_effect_def = EffectRegistry.get_def(child_effect_id)
	if child_effect_def == null:
		return false
	var effect_tags := PackedStringArray(child_effect_def.tags)
	for allowed_tag in PackedStringArray(slot_def.allowed_effect_tags):
		if effect_tags.has(allowed_tag):
			return true
	return false


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


static func _validate_sun_drop_entry(drop_entry: Resource, scenario_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if drop_entry == null:
		errors.append("BattleScenario %s contains a null sun drop entry." % String(scenario_id))
		return errors
	if drop_entry.get_script() != SunDropEntryRef:
		errors.append("BattleScenario %s sun_drop_entries must use sun_drop_entry.gd." % String(scenario_id))
		return errors
	if float(drop_entry.get("at_time")) < 0.0:
		errors.append("BattleScenario %s sun drop at_time must be >= 0." % String(scenario_id))
	if int(drop_entry.get("value")) <= 0:
		errors.append("BattleScenario %s sun drop value must be > 0." % String(scenario_id))
	if float(drop_entry.get("auto_collect_delay")) < -1.0:
		errors.append("BattleScenario %s sun drop auto_collect_delay must be >= -1." % String(scenario_id))
	return errors


static func _validate_resource_spend_request(spend_request: Resource, scenario_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if spend_request == null:
		errors.append("BattleScenario %s contains a null resource spend request." % String(scenario_id))
		return errors
	if spend_request.get_script() != BattleResourceSpendRequestRef:
		errors.append("BattleScenario %s resource_spend_requests must use resource_spend_request.gd." % String(scenario_id))
		return errors
	if float(spend_request.get("at_time")) < 0.0:
		errors.append("BattleScenario %s resource spend at_time must be >= 0." % String(scenario_id))
	if StringName(spend_request.get("resource_id")) == StringName():
		errors.append("BattleScenario %s resource spend request must define resource_id." % String(scenario_id))
	if int(spend_request.get("cost")) <= 0:
		errors.append("BattleScenario %s resource spend cost must be > 0." % String(scenario_id))
	return errors


static func _validate_card_def(card_def: Resource, scenario_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if card_def == null:
		errors.append("BattleScenario %s contains a null card def." % String(scenario_id))
		return errors
	if card_def.get_script() != CardDefRef:
		errors.append("BattleScenario %s card_defs must use card_def.gd." % String(scenario_id))
		return errors
	if StringName(card_def.get("card_id")) == StringName():
		errors.append("BattleScenario %s card def must define card_id." % String(scenario_id))
	var archetype_id := StringName(card_def.get("archetype_id"))
	var entity_template_value: Variant = card_def.get("entity_template_id")
	if archetype_id == StringName():
		errors.append("BattleScenario %s card def %s must define archetype_id." % [String(scenario_id), String(card_def.get("card_id"))])
	elif archetype_id != StringName():
		if not SceneRegistry.has_archetype(archetype_id):
			errors.append("BattleScenario %s card def %s references unknown archetype_id %s." % [
				String(scenario_id),
				String(card_def.get("card_id")),
				String(archetype_id),
			])
	if entity_template_value != null and String(entity_template_value) != "":
		errors.append("BattleScenario %s card def %s must not define entity_template_id." % [String(scenario_id), String(card_def.get("card_id"))])
	if int(card_def.get("sun_cost")) < 0:
		errors.append("BattleScenario %s card def %s sun_cost must be >= 0." % [String(scenario_id), String(card_def.get("card_id"))])
	if float(card_def.get("cooldown_seconds")) < 0.0:
		errors.append("BattleScenario %s card def %s cooldown_seconds must be >= 0." % [String(scenario_id), String(card_def.get("card_id"))])
	var placement_tags: Variant = card_def.get("placement_tags")
	if not (placement_tags is PackedStringArray):
		errors.append("BattleScenario %s card def %s placement_tags must be a PackedStringArray." % [String(scenario_id), String(card_def.get("card_id"))])
	return errors


static func _validate_card_play_request(play_request: Resource, scenario_id: StringName, board_slot_count: int) -> Array[String]:
	var errors: Array[String] = []
	if play_request == null:
		errors.append("BattleScenario %s contains a null card play request." % String(scenario_id))
		return errors
	if play_request.get_script() != BattleCardPlayRequestRef:
		errors.append("BattleScenario %s card_play_requests must use card_play_request.gd." % String(scenario_id))
		return errors
	if float(play_request.get("at_time")) < 0.0:
		errors.append("BattleScenario %s card play request at_time must be >= 0." % String(scenario_id))
	if StringName(play_request.get("card_id")) == StringName():
		errors.append("BattleScenario %s card play request must define card_id." % String(scenario_id))
	if int(play_request.get("slot_index")) < 0 or int(play_request.get("slot_index")) >= board_slot_count:
		errors.append("BattleScenario %s card play request slot_index must be within board_slot_count." % String(scenario_id))
	if int(play_request.get("lane_id")) < 0:
		errors.append("BattleScenario %s card play request lane_id must be >= 0." % String(scenario_id))
	return errors


static func _validate_board_slot_config(slot_config: Resource, scenario_id: StringName, board_slot_count: int) -> Array[String]:
	var errors: Array[String] = []
	if slot_config == null:
		errors.append("BattleScenario %s contains a null board slot config." % String(scenario_id))
		return errors
	if slot_config.get_script() != BoardSlotConfigRef:
		errors.append("BattleScenario %s board_slot_configs must use board_slot_config.gd." % String(scenario_id))
		return errors
	if int(slot_config.get("lane_id")) < 0:
		errors.append("BattleScenario %s board slot config lane_id must be >= 0." % String(scenario_id))
	if int(slot_config.get("slot_index")) < 0 or int(slot_config.get("slot_index")) >= board_slot_count:
		errors.append("BattleScenario %s board slot config slot_index must be within board_slot_count." % String(scenario_id))
	if StringName(slot_config.get("slot_type")) == StringName():
		errors.append("BattleScenario %s board slot config must define slot_type." % String(scenario_id))
	elif not BoardSlotCatalogRef.is_known_slot_type(StringName(slot_config.get("slot_type"))):
		errors.append("BattleScenario %s board slot config slot_type must be one of %s." % [
			String(scenario_id),
			", ".join(BoardSlotCatalogRef.list_slot_types()),
		])
	var placement_tags: Variant = slot_config.get("placement_tags")
	if not (placement_tags is PackedStringArray):
		errors.append("BattleScenario %s board slot config placement_tags must be a PackedStringArray." % String(scenario_id))
	return errors


static func _validate_status_application_request(status_request: Resource, scenario_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if status_request == null:
		errors.append("BattleScenario %s contains a null status application request." % String(scenario_id))
		return errors
	if status_request.get_script() != StatusApplicationRequestRef:
		errors.append("BattleScenario %s status_application_requests must use status_application_request.gd." % String(scenario_id))
		return errors
	if float(status_request.get("at_time")) < 0.0:
		errors.append("BattleScenario %s status application at_time must be >= 0." % String(scenario_id))
	if StringName(status_request.get("status_id")) == StringName():
		errors.append("BattleScenario %s status application must define status_id." % String(scenario_id))
	if float(status_request.get("duration")) <= 0.0:
		errors.append("BattleScenario %s status application duration must be > 0." % String(scenario_id))
	if float(status_request.get("movement_scale")) < 0.0:
		errors.append("BattleScenario %s status application movement_scale must be >= 0." % String(scenario_id))
	return errors


static func _validate_wave_def(wave_def: Resource, scenario_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if wave_def == null:
		errors.append("BattleScenario %s contains a null wave def." % String(scenario_id))
		return errors
	if wave_def.get_script() != WaveDefRef:
		errors.append("BattleScenario %s wave_defs must use wave_def.gd." % String(scenario_id))
		return errors
	if StringName(wave_def.get("wave_id")) == StringName():
		errors.append("BattleScenario %s wave def must define wave_id." % String(scenario_id))
	if float(wave_def.get("start_time")) < 0.0:
		errors.append("BattleScenario %s wave %s start_time must be >= 0." % [String(scenario_id), String(wave_def.get("wave_id"))])
	var spawn_entries: Variant = wave_def.get("spawn_entries")
	if not (spawn_entries is Array) or Array(spawn_entries).is_empty():
		errors.append("BattleScenario %s wave %s must contain at least one spawn entry." % [String(scenario_id), String(wave_def.get("wave_id"))])
	elif spawn_entries is Array:
		for wave_spawn_entry in spawn_entries:
			errors.append_array(_validate_wave_spawn_entry(wave_spawn_entry, scenario_id, StringName(wave_def.get("wave_id"))))
	return errors


static func _validate_wave_spawn_entry(wave_spawn_entry: Resource, scenario_id: StringName, wave_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if wave_spawn_entry == null:
		errors.append("BattleScenario %s wave %s contains a null wave spawn entry." % [String(scenario_id), String(wave_id)])
		return errors
	if wave_spawn_entry.get_script() != WaveSpawnEntryRef:
		errors.append("BattleScenario %s wave %s spawn_entries must use wave_spawn_entry.gd." % [String(scenario_id), String(wave_id)])
		return errors
	if float(wave_spawn_entry.get("spawn_time_offset")) < 0.0:
		errors.append("BattleScenario %s wave %s spawn_time_offset must be >= 0." % [String(scenario_id), String(wave_id)])
	var spawn_entry: Resource = wave_spawn_entry.get("spawn_entry")
	errors.append_array(validate_battle_spawn_entry(spawn_entry, scenario_id))
	return errors


static func _validate_field_object_config(field_object_config: Resource, scenario_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if field_object_config == null:
		errors.append("BattleScenario %s contains a null field object config." % String(scenario_id))
		return errors
	if field_object_config.get_script() != FieldObjectConfigRef:
		errors.append("BattleScenario %s field_object_configs must use field_object_config.gd." % String(scenario_id))
		return errors
	var archetype_id := StringName(field_object_config.get("archetype_id"))
	var template_value: Variant = field_object_config.get("object_template_id")
	if archetype_id == StringName():
		errors.append("BattleScenario %s field object config must define archetype_id." % String(scenario_id))
	elif archetype_id != StringName():
		if not SceneRegistry.has_archetype(archetype_id):
			errors.append("BattleScenario %s field object config references unknown archetype_id %s." % [String(scenario_id), String(archetype_id)])
		else:
			var archetype = SceneRegistry.get_archetype(archetype_id)
			if archetype != null:
				for error in validate_combat_archetype(archetype):
					errors.append("BattleScenario %s field object config archetype: %s" % [String(scenario_id), error])
				if StringName(archetype.get("entity_kind")) != &"field_object":
					errors.append("BattleScenario %s field object config archetype %s must have entity_kind field_object." % [String(scenario_id), String(archetype_id)])
	if template_value != null and String(template_value) != "":
		errors.append("BattleScenario %s field object config must not define object_template_id." % String(scenario_id))
	if int(field_object_config.get("lane_id")) < 0:
		errors.append("BattleScenario %s field object config lane_id must be >= 0." % String(scenario_id))
	return errors


static func _validate_param_definition(param_def: Dictionary, scope: String) -> Array[String]:
	var errors: Array[String] = []
	var param_type := String(param_def.get("type", ""))
	if param_type.is_empty():
		errors.append("%s has a param definition without type." % scope)
	elif not _allowed_param_types().has(param_type):
		errors.append("%s has unsupported param type %s." % [scope, param_type])
	if param_type == "resource" and param_def.has("resource_script"):
		var resource_script_path := String(param_def.get("resource_script", "")).strip_edges()
		if resource_script_path.is_empty():
			errors.append("%s has a resource param without resource_script." % scope)
		elif not (_load_resource_script(resource_script_path) is Script):
			errors.append("%s references missing resource_script %s." % [scope, resource_script_path])
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
		"packed_string_array":
			if value is PackedStringArray:
				normalized_value = PackedStringArray(value)
			elif value is Array:
				normalized_value = PackedStringArray(value)
			else:
				errors.append("%s param %s must be PackedStringArray." % [scope, param_name])
				normalized_value = PackedStringArray()
		"resource":
			if value != null and not (value is Resource):
				errors.append("%s param %s must be Resource." % [scope, param_name])
			elif value != null and param_def.has("resource_script"):
				var resource_script_path := String(param_def.get("resource_script", "")).strip_edges()
				var expected_script: Variant = _load_resource_script(resource_script_path)
				if expected_script == null:
					errors.append("%s param %s references missing resource_script %s." % [scope, param_name, resource_script_path])
				elif value.get_script() != expected_script:
					errors.append("%s param %s must use resource script %s." % [scope, param_name, resource_script_path])
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
		"pierce",
	]


static func _allowed_terminal_hit_strategies() -> Array[String]:
	return ["none", "impact_hitbox", "impact_radius"]


static func _allowed_dynamic_target_axes() -> Array[String]:
	return ["x", "y", "xy"]


static func _allowed_param_types() -> Array[String]:
	return ["int", "float", "string", "string_name", "bool", "vector2", "packed_string_array", "resource"]


static func _allowed_trigger_behavior_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in FROZEN_TRIGGER_BEHAVIOR_SPECS.keys():
		keys.append(String(key))
	return keys


static func _trigger_behavior_spec(behavior_key: StringName) -> Dictionary:
	return Dictionary(FROZEN_TRIGGER_BEHAVIOR_SPECS.get(behavior_key, {}))


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


static func _normalize_trigger_event_and_conditions(
	raw_event_name: StringName,
	raw_condition_values: Dictionary,
	trigger_def,
	scope: String
) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var normalized_event_name := raw_event_name
	if normalized_event_name == StringName():
		normalized_event_name = StringName(trigger_def.event_name)
	elif StringName(trigger_def.event_name) != StringName() and normalized_event_name != StringName(trigger_def.event_name):
		errors.append("%s event_name must match TriggerDef event_name." % scope)

	var normalized_conditions: Dictionary = {}
	for param_def in trigger_def.condition_params:
		if not (param_def is Dictionary):
			continue
		var param_name := String(param_def.get("name", ""))
		if param_name.is_empty():
			continue
		if raw_condition_values.has(param_name):
			normalized_conditions[param_name] = _normalize_param_value(
				raw_condition_values[param_name],
				param_def,
				errors,
				scope
			)
		elif param_def.has("default"):
			normalized_conditions[param_name] = param_def["default"]

	if not bool(trigger_def.allow_extra_conditions):
		for key: Variant in raw_condition_values.keys():
			if not normalized_conditions.has(key):
				errors.append("%s has unsupported condition %s." % [scope, str(key)])

	return {
		"errors": errors,
		"event_name": normalized_event_name,
		"condition_values": normalized_conditions,
	}


static func _validate_entity_runtime_params(entity_kind: String, params: Dictionary, scope: String) -> Array[String]:
	var errors: Array[String] = []
	if not (params is Dictionary):
		errors.append("%s must be a Dictionary." % scope)
		return errors
	errors.append_array(_validate_projectile_config_consistency(params, params.get("projectile_template", null), scope))

	var effect_overrides: Dictionary = {}
	if params.has("effect_overrides"):
		if params["effect_overrides"] is Dictionary:
			effect_overrides = params["effect_overrides"].duplicate(true)
		else:
			errors.append("%s.effect_overrides must be a Dictionary." % scope)

	var on_hit_effect_params: Dictionary = {}
	if params.has("on_hit_effect_params"):
		if params["on_hit_effect_params"] is Dictionary:
			on_hit_effect_params = params["on_hit_effect_params"].duplicate(true)
		else:
			errors.append("%s.on_hit_effect_params must be a Dictionary." % scope)
	if effect_overrides is Dictionary:
		for key: Variant in effect_overrides.keys():
			if SPAWN_ENTRY_RESERVED_PARAMS.has(key):
				errors.append("%s.effect_overrides must not override reserved key %s." % [scope, str(key)])
	for key: Variant in params.keys():
		if not ALLOWED_SPAWN_OVERRIDE_KEYS.has(str(key)):
			errors.append("%s has unsupported spawn override key %s." % [scope, str(key)])
	if entity_kind != "plant":
		return errors
	return errors


static func _validate_projectile_config_consistency(params: Dictionary, projectile_template, scope: String) -> Array[String]:
	var errors: Array[String] = []
	if not (params is Dictionary):
		return errors

	var profile: Resource = null
	if params.get("flight_profile", null) is Resource:
		profile = params.get("flight_profile")
	elif projectile_template is ProjectileTemplateRef and projectile_template.flight_profile is Resource:
		profile = projectile_template.flight_profile

	if profile != null:
		for error in validate_projectile_flight_profile(profile):
			errors.append("%s flight_profile: %s" % [scope, error])
		if params.has("movement_mode") and profile.get_script() == ProjectileFlightProfileRef:
			var profile_move_mode := StringName(profile.get("move_mode"))
			var override_move_mode := StringName(params.get("movement_mode", StringName()))
			if override_move_mode != StringName() and override_move_mode != profile_move_mode:
				errors.append("%s movement_mode must match flight_profile.move_mode when both are provided." % scope)

	var resolved_move_mode := StringName(params.get("movement_mode", StringName()))
	if resolved_move_mode == StringName() and profile != null and profile.get_script() == ProjectileFlightProfileRef:
		resolved_move_mode = StringName(profile.get("move_mode"))
	if resolved_move_mode == &"track" and params.has("arc_height"):
		errors.append("%s arc_height is only valid for parabola movement." % scope)
	if resolved_move_mode == &"linear" and params.has("turn_rate"):
		errors.append("%s turn_rate is only valid for track movement." % scope)
	if resolved_move_mode == &"parabola" and params.has("turn_rate"):
		errors.append("%s turn_rate is only valid for track movement." % scope)
	return errors


static func _entity_template_trigger_bindings(entity_template) -> Array:
	if entity_template == null:
		return []
	var trigger_bindings: Variant = entity_template.get("trigger_bindings")
	return trigger_bindings if trigger_bindings is Array else []


static func _resolve_battlefield_preset(scenario: Resource):
	if scenario == null:
		return null
	var battlefield_preset: Variant = scenario.get("battlefield_preset")
	if battlefield_preset != null and battlefield_preset.get_script() == BattlefieldPresetRef:
		return battlefield_preset
	return null


static func _resolve_scenario_board_slot_count(scenario: Resource, battlefield_preset = null) -> int:
	if battlefield_preset != null and int(battlefield_preset.get("board_slot_count")) > 0:
		return int(battlefield_preset.get("board_slot_count"))
	return int(scenario.get("board_slot_count"))


static func _resolve_scenario_board_slot_spacing(scenario: Resource, battlefield_preset = null) -> float:
	if battlefield_preset != null:
		return float(battlefield_preset.get("board_slot_spacing"))
	return float(scenario.get("board_slot_spacing"))


static func _load_resource_script(resource_script_path: String):
	if resource_script_path.is_empty():
		return null
	var loaded := load(resource_script_path)
	return loaded if loaded is Script else null


static func _validate_archetype_compiled_bindings(
	entity_kind: StringName,
	archetype,
	spawn_entry: Resource,
	scope: String
) -> Array[String]:
	var runtime_spec = CombatContentResolverRef.resolve_spawn_entry_runtime_spec(spawn_entry)
	if runtime_spec == null:
		return []
	var compiled_bindings: Variant = runtime_spec.get("compiled_trigger_bindings")
	if compiled_bindings == null or not (compiled_bindings is Array) or Array(compiled_bindings).is_empty():
		return []
	var factory: Variant = EntityFactoryRef.new()
	var merged_params: Dictionary = {}
	if runtime_spec.get("params") is Dictionary:
		merged_params = Dictionary(runtime_spec.params).duplicate(true)
	var projectile_flight_profile: Resource = runtime_spec.get("projectile_flight_profile") if runtime_spec.get("projectile_flight_profile") is Resource else null
	var projectile_template = runtime_spec.get("projectile_template")
	var errors: Array[String] = []
	for trigger_instance in factory.build_runtime_triggers_from_bindings(entity_kind, Array(compiled_bindings), merged_params, projectile_flight_profile, projectile_template):
		var validation: Dictionary = normalize_trigger_instance(trigger_instance)
		if not bool(validation.get("valid", false)):
			for error in PackedStringArray(validation.get("errors", PackedStringArray())):
				errors.append("%s: %s" % [scope, error])
	return errors
