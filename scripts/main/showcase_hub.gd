extends Control
class_name ShowcaseHub

const VALIDATION_ENTRY_SCENE := "res://scenes/validation/minimal_battle_validation.tscn"

const SHOWCASES := [
	{
		"title": "最小验证场景",
		"summary": "原始主干演示场景，包含直线、追踪和抛物线三种基础投射表现。",
		"scene": "res://scenes/showcase/minimal_validation_showcase.tscn",
	},
	{
		"title": "模板实例化",
		"summary": "观察模板驱动实体生成，以及模板 ID 如何进入运行时事件链。",
		"scene": "res://scenes/showcase/template_instantiation_showcase.tscn",
	},
	{
		"title": "模板工厂",
		"summary": "观察攻击、受伤反击和死亡爆炸如何由模板资源生成，而不是写死在管理器里。",
		"scene": "res://scenes/showcase/template_factory_showcase.tscn",
	},
	{
		"title": "高度命中规则",
		"summary": "对比低高度投射物与高空目标的交互，观察高度带规则如何生效。",
		"scene": "res://scenes/showcase/height_hit_showcase.tscn",
	},
	{
		"title": "终点爆炸",
		"summary": "观察投射体在终点命中后，如何衔接到范围爆炸伤害链。",
		"scene": "res://scenes/showcase/terminal_explode_showcase.tscn",
	},
	{
		"title": "空中拦截样例",
		"summary": "Epic C 样例：空中追踪投射物分别命中低空与中空目标。",
		"scene": "res://scenes/showcase/air_interceptor_showcase.tscn",
	},
	{
		"title": "连发射手样例",
		"summary": "Epic C 样例：连续 burst 射击分别压制基础行进单位与快跑单位。",
		"scene": "res://scenes/showcase/repeater_burst_showcase.tscn",
	},
	{
		"title": "抛投样例集",
		"summary": "Epic C 样例：卷心菜直击与西瓜终点爆炸，两类抛投行为并列展示。",
		"scene": "res://scenes/showcase/lobber_catalog_showcase.tscn",
	},
	{
		"title": "僵尸梯队样例",
		"summary": "Epic C 样例：基础、快跑、坦克和重型僵尸共同测试统一的 bite 运行时。",
		"scene": "res://scenes/showcase/zombie_roster_showcase.tscn",
	},
]


func _ready() -> void:
	if _should_route_to_validation_scene():
		call_deferred("_open_showcase", VALIDATION_ENTRY_SCENE)
		return
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color("e7e1d1")
	add_child(background)

	var shell := MarginContainer.new()
	shell.anchor_right = 1.0
	shell.anchor_bottom = 1.0
	shell.add_theme_constant_override("margin_left", 40)
	shell.add_theme_constant_override("margin_top", 28)
	shell.add_theme_constant_override("margin_right", 40)
	shell.add_theme_constant_override("margin_bottom", 28)
	add_child(shell)

	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 18)
	scroll.add_child(layout)

	var title := Label.new()
	title.text = "Open PVZ 测试场景面板"
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "一次只进入一个稳定的展示场景。进入后可按 R 重置当前场景，按 Esc 返回这里。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(subtitle)

	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 16)
	cards.add_theme_constant_override("v_separation", 16)
	layout.add_child(cards)

	for item in SHOWCASES:
		cards.add_child(_build_showcase_card(item))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)

	var quit_button := Button.new()
	quit_button.text = "退出"
	quit_button.pressed.connect(func(): get_tree().quit())
	footer.add_child(quit_button)


func _build_showcase_card(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 140.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var title := Label.new()
	title.text = String(item.get("title", "展示场景"))
	title.add_theme_font_size_override("font_size", 20)
	layout.add_child(title)

	var summary := Label.new()
	summary.text = String(item.get("summary", ""))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(summary)

	var open_button := Button.new()
	open_button.text = "进入"
	open_button.pressed.connect(func(): _open_showcase(String(item.get("scene", ""))))
	layout.add_child(open_button)

	return panel


func _open_showcase(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)


func _should_route_to_validation_scene() -> bool:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg)
		if arg.begins_with("--validation-scenario="):
			return true
		if arg.begins_with("--validation-scenario-id="):
			return true
		if arg == "--validation-auto-quit":
			return true
	return false
