extends Node
class_name VisualStageLayerService

const VisualLayerPolicyRef = preload("res://scripts/visual/visual_layer_policy.gd")

# ── Layer host mapping ──────────────────────────────────────────────

var _layer_hosts: Dictionary = {}  # layer_name (StringName) -> Node2D host
var _root: Node2D = null           # BattleVisualRoot
var _background_sprite: Sprite2D = null


# ── Layer name to host node name mapping ────────────────────────────
# Some policy layers share a host node (e.g. plant + zombie → EntityLayer)

const _LAYER_TO_HOST := {
	&"ground": &"GroundLayer",
	&"shadow": &"ShadowLayer",
	&"field_object": &"FieldObjectLayer",
	&"plant": &"EntityLayer",
	&"zombie": &"EntityLayer",
	&"projectile": &"ProjectileLayer",
	&"world_fx": &"WorldFxLayer",
	&"fog_weather": &"FogWeatherLayer",
	&"preview": &"PreviewLayer",
	&"screen_fx": &"ScreenFxLayer",
	&"ui": &"UiLayer",
}

const _HOST_ORDER: PackedStringArray = [
	&"GroundLayer",
	&"ShadowLayer",
	&"FieldObjectLayer",
	&"EntityLayer",
	&"ProjectileLayer",
	&"WorldFxLayer",
	&"FogWeatherLayer",
	&"PreviewLayer",
	&"ScreenFxLayer",
	&"UiLayer",
]


# ── Public API ──────────────────────────────────────────────────────

func initialize(parent: Node2D) -> void:
	_root = Node2D.new()
	_root.name = "BattleVisualRoot"
	parent.add_child(_root)
	var runtime_entities := parent.get_node_or_null("RuntimeEntities")
	if runtime_entities != null:
		parent.move_child(_root, runtime_entities.get_index())

	for host_name: StringName in _HOST_ORDER:
		var host: Node2D = Node2D.new()
		host.name = host_name
		_root.add_child(host)
		_layer_hosts[host_name] = host


func get_layer_host(layer_name: StringName) -> Node2D:
	var host_name: StringName = _LAYER_TO_HOST.get(layer_name, &"EntityLayer")
	var host: Node2D = _layer_hosts.get(host_name, null)
	return host


func apply_z_index(node: Node2D, entity_kind: StringName, lane_id: int, local_offset: int = 0) -> void:
	node.z_index = VisualLayerPolicyRef.resolve_z_index(entity_kind, lane_id, VisualLayerPolicyRef.get_layer_for_entity_kind(entity_kind), local_offset)


func apply_visual_preset(preset: Resource) -> void:
	_clear_background()
	if preset == null:
		return
	var visual_id := StringName(preset.get("battlefield_visual_id"))
	if visual_id != StringName():
		_apply_battlefield_visual(visual_id)
		return
	var debug_service := _get_debug_service()
	if debug_service != null and debug_service.has_method("record_visual_event"):
		debug_service.record_visual_event({
			"cue_id": &"visual_preset_applied",
			"action_type": &"apply_visual_preset",
			"result": "recorded",
			"preset_class": preset.get_class(),
		})


func cleanup() -> void:
	_clear_background()
	for host: Variant in _layer_hosts.values():
		if host != null and is_instance_valid(host):
			host.queue_free()
	_layer_hosts.clear()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null


func _apply_battlefield_visual(visual_id: StringName) -> void:
	var asset_registry := _get_asset_registry()
	if asset_registry == null or not asset_registry.has_method("resolve_battlefield_visual"):
		_record_background_event(visual_id, "skipped", "asset registry unavailable")
		return
	var visual_def := asset_registry.call("resolve_battlefield_visual", visual_id) as Resource
	if visual_def == null:
		_record_background_event(visual_id, "skipped", "battlefield visual not found")
		return
	if not asset_registry.has_method("resolve_texture"):
		_record_background_event(visual_id, "skipped", "texture resolver unavailable")
		return
	var texture := asset_registry.call("resolve_texture", StringName(visual_def.get("texture_asset_id"))) as Texture2D
	if texture == null:
		_record_background_event(visual_id, "skipped", "texture not found")
		return
	var ground_layer := get_layer_host(&"ground")
	if ground_layer == null:
		_record_background_event(visual_id, "skipped", "ground layer unavailable")
		return
	_background_sprite = Sprite2D.new()
	_background_sprite.name = "BattlefieldBackground"
	_background_sprite.centered = false
	_background_sprite.texture = texture
	_background_sprite.position = Vector2(visual_def.get("draw_offset"))
	_background_sprite.z_index = 0
	ground_layer.add_child(_background_sprite)
	_record_background_event(visual_id, "executed", "")


func _clear_background() -> void:
	if _background_sprite != null and is_instance_valid(_background_sprite):
		var parent := _background_sprite.get_parent()
		if parent != null:
			parent.remove_child(_background_sprite)
		_background_sprite.free()
	_background_sprite = null


func _get_asset_registry() -> Node:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("AssetRegistry")


func _record_background_event(visual_id: StringName, result: String, skip_reason: String) -> void:
	var debug_service := _get_debug_service()
	if debug_service == null or not debug_service.has_method("record_visual_event"):
		return
	var event := {
		"cue_id": visual_id,
		"action_type": &"apply_battlefield_visual",
		"result": result,
	}
	if not skip_reason.is_empty():
		event["skip_reason"] = skip_reason
	debug_service.record_visual_event(event)


func _get_debug_service() -> Node:
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("DebugService")
