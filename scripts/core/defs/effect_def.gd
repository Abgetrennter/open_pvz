extends "res://scripts/core/registry/registry_contributor_def.gd"
class_name EffectDef

@export var slots: Array = []
@export var allow_extra_params := false
@export var allow_extra_children := false
@export var strategy_script: Script = null


func get_slot_def(slot_name: StringName):
	for slot_def in slots:
		if slot_def == null:
			continue
		if not slot_def.has_method("get"):
			continue
		if StringName(slot_def.get("slot_name")) == slot_name:
			return slot_def
	return null
