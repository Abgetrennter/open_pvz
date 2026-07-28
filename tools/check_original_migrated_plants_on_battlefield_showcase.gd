extends SceneTree

const SHOWCASE_SCENE_PATH := "res://scenes/showcase/original_migrated_plants_battlefield_showcase.tscn"
const HUB_SCRIPT_PATH := "res://scripts/main/showcase_hub.gd"
const EXPECTED_BACKGROUND_VISUAL_ID := &"classic_original.battlefield.grass_day.visual"
const EXPECTED_PLANTS := {
	&"archetype_original_peashooter": &"classic_original.entity.plant.peashooter.visual",
	&"archetype_original_sunflower": &"classic_original.entity.plant.sunflower.visual",
	&"archetype_original_threepeater": &"classic_original.entity.plant.threepeater.visual",
	&"archetype_original_chomper": &"classic_original.entity.plant.chomper.visual",
	&"archetype_original_squash": &"classic_original.entity.plant.squash.visual",
}
const EXPECTED_ORIGINAL_GRID := {
	&"archetype_original_peashooter": {"col": 1, "row": 0, "ground_offset": Vector2(0.0, 34.0)},
	&"archetype_original_sunflower": {"col": 2, "row": 1, "ground_offset": Vector2(0.0, 33.0)},
	&"archetype_original_threepeater": {"col": 3, "row": 2, "ground_offset": Vector2(0.0, 34.0)},
	&"archetype_original_chomper": {"col": 4, "row": 3, "ground_offset": Vector2(0.0, 21.0)},
	&"archetype_original_squash": {"col": 5, "row": 4, "ground_offset": Vector2(0.0, 20.0)},
}
const PRIVATE_PACK_ID := &"classic_original_assets"
const ORIGINAL_LAWN_XMIN := 40.0
const ORIGINAL_LAWN_YMIN := 80.0
const ORIGINAL_CELL_WIDTH := 80.0
const ORIGINAL_GRASS_CELL_HEIGHT := 100.0
const ORIGINAL_PLANT_CENTER_OFFSET := Vector2(40.0, 40.0)
const SETTLE_FRAMES := 48


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors := PackedStringArray()
	errors.append_array(await _validate_scene())
	errors.append_array(_validate_hub_entry())
	if not errors.is_empty():
		_fail(" | ".join(errors))
		return
	print("Migrated original plants battlefield showcase is wired to original background and private actors.")
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

	var debug_service := root.get_node_or_null("/root/DebugService")
	if debug_service != null and debug_service.has_method("clear_logs"):
		debug_service.call("clear_logs")
	root.add_child(scene)
	for _i in range(SETTLE_FRAMES):
		await process_frame

	if not scene.has_method("get_showcase_actor_specs"):
		errors.append("showcase scene must expose get_showcase_actor_specs()")
	else:
		errors.append_array(_validate_actor_specs(scene.call("get_showcase_actor_specs")))
	errors.append_array(_validate_background(scene))
	errors.append_array(_validate_actors(scene))
	scene.queue_free()
	await process_frame
	return errors


func _validate_actor_specs(specs: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	if specs.size() != EXPECTED_PLANTS.size():
		errors.append("showcase actor spec count is %d, expected %d" % [specs.size(), EXPECTED_PLANTS.size()])
	var actual := {}
	for spec in specs:
		if spec is Dictionary:
			actual[StringName((spec as Dictionary).get("archetype_id", StringName()))] = StringName((spec as Dictionary).get("visual_profile_id", StringName()))
	for archetype_id in EXPECTED_PLANTS.keys():
		if not actual.has(archetype_id):
			errors.append("showcase missing actor spec %s" % String(archetype_id))
			continue
		if StringName(actual[archetype_id]) != StringName(EXPECTED_PLANTS[archetype_id]):
			errors.append("showcase actor spec %s profile is %s" % [String(archetype_id), String(actual[archetype_id])])
		var spec := _find_actor_spec(specs, StringName(archetype_id))
		var expected_grid: Dictionary = EXPECTED_ORIGINAL_GRID.get(archetype_id, {})
		if int(spec.get("grid_col", -1)) != int(expected_grid.get("col", -1)):
			errors.append("showcase actor spec %s grid_col is %d" % [String(archetype_id), int(spec.get("grid_col", -1))])
		if int(spec.get("grid_row", -1)) != int(expected_grid.get("row", -1)):
			errors.append("showcase actor spec %s grid_row is %d" % [String(archetype_id), int(spec.get("grid_row", -1))])
	return errors


func _validate_background(scene: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	var background := scene.find_child("BattlefieldBackground", true, false) as Sprite2D
	if background == null:
		errors.append("showcase missing BattlefieldBackground")
		return errors
	if background.texture == null:
		errors.append("BattlefieldBackground missing texture")
	elif background.texture.get_size() != Vector2(1400.0, 600.0):
		errors.append("BattlefieldBackground texture size is %s" % str(background.texture.get_size()))
	if not background.position.is_equal_approx(Vector2(-220.0, 0.0)):
		errors.append("BattlefieldBackground position is %s" % str(background.position))
	if not background.scale.is_equal_approx(Vector2.ONE):
		errors.append("BattlefieldBackground scale is %s" % str(background.scale))
	if scene.has_method("get_background_visual_id") and StringName(scene.call("get_background_visual_id")) != EXPECTED_BACKGROUND_VISUAL_ID:
		errors.append("background visual id is %s" % String(scene.call("get_background_visual_id")))
	return errors


func _validate_actors(scene: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	for archetype_id in EXPECTED_PLANTS.keys():
		var actor := _find_actor_by_archetype(scene, StringName(archetype_id))
		if actor == null:
			errors.append("missing actor for %s" % String(archetype_id))
			continue
		if _count_visible_textured_nodes(actor) <= 0:
			errors.append("%s actor has no visible textured nodes" % String(archetype_id))
		var profile_id := StringName(actor.get_meta(&"visual_profile_id", StringName()))
		if profile_id != StringName(EXPECTED_PLANTS[archetype_id]):
			errors.append("%s actor profile is %s" % [String(archetype_id), String(profile_id)])
		var pack_id := StringName(actor.get_meta(&"pack_id", StringName()))
		if pack_id != PRIVATE_PACK_ID:
			errors.append("%s actor pack is %s" % [String(archetype_id), String(pack_id)])
		var expected_position := _expected_actor_position(StringName(archetype_id))
		if not actor.position.is_equal_approx(expected_position):
			errors.append("%s actor position is %s, expected %s" % [String(archetype_id), str(actor.position), str(expected_position)])
		var expected_entity_position := _original_grid_entity_position(StringName(archetype_id))
		var actual_entity_position := actor.get_meta(&"original_entity_position", Vector2.ZERO) as Vector2
		if not actual_entity_position.is_equal_approx(expected_entity_position):
			errors.append("%s original entity position is %s, expected %s" % [String(archetype_id), str(actual_entity_position), str(expected_entity_position)])
		var expected_grid: Dictionary = EXPECTED_ORIGINAL_GRID.get(archetype_id, {})
		if int(actor.get_meta(&"original_grid_col", -1)) != int(expected_grid.get("col", -1)):
			errors.append("%s original grid col is %d" % [String(archetype_id), int(actor.get_meta(&"original_grid_col", -1))])
		if int(actor.get_meta(&"original_grid_row", -1)) != int(expected_grid.get("row", -1)):
			errors.append("%s original grid row is %d" % [String(archetype_id), int(actor.get_meta(&"original_grid_row", -1))])
	return errors


func _find_actor_spec(specs: Array, archetype_id: StringName) -> Dictionary:
	for spec in specs:
		if spec is Dictionary and StringName((spec as Dictionary).get("archetype_id", StringName())) == archetype_id:
			return spec as Dictionary
	return {}


func _expected_actor_position(archetype_id: StringName) -> Vector2:
	var expected_grid: Dictionary = EXPECTED_ORIGINAL_GRID.get(archetype_id, {})
	return _original_grid_entity_position(archetype_id) + Vector2(expected_grid.get("ground_offset", Vector2.ZERO))


func _original_grid_entity_position(archetype_id: StringName) -> Vector2:
	var expected_grid: Dictionary = EXPECTED_ORIGINAL_GRID.get(archetype_id, {})
	var col := int(expected_grid.get("col", 0))
	var row := int(expected_grid.get("row", 0))
	return Vector2(
		ORIGINAL_LAWN_XMIN + float(col) * ORIGINAL_CELL_WIDTH,
		ORIGINAL_LAWN_YMIN + float(row) * ORIGINAL_GRASS_CELL_HEIGHT
	) + ORIGINAL_PLANT_CENTER_OFFSET


func _find_actor_by_archetype(root_node: Node, archetype_id: StringName) -> Node2D:
	if root_node is Node2D and StringName(root_node.get_meta(&"archetype_id", StringName())) == archetype_id:
		return root_node as Node2D
	for child in root_node.get_children():
		var found := _find_actor_by_archetype(child, archetype_id)
		if found != null:
			return found
	return null


func _count_visible_textured_nodes(root_node: Node) -> int:
	if root_node == null:
		return 0
	var count := 0
	if root_node is Sprite2D:
		var sprite := root_node as Sprite2D
		if sprite.is_visible_in_tree() and sprite.texture != null:
			count += 1
	elif root_node is TextureRect:
		var texture_rect := root_node as TextureRect
		if texture_rect.is_visible_in_tree() and texture_rect.texture != null:
			count += 1
	for child in root_node.get_children():
		count += _count_visible_textured_nodes(child)
	return count


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
