extends Node
class_name VisualValidationProbe

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")
const VisualCueDefRef = preload("res://scripts/core/defs/visual_cue_def.gd")
const UIThemeProfileRef = preload("res://scripts/ui/theme/ui_theme_profile.gd")

const PRIVATE_CLASSIC_PACK_ID := &"classic_original_assets"
const PRIVATE_CLASSIC_PROFILE_IDS := [
	&"classic_original.entity.plant.peashooter.visual",
	&"classic_original.entity.plant.sunflower.visual",
	&"classic_original.entity.plant.threepeater.visual",
	&"classic_original.entity.plant.chomper.visual",
	&"classic_original.entity.plant.squash.visual",
]
const PRIVATE_CLASSIC_ARCHETYPE_TO_PROFILE := {
	&"archetype_original_peashooter": &"classic_original.entity.plant.peashooter.visual",
	&"archetype_original_sunflower": &"classic_original.entity.plant.sunflower.visual",
	&"archetype_original_threepeater": &"classic_original.entity.plant.threepeater.visual",
	&"archetype_original_chomper": &"classic_original.entity.plant.chomper.visual",
	&"archetype_original_squash": &"classic_original.entity.plant.squash.visual",
}

var _battle: Node = null
var _emitted: Dictionary = {}
var _guardrail_attempted := false


func setup(battle: Node) -> void:
	_battle = battle


func _process(_delta: float) -> void:
	if _battle == null or not is_instance_valid(_battle):
		return
	var active_scenario = _battle.resolve_scenario()
	if active_scenario == null:
		return
	var scenario_id := StringName(active_scenario.scenario_id)
	var sid := String(scenario_id)
	if not sid.begins_with("visual_") and not sid.begins_with("ui_theme_"):
		return

	_probe_registries()
	_probe_extension_register_kinds()
	if scenario_id == &"visual_private_classic_asset_pack_smoke":
		_probe_private_classic_asset_pack()
	if scenario_id == &"visual_private_classic_archetype_binding_smoke":
		_probe_private_classic_archetype_bindings()
	_probe_stage_layers()
	_probe_visual_log()
	_probe_ui_theme()
	if scenario_id == &"visual_slot_guardrail":
		_probe_guardrails()


func _probe_registries() -> void:
	if _emitted.has(&"registry"):
		return
	var passed := VisualCueRegistry.has(&"core.projectile_hit_splat") \
		and VisualFxRegistry.has(&"core.hit_splat") \
		and AudioCueRegistry.has(&"core.silent") \
		and VisualProfileRegistry.has(&"core.placeholder_plant")
	if not passed:
		return
	_emitted[&"registry"] = true
	_emit_probe(&"registry", &"passed")


func _probe_extension_register_kinds() -> void:
	if _emitted.has(&"extension_register_kinds"):
		return
	var allowed_register_kinds: Dictionary = ExtensionPackCatalogRef.ALLOWED_REGISTER_KINDS
	var required_kinds := PackedStringArray([
		"visual_cues",
		"visual_fx",
		"audio_cues",
		"visual_profiles",
	])
	for register_kind: String in required_kinds:
		if not allowed_register_kinds.has(StringName(register_kind)):
			return
	_emitted[&"extension_register_kinds"] = true
	_emit_probe(&"extension_register_kinds", &"passed")


func _probe_private_classic_asset_pack() -> void:
	if _emitted.has(&"private_classic_asset_pack"):
		return
	var enabled_pack := _find_enabled_private_classic_pack()
	if enabled_pack.is_empty():
		return
	var loaded_count := 0
	for profile_id in PRIVATE_CLASSIC_PROFILE_IDS:
		if not VisualProfileRegistry.has(profile_id):
			return
		var profile := VisualProfileRegistry.get_def(profile_id)
		if profile == null or profile.get("actor_scene") == null:
			return
		var asset_registry := _get_asset_registry()
		if asset_registry == null:
			return
		if not bool(asset_registry.call("has_asset", profile_id, &"visual_profile")):
			return
		var asset_profile := asset_registry.call("resolve_visual_profile", profile_id) as Resource
		if asset_profile == null or asset_profile.get("actor_scene") == null:
			return
		loaded_count += 1
	_emitted[&"private_classic_asset_pack"] = true
	_emit_probe(&"private_classic_assets", &"passed", {
		"pack_id": PRIVATE_CLASSIC_PACK_ID,
		"profile_count": loaded_count,
	})


func _probe_private_classic_archetype_bindings() -> void:
	if _emitted.has(&"private_classic_archetype_bindings"):
		return
	var enabled_pack := _find_enabled_private_classic_pack()
	if enabled_pack.is_empty():
		return

	var found_archetypes: Dictionary = {}
	var bound_count := 0
	for entity in _battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		var archetype_id := StringName(entity.get("archetype_id"))
		if not PRIVATE_CLASSIC_ARCHETYPE_TO_PROFILE.has(archetype_id):
			continue
		found_archetypes[archetype_id] = true
		var expected_profile_id: StringName = PRIVATE_CLASSIC_ARCHETYPE_TO_PROFILE[archetype_id]
		var visual_actor: Node = entity.get_node_or_null("VisualActorComponent")
		if visual_actor == null:
			return
		if not VisualProfileRegistry.has(expected_profile_id):
			return
		if not visual_actor.has_method("get_actor_root"):
			return
		if visual_actor.call("get_actor_root") == null:
			return
		if not visual_actor.has_method("get_profile_source"):
			return
		var profile_source: Dictionary = visual_actor.call("get_profile_source")
		if StringName(profile_source.get("pack_id", StringName())) != PRIVATE_CLASSIC_PACK_ID:
			return
		if StringName(profile_source.get("id", StringName())) != expected_profile_id:
			return
		bound_count += 1

	for archetype_id in PRIVATE_CLASSIC_ARCHETYPE_TO_PROFILE.keys():
		if not found_archetypes.has(archetype_id):
			return

	_emitted[&"private_classic_archetype_bindings"] = true
	_emit_probe(&"private_classic_archetype_bindings", &"passed", {
		"pack_id": PRIVATE_CLASSIC_PACK_ID,
		"bound_count": bound_count,
	})


func _find_enabled_private_classic_pack() -> Dictionary:
	for pack in ExtensionPackCatalogRef.list_enabled_packs(&"visual_profiles"):
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_CLASSIC_PACK_ID:
			return pack
	return {}


func _get_asset_registry() -> Node:
	return get_node_or_null("/root/AssetRegistry")


func _probe_stage_layers() -> void:
	if _emitted.has(&"stage_layers"):
		return
	if _battle.get_node_or_null("BattleVisualRoot") == null:
		return
	var required_paths := PackedStringArray([
		"BattleVisualRoot/GroundLayer",
		"BattleVisualRoot/ShadowLayer",
		"BattleVisualRoot/ProjectileLayer",
		"BattleVisualRoot/WorldFxLayer",
		"BattleVisualRoot/ScreenFxLayer",
		"BattleVisualRoot/UiLayer",
	])
	for path: String in required_paths:
		if _battle.get_node_or_null(NodePath(path)) == null:
			return
	_emitted[&"stage_layers"] = true
	_emit_probe(&"stage_layers", &"passed")


func _probe_visual_log() -> void:
	for entry: Dictionary in DebugService.visual_log:
		var cue_id := StringName(entry.get("cue_id", StringName()))
		var action_type := StringName(entry.get("action_type", StringName()))
		if cue_id == StringName() or action_type == StringName():
			continue
		var key := "visual_log:%s:%s" % [String(cue_id), String(action_type)]
		if _emitted.has(key):
			continue
		_emitted[key] = true
		_emit_probe(&"visual_log", &"passed", {
			"cue_id": cue_id,
			"action_type": action_type,
			"action_result": StringName(entry.get("result", StringName())),
		})


func _probe_guardrails() -> void:
	if _guardrail_attempted:
		return
	_guardrail_attempted = true

	var core_override = VisualCueDefRef.new()
	core_override.id = &"core.visual_guardrail_override"
	core_override.listen_event = &"projectile.hit"
	VisualCueRegistry.register_def(core_override, _extension_source("core_override"))

	var duplicate_a = VisualCueDefRef.new()
	duplicate_a.id = &"extension.visual_guardrail_duplicate"
	duplicate_a.listen_event = &"projectile.hit"
	VisualCueRegistry.register_def(duplicate_a, _extension_source("duplicate_a"))

	var duplicate_b = VisualCueDefRef.new()
	duplicate_b.id = &"extension.visual_guardrail_duplicate"
	duplicate_b.listen_event = &"projectile.hit"
	VisualCueRegistry.register_def(duplicate_b, _extension_source("duplicate_b"))

	_emit_probe(&"guardrail", &"attempted")


func _extension_source(path_suffix: String) -> Dictionary:
	return {
		"kind": &"extension",
		"extension": true,
		"pack_id": &"visual_guardrail_probe",
		"path": "res://scripts/validation/visual_validation_probe.gd:%s" % path_suffix,
		"trust_level": &"data_only",
	}


func _probe_ui_theme() -> void:
	if _emitted.has(&"ui_theme_default"):
		return
	var default_theme: Resource = UIThemeProfileRef.default()
	if default_theme == null:
		return
	if default_theme.theme_id != &"default":
		return
	# Verify a concrete color field has a non-zero value (sanity check)
	if default_theme.victory_text_color.a <= 0.0:
		return
	_emitted[&"ui_theme_default"] = true
	_emit_probe(&"theme_default_loaded", &"passed")


func _emit_probe(probe: StringName, result: StringName, extra_core: Dictionary = {}) -> void:
	var event_data: Variant = EventDataRef.create(null, null, null, PackedStringArray(["visual", "validation"]))
	event_data.core["probe"] = probe
	event_data.core["result"] = result
	for key: Variant in extra_core.keys():
		event_data.core[key] = extra_core[key]
	EventBus.push_event(&"visual.validation_probe", event_data)
