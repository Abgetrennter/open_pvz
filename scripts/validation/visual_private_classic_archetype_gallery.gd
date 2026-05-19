extends Node2D

const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")

const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const BOARD_ORIGIN := Vector2(58.0, 238.0)
const SLOT_COUNT := 5
const SLOT_SPACING := 168.0
const LANE_COUNT := 3
const LANE_SPACING := 70.0
const PLANT_LANE := 1
const PRIVATE_PACK_ID := &"classic_original_assets"

const GALLERY_ITEMS := [
	{
		"name": "Peashooter",
		"archetype_path": "res://data/combat/archetypes/plants/archetype_original_peashooter.tres",
		"kind": "shooter",
		"idle": &"idle",
		"action": &"shoot",
		"fallback_action": &"shooting",
	},
	{
		"name": "Sunflower",
		"archetype_path": "res://data/combat/archetypes/plants/archetype_original_sunflower.tres",
		"kind": "idle_only",
		"idle": &"idle",
	},
	{
		"name": "ThreePeater",
		"archetype_path": "res://data/combat/archetypes/plants/archetype_original_threepeater.tres",
		"kind": "shooter",
		"idle": &"idle",
		"fallback_idle": &"head_idle2",
		"action": &"shoot",
		"fallback_action": &"shooting2",
	},
	{
		"name": "Chomper",
		"archetype_path": "res://data/combat/archetypes/plants/archetype_original_chomper.tres",
		"kind": "chomper",
		"idle": &"idle",
	},
	{
		"name": "Squash",
		"archetype_path": "res://data/combat/archetypes/plants/archetype_original_squash.tres",
		"kind": "squash",
		"idle": &"idle",
	},
]

var _status_label: Label = null
var _ui_layer: CanvasLayer = null
var _entries: Array[Dictionary] = []
var _loaded_count := 0


func _ready() -> void:
	_create_status_label()
	_enable_private_pack_for_gallery()
	_load_gallery_items()
	_update_status_label()


func _process(delta: float) -> void:
	for entry in _entries:
		if entry.get("actor", null) == null:
			continue
		_update_entry(entry, delta)
	queue_redraw()


func _draw() -> void:
	_draw_board()
	for entry in _entries:
		if entry.get("actor", null) != null:
			continue
		var slot_index := int(entry.get("slot_index", 0))
		_draw_missing_marker(_slot_position(slot_index))


func _create_status_label() -> void:
	var canvas := CanvasLayer.new()
	_ui_layer = canvas
	add_child(canvas)
	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 18.0)
	_status_label.size = Vector2(912.0, 92.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("f3f0d6"))
	canvas.add_child(_status_label)


func _load_gallery_items() -> void:
	for index in range(GALLERY_ITEMS.size()):
		var item: Dictionary = GALLERY_ITEMS[index]
		var label := _create_item_label(index)
		var entry := {
			"slot_index": index,
			"label": label,
			"actor": null,
			"animation_player": null,
			"kind": String(item.get("kind", "")),
			"idle": StringName(item.get("idle", StringName())),
			"fallback_idle": StringName(item.get("fallback_idle", item.get("idle", StringName()))),
			"action": StringName(item.get("action", StringName())),
			"fallback_action": StringName(item.get("fallback_action", item.get("action", StringName()))),
			"elapsed": 0.0,
			"phase": 0,
		}
		_entries.append(entry)
		_load_single_item(item, entry)


func _enable_private_pack_for_gallery() -> void:
	ExtensionPackCatalogRef.enable_pack_for_current_session(PRIVATE_PACK_ID)
	var asset_registry := _get_asset_registry()
	if asset_registry != null and asset_registry.has_method("rebuild_registry"):
		asset_registry.call("rebuild_registry")
	if not VisualProfileRegistry.has(&"classic_original.entity.plant.peashooter.visual"):
		VisualProfileRegistry.rebuild_registry()


func _load_single_item(item: Dictionary, entry: Dictionary) -> void:
	var item_name := String(item.get("name", ""))
	var archetype_path := String(item.get("archetype_path", ""))
	var archetype := ResourceLoader.load(archetype_path)
	if archetype == null:
		_set_item_label(entry, item_name, StringName(), "未找到 archetype")
		return

	var profile_id := StringName(archetype.get("visual_profile_id"))
	if profile_id == StringName():
		_set_item_label(entry, item_name, profile_id, "未绑定 visual_profile_id")
		return

	var profile := _resolve_asset_registry_profile(profile_id)
	if profile == null and VisualProfileRegistry.has(profile_id):
		profile = VisualProfileRegistry.get_def(profile_id)
	if profile == null:
		_set_item_label(entry, item_name, profile_id, "profile 未注册")
		return

	if profile == null or profile.get("actor_scene") == null:
		_set_item_label(entry, item_name, profile_id, "profile 缺少 actor_scene")
		return

	var packed_scene := profile.get("actor_scene") as PackedScene
	var instance := packed_scene.instantiate()
	var actor := instance as Node2D
	if actor == null:
		instance.queue_free()
		_set_item_label(entry, item_name, profile_id, "actor 根节点不是 Node2D")
		return

	actor.position = _slot_position(int(entry.get("slot_index", 0)))
	add_child(actor)
	entry["actor"] = actor
	entry["animation_player"] = _find_animation_player(actor)
	_loaded_count += 1
	_set_item_label(entry, item_name, profile_id, "已绑定")
	_play_state(entry, StringName(entry.get("idle", StringName())), StringName(entry.get("fallback_idle", StringName())), true)


func _resolve_asset_registry_profile(profile_id: StringName) -> Resource:
	var asset_registry := _get_asset_registry()
	if asset_registry == null or not asset_registry.has_method("resolve_visual_profile"):
		return null
	return asset_registry.call("resolve_visual_profile", profile_id) as Resource


func _get_asset_registry() -> Node:
	return get_node_or_null("/root/AssetRegistry")


func _create_item_label(slot_index: int) -> Label:
	var label := Label.new()
	label.position = _slot_position(slot_index) + Vector2(-78.0, 58.0)
	label.size = Vector2(156.0, 86.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("e6e8d0"))
	if _ui_layer != null:
		_ui_layer.add_child(label)
	else:
		add_child(label)
	return label


func _set_item_label(entry: Dictionary, item_name: String, profile_id: StringName, state_text: String) -> void:
	var label := entry.get("label", null) as Label
	if label == null:
		return
	var profile_text := "-" if profile_id == StringName() else String(profile_id)
	label.text = "%s\n%s\n%s" % [item_name, state_text, profile_text]


func _update_entry(entry: Dictionary, delta: float) -> void:
	entry["elapsed"] = float(entry.get("elapsed", 0.0)) + delta
	match String(entry.get("kind", "")):
		"shooter":
			_update_shooter(entry)
		"chomper":
			_update_chomper(entry)
		"squash":
			_update_squash(entry)
		_:
			if _animation_stopped(entry):
				_play_state(entry, StringName(entry.get("idle", StringName())), StringName(entry.get("fallback_idle", StringName())), true)


func _update_shooter(entry: Dictionary) -> void:
	var elapsed := float(entry.get("elapsed", 0.0))
	var phase := int(entry.get("phase", 0))
	if phase == 0 and elapsed >= 1.25:
		entry["phase"] = 1
		entry["elapsed"] = 0.0
		_play_action(entry, StringName(entry.get("action", StringName())), StringName(entry.get("fallback_action", StringName())))
	elif phase == 1 and elapsed >= 0.85:
		entry["phase"] = 0
		entry["elapsed"] = 0.0
		_play_state(entry, StringName(entry.get("idle", StringName())), StringName(entry.get("fallback_idle", StringName())), true)


func _update_chomper(entry: Dictionary) -> void:
	var elapsed := float(entry.get("elapsed", 0.0))
	var phase := int(entry.get("phase", 0))
	match phase:
		0:
			if elapsed >= 1.35:
				_set_phase(entry, 1)
				_play_action(entry, &"devour", &"bite")
		1:
			if elapsed >= 1.05:
				_set_phase(entry, 2)
				_play_state(entry, &"digesting", &"chew", true)
		2:
			if elapsed >= 1.25:
				_set_phase(entry, 3)
				_play_action(entry, &"swallow", &"swallow")
		3:
			if elapsed >= 1.1:
				_set_phase(entry, 0)
				_play_state(entry, &"idle", &"idle", true)


func _update_squash(entry: Dictionary) -> void:
	var elapsed := float(entry.get("elapsed", 0.0))
	var phase := int(entry.get("phase", 0))
	match phase:
		0:
			if elapsed >= 1.0:
				_set_phase(entry, 1)
				_play_action(entry, &"look_right", &"lookright")
		1:
			if elapsed >= 0.75:
				_set_phase(entry, 2)
				_play_action(entry, &"jump_up", &"jumpup")
		2:
			if elapsed >= 1.05:
				_set_phase(entry, 3)
				_play_action(entry, &"jump_down", &"jumpdown")
		3:
			if elapsed >= 1.1:
				_set_phase(entry, 0)
				_play_state(entry, &"idle", &"idle", true)


func _set_phase(entry: Dictionary, phase: int) -> void:
	entry["phase"] = phase
	entry["elapsed"] = 0.0


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


func _update_status_label() -> void:
	var private_pack_enabled := _is_private_pack_enabled()
	var pack_state := "已启用" if private_pack_enabled else "未启用"
	var message := "原版植物私有素材正式匹配展示：%d/%d 个 actor 已从 CombatArchetype.visual_profile_id 加载。classic_original_assets：%s。" % [
		_loaded_count,
		GALLERY_ITEMS.size(),
		pack_state,
	]
	if not private_pack_enabled:
		message += "\n请使用 --include-classic-original-assets 启动后查看真实素材。"
	_status_label.text = message


func _is_private_pack_enabled() -> bool:
	for pack in ExtensionPackCatalogRef.list_enabled_packs(&"visual_profiles"):
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_PACK_ID:
			return true
	return false


func _draw_board() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color("203928"))
	draw_rect(
		Rect2(
			BOARD_ORIGIN + Vector2(-24.0, -36.0),
			Vector2(SLOT_SPACING * float(SLOT_COUNT) + 48.0, LANE_SPACING * float(LANE_COUNT - 1) + 72.0)
		),
		Color("24492e")
	)
	for lane_index in range(LANE_COUNT):
		var y := _lane_y(lane_index)
		draw_line(Vector2(BOARD_ORIGIN.x - 24.0, y), Vector2(BOARD_ORIGIN.x + SLOT_SPACING * float(SLOT_COUNT) + 24.0, y), Color("6b9f54"), 3.0)
		if lane_index < LANE_COUNT - 1:
			draw_line(Vector2(BOARD_ORIGIN.x - 24.0, y + LANE_SPACING * 0.5), Vector2(BOARD_ORIGIN.x + SLOT_SPACING * float(SLOT_COUNT) + 24.0, y + LANE_SPACING * 0.5), Color("315b37"), 1.0)
	for slot_index in range(SLOT_COUNT + 1):
		var x := BOARD_ORIGIN.x + float(slot_index) * SLOT_SPACING
		draw_line(Vector2(x, _lane_y(0) - 36.0), Vector2(x, _lane_y(LANE_COUNT - 1) + 36.0), Color("315b37"), 1.0)
	for slot_index in range(SLOT_COUNT):
		var center := _slot_position(slot_index)
		draw_circle(center, 3.0, Color("e7d36a"))


func _draw_missing_marker(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, -34.0), 16.0, Color("7a605f"))
	draw_line(center + Vector2(-18.0, -12.0), center + Vector2(18.0, -56.0), Color("f0b8a8"), 3.0)
	draw_line(center + Vector2(18.0, -12.0), center + Vector2(-18.0, -56.0), Color("f0b8a8"), 3.0)


func _slot_position(slot: int) -> Vector2:
	return Vector2(BOARD_ORIGIN.x + float(slot) * SLOT_SPACING + SLOT_SPACING * 0.5, _lane_y(PLANT_LANE))


func _lane_y(lane: int) -> float:
	return BOARD_ORIGIN.y + float(lane) * LANE_SPACING
