extends "res://scripts/core/registry/registry_contributor_def.gd"
class_name VisualProfileDef

@export var actor_scene: PackedScene = null
@export var animation_map: Dictionary = {}
@export var state_animation_map: Dictionary = {}
@export var status_visual_map: Dictionary = {}
@export var damage_stage_defs: Array[Dictionary] = []
@export var shadow_policy: Dictionary = {}
@export var z_policy: Dictionary = {}
