extends SceneTree
## T0 golden baseline tool for the reanim native runtime spike.
##
## Generates deterministic per-sample baseline reports (source hash, raw actor
## metrics, fixed-frame keyframe snapshots, angle warnings, composite wrapper
## record) so later ReanimData/ReanimPlayer output can be compared against the
## legacy import chain without relying on wall-clock time.
##
## Usage:
##   godot --headless --path . --script res://tools/reanim_golden_baseline.gd -- \
##     [--pack-root res://local_extensions/classic_original_assets] \
##     [--out-dir <res://dir>] [--samples peashooter,wallnut,threepeater]

const DEFAULT_PACK_ROOT := "res://local_extensions/classic_original_assets"
const DEFAULT_SAMPLES := "peashooter,wallnut,threepeater"
const FLOAT_STEP := 0.000001

const SAMPLE_SOURCES := {
	"peashooter": "PeaShooterSingle.reanim",
	"wallnut": "Wallnut.reanim",
	"threepeater": "ThreePeater.reanim",
}

const THREEPEATER_WRAPPER_SCRIPT := "res://scripts/validation/visual_reanim_threepeater_composite_actor.gd"

var _ran := false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	var exit_code := _run()
	quit(exit_code)
	return true


func _run() -> int:
	var args := _parse_args(OS.get_cmdline_user_args())
	var pack_root := _normalize_res_dir(String(args.get("pack-root", DEFAULT_PACK_ROOT)))
	var out_dir := _normalize_res_dir(String(args.get("out-dir", pack_root.path_join("generated/reports/reanim_golden"))))
	var sample_ids := String(args.get("samples", DEFAULT_SAMPLES)).split(",", false)

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(pack_root)):
		push_error("Pack root not found: %s" % pack_root)
		return 2

	var dir_result := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	if dir_result != OK:
		push_error("Failed to create output directory: %s" % out_dir)
		return 3

	var index_entries: Array[Dictionary] = []
	for raw_sample_id in sample_ids:
		var sample_id := String(raw_sample_id).strip_edges()
		if sample_id == "":
			continue
		if not SAMPLE_SOURCES.has(sample_id):
			push_error("Unknown sample id (no source mapping): %s" % sample_id)
			return 4
		var report := _build_sample_report(sample_id, pack_root)
		if report.is_empty():
			push_error("Failed to build golden baseline for sample: %s" % sample_id)
			return 5
		var report_path := out_dir.path_join("%s.golden_baseline.json" % sample_id)
		if not _save_json(report_path, report):
			return 6
		index_entries.append({
			"id": sample_id,
			"report": report_path,
			"report_sha256": FileAccess.get_sha256(report_path),
		})
		print("Wrote golden baseline: %s" % report_path)

	var index_payload := {
		"schema_version": 1,
		"pack_root": pack_root,
		"samples": index_entries,
	}
	var index_path := out_dir.path_join("golden_baseline_index.json")
	if not _save_json(index_path, index_payload):
		return 6
	print("Wrote golden baseline index: %s" % index_path)
	return 0


func _build_sample_report(sample_id: String, pack_root: String) -> Dictionary:
	var source_path := pack_root.path_join("sources/reanim").path_join(String(SAMPLE_SOURCES[sample_id]))
	var actor_path := pack_root.path_join("generated/raw").path_join(sample_id).path_join("actor.tscn")
	if not FileAccess.file_exists(source_path):
		push_error("Reanim source missing: %s" % source_path)
		return {}
	if not FileAccess.file_exists(actor_path):
		push_error("Raw actor scene missing: %s" % actor_path)
		return {}

	var report := {
		"schema_version": 1,
		"sample_id": sample_id,
		"source": {
			"path": source_path,
			"sha256": FileAccess.get_sha256(source_path),
			"size_bytes": _file_size(source_path),
		},
		"raw_actor": {
			"path": actor_path,
			"size_bytes": _file_size(actor_path),
			"line_count": _line_count(actor_path),
		},
	}

	var angle_info := _collect_angle_warnings(sample_id, pack_root)
	report["angle_warnings"] = angle_info["warnings"]
	report["angle_warnings_source"] = angle_info["source"]
	if not (angle_info["warnings"] as Array).is_empty():
		print("[reanim_golden_baseline] %s has %d angle warning(s) (source: %s) -- kept, not silenced." % [
			sample_id, (angle_info["warnings"] as Array).size(), String(angle_info["source"]),
		])

	var actor_snapshot := _build_actor_snapshot(actor_path)
	if actor_snapshot.is_empty():
		return {}
	report["actor_structure"] = actor_snapshot["structure"]
	report["frame_samples"] = actor_snapshot["frame_samples"]

	if sample_id == "threepeater":
		report["composite_wrapper"] = _build_threepeater_wrapper_record(pack_root)

	return report


func _collect_angle_warnings(sample_id: String, pack_root: String) -> Dictionary:
	var candidates := [
		pack_root.path_join("generated/raw").path_join(sample_id).path_join("import_report.json"),
		pack_root.path_join("generated/reports").path_join("%s.import_report.json" % sample_id),
	]
	for candidate: String in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if not (parsed is Dictionary):
			continue
		var semantic: Variant = (parsed as Dictionary).get("semantic_analysis", null)
		if semantic is Dictionary and (semantic as Dictionary).has("angle_warnings"):
			return {
				"warnings": (semantic as Dictionary)["angle_warnings"],
				"source": candidate,
			}
	return {"warnings": [], "source": ""}


func _build_actor_snapshot(actor_path: String) -> Dictionary:
	var packed := ResourceLoader.load(actor_path) as PackedScene
	if packed == null:
		push_error("Raw actor scene could not be loaded: %s" % actor_path)
		return {}
	var actor := packed.instantiate() as Node2D
	if actor == null:
		push_error("Raw actor root is not Node2D: %s" % actor_path)
		return {}

	var nodes: Array[Dictionary] = []
	var defaults: Dictionary = {}
	var draw_index := 0
	for child in actor.get_children():
		var entry := {
			"index": draw_index,
			"name": String(child.name),
			"type": child.get_class(),
		}
		draw_index += 1
		if child is Sprite2D:
			var sprite := child as Sprite2D
			entry["initial_visible"] = sprite.visible
			entry["initial_texture"] = _texture_name(sprite.texture)
			defaults[String(child.name)] = {
				"visible": sprite.visible,
				"texture": sprite.texture,
				"position": sprite.position,
				"scale": sprite.scale,
				"rotation": sprite.rotation,
				"skew": sprite.skew,
				"self_modulate": sprite.self_modulate,
			}
		nodes.append(entry)

	var player := actor.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player == null:
		push_error("Raw actor has no AnimationPlayer: %s" % actor_path)
		actor.free()
		return {}

	var animations: Array[Dictionary] = []
	var frame_samples: Array[Dictionary] = []
	var animation_names := player.get_animation_list()
	for animation_name in animation_names:
		var animation := player.get_animation(animation_name)
		if animation == null:
			continue
		var fps := int(roundf(1.0 / maxf(animation.step, 0.0001)))
		var frame_count := maxi(1, int(roundf(animation.length * float(fps))))
		var key_total := 0
		for track_index in range(animation.get_track_count()):
			key_total += animation.track_get_key_count(track_index)
		animations.append({
			"name": String(animation_name),
			"length": _round_float(animation.length),
			"step": _round_float(animation.step),
			"fps": fps,
			"frame_count": frame_count,
			"loop_mode": int(animation.loop_mode),
			"track_count": animation.get_track_count(),
			"key_total": key_total,
		})
		frame_samples.append({
			"animation": String(animation_name),
			"frames": _sample_animation_frames(animation, fps, frame_count, defaults),
		})

	actor.free()
	return {
		"structure": {
			"root_type": "Node2D",
			"node_count": nodes.size(),
			"nodes": nodes,
			"animations": animations,
		},
		"frame_samples": frame_samples,
	}


func _sample_animation_frames(animation: Animation, fps: int, frame_count: int, defaults: Dictionary) -> Array[Dictionary]:
	var frame_indices := _fixed_sample_frames(frame_count)
	var samples: Array[Dictionary] = []
	for frame in frame_indices:
		var time := float(frame) / float(fps)
		var node_states: Dictionary = {}
		for track_index in range(animation.get_track_count()):
			if animation.track_get_type(track_index) != Animation.TYPE_VALUE:
				continue
			var path := String(animation.track_get_path(track_index))
			var separator := path.find(":")
			if separator < 0:
				continue
			var node_name := path.substr(0, separator)
			var property_name := path.substr(separator + 1)
			if not node_states.has(node_name):
				node_states[node_name] = {}
			var value: Variant = _sample_track_value(animation, track_index, time, defaults, node_name, property_name)
			(node_states[node_name] as Dictionary)[property_name] = _to_json_value(value)
		samples.append({
			"frame": frame,
			"time": _round_float(time),
			"nodes": node_states,
		})
	return samples


func _fixed_sample_frames(frame_count: int) -> Array[int]:
	var wanted := [0, frame_count / 4, frame_count / 2, (3 * frame_count) / 4, frame_count - 1]
	var seen: Dictionary = {}
	var frames: Array[int] = []
	for frame in wanted:
		var clamped: int = clampi(int(frame), 0, maxi(0, frame_count - 1))
		if seen.has(clamped):
			continue
		seen[clamped] = true
		frames.append(clamped)
	frames.sort()
	return frames


## Samples the held key value (last key at or before the sample time) for every
## track. The legacy importer wrote keys with insert-if-changed semantics, so
## holding the previous key reconstructs the exact per-frame fill-forward state
## (de-pvz ReanimationFillInMissingData). Interpolating instead would leak
## sparse-key interpolation artifacts into the baseline: Godot lerps across the
## gaps left by deduplicated keys, producing values the original engine never
## computed (e.g. peashooter idle_mouth rotation at full_idle frame 6).
func _sample_track_value(animation: Animation, track_index: int, time: float, defaults: Dictionary, node_name: String, property_name: String) -> Variant:
	var best_key := -1
	for key_index in range(animation.track_get_key_count(track_index)):
		if animation.track_get_key_time(track_index, key_index) <= time + 0.0001:
			best_key = key_index
		else:
			break
	if best_key >= 0:
		return animation.track_get_key_value(track_index, best_key)

	var node_defaults: Dictionary = defaults.get(node_name, {})
	return node_defaults.get(property_name, null)


func _build_threepeater_wrapper_record(pack_root: String) -> Dictionary:
	var wrapper_scene_path := pack_root.path_join("actors/threepeater/actor.tscn")
	if not FileAccess.file_exists(wrapper_scene_path):
		return {"error": "wrapper_scene_missing", "path": wrapper_scene_path}
	var packed := ResourceLoader.load(wrapper_scene_path) as PackedScene
	if packed == null:
		return {"error": "wrapper_scene_unloadable", "path": wrapper_scene_path}
	var wrapper := packed.instantiate() as Node2D
	if wrapper == null:
		return {"error": "wrapper_root_not_node2d", "path": wrapper_scene_path}

	root.add_child(wrapper)

	var record := {
		"scene_path": wrapper_scene_path,
		"script_path": THREEPEATER_WRAPPER_SCRIPT,
		"script_line_count": _line_count(THREEPEATER_WRAPPER_SCRIPT),
		"exports": {
			"raw_actor_scene_path": String(wrapper.get("raw_actor_scene_path")),
			"source_reanim_path": String(wrapper.get("source_reanim_path")),
			"actor_anchor_offset": _to_json_value(wrapper.get("actor_anchor_offset")),
			"actor_scale_value": _round_float(float(wrapper.get("actor_scale_value"))),
		},
	}

	var script := wrapper.get_script() as Script
	if script != null:
		var constants := script.get_script_constant_map()
		var constant_record: Dictionary = {}
		for constant_name in ["REANIM_SOURCE_FPS", "BODY_START_FRAME", "BODY_END_FRAME", "IDLE_RATE_SCALE", "SHOOTING_RATE_SCALE", "REANIM_BLEND_SECONDS"]:
			if constants.has(constant_name):
				constant_record[constant_name] = _to_json_value(constants[constant_name])
		record["constants"] = constant_record

	var children: Array[Dictionary] = []
	for child in wrapper.get_children():
		children.append({"name": String(child.name), "type": child.get_class()})
	record["children"] = children

	var head_parts: Array[Dictionary] = []
	var raw_parts: Variant = wrapper.get("_head_parts")
	if raw_parts is Array:
		for raw_part in (raw_parts as Array):
			var part := raw_part as Dictionary
			var anchor_node := part.get("anchor_node", null) as Node2D
			head_parts.append({
				"id": int(part.get("id", 0)),
				"host_track": String(part.get("anchor", "")),
				"idle_clip": String(part.get("idle", &"")),
				"shooting_clip": String(part.get("shooting", &"")),
				"mouth_node": String(part.get("mouth", "")),
				"has_actor": part.get("actor", null) != null,
				"has_player": part.get("player", null) != null,
				"has_anchor_node": anchor_node != null,
				"anchor_base_origin": _to_json_value((part.get("base_transform", Transform2D.IDENTITY) as Transform2D).origin),
			})
	record["head_parts"] = head_parts

	var action_results := {
		"play_state_idle": bool(wrapper.call("play_state", &"idle")),
		"play_state_attacking": bool(wrapper.call("play_state", &"attacking")),
		"play_action_shoot": bool(wrapper.call("play_action", &"shoot")),
		"play_action_unknown": bool(wrapper.call("play_action", &"__unknown__")),
		"play_animation_shooting": bool(wrapper.call("play_animation", &"shooting")),
		"set_visual_speed": bool(wrapper.call("set_visual_speed", 1.0)),
	}
	record["action_results"] = action_results

	var anchors: Dictionary = {}
	for anchor_name in ["muzzle", "muzzle1", "muzzle2", "muzzle3", "__unknown__"]:
		var anchor := wrapper.call("get_anchor", StringName(anchor_name)) as Node2D
		if anchor == null:
			anchors[anchor_name] = null
		else:
			anchors[anchor_name] = {
				"node": String(anchor.name),
				"global_position": _to_json_value(anchor.global_position),
			}
	record["anchors"] = anchors

	root.remove_child(wrapper)
	wrapper.free()
	return record


func _texture_name(texture: Texture2D) -> String:
	if texture == null:
		return ""
	if texture.resource_name != "":
		return texture.resource_name
	if texture.resource_path != "":
		return texture.resource_path.get_file()
	return "<unnamed>"


func _to_json_value(value: Variant) -> Variant:
	if value is Vector2:
		var vec := value as Vector2
		return [_round_float(vec.x), _round_float(vec.y)]
	if value is Color:
		var color := value as Color
		return [_round_float(color.r), _round_float(color.g), _round_float(color.b), _round_float(color.a)]
	if value is float:
		return _round_float(value)
	if value is Texture2D:
		return _texture_name(value)
	if value == null:
		return null
	if value is bool or value is int or value is String:
		return value
	return String(value)


func _round_float(value: float) -> float:
	return snappedf(value, FLOAT_STEP)


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	return int(file.get_length())


func _line_count(path: String) -> int:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return 0
	return text.split("\n").size()


func _save_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open for write: %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	return true


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


func _normalize_res_dir(path: String) -> String:
	var normalized := path.replace("\\", "/")
	if normalized.ends_with("/"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized
