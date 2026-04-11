extends Resource
class_name BattleScenario

@export var scenario_id: StringName = &"minimal_validation"
@export var display_name := "Minimal Battle Validation"
@export_multiline var description := ""
@export var goals: PackedStringArray = PackedStringArray()
@export var spawns: Array = []
