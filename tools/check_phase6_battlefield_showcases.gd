extends SceneTree

const EXPECTED_SHOWCASES := [
	{
		"scene": "res://scenes/showcase/phase6_ground_pressure_showcase.tscn",
		"scenario": "res://data/combat/levels/phase6/level_ground_pressure_v1.tres",
		"visual_id": &"classic_original.battlefield.grass_day.visual",
	},
	{
		"scene": "res://scenes/showcase/phase6_water_air_split_showcase.tscn",
		"scenario": "res://data/combat/levels/phase6/level_water_air_split_v1.tres",
		"visual_id": &"classic_original.battlefield.pool_day.visual",
	},
	{
		"scene": "res://scenes/showcase/phase6_roof_holdout_showcase.tscn",
		"scenario": "res://data/combat/levels/phase6/level_roof_holdout_v1.tres",
		"visual_id": &"classic_original.battlefield.roof_day.visual",
	},
]
const HUB_SCRIPT_PATH := "res://scripts/main/showcase_hub.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors := PackedStringArray()
	errors.append_array(_validate_showcases())
	errors.append_array(_validate_hub_entries())
	if not errors.is_empty():
		_fail(" | ".join(errors))
		return
	print("Phase 6 battlefield showcases are linked to real scenarios with original backgrounds.")
	quit(0)


func _validate_showcases() -> PackedStringArray:
	var errors := PackedStringArray()
	for expected in EXPECTED_SHOWCASES:
		var scene_path := String(expected.get("scene", ""))
		if not ResourceLoader.exists(scene_path):
			errors.append("missing showcase scene %s" % scene_path)
			continue
		var packed := ResourceLoader.load(scene_path) as PackedScene
		if packed == null:
			errors.append("could not load showcase scene %s" % scene_path)
			continue
		var scene := packed.instantiate()
		if scene == null:
			errors.append("could not instantiate showcase scene %s" % scene_path)
			continue
		root.add_child(scene)
		var scenario := scene.get("scenario") as Resource
		if scenario == null:
			errors.append("%s has no scenario resource" % scene_path)
		else:
			if scenario.resource_path != String(expected.get("scenario", "")):
				errors.append("%s scenario is %s, expected %s" % [
					scene_path,
					scenario.resource_path,
					String(expected.get("scenario", "")),
				])
			var preset := scenario.get("battlefield_preset") as Resource
			if preset == null:
				errors.append("%s scenario has no battlefield_preset" % scene_path)
			elif StringName(preset.get("battlefield_visual_id")) != StringName(expected.get("visual_id", StringName())):
				errors.append("%s visual id is %s, expected %s" % [
					scene_path,
					String(preset.get("battlefield_visual_id")),
					String(StringName(expected.get("visual_id", StringName()))),
				])
		scene.queue_free()
	return errors


func _validate_hub_entries() -> PackedStringArray:
	var errors := PackedStringArray()
	var script := ResourceLoader.load(HUB_SCRIPT_PATH) as Script
	if script == null:
		errors.append("could not load hub script %s" % HUB_SCRIPT_PATH)
		return errors
	var groups: Array = script.get_script_constant_map().get("GROUPS", [])
	for expected in EXPECTED_SHOWCASES:
		var scene_path := String(expected.get("scene", ""))
		if not _hub_links_scene(groups, scene_path):
			errors.append("main hub does not link to %s" % scene_path)
	return errors


func _hub_links_scene(groups: Array, scene_path: String) -> bool:
	for group in groups:
		if not (group is Dictionary):
			continue
		for item in (group as Dictionary).get("items", []):
			if item is Dictionary and String((item as Dictionary).get("scene", "")) == scene_path:
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
