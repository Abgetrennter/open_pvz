extends Resource
class_name ReanimActorDef
## Composite native reanim actor definition (spike T3).
##
## Declares playback parts (each backed by one ReanimData resource), per-part
## state/action clip maps, host-track bindings (a part follows a track sampled
## on another part, generalizing the legacy ThreePeater head attachment),
## track visibility masks and named anchors resolved from part tracks.
##
## Produced by tools/reanim_importer/reanim_generate_composites.gd from the
## private manifest. Runtime consumers only read this Resource; no JSON is
## parsed at runtime. All dictionary keys inside parts/states/actions/anchors
## are plain Strings so .tres round-trips stay stable.

const ReanimDataRef = preload("res://scripts/visual/reanim/reanim_data.gd")

const TRACK_VISIBILITY_MODES := ["include", "exclude"]

@export var def_id: StringName = &""
@export var initial_state: StringName = &""
## Base local offset/scale applied to every part player
## (mirrors the legacy composite actor_anchor_offset / actor_scale_value).
@export var root_offset: Vector2 = Vector2.ZERO
@export var root_scale: float = 1.0
## Part entries: {id: String, reanim_data: ReanimData, initial_clip: String,
## loop: bool, host_part_id: String, host_track: String, render_order: int,
## track_visibility: {mode: "include"|"exclude", patterns: Array[String]},
## image_override: Dictionary (reserved, must stay empty in schema v1)}
@export var parts: Array[Dictionary] = []
## State id (String) -> {part_id: clip_name} looped playback.
@export var states: Dictionary = {}
## Action id (String) -> {part_id: clip_name} one-shot playback; the involved
## parts return to the current state clips once every one-shot finished.
@export var actions: Dictionary = {}
## Anchor name (String) -> {part: String, track: String, offset: Vector2}
## or {alias_of: String} referencing another concrete anchor.
@export var anchors: Dictionary = {}


func get_part(part_id: String) -> Dictionary:
	for part in parts:
		if String(part.get("id", "")) == part_id:
			return part
	return {}


## Structural consistency check; returns a list of problems (empty = valid).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if parts.is_empty():
		problems.append("parts must not be empty")
	var data_by_part: Dictionary = {}
	for part in parts:
		var part_id := String(part.get("id", ""))
		if part_id == "":
			problems.append("part with empty id")
			continue
		if data_by_part.has(part_id):
			problems.append("duplicate part id: %s" % part_id)
			continue
		var data := part.get("reanim_data", null) as ReanimDataRef
		if data == null:
			problems.append("part %s is missing reanim_data" % part_id)
			continue
		data_by_part[part_id] = data
		if not data.validate().is_empty():
			problems.append("part %s has invalid reanim_data" % part_id)
		var initial_clip := String(part.get("initial_clip", ""))
		if initial_clip != "" and data.get_clip(initial_clip).is_empty():
			problems.append("part %s has unknown initial_clip: %s" % [part_id, initial_clip])
		problems.append_array(_validate_track_visibility(part_id, part.get("track_visibility", {})))
		var image_override: Variant = part.get("image_override", {})
		if not image_override is Dictionary:
			problems.append("part %s image_override must be a Dictionary" % part_id)
		elif not (image_override as Dictionary).is_empty():
			# Reserved capability: fail closed until a later milestone implements it.
			problems.append("part %s image_override is not supported in schema v1" % part_id)
	for part in parts:
		var part_id := String(part.get("id", ""))
		var host_part_id := String(part.get("host_part_id", ""))
		if host_part_id == "":
			continue
		var host_track := String(part.get("host_track", ""))
		if host_part_id == part_id:
			problems.append("part %s cannot host itself" % part_id)
		elif not data_by_part.has(host_part_id):
			problems.append("part %s has unknown host_part_id: %s" % [part_id, host_part_id])
		elif host_track == "":
			problems.append("part %s has host_part_id but empty host_track" % part_id)
		elif (data_by_part[host_part_id] as ReanimDataRef).find_track(host_track) < 0:
			problems.append("part %s has unknown host_track: %s/%s" % [part_id, host_part_id, host_track])
	problems.append_array(_validate_clip_map("state", states, data_by_part))
	problems.append_array(_validate_clip_map("action", actions, data_by_part))
	if initial_state != &"" and not states.has(String(initial_state)):
		problems.append("initial_state has no states entry: %s" % String(initial_state))
	problems.append_array(_validate_anchors(data_by_part))
	return problems


func _validate_track_visibility(part_id: String, visibility: Variant) -> PackedStringArray:
	var problems := PackedStringArray()
	if not visibility is Dictionary:
		problems.append("part %s track_visibility must be a Dictionary" % part_id)
		return problems
	var visibility_dict := visibility as Dictionary
	if visibility_dict.is_empty():
		return problems
	var mode := String(visibility_dict.get("mode", ""))
	if not TRACK_VISIBILITY_MODES.has(mode):
		problems.append("part %s track_visibility mode must be include/exclude: %s" % [part_id, mode])
	var patterns: Variant = visibility_dict.get("patterns", [])
	if not patterns is Array or (patterns as Array).is_empty():
		problems.append("part %s track_visibility patterns must be a non-empty Array" % part_id)
	return problems


func _validate_clip_map(kind: String, clip_maps: Dictionary, data_by_part: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	for map_id in clip_maps.keys():
		var mapping: Variant = clip_maps[map_id]
		if not mapping is Dictionary or (mapping as Dictionary).is_empty():
			problems.append("%s %s mapping must be a non-empty Dictionary" % [kind, String(map_id)])
			continue
		for part_key in (mapping as Dictionary).keys():
			var part_id := String(part_key)
			var clip_name := String((mapping as Dictionary)[part_key])
			if not data_by_part.has(part_id):
				problems.append("%s %s references unknown part: %s" % [kind, String(map_id), part_id])
			elif (data_by_part[part_id] as ReanimDataRef).get_clip(clip_name).is_empty():
				problems.append("%s %s references unknown clip: %s/%s" % [kind, String(map_id), part_id, clip_name])
	return problems


func _validate_anchors(data_by_part: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	for anchor_key in anchors.keys():
		var anchor_name := String(anchor_key)
		var config: Variant = anchors[anchor_key]
		if not config is Dictionary:
			problems.append("anchor %s config must be a Dictionary" % anchor_name)
			continue
		var config_dict := config as Dictionary
		var alias_of := String(config_dict.get("alias_of", ""))
		if alias_of != "":
			var target: Variant = anchors.get(alias_of, null)
			if not target is Dictionary or String((target as Dictionary).get("alias_of", "")) != "":
				problems.append("anchor %s alias_of must reference a concrete anchor: %s" % [anchor_name, alias_of])
			continue
		var part_id := String(config_dict.get("part", ""))
		var track_name := String(config_dict.get("track", ""))
		if not data_by_part.has(part_id):
			problems.append("anchor %s references unknown part: %s" % [anchor_name, part_id])
		elif track_name == "" or (data_by_part[part_id] as ReanimDataRef).find_track(track_name) < 0:
			problems.append("anchor %s references unknown track: %s/%s" % [anchor_name, part_id, track_name])
	return problems
