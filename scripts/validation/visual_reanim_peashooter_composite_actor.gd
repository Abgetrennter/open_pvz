extends Node2D

@export_file("*.tscn") var raw_actor_scene_path := "res://vendor/out_files/_openpvz_import/peashooter/actor.tscn"
const ACTOR_ANCHOR_OFFSET := Vector2(-44.0, -96.0)
const OPENPVZ_SLOT_SPACING := 80.0
const ORIGINAL_SLOT_WIDTH := 80.0
const ACTOR_SCALE_VALUE := OPENPVZ_SLOT_SPACING / ORIGINAL_SLOT_WIDTH
const REANIM_SOURCE_FPS := 12.0
const IDLE_RATE_SCALE := 17.0 / REANIM_SOURCE_FPS
const SHOOTING_RATE_SCALE := 35.0 / REANIM_SOURCE_FPS
const REANIM_BLEND_SECONDS := 0.18
const MUZZLE_POSITION := Vector2(46.0, -38.0)

var _body_actor: Node2D = null
var _head_actor: Node2D = null
var _body_stem: Node2D = null
var _muzzle_anchor: Node2D = null
var _body_animation_player: AnimationPlayer = null
var _head_animation_player: AnimationPlayer = null
var _stem_base_transform := Transform2D.IDENTITY
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
		_play_head_idle(REANIM_BLEND_SECONDS)


func play_state(state_id: StringName) -> bool:
	match state_id:
		&"idle":
			_play_body_idle(0.0, true)
			_play_head_idle(REANIM_BLEND_SECONDS)
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
	match animation_name:
		&"idle":
			return play_state(&"idle")
		&"head_idle":
			_play_head_idle(REANIM_BLEND_SECONDS)
			return true
		&"shooting":
			return _play_shooting()
		_:
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
		&"anim_stem", &"stem", &"head":
			return _body_stem
		_:
			return null


func _load_parts() -> void:
	if not ResourceLoader.exists(raw_actor_scene_path):
		push_warning("Peashooter raw reanim actor is missing: %s" % raw_actor_scene_path)
		return

	var raw_actor_scene := ResourceLoader.load(raw_actor_scene_path) as PackedScene
	if raw_actor_scene == null:
		push_warning("Peashooter raw reanim actor could not be loaded: %s" % raw_actor_scene_path)
		return

	_body_actor = _instantiate_part(raw_actor_scene, "Body")
	_head_actor = _instantiate_part(raw_actor_scene, "Head")
	if _body_actor == null or _head_actor == null:
		return

	_body_animation_player = _find_animation_player(_body_actor)
	_head_animation_player = _find_animation_player(_head_actor)
	_play_body_idle(0.0, true)

	_body_stem = _body_actor.get_node_or_null("anim_stem") as Node2D
	if _body_stem != null:
		_stem_base_transform = _body_stem.transform
	else:
		push_warning("Peashooter body actor is missing anim_stem; head attachment will fall back to body transform.")

	_play_head_idle(0.0, true)
	_create_muzzle_anchor()
	_update_head_attachment()


func _instantiate_part(raw_actor_scene: PackedScene, node_name: String) -> Node2D:
	var instance := raw_actor_scene.instantiate()
	var actor := instance as Node2D
	if actor == null:
		instance.queue_free()
		push_warning("Peashooter raw actor root is not Node2D.")
		return null
	actor.name = node_name
	actor.position = ACTOR_ANCHOR_OFFSET
	actor.scale = Vector2.ONE * ACTOR_SCALE_VALUE
	add_child(actor)
	return actor


func _create_muzzle_anchor() -> void:
	_muzzle_anchor = Node2D.new()
	_muzzle_anchor.name = "MuzzleAnchor"
	_muzzle_anchor.position = MUZZLE_POSITION
	add_child(_muzzle_anchor)


func _play_body_idle(blend_seconds := 0.0, advance_now := false) -> void:
	_play_on_player(_body_animation_player, &"idle", &"full_idle", blend_seconds, IDLE_RATE_SCALE, advance_now)


func _play_head_idle(blend_seconds := 0.0, advance_now := false) -> void:
	_play_on_player(_head_animation_player, &"head_idle", &"idle", blend_seconds, IDLE_RATE_SCALE, advance_now)


func _play_shooting() -> bool:
	if _head_animation_player == null:
		return false
	var animation_name := _play_on_player(_head_animation_player, &"shooting", &"head_idle", REANIM_BLEND_SECONDS, SHOOTING_RATE_SCALE)
	if animation_name == StringName():
		return false
	_is_shooting = true
	_shooting_elapsed = 0.0
	_shooting_duration = _animation_duration(_head_animation_player, animation_name, SHOOTING_RATE_SCALE)
	return true


func _play_raw_animation(animation_name: StringName) -> bool:
	if _body_animation_player != null and _body_animation_player.has_animation(animation_name):
		_play_on_player(_body_animation_player, animation_name, &"", REANIM_BLEND_SECONDS, IDLE_RATE_SCALE)
		return true
	if _head_animation_player != null and _head_animation_player.has_animation(animation_name):
		_play_on_player(_head_animation_player, animation_name, &"", REANIM_BLEND_SECONDS, IDLE_RATE_SCALE)
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
		if animation_name == &"shooting":
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
	if _body_stem == null:
		_head_actor.transform = _body_actor.transform
		return
	_head_actor.transform = _body_actor.transform * _body_stem.transform * _stem_base_transform.affine_inverse()


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child: Node in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
