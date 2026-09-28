extends Node2D
class_name VisualStatusOverlayOwner

## Validation-only entity stand-in for status overlay probing. Exposes the
## duck-typed surface VisualActorComponent reads (get_entity_id,
## entity_kind) without touching any rule system. Never used by gameplay.


var entity_id: int = -1
var entity_kind: StringName = &"plant"


func get_entity_id() -> int:
	return entity_id
