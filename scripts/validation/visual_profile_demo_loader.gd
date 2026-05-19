extends RefCounted
class_name VisualProfileDemoLoader


static func load_actor_scene(profile_id: StringName, profile_path := "", actor_scene_path := "") -> Dictionary:
	if profile_id != StringName():
		var asset_profile := _resolve_asset_registry_profile(profile_id)
		var asset_scene := _actor_scene_from_profile(asset_profile)
		if asset_scene != null:
			return _result(asset_scene, asset_profile, "asset id %s" % String(profile_id), "")
		if not VisualProfileRegistry.has(profile_id):
			return _result(null, null, String(profile_id), "VisualProfileRegistry 未注册 profile id：%s" % String(profile_id))
		var registry_profile := VisualProfileRegistry.get_def(profile_id)
		var registry_scene := _actor_scene_from_profile(registry_profile)
		if registry_scene != null:
			return _result(registry_scene, registry_profile, "profile id %s" % String(profile_id), "")
		return _result(null, registry_profile, String(profile_id), "VisualProfileRegistry profile 缺少 actor_scene：%s" % String(profile_id))

	if not profile_path.is_empty():
		if ResourceLoader.exists(profile_path):
			var file_profile := ResourceLoader.load(profile_path)
			var file_scene := _actor_scene_from_profile(file_profile)
			if file_scene != null:
				return _result(file_scene, file_profile, profile_path, "")
			return _result(null, file_profile, profile_path, "visual profile 无法加载 actor_scene：%s" % profile_path)
		return _result(null, null, profile_path, "未找到 visual profile：%s" % profile_path)

	if not actor_scene_path.is_empty():
		if ResourceLoader.exists(actor_scene_path):
			var packed_scene := ResourceLoader.load(actor_scene_path) as PackedScene
			if packed_scene != null:
				return _result(packed_scene, null, actor_scene_path, "")
			return _result(null, null, actor_scene_path, "导入产物无法作为 PackedScene 加载：%s" % actor_scene_path)
		return _result(null, null, actor_scene_path, "未找到导入产物：%s" % actor_scene_path)

	return _result(null, null, "", "未配置 visual profile 或 actor scene 路径。")


static func _resolve_asset_registry_profile(profile_id: StringName) -> Resource:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var asset_registry := tree.root.get_node_or_null("AssetRegistry")
	if asset_registry == null or not asset_registry.has_method("resolve_visual_profile"):
		return null
	return asset_registry.call("resolve_visual_profile", profile_id) as Resource


static func _actor_scene_from_profile(profile: Resource) -> PackedScene:
	if profile == null:
		return null
	return profile.get("actor_scene") as PackedScene


static func _result(actor_scene: PackedScene, profile: Resource, source: String, error: String) -> Dictionary:
	return {
		"actor_scene": actor_scene,
		"profile": profile,
		"source": source,
		"error": error,
	}
