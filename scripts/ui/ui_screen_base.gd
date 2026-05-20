extends CanvasLayer
class_name UIScreenBase

const UIThemeProfileRef = preload("res://scripts/ui/theme/ui_theme_profile.gd")

var _battle: Node = null
var _theme_profile: Resource = null


func screen_setup(battle: Node, theme: Resource = null) -> void:
	_battle = battle
	_theme_profile = theme if theme != null else UIThemeProfileRef.default()


func screen_teardown() -> void:
	_battle = null


func _get_theme() -> Resource:
	return _theme_profile


func _resolve_text(key: StringName) -> String:
	return str(key)
