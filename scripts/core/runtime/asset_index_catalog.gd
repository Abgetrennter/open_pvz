extends RefCounted
class_name AssetIndexCatalog

const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")

const DEFAULT_ASSET_INDEX_PATH := "asset_index.json"
const BUCKET_KIND_MAP := {
	"visual_profiles": &"visual_profile",
	"visual_fx": &"visual_fx",
	"visual_cues": &"visual_cue",
	"audio_cues": &"audio_cue",
}


static func list_assets(kind: StringName = StringName()) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pack_manifest in _list_enabled_asset_packs():
		var index := load_index_for_pack(pack_manifest)
		if index.is_empty():
			continue
		result.append_array(_extract_assets(index, pack_manifest, kind))
	return result


static func resolve_asset(logical_id: StringName, kind: StringName = StringName()) -> Dictionary:
	for asset in list_assets(kind):
		if StringName(asset.get("id", StringName())) == logical_id:
			return asset
	return {}


static func load_index_for_pack(pack_manifest: Dictionary) -> Dictionary:
	var index_path := get_asset_index_path(pack_manifest)
	if index_path.is_empty() or not FileAccess.file_exists(index_path):
		return {}
	var file := FileAccess.open(index_path, FileAccess.READ)
	if file == null:
		return {}
	var raw_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		return {}
	var index := Dictionary(parsed)
	index["_index_path"] = index_path
	return index


static func get_asset_index_path(pack_manifest: Dictionary) -> String:
	var root_path := String(pack_manifest.get("root_path", ""))
	if root_path.is_empty():
		return ""
	var relative_path := DEFAULT_ASSET_INDEX_PATH
	var entry_points: Variant = pack_manifest.get("entry_points", {})
	if entry_points is Dictionary:
		relative_path = String((entry_points as Dictionary).get("asset_index", DEFAULT_ASSET_INDEX_PATH))
	return resolve_pack_path(pack_manifest, relative_path)


static func resolve_pack_path(pack_manifest: Dictionary, relative_or_res_path: String) -> String:
	if relative_or_res_path.is_empty():
		return ""
	var normalized := relative_or_res_path.replace("\\", "/")
	if normalized.begins_with("res://"):
		return normalized
	var root_path := String(pack_manifest.get("root_path", ""))
	if root_path.is_empty():
		return normalized
	return root_path.path_join(normalized)


static func validate_pack_index(pack_manifest: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var index_path := get_asset_index_path(pack_manifest)
	if index_path.is_empty():
		errors.append("asset_pack %s is missing root_path for asset_index." % String(pack_manifest.get("pack_id", StringName())))
		return errors
	if not FileAccess.file_exists(index_path):
		errors.append("asset_pack %s is missing asset_index: %s" % [String(pack_manifest.get("pack_id", StringName())), index_path])
		return errors
	var index := load_index_for_pack(pack_manifest)
	if index.is_empty():
		errors.append("asset_pack %s has invalid asset_index JSON: %s" % [String(pack_manifest.get("pack_id", StringName())), index_path])
		return errors
	var assets := _extract_assets(index, pack_manifest, StringName())
	if assets.is_empty():
		errors.append("asset_pack %s asset_index has no assets." % String(pack_manifest.get("pack_id", StringName())))
		return errors
	for asset in assets:
		_validate_asset_entry(asset, errors)
	return errors


static func _list_enabled_asset_packs() -> Array[Dictionary]:
	var packs: Array[Dictionary] = []
	for pack_manifest in ExtensionPackCatalogRef.list_enabled_packs():
		if StringName(pack_manifest.get("pack_type", StringName())) == &"asset_pack":
			packs.append(pack_manifest)
	return packs


static func _extract_assets(index: Dictionary, pack_manifest: Dictionary, kind: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var assets: Variant = index.get("assets", {})
	if assets is Dictionary:
		for raw_id in (assets as Dictionary).keys():
			var asset := _normalize_asset_entry(StringName(String(raw_id)), (assets as Dictionary)[raw_id], pack_manifest, StringName())
			if asset.is_empty():
				continue
			if kind == StringName() or StringName(asset.get("kind", StringName())) == kind:
				seen_ids[StringName(asset.get("id", StringName()))] = true
				result.append(asset)
	for bucket_name in BUCKET_KIND_MAP.keys():
		var bucket: Variant = index.get(bucket_name, {})
		if not bucket is Dictionary:
			continue
		var bucket_kind: StringName = BUCKET_KIND_MAP[bucket_name]
		for raw_id in (bucket as Dictionary).keys():
			var asset := _normalize_asset_entry(StringName(String(raw_id)), (bucket as Dictionary)[raw_id], pack_manifest, bucket_kind)
			if asset.is_empty():
				continue
			if seen_ids.has(StringName(asset.get("id", StringName()))):
				continue
			if kind == StringName() or StringName(asset.get("kind", StringName())) == kind:
				seen_ids[StringName(asset.get("id", StringName()))] = true
				result.append(asset)
	return result


static func _normalize_asset_entry(id: StringName, raw_entry: Variant, pack_manifest: Dictionary, fallback_kind: StringName) -> Dictionary:
	if id == StringName():
		return {}
	var entry: Dictionary = {}
	if raw_entry is String or raw_entry is StringName:
		entry = {"path": String(raw_entry)}
	elif raw_entry is Dictionary:
		entry = Dictionary(raw_entry).duplicate(true)
	else:
		return {}
	var asset_kind := StringName(entry.get("kind", fallback_kind))
	if asset_kind == StringName():
		asset_kind = fallback_kind
	var raw_path := String(entry.get("path", entry.get("profile", "")))
	var resolved_path := resolve_pack_path(pack_manifest, raw_path)
	return {
		"id": id,
		"kind": asset_kind,
		"path": resolved_path,
		"pack_id": StringName(pack_manifest.get("pack_id", StringName())),
		"pack_root": String(pack_manifest.get("root_path", "")),
		"entry": entry,
	}


static func _validate_asset_entry(asset: Dictionary, errors: PackedStringArray) -> void:
	var id := StringName(asset.get("id", StringName()))
	var path := String(asset.get("path", ""))
	if id == StringName():
		errors.append("asset_index contains an empty logical asset id.")
	if path.is_empty():
		errors.append("asset_index entry %s is missing path." % String(id))
	elif not FileAccess.file_exists(path):
		errors.append("asset_index entry %s path does not exist: %s" % [String(id), path])
	var entry: Dictionary = asset.get("entry", {})
	for path_key in ["actor_scene", "profile"]:
		if not entry.has(path_key):
			continue
		var nested_path := resolve_pack_path({"root_path": String(asset.get("pack_root", ""))}, String(entry.get(path_key, "")))
		if not nested_path.is_empty() and not FileAccess.file_exists(nested_path):
			errors.append("asset_index entry %s %s does not exist: %s" % [String(id), path_key, nested_path])
