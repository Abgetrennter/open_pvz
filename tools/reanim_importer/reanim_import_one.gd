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

	if _args.has("source-dir"):
		return _run_report_batch(out_dir)

	_reset_file_state()
	var reanim := _parse_reanim(_args["source"])
	if reanim.is_empty():
		return 4

	if _is_truthy(String(_args.get("report-only", "false"))):
		var report_path := out_dir.path_join("semantic_report.json")
		_save_json(report_path, _build_semantic_report(reanim))
		print("Wrote reanim semantic report: %s" % report_path)
		return 0

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


func _run_report_batch(out_dir: String) -> int:
	var source_dir := _normalize_res_dir(String(_args["source-dir"]))
	var sources := _list_reanim_sources(source_dir)
	if sources.is_empty():
		push_error("No .reanim files found under --source-dir: %s" % source_dir)
		return 4

	var entries: Array[Dictionary] = []
	for source_path in sources:
		_reset_file_state()
		var reanim := _parse_reanim(source_path)
		if reanim.is_empty():
			entries.append({
				"source": source_path,
				"ok": false,
				"error": "parse_failed",
			})
			continue

		var report := _build_semantic_report(reanim)
		var report_file := "%s.semantic_report.json" % source_path.get_file().get_basename()
		var report_path := out_dir.path_join(report_file)
		_save_json(report_path, report)
		entries.append({
			"source": source_path,
			"ok": true,
			"report": report_path,
			"track_count": int(report["track_count"]),
			"marker_track_count": int(report["marker_track_count"]),
			"visual_layer_count": int(report["visual_layer_count"]),
			"suspected_overlay_count": int(report["suspected_overlay_count"]),
			"suspected_attachment_count": int(report["suspected_attachment_count"]),
			"unresolved_layer_count": int(report["unresolved_layer_count"]),
			"angle_warning_count": int(report["angle_warning_count"]),
		})

	var index_payload := {
		"source_dir": source_dir,
		"report_count": entries.size(),
		"reports": entries,
	}
	var index_path := out_dir.path_join("semantic_report_index.json")
	_save_json(index_path, index_payload)
	print("Wrote %d reanim semantic reports: %s" % [entries.size(), index_path])
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
	for key in ["image-root", "resources", "out-dir"]:
		if not args.has(key) or String(args[key]).strip_edges() == "":
			push_error("Missing required argument: --%s" % key)
			return false

	if not args.has("source") and not args.has("source-dir"):
		push_error("Missing required argument: --source or --source-dir")
		return false

	if not _is_truthy(String(args.get("report-only", "false"))) and not args.has("source-dir"):
		if not args.has("profile-id") or String(args["profile-id"]).strip_edges() == "":
			push_error("Missing required argument: --profile-id")
			return false

	if args.has("source") and not FileAccess.file_exists(String(args["source"])):
		push_error("File not found for --source: %s" % String(args["source"]))
		return false

	if args.has("source-dir") and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(String(args["source-dir"]))):
		push_error("Source directory not found: %s" % String(args["source-dir"]))
		return false

	for file_key in ["resources"]:
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
	print("  godot --headless --script res://tools/reanim_importer/reanim_import_one.gd -- --source <file.reanim> --image-root <res://dir> --resources <resources.xml> --out-dir <res://dir> --report-only true")
	print("  godot --headless --script res://tools/reanim_importer/reanim_import_one.gd -- --source-dir <res://dir> --image-root <res://dir> --resources <resources.xml> --out-dir <res://dir>")


func _normalize_res_dir(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


func _is_truthy(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized in ["1", "true", "yes", "on"]


func _reset_file_state() -> void:
	_loaded_textures = {}
	_unresolved_textures = {}
	_blend_modes = {}
	_warnings = []
	_verification = {}


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
	var is_visible := true
	for frame in track.get("frames", []):
		var frame_dict: Dictionary = frame
		var frame_index := int(frame_dict.get("frame", 0))
		if not frame_dict.has("f"):
			if is_visible:
				if start_frame == -1:
					start_frame = frame_index
				end_frame = frame_index
			continue

		var visible_flag := String(frame_dict["f"])
		if visible_flag == "0":
			is_visible = true
			if start_frame == -1:
				start_frame = frame_index
			end_frame = frame_index
		elif visible_flag == "-1":
			is_visible = false
			if start_frame != -1:
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
		_insert_key(animation, node_name, "position", time, state["position"], Animation.UPDATE_CONTINUOUS)
		_insert_key(animation, node_name, "scale", time, state["scale"], Animation.UPDATE_CONTINUOUS)
		_insert_key(animation, node_name, "rotation", time, state["rotation"], Animation.UPDATE_CONTINUOUS)
		_insert_key(animation, node_name, "skew", time, state["skew"], Animation.UPDATE_CONTINUOUS)
		_insert_key(animation, node_name, "self_modulate", time, state["self_modulate"], Animation.UPDATE_CONTINUOUS)
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
		var next_rotation := _degrees_to_radians_continuous(float(frame["kx"]))
		state["rotation"] = next_rotation
		state["skew"] = axis_angle - next_rotation
	if frame.has("ky"):
		axis_angle = _degrees_to_radians_continuous(float(frame["ky"]))
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
	_insert_key(animation, node_name, property_name, time, value, update_mode)


func _insert_key(animation: Animation, node_name: String, property_name: String, time: float, value: Variant, update_mode: int) -> void:
	var track_index := _ensure_value_track(animation, NodePath("%s:%s" % [node_name, property_name]), update_mode)
	animation.track_insert_key(track_index, time, value)


func _degrees_to_radians_continuous(degrees: float) -> float:
	return deg_to_rad(degrees)


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


func _build_semantic_report(reanim: Dictionary) -> Dictionary:
	var frame_count := int(reanim["frame_count"])
	var marker_tracks: Array[Dictionary] = []
	for marker in reanim["markers"]:
		marker_tracks.append(_summarize_track_semantics(marker, "marker", frame_count))

	var track_summaries: Array[Dictionary] = []
	var visual_layers: Array[Dictionary] = []
	var suspected_overlays: Array[Dictionary] = []
	var suspected_attachments: Array[Dictionary] = []
	var default_visible_segments: Array[Dictionary] = []
	var unresolved_layers: Array[Dictionary] = []
	var angle_warnings: Array[Dictionary] = []
	var blend_modes_seen: Dictionary = {}
	var texture_keys_seen: Dictionary = {}

	for track in reanim["tracks"]:
		var summary := _summarize_track_semantics(track, "track", frame_count)
		track_summaries.append(summary)

		if bool(summary["is_visual_layer"]):
			visual_layers.append(_pick_track_summary_fields(summary))
		if bool(summary["is_suspected_overlay"]):
			suspected_overlays.append(_pick_track_summary_fields(summary))
		if bool(summary["is_suspected_attachment"]):
			suspected_attachments.append(_pick_track_summary_fields(summary))
		if int(summary["unresolved_texture_count"]) > 0:
			unresolved_layers.append(_pick_track_summary_fields(summary))

		for segment in summary["visible_segments"]:
			var segment_dict: Dictionary = segment
			if bool(segment_dict.get("starts_from_default_visible", false)):
				default_visible_segments.append({
					"track": summary["name"],
					"start_frame": int(segment_dict["start_frame"]),
					"end_frame": int(segment_dict["end_frame"]),
				})

		for warning in summary["angle_warnings"]:
			angle_warnings.append(warning)
		for blend_mode in summary["blend_modes"]:
			blend_modes_seen[String(blend_mode)] = true
		for texture_key in summary["texture_keys"]:
			texture_keys_seen[String(texture_key)] = true

	var overlay_bindings := _infer_overlay_bindings(track_summaries)
	var overlay_follow_warning_count := 0
	for binding in overlay_bindings:
		var binding_dict: Dictionary = binding
		if String(binding_dict.get("recommended_parent_track", "")) != "":
			overlay_follow_warning_count += 1

	var animations: Array[Dictionary] = []
	for animation_def in reanim["animations"]:
		animations.append({
			"name": String(animation_def.get("name", "")),
			"start_frame": int(animation_def.get("start_frame", 0)),
			"end_frame": int(animation_def.get("end_frame", 0)),
			"source_track": String(animation_def.get("source_track", "")),
			"source_kind": String(animation_def.get("source_kind", "marker")),
		})

	return {
		"source": reanim["source"],
		"fps": int(reanim["fps"]),
		"frame_count": frame_count,
		"track_count": int(reanim["tracks"].size() + reanim["markers"].size()),
		"marker_track_count": marker_tracks.size(),
		"visual_track_count": reanim["tracks"].size(),
		"visual_layer_count": visual_layers.size(),
		"suspected_overlay_count": suspected_overlays.size(),
		"suspected_attachment_count": suspected_attachments.size(),
		"default_visible_segment_count": default_visible_segments.size(),
		"unresolved_layer_count": unresolved_layers.size(),
		"angle_warning_count": angle_warnings.size(),
		"overlay_binding_count": overlay_bindings.size(),
		"overlay_follow_warning_count": overlay_follow_warning_count,
		"marker_tracks": marker_tracks,
		"track_summaries": track_summaries,
		"visual_layers": visual_layers,
		"suspected_overlays": suspected_overlays,
		"suspected_attachments": suspected_attachments,
		"overlay_bindings": overlay_bindings,
		"default_visible_segments": default_visible_segments,
		"unresolved_layers": unresolved_layers,
		"angle_warnings": angle_warnings,
		"animations": animations,
		"texture_key_count": texture_keys_seen.size(),
		"blend_modes_seen": blend_modes_seen.keys(),
		"warnings": _warnings,
	}


func _summarize_track_semantics(track: Dictionary, kind: String, frame_count: int) -> Dictionary:
	var track_name := String(track.get("name", ""))
	var field_counts: Dictionary = {}
	var texture_keys: Dictionary = {}
	var unresolved_textures: Array[String] = []
	var resolved_textures: Array[Dictionary] = []
	var blend_modes: Dictionary = {}
	var angle_warnings: Array[Dictionary] = []
	var previous_angles: Dictionary = {}

	for frame in track.get("frames", []):
		var frame_dict: Dictionary = frame
		var frame_index := int(frame_dict.get("frame", 0))
		for key in frame_dict.keys():
			var field := String(key)
			if field == "frame":
				continue
			field_counts[field] = int(field_counts.get(field, 0)) + 1

		if frame_dict.has("i"):
			var texture_key := String(frame_dict["i"])
			texture_keys[texture_key] = true
			var resolved_path := _resolve_texture_path(texture_key)
			if resolved_path == "":
				if not unresolved_textures.has(texture_key):
					unresolved_textures.append(texture_key)
			else:
				resolved_textures.append({
					"frame": frame_index,
					"key": texture_key,
					"path": resolved_path,
				})

		if frame_dict.has("bm"):
			blend_modes[String(frame_dict["bm"])] = true

		for angle_field in ["kx", "ky"]:
			if not frame_dict.has(angle_field):
				continue
			var degrees := float(frame_dict[angle_field])
			if absf(degrees) >= 360.0:
				angle_warnings.append({
					"track": track_name,
					"frame": frame_index,
					"field": angle_field,
					"degrees": degrees,
					"reason": "absolute_angle_at_or_above_360",
				})
			if previous_angles.has(angle_field):
				var previous := float(previous_angles[angle_field])
				if absf(degrees - previous) > 180.0:
					angle_warnings.append({
						"track": track_name,
						"frame": frame_index,
						"field": angle_field,
						"degrees": degrees,
						"previous_degrees": previous,
						"reason": "large_frame_to_frame_delta",
					})
			previous_angles[angle_field] = degrees

	var visible_segments := _derive_track_visible_segments(track, frame_count)
	var has_texture := not texture_keys.is_empty()
	var has_transform := _has_any_field(field_counts, ["x", "y", "sx", "sy", "kx", "ky"])
	var has_alpha := field_counts.has("a")
	var is_marker := kind == "marker"
	var is_anim_track := track_name.begins_with("anim_")
	var lower_name := track_name.to_lower()
	var is_suspected_attachment := not is_marker and is_anim_track and not has_texture and has_transform
	var is_short_visible := _is_short_visible_track(visible_segments, frame_count)
	var is_overlay_name := _name_suggests_overlay(lower_name)
	var is_suspected_overlay := not is_marker and has_texture and (is_overlay_name or (is_anim_track and is_short_visible and _is_micro_visible_track(visible_segments)))
	var is_visual_layer := not is_marker and (has_texture or has_transform or has_alpha)
	var semantic_kind := "marker"
	if not is_marker:
		if is_suspected_attachment:
			semantic_kind = "suspected_attachment"
		elif is_suspected_overlay:
			semantic_kind = "suspected_overlay"
		elif is_visual_layer:
			semantic_kind = "visual_layer"
		else:
			semantic_kind = "unclassified"

	return {
		"name": track_name,
		"semantic_kind": semantic_kind,
		"frame_count": track.get("frames", []).size(),
		"field_counts": field_counts,
		"texture_keys": texture_keys.keys(),
		"resolved_texture_count": resolved_textures.size(),
		"resolved_texture_samples": resolved_textures.slice(0, min(5, resolved_textures.size())),
		"unresolved_textures": unresolved_textures,
		"unresolved_texture_count": unresolved_textures.size(),
		"visible_segments": visible_segments,
		"blend_modes": blend_modes.keys(),
		"angle_warnings": angle_warnings,
		"is_marker": is_marker,
		"is_visual_layer": is_visual_layer,
		"is_suspected_overlay": is_suspected_overlay,
		"is_suspected_attachment": is_suspected_attachment,
		"is_default_visible": _has_default_visible_segment(visible_segments),
		"has_texture": has_texture,
		"has_transform": has_transform,
	}


func _derive_track_visible_segments(track: Dictionary, frame_count: int) -> Array[Dictionary]:
	var segments: Array[Dictionary] = []
	var is_visible := true
	var segment_start := 0
	var starts_from_default := true
	var has_open_segment := frame_count > 0

	for frame in track.get("frames", []):
		var frame_dict: Dictionary = frame
		if not frame_dict.has("f"):
			continue

		var frame_index := int(frame_dict.get("frame", 0))
		var visible_flag := String(frame_dict["f"])
		if visible_flag == "-1":
			if is_visible and has_open_segment and frame_index > segment_start:
				segments.append({
					"start_frame": segment_start,
					"end_frame": frame_index - 1,
					"starts_from_default_visible": starts_from_default,
				})
			is_visible = false
			has_open_segment = false
		elif visible_flag == "0":
			if not is_visible:
				segment_start = frame_index
				starts_from_default = false
				has_open_segment = true
			is_visible = true

	if is_visible and has_open_segment:
		segments.append({
			"start_frame": segment_start,
			"end_frame": max(0, frame_count - 1),
			"starts_from_default_visible": starts_from_default,
		})
	return segments


func _has_any_field(field_counts: Dictionary, fields: Array[String]) -> bool:
	for field in fields:
		if field_counts.has(field):
			return true
	return false


func _has_default_visible_segment(visible_segments: Array) -> bool:
	for segment in visible_segments:
		var segment_dict: Dictionary = segment
		if bool(segment_dict.get("starts_from_default_visible", false)):
			return true
	return false


func _is_short_visible_track(visible_segments: Array, frame_count: int) -> bool:
	if frame_count <= 0 or visible_segments.is_empty():
		return false
	var visible_frames := 0
	for segment in visible_segments:
		var segment_dict: Dictionary = segment
		visible_frames += int(segment_dict["end_frame"]) - int(segment_dict["start_frame"]) + 1
	return visible_frames < int(ceil(float(frame_count) * 0.5))


func _is_micro_visible_track(visible_segments: Array) -> bool:
	var visible_frames := 0
	for segment in visible_segments:
		var segment_dict: Dictionary = segment
		visible_frames += int(segment_dict["end_frame"]) - int(segment_dict["start_frame"]) + 1
	return visible_frames <= 6


func _name_suggests_overlay(lower_name: String) -> bool:
	for token in ["blink", "eye", "glow", "light", "shine", "spark", "tongue", "zombie", "arm", "effect"]:
		if lower_name.contains(token):
			return true
	return false


func _infer_overlay_bindings(track_summaries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for summary in track_summaries:
		if not bool(summary.get("is_suspected_overlay", false)):
			continue

		var parent := _find_overlay_parent(summary, track_summaries)
		var binding := {
			"overlay_track": String(summary["name"]),
			"recommended_parent_track": String(parent.get("name", "")),
			"confidence": String(parent.get("confidence", "none")),
			"reason": String(parent.get("reason", "no suitable moving visual parent found")),
			"transform_policy": "inherit_parent_current_transform",
			"implementation_note": "Do not play this overlay as a full actor replacement or pin it to world coordinates.",
			"visible_segments": summary["visible_segments"],
		}
		result.append(binding)
	return result


func _find_overlay_parent(overlay_summary: Dictionary, track_summaries: Array[Dictionary]) -> Dictionary:
	var best_score := -999999
	var best_summary: Dictionary = {}
	var best_reasons: Array[String] = []
	for candidate in track_summaries:
		if String(candidate.get("name", "")) == String(overlay_summary.get("name", "")):
			continue
		if bool(candidate.get("is_marker", false)):
			continue
		if bool(candidate.get("is_suspected_attachment", false)):
			continue
		if bool(candidate.get("is_suspected_overlay", false)):
			continue
		if not bool(candidate.get("has_texture", false)):
			continue

		var score_info := _score_overlay_parent_candidate(overlay_summary, candidate)
		var score := int(score_info["score"])
		if score > best_score:
			best_score = score
			best_summary = candidate
			best_reasons = score_info["reasons"]

	if best_summary.is_empty() or best_score < 20:
		return {}

	var confidence := "low"
	if best_score >= 80:
		confidence = "high"
	elif best_score >= 45:
		confidence = "medium"

	return {
		"name": String(best_summary["name"]),
		"confidence": confidence,
		"reason": "; ".join(best_reasons),
	}


func _score_overlay_parent_candidate(overlay_summary: Dictionary, candidate: Dictionary) -> Dictionary:
	var overlay_name := String(overlay_summary.get("name", "")).to_lower()
	var candidate_name := String(candidate.get("name", "")).to_lower()
	var overlay_texture_text := " ".join(_to_string_array(overlay_summary.get("texture_keys", []))).to_lower()
	var candidate_texture_text := " ".join(_to_string_array(candidate.get("texture_keys", []))).to_lower()
	var score := 0
	var reasons: Array[String] = []

	if _segments_overlap_or_touch(overlay_summary.get("visible_segments", []), candidate.get("visible_segments", []), 2):
		score += 20
		reasons.append("visible segment overlaps or touches parent candidate")

	var overlay_head_index := _extract_head_index("%s %s" % [overlay_name, overlay_texture_text])
	var candidate_head_index := _extract_head_index("%s %s" % [candidate_name, candidate_texture_text])
	if overlay_head_index != "" and overlay_head_index == candidate_head_index:
		score += 45
		reasons.append("same head index %s" % overlay_head_index)

	if overlay_name.contains("blink") or overlay_texture_text.contains("blink") or overlay_name.contains("eye") or overlay_texture_text.contains("eye"):
		if candidate_name.contains("face"):
			score += 65
			reasons.append("eye/blink overlay prefers face visual parent")
		elif candidate_texture_text.contains("head") and not candidate_texture_text.contains("headleaf"):
			score += 35
			reasons.append("eye/blink overlay prefers face/head visual parent")
		elif candidate_name.contains("head") or candidate_name == "anim_idle":
			score += 30
			reasons.append("eye/blink overlay prefers moving head parent")

	if overlay_name.begins_with("anim_blink") and candidate_name == "anim_idle":
		score += 80
		reasons.append("anim_blink conventionally follows anim_idle local head layer")

	var shared_prefix := _shared_prefix_score(overlay_name, candidate_name)
	if shared_prefix > 0:
		score += shared_prefix
		reasons.append("shares name prefix")

	if candidate_name.contains("leaf") and (overlay_name.contains("blink") or overlay_name.contains("eye")):
		score -= 45
		reasons.append("leaf is a weaker parent for eye/blink overlay")

	return {
		"score": score,
		"reasons": reasons,
	}


func _segments_overlap_or_touch(left_segments: Array, right_segments: Array, tolerance_frames: int) -> bool:
	for left in left_segments:
		var left_dict: Dictionary = left
		var left_start := int(left_dict["start_frame"]) - tolerance_frames
		var left_end := int(left_dict["end_frame"]) + tolerance_frames
		for right in right_segments:
			var right_dict: Dictionary = right
			var right_start := int(right_dict["start_frame"])
			var right_end := int(right_dict["end_frame"])
			if left_start <= right_end and right_start <= left_end:
				return true
	return false


func _extract_head_index(value: String) -> String:
	var regex := RegEx.new()
	if regex.compile("(?:head|face)[_a-z]*([0-9]+)") != OK:
		return ""
	var match := regex.search(value)
	if match == null:
		return ""
	return match.get_string(1)


func _shared_prefix_score(left: String, right: String) -> int:
	var left_parts := left.split("_", false)
	var right_parts := right.split("_", false)
	var count := 0
	var limit: int = min(left_parts.size(), right_parts.size())
	for i in range(limit):
		if left_parts[i] != right_parts[i]:
			break
		count += 1
	return min(count * 5, 20)


func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result


func _pick_track_summary_fields(summary: Dictionary) -> Dictionary:
	return {
		"name": String(summary["name"]),
		"semantic_kind": String(summary["semantic_kind"]),
		"texture_keys": summary["texture_keys"],
		"unresolved_textures": summary["unresolved_textures"],
		"visible_segments": summary["visible_segments"],
		"field_counts": summary["field_counts"],
		"angle_warning_count": summary["angle_warnings"].size(),
	}


func _list_reanim_sources(source_dir: String) -> Array[String]:
	var result: Array[String] = []
	_collect_reanim_sources(source_dir, result)
	result.sort()
	return result


func _collect_reanim_sources(res_dir: String, output: Array[String]) -> void:
	var absolute_dir := ProjectSettings.globalize_path(res_dir)
	for file_name in DirAccess.get_files_at(absolute_dir):
		if String(file_name).get_extension().to_lower() == "reanim":
			output.append(res_dir.path_join(file_name))
	if not _is_truthy(String(_args.get("recursive", "false"))):
		return
	for dir_name in DirAccess.get_directories_at(absolute_dir):
		if String(dir_name).begins_with("."):
			continue
		_collect_reanim_sources(res_dir.path_join(dir_name), output)


func _save_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write JSON report: %s" % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


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
		"semantic_analysis": _build_semantic_report(reanim),
		"verification": _verification,
		"warnings": _warnings,
	}
	_save_json(report_path, payload)


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
