extends "res://scripts/core/registry/registry_contributor_def.gd"
class_name ProjectileMovementDef

@export var movement_script: Script = null
@export var default_hit_strategy: StringName = &"swept_segment"
@export var default_terminal_hit_strategy: StringName = &"none"
