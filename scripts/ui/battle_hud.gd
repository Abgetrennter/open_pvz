extends Control
class_name BattleHUD


func setup(battle: Node, scenario: Resource) -> void:
	for child in get_children():
		if child != null and child.has_method("panel_setup"):
			child.call("panel_setup", battle, scenario)


func teardown() -> void:
	for child in get_children():
		if child != null and child.has_method("panel_teardown"):
			child.call("panel_teardown")
