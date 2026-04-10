extends RefCounted
class_name EffectNode

var effect_id: StringName = StringName()
var params: Dictionary = {}
var children: Dictionary = {}


func _init(new_effect_id: StringName = StringName(), new_params: Dictionary = {}, new_children: Dictionary = {}) -> void:
	effect_id = new_effect_id
	params = new_params.duplicate(true)
	children = new_children.duplicate(true)


func get_child(slot_name: StringName):
	return children.get(slot_name)
