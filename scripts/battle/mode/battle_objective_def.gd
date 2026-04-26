extends Resource
class_name BattleObjectiveDef

@export var objective_id: StringName = StringName()
@export var objective_type: StringName = &"all_waves_cleared"
@export var params: Dictionary = {}
@export var failure_conditions: PackedStringArray = PackedStringArray()
@export var summary_tags: PackedStringArray = PackedStringArray()
