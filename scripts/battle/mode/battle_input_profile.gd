extends Resource
class_name BattleInputProfile

@export var profile_id: StringName = StringName()

@export var enable_card_select := true
@export var enable_card_place := true
@export var enable_slot_click := true
@export var enable_entity_click := false
@export var enable_slot_drag := false
@export var enable_swap := false
@export var enable_manual_skill := false
@export var enable_rhythm_hit := false
@export var enable_cancel := true

@export var input_tags: PackedStringArray = PackedStringArray()
