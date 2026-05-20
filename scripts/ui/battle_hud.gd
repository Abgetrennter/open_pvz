extends Control
class_name BattleHUD

const UIThemeProfileRef = preload("res://scripts/ui/theme/ui_theme_profile.gd")

var _theme_profile: Resource = null


func setup(battle: Node, scenario: Resource, theme: Resource = null) -> void:
	_theme_profile = theme if theme != null else UIThemeProfileRef.default()
	for child in get_children():
		if child != null and child.has_method("panel_setup"):
			child.call("panel_setup", battle, scenario, _theme_profile)


func teardown() -> void:
	for child in get_children():
		if child != null and child.has_method("panel_teardown"):
			child.call("panel_teardown")
