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
		"group_summary": "事件链、archetype 装配与迁移兼容层的基础展示；旧模板路径仅作为 legacy 对照保留。",
		"color": Color("4db6ac"),
		"items": [
			{
				"title": "最小验证场景",
				"summary": "原始主干演示场景，包含直线、追踪和抛物线三种基础投射表现。",
				"scene": "res://scenes/showcase/minimal_validation_showcase.tscn",
			},
			{
				"title": "Legacy 模板实例化",
				"summary": "观察旧模板兼容层如何继续生成实体，并把 legacy 模板身份带进事件链。",
				"scene": "res://scenes/showcase/template_instantiation_showcase.tscn",
			},
			{
				"title": "Legacy 模板工厂",
				"summary": "观察旧模板工厂如何作为迁移兼容层继续工作，而主作者入口已经切到 archetype。",
				"scene": "res://scenes/showcase/template_factory_showcase.tscn",
			},
		],
	},
	{
		"group_title": "Mechanic-first 骨架",
		"group_summary": "展示新 archetype / mechanic / compiler 骨架已经如何接回现有运行时主链，当前覆盖资源生产、直接伤害、投射物攻击、生命周期和基础僵尸路径。",
		"color": Color("8e9aee"),
		"items": [
			{
				"title": "产阳骨架展示",
				"summary": "一个资源生产型 archetype 通过 Trigger + Payload skeleton mechanic 编译出运行时 trigger binding，并沿共享产阳链生成和收集阳光。",
				"scene": "res://scenes/showcase/archetype_sunflower_showcase.tscn",
			},
			{
				"title": "生命周期骨架展示",
				"summary": "一个 lifecycle archetype 通过 on_spawned + produce_sun skeleton mechanic 编译出运行时触发器，并在进入战场时立即执行一次效果。",
				"scene": "res://scenes/showcase/archetype_lifecycle_showcase.tscn",
			},
			{
				"title": "放置生命周期展示",
				"summary": "一个 archetype-backed 卡片通过放置链进入战场，并在 placement.accepted 后立即触发 on_place lifecycle。",
				"scene": "res://scenes/showcase/archetype_on_place_showcase.tscn",
			},
			{
				"title": "状态阶段展示",
				"summary": "一个攻击 archetype 先处于 arming，再进入 active 后才开始伤害目标。",
				"scene": "res://scenes/showcase/archetype_state_showcase.tscn",
			},
			{
				"title": "攻击骨架展示",
				"summary": "一个攻击型 archetype 通过 Trigger + Payload skeleton mechanic 编译出运行时 trigger binding，并直接伤害和击杀目标。",
				"scene": "res://scenes/showcase/archetype_attack_showcase.tscn",
			},
			{
				"title": "投射物骨架展示",
				"summary": "两个 projectile archetype 分别生成直线和抛物线攻击，展示第一版编译器已经接回共享 spawn_projectile 运行时。",
				"scene": "res://scenes/showcase/archetype_projectile_showcase.tscn",
			},
			{
				"title": "僵尸骨架展示",
				"summary": "一个 zombie archetype 通过 archetype 入口生成，并继续复用现有 bite 连续运行时。",
				"scene": "res://scenes/showcase/archetype_zombie_showcase.tscn",
			},
			{
				"title": "Sweep 控制器展示",
				"summary": "一个 archetype-backed mower 通过 sweep controller 检测并清扫来袭僵尸。",
				"scene": "res://scenes/showcase/archetype_mower_showcase.tscn",
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
			{
				"title": "向日葵阳光生产",
				"summary": "三条车道各一棵向日葵，以不同间隔和价值并行产出阳光，同时演示天降阳光和自动收集。",
				"scene": "res://scenes/showcase/sunflower_sun_production_showcase.tscn",
			},
		],
	},
	{
		"group_title": "第五阶段错误技",
		"group_summary": "第五阶段错误技总览：前 4 个场景对应提交 7617055 的正式级联样例，后 9 个场景用于展示扩展包新增的分裂、召唤、状态控制、击退、跳链、光环、延迟触发、延迟爆炸和标记能力。",
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
			{
				"title": "命中分裂扩展样例",
				"summary": "主弹命中后从命中点分裂出追击投射物，验证扩展包最小 on_hit effect 位已经打通。",
				"scene": "res://scenes/showcase/hit_split_chaos_showcase.tscn",
			},
			{
				"title": "周期召唤扩展样例",
				"summary": "召唤植物周期生成 shardling 并加入战斗，验证扩展包最小 spawn_entity 能力位已经打通。",
				"scene": "res://scenes/showcase/periodic_summon_chaos_showcase.tscn",
			},
			{
				"title": "状态控制扩展样例",
				"summary": "命中后直接施加减速状态，验证扩展 apply_status 能力位已经接入现有状态主链。",
				"scene": "res://scenes/showcase/apply_status_chaos_showcase.tscn",
			},
			{
				"title": "击退扩展样例",
				"summary": "命中后把僵尸向后推回去，验证扩展 knockback 位移效果已经接入共享实体运行时。",
				"scene": "res://scenes/showcase/knockback_chaos_showcase.tscn",
			},
			{
				"title": "跳链扩展样例",
				"summary": "命中后按距离把伤害跳到附近多个目标，验证扩展 chain_bounce 多目标逻辑已经打通。",
				"scene": "res://scenes/showcase/chain_bounce_chaos_showcase.tscn",
			},
			{
				"title": "光环扩展样例",
				"summary": "站场植物持续减速近处敌人，验证扩展 aura 能力位已经接入共享状态主链。",
				"scene": "res://scenes/showcase/aura_chaos_showcase.tscn",
			},
			{
				"title": "延迟触发扩展样例",
				"summary": "命中后延迟一段时间再造成伤害，验证扩展 delayed_trigger 的时序执行链。",
				"scene": "res://scenes/showcase/delayed_trigger_chaos_showcase.tscn",
			},
			{
				"title": "延迟爆炸扩展样例",
				"summary": "命中后延迟爆炸并波及周围目标，验证扩展 delayed_explode 的共享 area effect 链。",
				"scene": "res://scenes/showcase/delayed_explode_chaos_showcase.tscn",
			},
			{
				"title": "标记扩展样例",
				"summary": "命中后施加独立 mark，并在持续时间结束后自动移除，验证扩展 mark 生命周期。",
				"scene": "res://scenes/showcase/mark_chaos_showcase.tscn",
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
