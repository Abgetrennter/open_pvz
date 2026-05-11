extends Node
class_name VisualValidationProbe

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")
const VisualCueDefRef = preload("res://scripts/core/defs/visual_cue_def.gd")

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
	if not ClassDB.class_exists(&"UIThemeProfile"):
		return
	var default_theme: Resource = UIThemeProfile.default()
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
