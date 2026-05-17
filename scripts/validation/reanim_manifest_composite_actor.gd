extends Node2D

@export_file("*.tscn") var raw_actor_scene_path := ""
@export var actor_anchor_offset := Vector2.ZERO
@export var actor_scale_value := 1.0
@export var initial_state := &"idle"
@export var state_animation_map: Dictionary = {}
@export var action_animation_map: Dictionary = {}
@export var animation_rate_map: Dictionary = {}
@export var texture_override_sets: Dictionary = {}
@export var suppressed_tracks: Array[String] = []
@export var anchors: Dictionary = {}

var _raw_actor: Node2D = null
var _animation_player: AnimationPlayer = null
var _visual_speed_scale := 1.0
var _one_shot_elapsed := 0.0
var _one_shot_duration := 0.0
var _one_shot_next_state := &""
var _anchor_nodes: Dictionary = {}


func _ready() -> void:
	process_priority = 100
	_load_actor()


func _process(delta: float) -> void:
	_hide_suppressed_tracks()
	if _one_shot_next_state == StringName():
		return
	_one_shot_elapsed += delta
	if _one_shot_elapsed < _one_shot_duration:
		return
	var next_state := _one_shot_next_state
	_one_shot_next_state = &""
	play_state(next_state)


func play_state(state_id: StringName) -> bool:
	var animation_name := _resolve_state_animation(state_id)
	if animation_name == StringName():
		return false
	_one_shot_next_state = &""
	return _play_animation(animation_name, true, _rate_for(animation_name))


func play_action(action_id: StringName) -> bool:
	var action_def: Variant = action_animation_map.get(action_id, action_animation_map.get(String(action_id), null))
	if action_def == null:
		return false
	if action_def is String or action_def is StringName:
		return _play_one_shot(StringName(action_def), &"idle", _rate_for(StringName(action_def)))
	if not action_def is Dictionary:
		return false

	var dict := action_def as Dictionary
	var animation_name := StringName(dict.get("animation", ""))
	if animation_name == StringName():
		return false
	var next_state := StringName(dict.get("next_state", "idle"))
	var rate := float(dict.get("rate", _rate_for(animation_name)))
	var loop := bool(dict.get("loop", false))
	if loop:
		return _play_animation(animation_name, true, rate)
	return _play_one_shot(animation_name, next_state, rate)


func play_animation(animation_name: StringName) -> bool:
	if _animation_player != null and _animation_player.has_animation(animation_name):
		return _play_animation(animation_name, true, _rate_for(animation_name))
	return play_state(animation_name) or play_action(animation_name)


func set_visual_speed(speed_scale: float) -> bool:
	_visual_speed_scale = maxf(0.01, speed_scale)
	if _animation_player != null:
		_animation_player.speed_scale = _visual_speed_scale
	return true


func apply_texture_override_set(set_id: StringName) -> bool:
	var override_entries: Variant = texture_override_sets.get(set_id, texture_override_sets.get(String(set_id), null))
	if not override_entries is Array:
		return false
	for entry in override_entries:
		if not entry is Dictionary:
			continue
		var dict := entry as Dictionary
		_patch_texture_override(
			StringName(dict.get("animation", "")),
			NodePath(String(dict.get("track", ""))),
			String(dict.get("texture", ""))
		)
	return true


func get_anchor(anchor_name: StringName) -> Node2D:
	return _anchor_nodes.get(anchor_name, _anchor_nodes.get(String(anchor_name), null)) as Node2D


func _load_actor() -> void:
	if raw_actor_scene_path == "" or not ResourceLoader.exists(raw_actor_scene_path):
		push_warning("Manifest composite raw actor is missing: %s" % raw_actor_scene_path)
		return
	var packed_scene := ResourceLoader.load(raw_actor_scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Manifest composite raw actor could not be loaded: %s" % raw_actor_scene_path)
		return
	var instance := packed_scene.instantiate()
	_raw_actor = instance as Node2D
	if _raw_actor == null:
		instance.queue_free()
		push_warning("Manifest composite raw actor root is not Node2D.")
		return

	_raw_actor.name = "RawActor"
	_raw_actor.position = actor_anchor_offset
	_raw_actor.scale = Vector2.ONE * actor_scale_value
	add_child(_raw_actor)
	_animation_player = _find_animation_player(_raw_actor)
	_create_anchors()
	_hide_suppressed_tracks()
	if initial_state != StringName():
		play_state(initial_state)


func _create_anchors() -> void:
	for raw_key in anchors.keys():
		var anchor := Node2D.new()
		anchor.name = "%sAnchor" % String(raw_key).capitalize().replace(" ", "")
		anchor.position = _to_vector2(anchors[raw_key])
		add_child(anchor)
		_anchor_nodes[raw_key] = anchor
		_anchor_nodes[StringName(String(raw_key))] = anchor


func _resolve_state_animation(state_id: StringName) -> StringName:
	var mapped: Variant = state_animation_map.get(state_id, state_animation_map.get(String(state_id), null))
	if mapped == null:
		return StringName()
	return StringName(mapped)


func _play_animation(animation_name: StringName, loop: bool, rate: float) -> bool:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return false
	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_animation_player.play(animation_name, 0.0, rate * _visual_speed_scale)
	_animation_player.advance(0.0)
	_hide_suppressed_tracks()
	return true


func _play_one_shot(animation_name: StringName, next_state: StringName, rate: float) -> bool:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return false
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return false
	animation.loop_mode = Animation.LOOP_NONE
	_animation_player.play(animation_name, 0.0, rate * _visual_speed_scale)
	_animation_player.advance(0.0)
	_one_shot_elapsed = 0.0
	_one_shot_duration = maxf(0.1, animation.length / maxf(0.01, absf(rate * _visual_speed_scale)))
	_one_shot_next_state = next_state
	_hide_suppressed_tracks()
	return true


func _rate_for(animation_name: StringName) -> float:
	return float(animation_rate_map.get(animation_name, animation_rate_map.get(String(animation_name), 1.0)))


func _patch_texture_override(animation_name: StringName, track_path: NodePath, texture_path: String) -> void:
	if animation_name == StringName() or String(track_path) == "" or texture_path == "":
		return
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return
	var texture := _load_texture(texture_path)
	if texture == null:
		return
	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return
	for track_index in range(animation.get_track_count()):
		if animation.track_get_path(track_index) != track_path:
			continue
		for key_index in range(animation.track_get_key_count(track_index)):
			animation.track_set_key_value(track_index, key_index, texture)
	var node_path := String(track_path).split(":", false)
	if node_path.size() > 0:
		var sprite := _raw_actor.get_node_or_null(NodePath(node_path[0])) as Sprite2D
		if sprite != null:
			sprite.texture = texture


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as Texture2D
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _hide_suppressed_tracks() -> void:
	if _raw_actor == null:
		return
	for track_name in suppressed_tracks:
		var sprite := _raw_actor.get_node_or_null(NodePath(track_name)) as Sprite2D
		if sprite != null:
			sprite.visible = false


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
