extends Node2D

const ACTOR_SCENE_PATH := "res://vendor/out_files/_openpvz_import/threepeater/actor.tscn"
const SOURCE_REANIM_PATH := "res://vendor/out_files/reanim/ThreePeater.reanim"
const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const BOARD_ORIGIN := Vector2(120.0, 135.0)
const SLOT_COUNT := 9
const LANE_COUNT := 5
const OPENPVZ_SLOT_SPACING := 80.0
const OPENPVZ_LANE_SPACING := 60.0
const ORIGINAL_SLOT_WIDTH := 80.0
const ACTOR_SCALE_VALUE := OPENPVZ_SLOT_SPACING / ORIGINAL_SLOT_WIDTH
const ACTOR_ANCHOR_OFFSET := Vector2(-44.0, -96.0)
const PLANT_SLOT := 1
const PLANT_LANE := 2
const TARGET_SLOT := 7
const PEA_SPEED_SLOTS_PER_SEC := 4.1625
const FIRE_INTERVAL_SECONDS := 1.5
const REANIM_SOURCE_FPS := 12.0
const BODY_START_FRAME := 124
const BODY_END_FRAME := 148
const IDLE_RATE_SCALE := 17.0 / REANIM_SOURCE_FPS
const SHOOTING_RATE_SCALE := 20.0 / REANIM_SOURCE_FPS
const REANIM_BLEND_SECONDS := 0.1
const PEA_RELEASE_SECONDS := 0.34
const PEA_RADIUS := 7.0

var _status_label: Label = null
var _body_actor: Node2D = null
var _body_animation_player: AnimationPlayer = null
var _body_base_sprite_states: Dictionary = {}
var _body_track_frames: Dictionary = {}
var _body_frame_elapsed := 0.0
var _fire_elapsed := 0.0
var _shooting_elapsed := 0.0
var _shooting_duration := 0.0
var _pending_pea_elapsed := 0.0
var _is_shooting := false
var _has_pending_peas := false
var _peas: Array[Dictionary] = []
var _head_parts: Array[Dictionary] = [
	{
		"id": 1,
		"lane": PLANT_LANE + 1,
		"anchor": "anim_head1",
		"idle": &"head_idle1",
		"shooting": &"shooting1",
		"mouth": "ThreePeater_mouth1",
	},
	{
		"id": 2,
		"lane": PLANT_LANE,
		"anchor": "anim_head2",
		"idle": &"head_idle2",
		"shooting": &"shooting2",
		"mouth": "ThreePeater_mouth2",
	},
	{
		"id": 3,
		"lane": PLANT_LANE - 1,
		"anchor": "anim_head3",
		"idle": &"head_idle3",
		"shooting": &"shooting3",
		"mouth": "ThreePeater_mouth3",
	},
]


func _ready() -> void:
	_create_status_label()
	_load_actor()
	_set_status("Reanim ThreePeater 实际演示：三头 attachment，shooting1/2/3 同步发射到三条 lane。")


func _process(delta: float) -> void:
	_fire_elapsed += delta
	if _fire_elapsed >= FIRE_INTERVAL_SECONDS:
		_fire_elapsed = 0.0
		_fire_three_peas()

	if _is_shooting:
		_shooting_elapsed += delta
		if _shooting_elapsed >= _shooting_duration:
			_is_shooting = false
			_play_head_idle()

	if _has_pending_peas:
		_pending_pea_elapsed += delta
		if _pending_pea_elapsed >= PEA_RELEASE_SECONDS:
			_has_pending_peas = false
			_spawn_three_peas()

	_update_body_animation(delta)
	_update_head_attachments()
	_apply_visibility_masks()
	_update_peas(delta)
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

	for part in _head_parts:
		_draw_target(int(part["lane"]))
	for pea in _peas:
		var position := pea.get("position", Vector2.ZERO) as Vector2
		draw_circle(position, PEA_RADIUS, Color("9be33b"))
		draw_circle(position + Vector2(-2.0, -2.0), PEA_RADIUS * 0.35, Color("e9ff8f"))


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
	if not ResourceLoader.exists(ACTOR_SCENE_PATH):
		_set_status("未找到导入产物：%s\n请先运行 reanim_import_one.gd 生成 ThreePeater actor。" % ACTOR_SCENE_PATH)
		return

	var packed_scene := ResourceLoader.load(ACTOR_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_set_status("导入产物无法作为 PackedScene 加载：%s" % ACTOR_SCENE_PATH)
		return

	_body_actor = _instantiate_actor(packed_scene)
	if _body_actor == null:
		return
	add_child(_body_actor)
	_body_animation_player = _find_animation_player(_body_actor)
	_capture_body_base_sprite_states()
	if _body_animation_player != null:
		_body_animation_player.stop()
	_parse_body_track_frames()
	_update_body_animation(0.0)

	for i in range(_head_parts.size()):
		var part := _head_parts[i]
		var head_actor := _instantiate_actor(packed_scene)
		if head_actor == null:
			continue
		add_child(head_actor)
		part["actor"] = head_actor
		part["player"] = _find_animation_player(head_actor)
		var anchor := _body_actor.get_node_or_null(NodePath(String(part["anchor"]))) as Node2D
		part["anchor_node"] = anchor
		part["base_transform"] = anchor.transform if anchor != null else Transform2D.IDENTITY
		_head_parts[i] = part
		_play_on_player(part["player"] as AnimationPlayer, part["idle"] as StringName, &"", 0.0, IDLE_RATE_SCALE, true)

	_update_head_attachments()
	_apply_visibility_masks()


func _instantiate_actor(packed_scene: PackedScene) -> Node2D:
	var instance := packed_scene.instantiate()
	var actor := instance as Node2D
	if actor == null:
		instance.queue_free()
		_set_status("导入产物根节点不是 Node2D：%s" % ACTOR_SCENE_PATH)
		return null
	actor.position = _slot_position(PLANT_LANE, PLANT_SLOT) + ACTOR_ANCHOR_OFFSET
	actor.scale = Vector2.ONE * ACTOR_SCALE_VALUE
	return actor


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _fire_three_peas() -> void:
	if _body_actor == null:
		return
	_is_shooting = true
	_has_pending_peas = true
	_shooting_elapsed = 0.0
	_pending_pea_elapsed = 0.0
	_shooting_duration = 0.0
	for part in _head_parts:
		var player := part.get("player", null) as AnimationPlayer
		var animation_name := _play_on_player(player, part["shooting"] as StringName, part["idle"] as StringName, REANIM_BLEND_SECONDS, SHOOTING_RATE_SCALE)
		_shooting_duration = maxf(_shooting_duration, _animation_duration(player, animation_name, SHOOTING_RATE_SCALE))


func _play_head_idle() -> void:
	for part in _head_parts:
		_play_on_player(part.get("player", null) as AnimationPlayer, part["idle"] as StringName, &"", REANIM_BLEND_SECONDS, IDLE_RATE_SCALE)


func _spawn_three_peas() -> void:
	for part in _head_parts:
		var lane := int(part["lane"])
		if lane < 0 or lane >= LANE_COUNT:
			continue
		var actor := part.get("actor", null) as Node2D
		var mouth := actor.get_node_or_null(NodePath(String(part["mouth"]))) as Node2D if actor != null else null
		var start_position := mouth.global_position + Vector2(18.0, 8.0) if mouth != null else _slot_position(PLANT_LANE, PLANT_SLOT)
		_peas.append({
			"position": start_position,
			"target_y": _lane_y(lane) - 36.0,
		})


func _play_on_player(player: AnimationPlayer, primary: StringName, fallback: StringName, blend_seconds := 0.0, speed_scale := 1.0, advance_now := false) -> StringName:
	if player == null:
		return &""
	var animation_name := _resolve_animation_name(player, primary, fallback)
	if animation_name == &"":
		return &""
	var animation := player.get_animation(animation_name)
	if animation != null:
		if String(animation_name).begins_with("shooting"):
			animation.loop_mode = Animation.LOOP_NONE
		else:
			animation.loop_mode = Animation.LOOP_LINEAR
	player.play(animation_name, blend_seconds, speed_scale)
	if advance_now:
		player.advance(0.0)
	return animation_name


func _resolve_animation_name(player: AnimationPlayer, primary: StringName, fallback: StringName) -> StringName:
	if primary != &"" and player.has_animation(primary):
		return primary
	if fallback != &"" and player.has_animation(fallback):
		return fallback
	return &""


func _animation_duration(player: AnimationPlayer, animation_name: StringName, speed_scale: float) -> float:
	if player == null or animation_name == &"" or not player.has_animation(animation_name):
		return 0.6
	var animation := player.get_animation(animation_name)
	if animation == null:
		return 0.6
	return maxf(0.1, animation.length / maxf(0.01, absf(speed_scale)))


func _parse_body_track_frames() -> void:
	_body_track_frames.clear()
	if not FileAccess.file_exists(SOURCE_REANIM_PATH):
		return
	var parser := XMLParser.new()
	var source_text := FileAccess.get_file_as_string(SOURCE_REANIM_PATH)
	var wrapped := "<root>\n%s\n</root>" % source_text
	if parser.open_buffer(wrapped.to_utf8_buffer()) != OK:
		return

	var current_track_name := ""
	var current_frames: Array[Dictionary] = []
	var current_frame: Dictionary = {}
	var current_field := ""
	var current_text := ""

	while parser.read() == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			if node_name == "track":
				current_track_name = ""
				current_frames = []
			elif node_name == "t":
				current_frame = {"frame": current_frames.size()}
			elif node_name in ["name", "f", "x", "y", "sx", "sy", "kx", "ky", "a"]:
				current_field = node_name
				current_text = ""
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			if current_field != "":
				current_text += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name := parser.get_node_name()
			if current_field == end_name:
				var value := current_text.strip_edges()
				if end_name == "name" and current_frame.is_empty():
					current_track_name = value
				elif not current_frame.is_empty():
					current_frame[end_name] = value
				current_field = ""
				current_text = ""
			if end_name == "t" and not current_frame.is_empty():
				current_frames.append(current_frame)
				current_frame = {}
			elif end_name == "track":
				if _is_body_animation_track(current_track_name):
					_body_track_frames[current_track_name] = current_frames


func _is_body_animation_track(track_name: String) -> bool:
	if track_name == "":
		return false
	if track_name in ["anim_head1", "anim_head2", "anim_head3"]:
		return true
	return not _is_any_head_node(track_name)


func _update_body_animation(delta: float) -> void:
	if _body_actor == null or _body_track_frames.is_empty():
		return
	var body_frame_count := BODY_END_FRAME - BODY_START_FRAME + 1
	if body_frame_count <= 0:
		return
	_body_frame_elapsed = fmod(_body_frame_elapsed + delta * IDLE_RATE_SCALE * REANIM_SOURCE_FPS, float(body_frame_count))
	var source_frame := BODY_START_FRAME + int(floor(_body_frame_elapsed))
	for track_name in _body_track_frames.keys():
		var node := _body_actor.get_node_or_null(NodePath(String(track_name))) as Node2D
		if node == null:
			continue
		var state := _resolve_track_state(_body_track_frames[track_name], source_frame)
		_apply_track_state(node, state)


func _resolve_track_state(frames: Array, source_frame: int) -> Dictionary:
	var state := {
		"visible": false,
		"position": Vector2.ZERO,
		"scale": Vector2.ONE,
		"rotation": 0.0,
		"skew": 0.0,
		"axis_angle": 0.0,
		"alpha": 1.0,
	}
	for frame in frames:
		var frame_dict: Dictionary = frame
		if int(frame_dict.get("frame", 0)) > source_frame:
			break
		_apply_reanim_frame_to_state(state, frame_dict)
	return state


func _apply_reanim_frame_to_state(state: Dictionary, frame: Dictionary) -> void:
	if frame.has("f"):
		state["visible"] = String(frame["f"]) != "-1"
	if frame.has("x") or frame.has("y"):
		var position: Vector2 = state["position"]
		if frame.has("x"):
			position.x = float(frame["x"])
		if frame.has("y"):
			position.y = float(frame["y"])
		state["position"] = position
	if frame.has("sx") or frame.has("sy"):
		var scale: Vector2 = state["scale"]
		if frame.has("sx"):
			scale.x = float(frame["sx"])
		if frame.has("sy"):
			scale.y = float(frame["sy"])
		state["scale"] = scale
	var axis_angle := float(state["axis_angle"])
	if frame.has("kx"):
		var next_rotation := deg_to_rad(fmod(float(frame["kx"]), 360.0))
		state["rotation"] = next_rotation
		state["skew"] = axis_angle - next_rotation
	if frame.has("ky"):
		axis_angle = deg_to_rad(fmod(float(frame["ky"]), 360.0))
		state["axis_angle"] = axis_angle
		state["skew"] = axis_angle - float(state["rotation"])
	if frame.has("a"):
		state["alpha"] = clampf(float(frame["a"]), 0.0, 1.0)


func _apply_track_state(node: Node2D, state: Dictionary) -> void:
	node.visible = bool(state["visible"])
	node.position = state["position"] as Vector2
	node.scale = state["scale"] as Vector2
	node.rotation = float(state["rotation"])
	node.skew = float(state["skew"])
	if node is Sprite2D:
		var sprite := node as Sprite2D
		var color := sprite.self_modulate
		color.a = float(state["alpha"])
		sprite.self_modulate = color


func _update_head_attachments() -> void:
	if _body_actor == null:
		return
	for i in range(_head_parts.size()):
		var part := _head_parts[i]
		var head_actor := part.get("actor", null) as Node2D
		var anchor := part.get("anchor_node", null) as Node2D
		if head_actor == null or anchor == null:
			continue
		var base_transform := part.get("base_transform", Transform2D.IDENTITY) as Transform2D
		head_actor.transform = _body_actor.transform * anchor.transform * base_transform.affine_inverse()


func _apply_visibility_masks() -> void:
	if _body_actor != null:
		_apply_actor_mask(_body_actor, 0)
	for part in _head_parts:
		var actor := part.get("actor", null) as Node2D
		if actor != null:
			_apply_actor_mask(actor, int(part["id"]))


func _apply_actor_mask(root: Node, head_id: int) -> void:
	if root is Sprite2D:
		var sprite := root as Sprite2D
		if head_id == 0:
			if _is_any_head_node(sprite.name):
				sprite.visible = false
			else:
				_restore_body_sprite_render_state(sprite)
		elif not _is_head_node_for_id(sprite.name, head_id):
			sprite.visible = false
	for child in root.get_children():
		_apply_actor_mask(child, head_id)


func _capture_body_base_sprite_states() -> void:
	_body_base_sprite_states.clear()
	_collect_body_base_sprite_states(_body_actor)


func _collect_body_base_sprite_states(node: Node) -> void:
	if node is Sprite2D:
		var sprite := node as Sprite2D
		_body_base_sprite_states[sprite.get_path()] = {
			"visible": sprite.visible,
			"position": sprite.position,
			"scale": sprite.scale,
			"rotation": sprite.rotation,
			"skew": sprite.skew,
			"self_modulate": sprite.self_modulate,
			"texture": sprite.texture,
		}
	for child in node.get_children():
		_collect_body_base_sprite_states(child)


func _restore_body_sprite_render_state(sprite: Sprite2D) -> void:
	if not _body_base_sprite_states.has(sprite.get_path()):
		return
	var state: Dictionary = _body_base_sprite_states[sprite.get_path()]
	sprite.visible = bool(state["visible"])
	if sprite.texture == null:
		sprite.texture = state["texture"] as Texture2D


func _is_any_head_node(node_name: String) -> bool:
	return node_name.begins_with("anim_head") or node_name.begins_with("anim_face") or node_name.contains("_head") or node_name.contains("_mouth") or node_name.contains("_blink") or node_name.begins_with("ThreePeater_mouth")


func _is_head_node_for_id(node_name: String, head_id: int) -> bool:
	var suffix := str(head_id)
	return node_name == "anim_head%s" % suffix \
		or node_name == "anim_face%s" % suffix \
		or node_name.contains("_head%s" % suffix) \
		or node_name.contains("_mouth%s" % suffix) \
		or node_name.contains("_blink%s" % suffix)


func _update_peas(delta: float) -> void:
	var pea_speed := PEA_SPEED_SLOTS_PER_SEC * OPENPVZ_SLOT_SPACING
	var target_x := _slot_position(PLANT_LANE, TARGET_SLOT).x
	for i in range(_peas.size() - 1, -1, -1):
		var pea := _peas[i]
		var position := pea.get("position", Vector2.ZERO) as Vector2
		var target_y := float(pea.get("target_y", position.y))
		position.x += pea_speed * delta
		position.y = move_toward(position.y, target_y, OPENPVZ_LANE_SPACING * 0.95 * delta)
		pea["position"] = position
		_peas[i] = pea
		if position.x >= target_x:
			_peas.remove_at(i)


func _draw_target(lane: int) -> void:
	var center := _slot_position(lane, TARGET_SLOT)
	var body_rect := Rect2(center + Vector2(-16.0, -50.0), Vector2(32.0, 72.0))
	draw_rect(body_rect, Color("65705a"))
	draw_circle(center + Vector2(0.0, -64.0), 18.0, Color("879174"))
	draw_line(center + Vector2(-18.0, 24.0), center + Vector2(-28.0, 52.0), Color("65705a"), 5.0)
	draw_line(center + Vector2(18.0, 24.0), center + Vector2(28.0, 52.0), Color("65705a"), 5.0)


func _slot_position(lane: int, slot: int) -> Vector2:
	return Vector2(BOARD_ORIGIN.x + float(slot) * OPENPVZ_SLOT_SPACING + OPENPVZ_SLOT_SPACING * 0.5, _lane_y(lane))


func _lane_y(lane: int) -> float:
	return BOARD_ORIGIN.y + float(lane) * OPENPVZ_LANE_SPACING


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
