extends Node2D

const PROFILE_PATH := "res://vendor/out_files/_openpvz_import/scaredyshroom_composite/visual_profile.tres"
const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const BOARD_ORIGIN := Vector2(120.0, 135.0)
const SLOT_COUNT := 9
const LANE_COUNT := 5
const OPENPVZ_SLOT_SPACING := 80.0
const OPENPVZ_LANE_SPACING := 60.0
const PLANT_SLOT := 2
const PLANT_LANE := 2
const TARGET_FAR_SLOT := 7
const TARGET_NEAR_SLOT_OFFSET := 1.15
const SPORE_SPEED_SLOTS_PER_SEC := 4.1625
const SPORE_RADIUS := 6.0
const PHASE_SLEEP := 0
const PHASE_GROW := 1
const PHASE_IDLE := 2
const PHASE_READY_PAUSE := 3
const PHASE_SHOOT := 4
const PHASE_APPROACH := 5
const PHASE_COWER := 6
const PHASE_SCARED_IDLE := 7
const PHASE_RAISE := 8
const PHASE_RESET := 9

const PHASE_SECONDS := {
	PHASE_SLEEP: 1.0,
	PHASE_GROW: 1.35,
	PHASE_IDLE: 0.8,
	PHASE_READY_PAUSE: 0.45,
	PHASE_SHOOT: 1.0,
	PHASE_APPROACH: 1.0,
	PHASE_COWER: 1.2,
	PHASE_SCARED_IDLE: 1.4,
	PHASE_RAISE: 1.4,
	PHASE_RESET: 0.65,
}

var _status_label: Label = null
var _actor: Node2D = null
var _phase := PHASE_SLEEP
var _phase_elapsed := 0.0
var _pending_spore_elapsed := 0.0
var _pending_spore_release := -1.0
var _spores: Array[Dictionary] = []


func _ready() -> void:
	_create_status_label()
	_load_actor()
	_set_status("Scaredy-shroom composite actor 演示：sleep -> grow -> idle -> shooting -> scared -> scaredidle -> grow。")


func _process(delta: float) -> void:
	_phase_elapsed += delta
	_update_phase()
	_update_pending_spore(delta)
	_update_spores(delta)
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

	_draw_target(_target_position())
	for spore in _spores:
		var position := spore.get("position", Vector2.ZERO) as Vector2
		draw_circle(position, SPORE_RADIUS, Color("d9eff7"))
		draw_circle(position + Vector2(-2.0, -2.0), SPORE_RADIUS * 0.35, Color("ffffff"))


func _create_status_label() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_status_label = Label.new()
	_status_label.position = Vector2(24.0, 18.0)
	_status_label.size = Vector2(900.0, 84.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color("f3f0d6"))
	canvas.add_child(_status_label)


func _load_actor() -> void:
	if not ResourceLoader.exists(PROFILE_PATH):
		_set_status("未找到 Scaredy-shroom composite visual profile：%s\n请先运行 Scaredy-shroom reanim 导入并生成 composite 输出。" % PROFILE_PATH)
		return

	var profile := ResourceLoader.load(PROFILE_PATH)
	if profile == null or profile.get("actor_scene") == null:
		_set_status("Scaredy-shroom composite visual profile 无法加载 actor_scene：%s" % PROFILE_PATH)
		return

	var packed_scene := profile.get("actor_scene") as PackedScene
	var instance := packed_scene.instantiate()
	_actor = instance as Node2D
	if _actor == null:
		instance.queue_free()
		_set_status("Scaredy-shroom composite actor 根节点不是 Node2D：%s" % PROFILE_PATH)
		return

	_actor.position = _slot_position(PLANT_LANE, PLANT_SLOT)
	add_child(_actor)
	if _actor.has_method("play_state"):
		_actor.call("play_state", &"sleep")


func _update_phase() -> void:
	var duration := float(PHASE_SECONDS.get(_phase, 1.0))
	if _phase_elapsed < duration:
		return

	match _phase:
		PHASE_SLEEP:
			_play_actor_action(&"grow")
			_set_phase(PHASE_GROW)
		PHASE_GROW:
			_play_actor_state(&"idle")
			_set_phase(PHASE_IDLE)
		PHASE_IDLE:
			_set_phase(PHASE_READY_PAUSE)
		PHASE_READY_PAUSE:
			_play_actor_action(&"shooting")
			_pending_spore_elapsed = 0.0
			_pending_spore_release = 0.28
			_set_phase(PHASE_SHOOT)
		PHASE_SHOOT:
			_set_phase(PHASE_APPROACH)
		PHASE_APPROACH:
			_play_actor_action(&"scared")
			_set_phase(PHASE_COWER)
		PHASE_COWER:
			_play_actor_state(&"scared")
			_set_phase(PHASE_SCARED_IDLE)
		PHASE_SCARED_IDLE:
			_play_actor_action(&"grow")
			_set_phase(PHASE_RAISE)
		PHASE_RAISE:
			_play_actor_state(&"idle")
			_set_phase(PHASE_RESET)
		_:
			_play_actor_state(&"sleep")
			_set_phase(PHASE_SLEEP)


func _set_phase(next_phase: int) -> void:
	_phase = next_phase
	_phase_elapsed = 0.0


func _update_pending_spore(delta: float) -> void:
	if _pending_spore_release < 0.0:
		return

	_pending_spore_elapsed += delta
	if _pending_spore_elapsed < _pending_spore_release:
		return

	_pending_spore_release = -1.0
	_spores.append({"position": _muzzle_position()})


func _update_spores(delta: float) -> void:
	var spore_speed := SPORE_SPEED_SLOTS_PER_SEC * OPENPVZ_SLOT_SPACING
	var target_x := _slot_position(PLANT_LANE, TARGET_FAR_SLOT).x
	for i in range(_spores.size() - 1, -1, -1):
		var spore := _spores[i]
		var position := spore.get("position", Vector2.ZERO) as Vector2
		position.x += spore_speed * delta
		spore["position"] = position
		_spores[i] = spore
		if position.x >= target_x:
			_spores.remove_at(i)


func _play_actor_state(state_id: StringName) -> void:
	if _actor != null and _actor.has_method("play_state"):
		_actor.call("play_state", state_id)


func _play_actor_action(action_id: StringName) -> void:
	if _actor != null and _actor.has_method("play_action"):
		_actor.call("play_action", action_id)


func _muzzle_position() -> Vector2:
	if _actor != null and _actor.has_method("get_anchor"):
		var anchor := _actor.call("get_anchor", &"muzzle") as Node2D
		if anchor != null:
			return anchor.global_position
	return _slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(14.0, -31.0)


func _target_position() -> Vector2:
	var far := _slot_position(PLANT_LANE, TARGET_FAR_SLOT)
	var near := _slot_position(PLANT_LANE, PLANT_SLOT) + Vector2(OPENPVZ_SLOT_SPACING * TARGET_NEAR_SLOT_OFFSET, 0.0)
	match _phase:
		PHASE_APPROACH:
			return far.lerp(near, clampf(_phase_elapsed / float(PHASE_SECONDS[PHASE_APPROACH]), 0.0, 1.0))
		PHASE_COWER, PHASE_SCARED_IDLE:
			return near
		PHASE_RAISE:
			return near.lerp(far, clampf(_phase_elapsed / float(PHASE_SECONDS[PHASE_RAISE]), 0.0, 1.0))
		_:
			return far


func _draw_target(center: Vector2) -> void:
	var body_rect := Rect2(center + Vector2(-16.0, -50.0), Vector2(32.0, 72.0))
	draw_rect(body_rect, Color("65705a"))
	draw_circle(center + Vector2(0.0, -64.0), 18.0, Color("879174"))
	draw_line(center + Vector2(-18.0, 24.0), center + Vector2(-28.0, 52.0), Color("65705a"), 5.0)
	draw_line(center + Vector2(18.0, 24.0), center + Vector2(28.0, 52.0), Color("65705a"), 5.0)


func _slot_position(lane: int, slot: int) -> Vector2:
	return Vector2(BOARD_ORIGIN.x + float(slot) * OPENPVZ_SLOT_SPACING + OPENPVZ_SLOT_SPACING * 0.5, _lane_y(lane))


func _lane_y(lane: int) -> float:
	return BOARD_ORIGIN.y + float(lane) * OPENPVZ_LANE_SPACING


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
