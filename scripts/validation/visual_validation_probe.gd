extends Node
class_name VisualValidationProbe

const EventDataRef = preload("res://scripts/core/runtime/event_data.gd")
const AssetIndexCatalogRef = preload("res://scripts/core/runtime/asset_index_catalog.gd")
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")
const VisualCueDefRef = preload("res://scripts/core/defs/visual_cue_def.gd")
const UIThemeProfileRef = preload("res://scripts/ui/theme/ui_theme_profile.gd")
const ReanimDataRef = preload("res://scripts/visual/reanim/reanim_data.gd")
const ReanimPlayerRef = preload("res://scripts/visual/reanim/reanim_player.gd")
const ReanimActorRef = preload("res://scripts/visual/reanim/reanim_actor.gd")
const ReanimActorDefRef = preload("res://scripts/visual/reanim/reanim_actor_def.gd")

const PRIVATE_CLASSIC_PACK_ID := &"classic_original_assets"
const REANIM_DATA_SAMPLE_IDS := ["peashooter", "wallnut", "threepeater"]
const REANIM_DATA_ROOT := "res://local_extensions/classic_original_assets/generated/reanim_data"
const REANIM_GOLDEN_REPORT_ROOT := "res://local_extensions/classic_original_assets/generated/reports/reanim_golden"
const REANIM_NATIVE_THREEPEATER_ROOT := "res://local_extensions/classic_original_assets/generated/native/threepeater"
const REANIM_RAW_THREEPEATER_ACTOR := "res://local_extensions/classic_original_assets/generated/raw/threepeater/actor.tscn"
const REANIM_NATIVE_SUNFLOWER_ROOT := "res://local_extensions/classic_original_assets/generated/native/sunflower"
const REANIM_RAW_SUNFLOWER_ACTOR := "res://local_extensions/classic_original_assets/generated/raw/sunflower/actor.tscn"
const REANIM_CHOMPER_SEMANTIC_REPORT := "res://local_extensions/classic_original_assets/generated/reports/semantic/Chomper.semantic_report.json"
const REANIM_NATIVE_MAX_SIZE_RATIO := 0.25
const REANIM_REQUIRED_FEATURE_FLAGS := ["has_text", "has_font", "has_attacher", "has_blend_mode", "has_unknown_fields"]
const CORE_PRIVATE_CLASSIC_PROFILE_IDS := [
	&"classic_original.entity.plant.peashooter.visual",
	&"classic_original.entity.plant.sunflower.visual",
	&"classic_original.entity.plant.threepeater.visual",
	&"classic_original.entity.plant.chomper.visual",
	&"classic_original.entity.plant.squash.visual",
]

var _battle: Node = null
var _emitted: Dictionary = {}
var _guardrail_attempted := false
var _reanim_clock: Dictionary = {}


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
	if scenario_id == &"visual_reanim_data_import_smoke":
		_probe_reanim_data_import()
	if scenario_id == &"visual_reanim_native_runtime_smoke":
		_probe_reanim_native_runtime()
	if scenario_id == &"visual_reanim_sim_clock":
		_probe_reanim_sim_clock()
	if scenario_id == &"visual_reanim_angle_compatibility":
		_probe_reanim_angle_compatibility()
	if scenario_id == &"visual_reanim_renderer_order":
		_probe_reanim_renderer_order()
	if scenario_id == &"visual_reanim_composite_threepeater":
		_probe_reanim_composite_threepeater()
	if scenario_id == &"visual_reanim_blink_overlay":
		_probe_reanim_blink_overlay()
	if scenario_id == &"visual_reanim_chomper_angle":
		_probe_reanim_chomper_angle()
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
	for profile_id_text in _private_classic_profile_ids():
		var profile_id := StringName(profile_id_text)
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

	var bound_count := 0
	for entity in _battle.get_runtime_combat_entities():
		if entity == null or not is_instance_valid(entity):
			continue
		var archetype_id := StringName(entity.get("archetype_id"))
		var expected_profile_id := _classic_profile_for_archetype(archetype_id)
		if expected_profile_id == StringName():
			continue
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

	if bound_count <= 0:
		return

	_emitted[&"private_classic_archetype_bindings"] = true
	_emit_probe(&"private_classic_archetype_bindings", &"passed", {
		"pack_id": PRIVATE_CLASSIC_PACK_ID,
		"bound_count": bound_count,
	})


func _probe_reanim_data_import() -> void:
	if _emitted.has(&"reanim_data_import"):
		return
	if _find_enabled_private_classic_pack().is_empty():
		return
	var checked_clip_count := 0
	for sample_id: String in REANIM_DATA_SAMPLE_IDS:
		var data_path := "%s/%s/reanim_data.tres" % [REANIM_DATA_ROOT, sample_id]
		if not ResourceLoader.exists(data_path):
			return
		var data := ResourceLoader.load(data_path) as ReanimDataRef
		if data == null:
			return
		if data.schema_version != ReanimDataRef.SCHEMA_VERSION:
			return
		if not data.validate().is_empty():
			return
		if data.frame_count <= 0 or data.get_track_count() <= 0:
			return
		for flag: String in REANIM_REQUIRED_FEATURE_FLAGS:
			if not data.feature_flags.has(flag):
				return
		var golden := _load_reanim_golden_report(sample_id)
		if golden.is_empty():
			return
		var golden_source: Dictionary = golden.get("source", {})
		if data.source_hash != String(golden_source.get("sha256", "")):
			return
		var golden_structure: Dictionary = golden.get("actor_structure", {})
		for animation: Dictionary in golden_structure.get("animations", []):
			var clip := data.get_clip(String(animation.get("name", "")))
			if clip.is_empty():
				return
			if int(clip.get("frame_count", -1)) != int(animation.get("frame_count", -2)):
				return
			if data.fps != int(animation.get("fps", -1)):
				return
			checked_clip_count += 1
	if checked_clip_count <= 0:
		return
	_emitted[&"reanim_data_import"] = true
	_emit_probe(&"reanim_data_import", &"passed", {
		"sample_count": REANIM_DATA_SAMPLE_IDS.size(),
		"checked_clip_count": checked_clip_count,
	})


func _load_reanim_golden_report(sample_id: String) -> Dictionary:
	var report_path := "%s/%s.golden_baseline.json" % [REANIM_GOLDEN_REPORT_ROOT, sample_id]
	if not FileAccess.file_exists(report_path):
		return {}
	var file := FileAccess.open(report_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed as Dictionary


func _probe_reanim_native_runtime() -> void:
	if _emitted.has(&"reanim_native_runtime") or _emitted.has(&"reanim_native_runtime_failed"):
		return
	if _find_enabled_private_classic_pack().is_empty():
		return
	var compared_node_count := 0
	for sample_id: String in ["peashooter", "wallnut"]:
		var golden := _load_reanim_golden_report(sample_id)
		if golden.is_empty():
			return
		var player := _create_reanim_player(sample_id)
		if player == null:
			return
		var data: ReanimDataRef = player.get_data()
		# Negative case: unknown clips must fail closed (false + diagnostic).
		if player.play_clip(&"__reanim_probe_missing_clip__"):
			_report_reanim_probe_failure(&"reanim_native_runtime", "unknown clip unexpectedly accepted for %s" % sample_id)
			player.queue_free()
			return
		var sample_sets: Array = golden.get("frame_samples", [])
		for sample_set: Dictionary in sample_sets:
			var clip_name := String(sample_set.get("animation", ""))
			var clip := data.get_clip(clip_name)
			if clip.is_empty() or not player.play_clip(StringName(clip_name), true):
				_report_reanim_probe_failure(&"reanim_native_runtime", "cannot play golden clip %s/%s" % [sample_id, clip_name])
				player.queue_free()
				return
			var clip_start := int(clip.get("start_frame", 0))
			var golden_frames: Array = sample_set.get("frames", [])
			for frame_entry: Dictionary in golden_frames:
				player.sample_at_frame(float(clip_start + int(frame_entry.get("frame", 0))))
				var golden_nodes: Dictionary = frame_entry.get("nodes", {})
				for entry: Dictionary in player.get_draw_snapshot():
					var node_key := _reanim_sanitize_name(String(entry.get("track", "")))
					if not golden_nodes.has(node_key):
						continue
					var golden_node: Dictionary = golden_nodes[node_key]
					if not _reanim_snapshot_matches(entry, golden_node):
						_report_reanim_probe_failure(&"reanim_native_runtime", "snapshot mismatch %s/%s frame %d node %s" % [sample_id, clip_name, int(frame_entry.get("frame", 0)), node_key])
						player.queue_free()
						return
					compared_node_count += 1
		# Negative case: a missing texture must fail setup (false + diagnostic).
		var broken := data.duplicate() as ReanimDataRef
		var broken_paths := broken.image_paths
		if broken_paths.size() > 0:
			broken_paths[0] = "res://__reanim_probe_missing_texture__.png"
			broken.image_paths = broken_paths
			var broken_player: ReanimPlayerRef = ReanimPlayerRef.new()
			add_child(broken_player)
			var broken_accepted := broken_player.setup(broken)
			broken_player.queue_free()
			if broken_accepted:
				_report_reanim_probe_failure(&"reanim_native_runtime", "missing texture unexpectedly accepted for %s" % sample_id)
				player.queue_free()
				return
		player.queue_free()
	if compared_node_count <= 0:
		return
	_emitted[&"reanim_native_runtime"] = true
	_emit_probe(&"reanim_native_runtime", &"passed", {
		"compared_node_count": compared_node_count,
	})


func _probe_reanim_sim_clock() -> void:
	if _emitted.has(&"reanim_sim_clock"):
		return
	if _find_enabled_private_classic_pack().is_empty():
		return
	var stage := int(_reanim_clock.get("stage", 0))
	if stage == 99:
		return
	if stage == 0:
		var new_player := _create_reanim_player("peashooter")
		if new_player == null:
			return
		if not new_player.play_clip(&"idle", true):
			new_player.queue_free()
			_report_reanim_clock_failure("cannot play peashooter idle clip")
			return
		_reanim_clock["player"] = new_player
		_reanim_clock["t0"] = GameState.current_time
		_reanim_clock["p0"] = new_player.get_phase_seconds()
		_reanim_clock["stage"] = 1
		return
	var player := _reanim_clock.get("player", null) as ReanimPlayerRef
	if player == null or not is_instance_valid(player):
		_report_reanim_clock_failure("sim clock player lost")
		return
	if stage == 1:
		var t0 := float(_reanim_clock.get("t0", 0.0))
		var elapsed := GameState.current_time - t0
		if elapsed < 0.2:
			return
		var expected := float(_reanim_clock.get("p0", 0.0)) + elapsed
		if absf(player.get_phase_seconds() - expected) > 0.0001:
			_report_reanim_clock_failure("running phase drift: %f != %f" % [player.get_phase_seconds(), expected])
			return
		GameState.set_simulation_paused(true)
		_reanim_clock["frozen"] = player.get_phase_seconds()
		_reanim_clock["pause_frames"] = 0
		_reanim_clock["stage"] = 2
		return
	if stage == 2:
		var frozen := float(_reanim_clock.get("frozen", 0.0))
		if absf(player.get_phase_seconds() - frozen) > 0.000001:
			GameState.set_simulation_paused(false)
			_report_reanim_clock_failure("paused phase moved: %f != %f" % [player.get_phase_seconds(), frozen])
			return
		var pause_frames := int(_reanim_clock.get("pause_frames", 0)) + 1
		_reanim_clock["pause_frames"] = pause_frames
		if pause_frames < 3:
			return
		GameState.step_simulation_ticks(10)
		var expected := frozen + 10.0 * GameState.fixed_dt
		if absf(player.get_phase_seconds() - expected) > 0.0001:
			GameState.set_simulation_paused(false)
			_report_reanim_clock_failure("manual step phase mismatch: %f != %f" % [player.get_phase_seconds(), expected])
			return
		player.set_visual_speed(2.0)
		if absf(player.get_phase_seconds() - expected) > 0.0001:
			GameState.set_simulation_paused(false)
			_report_reanim_clock_failure("speed change caused phase jump: %f != %f" % [player.get_phase_seconds(), expected])
			return
		_reanim_clock["t2"] = GameState.current_time
		_reanim_clock["p2"] = player.get_phase_seconds()
		GameState.set_simulation_paused(false)
		_reanim_clock["stage"] = 3
		return
	if stage == 3:
		var t2 := float(_reanim_clock.get("t2", 0.0))
		var elapsed := GameState.current_time - t2
		if elapsed < 0.2:
			return
		var expected := float(_reanim_clock.get("p2", 0.0)) + elapsed * 2.0
		if absf(player.get_phase_seconds() - expected) > 0.0001:
			_report_reanim_clock_failure("double speed phase mismatch: %f != %f" % [player.get_phase_seconds(), expected])
			return
		player.queue_free()
		_reanim_clock["stage"] = 99
		_emitted[&"reanim_sim_clock"] = true
		_emit_probe(&"reanim_sim_clock", &"passed", {
			"pause_frames": 3,
			"manual_ticks": 10,
		})


func _probe_reanim_angle_compatibility() -> void:
	if _emitted.has(&"reanim_angle_compatibility") or _emitted.has(&"reanim_angle_compatibility_failed"):
		return
	if _find_enabled_private_classic_pack().is_empty():
		return
	var data := _load_reanim_data("wallnut")
	if data == null:
		return
	var jump_count := 0
	var checked_delta_count := 0
	var jump_threshold := deg_to_rad(45.0)
	for track_index in data.get_track_count():
		if data.track_kinds[track_index] != ReanimDataRef.TRACK_KIND_VISUAL:
			continue
		var has_previous := false
		var previous_rotation := 0.0
		for frame in data.frame_count:
			if data.is_frame_hidden(track_index, frame):
				has_previous = false
				continue
			var frame_rotation := ReanimPlayerRef.build_track_transform(
				data.get_float(track_index, frame, ReanimDataRef.FLOAT_X),
				data.get_float(track_index, frame, ReanimDataRef.FLOAT_Y),
				data.get_float(track_index, frame, ReanimDataRef.FLOAT_KX_DEG),
				data.get_float(track_index, frame, ReanimDataRef.FLOAT_KY_DEG),
				data.get_float(track_index, frame, ReanimDataRef.FLOAT_SX),
				data.get_float(track_index, frame, ReanimDataRef.FLOAT_SY)).get_rotation()
			if has_previous:
				var delta := wrapf(frame_rotation - previous_rotation, -PI, PI)
				checked_delta_count += 1
				if absf(delta) > jump_threshold:
					jump_count += 1
			previous_rotation = frame_rotation
			has_previous = true
	if checked_delta_count <= 0:
		return
	if jump_count > 0:
		_report_reanim_probe_failure(&"reanim_angle_compatibility", "wallnut rotation jumps detected: %d of %d deltas" % [jump_count, checked_delta_count])
		return
	_emitted[&"reanim_angle_compatibility"] = true
	_emit_probe(&"reanim_angle_compatibility", &"passed", {
		"checked_delta_count": checked_delta_count,
	})


func _probe_reanim_renderer_order() -> void:
	if _emitted.has(&"reanim_renderer_order") or _emitted.has(&"reanim_renderer_order_failed"):
		return
	if _find_enabled_private_classic_pack().is_empty():
		return
	var data := _load_reanim_data("peashooter")
	if data == null:
		return
	var expected := PackedStringArray()
	for track_index in data.get_track_count():
		if data.track_kinds[track_index] == ReanimDataRef.TRACK_KIND_VISUAL:
			expected.append(data.track_names[track_index])
	var runs: Array[PackedStringArray] = []
	for _run in 2:
		var player := _create_reanim_player("peashooter")
		if player == null:
			return
		var order_names := PackedStringArray()
		var snapshot := player.get_draw_snapshot()
		for entry_index in snapshot.size():
			var entry: Dictionary = snapshot[entry_index]
			if int(entry.get("order", -1)) != entry_index:
				_report_reanim_probe_failure(&"reanim_renderer_order", "draw order index mismatch at %d" % entry_index)
				player.queue_free()
				return
			order_names.append(String(entry.get("track", "")))
		player.queue_free()
		runs.append(order_names)
	if runs[0] != expected or runs[1] != expected:
		_report_reanim_probe_failure(&"reanim_renderer_order", "draw order deviates from source track order")
		return
	_emitted[&"reanim_renderer_order"] = true
	_emit_probe(&"reanim_renderer_order", &"passed", {
		"track_count": expected.size(),
	})


## T3: composite ThreePeater built from the generated ReanimActorDef. Checks
## the full optional-contract chain, host-track head bindings and anchors
## against the T0 golden wrapper baseline, payload size versus the raw legacy
## actor, and def-level fail-closed negatives.
func _probe_reanim_composite_threepeater() -> void:
	if _emitted.has(&"reanim_composite_threepeater") or _emitted.has(&"reanim_composite_threepeater_failed"):
		return
	if _find_enabled_private_classic_pack().is_empty():
		return
	var golden := _load_reanim_golden_report("threepeater")
	if golden.is_empty():
		return
	var wrapper: Dictionary = golden.get("composite_wrapper", {})
	var golden_anchors: Dictionary = wrapper.get("anchors", {})
	var golden_heads: Array = wrapper.get("head_parts", [])
	if golden_anchors.is_empty() or golden_heads.is_empty():
		return
	var scene_path := "%s/actor.tscn" % REANIM_NATIVE_THREEPEATER_ROOT
	var def_path := "%s/actor_def.tres" % REANIM_NATIVE_THREEPEATER_ROOT
	if not ResourceLoader.exists(scene_path) or not ResourceLoader.exists(def_path):
		return
	var packed := ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		return
	var actor := packed.instantiate() as Node2D
	if actor == null:
		return
	add_child(actor)
	if int(actor.call("get_part_count")) != 4:
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "expected 4 parts, got %d" % int(actor.call("get_part_count")))
		actor.queue_free()
		return
	# Optional-contract chain incl. negative lookups.
	if bool(actor.call("play_state", &"__reanim_probe_missing_state__")):
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "unknown state unexpectedly accepted")
		actor.queue_free()
		return
	if bool(actor.call("play_action", &"__reanim_probe_missing_action__")):
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "unknown action unexpectedly accepted")
		actor.queue_free()
		return
	if actor.call("get_anchor", &"__reanim_probe_missing_anchor__") != null:
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "unknown anchor returned a node")
		actor.queue_free()
		return
	if not bool(actor.call("set_visual_speed", 2.0)) or not bool(actor.call("set_visual_speed", 1.0)):
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "set_visual_speed rejected")
		actor.queue_free()
		return
	if not bool(actor.call("play_action", &"shoot")):
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "play_action shoot rejected")
		actor.queue_free()
		return
	if not bool(actor.call("play_state", &"idle")):
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "play_state idle rejected")
		actor.queue_free()
		return
	# Back at the initial pose (clips re-epoched within this frame), the anchor
	# chain must reproduce the golden wrapper muzzle positions.
	actor.call("refresh_composition")
	for anchor_name: String in ["muzzle", "muzzle1", "muzzle2", "muzzle3"]:
		var golden_entry: Variant = golden_anchors.get(anchor_name, null)
		if not golden_entry is Dictionary:
			_report_reanim_probe_failure(&"reanim_composite_threepeater", "golden anchor missing: %s" % anchor_name)
			actor.queue_free()
			return
		var anchor := actor.call("get_anchor", StringName(anchor_name)) as Node2D
		if anchor == null:
			_report_reanim_probe_failure(&"reanim_composite_threepeater", "anchor missing: %s" % anchor_name)
			actor.queue_free()
			return
		var golden_position: Array = (golden_entry as Dictionary).get("global_position", [0.0, 0.0])
		var expected := Vector2(float(golden_position[0]), float(golden_position[1]))
		if anchor.global_position.distance_to(expected) > 0.05:
			_report_reanim_probe_failure(&"reanim_composite_threepeater", "anchor %s deviates: %s != %s" % [anchor_name, str(anchor.global_position), str(expected)])
			actor.queue_free()
			return
	# Host-track binding: body anim_head1/2/3 base transforms must match the
	# golden wrapper anchor_base_origin values, and the head part players must
	# be drawn after the body part (stable interleaved order).
	var body_player := actor.call("get_part_player", &"body") as ReanimPlayerRef
	if body_player == null:
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "body part player missing")
		actor.queue_free()
		return
	for head_index in golden_heads.size():
		var golden_head: Dictionary = golden_heads[head_index]
		var host_track := String(golden_head.get("host_track", ""))
		var base_origin: Array = golden_head.get("anchor_base_origin", [0.0, 0.0])
		var sampled: Transform2D = body_player.get_track_transform(host_track)
		if sampled.origin.distance_to(Vector2(float(base_origin[0]), float(base_origin[1]))) > 0.05:
			_report_reanim_probe_failure(&"reanim_composite_threepeater", "host base origin deviates for %s: %s" % [host_track, str(sampled.origin)])
			actor.queue_free()
			return
		var head_player := actor.call("get_part_player", StringName("head%d" % int(golden_head.get("id", 0)))) as ReanimPlayerRef
		if head_player == null or head_player.get_index() <= body_player.get_index():
			_report_reanim_probe_failure(&"reanim_composite_threepeater", "head part order invalid for id %d" % int(golden_head.get("id", 0)))
			actor.queue_free()
			return
	# Volume assertion: native payload (data + def + scene) stays within the
	# budget relative to the raw legacy actor.
	var native_bytes := _reanim_file_size("%s/reanim_data.tres" % [REANIM_DATA_ROOT.path_join("threepeater")]) \
		+ _reanim_file_size(def_path) + _reanim_file_size(scene_path)
	var raw_bytes := _reanim_file_size(REANIM_RAW_THREEPEATER_ACTOR)
	if native_bytes <= 0 or raw_bytes <= 0 or float(native_bytes) > float(raw_bytes) * REANIM_NATIVE_MAX_SIZE_RATIO:
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "native payload too large: %d vs raw %d" % [native_bytes, raw_bytes])
		actor.queue_free()
		return
	# Negative case: an invalid host binding in the def must fail closed.
	var def := ResourceLoader.load(def_path) as ReanimActorDefRef
	if def == null:
		_report_reanim_probe_failure(&"reanim_composite_threepeater", "actor def could not be loaded")
		actor.queue_free()
		return
	var broken := def.duplicate(true) as ReanimActorDefRef
	var broken_parts := broken.parts.duplicate(true)
	if broken_parts.size() > 1:
		broken_parts[1]["host_part_id"] = "__reanim_probe_missing_part__"
		broken.parts = broken_parts
		var broken_actor := ReanimActorRef.new()
		add_child(broken_actor)
		var broken_accepted := bool(broken_actor.setup_from_def(broken))
		broken_actor.queue_free()
		if broken_accepted:
			_report_reanim_probe_failure(&"reanim_composite_threepeater", "invalid host binding unexpectedly accepted")
			actor.queue_free()
			return
	actor.queue_free()
	_emitted[&"reanim_composite_threepeater"] = true
	_emit_probe(&"reanim_composite_threepeater", &"passed", {
		"part_count": 4,
		"anchor_count": 4,
		"native_bytes": native_bytes,
		"raw_bytes": raw_bytes,
	})


## Verifies the sunflower blink overlay is expressed purely through existing
## ReanimActorDef parts (slim T5): the blink part stays data-hidden during
## idle (image_frame < 0), becomes visible only while the one-shot blink
## action plays, and the body part never renders the blink track (mask).
func _probe_reanim_blink_overlay() -> void:
	if _emitted.has(&"reanim_blink_overlay") or _emitted.has(&"reanim_blink_overlay_failed"):
		return
	if _find_enabled_private_classic_pack().is_empty():
		return
	var scene_path := "%s/actor.tscn" % REANIM_NATIVE_SUNFLOWER_ROOT
	var def_path := "%s/actor_def.tres" % REANIM_NATIVE_SUNFLOWER_ROOT
	if not ResourceLoader.exists(scene_path) or not ResourceLoader.exists(def_path):
		return
	var packed := ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		return
	var actor := packed.instantiate() as Node2D
	if actor == null:
		return
	add_child(actor)
	if int(actor.call("get_part_count")) != 2:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "expected 2 parts, got %d" % int(actor.call("get_part_count")))
		actor.queue_free()
		return
	var body_player := actor.call("get_part_player", &"body") as ReanimPlayerRef
	var blink_player := actor.call("get_part_player", &"blink") as ReanimPlayerRef
	if body_player == null or blink_player == null:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "body/blink part player missing")
		actor.queue_free()
		return
	# Data prerequisites: blink clip and blink textures come from the source.
	var data := blink_player.get_data()
	if data == null or data.get_clip("blink").is_empty():
		_report_reanim_probe_failure(&"reanim_blink_overlay", "blink clip missing from reanim data")
		actor.queue_free()
		return
	var image_refs := data.image_refs
	if not "IMAGE_REANIM_SUNFLOWER_BLINK1" in image_refs or not "IMAGE_REANIM_SUNFLOWER_BLINK2" in image_refs:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "blink textures missing from image refs")
		actor.queue_free()
		return
	var body_blink_sprite := _find_reanim_track_sprite(body_player, "anim_blink")
	var overlay_sprite := _find_reanim_track_sprite(blink_player, "anim_blink")
	if body_blink_sprite == null or overlay_sprite == null:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "anim_blink sprites missing")
		actor.queue_free()
		return
	# Idle: the overlay is hidden by data (image_frame < 0) and the body copy
	# stays hidden by the visibility mask.
	body_player.sample_now()
	blink_player.sample_now()
	if overlay_sprite.visible or body_blink_sprite.visible:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "blink visible during idle (overlay=%s body=%s)" % [overlay_sprite.visible, body_blink_sprite.visible])
		actor.queue_free()
		return
	# Negative cases: unknown action rejected; no anchors are defined.
	if bool(actor.call("play_action", &"__reanim_probe_missing_action__")):
		_report_reanim_probe_failure(&"reanim_blink_overlay", "unknown action unexpectedly accepted")
		actor.queue_free()
		return
	if actor.call("get_anchor", &"muzzle") != null:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "unexpected anchor exposed")
		actor.queue_free()
		return
	# One-shot blink: overlay becomes visible with a blink texture while the
	# body keeps playing idle undisturbed.
	if not bool(actor.call("play_action", &"blink")):
		_report_reanim_probe_failure(&"reanim_blink_overlay", "play_action blink rejected")
		actor.queue_free()
		return
	if blink_player.get_clip_name() != &"blink" or body_player.get_clip_name() != &"idle":
		_report_reanim_probe_failure(&"reanim_blink_overlay", "unexpected clips after blink: blink=%s body=%s" % [blink_player.get_clip_name(), body_player.get_clip_name()])
		actor.queue_free()
		return
	blink_player.sample_now()
	body_player.sample_now()
	if not overlay_sprite.visible or overlay_sprite.texture == null:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "overlay not visible while blink plays")
		actor.queue_free()
		return
	if body_blink_sprite.visible:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "masked body blink track became visible")
		actor.queue_free()
		return
	# Returning to the idle state hides the overlay again.
	if not bool(actor.call("play_state", &"idle")):
		_report_reanim_probe_failure(&"reanim_blink_overlay", "play_state idle rejected")
		actor.queue_free()
		return
	blink_player.sample_now()
	if overlay_sprite.visible:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "overlay still visible after returning to idle")
		actor.queue_free()
		return
	# Volume budget, consistent with the composite probe.
	var native_bytes := _reanim_file_size("%s/reanim_data.tres" % [REANIM_DATA_ROOT.path_join("sunflower")]) \
		+ _reanim_file_size(def_path) + _reanim_file_size(scene_path)
	var raw_bytes := _reanim_file_size(REANIM_RAW_SUNFLOWER_ACTOR)
	if native_bytes <= 0 or raw_bytes <= 0 or float(native_bytes) > float(raw_bytes) * REANIM_NATIVE_MAX_SIZE_RATIO:
		_report_reanim_probe_failure(&"reanim_blink_overlay", "native payload too large: %d vs raw %d" % [native_bytes, raw_bytes])
		actor.queue_free()
		return
	actor.queue_free()
	_emitted[&"reanim_blink_overlay"] = true
	_emit_probe(&"reanim_blink_overlay", &"passed", {
		"part_count": 2,
		"native_bytes": native_bytes,
		"raw_bytes": raw_bytes,
	})


func _find_reanim_track_sprite(player: ReanimPlayerRef, track_prefix: String) -> Sprite2D:
	for child in player.get_children():
		var sprite := child as Sprite2D
		if sprite != null and String(sprite.name).begins_with(track_prefix):
			return sprite
	return null


## Chomper carries by far the most source angle warnings (kx/ky divergence).
## The native matrix sampling must still produce frame-to-frame and
## intra-frame (interpolated midpoint) rotation continuity, and the source
## warnings must stay visible in the semantic report instead of being muted.
func _probe_reanim_chomper_angle() -> void:
	if _emitted.has(&"reanim_chomper_angle") or _emitted.has(&"reanim_chomper_angle_failed"):
		return
	if _find_enabled_private_classic_pack().is_empty():
		return
	var data := _load_reanim_data("chomper")
	if data == null:
		return
	# Source warnings stay on record (fail if the report went missing or muted).
	var warning_count := _reanim_semantic_angle_warning_count(REANIM_CHOMPER_SEMANTIC_REPORT)
	if warning_count <= 0:
		_report_reanim_probe_failure(&"reanim_chomper_angle", "chomper angle warnings missing from semantic report (count=%d)" % warning_count)
		return
	var player := _create_reanim_player("chomper")
	if player == null:
		return
	add_child(player)
	var jump_count := 0
	var checked_delta_count := 0
	# Chomper's chew spikes legitimately rotate ~50-56 deg per frame in the
	# source (Chomper_spike1-4, frames 39-41), so the jump threshold sits at
	# 90 deg to catch real wrap-around flips only; the midpoint check below is
	# the actual interpolation-artifact detector (midpoint must not overshoot).
	var jump_threshold := deg_to_rad(90.0)
	for track_index in data.get_track_count():
		if data.track_kinds[track_index] != ReanimDataRef.TRACK_KIND_VISUAL:
			continue
		var track_name := data.track_names[track_index]
		var has_previous := false
		var previous_rotation := 0.0
		for frame in data.frame_count:
			if data.is_frame_hidden(track_index, frame):
				has_previous = false
				continue
			var frame_rotation: float = player.get_track_transform(track_name, float(frame)).get_rotation()
			if has_previous:
				# Interpolated midpoint must sit between the neighbouring frames
				# (no wrap-around flip mid-frame) and successive frames must not jump.
				var midpoint_rotation: float = player.get_track_transform(track_name, float(frame) - 0.5).get_rotation()
				var frame_delta := wrapf(frame_rotation - previous_rotation, -PI, PI)
				var midpoint_delta := wrapf(midpoint_rotation - previous_rotation, -PI, PI)
				checked_delta_count += 2
				if absf(frame_delta) > jump_threshold or absf(midpoint_delta) > absf(frame_delta) + 0.001:
					jump_count += 1
			previous_rotation = frame_rotation
			has_previous = true
	player.queue_free()
	if checked_delta_count <= 0:
		return
	if jump_count > 0:
		_report_reanim_probe_failure(&"reanim_chomper_angle", "chomper rotation jumps detected: %d of %d checks" % [jump_count, checked_delta_count])
		return
	_emitted[&"reanim_chomper_angle"] = true
	_emit_probe(&"reanim_chomper_angle", &"passed", {
		"checked_delta_count": checked_delta_count,
		"source_angle_warning_count": warning_count,
	})


func _reanim_semantic_angle_warning_count(report_path: String) -> int:
	var file := FileAccess.open(report_path, FileAccess.READ)
	if file == null:
		return -1
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return -1
	return int((parsed as Dictionary).get("angle_warning_count", -1))


func _reanim_file_size(res_path: String) -> int:
	var file := FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		return -1
	var length := int(file.get_length())
	file.close()
	return length


func _load_reanim_data(sample_id: String) -> ReanimDataRef:
	var data_path := "%s/%s/reanim_data.tres" % [REANIM_DATA_ROOT, sample_id]
	if not ResourceLoader.exists(data_path):
		return null
	return ResourceLoader.load(data_path) as ReanimDataRef


func _create_reanim_player(sample_id: String) -> ReanimPlayerRef:
	var data := _load_reanim_data(sample_id)
	if data == null:
		return null
	var player: ReanimPlayerRef = ReanimPlayerRef.new()
	add_child(player)
	if not player.setup(data):
		player.queue_free()
		return null
	return player


## Mirrors the importer node-name sanitizer so golden node keys line up.
func _reanim_sanitize_name(value: String) -> String:
	var sanitized := value.strip_edges()
	for ch: String in [" ", ".", "/", "\\", ":", ";", ",", "(", ")", "[", "]"]:
		sanitized = sanitized.replace(ch, "_")
	if sanitized == "":
		return "Track"
	return sanitized


## Compares one draw-snapshot entry against a golden baseline node by matrix,
## sidestepping the legacy rotation/skew angle-continuity representation.
func _reanim_snapshot_matches(entry: Dictionary, golden_node: Dictionary) -> bool:
	var golden_visible := bool(golden_node.get("visible", false))
	if bool(entry.get("visible", false)) != golden_visible:
		return false
	if not golden_visible:
		return true
	var golden_texture: Variant = golden_node.get("texture", "")
	var golden_texture_name := String(golden_texture) if golden_texture != null else ""
	if String(entry.get("texture", "")) != golden_texture_name:
		return false
	var golden_position: Array = golden_node.get("position", [0.0, 0.0])
	var golden_scale: Array = golden_node.get("scale", [1.0, 1.0])
	var golden_transform := Transform2D(
		float(golden_node.get("rotation", 0.0)),
		Vector2(float(golden_scale[0]), float(golden_scale[1])),
		float(golden_node.get("skew", 0.0)),
		Vector2(float(golden_position[0]), float(golden_position[1])))
	var entry_transform: Transform2D = entry.get("transform", Transform2D())
	if entry_transform.x.distance_to(golden_transform.x) > 0.01:
		return false
	if entry_transform.y.distance_to(golden_transform.y) > 0.01:
		return false
	if entry_transform.origin.distance_to(golden_transform.origin) > 0.05:
		return false
	var golden_modulate: Array = golden_node.get("self_modulate", [1.0, 1.0, 1.0, 1.0])
	if absf(float(entry.get("alpha", 1.0)) - float(golden_modulate[3])) > 0.01:
		return false
	return true


func _report_reanim_probe_failure(probe: StringName, message: String) -> void:
	var failed_key := StringName("%s_failed" % String(probe))
	if _emitted.has(failed_key):
		return
	_emitted[failed_key] = true
	if typeof(DebugService) != TYPE_NIL and DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(&"reanim_runtime", "%s probe failed: %s" % [String(probe), message], &"error")


func _report_reanim_clock_failure(message: String) -> void:
	var player := _reanim_clock.get("player", null) as ReanimPlayerRef
	if player != null and is_instance_valid(player):
		player.queue_free()
	_reanim_clock["stage"] = 99
	if typeof(DebugService) != TYPE_NIL and DebugService.has_method("record_protocol_issue"):
		DebugService.record_protocol_issue(&"reanim_runtime", "reanim_sim_clock probe failed: %s" % message, &"error")


func _find_enabled_private_classic_pack() -> Dictionary:
	for pack in ExtensionPackCatalogRef.list_enabled_packs(&"visual_profiles"):
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_CLASSIC_PACK_ID:
			return pack
	return {}


func _private_classic_profile_ids() -> PackedStringArray:
	var ids_by_text := {}
	for profile_id in CORE_PRIVATE_CLASSIC_PROFILE_IDS:
		ids_by_text[String(profile_id)] = true
	for asset: Dictionary in AssetIndexCatalogRef.list_assets(&"visual_profile"):
		if StringName(asset.get("pack_id", StringName())) != PRIVATE_CLASSIC_PACK_ID:
			continue
		var profile_id := StringName(asset.get("id", StringName()))
		if profile_id != StringName():
			ids_by_text[String(profile_id)] = true
	var ids := PackedStringArray()
	for id_text in ids_by_text.keys():
		ids.append(String(id_text))
	ids.sort()
	return ids


func _classic_profile_for_archetype(archetype_id: StringName) -> StringName:
	if archetype_id == StringName():
		return StringName()
	var scene_registry := get_node_or_null("/root/SceneRegistry")
	if scene_registry == null or not scene_registry.has_method("get_archetype"):
		return StringName()
	var archetype := scene_registry.call("get_archetype", archetype_id) as Resource
	if archetype == null:
		return StringName()
	var profile_id := StringName(archetype.get("visual_profile_id"))
	if not _is_private_classic_profile_id(profile_id):
		return StringName()
	return profile_id


func _is_private_classic_profile_id(profile_id: StringName) -> bool:
	return String(profile_id).begins_with("classic_original.entity.plant.") and String(profile_id).ends_with(".visual")


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
