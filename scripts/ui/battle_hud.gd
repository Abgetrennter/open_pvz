extends Control
class_name BattleHUD

var _theme_profile: UIThemeProfile = null


func setup(battle: Node, scenario: Resource, theme: UIThemeProfile = null) -> void:
	_theme_profile = theme if theme != null else UIThemeProfile.default()
	for child in get_children():
		if child != null and child.has_method("panel_setup"):
			child.call("panel_setup", battle, scenario, _theme_profile)


func teardown() -> void:
	for child in get_children():
		if child != null and child.has_method("panel_teardown"):
			child.call("panel_teardown")
