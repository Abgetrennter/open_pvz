extends Node2D

@export_file("*.tscn") var raw_actor_scene_path := "res://vendor/out_files/_openpvz_import/scaredyshroom/actor.tscn"
@export var actor_anchor_offset := Vector2(-34.0, -78.0)
@export var actor_scale_value := 1.0
@export var muzzle_anchor_position := Vector2(14.0, -31.0)
@export var fear_anchor_position := Vector2(0.0, 20.0)
@export var idle_rate_scale := 12.0 / 12.0
@export var sleep_rate_scale := 12.0 / 12.0
@export var shooting_rate_scale := 35.0 / 12.0
@export var scared_rate_scale := 10.0 / 12.0
@export var grow_rate_scale := 9.0 / 12.0

const STATE_IDLE := &"idle"
const STATE_SLEEP := &"sleep"
const STATE_SCARED := &"scared"

var _raw_actor: Node2D = null
var _animation_player: AnimationPlayer = null
var _muzzle_anchor: Node2D = null
var _fear_anchor: Node2D = null
var _visual_speed_scale := 1.0
var _one_shot_elapsed := 0.0
var _one_shot_duration := 0.0
var _one_shot_next_state := &""
var _current_visual_state := STATE_IDLE


func _ready() -> void:
	process_priority = 100
	_load_actor()


func _process(delta: float) -> void:
	if _one_shot_next_state == StringName():
		return

	_one_shot_elapsed += delta
	if _one_shot_elapsed < _one_shot_duration:
		return

	var next_state := _one_shot_next_state
	_one_shot_next_state = &""
	play_state(next_state)


func play_state(state_id: StringName) -> bool:
	match state_id:
		&"idle", &"ready", &"awake":
			_one_shot_next_state = &""
			return _play_loop(&"idle", idle_rate_scale)
		&"sleep", &"sleeping", &"asleep":
			_one_shot_next_state = &""
			return _play_loop(&"sleep", sleep_rate_scale)
		&"scared", &"cowering", &"cower":
			_one_shot_next_state = &""
			return _play_loop(&"scaredidle", scared_rate_scale)
		_:
			return false


func play_action(action_id: StringName) -> bool:
	match action_id:
		&"shooting", &"shoot", &"fire", &"attack":
			return _play_one_shot(&"shooting", shooting_rate_scale, &"idle")
		&"scared", &"cower", &"lower", &"lowering":
			return _play_one_shot(&"scared", scared_rate_scale, &"scared")
		&"grow", &"raise", &"raising", &"wake":
			return _play_one_shot(&"grow", grow_rate_scale, &"idle")
		&"blink":
			return play_state(_current_visual_state)
		_:
			return false


func play_animation(animation_name: StringName) -> bool:
	match animation_name:
		&"idle":
			return play_state(&"idle")
		&"sleep":
			return play_state(&"sleep")
		&"scaredidle":
			return play_state(&"scared")
		&"shooting":
			return play_action(&"shooting")
		&"scared":
			return play_action(&"scared")
		&"grow":
			return play_action(&"grow")
		&"blink":
			return play_action(&"blink")
		_:
			return _play_loop(animation_name, idle_rate_scale)


func set_visual_speed(speed_scale: float) -> bool:
	_visual_speed_scale = maxf(0.01, speed_scale)
	if _animation_player != null:
		_animation_player.speed_scale = _visual_speed_scale
	return true


func get_anchor(anchor_name: StringName) -> Node2D:
	match anchor_name:
		&"muzzle", &"projectile", &"spore_spawn":
			return _muzzle_anchor
		&"fear", &"cower", &"nearby_scan":
			return _fear_anchor
		_:
			return null


func _load_actor() -> void:
	if raw_actor_scene_path == "" or not ResourceLoader.exists(raw_actor_scene_path):
		push_warning("Scaredy-shroom raw reanim actor is missing: %s" % raw_actor_scene_path)
		return

	var packed_scene := ResourceLoader.load(raw_actor_scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Scaredy-shroom raw reanim actor could not be loaded: %s" % raw_actor_scene_path)
		return

	var instance := packed_scene.instantiate()
	_raw_actor = instance as Node2D
	if _raw_actor == null:
		instance.queue_free()
		push_warning("Scaredy-shroom raw actor root is not Node2D.")
		return

	_raw_actor.name = "RawScaredyShroom"
	_raw_actor.position = actor_anchor_offset
	_raw_actor.scale = Vector2.ONE * actor_scale_value
	add_child(_raw_actor)

	_animation_player = _find_animation_player(_raw_actor)
	_create_anchors()
	play_state(&"sleep")


func _create_anchors() -> void:
	_muzzle_anchor = Node2D.new()
	_muzzle_anchor.name = "MuzzleAnchor"
	_muzzle_anchor.position = muzzle_anchor_position
	add_child(_muzzle_anchor)

	_fear_anchor = Node2D.new()
	_fear_anchor.name = "FearAnchor"
	_fear_anchor.position = fear_anchor_position
	add_child(_fear_anchor)


func _play_loop(animation_name: StringName, rate_scale: float) -> bool:
	if _animation_player == null or not _animation_player.has_animation(animation_name):
		return false

	var animation := _animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(animation_name, 0.0, rate_scale * _visual_speed_scale)
	_animation_player.advance(0.0)
	_current_visual_state = _state_from_animation(animation_name)
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
	return true


func _state_from_animation(animation_name: StringName) -> StringName:
	match animation_name:
		&"sleep":
			return STATE_SLEEP
		&"scared", &"scaredidle":
			return STATE_SCARED
		_:
			return STATE_IDLE


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child: Node in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
