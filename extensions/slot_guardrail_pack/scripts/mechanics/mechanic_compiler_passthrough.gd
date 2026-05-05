extends RefCounted
class_name SlotGuardrailCompilerPassthrough


func compile(_mechanic, _archetype, merged_params: Dictionary) -> Dictionary:
	return merged_params.duplicate(true)
