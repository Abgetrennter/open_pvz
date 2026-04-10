extends Node
class_name DebugViewComponent


func snapshot() -> Dictionary:
	return DebugService.snapshot_entity(get_parent())
