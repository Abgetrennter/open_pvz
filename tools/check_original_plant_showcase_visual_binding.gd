extends SceneTree

const SHOWCASE_SCENES := [
	{
		"path": "res://scenes/showcase/original_shooter_garden_showcase.tscn",
		"expected_private_bindings": {
			&"archetype_original_peashooter": &"classic_original.entity.plant.peashooter.visual",
			&"archetype_original_threepeater": &"classic_original.entity.plant.threepeater.visual",
		},
		"expected_fallbacks": [
			&"archetype_original_repeater",
			&"archetype_original_gatlingpea",
			&"archetype_original_splitpea",
		],
	},
	{
		"path": "res://scenes/showcase/original_production_garden_showcase.tscn",
		"expected_private_bindings": {
			&"archetype_original_sunflower": &"classic_original.entity.plant.sunflower.visual",
		},
		"expected_fallbacks": [
			&"archetype_original_twinsunflower",
			&"archetype_original_sunshroom",
			&"archetype_original_marigold",
		],
	},
	{
		"path": "res://scenes/showcase/original_special_garden_showcase.tscn",
		"expected_private_bindings": {
			&"archetype_original_chomper": &"classic_original.entity.plant.chomper.visual",
			&"archetype_original_squash": &"classic_original.entity.plant.squash.visual",
		},
		"expected_fallbacks": [
			&"archetype_original_cobcannon",
			&"archetype_original_blover",
			&"archetype_original_hypnoshroom",
		],
	},
]
const REQUIRED_PRIVATE_BINDINGS := {
	&"archetype_original_peashooter": &"classic_original.entity.plant.peashooter.visual",
	&"archetype_original_sunflower": &"classic_original.entity.plant.sunflower.visual",
	&"archetype_original_threepeater": &"classic_original.entity.plant.threepeater.visual",
	&"archetype_original_chomper": &"classic_original.entity.plant.chomper.visual",
	&"archetype_original_squash": &"classic_original.entity.plant.squash.visual",
}
const PRIVATE_PACK_ID := &"classic_original_assets"
const DEBUG_ENABLE_CLASSIC_ORIGINAL_ASSETS_SETTING := "openpvz/debug/enable_classic_original_assets"
const SCENE_SETTLE_FRAMES := 40
const MAX_COMPONENT_ENTITY_DISTANCE := 12.0
const MIN_ACTOR_VISIBLE_BOTTOM_Y := 12.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var preflight_errors := _validate_debug_catalog_preflight()
	if not preflight_errors.is_empty():
		_fail(" | ".join(preflight_errors))
		return

	var all_errors := PackedStringArray()
	for scene_spec: Dictionary in SHOWCASE_SCENES:
		var scene_errors := await _validate_showcase_scene(scene_spec)
		all_errors.append_array(scene_errors)
	if not all_errors.is_empty():
		_fail(" | ".join(all_errors))
		return

	print("Original plant showcase private visual bindings and fallback placeholders are active.")
	quit(0)


func _validate_showcase_scene(scene_spec: Dictionary) -> PackedStringArray:
	var scene_path := String(scene_spec.get("path", ""))
	var errors := PackedStringArray()
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		errors.append("could not load showcase scene: %s" % scene_path)
		return errors

	var showcase := packed_scene.instantiate()
	if showcase == null:
		errors.append("could not instantiate showcase scene: %s" % scene_path)
		return errors

	root.add_child(showcase)
	for _i in range(SCENE_SETTLE_FRAMES):
		await process_frame

	errors.append_array(_validate_showcase(showcase, scene_spec))
	showcase.queue_free()
	await process_frame
	return errors


func _validate_showcase(showcase: Node, scene_spec: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var scene_path := String(scene_spec.get("path", ""))
	if not _is_private_pack_enabled():
		errors.append("%s: classic_original_assets is not enabled" % scene_path)

	var expected_private_bindings: Dictionary = scene_spec.get("expected_private_bindings", {})
	for archetype_id in expected_private_bindings.keys():
		var expected_profile_id: StringName = expected_private_bindings[archetype_id]
		var entity := _find_entity_by_archetype(showcase, archetype_id)
		if entity == null:
			errors.append("%s: missing entity %s" % [scene_path, String(archetype_id)])
			continue

		var visual_actor := entity.get_node_or_null("VisualActorComponent")
		if visual_actor == null:
			errors.append("%s: %s missing VisualActorComponent" % [scene_path, String(archetype_id)])
			continue
		if not visual_actor.has_method("get_actor_root") or visual_actor.call("get_actor_root") == null:
			errors.append("%s: %s missing actor root" % [scene_path, String(archetype_id)])
			continue
		var actor_root := visual_actor.call("get_actor_root") as Node2D
		if entity is Node2D:
			var entity_position := (entity as Node2D).global_position
			if visual_actor is Node2D:
				var component_distance := (visual_actor as Node2D).global_position.distance_to(entity_position)
				if component_distance > MAX_COMPONENT_ENTITY_DISTANCE:
					errors.append("%s: %s visual actor component is detached from entity transform: %.2f px" % [scene_path, String(archetype_id), component_distance])
			var actor_bounds := _visible_textured_global_rect(actor_root)
			if actor_bounds.size != Vector2.ZERO:
				var visible_top_y := actor_bounds.position.y - entity_position.y
				var visible_bottom_y := actor_bounds.position.y + actor_bounds.size.y - entity_position.y
				if visible_bottom_y < MIN_ACTOR_VISIBLE_BOTTOM_Y:
					errors.append("%s: %s actor visible bounds are too high relative to entity origin: top %.2f px, bottom %.2f px" % [scene_path, String(archetype_id), visible_top_y, visible_bottom_y])
		var visible_textured_count := _count_visible_textured_nodes(actor_root)
		if visible_textured_count <= 0:
			errors.append("%s: %s actor root has no visible textured nodes" % [scene_path, String(archetype_id)])
		if not visual_actor.has_method("get_profile_source"):
			errors.append("%s: %s missing profile source API" % [scene_path, String(archetype_id)])
			continue

		var source: Dictionary = visual_actor.call("get_profile_source")
		if StringName(source.get("pack_id", StringName())) != PRIVATE_PACK_ID:
			errors.append("%s: %s resolved from pack %s" % [scene_path, String(archetype_id), String(source.get("pack_id", StringName()))])
		if StringName(source.get("id", StringName())) != expected_profile_id:
			errors.append("%s: %s resolved profile %s" % [scene_path, String(archetype_id), String(source.get("id", StringName()))])

	for archetype_id in Array(scene_spec.get("expected_fallbacks", [])):
		var entity := _find_entity_by_archetype(showcase, StringName(archetype_id))
		if entity == null:
			errors.append("%s: missing fallback entity %s" % [scene_path, String(archetype_id)])
			continue
		if entity.get_node_or_null("VisualActorComponent") != null:
			errors.append("%s: unbound %s should keep fallback placeholder, but mounted VisualActorComponent" % [scene_path, String(archetype_id)])

	return errors


func _validate_debug_catalog_preflight() -> PackedStringArray:
	var errors := PackedStringArray()
	if not bool(ProjectSettings.get_setting(DEBUG_ENABLE_CLASSIC_ORIGINAL_ASSETS_SETTING, false)):
		errors.append("%s is not enabled" % DEBUG_ENABLE_CLASSIC_ORIGINAL_ASSETS_SETTING)
	if not _is_private_pack_enabled():
		errors.append("classic_original_assets is not enabled before showcase instantiation")
	return errors


func _find_entity_by_archetype(root_node: Node, archetype_id: StringName) -> Node:
	if root_node != null and root_node.has_method("get_runtime_combat_entities"):
		for entity in root_node.call("get_runtime_combat_entities"):
			if entity != null and is_instance_valid(entity) and StringName(entity.get("archetype_id")) == archetype_id:
				return entity
	for child in root_node.get_children():
		var found := _find_entity_by_archetype(child, archetype_id)
		if found != null:
			return found
	return null


func _is_private_pack_enabled() -> bool:
	for pack in ExtensionPackCatalog.list_enabled_packs(&"visual_profiles"):
		if StringName(pack.get("pack_id", StringName())) == PRIVATE_PACK_ID:
			return true
	return false


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


func _visible_textured_global_rect(root_node: Node) -> Rect2:
	var bounds := {
		"has_bounds": false,
		"min": Vector2(1000000000.0, 1000000000.0),
		"max": Vector2(-1000000000.0, -1000000000.0),
	}
	_accumulate_visible_textured_global_rect(root_node, bounds)
	if not bool(bounds["has_bounds"]):
		return Rect2()
	var min_pos := bounds["min"] as Vector2
	var max_pos := bounds["max"] as Vector2
	return Rect2(min_pos, max_pos - min_pos)


func _accumulate_visible_textured_global_rect(node: Node, bounds: Dictionary) -> void:
	if node == null:
		return
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.is_visible_in_tree() and sprite.texture != null:
			_expand_global_bounds_from_rect(sprite.get_global_transform(), sprite.get_rect(), bounds)
	for child in node.get_children():
		_accumulate_visible_textured_global_rect(child, bounds)


func _expand_global_bounds_from_rect(transform: Transform2D, rect: Rect2, bounds: Dictionary) -> void:
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(0.0, rect.size.y),
		rect.position + rect.size,
	]
	for corner: Vector2 in corners:
		var global_corner := transform * corner
		if not bool(bounds["has_bounds"]):
			bounds["has_bounds"] = true
			bounds["min"] = global_corner
			bounds["max"] = global_corner
			continue
		var min_pos := bounds["min"] as Vector2
		var max_pos := bounds["max"] as Vector2
		bounds["min"] = Vector2(minf(min_pos.x, global_corner.x), minf(min_pos.y, global_corner.y))
		bounds["max"] = Vector2(maxf(max_pos.x, global_corner.x), maxf(max_pos.y, global_corner.y))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
