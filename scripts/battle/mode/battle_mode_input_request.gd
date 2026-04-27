extends Resource
class_name BattleModeInputRequest

@export var at_time := 0.0
@export var action_name: StringName = &"entity_click"

@export var entity_id := -1
@export var entity_archetype_id: StringName = StringName()
@export var legacy_template_id: StringName = StringName()

@export var lane_id := -1
@export var slot_index := -1

@export var from_lane := -1
@export var from_slot := -1
@export var to_lane := -1
@export var to_slot := -1

@export var metadata: Dictionary = {}
