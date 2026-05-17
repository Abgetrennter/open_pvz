extends Node2D

const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const BOARD_ORIGIN := Vector2(120.0, 135.0)
const SLOT_COUNT := 9
const LANE_COUNT := 5
const OPENPVZ_SLOT_SPACING := 80.0
const OPENPVZ_LANE_SPACING := 60.0
const PLANT_SLOT := 2
const PLANT_LANE := 2

@export var actor_scene_path := ""
@export var profile_path := ""
@export var display_name := ""
@export var status_text := ""
@export var demo_kind := ""
@export var actor_anchor_offset := Vector2.ZERO

var _status_label: Label = null
var _actor: Node2D = null
var _animation_player: AnimationPlayer = null
var _phase_elapsed := 0.0
var _phase_index := 0
var _wallnut_face: Sprite2D = null
var _wallnut_body_texture: Texture2D = null
var _wallnut_cracked1_texture: Texture2D = null
var _wallnut_cracked2_texture: Texture2D = null
var _wallnut_current_texture: Texture2D = null
var _wallnut_uses_actor_texture_override := false
var _blast_elapsed := 999.0


func _ready() -> void:
	_create_status_label()
	_load_actor()
	_set_status(status_text)
	_start_demo()


func _process(delta: float) -> void:
	_phase_elapsed += delta
	_blast_elapsed += delta
	match demo_kind:
		"wallnut":
			_update_wallnut()
		"potatomine":
			_update_potato_mine()
		"cherrybomb":
			_update_cherry_bomb()
		"squash":
			_update_squash()
		"fumeshroom":
			_update_fume_shroom()
		"tallnut":
			_update_damage_texture_cycle(&"normal", &"cracked1", &"cracked2")
		"pumpkin":
			_update_damage_texture_cycle(&"normal", &"damage1", &"damage3")
		"jalapeno":
			_update_jalapeno()
		"doomshroom":
			_update_doom_shroom()
	queue_redraw()


func _draw() -> void:
	_draw_board()
	match demo_kind:
		"wallnut":
			_draw_bite_marks()
		"potatomine":
			_draw_target(_slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(64.0, -22.0))
			_draw_blast(Color("f1c04a"), 52.0)
		"cherrybomb":
			_draw_targets_around()
			_draw_blast(Color("f05d42"), 116.0)
		"squash":
			_draw_target(_slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(78.0, -23.0), _phase_index == 3)
			_draw_squash_impact()
		"fumeshroom":
			_draw_fume_targets()
			_draw_fume_cloud()
		"tallnut":
			_draw_bite_marks()
		"pumpkin":
			_draw_pumpkin_target()
			_draw_bite_marks()
		"jalapeno":
			_draw_lane_targets()
			_draw_fire_lane()
		"doomshroom":
			_draw_targets_around()
			_draw_blast(Color("8a68d8"), 136.0)


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
	var packed_scene := _load_actor_scene()
	if packed_scene == null:
		return

	var instance := packed_scene.instantiate()
	_actor = instance as Node2D
	if _actor == null:
		instance.queue_free()
		_set_status("导入产物根节点不是 Node2D：%s" % actor_scene_path)
		return

	_actor.position = _slot_position(PLANT_LANE, PLANT_SLOT) + actor_anchor_offset
	add_child(_actor)
	_animation_player = _find_animation_player(_actor)
	_configure_wallnut()


func _load_actor_scene() -> PackedScene:
	if profile_path != "":
		if not ResourceLoader.exists(profile_path):
			_set_status("未找到 visual profile：%s\n请先运行 reanim_generate_composites.gd 生成 composite 输出。" % profile_path)
			return null
		var profile := ResourceLoader.load(profile_path)
		if profile == null or profile.get("actor_scene") == null:
			_set_status("visual profile 无法加载 actor_scene：%s" % profile_path)
			return null
		return profile.get("actor_scene") as PackedScene

	if not ResourceLoader.exists(actor_scene_path):
		_set_status("未找到导入产物：%s\n请先运行 reanim_import_one.gd 生成 actor。" % actor_scene_path)
		return null

	var packed_scene := ResourceLoader.load(actor_scene_path) as PackedScene
	if packed_scene == null:
		_set_status("导入产物无法作为 PackedScene 加载：%s" % actor_scene_path)
	return packed_scene


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _start_demo() -> void:
	_phase_elapsed = 0.0
	_phase_index = 0
	_blast_elapsed = 999.0
	match demo_kind:
		"wallnut":
			_play_animation(&"face", true)
		"potatomine":
			_play_animation(&"rise", false)
			_pause_at_start()
		"cherrybomb":
			_play_state(&"idle", &"idle", true)
		"squash":
			_play_state(&"idle", &"idle", true)
		"fumeshroom":
			_play_state(&"idle", &"idle", true)
		"tallnut":
			_play_state(&"idle", &"idle", true)
			_apply_actor_texture_override(&"normal")
		"pumpkin":
			_play_state(&"idle", &"all", true)
			_apply_actor_texture_override(&"normal")
		"jalapeno":
			_play_state(&"idle", &"idle", true)
		"doomshroom":
			_play_state(&"idle", &"idle", true)


func _update_wallnut() -> void:
	if _phase_elapsed >= 2.3:
		_phase_elapsed = 0.0
		_phase_index = (_phase_index + 1) % 3
	if _animation_player != null and _animation_player.current_animation != "face":
		_play_animation(&"face", true)
	_apply_wallnut_damage_texture()


func _update_potato_mine() -> void:
	match _phase_index:
		0:
			if _phase_elapsed >= 1.1:
				_set_phase(1)
				_play_animation(&"rise", false)
		1:
			if _phase_elapsed >= 1.75:
				_set_phase(2)
				_play_animation(&"armed", true)
		2:
			if _phase_elapsed >= 2.4:
				_set_phase(3)
				_play_animation(&"mashed", false)
				_blast_elapsed = 0.0
		3:
			if _phase_elapsed >= 1.2:
				_set_phase(0)
				_play_animation(&"rise", false)
				_pause_at_start()


func _update_cherry_bomb() -> void:
	match _phase_index:
		0:
			if _phase_elapsed >= 1.4:
				_set_phase(1)
				_play_animation(&"explode", false)
		1:
			if _phase_elapsed >= 0.64 and _blast_elapsed > 100.0:
				_blast_elapsed = 0.0
			if _phase_elapsed >= 1.4:
				_set_phase(2)
				_hide_actor(true)
		2:
			if _phase_elapsed >= 1.2:
				_hide_actor(false)
				_set_phase(0)
				_play_state(&"idle", &"idle", true)


func _update_squash() -> void:
	match _phase_index:
		0:
			if _phase_elapsed >= 1.0:
				_set_phase(1)
				_play_action(&"look_right", &"lookright")
		1:
			if _phase_elapsed >= 0.75:
				_set_phase(2)
				_play_action(&"jump_up", &"jumpup")
		2:
			if _phase_elapsed >= 1.15:
				_set_phase(3)
				_play_action(&"jump_down", &"jumpdown")
				_blast_elapsed = 0.0
		3:
			if _phase_elapsed >= 1.15:
				_set_phase(0)
				_play_state(&"idle", &"idle", true)


func _update_fume_shroom() -> void:
	match _phase_index:
		0:
			if _phase_elapsed >= 1.25:
				_set_phase(1)
				_play_action(&"shoot", &"shooting")
				_blast_elapsed = 0.0
		1:
			if _phase_elapsed >= 1.35:
				_set_phase(0)
				_play_state(&"idle", &"idle", true)


func _update_damage_texture_cycle(normal_set: StringName, middle_set: StringName, final_set: StringName) -> void:
	if _phase_elapsed >= 2.3:
		_phase_elapsed = 0.0
		_phase_index = (_phase_index + 1) % 3
	if _animation_player != null and not _animation_player.is_playing():
		_play_state(&"idle", &"idle", true)
	match _phase_index:
		0:
			_apply_actor_texture_override(normal_set)
		1:
			_apply_actor_texture_override(middle_set)
		2:
			_apply_actor_texture_override(final_set)


func _update_jalapeno() -> void:
	match _phase_index:
		0:
			if _phase_elapsed >= 1.15:
				_set_phase(1)
				_play_action(&"explode", &"explode")
				_blast_elapsed = 0.0
		1:
			if _phase_elapsed >= 1.2:
				_set_phase(2)
				_hide_actor(true)
		2:
			if _phase_elapsed >= 1.0:
				_hide_actor(false)
				_set_phase(0)
				_play_state(&"idle", &"idle", true)


func _update_doom_shroom() -> void:
	match _phase_index:
		0:
			if _phase_elapsed >= 1.35:
				_set_phase(1)
				_play_action(&"explode", &"explode")
				_blast_elapsed = 0.0
		1:
			if _phase_elapsed >= 1.8:
				_set_phase(2)
				_play_state(&"sleep", &"sleep", true)
		2:
			if _phase_elapsed >= 1.4:
				_set_phase(0)
				_play_state(&"idle", &"idle", true)


func _set_phase(next_phase: int) -> void:
	_phase_index = next_phase
	_phase_elapsed = 0.0


func _play_animation(animation_name: StringName, loop: bool) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_animation_player.play(animation_name)


func _play_state(state_id: StringName, fallback_animation: StringName, loop: bool) -> void:
	if _actor != null and _actor.has_method("play_state"):
		if bool(_actor.call("play_state", state_id)):
			return
	_play_animation(fallback_animation, loop)


func _play_action(action_id: StringName, fallback_animation: StringName) -> void:
	if _actor != null and _actor.has_method("play_action"):
		if bool(_actor.call("play_action", action_id)):
			return
	_play_animation(fallback_animation, false)


func _apply_actor_texture_override(set_id: StringName) -> void:
	if _actor != null and _actor.has_method("apply_texture_override_set"):
		_actor.call("apply_texture_override_set", set_id)


func _pause_at_start() -> void:
	if _animation_player == null:
		return
	_animation_player.seek(0.0, true)
	_animation_player.pause()


func _hide_actor(hidden: bool) -> void:
	if _actor != null:
		_actor.visible = not hidden


func _configure_wallnut() -> void:
	if demo_kind != "wallnut" or _actor == null:
		return
	_wallnut_uses_actor_texture_override = _actor.has_method("apply_texture_override_set")
	if _wallnut_uses_actor_texture_override:
		return
	_wallnut_face = _find_node_by_name(_actor, "anim_face") as Sprite2D
	_wallnut_body_texture = _load_texture("res://vendor/out_files/reanim/Wallnut_body.png")
	_wallnut_cracked1_texture = _load_texture("res://vendor/out_files/reanim/Wallnut_cracked1.png")
	_wallnut_cracked2_texture = _load_texture("res://vendor/out_files/reanim/Wallnut_cracked2.png")


func _apply_wallnut_damage_texture() -> void:
	if _wallnut_uses_actor_texture_override:
		match _phase_index:
			0:
				_actor.call("apply_texture_override_set", &"normal")
			1:
				_actor.call("apply_texture_override_set", &"cracked1")
			2:
				_actor.call("apply_texture_override_set", &"cracked2")
		return
	if _wallnut_face == null:
		return
	match _phase_index:
		0:
			if _wallnut_body_texture != null:
				_set_wallnut_face_texture(_wallnut_body_texture)
		1:
			if _wallnut_cracked1_texture != null:
				_set_wallnut_face_texture(_wallnut_cracked1_texture)
		2:
			if _wallnut_cracked2_texture != null:
				_set_wallnut_face_texture(_wallnut_cracked2_texture)


func _set_wallnut_face_texture(texture: Texture2D) -> void:
	if _wallnut_current_texture == texture:
		return
	_wallnut_current_texture = texture
	_wallnut_face.texture = texture
	_patch_animation_texture_key(&"face", NodePath("anim_face:texture"), texture)


func _patch_animation_texture_key(animation_name: StringName, track_path: NodePath, texture: Texture2D) -> void:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	for track_index in range(animation.get_track_count()):
		if animation.track_get_path(track_index) != track_path:
			continue
		for key_index in range(animation.track_get_key_count(track_index)):
			animation.track_set_key_value(track_index, key_index, texture)


func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _draw_board() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color("203928"))
	draw_rect(
		Rect2(
			BOARD_ORIGIN + Vector2(-40.0, -42.0),
			Vector2(OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 80.0, OPENPVZ_LANE_SPACING * float(LANE_COUNT - 1) + 84.0)
		),
		Color("24492e")
	)
	for lane_index in range(LANE_COUNT):
		var y := _lane_y(lane_index)
		draw_line(Vector2(BOARD_ORIGIN.x - 40.0, y), Vector2(BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 40.0, y), Color("6b9f54"), 3.0)
		if lane_index < LANE_COUNT - 1:
			draw_line(Vector2(BOARD_ORIGIN.x - 40.0, y + OPENPVZ_LANE_SPACING * 0.5), Vector2(BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 40.0, y + OPENPVZ_LANE_SPACING * 0.5), Color("315b37"), 1.0)
	for slot_index in range(SLOT_COUNT + 1):
		var x := BOARD_ORIGIN.x + float(slot_index) * OPENPVZ_SLOT_SPACING
		draw_line(Vector2(x, _lane_y(0) - 42.0), Vector2(x, _lane_y(LANE_COUNT - 1) + 42.0), Color("315b37"), 1.0)


func _draw_bite_marks() -> void:
	if _phase_index == 0:
		return
	var base := _slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(54.0, -42.0)
	var color := Color("d8c293") if _phase_index == 1 else Color("f2d6a2")
	draw_arc(base, 16.0, -0.8, 0.8, 10, color, 3.0)
	if _phase_index == 2:
		draw_arc(base + Vector2(-4.0, 15.0), 20.0, -0.6, 0.7, 10, color, 3.0)


func _draw_targets_around() -> void:
	for offset in [Vector2(82.0, -20.0), Vector2(118.0, -70.0), Vector2(122.0, 35.0)]:
		_draw_target(_slot_position(PLANT_LANE, PLANT_SLOT) + offset)


func _draw_target(center: Vector2, force_hidden := false) -> void:
	if force_hidden or _blast_elapsed < 0.35:
		return
	var body_rect := Rect2(center + Vector2(-11.0, -30.0), Vector2(22.0, 44.0))
	draw_rect(body_rect, Color("65705a"))
	draw_circle(center + Vector2(0.0, -42.0), 13.0, Color("879174"))
	draw_line(center + Vector2(-11.0, 10.0), center + Vector2(-20.0, 29.0), Color("65705a"), 3.0)
	draw_line(center + Vector2(11.0, 10.0), center + Vector2(20.0, 29.0), Color("65705a"), 3.0)


func _draw_blast(color: Color, radius: float) -> void:
	if _blast_elapsed > 0.5:
		return
	var t := clampf(_blast_elapsed / 0.5, 0.0, 1.0)
	var alpha := 1.0 - t
	var center := _slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(32.0, -36.0)
	var blast_color := Color(color.r, color.g, color.b, alpha * 0.55)
	draw_circle(center, lerpf(radius * 0.35, radius, t), blast_color)
	draw_arc(center, lerpf(radius * 0.45, radius * 1.05, t), 0.0, TAU, 48, Color(color.r, color.g, color.b, alpha), 4.0)


func _draw_squash_impact() -> void:
	if _blast_elapsed > 0.45:
		return
	var t := clampf(_blast_elapsed / 0.45, 0.0, 1.0)
	var center := _slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(78.0, 1.0)
	draw_circle(center, lerpf(12.0, 28.0, t), Color(0.35, 0.42, 0.32, (1.0 - t) * 0.7))
	draw_arc(center + Vector2(0.0, -10.0), lerpf(18.0, 42.0, t), 0.2, PI - 0.2, 24, Color(0.86, 0.78, 0.43, 1.0 - t), 3.0)


func _draw_fume_targets() -> void:
	for offset in [Vector2(92.0, -22.0), Vector2(146.0, -22.0), Vector2(200.0, -22.0)]:
		_draw_target(_slot_position(PLANT_LANE, PLANT_SLOT) + offset)


func _draw_fume_cloud() -> void:
	if _blast_elapsed > 0.55:
		return
	var t := clampf(_blast_elapsed / 0.55, 0.0, 1.0)
	var alpha := 1.0 - t
	var origin := _slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(42.0, -38.0)
	var rect := Rect2(origin, Vector2(lerpf(60.0, 220.0, t), 34.0))
	draw_rect(rect, Color(0.62, 0.74, 0.64, alpha * 0.42), false, 5.0)
	for i in range(4):
		var center := origin + Vector2(38.0 + float(i) * 46.0 + t * 20.0, 14.0 + sin(t * TAU + float(i)) * 6.0)
		draw_circle(center, lerpf(10.0, 22.0, t), Color(0.72, 0.84, 0.70, alpha * 0.45))


func _draw_pumpkin_target() -> void:
	_draw_target(_slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(11.0, -23.0))


func _draw_lane_targets() -> void:
	for slot_index in range(4, SLOT_COUNT):
		_draw_target(_slot_position(PLANT_LANE, slot_index) + Vector2(0.0, -22.0), _blast_elapsed < 0.55)


func _draw_fire_lane() -> void:
	if _blast_elapsed > 0.65:
		return
	var t := clampf(_blast_elapsed / 0.65, 0.0, 1.0)
	var alpha := 1.0 - t
	var y := _lane_y(PLANT_LANE)
	var start_x := BOARD_ORIGIN.x - 28.0
	var end_x := BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 28.0
	draw_rect(Rect2(Vector2(start_x, y - 24.0), Vector2(end_x - start_x, 48.0)), Color(0.94, 0.22, 0.06, alpha * 0.25))
	draw_line(Vector2(start_x, y), Vector2(end_x, y), Color(1.0, 0.68, 0.16, alpha), 7.0)


func _slot_position(lane: int, slot: int) -> Vector2:
	return Vector2(BOARD_ORIGIN.x + float(slot) * OPENPVZ_SLOT_SPACING + OPENPVZ_SLOT_SPACING * 0.5, _lane_y(lane))


func _lane_y(lane: int) -> float:
	return BOARD_ORIGIN.y + float(lane) * OPENPVZ_LANE_SPACING


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
