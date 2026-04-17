extends Control
class_name ShowcaseHub

const VALIDATION_ENTRY_SCENE := "res://scenes/validation/minimal_battle_validation.tscn"

const GROUPS := [
	{
		"group_title": "可玩演示",
		"group_summary": "完整的可玩关卡，包含玩家交互、经济循环和波次攻防。",
		"color": Color("f2d25c"),
		"items": [
			{
				"title": "MVP Demo",
				"summary": "收集阳光、放置植物、抵御 3 波僵尸进攻。点击卡片选中，点击格子放置。R 重开，Esc 返回。",
				"scene": "res://scenes/demo/demo_level.tscn",
			},
		],
	},
	{
		"group_title": "引擎核心",
		"group_summary": "事件链、模板装配、工厂触发等引擎骨架的基础展示。",
		"color": Color("4db6ac"),
		"items": [
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
		],
	},
	{
		"group_title": "投射体系统",
		"group_summary": "高度带、终点爆炸、扫掠碰撞等投射体运行时的展示。",
		"color": Color("4fc3f7"),
		"items": [
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
		],
	},
	{
		"group_title": "内容样例",
		"group_summary": "Epic C 内容扩展样例：各类植物与僵尸的攻防行为展示。",
		"color": Color("81c784"),
		"items": [
			{
				"title": "空中拦截样例",
				"summary": "空中追踪投射物分别命中低空与中空目标。",
				"scene": "res://scenes/showcase/air_interceptor_showcase.tscn",
			},
			{
				"title": "连发射手样例",
				"summary": "连续 burst 射击分别压制基础行进单位与快跑单位。",
				"scene": "res://scenes/showcase/repeater_burst_showcase.tscn",
			},
			{
				"title": "抛投样例集",
				"summary": "卷心菜直击与西瓜终点爆炸，两类抛投行为并列展示。",
				"scene": "res://scenes/showcase/lobber_catalog_showcase.tscn",
			},
			{
				"title": "僵尸梯队样例",
				"summary": "基础、快跑、坦克和重型僵尸共同测试统一的 bite 运行时。",
				"scene": "res://scenes/showcase/zombie_roster_showcase.tscn",
			},
		],
	},
	{
		"group_title": "第五阶段错误技",
		"group_summary": "第五阶段正式错误技样例分组，对齐提交 7617055 的 4 个标准场景，集中展示级联爆炸、溅射区域、高速追击和多 lane 反击。",
		"color": Color("ef6c57"),
		"items": [
			{
				"title": "连锁爆炸级联",
				"summary": "基础射手与追踪投弹手共同击穿 Reactive Bomber，随后触发双反击与死亡爆炸链。",
				"scene": "res://scenes/showcase/chain_explosion_cascade_showcase.tscn",
			},
			{
				"title": "溅射区域级联",
				"summary": "西瓜投手的终点爆炸同时覆盖重装桶僵尸和旁边普通僵尸，展示多目标 splash 结算。",
				"scene": "res://scenes/showcase/splash_zone_cascade_showcase.tscn",
			},
			{
				"title": "高速追击级联",
				"summary": "追踪投弹手反复追击快跑僵尸，观察 tracking runtime 对高速目标的连续命中。",
				"scene": "res://scenes/showcase/fast_pursuit_cascade_showcase.tscn",
			},
			{
				"title": "多 Lane 反击级联",
				"summary": "两条 lane 上各自独立完成攻击与反击，验证 retaliation 链不会跨 lane 串线。",
				"scene": "res://scenes/showcase/multi_lane_retaliation_cascade_showcase.tscn",
			},
		],
	},
	{
		"group_title": "输入验证",
		"group_summary": "验证鼠标点击交互的正确性：阳光收集、卡片放置等玩家输入路径。",
		"color": Color("ffb74d"),
		"items": [
			{
				"title": "阳光点击验证",
				"summary": "天降阳光后自动注入鼠标点击，验证点击收集事件链。",
				"scene": "res://scenes/validation/sun_click_validation.tscn",
			},
			{
				"title": "卡片放置验证",
				"summary": "自动选中卡片并点击格子，验证卡片放置的完整流程。",
				"scene": "res://scenes/validation/card_place_validation.tscn",
			},
		],
	},
]

var _root: VBoxContainer = null


func _ready() -> void:
	if _should_route_to_validation_scene():
		call_deferred("_open_showcase", VALIDATION_ENTRY_SCENE)
		return
	_build_ui()
	_show_group_list()


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

	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 16)
	scroll.add_child(_root)


func _clear_root() -> void:
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()


func _show_group_list() -> void:
	_clear_root()
	var title := Label.new()
	title.text = "Open PVZ"
	title.add_theme_font_size_override("font_size", 32)
	_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选择一个分组查看场景。进入后可按 R 重置当前场景，按 Esc 返回。"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(subtitle)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_root.add_child(grid)

	for i in range(GROUPS.size()):
		grid.add_child(_build_group_card(GROUPS[i], i))

	_root.add_child(_build_footer())


func _show_group_detail(group_index: int) -> void:
	_clear_root()
	var group: Dictionary = GROUPS[group_index]

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_root.add_child(header)

	var back_button := Button.new()
	back_button.text = "← 返回"
	back_button.pressed.connect(_show_group_list)
	header.add_child(back_button)

	var color_tag := ColorRect.new()
	color_tag.custom_minimum_size = Vector2(8.0, 28.0)
	color_tag.color = group.color
	header.add_child(color_tag)

	var group_title := Label.new()
	group_title.text = String(group.group_title)
	group_title.add_theme_font_size_override("font_size", 26)
	header.add_child(group_title)

	var count_label := Label.new()
	count_label.text = "(%d 个场景)" % group.items.size()
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.modulate = Color(0.5, 0.5, 0.5, 1.0)
	header.add_child(count_label)

	var desc := Label.new()
	desc.text = String(group.group_summary)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color(0.4, 0.4, 0.4, 1.0)
	_root.add_child(desc)

	var separator := HSeparator.new()
	_root.add_child(separator)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_root.add_child(grid)

	for item in group.items:
		grid.add_child(_build_scene_card(item, group.color))

	_root.add_child(_build_footer())


func _build_group_card(group: Dictionary, group_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 160.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var color_tag := ColorRect.new()
	color_tag.custom_minimum_size = Vector2(6.0, 24.0)
	color_tag.color = group.color
	header.add_child(color_tag)

	var title := Label.new()
	title.text = String(group.group_title)
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var count_label := Label.new()
	count_label.text = "%d" % group.items.size()
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.modulate = Color(0.5, 0.5, 0.5, 1.0)
	header.add_child(count_label)

	var summary := Label.new()
	summary.text = String(group.group_summary)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.modulate = Color(0.35, 0.35, 0.35, 1.0)
	layout.add_child(summary)

	var open_button := Button.new()
	open_button.text = "查看场景"
	open_button.pressed.connect(func(): _show_group_detail(group_index))
	layout.add_child(open_button)

	return panel


func _build_scene_card(item: Dictionary, accent_color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 130.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var title := Label.new()
	title.text = String(item.get("title", ""))
	title.add_theme_font_size_override("font_size", 18)
	layout.add_child(title)

	var summary := Label.new()
	summary.text = String(item.get("summary", ""))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.modulate = Color(0.35, 0.35, 0.35, 1.0)
	layout.add_child(summary)

	var open_button := Button.new()
	open_button.text = "进入"
	var scene_path := String(item.get("scene", ""))
	open_button.pressed.connect(func(): _open_showcase(scene_path))
	layout.add_child(open_button)

	return panel


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	var quit_button := Button.new()
	quit_button.text = "退出"
	quit_button.pressed.connect(func(): get_tree().quit())
	footer.add_child(quit_button)
	return footer


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
