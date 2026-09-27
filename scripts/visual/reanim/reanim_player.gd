extends Node2D
class_name ReanimPlayer
## Native reanim playback for a single ReanimData resource (spike T2).
##
## Sampling follows the de-pvz Reanimator semantics:
## - x/y/kx/ky/sx/sy/a are linearly interpolated between frames
##   (GetTransformAtTime), image and image_frame take the discrete value of
##   the frame before the play head.
## - The track transform is built via MatrixFromTransform:
##   column x = (cos(kx), sin(kx)) * sx, column y = (-sin(ky), cos(ky)) * sy
##   with kx/ky in radians, origin = (x, y).
##
## Playback phase is anchored to the simulation clock, never the wall clock:
## phase = phase_at_epoch + (GameState.current_time - epoch_sim_time) * visual_speed.
## Pausing the simulation therefore freezes the phase, and manual ticks
## advance it deterministically.

const ReanimDataRef = preload("res://scripts/visual/reanim/reanim_data.gd")

const DIAGNOSTIC_SCOPE := &"reanim_runtime"

var _data: ReanimDataRef = null
var _valid := false
var _active := false
var _game_state: Node = null
var _clip: Dictionary = {}
var _clip_loop := true
var _direction := 1.0
var _visual_speed := 1.0
var _phase_at_epoch := 0.0
var _epoch_sim_time := 0.0
## Visual track index per sprite child, in draw order (source file order).
var _visual_track_indices: PackedInt32Array = PackedInt32Array()
var _sprites: Array[Sprite2D] = []
var _textures: Array[Texture2D] = []
## Track indices whose sprites stay hidden (composite visibility masks).
var _hidden_track_lookup: Dictionary = {}


func setup(data: ReanimDataRef) -> bool:
	_clear()
	if data == null:
		_report_issue("setup rejected: ReanimData is null")
		return false
	var problems := data.validate()
	if not problems.is_empty():
		_report_issue("setup rejected for %s: %s" % [String(data.source_id), ", ".join(problems)])
		return false
	if not _load_textures(data):
		return false
	_data = data
	for track_index in data.get_track_count():
		if data.track_kinds[track_index] != ReanimDataRef.TRACK_KIND_VISUAL:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "%s_%d" % [_sanitize_node_name(data.track_names[track_index]), track_index]
		sprite.centered = false
		sprite.visible = false
		add_child(sprite)
		_sprites.append(sprite)
		_visual_track_indices.append(track_index)
	_valid = true
	return true


func is_valid() -> bool:
	return _valid


func get_data() -> ReanimDataRef:
	return _data


func play_clip(clip_name: StringName, loop: bool = true, direction: float = 1.0) -> bool:
	if not _valid:
		_report_issue("play_clip(%s) rejected: player has no valid ReanimData" % String(clip_name))
		return false
	var clip := _data.get_clip(String(clip_name))
	if clip.is_empty():
		_report_issue("play_clip rejected for %s: unknown clip \"%s\"" % [String(_data.source_id), String(clip_name)])
		return false
	_clip = clip
	_clip_loop = loop
	_direction = -1.0 if direction < 0.0 else 1.0
	_phase_at_epoch = 0.0
	_epoch_sim_time = _now()
	_active = true
	sample_now()
	return true


func stop() -> void:
	_active = false


func get_clip_name() -> StringName:
	return StringName(String(_clip.get("name", "")))


func is_playing() -> bool:
	return _active


## Re-anchors the phase epoch so a speed change never causes a phase jump.
func set_visual_speed(speed: float) -> void:
	var now := _now()
	_phase_at_epoch = get_phase_seconds(now)
	_epoch_sim_time = now
	_visual_speed = maxf(speed, 0.0)


func get_visual_speed() -> float:
	return _visual_speed


## Local phase in seconds along the clip timeline (unwrapped).
func get_phase_seconds(sim_time: float = -1.0) -> float:
	var now := sim_time if sim_time >= 0.0 else _now()
	return _phase_at_epoch + (now - _epoch_sim_time) * _visual_speed


## Absolute frame position inside the data, derived from the current phase.
func get_frame_position(sim_time: float = -1.0) -> float:
	if _clip.is_empty():
		return 0.0
	var clip_start := int(_clip.get("start_frame", 0))
	var clip_frames := int(_clip.get("frame_count", 1))
	if clip_frames <= 1 or _data == null:
		return float(clip_start)
	# de-pvz GetFrameTime: a looping clip spans frame_count - 1 frame intervals.
	var span := float(clip_frames - 1)
	var offset := get_phase_seconds(sim_time) * float(_data.fps) * _direction
	if _direction < 0.0:
		offset += span
	if _clip_loop:
		offset = fposmod(offset, span)
	else:
		offset = clampf(offset, 0.0, span)
	return float(clip_start) + offset


func is_finished() -> bool:
	if _clip_loop or _clip.is_empty() or _data == null:
		return false
	var clip_frames := int(_clip.get("frame_count", 1))
	var span := float(maxi(clip_frames - 1, 0))
	return get_phase_seconds() * float(_data.fps) >= span


func sample_now() -> void:
	if _active:
		sample_at_frame(get_frame_position())


## Deterministic sampling entry point (also used by validation probes).
func sample_at_frame(frame_position: float) -> void:
	if not _valid or _clip.is_empty():
		return
	var window := _frame_window(frame_position)
	var frame_before := int(window[0])
	var frame_after := int(window[1])
	var lerp_t := float(window[2])
	for sprite_index in _sprites.size():
		var track_index := _visual_track_indices[sprite_index]
		var sprite := _sprites[sprite_index]
		if _hidden_track_lookup.has(track_index):
			sprite.visible = false
			continue
		var image_frame := _data.get_image_frame(track_index, frame_before)
		if image_frame < 0:
			sprite.visible = false
			continue
		var image_index := _data.get_image_index(track_index, frame_before)
		# Tracks without any image stay visible with a null texture, matching
		# the legacy chain (they draw nothing but keep their transform).
		sprite.texture = _textures[image_index] if image_index >= 0 and image_index < _textures.size() else null
		sprite.transform = _interpolated_transform(track_index, frame_before, frame_after, lerp_t)
		var alpha := lerpf(
			_data.get_float(track_index, frame_before, ReanimDataRef.FLOAT_ALPHA),
			_data.get_float(track_index, frame_after, ReanimDataRef.FLOAT_ALPHA),
			lerp_t)
		sprite.self_modulate = Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0))
		sprite.visible = true


## Draw-order snapshot for validation probes (deterministic, no wall clock).
func get_draw_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for sprite_index in _sprites.size():
		var track_index := _visual_track_indices[sprite_index]
		var sprite := _sprites[sprite_index]
		var texture_file := ""
		if sprite.texture != null:
			texture_file = sprite.texture.resource_path.get_file()
			if texture_file == "":
				texture_file = sprite.texture.resource_name
		snapshot.append({
			"order": sprite_index,
			"track": _data.track_names[track_index],
			"visible": sprite.visible,
			"texture": texture_file,
			"transform": sprite.transform,
			"alpha": sprite.self_modulate.a,
		})
	return snapshot


func get_visual_track_names() -> PackedStringArray:
	var names := PackedStringArray()
	for track_index in _visual_track_indices:
		names.append(_data.track_names[track_index])
	return names


func has_track(track_name: String) -> bool:
	return _valid and _data.find_track(track_name) >= 0


## Hides the sprites of the named tracks (transform data stays sampleable).
func set_hidden_track_names(track_names: PackedStringArray) -> void:
	_hidden_track_lookup.clear()
	if not _valid:
		return
	for track_name in track_names:
		var track_index := _data.find_track(track_name)
		if track_index >= 0:
			_hidden_track_lookup[track_index] = true
	for sprite_index in _sprites.size():
		if _hidden_track_lookup.has(_visual_track_indices[sprite_index]):
			_sprites[sprite_index].visible = false
	sample_now()


## Samples one track's transform at the given frame position (defaults to the
## current play head), clamped to the active clip like sample_at_frame. Used
## by composite actors for host-track bindings and track-based anchors.
func get_track_transform(track_name: String, frame_position: float = -1.0) -> Transform2D:
	if not _valid:
		return Transform2D.IDENTITY
	var track_index := _data.find_track(track_name)
	if track_index < 0:
		_report_issue("get_track_transform rejected for %s: unknown track \"%s\"" % [String(_data.source_id), track_name])
		return Transform2D.IDENTITY
	var target := frame_position if frame_position >= 0.0 else get_frame_position()
	var window := _frame_window(target)
	return _interpolated_transform(track_index, int(window[0]), int(window[1]), float(window[2]))


## Clamps a frame position to the active clip (or the whole data range when
## no clip is active) and returns [frame_before, frame_after, lerp_t].
func _frame_window(frame_position: float) -> Array:
	var first_frame := 0
	var last_frame := maxi(_data.frame_count - 1, 0)
	if not _clip.is_empty():
		first_frame = int(_clip.get("start_frame", 0))
		last_frame = first_frame + maxi(int(_clip.get("frame_count", 1)) - 1, 0)
	var frame_before := clampi(int(floor(frame_position)), first_frame, last_frame)
	var frame_after := mini(frame_before + 1, last_frame)
	var lerp_t := clampf(frame_position - float(frame_before), 0.0, 1.0)
	return [frame_before, frame_after, lerp_t]


func _process(_delta: float) -> void:
	sample_now()


func _interpolated_transform(track_index: int, frame_before: int, frame_after: int, lerp_t: float) -> Transform2D:
	var x := lerpf(
		_data.get_float(track_index, frame_before, ReanimDataRef.FLOAT_X),
		_data.get_float(track_index, frame_after, ReanimDataRef.FLOAT_X), lerp_t)
	var y := lerpf(
		_data.get_float(track_index, frame_before, ReanimDataRef.FLOAT_Y),
		_data.get_float(track_index, frame_after, ReanimDataRef.FLOAT_Y), lerp_t)
	var kx_deg := lerpf(
		_data.get_float(track_index, frame_before, ReanimDataRef.FLOAT_KX_DEG),
		_data.get_float(track_index, frame_after, ReanimDataRef.FLOAT_KX_DEG), lerp_t)
	var ky_deg := lerpf(
		_data.get_float(track_index, frame_before, ReanimDataRef.FLOAT_KY_DEG),
		_data.get_float(track_index, frame_after, ReanimDataRef.FLOAT_KY_DEG), lerp_t)
	var sx := lerpf(
		_data.get_float(track_index, frame_before, ReanimDataRef.FLOAT_SX),
		_data.get_float(track_index, frame_after, ReanimDataRef.FLOAT_SX), lerp_t)
	var sy := lerpf(
		_data.get_float(track_index, frame_before, ReanimDataRef.FLOAT_SY),
		_data.get_float(track_index, frame_after, ReanimDataRef.FLOAT_SY), lerp_t)
	return build_track_transform(x, y, kx_deg, ky_deg, sx, sy)


## de-pvz Reanimation::MatrixFromTransform equivalent.
static func build_track_transform(x: float, y: float, kx_deg: float, ky_deg: float, sx: float, sy: float) -> Transform2D:
	var skew_x := -deg_to_rad(kx_deg)
	var skew_y := -deg_to_rad(ky_deg)
	return Transform2D(
		Vector2(cos(skew_x) * sx, -sin(skew_x) * sx),
		Vector2(sin(skew_y) * sy, cos(skew_y) * sy),
		Vector2(x, y))


func _load_textures(data: ReanimDataRef) -> bool:
	var loaded: Array[Texture2D] = []
	for image_index in data.image_paths.size():
		var image_path := data.image_paths[image_index]
		var texture := _load_texture_from_path(image_path)
		if texture == null:
			_report_issue("missing reanim texture for %s: %s (%s)" % [
				String(data.source_id), data.image_refs[image_index], image_path])
			return false
		loaded.append(texture)
	_textures = loaded
	return true


## Private-pack sources are not part of the Godot import pipeline, so fall
## back to loading the raw image file when no imported resource exists.
static func _load_texture_from_path(image_path: String) -> Texture2D:
	if image_path == "":
		return null
	if ResourceLoader.exists(image_path):
		return ResourceLoader.load(image_path) as Texture2D
	if not FileAccess.file_exists(image_path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(image_path))
	if image == null or image.is_empty():
		return null
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = image_path.get_file()
	return texture


func _clear() -> void:
	_valid = false
	_active = false
	_data = null
	_clip = {}
	_textures = []
	_hidden_track_lookup.clear()
	_visual_track_indices = PackedInt32Array()
	for sprite in _sprites:
		sprite.queue_free()
	_sprites = []


func _now() -> float:
	if _game_state == null or not is_instance_valid(_game_state):
		_game_state = _find_singleton("GameState")
	if _game_state == null:
		return 0.0
	return float(_game_state.get("current_time"))


func _sanitize_node_name(value: String) -> String:
	var sanitized := value.strip_edges()
	for ch in [" ", ".", "/", "\\", ":", ";", ",", "(", ")", "[", "]"]:
		sanitized = sanitized.replace(ch, "_")
	if sanitized == "":
		return "Track"
	return sanitized


func _report_issue(message: String) -> void:
	var debug_service := _find_singleton("DebugService")
	if debug_service != null and debug_service.has_method("record_protocol_issue"):
		debug_service.record_protocol_issue(DIAGNOSTIC_SCOPE, message, &"error")


## Autoload lookup through the main loop so this script also compiles in
## headless tool mode (no autoload globals there; diagnostics become no-ops).
static func _find_singleton(singleton_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(singleton_name))
