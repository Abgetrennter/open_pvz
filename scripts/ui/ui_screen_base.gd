extends CanvasLayer
class_name UIScreenBase

var _battle: Node = null


func screen_setup(battle: Node) -> void:
	_battle = battle


func screen_teardown() -> void:
	_battle = null
