extends CanvasLayer
class_name UIScreenBase

var _battle: Node = null
var _theme_profile: UIThemeProfile = null


func screen_setup(battle: Node, theme: UIThemeProfile = null) -> void:
	_battle = battle
	_theme_profile = theme if theme != null else UIThemeProfile.default()


func screen_teardown() -> void:
	_battle = null


func _get_theme() -> UIThemeProfile:
	return _theme_profile


func _resolve_text(key: StringName) -> String:
	return str(key)
