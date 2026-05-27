extends SceneTree

const AssetIndexCatalogRef = preload("res://scripts/core/runtime/asset_index_catalog.gd")
const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")
const VisualStageLayerServiceRef = preload("res://scripts/visual/visual_stage_layer_service.gd")

const PRIVATE_PACK_ID := &"classic_original_assets"
const CLASSIC_GRASS_VISUAL_ID := &"classic_original.battlefield.grass_day.visual"
const EXPECTED_TEXTURE_ID := &"classic_original.battlefield.grass_day.background"
const EXPECTED_DRAW_OFFSET := Vector2(-220.0, 0.0)
const EXPECTED_BACKGROUND_SCALE := Vector2.ONE
const EXPECTED_SOURCE_SIZE := Vector2(1400.0, 600.0)
const EXPECTED_VIEWPORT_SIZE := Vector2(800.0, 600.0)
const EXPECTED_BACKGROUND_Z_INDEX := 0
const DEBUG_ENABLE_CLASSIC_ORIGINAL_ASSETS_SETTING := "openpvz/debug/enable_classic_original_assets"
const GROUND_BASELINE_PRESET_PATH := "res://data/combat/battlefields/phase6/battlefield_ground_baseline.tres"

const EXPECTED_BACKGROUNDS := [
	{
		"visual_id": &"classic_original.battlefield.grass_day.visual",
		"texture_id": &"classic_original.battlefield.grass_day.background",
	},
	{
		"visual_id": &"classic_original.battlefield.unsodded_day.visual",
		"texture_id": &"classic_original.battlefield.unsodded_day.background",
	},
	{
		"visual_id": &"classic_original.battlefield.pool_day.visual",
		"texture_id": &"classic_original.battlefield.pool_day.background",
	},
	{
		"visual_id": &"classic_original.battlefield.roof_day.visual",
		"texture_id": &"classic_original.battlefield.roof_day.background",
	},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors := PackedStringArray()
	if not bool(ProjectSettings.get_setting(DEBUG_ENABLE_CLASSIC_ORIGINAL_ASSETS_SETTING, false)):
		errors.append("%s is not enabled" % DEBUG_ENABLE_CLASSIC_ORIGINAL_ASSETS_SETTING)
	var private_pack := _find_private_pack()
	if private_pack.is_empty():
		errors.append("classic_original_assets is not enabled")

	if not private_pack.is_empty():
		errors.append_array(AssetIndexCatalogRef.validate_pack_index(private_pack))
		errors.append_array(_validate_expected_background_assets())
		errors.append_array(_validate_visual_stage_node())
	else:
		errors.append("could not validate static background assets without private pack")

	if not errors.is_empty():
		_fail(" | ".join(errors))
		return
	print("Classic original static battlefield background assets are registered.")
	quit(0)


func _find_private_pack() -> Dictionary:
	for pack in ExtensionPackCatalogRef.list_enabled_packs():
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_PACK_ID:
			return pack
	return {}


func _validate_expected_background_assets() -> PackedStringArray:
	var errors := PackedStringArray()
	for expected in EXPECTED_BACKGROUNDS:
		var visual_id := StringName(expected.get("visual_id", StringName()))
		var texture_id := StringName(expected.get("texture_id", StringName()))
		var visual_asset := AssetIndexCatalogRef.resolve_asset(visual_id, &"battlefield_visual")
		if visual_asset.is_empty():
			errors.append("missing battlefield visual asset %s" % String(visual_id))
			continue
		var texture_asset := AssetIndexCatalogRef.resolve_asset(texture_id, &"texture")
		if texture_asset.is_empty():
			errors.append("missing texture asset %s" % String(texture_id))
			continue
		var visual_def := ResourceLoader.load(String(visual_asset.get("path", ""))) as Resource
		if visual_def == null:
			errors.append("could not load battlefield visual %s" % String(visual_id))
			continue
		if StringName(visual_def.get("id")) != visual_id:
			errors.append("battlefield visual id is %s, expected %s" % [String(visual_def.get("id")), String(visual_id)])
		if StringName(visual_def.get("texture_asset_id")) != texture_id:
			errors.append("battlefield visual texture_asset_id is %s, expected %s" % [String(visual_def.get("texture_asset_id")), String(texture_id)])
		if Vector2(visual_def.get("draw_offset")) != EXPECTED_DRAW_OFFSET:
			errors.append("battlefield visual draw_offset is %s, expected %s" % [str(visual_def.get("draw_offset")), str(EXPECTED_DRAW_OFFSET)])
		if Vector2(visual_def.get("source_size")) != EXPECTED_SOURCE_SIZE:
			errors.append("battlefield visual source_size is %s, expected %s" % [str(visual_def.get("source_size")), str(EXPECTED_SOURCE_SIZE)])
		if String(visual_def.get("fit_mode")) != "original":
			errors.append("battlefield visual fit_mode is %s, expected original" % String(visual_def.get("fit_mode")))
	return errors


func _validate_visual_stage_node() -> PackedStringArray:
	var errors := PackedStringArray()
	var asset_registry := _get_asset_registry()
	if asset_registry == null:
		errors.append("AssetRegistry is not available")
		return errors
	asset_registry.call("rebuild_registry")
	var visual_def := asset_registry.call("resolve_battlefield_visual", CLASSIC_GRASS_VISUAL_ID) as Resource
	if visual_def == null:
		errors.append("AssetRegistry could not resolve %s" % String(CLASSIC_GRASS_VISUAL_ID))
		return errors
	var texture := asset_registry.call("resolve_texture", EXPECTED_TEXTURE_ID) as Texture2D
	if texture == null:
		errors.append("AssetRegistry could not resolve %s" % String(EXPECTED_TEXTURE_ID))
		return errors

	var preset := ResourceLoader.load(GROUND_BASELINE_PRESET_PATH) as Resource
	if preset == null:
		errors.append("could not load %s" % GROUND_BASELINE_PRESET_PATH)
		return errors
	if StringName(preset.get("battlefield_visual_id")) != CLASSIC_GRASS_VISUAL_ID:
		errors.append("%s battlefield_visual_id is %s, expected %s" % [GROUND_BASELINE_PRESET_PATH, String(preset.get("battlefield_visual_id")), String(CLASSIC_GRASS_VISUAL_ID)])

	var battle_root := Node2D.new()
	battle_root.name = "BattleVisualStageHarness"
	root.add_child(battle_root)
	var runtime_entities := Node2D.new()
	runtime_entities.name = "RuntimeEntities"
	battle_root.add_child(runtime_entities)

	var service := VisualStageLayerServiceRef.new()
	service.name = "VisualStageLayerService"
	battle_root.add_child(service)
	service.initialize(battle_root)
	var service_asset_registry := service.call("_get_asset_registry") as Node if service.has_method("_get_asset_registry") else null
	if service_asset_registry == null:
		errors.append("VisualStageLayerService could not resolve AssetRegistry")
	service.apply_visual_preset(preset)

	var visual_root := battle_root.get_node_or_null("BattleVisualRoot")
	if visual_root == null:
		errors.append("BattleVisualRoot was not created")
		return errors
	if runtime_entities.get_index() <= visual_root.get_index():
		errors.append("BattleVisualRoot must render before RuntimeEntities for ground backgrounds")
	var background := visual_root.get_node_or_null("GroundLayer/BattlefieldBackground") as Sprite2D
	if background == null:
		var ground_layer := visual_root.get_node_or_null("GroundLayer")
		var child_names := PackedStringArray()
		if ground_layer != null:
			for child in ground_layer.get_children():
				child_names.append(child.name)
		var host := service.get_layer_host(&"ground") if service.has_method("get_layer_host") else null
		errors.append("GroundLayer/BattlefieldBackground was not created; ground layer exists: %s; host exists: %s; ground children: %s" % [
			str(ground_layer != null),
			str(host != null),
			", ".join(Array(child_names)),
		])
		return errors
	if background.texture == null:
		errors.append("BattlefieldBackground has no texture")
	elif background.texture.get_size() != EXPECTED_SOURCE_SIZE:
		errors.append("BattlefieldBackground texture size is %s, expected %s" % [str(background.texture.get_size()), str(EXPECTED_SOURCE_SIZE)])
	if background.centered:
		errors.append("BattlefieldBackground must use top-left positioning")
	if background.position != EXPECTED_DRAW_OFFSET:
		errors.append("BattlefieldBackground position is %s, expected %s" % [str(background.position), str(EXPECTED_DRAW_OFFSET)])
	if background.scale != EXPECTED_BACKGROUND_SCALE:
		errors.append("BattlefieldBackground scale is %s, expected %s" % [str(background.scale), str(EXPECTED_BACKGROUND_SCALE)])
	var bottom_edge := background.position.y + background.texture.get_size().y * background.scale.y
	if bottom_edge > EXPECTED_VIEWPORT_SIZE.y + 0.01:
		errors.append("BattlefieldBackground bottom edge is %.2f, expected <= %.2f" % [bottom_edge, EXPECTED_VIEWPORT_SIZE.y])
	if background.z_index != EXPECTED_BACKGROUND_Z_INDEX:
		errors.append("BattlefieldBackground z_index is %d, expected %d" % [background.z_index, EXPECTED_BACKGROUND_Z_INDEX])

	var empty_preset := preset.duplicate()
	empty_preset.set("battlefield_visual_id", StringName())
	service.apply_visual_preset(empty_preset)
	if visual_root.get_node_or_null("GroundLayer/BattlefieldBackground") != null:
		errors.append("BattlefieldBackground was not cleared when preset visual id was empty")
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
