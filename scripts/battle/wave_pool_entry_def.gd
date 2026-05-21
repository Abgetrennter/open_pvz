extends Resource
class_name WavePoolEntryDef

@export var archetype_id: StringName = StringName()
@export var archetype: Resource = null
@export var power := 1
@export var weight := 1
@export var first_allowed_wave := 0
@export var lane_id := 0
@export var x_position := 900.0
@export var required_spawn_tags: PackedStringArray = PackedStringArray()
@export var spawn_overrides: Dictionary = {}
