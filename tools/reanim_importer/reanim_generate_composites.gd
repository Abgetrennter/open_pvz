extends SceneTree

const VisualProfileDefRef = preload("res://scripts/core/defs/visual_profile_def.gd")
const CompositeActorScript = preload("res://scripts/validation/reanim_manifest_composite_actor.gd")

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

	var generated: Array[Dictionary] = []
	for entry in manifest.get("entries", []):
		if not entry is Dictionary:
			continue
		var result := _generate_entry(entry)
		generated.append(result)
		if not bool(result.get("ok", false)):
			push_warning("Composite generation failed for %s: %s" % [String(result.get("id", "")), String(result.get("error", ""))])

	print("Generated %d manifest composite entries." % generated.size())
	return 0


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
	if id == "" or out_dir == "":
		return {"id": id, "ok": false, "error": "missing id/out_dir"}
	if not ResourceLoader.exists(String(entry.get("raw_actor_scene", ""))):
		return {"id": id, "ok": false, "error": "raw actor scene missing"}

	var make_dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	if make_dir_result != OK:
		return {"id": id, "ok": false, "error": "could not create out_dir"}

	var actor_path := out_dir.path_join("actor.tscn")
	var profile_path := out_dir.path_join("visual_profile.tres")
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
	_save_json(out_dir.path_join("composite_report.json"), report)
	return report


func _build_actor(entry: Dictionary) -> PackedScene:
	var root := Node2D.new()
	root.name = "ReanimManifestComposite"
	root.set_script(CompositeActorScript)
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

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		push_error("Failed to pack generated manifest composite actor.")
	root.queue_free()
	return packed


func _save_profile(entry: Dictionary, actor_path: String, profile_path: String) -> int:
	var profile = VisualProfileDefRef.new()
	profile.id = StringName(entry.get("profile_id", "local.original.%s.composite" % String(entry.get("id", "unknown"))))
	profile.actor_scene = ResourceLoader.load(actor_path) as PackedScene
	profile.state_animation_map = _string_dict_to_string_name_dict(entry.get("state_animation_map", {}))
	profile.action_animation_map = _profile_action_map(entry.get("action_animation_map", {}))
	profile.animation_map = {}
	profile.z_policy = {"layer": &"plant"}
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


func _normalize_res_dir(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


func _save_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write JSON report: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
