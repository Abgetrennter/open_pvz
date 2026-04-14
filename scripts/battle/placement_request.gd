extends Resource
class_name BattlePlacementRequest

@export var request_id: StringName = StringName()
@export var card_id: StringName = StringName()
@export var source_id: StringName = StringName()
@export var entity_template_id: StringName = StringName()
@export var lane_id := 0
@export var slot_index := 0
@export var placement_tags: PackedStringArray = PackedStringArray(["ground"])
