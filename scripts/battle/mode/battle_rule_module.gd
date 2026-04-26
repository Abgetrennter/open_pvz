extends Resource
class_name BattleRuleModule

@export var module_id: StringName = StringName()
@export var display_name := ""
@export var enabled := true
@export var priority := 100
@export var params: Dictionary = {}
@export var tags: PackedStringArray = PackedStringArray()
