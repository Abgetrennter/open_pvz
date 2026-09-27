extends SceneTree
## reanim_seed_root_offset.gd — headless diagnostic that reports the per-frame
## visible AABB of a ReanimData and suggests a *candidate* `root_offset` for the
## operator to confirm by eye in the demo.
##
## The original PVZ `.reanim` files carry no per-plant offset/origin and the
## OpenPVZ importer emits none; root_offset is hand-calibrated per plant (see
## plans/reanim-native-runtime-implementation-plan.md:399 — "per-frame visible
## AABB bottom-center, then eye-calibrated"). This tool automates ONLY the AABB
## measurement. Validated against the 18 already-migrated plants: the candidate
## is within a few px for some (wallnut/fumeshroom/tallnut ~±1px) but diverges
## widely for others (flowerpot/seashroom/lilypad off by 20-30px) because PVZ
## reanim sprite anchoring and transparent padding do not match a naive
## top-left texture rect. THEREFORE: treat the candidate as a rough starting
## point only, and always confirm/trim in the demo. The reported AABB (width,
## height, bottom_y) is the genuinely useful sanity signal.
##
## Method: across all frames of a reference clip (default: idle, else the first
## marker clip), union the transformed texture rects of every visible visual
## track. Candidate offset = `(-(min_x+max_x)/2, -max_y)` plus an advisory
## vendor Y correction (vendor/de-pvz/Lawn/Plant.cpp:3569-3705) where one
## exists. Does NOT modify any file.
##
## Usage (headless):
##   godot --headless --path <project> --script res://tools/reanim_importer/reanim_seed_root_offset.gd -- \
##     --reanim-data res://local_extensions/classic_original_assets/generated/reanim_data/<id>/reanim_data.tres \
##     [--clip idle] [--id peashooter] [--compare -44,-96]
##
## Output: prints `id, proposed_root_offset=[x, y], aabb=[minx,miny,maxx,maxy],
## frames_sampled=N, tracks=V, note=...`. Does NOT modify any file.

const ReanimDataRef = preload("res://scripts/visual/reanim/reanim_data.gd")
const ReanimPlayerRef = preload("res://scripts/visual/reanim/reanim_player.gd")

# vendor/de-pvz/Lawn/Plant.cpp:3569-3705 PlantDrawHeightOffset: aHeightOffset
# added to the plant's Y. We NEGATE it into root_offset space (a positive draw
# offset = art moved down = root_offset y more negative). Only seeds with a
# nonzero branch are listed; everyone else is 0.
const VENDOR_Y_CORRECTION := {
	&"flowerpot": 26.0,
	&"lilypad": 25.0,
	&"starfruit": 10.0,
	&"seashroom": 28.0,
	&"coffeebean": -20.0,   # SEED_INSTANT_COFFEE
	&"pumpkin": 15.0,
	&"puffshroom": 5.0,
	&"scaredyshroom": -14.0,
	&"gravebuster": -40.0,
	# spikeweed/spikerock depend on board row (+5..+15); use a mid value.
	&"spikeweed": 12.0,
	&"spikerock": 12.0,
}


func _init():
	var args := _parse_args()
	if args.is_empty():
		_usage()
		quit(0)
		return

	var data_path := String(args.get("--reanim-data", ""))
	if data_path == "":
		print("ERROR: --reanim-data <res://.../reanim_data.tres> is required")
		quit(1)
		return

	var data := load(data_path) as ReanimDataRef
	if data == null:
		print("ERROR: could not load ReanimData at %s" % data_path)
		quit(1)
		return
	var problems := data.validate()
	if not problems.is_empty():
		print("ERROR: reanim_data invalid: %s" % ", ".join(problems))
		quit(1)
		return

	var plant_id := String(args.get("--id", String(data.source_id)))
	var clip_name := String(args.get("--clip", ""))
	var compare := String(args.get("--compare", ""))

	var result := _compute_seed_offset(data, clip_name)
	if result.get("__error", false):
		quit(1)
		return

	# Apply vendor Y correction where one exists (negated: a positive draw
	# height offset lowers the art, so root_offset.y decreases).
	var vendor_y := 0.0
	var key := StringName(plant_id)
	if VENDOR_Y_CORRECTION.has(key):
		vendor_y = float(VENDOR_Y_CORRECTION[key])
	var offset_y_base := float(result["offset_y"])
	var offset_x_base := float(result["offset_x"])
	var proposed_y := offset_y_base - vendor_y
	var proposed := [offset_x_base, proposed_y]

	var note := "frames=%d tracks=%d aabb=[%d,%d..%d,%d] w=%d h=%d bottom=%d clip=%s" % [
		result["frames_sampled"], result["tracks_used"],
		result["min_x"], result["min_y"], result["max_x"], result["max_y"],
		int(result["max_x"] - result["min_x"]), int(result["max_y"] - result["min_y"]),
		int(result["max_y"]), result["clip_used"]]
	if vendor_y != 0.0:
		note += " vendor_y=%+d" % int(vendor_y)

	print("%s, candidate_root_offset=[%.1f, %.1f] (CONFIRM BY EYE), %s" % [
		plant_id, proposed[0], proposed[1], note])
	if compare != "":
		var parts := compare.split(",")
		if parts.size() == 2:
			print("  compare-known=[%s, %s] delta=[%.1f, %.1f]" % [
				parts[0], parts[1],
				proposed[0] - float(parts[0]), proposed[1] - float(parts[1])])
	quit(0)


## Resolve the reference clip: the requested one, else "idle", else the first
## marker clip, else the whole frame range.
func _compute_seed_offset(data: ReanimDataRef, clip_name: String) -> Dictionary:
	var textures := _load_textures(data)
	if textures.is_empty():
		print("ERROR: no textures loaded for %s" % String(data.source_id))
		return {"__error": true}

	var clip := {}
	if clip_name != "":
		clip = data.get_clip(clip_name)
	if clip.is_empty():
		clip = data.get_clip("idle")
	if clip.is_empty():
		for c in data.clips:
			if String(c.get("source_kind", "")) == "marker":
				clip = c
				break
	if clip.is_empty() and data.clips.size() > 0:
		clip = data.clips[0]
	if clip.is_empty():
		# Fall back to the whole range.
		clip = {"name": "<all>", "start_frame": 0, "frame_count": data.frame_count}

	var start_f := int(clip.get("start_frame", 0))
	var fc := int(clip.get("frame_count", data.frame_count))
	if fc <= 0:
		fc = data.frame_count
	var end_f := mini(start_f + fc, data.frame_count)
	var clip_used := String(clip.get("name", "<all>"))

	# Visual track indices, in storage order (draw order is applied by the actor;
	# for bounds we union all visible tracks regardless of order).
	var visual_tracks: PackedInt32Array = []
	for ti in range(data.get_track_count()):
		if data.track_kinds[ti] == ReanimDataRef.TRACK_KIND_VISUAL:
			visual_tracks.append(ti)

	var has_min := false
	var min_x := 0.0
	var min_y := 0.0
	var max_x := 0.0
	var max_y := 0.0
	var frames_sampled := 0
	for frame in range(start_f, end_f):
		frames_sampled += 1
		for ti in visual_tracks:
			if data.is_frame_hidden(ti, frame):
				continue
			var img_index := data.get_image_index(ti, frame)
			if img_index < 0 or img_index >= textures.size():
				continue
			var tex: Texture2D = textures[img_index]
			if tex == null:
				continue
			# Track transform origin is the sprite's position in actor space.
			var tx := data.get_float(ti, frame, ReanimDataRef.FLOAT_X)
			var ty := data.get_float(ti, frame, ReanimDataRef.FLOAT_Y)
			# Texture size defines the sprite rect anchored at (tx, ty) as the
			# top-left (matches PVZ reanim sprite placement).
			var w := float(tex.get_width())
			var h := float(tex.get_height())
			# Expand by the scale to approximate the rendered footprint.
			var sx := data.get_float(ti, frame, ReanimDataRef.FLOAT_SX)
			var sy := data.get_float(ti, frame, ReanimDataRef.FLOAT_SY)
			var x0 := tx
			var y0 := ty
			var x1 := tx + w * sx
			var y1 := ty + h * sy
			if not has_min:
				min_x = x0; min_y = y0; max_x = x1; max_y = y1
				has_min = true
			else:
				min_x = min(min_x, x0); min_y = min(min_y, y0)
				max_x = max(max_x, x1); max_y = max(max_y, y1)

	if not has_min:
		print("WARN: no visible textured frames found for %s clip=%s" % [String(data.source_id), clip_used])
		return {
			"offset_x": 0.0, "offset_y": 0.0, "frames_sampled": frames_sampled,
			"tracks_used": visual_tracks.size(), "min_x": 0.0, "min_y": 0.0,
			"max_x": 0.0, "max_y": 0.0, "clip_used": clip_used,
		}

	# Bottom-center offset: translate so the AABB's bottom-center sits at origin.
	var offset_x := -(min_x + max_x) * 0.5
	var offset_y := -max_y
	return {
		"offset_x": offset_x, "offset_y": offset_y,
		"frames_sampled": frames_sampled, "tracks_used": visual_tracks.size(),
		"min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y,
		"clip_used": clip_used,
	}


func _load_textures(data: ReanimDataRef) -> Array[Texture2D]:
	var loaded: Array[Texture2D] = []
	for image_index in range(data.image_paths.size()):
		var image_path := String(data.image_paths[image_index])
		var texture: Texture2D = ReanimPlayerRef._load_texture_from_path(image_path)
		loaded.append(texture)  # may be null; callers check
	return loaded


func _parse_args() -> Dictionary:
	var parsed := {}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		var arg := String(argv[i])
		if arg.begins_with("--") and i + 1 < argv.size():
			parsed[arg] = String(argv[i + 1])
			i += 2
		else:
			i += 1
	return parsed


func _usage() -> void:
	print("Usage: reanim_seed_root_offset.gd --reanim-data <res://...tres> [--clip idle] [--id <plant>] [--compare x,y]")
