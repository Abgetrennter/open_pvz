extends Node2D
class_name InfrastructureProtocolShowcase

const BACKGROUND := Color("e7e1d1")
const PANEL := Color("f6f0df")
const PANEL_OUTLINE := Color("756c57")
const TEXT := Color("2f2b22")
const MUTED := Color("6b6250")
const PLANT := Color("5aa06c")
const ZOMBIE := Color("7c8a55")
const BODY := Color("8f6b56")
const SHIELD := Color("78a8bf")
const HELM := Color("d6a653")
const ATTACHMENT := Color("c66f6f")
const PROJECTILE := Color("eec84d")
const HIT := Color("f0624d")
const BYPASS := Color("45a3d8")
const AIR := Color("79b7d9")
const HIDDEN := Color("7c6d9c")
const GROUND := Color("79a85b")
const GRID := Color("9fbe74")

@export_enum("health_layers", "damage_policy", "movement_leap", "exposure") var showcase_mode := "health_layers"
@export var showcase_title := "僵尸基础设施可视化"
@export_multiline var showcase_summary := ""

var _ui_layer: CanvasLayer = null
var _time := 0.0


func _ready() -> void:
	_build_ui()
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		_time = 0.0
		queue_redraw()
	elif key_event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(SceneRegistry.MAIN_SCENE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACKGROUND)
	_draw_board()
	match String(showcase_mode):
		"damage_policy":
			_draw_damage_policy()
		"movement_leap":
			_draw_movement_leap()
		"exposure":
			_draw_exposure()
		_:
			_draw_health_layers()


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 20
	add_child(_ui_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 12.0)
	panel.size = Vector2(430.0, 132.0)
	_ui_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 7)
	margin.add_child(layout)

	var title := Label.new()
	title.text = showcase_title
	layout.add_child(title)

	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = showcase_summary
	layout.add_child(summary)

	var controls := Label.new()
	controls.text = "R 重播    Esc 返回主面板"
	controls.modulate = Color(0.35, 0.35, 0.35, 1.0)
	layout.add_child(controls)


func _draw_board() -> void:
	var field := Rect2(Vector2(42.0, 184.0), Vector2(876.0, 286.0))
	draw_rect(field, Color("c9e89c"))
	draw_rect(field, Color("6f9d53"), false, 2.0)
	for row in range(3):
		var y := 232.0 + float(row) * 82.0
		draw_line(Vector2(64.0, y), Vector2(896.0, y), GRID, 2.0)
	for col in range(9):
		var x := 104.0 + float(col) * 88.0
		draw_line(Vector2(x, 198.0), Vector2(x, 456.0), Color("8db768", 0.45), 1.0)


func _draw_health_layers() -> void:
	_draw_panel(Vector2(498.0, 42.0), Vector2(390.0, 102.0), "HealthLayer 路由：attachment -> shield -> helm -> body")
	var amount := 42
	var progress := _loop_progress(5.4)
	var hit_index := mini(3, int(progress * 4.0))
	var labels: Array[String] = ["attachment", "shield", "helm", "body"]
	var colors: Array[Color] = [ATTACHMENT, SHIELD, HELM, BODY]
	var health: Array[int] = [20, 34, 50, 90]
	var max_health: Array[int] = [20, 50, 50, 90]
	for i in range(4):
		if i < hit_index:
			health[i] = 0
		elif i == hit_index:
			health[i] = maxi(0, health[i] - int(amount * _fract(progress * 4.0)))
	var start := Vector2(600.0, 336.0)
	_draw_layered_zombie(start, health, max_health)
	var shot_start := Vector2(176.0, 336.0)
	var target := start + Vector2(-72.0 + hit_index * 24.0, -74.0 + hit_index * 23.0)
	var shot_pos := shot_start.lerp(target, _fract(progress * 4.0))
	_draw_plant(shot_start)
	_draw_projectile(shot_pos, PROJECTILE)
	draw_line(shot_start + Vector2(28.0, -24.0), target, Color("e0c65b", 0.22), 2.0)
	for i in range(4):
		_draw_layer_card(Vector2(484.0 + i * 104.0, 206.0), labels[i], health[i], max_health[i], colors[i], i == hit_index)
	_draw_text("每次命中先找当前可承接层；过伤按 spill_to_next 继续向下一层路由。", Vector2(484.0, 112.0), 15, MUTED)


func _draw_damage_policy() -> void:
	_draw_panel(Vector2(478.0, 42.0), Vector2(410.0, 106.0), "DamageLayerPolicy：bypass_layer_kinds = [shield]")
	var progress := _loop_progress(5.0)
	var phase := int(progress * 3.0)
	_draw_plant(Vector2(160.0, 336.0))
	var zombie_pos := Vector2(664.0, 336.0)
	_draw_policy_zombie(zombie_pos, phase)
	var target_y := 315.0 if phase == 0 else 345.0
	var shot_pos := Vector2(190.0, 292.0).lerp(Vector2(610.0, target_y), _fract(progress * 3.0))
	_draw_projectile(shot_pos, BYPASS)
	draw_line(Vector2(188.0, 292.0), Vector2(610.0, target_y), Color("45a3d8", 0.25), 2.0)
	_draw_layer_card(Vector2(498.0, 204.0), "shield", 999 if phase == 0 else 999, 999, SHIELD, false)
	_draw_layer_card(Vector2(614.0, 204.0), "helm", 50 if phase < 2 else 12, 50, HELM, phase == 1)
	_draw_layer_card(Vector2(730.0, 204.0), "body", 90 if phase < 2 else 74, 90, BODY, phase == 2)
	_draw_text("投手类伤害可绕过 shield，但不会绕过 attachment 或 helm。", Vector2(500.0, 112.0), 15, MUTED)
	_draw_text("蓝色弹道表示 policy 透传到 projectile/direct/on-hit 三条入口。", Vector2(500.0, 132.0), 15, MUTED)


func _draw_movement_leap() -> void:
	_draw_panel(Vector2(468.0, 42.0), Vector2(420.0, 106.0), "Movement.core.leap_once：命令合并 + 逻辑 Z 轴")
	var progress := _loop_progress(4.2)
	var x := lerpf(180.0, 720.0, progress)
	var arc := sin(progress * PI)
	var height := arc * 98.0
	var ground := Vector2(x, 356.0)
	var pos := ground - Vector2(0.0, height)
	var airborne := progress > 0.06 and progress < 0.94
	_draw_shadow(ground, 22.0 + arc * 12.0)
	_draw_zombie_body(pos, ZOMBIE)
	_draw_arrow(Vector2(178.0, 356.0), Vector2(720.0, 356.0), GROUND)
	_draw_text("height = %.0f" % height, pos + Vector2(-34.0, -58.0), 16, TEXT)
	_draw_text("exposure_state = %s" % ("airborne" if airborne else "ground"), Vector2(500.0, 112.0), 15, MUTED)
	_draw_text("ground_contact = %s" % ("false" if airborne else "true"), Vector2(500.0, 132.0), 15, MUTED)
	_draw_text("落地时发出 entity.landed；位置积分仍只在 MovementComponent。", Vector2(500.0, 152.0), 15, MUTED)
	if progress > 0.9:
		_draw_impact_ring(ground, _fract((progress - 0.9) / 0.1))


func _draw_exposure() -> void:
	_draw_panel(Vector2(452.0, 42.0), Vector2(440.0, 116.0), "Exposure / HitPolicy：默认只命中 ground")
	var progress := _loop_progress(5.6)
	var shot_lane := int(progress * 4.0) % 4
	var states: Array[String] = ["ground", "flying", "underground", "airborne"]
	var colors: Array[Color] = [GROUND, AIR, HIDDEN, AIR]
	var y_values: Array[float] = [248.0, 318.0, 388.0, 458.0]
	for i in range(4):
		var pos := Vector2(660.0, y_values[i] - (44.0 if states[i] == "flying" else 0.0))
		if states[i] == "underground":
			_draw_hidden_zombie(Vector2(660.0, y_values[i]))
		else:
			_draw_zombie_body(pos, colors[i])
		_draw_text(states[i], Vector2(704.0, y_values[i] - 30.0), 15, TEXT)
	_draw_plant(Vector2(166.0, y_values[shot_lane]))
	var target := Vector2(620.0, y_values[shot_lane] - (44.0 if states[shot_lane] == "flying" else 0.0))
	var shot_pos := Vector2(194.0, y_values[shot_lane] - 24.0).lerp(target, _fract(progress * 4.0))
	var can_hit: bool = states[shot_lane] == "ground" or states[shot_lane] == "flying"
	var color: Color = PROJECTILE if states[shot_lane] == "ground" else (AIR if states[shot_lane] == "flying" else Color("969696"))
	_draw_projectile(shot_pos, color)
	if can_hit:
		_draw_text("target_exposure_states 显式 opt-in", Vector2(492.0, 122.0), 15, MUTED)
	else:
		_draw_text("默认 ground 不会命中特殊暴露态", Vector2(492.0, 122.0), 15, MUTED)
	_draw_text("ground 默认可命中；flying/submerged/underground/airborne 必须显式声明。", Vector2(492.0, 144.0), 15, MUTED)


func _draw_panel(pos: Vector2, size: Vector2, title: String) -> void:
	draw_rect(Rect2(pos, size), PANEL)
	draw_rect(Rect2(pos, size), PANEL_OUTLINE, false, 2.0)
	_draw_text(title, pos + Vector2(14.0, 28.0), 18, TEXT)


func _draw_layered_zombie(pos: Vector2, health: Array, max_health: Array) -> void:
	_draw_zombie_body(pos, BODY)
	if health[2] > 0:
		draw_rect(Rect2(pos + Vector2(-20.0, -84.0), Vector2(40.0, 13.0)), HELM)
		draw_rect(Rect2(pos + Vector2(-20.0, -84.0), Vector2(40.0, 13.0)), TEXT, false, 1.5)
	if health[1] > 0:
		draw_rect(Rect2(pos + Vector2(-42.0, -56.0), Vector2(16.0, 68.0)), SHIELD)
		draw_rect(Rect2(pos + Vector2(-42.0, -56.0), Vector2(16.0, 68.0)), TEXT, false, 1.5)
	if health[0] > 0:
		draw_circle(pos + Vector2(34.0, -78.0), 17.0, ATTACHMENT)
		draw_circle(pos + Vector2(34.0, -78.0), 17.0, TEXT, false, 1.5)
	_draw_stacked_bars(pos + Vector2(-46.0, 34.0), health, max_health)


func _draw_policy_zombie(pos: Vector2, phase: int) -> void:
	_draw_zombie_body(pos, BODY)
	draw_rect(Rect2(pos + Vector2(-44.0, -54.0), Vector2(16.0, 66.0)), SHIELD)
	draw_rect(Rect2(pos + Vector2(-44.0, -54.0), Vector2(16.0, 66.0)), TEXT, false, 1.5)
	if phase < 2:
		draw_rect(Rect2(pos + Vector2(-20.0, -84.0), Vector2(40.0, 13.0)), HELM)
		draw_rect(Rect2(pos + Vector2(-20.0, -84.0), Vector2(40.0, 13.0)), TEXT, false, 1.5)
	draw_arc(pos + Vector2(-36.0, -16.0), 34.0, deg_to_rad(-72.0), deg_to_rad(72.0), 12, BYPASS, 3.0)


func _draw_zombie_body(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos + Vector2(-18.0, -56.0), Vector2(36.0, 66.0)), color)
	draw_rect(Rect2(pos + Vector2(-18.0, -56.0), Vector2(36.0, 66.0)), TEXT, false, 2.0)
	draw_circle(pos + Vector2(0.0, -70.0), 17.0, color.lightened(0.12))
	draw_circle(pos + Vector2(0.0, -70.0), 17.0, TEXT, false, 2.0)
	draw_circle(pos + Vector2(-6.0, -73.0), 2.0, TEXT)
	draw_circle(pos + Vector2(6.0, -73.0), 2.0, TEXT)
	draw_line(pos + Vector2(-10.0, 10.0), pos + Vector2(-18.0, 26.0), TEXT, 2.0)
	draw_line(pos + Vector2(10.0, 10.0), pos + Vector2(18.0, 26.0), TEXT, 2.0)


func _draw_hidden_zombie(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-28.0, -8.0), Vector2(56.0, 16.0)), HIDDEN.darkened(0.2))
	draw_arc(pos, 28.0, PI, TAU, 16, HIDDEN, 4.0)
	_draw_text("hidden", pos + Vector2(-22.0, -24.0), 13, TEXT)


func _draw_plant(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-18.0, -48.0), Vector2(36.0, 56.0)), PLANT)
	draw_rect(Rect2(pos + Vector2(-18.0, -48.0), Vector2(36.0, 56.0)), TEXT, false, 2.0)
	draw_circle(pos + Vector2(10.0, -60.0), 16.0, PLANT.lightened(0.15))
	draw_circle(pos + Vector2(10.0, -60.0), 16.0, TEXT, false, 2.0)
	draw_circle(pos + Vector2(18.0, -62.0), 4.0, TEXT)


func _draw_projectile(pos: Vector2, color: Color) -> void:
	draw_circle(pos + Vector2(3.0, 5.0), 8.0, Color(0.0, 0.0, 0.0, 0.16))
	draw_circle(pos, 9.0, color)
	draw_circle(pos, 9.0, TEXT, false, 1.8)


func _draw_layer_card(pos: Vector2, label: String, value: int, maximum: int, color: Color, active: bool) -> void:
	var size := Vector2(92.0, 72.0)
	draw_rect(Rect2(pos, size), Color("fff8e7") if active else PANEL)
	draw_rect(Rect2(pos, size), color if active else PANEL_OUTLINE, false, 2.0)
	_draw_text(label, pos + Vector2(8.0, 22.0), 13, TEXT)
	var ratio := clampf(float(value) / maxf(float(maximum), 1.0), 0.0, 1.0)
	draw_rect(Rect2(pos + Vector2(8.0, 40.0), Vector2(76.0, 8.0)), Color("2f2b22", 0.16))
	draw_rect(Rect2(pos + Vector2(8.0, 40.0), Vector2(76.0 * ratio, 8.0)), color)
	_draw_text("%d/%d" % [value, maximum], pos + Vector2(8.0, 62.0), 12, MUTED)


func _draw_stacked_bars(pos: Vector2, health: Array, max_health: Array) -> void:
	var colors: Array[Color] = [ATTACHMENT, SHIELD, HELM, BODY]
	for i in range(4):
		var y := pos.y + float(i) * 9.0
		var ratio := clampf(float(health[i]) / maxf(float(max_health[i]), 1.0), 0.0, 1.0)
		draw_rect(Rect2(Vector2(pos.x, y), Vector2(92.0, 6.0)), Color("2f2b22", 0.16))
		draw_rect(Rect2(Vector2(pos.x, y), Vector2(92.0 * ratio, 6.0)), colors[i])


func _draw_shadow(pos: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		points.append(pos + Vector2(cos(angle) * radius, sin(angle) * radius * 0.32))
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.18))


func _draw_impact_ring(pos: Vector2, progress: float) -> void:
	var radius := lerpf(12.0, 48.0, progress)
	draw_circle(pos, radius, Color("f1d07a", 1.0 - progress), false, 3.0)


func _draw_arrow(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	draw_line(from_pos, to_pos, color, 4.0)
	var dir := (to_pos - from_pos).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon([to_pos, to_pos - dir * 18.0 + side * 8.0, to_pos - dir * 18.0 - side * 8.0], color)


func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _loop_progress(duration: float) -> float:
	return fmod(_time, duration) / duration


func _fract(value: float) -> float:
	return value - floor(value)
