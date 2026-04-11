extends Resource
class_name BattleValidationRule

@export var rule_id: StringName = &"rule"
@export_multiline var description := ""
@export var event_name: StringName = StringName()
@export var min_count := 1
@export var required_tags: PackedStringArray = PackedStringArray()
@export var required_core_values: Dictionary = {}
