extends SceneTree

const SHOWCASE_SCENE_PATH := "res://scenes/showcase/original_battlefield_background_showcase.tscn"
const HUB_SCRIPT_PATH := "res://scripts/main/showcase_hub.gd"
const EXPECTED_PREVIEW_COUNT := 4
const EXPECTED_VISUAL_IDS := [
	&"classic_original.battlefield.grass_day.visual",
	&"classic_original.battlefield.unsodded_day.visual",
	&"classic_original.battlefield.pool_day.visual",
	&"classic_original.battlefield.roof_day.visual",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors := PackedStringArray()
	errors.append_array(_validate_scene())
	errors.append_array(_validate_hub_entry())
	if not errors.is_empty():
		_fail(" | ".join(errors))
		return
	print("Original battlefield background showcase is available from the main hub.")
	quit(0)


func _validate_scene() -> PackedStringArray:
	var errors := PackedStringArray()
	if not ResourceLoader.exists(SHOWCASE_SCENE_PATH):
		errors.append("missing showcase scene %s" % SHOWCASE_SCENE_PATH)
		return errors
	var packed := ResourceLoader.load(SHOWCASE_SCENE_PATH) as PackedScene
	if packed == null:
		errors.append("could not load showcase scene %s" % SHOWCASE_SCENE_PATH)
		return errors
	var scene := packed.instantiate()
	if scene == null:
		errors.append("could not instantiate showcase scene %s" % SHOWCASE_SCENE_PATH)
		return errors
	root.add_child(scene)
	if not scene.has_method("get_preview_entries"):
		errors.append("showcase scene must expose get_preview_entries()")
	else:
		var entries: Array = scene.call("get_preview_entries")
		if entries.size() != EXPECTED_PREVIEW_COUNT:
			errors.append("showcase preview count is %d, expected %d" % [entries.size(), EXPECTED_PREVIEW_COUNT])
		var actual_ids := {}
		for entry in entries:
			if entry is Dictionary:
				actual_ids[StringName((entry as Dictionary).get("visual_id", StringName()))] = true
		for visual_id in EXPECTED_VISUAL_IDS:
			if not actual_ids.has(visual_id):
				errors.append("showcase missing preview visual id %s" % String(visual_id))
	var preview_root := scene.find_child("PreviewGrid", true, false)
	if preview_root == null:
		errors.append("showcase scene must create PreviewGrid")
	elif preview_root.get_child_count() != EXPECTED_PREVIEW_COUNT:
		errors.append("showcase preview grid child count is %d, expected %d" % [preview_root.get_child_count(), EXPECTED_PREVIEW_COUNT])
	scene.queue_free()
	return errors


func _validate_hub_entry() -> PackedStringArray:
	var errors := PackedStringArray()
	var script := ResourceLoader.load(HUB_SCRIPT_PATH) as Script
	if script == null:
		errors.append("could not load hub script %s" % HUB_SCRIPT_PATH)
		return errors
	var groups: Array = script.get_script_constant_map().get("GROUPS", [])
	var found := false
	for group in groups:
		if not (group is Dictionary):
			continue
		for item in (group as Dictionary).get("items", []):
			if item is Dictionary and String((item as Dictionary).get("scene", "")) == SHOWCASE_SCENE_PATH:
				found = true
	if not found:
		errors.append("main hub does not link to %s" % SHOWCASE_SCENE_PATH)
	return errors


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
