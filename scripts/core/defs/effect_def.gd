extends Resource
class_name EffectDef

@export var effect_id: StringName = StringName()
@export var param_defs: Array[Dictionary] = []
@export var slots: Array = []
@export var allow_extra_params := false
@export var allow_extra_children := false
@export var tags: PackedStringArray = PackedStringArray()


func get_param_def(param_name: StringName) -> Dictionary:
	for param_def in param_defs:
		if StringName(param_def.get("name", StringName())) == param_name:
			return param_def
	return {}


func get_slot_def(slot_name: StringName):
	for slot_def in slots:
		if slot_def == null:
			continue
		if not slot_def.has_method("get"):
			continue
		if StringName(slot_def.get("slot_name")) == slot_name:
			return slot_def
	return null
