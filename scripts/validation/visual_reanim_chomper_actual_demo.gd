extends Node2D

const PROFILE_PATH := "res://vendor/out_files/_openpvz_import/chomper_composite/visual_profile.tres"
const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const BOARD_ORIGIN := Vector2(120.0, 135.0)
const SLOT_COUNT := 9
const LANE_COUNT := 5
const OPENPVZ_SLOT_SPACING := 80.0
const OPENPVZ_LANE_SPACING := 60.0
const PLANT_SLOT := 2
const PLANT_LANE := 2
const PHASE_READY := 0
const PHASE_BITING := 1
const PHASE_DIGESTING := 2
const PHASE_SWALLOWING := 3
const PHASE_RESPAWNING := 4
const READY_SECONDS := 1.0
const BITE_HIDE_TARGET_SECONDS := 0.72
const BITE_TO_DIGEST_SECONDS := 1.12
const DIGEST_SECONDS := 2.0
const SWALLOW_SECONDS := 2.45
const RESPAWN_SECONDS := 0.9

var _status_label: Label = null
var _actor: Node2D = null
var _phase := PHASE_READY
var _phase_elapsed := 0.0
var _target_visible := true
var _target_was_hidden := false


func _ready() -> void:
	_create_status_label()
	_load_actor()
	_set_status("Chomper composite actor 演示：idle -> bite -> chew(digesting) -> swallow，消化时长在 demo 中压缩到 2 秒。")


func _process(delta: float) -> void:
	_phase_elapsed += delta
	match _phase:
		PHASE_READY:
			if _phase_elapsed >= READY_SECONDS:
				_play_actor_action(&"devour")
				_set_phase(PHASE_BITING)
		PHASE_BITING:
			if not _target_was_hidden and _phase_elapsed >= BITE_HIDE_TARGET_SECONDS:
				_target_visible = false
				_target_was_hidden = true
			if _phase_elapsed >= BITE_TO_DIGEST_SECONDS:
				_set_phase(PHASE_DIGESTING)
		PHASE_DIGESTING:
			if _phase_elapsed >= DIGEST_SECONDS:
				_play_actor_action(&"swallow")
				_set_phase(PHASE_SWALLOWING)
		PHASE_SWALLOWING:
			if _phase_elapsed >= SWALLOW_SECONDS:
				_target_visible = true
				_set_phase(PHASE_RESPAWNING)
		PHASE_RESPAWNING:
			if _phase_elapsed >= RESPAWN_SECONDS:
				_set_phase(PHASE_READY)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color("203928"))
	draw_rect(
		Rect2(
			BOARD_ORIGIN + Vector2(-40.0, -42.0),
			Vector2(OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 80.0, OPENPVZ_LANE_SPACING * float(LANE_COUNT - 1) + 84.0)
		),
		Color("24492e")
	)

	for lane_index in range(LANE_COUNT):
		var y := _lane_y(lane_index)
		draw_line(Vector2(BOARD_ORIGIN.x - 40.0, y), Vector2(BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 40.0, y), Color("6b9f54"), 3.0)
		if lane_index < LANE_COUNT - 1:
			draw_line(Vector2(BOARD_ORIGIN.x - 40.0, y + OPENPVZ_LANE_SPACING * 0.5), Vector2(BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 40.0, y + OPENPVZ_LANE_SPACING * 0.5), Color("315b37"), 1.0)

	for slot_index in range(SLOT_COUNT + 1):
		var x := BOARD_ORIGIN.x + float(slot_index) * OPENPVZ_SLOT_SPACING
		draw_line(Vector2(x, _lane_y(0) - 42.0), Vector2(x, _lane_y(LANE_COUNT - 1) + 42.0), Color("315b37"), 1.0)

	if _target_visible:
		_draw_target(_target_position())


func _create_status_label() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 18.0)
	_status_label.size = Vector2(900.0, 72.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("f3f0d6"))
	canvas.add_child(_status_label)


func _load_actor() -> void:
	if not ResourceLoader.exists(PROFILE_PATH):
		_set_status("未找到 Chomper composite visual profile：%s\n请先运行 Chomper reanim 导入并生成 composite 输出。" % PROFILE_PATH)
		return

	var profile := ResourceLoader.load(PROFILE_PATH)
	if profile == null or profile.get("actor_scene") == null:
		_set_status("Chomper composite visual profile 无法加载 actor_scene：%s" % PROFILE_PATH)
		return

	var packed_scene := profile.get("actor_scene") as PackedScene
	var instance := packed_scene.instantiate()
	_actor = instance as Node2D
	if _actor == null:
		instance.queue_free()
		_set_status("Chomper composite actor 根节点不是 Node2D：%s" % PROFILE_PATH)
		return

	_actor.position = _slot_position(PLANT_LANE, PLANT_SLOT)
	add_child(_actor)
	if _actor.has_method("play_state"):
		_actor.call("play_state", &"idle")


func _set_phase(next_phase: int) -> void:
	_phase = next_phase
	_phase_elapsed = 0.0
	if next_phase == PHASE_READY:
		_target_visible = true
		_target_was_hidden = false


func _play_actor_action(action_id: StringName) -> void:
	if _actor != null and _actor.has_method("play_action"):
		_actor.call("play_action", action_id)


func _target_position() -> Vector2:
	if _actor != null and _actor.has_method("get_anchor"):
		var anchor := _actor.call("get_anchor", &"bite_target") as Node2D
		if anchor != null:
			return anchor.global_position
	return _slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(88.0, -32.0)


func _draw_target(center: Vector2) -> void:
	var body_rect := Rect2(center + Vector2(-13.0, -35.0), Vector2(26.0, 50.0))
	draw_rect(body_rect, Color("65705a"))
	draw_circle(center + Vector2(0.0, -48.0), 15.0, Color("879174"))
	draw_line(center + Vector2(-13.0, 12.0), center + Vector2(-23.0, 34.0), Color("65705a"), 4.0)
	draw_line(center + Vector2(13.0, 12.0), center + Vector2(23.0, 34.0), Color("65705a"), 4.0)


func _slot_position(lane: int, slot: int) -> Vector2:
	return Vector2(BOARD_ORIGIN.x + float(slot) * OPENPVZ_SLOT_SPACING + OPENPVZ_SLOT_SPACING * 0.5, _lane_y(lane))


func _lane_y(lane: int) -> float:
	return BOARD_ORIGIN.y + float(lane) * OPENPVZ_LANE_SPACING


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
