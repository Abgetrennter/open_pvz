extends Node2D

const ACTOR_SCENE_PATH := "res://vendor/out_files/_openpvz_import/peashooter/actor.tscn"
const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const ACTOR_POSITION := Vector2(480.0, 318.0)
const ACTOR_SCALE := Vector2(3.0, 3.0)
const CYCLE_SECONDS := 1.6
const PREFERRED_ANIMATIONS: Array[StringName] = [
	&"idle",
	&"shooting",
	&"blink",
	&"full_idle",
	&"head_idle",
]

var _actor: Node2D = null
var _animation_player: AnimationPlayer = null
var _available_animations: Array[StringName] = []
var _animation_index := 0
var _cycle_elapsed := 0.0
var _status_label: Label = null


func _ready() -> void:
	_create_status_label()
	_load_actor()


func _process(delta: float) -> void:
	if _animation_player == null or _available_animations.is_empty():
		return
	_cycle_elapsed += delta
	if Input.is_action_just_pressed("ui_accept") or _cycle_elapsed >= CYCLE_SECONDS:
		_cycle_elapsed = 0.0
		_play_animation((_animation_index + 1) % _available_animations.size())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color("203928"))
	for lane_index in range(5):
		var y := 158.0 + float(lane_index) * 58.0
		draw_line(Vector2(96.0, y), Vector2(864.0, y), Color("4f7e48"), 2.0)
		draw_line(Vector2(96.0, y + 29.0), Vector2(864.0, y + 29.0), Color("315b37"), 1.0)
	for column_index in range(9):
		var x := 144.0 + float(column_index) * 80.0
		draw_line(Vector2(x, 132.0), Vector2(x, 418.0), Color("315b37"), 1.0)
	draw_line(Vector2(96.0, 418.0), Vector2(864.0, 418.0), Color("6b9f54"), 3.0)


func _create_status_label() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 20.0)
	_status_label.size = Vector2(880.0, 72.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("f3f0d6"))
	canvas.add_child(_status_label)


func _load_actor() -> void:
	if not ResourceLoader.exists(ACTOR_SCENE_PATH):
		_set_status("未找到导入产物：%s\n请先运行 reanim_import_one.gd 生成 Peashooter actor。" % ACTOR_SCENE_PATH)
		return

	var packed_scene := ResourceLoader.load(ACTOR_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_set_status("导入产物无法作为 PackedScene 加载：%s" % ACTOR_SCENE_PATH)
		return

	var instance := packed_scene.instantiate()
	_actor = instance as Node2D
	if _actor == null:
		instance.queue_free()
		_set_status("导入产物根节点不是 Node2D：%s" % ACTOR_SCENE_PATH)
		return

	_actor.position = ACTOR_POSITION
	_actor.scale = ACTOR_SCALE
	add_child(_actor)

	_animation_player = _find_animation_player(_actor)
	if _animation_player == null:
		_set_status("已加载 actor，但没有找到 AnimationPlayer。")
		return

	_available_animations = _collect_available_animations(_animation_player)
	if _available_animations.is_empty():
		_set_status("已加载 actor，但 AnimationPlayer 中没有可播放动画。")
		return

	_play_animation(0)


func _find_animation_player(root: Node) -> AnimationPlayer:
	var direct := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if direct != null:
		return direct
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _collect_available_animations(player: AnimationPlayer) -> Array[StringName]:
	var collected: Array[StringName] = []
	for animation_name in PREFERRED_ANIMATIONS:
		if player.has_animation(animation_name):
			collected.append(animation_name)
	for animation_name in player.get_animation_list():
		var normalized := StringName(animation_name)
		if not collected.has(normalized):
			collected.append(normalized)
	return collected


func _play_animation(index: int) -> void:
	if _animation_player == null or _available_animations.is_empty():
		return
	_animation_index = clampi(index, 0, _available_animations.size() - 1)
	var animation_name := _available_animations[_animation_index]
	_animation_player.play(animation_name)
	_set_status("Reanim Import Preview: %s\n动画 %d/%d: %s" % [
		ACTOR_SCENE_PATH,
		_animation_index + 1,
		_available_animations.size(),
		String(animation_name),
	])


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
