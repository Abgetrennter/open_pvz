extends SceneTree

const VisualProfileDefRef = preload("res://scripts/core/defs/visual_profile_def.gd")

const FIELD_NAMES := {
	"f": true,
	"i": true,
	"x": true,
	"y": true,
	"sx": true,
	"sy": true,
	"kx": true,
	"ky": true,
	"a": true,
	"bm": true,
}

const DEFAULT_STATE := {
	"visible": true,
	"position": Vector2.ZERO,
	"scale": Vector2.ONE,
	"rotation": 0.0,
	"skew": 0.0,
	"axis_angle": 0.0,
	"self_modulate": Color.WHITE,
	"texture_key": "",
	"texture": null,
}

var _args: Dictionary = {}
var _image_map: Dictionary = {}
var _image_fallback_map: Dictionary = {}
var _loaded_textures: Dictionary = {}
var _unresolved_textures: Dictionary = {}
var _blend_modes: Dictionary = {}
var _warnings: Array[String] = []
var _verification: Dictionary = {}


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	_args = _parse_args(OS.get_cmdline_user_args())
	if not _validate_args(_args):
		_print_usage()
		return 2

	var out_dir: String = _normalize_res_dir(_args["out-dir"])
	var absolute_out_dir := ProjectSettings.globalize_path(out_dir)
	var dir_result := DirAccess.make_dir_recursive_absolute(absolute_out_dir)
	if dir_result != OK:
		push_error("Failed to create output directory: %s" % out_dir)
		return 3

	_image_fallback_map = _build_case_insensitive_image_map(_args["image-root"])
	_image_map = _parse_resources_xml(_args["resources"], _args["image-root"])

	var reanim := _parse_reanim(_args["source"])
	if reanim.is_empty():
		return 4

	var actor := _build_actor_scene(reanim)
	var actor_path := out_dir.path_join("actor.tscn")
	var actor_save_result := ResourceSaver.save(actor, actor_path)
	if actor_save_result != OK:
		push_error("Failed to save actor scene: %s" % actor_path)
		return 5
	_verification = _verify_generated_actor(actor_path)

	var profile_path := out_dir.path_join("visual_profile.tres")
	var profile_save_result := _save_visual_profile(profile_path, actor_path, reanim)
	if profile_save_result != OK:
		push_error("Failed to save visual profile: %s" % profile_path)
		return 6

	_save_report(out_dir.path_join("import_report.json"), actor_path, profile_path, reanim)
	print("Imported reanim actor: %s" % actor_path)
	return 0


func _parse_args(raw_args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var i := 0
	while i < raw_args.size():
		var token := String(raw_args[i])
		if token.begins_with("--"):
			var key := token.substr(2)
			if i + 1 < raw_args.size() and not String(raw_args[i + 1]).begins_with("--"):
				result[key] = String(raw_args[i + 1])
				i += 2
			else:
				result[key] = "true"
				i += 1
		else:
			i += 1
	return result


func _validate_args(args: Dictionary) -> bool:
	for key in ["source", "image-root", "resources", "out-dir", "profile-id"]:
		if not args.has(key) or String(args[key]).strip_edges() == "":
			push_error("Missing required argument: --%s" % key)
			return false

	for file_key in ["source", "resources"]:
		if not FileAccess.file_exists(String(args[file_key])):
			push_error("File not found for --%s: %s" % [file_key, String(args[file_key])])
			return false

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(String(args["image-root"]))):
		push_error("Image root not found: %s" % String(args["image-root"]))
		return false

	return true


func _print_usage() -> void:
	print("Usage:")
	print("  godot --headless --script res://tools/reanim_importer/reanim_import_one.gd -- --source <file.reanim> --image-root <res://dir> --resources <resources.xml> --out-dir <res://dir> --profile-id <id>")


func _normalize_res_dir(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


func _parse_resources_xml(resources_path: String, image_root: String) -> Dictionary:
	var parser := XMLParser.new()
	var open_result := parser.open(resources_path)
	if open_result != OK:
		_warnings.append("resources.xml could not be parsed: %s" % resources_path)
		return {}

	var result: Dictionary = {}
	var current_id_prefix := ""
	var current_path := ""
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var node_name := parser.get_node_name()
		if node_name == "SetDefaults":
			current_id_prefix = _xml_attr(parser, "idprefix", current_id_prefix)
			current_path = _xml_attr(parser, "path", current_path)
		elif node_name == "Image":
			var id := _xml_attr(parser, "id", "")
			var path := _xml_attr(parser, "path", "")
			if id == "" or path == "":
				continue
			var key := "%s%s" % [current_id_prefix, id]
			var file_name := path
			if file_name.get_extension().to_lower() not in ["png", "jpg", "jpeg", "gif"]:
				file_name += ".png"
			var mapped_path := image_root.path_join(file_name)
			if current_path != "" and current_path != "reanim":
				mapped_path = image_root.path_join(current_path).path_join(file_name)
			result[key] = mapped_path
	return result


func _build_case_insensitive_image_map(image_root: String) -> Dictionary:
	var result: Dictionary = {}
	var absolute_root := ProjectSettings.globalize_path(image_root)
	var files := DirAccess.get_files_at(absolute_root)
	for file_name in files:
		var ext := String(file_name).get_extension().to_lower()
		if ext not in ["png", "jpg", "jpeg", "gif"]:
			continue
		result[String(file_name).to_lower()] = image_root.path_join(file_name)
	return result


func _parse_reanim(source_path: String) -> Dictionary:
	var source_text := FileAccess.get_file_as_string(source_path)
	if source_text == "":
		push_error("Reanim source is empty: %s" % source_path)
		return {}

	var parser := XMLParser.new()
	var wrapped := "<root>\n%s\n</root>" % source_text
	var open_result := parser.open_buffer(wrapped.to_utf8_buffer())
	if open_result != OK:
		push_error("Could not parse reanim XML: %s" % source_path)
		return {}

	var result := {
		"source": source_path,
		"fps": 12,
		"tracks": [],
		"markers": [],
		"frame_count": 0,
		"animations": [],
	}
	var current_track: Dictionary = {}
	var current_frame: Dictionary = {}
	var current_field := ""
	var current_text := ""

	while parser.read() == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name := parser.get_node_name()
			if node_name == "track":
				current_track = {"name": "", "frames": []}
			elif node_name == "t" and not current_track.is_empty():
				current_frame = {"frame": current_track["frames"].size()}
			elif node_name == "fps" or node_name == "name" or FIELD_NAMES.has(node_name):
				current_field = node_name
				current_text = ""
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			if current_field != "":
				current_text += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name := parser.get_node_name()
			if current_field == end_name:
				var value := current_text.strip_edges()
				if end_name == "fps":
					result["fps"] = max(1, int(value))
				elif end_name == "name" and not current_track.is_empty() and current_frame.is_empty():
					current_track["name"] = value
				elif FIELD_NAMES.has(end_name) and not current_frame.is_empty():
					current_frame[end_name] = value
				current_field = ""
				current_text = ""

			if end_name == "t" and not current_track.is_empty() and not current_frame.is_empty():
				current_track["frames"].append(current_frame)
				current_frame = {}
			elif end_name == "track" and not current_track.is_empty():
				result["frame_count"] = max(int(result["frame_count"]), current_track["frames"].size())
				if _is_marker_track(current_track):
					result["markers"].append(current_track)
				else:
					result["tracks"].append(current_track)
				current_track = {}

	result["animations"] = _derive_marker_animations(result["markers"], int(result["frame_count"]), int(result["fps"]))
	_append_visual_layer_animations(result["animations"], result["tracks"], int(result["frame_count"]))
	if result["animations"].is_empty():
		result["animations"].append({"name": "all", "start_frame": 0, "end_frame": max(0, int(result["frame_count"]) - 1)})
	return result


func _is_marker_track(track: Dictionary) -> bool:
	var track_name := String(track.get("name", ""))
	if not track_name.begins_with("anim_"):
		return false
	for frame in track.get("frames", []):
		var frame_dict: Dictionary = frame
		for key in frame_dict.keys():
			if key != "frame" and key != "f":
				return false
	return true


func _derive_marker_animations(markers: Array, frame_count: int, _fps: int) -> Array[Dictionary]:
	var animations: Array[Dictionary] = []
	for marker in markers:
		var marker_name := String(marker.get("name", ""))
		var animation_name := marker_name.trim_prefix("anim_")
		if animation_name == "":
			continue
		var start_frame := -1
		var end_frame := frame_count - 1
		for frame in marker.get("frames", []):
			var frame_index := int(frame.get("frame", 0))
			var visible_flag := String(frame.get("f", ""))
			if visible_flag == "0" and start_frame == -1:
				start_frame = frame_index
			elif visible_flag == "-1" and start_frame != -1 and frame_index > start_frame:
				end_frame = frame_index - 1
				break
		if start_frame == -1:
			continue
		animations.append({
			"name": animation_name,
			"start_frame": start_frame,
			"end_frame": max(start_frame, end_frame),
		})
	return animations


func _append_visual_layer_animations(animations: Array[Dictionary], tracks: Array, frame_count: int) -> void:
	var existing_names: Dictionary = {}
	for animation_def in animations:
		existing_names[String(animation_def.get("name", ""))] = true

	for track in tracks:
		var track_dict: Dictionary = track
		var track_name := String(track_dict.get("name", ""))
		if not track_name.begins_with("anim_"):
			continue

		var animation_name := track_name.trim_prefix("anim_")
		if animation_name == "" or existing_names.has(animation_name):
			continue

		var visible_range := _derive_track_visible_range(track_dict, frame_count)
		if visible_range.is_empty():
			continue

		animations.append({
			"name": animation_name,
			"start_frame": int(visible_range["start_frame"]),
			"end_frame": int(visible_range["end_frame"]),
			"source_track": track_name,
			"source_kind": "visual_layer",
		})
		existing_names[animation_name] = true


func _derive_track_visible_range(track: Dictionary, frame_count: int) -> Dictionary:
	var start_frame := -1
	var end_frame := -1
	for frame in track.get("frames", []):
		var frame_dict: Dictionary = frame
		var frame_index := int(frame_dict.get("frame", 0))
		if not frame_dict.has("f"):
			if start_frame != -1:
				end_frame = frame_index
			continue

		var visible_flag := String(frame_dict["f"])
		if visible_flag == "0":
			if start_frame == -1:
				start_frame = frame_index
			end_frame = frame_index
		elif visible_flag == "-1" and start_frame != -1:
			end_frame = max(start_frame, frame_index - 1)
			break

	if start_frame == -1:
		return {}
	if end_frame == -1:
		end_frame = frame_count - 1

	return {
		"start_frame": start_frame,
		"end_frame": max(start_frame, end_frame),
	}


func _build_actor_scene(reanim: Dictionary) -> PackedScene:
	var root := Node2D.new()
	root.name = "ReanimActor"

	var node_by_track: Dictionary = {}
	for track in reanim["tracks"]:
		var track_name := String(track.get("name", ""))
		var sprite := Sprite2D.new()
		sprite.name = _unique_node_name(root, _sanitize_node_name(track_name))
		sprite.centered = false
		sprite.visible = false
		_apply_initial_sprite_state(sprite, track)
		root.add_child(sprite)
		sprite.owner = root
		node_by_track[track_name] = sprite

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	root.add_child(animation_player)
	animation_player.owner = root

	var library := AnimationLibrary.new()
	for animation_def in reanim["animations"]:
		var animation := _build_animation(animation_def, reanim, node_by_track)
		library.add_animation(StringName(animation_def["name"]), animation)
	animation_player.add_animation_library("", library)

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		push_error("Failed to pack generated actor scene.")
	root.queue_free()
	return packed


func _apply_initial_sprite_state(sprite: Sprite2D, track: Dictionary) -> void:
	var state := DEFAULT_STATE.duplicate(true)
	for frame in track.get("frames", []):
		_apply_frame_state(state, frame)
		if state["texture"] != null:
			break
	sprite.visible = bool(state["visible"])
	sprite.position = state["position"]
	sprite.scale = state["scale"]
	sprite.rotation = state["rotation"]
	sprite.skew = state["skew"]
	sprite.self_modulate = state["self_modulate"]
	sprite.texture = state["texture"]


func _build_animation(animation_def: Dictionary, reanim: Dictionary, node_by_track: Dictionary) -> Animation:
	var animation := Animation.new()
	var fps := int(reanim["fps"])
	var start_frame := int(animation_def["start_frame"])
	var end_frame := int(animation_def["end_frame"])
	var frame_count: int = max(1, end_frame - start_frame + 1)
	animation.length = float(frame_count) / float(fps)
	animation.step = 1.0 / float(fps)
	animation.loop_mode = Animation.LOOP_LINEAR

	for track in reanim["tracks"]:
		var track_name := String(track.get("name", ""))
		var node: Node = node_by_track.get(track_name, null)
		if node == null:
			continue
		_add_track_animation(animation, track, node.name, start_frame, end_frame, fps)
	return animation


func _add_track_animation(animation: Animation, track: Dictionary, node_name: String, start_frame: int, end_frame: int, fps: int) -> void:
	var state := DEFAULT_STATE.duplicate(true)
	var last_written: Dictionary = {}
	var frames: Array = track.get("frames", [])
	for frame in frames:
		var frame_index := int(frame.get("frame", 0))
		_apply_frame_state(state, frame)
		if frame_index < start_frame or frame_index > end_frame:
			continue
		var time := float(frame_index - start_frame) / float(fps)
		_insert_if_changed(animation, last_written, node_name, "visible", time, state["visible"], Animation.UPDATE_DISCRETE)
		_insert_if_changed(animation, last_written, node_name, "position", time, state["position"], Animation.UPDATE_CONTINUOUS)
		_insert_if_changed(animation, last_written, node_name, "scale", time, state["scale"], Animation.UPDATE_CONTINUOUS)
		_insert_if_changed(animation, last_written, node_name, "rotation", time, state["rotation"], Animation.UPDATE_CONTINUOUS)
		_insert_if_changed(animation, last_written, node_name, "skew", time, state["skew"], Animation.UPDATE_CONTINUOUS)
		_insert_if_changed(animation, last_written, node_name, "self_modulate", time, state["self_modulate"], Animation.UPDATE_CONTINUOUS)
		_insert_if_changed(animation, last_written, node_name, "texture", time, state["texture"], Animation.UPDATE_DISCRETE)


func _apply_frame_state(state: Dictionary, frame: Dictionary) -> void:
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
		var next_rotation := _degrees_to_radians_wrapped(float(frame["kx"]))
		state["rotation"] = next_rotation
		state["skew"] = axis_angle - next_rotation
	if frame.has("ky"):
		axis_angle = _degrees_to_radians_wrapped(float(frame["ky"]))
		state["axis_angle"] = axis_angle
		state["skew"] = axis_angle - float(state["rotation"])
	if frame.has("a"):
		var color: Color = state["self_modulate"]
		color.a = clampf(float(frame["a"]), 0.0, 1.0)
		state["self_modulate"] = color
	if frame.has("i"):
		var texture_key := String(frame["i"])
		state["texture_key"] = texture_key
		state["texture"] = _load_texture(texture_key)
	if frame.has("bm"):
		_blend_modes[String(frame["bm"])] = true


func _insert_if_changed(animation: Animation, last_written: Dictionary, node_name: String, property_name: String, time: float, value: Variant, update_mode: int) -> void:
	var last_key := "%s:%s" % [node_name, property_name]
	if last_written.has(last_key) and last_written[last_key] == value:
		return
	last_written[last_key] = value
	var track_index := _ensure_value_track(animation, NodePath("%s:%s" % [node_name, property_name]), update_mode)
	animation.track_insert_key(track_index, time, value)


func _degrees_to_radians_wrapped(degrees: float) -> float:
	return deg_to_rad(fmod(degrees, 360.0))


func _ensure_value_track(animation: Animation, path: NodePath, update_mode: int) -> int:
	for i in range(animation.get_track_count()):
		if animation.track_get_path(i) == path:
			return i
	var track_index := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, path)
	animation.value_track_set_update_mode(track_index, update_mode)
	return track_index


func _load_texture(texture_key: String) -> Texture2D:
	if texture_key == "":
		return null
	if _loaded_textures.has(texture_key):
		return _loaded_textures[texture_key]

	var path := _resolve_texture_path(texture_key)
	if path == "":
		_unresolved_textures[texture_key] = true
		_loaded_textures[texture_key] = null
		return null

	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = ResourceLoader.load(path) as Texture2D
	if texture == null:
		texture = _load_texture_from_image_file(path)
	if texture == null:
		_unresolved_textures[texture_key] = true
		_warnings.append("Texture could not be loaded: %s -> %s" % [texture_key, path])
	_loaded_textures[texture_key] = texture
	return texture


func _load_texture_from_image_file(path: String) -> Texture2D:
	var image := Image.new()
	var load_result := image.load(ProjectSettings.globalize_path(path))
	if load_result != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = path.get_file()
	return texture


func _resolve_texture_path(texture_key: String) -> String:
	if _image_map.has(texture_key):
		var mapped := String(_image_map[texture_key])
		if ResourceLoader.exists(mapped) or FileAccess.file_exists(mapped):
			return mapped

	var candidate := texture_key
	if candidate.begins_with("IMAGE_REANIM_"):
		candidate = candidate.substr("IMAGE_REANIM_".length())
	candidate = _resource_id_to_file_stem(candidate) + ".png"
	var lower_candidate := candidate.to_lower()
	if _image_fallback_map.has(lower_candidate):
		return String(_image_fallback_map[lower_candidate])
	return ""


func _resource_id_to_file_stem(id: String) -> String:
	var parts := id.split("_", false)
	var converted: Array[String] = []
	for part in parts:
		var lower := String(part).to_lower()
		if lower == "":
			continue
		converted.append(lower.substr(0, 1).to_upper() + lower.substr(1))
	return "_".join(converted)


func _save_visual_profile(profile_path: String, actor_path: String, reanim: Dictionary) -> int:
	var profile = VisualProfileDefRef.new()
	profile.id = StringName(_args["profile-id"])
	profile.actor_scene = ResourceLoader.load(actor_path) as PackedScene
	profile.state_animation_map = _make_default_state_animation_map(reanim["animations"])
	profile.animation_map = {}
	profile.z_policy = {"layer": &"plant"}
	return ResourceSaver.save(profile, profile_path)


func _make_default_state_animation_map(animations: Array) -> Dictionary:
	var available: Dictionary = {}
	for animation_def in animations:
		available[String(animation_def["name"])] = true

	var result: Dictionary = {}
	if available.has("idle"):
		result[&"idle"] = &"idle"
	elif available.has("full_idle"):
		result[&"idle"] = &"full_idle"
	if available.has("shooting"):
		result[&"attacking"] = &"shooting"
	elif available.has("attack"):
		result[&"attacking"] = &"attack"
	if available.has("death"):
		result[&"dead"] = &"death"
	elif available.has("superlongdeath"):
		result[&"dead"] = &"superlongdeath"
	return result


func _save_report(report_path: String, actor_path: String, profile_path: String, reanim: Dictionary) -> void:
	var payload := {
		"source": _args["source"],
		"actor_scene": actor_path,
		"visual_profile": profile_path,
		"profile_id": _args["profile-id"],
		"fps": reanim["fps"],
		"track_count": reanim["tracks"].size(),
		"marker_count": reanim["markers"].size(),
		"animation_names": reanim["animations"].map(func(entry): return entry["name"]),
		"loaded_texture_count": _loaded_textures.values().filter(func(value): return value != null).size(),
		"unresolved_texture_count": _unresolved_textures.size(),
		"unresolved_textures": _unresolved_textures.keys(),
		"blend_modes_seen": _blend_modes.keys(),
		"verification": _verification,
		"warnings": _warnings,
	}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write import report: %s" % report_path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func _verify_generated_actor(actor_path: String) -> Dictionary:
	var result := {
		"actor_loadable": false,
		"has_idle": false,
		"has_shooting": false,
		"sprite_with_texture_count": 0,
	}
	var packed := ResourceLoader.load(actor_path) as PackedScene
	if packed == null:
		_warnings.append("Generated actor scene could not be loaded: %s" % actor_path)
		return result
	result["actor_loadable"] = true
	var root := packed.instantiate()
	var player := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null:
		result["has_idle"] = player.has_animation(&"idle")
		result["has_shooting"] = player.has_animation(&"shooting")
	result["sprite_with_texture_count"] = _count_sprite_textures(root)
	root.free()
	return result


func _count_sprite_textures(node: Node) -> int:
	var count := 0
	if node is Sprite2D and node.texture != null:
		count += 1
	for child in node.get_children():
		count += _count_sprite_textures(child)
	return count


func _sanitize_node_name(value: String) -> String:
	var sanitized := value.strip_edges()
	for ch in [" ", ".", "/", "\\", ":", ";", ",", "(", ")", "[", "]"]:
		sanitized = sanitized.replace(ch, "_")
	if sanitized == "":
		return "Track"
	return sanitized


func _unique_node_name(parent: Node, base_name: String) -> String:
	var candidate := base_name
	var index := 2
	while parent.has_node(NodePath(candidate)):
		candidate = "%s%d" % [base_name, index]
		index += 1
	return candidate


func _xml_attr(parser: XMLParser, attr_name: String, fallback: String) -> String:
	for i in range(parser.get_attribute_count()):
		if parser.get_attribute_name(i) == attr_name:
			return parser.get_attribute_value(i)
	return fallback
