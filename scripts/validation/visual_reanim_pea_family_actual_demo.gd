extends Node2D

@export_file("*.tres") var profile_path := ""
@export var display_name := "Pea Family"
@export var status_text := ""
@export var plant_slot := 1
@export var plant_lane := 2
@export var target_slot := 7
@export var fire_interval_seconds := 1.45
@export var projectile_release_times := PackedFloat32Array([0.32])
@export var fallback_muzzle_offset := Vector2(46.0, -38.0)

const VIEWPORT_SIZE := Vector2(960.0, 540.0)
const BOARD_ORIGIN := Vector2(120.0, 135.0)
const SLOT_COUNT := 9
const LANE_COUNT := 5
const OPENPVZ_SLOT_SPACING := 80.0
const OPENPVZ_LANE_SPACING := 60.0
const PEA_SPEED_SLOTS_PER_SEC := 4.1625
const PEA_RADIUS := 7.0

var _status_label: Label = null
var _actor: Node2D = null
var _fire_elapsed := 0.0
var _pending_elapsed := 0.0
var _pending_release_times: Array[float] = []
var _peas: Array[Dictionary] = []


func _ready() -> void:
	_create_status_label()
	_load_actor()
	if status_text == "":
		_set_status("%s composite actor 演示：body/head attachment 封装在 actor scene，demo 只调用 play_action(shooting)。" % display_name)
	else:
		_set_status(status_text)


func _process(delta: float) -> void:
	_fire_elapsed += delta
	if _fire_elapsed >= fire_interval_seconds:
		_fire_elapsed = 0.0
		_fire_pea()

	if not _pending_release_times.is_empty():
		_pending_elapsed += delta
		while not _pending_release_times.is_empty() and _pending_elapsed >= _pending_release_times[0]:
			_pending_release_times.pop_front()
			_spawn_pea()

	var pea_speed := PEA_SPEED_SLOTS_PER_SEC * OPENPVZ_SLOT_SPACING
	var target_x := _slot_position(plant_lane, target_slot).x
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
	if profile_path == "" or not ResourceLoader.exists(profile_path):
		_set_status("未找到 composite visual profile：%s\n请先运行 reanim 导入并生成 composite 输出。" % profile_path)
		return

	var profile := ResourceLoader.load(profile_path)
	if profile == null or profile.get("actor_scene") == null:
		_set_status("composite visual profile 无法加载 actor_scene：%s" % profile_path)
		return

	var packed_scene := profile.get("actor_scene") as PackedScene
	var instance := packed_scene.instantiate()
	_actor = instance as Node2D
	if _actor == null:
		instance.queue_free()
		_set_status("composite actor 根节点不是 Node2D：%s" % profile_path)
		return

	_actor.position = _slot_position(plant_lane, plant_slot)
	add_child(_actor)
	if _actor.has_method("play_state"):
		_actor.call("play_state", &"idle")


func _fire_pea() -> void:
	if _actor == null or not _actor.has_method("play_action"):
		return
	var played := bool(_actor.call("play_action", &"shooting"))
	if not played:
		return

	_pending_elapsed = 0.0
	_pending_release_times.clear()
	for release_time in projectile_release_times:
		_pending_release_times.append(float(release_time))
	_pending_release_times.sort()


func _spawn_pea() -> void:
	_peas.append({
		"position": _muzzle_position(),
	})


func _muzzle_position() -> Vector2:
	if _actor != null and _actor.has_method("get_anchor"):
		var anchor := _actor.call("get_anchor", &"muzzle") as Node2D
		if anchor != null:
			return anchor.global_position
	return _slot_position(plant_lane, plant_slot) + fallback_muzzle_offset


func _draw_target() -> void:
	var center := _slot_position(plant_lane, target_slot)
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
