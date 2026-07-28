extends Control
class_name OriginalBattlefieldBackgroundShowcase

const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")

const PRIVATE_PACK_ID := &"classic_original_assets"
const PREVIEW_TARGET_SIZE := Vector2(400.0, 171.0)
const PREVIEW_ENTRIES := [
	{
		"title": "草坪白天",
		"visual_id": &"classic_original.battlefield.grass_day.visual",
		"texture_id": &"classic_original.battlefield.grass_day.background",
	},
	{
		"title": "未铺草皮白天",
		"visual_id": &"classic_original.battlefield.unsodded_day.visual",
		"texture_id": &"classic_original.battlefield.unsodded_day.background",
	},
	{
		"title": "泳池白天",
		"visual_id": &"classic_original.battlefield.pool_day.visual",
		"texture_id": &"classic_original.battlefield.pool_day.background",
	},
	{
		"title": "屋顶白天",
		"visual_id": &"classic_original.battlefield.roof_day.visual",
		"texture_id": &"classic_original.battlefield.roof_day.background",
	},
]

var _status_label: Label = null
var _preview_grid: GridContainer = null


func _ready() -> void:
	_enable_private_pack_for_showcase()
	_build_ui()
	_load_previews()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		_return_to_main_menu()


func get_preview_entries() -> Array:
	return PREVIEW_ENTRIES.duplicate(true)


func _enable_private_pack_for_showcase() -> void:
	ExtensionPackCatalogRef.enable_pack_for_current_session(PRIVATE_PACK_ID)
	var asset_registry := _get_asset_registry()
	if asset_registry != null and asset_registry.has_method("rebuild_registry"):
		asset_registry.call("rebuild_registry")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color("1b2b22")
	add_child(background)

	var content := MarginContainer.new()
	content.name = "Content"
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.add_theme_constant_override("margin_left", 36)
	content.add_theme_constant_override("margin_top", 24)
	content.add_theme_constant_override("margin_right", 36)
	content.add_theme_constant_override("margin_bottom", 24)
	background.add_child(content)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	content.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var back_button := Button.new()
	back_button.text = "返回主面板 (Esc)"
	back_button.pressed.connect(_return_to_main_menu)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "原版战场背景静态展示"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("f0ead2"))
	header.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color("d8dcc5"))
	layout.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	_preview_grid = GridContainer.new()
	_preview_grid.name = "PreviewGrid"
	_preview_grid.columns = 2
	_preview_grid.add_theme_constant_override("h_separation", 16)
	_preview_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_preview_grid)


func _load_previews() -> void:
	var loaded_count := 0
	for entry in PREVIEW_ENTRIES:
		if _preview_grid == null:
			continue
		var card := _build_preview_card(entry)
		_preview_grid.add_child(card)
		if bool(card.get_meta(&"preview_loaded", false)):
			loaded_count += 1
	var pack_state := "已启用" if _is_private_pack_enabled() else "未启用"
	_status_label.text = "从 classic_original_assets 的 battlefield_visual 条目读取 4 张原版静态背景。素材包：%s，已加载：%d/4。" % [
		pack_state,
		loaded_count,
	]
	if loaded_count < PREVIEW_ENTRIES.size():
		_status_label.text += "\n缺失项会保留卡片位置，用于确认首页入口和素材绑定状态。"


func _build_preview_card(entry: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430.0, 265.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = String(entry.get("title", ""))
	title.add_theme_font_size_override("font_size", 18)
	layout.add_child(title)

	var preview := TextureRect.new()
	preview.custom_minimum_size = PREVIEW_TARGET_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layout.add_child(preview)

	var detail := Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 13)
	detail.modulate = Color(0.35, 0.35, 0.35, 1.0)
	layout.add_child(detail)

	var visual_id := StringName(entry.get("visual_id", StringName()))
	var visual_def := _resolve_battlefield_visual(visual_id)
	if visual_def == null:
		preview.texture = _make_placeholder_texture(Color("3d4a3d"), Color("c7d8ae"))
		detail.text = "%s\n未解析 battlefield_visual。" % String(visual_id)
		panel.set_meta(&"preview_loaded", false)
		return panel

	var texture_id := StringName(visual_def.get("texture_asset_id"))
	var texture := _resolve_texture(texture_id)
	if texture == null:
		preview.texture = _make_placeholder_texture(Color("4a3d3d"), Color("f0b8a8"))
		detail.text = "%s\n贴图未加载：%s" % [String(visual_id), String(texture_id)]
		panel.set_meta(&"preview_loaded", false)
		return panel

	preview.texture = texture
	detail.text = "%s\ntexture=%s size=%s offset=%s" % [
		String(visual_id),
		String(texture_id),
		str(texture.get_size()),
		str(Vector2(visual_def.get("draw_offset"))),
	]
	panel.set_meta(&"preview_loaded", true)
	return panel


func _resolve_battlefield_visual(visual_id: StringName) -> Resource:
	var asset_registry := _get_asset_registry()
	if asset_registry == null or not asset_registry.has_method("resolve_battlefield_visual"):
		return null
	return asset_registry.call("resolve_battlefield_visual", visual_id) as Resource


func _resolve_texture(texture_id: StringName) -> Texture2D:
	var asset_registry := _get_asset_registry()
	if asset_registry == null or not asset_registry.has_method("resolve_texture"):
		return null
	return asset_registry.call("resolve_texture", texture_id) as Texture2D


func _get_asset_registry() -> Node:
	return get_node_or_null("/root/AssetRegistry")


func _is_private_pack_enabled() -> bool:
	for pack in ExtensionPackCatalogRef.list_enabled_packs():
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_PACK_ID:
			return true
	return false


func _make_placeholder_texture(background_color: Color, mark_color: Color) -> Texture2D:
	var image := Image.create(int(PREVIEW_TARGET_SIZE.x), int(PREVIEW_TARGET_SIZE.y), false, Image.FORMAT_RGBA8)
	image.fill(background_color)
	var width := image.get_width()
	var height := image.get_height()
	for index in range(min(width, height)):
		image.set_pixel(index, index, mark_color)
		image.set_pixel(width - index - 1, index, mark_color)
	return ImageTexture.create_from_image(image)


func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file(SceneRegistry.MAIN_SCENE)
