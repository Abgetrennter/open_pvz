extends SceneTree

const AssetIndexCatalogRef = preload("res://scripts/core/runtime/asset_index_catalog.gd")
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")

const REQUIRED_PROFILE_IDS := [
	&"classic_original.entity.plant.peashooter.visual",
	&"classic_original.entity.plant.sunflower.visual",
	&"classic_original.entity.plant.threepeater.visual",
	&"classic_original.entity.plant.chomper.visual",
	&"classic_original.entity.plant.squash.visual",
]


func _init() -> void:
	var expect_enabled := false
	for raw_arg in OS.get_cmdline_user_args():
		if String(raw_arg) == "--expect-classic-original-assets":
			expect_enabled = true
			break

	var enabled_pack := _find_enabled_classic_pack()

	if expect_enabled:
		if enabled_pack.is_empty():
			push_error("classic_original_assets should be enabled with --include-classic-original-assets.")
			quit(1)
			return
		var missing_profiles := _find_missing_private_profiles(String(enabled_pack.get("root_path", "")))
		if not missing_profiles.is_empty():
			push_error("classic_original_assets missing visual profiles: %s" % ", ".join(Array(missing_profiles)))
			quit(1)
			return
		var asset_index_errors := _validate_asset_index(enabled_pack)
		if not asset_index_errors.is_empty():
			push_error("classic_original_assets asset_index is invalid: %s" % " | ".join(Array(asset_index_errors)))
			quit(1)
			return
		var asset_registry := _get_asset_registry()
		if asset_registry == null:
			push_error("AssetRegistry autoload is not available.")
			quit(1)
			return
		asset_registry.call("rebuild_registry")
		var registry_errors := _validate_asset_registry()
		if not registry_errors.is_empty():
			push_error("classic_original_assets AssetRegistry resolution is invalid: %s" % " | ".join(Array(registry_errors)))
			quit(1)
			return
		print("classic_original_assets enabled with %d visual profiles." % REQUIRED_PROFILE_IDS.size())
		quit(0)
		return

	if not enabled_pack.is_empty():
		push_error("classic_original_assets should not be enabled without its activation flag.")
		quit(1)
		return
	print("classic_original_assets is disabled by default.")
	quit(0)


func _find_enabled_classic_pack() -> Dictionary:
	for pack in ExtensionPackCatalogRef.list_enabled_packs(&"visual_profiles"):
		if StringName(pack.get("pack_id", StringName())) == &"classic_original_assets":
			return pack
	return {}


func _find_missing_private_profiles(root_path: String) -> PackedStringArray:
	var missing := PackedStringArray()
	if root_path.is_empty():
		missing.append("classic_original_assets root_path")
		return missing
	for profile_id in REQUIRED_PROFILE_IDS:
		var profile_path := _profile_path_for_id(root_path, profile_id)
		if profile_path.is_empty() or not FileAccess.file_exists(profile_path):
			missing.append(String(profile_id))
			continue
		var profile_text := FileAccess.get_file_as_string(profile_path)
		if not profile_text.contains("id = &\"%s\"" % String(profile_id)):
			missing.append(String(profile_id))
	return missing


func _validate_asset_index(enabled_pack: Dictionary) -> PackedStringArray:
	var errors := AssetIndexCatalogRef.validate_pack_index(enabled_pack)
	for profile_id in REQUIRED_PROFILE_IDS:
		var asset := AssetIndexCatalogRef.resolve_asset(profile_id, &"visual_profile")
		if asset.is_empty():
			errors.append("asset_index missing %s" % String(profile_id))
			continue
		if StringName(asset.get("pack_id", StringName())) != &"classic_original_assets":
			errors.append("asset_index entry %s resolved from unexpected pack %s" % [String(profile_id), String(asset.get("pack_id", StringName()))])
			continue
		var entry: Dictionary = asset.get("entry", {})
		var actor_scene_path := AssetIndexCatalogRef.resolve_pack_path(enabled_pack, String(entry.get("actor_scene", "")))
		if actor_scene_path.is_empty() or not ResourceLoader.exists(actor_scene_path):
			errors.append("asset_index entry %s actor_scene missing: %s" % [String(profile_id), actor_scene_path])
		var source: Dictionary = entry.get("source", {})
		var source_reanim_path := AssetIndexCatalogRef.resolve_pack_path(enabled_pack, String(source.get("reanim", "")))
		if source_reanim_path.is_empty() or not FileAccess.file_exists(source_reanim_path):
			errors.append("asset_index entry %s source reanim missing: %s" % [String(profile_id), source_reanim_path])
	return errors


func _validate_asset_registry() -> PackedStringArray:
	var errors := PackedStringArray()
	var asset_registry := _get_asset_registry()
	if asset_registry == null:
		errors.append("AssetRegistry autoload is not available.")
		return errors
	for profile_id in REQUIRED_PROFILE_IDS:
		if not bool(asset_registry.call("has_asset", profile_id, &"visual_profile")):
			errors.append("AssetRegistry missing %s" % String(profile_id))
			continue
		var profile := asset_registry.call("resolve_visual_profile", profile_id) as Resource
		if profile == null:
			errors.append("AssetRegistry could not resolve %s" % String(profile_id))
			continue
		if profile.get("actor_scene") == null:
			errors.append("AssetRegistry profile %s has no actor_scene" % String(profile_id))
		if not profile.has_meta(&"asset_registry_source"):
			errors.append("AssetRegistry profile %s is missing source metadata" % String(profile_id))
	return errors


func _get_asset_registry() -> Node:
	if root != null:
		var existing := root.get_node_or_null("AssetRegistry")
		if existing != null:
			return existing
		var registry_script := load("res://autoload/AssetRegistry.gd") as Script
		if registry_script != null:
			var registry := registry_script.new() as Node
			if registry != null:
				registry.name = "AssetRegistry"
				root.add_child(registry)
				return registry
	return null


func _profile_path_for_id(root_path: String, profile_id: StringName) -> String:
	var plant_name := String(profile_id).trim_prefix("classic_original.entity.plant.").trim_suffix(".visual")
	if plant_name.is_empty():
		return ""
	return root_path.path_join("data/combat/visual_profiles/plants/%s.tres" % plant_name)
