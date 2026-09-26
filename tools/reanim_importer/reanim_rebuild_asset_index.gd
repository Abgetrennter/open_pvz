extends SceneTree
## reanim_rebuild_asset_index.gd — rebuilds asset_index.json from the private
## reanim manifest WITHOUT regenerating any actor scenes. Use after adding/
## editing native entries via run_reanim_migrate_one.ps1 so the asset index
## stays in sync with the manifest (the full Stage B pass also does this, but
## rebuilds every legacy composite actor -- slow and unnecessary when only the
## index is stale).
##
## Mirrors the asset-index construction in reanim_generate_composites.gd
## (_build_asset_index_entry + _save_asset_index_if_requested) so the output is
## byte-equivalent to a full pass.
##
## Usage:
##   godot --headless --path <project> --script res://tools/reanim_importer/reanim_rebuild_asset_index.gd -- \
##     --manifest res://local_extensions/classic_original_assets/manifests/reanim_visual_manifest.local.json

const NATIVE_FALLBACK_ACTOR := ""

var _args: Dictionary = {}


func _init():
	_args = _parse_args(OS.get_cmdline_user_args())
	var manifest_path := String(_args.get("manifest", ""))
	if manifest_path.is_empty():
		push_error("--manifest <res://...json> is required")
		quit(1)
		return
	if not FileAccess.file_exists(manifest_path):
		push_error("Manifest not found: %s" % manifest_path)
		quit(2)
		return
	var manifest := _load_json(manifest_path)
	if manifest.is_empty():
		quit(3)
		return

	var asset_index_path := _normalize_res_path(String(manifest.get("asset_index_out_path", "")))
	if asset_index_path.is_empty():
		push_error("manifest has no asset_index_out_path")
		quit(4)
		return
	var pack_root := _normalize_res_dir(String(manifest.get("asset_index_pack_root", asset_index_path.get_base_dir())))

	var existing_index := {}
	if FileAccess.file_exists(asset_index_path):
		existing_index = _load_json(asset_index_path)
	var assets := _preserve_unmanaged_assets(existing_index)
	var visual_profiles := {}
	var count := 0
	for entry in manifest.get("entries", []):
		if not entry is Dictionary:
			continue
		var typed := entry as Dictionary
		var profile_id := String(typed.get("profile_id", ""))
		if profile_id.is_empty():
			continue
		var profile_path := _normalize_res_path(String(typed.get("profile_out_path", "")))
		var report_path := _normalize_res_path(String(typed.get("report_out_path", "")))
		var asset_entry := _build_asset_index_entry(typed, profile_path, report_path)
		asset_entry = _make_asset_entry_paths_relative(asset_entry, pack_root)
		assets[profile_id] = asset_entry
		visual_profiles[profile_id] = String(asset_entry.get("path", ""))
		count += 1

	var index := {
		"version": 1,
		"format": "openpvz.asset_index.v1",
		"pack_id": String(manifest.get("pack_id", "")),
		"generated_by": "tools/reanim_importer/reanim_rebuild_asset_index.gd",
		"assets": assets,
		"visual_profiles": visual_profiles,
	}
	var dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(asset_index_path.get_base_dir()))
	if dir_result != OK:
		push_warning("Could not create asset index output dir: %s" % asset_index_path.get_base_dir())
		quit(5)
		return
	_save_json(asset_index_path, index)
	print("Rebuilt asset index: %s (%d managed profiles)" % [asset_index_path, count])
	quit(0)


func _build_asset_index_entry(entry: Dictionary, profile_path: String, report_path: String) -> Dictionary:
	var actor_path := _active_actor_scene_path(entry)
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


func _active_actor_scene_path(entry: Dictionary) -> String:
	var native_value: Variant = entry.get("native", {})
	if native_value is Dictionary:
		var native_path := _normalize_res_path(String((native_value as Dictionary).get("actor_scene_out_path", "")))
		if not native_path.is_empty():
			return native_path
	return _normalize_res_path(String(entry.get("actor_scene_out_path", "")))


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
			continue  # managed asset: rebuilt from manifest below
		preserved[asset_id] = (existing_assets as Dictionary)[asset_id]
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
	var np := path.replace("\\", "/")
	var nr := pack_root.replace("\\", "/")
	if np.begins_with("%s/" % nr):
		return np.substr(nr.length() + 1)
	return np


func _normalize_res_dir(path: String) -> String:
	var n := path.replace("\\", "/")
	if n.ends_with("/"):
		n = n.substr(0, n.length() - 1)
	return n


func _normalize_res_path(path: String) -> String:
	return path.replace("\\", "/")


func _save_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write JSON: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return parsed


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
