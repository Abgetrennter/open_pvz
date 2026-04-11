extends Resource
class_name BattleScenario

@export var scenario_id: StringName = &"minimal_validation"
@export var display_name := "Minimal Battle Validation"
@export_multiline var description := ""
@export var goals: PackedStringArray = PackedStringArray()
@export var validation_time_limit := 8.0
@export var validation_rules: Array = []
@export var spawns: Array = []
