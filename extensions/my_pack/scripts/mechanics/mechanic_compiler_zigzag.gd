extends RefCounted
class_name MyPackMechanicCompilerZigzag


func compile(mechanic, _archetype, _merged_params: Dictionary) -> Dictionary:
	var params: Dictionary = Dictionary(mechanic.params).duplicate(true)
	params["movement_mode"] = &"my_pack.zigzag"
	if not params.has("amplitude"):
		params["amplitude"] = 24.0
	if not params.has("frequency"):
		params["frequency"] = 4.0
	return params

