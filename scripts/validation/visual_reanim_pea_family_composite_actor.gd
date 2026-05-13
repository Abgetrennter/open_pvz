extends Node2D

@export_file("*.tscn") var raw_actor_scene_path := ""
@export var actor_log_name := "PeaFamily"
@export var actor_anchor_offset := Vector2(-44.0, -96.0)
@export var actor_scale_value := 1.0
@export var idle_rate_scale := 17.0 / 12.0
@export var shooting_rate_scale := 35.0 / 12.0
@export var reanim_blend_seconds := 0.18
@export var muzzle_position := Vector2(46.0, -38.0)
@export var body_idle_animation := &"idle"
@export var body_idle_fallback_animation := &"full_idle"
@export var head_idle_animation := &"head_idle"
@export var shooting_animation := &"shooting"

const ATTACHMENT_TRACK_NAMES := [&"anim_stem", &"anim_idle"]

var _body_actor: Node2D = null
var _head_actor: Node2D = null
var _body_attachment: Node2D = null
var _muzzle_anchor: Node2D = null
var _body_animation_player: AnimationPlayer = null
var _head_animation_player: AnimationPlayer = null
var _attachment_base_transform := Transform2D.IDENTITY
var _visual_speed_scale := 1.0
var _shooting_elapsed := 0.0
var _shooting_duration := 0.0
var _is_shooting := false


func _ready() -> void:
	process_priority = 100
	_load_parts()


func _process(delta: float) -> void:
	_update_head_attachment()
	if not _is_shooting:
		return

	_shooting_elapsed += delta
	if _shooting_elapsed >= _shooting_duration:
		_is_shooting = false
		_play_head_idle(reanim_blend_seconds)


func play_state(state_id: StringName) -> bool:
	match state_id:
		&"idle":
			_play_body_idle(0.0, true)
			_play_head_idle(reanim_blend_seconds)
			_is_shooting = false
			return true
		&"attacking", &"attack":
			return play_action(&"shooting")
		_:
			return false


func play_action(action_id: StringName) -> bool:
	match action_id:
		&"shooting", &"shoot", &"fire", &"attack":
			return _play_shooting()
		_:
			return false


func play_animation(animation_name: StringName) -> bool:
	if animation_name == body_idle_animation or animation_name == &"idle":
		return play_state(&"idle")
	if animation_name == head_idle_animation:
		_play_head_idle(reanim_blend_seconds)
		return true
	if animation_name == shooting_animation:
		return _play_shooting()
	return _play_raw_animation(animation_name)


func set_visual_speed(speed_scale: float) -> bool:
	_visual_speed_scale = maxf(0.01, speed_scale)
	if _body_animation_player != null:
		_body_animation_player.speed_scale = _visual_speed_scale
	if _head_animation_player != null:
		_head_animation_player.speed_scale = _visual_speed_scale
	return true


func get_anchor(anchor_name: StringName) -> Node2D:
	match anchor_name:
		&"muzzle", &"projectile", &"pea_spawn":
			return _muzzle_anchor
		&"anim_stem", &"stem", &"head", &"anim_idle":
			return _body_attachment
		_:
			return null


func _load_parts() -> void:
	if raw_actor_scene_path == "" or not ResourceLoader.exists(raw_actor_scene_path):
		push_warning("%s raw reanim actor is missing: %s" % [actor_log_name, raw_actor_scene_path])
		return

	var raw_actor_scene := ResourceLoader.load(raw_actor_scene_path) as PackedScene
	if raw_actor_scene == null:
		push_warning("%s raw reanim actor could not be loaded: %s" % [actor_log_name, raw_actor_scene_path])
		return

	_body_actor = _instantiate_part(raw_actor_scene, "Body")
	_head_actor = _instantiate_part(raw_actor_scene, "Head")
	if _body_actor == null or _head_actor == null:
		return

	_body_animation_player = _find_animation_player(_body_actor)
	_head_animation_player = _find_animation_player(_head_actor)
	_play_body_idle(0.0, true)

	_body_attachment = _find_attachment_track(_body_actor)
	if _body_attachment != null:
		_attachment_base_transform = _body_attachment.transform
	else:
		push_warning("%s body actor is missing anim_stem/anim_idle; head attachment will fall back to body transform." % actor_log_name)

	_play_head_idle(0.0, true)
	_create_muzzle_anchor()
	_update_head_attachment()


func _instantiate_part(raw_actor_scene: PackedScene, node_name: String) -> Node2D:
	var instance := raw_actor_scene.instantiate()
	var actor := instance as Node2D
	if actor == null:
		instance.queue_free()
		push_warning("%s raw actor root is not Node2D." % actor_log_name)
		return null

	actor.name = node_name
	actor.position = actor_anchor_offset
	actor.scale = Vector2.ONE * actor_scale_value
	add_child(actor)
	return actor


func _create_muzzle_anchor() -> void:
	_muzzle_anchor = Node2D.new()
	_muzzle_anchor.name = "MuzzleAnchor"
	_muzzle_anchor.position = muzzle_position
	add_child(_muzzle_anchor)


func _play_body_idle(blend_seconds := 0.0, advance_now := false) -> void:
	_play_on_player(_body_animation_player, body_idle_animation, body_idle_fallback_animation, blend_seconds, idle_rate_scale, advance_now)


func _play_head_idle(blend_seconds := 0.0, advance_now := false) -> void:
	_play_on_player(_head_animation_player, head_idle_animation, body_idle_animation, blend_seconds, idle_rate_scale, advance_now)


func _play_shooting() -> bool:
	if _head_animation_player == null:
		return false

	var animation_name := _play_on_player(_head_animation_player, shooting_animation, head_idle_animation, reanim_blend_seconds, shooting_rate_scale)
	if animation_name == StringName():
		return false

	_is_shooting = true
	_shooting_elapsed = 0.0
	_shooting_duration = _animation_duration(_head_animation_player, animation_name, shooting_rate_scale)
	return true


func _play_raw_animation(animation_name: StringName) -> bool:
	if _body_animation_player != null and _body_animation_player.has_animation(animation_name):
		_play_on_player(_body_animation_player, animation_name, &"", reanim_blend_seconds, idle_rate_scale)
		return true
	if _head_animation_player != null and _head_animation_player.has_animation(animation_name):
		_play_on_player(_head_animation_player, animation_name, &"", reanim_blend_seconds, idle_rate_scale)
		return true
	return false


func _play_on_player(
	player: AnimationPlayer,
	primary: StringName,
	fallback: StringName,
	blend_seconds := 0.0,
	rate_scale := 1.0,
	advance_now := false
) -> StringName:
	if player == null:
		return StringName()

	var animation_name := _resolve_animation_name(player, primary, fallback)
	if animation_name == StringName():
		return StringName()

	var animation := player.get_animation(animation_name)
	if animation != null:
		if animation_name == shooting_animation:
			animation.loop_mode = Animation.LOOP_NONE
		else:
			animation.loop_mode = Animation.LOOP_LINEAR

	player.play(animation_name, blend_seconds, rate_scale * _visual_speed_scale)
	if advance_now:
		player.advance(0.0)
	return animation_name


func _resolve_animation_name(player: AnimationPlayer, primary: StringName, fallback: StringName) -> StringName:
	if primary != StringName() and player.has_animation(primary):
		return primary
	if fallback != StringName() and player.has_animation(fallback):
		return fallback
	return StringName()


func _animation_duration(player: AnimationPlayer, animation_name: StringName, rate_scale: float) -> float:
	if player == null or animation_name == StringName() or not player.has_animation(animation_name):
		return 0.6

	var animation := player.get_animation(animation_name)
	if animation == null:
		return 0.6
	return maxf(0.1, animation.length / maxf(0.01, absf(rate_scale * _visual_speed_scale)))


func _update_head_attachment() -> void:
	if _body_actor == null or _head_actor == null:
		return
	if _body_attachment == null:
		_head_actor.transform = _body_actor.transform
		return
	_head_actor.transform = _body_actor.transform * _body_attachment.transform * _attachment_base_transform.affine_inverse()


func _find_attachment_track(root: Node) -> Node2D:
	for track_name in ATTACHMENT_TRACK_NAMES:
		var node := root.get_node_or_null(String(track_name)) as Node2D
		if node != null:
			return node
	return null


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child: Node in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
