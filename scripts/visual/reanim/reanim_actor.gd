extends Node2D
class_name ReanimActor
## Native reanim actor exposing the VisualActorComponent optional contract
## (play_state / play_action / play_animation / set_visual_speed / get_anchor).
##
## Unrecognized states/actions return false so VisualActorComponent keeps its
## existing fallback semantics. Parts can be added manually (single-part T2
## path) or driven by a ReanimActorDef (composite T3 path): every part owns
## one ReanimPlayer; a part with a host binding follows a track sampled on its
## host part (generalized attachment, no per-plant runtime branches), and
## anchors resolve from part tracks plus a fixed offset.

const ReanimDataRef = preload("res://scripts/visual/reanim/reanim_data.gd")
const ReanimPlayerRef = preload("res://scripts/visual/reanim/reanim_player.gd")
const ReanimActorDefRef = preload("res://scripts/visual/reanim/reanim_actor_def.gd")

const DIAGNOSTIC_SCOPE := &"reanim_runtime"

## Optional composite definition applied on ready.
@export var actor_def: Resource = null

## StringName -> StringName clip (primary part) or Dictionary part_id -> clip
## (looped playback).
var state_clip_map: Dictionary = {}
## StringName -> StringName clip (primary part) or Dictionary part_id -> clip
## (one-shot playback; involved parts return to the current state).
var action_clip_map: Dictionary = {}

var _parts: Array[Dictionary] = []
var _primary_player: ReanimPlayerRef = null
var _primary_part_id: StringName = &""
var _base_local := Transform2D.IDENTITY
var _anchors: Dictionary = {}
## Anchor name (String) -> concrete {part, track, offset} config.
var _anchor_defs: Dictionary = {}
var _def_anchor_nodes: Array[Node2D] = []
var _current_state: StringName = &""
var _pending_action := false
var _pending_part_ids: Array[StringName] = []
var _visual_speed := 1.0


func _ready() -> void:
	if actor_def != null and not setup_from_def(actor_def):
		_report_issue("actor_def setup failed on ready: %s" % String(actor_def.resource_path))


## Builds parts, visibility masks, host bindings, anchors and clip maps from a
## ReanimActorDef. Fails closed (false + diagnostic) on any invalid data.
func setup_from_def(def: Resource) -> bool:
	var typed := def as ReanimActorDefRef
	if typed == null:
		_report_issue("setup_from_def rejected: def is not a ReanimActorDef")
		return false
	var problems := typed.validate()
	if not problems.is_empty():
		_report_issue("setup_from_def rejected for %s: %s" % [String(typed.def_id), ", ".join(problems)])
		return false
	_clear_composition()
	_base_local = Transform2D(0.0, Vector2.ONE * typed.root_scale, 0.0, typed.root_offset)
	var ordered := typed.parts.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("render_order", 0)) < int(b.get("render_order", 0)))
	for part_def in ordered:
		var part_id := StringName(String(part_def.get("id", "")))
		var data := part_def.get("reanim_data", null) as ReanimDataRef
		var initial_clip := StringName(String(part_def.get("initial_clip", "")))
		if not add_part(part_id, data, initial_clip, bool(part_def.get("loop", true))):
			_clear_composition()
			return false
		var part := _parts[_parts.size() - 1]
		var player := part.get("player", null) as ReanimPlayerRef
		player.transform = _base_local
		part["host_part_id"] = StringName(String(part_def.get("host_part_id", "")))
		part["host_track"] = String(part_def.get("host_track", ""))
		_parts[_parts.size() - 1] = part
		var hidden := _resolve_hidden_tracks(player, part_def.get("track_visibility", {}))
		if not hidden.is_empty():
			player.set_hidden_track_names(hidden)
	state_clip_map = _normalize_clip_maps(typed.states)
	action_clip_map = _normalize_clip_maps(typed.actions)
	if typed.initial_state != &"" and not play_state(typed.initial_state):
		_report_issue("setup_from_def could not play initial state %s for %s" % [String(typed.initial_state), String(typed.def_id)])
		_clear_composition()
		return false
	_capture_host_bases()
	_build_def_anchors(typed)
	refresh_composition()
	return true


## Adds a playback part; the first added part becomes the primary part.
func add_part(part_id: StringName, data: ReanimDataRef, initial_clip: StringName = &"", loop: bool = true) -> bool:
	var player: ReanimPlayerRef = ReanimPlayerRef.new()
	player.name = "Part_%s" % String(part_id)
	add_child(player)
	if not player.setup(data):
		player.queue_free()
		return false
	player.set_visual_speed(_visual_speed)
	if initial_clip != &"" and not player.play_clip(initial_clip, loop):
		player.queue_free()
		return false
	_parts.append({
		"id": part_id,
		"player": player,
		"host_part_id": &"",
		"host_track": "",
		"host_base": Transform2D.IDENTITY,
	})
	if _primary_player == null:
		_primary_player = player
		_primary_part_id = part_id
	return true


func get_part_player(part_id: StringName) -> ReanimPlayerRef:
	for part in _parts:
		if StringName(part.get("id", &"")) == part_id:
			return part.get("player", null) as ReanimPlayerRef
	return null


func get_part_count() -> int:
	return _parts.size()


func register_anchor(anchor_name: StringName, node: Node2D) -> void:
	_anchors[anchor_name] = node


func play_state(state_id: StringName) -> bool:
	if not state_clip_map.has(state_id):
		return false
	if not _play_mapping(state_clip_map[state_id], true):
		return false
	_current_state = state_id
	_pending_action = false
	_pending_part_ids.clear()
	refresh_composition()
	return true


func play_action(action_id: StringName) -> bool:
	if not action_clip_map.has(action_id):
		return false
	var clips := _clips_for_mapping(action_clip_map[action_id])
	if clips.is_empty():
		return false
	var involved: Array[StringName] = []
	for part_key in clips.keys():
		var part_id := StringName(String(part_key))
		var player := get_part_player(part_id)
		if player == null or not player.play_clip(StringName(String(clips[part_key])), false):
			return false
		involved.append(part_id)
	_pending_action = true
	_pending_part_ids = involved
	refresh_composition()
	return true


func play_animation(animation_name: StringName) -> bool:
	if _primary_player == null:
		return false
	return _primary_player.play_clip(animation_name, true)


func set_visual_speed(speed_scale: float) -> bool:
	_visual_speed = maxf(speed_scale, 0.0)
	for part in _parts:
		var player := part.get("player", null) as ReanimPlayerRef
		if player != null:
			player.set_visual_speed(_visual_speed)
	return true


func get_anchor(anchor_name: StringName) -> Node2D:
	return _anchors.get(anchor_name, null) as Node2D


## Applies host-track bindings and anchor positions for the current phase.
## Deterministic: reads track transforms from data at the players' current
## frame positions, never from previously rendered sprites.
func refresh_composition() -> void:
	for part in _parts:
		var host_part_id := StringName(part.get("host_part_id", &""))
		if host_part_id == &"":
			continue
		var host_player := get_part_player(host_part_id)
		var player := part.get("player", null) as ReanimPlayerRef
		if host_player == null or player == null:
			continue
		var host_now: Transform2D = host_player.get_track_transform(String(part.get("host_track", "")))
		var host_base: Transform2D = part.get("host_base", Transform2D.IDENTITY)
		player.transform = _base_local * host_now * host_base.affine_inverse()
	for anchor_key in _anchor_defs.keys():
		var config: Dictionary = _anchor_defs[anchor_key]
		var node := _anchors.get(StringName(String(anchor_key)), null) as Node2D
		var player := get_part_player(StringName(String(config.get("part", ""))))
		if node == null or player == null:
			continue
		var track_transform: Transform2D = player.get_track_transform(String(config.get("track", "")))
		node.global_position = player.global_transform * track_transform.origin + _to_vector2(config.get("offset", Vector2.ZERO))


func _process(_delta: float) -> void:
	refresh_composition()
	if not _pending_action:
		return
	for part_id in _pending_part_ids:
		var player := get_part_player(part_id)
		if player != null and not player.is_finished():
			return
	_pending_action = false
	if _current_state == &"" or not state_clip_map.has(_current_state):
		_pending_part_ids.clear()
		return
	var clips := _clips_for_mapping(state_clip_map[_current_state])
	for part_id in _pending_part_ids:
		var clip: Variant = clips.get(String(part_id), null)
		var player := get_part_player(part_id)
		if clip != null and player != null:
			player.play_clip(StringName(String(clip)), true)
	_pending_part_ids.clear()


func _play_mapping(mapping: Variant, loop: bool) -> bool:
	var clips := _clips_for_mapping(mapping)
	if clips.is_empty():
		return false
	for part_key in clips.keys():
		var player := get_part_player(StringName(String(part_key)))
		if player == null or not player.play_clip(StringName(String(clips[part_key])), loop):
			return false
	return true


## Normalizes a clip-map value to Dictionary part_id -> clip; StringName /
## String values keep the legacy single-part semantics (primary part).
func _clips_for_mapping(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	if _primary_part_id != &"":
		return {String(_primary_part_id): String(value)}
	return {}


func _normalize_clip_maps(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in source.keys():
		result[StringName(String(key))] = source[key]
	return result


## The host base is the host track transform at binding time (initial clips
## started within this call, so the phase sits exactly on the clip start),
## mirroring the legacy composite wrapper's base_transform captured at load.
func _capture_host_bases() -> void:
	for i in _parts.size():
		var part := _parts[i]
		var host_part_id := StringName(part.get("host_part_id", &""))
		if host_part_id == &"":
			continue
		var host_player := get_part_player(host_part_id)
		if host_player == null:
			continue
		part["host_base"] = host_player.get_track_transform(String(part.get("host_track", "")))
		_parts[i] = part


func _build_def_anchors(typed: ReanimActorDefRef) -> void:
	for anchor_key in typed.anchors.keys():
		var anchor_name := String(anchor_key)
		var config: Dictionary = typed.anchors[anchor_key]
		var alias_of := String(config.get("alias_of", ""))
		if alias_of != "":
			config = typed.anchors.get(alias_of, {}) as Dictionary
		_anchor_defs[anchor_name] = config
		var node := Node2D.new()
		node.name = "Anchor_%s" % anchor_name
		add_child(node)
		_def_anchor_nodes.append(node)
		register_anchor(StringName(anchor_name), node)


func _resolve_hidden_tracks(player: ReanimPlayerRef, visibility: Variant) -> PackedStringArray:
	var hidden := PackedStringArray()
	if not visibility is Dictionary:
		return hidden
	var visibility_dict := visibility as Dictionary
	if visibility_dict.is_empty():
		return hidden
	var mode := String(visibility_dict.get("mode", ""))
	var patterns: Array = visibility_dict.get("patterns", []) if visibility_dict.get("patterns", []) is Array else []
	for track_name in player.get_visual_track_names():
		var matched := false
		for pattern in patterns:
			if String(track_name).match(String(pattern)):
				matched = true
				break
		if (mode == "exclude" and matched) or (mode == "include" and not matched):
			hidden.append(track_name)
	return hidden


func _clear_composition() -> void:
	for part in _parts:
		var player := part.get("player", null) as ReanimPlayerRef
		if player != null and is_instance_valid(player):
			player.queue_free()
	_parts = []
	_primary_player = null
	_primary_part_id = &""
	for node in _def_anchor_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_def_anchor_nodes = []
	_anchors = {}
	_anchor_defs = {}
	state_clip_map = {}
	action_clip_map = {}
	_current_state = &""
	_pending_action = false
	_pending_part_ids = []
	_base_local = Transform2D.IDENTITY


static func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO


func _report_issue(message: String) -> void:
	var debug_service := ReanimPlayerRef._find_singleton("DebugService")
	if debug_service != null and debug_service.has_method("record_protocol_issue"):
		debug_service.record_protocol_issue(DIAGNOSTIC_SCOPE, message, &"error")
