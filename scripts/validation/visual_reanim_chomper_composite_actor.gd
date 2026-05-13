extends Node2D

@export_file("*.tscn") var raw_actor_scene_path := "res://vendor/out_files/_openpvz_import/chomper/actor.tscn"
@export var actor_anchor_offset := Vector2(-44.0, -94.0)
@export var actor_scale_value := 1.0
@export var mouth_anchor_position := Vector2(58.0, -42.0)
@export var bite_target_anchor_position := Vector2(88.0, -32.0)
@export var idle_rate_scale := 1.0
@export var bite_rate_scale := 2.0
@export var chew_rate_scale := 1.25
@export var swallow_rate_scale := 1.0

const SUPPRESSED_HELPER_TRACKS := [
	"Chomper_stomach",
	"Zombie_outerarm_hand",
	"Zombie_outerarm_lower",
	"Chomper_tongue_lick",
]
const STATE_IDLE := &"idle"
const STATE_BITE := &"bite"
const STATE_CHEW := &"chew"
const STATE_SWALLOW := &"swallow"

var _raw_actor: Node2D = null
var _animation_player: AnimationPlayer = null
var _mouth_anchor: Node2D = null
var _bite_target_anchor: Node2D = null
var _visual_speed_scale := 1.0
var _one_shot_elapsed := 0.0
var _one_shot_duration := 0.0
var _one_shot_next_state := &""
var _current_visual_state := STATE_IDLE


func _ready() -> void:
	process_priority = 100
	_load_actor()


func _process(delta: float) -> void:
	_apply_state_layer_visibility()
	if _one_shot_next_state == StringName():
		return

	_one_shot_elapsed += delta
	if _one_shot_elapsed < _one_shot_duration:
		return

	var next_state := _one_shot_next_state
	_one_shot_next_state = &""
	if next_state == &"digesting":
		play_state(&"digesting")
	else:
		play_state(&"idle")


func play_state(state_id: StringName) -> bool:
	match state_id:
		&"idle", &"ready":
			_one_shot_next_state = &""
			return _play_loop(&"idle", idle_rate_scale)
		&"digesting", &"chew", &"chewing":
			_one_shot_next_state = &""
			return _play_loop(&"chew", chew_rate_scale)
		_:
			return false


func play_action(action_id: StringName) -> bool:
	match action_id:
		&"devour", &"bite", &"attack":
			return _play_one_shot(&"bite", bite_rate_scale, &"digesting")
		&"swallow":
			return _play_one_shot(&"swallow", swallow_rate_scale, &"idle")
		_:
			return false


func play_animation(animation_name: StringName) -> bool:
	match animation_name:
		&"idle":
			return play_state(&"idle")
		&"chew":
			return play_state(&"digesting")
		&"bite":
			return play_action(&"bite")
		&"swallow":
			return play_action(&"swallow")
		_:
			return _play_loop(animation_name, idle_rate_scale)


func set_visual_speed(speed_scale: float) -> bool:
	_visual_speed_scale = maxf(0.01, speed_scale)
	if _animation_player != null:
		_animation_player.speed_scale = _visual_speed_scale
	return true


func get_anchor(anchor_name: StringName) -> Node2D:
	match anchor_name:
		&"mouth", &"chomp", &"devour":
			return _mouth_anchor
		&"bite_target", &"target", &"devour_target":
			return _bite_target_anchor
		_:
			return null


func _load_actor() -> void:
	if raw_actor_scene_path == "" or not ResourceLoader.exists(raw_actor_scene_path):
		push_warning("Chomper raw reanim actor is missing: %s" % raw_actor_scene_path)
		return

	var packed_scene := ResourceLoader.load(raw_actor_scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Chomper raw reanim actor could not be loaded: %s" % raw_actor_scene_path)
		return

	var instance := packed_scene.instantiate()
	_raw_actor = instance as Node2D
	if _raw_actor == null:
		instance.queue_free()
		push_warning("Chomper raw actor root is not Node2D.")
		return

	_raw_actor.name = "RawChomper"
	_raw_actor.position = actor_anchor_offset
	_raw_actor.scale = Vector2.ONE * actor_scale_value
	add_child(_raw_actor)

	_animation_player = _find_animation_player(_raw_actor)
	_suppress_helper_animation_tracks()
	_create_anchors()
	play_state(&"idle")


func _create_anchors() -> void:
	_mouth_anchor = Node2D.new()
	_mouth_anchor.name = "MouthAnchor"
	_mouth_anchor.position = mouth_anchor_position
	add_child(_mouth_anchor)

	_bite_target_anchor = Node2D.new()
	_bite_target_anchor.name = "BiteTargetAnchor"
	_bite_target_anchor.position = bite_target_anchor_position
	add_child(_bite_target_anchor)


func _play_loop(animation_name: StringName, rate_scale: float) -> bool:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return false

	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(animation_name, 0.0, rate_scale * _visual_speed_scale)
	_animation_player.advance(0.0)
	_current_visual_state = _state_from_animation(animation_name)
	_apply_state_layer_visibility()
	return true


func _play_one_shot(animation_name: StringName, rate_scale: float, next_state: StringName) -> bool:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return false

	var animation := _animation_player.get_animation(animation_name)
	if animation == null:
		return false

	animation.loop_mode = Animation.LOOP_NONE
	_animation_player.play(animation_name, 0.0, rate_scale * _visual_speed_scale)
	_animation_player.advance(0.0)
	_one_shot_elapsed = 0.0
	_one_shot_duration = maxf(0.1, animation.length / maxf(0.01, absf(rate_scale * _visual_speed_scale)))
	_one_shot_next_state = next_state
	_current_visual_state = _state_from_animation(animation_name)
	_apply_state_layer_visibility()
	return true


func _state_from_animation(animation_name: StringName) -> StringName:
	match animation_name:
		&"bite":
			return STATE_BITE
		&"chew":
			return STATE_CHEW
		&"swallow":
			return STATE_SWALLOW
		_:
			return STATE_IDLE


func _apply_state_layer_visibility() -> void:
	if _raw_actor == null:
		return

	for node_name in SUPPRESSED_HELPER_TRACKS:
		_set_sprite_visible(node_name, false)


func _set_sprite_visible(node_name: String, is_visible: bool) -> void:
	var sprite := _raw_actor.get_node_or_null(NodePath(node_name)) as Sprite2D
	if sprite != null:
		sprite.visible = is_visible


func _suppress_helper_animation_tracks() -> void:
	if _animation_player == null:
		return

	for animation_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(animation_name)
		if animation == null:
			continue
		for track_index in range(animation.get_track_count()):
			var path := String(animation.track_get_path(track_index))
			for node_name in SUPPRESSED_HELPER_TRACKS:
				if path.begins_with("%s:" % node_name):
					animation.track_set_enabled(track_index, false)
					break


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child: Node in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
