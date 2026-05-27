extends Node

const AssetIndexCatalogRef = preload("res://scripts/core/runtime/asset_index_catalog.gd")
const VisualProfileDefRef = preload("res://scripts/core/defs/visual_profile_def.gd")
const BattlefieldVisualDefRef = preload("res://scripts/core/defs/battlefield_visual_def.gd")

const KIND_VISUAL_PROFILE := &"visual_profile"
const KIND_BATTLEFIELD_VISUAL := &"battlefield_visual"
const KIND_TEXTURE := &"texture"

var _assets_by_kind: Dictionary = {}
var _assets_by_id: Dictionary = {}


func _ready() -> void:
	rebuild_registry()


func rebuild_registry() -> void:
	_assets_by_kind.clear()
	_assets_by_id.clear()
	for asset in AssetIndexCatalogRef.list_assets():
		_register_asset(asset)


func has_asset(asset_id: StringName, kind := StringName()) -> bool:
	return not resolve_asset(asset_id, kind).is_empty()


func resolve_asset(asset_id: StringName, kind := StringName()) -> Dictionary:
	if asset_id == StringName():
		return {}
	if kind != StringName():
		var by_id: Dictionary = _assets_by_kind.get(kind, {})
		return Dictionary(by_id.get(asset_id, {})).duplicate(true)
	return Dictionary(_assets_by_id.get(asset_id, {})).duplicate(true)


func resolve_visual_profile(profile_id: StringName) -> Resource:
	var asset := resolve_asset(profile_id, KIND_VISUAL_PROFILE)
	if asset.is_empty():
		return null
	var profile_path := String(asset.get("path", ""))
	if profile_path.is_empty():
		_record_issue("AssetRegistry visual_profile %s has no path." % String(profile_id))
		return null
	if not ResourceLoader.exists(profile_path):
		_record_issue("AssetRegistry visual_profile %s path does not exist: %s" % [String(profile_id), profile_path])
		return null
	var profile := ResourceLoader.load(profile_path)
	if profile == null:
		_record_issue("AssetRegistry visual_profile %s could not be loaded: %s" % [String(profile_id), profile_path])
		return null
	if profile.get_script() != VisualProfileDefRef:
		_record_issue("AssetRegistry visual_profile %s must use VisualProfileDef: %s" % [String(profile_id), profile_path])
		return null
	profile.set_meta(&"asset_registry_source", asset.duplicate(true))
	profile.set_meta(&"asset_registry_resolved", true)
	return profile


func resolve_battlefield_visual(visual_id: StringName) -> Resource:
	var asset := resolve_asset(visual_id, KIND_BATTLEFIELD_VISUAL)
	if asset.is_empty():
		return null
	var visual_path := String(asset.get("path", ""))
	if visual_path.is_empty():
		_record_issue("AssetRegistry battlefield_visual %s has no path." % String(visual_id))
		return null
	if not ResourceLoader.exists(visual_path):
		_record_issue("AssetRegistry battlefield_visual %s path does not exist: %s" % [String(visual_id), visual_path])
		return null
	var visual_def := ResourceLoader.load(visual_path)
	if visual_def == null:
		_record_issue("AssetRegistry battlefield_visual %s could not be loaded: %s" % [String(visual_id), visual_path])
		return null
	if visual_def.get_script() != BattlefieldVisualDefRef:
		_record_issue("AssetRegistry battlefield_visual %s must use BattlefieldVisualDef: %s" % [String(visual_id), visual_path])
		return null
	visual_def.set_meta(&"asset_registry_source", asset.duplicate(true))
	visual_def.set_meta(&"asset_registry_resolved", true)
	return visual_def


func resolve_texture(texture_id: StringName) -> Texture2D:
	var asset := resolve_asset(texture_id, KIND_TEXTURE)
	if asset.is_empty():
		return null
	var texture_path := String(asset.get("path", ""))
	if texture_path.is_empty():
		_record_issue("AssetRegistry texture %s has no path." % String(texture_id))
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(texture_path):
		texture = ResourceLoader.load(texture_path) as Texture2D
	if texture == null:
		texture = _load_texture_from_image_file(texture_path)
	if texture == null:
		_record_issue("AssetRegistry texture %s could not be loaded: %s" % [String(texture_id), texture_path])
		return null
	return texture


func _register_asset(asset: Dictionary) -> void:
	var asset_id := StringName(asset.get("id", StringName()))
	var kind := StringName(asset.get("kind", StringName()))
	if asset_id == StringName() or kind == StringName():
		_record_issue("AssetRegistry ignored asset with missing id or kind.")
		return
	if _assets_by_id.has(asset_id):
		_record_issue("AssetRegistry duplicate asset id %s from pack %s was ignored." % [
			String(asset_id),
			String(asset.get("pack_id", StringName())),
		])
		return
	if not _assets_by_kind.has(kind):
		_assets_by_kind[kind] = {}
	var by_id: Dictionary = _assets_by_kind[kind]
	if by_id.has(asset_id):
		_record_issue("AssetRegistry duplicate %s asset %s was ignored." % [String(kind), String(asset_id)])
		return
	var stored := asset.duplicate(true)
	by_id[asset_id] = stored
	_assets_by_kind[kind] = by_id
	_assets_by_id[asset_id] = stored


func _record_issue(message: String) -> void:
	push_warning(message)
	var debug_service := get_node_or_null("/root/DebugService")
	if debug_service != null and debug_service.has_method("record_protocol_issue"):
		debug_service.record_protocol_issue(&"asset_registry", message, &"error")


func _load_texture_from_image_file(texture_path: String) -> Texture2D:
	if texture_path.is_empty() or not FileAccess.file_exists(texture_path):
		return null
	var image := Image.new()
	var result := image.load(ProjectSettings.globalize_path(texture_path))
	if result != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = texture_path.get_file()
	return texture
