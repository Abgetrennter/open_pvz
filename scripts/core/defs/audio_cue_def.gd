extends "res://scripts/core/registry/registry_contributor_def.gd"
class_name AudioCueDef

@export var stream: Resource = null
@export var bus: StringName = &"Master"
@export var volume: float = 0.0
@export var pitch_range: Vector2 = Vector2(0.95, 1.05)
@export var dedupe_window: float = 0.05
