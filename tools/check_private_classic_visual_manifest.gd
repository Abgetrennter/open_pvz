extends SceneTree

const AssetIndexCatalogRef = preload("res://scripts/core/runtime/asset_index_catalog.gd")
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")
const VisualProfileDefRef = preload("res://scripts/core/defs/visual_profile_def.gd")
const ReanimActorDefRef = preload("res://scripts/visual/reanim/reanim_actor_def.gd")

const PRIVATE_PACK_ID := &"classic_original_assets"
const MANIFEST_RELATIVE_PATH := "manifests/reanim_visual_manifest.local.json"


func _init() -> void:
	var enabled_pack := _find_enabled_private_classic_pack()
	if enabled_pack.is_empty():
		push_error("classic_original_assets should be enabled with --include-classic-original-assets.")
		quit(1)
		return

	var errors := PackedStringArray()
	errors.append_array(_validate_pack_manifest(enabled_pack))
	if not errors.is_empty():
		push_error("classic_original_assets visual manifest/index is invalid: %s" % " | ".join(Array(errors)))
		quit(1)
		return

	var manifest := _load_manifest(enabled_pack)
	var entries: Array = Array(manifest.get("entries", []))
	print("classic_original_assets visual manifest/index valid with %d visual profiles." % entries.size())
	quit(0)


func _find_enabled_private_classic_pack() -> Dictionary:
	for pack in ExtensionPackCatalogRef.list_enabled_packs(&"visual_profiles"):
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_PACK_ID:
			return pack
	return {}


func _validate_pack_manifest(enabled_pack: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var manifest := _load_manifest(enabled_pack)
	if manifest.is_empty():
		errors.append("missing or invalid manifest: %s" % _manifest_path(enabled_pack))
		return errors
	if StringName(manifest.get("pack_id", StringName())) != PRIVATE_PACK_ID:
		errors.append("manifest pack_id must be %s" % String(PRIVATE_PACK_ID))
	if not manifest.get("entries", []) is Array:
		errors.append("manifest entries must be an Array")
		return errors

	var entry_profile_ids := {}
	var entry_ids := {}
	for entry: Dictionary in Array(manifest.get("entries", [])):
		_validate_manifest_entry(enabled_pack, entry, entry_ids, entry_profile_ids, errors)

	errors.append_array(_validate_asset_index(enabled_pack, entry_profile_ids))
	# Validate the consumer side too: a self-consistent partial pack must not
	# pass while formal archetypes refer to missing profiles.
	for file_name in DirAccess.get_files_at("res://data/combat/archetypes/plants"):
		if not file_name.ends_with(".tres"):
			continue
		var archetype := load("res://data/combat/archetypes/plants/" + file_name) as Resource
		if archetype == null:
			errors.append("could not load archetype: %s" % file_name)
			continue
		var bound_id := StringName(archetype.get("visual_profile_id"))
		if String(bound_id).begins_with("classic_original.") and not entry_profile_ids.has(bound_id):
			errors.append("archetype %s references missing manifest profile: %s" % [file_name, String(bound_id)])
	return errors


func _load_manifest(enabled_pack: Dictionary) -> Dictionary:
	var manifest_path := _manifest_path(enabled_pack)
	if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):
		return {}
	var raw_text := FileAccess.get_file_as_string(manifest_path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if not parsed is Dictionary:
		return {}
	return Dictionary(parsed)


func _manifest_path(enabled_pack: Dictionary) -> String:
	return AssetIndexCatalogRef.resolve_pack_path(enabled_pack, MANIFEST_RELATIVE_PATH)


func _validate_manifest_entry(
	enabled_pack: Dictionary,
	entry: Dictionary,
	entry_ids: Dictionary,
	entry_profile_ids: Dictionary,
	errors: PackedStringArray
) -> void:
	var entry_id := String(entry.get("id", "")).strip_edges()
	if entry_id.is_empty():
		errors.append("manifest entry is missing id")
	elif entry_ids.has(entry_id):
		errors.append("manifest entry id duplicated: %s" % entry_id)
	entry_ids[entry_id] = true

	var profile_id := StringName(entry.get("profile_id", StringName()))
	if profile_id == StringName():
		errors.append("manifest entry %s is missing profile_id" % entry_id)
	elif entry_profile_ids.has(profile_id):
		errors.append("manifest profile_id duplicated: %s" % String(profile_id))
	entry_profile_ids[profile_id] = true
	if entry.has("native"):
		var native: Dictionary = entry["native"]
		var def_path := String(native.get("def_out_path", ""))
		var actor_def := load(def_path) as ReanimActorDefRef if not def_path.is_empty() else null
		if actor_def == null:
			errors.append("manifest entry %s native definition missing: %s" % [entry_id, def_path])
		else:
			for problem in actor_def.validate():
				errors.append("manifest entry %s: %s" % [entry_id, problem])

	_validate_existing_file(entry_id, "raw_actor_scene", String(entry.get("raw_actor_scene", "")), errors)
	_validate_existing_file(entry_id, "report_out_path", String(entry.get("report_out_path", "")), errors)
	_validate_existing_file(entry_id, "import_report", String(entry.get("import_report", "")), errors)
	_validate_existing_file(entry_id, "source_reanim", String(entry.get("source_reanim", "")), errors)
	if String(entry.get("source_resources", "")).strip_edges() != "":
		_validate_existing_file(entry_id, "source_resources", String(entry.get("source_resources", "")), errors)

	# Native entries keep the old composite output path only as an optional
	# regeneration target. The active actor is the native scene referenced by
	# the VisualProfile and asset index.
	var actor_scene_path := _active_actor_scene_path(entry)
	if actor_scene_path.is_empty() or not ResourceLoader.exists(actor_scene_path):
		errors.append("manifest entry %s active actor scene missing: %s" % [entry_id, actor_scene_path])
	else:
		var actor_scene := ResourceLoader.load(actor_scene_path) as PackedScene
		if actor_scene == null:
			errors.append("manifest entry %s active actor scene is not a PackedScene: %s" % [entry_id, actor_scene_path])

	var profile_path := String(entry.get("profile_out_path", ""))
	if profile_path.is_empty() or not ResourceLoader.exists(profile_path):
		errors.append("manifest entry %s profile_out_path missing: %s" % [entry_id, profile_path])
		return
	var profile := ResourceLoader.load(profile_path) as Resource
	if profile == null:
		errors.append("manifest entry %s profile_out_path could not be loaded: %s" % [entry_id, profile_path])
		return
	if profile.get_script() != VisualProfileDefRef:
		errors.append("manifest entry %s profile_out_path must use VisualProfileDef: %s" % [entry_id, profile_path])
	if StringName(profile.get("id")) != profile_id:
		errors.append("manifest entry %s profile id mismatch: %s" % [entry_id, String(profile.get("id"))])
	var profile_actor_scene := profile.get("actor_scene") as PackedScene
	if profile_actor_scene == null:
		errors.append("manifest entry %s profile has no actor_scene: %s" % [entry_id, profile_path])
	elif profile_actor_scene.resource_path != actor_scene_path:
		errors.append("manifest entry %s profile actor_scene mismatch: expected %s got %s" % [entry_id, actor_scene_path, profile_actor_scene.resource_path])
	if entry.has("ground_offset"):
		var expected_ground_offset := _to_vector2(entry.get("ground_offset", [0.0, 0.0]))
		var actual_ground_offset := profile.get("ground_offset") as Vector2
		if not actual_ground_offset.is_equal_approx(expected_ground_offset):
			errors.append("manifest entry %s ground_offset mismatch: expected %s got %s" % [entry_id, str(expected_ground_offset), str(actual_ground_offset)])


func _validate_existing_file(entry_id: String, field_name: String, raw_path: String, errors: PackedStringArray) -> void:
	var path := raw_path.strip_edges()
	if path.is_empty():
		errors.append("manifest entry %s is missing %s" % [entry_id, field_name])
	elif not FileAccess.file_exists(path):
		errors.append("manifest entry %s %s missing: %s" % [entry_id, field_name, path])


func _active_actor_scene_path(entry: Dictionary) -> String:
	var native_value: Variant = entry.get("native", {})
	if native_value is Dictionary:
		var native_path := String((native_value as Dictionary).get("actor_scene_out_path", "")).strip_edges()
		if not native_path.is_empty():
			return native_path
	return String(entry.get("actor_scene_out_path", "")).strip_edges()


func _validate_asset_index(enabled_pack: Dictionary, entry_profile_ids: Dictionary) -> PackedStringArray:
	var errors := AssetIndexCatalogRef.validate_pack_index(enabled_pack)
	var indexed_profile_ids := {}
	for asset: Dictionary in AssetIndexCatalogRef.list_assets(&"visual_profile"):
		if StringName(asset.get("pack_id", StringName())) != PRIVATE_PACK_ID:
			continue
		var asset_id := StringName(asset.get("id", StringName()))
		indexed_profile_ids[asset_id] = true
		if not entry_profile_ids.has(asset_id):
			errors.append("asset_index has visual profile not present in manifest: %s" % String(asset_id))

	for profile_id in entry_profile_ids.keys():
		if not indexed_profile_ids.has(profile_id):
			errors.append("manifest profile missing from asset_index: %s" % String(profile_id))
			continue
		var asset := AssetIndexCatalogRef.resolve_asset(profile_id, &"visual_profile")
		_validate_index_entry_against_manifest(enabled_pack, asset, profile_id, errors)
	return errors


func _validate_index_entry_against_manifest(
	enabled_pack: Dictionary,
	asset: Dictionary,
	profile_id: StringName,
	errors: PackedStringArray
) -> void:
	if asset.is_empty():
		errors.append("asset_index missing %s" % String(profile_id))
		return
	if StringName(asset.get("pack_id", StringName())) != PRIVATE_PACK_ID:
		errors.append("asset_index entry %s resolved from unexpected pack %s" % [String(profile_id), String(asset.get("pack_id", StringName()))])
		return
	var entry: Dictionary = asset.get("entry", {})
	var profile_path := String(asset.get("path", ""))
	if profile_path.is_empty() or not ResourceLoader.exists(profile_path):
		errors.append("asset_index entry %s profile missing: %s" % [String(profile_id), profile_path])
	var actor_scene_path := AssetIndexCatalogRef.resolve_pack_path(enabled_pack, String(entry.get("actor_scene", "")))
	if actor_scene_path.is_empty() or not ResourceLoader.exists(actor_scene_path):
		errors.append("asset_index entry %s actor_scene missing: %s" % [String(profile_id), actor_scene_path])
	elif not profile_path.is_empty() and ResourceLoader.exists(profile_path):
		var profile := ResourceLoader.load(profile_path) as Resource
		var profile_actor_scene: PackedScene = null
		if profile != null:
			profile_actor_scene = profile.get("actor_scene") as PackedScene
		if profile_actor_scene == null or profile_actor_scene.resource_path != actor_scene_path:
			errors.append("asset_index entry %s actor_scene does not match profile: %s" % [String(profile_id), actor_scene_path])
	var source: Dictionary = entry.get("source", {})
	var source_reanim_path := AssetIndexCatalogRef.resolve_pack_path(enabled_pack, String(source.get("reanim", "")))
	if source_reanim_path.is_empty() or not FileAccess.file_exists(source_reanim_path):
		errors.append("asset_index entry %s source reanim missing: %s" % [String(profile_id), source_reanim_path])


func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
