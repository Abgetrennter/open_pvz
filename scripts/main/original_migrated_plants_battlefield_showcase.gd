extends Node2D
class_name OriginalMigratedPlantsBattlefieldShowcase

const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")

const PRIVATE_PACK_ID := &"classic_original_assets"
const BACKGROUND_VISUAL_ID := &"classic_original.battlefield.grass_day.visual"
const ORIGINAL_LAWN_XMIN := 40.0
const ORIGINAL_LAWN_YMIN := 80.0
const ORIGINAL_CELL_WIDTH := 80.0
const ORIGINAL_GRASS_CELL_HEIGHT := 100.0
const ORIGINAL_PLANT_CENTER_OFFSET := Vector2(40.0, 40.0)
const UI_PANEL_MARGIN := 12.0
const UI_PANEL_SIZE := Vector2(370.0, 112.0)
const ACTOR_SPECS := [
	{
		"display_name": "Peashooter",
		"archetype_id": &"archetype_original_peashooter",
		"visual_profile_id": &"classic_original.entity.plant.peashooter.visual",
		"grid_col": 1,
		"grid_row": 0,
		"idle": &"idle",
	},
	{
		"display_name": "Sunflower",
		"archetype_id": &"archetype_original_sunflower",
		"visual_profile_id": &"classic_original.entity.plant.sunflower.visual",
		"grid_col": 2,
		"grid_row": 1,
		"idle": &"idle",
	},
	{
		"display_name": "ThreePeater",
		"archetype_id": &"archetype_original_threepeater",
		"visual_profile_id": &"classic_original.entity.plant.threepeater.visual",
		"grid_col": 3,
		"grid_row": 2,
		"idle": &"idle",
		"fallback_idle": &"head_idle2",
	},
	{
		"display_name": "Chomper",
		"archetype_id": &"archetype_original_chomper",
		"visual_profile_id": &"classic_original.entity.plant.chomper.visual",
		"grid_col": 4,
		"grid_row": 3,
		"idle": &"idle",
		"action": &"devour",
		"fallback_action": &"bite",
		"action_interval": 2.0,
		"action_duration": 1.0,
	},
	{
		"display_name": "Squash",
		"archetype_id": &"archetype_original_squash",
		"visual_profile_id": &"classic_original.entity.plant.squash.visual",
		"grid_col": 5,
		"grid_row": 4,
		"idle": &"idle",
		"action": &"look_right",
		"fallback_action": &"lookright",
		"action_interval": 2.4,
		"action_duration": 0.75,
	},
]

var _actor_layer: Node2D = null
var _ui_layer: CanvasLayer = null
var _status_label: Label = null
var _entries: Array[Dictionary] = []


func _ready() -> void:
	_enable_private_pack_for_showcase()
	_build_background()
	_build_actor_layer()
	_build_ui()
	_load_actors()
	_update_status()


func _process(delta: float) -> void:
	for entry in _entries:
		_update_actor_entry(entry, delta)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		_return_to_main_menu()


func get_showcase_actor_specs() -> Array:
	return ACTOR_SPECS.duplicate(true)


func get_background_visual_id() -> StringName:
	return BACKGROUND_VISUAL_ID


func _enable_private_pack_for_showcase() -> void:
	ExtensionPackCatalogRef.enable_pack_for_current_session(PRIVATE_PACK_ID)
	var asset_registry := _get_asset_registry()
	if asset_registry != null and asset_registry.has_method("rebuild_registry"):
		asset_registry.call("rebuild_registry")
	if not VisualProfileRegistry.has(&"classic_original.entity.plant.peashooter.visual"):
		VisualProfileRegistry.rebuild_registry()


func _build_background() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "BattlefieldBackground"
	sprite.centered = false
	sprite.position = Vector2(-220.0, 0.0)
	sprite.z_index = 0
	var visual_def := _resolve_battlefield_visual(BACKGROUND_VISUAL_ID)
	if visual_def != null:
		sprite.position = Vector2(visual_def.get("draw_offset"))
		sprite.texture = _resolve_texture(StringName(visual_def.get("texture_asset_id")))
	add_child(sprite)


func _build_actor_layer() -> void:
	_actor_layer = Node2D.new()
	_actor_layer.name = "MigratedPlantActorLayer"
	_actor_layer.z_index = 100
	add_child(_actor_layer)


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 20
	add_child(_ui_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(800.0 - UI_PANEL_SIZE.x - UI_PANEL_MARGIN, UI_PANEL_MARGIN)
	panel.size = UI_PANEL_SIZE
	_ui_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "原版植物实景展示"
	title.add_theme_font_size_override("font_size", 20)
	layout.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	layout.add_child(_status_label)

	var back_button := Button.new()
	back_button.text = "返回主面板 (Esc)"
	back_button.pressed.connect(_return_to_main_menu)
	layout.add_child(back_button)


func _load_actors() -> void:
	for spec in ACTOR_SPECS:
		var entry := _make_entry(spec)
		_entries.append(entry)
		var profile := _resolve_visual_profile(StringName(spec.get("visual_profile_id", StringName())))
		if profile == null:
			entry["state"] = "profile missing"
			continue
		var packed_scene := profile.get("actor_scene") as PackedScene
		if packed_scene == null:
			entry["state"] = "actor missing"
			continue
		var instance := packed_scene.instantiate()
		var actor := instance as Node2D
		if actor == null:
			instance.queue_free()
			entry["state"] = "actor root invalid"
			continue
		actor.name = "%sActor" % String(spec.get("display_name", "Plant"))
		var original_entity_position := _original_grid_entity_position(spec)
		actor.position = _actor_position_for_spec(spec, profile)
		actor.set_meta(&"archetype_id", StringName(spec.get("archetype_id", StringName())))
		actor.set_meta(&"visual_profile_id", StringName(spec.get("visual_profile_id", StringName())))
		actor.set_meta(&"pack_id", _profile_pack_id(profile))
		actor.set_meta(&"original_entity_position", original_entity_position)
		actor.set_meta(&"original_grid_col", int(spec.get("grid_col", -1)))
		actor.set_meta(&"original_grid_row", int(spec.get("grid_row", -1)))
		_actor_layer.add_child(actor)
		entry["actor"] = actor
		entry["animation_player"] = _find_animation_player(actor)
		entry["state"] = "loaded"
		_play_state(entry, StringName(entry.get("idle", StringName())), StringName(entry.get("fallback_idle", StringName())), true)


func _make_entry(spec: Dictionary) -> Dictionary:
	return {
		"spec": spec,
		"actor": null,
		"animation_player": null,
		"idle": StringName(spec.get("idle", StringName())),
		"fallback_idle": StringName(spec.get("fallback_idle", spec.get("idle", StringName()))),
		"action": StringName(spec.get("action", StringName())),
		"fallback_action": StringName(spec.get("fallback_action", spec.get("action", StringName()))),
		"action_interval": float(spec.get("action_interval", 0.0)),
		"action_duration": float(spec.get("action_duration", 0.0)),
		"elapsed": 0.0,
		"phase": 0,
		"state": "pending",
	}


func _actor_position_for_spec(spec: Dictionary, profile: Resource) -> Vector2:
	return _original_grid_entity_position(spec) + _profile_ground_offset(profile)


func _original_grid_entity_position(spec: Dictionary) -> Vector2:
	var grid_col := int(spec.get("grid_col", 0))
	var grid_row := int(spec.get("grid_row", 0))
	return Vector2(
		ORIGINAL_LAWN_XMIN + float(grid_col) * ORIGINAL_CELL_WIDTH,
		ORIGINAL_LAWN_YMIN + float(grid_row) * ORIGINAL_GRASS_CELL_HEIGHT
	) + ORIGINAL_PLANT_CENTER_OFFSET


func _profile_ground_offset(profile: Resource) -> Vector2:
	if profile == null:
		return Vector2.ZERO
	var ground_offset_value: Variant = profile.get("ground_offset")
	if ground_offset_value is Vector2:
		return ground_offset_value
	return Vector2.ZERO


func _update_actor_entry(entry: Dictionary, delta: float) -> void:
	var actor := entry.get("actor", null) as Node
	if actor == null:
		return
	var action := StringName(entry.get("action", StringName()))
	if action == StringName():
		if _animation_stopped(entry):
			_play_state(entry, StringName(entry.get("idle", StringName())), StringName(entry.get("fallback_idle", StringName())), true)
		return
	entry["elapsed"] = float(entry.get("elapsed", 0.0)) + delta
	var phase := int(entry.get("phase", 0))
	if phase == 0 and float(entry.get("elapsed", 0.0)) >= float(entry.get("action_interval", 0.0)):
		entry["phase"] = 1
		entry["elapsed"] = 0.0
		_play_action(entry, action, StringName(entry.get("fallback_action", StringName())))
	elif phase == 1 and float(entry.get("elapsed", 0.0)) >= float(entry.get("action_duration", 0.0)):
		entry["phase"] = 0
		entry["elapsed"] = 0.0
		_play_state(entry, StringName(entry.get("idle", StringName())), StringName(entry.get("fallback_idle", StringName())), true)


func _play_state(entry: Dictionary, state_id: StringName, fallback_animation: StringName, loop: bool) -> void:
	var actor := entry.get("actor", null) as Node
	if actor != null and actor.has_method("play_state"):
		if bool(actor.call("play_state", state_id)):
			return
	_play_animation(entry, fallback_animation, loop)


func _play_action(entry: Dictionary, action_id: StringName, fallback_animation: StringName) -> void:
	var actor := entry.get("actor", null) as Node
	if actor != null and actor.has_method("play_action"):
		if bool(actor.call("play_action", action_id)):
			return
	_play_animation(entry, fallback_animation, false)


func _play_animation(entry: Dictionary, animation_name: StringName, loop: bool) -> void:
	var animation_player := entry.get("animation_player", null) as AnimationPlayer
	if animation_player == null or animation_name == StringName():
		return
	if not animation_player.has_animation(animation_name):
		return
	var animation := animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	animation_player.play(animation_name)


func _animation_stopped(entry: Dictionary) -> bool:
	var animation_player := entry.get("animation_player", null) as AnimationPlayer
	return animation_player != null and not animation_player.is_playing()


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _update_status() -> void:
	if _status_label == null:
		return
	var loaded_count := 0
	for entry in _entries:
		if String(entry.get("state", "")) == "loaded":
			loaded_count += 1
	var pack_state := "已启用" if _is_private_pack_enabled() else "未启用"
	_status_label.text = "草坪背景上展示已迁移成功的 5 株原版植物 actor。classic_original_assets：%s，已加载：%d/5。" % [
		pack_state,
		loaded_count,
	]


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


func _resolve_visual_profile(profile_id: StringName) -> Resource:
	var asset_registry := _get_asset_registry()
	if asset_registry != null and asset_registry.has_method("resolve_visual_profile"):
		var profile := asset_registry.call("resolve_visual_profile", profile_id) as Resource
		if profile != null:
			return profile
	if VisualProfileRegistry.has(profile_id):
		return VisualProfileRegistry.get_def(profile_id)
	return null


func _profile_pack_id(profile: Resource) -> StringName:
	if profile != null and profile.has_meta(&"asset_registry_source"):
		var source: Variant = profile.get_meta(&"asset_registry_source")
		if source is Dictionary:
			return StringName((source as Dictionary).get("pack_id", StringName()))
	return StringName()


func _get_asset_registry() -> Node:
	return get_node_or_null("/root/AssetRegistry")


func _is_private_pack_enabled() -> bool:
	for pack in ExtensionPackCatalogRef.list_enabled_packs(&"visual_profiles"):
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_PACK_ID:
			return true
	return false


func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file(SceneRegistry.MAIN_SCENE)
