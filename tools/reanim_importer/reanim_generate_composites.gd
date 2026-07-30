extends SceneTree

const VisualProfileDefRef = preload("res://scripts/core/defs/visual_profile_def.gd")
const CompositeActorScript = preload("res://scripts/validation/reanim_manifest_composite_actor.gd")
const ReanimDataRef = preload("res://scripts/visual/reanim/reanim_data.gd")
const ReanimActorDefRef = preload("res://scripts/visual/reanim/reanim_actor_def.gd")
const ReanimActorScript = preload("res://scripts/visual/reanim/reanim_actor.gd")

var _args: Dictionary = {}


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	_args = _parse_args(OS.get_cmdline_user_args())
	var manifest_path := String(_args.get("manifest", "res://tools/reanim_importer/reanim_visual_manifest.json"))
	if not FileAccess.file_exists(manifest_path):
		push_error("Manifest not found: %s" % manifest_path)
		return 2
	var manifest := _load_json(manifest_path)
	if manifest.is_empty():
		return 3

	var only_id := String(_args.get("only", ""))
	var native_only := String(_args.get("native-only", "false")) == "true"
	var generated: Array[Dictionary] = []
	var native_failures := 0
	for entry in manifest.get("entries", []):
		if not entry is Dictionary:
			continue
		if only_id != "" and String((entry as Dictionary).get("id", "")) != only_id:
			continue
		if not native_only:
			var result := _generate_entry(entry)
			generated.append(result)
			if not bool(result.get("ok", false)):
				push_warning("Composite generation failed for %s: %s" % [String(result.get("id", "")), String(result.get("error", ""))])
		if (entry as Dictionary).has("native"):
			var native_result := _generate_native_entry(entry)
			if not bool(native_result.get("ok", false)):
				native_failures += 1
				push_warning("Native def generation failed for %s: %s" % [String(native_result.get("id", "")), String(native_result.get("error", ""))])
			else:
				print("Generated native reanim def for %s -> %s" % [String(native_result.get("id", "")), String(native_result.get("actor_scene", ""))])
	# Rebuilding the asset index from a filtered entry set would drop managed
	# entries, so it only runs on full legacy generation passes.
	if not native_only and only_id == "":
		_save_asset_index_if_requested(manifest, generated)

	print("Generated %d manifest composite entries." % generated.size())
	return 4 if native_failures > 0 else 0


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var i := 0
	while i < raw_args.size():
		var token := String(raw_args[i])
		if token.begins_with("--"):
			var key := token.substr(2)
			if i + 1 < raw_args.size() and not String(raw_args[i + 1]).begins_with("--"):
				result[key] = String(raw_args[i + 1])
				i += 2
			else:
				result[key] = "true"
				i += 1
		else:
			i += 1
	return result


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Manifest is not a JSON object: %s" % path)
		return {}
	return parsed


func _generate_entry(entry: Dictionary) -> Dictionary:
	var id := String(entry.get("id", ""))
	var out_dir := _normalize_res_dir(String(entry.get("out_dir", "")))
	var actor_path := _normalize_res_path(String(entry.get("actor_scene_out_path", "")))
	if actor_path == "":
		if out_dir == "":
			return {"id": id, "ok": false, "error": "missing id/out_dir or actor_scene_out_path"}
		actor_path = out_dir.path_join("actor.tscn")
	var profile_path := _normalize_res_path(String(entry.get("profile_out_path", "")))
	if profile_path == "":
		if out_dir == "":
			return {"id": id, "ok": false, "error": "missing profile output path"}
		profile_path = out_dir.path_join("visual_profile.tres")
	var report_path := _normalize_res_path(String(entry.get("report_out_path", "")))
	if report_path == "":
		if out_dir == "":
			report_path = actor_path.get_base_dir().path_join("composite_report.json")
		else:
			report_path = out_dir.path_join("composite_report.json")
	if id == "":
		return {"id": id, "ok": false, "error": "missing id"}
	if not ResourceLoader.exists(String(entry.get("raw_actor_scene", ""))):
		return {"id": id, "ok": false, "error": "raw actor scene missing"}

	var actor_dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(actor_path.get_base_dir()))
	if actor_dir_result != OK:
		return {"id": id, "ok": false, "error": "could not create actor output dir"}
	var profile_dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profile_path.get_base_dir()))
	if profile_dir_result != OK:
		return {"id": id, "ok": false, "error": "could not create profile output dir"}
	var report_dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	if report_dir_result != OK:
		return {"id": id, "ok": false, "error": "could not create report output dir"}

	var actor := _build_actor(entry)
	var actor_save_result := ResourceSaver.save(actor, actor_path)
	if actor_save_result != OK:
		return {"id": id, "ok": false, "error": "could not save actor"}

	var profile_save_result := _save_profile(entry, actor_path, profile_path)
	if profile_save_result != OK:
		return {"id": id, "ok": false, "error": "could not save profile"}

	var report := {
		"id": id,
		"ok": true,
		"actor_scene": actor_path,
		"visual_profile": profile_path,
		"raw_actor_scene": String(entry.get("raw_actor_scene", "")),
		"state_animation_map": entry.get("state_animation_map", {}),
		"action_animation_map": entry.get("action_animation_map", {}),
		"texture_override_sets": entry.get("texture_override_sets", {}),
		"suppressed_tracks": entry.get("suppressed_tracks", []),
		"overlay_bindings": entry.get("overlay_bindings", []),
	}
	_save_json(report_path, report)
	report["profile_id"] = String(entry.get("profile_id", "local.original.%s.composite" % id))
	report["asset_index_entry"] = _build_asset_index_entry(entry, actor_path, profile_path, report_path)
	return report


func _build_actor(entry: Dictionary) -> PackedScene:
	var root := Node2D.new()
	var actor_script_path := _normalize_res_path(String(entry.get("actor_script", "")))
	if actor_script_path != "":
		root.name = String(entry.get("actor_node_name", "ReanimCustomComposite"))
		var actor_script := ResourceLoader.load(actor_script_path) as Script
		if actor_script == null:
			push_warning("Custom actor script could not be loaded, falling back to manifest composite: %s" % actor_script_path)
			root.set_script(CompositeActorScript)
			_apply_manifest_composite_properties(root, entry)
		else:
			root.set_script(actor_script)
			_apply_actor_properties(root, entry.get("actor_properties", {}))
	else:
		root.name = String(entry.get("actor_node_name", "ReanimManifestComposite"))
		root.set_script(CompositeActorScript)
		_apply_manifest_composite_properties(root, entry)

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		push_error("Failed to pack generated manifest composite actor.")
	root.queue_free()
	return packed


func _apply_manifest_composite_properties(root: Node2D, entry: Dictionary) -> void:
	root.set("raw_actor_scene_path", String(entry.get("raw_actor_scene", "")))
	root.set("actor_anchor_offset", _to_vector2(entry.get("actor_anchor_offset", [0.0, 0.0])))
	root.set("actor_scale_value", float(entry.get("actor_scale_value", 1.0)))
	root.set("initial_state", StringName(entry.get("initial_state", "idle")))
	root.set("state_animation_map", _string_dict_to_string_name_dict(entry.get("state_animation_map", {})))
	root.set("action_animation_map", _normalize_action_map(entry.get("action_animation_map", {})))
	root.set("animation_rate_map", _string_dict_to_string_name_dict(entry.get("animation_rate_map", {})))
	root.set("texture_override_sets", _normalize_texture_override_sets(entry.get("texture_override_sets", {})))
	root.set("suppressed_tracks", _to_string_array(entry.get("suppressed_tracks", [])))
	root.set("anchors", entry.get("anchors", {}))


func _apply_actor_properties(root: Node2D, value: Variant) -> void:
	if not value is Dictionary:
		return
	for key in (value as Dictionary).keys():
		root.set(String(key), _normalize_actor_property_value((value as Dictionary)[key]))


func _save_profile(entry: Dictionary, actor_path: String, profile_path: String) -> int:
	var profile = VisualProfileDefRef.new()
	profile.id = StringName(entry.get("profile_id", "local.original.%s.composite" % String(entry.get("id", "unknown"))))
	profile.actor_scene = ResourceLoader.load(actor_path) as PackedScene
	profile.state_animation_map = _string_dict_to_string_name_dict(entry.get("state_animation_map", {}))
	profile.action_animation_map = _profile_action_map(entry.get("action_animation_map", {}))
	profile.animation_map = _string_dict_to_string_name_dict(entry.get("animation_map", {}))
	profile.ground_offset = _to_vector2(entry.get("ground_offset", [0.0, 0.0]))
	profile.z_policy = {"layer": &"plant"}
	profile.tags = PackedStringArray(_to_string_array(entry.get("profile_tags", [])))
	return ResourceSaver.save(profile, profile_path)


func _profile_action_map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for key in (value as Dictionary).keys():
		var raw: Variant = value[key]
		if raw is Dictionary:
			result[StringName(String(key))] = StringName(String((raw as Dictionary).get("animation", "")))
		else:
			result[StringName(String(key))] = StringName(String(raw))
	return result


func _string_dict_to_string_name_dict(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for key in (value as Dictionary).keys():
		result[StringName(String(key))] = StringName(String((value as Dictionary)[key]))
	return result


func _normalize_action_map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for key in (value as Dictionary).keys():
		var raw: Variant = (value as Dictionary)[key]
		if raw is Dictionary:
			var raw_dict := raw as Dictionary
			result[StringName(String(key))] = {
				"animation": StringName(String(raw_dict.get("animation", ""))),
				"next_state": StringName(String(raw_dict.get("next_state", "idle"))),
				"rate": float(raw_dict.get("rate", 1.0)),
				"loop": bool(raw_dict.get("loop", false)),
			}
		else:
			result[StringName(String(key))] = StringName(String(raw))
	return result


func _normalize_texture_override_sets(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for key in (value as Dictionary).keys():
		result[StringName(String(key))] = (value as Dictionary)[key]
	return result


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result


func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO


func _normalize_actor_property_value(value: Variant) -> Variant:
	if value is Array and value.size() == 2 and _is_number_like(value[0]) and _is_number_like(value[1]):
		return _to_vector2(value)
	return value


func _is_number_like(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _build_asset_index_entry(entry: Dictionary, actor_path: String, profile_path: String, report_path: String) -> Dictionary:
	var generated := {
		"raw_actor_scene": String(entry.get("raw_actor_scene", "")),
		"composite_report": report_path,
	}
	if String(entry.get("import_report", "")) != "":
		generated["import_report"] = String(entry.get("import_report", ""))

	var source := {}
	if String(entry.get("source_reanim", "")) != "":
		source["reanim"] = String(entry.get("source_reanim", ""))
	if String(entry.get("source_resources", "")) != "":
		source["resources"] = String(entry.get("source_resources", ""))

	return {
		"kind": "visual_profile",
		"path": profile_path,
		"profile": profile_path,
		"actor_scene": actor_path,
		"source": source,
		"generated": generated,
		"semantic": {
			"states": entry.get("state_animation_map", {}),
			"actions": entry.get("action_animation_map", {}),
			"animation_aliases": entry.get("animation_map", {}),
			"overlays": entry.get("overlay_bindings", []),
			"suppressed_tracks": entry.get("suppressed_tracks", []),
		},
	}


func _save_asset_index_if_requested(manifest: Dictionary, generated: Array[Dictionary]) -> void:
	var asset_index_path := _normalize_res_path(String(manifest.get("asset_index_out_path", "")))
	if asset_index_path.is_empty():
		return
	var pack_root := _normalize_res_dir(String(manifest.get("asset_index_pack_root", asset_index_path.get_base_dir())))
	var existing_index := {}
	if FileAccess.file_exists(asset_index_path):
		existing_index = _load_json(asset_index_path)
	var assets := _preserve_unmanaged_assets(existing_index)
	var visual_profiles := {}
	for result in generated:
		if not bool(result.get("ok", false)):
			continue
		var profile_id := String(result.get("profile_id", ""))
		if profile_id.is_empty():
			continue
		var asset_entry: Dictionary = Dictionary(result.get("asset_index_entry", {})).duplicate(true)
		asset_entry = _make_asset_entry_paths_relative(asset_entry, pack_root)
		assets[profile_id] = asset_entry
		visual_profiles[profile_id] = String(asset_entry.get("path", ""))
	var index := {
		"version": 1,
		"format": "openpvz.asset_index.v1",
		"pack_id": String(manifest.get("pack_id", "")),
		"generated_by": "tools/reanim_importer/reanim_generate_composites.gd",
		"assets": assets,
		"visual_profiles": visual_profiles,
	}
	var output_dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_index_path.get_base_dir()))
	if output_dir_result != OK:
		push_warning("Could not create asset index output dir: %s" % asset_index_path.get_base_dir())
		return
	_save_json(asset_index_path, index)


func _preserve_unmanaged_assets(existing_index: Dictionary) -> Dictionary:
	var preserved := {}
	var existing_assets: Variant = existing_index.get("assets", {})
	if not existing_assets is Dictionary:
		return preserved
	var managed_profile_ids: Variant = existing_index.get("visual_profiles", {})
	if not managed_profile_ids is Dictionary:
		managed_profile_ids = {}
	for asset_id in (existing_assets as Dictionary).keys():
		if (managed_profile_ids as Dictionary).has(asset_id):
			continue
		var asset_entry: Variant = (existing_assets as Dictionary)[asset_id]
		preserved[asset_id] = asset_entry.duplicate(true) if asset_entry is Dictionary else asset_entry
	return preserved


func _make_asset_entry_paths_relative(entry: Dictionary, pack_root: String) -> Dictionary:
	for key in ["path", "profile", "actor_scene"]:
		if entry.has(key):
			entry[key] = _relative_to_pack_root(String(entry[key]), pack_root)
	if entry.get("source", {}) is Dictionary:
		var source: Dictionary = entry["source"]
		for key in source.keys():
			source[key] = _relative_to_pack_root(String(source[key]), pack_root)
	if entry.get("generated", {}) is Dictionary:
		var generated: Dictionary = entry["generated"]
		for key in generated.keys():
			generated[key] = _relative_to_pack_root(String(generated[key]), pack_root)
	return entry


func _relative_to_pack_root(path: String, pack_root: String) -> String:
	if path.is_empty() or pack_root.is_empty():
		return path
	var normalized_path := path.replace("\\", "/")
	var normalized_root := pack_root.replace("\\", "/")
	if normalized_path.begins_with("%s/" % normalized_root):
		return normalized_path.substr(normalized_root.length() + 1)
	return normalized_path


func _normalize_res_dir(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


func _normalize_res_path(path: String) -> String:
	return path.replace("\\", "/")


func _save_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write JSON report: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


## Builds a ReanimActorDef resource plus a lightweight actor scene (ReanimActor
## root referencing the def) from the entry's "native" block. Fails closed on
## any invalid or missing data; the runtime only ever reads the .tres output.
func _generate_native_entry(entry: Dictionary) -> Dictionary:
	var id := String(entry.get("id", ""))
	var native: Dictionary = entry.get("native", {})
	var def_path := _normalize_res_path(String(native.get("def_out_path", "")))
	var actor_path := _normalize_res_path(String(native.get("actor_scene_out_path", "")))
	var report_path := _normalize_res_path(String(native.get("report_out_path", "")))
	if id == "" or def_path == "" or actor_path == "":
		return {"id": id, "ok": false, "error": "missing id/def_out_path/actor_scene_out_path"}

	var def = ReanimActorDefRef.new()
	def.def_id = StringName(String(native.get("def_id", id)))
	def.initial_state = StringName(String(native.get("initial_state", "")))
	def.root_offset = _to_vector2(native.get("root_offset", entry.get("actor_anchor_offset", [0.0, 0.0])))
	def.root_scale = float(native.get("root_scale", 1.0))

	var parts: Array[Dictionary] = []
	for part_value in native.get("parts", []):
		if not part_value is Dictionary:
			return {"id": id, "ok": false, "error": "native part is not a Dictionary"}
		var part_source := part_value as Dictionary
		var data_path := _normalize_res_path(String(part_source.get("reanim_data", "")))
		if not ResourceLoader.exists(data_path):
			return {"id": id, "ok": false, "error": "reanim_data missing: %s" % data_path}
		var data := ResourceLoader.load(data_path) as ReanimDataRef
		if data == null:
			return {"id": id, "ok": false, "error": "reanim_data not a ReanimData: %s" % data_path}
		parts.append({
			"id": String(part_source.get("id", "")),
			"reanim_data": data,
			"initial_clip": String(part_source.get("initial_clip", "")),
			"loop": bool(part_source.get("loop", true)),
			"host_part_id": String(part_source.get("host_part_id", "")),
			"host_track": String(part_source.get("host_track", "")),
			"render_order": int(part_source.get("render_order", 0)),
			"track_visibility": _normalize_track_visibility(part_source.get("track_visibility", {})),
			"image_override": part_source.get("image_override", {}) if part_source.get("image_override", {}) is Dictionary else {},
		})
	def.parts = parts
	def.states = _normalize_native_clip_maps(native.get("states", {}))
	def.actions = _normalize_native_clip_maps(native.get("actions", {}))
	def.anchors = _normalize_native_anchors(native.get("anchors", {}))

	var problems: PackedStringArray = def.validate()
	if not problems.is_empty():
		return {"id": id, "ok": false, "error": "invalid native def: %s" % ", ".join(problems)}

	for output_path in [def_path, actor_path]:
		var dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(output_path).get_base_dir()))
		if dir_result != OK:
			return {"id": id, "ok": false, "error": "could not create native output dir"}
	if ResourceSaver.save(def, def_path) != OK:
		return {"id": id, "ok": false, "error": "could not save actor def"}
	# Adopt the saved path so the packed scene references the def as an
	# ExtResource without re-loading it (a cache-replacing load would trigger
	# a script reload cascade that breaks in headless tool mode).
	def.take_over_path(def_path)

	var root := Node2D.new()
	root.name = String(native.get("actor_node_name", "ReanimNativeActor"))
	root.set_script(ReanimActorScript)
	root.set("actor_def", def)
	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	root.queue_free()
	if pack_result != OK:
		return {"id": id, "ok": false, "error": "could not pack native actor scene"}
	if ResourceSaver.save(packed, actor_path) != OK:
		return {"id": id, "ok": false, "error": "could not save native actor scene"}

	if report_path != "":
		var report := {
			"id": id,
			"ok": true,
			"actor_def": def_path,
			"actor_scene": actor_path,
			"part_count": parts.size(),
			"def_bytes": _file_size(def_path),
			"actor_scene_bytes": _file_size(actor_path),
		}
		var report_dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
		if report_dir_result == OK:
			_save_json(report_path, report)
	return {"id": id, "ok": true, "actor_def": def_path, "actor_scene": actor_path}


func _normalize_track_visibility(value: Variant) -> Dictionary:
	if not value is Dictionary or (value as Dictionary).is_empty():
		return {}
	var source := value as Dictionary
	var patterns: Array = []
	for pattern in source.get("patterns", []):
		patterns.append(String(pattern))
	return {"mode": String(source.get("mode", "")), "patterns": patterns}


func _normalize_native_clip_maps(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for map_id in (value as Dictionary).keys():
		var mapping: Variant = (value as Dictionary)[map_id]
		if not mapping is Dictionary:
			continue
		var clips: Dictionary = {}
		for part_id in (mapping as Dictionary).keys():
			clips[String(part_id)] = String((mapping as Dictionary)[part_id])
		result[String(map_id)] = clips
	return result


func _normalize_native_anchors(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	for anchor_name in (value as Dictionary).keys():
		var config: Variant = (value as Dictionary)[anchor_name]
		if not config is Dictionary:
			continue
		var config_dict := config as Dictionary
		var alias_of := String(config_dict.get("alias_of", ""))
		if alias_of != "":
			result[String(anchor_name)] = {"alias_of": alias_of}
		else:
			result[String(anchor_name)] = {
				"part": String(config_dict.get("part", "")),
				"track": String(config_dict.get("track", "")),
				"offset": _to_vector2(config_dict.get("offset", [0.0, 0.0])),
			}
	return result


func _file_size(res_path: String) -> int:
	var file := FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		return -1
	var length := int(file.get_length())
	file.close()
	return length
