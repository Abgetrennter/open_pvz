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
		"group_summary": "事件链、archetype 装配与运行时编译链的基础展示。",
		"color": Color("4db6ac"),
		"items": [
			{
				"title": "最小验证场景",
				"summary": "原始主干演示场景，包含直线、追踪和抛物线三种基础投射表现。",
				"scene": "res://scenes/showcase/minimal_validation_showcase.tscn",
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
				"summary": "一个资源生产型 archetype 通过 Trigger + Payload skeleton mechanic 编译出 RuntimeTriggerSpec，并沿共享产阳链生成和收集阳光。",
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
				"summary": "一个攻击型 archetype 通过 Trigger + Payload skeleton mechanic 编译出运行时 RuntimeTriggerSpec，并直接伤害和击杀目标。",
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
		"group_title": "原版植物移植展示",
		"group_summary": "39 种原版 PVZ 植物按战斗类型分为 8 个展示场景，直观呈现射手、寒冰、投手、生产、蘑菇、爆炸、防御和特殊植物的战斗行为。",
		"color": Color("66bb6a"),
		"items": [
			{
				"title": "射手植物园",
				"summary": "豌豆射手、双发射手、加特林豌豆、三线射手和分裂射手各对一行僵尸，展示从基础单发到连射、多方向射击的射手家族。",
				"scene": "res://scenes/showcase/original_shooter_garden_showcase.tscn",
			},
			{
				"title": "寒冰与控制园",
				"summary": "寒冰射手、寒冰菇、仙人掌、冰西瓜和猫尾草通过地面、空中、水面与升级上下文展示控制能力。",
				"scene": "res://scenes/showcase/original_frost_control_garden_showcase.tscn",
			},
			{
				"title": "投手园",
				"summary": "卷心菜投手、玉米投手、西瓜投手和杨桃展示抛物线投射、直接命中和终点爆炸溅射。",
				"scene": "res://scenes/showcase/original_lobber_garden_showcase.tscn",
			},
			{
				"title": "生产园",
				"summary": "向日葵、双子向日葵、阳光菇和金盏花并行产出阳光与金币，演示资源生产链的多样节奏。",
				"scene": "res://scenes/showcase/original_production_garden_showcase.tscn",
			},
			{
				"title": "蘑菇园",
				"summary": "小喷菇、大喷菇、忧郁菇、海蘑菇和胆小菇展示近距离、穿透、范围和条件触发的蘑菇家族。",
				"scene": "res://scenes/showcase/original_mushroom_garden_showcase.tscn",
			},
			{
				"title": "爆炸园",
				"summary": "樱桃炸弹、火爆辣椒、毁灭菇和土豆地雷展示各类爆炸效果。",
				"scene": "res://scenes/showcase/original_explosion_garden_showcase.tscn",
			},
			{
				"title": "防御与辅助园",
				"summary": "坚果墙、高坚果、南瓜罩、地刺、钢地刺和火炬树桩展示防御承伤、地面控制和火球强化。",
				"scene": "res://scenes/showcase/original_defense_support_garden_showcase.tscn",
			},
			{
				"title": "特殊植物园",
				"summary": "大嘴花、倭瓜、缠人海带、玉米加农炮、三叶草和魅惑菇展示吞噬、跳跃、水战、炮击和催眠等独特机制。",
				"scene": "res://scenes/showcase/original_special_garden_showcase.tscn",
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
	{
		"group_title": "本地素材导入",
		"group_summary": "仅用于本机私有解包素材的预览验证；场景动态读取 ignored 导入产物，不作为发布资源依赖。",
		"color": Color("ba68c8"),
		"items": [
			{
				"title": "Reanim 豌豆射手预览",
				"summary": "加载 reanim_import_one.gd 生成的 Peashooter actor，并轮播 idle、shooting 等导入动画。",
				"scene": "res://scenes/validation/visual_reanim_import_preview.tscn",
			},
			{
				"title": "Reanim 实际尺寸参考",
				"summary": "按原版 80 设计单位对齐 OpenPVZ 当前 80 world unit 格距，检查导入 actor 的真实战场占比。",
				"scene": "res://scenes/validation/visual_reanim_actual_size_preview.tscn",
			},
			{
				"title": "Reanim 实际演示",
				"summary": "在 OpenPVZ 当前 5 lane / 9 slot 棋盘尺度下播放 idle 与 shooting，并按 slots/s 展示豌豆弹道。",
				"scene": "res://scenes/validation/visual_reanim_actual_demo.tscn",
			},
			{
				"title": "Reanim Repeater 实际演示",
				"summary": "使用 PeaShooter.reanim 生成 Repeater composite actor，展示 body/head attachment 与双发节奏。",
				"scene": "res://scenes/validation/visual_reanim_repeater_actual_demo.tscn",
			},
			{
				"title": "Reanim Gatling Pea 实际演示",
				"summary": "加载 GatlingPea.reanim 生成的 composite actor，展示 anim_idle 挂点、head shooting 与四连发节奏。",
				"scene": "res://scenes/validation/visual_reanim_gatlingpea_actual_demo.tscn",
			},
			{
				"title": "Reanim Chomper 实际演示",
				"summary": "加载 Chomper.reanim 生成的 composite actor，展示 bite、chew、swallow 的单体状态机式视觉流程。",
				"scene": "res://scenes/validation/visual_reanim_chomper_actual_demo.tscn",
			},
			{
				"title": "Reanim 胆小菇实际演示",
				"summary": "加载 ScaredyShroom.reanim 生成的 composite actor，展示 sleep、grow、shooting、scared 与 scaredidle 形态变化。",
				"scene": "res://scenes/validation/visual_reanim_scaredyshroom_actual_demo.tscn",
			},
			{
				"title": "Reanim 向日葵实际演示",
				"summary": "加载本地导入的 Sunflower actor，在实际棋盘尺度下循环 idle 并展示周期产阳视觉。",
				"scene": "res://scenes/validation/visual_reanim_sunflower_actual_demo.tscn",
			},
			{
				"title": "Reanim 三线射手实际演示",
				"summary": "加载本地导入的 ThreePeater actor，复刻三头 attachment，并向上中下三条 lane 同步发射。",
				"scene": "res://scenes/validation/visual_reanim_threepeater_actual_demo.tscn",
			},
			{
				"title": "Reanim 坚果墙实际演示",
				"summary": "加载 Wallnut.reanim 生成的 actor，展示 idle 摇摆和 cracked1/cracked2 受伤贴图替换。",
				"scene": "res://scenes/validation/visual_reanim_wallnut_actual_demo.tscn",
			},
			{
				"title": "Reanim 土豆地雷实际演示",
				"summary": "加载 PotatoMine.reanim 生成的 actor，展示埋地、出土、armed/glow 和 mashed 爆炸状态流。",
				"scene": "res://scenes/validation/visual_reanim_potatomine_actual_demo.tscn",
			},
			{
				"title": "Reanim 樱桃炸弹实际演示",
				"summary": "加载 CherryBomb.reanim 生成的 actor，展示 idle 到 explode 的一次性爆炸视觉流程。",
				"scene": "res://scenes/validation/visual_reanim_cherrybomb_actual_demo.tscn",
			},
			{
				"title": "Reanim 倭瓜实际演示",
				"summary": "加载 Squash.reanim 生成的 manifest composite，展示观察、起跳和压制目标的一次性动作流程。",
				"scene": "res://scenes/validation/visual_reanim_squash_actual_demo.tscn",
			},
			{
				"title": "Reanim 大喷菇实际演示",
				"summary": "加载 FumeShroom.reanim 生成的 manifest composite，展示 idle/shooting 与短程喷雾占位效果。",
				"scene": "res://scenes/validation/visual_reanim_fumeshroom_actual_demo.tscn",
			},
			{
				"title": "Reanim 高坚果实际演示",
				"summary": "加载 Tallnut.reanim 生成的 manifest composite，展示坚果类 cracked 贴图替换的泛化流程。",
				"scene": "res://scenes/validation/visual_reanim_tallnut_actual_demo.tscn",
			},
			{
				"title": "Reanim 南瓜头实际演示",
				"summary": "加载 Pumpkin.reanim 生成的 manifest composite，展示 back/front 双层和 front 受伤贴图替换。",
				"scene": "res://scenes/validation/visual_reanim_pumpkin_actual_demo.tscn",
			},
			{
				"title": "Reanim 火爆辣椒实际演示",
				"summary": "加载 Jalapeno.reanim 生成的 manifest composite，展示 explode 动画和整行火焰占位效果。",
				"scene": "res://scenes/validation/visual_reanim_jalapeno_actual_demo.tscn",
			},
			{
				"title": "Reanim 毁灭菇实际演示",
				"summary": "加载 DoomShroom.reanim 生成的 manifest composite，展示 idle、explode、sleep 状态切换和爆炸占位效果。",
				"scene": "res://scenes/validation/visual_reanim_doomshroom_actual_demo.tscn",
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
