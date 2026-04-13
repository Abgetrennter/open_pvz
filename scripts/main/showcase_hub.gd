extends Control
class_name ShowcaseHub

const SHOWCASES := [
	{
		"title": "Minimal Validation",
		"summary": "Linear, tracking, and parabola samples in the original backbone scene.",
		"scene": "res://scenes/showcase/minimal_validation_showcase.tscn",
	},
	{
		"title": "Template Instantiation",
		"summary": "See template-driven entity spawning and runtime template ids in action.",
		"scene": "res://scenes/showcase/template_instantiation_showcase.tscn",
	},
	{
		"title": "Template Factory",
		"summary": "Attack, retaliation, and death behaviors built from template resources.",
		"scene": "res://scenes/showcase/template_factory_showcase.tscn",
	},
	{
		"title": "Height Hit Rules",
		"summary": "Compare low projectiles against elevated targets under height-band rules.",
		"scene": "res://scenes/showcase/height_hit_showcase.tscn",
	},
	{
		"title": "Terminal Explode",
		"summary": "Observe terminal-hit projectiles handing off to clustered explode damage.",
		"scene": "res://scenes/showcase/terminal_explode_showcase.tscn",
	},
]


func _ready() -> void:
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

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	shell.add_child(layout)

	var title := Label.new()
	title.text = "Open PVZ Showcase Hub"
	title.add_theme_font_size_override("font_size", 28)
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Open one stable showcase scene at a time. Each scene supports R to reset and Esc to return here."
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
	quit_button.text = "Quit"
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
	title.text = String(item.get("title", "Showcase"))
	title.add_theme_font_size_override("font_size", 20)
	layout.add_child(title)

	var summary := Label.new()
	summary.text = String(item.get("summary", ""))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(summary)

	var open_button := Button.new()
	open_button.text = "Open"
	open_button.pressed.connect(func(): _open_showcase(String(item.get("scene", ""))))
	layout.add_child(open_button)

	return panel


func _open_showcase(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)
