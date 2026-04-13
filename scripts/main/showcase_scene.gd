extends "res://scripts/battle/battle_manager.gd"
class_name ShowcaseScene

@export var showcase_title := "展示场景"
@export_multiline var showcase_summary := ""

var _ui_layer: CanvasLayer = null
var _title_label: Label = null
var _summary_label: Label = null
var _back_button: Button = null


func _ready() -> void:
	super()
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		_return_to_main_menu()


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 20
	add_child(_ui_layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(12.0, 12.0)
	panel.size = Vector2(360.0, 120.0)
	_ui_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	_title_label = Label.new()
	_title_label.text = showcase_title
	layout.add_child(_title_label)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.text = showcase_summary
	layout.add_child(_summary_label)

	_back_button = Button.new()
	_back_button.text = "返回主面板 (Esc)"
	_back_button.pressed.connect(_return_to_main_menu)
	layout.add_child(_back_button)


func _return_to_main_menu() -> void:
	get_tree().change_scene_to_file(SceneRegistry.MAIN_SCENE)
