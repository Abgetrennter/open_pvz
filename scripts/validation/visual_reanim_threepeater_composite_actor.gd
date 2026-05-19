extends Node2D

@export_file("*.tscn") var raw_actor_scene_path := ""
@export_file("*.reanim") var source_reanim_path := ""
@export var actor_anchor_offset := Vector2(-44.0, -96.0)
@export var actor_scale_value := 1.0

const REANIM_SOURCE_FPS := 12.0
const BODY_START_FRAME := 124
const BODY_END_FRAME := 148
const IDLE_RATE_SCALE := 17.0 / REANIM_SOURCE_FPS
const SHOOTING_RATE_SCALE := 20.0 / REANIM_SOURCE_FPS
const REANIM_BLEND_SECONDS := 0.1

var _body_actor: Node2D = null
var _body_animation_player: AnimationPlayer = null
var _body_base_sprite_states: Dictionary = {}
var _body_track_frames: Dictionary = {}
var _body_frame_elapsed := 0.0
var _visual_speed_scale := 1.0
var _shooting_elapsed := 0.0
var _shooting_duration := 0.0
var _is_shooting := false
var _middle_muzzle_anchor: Node2D = null
var _head_parts: Array[Dictionary] = [
	{
		"id": 1,
		"anchor": "anim_head1",
		"idle": &"head_idle1",
		"shooting": &"shooting1",
		"mouth": "ThreePeater_mouth1",
	},
	{
		"id": 2,
		"anchor": "anim_head2",
		"idle": &"head_idle2",
		"shooting": &"shooting2",
		"mouth": "ThreePeater_mouth2",
	},
	{
		"id": 3,
		"anchor": "anim_head3",
		"idle": &"head_idle3",
		"shooting": &"shooting3",
		"mouth": "ThreePeater_mouth3",
	},
]


func _ready() -> void:
	process_priority = 100
	_create_anchors()
	_load_parts()


func _process(delta: float) -> void:
	_update_body_animation(delta)
	_update_head_attachments()
	_update_anchor_positions()
	_apply_visibility_masks()
	if not _is_shooting:
		return
	_shooting_elapsed += delta
	if _shooting_elapsed >= _shooting_duration:
		_is_shooting = false
		_play_head_idle(REANIM_BLEND_SECONDS)


func play_state(state_id: StringName) -> bool:
	match state_id:
		&"idle", &"ready":
			_is_shooting = false
			_play_head_idle(REANIM_BLEND_SECONDS)
			return true
		&"attacking", &"attack":
			return play_action(&"shoot")
		_:
			return false


func play_action(action_id: StringName) -> bool:
	match action_id:
		&"shoot", &"shooting", &"fire", &"attack":
			return _play_shooting()
		_:
			return false


func play_animation(animation_name: StringName) -> bool:
	match animation_name:
		&"idle", &"head_idle2":
			return play_state(&"idle")
		&"shooting", &"shooting2":
			return _play_shooting()
		&"head_idle1", &"head_idle3":
			_play_head_idle(REANIM_BLEND_SECONDS)
			return true
		&"shooting1", &"shooting3":
			return _play_shooting()
		_:
			return false


func set_visual_speed(speed_scale: float) -> bool:
	_visual_speed_scale = maxf(0.01, speed_scale)
	for part in _head_parts:
		var player := part.get("player", null) as AnimationPlayer
		if player != null:
			player.speed_scale = _visual_speed_scale
	return true


func get_anchor(anchor_name: StringName) -> Node2D:
	match anchor_name:
		&"muzzle", &"projectile", &"pea_spawn":
			return _middle_muzzle_anchor
		&"muzzle1", &"pea_spawn1":
			return _head_parts[0].get("muzzle_anchor", null) as Node2D
		&"muzzle2", &"pea_spawn2":
			return _head_parts[1].get("muzzle_anchor", null) as Node2D
		&"muzzle3", &"pea_spawn3":
			return _head_parts[2].get("muzzle_anchor", null) as Node2D
		_:
			return null


func _load_parts() -> void:
	if raw_actor_scene_path == "" or not ResourceLoader.exists(raw_actor_scene_path):
		push_warning("ThreePeater raw reanim actor is missing: %s" % raw_actor_scene_path)
		return

	var raw_actor_scene := ResourceLoader.load(raw_actor_scene_path) as PackedScene
	if raw_actor_scene == null:
		push_warning("ThreePeater raw reanim actor could not be loaded: %s" % raw_actor_scene_path)
		return

	_body_actor = _instantiate_actor(raw_actor_scene, "Body")
	if _body_actor == null:
		return
	_body_animation_player = _find_animation_player(_body_actor)
	_capture_body_base_sprite_states()
	if _body_animation_player != null:
		_body_animation_player.stop()
	_parse_body_track_frames()
	_update_body_animation(0.0)

	for i in range(_head_parts.size()):
		var part := _head_parts[i]
		var head_actor := _instantiate_actor(raw_actor_scene, "Head%s" % str(part["id"]))
		if head_actor == null:
			continue
		part["actor"] = head_actor
		part["player"] = _find_animation_player(head_actor)
		var anchor := _body_actor.get_node_or_null(NodePath(String(part["anchor"]))) as Node2D
		part["anchor_node"] = anchor
		part["base_transform"] = anchor.transform if anchor != null else Transform2D.IDENTITY
		_head_parts[i] = part
		_play_on_player(part["player"] as AnimationPlayer, part["idle"] as StringName, &"", 0.0, IDLE_RATE_SCALE, true)

	_update_head_attachments()
	_update_anchor_positions()
	_apply_visibility_masks()


func _instantiate_actor(raw_actor_scene: PackedScene, node_name: String) -> Node2D:
	var instance := raw_actor_scene.instantiate()
	var actor := instance as Node2D
	if actor == null:
		instance.queue_free()
		push_warning("ThreePeater raw actor root is not Node2D.")
		return null
	actor.name = node_name
	actor.position = actor_anchor_offset
	actor.scale = Vector2.ONE * actor_scale_value
	add_child(actor)
	return actor


func _create_anchors() -> void:
	_middle_muzzle_anchor = Node2D.new()
	_middle_muzzle_anchor.name = "MuzzleAnchor"
	add_child(_middle_muzzle_anchor)
	for i in range(_head_parts.size()):
		var anchor := Node2D.new()
		anchor.name = "Muzzle%sAnchor" % str(_head_parts[i]["id"])
		add_child(anchor)
		var part := _head_parts[i]
		part["muzzle_anchor"] = anchor
		_head_parts[i] = part


func _play_head_idle(blend_seconds := 0.0) -> void:
	for part in _head_parts:
		_play_on_player(part.get("player", null) as AnimationPlayer, part["idle"] as StringName, &"", blend_seconds, IDLE_RATE_SCALE)


func _play_shooting() -> bool:
	var played := false
	_is_shooting = true
	_shooting_elapsed = 0.0
	_shooting_duration = 0.0
	for part in _head_parts:
		var player := part.get("player", null) as AnimationPlayer
		var animation_name := _play_on_player(player, part["shooting"] as StringName, part["idle"] as StringName, REANIM_BLEND_SECONDS, SHOOTING_RATE_SCALE)
		if animation_name == StringName():
			continue
		played = true
		_shooting_duration = maxf(_shooting_duration, _animation_duration(player, animation_name, SHOOTING_RATE_SCALE))
	if not played:
		_is_shooting = false
	return played


func _play_on_player(
	player: AnimationPlayer,
	primary: StringName,
	fallback: StringName,
	blend_seconds := 0.0,
	rate_scale := 1.0,
	advance_now := false
) -> StringName:
	if player == null:
		return StringName()
	var animation_name := _resolve_animation_name(player, primary, fallback)
	if animation_name == StringName():
		return StringName()

	var animation := player.get_animation(animation_name)
	if animation != null:
		if String(animation_name).begins_with("shooting"):
			animation.loop_mode = Animation.LOOP_NONE
		else:
			animation.loop_mode = Animation.LOOP_LINEAR
	player.play(animation_name, blend_seconds, rate_scale * _visual_speed_scale)
	if advance_now:
		player.advance(0.0)
	return animation_name


func _resolve_animation_name(player: AnimationPlayer, primary: StringName, fallback: StringName) -> StringName:
	if primary != StringName() and player.has_animation(primary):
		return primary
	if fallback != StringName() and player.has_animation(fallback):
		return fallback
	return StringName()


func _animation_duration(player: AnimationPlayer, animation_name: StringName, rate_scale: float) -> float:
	if player == null or animation_name == StringName() or not player.has_animation(animation_name):
		return 0.6
	var animation := player.get_animation(animation_name)
	if animation == null:
		return 0.6
	return maxf(0.1, animation.length / maxf(0.01, absf(rate_scale * _visual_speed_scale)))


func _parse_body_track_frames() -> void:
	_body_track_frames.clear()
	if source_reanim_path == "" or not FileAccess.file_exists(source_reanim_path):
		push_warning("ThreePeater source reanim is missing: %s" % source_reanim_path)
		return

	var parser := XMLParser.new()
	var source_text := FileAccess.get_file_as_string(source_reanim_path)
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
	_body_frame_elapsed = fmod(_body_frame_elapsed + delta * IDLE_RATE_SCALE * REANIM_SOURCE_FPS * _visual_speed_scale, float(body_frame_count))
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


func _update_anchor_positions() -> void:
	for i in range(_head_parts.size()):
		var part := _head_parts[i]
		var head_actor := part.get("actor", null) as Node2D
		var mouth := head_actor.get_node_or_null(NodePath(String(part["mouth"]))) as Node2D if head_actor != null else null
		var muzzle_anchor := part.get("muzzle_anchor", null) as Node2D
		if mouth != null and muzzle_anchor != null:
			muzzle_anchor.global_position = mouth.global_position + Vector2(18.0, 8.0)
	if _middle_muzzle_anchor != null:
		var middle_anchor := _head_parts[1].get("muzzle_anchor", null) as Node2D
		if middle_anchor != null:
			_middle_muzzle_anchor.global_position = middle_anchor.global_position


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
	return node_name.begins_with("anim_head") \
		or node_name.begins_with("anim_face") \
		or node_name.contains("_head") \
		or node_name.contains("_mouth") \
		or node_name.contains("_blink") \
		or node_name.begins_with("ThreePeater_mouth")


func _is_head_node_for_id(node_name: String, head_id: int) -> bool:
	var suffix := str(head_id)
	return node_name == "anim_head%s" % suffix \
		or node_name == "anim_face%s" % suffix \
		or node_name.contains("_head%s" % suffix) \
		or node_name.contains("_mouth%s" % suffix) \
		or node_name.contains("_blink%s" % suffix)


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
