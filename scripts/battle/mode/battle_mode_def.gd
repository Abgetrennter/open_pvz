extends Resource
class_name BattleModeDef

@export var mode_id: StringName = StringName()
@export var display_name := ""
@export_multiline var description := ""
@export var category: StringName = &"challenge"

@export var input_profile: Resource = null
@export var objective_def: Resource = null
@export var rule_modules: Array[Resource] = []

@export var ui_profile_id: StringName = StringName()
@export var tags: PackedStringArray = PackedStringArray()
