extends "res://scripts/core/registry/registry_contributor_def.gd"
class_name VisualCueDef

@export var listen_event: StringName = StringName()
@export var filters: Dictionary = {}
@export var actions: Array[Dictionary] = []
