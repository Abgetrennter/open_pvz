extends Resource
class_name ProjectileMovementDef

@export var move_mode: StringName = StringName()
@export var movement_script: Script = null
@export var param_defs: Array[Dictionary] = []
@export var default_hit_strategy: StringName = &"swept_segment"
@export var default_terminal_hit_strategy: StringName = &"none"
@export var tags: PackedStringArray = PackedStringArray()

