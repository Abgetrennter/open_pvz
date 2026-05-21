extends Resource
class_name WaveDef

@export var wave_id: StringName = &"wave"
@export var start_time := 0.0
@export var spawn_entries: Array = []
@export var wave_kind: StringName = &"normal"
@export var advance_policy: Resource = null
