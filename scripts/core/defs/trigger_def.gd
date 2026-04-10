extends Resource
class_name TriggerDef

@export var trigger_id: StringName = StringName()
@export var event_name: StringName = StringName()
@export var weight := 1
@export var max_bound_effects := 1
@export var condition_params: Array[Dictionary] = []
@export var tags: PackedStringArray = PackedStringArray()
