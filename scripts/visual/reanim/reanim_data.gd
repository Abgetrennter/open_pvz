extends Resource
class_name ReanimData
## Immutable reanim animation data (schema v1) for the native reanim runtime.
##
## Produced by tools/reanim_importer/reanim_import_one.gd with --emit-reanim-data.
## Track frame data is expanded at import time following the de-pvz
## ReanimationFillInMissingData semantics (carry-forward with defaults), so
## runtime sampling is O(1) per (track, frame) with no per-frame dictionaries.
##
## Packed layout:
## - frame_floats: FLOAT_STRIDE values per (track, frame): x, y, kx_deg, ky_deg, sx, sy, alpha
## - frame_ints: INT_STRIDE values per (track, frame): image_index (-1 = none), image_frame (f, < 0 = hidden)
## Index base for (track, frame) = (track * frame_count + frame) * stride.

const SCHEMA_VERSION := 1

const FLOAT_STRIDE := 7
const FLOAT_X := 0
const FLOAT_Y := 1
const FLOAT_KX_DEG := 2
const FLOAT_KY_DEG := 3
const FLOAT_SX := 4
const FLOAT_SY := 5
const FLOAT_ALPHA := 6

const INT_STRIDE := 2
const INT_IMAGE_INDEX := 0
const INT_IMAGE_FRAME := 1

const TRACK_KIND_VISUAL := 0
const TRACK_KIND_MARKER := 1

@export var schema_version: int = SCHEMA_VERSION
@export var source_id: StringName = &""
@export var source_path: String = ""
@export var source_hash: String = ""
@export var fps: int = 12
@export var frame_count: int = 0
@export var track_names: PackedStringArray = PackedStringArray()
@export var track_kinds: PackedInt32Array = PackedInt32Array()
@export var frame_floats: PackedFloat32Array = PackedFloat32Array()
@export var frame_ints: PackedInt32Array = PackedInt32Array()
## Reanim texture keys (e.g. IMAGE_REANIM_PEASHOOTER_HEAD), aligned with image_paths.
@export var image_refs: PackedStringArray = PackedStringArray()
@export var image_paths: PackedStringArray = PackedStringArray()
@export var font_refs: PackedStringArray = PackedStringArray()
@export var text_table: PackedStringArray = PackedStringArray()
## Clip entries: {name: String, start_frame: int, frame_count: int, source_kind: String, confirmed: bool}
@export var clips: Array[Dictionary] = []
## Capability flags observed in the source (has_text/has_font/has_attacher/has_blend_mode ...).
@export var feature_flags: Dictionary = {}


func get_track_count() -> int:
	return track_names.size()


func find_track(track_name: String) -> int:
	for i in range(track_names.size()):
		if track_names[i] == track_name:
			return i
	return -1


func get_float(track_index: int, frame: int, field: int) -> float:
	return frame_floats[(track_index * frame_count + frame) * FLOAT_STRIDE + field]


func get_image_index(track_index: int, frame: int) -> int:
	return frame_ints[(track_index * frame_count + frame) * INT_STRIDE + INT_IMAGE_INDEX]


func get_image_frame(track_index: int, frame: int) -> int:
	return frame_ints[(track_index * frame_count + frame) * INT_STRIDE + INT_IMAGE_FRAME]


func is_frame_hidden(track_index: int, frame: int) -> bool:
	return get_image_frame(track_index, frame) < 0


func get_clip(clip_name: String) -> Dictionary:
	for clip in clips:
		if String(clip.get("name", "")) == clip_name:
			return clip
	return {}


func get_clip_names() -> PackedStringArray:
	var names := PackedStringArray()
	for clip in clips:
		names.append(String(clip.get("name", "")))
	return names


## Structural consistency check; returns a list of problems (empty = valid).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if schema_version != SCHEMA_VERSION:
		problems.append("schema_version mismatch: %d != %d" % [schema_version, SCHEMA_VERSION])
	if frame_count <= 0:
		problems.append("frame_count must be positive")
	if fps <= 0:
		problems.append("fps must be positive")
	if track_kinds.size() != track_names.size():
		problems.append("track_kinds size %d != track_names size %d" % [track_kinds.size(), track_names.size()])
	var expected_floats := track_names.size() * frame_count * FLOAT_STRIDE
	if frame_floats.size() != expected_floats:
		problems.append("frame_floats size %d != expected %d" % [frame_floats.size(), expected_floats])
	var expected_ints := track_names.size() * frame_count * INT_STRIDE
	if frame_ints.size() != expected_ints:
		problems.append("frame_ints size %d != expected %d" % [frame_ints.size(), expected_ints])
	if image_paths.size() != image_refs.size():
		problems.append("image_paths size %d != image_refs size %d" % [image_paths.size(), image_refs.size()])
	for clip in clips:
		var clip_name := String(clip.get("name", ""))
		if clip_name == "":
			problems.append("clip with empty name")
			continue
		var start_frame := int(clip.get("start_frame", -1))
		var clip_frames := int(clip.get("frame_count", 0))
		if start_frame < 0 or clip_frames <= 0 or start_frame + clip_frames > frame_count:
			problems.append("clip out of range: %s [%d +%d) frame_count=%d" % [clip_name, start_frame, clip_frames, frame_count])
	return problems
