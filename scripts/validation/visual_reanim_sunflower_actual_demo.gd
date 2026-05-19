extends Node2D

const ExtensionPackCatalogRef = preload("res://scripts/core/runtime/extension_pack_catalog.gd")
const VisualProfileDemoLoaderRef = preload("res://scripts/validation/visual_profile_demo_loader.gd")

const PROFILE_ID := &"classic_original.entity.plant.sunflower.visual"
const PRIVATE_CLASSIC_PACK_ID := &"classic_original_assets"
const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const BOARD_ORIGIN := Vector2(120.0, 135.0)
const SLOT_COUNT := 9
const LANE_COUNT := 5
const OPENPVZ_SLOT_SPACING := 80.0
const OPENPVZ_LANE_SPACING := 60.0
const PLANT_SLOT := 2
const PLANT_LANE := 2
const SOURCE_FPS := 12.0
const IDLE_START_FRAME := 4
const IDLE_END_FRAME := 28
const BLINK_HEAD_OFFSET := Vector2(12.8, 6.2)
const BLINK_INTERVAL_SECONDS := 2.4
const BLINK_FRAME_SECONDS := 1.0 / SOURCE_FPS
const SUN_PRODUCE_INTERVAL_SECONDS := 2.8
const SUN_LIFETIME_SECONDS := 2.2
const SUN_RISE_DISTANCE := 44.0

var _status_label: Label = null
var _actor: Node2D = null
var _animation_player: AnimationPlayer = null
var _idle_animation_name: StringName = &""
var _idle_start_seconds := 0.0
var _idle_end_seconds := 0.0
var _idle_elapsed := 0.0
var _head_sprite: Sprite2D = null
var _blink_track_sprite: Sprite2D = null
var _blink_sprite: Sprite2D = null
var _blink1_texture: Texture2D = null
var _blink2_texture: Texture2D = null
var _blink_elapsed := 0.0
var _produce_elapsed := 0.0
var _suns: Array[Dictionary] = []


func _ready() -> void:
	_create_status_label()
	_load_actor()
	if _actor != null:
		_set_status("Reanim Sunflower 实际演示：通过 VisualProfileRegistry 加载私有素材包 profile，周期性产阳视觉。")


func _process(delta: float) -> void:
	_update_idle_subrange(delta)
	_update_blink_overlay(delta)

	_produce_elapsed += delta
	if _produce_elapsed >= SUN_PRODUCE_INTERVAL_SECONDS:
		_produce_elapsed = 0.0
		_spawn_sun()

	for i in range(_suns.size() - 1, -1, -1):
		var sun := _suns[i]
		sun["age"] = float(sun.get("age", 0.0)) + delta
		_suns[i] = sun
		if float(sun["age"]) >= SUN_LIFETIME_SECONDS:
			_suns.remove_at(i)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color("203928"))
	draw_rect(Rect2(BOARD_ORIGIN + Vector2(-40.0, -42.0), Vector2(OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 80.0, OPENPVZ_LANE_SPACING * float(LANE_COUNT - 1) + 84.0)), Color("24492e"))

	for lane_index in range(LANE_COUNT):
		var y := _lane_y(lane_index)
		draw_line(Vector2(BOARD_ORIGIN.x - 40.0, y), Vector2(BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 40.0, y), Color("6b9f54"), 3.0)
		if lane_index < LANE_COUNT - 1:
			draw_line(Vector2(BOARD_ORIGIN.x - 40.0, y + OPENPVZ_LANE_SPACING * 0.5), Vector2(BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 40.0, y + OPENPVZ_LANE_SPACING * 0.5), Color("315b37"), 1.0)

	for slot_index in range(SLOT_COUNT + 1):
		var x := BOARD_ORIGIN.x + float(slot_index) * OPENPVZ_SLOT_SPACING
		draw_line(Vector2(x, _lane_y(0) - 42.0), Vector2(x, _lane_y(LANE_COUNT - 1) + 42.0), Color("315b37"), 1.0)

	for sun in _suns:
		_draw_sun(sun)


func _create_status_label() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 18.0)
	_status_label.size = Vector2(900.0, 72.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("f3f0d6"))
	canvas.add_child(_status_label)


func _load_actor() -> void:
	var result := VisualProfileDemoLoaderRef.load_actor_scene(PROFILE_ID)
	var packed_scene := result.get("actor_scene", null) as PackedScene
	if packed_scene == null:
		_set_status("%s\n请启用本地私有素材包：--include-classic-original-assets。" % String(result.get("error", "")))
		return

	var instance := packed_scene.instantiate()
	_actor = instance as Node2D
	if _actor == null:
		instance.queue_free()
		_set_status("导入产物根节点不是 Node2D：%s" % String(result.get("source", "")))
		return

	_actor.position = _slot_position(PLANT_LANE, PLANT_SLOT)
	_actor.scale = Vector2.ONE
	add_child(_actor)

	_animation_player = _find_animation_player(_actor)
	_configure_blink_overlay()
	_play_idle()


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _play_idle() -> void:
	if _animation_player == null:
		return
	if _animation_player.has_animation(&"idle"):
		_idle_animation_name = &"idle"
	elif _animation_player.has_animation(&"all"):
		_idle_animation_name = &"all"
	else:
		var animation_list := _animation_player.get_animation_list()
		if not animation_list.is_empty():
			_idle_animation_name = StringName(animation_list[0])
	if _idle_animation_name == &"":
		return
	var animation := _animation_player.get_animation(_idle_animation_name)
	if animation != null and _idle_animation_name == &"all":
		animation.loop_mode = Animation.LOOP_NONE
		_idle_start_seconds = float(IDLE_START_FRAME) / SOURCE_FPS
		_idle_end_seconds = minf(animation.length, float(IDLE_END_FRAME + 1) / SOURCE_FPS)
	else:
		_idle_start_seconds = 0.0
		_idle_end_seconds = animation.length if animation != null else 0.0
	_idle_elapsed = 0.0
	_animation_player.play(_idle_animation_name)
	_animation_player.seek(_idle_start_seconds, true)
	if _idle_animation_name == &"all":
		_animation_player.pause()


func _update_idle_subrange(delta: float) -> void:
	if _animation_player == null or _idle_animation_name == &"":
		return
	var animation := _animation_player.get_animation(_idle_animation_name)
	if animation == null:
		return
	if _idle_start_seconds <= 0.0:
		return
	var idle_duration := maxf(animation.step, _idle_end_seconds - _idle_start_seconds)
	_idle_elapsed = fmod(_idle_elapsed + delta, idle_duration)
	if _animation_player.current_animation != String(_idle_animation_name):
		_animation_player.play(_idle_animation_name)
		_animation_player.pause()
	_animation_player.seek(_idle_start_seconds + _idle_elapsed, true)


func _configure_blink_overlay() -> void:
	if _actor == null:
		return
	_head_sprite = _find_node_by_name(_actor, "anim_idle") as Sprite2D
	_blink_track_sprite = _find_node_by_name(_actor, "anim_blink") as Sprite2D
	if _head_sprite == null or _blink_track_sprite == null:
		return
	_blink_track_sprite.visible = false
	_blink_sprite = Sprite2D.new()
	_blink_sprite.name = "BlinkOverlay"
	_blink_sprite.centered = false
	_blink_sprite.visible = false
	_head_sprite.get_parent().add_child(_blink_sprite)
	_blink1_texture = _load_texture(_private_source_texture_path("SunFlower_blink1.png"))
	_blink2_texture = _load_texture(_private_source_texture_path("SunFlower_blink2.png"))


func _update_blink_overlay(delta: float) -> void:
	if _blink_sprite == null or _blink1_texture == null or _blink2_texture == null:
		return
	_blink_elapsed = fmod(_blink_elapsed + delta, BLINK_INTERVAL_SECONDS)
	var frame_index := int(_blink_elapsed / BLINK_FRAME_SECONDS)
	if frame_index == 0:
		_show_blink_frame(_blink2_texture, 0.0)
	elif frame_index == 1:
		_show_blink_frame(_blink1_texture, 0.2)
	elif frame_index == 2:
		_show_blink_frame(_blink2_texture, 0.0)
	else:
		_blink_sprite.visible = false


func _show_blink_frame(texture: Texture2D, y_offset: float) -> void:
	if _head_sprite == null:
		return
	_blink_sprite.visible = true
	_blink_sprite.position = _head_sprite.position + BLINK_HEAD_OFFSET + Vector2(0.0, y_offset)
	_blink_sprite.scale = _head_sprite.scale
	_blink_sprite.rotation = _head_sprite.rotation
	_blink_sprite.skew = _head_sprite.skew
	_blink_sprite.self_modulate = Color.WHITE
	_blink_sprite.texture = texture


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _private_source_texture_path(file_name: String) -> String:
	for pack in ExtensionPackCatalogRef.list_enabled_packs(&"visual_profiles"):
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_CLASSIC_PACK_ID:
			return String(pack.get("root_path", "")).path_join("sources/reanim/%s" % file_name)
	return ""


func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _spawn_sun() -> void:
	var base_position := _slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(16.0, -74.0)
	_suns.append({
		"age": 0.0,
		"position": base_position,
	})


func _draw_sun(sun: Dictionary) -> void:
	var age := float(sun.get("age", 0.0))
	var t := clampf(age / SUN_LIFETIME_SECONDS, 0.0, 1.0)
	var position := sun.get("position", Vector2.ZERO) as Vector2
	position.y -= SUN_RISE_DISTANCE * sin(t * PI)
	var alpha := 1.0 - maxf(0.0, t - 0.65) / 0.35
	var outer := Color(1.0, 0.76, 0.14, alpha)
	var inner := Color(1.0, 0.96, 0.35, alpha)
	for ray_index in range(10):
		var angle := TAU * float(ray_index) / 10.0
		var from := position + Vector2(cos(angle), sin(angle)) * 14.0
		var to := position + Vector2(cos(angle), sin(angle)) * 21.0
		draw_line(from, to, outer, 3.0)
	draw_circle(position, 16.0, outer)
	draw_circle(position, 9.0, inner)


func _slot_position(lane: int, slot: int) -> Vector2:
	return Vector2(BOARD_ORIGIN.x + float(slot) * OPENPVZ_SLOT_SPACING + OPENPVZ_SLOT_SPACING * 0.5, _lane_y(lane))


func _lane_y(lane: int) -> float:
	return BOARD_ORIGIN.y + float(lane) * OPENPVZ_LANE_SPACING


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
