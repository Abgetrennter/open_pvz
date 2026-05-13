extends Node2D

const ACTOR_SCENE_PATH := "res://vendor/out_files/_openpvz_import/peashooter_composite/actor.tscn"
const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const BOARD_ORIGIN := Vector2(120.0, 135.0)
const SLOT_COUNT := 9
const LANE_COUNT := 5
const OPENPVZ_SLOT_SPACING := 80.0
const OPENPVZ_LANE_SPACING := 60.0
const PLANT_SLOT := 1
const PLANT_LANE := 2
const TARGET_SLOT := 7
const PEA_SPEED_SLOTS_PER_SEC := 4.1625
const FIRE_INTERVAL_SECONDS := 1.45
const PEA_RELEASE_SECONDS := 0.32
const PEA_RADIUS := 7.0
const FALLBACK_MUZZLE_OFFSET := Vector2(46.0, -38.0)

var _status_label: Label = null
var _actor: Node2D = null
var _fire_elapsed := 0.0
var _pending_pea_elapsed := 0.0
var _has_pending_pea := false
var _peas: Array[Dictionary] = []


func _ready() -> void:
	_create_status_label()
	_load_actor()
	_set_status("Peashooter composite actor 演示：body/head/anim_stem 已封装在 actor scene，demo 只调用 play_action(shooting)。")


func _process(delta: float) -> void:
	_fire_elapsed += delta
	if _fire_elapsed >= FIRE_INTERVAL_SECONDS:
		_fire_elapsed = 0.0
		_fire_pea()

	if _has_pending_pea:
		_pending_pea_elapsed += delta
		if _pending_pea_elapsed >= PEA_RELEASE_SECONDS:
			_has_pending_pea = false
			_spawn_pea()

	var pea_speed := PEA_SPEED_SLOTS_PER_SEC * OPENPVZ_SLOT_SPACING
	var target_x := _slot_position(PLANT_LANE, TARGET_SLOT).x
	for i in range(_peas.size() - 1, -1, -1):
		var pea := _peas[i]
		var position := pea.get("position", Vector2.ZERO) as Vector2
		position.x += pea_speed * delta
		pea["position"] = position
		_peas[i] = pea
		if position.x >= target_x:
			_peas.remove_at(i)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEWPORT_SIZE), Color("203928"))
	draw_rect(Rect2(BOARD_ORIGIN + Vector2(-40.0, -42.0), Vector2(OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 80.0, OPENPVZ_LANE_SPACING * float(LANE_COUNT - 1) + 84.0)), Color("24492e"))

	for lane_index in range(LANE_COUNT):
		var y := _lane_y(lane_index)
		draw_line(Vector2(BOARD_ORIGIN.x - 40.0, y), Vector2(BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 40.0, y), Color("6b9f54"), 3.0)
		if lane_index < LANE_COUNT - 1:
			draw_line(Vector2(BOARD_ORIGIN.x - 40.0, y + OPENPVZ_LANE_SPACING * 0.5), Vector2(BOARD_ORIGIN.x + OPENPVZ_SLOT_SPACING * float(SLOT_COUNT) + 40.0, y + OPENPVZ_LANE_SPACING * 0.5), Color("315b37"), 1.0)

	for slot_index in range(SLOT_COUNT + 1):
		var x := BOARD_ORIGIN.x + float(slot_index) * OPENPVZ_SLOT_SPACING
		draw_line(Vector2(x, _lane_y(0) - 42.0), Vector2(x, _lane_y(LANE_COUNT - 1) + 42.0), Color("315b37"), 1.0)

	_draw_target()
	for pea in _peas:
		var position := pea.get("position", Vector2.ZERO) as Vector2
		draw_circle(position, PEA_RADIUS, Color("9be33b"))
		draw_circle(position + Vector2(-2.0, -2.0), PEA_RADIUS * 0.35, Color("e9ff8f"))


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
	if not ResourceLoader.exists(ACTOR_SCENE_PATH):
		_set_status("未找到 composite actor：%s\n请先运行 Peashooter reanim 导入并生成 composite 输出。" % ACTOR_SCENE_PATH)
		return

	var packed_scene := ResourceLoader.load(ACTOR_SCENE_PATH) as PackedScene
	if packed_scene == null:
		_set_status("composite actor 无法作为 PackedScene 加载：%s" % ACTOR_SCENE_PATH)
		return

	var instance := packed_scene.instantiate()
	_actor = instance as Node2D
	if _actor == null:
		instance.queue_free()
		_set_status("composite actor 根节点不是 Node2D：%s" % ACTOR_SCENE_PATH)
		return

	_actor.position = _slot_position(PLANT_LANE, PLANT_SLOT)
	add_child(_actor)
	if _actor.has_method("play_state"):
		_actor.call("play_state", &"idle")


func _fire_pea() -> void:
	if _actor == null or not _actor.has_method("play_action"):
		return
	var played := bool(_actor.call("play_action", &"shooting"))
	if not played:
		return
	_has_pending_pea = true
	_pending_pea_elapsed = 0.0


func _spawn_pea() -> void:
	_peas.append({
		"position": _muzzle_position(),
	})


func _muzzle_position() -> Vector2:
	if _actor != null and _actor.has_method("get_anchor"):
		var anchor := _actor.call("get_anchor", &"muzzle") as Node2D
		if anchor != null:
			return anchor.global_position
	return _slot_position(PLANT_LANE, PLANT_SLOT) + FALLBACK_MUZZLE_OFFSET


func _draw_target() -> void:
	var center := _slot_position(PLANT_LANE, TARGET_SLOT)
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
